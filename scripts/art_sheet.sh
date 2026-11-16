#!/bin/bash

# ============================================================================
# Contact sheet of the code-drawn art on a private Xvfb (never the live
# display), muted, one call under 60 s. Copy the PNG before Reading it: a hook
# downscales files in place.
#   scripts/art_sheet.sh <kind> <out.png> [WxH] [tool args...]
#   kinds: buffs | buffs_big | ui | vignettes [--t=S] | vignette --id=<buff>
#          | shop [--id=<buff>] [--t=S]
#   default size 1920x1080; use 1280x720 and 3840x2160 for the size checks
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/launch.sh"

main() {
    if [[ $# -lt 2 ]]; then
        echo "usage: $0 <buffs|buffs_big|ui|vignettes|vignette|shop> <out.png> [WxH] [args...]" >&2
        exit 2
    fi
    need godot Xvfb
    refresh_class_cache
    local kind="$1" out size="${3:-1920x1080}"
    out="$(realpath -m "$2")"
    shift 2
    [[ $# -eq 0 ]] || shift
    mkdir -p "$(dirname "$out")"
    cap timeout -k 3 50 "$REPO_ROOT/scripts/xvfb_run.sh" "$size" godot --audio-driver Dummy \
        --resolution "$size" --path "$REPO_ROOT" -s tools/art_sheet.gd -- "$kind" "$out" "$@" 2>&1 |
        grep -E 'art_sheet|ERROR|error' || true
    [[ -s "$out" ]] || {
        echo "art_sheet: no frame written" >&2
        exit 1
    }
}

main "$@"
