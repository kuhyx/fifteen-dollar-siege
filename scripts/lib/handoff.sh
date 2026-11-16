#!/bin/bash

# ============================================================================
# What every hand-off script needs (sourced after common.sh, never executed):
# an item is a tiny file in scripts/handoff/ that sets
#   ITEM_ID      name of the answer          ITEM_QUESTION  ONE yes/no question
#   ITEM_KIND    game (default) or web       ITEM_SOUND     1 = the game plays sound
#   ITEM_SCREEN  the screen --check expects  ITEM_JQ        extra jq test on the state
#   ITEM_ARGS    game arguments (after `--`)   ITEM_HINT  one line before it opens
# and ends with `handoff_main "$@"`. Run for kuhy it opens the game (or the
# browser) in the state to judge, asks the question, and on a no asks for one
# line of what was wrong; every answer is appended to the answer file under
# the repo's feedback/ link. With --check it is the same launch, muted, on a
# private Xvfb screen (never display :0), asks nothing, writes no answer and
# exits 0 within 20 s only when the game really came up on the expected screen.
# ============================================================================

# shellcheck source=scripts/lib/launch.sh
source "$REPO_ROOT/scripts/lib/launch.sh"
# shellcheck source=scripts/lib/bot.sh
source "$REPO_ROOT/scripts/lib/bot.sh"

# The pinned sieges of src/core/siege_fixtures.gd (tests/test_handoff_launch.gd
# holds these to it): a loadout and seed that win, and one that burns.
readonly WIN_LOADOUT="double_men,fifty_men,knight_armor,pep_talk"
readonly LOSE_LOADOUT="pep_talk,stew"
readonly FIXTURE_SEED=4
# A win that cost 10 dollars (two stars: the third asks for 6 or less).
readonly TWO_STAR_LOADOUT="stitched_monster,medics"
export WIN_LOADOUT LOSE_LOADOUT FIXTURE_SEED TWO_STAR_LOADOUT # the items read them
readonly HANDOFF_DIR="$REPO_ROOT/scripts/handoff"
readonly CHECK_LIMIT_S=20
readonly CHECK_SIZE=960x540

HANDOFF_TMP=""
HANDOFF_PIDS=()

handoff_cleanup() {
    local pid
    for pid in "${HANDOFF_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    [[ -z "$HANDOFF_TMP" ]] || rm -rf "$HANDOFF_TMP"
}

# Every item, in walking order (the file names carry the order).
handoff_items() {
    find "$HANDOFF_DIR" -maxdepth 1 -name '[0-9][0-9]_*.sh' -type f | sort
}

# ---- the answer file ------------------------------------------------------

# One JSON object per line: {time, item, answer: yes|no|skipped, note}.
#   record_answer <item> <yes|no|skipped> <note>
record_answer() {
    local file="${SIEGE_ANSWERS:-$BINARIES/feedback/playtest-answers.jsonl}"
    mkdir -p "$(dirname "$file")"
    jq -nc --arg time "$(date +%Y-%m-%dT%H:%M:%S%:z)" --arg item "$1" --arg answer "$2" \
        --arg note "$3" '{time: $time, item: $item, answer: $answer, note: $note}' \
        >>"$file"
}

# Asks until it gets a y or an n; prints yes or no. Fails when input ends.
ask_yes_no() {
    local reply
    while true; do
        printf '  [y/n] ' >&2
        read -r reply || return 1
        case "${reply,,}" in
            y | yes) echo yes && return 0 ;;
            n | no) echo no && return 0 ;;
        esac
    done
}

# ---- the game -------------------------------------------------------------

# Engine flags before `--`: muted always, except for the one item that plays sound.
engine_flags() {
    if [[ "${CHECKING:-0}" != 1 && "${ITEM_SOUND:-0}" == 1 ]]; then
        return 0
    fi
    echo --audio-driver Dummy
}

# Runs the game once with the item's arguments; a fresh throwaway save, so the
# real save never changes. The log is in $HANDOFF_TMP/game.log.
run_game() {
    local flags=() save="$HANDOFF_TMP/save" code=0
    read -r -a flags < <(engine_flags) || true # no flags: the sound item
    rm -rf "$save"
    godot "${flags[@]}" --path "$REPO_ROOT" -- "${ITEM_ARGS[@]}" "--save-dir=$save" \
        >"$HANDOFF_TMP/game.log" 2>&1 </dev/null || code=$?
    if ((code == 0)) && grep -q 'SCRIPT ERROR' "$HANDOFF_TMP/game.log"; then
        code=1
    fi
    return "$code"
}

# ---- --check ----------------------------------------------------------------

# The state file the game wrote must name the screen the item promises.
check_state() {
    local state="$HANDOFF_TMP/state.json"
    [[ -s "$state" ]] || {
        tail -n 10 "$HANDOFF_TMP/game.log" >&2
        echo "$ITEM_ID: the game wrote no state (exit ok but the screen never came up)" >&2
        return 1
    }
    jq -e --arg screen "$ITEM_SCREEN" '.screen == $screen' "$state" >/dev/null || {
        echo "$ITEM_ID: expected screen $ITEM_SCREEN, got $(jq -r .screen "$state")" >&2
        return 1
    }
    if [[ -n "${ITEM_JQ:-}" ]]; then
        jq -e "$ITEM_JQ" "$state" >/dev/null || {
            echo "$ITEM_ID: the state fails $ITEM_JQ: $(jq -c . "$state")" >&2
            return 1
        }
    fi
    if [[ "${BOT_HEADLESS:-0}" != 1 ]]; then
        frames_ok "$state.png" >/dev/null || return 1
    fi
}

# Same launch as for kuhy, muted, on a private Xvfb screen (or headless in CI).
check_game() {
    local code=0 launch=("$REPO_ROOT/scripts/xvfb_run.sh" "$CHECK_SIZE")
    [[ "${BOT_HEADLESS:-0}" != 1 ]] || launch=(env)
    CHECKING=1
    refresh_class_cache >/dev/null 2>&1
    local flags=(--audio-driver Dummy)
    [[ "${BOT_HEADLESS:-0}" != 1 ]] || flags+=(--headless)
    # One software-GL thread: eight checks side by side share a capped CPU budget.
    LP_NUM_THREADS=1 cap timeout -k 2 "$CHECK_LIMIT_S" "${launch[@]}" godot "${flags[@]}" --path "$REPO_ROOT" -- \
        "${ITEM_ARGS[@]}" "--save-dir=$HANDOFF_TMP/save" "--check-state=$HANDOFF_TMP/state.json" \
        >"$HANDOFF_TMP/game.log" 2>&1 </dev/null || code=$?
    if ((code != 0)) || grep -q 'SCRIPT ERROR' "$HANDOFF_TMP/game.log"; then
        tail -n 15 "$HANDOFF_TMP/game.log" >&2
        echo "$ITEM_ID: check FAILED (game exit $code)" >&2
        return 1
    fi
    check_state
    echo "$ITEM_ID: check ok (screen $ITEM_SCREEN, muted, private screen)"
}

# ---- the walk ----------------------------------------------------------------

# Prints the question and gets one answer; a no also gets one line of why.
# Records it. Prints nothing else.
ask_and_record() {
    local answer note=""
    printf '\n%s\n' "$ITEM_QUESTION"
    answer="$(ask_yes_no)" || {
        echo "no answer (input ended): nothing recorded" >&2
        return 1
    }
    if [[ "$answer" == no ]]; then
        printf '  what was wrong (one line): '
        read -r note || note=""
    fi
    record_answer "$ITEM_ID" "$answer" "$note"
}

# After a failed launch: retry, skip (recorded) or quit.
retry_or_skip() {
    local reply
    while true; do
        printf '  [r]etry, [s]kip or [q]uit? ' >&2
        read -r reply || return 2
        case "${reply,,}" in
            r | retry) return 0 ;;
            s | skip) record_answer "$ITEM_ID" skipped "" && return 1 ;;
            q | quit) return 2 ;;
        esac
    done
}

# The thing to judge, once: the game window, or the browser (item kind web).
show_item() {
    if [[ "${ITEM_KIND:-game}" == web ]]; then
        show_web
    else
        [[ -z "${ITEM_HINT:-}" ]] || printf '  %s\n' "$ITEM_HINT"
        printf '%s\n' "  close the window when you have seen enough."
        run_game
    fi
}

handoff_main() {
    HANDOFF_TMP="$(mktemp -d "${TMPDIR:-/tmp}/handoff.XXXXXX")"
    trap handoff_cleanup EXIT
    need godot jq
    [[ "${ITEM_KIND:-game}" != web ]] || source "$REPO_ROOT/scripts/lib/handoff_web.sh"
    if [[ "${1:-}" == --check ]]; then
        if [[ "${ITEM_KIND:-game}" == web ]]; then check_web; else check_game; fi
        return
    fi
    local code
    use_mesa_if_gl_broken
    refresh_class_cache
    while true; do
        code=0
        show_item || code=$?
        if ((code != 0)); then
            tail -n 12 "$HANDOFF_TMP/game.log" >&2 2>/dev/null || true
            echo "$ITEM_ID: it did not run (exit $code)" >&2
            code=0
            retry_or_skip || code=$?
            ((code == 0)) && continue
            ((code == 1)) && return 0
            return 130
        fi
        ask_and_record
        return
    done
}
