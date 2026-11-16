#!/bin/bash

# ============================================================================
# kuhy's windowed run: a real window, sound on, dev feedback mode on (--dev:
# F12 annotates the frame), the session recorded (game_recording from kuhyx/utils,
# set up in tools/recording/).
#   ./run.sh [game args]     e.g. ./run.sh --mode=watch --loadout=double_men
# Agents never run this on the live display: they use scripts/autodrive_all.sh
# (muted, Xvfb). SIEGE_ENGINE_ARGS adds engine flags before `--` (the launcher
# test passes "--audio-driver Dummy" under its own Xvfb).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$REPO_ROOT/scripts/lib/launch.sh"

main() {
    need godot
    use_mesa_if_gl_broken
    # A pull may have brought a new class_name: refresh Godot's class cache
    # first (only spawns Godot when the cache is behind the tree).
    refresh_class_cache "$REPO_ROOT"
    local engine_args=()
    read -r -a engine_args <<<"${SIEGE_ENGINE_ARGS:-}"
    local game=(godot "${engine_args[@]}" --path "$REPO_ROOT" -- --dev "$@")
    # The recorder decides by itself: only a windowed dev run with sound is recorded.
    record_wrap "$(date +%s)-run-$RANDOM" "${game[@]}"
}

main "$@"
