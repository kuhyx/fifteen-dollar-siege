#!/bin/bash

# ============================================================================
# Runs ./run.sh the way kuhy does (--dev, real main scene), but on a private
# Xvfb, muted, and makes the dev tools annotate one frozen battle frame
# (--dev-shot), so one run proves the launcher AND the F12 bundle:
#   fallback  GPU OpenGL is unusable (a stand-in glxinfo that fails, the state
#             after an NVIDIA driver upgrade without a reboot): run.sh must
#             switch to Mesa and the game must still start (lesson L2)
#   nvidia    the NVIDIA GLX + EGL vendor forced under Xvfb: the real repro on
#             a half-upgraded driver, a plain GPU run on a healthy one
#             (skipped on a machine without the NVIDIA vendor file)
# Each case passes only with exit 0, no SCRIPT ERROR, every bundle file, a
# text and a select mark in report.json and no blank frame.
#   scripts/test_launcher.sh [fallback|nvidia ...]   default: both
#   KEEP=1 keeps the bundles (the path is printed) for a human or agent to Read.
# ============================================================================

set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=scripts/lib/bot.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/bot.sh"

readonly SIZE=1920x1080
readonly NVIDIA_EGL=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
readonly BUNDLE_FILES=(screenshot.png annotated.png overlay.png report.json game.log snapshot.json)
readonly FALLBACK_NOTE="using Mesa software rendering"
TMP=""

cleanup() {
    if [[ -n "${KEEP:-}" ]]; then
        echo "launcher: kept $TMP"
    else
        [[ -z "$TMP" ]] || rm -rf "$TMP"
    fi
}

# Runs run.sh once into $1 (a fresh dir); the rest are env assignments.
launch() {
    local dir="$1" code=0
    shift
    mkdir -p "$dir"
    env "$@" SIEGE_ENGINE_ARGS="--audio-driver Dummy --resolution $SIZE" \
        "$CAPPED_OR_ENV" timeout -k 3 40 "$REPO_ROOT/scripts/xvfb_run.sh" "$SIZE" \
        "$REPO_ROOT/run.sh" --mode=command --loadout=double_men,fifty_men --seed=7 \
        "--save-dir=$dir/save" "--feedback-dir=$dir/feedback" "--dev-shot=$dir/shot.png" \
        >"$dir/log.txt" 2>&1 || code=$?
    if ((code != 0)) || grep -q 'SCRIPT ERROR' "$dir/log.txt"; then
        tail -30 "$dir/log.txt" >&2
        echo "launcher: run.sh FAILED (exit $code, log $dir/log.txt)" >&2
        return 1
    fi
}

# The bundle the scripted F12 saved into $1/shot/.
check_bundle() {
    local dir="$1" bundle="$1/shot" file
    for file in "${BUNDLE_FILES[@]}"; do
        [[ -s "$bundle/$file" ]] || {
            echo "launcher: $bundle/$file is missing or empty" >&2
            return 1
        }
    done
    jq -e '([.shapes[].tool] | index("text") and index("select"))
        and (.selected | length) >= 1 and .mode == "command" and .screen == "battle"' \
        "$bundle/report.json" >/dev/null || {
        echo "launcher: report.json lacks the text or select mark" >&2
        return 1
    }
    compgen -G "$dir/feedback/feedback-*.md" >/dev/null || {
        echo "launcher: no Markdown entry in $dir/feedback" >&2
        return 1
    }
    frames_ok "$bundle/screenshot.png" "$bundle/annotated.png" "$bundle/overlay.png" >/dev/null
}

case_fallback() {
    local dir="$TMP/fallback"
    mkdir -p "$dir/bin"
    printf '#!/bin/bash\nexit 1\n' >"$dir/bin/glxinfo"
    chmod +x "$dir/bin/glxinfo"
    launch "$dir" "PATH=$dir/bin:$PATH"
    grep -q "$FALLBACK_NOTE" "$dir/log.txt" || {
        echo "launcher: run.sh did not fall back to Mesa" >&2
        return 1
    }
    check_bundle "$dir"
    echo "launcher fallback: PASS (Mesa fallback, bundle complete)"
}

case_nvidia() {
    local dir="$TMP/nvidia" note="GPU OpenGL"
    if [[ ! -f "$NVIDIA_EGL" ]]; then
        echo "launcher nvidia: skipped (no $NVIDIA_EGL on this machine)"
        return 0
    fi
    launch "$dir" __GLX_VENDOR_LIBRARY_NAME=nvidia "__EGL_VENDOR_LIBRARY_FILENAMES=$NVIDIA_EGL"
    check_bundle "$dir"
    ! grep -q "$FALLBACK_NOTE" "$dir/log.txt" || note="Mesa fallback: the driver is broken"
    echo "launcher nvidia: PASS ($note, bundle complete)"
}

main() {
    need godot Xvfb jq
    CAPPED_OR_ENV="$CAPPED"
    [[ -x "$CAPPED" ]] || CAPPED_OR_ENV="env"
    mkdir -p "$SCRATCH"
    TMP="$(mktemp -d "$SCRATCH/launcher.XXXXXX")"
    trap cleanup EXIT
    local cases=("$@") one
    [[ ${#cases[@]} -gt 0 ]] || cases=(fallback nvidia)
    for one in "${cases[@]}"; do
        case "$one" in
            fallback) case_fallback ;;
            nvidia) case_nvidia ;;
            *)
                echo "usage: test_launcher.sh [fallback|nvidia ...]" >&2
                exit 2
                ;;
        esac
    done
    echo "launcher: PASS"
}

main "$@"
