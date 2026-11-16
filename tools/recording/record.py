#!/usr/bin/env python3
"""Session recording CLI (scripts/recordings.sh and run.sh call it).

record.py wrap [--session ID] [--force] [--audio SRC] [--fps N] [--max-seconds S] -- <game command>
record.py finalize <rec.json>             rebuild events.json + chapters
record.py latest|list [--dir D]           moments of the newest recording / all recordings
record.py open [N] [--session ID] [--dir D] [--dry-run]
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from recording import finalize, library, supervise


def default_dir() -> Path:
    return supervise.feedback_dir([], os.environ) / "recordings"


def pick(rec_dir: Path, session: str) -> dict:
    found = library.sessions(rec_dir)
    if session:
        found = [p for p in found if p.name.startswith(session)]
    if not found:
        raise SystemExit(f"no recordings in {rec_dir}")
    return library.load(found[0])


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(description=__doc__)
    sub = top.add_subparsers(dest="cmd", required=True)
    wrap = sub.add_parser("wrap")
    wrap.add_argument("--session", default="")
    wrap.add_argument("--force", action="store_true", help="record bot/test runs too (tests only)")
    wrap.add_argument("--audio", default="default", help="default|lavfi|<pulse source>")
    wrap.add_argument("--fps", type=int, default=30)
    wrap.add_argument("--max-seconds", type=float, default=0.0)
    wrap.add_argument("command", nargs=argparse.REMAINDER)
    fin = sub.add_parser("finalize")
    fin.add_argument("meta")
    for name in ("latest", "list", "open"):
        p = sub.add_parser(name)
        p.add_argument("--dir", default="")
        p.add_argument("--session", default="")
        if name == "open":
            p.add_argument("n", nargs="?", type=int)
            p.add_argument("--dry-run", action="store_true")
    return top


def main(argv: list[str]) -> int:
    args = parser().parse_args(argv)
    if args.cmd == "wrap":
        command = args.command[1:] if args.command[:1] == ["--"] else args.command
        return supervise.run(
            command,
            force=args.force,
            session=args.session,
            audio=args.audio,
            fps=args.fps,
            max_seconds=args.max_seconds,
        )
    if args.cmd == "finalize":
        finalize.finalize(Path(args.meta))
        return 0
    rec_dir = Path(args.dir) if args.dir else default_dir()
    if args.cmd == "list":
        print(library.listing(rec_dir))
    elif args.cmd == "latest":
        print(library.table(pick(rec_dir, args.session)))
    else:
        doc = pick(rec_dir, args.session)
        try:
            return library.open_moment(doc, rec_dir, args.n, args.dry_run)
        except IndexError as err:
            raise SystemExit(str(err)) from err
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
