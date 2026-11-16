"""gpu-screen-recorder backend: argv, backend choice, first-frame time, timeline alignment."""

import os
import stat
import subprocess
import sys
import tempfile
import unittest
from itertools import pairwise
from pathlib import Path
from unittest import mock

from helpers import ROOT  # noqa: F401
from recording import encoder, gsr

SPEC = encoder.Spec(window_id=39845893, fps=30, t0_unix=1_800_000_000.5, out="/o/s.mkv", audio="default")
TS_TEXT = "monotonic_microsec\trealtime_microsec\n8935499369\t1794415951373572\n"

FAKE_GSR = """#!{python}
import os, pathlib, signal, sys, time
args = sys.argv[1:]
out = args[args.index("-o") + 1]
mode = os.environ.get("FAKE_GSR", "ok")
if mode == "die":
    sys.exit(1)
if mode == "ok":
    pathlib.Path(out + ".ts").write_text("monotonic_microsec\\trealtime_microsec\\n5\\t1800000007250000\\n")
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
time.sleep(60)
"""


def install_fake(folder: Path, name: str, body: str) -> None:
    path = folder / name
    path.write_text(body.format(python=sys.executable))
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class CommandTest(unittest.TestCase):
    def test_records_the_window_on_the_gpu_at_the_fps(self) -> None:
        cmd = gsr.command(SPEC)
        self.assertEqual(cmd[0], "gpu-screen-recorder")
        pairs = list(pairwise(cmd))
        for pair in (("-w", "39845893"), ("-f", "30"), ("-k", "h264"), ("-c", "mkv"), ("-o", "/o/s.mkv")):
            self.assertIn(pair, pairs, pair)
        self.assertNotIn("x11grab", cmd)

    def test_the_first_frame_time_is_written_for_the_timeline(self) -> None:
        self.assertIn(("-write-first-frame-ts", "yes"), list(pairwise(gsr.command(SPEC))))

    def test_constant_frame_rate_without_the_cursor_and_quiet(self) -> None:
        pairs = list(pairwise(gsr.command(SPEC)))
        for pair in (("-fm", "cfr"), ("-cursor", "no"), ("-v", "no"), ("-q", "very_high")):
            self.assertIn(pair, pairs, pair)

    def test_audio_is_the_default_output_as_opus_because_flac_is_disabled_in_gsr(self) -> None:
        pairs = list(pairwise(gsr.command(SPEC)))
        self.assertIn(("-a", "default_output"), pairs)
        self.assertIn(("-ac", "opus"), pairs)

    def test_a_named_pulse_source_is_a_device(self) -> None:
        spec = encoder.Spec(**{**SPEC.__dict__, "audio": "sink.monitor"})
        self.assertIn(("-a", "device:sink.monitor"), list(pairwise(gsr.command(spec))))

    def test_ts_file_sits_next_to_the_video_with_an_extra_extension(self) -> None:
        self.assertEqual(gsr.ts_path("/o/s.mkv"), Path("/o/s.mkv.ts"))


class FirstFrameTest(unittest.TestCase):
    def test_the_realtime_column_is_the_unix_time(self) -> None:
        self.assertAlmostEqual(gsr.parse_first_frame(TS_TEXT) or 0.0, 1794415951.373572, places=6)

    def test_a_missing_or_partial_file_is_not_a_time_yet(self) -> None:
        for text in ("", "monotonic_microsec\trealtime_microsec\n", TS_TEXT.rstrip("\n"), "x\ty\n1\t2z\n"):
            self.assertIsNone(gsr.parse_first_frame(text), repr(text))


class LatencyTest(unittest.TestCase):
    def test_the_measured_capture_latency_is_between_two_and_three_frames_at_30_fps(self) -> None:
        self.assertGreater(gsr.CAPTURE_LATENCY_S, 2 / 30)
        self.assertLess(gsr.CAPTURE_LATENCY_S, 3 / 30)


class BackendTest(unittest.TestCase):
    def test_gsr_when_installed(self) -> None:
        self.assertEqual(gsr.pick_backend({}, "default", have_gsr=True), "gsr")

    def test_x11grab_when_gsr_is_missing(self) -> None:
        self.assertEqual(gsr.pick_backend({}, "default", have_gsr=False), "x11grab")

    def test_the_env_forces_x11grab(self) -> None:
        env = {gsr.BACKEND_ENV: "x11grab"}
        self.assertEqual(gsr.pick_backend(env, "default", have_gsr=True), "x11grab")

    def test_the_silent_test_source_needs_ffmpeg(self) -> None:
        self.assertEqual(gsr.pick_backend({}, "lavfi", have_gsr=True), "x11grab")

    def test_available_follows_the_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"PATH": tmp}):
                self.assertFalse(gsr.available())
            install_fake(Path(tmp), "gpu-screen-recorder", FAKE_GSR)
            with mock.patch.dict(os.environ, {"PATH": tmp}):
                self.assertTrue(gsr.available())


class StartTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        install_fake(self.dir, "gpu-screen-recorder", FAKE_GSR)
        path = f"{self.dir}{os.pathsep}{os.environ['PATH']}"
        patcher = mock.patch.dict(os.environ, {"PATH": path})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.spec = encoder.Spec(**{**SPEC.__dict__, "out": str(self.dir / "s.mkv")})

    def start(self, mode: str, wait_s: float = 5.0) -> tuple[subprocess.Popen, float] | None:
        with mock.patch.dict(os.environ, {"FAKE_GSR": mode}), (self.dir / "log").open("ab") as log:
            return gsr.start(self.spec, log, "0", wait_s=wait_s)

    def test_returns_the_running_recorder_and_its_first_frame_unix_time(self) -> None:
        started = self.start("ok")
        assert started is not None
        proc, first = started
        self.addCleanup(proc.wait)
        self.assertIsNone(proc.poll())
        # gsr stamps its first frame after the screen showed it (measured on :0, bench.sh sync)
        self.assertAlmostEqual(first, 1_800_000_007.25 - gsr.CAPTURE_LATENCY_S, places=6)
        proc.send_signal(2)

    def test_a_recorder_that_dies_at_start_is_a_failure(self) -> None:
        self.assertIsNone(self.start("die"))

    def test_a_recorder_that_never_stamps_its_first_frame_is_killed_and_a_failure(self) -> None:
        self.assertIsNone(self.start("nots", wait_s=1.0))


class AlignTest(unittest.TestCase):
    def test_delta_puts_the_first_frame_on_the_t0_timeline(self) -> None:
        self.assertAlmostEqual(gsr.shift_delta(first_unix=107.0, t0=100.0, video_start=0.0), 7.0)
        self.assertAlmostEqual(gsr.shift_delta(first_unix=107.0, t0=100.0, video_start=0.25), 6.75)

    def test_shift_command_copies_streams_and_moves_the_stamps(self) -> None:
        cmd = gsr.shift_command(Path("/o/a.mkv"), Path("/o/a.shift.mkv"), 7.0)
        pairs = list(pairwise(cmd))
        self.assertIn(("-output_ts_offset", "7.000000"), pairs)
        self.assertIn(("-c", "copy"), pairs)
        self.assertIn("-copyts", cmd)
        self.assertEqual(cmd[-1], "/o/a.shift.mkv")

    def test_align_moves_a_real_file_onto_the_timeline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "p.mkv"
            cmd = ["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=160x120:rate=30", "-t", "1"]
            subprocess.run([*cmd, "-c:v", "libx264", str(video)], check=True, timeout=30)
            self.assertAlmostEqual(gsr.video_start(video), 0.0, places=3)
            gsr.align(video, first_unix=107.0, t0=100.0)
            self.assertAlmostEqual(gsr.video_start(video), 7.0, places=2)
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["p.mkv"])

    def test_a_file_already_on_the_timeline_is_left_alone(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "p.mkv"
            video.write_bytes(b"not a video")  # would make ffprobe/ffmpeg fail if touched
            with mock.patch.object(gsr, "video_start", return_value=0.0005):
                gsr.align(video, first_unix=100.0, t0=100.0)
            self.assertEqual(video.read_bytes(), b"not a video")


if __name__ == "__main__":
    unittest.main()
