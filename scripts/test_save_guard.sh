#!/bin/bash

# ============================================================================
# Proves a GUT run cannot touch the player's real save even WITHOUT the
# pre-run hook's redirect (build-game lesson L10: a hook is skippable). GUT
# runs with tests/no_redirect_hook.gd in place of tests/pre_run.gd, against an
# XDG_DATA_HOME that holds a planted real-looking save. Green only when
# tests/test_save_guard.gd passes (the probe included) and every planted file
# is byte-identical afterwards with nothing added.
#   scripts/test_save_guard.sh
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

# A listing of every file under $1 with its hash, for a before/after compare.
snapshot() {
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum)
}

main() {
    need godot
    need_gut
    cd "$REPO_ROOT"
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/guard.XXXXXX")"
    trap cleanup EXIT
    # Never the player's data home: this run only ever sees the throwaway one.
    export XDG_DATA_HOME="$TMP/xdg"
    export SIEGE_FEEDBACK_DIR="$TMP/feedback"
    export SIEGE_SAVE_GUARD_PROBE=1
    local real="$XDG_DATA_HOME/godot/app_userdata/$REPO_NAME/save"
    mkdir -p "$real" "$SIEGE_FEEDBACK_DIR"
    printf '{"watch":["double_men","fifty_men"]}' >"$real/last_loadout.json"
    printf '{"planted":true}' >"$real/other.json"
    local before
    before="$(snapshot "$real")"

    local out code=0
    out="$(cap timeout 50 godot --headless --audio-driver Dummy --path . \
        -s addons/gut/gut_cmdln.gd -gexit \
        -gpre_run_script=res://tests/no_redirect_hook.gd \
        -gselect=test_save_guard 2>&1)" || code=$?
    echo "$out" | grep -E '^(Tests|Passing Tests|Failing Tests|Risky/Pending)|SCRIPT ERROR' || true
    if ((code != 0)) || grep -qE 'SCRIPT ERROR|Failing Tests' <<<"$out"; then
        echo "$out" | tail -30 >&2
        echo "save guard: GUT FAILED (exit $code)" >&2
        exit 1
    fi
    if grep -qE '^Risky/Pending' <<<"$out"; then
        echo "save guard: the probe did not run (pending)" >&2
        exit 1
    fi
    if [[ "$(snapshot "$real")" != "$before" ]]; then
        echo "save guard: the real save changed" >&2
        diff <(echo "$before") <(snapshot "$real") >&2 || true
        exit 1
    fi
    echo "save guard: green"
}

main "$@"
