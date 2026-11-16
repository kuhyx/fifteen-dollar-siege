#!/bin/bash

# ============================================================================
# Every gate of this repo in one exit code, under 60 s:
#   smoke      godot --import, then --quit: no SCRIPT ERROR (build-game R9), no
#              "resources still in use at exit" (a sound left playing)
#   lint       gdlint, gdformat --check, shellcheck, ruff
#   test       GUT suite              save_guard  GUT without the hook redirect
#   recording  recorder unit tests    autodrive   the bot, all three modes
#   launcher   run.sh on a broken GPU GL + the F12 bundle (Xvfb)
#   static     greps: muted runs, lossless imports, no AI-art tooling, dev
#              files without class_name, exports without src/dev, no visible text,
#              no colour literal outside the palette file
#   shared     file length, md naming, no binaries, dependency freshness, contract
#   audio      audio tool tests, rendered files current, offline analysis of each
#   coverage   100 % branch coverage of tools/recording and tools/audio (scripts/coverage.sh)
#   export     the Linux build plays without src/dev
# smoke runs first, the middle gates run side by side (each in its own capped
# scope), export runs last (it re-imports). One line per gate; a failed gate
# prints the tail of its log.
#   scripts/check.sh              all gates
#   scripts/check.sh lint test    only these
#   scripts/check.sh --list       the gate names
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly FIRST=(smoke)
readonly PARALLEL=(lint test save_guard recording autodrive launcher static shared audio coverage)
readonly LAST=(export)
LOGS=""
FAILED=0

cleanup() {
    [[ -z "$LOGS" ]] || rm -rf "$LOGS"
}

gate_smoke() {
    local out
    out="$(cap timeout 50 godot --headless --path "$REPO_ROOT" --import 2>&1)"
    out+="$(cap timeout 30 godot --headless --path "$REPO_ROOT" --quit 2>&1)"
    if grep -E 'SCRIPT ERROR|Parse Error|still in use at exit' <<<"$out"; then
        return 1
    fi
    echo "import and quit: no SCRIPT ERROR"
}

# Prints the offending lines of a check that must find nothing; fails if any.
must_be_empty() {
    local what="$1" found
    shift
    found="$("$@" 2>/dev/null || true)"
    [[ -z "$found" ]] && return 0
    echo "static: $what" >&2
    echo "$found" | head -10 >&2
    return 1
}

gate_static() {
    local bad=0 dev_filters
    # The words below are split so this file never matches its own patterns.
    local ai_art='art''gate|generate\.p''y|Lo''RA' no_hook='-gcon''fig='
    local lossy='libvor''bis|libmp3''lame|ogg''enc'
    # R2: a script that starts godot says so muted or headless.
    must_be_empty "a godot run that is neither headless nor muted" bash -c \
        "grep -rlE '(^|[[:space:]])godot[[:space:]]+(--|\")' scripts | xargs -r grep -LE 'audio-driver Dummy|--headless'" || bad=1
    # R13: no lossy import, no lossy audio encoder in the tooling.
    must_be_empty "a lossy texture import (compress/mode=1)" bash -c \
        "find -L . \( -name .godot -o -name .claude \) -prune -o -name '*.import' -print0 | xargs -0 -r grep -lE 'compress/mode=1'" || bad=1
    must_be_empty "a lossy audio encoder in scripts/ or tools/" \
        grep -rlE "$lossy" scripts tools || bad=1
    # R3: no AI-art tooling outside the docs.
    must_be_empty "AI-art tooling" git grep -nE "$ai_art" -- ':!*.md' || bad=1
    # R10: dev files are reachable by path only, and stay out of every export.
    must_be_empty "a class_name in src/dev" grep -rn '^class_name' src/dev || bad=1
    dev_filters="$(grep -c 'exclude_filter=.*src/dev/\*' export_presets.cfg || true)"
    if [[ "$dev_filters" -ne "$(grep -c '^\[preset\.[0-9]*\]$' export_presets.cfg)" ]]; then
        echo "static: an export preset does not exclude src/dev/*" >&2
        bad=1
    fi
    # L11: GUT only ever starts through scripts/test.sh and its config.
    must_be_empty "a GUT call that skips .gutconfig.json" grep -rn -- "$no_hook" scripts || bad=1
    # One palette: no colour literal outside src/ui/palette.gd.
    scripts/check_palette.sh >/dev/null || bad=1
    # textgate: nothing the player sees is a word.
    if command -v textgate >/dev/null && ! textgate scan | grep -q '^0 to rework'; then
        textgate scan | tail -10 >&2
        bad=1
    fi
    ((bad == 0)) || return 1
    echo "greps clean"
}

gate_shared() {
    scripts/check_file_length.sh --all
    scripts/check_md_naming.sh --all
    git ls-files -z | xargs -0 scripts/check_no_binaries.sh
    scripts/check_dependency_freshness.sh --all >/dev/null
    scripts/check_repo_contract.sh
    echo "shared gates ok"
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
        export) scripts/test_export.sh ;;
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
    local all=("${FIRST[@]}" "${PARALLEL[@]}" "${LAST[@]}") gate
    if [[ "${1:-}" == --list ]]; then
        printf '%s\n' "${all[@]}"
        return 0
    fi
    WANTED=("$@")
    [[ ${#WANTED[@]} -gt 0 ]] || WANTED=("${all[@]}")
    for gate in "${WANTED[@]}"; do
        [[ " ${all[*]} " == *" $gate "* ]] || {
            echo "unknown gate '$gate' (scripts/check.sh --list)" >&2
            exit 2
        }
    done
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
