"""The battle bed: four stems of one piece, mixed by the game as the siege turns.

  battle_base   the sneak: tip-toe pizzicato, a held pad, a heartbeat drum.
                Always on. This is what "the village sleeps" sounds like.
  battle_alarm  war drums and an eighth-note ostinato. Level follows `alarm`.
  battle_hope   a horn tune and kettle drums. Rises as VILLAGE morale falls.
  battle_dread  shaking low strings, falling sighs, a lament bass. Rises as
                ARMY morale falls.

All four share key, tempo, chords and length (D minor, 120, 16 bars, 32.0 s
exactly), so any mix of them is one piece getting louder or darker: the
cookbook's "render the same piece several ways and crossfade in the game".
The hub is D dorian; the battle flattens one scale step (B -> B flat) and
the mood turns: the article's "one array element is the entire difference".
Reference for the quality bar: Stronghold's siege cues ("Sword Play").
"""

from __future__ import annotations

from collections.abc import Callable

import numpy as np
from music_theory import pitch, sequencer

from audio import drums, dsp, grid, voices

SEED = 20261117
TEMPO = 120.0
BAR = 4.0
CHORDS = (1, 1, 7, 7, 1, 1, 6, 7, 1, 1, 4, 4, 6, 7, 1, 1)
BEATS = BAR * len(CHORDS)
LOW = grid.Key("D2", "minor")
MID = grid.Key("D3", "minor")
HIGH = grid.Key("D4", "minor")
RECIPE = {"key": "D minor", "tempo_bpm": TEMPO, "meter": "4/4", "bars": len(CHORDS), "seed": SEED}

_HORN_TUNE = (
    "4/2 7/2 | 9/3 7 | 8/2 6/2 | 10/3 8 | 4/2 7/2 | 9/3 11 | 12/2 11 9 | 10/2 8/2 | "
    "9/2 7/2 | 11/3 9 | 10/2 12/2 | 14/3 12 | 12/2 11 9 | 10/2 8/2 | 7/4 | 7/2 -/2"
)
# A falling step over each chord (in MID degrees): the note above a chord tone, then the tone.
_SIGHS = {1: "12/2.5 11/1.5", 7: "9/2.5 8/1.5", 6: "10/2.5 9/1.5", 4: "13/2.5 12/1.5"}
# D C B-flat A, a bar each: the lament bass, four times.
_LAMENT = "7/4 6/4 5/4 4/4 " * 4
_OSTINATO = ((0, 0.7), (0, 0.45), (2, 0.55), (0, 0.45), (1, 0.6), (0, 0.45), (2, 0.55), (0, 0.45))
_WAR_ROW = "T..T..T.T..T..T."
_FILL_ROW = "T..T..T.hhmmllTT"


def _notes(pairs: list[tuple[int, float, float, float]]) -> list[sequencer.NoteEvent]:
    return [sequencer.NoteEvent(midi, beat, length, level) for midi, beat, length, level in pairs]


def _finish(mix: grid.Mix, wet: float) -> np.ndarray:
    mix.total[:] = dsp.highpass(mix.total, 42.0, poles=2, wrap=True)
    return dsp.room(mix.total, 1.8, wet, SEED, wrap=True)


def base() -> np.ndarray:
    mix = grid.Mix(TEMPO, BEATS, wrap=True, seed=SEED)
    rng = np.random.default_rng([SEED, 2])
    heart = {"L": (drums.frame_drum(True), 0.34), "l": (drums.frame_drum(True), 0.2)}
    for bar, numeral in enumerate(CHORDS):
        at = bar * BAR
        root, third, fifth = MID.chord(numeral)
        tiptoe = [
            (root, at, 1.0, 0.8),
            (fifth, at + 1, 1.0, 0.5),
            (root + 12, at + 2, 1.0, 0.6),
            (fifth, at + 3, 0.5, 0.5),
        ]
        if bar % 2:
            tiptoe.append((fifth - 12, at + 3.5, 0.5, 0.35))
        mix.play(_notes(tiptoe), voices.pizz, pan=-0.2, gain=0.9, loose_ms=4.0, accent=0.08)
        low_root, _, low_fifth = LOW.chord(numeral)
        mix.play(_notes([(low_root + 12, at, BAR, 1.0), (low_fifth + 12, at, BAR, 0.6)]), voices.strings, gain=0.16)
        mix.row("L.l.....L.l.....", 0.25, heart, at, pan=0.1)
        if bar % 4 == 2:  # a curious little question from up high, every fourth bar
            picks = rng.choice((root, third, fifth), 4)
            mix.play(
                _notes([(int(n) + 24, at + 2 + i * 0.5, 0.5, 0.5) for i, n in enumerate(picks)]),
                voices.pizz,
                pan=0.4,
                gain=0.3,
            )
    return _finish(mix, 0.25)


def alarm() -> np.ndarray:
    mix = grid.Mix(TEMPO, BEATS, wrap=True, seed=SEED + 1)
    war = {
        "T": (drums.taiko(), 0.8),
        "h": (drums.tom(190.0), 0.5),
        "m": (drums.tom(140.0), 0.55),
        "l": (drums.tom(100.0), 0.6),
    }
    side = {"S": (drums.field_snare(), 0.7), "s": (drums.field_snare(), 0.22)}
    shake = {"t": (drums.tambourine(), 0.3), "T": (drums.tambourine(), 0.5)}
    for bar, numeral in enumerate(CHORDS):
        at = bar * BAR
        mix.row(_FILL_ROW if bar % 4 == 3 else _WAR_ROW, 0.25, war, at)
        mix.row("....S..s....S..s", 0.25, side, at, pan=0.25)
        mix.row("T.t.T.t.T.t.T.t.", 0.25, shake, at, pan=-0.4)
        chord = MID.chord(numeral)
        ostinato = [(chord[tone], at + step * 0.5, 0.5, level) for step, (tone, level) in enumerate(_OSTINATO)]
        mix.play(_notes(ostinato), voices.staccato, pan=0.3, gain=0.62, loose_ms=3.0, accent=0.06)
    return _finish(mix, 0.18)


def _under(midi: int, chord: tuple[int, ...]) -> int:
    tones = [note + octave for note in chord for octave in (-12, 0, 12, 24)]
    return max(note for note in tones if note <= midi - 3)


def hope() -> np.ndarray:
    mix = grid.Mix(TEMPO, BEATS, wrap=True, seed=SEED + 2)
    tune = MID.line(_HORN_TUNE, 0.0, 0.7)
    mix.play(tune, voices.horn, pan=-0.2, gain=0.55, loose_ms=4.0)
    second = [
        sequencer.NoteEvent(
            _under(note.midi, MID.chord(CHORDS[int(note.start_beat // BAR)])), note.start_beat, note.length_beats, 0.5
        )
        for note in tune
        if note.length_beats >= 2.0
    ]
    mix.play(second, voices.horn, pan=0.3, gain=0.4, loose_ms=4.0)
    shake = {"t": (drums.tambourine(), 0.28)}
    for bar, numeral in enumerate(CHORDS):
        at = bar * BAR
        kettle = drums.timpani(pitch.midi_to_hz(LOW.chord(numeral)[0] + 12))
        mix.hit(at, kettle, pan=0.15, gain=0.5)
        if bar % 2:
            mix.hit(at + 3.5, kettle, pan=0.15, gain=0.3)
        mix.row("t...t...t...t...", 0.25, shake, at, pan=-0.35)
    return _finish(mix, 0.28)


def dread() -> np.ndarray:
    mix = grid.Mix(TEMPO, BEATS, wrap=True, seed=SEED + 3)
    mix.play(LOW.line(_LAMENT, 0.0, 0.8), voices.strings, pan=0.1, gain=0.42)
    for bar, numeral in enumerate(CHORDS):
        at = bar * BAR
        root, _, fifth = LOW.chord(numeral)
        mix.play(_notes([(root + 12, at, BAR, 0.9), (fifth + 12, at, BAR, 0.55)]), voices.tremolo, pan=-0.15, gain=0.34)
        if bar % 2 == 0:
            mix.play(MID.line(_SIGHS[numeral], at, 0.7), voices.strings, pan=0.3, gain=0.4, loose_ms=5.0)
        mix.hit(at, drums.timpani(pitch.midi_to_hz(LOW.note(0))), pan=-0.1, gain=0.55)
        if bar % 2:
            mix.hit(at + 3.5, drums.timpani(pitch.midi_to_hz(LOW.note(0))), pan=-0.1, gain=0.3)
    return _finish(mix, 0.3)


STEMS: dict[str, Callable[[], np.ndarray]] = {
    "battle_base": base,
    "battle_alarm": alarm,
    "battle_hope": hope,
    "battle_dread": dread,
}
