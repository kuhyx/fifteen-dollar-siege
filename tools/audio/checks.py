"""What the offline gate measures in one audio file, and when a number is a fault.

Nobody listens to these files before kuhy does, so every way a file can be
wrong without anyone hearing it gets a number and a limit here. Limits and
their sources are the table in DOCS-audio.md ("Offline gate").
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from music_theory import analysis

from audio import loudness

MIN_RATE = 44100
# EBU R 128 keeps programme peaks at or under -1 dB; a file may not come closer to full scale.
PEAK_CEILING_DB = -1.0
FULL_SCALE = 32766.0 / 32767.0
CLIP_RUN = 3
SILENCE_RMS_DB = -60.0
DC_LIMIT = 0.002
# A one-shot must begin within this of its first frame (above -50 dBFS) and end at zero.
LATE_START_S = 0.02
AUDIBLE = 10.0 ** (-50.0 / 20.0)
EDGE_LIMIT = 0.004
# ISO 226: the ear is most sensitive from 2 to 5 kHz. An effect whose spectral
# centre of mass sits above this reads as hiss or a whistle [design guess: the exact line].
SHRILL_HZ = 4000.0
# The seam of a loop may step no harder than twice the hardest steps inside it.
SEAM_RATIO = 2.0
# Loudness bands (LUFS). Full mixes centre on -18 (Sony ASWG-R001, portable
# target -18 +-2); stems sit lower because they sum; effects are read at their
# loudest 100 ms and spread by role [design guess: the stem, effect and UI bands].
BANDS: dict[str, tuple[float, float]] = {
    "music": (-20.0, -16.0),
    "stem": (-26.0, -19.0),
    "stinger": (-20.0, -14.0),
    "sfx": (-26.0, -12.0),
    "ui": (-30.0, -16.0),
}
LOOP_KINDS = ("music", "stem")


@dataclass(frozen=True)
class Measure:
    rate: int
    channels: int
    seconds: float
    peak_db: float
    clip_run: int
    rms_db: float
    dc: float
    lead_s: float
    first: float
    last: float
    centroid_hz: float
    loudness: dict[str, float]
    seam_ratio: float


@dataclass(frozen=True)
class Fault:
    check: str
    detail: str


def _db(value: float) -> float:
    return 20.0 * math.log10(value) if value > 0.0 else -120.0


def _longest_run(mask: np.ndarray) -> int:
    if not mask.any():
        return 0
    edges = np.diff(np.concatenate(([0], mask.astype(np.int8), [0])))
    return int(np.max(np.flatnonzero(edges == -1) - np.flatnonzero(edges == 1)))


def _lead_seconds(body: np.ndarray, rate: int) -> float:
    heard = np.flatnonzero(np.max(np.abs(body), axis=1) > AUDIBLE)
    return float(heard[0]) / rate if len(heard) else float(len(body)) / rate


def seam_ratio(body: np.ndarray) -> float:
    """How hard the wrap from the last frame to the first steps, against the file's own steps.

    Compares the first and the second difference across the seam with the
    99.9th percentile of the same differences inside the file: 1 means the
    seam is as smooth as the audio around it.
    """
    worst = 0.0
    for channel in body.T:
        if len(channel) < 8:
            continue
        ring = np.concatenate((channel[-2:], channel[:2]))
        step = abs(ring[2] - ring[1])
        bend = float(np.max(np.abs(np.diff(ring, n=2))))
        usual_step = float(np.percentile(np.abs(np.diff(channel)), 99.9)) + 1e-4
        usual_bend = float(np.percentile(np.abs(np.diff(channel, n=2)), 99.9)) + 1e-4
        worst = max(worst, step / usual_step, bend / usual_bend)
    return worst


def measure(signal: np.ndarray, rate: int) -> Measure:
    body = (signal if signal.ndim == 2 else signal[:, None]).astype(np.float64)
    top = float(np.max(np.abs(body))) if len(body) else 0.0
    rms = math.sqrt(float(np.mean(body**2))) if len(body) else 0.0
    mono = np.mean(body, axis=1)
    return Measure(
        rate=rate,
        channels=body.shape[1],
        seconds=len(body) / rate,
        peak_db=_db(top),
        clip_run=max(_longest_run(np.abs(channel) >= FULL_SCALE) for channel in body.T),
        rms_db=_db(rms),
        dc=float(np.max(np.abs(np.mean(body, axis=0)))) if len(body) else 0.0,
        lead_s=_lead_seconds(body, rate),
        first=float(np.max(np.abs(body[0]))) if len(body) else 0.0,
        last=float(np.max(np.abs(body[-1]))) if len(body) else 0.0,
        centroid_hz=analysis.spectral_centroid(mono, rate),
        loudness={
            "integrated": loudness.integrated(body, rate),
            "short_peak": loudness.short_peak(body, rate),
        },
        seam_ratio=seam_ratio(body),
    )


def loudness_of(found: Measure, kind: str) -> float:
    return found.loudness["integrated" if kind in ("music", "stem", "stinger") else "short_peak"]


def faults(found: Measure, kind: str, loop: bool) -> list[Fault]:
    """Every limit this file breaks; empty when it is fit to ship."""
    out: list[Fault] = []

    def fail(check: str, detail: str) -> None:
        out.append(Fault(check, detail))

    if kind not in BANDS:
        fail("kind", f"unknown kind {kind!r}")
        return out
    if found.rate < MIN_RATE:
        fail("sample_rate", f"{found.rate} Hz is under {MIN_RATE}")
    if found.rms_db < SILENCE_RMS_DB:
        fail("silence", f"rms {found.rms_db:.1f} dBFS")
        return out
    if found.peak_db > PEAK_CEILING_DB or found.clip_run >= CLIP_RUN:
        fail("clipping", f"peak {found.peak_db:.2f} dBFS, {found.clip_run} frames at full scale")
    if found.dc > DC_LIMIT:
        fail("dc_offset", f"mean {found.dc:.4f}")
    low, high = BANDS[kind]
    level = loudness_of(found, kind)
    if not low <= level <= high:
        fail("loudness", f"{level:.1f} LUFS outside {low:g}..{high:g}")
    if loop:
        if found.seam_ratio > SEAM_RATIO:
            fail("loop_seam", f"seam steps {found.seam_ratio:.1f}x harder than the audio")
    else:
        if found.lead_s > LATE_START_S:
            fail("late_start", f"{found.lead_s * 1000.0:.0f} ms of silence first")
        if found.first > EDGE_LIMIT:
            fail("abrupt_start", f"first frame at {found.first:.4f}")
        if found.last > EDGE_LIMIT:
            fail("abrupt_end", f"last frame at {found.last:.4f}")
    if kind in ("sfx", "ui") and found.centroid_hz > SHRILL_HZ:
        fail("shrill", f"centroid {found.centroid_hz:.0f} Hz over {SHRILL_HZ:g}")
    return out
