#!/bin/bash

# ============================================================================
# Proves scripts/build_round.sh in a throwaway builds folder (never kuhy's
# builds/): bad arguments are refused, a round writes index.html, the Linux
# binary and one NOTES line, and a second call for the same round refuses and
# changes nothing. About 15 s (two exports).
#   scripts/test_build_round.sh
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

TMP=""
readonly ROUND="$REPO_ROOT/scripts/build_round.sh"

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "build_round: FAILED ($1)" >&2
    exit 1
}

# The call must exit with `want`; its message goes to the log for the reader.
expect_exit() {
    local want="$1" what="$2" code=0
    shift 2
    "$ROUND" "$@" >"$TMP/out.txt" 2>&1 || code=$?
    [[ "$code" -eq "$want" ]] || {
        cat "$TMP/out.txt" >&2
        fail "$what: exit $code, wanted $want"
    }
}

main() {
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/round.XXXXXX")"
    trap cleanup EXIT
    export SIEGE_BUILDS="$TMP/builds"
    mkdir -p "$SIEGE_BUILDS/v07"
    echo keep >"$SIEGE_BUILDS/v07/sentinel"

    expect_exit 2 "no arguments"
    expect_exit 2 "a round without two digits" 7 "a note"
    expect_exit 2 "a round that is not a number" ab "a note"
    expect_exit 2 "an empty note" 08 ""
    expect_exit 1 "a round that exists" 07 "a note"
    [[ "$(cat "$SIEGE_BUILDS/v07/sentinel")" == keep && "$(ls "$SIEGE_BUILDS/v07")" == sentinel ]] ||
        fail "an existing round was touched"

    expect_exit 0 "a new round" 08 "first test round"
    local dir="$SIEGE_BUILDS/v08"
    [[ -s "$dir/index.html" && -s "$dir/index.pck" && -s "$dir/index.wasm" ]] || fail "no web export in $dir"
    [[ -x "$dir/linux/fifteen-dollar-siege.x86_64" ]] || fail "no Linux binary in $dir/linux"
    [[ "$(wc -l <"$dir/NOTES")" -eq 1 ]] || fail "NOTES is not one line"
    grep -q 'first test round' "$dir/NOTES" || fail "NOTES lacks the note"
    [[ -z "$(find "$SIEGE_BUILDS" -maxdepth 1 -name '*partial*')" ]] || fail "a partial folder is left behind"

    local before
    before="$(find "$dir" -type f -printf '%p %s %T@\n' | sort | sha256sum)"
    expect_exit 1 "the same round again" 08 "second try"
    [[ "$before" == "$(find "$dir" -type f -printf '%p %s %T@\n' | sort | sha256sum)" ]] ||
        fail "a second call changed round 08"
    echo "build_round: PASS (refuses bad arguments and existing rounds; v08 has web, linux, NOTES)"
}

main "$@"
