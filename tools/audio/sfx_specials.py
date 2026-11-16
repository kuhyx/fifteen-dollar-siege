"""Effects of the buffs: one unmistakable sound per special, played for laughs.

The screen has no words, so each of these has to say what happened on its
own: a blast, a splat, a buzz, a bellow. Everything loud is low-passed: big
is low, not bright.
"""

from __future__ import annotations

import math
from collections.abc import Callable

import numpy as np
from music_theory import pitch

from audio import dsp, guitar, voices
from audio import sfx_kit as kit

D4 = pitch.midi_to_hz(62)
A4 = pitch.midi_to_hz(69)


def shotgun() -> np.ndarray:
    """A flat boom, a thump in the chest, and the shot rolling off the houses."""
    out = kit.Take(1.0)
    out.add(0.0, kit.struck(dsp.lowpass(kit.hiss(0.5, "shot"), 3400.0), 0.07, 0.0008), 1.0)
    out.add(0.0, kit.thump(120.0, 42.0, 0.11, 0.03), 0.9)
    out.add(0.06, kit.struck(dsp.lowpass(kit.hiss(0.9, "shotecho"), 1100.0), 0.3, 0.02), 0.35)
    return out.mix


def catapult() -> np.ndarray:
    """The arm creaks back, cracks against the stop, and the pumpkin leaves."""
    out = kit.Take(0.95)
    creak = kit.tone((70.0, 105.0), 0.26, 14, 1.0, 2400.0) * (0.3 + 0.7 * kit.grains(0.26, "creak", 60.0, 0.006))
    out.add(0.0, kit.swell(creak, 0.02, 0.03), 0.5)
    out.add(0.26, kit.ping(190.0, 0.05, ((1.0, 1.0), (2.3, 0.5), (3.9, 0.2))), 1.0)
    out.add(0.26, kit.thump(140.0, 60.0, 0.07, 0.03), 0.9)
    out.add(0.3, kit.swell(kit.sweep((320.0, 1300.0), 0.5, "fling", 2.2), 0.05, 0.4), 0.6)
    return out.mix


def splat() -> np.ndarray:
    """Pumpkin meets village: a wet squelch, a thud, and two drips."""
    out = kit.Take(0.75)
    for late, name in ((0.0, "splat1"), (0.04, "splat2")):
        out.add(late, kit.swell(kit.sweep((1700.0, 320.0), 0.2, name, 4.0), 0.004, 0.12), 0.9)
    out.add(0.0, kit.thump(125.0, 52.0, 0.09, 0.03), 0.8)
    for late, hz in ((0.3, 520.0), (0.46, 410.0)):
        out.add(late, kit.struck(kit.tone((hz, hz * 0.6), 0.07), 0.02), 0.35)
    return out.mix


def heal() -> np.ndarray:
    """The medics at work: four soft chimes going up the D major chord."""
    out = kit.Take(1.3)
    for index, midi in enumerate((74, 78, 81, 86)):
        out.add(index * 0.075, kit.ping(pitch.midi_to_hz(midi), 0.16, ((1.0, 1.0), (2.0, 0.2))), 0.8 - index * 0.08)
    return out.mix


def wasps() -> np.ndarray:
    """A swarm: wingbeat tones a little apart, fluttering, sweeping past."""
    seconds = 1.35
    count = dsp.frames(seconds)
    swarm = np.zeros(count)
    for hz, flutter in ((188.0, 21.0), (207.0, 24.0), (233.0, 19.0)):
        wings = kit.tone((hz * 0.94, hz * 1.06, hz), seconds, 16, 1.0, 3400.0, wobble=(0.5, 11.0))
        swarm += wings * (0.65 + 0.35 * np.sin(2.0 * math.pi * flutter * dsp.times(count)))
    passing = dsp.sweep_bandpass(swarm, dsp.glide((700.0, 1700.0, 900.0), count), 1.2)
    return kit.swell(passing + 0.35 * swarm, 0.25, 0.5)


def moose() -> np.ndarray:
    """A bellow through a long nose, then hooves."""
    out = kit.Take(1.3)
    bellow = kit.tone((92.0, 150.0, 138.0, 84.0), 0.8, 14, 1.0, 3000.0, wobble=(0.3, 5.0))
    nose = dsp.bandpass(bellow, 460.0, 2.0) + 0.5 * dsp.bandpass(bellow, 950.0, 3.0) + 0.3 * bellow
    out.add(0.0, kit.swell(nose, 0.09, 0.25), 1.0)
    for late in (0.62, 0.76, 0.9, 1.04):
        out.add(late, kit.thump(110.0, 55.0, 0.05, 0.02), 0.6)
    return out.mix


def cart_crash() -> np.ndarray:
    """A golf cart: "meep meep", then it hits something."""
    out = kit.Take(1.25)
    for late in (0.0, 0.13):
        meep = kit.tone((440.0,), 0.09, 7, 1.0, 3000.0, odd=True) + kit.tone((349.2,), 0.09, 7, 1.0, 3000.0, odd=True)
        out.add(late, kit.swell(meep, 0.004, 0.02), 0.4)
    out.add(0.3, kit.struck(kit.band(0.4, "crash", 1200.0, 0.7), 0.07, 0.001), 1.0)
    out.add(0.3, kit.ping(523.0, 0.2, ((1.0, 1.0), (2.27, 0.6), (3.31, 0.3))), 0.6)
    out.add(0.3, kit.thump(130.0, 50.0, 0.09), 0.8)
    rattle = kit.band(0.6, "rattle", 2100.0, 1.2) * kit.grains(0.6, "rattlegate", 34.0, 0.004)
    out.add(0.38, rattle * np.linspace(1.0, 0.0, len(rattle)), 0.6)
    return out.mix


def smash() -> np.ndarray:
    """The monster's fist: the ground gives, and it growls."""
    out = kit.Take(1.1)
    out.add(0.0, kit.thump(98.0, 44.0, 0.22, 0.08), 1.0)
    out.add(0.0, kit.struck(dsp.lowpass(kit.hiss(0.6, "smash"), 520.0), 0.16, 0.002), 0.9)
    growl = kit.tone((58.0, 50.0), 0.6, 12, 1.0, 900.0) * (
        0.55 + 0.45 * np.sin(2.0 * math.pi * 27.0 * dsp.times(dsp.frames(0.6)))
    )
    out.add(0.18, kit.swell(growl, 0.06, 0.3), 0.6)
    return out.mix


def trumpet() -> np.ndarray:
    """The boy's fanfare: two quick notes, a leap, and the top note cracks."""
    out = kit.Take(1.0)
    out.add(0.0, voices.horn(D4, 0.1))
    out.add(0.13, voices.horn(D4, 0.1))
    cracked = kit.tone((A4 * 1.07, A4 * 1.07, A4 * 0.975, A4 * 0.975), 0.42, 10, 1.0, 3400.0, wobble=(0.25, 6.5))
    out.add(0.27, kit.swell(cracked, 0.02, 0.12), 0.9)
    return out.mix


def guitar_stab() -> np.ndarray:
    """The band strikes up: one distorted low D chord."""
    return guitar.power(38, 0.55)


def reveal() -> np.ndarray:
    """The potion wears off: a pop upward and three falling sparkles."""
    out = kit.Take(0.6)
    out.add(0.0, kit.swell(kit.tone((380.0, 1400.0), 0.09), 0.003, 0.03), 0.9)
    for index, hz in enumerate((1568.0, 1318.5, 1046.5)):
        out.add(0.09 + index * 0.06, kit.ping(hz, 0.07, ((1.0, 1.0), (2.0, 0.15))), 0.5)
    return out.mix


def ufo() -> np.ndarray:
    """A saucer takes someone: a wavering rise, a throbbing beam, and it zips away."""
    out = kit.Take(1.5)
    hover = kit.tone((320.0, 760.0), 1.05, 2, 2.0, wobble=(0.45, 6.0))
    out.add(0.0, kit.swell(hover, 0.12, 0.1), 0.8)
    beam = kit.tone((180.0, 260.0), 1.05, 5, 1.2) * (
        0.5 + 0.5 * np.sin(2.0 * math.pi * 18.0 * dsp.times(dsp.frames(1.05)))
    )
    out.add(0.0, kit.swell(beam, 0.2, 0.15), 0.5)
    out.add(1.05, kit.swell(kit.tone((760.0, 2200.0), 0.14), 0.005, 0.06), 0.6)
    return out.mix


def _mumble(hz: float, seconds: float, name: str) -> np.ndarray:
    """One syllable of a gruff voice: a buzz through a mouth that opens and shuts ("mwah")."""
    buzz = kit.tone((hz * 0.94, hz * 1.08, hz * 0.9), seconds, 30, 1.0, 3600.0)
    count = len(buzz)
    mouth = dsp.sweep_bandpass(buzz, dsp.glide((340.0, 950.0, 420.0), count), 3.5)
    air = dsp.bandpass(kit.hiss(seconds, name), 2300.0, 4.0) * 0.04
    return kit.swell(mouth + 0.25 * dsp.bandpass(buzz, 2300.0, 5.0) + air, 0.03, 0.05)


def pep_talk() -> np.ndarray:
    """The pep talk: three gruff syllables, one big one, and the men grunt back."""
    out = kit.Take(1.65)
    for late, hz, seconds in ((0.0, 108.0, 0.15), (0.2, 100.0, 0.14), (0.38, 112.0, 0.16), (0.62, 132.0, 0.4)):
        out.add(late, _mumble(hz, seconds, f"pep{late}"), 0.9 if seconds < 0.3 else 1.1)
    source = kit.rng("pepmen")
    for voice in range(9):
        hz = float(source.uniform(95.0, 150.0))
        grunt = kit.tone((hz * 1.1, hz * 0.85), 0.3, 22, 1.0, 3600.0)
        vowel = dsp.bandpass(grunt, 620.0, 3.0) + 0.6 * dsp.bandpass(grunt, 1050.0, 4.0)
        out.add(1.14 + float(source.uniform(0.0, 0.05)), kit.swell(vowel, 0.02, 0.2), 0.4)
    return out.mix


SOUNDS: dict[str, tuple[Callable[[], np.ndarray], float]] = {
    "shotgun": (shotgun, -14.5),
    "catapult": (catapult, -18.0),
    "splat": (splat, -17.0),
    "heal": (heal, -20.0),
    "wasps": (wasps, -18.0),
    "moose": (moose, -16.5),
    "cart_crash": (cart_crash, -16.0),
    "smash": (smash, -15.0),
    "trumpet": (trumpet, -17.0),
    "guitar_stab": (guitar_stab, -15.5),
    "reveal": (reveal, -19.0),
    "ufo": (ufo, -18.0),
    "pep_talk": (pep_talk, -17.0),
}
