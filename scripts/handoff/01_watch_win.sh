#!/bin/bash

# ============================================================================
# Hand-off item: a Watch siege that wins (strong loadout)
# Run it from any directory. It opens the game in that state, asks one
# question and appends your answer to the feedback/ folder; --check does the
# same launch muted on a private screen, asks nothing and exits 0 when it came up.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/handoff.sh
source "$REPO_ROOT/scripts/lib/handoff.sh"

ITEM_ID="watch_win"
ITEM_QUESTION="Watch, a strong army: was it clear what happened and why the army won?"
ITEM_SCREEN="battle"
ITEM_JQ='.mode == "watch" and (.loadout | length) == 4'
ITEM_SOUND=0
ITEM_ARGS=(--mode=watch "--loadout=$WIN_LOADOUT" "--seed=$FIXTURE_SEED")

handoff_main "$@"
