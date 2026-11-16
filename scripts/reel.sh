#!/bin/bash

# ============================================================================
# Watch ONE real siege on a private Xvfb screen (muted, never the live
# display) and save a frame every few sim seconds, plus the payoff. For
# LOOKING at what the sim does on screen; not a gate.
#   scripts/reel.sh <out_dir> <id,id,...|-> <seed> [every_s] [WxH] [mode] [speed]
# `-` buys nothing. Defaults: every 5 s, 1280x720, watch, speed 16.
# Prints one REEL line per frame (clock, alarm, morale, hold).
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

RUN=""

main() {
    if [[ $# -lt 3 ]]; then
        echo "usage: $0 <out_dir> <id,id|-> <seed> [every_s] [WxH] [mode] [speed]" >&2
        exit 2
    fi
    need godot Xvfb
    refresh_class_cache
    local out ids="$2" seed="$3" every="${4:-5}" size="${5:-1280x720}"
    local mode="${6:-watch}" speed="${7:-16}" code=0
    [[ "$ids" != "-" ]] || ids=""
    out="$(realpath -m "$1")"
    mkdir -p "$out" "$SCRATCH"
    rm -f "$out"/*.png
    RUN="$(mktemp -d "$SCRATCH/reel.XXXXXX")"
    trap 'rm -rf "$RUN"' EXIT
    bot_run "$size" 55 "$RUN/log.txt" "$RUN/result" "$RUN/save" reel \
        "--mode=$mode" "--loadout=$ids" "--seed=$seed" "--speed=$speed" "--every=$every" \
        "--screenshot-dir=$out" || code=$?
    grep -E '^REEL' "$RUN/log.txt" || true
    bot_judge "reel" "$code" "$RUN/log.txt" "$RUN/result"
    echo "reel: $(find "$out" -name '*.png' | wc -l) frames in $out"
}

main "$@"
