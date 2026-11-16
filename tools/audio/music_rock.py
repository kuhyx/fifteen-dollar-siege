"""The rock band's riff: an ORIGINAL eight-bar hard-rock loop for the `rock_band` buff.

The buff's source text names a real band and song; the game uses neither
(CLAUDE.md, CREDITS.md). This riff is written from scratch and is built to
be unlike that song on every axis a listener would name:

  key      D minor pentatonic with the blues flat fifth, on a dropped low D.
           That song is in B major.
  tempo    120 beats a minute, a mid-tempo stomp. That song runs near 134.
  rhythm   syncopated power-chord stabs with rests between palm-muted
           chugs, the F chord pushed onto the "and" of two. That song's
           hook is an unbroken stream of sixteenths on one string.
  melody   chords D5 - F5 - G5, answered by C5 - D5, then F5 G5 B-flat5 C5
           and a blues-scale run. No pedal-point figure against an open
           string, no chanted hook, no quoted interval pattern.

Same tempo and half the length of the battle bed (16.0 s), so the game can
fade it in over the bed in phase. Reference for the quality bar only: the
twin-guitar riff writing of late-1970s hard rock, panned left and right.
"""

from __future__ import annotations

import numpy as np
from music_theory import sequencer

from audio import drums, dsp, grid, guitar, voices

NAME = "rock_riff"
SEED = 20261118
TEMPO = 120.0
BARS = 8
BEATS = 4.0 * BARS
RECIPE = {"key": "D minor pentatonic (blues)", "tempo_bpm": TEMPO, "meter": "4/4", "bars": BARS, "seed": SEED}
# Guitar roots in drop-D tuning, as MIDI notes (D2 = 38).
ROOT = {"D": 38, "F": 41, "G": 43, "Bb": 46, "C": 48}

# One bar: (beat, chord, length in beats, palm-muted).
_MAIN = (
    (0, "D", 0.5, False),
    (0.5, "D", 0.5, True),
    (1, "D", 0.5, True),
    (1.5, "F", 1.0, False),
    (2.5, "D", 0.5, True),
    (3, "G", 0.5, False),
    (3.5, "D", 0.5, True),
)
_ANSWER = (
    (0, "D", 0.5, False),
    (0.5, "D", 0.5, True),
    (1, "D", 0.5, True),
    (1.5, "C", 0.5, False),
    (2, "D", 1.0, False),
)
_ANSWER_SHORT = _ANSWER[:4]
_CLIMB = (
    (0, "F", 1.0, False),
    (1, "F", 0.5, True),
    (1.5, "F", 0.5, True),
    (2, "G", 1.0, False),
    (3, "G", 0.5, True),
    (3.5, "G", 0.5, True),
)
_TOP = ((0, "Bb", 1.0, False), (1, "Bb", 0.5, True), (1.5, "Bb", 0.5, False), (2, "C", 1.5, False))
_STOPS = ((0, "D", 0.5, False), (1, "D", 0.5, False))
RIFF = (_MAIN, _ANSWER, _MAIN, _ANSWER_SHORT, _CLIMB, _TOP, _MAIN, _STOPS)
# Lead fills as (bar, first beat, step in beats, MIDI notes).
FILLS = (
    (1, 3.0, 0.5, (57, 60)),
    (3, 2.0, 0.25, (62, 65, 67, 68, 67, 65, 62, 60)),
    (7, 2.0, 0.25, (62, 60, 57, 55, 53, 55, 57, 60)),
)
_KICK = "K.....K...K....."
_SNARE = "....S.......S..."
_HATS = "h.h.h.h.h.h.h.h."
_HATS_OPEN = "h.h.h.h.h.h.h.o."
_SNARE_FILL = "....S.......SSSS"


def _guitars(mix: grid.Mix) -> None:
    cache: dict[tuple[str, float, bool, int], np.ndarray] = {}
    beat_s = sequencer.beat_seconds(TEMPO)
    for bar, row in enumerate(RIFF):
        for beat, name, length, mute in row:
            for take, side in ((0, -0.7), (1, 0.7)):
                key = (name, length, mute, take)
                if key not in cache:
                    cache[key] = guitar.power(ROOT[name], length * beat_s, mute, take)
                mix.hit(bar * 4.0 + beat, cache[key], pan=side, gain=0.8 if mute else 0.95)
            mix.play(
                [sequencer.NoteEvent(ROOT[name], bar * 4.0 + beat, length, 0.9 if not mute else 0.7)],
                voices.bass,
                gain=0.6,
            )
    for bar, first, step, notes in FILLS:
        for index, midi in enumerate(notes):
            lead = guitar.chord((midi,), step * beat_s, take=index % 2)
            mix.hit(bar * 4.0 + first + index * step, lead, pan=0.15, gain=0.8)


def _kit(mix: grid.Mix) -> None:
    kit = {
        "K": (drums.kick(), 1.3),
        "S": (drums.snare(), 1.5),
        "h": (drums.hat(), 0.5),
        "o": (drums.hat(open_hat=True), 0.55),
    }
    for bar in range(BARS):
        at = bar * 4.0
        mix.row(_KICK, 0.25, kit, at)
        mix.row(_SNARE_FILL if bar == BARS - 1 else _SNARE, 0.25, kit, at, pan=0.05)
        mix.row(_HATS_OPEN if bar % 4 == 3 else _HATS, 0.25, kit, at, pan=0.3)
        if bar % 4 == 0:
            mix.hit(at, drums.crash(), pan=-0.3, gain=0.45)


def render() -> np.ndarray:
    mix = grid.Mix(TEMPO, BEATS, wrap=True, seed=SEED)
    _guitars(mix)
    _kit(mix)
    # A little shared grit glues the band together; the high-pass comes last
    # because clipping an uneven wave leaves a DC offset behind.
    glued = dsp.drive(dsp.room(mix.total, 0.6, 0.08, SEED, wrap=True) * 0.55, 1.3)
    return dsp.highpass(glued, 32.0, wrap=True)
