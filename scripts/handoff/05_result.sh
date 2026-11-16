#!/bin/bash

# ============================================================================
# Hand-off item: the result screen (stars, dice)
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

ITEM_ID="result"
ITEM_QUESTION="The result screen: do the stars and the dice make sense without a word?"
ITEM_SCREEN="result"
ITEM_JQ='.mode == "watch" and .cost == 10'
ITEM_SOUND=0
ITEM_ARGS=(--mode=watch --screen=result "--loadout=$TWO_STAR_LOADOUT" "--seed=$FIXTURE_SEED")

handoff_main "$@"
