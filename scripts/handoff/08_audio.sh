#!/bin/bash

# ============================================================================
# Hand-off item: the audio; the only item that plays sound (hub, shop, a siege, the result)
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

ITEM_ID="audio"
ITEM_QUESTION="The sound: do the music and the effects sound good, and does each fit its moment?"
ITEM_SCREEN="hub"
ITEM_JQ='true'
ITEM_SOUND=1
ITEM_HINT="sound is on: pick Watch, buy a few buffs, go, and let the siege end."
ITEM_ARGS=()

handoff_main "$@"
