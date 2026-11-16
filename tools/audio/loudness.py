"""Loudness as ITU-R BS.1770-4 measures it: K-weighting, mean square, gating.

Peak level says when a file clips, not how loud it sounds. K-weighting (a
high shelf of +4 dB above ~1.5 kHz, then a high-pass at 38 Hz) models the
ear well enough that broadcasters level programmes with it, so the gate
compares files in LUFS. Filter constants: the analogue prototypes in
BS.1770-4 annex 1, as re-derived for any sample rate by pyloudnorm.

Two readings:
  integrated  gated programme loudness, for music (400 ms blocks, -70 LUFS
              absolute gate, -10 LU relative gate)
  short_peak  the loudest 100 ms window, for a sound effect: a 60 ms click
              has no 400 ms block to gate, and its loudest moment is what a
              player hears [design guess: the window length]
"""

from __future__ import annotations

import math

import numpy as np

BLOCK_S = 0.4
OVERLAP = 0.75
ABSOLUTE_GATE = -70.0
RELATIVE_GATE = -10.0
SHORT_S = 0.1
SHORT_HOP_S = 0.01
SILENT = -120.0
_OFFSET = -0.691


def _shelf(count: int, rate: int) -> np.ndarray:
    gain, q, centre = 4.0, 1.0 / math.sqrt(2.0), 1500.0
    amp = 10.0 ** (gain / 40.0)
    w0 = 2.0 * math.pi * centre / rate
    alpha = math.sin(w0) / (2.0 * q)
    cos_w0, root = math.cos(w0), 2.0 * math.sqrt(amp) * alpha
    b = (
        amp * ((amp + 1) + (amp - 1) * cos_w0 + root),
        -2 * amp * ((amp - 1) + (amp + 1) * cos_w0),
        amp * ((amp + 1) + (amp - 1) * cos_w0 - root),
    )
    a = (
        (amp + 1) - (amp - 1) * cos_w0 + root,
        2 * ((amp - 1) - (amp + 1) * cos_w0),
        (amp + 1) - (amp - 1) * cos_w0 - root,
    )
    return _response(b, a, count, rate)


def _highpass(count: int, rate: int) -> np.ndarray:
    q, centre = 0.5, 38.0
    w0 = 2.0 * math.pi * centre / rate
    alpha = math.sin(w0) / (2.0 * q)
    cos_w0 = math.cos(w0)
    b = ((1 + cos_w0) / 2, -(1 + cos_w0), (1 + cos_w0) / 2)
    return _response(b, (1 + alpha, -2 * cos_w0, 1 - alpha), count, rate)


def _response(b: tuple[float, ...], a: tuple[float, ...], count: int, rate: int) -> np.ndarray:
    z = np.exp(-2j * math.pi * np.fft.rfftfreq(count, d=1.0 / rate) / rate)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def k_weighted(signal: np.ndarray, rate: int) -> np.ndarray:
    """The signal as the ear weighs it, as (frames, channels)."""
    body = signal if signal.ndim == 2 else signal[:, None]
    count = len(body)
    if count < 2:
        return body.astype(np.float64)
    curve = (_shelf(count, rate) * _highpass(count, rate))[:, None]
    return np.fft.irfft(np.fft.rfft(body, axis=0) * curve, n=count, axis=0)


def _lufs(mean_square: float) -> float:
    return _OFFSET + 10.0 * math.log10(mean_square) if mean_square > 0.0 else SILENT


def _block_powers(weighted: np.ndarray, rate: int, block_s: float, hop_s: float) -> np.ndarray:
    """Mean square of every window, summed over channels (BS.1770 weights L and R at 1)."""
    block = max(int(block_s * rate), 1)
    hop = max(int(hop_s * rate), 1)
    power = np.sum(weighted**2, axis=1)
    if len(power) < block:
        # Shorter than one window: the sound in a window of silence, as a player hears it.
        return np.array([float(np.sum(power)) / block])
    sums = np.concatenate(([0.0], np.cumsum(power)))
    starts = np.arange(0, len(power) - block + 1, hop)
    return (sums[starts + block] - sums[starts]) / block


def integrated(signal: np.ndarray, rate: int) -> float:
    """Gated programme loudness in LUFS."""
    powers = _block_powers(k_weighted(signal, rate), rate, BLOCK_S, BLOCK_S * (1.0 - OVERLAP))
    loud = powers[[_lufs(float(p)) > ABSOLUTE_GATE for p in powers]]
    if not len(loud):
        return SILENT
    relative = _lufs(float(np.mean(loud))) + RELATIVE_GATE
    kept = loud[[_lufs(float(p)) > relative for p in loud]]
    return _lufs(float(np.mean(kept))) if len(kept) else SILENT


def short_peak(signal: np.ndarray, rate: int) -> float:
    """Loudness of the loudest 100 ms, in LUFS."""
    powers = _block_powers(k_weighted(signal, rate), rate, SHORT_S, SHORT_HOP_S)
    return _lufs(float(np.max(powers)))


def of_kind(signal: np.ndarray, rate: int, kind: str) -> float:
    """The reading that fits the file: programme loudness for music, the loudest moment otherwise."""
    return integrated(signal, rate) if kind in ("music", "stem", "stinger") else short_peak(signal, rate)
