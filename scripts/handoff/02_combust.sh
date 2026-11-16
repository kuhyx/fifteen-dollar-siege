#!/bin/bash

# ============================================================================
# Hand-off item: a Watch siege that loses, with the combust payoff
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

ITEM_ID="watch_combust"
ITEM_QUESTION="Watch, a weak army: was the loss clear, and did the burning army feel like a payoff?"
ITEM_SCREEN="battle"
ITEM_JQ='.mode == "watch" and (.loadout | length) == 2'
ITEM_SOUND=0
ITEM_ARGS=(--mode=watch "--loadout=$LOSE_LOADOUT" "--seed=$FIXTURE_SEED")

handoff_main "$@"
