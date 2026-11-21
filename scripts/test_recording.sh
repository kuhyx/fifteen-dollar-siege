#!/bin/bash

# ============================================================================
# Tests of this game's side of the session recorder (the recorder itself is the
# game_recording package of kuhyx/utils and is tested there): the pinned
# requirement line and its local-proof overrides, then the unittest tree
# tests/recording (the game's configuration: names, moment map, entry point),
# run by the recorder venv's python. No window, no sound.
#   scripts/test_recording.sh
# The Xvfb end-to-end run is scripts/e2e_recording.sh.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/recording.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/recording.sh"

readonly PINNED='game_recording @ git+https://github.com/kuhyx/utils@game-recording-v0.1.1#subdirectory=game_recording'
readonly BUILD="$REPO_ROOT/tools/recording/build.sh"

fail() {
    echo "recording tests: FAILED, $1" >&2
    exit 1
}

# Unset overrides resolve to exactly the pinned GitHub line; set ones swap the
# remote and the ref, nothing else.
test_pin() {
    local got
    got="$(env -u SIEGE_UTILS_REMOTE -u SIEGE_UTILS_RECORDING_REF "$BUILD" --print-requirement)"
    [[ "$got" == "$PINNED" ]] || fail "the default requirement is '$got', not the pinned line"
    grep -qxF "$PINNED" "$REPO_ROOT/tools/recording/requirements.txt" || fail "requirements.txt lost the pinned line"
    got="$(SIEGE_UTILS_REMOTE=file:///utils SIEGE_UTILS_RECORDING_REF=abc123 "$BUILD" --print-requirement)"
    [[ "$got" == 'game_recording @ git+file:///utils@abc123#subdirectory=game_recording' ]] ||
        fail "the override requirement is '$got'"
}

main() {
    need python3 ffmpeg ffprobe
    cd "$REPO_ROOT"
    test_pin
    local python out code=0
    python="$(recording_python)"
    out="$(cap timeout 50 "$python" -I -m unittest discover -s tests/recording -t tests/recording \
        -p 'test_*.py' 2>&1)" || code=$?
    if ((code != 0)); then
        echo "$out" | tail -40 >&2
        echo "recording tests: FAILED (exit $code)" >&2
        exit 1
    fi
    echo "recording tests: pin ok, $(echo "$out" | grep -E '^Ran ' | tail -1), OK"
}

main "$@"
