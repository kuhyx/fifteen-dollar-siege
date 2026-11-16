"""The record.py CLI: each subcommand reaches the right module with the right arguments."""

import contextlib
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import ROOT
from recording import record

DOC = {
    "session": "s1",
    "tag": "v02",
    "video": {"start_s": 0.0, "duration_s": 10.0, "end_s": 10.0, "file": "s1.mkv"},
    "sync": {"approx": False},
    "events": [{"t": 1.0, "label": "pause_open"}],
}


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        (self.dir / "s1.events.json").write_text(json.dumps(DOC), encoding="utf-8")

    def run_cli(self, *argv: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = record.main(list(argv))
        return code, out.getvalue()

    def test_wrap_passes_the_command_after_the_double_dash_and_the_options(self) -> None:
        with mock.patch.object(record.supervise, "run", return_value=4) as run:
            code, _ = self.run_cli("wrap", "--force", "--fps", "60", "--max-seconds", "2", "--", "godot", "--dev")
        self.assertEqual(code, 4)
        run.assert_called_once_with(
            ["godot", "--dev"], force=True, session="", audio="default", fps=60, max_seconds=2.0
        )

    def test_wrap_without_a_double_dash_takes_the_command_as_given(self) -> None:
        with mock.patch.object(record.supervise, "run", return_value=0) as run:
            self.run_cli("wrap", "--session", "x", "game")
        self.assertEqual(run.call_args.args[0], ["game"])
        self.assertEqual(run.call_args.kwargs["session"], "x")

    def test_finalize_rebuilds_the_events_of_one_rec_json(self) -> None:
        with mock.patch.object(record.finalize, "finalize") as finalize:
            self.assertEqual(self.run_cli("finalize", "/r/s1.rec.json")[0], 0)
        finalize.assert_called_once_with(Path("/r/s1.rec.json"))

    def test_list_and_latest_print_the_library(self) -> None:
        code, out = self.run_cli("list", "--dir", str(self.dir))
        self.assertEqual((code, out), (0, "s1  00:10.000  1 moments  v02\n"))
        code, out = self.run_cli("latest", "--dir", str(self.dir), "--session", "s1")
        self.assertEqual(code, 0)
        self.assertIn("pause_open", out)

    def test_open_dry_run_prints_the_player_command(self) -> None:
        code, out = self.run_cli("open", "1", "--dir", str(self.dir), "--dry-run")
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith("mpv "))
        self.assertTrue(out.strip().endswith("s1.mkv"))

    def test_open_of_a_missing_moment_exits_with_the_message(self) -> None:
        with self.assertRaises(SystemExit) as raised:
            self.run_cli("open", "9", "--dir", str(self.dir), "--dry-run")
        self.assertEqual(str(raised.exception), "no moment 9 (1..1)")

    def test_a_session_that_matches_nothing_exits_with_the_message(self) -> None:
        with self.assertRaises(SystemExit) as raised:
            self.run_cli("latest", "--dir", str(self.dir), "--session", "zzz")
        self.assertEqual(str(raised.exception), f"no recordings in {self.dir}")

    def test_the_default_dir_is_the_feedback_recordings_folder(self) -> None:
        with mock.patch.dict("os.environ", {"SIEGE_BINARIES": "/b"}):
            self.assertEqual(record.default_dir(), Path("/b/feedback/recordings"))

    def test_the_script_runs_as_a_program(self) -> None:
        out = io.StringIO()
        argv = ["record.py", "list", "--dir", str(self.dir)]
        with (
            mock.patch.object(sys, "argv", argv),
            contextlib.redirect_stdout(out),
            self.assertRaises(SystemExit) as raised,
        ):
            runpy.run_path(str(ROOT / "tools/recording/record.py"), run_name="__main__")
        self.assertEqual(raised.exception.code, 0)
        self.assertIn("1 moments", out.getvalue())


if __name__ == "__main__":
    unittest.main()
