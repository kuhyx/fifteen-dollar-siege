#!/bin/bash

# ============================================================================
# What EVERY windowed launcher needs (sourced after common.sh): the host GL
# fallback, the class-cache refresh and the session recorder. A new launcher
# calls all three; a launcher that skips the GL fallback crashes on kuhy's
# machine after an NVIDIA driver upgrade (build-game lesson L2).
# ============================================================================

# shellcheck source=scripts/lib/recording.sh
source "$(dirname "${BASH_SOURCE[0]}")/recording.sh"

# After an NVIDIA driver upgrade the new userspace libraries no longer match
# the still-loaded kernel module until a reboot, and no OpenGL context can be
# made at all. Probe once; if GPU GL is dead, use Mesa's software renderer so
# the game still starts (slow, but playable for a quick look).
use_mesa_if_gl_broken() {
    command -v glxinfo >/dev/null || return 0
    timeout 10 glxinfo -B >/dev/null 2>&1 && return 0
    echo "$REPO_NAME: GPU OpenGL unavailable, using Mesa software rendering (reboot after a driver upgrade)" >&2
    export __GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
}

# ----------------------------------------------------------------------------
# Godot's global class cache (.godot/global_script_class_cache.cfg) is only
# rebuilt by an import. After a pull or merge brings a new class_name, a plain
# run fails with 'Could not find type "X"' until someone imports (lesson L5).
# These helpers refresh it first and spawn Godot ONLY when the cache is
# actually behind the tree (a grep and an awk otherwise).
# ----------------------------------------------------------------------------

readonly CLASS_CACHE_REL=".godot/global_script_class_cache.cfg"
# Folders Godot does not scan for scripts.
readonly CLASS_CACHE_PRUNE=(-name .godot -o -name builds -o -name .claude -o -name .git)

# "Name res://path" per class_name script of the tree, sorted.
_class_cache_tree() {
    local root="$1"
    (cd "$root" &&
        find . \( "${CLASS_CACHE_PRUNE[@]}" \) -prune -o \
            -name '*.gd' -type f -exec grep -HoE -m1 '^class_name[[:space:]]+[A-Za-z0-9_]+' {} + |
        sed -E 's#^\./([^:]*):class_name[[:space:]]+(.*)$#\2 res://\1#' | sort) || true
}

# The same list as the cache file records it.
_class_cache_listed() {
    awk -F'"' '/"class":/ {c = $4} /"path":/ {print c, $4}' "$1" | sort
}

# True (0) when the cache is missing, lists different classes than the tree,
# or a class script is newer than it. Says why on stderr.
class_cache_stale() {
    local root="${1:-$REPO_ROOT}" cache newer
    cache="$root/$CLASS_CACHE_REL"
    if [[ ! -f "$cache" ]]; then
        echo "class cache: missing" >&2
        return 0
    fi
    if ! diff <(_class_cache_listed "$cache") <(_class_cache_tree "$root") >/dev/null; then
        echo "class cache: class_name set differs from the tree" >&2
        return 0
    fi
    newer="$(cd "$root" && find . \( "${CLASS_CACHE_PRUNE[@]}" \) -prune -o \
        -name '*.gd' -type f -newer "$CLASS_CACHE_REL" \
        -exec grep -lE '^class_name[[:space:]]' {} + | head -1)" || true
    if [[ -n "$newer" ]]; then
        echo "class cache: older than $newer" >&2
        return 0
    fi
    return 1
}

# Imports (headless, bounded) when the cache is stale; no-op when fresh.
refresh_class_cache() {
    local root="${1:-$REPO_ROOT}"
    class_cache_stale "$root" || return 0
    echo "class cache is stale: running godot --import first" >&2
    timeout 50 godot --headless --path "$root" --import >/dev/null 2>&1 || true
    # Import may leave the file as is when nothing changed; keep the mtime check quiet.
    [[ ! -f "$root/$CLASS_CACHE_REL" ]] || touch "$root/$CLASS_CACHE_REL"
    if class_cache_stale "$root"; then
        echo "class cache: still stale after import (see above)" >&2
    fi
}

# Runs a game command under the session recorder (game_recording from kuhyx/utils,
# configured in tools/recording/): kuhy's
# own dev play is recorded beside the game (window + audio); bot, test, muted
# and headless runs pass straight through. Returns the game's exit code.
#   record_wrap <session-id> <command...>
# SIEGE_RECORD_AUDIO picks the audio source (default|lavfi|<pulse source>): the e2e gate
# records silence instead of the live audio server.
record_wrap() {
    local session="$1" tool
    shift
    for tool in python3 ffmpeg xdotool; do
        command -v "$tool" >/dev/null || {
            echo "record: $tool missing (run ./install.sh), playing without a recording" >&2
            "$@"
            return
        }
    done
    local python
    python="$(recording_python)" || {
        echo "record: the recorder venv failed (run ./install.sh), playing without a recording" >&2
        "$@"
        return
    }
    "$python" -I "$SIEGE_RECORDING_PY" wrap --audio "${SIEGE_RECORD_AUDIO:-default}" --session "$session" -- "$@"
}
