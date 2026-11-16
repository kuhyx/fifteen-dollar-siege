#!/bin/bash

# ============================================================================
# The web item of the hand-off walk (sourced by handoff.sh for ITEM_KIND=web):
# the newest builds/vNN served on a loopback port the OS picks, opened in
# kuhy's own browser. --check opens the same URL in an isolated, muted Chromium
# on a private Xvfb screen instead (it never reaches xdg-open) and passes when
# the browser fetched the game's data file.
# ============================================================================

readonly SERVE_WAIT_TICKS=100 # x 0.1 s
readonly BOOT_WAIT_TICKS=150  # x 0.1 s
WEB_URL=""

# The newest round: the highest builds/vNN with an index.html.
newest_build() {
    local dir
    while read -r dir; do
        [[ -f "$dir/index.html" ]] && echo "$dir"
    done < <(find -L "$BINARIES/builds" -maxdepth 1 -type d -name 'v[0-9]*' | sort -rV)
}

# Serves $1 on 127.0.0.1 and sets WEB_URL; the server log is $HANDOFF_TMP/server.log.
start_server() {
    local tick port=""
    python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$1" >"$HANDOFF_TMP/server.log" 2>&1 &
    HANDOFF_PIDS+=($!)
    for ((tick = 0; tick < SERVE_WAIT_TICKS; tick++)); do
        port="$(sed -n 's/^Serving HTTP on [^ ]* port \([0-9]*\) .*/\1/p' "$HANDOFF_TMP/server.log")"
        [[ -z "$port" ]] || break
        sleep 0.1
    done
    [[ -n "$port" ]] || {
        echo "$ITEM_ID: the local web server did not start" >&2
        return 1
    }
    WEB_URL="http://127.0.0.1:$port/index.html"
}

# The first browser of the machine, the same names tools/web/browser.py tries.
find_browser() {
    local name
    for name in chromium google-chrome-stable google-chrome chromium-browser; do
        command -v "$name" && return 0
    done
    echo "$ITEM_ID: no chromium or chrome found (run ./install.sh)" >&2
    return 1
}

# The build to judge; empty (and a message) when no round exists yet.
pick_build() {
    BUILD_DIR="$(newest_build | head -n 1)"
    [[ -n "$BUILD_DIR" ]] || echo "$ITEM_ID: no builds/vNN with an index.html in $BINARIES/builds" >&2
    [[ -n "$BUILD_DIR" ]]
}

show_web() {
    local opener
    pick_build || return 1
    start_server "$BUILD_DIR" || return 1
    opener="$(command -v xdg-open || true)"
    [[ -n "$opener" ]] || {
        echo "$ITEM_ID: xdg-open not found; open $WEB_URL yourself" >&2
    }
    printf '  %s  (%s)\n' "$WEB_URL" "$(basename "$BUILD_DIR")"
    [[ -z "$opener" ]] || "$opener" "$WEB_URL" >/dev/null 2>&1 || true
    printf '  press Enter when you have seen enough. '
    read -r _ || true
}

check_web() {
    local browser tick=0 profile="$HANDOFF_TMP/profile"
    if ! pick_build; then
        if [[ -n "${CI:-}" ]]; then
            echo "$ITEM_ID: check skipped (CI has no builds/)"
            return 0
        fi
        return 1
    fi
    start_server "$BUILD_DIR"
    browser="$(find_browser)"
    mkdir -p "$profile"
    HANDOFF_PIDS+=("$(
        "$REPO_ROOT/scripts/xvfb_run.sh" "$CHECK_SIZE" "$browser" --mute-audio \
            "--user-data-dir=$profile" --no-first-run --disable-extensions --use-gl=angle \
            --use-angle=swiftshader --enable-unsafe-swiftshader ${CI:+--no-sandbox} \
            "$WEB_URL" >/dev/null 2>&1 &
        echo $!
    )")
    while ((tick++ < BOOT_WAIT_TICKS)); do
        grep -q '"GET /index.pck HTTP/1.1" 200' "$HANDOFF_TMP/server.log" && break
        sleep 0.1
    done
    pkill -f -- "--user-data-dir=$profile" 2>/dev/null || true
    # The browser writes its profile while it exits: wait it out, or the cleanup's rm races it.
    tick=0
    while ((tick++ < BOOT_WAIT_TICKS)) && pgrep -f -- "--user-data-dir=$profile" >/dev/null; do
        sleep 0.1
    done
    grep -q '"GET /index.pck HTTP/1.1" 200' "$HANDOFF_TMP/server.log" || {
        echo "$ITEM_ID: the browser never fetched the game's data (log $HANDOFF_TMP/server.log)" >&2
        tail -n 5 "$HANDOFF_TMP/server.log" >&2
        return 1
    }
    echo "$ITEM_ID: check ok ($(basename "$BUILD_DIR") served and fetched by an isolated Chromium)"
}
