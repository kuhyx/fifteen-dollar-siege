"""This game's configuration of the session recorder (the package is kuhyx/utils game_recording)."""

import contextlib
import importlib
import io
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from unittest import mock

from game_recording import moments, policy, supervise

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "recording" / "siege_recording.py"
DEV_RUN = ["godot", "--", "--dev"]


def load_config_module() -> ModuleType:
    """tools/recording/siege_recording.py is a script, not a package: import it by path."""
    sys.path.insert(0, str(SCRIPT.parent))
    try:
        return importlib.import_module("siege_recording")
    finally:
        sys.path.remove(str(SCRIPT.parent))


siege = load_config_module()


def row(event: str, **fields: object) -> dict:
    return {"event": event, "session": "s", "seq": 1, "ms": 5, **fields}


class ConfigTest(unittest.TestCase):
    def test_the_env_names_keep_the_siege_prefix(self) -> None:
        config = siege.CONFIG
        self.assertEqual(config.blocking_flags, ("SIEGE_NO_RECORD",))
        self.assertEqual(config.binaries_var, "SIEGE_BINARIES")
        self.assertEqual(config.env_name("FEEDBACK_DIR"), "SIEGE_FEEDBACK_DIR")
        self.assertEqual(config.env_name("RECORDER_BACKEND"), "SIEGE_RECORDER_BACKEND")
        self.assertEqual(config.env_name("RECORDER_NICE"), "SIEGE_RECORDER_NICE")

    def test_the_env_opt_outs_block_recording(self) -> None:
        live = {"DISPLAY": ":0"}
        self.assertTrue(policy.decide(DEV_RUN, live, siege.CONFIG).record)
        for env in ({"SIEGE_NO_RECORD": "1"}, {"SIEGE_FEEDBACK_DIR": "/t"}):
            self.assertFalse(policy.decide(DEV_RUN, {**live, **env}, siege.CONFIG).record, env)

    def test_the_default_feedback_dir_is_the_binaries_folder(self) -> None:
        home = {"HOME": "/h"}
        want = Path("/h/data/fifteen-dollar-siege_binaries/feedback")
        self.assertEqual(supervise.feedback_dir([], home, siege.CONFIG), want)
        self.assertEqual(
            supervise.feedback_dir([], {**home, "SIEGE_BINARIES": "/b"}, siege.CONFIG), Path("/b/feedback")
        )
        self.assertEqual(supervise.feedback_dir(["--feedback-dir=/x"], home, siege.CONFIG), Path("/x"))


class MomentMapTest(unittest.TestCase):
    def kind(self, entry: dict) -> str | None:
        found = moments.classify([entry], siege.CONFIG.moments)
        return found[0]["kind"] if found else None

    def test_every_telemetry_entry_of_src_dev_is_a_moment(self) -> None:
        for event in ("session_start", "hub_open", "buy", "game_start", "command", "pause_open", "pause_close"):
            self.assertEqual(self.kind(row(event)), event)
        for event in ("lab_result", "reset_progress", "quit", "session_end"):
            self.assertEqual(self.kind(row(event)), event)

    def test_the_fields_kept_are_the_ones_the_game_writes(self) -> None:
        found = moments.classify(
            [row("game_start", loadout=["a", "b"], cost=6, men=200, seed=7, junk=1)], siege.CONFIG.moments
        )
        self.assertEqual(found[0]["label"], "game_start a,b 6 200 7")
        self.assertNotIn("junk", found[0])
        self.assertEqual(self.kind(row("command", order="rally", pos=[1.0, 2.0])), "command")

    def test_sim_events_pass_through_and_noise_does_not(self) -> None:
        self.assertEqual(self.kind(row("siege_gate_down", where=3)), "siege_gate_down")
        self.assertEqual(self.kind(row("milestone_half")), "milestone_half")
        self.assertIsNone(self.kind(row("frame_stats")))


class EntryPointTest(unittest.TestCase):
    def test_main_runs_a_recorder_command_for_this_game(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(siege.main(["list", "--dir", tmp]), 0)
        self.assertEqual(out.getvalue(), "\n")

    def test_run_as_a_script_exits_with_the_commands_code(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            argv = [str(SCRIPT), "list", "--dir", tmp]
            patched = mock.patch.object(sys, "argv", argv)
            with patched, contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as raised:
                runpy.run_path(str(SCRIPT), run_name="__main__")
        self.assertEqual(raised.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
