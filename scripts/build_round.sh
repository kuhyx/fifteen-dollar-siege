#!/bin/bash

# ============================================================================
# One prototype round as builds/vNN/ (build-game R17), never overwritten:
#   builds/vNN/index.html + pck + wasm   the single-threaded Web export
#   builds/vNN/linux/                    the Linux export
#   builds/vNN/NOTES                     one line: your note and the commit
# `builds` is the gitignored link into ~/data/fifteen-dollar-siege_binaries.
# The round is built in a hidden folder beside it and moved into place only
# when both exports passed, so a failed call leaves nothing behind. Two
# exports, about 15 s. SIEGE_BUILDS overrides the builds folder (the test).
#   scripts/build_round.sh <NN> "<one-line note>"
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

STAGE=""

cleanup() {
    [[ -z "$STAGE" ]] || rm -rf "$STAGE"
}

usage() {
    echo "usage: $0 <NN> \"<one-line note>\"   (NN: two digits)" >&2
    exit 2
}

main() {
    [[ $# -eq 2 && "$1" =~ ^[0-9]{2}$ && -n "$2" && "$2" != *$'\n'* ]] || usage
    need godot git
    local round="v$1" note="$2" builds="${SIEGE_BUILDS:-$REPO_ROOT/builds}" commit
    [[ -d "$builds" ]] || {
        echo "Error: $builds is missing (run ./install.sh)" >&2
        exit 1
    }
    if [[ -e "$builds/$round" ]]; then
        echo "Error: $builds/$round exists; a round is never overwritten (pick the next number)" >&2
        exit 1
    fi
    STAGE="$builds/.$round.partial"
    trap cleanup EXIT
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    "$REPO_ROOT/scripts/export.sh" web "$STAGE"
    "$REPO_ROOT/scripts/export.sh" linux "$STAGE/linux"
    commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    echo "$note [commit $commit]" >"$STAGE/NOTES"
    mv "$STAGE" "$builds/$round"
    STAGE=""
    echo "round $round: web $(du -sh "$builds/$round" | cut -f1) in $builds/$round (web at the top, linux/, NOTES)"
}

main "$@"
