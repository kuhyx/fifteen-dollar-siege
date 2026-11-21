"""An isolated headless Chromium and a small Chrome DevTools Protocol client.

Never kuhy's browser, never his display: its own temp profile, headless, muted,
and a debugging port the OS picks (read back from DevToolsActivePort).
"""

from __future__ import annotations

import base64
import json
import os
import shutil
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path
from typing import Any

import websocket

CANDIDATES = ("/usr/bin/chromium", "chromium", "google-chrome-stable", "google-chrome", "chromium-browser")
START_WAIT_S = 20.0


def find_chromium() -> str:
    """The browser binary: SIEGE_CHROMIUM, else the first candidate that exists."""
    wanted = os.environ.get("SIEGE_CHROMIUM", "")
    if wanted:
        return wanted
    for name in CANDIDATES:
        found = shutil.which(name)
        if found:
            return found
    msg = "no chromium or chrome found (run ./install.sh)"
    raise RuntimeError(msg)


class Browser:
    """One headless Chromium process with a throwaway profile."""

    def __init__(self, size: tuple[int, int]) -> None:
        self.profile = os.environ.get("SIEGE_WEB_PROFILE") or tempfile.mkdtemp(prefix="siege-web-")
        Path(self.profile).mkdir(parents=True, exist_ok=True)
        flags = [
            "--headless=new",
            "--mute-audio",
            "--remote-debugging-port=0",
            f"--user-data-dir={self.profile}",
            "--no-first-run",
            "--disable-extensions",
            "--disable-background-timer-throttling",
            "--disable-renderer-backgrounding",
            "--hide-scrollbars",
            "--use-gl=angle",
            "--use-angle=swiftshader",
            "--enable-unsafe-swiftshader",
            f"--window-size={size[0]},{size[1]}",
        ]
        if os.environ.get("CI"):
            flags.append("--no-sandbox")
        self.process = subprocess.Popen(
            [find_chromium(), *flags, "about:blank"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            # Headless needs no X: an unreachable DISPLAY makes ANGLE fail and WebGL2 vanish.
            env={k: v for k, v in os.environ.items() if k not in ("DISPLAY", "WAYLAND_DISPLAY")},
        )
        self.port = self._wait_for_port()

    def _wait_for_port(self) -> int:
        marker = Path(self.profile) / "DevToolsActivePort"
        deadline = time.monotonic() + START_WAIT_S
        while time.monotonic() < deadline:
            if marker.is_file() and marker.read_text().strip():
                return int(marker.read_text().splitlines()[0])
            if self.process.poll() is not None:
                break
            time.sleep(0.1)
        msg = "chromium never opened its debugging port"
        raise RuntimeError(msg)

    def page_socket(self) -> str:
        """The websocket URL of the first page."""
        deadline = time.monotonic() + START_WAIT_S
        while time.monotonic() < deadline:
            with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/json/list") as reply:
                pages = [t for t in json.load(reply) if t.get("type") == "page"]
            if pages:
                return str(pages[0]["webSocketDebuggerUrl"])
            time.sleep(0.1)
        msg = "chromium has no page"
        raise RuntimeError(msg)

    def close(self) -> None:
        """Stops the process and deletes the profile."""
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
        shutil.rmtree(self.profile, ignore_errors=True)


class Page:
    """CDP calls and the events a run collects (console errors, exceptions)."""

    def __init__(self, url: str) -> None:
        # suppress_origin: Chromium refuses a websocket with a foreign Origin header.
        self.socket = websocket.create_connection(url, suppress_origin=True, timeout=30)
        self.last_id = 0
        self.problems: list[str] = []
        self.logs: list[str] = []

    def call(self, method: str, **params: Any) -> dict[str, Any]:
        """One command; collects events that arrive before its reply."""
        self.last_id += 1
        self.socket.send(json.dumps({"id": self.last_id, "method": method, "params": params}))
        while True:
            message = json.loads(self.socket.recv())
            if message.get("id") == self.last_id:
                if "error" in message:
                    msg = f"{method}: {message['error']}"
                    raise RuntimeError(msg)
                return dict(message.get("result", {}))
            self._event(message)

    def pump(self, seconds: float) -> None:
        """Reads events for a while (the page keeps running meanwhile)."""
        deadline = time.monotonic() + seconds
        self.socket.settimeout(0.1)
        try:
            while time.monotonic() < deadline:
                try:
                    self._event(json.loads(self.socket.recv()))
                except websocket.WebSocketTimeoutException:
                    continue
        finally:
            self.socket.settimeout(30)

    def _event(self, message: dict[str, Any]) -> None:
        method = message.get("method", "")
        params = message.get("params", {})
        if method == "Runtime.exceptionThrown":
            details = params["exceptionDetails"]
            self.problems.append(
                f"exception: {details.get('text')} {details.get('exception', {}).get('description', '')}"
            )
        elif method == "Runtime.consoleAPICalled":
            text = " ".join(str(a.get("value", a.get("description", ""))) for a in params["args"])
            self.logs.append(f"{params['type']}: {text}")
            if params["type"] == "error":
                self.problems.append(f"console.error: {text}")
        elif method == "Log.entryAdded" and params["entry"]["level"] == "error":
            self.problems.append(f"log error: {params['entry'].get('text')} {params['entry'].get('url', '')}")

    def evaluate(self, expression: str) -> Any:
        """Runs JS in the page and returns its value."""
        result = self.call("Runtime.evaluate", expression=expression, returnByValue=True)
        if "exceptionDetails" in result:
            msg = f"evaluate failed: {result['exceptionDetails']}"
            raise RuntimeError(msg)
        return result["result"].get("value")

    def touch(self, x: float, y: float) -> None:
        """One finger down and up on a CSS pixel (a real touch event, no mouse)."""
        point = [{"x": x, "y": y, "id": 1}]
        self.call("Input.dispatchTouchEvent", type="touchStart", touchPoints=point)
        self.pump(0.08)
        self.call("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])

    def shot(self, path: Path) -> None:
        """A PNG of the page."""
        data = self.call("Page.captureScreenshot", format="png")["data"]
        path.write_bytes(base64.b64decode(data))
