#!/bin/bash

# ============================================================================
# Render "a siege in 20 seconds" as one WAV: a scripted siege
# (tools/audio/demo_siege.gd) played through the game's own AudioDirector.
# Godot's Movie Maker mixes it offline into a file on a private Xvfb screen
# with the Dummy audio driver: nothing is played on this machine. ffmpeg then
# copies the PCM track out of the movie (no codec, no resampling).
#   tools/audio/demo.sh [out.wav]
# Default: ~/data/claude-scratch/fifteen-dollar-siege/audio/siege_in_20_seconds.wav
# Listen later:  mpv <out.wav>
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"

readonly SIZE="320x180"
DEFAULT_OUT="$(dirname "$SCRATCH")/audio/siege_in_20_seconds.wav"
readonly DEFAULT_OUT
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

main() {
    need godot Xvfb ffmpeg
    local out="${1:-$DEFAULT_OUT}" log
    mkdir -p "$SCRATCH" "$(dirname "$out")"
    TMP="$(mktemp -d "$SCRATCH/demo.XXXXXX")"
    trap cleanup EXIT
    log="$TMP/godot.log"
    # A throwaway user:// : the demo never reads or writes kuhy's save.
    export XDG_DATA_HOME="$TMP/xdg"
    mkdir -p "$XDG_DATA_HOME"
    cap timeout 55 "$REPO_ROOT/scripts/xvfb_run.sh" "$SIZE" \
        godot --audio-driver Dummy --path "$REPO_ROOT" --resolution "$SIZE" \
        --write-movie "$TMP/demo.avi" --fixed-fps 30 \
        -s tools/audio/demo_siege.gd >"$log" 2>&1 || {
        tail -n 20 "$log" >&2
        echo "demo: the scripted siege FAILED" >&2
        exit 1
    }
    if grep -q 'SCRIPT ERROR' "$log"; then
        grep -A3 'SCRIPT ERROR' "$log" | head -20 >&2
        exit 1
    fi
    ffmpeg -v error -y -i "$TMP/demo.avi" -vn -c:a pcm_s16le "$out"
    echo "demo: $out ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out") s)"
}

main "$@"
