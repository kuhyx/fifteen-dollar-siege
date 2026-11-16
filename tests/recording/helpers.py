"""Shared fixtures for the recording tests (stdlib unittest, no dependencies)."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

SESSION = "1794396071-c6df"
# The game's clock: `ms` counts from DevLog creation; the sync entry pairs one
# ms value with the unix time of that same instant.
SYNC_UNIX = 1_800_000_000.250
SYNC_MS = 200


def entry(event: str, ms: int, seq: int = 0, **fields: object) -> dict:
    """One telemetry line as the game writes it."""
    return {
        "event": event,
        "session": SESSION,
        "seq": seq,
        "ms": ms,
        "frame": ms // 16,
        "time": "2026-11-11T12:00:00",
        **fields,
    }


def sync_entry() -> dict:
    return entry("recording_sync", SYNC_MS, 1, unix=SYNC_UNIX)
