#!/bin/bash

# ============================================================================
# Line + branch coverage of the Python in this repo (the session recorder,
# tools/recording/) from its unit tests. Writes coverage.xml at the repo root
# (gitignored) for `coverage-gaps coverage.xml` and prints one summary line.
# GDScript has no coverage tool; its gates are GUT and the autodrive bot.
#   scripts/coverage.sh            report only
#   COVERAGE_MIN=90 scripts/coverage.sh   also fail under 90 %
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
    need python3 coverage ffmpeg ffprobe
    cd "$REPO_ROOT"
    mkdir -p "$SCRATCH"
    local data="$SCRATCH/coverage.data" out code=0 total
    rm -f "$data"
    out="$(cap timeout 50 coverage run --branch --data-file="$data" --source=tools/recording \
        -m unittest discover -s tests/recording -t tests/recording -p 'test_*.py' 2>&1)" || code=$?
    if ((code != 0)); then
        echo "$out" | tail -40 >&2
        echo "coverage: the tests FAILED (exit $code)" >&2
        exit 1
    fi
    coverage xml --data-file="$data" -o coverage.xml -q
    total="$(coverage report --data-file="$data" --format=total)"
    rm -f "$data"
    echo "coverage: ${total}% of tools/recording (coverage.xml)"
    if [[ -n "${COVERAGE_MIN:-}" && "$total" -lt "$COVERAGE_MIN" ]]; then
        echo "coverage: under the ${COVERAGE_MIN}% floor" >&2
        exit 1
    fi
}

main "$@"
