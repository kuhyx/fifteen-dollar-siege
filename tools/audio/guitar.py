"""A distorted electric guitar, for the rock band's riff.

Strings are additive plucks (picked near the bridge, so brighter than the
lute). The fuzz is a tanh, and a tanh makes new partials far above the ones
it is fed: at 44.1 kHz they would fold back as hash. So the chord is built
and clipped at twice the rate, a speaker-cabinet low-pass takes the top off,
and only then is every second frame kept.
"""

from __future__ import annotations

import math

import numpy as np
from music_theory import pitch, synth

from audio import dsp
from audio.dsp import SR

OVER = 2
_RATE = SR * OVER
# Cents each string of a chord sits off, and seconds between strings of one strum.
_DETUNE = (0.0, 4.0, -3.0, 2.0)
_STRUM_S = 0.004


def _at(hz: float) -> float:
    """A cutoff for dsp's filters (which assume SR) when the signal runs at `_RATE`."""
    return hz / OVER


def _string(hz: float, count: int, tau: float) -> np.ndarray:
    partial = np.arange(1, max(1, min(40, int(6000.0 // hz))) + 1)
    amplitudes = np.sin(math.pi * partial * 0.13) / partial
    clock = np.arange(count) / _RATE
    slow = synth.additive(hz, (count + 0.5) / _RATE, np.where(partial <= 3, amplitudes, 0.0).tolist(), _RATE)
    fast = synth.additive(hz, (count + 0.5) / _RATE, np.where(partial > 3, amplitudes, 0.0).tolist(), _RATE)
    return slow * np.exp(-clock / tau) + fast * np.exp(-clock / (tau * 0.4))


def chord(midis: tuple[int, ...], seconds: float, mute: bool = False, take: int = 0) -> np.ndarray:
    """One strum through the amp. `mute` is the palm on the bridge: a short dark chug.

    `take` shifts the detune so two takes panned apart sound like two players.
    """
    count = dsp.frames(seconds + 0.2) * OVER
    raw = np.zeros(count)
    for index, midi in enumerate(midis):
        cents = _DETUNE[(index + take) % len(_DETUNE)] + (3.0 if take else 0.0)
        hz = synth.detune(pitch.midi_to_hz(midi), cents)
        late = int(index * _STRUM_S * _RATE)
        raw[late:] += _string(hz, count - late, 0.09 if mute else 1.4)
    if mute:
        raw = dsp.lowpass(raw, _at(900.0))
    tight = dsp.highpass(raw, _at(110.0))  # a loose low end turns to mud in the fuzz
    fuzz = np.tanh(tight * (5.0 if mute else 9.0) / max(dsp.peak(tight), 1e-9))
    cabinet = dsp.highpass(dsp.lowpass(fuzz, _at(5200.0), poles=2), _at(85.0))
    cabinet = cabinet + 0.7 * dsp.bandpass(fuzz, _at(1700.0), 0.9)
    clock = np.arange(count) / _RATE
    stop = np.exp(-np.clip(clock - seconds, 0.0, None) / 0.02)  # the hand damps the strings
    voiced = (cabinet * stop * np.clip(clock / 0.002, 0.0, 1.0))[::OVER]
    return synth.normalize(dsp.fade_out(voiced, 0.02), 1.0)


def power(root_midi: int, seconds: float, mute: bool = False, take: int = 0) -> np.ndarray:
    """Root, fifth, octave: the chord that survives distortion."""
    return chord((root_midi, root_midi + 7, root_midi + 12), seconds, mute, take)
