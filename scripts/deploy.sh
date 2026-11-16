#!/bin/bash

# ============================================================================
# Deploys origin/main to where the game runs: kuhy's checkout
# (~/src/fifteen-dollar-siege, played with ./run.sh). Refuses a dirty tree,
# fast-forwards it, reruns ./install.sh (tools, links, recorder venv), then
# its smoke gate (import, boot, quit: no SCRIPT ERROR) as the health check.
# Idempotent; non-zero unless the checkout is at origin/main and healthy.
#   scripts/deploy.sh
#   SIEGE_DEPLOY_DIR=/path   another checkout (the test uses a fixture)
# ============================================================================

set -euo pipefail

readonly DIR="${SIEGE_DEPLOY_DIR:-$HOME/src/fifteen-dollar-siege}"

die() {
    echo "deploy: FAILED ($1)" >&2
    exit 1
}

main() {
    [[ -d "$DIR/.git" ]] || die "no checkout at $DIR"
    [[ -z "$(git -C "$DIR" status --porcelain)" ]] || die "$DIR has local changes"
    git -C "$DIR" checkout -q main || die "cannot switch $DIR to main"
    git -C "$DIR" pull -q --ff-only origin main || die "cannot fast-forward $DIR"
    local head want
    head="$(git -C "$DIR" rev-parse HEAD)"
    want="$(git -C "$DIR" rev-parse origin/main)"
    [[ "$head" == "$want" ]] || die "$DIR is at ${head:0:7}, origin/main is ${want:0:7}"
    (cd "$DIR" && ./install.sh) || die "install.sh failed"
    (cd "$DIR" && scripts/check.sh smoke) || die "the smoke check failed"
    echo "deploy: $DIR at ${head:0:7}, installed, smoke ok"
}

main "$@"
