#!/bin/bash

# ============================================================================
# Proves a release build works without the dev tools: exports the Linux preset
# into a throwaway folder, checks the pack holds no src/dev file, then runs the
# exported binary's own --autodrive bot headless (muted, no window) with --dev
# on the command line: the game must say the dev tools are not in the build
# and the bot must still reach its PASS verdict.
#   scripts/test_export.sh [watch|command|lab]     default: watch
# Needs the export templates (install.sh).
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

main() {
    need godot
    local mode="${1:-watch}" code=0
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/export.XXXXXX")"
    trap cleanup EXIT
    "$REPO_ROOT/scripts/export.sh" linux "$TMP/linux"
    cap timeout -k 3 40 "$TMP/linux/fifteen-dollar-siege.x86_64" --headless "${BOT_ENGINE_FLAGS[@]}" -- \
        --dev "--autodrive=$mode" --speed=16 --seed=7 --lab-runs=30 \
        "--save-dir=$TMP/save" "--result-file=$TMP/result" >"$TMP/log.txt" 2>&1 || code=$?
    bot_judge "export $mode" "$code" "$TMP/log.txt" "$TMP/result" || exit 1
    grep -q 'src/dev/dev_tools.gd is not in this build' "$TMP/log.txt" || {
        echo "export: the build still loads the dev tools" >&2
        exit 1
    }
    echo "export: PASS (the Linux build plays $mode without src/dev)"
}

main "$@"
