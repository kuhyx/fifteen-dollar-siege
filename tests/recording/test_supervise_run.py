"""supervise.run on the recording path: a real child game, the recorder and encoder probe faked."""

import contextlib
import io
import re
import signal
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import ClassVar
from unittest import mock

from helpers import SESSION
from recording import supervise

REAL_SLEEP = time.sleep
ENV = {"DISPLAY": ":9", "HOME": "/nonexistent"}


def game(seconds: float, code: int = 0) -> list[str]:
    return [sys.executable, "-c", f"import sys, time; time.sleep({seconds}); sys.exit({code})", "--dev"]


class FakeRecorder:
    """Stands in for Recorder: records what the launcher asked of it."""

    instances: ClassVar[list["FakeRecorder"]] = []
    gives_up: ClassVar[bool] = False

    def __init__(self, game: object, usable: set[str], paths: dict, opts: dict, backend: str) -> None:
        self.args = (usable, paths, opts, backend)
        self.off = FakeRecorder.gives_up
        self.steps = 0
        self.stopped = False
        FakeRecorder.instances.append(self)

    def step(self) -> bool:
        self.steps += 1
        return True

    def stop(self) -> None:
        self.stopped = True


class RunTest(unittest.TestCase):
    def setUp(self) -> None:
        FakeRecorder.instances = []
        FakeRecorder.gives_up = False
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            self.addCleanup(signal.signal, sig, signal.getsignal(sig))
        self.err = io.StringIO()
        stderr = contextlib.redirect_stderr(self.err)
        stderr.__enter__()
        self.addCleanup(stderr.__exit__, None, None, None)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = {**ENV, "SIEGE_BINARIES": self.tmp.name}
        for patch in (
            mock.patch.object(supervise, "Recorder", FakeRecorder),
            mock.patch.object(supervise.encoder, "probe_usable", return_value={"libx264"}),
            mock.patch.object(supervise.gsr, "available", return_value=False),
            mock.patch.object(supervise.time, "sleep", side_effect=lambda _s: REAL_SLEEP(0.02)),
        ):
            patch.start()
            self.addCleanup(patch.stop)

    def test_a_recorded_run_steps_the_recorder_and_returns_the_games_exit_code(self) -> None:
        with mock.patch.object(supervise, "_finish") as finish:
            code = supervise.run(game(0.3, 5), self.env, force=True, session=SESSION, fps=60)
        self.assertEqual(code, 5)
        rec = FakeRecorder.instances[0]
        self.assertTrue(rec.stopped)
        self.assertGreater(rec.steps, 0)
        usable, paths, opts, backend = rec.args
        self.assertEqual((usable, backend, opts["fps"], opts["session"]), ({"libx264"}, "x11grab", 60, SESSION))
        self.assertEqual(paths["meta"].name, f"{SESSION}.rec.json")
        finish.assert_called_once_with(paths)

    def test_the_game_gets_a_session_and_feedback_dir_in_its_args(self) -> None:
        with (
            mock.patch.object(supervise, "_finish"),
            mock.patch.object(supervise.subprocess, "Popen", wraps=supervise.subprocess.Popen) as popen,
        ):
            supervise.run(game(0.1), self.env, force=True)
        argv = popen.call_args.args[0]
        self.assertEqual(argv[-2], f"--session-id={supervise.session_of(argv)}")
        self.assertEqual(argv[-1], f"--feedback-dir={self.tmp.name}/feedback")

    def test_max_seconds_stops_the_game_once_recording_began(self) -> None:
        with mock.patch.object(supervise, "_finish"):
            code = supervise.run(game(30), self.env, force=True, session=SESSION, max_seconds=0.1)
        self.assertEqual(code, -signal.SIGTERM)

    def test_a_recorder_that_gave_up_still_starts_the_timer(self) -> None:
        FakeRecorder.gives_up = True
        with (
            mock.patch.object(supervise, "_finish"),
            mock.patch.object(FakeRecorder, "step", return_value=False),
        ):
            code = supervise.run(game(30), self.env, force=True, session=SESSION, max_seconds=0.1)
        self.assertEqual(code, -signal.SIGTERM)

    def test_a_blocked_run_says_why_it_is_not_recorded(self) -> None:
        code = supervise.run([sys.executable, "-c", "pass"], {"DISPLAY": ":9", "SIEGE_NO_RECORD": "1"})
        self.assertEqual(code, 0)
        self.assertIn("off (SIEGE_NO_RECORD=1)", self.err.getvalue())

    def test_a_new_session_id_is_a_timestamp_and_four_hex_digits(self) -> None:
        self.assertRegex(supervise.new_session(), r"^\d+-run-[0-9a-f]{4}$")

    def test_a_forwarded_hangup_reaches_the_game(self) -> None:
        proc = mock.Mock()
        supervise._forward_signals(proc)
        signal.getsignal(signal.SIGHUP)(signal.SIGHUP, None)
        proc.send_signal.assert_called_once_with(signal.SIGHUP)
        self.assertEqual(signal.getsignal(signal.SIGINT), signal.SIG_IGN)


class FinishTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.paths = supervise.recording_paths(Path(self.tmp.name), SESSION)
        self.err = io.StringIO()
        stderr = contextlib.redirect_stderr(self.err)
        stderr.__enter__()
        self.addCleanup(stderr.__exit__, None, None, None)

    def doc(self, parts: int) -> dict:
        events = [{"t": 1.0}, {"t": 2.0, "before_recording": True}]
        video = {"file": f"{SESSION}.mkv", "duration_s": 61.4, "parts": [{}] * parts}
        return {"events": events, "video": video}

    def test_without_a_rec_json_there_is_nothing_to_finish(self) -> None:
        supervise._finish(self.paths)
        self.assertEqual(self.err.getvalue(), "")

    def test_the_summary_line_counts_the_moments_inside_the_video(self) -> None:
        self.paths["dir"].mkdir(parents=True)
        self.paths["meta"].write_text("{}")
        with mock.patch.object(supervise.finalize, "finalize", return_value=self.doc(1)):
            supervise._finish(self.paths)
        self.assertRegex(self.err.getvalue(), re.escape(f"{SESSION}.mkv (61 s, 1 moments)"))

    def test_a_window_that_went_away_adds_the_part_count(self) -> None:
        self.paths["dir"].mkdir(parents=True)
        self.paths["meta"].write_text("{}")
        with mock.patch.object(supervise.finalize, "finalize", return_value=self.doc(2)):
            supervise._finish(self.paths)
        self.assertIn("1 moments, 2 parts)", self.err.getvalue())

    def test_a_finalize_error_is_reported_not_raised(self) -> None:
        self.paths["dir"].mkdir(parents=True)
        self.paths["meta"].write_text("{}")
        with mock.patch.object(supervise.finalize, "finalize", side_effect=KeyError("video")):
            supervise._finish(self.paths)
        self.assertIn("could not build the timeline: 'video'", self.err.getvalue())


if __name__ == "__main__":
    unittest.main()
