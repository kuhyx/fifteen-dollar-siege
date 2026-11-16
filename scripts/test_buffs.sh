#!/bin/bash

# ============================================================================
# The buffs gate: for each of the 25 buffs, a siege of that buff alone on the
# real battle screen (private Xvfb, muted) until every sign of it shows (its
# chip, figure, look, effect, men, audio cue; src/autodrive/buff_signs.gd), one
# frame per buff. The shards run side by side so the call stays under 60 s.
#   scripts/test_buffs.sh [out_dir]    frames land in out_dir/<shard>/
#   BUFF_SHARDS=4   number of shards   BOT_SIZE=1280x720   window size
# Exit 0 only when every shard has the bot's PASS verdict and every buff has
# its readable, non-blank frame.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
hold_build_lock "$0" "$@"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

readonly SHARDS="${BUFF_SHARDS:-5}"
readonly SIZE="${BOT_SIZE:-1280x720}"
readonly BUFFS=25
RUN_DIR=""

# One shard: runs the bot, judges it, checks its frames.
run_shard() {
    local shard="$1" dir="$RUN_DIR/$1" code=0 want=0 i shots=()
    mkdir -p "$dir/shots"
    bot_run "$SIZE" 50 "$dir/log.txt" "$dir/result" "$dir/save" buffs \
        "--shard=$shard/$SHARDS" "--screenshot-dir=$dir/shots" || code=$?
    bot_judge "buffs $shard/$SHARDS" "$code" "$dir/log.txt" "$dir/result" || return 1
    [[ "${BOT_HEADLESS:-0}" == 1 ]] && return 0
    for ((i = 0; i < BUFFS; i++)); do
        ((i % SHARDS == shard)) && want=$((want + 1))
    done
    mapfile -t shots < <(find "$dir/shots" -maxdepth 1 -name '*.png' | sort)
    if [[ ${#shots[@]} -ne "$want" ]]; then
        echo "buffs $shard/$SHARDS: ${#shots[@]} frames, expected $want" >&2
        return 1
    fi
    frames_ok "${shots[@]}" >"$dir/frames.txt" 2>&1 || {
        cat "$dir/frames.txt" >&2
        return 1
    }
    cp "${shots[@]}" "$OUT/"
}

finish() {
    local code=$?
    if [[ "$code" -eq 0 ]]; then
        rm -rf "$RUN_DIR"
    else
        echo "buffs: logs kept in $RUN_DIR" >&2
    fi
}

main() {
    need godot Xvfb
    refresh_class_cache
    mkdir -p "$SCRATCH"
    OUT="$(realpath -m "${1:-$SCRATCH/shots/buffs}")"
    rm -rf "$OUT"
    mkdir -p "$OUT"
    RUN_DIR="$(mktemp -d "$SCRATCH/buffs.XXXXXX")"
    trap finish EXIT
    local shard pids=() code=0 start="$SECONDS"
    for ((shard = 0; shard < SHARDS; shard++)); do
        run_shard "$shard" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || code=1
    done
    ((code == 0)) || exit 1
    echo "buffs: PASS ($(find "$OUT" -name '*.png' | wc -l) frames in $OUT, $((SECONDS - start))s)"
}

main "$@"
