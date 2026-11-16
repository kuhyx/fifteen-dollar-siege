#!/bin/bash

# ============================================================================
# A quick look at the balance after a tuning change, one call under 60 s: the
# empty loadout and a small random sample (no hill-climbing), then the report
# with what each buff is worth in that sample. Rough numbers (about +-5 pp per
# buff): tune with this, confirm with scripts/balance_search.sh.
#   scripts/balance_quick.sh
#   QUICK_SAMPLE=150 QUICK_RUNS=6 QUICK_EMPTY=100   sizes
#   BUDGET_S=38                                     seconds of sieges
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly SAMPLE="${QUICK_SAMPLE:-150}"
readonly RUNS="${QUICK_RUNS:-6}"
readonly EMPTY="${QUICK_EMPTY:-100}"

main() {
    local sizes=("--sample=$SAMPLE" "--sample-runs=$RUNS" "--empty-runs=$EMPTY")
    BUDGET_S="${BUDGET_S:-38}" "$REPO_ROOT/scripts/balance_search.sh" --no-climb "${sizes[@]}"
    "$REPO_ROOT/scripts/balance_report.sh" "--min-runs=$RUNS" --rows=5 "${sizes[@]}" "$@"
}

main "$@"
