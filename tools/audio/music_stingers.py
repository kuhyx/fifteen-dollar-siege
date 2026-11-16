"""The two endings: a flag goes up, or the army goes up in flames.

win_stinger   the battle's D minor turns to D MAJOR (one array element, the
              third, F -> F sharp): horns climb the tonic chord from a
              dominant pickup (A -> D, the V -> I pull), kettle drums, a
              cymbal, a held chord.
lose_stinger  three heavy falling notes of the minor chord, then the last
              one sags an octave like a deflating bagpipe, and a single
              tiny pluck answers from far above. Slapstick, not tragedy.

One-shots: they end in silence instead of wrapping.
"""

from __future__ import annotations

import math

import numpy as np
from music_theory import pitch, sequencer, synth

from audio import drums, dsp, grid, voices
from audio.dsp import SR

SEED = 20261119
WIN_RECIPE = {"key": "D major", "tempo_bpm": 132.0, "meter": "4/4", "bars": 2, "seed": SEED}
LOSE_RECIPE = {"key": "D minor", "tempo_bpm": 96.0, "meter": "4/4", "bars": 1.5, "seed": SEED}


def _end(mix: grid.Mix, wet: float) -> np.ndarray:
    wetted = dsp.room(dsp.highpass(mix.total, 30.0), 1.6, wet, SEED)
    return dsp.fade_out(wetted, 0.4)


def win() -> np.ndarray:
    key = grid.Key("D4", "major")
    low = grid.Key("D3", "major")
    mix = grid.Mix(132.0, 11.0, wrap=False, seed=SEED)
    call = key.line("-3/.25 -3/.25 -3/.5 | 0 2/.5 4/.5 | 7/3.5", 0.0, 0.75)
    mix.play(call, voices.horn, pan=-0.15, gain=0.6)
    # Under the top note: the whole tonic chord, horns and strings.
    held = [sequencer.NoteEvent(midi, 3.0, 3.5, 0.6) for midi in (*low.chord(1), key.note(2))]
    mix.play(held, voices.horn, pan=0.25, gain=0.36)
    mix.play(held, voices.strings, pan=0.0, gain=0.26)
    dominant = drums.timpani(pitch.midi_to_hz(low.note(-3)))
    tonic = drums.timpani(pitch.midi_to_hz(low.note(0)))
    for beat, drum, gain in ((0.0, dominant, 0.5), (0.5, dominant, 0.4), (1.0, tonic, 0.7), (3.0, tonic, 0.8)):
        mix.hit(beat, drum, pan=0.1, gain=gain)
    mix.hit(3.0, dsp.lowpass(drums.crash(), 6500.0), pan=-0.2, gain=0.4)
    mix.row("t.t.t.t.T...", 0.25, {"t": (drums.tambourine(), 0.25), "T": (drums.tambourine(), 0.45)}, 1.0, pan=-0.4)
    return _end(mix, 0.3)


def _sag(seconds: float) -> np.ndarray:
    """D3 losing its breath: the pitch drops an octave and the tone closes up."""
    count = dsp.frames(seconds)
    clock = dsp.times(count)
    curve = dsp.glide((146.8, 139.0, 110.0, 73.4), count) * (1.0 + 0.012 * np.sin(2.0 * math.pi * 6.5 * clock))
    bright = dsp.harmonics(curve, 1.0 / np.arange(1, 14) ** 1.1, 3000.0)
    dull = dsp.harmonics(curve, 1.0 / np.arange(1, 5) ** 2.0, 3000.0)
    closing = np.linspace(1.0, 0.0, count) ** 1.5
    body = (bright * closing + dull * (1.0 - closing)) * synth.adsr(
        synth.Envelope(0.05, 0.1, 0.9, 0.5), (count + 0.5) / SR, SR
    )
    return synth.normalize(body, 1.0)


def lose() -> np.ndarray:
    key = grid.Key("D3", "minor")
    mix = grid.Mix(96.0, 8.5, wrap=False, seed=SEED)
    mix.play(key.line("4 2 0/.5", 0.0, 0.8), voices.horn, pan=-0.1, gain=0.6)
    mix.play(key.line("-3 -5 -7/.5", 0.0, 0.7), voices.strings, pan=0.2, gain=0.4)
    thud = drums.timpani(pitch.midi_to_hz(key.note(-7)))
    for beat, gain in ((0.0, 0.6), (1.0, 0.65), (2.0, 0.8)):
        mix.hit(beat, thud, pan=0.05, gain=gain)
    mix.hit(2.5, _sag(1.9), pan=-0.1, gain=0.55)
    mix.play(key.line("21/.5", 6.2, 0.5), voices.pizz, pan=0.35, gain=0.4)
    return _end(mix, 0.25)
