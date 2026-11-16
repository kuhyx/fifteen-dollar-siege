#!/bin/bash

# ============================================================================
# Mounts the shared dev feedback addon (kuhyx/utils, godot_dev_tools) at
# res://addons/dev_tools. The pin below is the ONLY place that names the repo
# and the tag; install.sh calls this script.
#   scripts/mount_dev_tools.sh               fetch (shallow, cached) and mount
#   scripts/mount_dev_tools.sh --print-pin   print "<url> <ref>" and stop
#   scripts/mount_dev_tools.sh --into DIR    mount into another project root
# The mount is a gitignored symlink into the cache (kuhy's machine) or a real
# copy (CI=1: a runner has no later use for a cache).
# Overrides, for proving an unreleased addon:
#   SIEGE_UTILS_REMOTE        another remote, e.g. file:///path/to/utils-worktree
#   SIEGE_UTILS_DEVTOOLS_REF  a tag or a full commit hash of that remote
#   SIEGE_UTILS_CACHE         the cache folder (default ~/.cache/fifteen-dollar-siege/utils)
# ============================================================================

set -euo pipefail

readonly PIN_URL="https://github.com/kuhyx/utils"
readonly PIN_TAG="godot-dev-tools-v0.1.1"
readonly ADDON_IN_REPO="godot_dev_tools/addons/dev_tools"
readonly MOUNT_REL="addons/dev_tools"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

remote="${SIEGE_UTILS_REMOTE:-$PIN_URL}"
ref="${SIEGE_UTILS_DEVTOOLS_REF:-$PIN_TAG}"
cache="${SIEGE_UTILS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/fifteen-dollar-siege/utils}"
into="$REPO_ROOT"

# Shallow-fetches `ref` of `remote` into `dir`, checking out only the addon folder.
fetch_into() {
    local dir="$1"
    git init -q "$dir"
    git -C "$dir" sparse-checkout set --no-cone "/$ADDON_IN_REPO/"
    git -C "$dir" -c advice.detachedHead=false fetch -q --depth 1 "$remote" "$ref"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

# The checkout of this remote and ref (made once; a tag or a hash never changes).
checkout_dir() {
    local key dir tmp
    key="$(printf '%s %s' "$remote" "$ref" | sha1sum | cut -c1-12)"
    dir="$cache/$key"
    if [[ ! -f "$dir/$ADDON_IN_REPO/dev_tools.gd" ]]; then
        mkdir -p "$cache"
        tmp="$(mktemp -d "$cache/.fetch.XXXXXX")"
        if ! fetch_into "$tmp"; then
            rm -rf "$tmp"
            echo "mount_dev_tools: cannot fetch $ref from $remote (is the tag pushed?)" >&2
            return 1
        fi
        rm -rf "$dir"
        mv "$tmp" "$dir"
    fi
    echo "$dir"
}

mount_addon() {
    local source link
    source="$(checkout_dir)/$ADDON_IN_REPO"
    link="$into/$MOUNT_REL"
    mkdir -p "$into/addons"
    if [[ -n "${CI:-}" ]]; then
        rm -rf "$link"
        cp -a "$source" "$link"
        echo "done dev tools $ref (copied)"
    elif [[ "$(readlink "$link" 2>/dev/null || true)" == "$source" ]]; then
        echo "ok   dev tools $ref"
    else
        rm -rf "$link"
        ln -sfn "$source" "$link"
        echo "done dev tools $ref -> $source"
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --print-pin)
                echo "$remote $ref"
                return 0
                ;;
            --into)
                into="$(realpath -m "$2")"
                shift 2
                ;;
            *)
                echo "usage: $0 [--print-pin] [--into DIR]" >&2
                return 2
                ;;
        esac
    done
    command -v git >/dev/null || {
        echo "Error: git not found" >&2
        return 1
    }
    mount_addon
}

main "$@"
