#!/bin/bash

# ============================================================================
# Hand-off item: the hub with progress (stars under Watch and Command, a shelf
# with buffs on it, a Lab best). It starts from a made-up save, never yours.
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

ITEM_ID="hub_stars"
ITEM_QUESTION="The hub: do the stars under Watch and Command tell how well you did, without a word?"
ITEM_SCREEN="hub"
ITEM_JQ='.stars.watch == 2 and .stars.command == 1'
ITEM_SAVE="$HANDOFF_DIR/saves/hub"
ITEM_ARGS=()

handoff_main "$@"
