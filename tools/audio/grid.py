"""Written parts on the music_theory beat grid, mixed to a stereo buffer.

Theory comes from the toolkit: a key is a root plus a step pattern
(`scales`), a note is a scale degree in it, a chord is `progressions`'
stacked thirds, time is `sequencer`'s beat grid and `NoteEvent`. This module
adds what a piece with several instruments needs: a one-line notation for a
part, drum rows, and a mix buffer that wraps note tails round the end so a
loop closes on itself.

Notation of `Key.line`: tokens split by spaces, `|` is decoration.
  `4`      scale degree 4 (0 = the tonic, 7 = an octave up, -1 = a step below)
  `4/.5`   the same for half a beat (default length: one beat)
  `-/2`    a two-beat rest
  `4+9`    two degrees at once
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

import numpy as np
from music_theory import pitch, progressions, scales, sequencer

from audio import dsp

type Voice = Callable[[float, float], np.ndarray]


@dataclass(frozen=True)
class Key:
    """A tonic (with its octave) and a mode: where degree 0 sits and what the steps are."""

    tonic: str
    mode: str

    @property
    def root(self) -> int:
        return pitch.parse_note(self.tonic)

    def note(self, degree: int) -> int:
        return scales.pitch_at_degree(self.root, scales.pattern_named(self.mode), degree)

    def chord(self, numeral: int) -> tuple[int, ...]:
        """MIDI notes of the triad on a 1-based degree (1 = the tonic chord).

        A chord whose root would sit a fifth or more above the tonic is
        taken an octave down, so a progression stays in one register.
        """
        found = progressions.chords_for(self.root, scales.pattern_named(self.mode), (numeral,))
        notes = tuple(found[0].notes)
        drop = 12 if notes[0] - self.root >= 7 else 0
        return tuple(note - drop for note in notes)

    def above(self, midi: int) -> int:
        """The next scale note over `midi` (a grace note's pitch)."""
        pattern = scales.pattern_named(self.mode)
        return next(note for note in (midi + 1, midi + 2, midi + 3) if scales.is_in_scale(self.root, pattern, note))

    def line(self, text: str, start_beat: float = 0.0, velocity: float = 0.6) -> list[sequencer.NoteEvent]:
        """Notes of a written part (see the module docstring), laid end to end."""
        events: list[sequencer.NoteEvent] = []
        beat = start_beat
        for token in text.replace("|", " ").split():
            name, _, length_text = token.partition("/")
            length = float(length_text) if length_text else 1.0
            if name != "-":
                for degree in name.split("+"):
                    events.append(sequencer.NoteEvent(self.note(int(degree)), beat, length, velocity))
            beat += length
        return events


def length_of(text: str) -> float:
    """Beats a written part lasts: a bar that does not add up shifts every later note."""
    total = 0.0
    for token in text.replace("|", " ").split():
        total += float(token.partition("/")[2] or 1.0)
    return total


def steps(row: str, step_beats: float, start_beat: float = 0.0) -> list[tuple[float, str]]:
    """Drum row `x..x..o.`: one character per step, `.` silent. Returns (beat, character)."""
    cells = row.replace("|", "").replace(" ", "")
    return [(start_beat + index * step_beats, cell) for index, cell in enumerate(cells) if cell != "."]


@dataclass
class Mix:
    """A stereo buffer on the beat grid. `wrap` folds tails back to the start (a loop)."""

    tempo_bpm: float
    beats: float
    wrap: bool = True
    seed: int = 0
    total: np.ndarray = field(init=False)
    _rng: np.random.Generator = field(init=False)
    _cache: dict[tuple[Voice, float, float], np.ndarray] = field(init=False, default_factory=dict)

    def __post_init__(self) -> None:
        self.total = np.zeros((sequencer.loop_frames(self.tempo_bpm, self.beats, dsp.SR), 2))
        self._rng = np.random.default_rng(self.seed)

    def frame_at(self, beat: float) -> int:
        return sequencer.loop_frames(self.tempo_bpm, beat, dsp.SR)

    def play(
        self,
        events: list[sequencer.NoteEvent],
        voice: Voice,
        pan: float = 0.0,
        gain: float = 1.0,
        loose_ms: float = 0.0,
        accent: float = 0.0,
    ) -> None:
        """Renders each note with `voice(hz, seconds)`.

        `loose_ms` is a player's timing spread, `accent` a random velocity
        spread (both seeded): a grid played exactly sounds like a machine.
        """
        beat_s = sequencer.beat_seconds(self.tempo_bpm)
        for event in events:
            seconds = event.length_beats * beat_s
            key = (voice, float(event.midi), round(seconds, 5))
            if key not in self._cache:
                self._cache[key] = voice(pitch.midi_to_hz(event.midi), seconds)
            late = self._rng.normal(0.0, loose_ms / 1000.0) if loose_ms else 0.0
            level = gain * event.velocity * (1.0 + accent * self._rng.uniform(-1.0, 1.0))
            start = self.frame_at(event.start_beat) + dsp.frames(abs(late))
            dsp.place(self.total, start, dsp.pan(self._cache[key] * level, pan), self.wrap)

    def hit(self, beat: float, sound: np.ndarray, pan: float = 0.0, gain: float = 1.0) -> None:
        dsp.place(self.total, self.frame_at(beat), dsp.pan(sound * gain, pan), self.wrap)

    def row(
        self,
        text: str,
        step_beats: float,
        kit: dict[str, tuple[np.ndarray, float]],
        start_beat: float = 0.0,
        pan: float = 0.0,
    ) -> None:
        """A drum row: `kit` maps a character to (sound, gain)."""
        for beat, cell in steps(text, step_beats, start_beat):
            sound, gain = kit[cell]
            self.hit(beat, sound, pan, gain * (1.0 + 0.06 * self._rng.uniform(-1.0, 1.0)))
