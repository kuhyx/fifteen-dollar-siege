#!/bin/bash

# ============================================================================
# The done gate: the --autodrive bot plays the REAL main scene under Xvfb,
# muted, once per mode (watch, command, lab). Each run buys a legal loadout
# through the real buttons, plays to the result once to WIN and once to LOSE,
# presses Esc and asserts the pause menu, and saves a frame at every beat.
# `showcase` feeds the battle screen scripted snapshots instead: every kind,
# state, look and event at once (no real siege shows them all), plus the 2,400-figure
# frame gate. `touch` plays hub -> shop -> buy -> go -> battle (rally flag,
# speed, pause, resume) -> result -> again with ONLY touch events (R17).
# The modes run in parallel (own Xvfb, save dir and log each) on a fixed
# 1/60 s frame step: the bot's waits count frames, so load only slows the run.
# Exit 0 only if every mode has the bot's PASS verdict (bot_judge) and every
# frame it saved is readable and not blank (fail closed).
#   scripts/autodrive_all.sh [mode ...]     default: watch command lab showcase touch
#   BOT_SIZE=1280x720   window size (default 1920x1080)
#   BOT_SPEED=16        sim seconds per second
#   GATE_MAX_S=40       also fail when the whole gate took longer
#   BOT_HEADLESS=1      no display (CI): the same asserts, no frames
# Never touches the live display; godot runs with --audio-driver Dummy (the
# flags live in scripts/lib/bot.sh). Whole script < 60 s; one mode per call if
# the machine is very busy.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

readonly ALL_MODES=(watch command lab showcase touch)
readonly RUN_TIMEOUT="${RUN_TIMEOUT:-45}"
readonly SIZE="${BOT_SIZE:-1920x1080}"
readonly SPEED="${BOT_SPEED:-16}"
readonly SHOT_ROOT="${SHOT_ROOT:-$SCRATCH/shots}"

# Everything one run writes (bot save dir, log, verdict, frames) lives in ONE
# directory of its own, so two gates at once (two checkouts, a stuck earlier
# run, the modes of this one) can never read each other's saves or verdicts.
RUN_DIR=""

# One mode: prints the bot's RESULT/FAIL lines, returns non-zero on failure.
run_mode() {
    local mode="$1" code=0 dir="$RUN_DIR/$1" shots=() want
    want="$(bot_frames "$mode")" || return 1
    mkdir -p "$dir/shots"
    bot_run "$SIZE" "$RUN_TIMEOUT" "$dir/log.txt" "$dir/result" "$dir/save" "$mode" \
        "--speed=$SPEED" "--seed=7" "--lab-runs=30" "--screenshot-dir=$dir/shots" || code=$?
    bot_judge "autodrive $mode" "$code" "$dir/log.txt" "$dir/result" || return 1
    if [[ "${BOT_HEADLESS:-0}" == 1 ]]; then
        echo "autodrive $mode: PASS (headless: asserts only, no frames)"
        return 0
    fi
    mapfile -t shots < <(find "$dir/shots" -maxdepth 1 -name '*.png' | sort)
    if [[ ${#shots[@]} -ne "$want" ]]; then
        echo "autodrive $mode: FAILED (${#shots[@]} frames, expected $want)" >&2
        return 1
    fi
    if ! frames_ok "${shots[@]}" >"$dir/frames.txt" 2>&1; then
        cat "$dir/frames.txt" >&2
        echo "autodrive $mode: FAILED (a blank or unreadable frame)" >&2
        return 1
    fi
    mkdir -p "$SHOT_ROOT/$mode"
    rm -f "$SHOT_ROOT/$mode"/*.png
    cp "${shots[@]}" "$SHOT_ROOT/$mode/"
    echo "autodrive $mode: PASS (${#shots[@]} frames in $SHOT_ROOT/$mode)"
}

# Keeps the run directory (logs) only when something failed.
finish() {
    local code=$?
    if [[ "$code" -eq 0 ]]; then
        rm -rf "$RUN_DIR"
    else
        echo "autodrive: logs kept in $RUN_DIR" >&2
    fi
}

main() {
    need godot
    [[ "${BOT_HEADLESS:-0}" == 1 ]] || need Xvfb
    refresh_class_cache
    local modes=("$@") mode failed=0 pids=() pid
    [[ ${#modes[@]} -gt 0 ]] || modes=("${ALL_MODES[@]}")
    mkdir -p "$SCRATCH"
    RUN_DIR="$(mktemp -d "$SCRATCH/run.XXXXXX")"
    trap finish EXIT
    for mode in "${modes[@]}"; do
        run_mode "$mode" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done
    [[ "$failed" -eq 0 ]] || exit 1
    echo "autodrive: all ${#modes[@]} modes passed in ${SECONDS}s"
    if [[ -n "${GATE_MAX_S:-}" && "$SECONDS" -gt "$GATE_MAX_S" ]]; then
        echo "autodrive: over the ${GATE_MAX_S}s budget" >&2
        exit 1
    fi
}

main "$@"
