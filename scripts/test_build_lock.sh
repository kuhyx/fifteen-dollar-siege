#!/bin/bash

# ============================================================================
# Proves hold_build_lock (scripts/lib/common.sh) against a fixture of the todo
# board's machine-wide build lock: a `godot` shim on PATH that queues every
# launch on one flock. A gate that runs godots side by side, each under a
# short `timeout`, must take that lock ONCE and run them all without queueing
# (before: a busy lock ate the timeout and the gate reported a blank frame).
# Without a shim, or with the lock already held, the helper changes nothing.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

readonly HOLD_S=4    # another build holds the lock this long
readonly LIMIT_S=2   # each godot of the fixture gate gets this long
TMP=""

cleanup() {
    [[ -z "$TMP" ]] || rm -rf "$TMP"
}

fail() {
    echo "build lock test: FAILED ($1)" >&2
    exit 1
}

# The board's lock in miniature: shims/godot -> buildlock.sh -> bin/godot,
# one flock for everything, TODOIMPL_BUILD_LOCK_HELD=1 for what runs inside.
make_rig() {
    local rig="$1"
    mkdir -p "$rig/shims" "$rig/bin"
    printf '%s\n' '#!/bin/bash' 'echo "ran $*"' >"$rig/bin/godot"
    cat >"$rig/buildlock.sh" <<EOF
#!/bin/bash
set -euo pipefail
tool="\$1"
shift
real="\$(PATH="$rig/bin:/usr/bin:/bin" command -v "\$tool")"
[[ "\${TODOIMPL_BUILD_LOCK_HELD:-}" == 1 ]] && exec "\$real" "\$@"
exec 9>>"$rig/build.lock"
flock 9
export TODOIMPL_BUILD_LOCK_HELD=1
"\$real" "\$@" 9>&-
EOF
    printf '%s\n' '#!/bin/bash' "exec $rig/buildlock.sh godot \"\$@\"" >"$rig/shims/godot"
    # The fixture gate: three godots side by side, each under a short timeout.
    cat >"$rig/gate.sh" <<EOF
#!/bin/bash
set -euo pipefail
source "$REPO_ROOT/scripts/lib/common.sh"
hold_build_lock "\$0" "\$@"
pids=()
for i in 1 2 3; do timeout $LIMIT_S godot --headless "\$i" & pids+=(\$!); done
for pid in "\${pids[@]}"; do wait "\$pid"; done
echo "gate held=\${TODOIMPL_BUILD_LOCK_HELD:-0}"
EOF
    chmod +x "$rig/bin/godot" "$rig/buildlock.sh" "$rig/shims/godot" "$rig/gate.sh"
}

# The fixture gate on a PATH whose godot is the rig's shim (never the board's).
run_gate_with_shim() {
    local rig="$1" path
    path="$(tr ':' '\n' <<<"$PATH" | grep -v '/shims$' | paste -sd:)"
    env -u TODOIMPL_BUILD_LOCK_HELD PATH="$rig/shims:$path" "$rig/gate.sh"
}

main() {
    TMP="$(mktemp -d)"
    trap cleanup EXIT
    local rig="$TMP/rig" out code=0
    make_rig "$rig"

    # 1. A busy lock: the gate waits once, then every godot runs in time.
    flock "$rig/build.lock" sleep "$HOLD_S" &
    sleep 0.3
    out="$(run_gate_with_shim "$rig" 2>&1)" || code=$?
    wait
    [[ "$code" -eq 0 ]] || fail "busy lock: the gate exited $code: $out"
    [[ "$(grep -c '^ran ' <<<"$out")" -eq 3 ]] || fail "busy lock: not every godot ran: $out"
    grep -q '^gate held=1$' <<<"$out" || fail "the gate did not run under the lock: $out"

    # 2. No shim on PATH: the helper is a no-op (CI, kuhy's shell).
    out="$(env -u TODOIMPL_BUILD_LOCK_HELD PATH="$rig/bin:/usr/bin:/bin" "$rig/gate.sh" 2>&1)" ||
        fail "no shim: $out"
    grep -q '^gate held=0$' <<<"$out" || fail "no shim: the gate took a lock: $out"

    # 3. The lock already held (a gate inside check.sh): no second wait.
    flock "$rig/build.lock" sleep "$HOLD_S" &
    sleep 0.3
    out="$(TODOIMPL_BUILD_LOCK_HELD=1 PATH="$rig/shims:$PATH" timeout "$LIMIT_S" "$rig/gate.sh" 2>&1)" ||
        fail "held lock: the gate queued again: $out"
    wait
    echo "build lock: PASS (busy lock waited once, no shim and held lock untouched)"
}

main "$@"
