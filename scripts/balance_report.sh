#!/bin/bash

# ============================================================================
# The balance table of the current sim, from what scripts/balance_search.sh
# measured: the four targets (no buffs, a random loadout, the best loadout,
# every buff in the top 50), the top loadouts and each buff's best rank, as
# Markdown (DOCS-design-sim.md holds a copy).
#   scripts/balance_report.sh [--rows=10] [--top=50] [--min-runs=48] [--strict]
# --strict exits 1 when a target is missed or not measured yet.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
    need godot
    cd "$REPO_ROOT"
    cap timeout -k 3 50 godot --headless --audio-driver Dummy --path "$REPO_ROOT" \
        -s tools/sim/balance_report.gd -- "$@" 2>&1 | grep -v '^Godot Engine'
}

main "$@"
