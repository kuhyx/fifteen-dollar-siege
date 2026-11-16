"""The recorder beside the game: gpu-screen-recorder, or ffmpeg x11grab as the fallback.

One part file per run of the recorder; every part sits on the same t0 timeline (the
unix time of the first part's time 0), see encoder.py (x11grab) and gsr.py.
"""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

from recording import encoder, gsr, window

WINDOW_WAIT_S = 30.0
RETURN_WAIT_S = 3600.0  # a window that went away may take a whole break to return
MAX_QUICK_DEATHS = 3  # ffmpeg dying right at start this many times in a row: give up
RECORDER_NICE = 10
STOP_GRACE_S = 20.0
SHORT_LIFE_S = 5.0  # a gsr part that ends sooner than this counts against gsr


def say(message: str) -> None:
    print(f"record: {message}", file=sys.stderr, flush=True)


def stop_recorder(proc: subprocess.Popen, grace_s: float = STOP_GRACE_S) -> bool:
    """SIGINT so the recorder writes the trailer; kill only after the grace. True = it finalized by itself."""
    if proc.poll() is not None:
        return True
    proc.send_signal(signal.SIGINT)
    try:
        proc.wait(timeout=grace_s)
        return True
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        return False


def part_file(session: str, number: int) -> str:
    """Part 1 is <session>.mkv; each restart (window came back) adds <session>.partN.mkv."""
    return f"{session}.mkv" if number == 1 else f"{session}.part{number}.mkv"


class Recorder:
    """The recorder process, restarted when the game's window goes away and returns.

    The window capture ends when the window is unmapped (an i3 workspace switch), resized or
    replaced. Each run is a part file on the same t0 timeline; the time between
    parts is simply not in the video (events there are `in_gap`). `backend` is "gsr" or
    "x11grab"; a gsr that fails to start switches the rest of the session to x11grab.
    """

    def __init__(
        self, game: subprocess.Popen, usable: set[str], paths: dict[str, Path], opts: dict, backend: str = "x11grab"
    ) -> None:
        self.game, self.usable, self.paths, self.opts = game, usable, paths, opts
        self.backend = backend
        self.proc: subprocess.Popen | None = None
        self.parts: list[str] = []
        self.t0 = 0.0
        self.quick_deaths = 0
        self.off = False
        self.open_gsr: tuple[Path, float] | None = None  # (file, first-frame unix) of the running gsr part
        self.win: window.Window | None = None  # the window the running part records
        self.pending: list[tuple[Path, float]] = []  # ended gsr parts, aligned once the game is over
        self.first_frames: dict[str, float] = {}  # part file -> unix time of its first frame (rec.json)
        self.gsr_started = 0.0  # monotonic start of the running gsr part
        self.short_lives = 0

    def _write_meta(self, codec: str, win: window.Window) -> None:
        meta = {
            "session": self.opts["session"], "t0_unix": self.t0, "video": self.parts[0], "parts": self.parts,
            "feedback": str(self.opts["feedback"] / "feedback.jsonl"), "encoder": codec, "backend": self.backend,
            "first_frame_unix": self.first_frames, "audio": self.opts["audio"], "fps": self.opts["fps"],
            "window": {"id": win.id, "width": win.width, "height": win.height},
        }  # fmt: skip
        self.paths["meta"].write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")

    def _spec(self, win: window.Window, out: Path) -> encoder.Spec:
        return encoder.Spec(
            window_id=win.id, fps=self.opts["fps"], t0_unix=self.t0, out=str(out),
            audio=self.opts["audio"], display=os.environ["DISPLAY"], width=win.width, height=win.height,
        )  # fmt: skip

    def _nice(self) -> str:
        # when the CPU is contended the game wins and the recorder drops frames, not the other way round.
        return os.environ.get("SIEGE_RECORDER_NICE", str(RECORDER_NICE))  # tests under a CPU cap: 0

    def _start_gsr(self, win: window.Window, name: str, out: Path) -> bool:
        with self.paths["log"].open("ab") as log:
            started = gsr.start(self._spec(win, out), log, self._nice())
        if started is None:
            say(f"gpu-screen-recorder failed to start, using x11grab; see {self.paths['log']}")
            self.backend = "x11grab"
            return False
        self.proc, first = started
        if not self.parts:
            self.t0 = first  # the timeline starts at the first frame, exactly (see gsr.py)
        self.parts.append(name)
        self.open_gsr = (out, first)
        self.first_frames[name] = first
        self.gsr_started = time.monotonic()
        self._write_meta("gsr-h264", win)
        say(f"recording {win.width}x{win.height} with gpu-screen-recorder -> {out}")
        self.quick_deaths = 0
        return True

    def _start_x11grab(self, win: window.Window, name: str, out: Path) -> None:
        codec = encoder.pick(self.usable)
        if not self.parts:
            self.t0 = time.time()  # the files' timeline starts here, exactly (see encoder.py)
        spec = self._spec(win, out)
        self.parts.append(name)
        self._write_meta(codec, win)
        with self.paths["log"].open("ab") as log:
            cmd = ["nice", "-n", self._nice(), *encoder.command(spec, codec)]
            self.proc = subprocess.Popen(cmd, stdout=log, stderr=log, start_new_session=True)
        try:
            self.proc.wait(timeout=1.0)  # still running after a second = recording
        except subprocess.TimeoutExpired:
            say(f"recording {win.width}x{win.height} with {codec} -> {out}")
            self.quick_deaths = 0
            return
        self.quick_deaths += 1
        self.parts.pop()
        self.proc = None
        say(f"ffmpeg died at start, see {self.paths['log']}")
        self.off = self.quick_deaths >= MAX_QUICK_DEATHS

    def _start_part(self, win: window.Window) -> None:
        name = part_file(self.opts["session"], len(self.parts) + 1)
        out = self.paths["dir"] / name
        self.paths["dir"].mkdir(parents=True, exist_ok=True)
        self.win = win
        if self.backend == "gsr" and self._start_gsr(win, name, out):
            return
        self._start_x11grab(win, name, out)

    def close_part(self) -> None:
        """The running gsr part has ended. Aligning it is a remux (disk I/O), so it waits for the game's end."""
        if self.open_gsr is not None:
            self.pending.append(self.open_gsr)
            self.open_gsr = None

    def _align_pending(self) -> None:
        """Moves each ended gsr part onto the t0 timeline (stream copy). Trouble is only reported."""
        pending, self.pending = self.pending, []
        for video, first in pending:
            try:
                gsr.align(video, first_unix=first, t0=self.t0)
            except (subprocess.SubprocessError, OSError, ValueError) as err:
                say(f"could not align {video.name} to the timeline: {err}")

    def _count_short_life(self) -> None:
        """A gsr that keeps dying soon after it started is replaced by x11grab for the rest of the session."""
        if self.open_gsr is None:
            return
        self.short_lives = self.short_lives + 1 if time.monotonic() - self.gsr_started < SHORT_LIFE_S else 0
        if self.short_lives >= MAX_QUICK_DEATHS:
            say("gpu-screen-recorder keeps stopping, using x11grab")
            self.backend = "x11grab"

    def step(self) -> bool:
        """One look at the recorder; True while a part is being recorded."""
        if self.off:
            return False
        if self.proc is not None and self.proc.poll() is None:
            if self.open_gsr is None or window.largest(self.game.pid) == self.win:
                return True
            # x11grab dies with its window; gsr neither exits nor resumes after an unmap
            # (an i3 workspace switch), so its part is ended here and the next one waits.
            stop_recorder(self.proc)
        first = not self.parts
        if self.proc is not None:
            say("recorder stopped (the window went away); waiting for it to come back")
            self.proc = None
            self._count_short_life()
            self.close_part()
        win = window.wait_stable(
            self.game.pid, WINDOW_WAIT_S if first else RETURN_WAIT_S, lambda: self.game.poll() is None
        )
        if win is None:
            if first:
                say("no game window found, not recording")
                self.off = True
            return False
        try:
            self._start_part(win)
        except (encoder.NoEncoder, OSError) as err:
            say(f"not recording: {err}")
            self.off = True
        return self.proc is not None

    def stop(self) -> None:
        if self.proc is not None and not stop_recorder(self.proc):
            say("the recorder ignored SIGINT and was killed; the mkv keeps what was written")
        self.close_part()
        self._align_pending()
