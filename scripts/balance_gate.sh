#!/bin/bash

# ============================================================================
# The quick balance gate, well under 60 s: the pinned checks of
# tools/sim/balance_pins.gd against the sim as it is now.
#   - the empty loadout wins under 5 %
#   - the pinned best loadout wins 85 % or more
#   - a pinned random sample wins 25-45 %
#   - for each of the 25 buffs a pinned loadout where buying it wins more
#   - the scripted commander (Command mode) beats Watch mode
# SHARDS headless godot processes measure side by side, one more judges.
# Fails closed: a missing shard, a script error or a timeout is a failure.
# Red after a tuning change? scripts/balance_search.sh until "left=0", then
# godot --headless --path . -s tools/sim/find_pins.gd -- --write
#   scripts/balance_gate.sh
#   SHARDS=3   processes
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
hold_build_lock "$0" "$@"

readonly SHARDS="${SHARDS:-3}"
OUT=""

cleanup() {
    [[ -z "$OUT" ]] || rm -rf "$OUT"
}

# Runs the gate tool headless with the given tool arguments.
gate() {
    cap timeout -k 3 50 godot --headless --audio-driver Dummy --path "$REPO_ROOT" \
        -s tools/sim/balance_gate.gd -- "$@" 2>&1
}

main() {
    need godot
    cd "$REPO_ROOT"
    mkdir -p "$SCRATCH"
    OUT="$(mktemp -d "$SCRATCH/balance_gate.XXXXXX")"
    trap cleanup EXIT
    local shard pids=() pid start="$SECONDS" verdict code=0
    for ((shard = 0; shard < SHARDS; shard++)); do
        gate "--out=$OUT" "--shard=$shard" "--shards=$SHARDS" >"$OUT/shard-$shard.log" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || code=1
    done
    if ((code != 0)) || grep -lE 'SCRIPT ERROR|Parse Error' "$OUT"/*.log >/dev/null; then
        tail -n 15 "$OUT"/*.log >&2
        echo "balance_gate: FAILED (a shard did not finish)" >&2
        exit 1
    fi
    verdict="$(gate "--judge=$OUT")" || code=1
    grep -E '^(ok|FAIL)' <<<"$verdict" | grep -v '^ok' >&2 || true
    if ((code != 0)) || ! grep -q '^RESULT balance_gate PASS' <<<"$verdict"; then
        grep -E '^RESULT' <<<"$verdict" >&2 || true
        echo "balance_gate: FAILED" >&2
        exit 1
    fi
    echo "balance_gate: green ($(grep -c '^ok' <<<"$verdict") checks, $((SECONDS - start))s)"
}

main "$@"
