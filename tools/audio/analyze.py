#!/usr/bin/env python3
"""Offline gate for the rendered audio: measure every file, fail on any fault.

analyze.py DIR [--json OUT] [--quiet]

Nobody hears these files before kuhy does. So every file listed in
DIR/MANIFEST.json is read back from disk and checked for: clipping,
silence, DC offset, a loop seam that steps, loudness outside its kind's
band, a shrill spectrum (effects), a late or abrupt start or end
(one-shots), a low sample rate. A file missing from disk, a WAV the manifest
does not know, or a loop without its closing frame fails too. Limits:
tools/audio/checks.py; the table is in DOCS-audio.md.
Exit 0 when every file is clean, 1 otherwise.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from audio import checks, wavio

MANIFEST = "MANIFEST.json"


def inspect(path: Path, kind: str, loop: bool) -> tuple[checks.Measure | None, list[checks.Fault]]:
    """One file's numbers and faults. A loop is measured without its closing frame."""
    if not path.exists():
        return None, [checks.Fault("missing", "not on disk")]
    signal, rate = wavio.read(path)
    faults: list[checks.Fault] = []
    if loop:
        if not wavio.is_closed(signal):
            faults.append(checks.Fault("loop_frame", "the last frame does not repeat the first"))
        signal = signal[:-1]
    found = checks.measure(signal, rate)
    return found, faults + checks.faults(found, kind, loop)


def report(root: Path) -> tuple[list[dict[str, object]], int]:
    """A row per file (numbers and faults) and the number of faulty files."""
    manifest_path = root / MANIFEST
    if not manifest_path.exists():
        return [{"file": MANIFEST, "faults": ["missing: run tools/audio/build.sh"]}], 1
    entries: dict[str, dict[str, object]] = json.loads(manifest_path.read_text())
    rows: list[dict[str, object]] = []
    bad = 0
    for rel in sorted(entries):
        recipe = entries[rel].get("recipe", {})
        kind, loop = str(recipe.get("kind", "")), bool(recipe.get("loop", False))
        found, faults = inspect(root / rel, kind, loop)
        row: dict[str, object] = {"file": rel, "kind": kind, "loop": loop}
        if found is not None:
            row.update(asdict(found))
            row["level"] = checks.loudness_of(found, kind) if kind in checks.BANDS else None
        row["faults"] = [f"{fault.check}: {fault.detail}" for fault in faults]
        bad += bool(faults)
        rows.append(row)
    for stray in sorted({path.relative_to(root).as_posix() for path in root.rglob("*.wav")} - set(entries)):
        rows.append({"file": stray, "faults": ["unlisted: not in the manifest"]})
        bad += 1
    return rows, bad


def summary(rows: list[dict[str, object]]) -> list[str]:
    """Loudness range per kind and the worst loop seam: the numbers a report quotes."""
    lines = []
    for kind in checks.BANDS:
        levels = [float(row["level"]) for row in rows if row.get("kind") == kind and row.get("level") is not None]
        if levels:
            low, high = checks.BANDS[kind]
            lines.append(
                f"{kind:8} {len(levels):2} files  {min(levels):6.1f} .. {max(levels):6.1f} LUFS  (band {low:g} .. {high:g})"
            )
    seams = [(float(row["seam_ratio"]), str(row["file"])) for row in rows if row.get("loop") and "seam_ratio" in row]
    if seams:
        worst, name = max(seams)
        lines.append(f"worst loop seam: {worst:.2f}x the audio's own steps ({name}; limit {checks.SEAM_RATIO:g}x)")
    return lines


def main(argv: list[str] | None = None) -> int:
    top = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    top.add_argument("dir", type=Path)
    top.add_argument("--json", type=Path, help="also write every row as JSON")
    top.add_argument("--quiet", action="store_true", help="print only faults and the summary")
    args = top.parse_args(argv)
    rows, bad = report(args.dir)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(rows, indent=2) + "\n")
    for row in rows:
        faults = row["faults"]
        if not args.quiet and "peak_db" in row:
            print(
                f"{row['file']:28} {row['seconds']:6.2f} s  peak {row['peak_db']:6.1f}  "
                f"{row['level']:6.1f} LUFS  centroid {row['centroid_hz']:5.0f} Hz  seam {row['seam_ratio']:4.2f}"
            )
        for fault in faults if isinstance(faults, list) else []:
            print(f"FAULT {row['file']}: {fault}", file=sys.stderr)
    for line in summary(rows):
        print(line)
    print(f"audio analysis: {len(rows) - bad} of {len(rows)} files clean")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
