"""16-bit PCM WAV in and out (mono or stereo), plus Godot's import sidecar.

Lossless only: PCM at the render rate, never a codec (build-game R13).

THE LOOP FRAME. Godot 4.7.2 plays a forward-looping WAV as a closed curve:
its import sets `loop_end` to the LAST frame index, plays that frame, then
continues from frame 1. A file of L frames therefore loops every L - 1 and
skips frame 0 on each wrap (measured with `AudioStreamPlayback.mix_audio`
on a 16-frame ramp). So a loop of L frames is written as L + 1: the first
frame again at the end. Godot then repeats exactly L frames, and stems of
32 s and 16 s stay locked. `read_loop` drops that frame again.

THE SIDECAR. Without one Godot imports a WAV as Quite OK Audio (lossy,
`compress/mode=2`) and without a loop. The sidecar is written beside every
file with PCM and the loop mode; Godot fills in the uid and paths on import
and keeps the [params]. tests/audio/test_audio_bank.gd loads each stream and
checks what Godot really made of it.
"""

from __future__ import annotations

import hashlib
import wave
from pathlib import Path

import numpy as np
from music_theory import synth

_SAMPLE_BYTES = 2
# Godot's enum for edit/loop_mode: 0 detect, 1 DISABLED, 2 forward.
_LOOP_OFF = 1
_LOOP_FORWARD = 2
_SIDECAR = """[remap]

importer="wav"
type="AudioStreamWAV"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop_mode}
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def closed(signal: np.ndarray) -> np.ndarray:
    """A loop with its first frame repeated at the end (see THE LOOP FRAME)."""
    return np.concatenate((signal, signal[:1]))


def write(path: Path, signal: np.ndarray, rate: int, loop: bool = False) -> Path:
    """Writes mono (N,) or stereo (N, 2) floats as 16-bit PCM; a loop gets its closing frame."""
    body = closed(signal) if loop else signal
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1 if body.ndim == 1 else body.shape[1])
        handle.setsampwidth(_SAMPLE_BYTES)
        handle.setframerate(rate)
        handle.writeframes(synth.to_int16(body).tobytes())
    return path


def read(path: Path) -> tuple[np.ndarray, int]:
    """The file's frames as floats, (N,) for mono and (N, C) otherwise, and its rate."""
    with wave.open(str(path), "rb") as handle:
        if handle.getsampwidth() != _SAMPLE_BYTES:
            raise ValueError(f"{path} is not 16-bit PCM")
        channels = handle.getnchannels()
        rate = handle.getframerate()
        raw = handle.readframes(handle.getnframes())
    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32767.0
    return (samples if channels == 1 else samples.reshape(-1, channels)), rate


def is_closed(signal: np.ndarray) -> bool:
    """The last frame repeats the first, as `write(loop=True)` leaves it."""
    return len(signal) > 1 and bool(np.all(signal[-1] == signal[0]))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sidecar_text(loop: bool) -> str:
    return _SIDECAR.format(loop_mode=_LOOP_FORWARD if loop else _LOOP_OFF)


def write_sidecar(path: Path, loop: bool) -> bool:
    """Writes `<path>.import` unless Godot's own copy already holds these params."""
    sidecar = path.with_name(path.name + ".import")
    wanted = sidecar_text(loop).split("[params]")[1].strip()
    if sidecar.exists() and sidecar.read_text().split("[params]")[-1].strip() == wanted:
        return False
    sidecar.write_text(sidecar_text(loop))
    return True
