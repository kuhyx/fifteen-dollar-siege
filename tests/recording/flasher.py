#!/usr/bin/env python3
"""A stand-in game for the sync proof: a Tk window that flips black/white on a
schedule and logs telemetry-shaped entries (recording_sync + one `reject` per
flip, ms since its log opened) to <feedback-dir>/feedback.jsonl. The true flip
times (unix clock, taken right after the X flush) go to <feedback-dir>/truth.json.
Takes the same user args as the game: --dev --session-id= --feedback-dir=.
"""

import json
import os
import subprocess
import sys
import time
import tkinter
from pathlib import Path

FLIPS = 10
PERIOD_S = 0.617  # not a whole number of frames: the flips sample every phase
FIRST_FLIP_S = 3.5  # after the window is up: the recorder needs ~1.5 s to start


def arg(prefix: str) -> str:
    return next((a[len(prefix) :] for a in sys.argv if a.startswith(prefix)), "")


def main() -> None:
    session, out = arg("--session-id="), Path(arg("--feedback-dir="))
    out.mkdir(parents=True, exist_ok=True)
    log_start = time.monotonic()
    seq = 0

    def write(event: str, **fields: object) -> None:
        nonlocal seq
        seq += 1
        row = {"event": event, "session": session, "seq": seq, "ms": int((time.monotonic() - log_start) * 1000)}
        with (out / "feedback.jsonl").open("a", encoding="utf-8") as f:
            f.write(json.dumps({**row, **fields}) + "\n")

    root = tkinter.Tk(className="cpflasher")  # a class of its own: bench.sh finds it by that
    root.geometry("640x360+0+0")
    root.configure(bg="black")
    root.update()
    # Tk does not set _NET_WM_PID, which real games (Godot) do and the recorder finds windows by.
    for win in (root.winfo_id(), int(root.wm_frame(), 16)):
        pid = ["-f", "_NET_WM_PID", "32c", "-set", "_NET_WM_PID", str(os.getpid())]
        subprocess.run(["xprop", "-id", hex(win), *pid], check=True)
    write("recording_sync", unix_us=int(time.time() * 1_000_000))
    truth = []
    for n in range(FLIPS):
        wait = FIRST_FLIP_S + n * PERIOD_S - (time.monotonic() - log_start)
        deadline = time.monotonic() + max(0.0, wait)
        while time.monotonic() < deadline:
            root.update()
            time.sleep(0.002)
        color = "white" if n % 2 == 0 else "black"
        root.configure(bg=color)
        root.update()
        flipped = time.time()
        write("command", order=f"flip{n}", pos=[n, 0], colour=color)
        truth.append({"n": n, "color": color, "unix": flipped})
    time.sleep(1.0)
    (out / "truth.json").write_text(json.dumps(truth))
    root.destroy()


if __name__ == "__main__":
    main()
