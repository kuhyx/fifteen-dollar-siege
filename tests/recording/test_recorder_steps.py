"""Recorder.step and its failure paths, with the process and window layers faked."""

import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import SESSION
from recording import gsr, recorder, supervise, window

WIN = window.Window(id=0x4200007, width=1280, height=800)


def alive() -> mock.Mock:
    return mock.Mock(poll=mock.Mock(return_value=None))


class StepTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        feedback = Path(self.tmp.name)
        self.paths = supervise.recording_paths(feedback, SESSION)
        self.opts = {"fps": 30, "audio": "default", "session": SESSION, "feedback": feedback}
        self.err = io.StringIO()
        stderr = contextlib.redirect_stderr(self.err)
        stderr.__enter__()
        self.addCleanup(stderr.__exit__, None, None, None)
        env = mock.patch.dict("os.environ", {"DISPLAY": ":9", "SIEGE_RECORDER_NICE": "0"})
        env.start()
        self.addCleanup(env.stop)

    def make(self, backend: str = "x11grab", usable: set[str] | None = None) -> recorder.Recorder:
        usable = {"libx264"} if usable is None else usable
        return recorder.Recorder(alive(), usable, self.paths, self.opts, backend)

    def test_an_off_recorder_does_nothing(self) -> None:
        rec = self.make()
        rec.off = True
        self.assertFalse(rec.step())

    def test_a_running_x11grab_part_keeps_going(self) -> None:
        rec = self.make()
        rec.proc = alive()
        self.assertTrue(rec.step())

    def test_no_window_at_the_start_turns_recording_off(self) -> None:
        rec = self.make()
        with mock.patch.object(window, "wait_stable", return_value=None):
            self.assertFalse(rec.step())
        self.assertTrue(rec.off)
        self.assertIn("no game window found", self.err.getvalue())

    def test_a_window_that_never_returns_leaves_the_session_on(self) -> None:
        rec = self.make()
        rec.parts = [f"{SESSION}.mkv"]
        with mock.patch.object(window, "wait_stable", return_value=None):
            self.assertFalse(rec.step())
        self.assertFalse(rec.off)

    def test_a_found_window_starts_a_part(self) -> None:
        rec = self.make()
        proc = mock.Mock()
        proc.wait.side_effect = subprocess.TimeoutExpired("ffmpeg", 1.0)
        with (
            mock.patch.object(window, "wait_stable", return_value=WIN),
            mock.patch.object(recorder.subprocess, "Popen", return_value=proc) as popen,
        ):
            self.assertTrue(rec.step())
        self.assertEqual(popen.call_args.args[0][:3], ["nice", "-n", "0"])
        self.assertEqual(rec.parts, [f"{SESSION}.mkv"])
        self.assertIn("recording 1280x800 with libx264", self.err.getvalue())

    def test_a_later_x11grab_part_keeps_the_first_parts_t0(self) -> None:
        rec = self.make()
        rec.parts, rec.t0 = [f"{SESSION}.mkv"], 123.0
        proc = mock.Mock()
        proc.wait.side_effect = subprocess.TimeoutExpired("ffmpeg", 1.0)
        with mock.patch.object(recorder.subprocess, "Popen", return_value=proc):
            rec._start_part(WIN)
        self.assertEqual((rec.t0, rec.parts), (123.0, [f"{SESSION}.mkv", f"{SESSION}.part2.mkv"]))

    def test_no_usable_encoder_stops_recording_with_a_message(self) -> None:
        rec = self.make(usable=set())
        with mock.patch.object(window, "wait_stable", return_value=WIN):
            self.assertFalse(rec.step())
        self.assertTrue(rec.off)
        self.assertIn("not recording: neither h264_nvenc nor libx264", self.err.getvalue())

    def test_an_ffmpeg_that_dies_at_start_is_retried_then_given_up_on(self) -> None:
        rec = self.make()
        with mock.patch.object(recorder.subprocess, "Popen", return_value=mock.Mock()):
            for attempt in range(1, recorder.MAX_QUICK_DEATHS + 1):
                rec._start_part(WIN)
                self.assertEqual((rec.proc, rec.parts, rec.quick_deaths), (None, [], attempt))
                self.assertEqual(rec.off, attempt == recorder.MAX_QUICK_DEATHS)
        self.assertIn("ffmpeg died at start", self.err.getvalue())

    def test_a_dead_window_part_is_replaced_by_waiting_for_the_next(self) -> None:
        rec = self.make()
        rec.parts = [f"{SESSION}.mkv"]
        rec.proc = mock.Mock(poll=mock.Mock(return_value=0))
        with mock.patch.object(window, "wait_stable", return_value=None):
            self.assertFalse(rec.step())
        self.assertIsNone(rec.proc)
        self.assertIn("the window went away", self.err.getvalue())


class GsrLifeTest(unittest.TestCase):
    def setUp(self) -> None:
        stderr = io.StringIO()
        redirect = contextlib.redirect_stderr(stderr)
        redirect.__enter__()
        self.addCleanup(redirect.__exit__, None, None, None)
        self.err = stderr
        self.rec = recorder.Recorder(alive(), {"libx264"}, {}, {}, "gsr")

    def test_without_an_open_gsr_part_nothing_is_counted(self) -> None:
        self.rec._count_short_life()
        self.assertEqual(self.rec.short_lives, 0)

    def test_short_lived_gsr_parts_switch_the_session_to_x11grab(self) -> None:
        self.rec.open_gsr = (Path(f"{SESSION}.mkv"), 1.0)
        with mock.patch.object(recorder.time, "monotonic", return_value=100.0):
            self.rec.gsr_started = 99.0
            for _ in range(recorder.MAX_QUICK_DEATHS):
                self.assertEqual(self.rec.backend, "gsr")
                self.rec._count_short_life()
        self.assertEqual(self.rec.backend, "x11grab")
        self.assertIn("keeps stopping", self.err.getvalue())

    def test_a_long_gsr_part_resets_the_count(self) -> None:
        self.rec.open_gsr = (Path(f"{SESSION}.mkv"), 1.0)
        self.rec.short_lives = 2
        with mock.patch.object(recorder.time, "monotonic", return_value=100.0):
            self.rec.gsr_started = 100.0 - recorder.SHORT_LIFE_S
            self.rec._count_short_life()
        self.assertEqual((self.rec.short_lives, self.rec.backend), (0, "gsr"))

    def test_an_alignment_that_fails_is_reported_not_raised(self) -> None:
        self.rec.pending = [(Path(f"/v/{SESSION}.part2.mkv"), 5.0)]
        with mock.patch.object(gsr, "align", side_effect=OSError("disk full")):
            self.rec._align_pending()
        self.assertIn(f"could not align {SESSION}.part2.mkv to the timeline: disk full", self.err.getvalue())
        self.assertEqual(self.rec.pending, [])

    def test_a_recorder_that_had_to_be_killed_says_so_on_stop(self) -> None:
        self.rec.proc = mock.Mock()
        with mock.patch.object(recorder, "stop_recorder", return_value=False):
            self.rec.stop()
        self.assertIn("ignored SIGINT", self.err.getvalue())

    def test_a_recorder_that_finalized_stops_quietly(self) -> None:
        self.rec.proc = mock.Mock()
        with mock.patch.object(recorder, "stop_recorder", return_value=True):
            self.rec.stop()
        self.assertEqual(self.err.getvalue(), "")

    def test_nothing_running_stops_quietly(self) -> None:
        self.rec.stop()
        self.assertEqual(self.err.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
