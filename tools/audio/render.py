#!/usr/bin/env python3
"""Render the game's music and sound effects to lossless WAV (tools/audio/build.sh calls it).

render.py --out DIR [--only NAME ...] [--jobs N] [--force]
render.py --out DIR --check      exit 1 when a file is missing or older than this code
render.py --list

Each file is built from code in this folder plus the pinned music_theory
toolkit, written as 16-bit 44.1 kHz PCM with Godot's import sidecar, and
recorded in DIR/MANIFEST.json (recipe, seed, toolkit version, SHA-256). A
file whose manifest entry matches this source tree is left alone, so a rerun
costs nothing and a run cut short picks up where it stopped.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from music_theory import manifest

from audio import catalog, wavio

MANIFEST = "MANIFEST.json"
HERE = Path(__file__).resolve().parent


def source_hash() -> str:
    """One hash of everything a render depends on: this folder's code and the toolkit pin."""
    digest = hashlib.sha256()
    for path in sorted([*HERE.glob("*.py"), HERE / "requirements.txt"]):
        digest.update(path.name.encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def is_current(entry: dict[str, object] | None, path: Path, source: str) -> bool:
    if entry is None or not path.exists():
        return False
    return entry.get("source") == source and entry.get("sha256") == wavio.sha256(path)


def render_one(name: str, out_dir: str, source: str) -> tuple[str, dict[str, object]]:
    """Builds, levels and writes one file; returns its manifest key and entry."""
    asset = catalog.by_name()[name]
    signal = catalog.finish(asset, asset.build())
    path = wavio.write(Path(out_dir) / asset.path, signal, asset.sample_rate, asset.loop)
    wavio.write_sidecar(path, asset.loop)
    entry = manifest.entry(asset, path, signal)
    entry["source"] = source
    entry["channels"] = 1 if signal.ndim == 1 else signal.shape[1]
    return asset.path, entry


def prune(out_dir: Path, wanted: set[str]) -> list[str]:
    """Removes WAVs (and their sidecars) that the catalogue no longer lists."""
    gone = []
    for path in sorted(out_dir.rglob("*.wav")):
        rel = path.relative_to(out_dir).as_posix()
        if rel not in wanted:
            path.unlink()
            path.with_name(path.name + ".import").unlink(missing_ok=True)
            gone.append(rel)
    return gone


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    top.add_argument("--out", type=Path)
    top.add_argument("--only", action="append", default=[], help="render just this name (repeatable)")
    top.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    top.add_argument("--force", action="store_true", help="render even when the manifest says a file is current")
    top.add_argument("--list", action="store_true", help="print every file of the catalogue and exit")
    top.add_argument("--check", action="store_true", help="render nothing; fail when a file is stale")
    return top


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    assets = catalog.all_assets()
    if args.list:
        for asset in assets:
            print(f"{asset.path}\t{asset.kind}\t{'loop' if asset.loop else 'one-shot'}\t{asset.target_lufs:g} LUFS")
        return 0
    if args.out is None:
        parser().error("--out is required")
    unknown = set(args.only) - {asset.name for asset in assets}
    if unknown:
        parser().error(f"unknown name(s): {', '.join(sorted(unknown))} (see --list)")
    out_dir: Path = args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / MANIFEST
    entries = manifest.read(manifest_path) if manifest_path.exists() else {}
    source = source_hash()
    todo = [
        asset
        for asset in assets
        if (not args.only or asset.name in args.only)
        and (args.force or not is_current(entries.get(asset.path), out_dir / asset.path, source))
    ]
    if args.check:
        for asset in todo:
            print(f"stale {asset.path}", file=sys.stderr)
        print(f"audio: {len(assets) - len(todo)} of {len(assets)} files current")
        return 1 if todo else 0
    for asset in assets:
        if asset not in todo and (out_dir / asset.path).exists():
            wavio.write_sidecar(out_dir / asset.path, asset.loop)
    with ProcessPoolExecutor(max_workers=max(args.jobs, 1)) as pool:
        pending = [pool.submit(render_one, asset.name, str(out_dir), source) for asset in todo]
        for done in as_completed(pending):
            key, entry = done.result()
            entries[key] = entry
            manifest.write(manifest_path, entries)
            print(f"rendered {key} ({entry['seconds']:.2f} s)")
    wanted = {asset.path for asset in assets}
    for rel in prune(out_dir, wanted):
        print(f"removed {rel} (no longer in the catalogue)")
    manifest.write(manifest_path, {key: value for key, value in entries.items() if key in wanted})
    print(f"audio: {len(todo)} rendered, {len(assets) - len(todo)} current, {len(assets)} files in {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
