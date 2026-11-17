#!/bin/bash

# ============================================================================
# Proves scripts/mount_dev_tools.sh without the network: the default pin is
# exactly the GitHub URL and the release tag; against a throwaway fixture
# remote (a commit hash, as SIEGE_UTILS_DEVTOOLS_REF) it mounts a symlink on
# kuhy's machine and a real copy in CI, reruns cleanly, and a ref that does
# not exist fails loudly instead of leaving a half mount.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly MOUNT="$REPO_ROOT/scripts/mount_dev_tools.sh"
readonly EXPECTED_PIN="https://github.com/kuhyx/utils godot-dev-tools-v0.2.1"
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "mount test: FAILED ($1)" >&2
    exit 1
}

# A fixture "utils" remote with one commit holding the addon's entry script.
make_remote() {
    local remote="$1"
    mkdir -p "$remote/godot_dev_tools/addons/dev_tools" "$remote/godot_dev_tools/addons/app_errors" "$remote/other"
    echo "extends Node" >"$remote/godot_dev_tools/addons/dev_tools/dev_tools.gd"
    echo "extends Node" >"$remote/godot_dev_tools/addons/app_errors/error_reporter.gd"
    echo "not the addon" >"$remote/other/file.txt"
    git -C "$remote" init -q
    git -C "$remote" add -A
    git -C "$remote" -c user.name=t -c user.email=t@example.invalid commit -q -m fixture
}

main() {
    local pin
    pin="$(env -u SIEGE_UTILS_REMOTE -u SIEGE_UTILS_DEVTOOLS_REF "$MOUNT" --print-pin)"
    [[ "$pin" == "$EXPECTED_PIN" ]] || fail "default pin is '$pin', expected '$EXPECTED_PIN'"

    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/mount.XXXXXX")"
    trap cleanup EXIT
    make_remote "$TMP/remote"
    local hash project="$TMP/project"
    hash="$(git -C "$TMP/remote" rev-parse HEAD)"
    export SIEGE_UTILS_REMOTE="file://$TMP/remote" SIEGE_UTILS_DEVTOOLS_REF="$hash"
    export SIEGE_UTILS_CACHE="$TMP/cache"

    env -u CI "$MOUNT" --into "$project" >/dev/null
    [[ -L "$project/addons/dev_tools" ]] || fail "no symlink on a local install"
    [[ -f "$project/addons/dev_tools/dev_tools.gd" ]] || fail "the link does not reach the addon"
    [[ -L "$project/addons/app_errors" ]] || fail "no app_errors symlink"
    [[ -f "$project/addons/app_errors/error_reporter.gd" ]] || fail "the app_errors link does not reach the addon"
    local extra
    for extra in "$TMP"/cache/*/other; do
        [[ ! -e "$extra" ]] || fail "more than the addon was checked out"
    done
    [[ "$(env -u CI "$MOUNT" --into "$project" | grep -c '^ok ')" -eq 2 ]] || fail "a rerun is not a no-op"

    CI=1 "$MOUNT" --into "$project" >/dev/null
    [[ -d "$project/addons/dev_tools" && ! -L "$project/addons/dev_tools" ]] ||
        fail "CI must get a real copy"
    [[ -f "$project/addons/dev_tools/dev_tools.gd" ]] || fail "the CI copy is empty"
    [[ -f "$project/addons/app_errors/error_reporter.gd" && ! -L "$project/addons/app_errors" ]] ||
        fail "CI must get a real app_errors copy"

    if SIEGE_UTILS_DEVTOOLS_REF=no-such-tag "$MOUNT" --into "$TMP/other" 2>/dev/null; then
        fail "a missing ref must fail"
    fi
    [[ ! -e "$TMP/other/addons/dev_tools" ]] || fail "a failed fetch left a mount"
    echo "mount: PASS (pin $EXPECTED_PIN; symlink, CI copy, rerun, missing ref)"
}

main "$@"
