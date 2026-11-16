#!/bin/bash

# ============================================================================
# Lint, every part non-mutating and the whole run under 60 s:
#   gd      gdlint (.gdlintrc: every check on) + gdformat --check on src tests tools
#   shell   shellcheck -x on every tracked or new *.sh
#   python  ruff check + ruff format --check on the session recorder
#   scripts/lint.sh [gd|shell|python ...]     default: all three
# Fix formatting by hand: gdformat <file>, ruff format <file>.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly GD_DIRS=(src tests tools)
readonly PY_DIRS=(tools tests/recording)

lint_gd() {
    need gdlint gdformat
    local files=()
    mapfile -t files < <(find "${GD_DIRS[@]}" -name '*.gd' -type f | sort)
    # gdtoolkit builds its parser cache (~/.cache/gdtoolkit) on first use with a
    # check-then-create that races when several processes start cold (a fresh CI
    # runner): one serial run of each tool warms it before the parallel batches.
    gdlint "${files[0]}" >/dev/null
    gdformat --check "${files[0]}" >/dev/null 2>&1 || true # the batches below judge the format
    # One process per batch of files, a few batches at once: gdlint parses slowly.
    printf '%s\0' "${files[@]}" | xargs -0 -n 12 -P 4 gdlint >/dev/null
    printf '%s\0' "${files[@]}" | xargs -0 -n 12 -P 4 gdformat --check >/dev/null 2>&1 || {
        gdformat --check "${files[@]}" 2>&1 | grep -v 'left unchanged' >&2 || true
        return 1
    }
    echo "lint gd: ${#files[@]} files ok"
}

lint_shell() {
    need shellcheck
    local files=()
    mapfile -t files < <(git ls-files --cached --others --exclude-standard -- '*.sh' | sort)
    shellcheck -x "${files[@]}"
    echo "lint shell: ${#files[@]} files ok"
}

lint_python() {
    need ruff
    ruff check --quiet "${PY_DIRS[@]}"
    ruff format --quiet --check "${PY_DIRS[@]}"
    echo "lint python: ok"
}

main() {
    cd "$REPO_ROOT"
    local parts=("$@") part
    [[ ${#parts[@]} -gt 0 ]] || parts=(gd shell python)
    for part in "${parts[@]}"; do
        case "$part" in
            gd) lint_gd ;;
            shell) lint_shell ;;
            python) lint_python ;;
            *)
                echo "usage: lint.sh [gd|shell|python ...]" >&2
                exit 2
                ;;
        esac
    done
    echo "lint: ok"
}

main "$@"
