"""The browser smoke gate: plays the Web export in an isolated headless Chromium.

    smoke.py <web_dir> <shots_dir>

Serves <web_dir> on a loopback port the OS picks, opens it with `?probe` (see
src/app/web_probe.gd) and passes only when the game really runs: the hub shows,
a first touch starts the sound (audio context running, hub music playing and
advancing), touch taps reach the shop and then a battle, and the console never
shows an error. Frames land in <shots_dir>; the caller checks them for blank.
"""

from __future__ import annotations

import functools
import http.server
import json
import signal
import sys
import threading
import time
from pathlib import Path
from typing import Any

import websocket
from browser import Browser, Page

SIZE = (1280, 720)
BOOT_WAIT_S = 40.0
STEP_WAIT_S = 15.0
HEAR_S = 1.5
# Seconds of sound the mixer must take per rendered frame (60 fps: 0.0167).
MIN_S_PER_FRAME = 0.01
MIN_MOVED_S = 0.1
# Remembers every AudioContext the page makes, so a test can read its state.
TRACK_AUDIO = """
window.__contexts = [];
for (const name of ['AudioContext', 'webkitAudioContext']) {
  const Original = window[name];
  if (!Original) continue;
  window[name] = class extends Original {
    constructor(...args) { super(...args); window.__contexts.push(this); }
  };
}
"""


class Quiet(http.server.SimpleHTTPRequestHandler):
    """Static files without an access log."""

    def log_message(self, *_args: object) -> None:
        """Drop the access log."""


def serve(root: Path) -> http.server.ThreadingHTTPServer:
    """The build on 127.0.0.1, on a port the OS picks (never a fixed one)."""
    handler = functools.partial(Quiet, directory=str(root))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class Run:
    """One page, the probe and the checks."""

    def __init__(self, page: Page, shots: Path) -> None:
        self.page = page
        self.shots = shots
        self.failures: list[str] = []

    def probe(self) -> dict[str, Any]:
        """The game's own report, {} before it has made one."""
        raw = self.page.evaluate("window.siegeProbe || ''")
        return dict(json.loads(raw)) if raw else {}

    def wait(self, what: str, ready: Any, seconds: float = STEP_WAIT_S) -> dict[str, Any]:
        """Waits until `ready(probe)`; records a failure and returns {} on timeout."""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            self.page.pump(0.2)
            state = self.probe()
            if state and ready(state):
                return state
        self.failures.append(f"timed out waiting for {what}: {self.probe().get('screen')}")
        return {}

    def tap(self, name: str, state: dict[str, Any]) -> None:
        """A finger on the target `name` of the probe `state`."""
        target = state["targets"][name]
        scale = self.page.evaluate(
            "(() => { const c = document.querySelector('canvas'); return c.clientWidth / c.width; })()"
        )
        self.page.touch(target[0] * scale, target[1] * scale)

    def audio_state(self) -> list[str]:
        """The state of every AudioContext the page made."""
        return list(self.page.evaluate("window.__contexts.map(c => c.state)"))

    def check(self, ok: bool, what: str) -> bool:
        """Records a failed expectation."""
        if not ok:
            self.failures.append(what)
        return ok


def fresh(run: Run, after_frame: int) -> dict[str, Any]:
    """The next report the game makes after `after_frame` (the page may run slowly)."""
    return run.wait("a fresh report", lambda s: s["frames"] > after_frame)


def hear(run: Run, player: str, what: str) -> None:
    """The player is playing and its position moves with the frames: the mixer runs.

    Software GL makes the page slow (a few frames a second), and the single-threaded
    web mixer works frame by frame, so the test counts audio per frame, not per
    second: at 60 fps a frame is 16.7 ms of sound.
    """
    first = fresh(run, 0)
    run.page.pump(HEAR_S)
    second = fresh(run, first.get("frames", 0))
    if not first or not second:
        return
    run.check(bool(second["music"][f"{player}_playing"]), f"{what} is not playing")
    moved = second["music"][f"{player}_pos"] - first["music"][f"{player}_pos"]
    frames = second["frames"] - first["frames"]
    run.check(
        moved > MIN_S_PER_FRAME * frames and moved > MIN_MOVED_S,
        f"{what} does not advance (moved {moved:.3f} s in {frames} frames)",
    )


def play(run: Run) -> None:
    """Hub, first touch (sound), shop, battle."""
    hub = run.wait("the hub", lambda s: s["screen"] == "hub", BOOT_WAIT_S)
    if not hub:
        return
    run.page.pump(1.0)
    run.page.shot(run.shots / "01_hub.png")
    print("audio before a touch:", run.audio_state())
    run.tap("command", hub)  # the first gesture: the browser may start sound now
    shop = run.wait("the shop", lambda s: s["screen"] == "loadout")
    if not shop:
        return
    run.wait("sound", lambda _s: "running" in run.audio_state())
    run.check("running" in run.audio_state(), f"audio context not running after a touch: {run.audio_state()}")
    print("audio after a touch:", run.audio_state())
    hear(run, "hub", "the hub music")
    run.page.shot(run.shots / "02_shop.png")
    run.tap("go_button", shop)
    battle = run.wait("a battle", lambda s: s["screen"] == "battle")
    if not battle:
        return
    run.wait("the clock to run", lambda s: s.get("clock_s", 0.0) > 0.5)
    hear(run, "battle", "the battle music")
    run.page.shot(run.shots / "03_battle.png")


def main() -> int:
    """Exit 0 only when every check passed."""
    web_dir, shots = Path(sys.argv[1]), Path(sys.argv[2])
    # A timeout's SIGTERM must still run the finally block that stops the browser.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    shots.mkdir(parents=True, exist_ok=True)
    server = serve(web_dir)
    browser = Browser(SIZE)
    try:
        page = Page(browser.page_socket())
        for domain in ("Page", "Runtime", "Log"):
            page.call(f"{domain}.enable")
        page.call("Emulation.setTouchEmulationEnabled", enabled=True)
        page.call("Page.addScriptToEvaluateOnNewDocument", source=TRACK_AUDIO)
        page.call("Page.navigate", url=f"http://127.0.0.1:{server.server_port}/index.html?probe")
        run = Run(page, shots)
        try:
            play(run)
        except (RuntimeError, OSError, websocket.WebSocketException) as error:
            run.failures.append(f"the page stopped answering: {error}")
        run.failures += page.problems
    finally:
        browser.close()
        server.shutdown()
    for failure in run.failures:
        print(f"web smoke: FAIL {failure}", file=sys.stderr)
    print("console:", *run.page.logs[-8:], sep="\n  ")
    return 1 if run.failures else 0


if __name__ == "__main__":
    sys.exit(main())
