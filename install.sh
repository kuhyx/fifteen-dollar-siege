#!/bin/bash

# ============================================================================
# Install everything fifteen-dollar-siege needs (idempotent; rerun after a pull):
#   - Godot 4.7.2 and the system tools the scripts call (pacman, or apt in CI)
#   - gdtoolkit, pre-commit, ruff, coverage: exact pins from requirements-dev.txt
#   - GUT (pinned tag) into addons/gut (gitignored)
#   - Chromium (the web smoke gate; CI uses the runner's Chrome) and its pinned
#     Python venv (tools/web/venv.sh)
#   - Godot export templates for the installed Godot (downloaded if missing)
#   - the music and sound effects, rendered from code into assets/audio/
#     (tools/audio/build.sh: its own Python venv with the pinned music toolkit)
#   - the session recorder's venv (tools/recording/build.sh: the pinned game_recording
#     package of kuhyx/utils)
#   - ~/data/fifteen-dollar-siege_binaries with assets/ builds/ feedback/, and
#     the gitignored links assets -> .../assets and builds -> .../builds
#   - git hooks (skip with SKIP_HOOKS=1; never in CI)
# CI=1 (GitHub Actions) installs only what the CI gates use (plus the export
# templates and the web venv: the web smoke gate runs there too).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
readonly GUT_TAG="v9.7.1"
readonly BINARIES="${SIEGE_BINARIES:-$HOME/data/fifteen-dollar-siege_binaries}"
readonly TEMPLATE_FILES=(linux_release.x86_64 web_nothreads_release.zip)
# tool:pacman package:apt package. The first group is what CI needs too.
readonly CORE_TOOLS=(git:git:git shellcheck:shellcheck:shellcheck ffmpeg:ffmpeg:ffmpeg)
readonly DESKTOP_TOOLS=(
    Xvfb:xorg-server-xvfb:xvfb glxinfo:mesa-utils:mesa-utils xdotool:xdotool:xdotool
    xprop:xorg-xprop:x11-utils mpv:mpv:mpv pactl:libpulse:pulseaudio-utils
    curl:curl:curl unzip:unzip:unzip jq:jq:jq chromium:chromium:chromium
)

in_ci() {
    [[ -n "${CI:-}" ]]
}

# Installs system packages with the machine's package manager.
pkg_install() {
    if command -v pacman >/dev/null; then
        sudo pacman -S --needed --noconfirm "$@"
    elif command -v apt-get >/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq "$@"
    else
        echo "Error: no pacman or apt-get to install: $*" >&2
        exit 1
    fi
}

# Installs the missing tools of a "tool:pacman:apt" list in one call.
ensure_tools() {
    local entry tool pacman_pkg apt_pkg missing=()
    for entry in "$@"; do
        IFS=: read -r tool pacman_pkg apt_pkg <<<"$entry"
        command -v "$tool" >/dev/null && continue
        if command -v pacman >/dev/null; then
            missing+=("$pacman_pkg")
        else
            missing+=("$apt_pkg")
        fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "ok   system tools"
        return
    fi
    pkg_install "${missing[@]}"
    echo "done system tools (${missing[*]})"
}

ensure_godot() {
    if command -v godot >/dev/null; then
        echo "ok   $(godot --version)"
        return
    fi
    if ! command -v pacman >/dev/null; then
        echo "Error: godot 4.7.2 not on PATH (CI installs it in its own step)" >&2
        exit 1
    fi
    pkg_install godot
    echo "done godot"
}

# Exact pins: uv tools on kuhy's machine (Arch's Python is PEP 668 managed), pip in CI.
ensure_python_tools() {
    if in_ci; then
        python3 -m pip install --quiet -r "$REPO_ROOT/requirements-dev.txt"
        echo "done python tools (pip)"
        return
    fi
    command -v uv >/dev/null || pkg_install uv
    local spec name probe
    while IFS= read -r spec; do
        [[ -n "$spec" ]] || continue
        name="${spec%%==*}"
        probe="$name"
        [[ "$name" != gdtoolkit ]] || probe=gdlint # gdtoolkit ships gdlint, not a gdtoolkit binary
        if [[ "$("$probe" --version 2>&1 || true)" == *"${spec##*==}"* ]]; then
            echo "ok   $spec"
        else
            uv tool install --force "$spec" >/dev/null 2>&1
            echo "done $spec"
        fi
    done <"$REPO_ROOT/requirements-dev.txt"
}

ensure_gut() {
    local gut_dir="$REPO_ROOT/addons/gut" tmp
    if [[ -f "$gut_dir/plugin.cfg" ]] && grep -q "\"${GUT_TAG#v}\"" "$gut_dir/plugin.cfg"; then
        echo "ok   GUT $GUT_TAG"
        return
    fi
    tmp="$(mktemp -d)"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$GUT_TAG" \
        https://github.com/bitwes/Gut "$tmp/gut"
    rm -rf "$gut_dir"
    mkdir -p "$REPO_ROOT/addons"
    mv "$tmp/gut/addons/gut" "$gut_dir"
    rm -rf "$tmp"
    echo "done GUT $GUT_TAG"
}

ensure_templates() {
    local version dir absent=0 file tpz unpacked
    version="$(godot --version | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?')"
    dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
    for file in "${TEMPLATE_FILES[@]}"; do
        [[ -f "$dir/$file" ]] || absent=1
    done
    if [[ "$absent" -eq 0 ]]; then
        echo "ok   export templates $version"
        return
    fi
    tpz="$(mktemp --suffix=.tpz)"
    unpacked="$(mktemp -d)"
    curl -fsSL -o "$tpz" \
        "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz"
    unzip -q "$tpz" -d "$unpacked"
    mkdir -p "$dir"
    mv "$unpacked"/templates/* "$dir"/
    rm -rf "$tpz" "$unpacked"
    echo "done export templates $version"
}

# Points repo link `name` at the binaries folder's `name` (never tracked by git).
link_dir() {
    local name="$1" target link
    mkdir -p "$BINARIES/$name"
    target="$(realpath "$BINARIES/$name")"
    link="$REPO_ROOT/$name"
    if [[ "$(readlink "$link" 2>/dev/null || true)" == "$target" ]]; then
        echo "ok   $name -> $target"
        return
    fi
    if [[ -d "$link" && ! -L "$link" ]]; then
        cp -a "$link"/. "$target"/
        rm -rf "$link"
    fi
    ln -sfn "$target" "$link"
    echo "done $name -> $target"
}

link_binaries() {
    mkdir -p "$BINARIES/feedback"
    link_dir assets
    link_dir builds
    # Godot must never import exported builds.
    : >"$BINARIES/builds/.gdignore"
}

install_hooks() {
    if [[ "${SKIP_HOOKS:-0}" == "1" ]]; then
        return
    fi
    (cd "$REPO_ROOT" && pre-commit install >/dev/null)
    echo "done git hooks"
}

main() {
    ensure_tools "${CORE_TOOLS[@]}"
    ensure_godot
    ensure_python_tools
    ensure_gut
    "$REPO_ROOT/tools/web/venv.sh" >/dev/null
    ensure_templates # CI exports the Web preset for the browser smoke gate
    if ! in_ci; then
        ensure_tools "${DESKTOP_TOOLS[@]}"
        link_binaries
        install_hooks
    fi
    "$REPO_ROOT/tools/recording/build.sh"
    "$REPO_ROOT/tools/audio/build.sh"
    godot --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
    echo "install: done. Run ./run.sh"
}

main "$@"
