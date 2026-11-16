"""Small rewards and surprises: a tally bell, a heartbeat, a glint, a dice roll.

Each one is short and answers something the player SEES: the bell rings with
the number that pops over the army, the heartbeat with the red edge of the
screen, the glint with a twinkle on a knight's armour. They sit well under
the battle's own sounds, so they decorate it and never cover it.
"""

from __future__ import annotations

from collections.abc import Callable

import numpy as np

from audio import drums, dsp
from audio import sfx_kit as kit

_BELL = ((1.0, 1.0), (2.0, 0.3), (3.01, 0.12))


def toll() -> np.ndarray:
    """A bright bell, a fifth above its twin: another hundred have fallen."""
    out = kit.Take(1.0)
    out.add(0.0, kit.ping(1318.5, 0.2, _BELL), 1.0)
    out.add(0.07, kit.ping(1975.5, 0.14, _BELL), 0.6)
    return out.mix


def heartbeat() -> np.ndarray:
    """Lub, dub: the last men are afraid."""
    out = kit.Take(0.6)
    out.add(0.0, kit.thump(78.0, 46.0, 0.07, 0.04), 1.0)
    out.add(0.17, kit.thump(66.0, 42.0, 0.08, 0.04), 0.7)
    return out.mix


def glint() -> np.ndarray:
    """A twinkle off polished steel."""
    out = kit.Take(0.4)
    out.add(0.0, kit.ping(2637.0, 0.05, ((1.0, 1.0), (1.5, 0.35))), 1.0)
    out.add(0.05, kit.ping(3520.0, 0.045, ((1.0, 1.0), (1.5, 0.3))), 0.5)
    return out.mix


def dice() -> np.ndarray:
    """A rattle of dice in a cup, then two of them land."""
    out = kit.Take(0.8)
    rattle = kit.band(0.42, "dice rattle", 1900.0, 1.4) * kit.grains(0.42, "dice grains", 70.0, 0.003)
    out.add(0.0, kit.swell(rattle, 0.02, 0.1), 1.2)
    out.add(0.43, drums.woodblock(430.0), 0.8)
    out.add(0.53, drums.woodblock(560.0), 0.6)
    return out.mix


def star() -> np.ndarray:
    """A star lands: a small bell and a shimmer."""
    out = kit.Take(0.8)
    out.add(0.0, kit.ping(1046.5, 0.16, _BELL), 1.0)
    out.add(0.03, kit.struck(kit.band(0.3, "star shimmer", 6000.0, 3.0), 0.08, 0.002), 0.18)
    return out.mix


def firework() -> np.ndarray:
    """A rocket whistles up and bursts into crackle."""
    out = kit.Take(1.3)
    whistle = kit.tone((500.0, 2300.0), 0.4, 1, 1.0, 6000.0)
    out.add(0.0, kit.swell(whistle, 0.05, 0.08), 0.35)
    burst = kit.struck(kit.band(0.5, "firework burst", 2600.0, 0.8), 0.09, 0.001)
    out.add(0.4, burst, 1.0)
    crackle = kit.band(0.7, "firework crackle", 5200.0, 2.0) * kit.grains(0.7, "firework grains", 45.0, 0.002)
    out.add(0.45, crackle * dsp.decay(len(crackle), 0.25), 0.7)
    return out.mix


def hic() -> np.ndarray:
    """A hiccup: a squeak that jumps up and falls back."""
    return kit.swell(kit.tone((300.0, 540.0, 360.0), 0.16, 3, 1.5), 0.01, 0.06)


SOUNDS: dict[str, tuple[Callable[[], np.ndarray], float]] = {
    "fun_toll": (toll, -22.0),
    "fun_heartbeat": (heartbeat, -21.0),
    "fun_glint": (glint, -25.0),
    "fun_dice": (dice, -22.0),
    "fun_star": (star, -23.0),
    "fun_firework": (firework, -22.0),
    "fun_hic": (hic, -24.0),
}
