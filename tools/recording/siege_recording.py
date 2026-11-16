#!/usr/bin/env python3
"""The game's side of the session recorder (the package is `game_recording`, kuhyx/utils).

Everything game-specific lives here: the names, the binaries folder and which
telemetry entries are moments. scripts/recordings.sh, the launcher and the e2e
gate run it with the recorder venv's python (tools/recording/build.sh --venv):
    siege_recording.py wrap [--session ID] [--force] [--audio SRC] -- <game command>
    siege_recording.py latest|list|open [N] [--dir D] [--session ID] [--dry-run]
    siege_recording.py finalize <session>.rec.json
"""

import sys
from collections.abc import Sequence

from game_recording import Config, MomentMap, cli
from game_recording.config import COMMON_DIRECT

# src/dev/telemetry.gd writes these entries; each is one moment with the fields kept.
DIRECT = {
    **COMMON_DIRECT,
    "buy": ("buff", "bought", "cost"),
    "game_start": ("loadout", "cost", "men", "seed"),
    "command": ("order", "pos"),
    "lab_result": ("wins", "runs", "mean_seconds"),
    "reset_progress": ("files",),
}
# Whatever the game logs under these names is a moment too (sim events).
PASSTHROUGH = ("siege_", "milestone")

CONFIG = Config(
    binaries_dir="data/fifteen-dollar-siege_binaries",
    env_prefix="SIEGE",
    moments=MomentMap(direct=DIRECT, passthrough_prefixes=PASSTHROUGH),
)


def main(argv: Sequence[str]) -> int:
    """Runs one recorder command for this game."""
    return cli.main(argv, CONFIG)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
