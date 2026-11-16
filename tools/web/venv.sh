#!/bin/bash

# ============================================================================
# The Python venv of the web smoke gate (one pinned package, the CDP client):
# makes it, or refreshes it when requirements.txt changed. install.sh runs it;
# scripts/test_web.sh calls it. Prints the venv's python on stdout.
#   tools/web/venv.sh
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"

readonly REQUIREMENTS="$REPO_ROOT/tools/web/requirements.txt"
readonly VENV="${SIEGE_WEB_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/$REPO_NAME/web-venv}"

main() {
    local want stamp="$VENV/.requirements.sha256"
    want="$(sha256sum "$REQUIREMENTS" | cut -d' ' -f1)"
    if [[ ! -x "$VENV/bin/python" || "$(cat "$stamp" 2>/dev/null || true)" != "$want" ]]; then
        need python3
        rm -rf "$VENV"
        mkdir -p "$(dirname "$VENV")"
        if command -v uv >/dev/null; then
            uv venv --quiet --python python3 "$VENV" >&2
            uv pip install --quiet --python "$VENV/bin/python" -r "$REQUIREMENTS" >&2
        else
            python3 -m venv "$VENV"
            "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check -r "$REQUIREMENTS" >&2
        fi
        echo "$want" >"$stamp"
        echo "done web venv ($VENV)" >&2
    fi
    echo "$VENV/bin/python"
}

main "$@"
