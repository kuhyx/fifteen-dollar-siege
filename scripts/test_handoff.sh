#!/bin/bash

# ============================================================================
# The gate of the hand-off scripts (scripts/handoff/NN_*.sh, walked by
# scripts/playtest.sh):
#   format  the answer file: one JSON object per line with exactly time, item,
#           answer (yes, no or skipped) and note (only a "no" has one); quotes,
#           tabs and backslashes in a note survive; the question loops until it
#           gets a y or an n
#   walk    scripts/playtest.sh with a stand-in godot that opens nothing: a no keeps
#           its note, a failed launch offers retry or skip and never moves on
#           by itself, a skip is recorded, q stops the walk
#   check   every item with --check, side by side: the same launch, muted, on a
#           private Xvfb, no question asked, exit 0 within 20 s, the state the
#           item promises (screen, loadout) written by the game and a frame
# Passes only when there is at least one item and every one of them passes.
#   scripts/test_handoff.sh [format|walk|check]      default: both, about 25 s
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/handoff.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/handoff.sh"

TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "handoff: FAILED ($1)" >&2
    exit 1
}

# One line of the answer file as `jq` sees it, failing on bad JSON.
field() {
    jq -er ".$2" <<<"$1"
}

test_format() {
    local nasty=$'a "quote", a \\ backslash,\ta tab, and é' line
    export SIEGE_ANSWERS="$TMP/answers.jsonl"
    record_answer 01_demo yes ""
    record_answer 02_demo no "$nasty"
    record_answer 03_demo skipped ""
    [[ "$(wc -l <"$SIEGE_ANSWERS")" -eq 3 ]] || fail "the answer file does not hold one line per answer"
    jq -e 'keys == ["answer","item","note","time"]' "$SIEGE_ANSWERS" >/dev/null ||
        fail "an answer line has other keys than time, item, answer, note"
    jq -e '.time | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$")' \
        "$SIEGE_ANSWERS" >/dev/null || fail "an answer's time is not an ISO stamp"
    line="$(sed -n 2p "$SIEGE_ANSWERS")"
    [[ "$(field "$line" answer)" == no ]] || fail "the answer is not kept"
    [[ "$(field "$line" note)" == "$nasty" ]] || fail "a note with quotes, tabs or backslashes did not survive"
    [[ "$(jq -r '.note' <<<"$(sed -n 1p "$SIEGE_ANSWERS")")" == "" ]] || fail "a yes carries a note"
    [[ "$(ask_yes_no <<<$'maybe\n\ny' 2>/dev/null)" == yes ]] || fail "the question did not loop until a y or an n"
    [[ "$(ask_yes_no <<<'N' 2>/dev/null)" == no ]] || fail "an N is not a no"
    ! ask_yes_no </dev/null >/dev/null 2>&1 || fail "the question loops forever without an answer"
    echo "handoff format: ok (3 answers, the question loops)"
}

# playtest.sh on item 04 with a godot that exits $FAKE_EXIT (1 the first $FAKE_FAILS runs).
walk() {
    local input="$1" code=0
    export SIEGE_ANSWERS="$TMP/walk.jsonl"
    rm -f "$SIEGE_ANSWERS" "$TMP/runs"
    "$REPO_ROOT/scripts/playtest.sh" 04 <<<"$input" >"$TMP/walk.log" 2>&1 || code=$?
    return "$code"
}

test_walk() {
    local code=0
    mkdir -p "$TMP/bin"
    cat >"$TMP/bin/godot" <<FAKE
#!/bin/bash
echo run >>"$TMP/runs"
echo "\$*" >>"$TMP/args"
[[ "\$(wc -l <"$TMP/runs")" -gt "\${FAKE_FAILS:-0}" ]]
FAKE
    chmod +x "$TMP/bin/godot"
    export PATH="$TMP/bin:$PATH" FAKE_FAILS=0
    walk $'n\nthe coins are tiny' || fail "a walk with a no did not finish"
    [[ "$(jq -r '[.item, .answer, .note] | join("|")' "$SIEGE_ANSWERS")" == "shop|no|the coins are tiny" ]] ||
        fail "a no did not keep its note"
    FAKE_FAILS=1 walk $'r\ny' || fail "retry after a failed launch did not finish"
    [[ "$(wc -l <"$TMP/runs")" -eq 2 && "$(jq -r .answer "$SIEGE_ANSWERS")" == yes ]] ||
        fail "retry did not run the item again"
    FAKE_FAILS=9 walk $'s' || fail "a skip did not finish"
    [[ "$(jq -r .answer "$SIEGE_ANSWERS")" == skipped ]] || fail "a skip was not recorded"
    FAKE_FAILS=9 walk $'q' || code=$?
    [[ "$code" -eq 130 && ! -s "$SIEGE_ANSWERS" ]] || fail "quit did not stop the walk quietly"
    FAKE_FAILS=9 walk $'x\ns' || fail "an unknown reply did not ask again"
    rm -f "$TMP/args"
    walk $'y' || fail "the shop item did not finish"
    grep -q -- '--audio-driver Dummy' "$TMP/args" || fail "an item other than the sound one is not muted"
    rm -f "$TMP/args"
    "$REPO_ROOT/scripts/playtest.sh" 08 <<<$'y' >/dev/null 2>&1 || fail "the sound item did not finish"
    ! grep -q -- 'audio-driver' "$TMP/args" || fail "the sound item is muted"
    grep -q -- '--save-dir=' "$TMP/args" || fail "an item does not use a throwaway save"
    echo "handoff walk: ok (no, retry, skip, quit, muted but the sound item)"
}

test_check() {
    local items=() item pids=() code=0 i
    mapfile -t items < <(handoff_items)
    [[ ${#items[@]} -gt 0 ]] || fail "no hand-off item in scripts/handoff"
    for item in "${items[@]}"; do
        "$item" --check >"$TMP/$(basename "$item").log" 2>&1 &
        pids+=($!)
    done
    for i in "${!pids[@]}"; do
        if wait "${pids[$i]}"; then
            tail -n 1 "$TMP/$(basename "${items[$i]}").log"
        else
            code=1
            tail -n 8 "$TMP/$(basename "${items[$i]}").log" >&2
        fi
    done
    ((code == 0)) || fail "an item did not start"
    echo "handoff check: ${#items[@]} items start, muted, on a private screen"
}

main() {
    need jq
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/handoff.XXXXXX")"
    trap cleanup EXIT
    local parts=("$@")
    [[ ${#parts[@]} -gt 0 ]] || parts=(format walk check)
    local part
    for part in "${parts[@]}"; do
        case "$part" in
            format) test_format ;;
            walk) (test_walk) ;;  # a subshell: its stand-in godot must not leak
            check) test_check ;;
            *)
                echo "usage: test_handoff.sh [format|walk|check ...]" >&2
                exit 2
                ;;
        esac
    done
    echo "handoff: PASS"
}

main "$@"
