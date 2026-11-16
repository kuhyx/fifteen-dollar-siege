#!/bin/bash

# ============================================================================
# The session recorder's Python venv (install.sh runs this; rerun after editing
# tools/recording/requirements.txt). The recorder is the `game_recording`
# package of kuhyx/utils, pinned to a tag there; it is stdlib only.
#   tools/recording/build.sh                    make or refresh the venv
#   tools/recording/build.sh --venv             same, and print its python
#   tools/recording/build.sh --print-requirement  print the line pip installs
# The venv lives in ${XDG_CACHE_HOME:-~/.cache}/<repo>/recording-venv and is
# made again when the requirement changes. SIEGE_RECORDING_VENV moves it.
# Proof before a tag exists: SIEGE_UTILS_REMOTE (a git URL, e.g. file:///path
# of a local utils checkout) and SIEGE_UTILS_RECORDING_REF (a commit or tag)
# replace the URL and the ref of the pinned line; unset, the line is used as is.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"

readonly REQUIREMENTS="$REPO_ROOT/tools/recording/requirements.txt"
readonly VENV="${SIEGE_RECORDING_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/$REPO_NAME/recording-venv}"
# <package> @ git+<remote>@<ref>#subdirectory=<dir>
readonly LINE_PATTERN='^([^ ]+) @ git\+(.+)@([^@#]+)#subdirectory=(.+)$'

# Prints the pinned line, with the remote and the ref swapped when the override
# variables are set.
requirement() {
    local line
    line="$(grep -v '^#' "$REQUIREMENTS" | grep -v '^[[:space:]]*$')"
    [[ "$line" =~ $LINE_PATTERN ]] || {
        echo "Error: $REQUIREMENTS does not hold one 'pkg @ git+url@ref#subdirectory=dir' line" >&2
        exit 1
    }
    local pkg="${BASH_REMATCH[1]}" remote="${BASH_REMATCH[2]}" ref="${BASH_REMATCH[3]}" dir="${BASH_REMATCH[4]}"
    echo "$pkg @ git+${SIEGE_UTILS_REMOTE:-$remote}@${SIEGE_UTILS_RECORDING_REF:-$ref}#subdirectory=$dir"
}

# Makes the venv, or refreshes it when the requirement changed since.
ensure_venv() {
    local want stamp="$VENV/.requirement.sha256" line
    line="$(requirement)"
    want="$(printf '%s\n' "$line" | sha256sum | cut -d' ' -f1)"
    if [[ -x "$VENV/bin/python" && "$(cat "$stamp" 2>/dev/null || true)" == "$want" ]]; then
        return
    fi
    need python3 git
    rm -rf "$VENV"
    mkdir -p "$(dirname "$VENV")"
    if command -v uv >/dev/null; then
        uv venv --quiet --python python3 "$VENV"
        uv pip install --quiet --python "$VENV/bin/python" "$line"
    else
        python3 -m venv "$VENV"
        "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check "$line"
    fi
    echo "$want" >"$stamp"
    echo "done recording venv ($VENV)" >&2
}

main() {
    if [[ "${1:-}" == --print-requirement ]]; then
        requirement
        return
    fi
    ensure_venv
    if [[ "${1:-}" == --venv ]]; then
        echo "$VENV/bin/python"
    fi
}

main "$@"
