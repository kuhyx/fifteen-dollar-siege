"""When a run is recorded (kuhy's dev play) and when never (bots, tests, headless)."""

import unittest

from helpers import ROOT  # noqa: F401  (puts tools/ on sys.path)
from recording import policy

LIVE = {"DISPLAY": ":0"}


class PolicyTest(unittest.TestCase):
    def test_kuhy_dev_run_is_recorded(self) -> None:
        d = policy.decide(["godot", "--path", "/r", "--", "--dev"], LIVE)
        self.assertTrue(d.record, d.reason)

    def test_exported_dev_build_is_recorded(self) -> None:
        d = policy.decide(["/b/fifteen-dollar-siege.x86_64", "--", "--dev", "--dev-tag=v01"], LIVE)
        self.assertTrue(d.record, d.reason)

    def test_no_dev_flag_means_no_recording(self) -> None:
        self.assertFalse(policy.decide(["godot", "--"], LIVE).record)

    def test_each_bot_marker_blocks(self) -> None:
        for marker in ("--autodrive=watch", "--dev-shot=/t/s.png", "--result-file=/t/r", "--expect-window=1280x800"):
            d = policy.decide(["godot", "--", "--dev", marker], LIVE)
            self.assertFalse(d.record, marker)

    def test_headless_and_muted_engine_runs_block(self) -> None:
        for engine in (["--headless"], ["--audio-driver", "Dummy"], ["--display-driver", "headless"]):
            self.assertFalse(policy.decide(["godot", *engine, "--", "--dev"], LIVE).record, engine)

    def test_save_dir_test_runs_block(self) -> None:
        self.assertFalse(policy.decide(["godot", "--", "--dev", "--save-dir=/t"], LIVE).record)

    def test_no_display_blocks(self) -> None:
        self.assertFalse(policy.decide(["godot", "--", "--dev"], {}).record)

    def test_env_opt_outs_block(self) -> None:
        for env in (
            {"SIEGE_NO_RECORD": "1"},
            {"SIEGE_FEEDBACK_DIR": "/t"},
        ):
            self.assertFalse(policy.decide(["godot", "--", "--dev"], {**LIVE, **env}).record, env)

    def test_env_set_to_zero_is_off_like_in_the_scripts(self) -> None:
        for name in ("SIEGE_NO_RECORD",):
            self.assertTrue(policy.decide(["godot", "--", "--dev"], {**LIVE, name: "0"}).record, name)

    def test_force_overrides_bot_rules_but_not_a_missing_display(self) -> None:
        args = ["godot", "--audio-driver", "Dummy", "--", "--dev", "--autodrive", "--save-dir=/t"]
        self.assertTrue(policy.decide(args, LIVE, force=True).record)
        self.assertFalse(policy.decide(args, {}, force=True).record)

    def test_the_reason_names_the_blocker(self) -> None:
        self.assertIn("--autodrive", policy.decide(["godot", "--", "--dev", "--autodrive"], LIVE).reason)

    def test_session_and_feedback_dir_come_from_the_args(self) -> None:
        a = ["godot", "--", "--dev", "--session-id=abc", "--feedback-dir=/fb"]
        self.assertEqual(policy.arg_value(a, "--session-id="), "abc")
        self.assertEqual(policy.arg_value(a, "--feedback-dir="), "/fb")
        self.assertEqual(policy.arg_value(a, "--nope="), "")


if __name__ == "__main__":
    unittest.main()
