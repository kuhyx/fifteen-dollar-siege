#!/bin/bash

# ============================================================================
# One slice (under 60 s) of the loadout search: SHARDS headless godot processes
# side by side, each measuring its own share of the plan for BUDGET_S seconds
# (tools/sim/balance_search.gd). Results are cached per sim hash under
# ~/data/claude-scratch/fifteen-dollar-siege/balance/, so call it again until
# a slice prints "left=0" on every shard; then scripts/balance_report.sh.
#   scripts/balance_search.sh [--no-climb]
#   SHARDS=2      processes (they share the session's CPU cap)
#   BUDGET_S=42   seconds of sieges per process
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly SHARDS="${SHARDS:-2}"
readonly BUDGET_S="${BUDGET_S:-42}"

main() {
    need godot
    cd "$REPO_ROOT"
    local shard pids=() failed=0 pid
    for ((shard = 0; shard < SHARDS; shard++)); do
        cap timeout -k 3 55 godot --headless --audio-driver Dummy --path "$REPO_ROOT" \
            -s tools/sim/balance_search.gd -- "--shard=$shard" "--shards=$SHARDS" \
            "--budget-s=$BUDGET_S" "$@" 2>&1 | grep -E '^RESULT|ERROR' &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done
    if ((failed)); then
        echo "balance_search: a shard failed" >&2
        exit 1
    fi
}

main "$@"
