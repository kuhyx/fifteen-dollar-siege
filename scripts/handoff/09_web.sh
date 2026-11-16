#!/bin/bash

# ============================================================================
# Hand-off item: the web build, opened in your browser from the newest builds/vNN.
# Run it from any directory. It serves the build on a loopback port, opens your
# browser, asks one question and appends your answer to the feedback/ folder;
# --check opens it in an isolated, muted Chromium on a private screen instead.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/handoff.sh
source "$REPO_ROOT/scripts/lib/handoff.sh"

ITEM_ID="web"
ITEM_QUESTION="The web build in your browser: does it play like the desktop game (menus, a siege, sound after the first click)?"
ITEM_KIND=web

handoff_main "$@"
