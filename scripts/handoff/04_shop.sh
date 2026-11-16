#!/bin/bash

# ============================================================================
# Hand-off item: the shop (25 pictograms, vignettes, dice)
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

ITEM_ID="shop"
ITEM_QUESTION="The shop: do the 25 pictures, the vignettes and the dice make sense without a word?"
ITEM_SCREEN="loadout"
ITEM_JQ='.mode == "watch" and .cost == 0'
ITEM_SOUND=0
ITEM_ARGS=(--mode=watch --screen=shop)

handoff_main "$@"
