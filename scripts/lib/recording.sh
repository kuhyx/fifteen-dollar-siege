#!/bin/bash

# ============================================================================
# How a script runs the session recorder (sourced after common.sh, never
# executed). The recorder is the `game_recording` package of kuhyx/utils in a
# cached venv (tools/recording/build.sh); this game's configuration of it is
# tools/recording/siege_recording.py.
# ============================================================================

SIEGE_RECORDING_PY="$REPO_ROOT/tools/recording/siege_recording.py"

# Prints the recorder venv's python (making the venv on the first call).
recording_python() {
    "$REPO_ROOT/tools/recording/build.sh" --venv
}

# Runs one recorder command: siege_recording <wrap|latest|list|open|finalize> ...
siege_recording() {
    local python
    python="$(recording_python)"
    "$python" -I "$SIEGE_RECORDING_PY" "$@"
}
