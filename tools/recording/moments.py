"""Which telemetry entries are moments worth a timestamp, and the derived ones.

Direct moments map one entry to one moment (src/dev/telemetry.gd writes them).
Derived moments need several entries: a burst of hitches is one moment.
Moments carry `ms` (the entry's game clock); timeline.py turns it into `t`.
"""

HITCH_MERGE_S = 2.0
# engine_error kinds that are a moment; warnings and stderr lines are noise.
ERROR_KINDS = {"error", "script_error", "shader_error"}

# Entries that are a moment as they are, with the fields worth keeping.
DIRECT = {
    "session_start": (),
    "hub_open": (),
    "buy": ("buff", "bought", "cost"),
    "game_start": ("loadout", "cost", "men", "seed"),
    "command": ("order", "pos"),
    "pause_open": (),
    "pause_close": ("paused_s",),
    "lab_result": ("wins", "runs", "mean_seconds"),
    "reset_progress": ("files",),
    "quit": ("reason",),
    "session_end": ("reason", "elapsed_s"),
}
# Whatever the game later logs under these names is a moment too (sim events).
PASSTHROUGH_PREFIXES = ("siege_", "milestone")
# Fields every entry carries; never part of a passthrough moment's payload.
ENVELOPE = ("session", "time", "frame", "tag", "event", "seq", "ms")
ANNOTATION = "annotation"


def event_name(row: dict) -> str:
    return row.get("event", "")


def _moment(row: dict, kind: str, label: str, **extra: object) -> dict:
    out = {"kind": kind, "label": label, "event": event_name(row), "seq": row.get("seq"), "ms": row["ms"]}
    if row.get("game"):
        out["game"] = row["game"]
    out.update(extra)
    return out


def _keep(row: dict, keys: tuple[str, ...]) -> dict:
    return {k: row[k] for k in keys if k in row}


def _words(value: object) -> str:
    """A field value as label text: a list reads as a,b,c."""
    if isinstance(value, list):
        return ",".join(str(v) for v in value)
    return str(value)


def _one(row: dict) -> dict | None:
    name = event_name(row)
    if name in DIRECT:
        extra = _keep(row, DIRECT[name])
        detail = " ".join(_words(v) for v in extra.values() if v not in ("", None))
        return _moment(row, name, f"{name} {row.get('game', '')} {detail}".replace("  ", " ").strip(), **extra)
    if name == "game_end":
        extra = _keep(row, ("outcome", "elapsed_s"))
        return _moment(row, "game_end", f"game_end {row.get('outcome', '')}".strip(), **extra)
    if name == ANNOTATION:
        return _moment(row, ANNOTATION, "F12 annotation", png=row.get("image", ""), marks=row.get("marks"))
    if name == "engine_error" and row.get("kind") in ERROR_KINDS:
        text = str(row.get("message", ""))[:60]
        extra = _keep(row, ("message", "file", "line"))
        return _moment(row, name, f"engine_error {text}", error_kind=row["kind"], **extra)
    if name.startswith(PASSTHROUGH_PREFIXES):
        extra = {k: v for k, v in row.items() if k not in ENVELOPE}
        return _moment(row, name, name, **extra)
    return None


def classify(rows: list[dict]) -> list[dict]:
    """The direct moments of a session's entries."""
    return [m for m in (_one(r) for r in rows) if m is not None]


def derive(rows: list[dict]) -> list[dict]:
    """The moments that need more than one entry."""
    return _hitches(rows)


def _hitches(rows: list[dict]) -> list[dict]:
    """A burst of `hitch` entries closer than HITCH_MERGE_S is one moment."""
    out: list[dict] = []
    last_ms = -(10**12)
    for row in rows:
        if event_name(row) != "hitch":
            continue
        dur = row.get("dur_ms", 0)
        if out and row["ms"] - last_ms <= HITCH_MERGE_S * 1000:
            out[-1]["count"] += 1
            out[-1]["max_ms"] = max(out[-1]["max_ms"], dur)
        else:
            out.append(_moment(row, "hitch", "", count=1, max_ms=dur, cause=row.get("cause", ""), derived=True))
        out[-1]["label"] = f"hitch x{out[-1]['count']} max {out[-1]['max_ms']} ms"
        last_ms = row["ms"]
    return out
