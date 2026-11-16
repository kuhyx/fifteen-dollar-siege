"""Percussion: each function returns one mono hit, peak 1, seeded from its name.

A drum is a pitch that drops and a burst of noise: the skin's note falls as
it relaxes, the noise is the stick. Medieval hand drums for the hub and the
battle, a rock kit for the band.
"""

from __future__ import annotations

import math
import zlib

import numpy as np
from music_theory import synth

from audio import dsp
from audio.dsp import SR


def _rng(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


def _skin(points: tuple[float, ...], drop_s: float, count: int) -> np.ndarray:
    """A sine whose pitch glides through `points` in `drop_s`, then holds."""
    curve = np.full(count, float(points[-1]))
    head = min(dsp.frames(drop_s), count)
    curve[:head] = dsp.glide(points, head)
    return np.sin(2.0 * math.pi * np.cumsum(curve) / SR)


def _hit(signal: np.ndarray) -> np.ndarray:
    return synth.normalize(dsp.fade_out(signal * dsp.ramp(len(signal), 0.0008), 0.01), 1.0)


def frame_drum(low: bool = True) -> np.ndarray:
    """A hand drum: `low` is the palm in the middle, otherwise fingers at the rim."""
    count = dsp.frames(0.45 if low else 0.25)
    body = _skin((150.0, 78.0) if low else (260.0, 170.0), 0.05, count) * dsp.decay(count, 0.15 if low else 0.07)
    slap = dsp.lowpass(dsp.noise(count, _rng("frame")), 900.0 if low else 2200.0) * dsp.decay(count, 0.012)
    return _hit(body + 0.5 * slap)


def taiko() -> np.ndarray:
    """A big war drum."""
    count = dsp.frames(0.9)
    # The note ends at 68 Hz, not lower: a laptop speaker has to carry it.
    body = _skin((135.0, 68.0), 0.07, count) * dsp.decay(count, 0.22)
    thump = dsp.lowpass(dsp.noise(count, _rng("taiko")), 650.0) * dsp.decay(count, 0.03)
    return _hit(dsp.drive(body + 0.6 * thump, 1.5))


def tom(hz: float) -> np.ndarray:
    count = dsp.frames(0.5)
    body = _skin((hz * 1.5, hz), 0.04, count) * dsp.decay(count, 0.16)
    stick = dsp.bandpass(dsp.noise(count, _rng("tom")), 1800.0, 0.8) * dsp.decay(count, 0.008)
    return _hit(body + 0.3 * stick)


def field_snare() -> np.ndarray:
    """A rope-tension side drum: more rattle than crack."""
    count = dsp.frames(0.3)
    rattle = dsp.highpass(dsp.bandpass(dsp.noise(count, _rng("field")), 1600.0, 0.7), 350.0) * dsp.decay(count, 0.08)
    return _hit(rattle + 0.6 * _skin((230.0, 190.0), 0.02, count) * dsp.decay(count, 0.05))


def tambourine() -> np.ndarray:
    count = dsp.frames(0.3)
    jingle = dsp.bandpass(dsp.noise(count, _rng("tambourine")), 6200.0, 1.4)
    shimmer = 0.7 + 0.3 * np.sin(2.0 * math.pi * 43.0 * dsp.times(count))
    return _hit(jingle * shimmer * dsp.decay(count, 0.055))


def timpani(hz: float) -> np.ndarray:
    """A kettle drum: partials at 1, 1.5, 2 and 2.44 of the note, plus the mallet."""
    count = dsp.frames(1.4)
    clock = dsp.times(count)
    out = np.zeros(count)
    for ratio, level, tau in ((1.0, 1.0, 0.5), (1.5, 0.5, 0.35), (1.99, 0.28, 0.25), (2.44, 0.14, 0.15)):
        out += level * np.sin(2.0 * math.pi * hz * ratio * clock) * np.exp(-clock / tau)
    mallet = dsp.lowpass(dsp.noise(count, _rng("timpani")), 700.0) * dsp.decay(count, 0.015)
    return _hit(out + 0.5 * mallet)


def woodblock(hz: float = 820.0) -> np.ndarray:
    count = dsp.frames(0.12)
    clock = dsp.times(count)
    tone = np.sin(2.0 * math.pi * hz * clock) + 0.4 * np.sin(2.0 * math.pi * hz * 2.42 * clock)
    return _hit(tone * dsp.decay(count, 0.03))


def kick() -> np.ndarray:
    count = dsp.frames(0.5)
    body = _skin((160.0, 56.0), 0.045, count) * dsp.decay(count, 0.13)
    click = dsp.highpass(dsp.noise(count, _rng("kick")), 2000.0) * dsp.decay(count, 0.003)
    return _hit(dsp.drive(body, 1.8) + 0.25 * click)


def snare() -> np.ndarray:
    count = dsp.frames(0.4)
    wires = dsp.highpass(dsp.bandpass(dsp.noise(count, _rng("snare")), 1900.0, 0.6), 250.0) * dsp.decay(count, 0.11)
    return _hit(wires + 0.7 * _skin((240.0, 185.0), 0.015, count) * dsp.decay(count, 0.06))


def hat(open_hat: bool = False) -> np.ndarray:
    count = dsp.frames(0.5 if open_hat else 0.12)
    metal = dsp.highpass(dsp.noise(count, _rng("hat")), 6500.0, poles=2)
    return _hit(metal * dsp.decay(count, 0.14 if open_hat else 0.026))


def crash() -> np.ndarray:
    count = dsp.frames(2.2)
    metal = dsp.highpass(dsp.bandpass(dsp.noise(count, _rng("crash")), 4500.0, 0.5), 2500.0)
    return _hit(metal * dsp.decay(count, 0.5))
