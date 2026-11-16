#!/bin/bash

# ============================================================================
# Unit tests of the session recorder (tools/recording/, stdlib unittest, no
# window, no sound): timeline, moments, policy, encoder command, finalize,
# launcher.   scripts/test_recording.sh
# The Xvfb end-to-end run is scripts/e2e_recording.sh.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
    need python3 ffmpeg ffprobe
    cd "$REPO_ROOT"
    local out code=0
    out="$(cap timeout 50 python3 -I -m unittest discover -s tests/recording -t tests/recording \
        -p 'test_*.py' 2>&1)" || code=$?
    if ((code != 0)); then
        echo "$out" | tail -40 >&2
        echo "recording tests: FAILED (exit $code)" >&2
        exit 1
    fi
    echo "recording tests: $(echo "$out" | grep -E '^Ran ' | tail -1), OK"
}

main "$@"
