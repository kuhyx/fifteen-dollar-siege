"""Runs the game and, for kuhy's own dev play, an external recorder beside it.

The game is a child process; its window is found by pid; the recorder
(gpu-screen-recorder, else ffmpeg x11grab, with the audio monitor) starts once the
window has settled and gets SIGINT when the game exits, so the mkv is finalized. Then finalize.py writes events.json + chapters.
Recording trouble never changes the game's exit code or stops the game.
"""

import os
import random
import signal
import subprocess
import threading
import time
from collections.abc import Mapping, Sequence
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from recording import encoder, finalize, gsr, policy, timeline
from recording.recorder import Recorder, part_file, say, stop_recorder  # noqa: F401  re-exported

BINARIES = "data/fifteen-dollar-siege_binaries"


def session_of(command: Sequence[str]) -> str:
    return policy.arg_value(command, "--session-id=")


def with_session(command: Sequence[str], session: str) -> list[str]:
    """The command with `--session-id=` among the game's user args (an existing one wins)."""
    return _with_user_arg(command, "--session-id=", session)


def _with_user_arg(command: Sequence[str], prefix: str, value: str) -> list[str]:
    out = list(command)
    if policy.arg_value(out, prefix):
        return out
    if "--" not in out:
        out.append("--")
    return [*out, f"{prefix}{value}"]


def feedback_dir(command: Sequence[str], env: Mapping[str, str]) -> Path:
    """Where the game's telemetry goes: --feedback-dir=, else the binaries folder's feedback/."""
    forced = policy.arg_value(command, "--feedback-dir=")
    if forced:
        return Path(forced)
    if env.get("SIEGE_BINARIES"):
        return Path(env["SIEGE_BINARIES"]) / "feedback"
    return Path(env.get("HOME", str(Path.home()))) / BINARIES / "feedback"


def recording_paths(feedback: Path, session: str) -> dict[str, Path]:
    rec = feedback / "recordings"
    return {
        "dir": rec,
        "video": rec / f"{session}.mkv",
        "events": rec / f"{session}.events.json",
        "meta": rec / f"{session}.rec.json",
        "log": rec / f"{session}.ffmpeg.log",
    }


def new_session() -> str:
    return f"{int(time.time())}-run-{random.randrange(1 << 16):04x}"


def _forward_signals(game: subprocess.Popen) -> None:
    """The launcher is a thin parent: kill/hangup go to the game; Ctrl-C already reaches it directly."""
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda s, _f: game.send_signal(s))


def _finish(paths: dict[str, Path]) -> None:
    if not paths["meta"].exists():
        return
    try:
        doc = finalize.finalize(paths["meta"])
        shown = sum(1 for e in doc["events"] if timeline.in_recording(e))
        parts = doc["video"]["parts"]
        gaps = f", {len(parts)} parts" if len(parts) > 1 else ""
        say(f"{paths['dir'] / doc['video']['file']} ({doc['video']['duration_s']:.0f} s, {shown} moments{gaps})")
    except Exception as err:  # noqa: BLE001  recording trouble must not fail the play session
        say(f"could not build the timeline: {err}")


def run(
    command: Sequence[str],
    env: Mapping[str, str] | None = None,
    *,
    force: bool = False,
    session: str = "",
    audio: str = "default",
    fps: int = 30,
    max_seconds: float = 0.0,
) -> int:
    """Runs `command`; records it when policy allows. Returns the game's exit code."""
    env = os.environ if env is None else env
    decision = policy.decide(command, env, force)
    if not decision.record:
        say(f"off ({decision.reason})")
        game = subprocess.Popen(list(command), env=dict(env))
        _forward_signals(game)
        return game.wait()
    session = session_of(command) or session or new_session()
    fb = feedback_dir(command, env)
    argv = _with_user_arg(with_session(command, session), "--feedback-dir=", str(fb))
    paths = recording_paths(fb, session)
    with ThreadPoolExecutor(max_workers=1) as pool:
        usable = pool.submit(encoder.probe_usable)  # NVENC init overlaps the game's start
        game = subprocess.Popen(argv, env=dict(env))
        _forward_signals(game)
        opts = {"fps": fps, "audio": audio, "session": session, "feedback": fb}
        backend = gsr.pick_backend(env, audio, gsr.available())
        recorder = Recorder(game, usable.result(), paths, opts, backend)
        timer_started = False
        while game.poll() is None:
            recording = recorder.step()
            if max_seconds > 0 and not timer_started and (recording or recorder.off):
                timer_started = True  # the test flag: stop the game N s after recording began
                threading.Timer(max_seconds, lambda: game.poll() is None and game.send_signal(signal.SIGTERM)).start()
            time.sleep(0.5)
    code = game.wait()
    recorder.stop()
    _finish(paths)
    return code
