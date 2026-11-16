"""Pitched instruments: each is `voice(hz, seconds) -> mono signal`, peak 1.

The skill's measured finding is that a raw saw arpeggio loses to a produced
track, and names the fix: detuned pairs, a darker top, a pad. So no voice
here is a bare oscillator. Each is band-limited additive synthesis (the
toolkit's `synth.additive`, partials stopped well under Nyquist) shaped the
way the real instrument is: a plucked string's high partials die first, a
horn brightens as it gets louder, a recorder has breath in it.
A note may ring past its written length; the mix wraps the tail in a loop.
"""

from __future__ import annotations

import math

import numpy as np
from music_theory import synth

from audio import dsp
from audio.dsp import SR

# A tuned minor-third bell: (ratio to the prime, level, seconds to fall by e).
# Hum, prime, tierce, quint, nominal, then the upper partials; the hum rings longest.
_BELL_PARTIALS = (
    (0.5, 0.5, 2.2),
    (1.0, 1.0, 1.5),
    (1.2, 0.7, 1.0),
    (1.5, 0.35, 0.8),
    (2.0, 0.55, 0.6),
    (2.5, 0.2, 0.4),
    (3.0, 0.18, 0.3),
    (4.0, 0.1, 0.2),
)


def _partials(hz: float, top_hz: float) -> np.ndarray:
    return np.arange(1, max(1, min(48, int(top_hz // hz))) + 1)


def _static(hz: float, count: int, amplitudes: np.ndarray) -> np.ndarray:
    """`synth.additive` for exactly `count` frames."""
    return synth.additive(hz, (count + 0.5) / SR, amplitudes.tolist(), SR)


def _adsr(count: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    return synth.adsr(synth.Envelope(attack, decay, sustain, release), (count + 0.5) / SR, SR)


def _unit(signal: np.ndarray) -> np.ndarray:
    return synth.normalize(dsp.fade_out(signal, 0.02), 1.0)


def pluck(hz: float, seconds: float, bright: float = 1.0, ring: float = 1.0) -> np.ndarray:
    """A lute string: plucked a fifth of the way along, the top partials gone in a moment."""
    count = dsp.frames(seconds + 0.9 * ring)
    clock = dsp.times(count)
    partial = _partials(hz, 7000.0)
    amplitudes = np.sin(math.pi * partial * 0.21) / partial
    slow = 1.1 * ring * (196.0 / hz) ** 0.4  # low strings ring longer
    out = np.zeros(count)
    for low, high, share in ((1, 2, 1.0), (3, 6, 0.42), (7, 99, 0.16)):
        group = np.where((partial >= low) & (partial <= high), amplitudes, 0.0)
        if group.any():
            out += _static(hz, count, group * (bright if low > 2 else 1.0)) * np.exp(-clock / (slow * share))
    lifted = np.exp(-np.clip(clock - seconds, 0.0, None) / (0.22 * ring))  # the finger comes off
    return _unit(out * lifted * dsp.ramp(count, 0.002))


def pizz(hz: float, seconds: float) -> np.ndarray:
    """A plucked bowed string: dark and short, the cartoon tip-toe."""
    return pluck(hz, min(seconds, 0.22), bright=0.55, ring=0.3)


def recorder(hz: float, seconds: float) -> np.ndarray:
    """A wooden flute: nearly a sine, a late vibrato, breath, a chiff at the start."""
    count = dsp.frames(seconds + 0.06)
    clock = dsp.times(count)
    wobble = 1.0 + 0.0035 * np.sin(2.0 * math.pi * 5.3 * clock) * np.clip((clock - 0.12) / 0.25, 0.0, 1.0)
    tone = dsp.harmonics(hz * wobble, [1.0, 0.28, 0.1, 0.035, 0.012])
    rng = np.random.default_rng(int(hz * 100.0))
    breath = dsp.bandpass(dsp.noise(count, rng), hz * 2.0, 1.2) * 0.05
    chiff = dsp.highpass(dsp.noise(count, rng), 1500.0) * dsp.decay(count, 0.012) * 0.1
    return _unit((tone + breath) * _adsr(count, 0.03, 0.05, 0.85, 0.07) + chiff * dsp.ramp(count, 0.002))


def horn(hz: float, seconds: float) -> np.ndarray:
    """A natural horn: the lips slide up into the note and it brightens as it swells."""
    count = dsp.frames(seconds + 0.1)
    clock = dsp.times(count)
    swell = _adsr(count, 0.045, 0.12, 0.78, 0.14)
    scoop = hz * 2.0 ** (-(18.0 / 1200.0) * np.exp(-clock / 0.03))
    partial = _partials(hz, 5200.0)
    dark = dsp.harmonics(scoop, 1.0 / partial**1.7, 5200.0)
    bright = dsp.harmonics(scoop, np.where(partial > 1, 1.0 / partial**0.9, 0.0), 5200.0)
    return _unit((dark + 0.55 * bright * swell**2) * swell)


def _section(hz: float, seconds: float, attack: float, release: float, top_hz: float = 4500.0) -> np.ndarray:
    """Three players a few cents apart: the detune is what makes it a section."""
    count = dsp.frames(seconds + release)
    amplitudes = 1.0 / _partials(hz, top_hz) ** 1.25
    out = np.zeros(count)
    for cents in (-6.0, 0.0, 7.0):
        out += _static(synth.detune(hz, cents), count, amplitudes[: len(_partials(synth.detune(hz, cents), top_hz))])
    return out * _adsr(count, attack, 0.1, 0.85, release)


def strings(hz: float, seconds: float) -> np.ndarray:
    """A slow bowed pad."""
    return _unit(_section(hz, seconds, 0.14, 0.3))


def staccato(hz: float, seconds: float) -> np.ndarray:
    """Short bow strokes for an ostinato."""
    return _unit(_section(hz, min(seconds, 0.2), 0.012, 0.07))


def tremolo(hz: float, seconds: float) -> np.ndarray:
    """A bow shaking on the string eight times a second: dread."""
    body = _section(hz, seconds, 0.2, 0.3, 3200.0)
    shake = 0.6 + 0.4 * np.sin(2.0 * math.pi * 8.0 * dsp.times(len(body)))
    return _unit(body * shake)


def drone(hz: float, seconds: float) -> np.ndarray:
    """A hurdy-gurdy's open string and its fifth, slowly beating."""
    count = dsp.frames(seconds + 0.5)
    clock = dsp.times(count)
    root = _static(hz, count, 1.0 / _partials(hz, 2400.0))
    fifth = _static(synth.detune(hz * 1.5, 4.0), count, 0.5 / _partials(hz * 1.5, 2400.0))
    breathe = 0.85 + 0.15 * np.sin(2.0 * math.pi * 0.45 * clock)
    return _unit((root + 0.6 * fifth) * breathe * _adsr(count, 0.4, 0.2, 0.9, 0.5))


def bass(hz: float, seconds: float) -> np.ndarray:
    """An electric bass: round, a little driven, stopped dead at the end of the note."""
    count = dsp.frames(seconds + 0.04)
    body = _static(hz, count, 1.0 / _partials(hz, 1600.0)) * _adsr(count, 0.006, 0.12, 0.7, 0.04)
    return _unit(dsp.drive(body * 0.9, 1.6))


def bell(hz: float, seconds: float) -> np.ndarray:
    """A church bell: the partials of a tuned bell (hum, prime, tierce, quint, nominal...)."""
    count = dsp.frames(seconds)
    clock = dsp.times(count)
    out = np.zeros(count)
    for ratio, level, tau in _BELL_PARTIALS:
        out += level * np.sin(2.0 * math.pi * hz * ratio * clock) * np.exp(-clock / (tau * seconds / 2.5))
    return _unit(out * dsp.ramp(count, 0.003))
