#!/bin/bash

# ============================================================================
# Line + branch coverage of the Python in this repo from its unit tests: the
# game's recorder settings (tools/recording/, tests/recording/) and the audio tools
# (tools/audio/, tests/audio/). One command, one number, FAILS under 100 %
# (COVERAGE_MIN=N lowers the floor while a gap is being closed). Writes
# coverage.xml at the repo root (gitignored) for `coverage-gaps coverage.xml`.
# Each tree runs under its own venv's python (the audio venv holds numpy, the
# recorder venv holds game_recording); coverage is installed into both at the
# requirements-dev.txt pin. The recorder itself is tested in kuhyx/utils.
# GDScript has no coverage tool; its gates are GUT and the autodrive bot.
#   scripts/coverage.sh
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# shellcheck source=scripts/lib/recording.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/recording.sh"

readonly VENV="${SIEGE_AUDIO_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/$REPO_NAME/audio-venv}"
readonly FLOOR="${COVERAGE_MIN:-100}"

# Makes sure the venv python can `import coverage` at the repo's pin.
ensure_coverage() {
    local python="$1" pin
    "$python" -c 'import coverage' 2>/dev/null && return 0
    pin="$(grep -E '^coverage==' "$REPO_ROOT/requirements-dev.txt")"
    if command -v uv >/dev/null; then
        uv pip install --quiet --python "$python" "$pin"
    else
        "$python" -m pip install --quiet --disable-pip-version-check "$pin"
    fi
}

# Runs one unittest tree under coverage, appending to the shared data file.
run_tree() {
    local python="$1" data="$2" tree="$3" out code=0
    out="$(cap timeout 50 "$python" -m coverage run --append --branch --data-file="$data" \
        --source=tools/recording,tools/audio \
        -m unittest discover -s "$tree" -t "$tree" -p 'test_*.py' 2>&1)" || code=$?
    if ((code != 0)); then
        echo "$out" | tail -40 >&2
        echo "coverage: the $tree tests FAILED (exit $code)" >&2
        exit 1
    fi
}

main() {
    need ffmpeg ffprobe
    local python="$VENV/bin/python" recording_py
    recording_py="$(recording_python)"
    [[ -x "$python" ]] || {
        echo "Error: the audio venv is missing (run ./install.sh)" >&2
        exit 1
    }
    ensure_coverage "$python"
    ensure_coverage "$recording_py"
    cd "$REPO_ROOT"
    mkdir -p "$SCRATCH"
    local data="$SCRATCH/coverage.data" pkg total
    rm -f "$data"
    run_tree "$recording_py" "$data" tests/recording
    run_tree "$python" "$data" tests/audio
    "$python" -m coverage xml --data-file="$data" -o coverage.xml -q
    for pkg in recording audio; do
        printf 'coverage: %-9s %s%%\n' "$pkg" \
            "$("$python" -m coverage report --data-file="$data" --format=total --include="tools/$pkg/*")"
    done
    total="$("$python" -m coverage report --data-file="$data" --format=total)"
    rm -f "$data"
    echo "coverage: total     ${total}% (coverage.xml)"
    if ((total < FLOOR)); then
        echo "coverage: under the ${FLOOR}% floor" >&2
        exit 1
    fi
}

main "$@"
