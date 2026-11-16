#!/bin/bash

# ============================================================================
# Driver of scripts/e2e_recording.sh gap (runs INSIDE the private Xvfb): starts
# the recorder around the flasher, then unmaps the game window for 2 s and maps
# it again, like an i3 workspace switch. Needs jq. Usage: gap_driver.sh <session> <feedback-dir> <audio>
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT
readonly UNMAP_AFTER_S=3
readonly UNMAP_FOR_S=2

main() {
    local session="$1" feedback="$2" audio="$3" win="" tick
    local python
    python="$("$ROOT/tools/recording/build.sh" --venv)"
    "$python" -I "$ROOT/tools/recording/siege_recording.py" wrap --audio "$audio" --session "$session" -- \
        python3 "$ROOT/tests/recording/flasher.py" --dev "--session-id=$session" "--feedback-dir=$feedback" &
    local wrapper=$!
    # The recorder writes the game window's id into its meta file once it has found it.
    local meta="$feedback/recordings/$session.rec.json"
    for ((tick = 0; tick < 120 && ${#win} == 0; tick++)); do
        [[ ! -s "$meta" ]] || win="$(jq -r '.window.id' "$meta")"
        [[ -n "$win" ]] || sleep 0.25
    done
    [[ -n "$win" ]] || { echo "gap_driver: no game window" >&2; exit 1; }
    sleep "$UNMAP_AFTER_S"
    xdotool windowunmap "$win"
    sleep "$UNMAP_FOR_S"
    xdotool windowmap "$win"
    wait "$wrapper"
}

main "$@"
