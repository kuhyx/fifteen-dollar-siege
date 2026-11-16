"""The hub and shop loop: a light jig in D dorian for recorder, lute and hand drum.

Reference for the quality bar (skill procedural-music, step 1): Robert
Euvino's lute-and-recorder cues in Stronghold (2001), e.g. "Castle Jam":
the nearest well-known game to "a medieval village, played for laughs".
Nothing of it is quoted; the tune below is written for this game.

Mood -> recipe: curious and light = dorian (minor with a raised sixth, the
B natural over the G chord is the "medieval" colour), a lilting 6/8 at 92
dotted-quarter pulses a minute, plucked and blown instruments, no bass
weight. Form A A' B A', 32 bars, 41.7 s, so it does not grate in a long shop.
"""

from __future__ import annotations

import numpy as np
from music_theory import sequencer

from audio import drums, dsp, grid, voices

NAME = "hub_loop"
SEED = 20261116
# Quarter beats a minute: the toolkit's beat is a quarter, a 6/8 bar holds three.
TEMPO = 138.0
BAR = 3.0
TUNE = grid.Key("D4", "dorian")
LUTE = grid.Key("D3", "dorian")
LOW = grid.Key("D2", "dorian")

_A = (
    "4 7/.5 9 7/.5 | 8/.5 7/.5 6/.5 7 4/.5 | 6 8/.5 10 8/.5 | 7/.5 6/.5 5/.5 6/1.5 | "
    "4 7/.5 9 7/.5 | 10/.5 9/.5 8/.5 7 5/.5 | "
)
_B = (
    "9 11/.5 9 6/.5 | 9/.5 8/.5 7/.5 6 4/.5 | 8 10/.5 8 6/.5 | 8/.5 7/.5 6/.5 3/1.5 | "
    "5 7/.5 10 7/.5 | 10/.5 9/.5 8/.5 7 5/.5 | 8 11/.5 8 6/.5 | 8/.5 7/.5 5/.5 4/1.5"
)
# (tune, chords by degree, tambourine row, second lute a chord tone below the tune)
SECTIONS: tuple[tuple[str, tuple[int, ...], str, bool], ...] = (
    (_A + "6 8/.5 7 6/.5 | 4/1.5 8 4/.5", (1, 1, 7, 7, 1, 4, 7, 5), "......", False),
    (_A + "8 7/.5 6 5/.5 | 7/2 -", (1, 1, 7, 7, 1, 4, 5, 1), "...t..", True),
    (_B, (3, 3, 7, 7, 4, 4, 5, 5), "...t..", False),
    (_A + "8 7/.5 6 5/.5 | 7/2 -", (1, 1, 7, 7, 1, 4, 5, 1), "..t..t", True),
)
RECIPE = {
    "key": "D dorian",
    "tempo_bpm": TEMPO,
    "meter": "6/8",
    "bars": 8 * len(SECTIONS),
    "form": "A A' B A'",
    "seed": SEED,
}
# One bar of lute: root, fifth, octave, tenth, octave, fifth, in eighths.
_ARPEGGIO = ((0, 0, 0.7), (2, 0, 0.45), (0, 12, 0.55), (1, 12, 0.5), (0, 12, 0.5), (2, 0, 0.45))
_DRUM_ROW = "L.hl.h"


def _under(midi: int, chord: tuple[int, ...]) -> int:
    """The chord tone at least a minor third under a tune note: a safe second voice."""
    tones = [note + octave for note in chord for octave in (0, 12, 24)]
    return max(note for note in tones if note <= midi - 3)


def _graces(tune: list[sequencer.NoteEvent], rng: np.random.Generator) -> list[sequencer.NoteEvent]:
    """A quick note from the step above before some long notes: the player showing off."""
    out = []
    for event in tune:
        if event.length_beats >= 1.0 and event.start_beat >= 0.2 and rng.random() < 0.22:
            out.append(sequencer.NoteEvent(TUNE.above(event.midi), event.start_beat - 0.14, 0.14, 0.3))
    return out


def render() -> np.ndarray:
    beats = BAR * 8 * len(SECTIONS)
    mix = grid.Mix(TEMPO, beats, wrap=True, seed=SEED)
    rng = np.random.default_rng([SEED, 1])
    kit = {
        "L": (drums.frame_drum(True), 0.42),
        "l": (drums.frame_drum(True), 0.2),
        "h": (drums.frame_drum(False), 0.26),
    }
    shake = {"t": (drums.tambourine(), 0.25)}
    for index, (text, chords, tambourine, second) in enumerate(SECTIONS):
        if grid.length_of(text) != BAR * 8:
            raise ValueError(f"hub section {index} is {grid.length_of(text)} beats, not {BAR * 8}")
        start = index * BAR * 8
        tune = TUNE.line(text, start, 0.62)
        mix.play(tune, voices.recorder, pan=-0.15, gain=0.5, loose_ms=5.0, accent=0.08)
        mix.play(_graces(tune, rng), voices.recorder, pan=-0.15, gain=0.5)
        for bar, numeral in enumerate(chords):
            at = start + bar * BAR
            chord = LUTE.chord(numeral)
            lute = [
                sequencer.NoteEvent(chord[tone] + lift, at + step * 0.5, 0.5, level)
                for step, (tone, lift, level) in enumerate(_ARPEGGIO)
            ]
            mix.play(lute, voices.pluck, pan=0.3, gain=0.6, loose_ms=6.0, accent=0.1)
            mix.play([sequencer.NoteEvent(LOW.chord(numeral)[0], at, BAR, 1.0)], voices.drone, gain=0.2)
            mix.row(_DRUM_ROW, 0.5, kit, at, pan=0.1)
            mix.row(tambourine, 0.5, shake, at, pan=-0.4)
            if second:
                under = [
                    sequencer.NoteEvent(_under(note.midi, chord), note.start_beat, note.length_beats, 0.4)
                    for note in tune
                    if at <= note.start_beat < at + BAR
                ]
                mix.play(under, voices.pluck, pan=-0.35, gain=0.42, loose_ms=6.0)
    mix.total[:] = dsp.highpass(mix.total, 35.0, wrap=True)
    return dsp.room(mix.total, 1.5, 0.2, SEED, wrap=True)
