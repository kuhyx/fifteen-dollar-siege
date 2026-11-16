#!/bin/bash

# ============================================================================
# GUT unit tests, headless (no window, no sound), one capped call under 60 s.
#   scripts/test.sh                 the whole suite
#   scripts/test.sh -gselect=name   one file (any -g argument is forwarded)
# Never hand-build a GUT command instead of this script: it is what keeps a
# test away from the real save (build-game lessons L10 and L11):
#   - user:// itself points at a throwaway folder (XDG_DATA_HOME) for the run
#   - .gutconfig.json runs tests/pre_run.gd, which moves the save root again
#   - the dev tools log into a folder this script removes
# Fail closed: green only with exit 0, no SCRIPT ERROR, no failing test, at
# least one test, and tests == passing + pending. A timeout or kill fails.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"

readonly RUN_TIMEOUT=50
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

# Value of a GUT totals row ("Tests 59", "Passing Tests 59"...), 0 when absent.
total_of() {
    local row="$1" out="$2"
    awk -v row="$row" '
        index($0, row) == 1 { v = $NF }
        END { print v + 0 }' <<<"$out"
}

main() {
    need godot
    need_gut
    cd "$REPO_ROOT"
    refresh_class_cache
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/test.XXXXXX")"
    trap cleanup EXIT
    export XDG_DATA_HOME="$TMP/xdg"
    export SIEGE_FEEDBACK_DIR="$TMP/feedback"
    mkdir -p "$XDG_DATA_HOME" "$SIEGE_FEEDBACK_DIR"

    local out code=0 start="$SECONDS"
    out="$(cap timeout -k 3 "$RUN_TIMEOUT" godot --headless --audio-driver Dummy \
        --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd -gexit "$@" 2>&1)" || code=$?
    local tests passing failing pending why=""
    tests="$(total_of Tests "$out")"
    passing="$(total_of "Passing Tests" "$out")"
    failing="$(total_of "Failing Tests" "$out")"
    pending="$(total_of "Risky/Pending" "$out")"
    if [[ "$code" -eq 124 || "$code" -eq 137 || "$code" -eq 143 ]]; then
        why="timed out or killed after ${RUN_TIMEOUT}s (exit $code)"
    elif grep -qE 'SCRIPT ERROR|Failing Tests' <<<"$out" || ((failing > 0)); then
        why="failing tests or a script error"
    elif ((code != 0)); then
        why="exit code $code"
    elif ((tests == 0)); then
        why="no tests ran"
    elif ((tests != passing + pending)); then
        why="tests $tests != passing $passing + pending $pending"
    fi
    local line="$tests tests, $passing pass, $failing fail, $pending pending, $((SECONDS - start))s"
    if [[ -n "$why" ]]; then
        echo "$out" | tail -60 >&2
        echo "test: FAILED ($why; $line)" >&2
        exit 1
    fi
    echo "test: green ($line)"
}

main "$@"
