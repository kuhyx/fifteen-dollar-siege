#!/bin/bash

# ============================================================================
# Every gate of this repo, in named groups that each finish well under 60 s
# (the hook that kills any call over 60 s is why; measured with `capped.sh`):
#   fast   (~12 s)  smoke    import, then boot and quit: no SCRIPT ERROR (build-game
#                            R9), no "resources still in use at exit"
#                   lint     gdlint, gdformat --check, shellcheck, ruff
#                   static   greps: muted runs, lossless imports, no AI-art tooling,
#                            dev files without class_name, exports without src/dev,
#                            no visible text, no colour literal outside the palette
#                   shared   file length, md naming, no binaries, dependency
#                            freshness, contract
#                   save_guard  GUT without the hook redirect
#                   recording   recorder unit tests
#   play   (~35 s)  test     the GUT suite
#   bots   (~15 s)  autodrive   the bot, every mode (frames on a private Xvfb)
#                   launcher    run.sh on a broken GPU GL + the F12 bundle
#   tools  (~35 s)  audio    audio tool tests, rendered files current, offline
#                            analysis, the boot probe
#                   coverage 100 % branch coverage of tools/recording, tools/audio
#   sim    (~20 s)  balance  the pinned balance checks of the sim (balance_gate.sh)
#                   buffs    each of the 25 buffs seen and heard on the real battle
#                            screen (test_buffs.sh)
#   build  (~20 s)  export   the Linux build plays without src/dev
#                   round    scripts/build_round.sh in a throwaway folder
#   web    (~25 s)  web      the Web build in an isolated headless Chromium
#   handoff (~15 s) handoff  scripts/handoff/*.sh: the answer file format, the walk of
#                            playtest.sh, every item with --check (muted, private screen)
# Inside a group smoke runs first, the middle gates side by side (each in its own
# capped scope), export / round / web last and one by one (they re-import). One
# line per gate; a failed gate prints the tail of its log.
#   scripts/check.sh --group fast        one group (several may follow)
#   scripts/check.sh lint test           only these gates
#   scripts/check.sh --list              the groups and their gates
#   scripts/check.sh --all               every group in turn: about 2 minutes, for
#                                        people and CI, never for a 60 s cap
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/check_gates.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/check_gates.sh"
# shellcheck source=scripts/lib/check_groups.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/check_groups.sh"

LOGS=""
FAILED=0

cleanup() {
    [[ -z "$LOGS" ]] || rm -rf "$LOGS"
}

# Runs one gate; its output goes to the caller (a log file).
run_gate() {
    case "$1" in
        smoke) gate_smoke ;;
        static) gate_static ;;
        shared) gate_shared ;;
        lint) scripts/lint.sh ;;
        test) scripts/test.sh ;;
        save_guard) scripts/test_save_guard.sh ;;
        recording) scripts/test_recording.sh ;;
        autodrive) scripts/autodrive_all.sh ;;
        launcher) scripts/test_launcher.sh ;;
        audio) tools/audio/check.sh ;;
        coverage) scripts/coverage.sh ;;
        balance) scripts/balance_gate.sh ;;
        buffs) scripts/test_buffs.sh ;;
        handoff) scripts/test_handoff.sh ;;
        export) scripts/test_export.sh ;;
        round) scripts/test_build_round.sh ;;
        web) scripts/test_web.sh ;;
    esac
}

# Prints the verdict line of a finished gate from its log and exit code.
report() {
    local gate="$1" code="$2" log="$LOGS/$1.log"
    if [[ "$code" -eq 0 ]]; then
        printf 'check %-10s ok    %s\n' "$gate" "$(tail -n 1 "$log")"
    else
        printf 'check %-10s FAIL  (exit %s)\n' "$gate" "$code"
        tail -n 25 "$log" >&2
        FAILED=1
    fi
}

# Runs the wanted gates of one phase: side by side, or one after the other.
phase() {
    local together="$1" gate code
    shift
    local pids=() names=()
    for gate in "$@"; do
        [[ " ${WANTED[*]} " == *" $gate "* ]] || continue
        if [[ "$together" == 1 ]]; then
            (run_gate "$gate") >"$LOGS/$gate.log" 2>&1 &
            pids+=($!)
            names+=("$gate")
        else
            code=0
            (run_gate "$gate") >"$LOGS/$gate.log" 2>&1 || code=$?
            report "$gate" "$code"
        fi
    done
    local i
    for i in "${!pids[@]}"; do
        code=0
        wait "${pids[$i]}" || code=$?
        report "${names[$i]}" "$code"
    done
}

main() {
    verify_groups
    if [[ "${1:-}" == --list ]]; then
        list_groups
        return 0
    fi
    parse_args "$@"
    cd "$REPO_ROOT"
    mkdir -p "$SCRATCH"
    LOGS="$(mktemp -d "$SCRATCH/check.XXXXXX")"
    trap cleanup EXIT
    phase 0 "${FIRST[@]}"
    phase 1 "${PARALLEL[@]}"
    phase 0 "${LAST[@]}"
    if ((FAILED)); then
        echo "check: FAILED" >&2
        exit 1
    fi
    echo "check: all green (${#WANTED[@]} gates, ${SECONDS}s)"
}

main "$@"
