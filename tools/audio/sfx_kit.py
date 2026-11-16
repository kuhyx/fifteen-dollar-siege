"""Building blocks of a synthesised sound effect.

A sound effect is mostly motion: a pitch that falls reads as a hit or a
failure, one that rises as a charge or a reward (the sfxr rule of thumb the
toolkit's own later presets follow). The blocks: a tone on a pitch curve, a
struck ping, a low thump, noise through a fixed or a gliding band, and two
envelopes. Every block is seeded from a name, so a re-render is the same
bytes. A recipe lays blocks on a short timeline with `Take`.
"""

from __future__ import annotations

import math
import zlib

import numpy as np

from audio import dsp
from audio.dsp import SR


def rng(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


def tone(
    points: tuple[float, ...],
    seconds: float,
    partials: int = 1,
    tilt: float = 1.0,
    top_hz: float = 5000.0,
    wobble: tuple[float, float] = (0.0, 6.0),
    odd: bool = False,
) -> np.ndarray:
    """`partials` harmonics (levels 1 / k^tilt) on a pitch gliding through `points` (Hz).

    `wobble` is (semitones, times a second) of vibrato. `odd` keeps the odd
    harmonics only: hollow, like a square wave.
    """
    count = dsp.frames(seconds)
    curve = dsp.glide(points, count)
    if wobble[0]:
        curve = curve * 2.0 ** (wobble[0] / 12.0 * np.sin(2.0 * math.pi * wobble[1] * dsp.times(count)))
    order = np.arange(1, partials + 1)
    levels = 1.0 / order**tilt
    if odd:
        levels = np.where(order % 2 == 1, levels, 0.0)
    return dsp.harmonics(curve, levels, top_hz)


def struck(signal: np.ndarray, tau_s: float, attack_s: float = 0.002) -> np.ndarray:
    """Hit, then dying away by a constant ratio."""
    return signal * dsp.ramp(len(signal), attack_s) * dsp.decay(len(signal), tau_s)


def swell(signal: np.ndarray, attack_s: float, release_s: float) -> np.ndarray:
    """Rises over `attack_s`, holds, falls to nothing over the last `release_s`."""
    count = len(signal)
    fall = np.clip((count - np.arange(count)) / max(dsp.frames(release_s), 1), 0.0, 1.0)
    return signal * dsp.ramp(count, attack_s) * fall


def ping(hz: float, tau_s: float, partials: tuple[tuple[float, float], ...] = ((1.0, 1.0), (2.76, 0.35))) -> np.ndarray:
    """A struck bar: partials at uneven ratios (1, 2.76: a free bar), so it reads as metal or wood."""
    count = dsp.frames(tau_s * 6.0)
    clock = dsp.times(count)
    out = np.zeros(count)
    for ratio, level in partials:
        out += level * np.sin(2.0 * math.pi * hz * ratio * clock) * np.exp(-clock * ratio**0.5 / tau_s)
    return out * dsp.ramp(count, 0.001)


def thump(start_hz: float, end_hz: float, tau_s: float, drop_s: float = 0.05) -> np.ndarray:
    """A low sine that falls in pitch: the weight under a hit."""
    count = dsp.frames(tau_s * 6.0)
    curve = np.full(count, end_hz)
    head = min(dsp.frames(drop_s), count)
    curve[:head] = dsp.glide((start_hz, end_hz), head)
    return struck(np.sin(2.0 * math.pi * np.cumsum(curve) / SR), tau_s, 0.003)


def hiss(seconds: float, name: str) -> np.ndarray:
    return dsp.noise(dsp.frames(seconds), rng(name))


def band(seconds: float, name: str, centre_hz: float, q: float = 1.0) -> np.ndarray:
    """Noise around one frequency."""
    return dsp.bandpass(hiss(seconds, name), centre_hz, q)


def sweep(points: tuple[float, ...], seconds: float, name: str, q: float = 2.5) -> np.ndarray:
    """Noise through a band that glides through `points`: a whoosh."""
    return dsp.sweep_bandpass(hiss(seconds, name), dsp.glide(points, dsp.frames(seconds)), q)


def grains(seconds: float, name: str, per_second: float, grain_s: float = 0.004) -> np.ndarray:
    """A 0..1 gate of short bumps at random times: crackle, rattle, pattering feet."""
    count = dsp.frames(seconds)
    gate = np.zeros(count)
    source = rng(name)
    width = max(dsp.frames(grain_s), 2)
    bump = np.hanning(width + 2)[1:-1]
    for start in source.integers(0, max(count - width, 1), int(per_second * seconds)):
        gate[start : start + width] = np.maximum(gate[start : start + width], bump[: count - start])
    return gate


class Take:
    """A short mono timeline: `add(at_s, sound, gain)` and read `mix`."""

    def __init__(self, seconds: float) -> None:
        self.mix = np.zeros(dsp.frames(seconds))

    def add(self, at_s: float, sound: np.ndarray, gain: float = 1.0) -> Take:
        dsp.place(self.mix, dsp.frames(at_s), sound * gain)
        return self
