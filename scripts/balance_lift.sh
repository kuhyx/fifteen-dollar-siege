#!/bin/bash

# ============================================================================
# What each buff adds to one loadout (tools/sim/buff_lift.gd), one slice under
# 60 s on SHARDS processes; cached like the search, so call it again until
# every shard prints left=0. The last shard's table is the full one.
#   scripts/balance_lift.sh <base ids, comma separated | none> [runs]
#   SHARDS=2 BUDGET_S=42
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly SHARDS="${SHARDS:-2}"
readonly BUDGET_S="${BUDGET_S:-42}"

main() {
    need godot
    [[ $# -ge 1 ]] || {
        echo "usage: balance_lift.sh <base ids | none> [runs]" >&2
        exit 2
    }
    cd "$REPO_ROOT"
    local shard pids=() pid out="$SCRATCH/lift.$$"
    mkdir -p "$SCRATCH"
    for ((shard = 0; shard < SHARDS; shard++)); do
        cap timeout -k 3 55 godot --headless --audio-driver Dummy --path "$REPO_ROOT" \
            -s tools/sim/buff_lift.gd -- "--base=$1" "--runs=${2:-40}" "--shard=$shard" \
            "--shards=$SHARDS" "--budget-s=$BUDGET_S" >"$out.$shard" 2>&1 &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    # Every shard prints the table from the merged cache; re-read it once all
    # are done so the table shows every shard's sieges.
    cap timeout -k 3 20 godot --headless --audio-driver Dummy --path "$REPO_ROOT" \
        -s tools/sim/buff_lift.gd -- "--base=$1" "--runs=${2:-40}" --budget-s=0 \
        --shard=0 --shards=1000000 2>&1 | grep -E '^\||^RESULT'
    grep -h '^RESULT' "$out".* || true
    rm -f "$out".*
}

main "$@"
