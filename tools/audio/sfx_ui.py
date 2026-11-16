"""Menu sounds: short, soft and physical (coins, wood, a lute string).

The shop is a tray of coins, so buying is coins landing on a card and
selling is coins coming back. A refusal is low and dull, never a buzzer:
the tray already shakes and turns red.
"""

from __future__ import annotations

from collections.abc import Callable

import numpy as np
from music_theory import pitch

from audio import drums, dsp, voices
from audio import sfx_kit as kit

_COIN = ((1.0, 1.0), (2.76, 0.3))


def _coins(pitches: tuple[float, ...], gap_s: float) -> np.ndarray:
    out = kit.Take(len(pitches) * gap_s + 0.45)
    for index, hz in enumerate(pitches):
        out.add(index * gap_s, kit.ping(hz, 0.07, _COIN), 1.0 - 0.1 * index)
        out.add(index * gap_s, kit.struck(kit.band(0.05, f"coin{index}", 2400.0, 2.0), 0.004, 0.0005), 0.25)
    return out.mix


def buy() -> np.ndarray:
    """Coins land on the card, each a little higher."""
    return _coins((1050.0, 1250.0, 1480.0), 0.055)


def unbuy() -> np.ndarray:
    """Coins come back to the tray, each a little lower."""
    return _coins((1250.0, 1050.0, 880.0), 0.06)


def refuse() -> np.ndarray:
    """Not enough coins: two dull knocks, the second a semitone lower."""
    out = kit.Take(0.42)
    for late, midi, seconds in ((0.0, 50, 0.09), (0.13, 49, 0.16)):
        knock = dsp.lowpass(kit.tone((pitch.midi_to_hz(midi),), seconds, 9, 1.0, 1400.0, odd=True), 1000.0)
        out.add(late, kit.swell(knock, 0.004, 0.05), 1.0)
    return out.mix


def go() -> np.ndarray:
    """The siege begins: a war drum and a horn rising a fourth."""
    out = kit.Take(0.95)
    out.add(0.0, drums.taiko()[: dsp.frames(0.7)], 0.9)
    rise = kit.tone((220.0, 220.0, 293.7, 293.7), 0.6, 9, 1.2, 3000.0)
    out.add(0.03, kit.swell(rise, 0.06, 0.2), 0.7)
    return out.mix


def button() -> np.ndarray:
    """A wooden click."""
    out = kit.Take(0.16)
    out.add(0.0, drums.woodblock(620.0), 1.0)
    out.add(0.0, kit.thump(170.0, 110.0, 0.02, 0.01), 0.4)
    return out.mix


def mode() -> np.ndarray:
    """Picking a mode: a lute strummed up the open fifth."""
    out = kit.Take(1.2)
    for index, midi in enumerate((62, 69, 74)):
        out.add(index * 0.028, voices.pluck(pitch.midi_to_hz(midi), 0.5), 1.0 - 0.12 * index)
    return out.mix


def _blips(first: float, second: float) -> np.ndarray:
    out = kit.Take(0.3)
    for late, hz in ((0.0, first), (0.075, second)):
        out.add(late, kit.swell(kit.tone((hz,), 0.075, 3, 2.0), 0.006, 0.04), 1.0)
    return out.mix


def pause() -> np.ndarray:
    """The world stops: two soft notes down."""
    return _blips(587.3, 440.0)


def resume() -> np.ndarray:
    """And starts again: the same two notes up."""
    return _blips(440.0, 587.3)


def lab_tick() -> np.ndarray:
    """One more siege counted in the Lab."""
    return drums.woodblock(980.0)[: dsp.frames(0.07)]


def lab_done() -> np.ndarray:
    """The batch is in: two small bells, a fourth apart."""
    out = kit.Take(0.95)
    out.add(0.0, kit.ping(880.0, 0.13, ((1.0, 1.0), (2.0, 0.25), (3.0, 0.1))), 1.0)
    out.add(0.14, kit.ping(1174.7, 0.16, ((1.0, 1.0), (2.0, 0.25), (3.0, 0.1))), 0.9)
    return out.mix


SOUNDS: dict[str, tuple[Callable[[], np.ndarray], float]] = {
    "ui_buy": (buy, -21.0),
    "ui_unbuy": (unbuy, -22.0),
    "ui_refuse": (refuse, -20.0),
    "ui_go": (go, -17.5),
    "ui_button": (button, -24.0),
    "ui_mode": (mode, -20.0),
    "ui_pause": (pause, -23.0),
    "ui_resume": (resume, -23.0),
    "ui_lab_tick": (lab_tick, -27.0),
    "ui_lab_done": (lab_done, -20.0),
}
