"""Every audio file of the game: where it goes, what kind it is, how loud, who builds it.

One list feeds the renderer, the manifest and the offline gate, so a file
cannot be rendered and then forgotten by the checks. `finish` is the last
step every file shares: clean edges for a one-shot, level to its loudness
target, and a ceiling under full scale.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

import numpy as np

from audio import (
    dsp,
    loudness,
    music_battle,
    music_hub,
    music_rock,
    music_stingers,
    sfx_fight,
    sfx_fun,
    sfx_specials,
    sfx_ui,
)

# Highest sample a finished file may hold (dBFS): head-room under the gate's -1.
CEILING_DB = -1.5
_QUIET = 10.0 ** (-80.0 / 20.0)


@dataclass(frozen=True)
class Asset:
    name: str
    folder: str
    kind: str
    loop: bool
    target_lufs: float
    build: Callable[[], np.ndarray]
    recipe: dict[str, object] = field(default_factory=dict)
    sample_rate: int = dsp.SR

    @property
    def path(self) -> str:
        return f"{self.folder}/{self.name}.wav"

    def to_dict(self) -> dict[str, object]:
        """The manifest's recipe: enough to say what this file is and how it was levelled."""
        return {"name": self.name, "kind": self.kind, "loop": self.loop, "target_lufs": self.target_lufs, **self.recipe}


def _music() -> list[Asset]:
    battle = [
        Asset(name, "music", "stem", True, target, build, music_battle.RECIPE)
        for (name, build), target in zip(music_battle.STEMS.items(), (-21.0, -21.0, -22.0, -22.0), strict=True)
    ]
    return [
        Asset(music_hub.NAME, "music", "music", True, -18.0, music_hub.render, music_hub.RECIPE),
        *battle,
        Asset(music_rock.NAME, "music", "music", True, -17.5, music_rock.render, music_rock.RECIPE),
        Asset("win_stinger", "music", "stinger", False, -16.5, music_stingers.win, music_stingers.WIN_RECIPE),
        Asset("lose_stinger", "music", "stinger", False, -17.0, music_stingers.lose, music_stingers.LOSE_RECIPE),
    ]


def _described(build: Callable[[], np.ndarray]) -> str:
    """`module.function(arguments)` of a builder: a stable name for the manifest."""
    inner = getattr(build, "func", build)
    given = getattr(build, "args", ())
    return f"{inner.__module__}.{inner.__name__}{given or ''}"


def _effects() -> list[Asset]:
    out = []
    for folder, sounds in (
        ("sfx", sfx_fight.SOUNDS),
        ("sfx", sfx_specials.SOUNDS),
        ("sfx", sfx_fun.SOUNDS),
        ("ui", sfx_ui.SOUNDS),
    ):
        for name, (build, target) in sounds.items():
            out.append(Asset(name, folder, folder, False, target, build, {"synthesis": _described(build)}))
    return out


def all_assets() -> list[Asset]:
    return _music() + _effects()


def by_name() -> dict[str, Asset]:
    return {asset.name: asset for asset in all_assets()}


def _one_shot(signal: np.ndarray) -> np.ndarray:
    """No rumble, no dead air after the sound, and both ends at zero."""
    clean = dsp.highpass(signal, 35.0)
    loud = np.flatnonzero(np.max(np.abs(clean.reshape(len(clean), -1)), axis=1) > _QUIET)
    if len(loud):
        clean = clean[: min(int(loud[-1]) + dsp.frames(0.02), len(clean))]
    gain = dsp.ramp(len(clean), 0.0006)
    clean = clean * (gain if clean.ndim == 1 else gain[:, None])
    return dsp.fade_out(clean, 0.015)


def finish(asset: Asset, signal: np.ndarray) -> np.ndarray:
    """The built signal as it ships: edges, loudness target, ceiling."""
    body = signal - np.mean(signal, axis=0) if asset.loop else _one_shot(signal)
    measured = loudness.of_kind(body, asset.sample_rate, asset.kind)
    gain = 10.0 ** ((asset.target_lufs - measured) / 20.0)
    ceiling = 10.0 ** (CEILING_DB / 20.0)
    return body * min(gain, ceiling / max(dsp.peak(body), 1e-9))
