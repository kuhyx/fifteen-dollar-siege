#!/bin/bash

# ============================================================================
# The audio gate of scripts/check.sh, a few seconds, nothing is rendered and
# nothing is played:
#   - unit tests of the audio tools (tests/audio/test_*.py): the offline gate
#     is red on every fault it names
#   - ruff on tests/audio (scripts/lint.sh covers tools/)
#   - the rendered files are current with this code (render.py --check)
#   - the offline gate over every rendered file (analyze.py)
#   tools/audio/check.sh
# Stale or missing audio: run tools/audio/build.sh (or ./install.sh).
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"

readonly AUDIO_TOOLS="$REPO_ROOT/tools/audio"
readonly VENV="${SIEGE_AUDIO_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/$REPO_NAME/audio-venv}"
readonly OUT="${SIEGE_AUDIO_DIR:-$REPO_ROOT/assets/audio}"

main() {
    need ruff
    local python="$VENV/bin/python" out code=0
    [[ -x "$python" ]] || {
        echo "Error: the audio venv is missing (run ./install.sh)" >&2
        exit 1
    }
    cd "$REPO_ROOT"
    out="$(cap timeout 50 "$python" -I -m unittest discover -s tests/audio -t tests/audio \
        -p 'test_*.py' 2>&1)" || code=$?
    if ((code != 0)); then
        echo "$out" | tail -40 >&2
        echo "audio tool tests: FAILED (exit $code)" >&2
        exit 1
    fi
    echo "audio tool tests: $(echo "$out" | grep -E '^Ran ' | tail -1), OK"
    ruff check --quiet tests/audio
    ruff format --quiet --check tests/audio
    "$python" -I "$AUDIO_TOOLS/render.py" --out "$OUT" --check
    cap timeout 50 "$python" -I "$AUDIO_TOOLS/analyze.py" "$OUT" --quiet
}

main "$@"
