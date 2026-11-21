#!/bin/bash

# ============================================================================
# Proves scripts/mount_credit.sh without the network: the default pin is exactly
# the GitHub URL and the release tag; against a throwaway fixture remote (a commit hash)
# it mounts a symlink on kuhy's machine and a real copy in CI, reruns cleanly, and a
# ref that does not exist fails loudly instead of leaving a half mount.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly MOUNT="$REPO_ROOT/scripts/mount_credit.sh"
readonly EXPECTED_PIN="https://github.com/kuhyx/utils kuhy-credit-v0.3.0"
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "mount test: FAILED ($1)" >&2
    exit 1
}

make_remote() {
    local remote="$1"
    mkdir -p "$remote/kuhy_credit/godot/addons/kuhy_credit"
    echo "extends Control" >"$remote/kuhy_credit/godot/addons/kuhy_credit/kuhy_credit.gd"
    echo "extends RefCounted" >"$remote/kuhy_credit/godot/addons/kuhy_credit/credit_data.gd"
    git -C "$remote" init -q
    git -C "$remote" add -A
    git -C "$remote" -c user.name=t -c user.email=t@example.invalid commit -q -m fixture
}

main() {
    local pin
    pin="$(env -u SIEGE_UTILS_REMOTE -u SIEGE_UTILS_CREDIT_REF "$MOUNT" --print-pin)"
    [[ "$pin" == "$EXPECTED_PIN" ]] || fail "default pin is '$pin', expected '$EXPECTED_PIN'"

    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/mount.XXXXXX")"
    trap cleanup EXIT
    make_remote "$TMP/remote"
    local hash project="$TMP/project"
    hash="$(git -C "$TMP/remote" rev-parse HEAD)"
    export SIEGE_UTILS_REMOTE="file://$TMP/remote" SIEGE_UTILS_CREDIT_REF="$hash"
    export SIEGE_UTILS_CACHE="$TMP/cache"

    env -u CI "$MOUNT" --into "$project" >/dev/null
    [[ -L "$project/addons/kuhy_credit" ]] || fail "no symlink on a local install"
    [[ -f "$project/addons/kuhy_credit/kuhy_credit.gd" ]] || fail "the link does not reach the addon"

    [[ "$(env -u CI "$MOUNT" --into "$project" | grep -c '^ok ')" -eq 2 ]] || fail "a rerun is not a no-op"

    CI=1 "$MOUNT" --into "$project" >/dev/null
    [[ -d "$project/addons/kuhy_credit" && ! -L "$project/addons/kuhy_credit" ]] ||
        fail "CI must get a real copy"
    [[ -f "$project/addons/kuhy_credit/kuhy_credit.gd" ]] || fail "the CI copy is empty"

    if SIEGE_UTILS_CREDIT_REF=no-such-tag "$MOUNT" --into "$TMP/other" 2>/dev/null; then
        fail "a missing ref must fail"
    fi
    [[ ! -e "$TMP/other/addons/kuhy_credit" ]] || fail "a failed fetch left a mount"
    echo "mount: PASS (pin $EXPECTED_PIN; symlink, CI copy, rerun, missing ref)"
}

main "$@"