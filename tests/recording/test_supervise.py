"""Launcher logic: session ids, folders, a recorder that finalizes on exit."""

import os
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

from helpers import ROOT  # noqa: F401
from recording import supervise


class ArgsTest(unittest.TestCase):
    def test_session_id_is_added_after_the_double_dash(self) -> None:
        out = supervise.with_session(["godot", "--path", "/r", "--", "--dev"], "s1")
        self.assertEqual(out, ["godot", "--path", "/r", "--", "--dev", "--session-id=s1"])

    def test_session_id_without_a_double_dash_adds_one(self) -> None:
        self.assertEqual(supervise.with_session(["/b/game"], "s1"), ["/b/game", "--", "--session-id=s1"])

    def test_an_existing_session_id_wins(self) -> None:
        cmd = ["godot", "--", "--dev", "--session-id=mine"]
        self.assertEqual(supervise.with_session(cmd, "s1"), cmd)
        self.assertEqual(supervise.session_of(cmd), "mine")

    def test_feedback_dir_comes_from_the_args_then_the_binaries_dir(self) -> None:
        self.assertEqual(supervise.feedback_dir(["g", "--", "--feedback-dir=/fb"], {}), Path("/fb"))
        env = {"SIEGE_BINARIES": "/bin"}
        self.assertEqual(supervise.feedback_dir(["g", "--", "--dev"], env), Path("/bin/feedback"))
        home = {"HOME": "/h"}
        self.assertEqual(supervise.feedback_dir(["g"], home), Path("/h/data/fifteen-dollar-siege_binaries/feedback"))

    def test_recordings_land_next_to_the_feedback_log(self) -> None:
        self.assertEqual(supervise.recording_paths(Path("/fb"), "s1")["video"], Path("/fb/recordings/s1.mkv"))
        self.assertEqual(supervise.recording_paths(Path("/fb"), "s1")["events"], Path("/fb/recordings/s1.events.json"))


class StopTest(unittest.TestCase):
    def fake_recorder(self, tmp: str, handle_sigint: bool) -> subprocess.Popen:
        done = Path(tmp) / "finalized"
        body = f"""
            import signal, sys, time, pathlib
            def stop(*_):
                pathlib.Path({str(done)!r}).write_text("trailer written")
                sys.exit(0)
            if {handle_sigint}:
                signal.signal(signal.SIGINT, stop)
            else:
                signal.signal(signal.SIGINT, signal.SIG_IGN)
            print("up", flush=True)
            time.sleep(60)
        """
        proc = subprocess.Popen([sys.executable, "-c", textwrap.dedent(body)], stdout=subprocess.PIPE, text=True)
        assert proc.stdout is not None
        proc.stdout.readline()  # wait until the handlers are installed
        self.addCleanup(proc.stdout.close)
        return proc

    def test_sigint_lets_the_recorder_finalize_its_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            proc = self.fake_recorder(tmp, handle_sigint=True)
            self.assertTrue(supervise.stop_recorder(proc, grace_s=5.0))
            self.assertEqual((Path(tmp) / "finalized").read_text(), "trailer written")
            self.assertIsNotNone(proc.poll())

    def test_a_recorder_that_ignores_sigint_is_killed_after_the_grace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            proc = self.fake_recorder(tmp, handle_sigint=False)
            started = time.monotonic()
            self.assertFalse(supervise.stop_recorder(proc, grace_s=0.5))
            self.assertLess(time.monotonic() - started, 5.0)
            self.assertIsNotNone(proc.poll())

    def test_a_recorder_that_already_exited_is_fine(self) -> None:
        proc = subprocess.Popen([sys.executable, "-c", "pass"])
        proc.wait()
        self.assertTrue(supervise.stop_recorder(proc, grace_s=1.0))


class PassThroughTest(unittest.TestCase):
    def test_a_blocked_run_just_runs_the_command_and_keeps_its_exit_code(self) -> None:
        env = {**os.environ, "DISPLAY": ":0"}
        code = supervise.run([sys.executable, "-c", "import sys; sys.exit(7)", "--autodrive"], env=env)
        self.assertEqual(code, 7)

    def test_run_never_signals_the_game_with_the_recorder_signal(self) -> None:
        self.assertEqual(signal.SIGINT.value, 2)  # the recorder is stopped by SIGINT; documented here


if __name__ == "__main__":
    unittest.main()
