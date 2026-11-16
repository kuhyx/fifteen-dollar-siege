#!/bin/bash

# ============================================================================
# End-to-end proof of the session recorder on a private Xvfb, muted (the game
# runs with --audio-driver Dummy; the recorder's audio is ffmpeg's silent
# lavfi source unless E2E_AUDIO=null-sink asks for a PulseAudio null sink).
# Never touches the live display or plays anything.
#   sync  (policy as in kuhy's play: no --force) a stand-in game flips its window black/white at known unix times; the
#         flips found in the recorded frames must sit where events.json says,
#         within one frame (tests/recording/flasher.py, e2e_check.py sync)
#   gap   the game window is unmapped for 2 s (an i3 workspace switch): the
#         recorder restarts into a second part on the same timeline (gap_driver.sh)
#   launcher  run.sh's own record_wrap around the stand-in game: a bundle with its
#         moments and chapters comes out (tests/recording/launcher_driver.sh)
#   game  the real game, --autodrive=watch for ~10 s (--max-seconds), recorded with
#         --force (bots are never recorded otherwise); ffprobe shows a video
#         stream at the window size and an audio stream, the moments sit inside
#         the file and become chapters (e2e_check.py game)
#   scripts/e2e_recording.sh [never|sync|gap|launcher|game|all]   (one case per call
#   for an agent: each is under 60 s, `all` is not). KEEP=1 keeps the temp dir.
# gpu-screen-recorder cannot run under Xvfb, so this proves the x11grab path.
# The recorder is the game_recording package of kuhyx/utils (tools/recording/build.sh).
# Needs: Xvfb, ffmpeg/ffprobe, xdotool, xprop, jq, tkinter (sync and gap).
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/recording.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/recording.sh"

readonly SIZE=1280x720
readonly CHECK="$REPO_ROOT/tests/recording/e2e_check.py"
TMP=""
REC_PY=""
SINK_MODULE=""
AUDIO=lavfi

cleanup() {
    [[ -z "$SINK_MODULE" ]] || pactl unload-module "$SINK_MODULE" 2>/dev/null || true
    if [[ -n "${KEEP:-}" ]]; then
        echo "e2e_recording: kept $TMP"
    else
        [[ -z "$TMP" ]] || rm -rf "$TMP"
    fi
}

# The audio source: silent lavfi by default (the live audio server is never
# touched); E2E_AUDIO=null-sink records from a throwaway PulseAudio null sink.
setup_audio() {
    local name="siege_rec_test_$$"
    if [[ "${E2E_AUDIO:-lavfi}" == null-sink ]] && command -v pactl >/dev/null &&
        SINK_MODULE="$(pactl load-module module-null-sink "sink_name=$name" 2>/dev/null)"; then
        AUDIO="$name.monitor"
    else
        SINK_MODULE=""
    fi
    echo "e2e_recording: audio source $AUDIO"
}

# Under capped.sh's 10 % CPU scope the software-rendered game would starve a niced ffmpeg.
export SIEGE_RECORDER_NICE=0
# gpu-screen-recorder cannot run under Xvfb (no GPU GL): this proves the x11grab fallback at 30 fps.
export SIEGE_RECORDER_BACKEND=x11grab

# wrap <session> <limit_s> [wrap flags] -- <game command>; FORCE=1 records bots too.
wrap() {
    local session="$1" limit="$2" force=()
    shift 2
    [[ "${FORCE:-0}" != 1 ]] || force=(--force)
    # Xvfb + a software-rendered game + ffmpeg need more than the default 10 % CPU cap.
    CAP_MEM=4G CAP_CPU_PCT=20 cap timeout -k 3 "$limit" "$REPO_ROOT/scripts/xvfb_run.sh" "$SIZE" \
        "$REC_PY" -I "$SIEGE_RECORDING_PY" wrap "${force[@]}" --audio "$AUDIO" --session "$session" "$@"
}

# Bot-marked and headless runs must pass through without a recording.
test_never() {
    local session="e2e-never-$$" fb="$TMP/never" cmd
    for cmd in "--dev --autodrive=watch" "--dev --save-dir=$TMP/s" "--dev --result-file=$TMP/r"; do
        # shellcheck disable=SC2086  # the words of $cmd are separate arguments
        wrap "$session" 20 -- python3 -c pass $cmd "--feedback-dir=$fb"
    done
    wrap "$session" 20 -- python3 -c pass "--feedback-dir=$fb" # no --dev
    [[ ! -e "$fb/recordings" ]] || { echo "e2e_recording: a bot run was recorded" >&2; exit 1; }
    echo "e2e_recording: bot, test and non-dev runs pass through unrecorded"
}

test_sync() {
    local session="e2e-sync-$$" fb="$TMP/sync"
    wrap "$session" 40 -- python3 "$REPO_ROOT/tests/recording/flasher.py" \
        --dev "--session-id=$session" "--feedback-dir=$fb"
    python3 -I "$CHECK" sync "$fb/recordings" "$session" "$fb/truth.json"
}

# The window is unmapped for 2 s mid-run (workspace switch): ffmpeg's x11grab dies
# there and the recorder must carry on with a second part.
test_gap() {
    local session="e2e-gap-$$" fb="$TMP/gap"
    CAP_MEM=4G CAP_CPU_PCT=20 cap timeout -k 3 50 "$REPO_ROOT/scripts/xvfb_run.sh" "$SIZE" \
        "$REPO_ROOT/tests/recording/gap_driver.sh" "$session" "$fb" "$AUDIO"
    python3 -I "$CHECK" gap "$fb/recordings" "$session" "$fb/truth.json"
}

# The launcher's own path (record_wrap, as run.sh calls it) around the stand-in
# game: venv, wrap, policy and finalize must still end in a bundle with moments.
test_launcher() {
    local session="e2e-launch-$$" fb="$TMP/launch"
    SIEGE_RECORD_AUDIO="$AUDIO" CAP_MEM=4G CAP_CPU_PCT=20 cap timeout -k 3 50 "$REPO_ROOT/scripts/xvfb_run.sh" "$SIZE" \
        "$REPO_ROOT/tests/recording/launcher_driver.sh" "$session" "$fb"
    python3 -I "$CHECK" launcher "$fb/recordings" "$session" "$fb/truth.json"
}

test_game() {
    local session="e2e-game-$$" fb="$TMP/game" code=0
    FORCE=1 wrap "$session" 50 --max-seconds 10 -- godot --audio-driver Dummy --max-fps 60 \
        --resolution "$SIZE" --path "$REPO_ROOT" -- --dev --autodrive=watch --speed=2 --seed=7 \
        "--save-dir=$TMP/save" "--result-file=$TMP/result" "--feedback-dir=$fb" \
        >"$TMP/game.log" || code=$?
    echo "e2e_recording: game exit $code (SIGTERM at the time limit is expected)"
    python3 -I "$CHECK" game "$fb/recordings" "$session" "$SIZE"
    ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,start_time \
        -of csv=p=0 "$fb/recordings/$session.mkv"
    "$REPO_ROOT/scripts/recordings.sh" latest --dir "$fb/recordings" | head -12
    "$REPO_ROOT/scripts/recordings.sh" open 1 --dir "$fb/recordings" --dry-run
}

main() {
    need Xvfb ffmpeg ffprobe xdotool xprop python3 jq
    REC_PY="$(recording_python)"
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/e2e.XXXXXX")"
    trap cleanup EXIT
    setup_audio
    case "${1:-all}" in
        never) test_never ;;
        sync) test_sync ;;
        gap) test_gap ;;
        launcher) test_launcher ;;
        game) test_game ;;
        all)
            test_never
            test_sync
            test_gap
            test_launcher
            test_game
            ;;
        *)
            echo "usage: e2e_recording.sh [never|sync|gap|launcher|game|all]" >&2
            exit 2
            ;;
    esac
    echo "e2e_recording: PASS"
}

main "$@"
