#!/bin/bash

# ============================================================================
# Proves scripts/deploy.sh against a fixture remote and a fixture checkout
# (stub install.sh and scripts/check.sh, so no real install runs): a checkout
# behind the remote is fast-forwarded, installed and smoke-checked; a rerun
# is a no-op that still passes; a dirty checkout, a failing install or a
# failing health check exits non-zero.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly DEPLOY="$REPO_ROOT/scripts/deploy.sh"
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "deploy test: FAILED ($1)" >&2
    exit 1
}

commit_all() {
    git -C "$1" add -A
    git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q -m "$2"
}

# A remote whose install.sh logs its run and whose smoke gate obeys a file.
make_remote() {
    local src="$1" remote="$2"
    mkdir -p "$src/scripts"
    cat >"$src/install.sh" <<'STUB'
#!/bin/bash
echo installed >>"$(dirname "$0")/install.log"
[[ ! -f "$(dirname "$0")/.fail_install" ]]
STUB
    cat >"$src/scripts/check.sh" <<'STUB'
#!/bin/bash
[[ "$*" == smoke ]] || exit 2
[[ ! -f "$(dirname "$0")/../.fail_smoke" ]]
STUB
    printf '%s\n' 'install.log' '.fail_*' >"$src/.gitignore"
    chmod +x "$src/install.sh" "$src/scripts/check.sh"
    git -C "$src" init -q -b main
    commit_all "$src" one
    git clone -q --bare "$src" "$remote"
}

deploy_to() {
    SIEGE_DEPLOY_DIR="$1" "$DEPLOY" >"$TMP/out.txt" 2>&1
}

main() {
    TMP="$(mktemp -d)"
    trap cleanup EXIT
    local src="$TMP/src" remote="$TMP/remote.git" live="$TMP/live"
    make_remote "$src" "$remote"
    git clone -q "$remote" "$live"

    # 1. Behind: fast-forwarded, installed, healthy.
    echo two >"$src/two.txt"
    commit_all "$src" two
    git -C "$src" push -q "$remote" main
    deploy_to "$live" || fail "behind: $(cat "$TMP/out.txt")"
    [[ -f "$live/two.txt" ]] || fail "behind: the checkout was not updated"
    [[ "$(git -C "$live" rev-parse HEAD)" == "$(git -C "$remote" rev-parse main)" ]] ||
        fail "behind: HEAD is not the remote main"
    grep -q installed "$live/install.log" || fail "behind: install.sh did not run"

    # 2. Rerun: idempotent.
    deploy_to "$live" || fail "rerun: $(cat "$TMP/out.txt")"

    # 3. Failing health check, failing install: non-zero.
    touch "$live/.fail_smoke"
    ! deploy_to "$live" || fail "a failing smoke check passed"
    rm "$live/.fail_smoke"
    touch "$live/.fail_install"
    ! deploy_to "$live" || fail "a failing install passed"
    rm "$live/.fail_install"

    # 4. Dirty checkout: refused, the change kept.
    echo local >>"$live/two.txt"
    ! deploy_to "$live" || fail "a dirty checkout was deployed"
    grep -q local "$live/two.txt" || fail "the dirty change was lost"
    echo "deploy: PASS (fast-forward, install, smoke; rerun; dirty, install and smoke failures refused)"
}

main "$@"
