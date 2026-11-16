#!/bin/bash

# ============================================================================
# Runs one command on a private Xvfb screen and returns the COMMAND's exit
# code (never the server's). Unlike `xvfb-run -a`, the display number comes from
# Xvfb itself (-displayfd), so several runs may start at once, from one gate or
# from sibling checkouts, without racing for the same display.
#   scripts/xvfb_run.sh <WxH> <command> [args...]
# Never touches the live display.
# ============================================================================

set -euo pipefail

readonly START_WAIT_TICKS=200 # x 0.05 s
XVFB_PID=""
TMP=""

# shellcheck disable=SC2329  # runs from the EXIT trap
cleanup() {
    [[ -z "$XVFB_PID" ]] || kill "$XVFB_PID" 2>/dev/null || true
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

main() {
    if [[ $# -lt 2 ]]; then
        echo "usage: $0 <WxH> <command> [args...]" >&2
        exit 2
    fi
    local size="$1" code=0 tick
    shift
    TMP="$(mktemp -d)"
    trap cleanup EXIT
    Xvfb -displayfd 3 -screen 0 "${size}x24" -nolisten tcp 3>"$TMP/display" 2>/dev/null &
    XVFB_PID=$!
    for ((tick = 0; tick < START_WAIT_TICKS; tick++)); do
        [[ -s "$TMP/display" ]] && break
        kill -0 "$XVFB_PID" 2>/dev/null || break
        sleep 0.05
    done
    if [[ ! -s "$TMP/display" ]]; then
        echo "Error: Xvfb did not start" >&2
        exit 3
    fi
    DISPLAY=":$(tr -d '[:space:]' <"$TMP/display")" "$@" || code=$?
    exit "$code"
}

main "$@"
