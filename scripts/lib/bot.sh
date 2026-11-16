#!/bin/bash

# ============================================================================
# Running and judging the --autodrive bot (sourced after common.sh). Every bot
# run is muted, on a private Xvfb screen, on a fixed 1/60 s frame step and
# under a hard wall-clock limit; a run passes only on the bot's own verdict.
# ============================================================================

# Engine flags of every bot run: muted, a fixed 1/60 s step per frame (game
# time never depends on how loaded the machine is), no vsync wait.
readonly BOT_ENGINE_FLAGS=(--audio-driver Dummy --fixed-fps 60 --disable-vsync)

# Frames the bot saves in one full run of a mode (one per beat; a missing beat
# fails the gate). Keep in step with src/autodrive/autodrive.gd.
bot_frames() {
    case "$1" in
        watch) echo 12 ;;
        command) echo 14 ;;
        lab) echo 7 ;;
        showcase) echo 21 ;;
        *)
            echo "Error: unknown mode '$1' (watch, command, lab or showcase)" >&2
            return 2
            ;;
    esac
}

# Runs the bot once on a private Xvfb screen of `size`. Writes the log and the
# bot's verdict file; returns the run's exit code (judge it with bot_judge).
# BOT_HEADLESS=1 (CI: no display, no GL) runs it with --headless instead: the
# same clicks and asserts, but no frame is drawn or saved.
#   bot_run <size> <limit_s> <log> <result_file> <save_dir> <mode> [game args...]
bot_run() {
    local size="$1" limit="$2" log="$3" result="$4" save="$5" mode="$6" code=0
    shift 6
    mkdir -p "$(dirname "$log")"
    rm -rf "$save" "$result"
    local launch=("$REPO_ROOT/scripts/xvfb_run.sh" "$size" godot --resolution "$size")
    local window=("--expect-window=$size")
    if [[ "${BOT_HEADLESS:-0}" == 1 ]]; then
        launch=(godot --headless)
        window=()
    fi
    cap timeout -k 3 "$limit" "${launch[@]}" "${BOT_ENGINE_FLAGS[@]}" --path "$REPO_ROOT" -- \
        "--autodrive=$mode" "--save-dir=$save" "--result-file=$result" \
        "${window[@]}" "$@" >"$log" 2>&1 || code=$?
    return "$code"
}

# Fail-closed verdict of one bot run. PASS needs ALL of: no timeout, no bot
# failure or script error in the log, the bot's own PASS verdict file, its
# RESULT line and exit code 0 (a nonzero code after the verdict is a crash on
# exit, never a wrapper's noise).
#   bot_judge <label> <exit_code> <log> <result_file>
bot_judge() {
    local label="$1" code="$2" log="$3" result="$4" why=""
    grep -E '^RESULT|AUTODRIVE FAIL|SCRIPT ERROR' "$log" | head -5 || true
    if [[ "$code" -eq 124 || "$code" -eq 137 ]]; then
        why="timed out"
    elif grep -qE 'AUTODRIVE FAIL|SCRIPT ERROR' "$log"; then
        why="the bot reported a failure"
    elif ! grep -q '^PASS' "$result" 2>/dev/null; then
        why="no PASS verdict file"
    elif ! grep -q '^RESULT autodrive PASS' "$log"; then
        why="no RESULT autodrive PASS line"
    elif [[ "$code" -ne 0 ]]; then
        why="exit code $code despite the PASS verdict"
    fi
    if [[ -n "$why" ]]; then
        echo "$label: FAILED ($why; exit $code, log $log)" >&2
        return 1
    fi
    return 0
}

# Fails closed unless every PNG given is a readable, non-blank frame.
#   frames_ok <png...>
frames_ok() {
    cap timeout 30 godot --headless --path "$REPO_ROOT" --script tools/frame_check.gd -- "$@"
}
