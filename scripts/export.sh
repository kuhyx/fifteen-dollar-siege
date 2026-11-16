#!/bin/bash

# ============================================================================
# One release export (one Godot call, under 60 s) into a folder of your choice:
#   scripts/export.sh web   <dir>   ->  <dir>/index.html (+ pck, wasm)
#   scripts/export.sh linux <dir>   ->  <dir>/fifteen-dollar-siege.x86_64
# The Web build is single-threaded (nothreads template). Both presets leave
# out src/dev, the mounted addons/dev_tools, tests, tools and scripts
# (export_presets.cfg): the script fails if the pack still holds a dev file.
# A prototype round (builds/vNN/ with
# a NOTES line, R17) is scripts/build_round.sh. Publishing is skill
# `itch-publish`.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
    if [[ $# -ne 2 ]]; then
        echo "usage: $0 <web|linux> <out_dir>" >&2
        exit 2
    fi
    need godot
    local preset artifact pack out log
    case "$1" in
        web) preset=Web artifact=index.html pack=index.pck ;;
        linux) preset=Linux artifact=fifteen-dollar-siege.x86_64 pack=fifteen-dollar-siege.x86_64 ;;
        *)
            echo "unknown target '$1' (web or linux)" >&2
            exit 2
            ;;
    esac
    out="$(realpath -m "$2")"
    mkdir -p "$out" "$SCRATCH"
    log="$SCRATCH/export_$1.log"
    rm -f "$out/$artifact"
    # Import in its own call first: an export of an un-imported tree lies with exit 0.
    cap timeout 40 godot --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
    CAP_MEM=4G cap timeout 50 godot --headless --path "$REPO_ROOT" \
        --export-release "$preset" "$out/$artifact" >"$log" 2>&1 || true
    if grep -qE '^(ERROR|SCRIPT ERROR)' "$log" || [[ ! -s "$out/$artifact" ]]; then
        grep -E '^(ERROR|SCRIPT ERROR)' "$log" | head -5 >&2 || true
        echo "export $1: FAILED (log $log)" >&2
        exit 1
    fi
    if grep -qaE 'src/dev/(dev_tools|siege_host)|addons/dev_tools/' "$out/$pack"; then
        echo "export $1: FAILED ($pack holds dev code; check export_presets.cfg)" >&2
        exit 1
    fi
    echo "export $1: ok $(du -sh "$out" | cut -f1) in $out (no dev code in the pack)"
}

main "$@"
