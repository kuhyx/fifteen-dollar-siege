"""gpu-screen-recorder (gsr): the low-impact recording backend.

x11grab makes the X server read every frame of the window back from the GPU into
system RAM (about 2 GB/s at 4K60), which slows the game. gsr captures the window
on the GPU (XComposite) and encodes with NVENC without that read-back; ffmpeg's
x11grab (encoder.py) stays as the fallback when gsr is missing or fails at start.

Timeline: gsr's file starts at 0 with its first frame, and
`-write-first-frame-ts yes` writes `<out>.ts` ("monotonic_microsec<TAB>realtime_microsec"
header, then one line of values). The realtime column is the unix time of file
time 0, less CAPTURE_LATENCY_S (measured): the first part's t0 is that time; a later part is remuxed (streams copied) so it sits on the same timeline.
Audio is Opus: gsr 6.1 has FLAC disabled.
"""

import os
import shutil
import signal
import subprocess
import time
from collections.abc import Mapping
from pathlib import Path
from typing import IO

from recording import encoder

GSR = "gpu-screen-recorder"
BACKEND_ENV = "SIEGE_RECORDER_BACKEND"  # auto (default) | gsr | x11grab
START_WAIT_S = 8.0  # EGL + NVENC init, until the first frame is stamped
ALIGN_TOLERANCE_S = 0.002  # a part this close to the timeline is not remuxed
# gsr writes the first-frame stamp ~87 ms after the screen showed that content
# (bench.sh sync on kuhy's :0, 2026-11-11: ten flips 76-98 ms late at 30 fps), so
# file time 0 is that much earlier; the median of the measurement, like x11grab's
# GRAB_LATENCY_FRAMES.
CAPTURE_LATENCY_S = 0.087


def available() -> bool:
    return shutil.which(GSR) is not None


def pick_backend(env: Mapping[str, str], audio: str, have_gsr: bool) -> str:
    """gsr when installed; x11grab when forced, when gsr is missing, or for the silent test source."""
    if env.get(BACKEND_ENV) == "x11grab" or audio == "lavfi" or not have_gsr:
        return "x11grab"
    return "gsr"


def command(spec: encoder.Spec) -> list[str]:
    """The gsr argv. SIGINT makes it stop and finalize the file."""
    audio = "default_output" if spec.audio == "default" else f"device:{spec.audio}"
    return [
        GSR, "-w", str(spec.window_id), "-f", str(spec.fps), "-fm", "cfr", "-k", "h264", "-q", "very_high",
        "-c", "mkv", "-cursor", "no", "-a", audio, "-ac", "opus", "-write-first-frame-ts", "yes",
        "-v", "no", "-o", spec.out,
    ]  # fmt: skip


def ts_path(out: str | Path) -> Path:
    return Path(f"{out}.ts")


def parse_first_frame(text: str) -> float | None:
    """Unix seconds of the first frame from the .ts file, None until it is completely written."""
    if not text.endswith("\n"):
        return None
    fields = text.splitlines()[-1].split("\t")
    if len(fields) != 2 or not all(f.isdigit() for f in fields):
        return None
    return int(fields[1]) / 1_000_000


def _read_first_frame(path: Path) -> float | None:
    try:
        return parse_first_frame(path.read_text(encoding="utf-8"))
    except OSError:
        return None


def start(
    spec: encoder.Spec, log: IO[bytes], nice: str, wait_s: float = START_WAIT_S
) -> tuple[subprocess.Popen, float] | None:
    """Starts gsr; (process, unix time of its first frame) once it records, None when it failed."""
    ts = ts_path(spec.out)
    ts.unlink(missing_ok=True)
    proc = subprocess.Popen(
        ["nice", "-n", nice, *command(spec)], stdout=log, stderr=log, start_new_session=True
    )  # fmt: skip
    deadline = time.monotonic() + wait_s
    while proc.poll() is None and time.monotonic() < deadline:
        first = _read_first_frame(ts)
        if first is not None:
            return proc, first - CAPTURE_LATENCY_S
        time.sleep(0.05)
    if proc.poll() is None:
        proc.send_signal(signal.SIGKILL)
    proc.wait()
    ts.unlink(missing_ok=True)
    Path(spec.out).unlink(missing_ok=True)
    return None


def shift_delta(first_unix: float, t0: float, video_start: float) -> float:
    """Seconds to add to a part's stamps so its first frame lands at first_unix on the t0 timeline."""
    return (first_unix - t0) - video_start


def shift_command(src: Path, dst: Path, delta: float) -> list[str]:
    cmd = ["ffmpeg", "-v", "error", "-y", "-copyts", "-i", str(src), "-map", "0"]
    return [*cmd, "-c", "copy", "-output_ts_offset", f"{delta:.6f}", "-f", "matroska", str(dst)]


def video_start(video: Path) -> float:
    cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=start_time"]
    done = subprocess.run([*cmd, "-of", "csv=p=0", str(video)], capture_output=True, text=True, check=True, timeout=60)
    return float(done.stdout.strip())


def align(video: Path, first_unix: float, t0: float) -> None:
    """Moves a finished gsr part onto the t0 timeline (stream copy; nothing when it is already there)."""
    delta = shift_delta(first_unix, t0, video_start(video))
    if abs(delta) <= ALIGN_TOLERANCE_S:
        return
    tmp = video.with_suffix(".shift.mkv")
    subprocess.run(shift_command(video, tmp, delta), check=True, timeout=600)
    os.replace(tmp, video)
