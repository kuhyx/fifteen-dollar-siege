#!/bin/bash

# ============================================================================
# Driver of scripts/e2e_recording.sh launcher (runs INSIDE the private Xvfb):
# record_wrap, the function run.sh hands the game to, around the stand-in game.
# Usage: launcher_driver.sh <session> <feedback-dir>
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT

# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$ROOT/scripts/lib/launch.sh"

main() {
    local session="$1" feedback="$2"
    record_wrap "$session" python3 "$ROOT/tests/recording/flasher.py" --dev "--session-id=$session" "--feedback-dir=$feedback"
}

main "$@"
