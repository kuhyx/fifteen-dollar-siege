#!/bin/bash

# ============================================================================
# The browser smoke gate: exports the Web preset into a temp dir, serves it on
# a loopback port chosen at runtime and plays it in an ISOLATED headless
# Chromium (own temp profile, muted, never your browser, never display :0).
# Passes only when the game really runs: the hub is drawn, the console shows no
# error, a first touch starts the sound (audio context running, hub music
# playing and advancing), and touch taps reach the shop and then a battle whose
# music plays. Frames land in $SCRATCH/shots/web and must not be blank.
#   scripts/test_web.sh        about 25 s (export 6 s, browser 15 s)
# Needs Chromium and the venv of tools/web/venv.sh (install.sh makes both).
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
hold_build_lock "$0" "$@"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

TMP=""

# Removes the temp dir and any browser still running on its profile.
cleanup() {
    [[ -z "$TMP" ]] || pkill -f -- "--user-data-dir=$TMP/profile" 2>/dev/null || true
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

main() {
    need godot
    local python shots web code=0
    python="$("$REPO_ROOT/tools/web/venv.sh")"
    shots="$SCRATCH/shots/web"
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/web.XXXXXX")"
    trap cleanup EXIT
    web="$TMP/web"
    "$REPO_ROOT/scripts/export.sh" web "$web"
    rm -rf "$shots"
    CAP_MEM=4G CAP_CPU_PCT=20 SIEGE_WEB_PROFILE="$TMP/profile" \
        cap timeout -k 3 50 "$python" "$REPO_ROOT/tools/web/smoke.py" "$web" "$shots" || code=$?
    if ((code != 0)); then
        echo "web: FAILED (exit $code; frames in $shots)" >&2
        exit 1
    fi
    frames_ok "$shots"/*.png >/dev/null || {
        echo "web: FAILED (a frame is blank; $shots)" >&2
        exit 1
    }
    echo "web: PASS $(du -sh "$web" | cut -f1) export, frames in $shots"
}

main "$@"
