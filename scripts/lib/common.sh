#!/bin/bash

# ============================================================================
# Shared helpers of every script in this repo (sourced, never executed):
# where the repo is, where throwaway files go, the resource cap, tool checks.
# ============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT
export CAPPED="${HOME}/.claude/scripts/capped.sh"
export REPO_NAME="fifteen-dollar-siege"
# Every gate (tests, smoke, autodrive, export) runs with the shared error
# reporter off: its errors are not a player's and must not become tickets.
export APP_ERRORS_OFF=1
# kuhy's binaries folder (feedback, builds, fetched assets); install.sh makes it.
export BINARIES="${SIEGE_BINARIES:-$HOME/data/${REPO_NAME}_binaries}"

# Logs, shots and bot saves: one directory PER CHECKOUT, so runs from sibling
# worktrees never share a save or overwrite each other's evidence.
_scratch_base() {
    if [[ -d "$HOME/data/claude-scratch" ]]; then
        echo "$HOME/data/claude-scratch"
    else
        echo "${TMPDIR:-/tmp}"
    fi
}
export SCRATCH="${SCRATCH:-$(_scratch_base)/$REPO_NAME/$(basename "$REPO_ROOT")}"

# Runs a command inside capped.sh when it exists (kuhy's machine), else directly.
cap() {
    if [[ -x "$CAPPED" ]]; then
        "$CAPPED" "$@"
    else
        "$@"
    fi
}

# Fails early when a tool the script needs is missing.
need() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null || {
            echo "Error: $tool not found (run ./install.sh)" >&2
            exit 1
        }
    done
}

# Fails when GUT is not there (install.sh fetches it; it is not in git).
need_gut() {
    [[ -f "$REPO_ROOT/addons/gut/gut_cmdln.gd" ]] || {
        echo "Error: addons/gut is missing (run ./install.sh)" >&2
        exit 1
    }
}

# The todo board puts a `godot` shim on PATH that queues every launch on one
# machine-wide build lock. A gate that runs godots side by side, each under a
# `timeout`, would then queue its own runs behind each other and let the wait
# eat the timeouts (the autodrive gate failed "a blank frame" that never
# drew). So an entry script calls this first: when godot is such a shim and
# the lock is not held yet, the script reruns ONCE under that lock (waiting
# with no timeout), and every godot inside skips it. Elsewhere a no-op.
#   hold_build_lock "$0" "$@"
hold_build_lock() {
    [[ "${TODOIMPL_BUILD_LOCK_HELD:-}" != 1 ]] || return 0
    local shim lock
    shim="$(command -v godot)" || return 0
    lock="$(head -c 512 "$shim" | sed -n 's/^exec \(.*\/buildlock\.sh\) godot .*/\1/p')"
    [[ -n "$lock" && -x "$lock" ]] || return 0
    exec "$lock" bash "$@"
}
