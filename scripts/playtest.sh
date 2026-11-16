#!/bin/bash

# ============================================================================
# kuhy's playtest: walks every item of scripts/handoff/ in order. Each opens the
# game (or the browser) in the state to judge, asks ONE yes/no question and,
# on a no, one line of what was wrong. Answers are appended to
# feedback/playtest-answers.jsonl (the repo's feedback/ link). Run it from any
# directory:
#   scripts/playtest.sh              all items, in order
#   scripts/playtest.sh 04 08        only the items whose file starts with 04 or 08
# An item that fails to start offers retry or skip (a skip is recorded); it never
# moves on by itself. Only the audio item plays sound.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/handoff.sh
source "$REPO_ROOT/scripts/lib/handoff.sh"

# True when the item's file name starts with one of the wanted numbers.
wanted() {
    local name want
    name="$(basename "$1")"
    [[ $# -eq 1 ]] && return 0
    shift
    for want in "$@"; do
        [[ "$name" == "$want"* ]] && return 0
    done
    return 1
}

main() {
    local items=() item todo=() code index=0 asked=0
    mapfile -t items < <(handoff_items)
    for item in "${items[@]}"; do
        wanted "$item" "$@" && todo+=("$item")
    done
    [[ ${#todo[@]} -gt 0 ]] || {
        echo "playtest: no item matches '$*' in $HANDOFF_DIR" >&2
        exit 2
    }
    for item in "${todo[@]}"; do
        index=$((index + 1))
        ITEM_ID="$(basename "$item" .sh)"
        while true; do
            printf '\n== %d/%d  %s ==\n' "$index" "${#todo[@]}" "$ITEM_ID"
            code=0
            "$item" || code=$?
            ((code == 0)) && break
            ((code == 130)) && {
                echo "playtest: stopped; ${asked} answered"
                exit 130
            }
            echo "playtest: $ITEM_ID ended with exit $code" >&2
            code=0
            retry_or_skip || code=$?
            ((code == 1)) && break
            ((code == 2)) && exit 130
        done
        asked=$((asked + 1))
    done
    printf '\nplaytest: done, %d items. Answers: %s\n' "$asked" \
        "${SIEGE_ANSWERS:-$BINARIES/feedback/playtest-answers.jsonl}"
}

main "$@"
