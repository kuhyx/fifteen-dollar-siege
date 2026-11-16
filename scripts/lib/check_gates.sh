#!/bin/bash

# ============================================================================
# The gates of scripts/check.sh that are a few lines of shell (sourced after
# common.sh, never executed): smoke, static and shared.
# ============================================================================

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
