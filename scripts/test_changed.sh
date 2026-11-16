#!/bin/bash

# ============================================================================
# Run only the tests related to files changed vs HEAD (staged, unstaged and
# untracked). Game code (GDScript, scenes, project settings) runs the GUT
# suite: GUT cannot select tests by changed file and the whole suite takes a
# few seconds. The session recorder (Python) runs its unit tests. A change
# that maps to neither (docs, CI) runs nothing; an unmappable one runs both.
# Quiet: failures in full, else one summary line per suite.
# ============================================================================

set -euo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

main() {
    local changed=() file game=0 recorder=0
    while IFS= read -r file; do
        [[ -n "$file" && -e "$file" ]] && changed+=("$file")
    done < <({
        git diff --name-only HEAD 2>/dev/null || true
        git ls-files --others --exclude-standard
    } | sort -u)
    if [[ ${#changed[@]} -eq 0 ]]; then
        echo "no changes vs HEAD: nothing to test"
        return 0
    fi
    for file in "${changed[@]}"; do
        case "$file" in
            tools/recording/* | tests/recording/* | scripts/test_recording.sh | scripts/lib/recording.sh) recorder=1 ;;
            *.md | .github/* | CREDITS* | .gitignore) ;;
            *.gd | *.tscn | *.tres | *.godot | *.cfg | .gutconfig.json | scripts/test.sh) game=1 ;;
            *)
                game=1
                recorder=1
                ;;
        esac
    done
    if ((game == 0 && recorder == 0)); then
        echo "no code changes vs HEAD: nothing to test"
        return 0
    fi
    ((game == 0)) || scripts/test.sh
    ((recorder == 0)) || scripts/test_recording.sh
}

main "$@"
