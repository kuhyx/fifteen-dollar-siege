"""Telemetry entries -> timestamps on the recording's timeline (events.json, chapters).

The game's entries carry `ms` since its log opened. One `recording_sync` entry
pairs an `ms` with the unix time of that same instant, so every entry has an
exact wall-clock time. The recorder's start (`t0_unix`) is on the same unix
clock (ffmpeg's -output_ts_offset puts its media timeline at t0), hence

    t = sync.unix + (entry.ms - sync.ms) / 1000 - t0_unix

`t` is seconds on the file's media timeline: what mpv shows with
`--rebase-start-time=no` and where MKV chapters sit. The first frame is at
`video_start_s` (a few tens of ms after t0), so earlier events are flagged
`before_recording`, later ones `after_recording`.

The recorder restarts when the game's window goes away and comes back (an i3
workspace switch): one part file per run, all on the same t0 timeline. An event
between two parts is `in_gap`; every other recorded event names its `file`.
"""

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from recording import moments


class NoSync(Exception):
    """The session has neither a recording_sync nor a session_start entry."""


@dataclass(frozen=True)
class Sync:
    unix_s: float
    ms: int
    method: str
    approx: bool


def load_session(path: Path, session: str) -> list[dict]:
    """The entries of one session from a feedback.jsonl (bad lines are skipped)."""
    rows: list[dict] = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if isinstance(row, dict) and row.get("session") == session:
            rows.append(row)
    return rows


def find_sync(entries: list[dict]) -> Sync:
    """The exact pairing from recording_sync, else session_start's whole-second `time`."""
    for row in entries:
        if row.get("event") == "recording_sync" and ("unix_us" in row or "unix" in row):
            unix = row["unix_us"] / 1_000_000 if "unix_us" in row else float(row["unix"])
            return Sync(unix, int(row["ms"]), "recording_sync", False)
    for row in entries:
        if row.get("event") == "session_start" and "time" in row:
            wall = datetime.fromisoformat(row["time"]).timestamp()
            return Sync(wall, int(row.get("ms", 0)), "session_start.time", True)
    raise NoSync("no recording_sync or session_start entry")


def _flag(moment: dict, t: float, parts: list[dict]) -> None:
    """Names the part file the moment is in, or says why it is in none."""
    for part in parts:
        if part["start_s"] - 1e-6 <= t <= part["start_s"] + part["duration_s"] + 1e-6:
            if part["file"]:
                moment["file"] = part["file"]
            return
    if t < parts[0]["start_s"]:
        moment["before_recording"] = True
    elif t > parts[-1]["start_s"] + parts[-1]["duration_s"]:
        moment["after_recording"] = True
    else:
        moment["in_gap"] = True


def build_events(
    entries: list[dict],
    *,
    session: str,
    t0_unix: float,
    video_start_s: float = 0.0,
    duration_s: float = 0.0,
    parts: list[dict] | None = None,
) -> dict:
    """The events.json document for one recording (`parts`: file, start_s, duration_s per part file)."""
    rows = [r for r in entries if r.get("session") == session]
    sync = find_sync(rows)
    parts = parts or [{"file": "", "start_s": video_start_s, "duration_s": duration_s}]
    first, last = parts[0]["start_s"], parts[-1]["start_s"] + parts[-1]["duration_s"]
    found = moments.classify(rows)
    found += moments.derive(rows)
    events = []
    for moment in found:
        t = sync.unix_s + (moment["ms"] - sync.ms) / 1000 - t0_unix
        moment["t"] = round(t, 6)
        _flag(moment, t, parts)
        events.append(moment)
    events.sort(key=lambda m: (m["t"], m.get("seq") or 0))
    tag = next((r["tag"] for r in rows if "tag" in r), "")
    return {
        "session": session,
        "tag": tag,
        "t0_unix": t0_unix,
        "video": {"start_s": first, "duration_s": last - first, "end_s": last, "parts": parts},
        "sync": {"method": sync.method, "approx": sync.approx, "unix": sync.unix_s, "ms": sync.ms},
        "events": events,
    }


def in_recording(event: dict) -> bool:
    return not (event.get("before_recording") or event.get("after_recording") or event.get("in_gap"))


def escape_meta(text: str) -> str:
    """ffmetadata escaping: backslash-prefix = ; # \\ and newline."""
    return "".join("\\" + c if c in "=;#\\\n" else c for c in text)


def chapters_ffmetadata(events: list[dict], duration_s: float, video_start_s: float, file: str | None = None) -> str:
    """An ffmetadata file with one chapter per event that lies inside the file (the part `file`)."""
    inside = [e for e in events if in_recording(e) and (file is None or e.get("file", file) == file)]
    end_ms = round((video_start_s + duration_s) * 1000)
    # The muxer drops a second chapter with the same start: events of one millisecond share one.
    titles: dict[int, list[str]] = {}
    for event in inside:
        titles.setdefault(round(event["t"] * 1000), []).append(event["label"])
    starts = list(titles)
    lines = [";FFMETADATA1"]
    for i, start in enumerate(starts):
        nxt = starts[i + 1] - 1 if i + 1 < len(starts) else end_ms
        lines += [
            "[CHAPTER]",
            "TIMEBASE=1/1000",
            f"START={start}",
            f"END={max(start, nxt)}",
            f"title={escape_meta(' | '.join(titles[start]))}",
        ]
    return "\n".join(lines) + "\n"
