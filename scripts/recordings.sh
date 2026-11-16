#!/bin/bash

# ============================================================================
# kuhy's recordings: list the moments of a session recording and open it
# (mpv, on YOUR display) at one of them.
#   scripts/recordings.sh latest [--session ID]   moments of the newest recording
#   scripts/recordings.sh list                    every recording, newest first
#   scripts/recordings.sh open [N] [--session ID] mpv at moment N (3 s before it);
#                                                 no N = from the start; --dry-run prints
# Recordings: ~/data/fifteen-dollar-siege_binaries/feedback/recordings/<session>.mkv
# (+ .events.json). `--dir D` reads another folder. The recorder is the
# game_recording package of kuhyx/utils; its settings for this game: tools/recording/.
# Agents only ever pass --dry-run to `open`.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/recording.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/recording.sh"

main() {
    need python3
    local cmd="${1:-latest}"
    [[ $# -eq 0 ]] || shift
    case "$cmd" in
        latest | list | open) siege_recording "$cmd" "$@" ;;
        *)
            echo "usage: recordings.sh latest|list|open [N] [--session ID] [--dry-run]" >&2
            exit 2
            ;;
    esac
}

main "$@"
