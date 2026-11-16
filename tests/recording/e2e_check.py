#!/usr/bin/env python3
"""Verdicts for scripts/e2e_recording.sh (called after a recorded run).

e2e_check.py sync <recordings-dir> <session> <truth.json>
    frame-accurate proof: the flasher's black/white flips, found in the video,
    sit where events.json and the unix-clock truth say.
e2e_check.py gap <recordings-dir> <session> <truth.json>
    the window was unmapped for 2 s mid-run: two parts on one timeline, the
    gap's moments flagged, the flips after the return still frame-accurate.
e2e_check.py game <recordings-dir> <session> <WxH>
    the real game's recording: video at the window size, an audio stream,
    every timestamp inside the file, chapters match the moments.
"""

import json
import re
import statistics
import subprocess
import sys
from pathlib import Path

EVENT_TOLERANCE_S = 0.003  # telemetry ms are whole milliseconds


def ffprobe(*args: str) -> dict:
    done = subprocess.run(["ffprobe", "-v", "error", "-of", "json", *args], capture_output=True, text=True, check=True)
    return json.loads(done.stdout)


def luma_per_frame(video: Path) -> list[tuple[float, float]]:
    """(pts_time on the file's timeline, mean luma) of every video frame."""
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-copyts",
        "-i",
        str(video),
        "-an",
        "-vf",
        "scale=8:8,format=gray,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-",
        "-f",
        "null",
        "-",
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    frames, pts = [], 0.0
    for line in out.splitlines():
        if m := re.search(r"pts_time:([\d.]+)", line):
            pts = float(m.group(1))
        elif m := re.search(r"YAVG=([\d.]+)", line):
            frames.append((pts, float(m.group(1))))
    return frames


def transitions(frames: list[tuple[float, float]]) -> list[float]:
    """pts of the first frame after each black<->white change."""
    out, state = [], frames[0][1] > 128
    for pts, luma in frames:
        now = luma > 128
        if now != state:
            out.append(pts)
            state = now
    return out


def frame_s(meta: dict) -> float:
    """One frame of the recording (its fps is in rec.json; 30 by default)."""
    return 1 / meta.get("fps", 30)


def sync(rec: Path, session: str, truth_path: Path) -> None:
    meta = json.loads((rec / f"{session}.rec.json").read_text())
    frame = frame_s(meta)
    doc = json.loads((rec / f"{session}.events.json").read_text())
    truth = json.loads(truth_path.read_text())
    flips = {e["item"]: e for e in doc["events"] if e["kind"] == "reject"}
    seen = transitions(luma_per_frame(rec / meta["video"]))
    assert not doc["sync"]["approx"], "sync must come from recording_sync"
    assert len(seen) == len(truth), f"{len(seen)} flips in the video, {len(truth)} made"
    event_err, lag = [], []
    for want, pts in zip(truth, seen, strict=True):
        media = want["unix"] - meta["t0_unix"]
        event = flips[f"flip{want['n']}"]
        assert not event.get("before_recording"), f"flip{want['n']} before the recording"
        event_err.append(abs(event["t"] - media))
        lag.append(pts - media)
    assert max(event_err) <= EVENT_TOLERANCE_S, f"events.json off by {max(event_err) * 1000:.1f} ms"
    # The recorder centres the video stamps on the content (encoder.GRAB_LATENCY_FRAMES):
    # each flip shows within one frame of its true time, the median within a frame (the
    # frame grid can step by one frame mid-run).
    shown = [round(x * 1000, 1) for x in lag]
    off = [x for x in lag if abs(x) > frame + 0.003]
    assert len(off) <= 3, f"{len(off)} of {len(lag)} flips are more than a frame off: {shown} ms"  # encoder hiccups
    assert abs(statistics.median(lag)) <= frame, f"median above a frame: {shown} ms"
    print(
        f"sync PASS flips={len(truth)} events_err_max={max(event_err) * 1000:.2f}ms "
        f"frame_lag_ms min={min(lag) * 1000:.1f} median={statistics.median(lag) * 1000:.1f} max={max(lag) * 1000:.1f}"
    )


def gap(rec: Path, session: str, truth_path: Path) -> None:
    meta = json.loads((rec / f"{session}.rec.json").read_text())
    frame = frame_s(meta)
    doc = json.loads((rec / f"{session}.events.json").read_text())
    truth = json.loads(truth_path.read_text())
    parts = doc["video"]["parts"]
    assert len(parts) >= 2, f"the recorder did not restart after the unmap: {parts}"
    assert parts[1]["start_s"] > parts[0]["start_s"] + parts[0]["duration_s"], "parts overlap"
    flips = [e for e in doc["events"] if e["kind"] == "reject"]
    assert any(e.get("in_gap") for e in flips), "no flip fell in the gap"
    after = [e for e in flips if e.get("file") == parts[1]["file"]]
    assert len(after) >= 3, f"only {len(after)} flips after the window came back; parts {parts}"
    seen = transitions(luma_per_frame(rec / parts[1]["file"]))
    tail = [t for t in truth if f"flip{t['n']}" in {e["item"] for e in after}]
    assert abs(len(seen) - len(tail)) <= 1, f"{len(seen)} flips in part 2, {len(tail)} made"
    lag = [p - (t["unix"] - meta["t0_unix"]) for t, p in zip(tail[-len(seen) :], seen[-len(tail) :], strict=False)]
    # the first flip can land in the recorder's start-up frames; the rest must be exact
    shown = [round(x * 1000) for x in lag]
    assert len(lag) >= 3 and all(abs(x) <= 2 * frame for x in lag[1:]), f"part 2 frames off: {shown} ms"
    for name in (p["file"] for p in parts):
        chap = ffprobe("-show_chapters", str(rec / name))["chapters"]
        want = {round(e["t"] * 1000) for e in doc["events"] if e.get("file") == name}
        assert len(chap) == len(want), (name, len(chap), len(want))
    print(
        f"gap PASS parts={len(parts)} gap={parts[1]['start_s'] - parts[0]['start_s'] - parts[0]['duration_s']:.1f}s "
        f"in_gap={sum(1 for e in flips if e.get('in_gap'))} part2_flips={len(after)} "
        f"lag_ms={[round(x * 1000, 1) for x in lag]}"
    )


def game(rec: Path, session: str, size: str) -> None:
    doc = json.loads((rec / f"{session}.events.json").read_text())
    video = rec / doc["video"]["file"]
    info = ffprobe("-show_streams", "-show_format", "-show_chapters", str(video))
    streams = {s["codec_type"]: s for s in info["streams"]}
    want_w, want_h = (int(x) for x in size.split("x"))
    assert (streams["video"]["width"], streams["video"]["height"]) == (want_w, want_h), streams["video"]
    assert "audio" in streams, "no audio stream"
    start, end = doc["video"]["start_s"], doc["video"]["end_s"]
    inside = [e for e in doc["events"] if not e.get("before_recording") and not e.get("after_recording")]
    assert inside, "no moment inside the recording"
    for event in inside:
        assert start - 1e-3 <= event["t"] <= end + 1e-3, event
    distinct = len({round(e["t"] * 1000) for e in inside})  # events of one millisecond share a chapter
    assert len(info["chapters"]) == distinct, (len(info["chapters"]), distinct)
    assert not doc["sync"]["approx"]
    kinds = sorted({e["kind"] for e in inside})
    fmt = info["format"]
    print(
        f"game PASS {streams['video']['codec_name']} {want_w}x{want_h} + {streams['audio']['codec_name']} "
        f"duration={float(fmt['duration']):.1f}s start={float(fmt['start_time']):.3f}s "
        f"moments={len(inside)} chapters={len(info['chapters'])} kinds={kinds}"
    )


if __name__ == "__main__":
    mode, rec_dir, sess, extra = sys.argv[1:5]
    if mode == "sync":
        sync(Path(rec_dir), sess, Path(extra))
    elif mode == "gap":
        gap(Path(rec_dir), sess, Path(extra))
    else:
        game(Path(rec_dir), sess, extra)
