"""After the game exits: events.json, chapters remuxed in, no re-encode."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import SESSION, SYNC_MS, SYNC_UNIX, entry, sync_entry
from recording import finalize

T0 = SYNC_UNIX + 0.5
START = 0.052


def make_video(path: Path) -> None:
    """A 4 s test pattern + tone whose timeline starts at START (like the real recorder's)."""
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=160x120:rate=30"]
    cmd += ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000", "-t", "4"]
    cmd += ["-output_ts_offset", str(START), "-c:v", "libx264", "-c:a", "flac", str(path)]
    subprocess.run(cmd, check=True, timeout=30)


def ffprobe(*args: str) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-of", "json", *args], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


class FinalizeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.rec = root / "recordings"
        self.rec.mkdir()
        make_video(self.rec / f"{SESSION}.mkv")
        rows = [
            sync_entry(),
            entry("game_start", SYNC_MS + 100, 2, game="watch"),
            entry("command", SYNC_MS + 1500, 3, order="rally", pos=[1, 2]),
            entry("buy", SYNC_MS + 2500, 4, buff="stew", bought=True, cost=1),
            entry("game_end", SYNC_MS + 3300, 5, game="watch", outcome="lose", elapsed_s=3.2),
        ]
        (root / "feedback.jsonl").write_text("\n".join(json.dumps(r) for r in rows) + "\n")
        meta = {"session": SESSION, "t0_unix": T0, "video": f"{SESSION}.mkv", "feedback": str(root / "feedback.jsonl")}
        (self.rec / f"{SESSION}.rec.json").write_text(json.dumps(meta))
        self.doc = finalize.finalize(self.rec / f"{SESSION}.rec.json")

    def test_events_json_is_written_with_timestamps_inside_the_duration(self) -> None:
        written = json.loads((self.rec / f"{SESSION}.events.json").read_text())
        self.assertEqual(written["events"], self.doc["events"])
        end = written["video"]["end_s"]
        inside = [e for e in written["events"] if not e.get("before_recording")]
        self.assertTrue(inside)
        for event in inside:
            self.assertGreaterEqual(event["t"], START - 1e-3)
            self.assertLessEqual(event["t"], end + 1e-3)

    def test_video_start_and_duration_come_from_the_file(self) -> None:
        self.assertAlmostEqual(self.doc["video"]["start_s"], START, places=2)
        self.assertGreater(self.doc["video"]["duration_s"], 3.5)

    def test_chapters_are_embedded_without_reencoding_or_moving_the_timeline(self) -> None:
        info = ffprobe("-show_chapters", "-show_streams", str(self.rec / f"{SESSION}.mkv"))
        starts = [float(c["start_time"]) for c in info["chapters"]]
        expected = [e["t"] for e in self.doc["events"] if not e.get("before_recording")]
        self.assertEqual(len(starts), len(expected))
        for got, want in zip(starts, expected, strict=True):
            self.assertAlmostEqual(got, want, places=2)
        video = next(s for s in info["streams"] if s["codec_type"] == "video")
        self.assertEqual(video["codec_name"], "h264")
        self.assertAlmostEqual(float(video["start_time"]), START, places=2)

    def test_first_run_game_start_before_the_recorder_is_flagged(self) -> None:
        start = next(e for e in self.doc["events"] if e["kind"] == "game_start")
        self.assertTrue(start.get("before_recording"))

    def test_finalize_is_repeatable(self) -> None:
        again = finalize.finalize(self.rec / f"{SESSION}.rec.json")
        self.assertEqual([e["t"] for e in again["events"]], [e["t"] for e in self.doc["events"]])


class ProbeAndPartsTest(unittest.TestCase):
    def test_a_file_without_a_duration_is_scanned_whole(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "open.mkv"
            make_video(video)
            with mock.patch.object(finalize, "_ffprobe") as probe:
                probe.side_effect = lambda *a: (
                    {"format": {"start_time": "0.5"}} if "format=start_time,duration" in a else ffprobe(*a)
                )
                start, duration = finalize.probe_span(video)
            self.assertEqual(start, 0.5)
            self.assertGreater(duration, 3.0)

    def test_a_first_frame_for_a_missing_part_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "feedback.jsonl").write_text(json.dumps(sync_entry()) + "\n")
            make_video(root / "a.mkv")
            meta = {
                "session": SESSION, "t0_unix": T0, "video": "a.mkv", "feedback": str(root / "feedback.jsonl"),
                "first_frame_unix": {"gone.mkv": T0},
            }  # fmt: skip
            (root / "x.rec.json").write_text(json.dumps(meta))
            self.assertAlmostEqual(finalize.finalize(root / "x.rec.json")["video"]["start_s"], START, places=2)


class GsrPartTest(unittest.TestCase):
    """A gsr part starts at 0; rec.json says when its first frame was, finalize puts it on the t0 timeline."""

    def test_an_unaligned_part_is_moved_once_and_stays_put(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "recordings").mkdir()
            rec = root / "recordings"
            cmd = ["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=160x120:rate=30", "-t", "2"]
            subprocess.run([*cmd, "-c:v", "libx264", str(rec / f"{SESSION}.mkv")], check=True, timeout=30)
            (root / "feedback.jsonl").write_text(json.dumps(sync_entry()) + "\n")
            meta = {
                "session": SESSION, "t0_unix": T0, "video": f"{SESSION}.mkv", "feedback": str(root / "feedback.jsonl"),
                "first_frame_unix": {f"{SESSION}.mkv": T0 + 2.0},
            }  # fmt: skip
            (rec / f"{SESSION}.rec.json").write_text(json.dumps(meta))
            for _ in range(2):
                doc = finalize.finalize(rec / f"{SESSION}.rec.json")
                self.assertAlmostEqual(doc["video"]["start_s"], 2.0, places=2)


if __name__ == "__main__":
    unittest.main()
