"""Effects of the fight itself: missiles, clubs, squads breaking, orders, the bell, the endings.

Pitched effects sit on D and A, the battle bed's tonic and fifth, so a horn
call or the bell never fights the music. The repeated ones (sling, arrow,
club) come in several takes; the game picks one and shifts its pitch.
"""

from __future__ import annotations

from collections.abc import Callable
from functools import partial

import numpy as np
from music_theory import pitch

from audio import drums, dsp, voices
from audio import sfx_kit as kit

D4 = pitch.midi_to_hz(62)
A3 = pitch.midi_to_hz(57)
A4 = pitch.midi_to_hz(69)


def sling(take: int) -> np.ndarray:
    """The sling whirls up and lets go: a rising whoosh, then the snap of the release."""
    speed = (0.9, 1.0, 1.12)[take]
    name = f"sling{take}"
    out = kit.Take(0.32)
    whirl = kit.swell(
        dsp.lowpass(kit.sweep((450.0 * speed, 2100.0 * speed), 0.2, name, 3.0), 2600.0, poles=2), 0.12, 0.05
    )
    out.add(0.0, whirl, 0.8)
    out.add(
        0.17,
        kit.struck(dsp.lowpass(kit.band(0.1, name + "snap", 1500.0 * speed, 1.5), 3000.0, poles=2), 0.012, 0.001),
        1.0,
    )
    return out.mix


def arrow(take: int) -> np.ndarray:
    """A bowstring's thrum and the hiss of the shaft."""
    speed = (1.0, 1.1)[take]
    name = f"arrow{take}"
    out = kit.Take(0.5)
    out.add(0.0, kit.struck(kit.tone((230.0 * speed, 170.0 * speed), 0.2, 6, 1.2), 0.05), 0.9)
    out.add(
        0.02,
        kit.swell(dsp.lowpass(kit.sweep((2500.0, 800.0 * speed), 0.4, name, 2.5), 3400.0, poles=2), 0.03, 0.3),
        0.7,
    )
    return out.mix


def club(take: int) -> np.ndarray:
    """Wood on wood (or on a helmet): a knock with a body under it."""
    hz = (300.0, 360.0, 430.0)[take]
    out = kit.Take(0.3)
    out.add(0.0, kit.ping(hz, 0.035, ((1.0, 1.0), (2.3, 0.5), (3.9, 0.25))), 1.0)
    out.add(0.0, kit.struck(dsp.lowpass(kit.hiss(0.2, f"club{take}"), 520.0), 0.03), 0.9)
    out.add(0.0, kit.thump(150.0, 80.0, 0.04, 0.02), 0.6)
    return out.mix


def rout() -> np.ndarray:
    """A squad runs: the slide whistle goes down and feet patter away."""
    out = kit.Take(0.85)
    whistle = kit.tone((1300.0, 1150.0, 480.0), 0.65, 3, 2.2, wobble=(0.35, 9.0))
    out.add(0.0, kit.swell(whistle, 0.02, 0.2), 0.9)
    feet = dsp.lowpass(kit.hiss(0.8, "rout"), 700.0) * kit.grains(0.8, "routfeet", 16.0, 0.02)
    out.add(0.05, feet * np.linspace(1.0, 0.2, len(feet)), 0.7)
    return out.mix


def _call(notes: tuple[tuple[float, float], ...], gap_s: float = 0.0) -> np.ndarray:
    """A horn phrase: (Hz, seconds) one after another."""
    total = sum(seconds + gap_s for _, seconds in notes) + 0.25
    out = kit.Take(total)
    at = 0.0
    for hz, seconds in notes:
        out.add(at, voices.horn(hz, seconds))
        at += seconds + gap_s
    return out.mix


def wiped() -> np.ndarray:
    """A squad is gone: a thud and a tone that sinks after it."""
    out = kit.Take(0.8)
    out.add(0.0, kit.thump(95.0, 44.0, 0.16), 1.0)
    sink = dsp.lowpass(kit.tone((220.0, 70.0), 0.6, 8, 1.0), 900.0)
    out.add(0.02, kit.swell(sink, 0.01, 0.4), 0.6)
    return out.mix


def alarm() -> np.ndarray:
    """The village notices: two horns a semitone apart lurch upward, and a gasp of air."""
    out = kit.Take(0.8)
    for start, end in ((A3, D4), (A3 * 1.06, D4 * 1.06)):
        smear = kit.tone((start, end, end), 0.55, 9, 1.1, 3200.0, wobble=(0.2, 7.0))
        out.add(0.0, kit.swell(smear, 0.04, 0.2), 0.6)
    out.add(0.0, kit.swell(kit.sweep((500.0, 1800.0), 0.3, "alarm", 2.0), 0.15, 0.1), 0.35)
    out.add(0.0, drums.field_snare(), 0.5)
    return out.mix


def centre_tick() -> np.ndarray:
    """One more stretch of the centre held: a kettle drum with a small bell on top."""
    out = kit.Take(0.9)
    out.add(0.0, drums.timpani(pitch.midi_to_hz(50))[: dsp.frames(0.85)], 1.0)
    out.add(0.0, kit.ping(D4 * 2.0, 0.12), 0.3)
    return out.mix


def cheer() -> np.ndarray:
    """A crowd's "aaah!": many rough voices through the two formants of that vowel."""
    seconds = 1.7
    out = kit.Take(seconds)
    source = kit.rng("cheer")
    for voice in range(16):
        hz = float(source.uniform(105.0, 230.0))
        late = float(source.uniform(0.0, 0.22))
        length = float(source.uniform(0.9, 1.4))
        sung = kit.tone(
            (hz, hz * 1.25, hz * 1.1), length, 24, 1.0, 4200.0, wobble=(0.4, float(source.uniform(4.0, 7.0)))
        )
        vowel = (
            dsp.bandpass(sung, 760.0, 3.0)
            + 0.7 * dsp.bandpass(sung, 1180.0, 4.0)
            + 0.2 * dsp.bandpass(sung, 2600.0, 5.0)
        )
        out.add(late, kit.swell(vowel, 0.12, 0.5), 0.5)
    breath = dsp.bandpass(kit.hiss(seconds, "cheerair"), 900.0, 0.8)
    out.add(0.0, kit.swell(breath, 0.2, 0.9), 0.5)
    return out.mix


def combust() -> np.ndarray:
    """The army goes up: a whoomp of flame opening, a thump under it, then crackle."""
    seconds = 1.9
    out = kit.Take(seconds)
    flame = dsp.lowpass(kit.sweep((260.0, 1500.0, 900.0), 1.5, "flame", 0.7), 2800.0, poles=2)
    out.add(0.0, kit.swell(flame, 0.14, 1.1), 1.0)
    out.add(0.05, kit.thump(88.0, 48.0, 0.22), 0.9)
    crackle = dsp.lowpass(kit.band(1.6, "crackle", 1700.0, 0.8), 3600.0, poles=2) * kit.grains(
        1.6, "cracklegate", 26.0, 0.003
    )
    out.add(0.25, crackle * np.linspace(1.0, 0.1, len(crackle)), 0.8)
    return out.mix


def bell() -> np.ndarray:
    return voices.bell(D4, 2.6)


SOUNDS: dict[str, tuple[Callable[[], np.ndarray], float]] = {
    "sling_1": (partial(sling, 0), -21.0),
    "sling_2": (partial(sling, 1), -21.0),
    "sling_3": (partial(sling, 2), -21.0),
    "arrow_1": (partial(arrow, 0), -21.0),
    "arrow_2": (partial(arrow, 1), -21.0),
    "club_1": (partial(club, 0), -20.0),
    "club_2": (partial(club, 1), -20.0),
    "club_3": (partial(club, 2), -20.0),
    "rout": (rout, -19.0),
    "rally": (partial(_call, ((A3, 0.11), (D4, 0.34)), 0.02), -18.0),
    "wiped": (wiped, -17.0),
    "command_rally": (partial(_call, ((D4, 0.12), (D4, 0.22)), 0.06), -18.0),
    "command_charge": (partial(_call, ((D4, 0.1), (A4, 0.45)), 0.02), -17.0),
    "command_retreat": (partial(_call, ((A4, 0.2), (D4, 0.45)), 0.03), -18.0),
    "alarm": (alarm, -15.0),
    "bell": (bell, -17.0),
    "centre_tick": (centre_tick, -18.0),
    "cheer": (cheer, -16.0),
    "combust": (combust, -15.0),
}
