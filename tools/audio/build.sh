#!/bin/bash

# ============================================================================
# Build the game's audio (install.sh runs this; rerun after editing tools/audio):
#   - a Python venv with the pinned music_theory toolkit (tools/audio/requirements.txt)
#   - every music track and sound effect, rendered from code to 16-bit 44.1 kHz
#     WAV in assets/audio/ (kuhy's machine: ~/data/fifteen-dollar-siege_binaries)
#   - the offline gate over the result (tools/audio/analyze.py)
# Only stale files are rendered, so a rerun takes a second.
#   tools/audio/build.sh             render what is stale, then check
#   tools/audio/build.sh --force     render everything again
#   tools/audio/build.sh --venv      only make the venv and print its python
# SIEGE_AUDIO_DIR moves the output, SIEGE_AUDIO_VENV the venv.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"

readonly AUDIO_TOOLS="$REPO_ROOT/tools/audio"
readonly REQUIREMENTS="$AUDIO_TOOLS/requirements.txt"
readonly VENV="${SIEGE_AUDIO_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/$REPO_NAME/audio-venv}"
readonly OUT="${SIEGE_AUDIO_DIR:-$REPO_ROOT/assets/audio}"

# Makes the venv, or refreshes it when requirements.txt changed since.
ensure_venv() {
    local want stamp="$VENV/.requirements.sha256"
    want="$(sha256sum "$REQUIREMENTS" | cut -d' ' -f1)"
    if [[ -x "$VENV/bin/python" && "$(cat "$stamp" 2>/dev/null || true)" == "$want" ]]; then
        return
    fi
    need python3 git
    rm -rf "$VENV"
    mkdir -p "$(dirname "$VENV")"
    if command -v uv >/dev/null; then
        uv venv --quiet --python python3 "$VENV"
        uv pip install --quiet --python "$VENV/bin/python" -r "$REQUIREMENTS"
    else
        python3 -m venv "$VENV"
        "$VENV/bin/python" -m pip install --quiet -r "$REQUIREMENTS"
    fi
    echo "$want" >"$stamp"
    echo "done audio venv ($VENV)"
}

main() {
    ensure_venv
    if [[ "${1:-}" == --venv ]]; then
        echo "$VENV/bin/python"
        return
    fi
    local force=()
    [[ "${1:-}" != --force ]] || force=(--force)
    cap timeout 55 "$VENV/bin/python" -I "$AUDIO_TOOLS/render.py" --out "$OUT" "${force[@]}" | tail -n 1
    cap timeout 55 "$VENV/bin/python" -I "$AUDIO_TOOLS/analyze.py" "$OUT" --quiet
}

main "$@"
