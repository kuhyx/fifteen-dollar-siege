#!/bin/bash

# ============================================================================
# Screenshot every autodrive beat of one mode under Xvfb (never the live
# display) and fail closed if a frame is missing, unreadable or blank.
#   scripts/screenshot.sh <out_dir> [mode] [WxH]   (default: watch 1920x1080)
# Frames land in <out_dir>/NN_<beat>.png. Copy one before Reading it: a hook
# downscales files in place.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

RUN_DIR=""

# Keeps the run directory (log, verdict) only when something failed.
finish() {
    local code=$?
    if [[ "$code" -eq 0 ]]; then
        rm -rf "$RUN_DIR"
    else
        echo "screenshot: logs kept in $RUN_DIR" >&2
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        echo "usage: $0 <out_dir> [watch|command|lab] [WxH]" >&2
        exit 2
    fi
    need godot Xvfb
    refresh_class_cache
    local out mode="${2:-watch}" size="${3:-1920x1080}" want
    want="$(bot_frames "$mode")"
    out="$(realpath -m "$1")"
    mkdir -p "$out" "$SCRATCH"
    rm -f "$out"/*.png
    # Save dir, log and verdict of this run live in a directory of its own, so
    # neither the bot nor the frame check touches the real user://.
    RUN_DIR="$(mktemp -d "$SCRATCH/run.XXXXXX")"
    trap finish EXIT
    local log="$RUN_DIR/log.txt" result="$RUN_DIR/result" code=0 shots=()
    bot_run "$size" 45 "$log" "$result" "$RUN_DIR/save" "$mode" \
        "--speed=${BOT_SPEED:-16}" "--seed=7" "--lab-runs=30" "--screenshot-dir=$out" || code=$?
    bot_judge "screenshot $mode" "$code" "$log" "$result" || exit 1
    mapfile -t shots < <(find "$out" -maxdepth 1 -name '*.png' | sort)
    if [[ ${#shots[@]} -ne "$want" ]]; then
        echo "screenshot: ${#shots[@]} frames, expected $want" >&2
        exit 1
    fi
    frames_ok "${shots[@]}"
    echo "screenshot: ${#shots[@]} frames ok in $out"
}

main "$@"
