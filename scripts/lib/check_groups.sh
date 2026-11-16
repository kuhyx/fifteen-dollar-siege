#!/bin/bash

# ============================================================================
# The groups of scripts/check.sh (sourced after common.sh, never executed): which
# gates run in which phase, which gates make a group, and the arguments that
# name them. FIRST, PARALLEL and LAST are the phases; a gate is in exactly one
# group (verify_groups).
# ============================================================================

readonly FIRST=(smoke)
readonly PARALLEL=(lint test save_guard mount recording autodrive launcher static shared audio coverage balance buffs handoff)
readonly LAST=(export round web)
# group name -> its gates. Every gate is in exactly one group.
readonly GROUP_NAMES=(fast play bots tools sim build web handoff)
readonly GROUP_FAST=(smoke lint static shared save_guard mount recording)
readonly GROUP_PLAY=(test)
readonly GROUP_BOTS=(autodrive launcher)
readonly GROUP_TOOLS=(audio coverage)
readonly GROUP_SIM=(balance buffs)
readonly GROUP_BUILD=(export round)
readonly GROUP_WEB=(web)
readonly GROUP_HANDOFF=(handoff)

# Prints the gates of group `$1`.
group_gates() {
    case "$1" in
        fast) printf '%s\n' "${GROUP_FAST[@]}" ;;
        play) printf '%s\n' "${GROUP_PLAY[@]}" ;;
        bots) printf '%s\n' "${GROUP_BOTS[@]}" ;;
        tools) printf '%s\n' "${GROUP_TOOLS[@]}" ;;
        sim) printf '%s\n' "${GROUP_SIM[@]}" ;;
        build) printf '%s\n' "${GROUP_BUILD[@]}" ;;
        web) printf '%s\n' "${GROUP_WEB[@]}" ;;
        handoff) printf '%s\n' "${GROUP_HANDOFF[@]}" ;;
        *)
            echo "unknown group '$1' (scripts/check.sh --list)" >&2
            return 2
            ;;
    esac
}

# No gate may be left out of every group, or sit in two (a dropped gate is a hole).
verify_groups() {
    local gate name count
    for gate in "${FIRST[@]}" "${PARALLEL[@]}" "${LAST[@]}"; do
        count=0
        for name in "${GROUP_NAMES[@]}"; do
            [[ " $(group_gates "$name" | tr '\n' ' ')" == *" $gate "* ]] && count=$((count + 1))
        done
        [[ "$count" -eq 1 ]] || {
            echo "check.sh: gate '$gate' is in $count groups (it must be in exactly one)" >&2
            exit 3
        }
    done
}

list_groups() {
    local name
    for name in "${GROUP_NAMES[@]}"; do
        printf '%-6s %s\n' "$name" "$(group_gates "$name" | tr '\n' ' ')"
    done
}

# Turns the arguments into WANTED: groups (--group NAME ...), --all, or gate names.
parse_args() {
    local all=("${FIRST[@]}" "${PARALLEL[@]}" "${LAST[@]}") arg group
    WANTED=()
    while (($# > 0)); do
        arg="$1"
        shift
        case "$arg" in
            --group)
                [[ $# -gt 0 ]] || {
                    echo "--group needs a name (scripts/check.sh --list)" >&2
                    exit 2
                }
                group="$1"
                shift
                mapfile -t -O "${#WANTED[@]}" WANTED < <(group_gates "$group") || exit 2
                ;;
            --all) WANTED+=("${all[@]}") ;;
            *) WANTED+=("$arg") ;;
        esac
    done
    if [[ ${#WANTED[@]} -eq 0 ]]; then
        echo "name a group or a gate: scripts/check.sh --group fast|play|bots|tools|sim|build|web|handoff (--list shows them)" >&2
        exit 2
    fi
    for arg in "${WANTED[@]}"; do
        [[ " ${all[*]} " == *" $arg "* ]] || {
            echo "unknown gate '$arg' (scripts/check.sh --list)" >&2
            exit 2
        }
    done
}
