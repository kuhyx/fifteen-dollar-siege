"""The launcher's Recorder: backend choice, fallback to x11grab, the t0 of a gsr part, 30 fps."""

import inspect
import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from helpers import ROOT
from recording import gsr, recorder, supervise, window
from test_gsr import FAKE_GSR, install_fake

FAKE_FFMPEG = """#!{python}
import signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
time.sleep(60)
"""
WIN = window.Window(id=0x4200007, width=1280, height=800)
GSR_T0 = 1_800_000_007.25 - gsr.CAPTURE_LATENCY_S  # FAKE_GSR's first-frame stamp, less the latency


class RecorderTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        bin_dir = self.dir / "bin"
        bin_dir.mkdir()
        install_fake(bin_dir, "gpu-screen-recorder", FAKE_GSR)
        install_fake(bin_dir, "ffmpeg", FAKE_FFMPEG)
        env = {
            "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            "DISPLAY": ":9",
            "SIEGE_RECORDER_NICE": "0",
        }
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        feedback = self.dir / "fb"
        self.paths = supervise.recording_paths(feedback, "s1")
        opts = {"fps": 30, "audio": "default", "session": "s1", "feedback": feedback}
        self.make = lambda backend: recorder.Recorder(mock.Mock(), {"libx264"}, self.paths, opts, backend)

    def meta(self) -> dict:
        return json.loads(self.paths["meta"].read_text())

    def stop(self, rec: recorder.Recorder) -> None:
        rec.stop()

    def test_defaults_are_30_fps(self) -> None:
        self.assertEqual(inspect.signature(supervise.run).parameters["fps"].default, 30)
        source = (ROOT / "tools/recording/record.py").read_text()
        self.assertIn('"--fps", type=int, default=30', source)

    def test_gsr_part_puts_t0_on_its_first_frame(self) -> None:
        rec = self.make("gsr")
        with mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}):
            rec._start_part(WIN)
        self.addCleanup(self.stop, rec)
        self.assertEqual(rec.backend, "gsr")
        self.assertAlmostEqual(rec.t0, GSR_T0, places=6)
        meta = self.meta()
        self.assertAlmostEqual(meta["t0_unix"], GSR_T0, places=6)
        self.assertEqual(meta["backend"], "gsr")
        self.assertEqual(meta["parts"], ["s1.mkv"])
        self.assertEqual(meta["fps"], 30)

    def test_a_gsr_that_fails_at_start_falls_back_to_x11grab_with_a_fresh_t0(self) -> None:
        rec = self.make("gsr")
        before = time.time()
        with mock.patch.dict(os.environ, {"FAKE_GSR": "die"}):
            rec._start_part(WIN)
        self.addCleanup(self.stop, rec)
        self.assertEqual(rec.backend, "x11grab")
        self.assertIsNotNone(rec.proc)
        self.assertGreaterEqual(rec.t0, before)
        self.assertLess(rec.t0, time.time() + 1)
        meta = self.meta()
        self.assertEqual(meta["backend"], "x11grab")
        self.assertEqual(meta["parts"], ["s1.mkv"])

    def _gsr_running(self) -> tuple[recorder.Recorder, object]:
        rec = self.make("gsr")
        with mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}):
            rec._start_part(WIN)
        self.addCleanup(self.stop, rec)
        return rec, rec.proc

    def test_gsr_keeps_recording_while_its_window_is_shown(self) -> None:
        rec, proc = self._gsr_running()
        with mock.patch.object(window, "largest", return_value=WIN):
            self.assertTrue(rec.step())
        self.assertIs(rec.proc, proc)

    def test_gsr_part_ends_when_its_window_is_hidden_so_a_new_part_follows(self) -> None:
        # gsr neither exits nor resumes after an unmap (bench.sh gap on :0): the recorder ends the part itself
        rec, proc = self._gsr_running()
        with (
            mock.patch.object(window, "largest", return_value=None),
            mock.patch.object(window, "wait_stable", return_value=None),
        ):
            self.assertFalse(rec.step())
        self.assertIsNotNone(proc.poll(), "the hidden window's gsr was stopped")
        self.assertIsNone(rec.proc)
        self.assertEqual(len(rec.pending), 1)

    def test_x11grab_backend_never_starts_gsr(self) -> None:
        rec = self.make("x11grab")
        with mock.patch.object(gsr, "start") as started:
            rec._start_part(WIN)
        self.addCleanup(self.stop, rec)
        started.assert_not_called()
        self.assertEqual(self.meta()["backend"], "x11grab")

    def test_stopping_a_gsr_part_aligns_a_later_part_to_the_t0_timeline(self) -> None:
        rec = self.make("gsr")
        rec.t0 = GSR_T0 - 10.0
        rec.parts = ["s1.mkv"]  # a second part: its first frame is 10 s after t0
        with (
            mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}),
            mock.patch.object(gsr, "align") as align,
        ):
            rec._start_part(WIN)
            rec.stop()
        align.assert_called_once_with(self.paths["dir"] / "s1.part2.mkv", first_unix=GSR_T0, t0=GSR_T0 - 10.0)
        self.assertEqual(rec.t0, GSR_T0 - 10.0)

    def test_a_part_that_ended_during_play_is_aligned_only_after_the_game_exits(self) -> None:
        rec = self.make("gsr")
        with mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}), mock.patch.object(gsr, "align") as align:
            rec._start_part(WIN)
            assert rec.proc is not None
            rec.proc.send_signal(2)
            rec.proc.wait(timeout=5)
            rec.close_part()  # the window went away; the game still runs
            align.assert_not_called()
            rec.stop()  # the game exited
        align.assert_called_once()

    def test_every_pending_part_is_aligned_once_and_its_first_frame_is_in_rec_json(self) -> None:
        rec = self.make("gsr")
        with mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}), mock.patch.object(gsr, "align") as align:
            for _ in range(2):
                rec._start_part(WIN)
                assert rec.proc is not None
                rec.proc.send_signal(2)
                rec.proc.wait(timeout=5)
                rec.close_part()
            rec.stop()
        self.assertEqual(align.call_count, 2)
        self.assertEqual(self.meta()["first_frame_unix"], {"s1.mkv": GSR_T0, "s1.part2.mkv": GSR_T0})

    def test_a_dead_proc_still_closes_once(self) -> None:
        rec = self.make("gsr")
        with mock.patch.dict(os.environ, {"FAKE_GSR": "ok"}), mock.patch.object(gsr, "align") as align:
            rec._start_part(WIN)
            rec.stop()
            rec.stop()
        self.assertEqual(align.call_count, 1)


if __name__ == "__main__":
    unittest.main()
