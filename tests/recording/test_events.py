"""Which telemetry entries become moments, and what each one keeps."""

import unittest

from helpers import entry
from recording import moments


class EventKindsTest(unittest.TestCase):
    def moment(self, row: dict, kind: str) -> dict:
        found = moments.classify([row])
        self.assertEqual([m["kind"] for m in found], [kind], row)
        return found[0]

    def test_session_start_and_hub_are_moments(self) -> None:
        self.moment(entry("session_start", 0, 1), "session_start")
        self.assertEqual(self.moment(entry("hub_open", 50, 2), "hub_open")["label"], "hub_open")

    def test_game_start_keeps_the_whole_loadout(self) -> None:
        row = entry(
            "game_start",
            9000,
            2,
            game="command",
            loadout=["double_men", "stew"],
            cost=6,
            men=200,
            seed=7,
        )
        m = self.moment(row, "game_start")
        self.assertEqual(m["game"], "command")
        self.assertEqual(m["loadout"], ["double_men", "stew"])
        self.assertEqual((m["cost"], m["men"], m["seed"]), (6, 200, 7))
        self.assertEqual(m["label"], "game_start command double_men,stew 6 200 7")
        self.assertEqual((m["ms"], m["seq"], m["event"]), (9000, 2, "game_start"))

    def test_game_end_names_the_outcome(self) -> None:
        m = self.moment(entry("game_end", 9000, 2, outcome="win", elapsed_s=20.5), "game_end")
        self.assertEqual(m["label"], "game_end win")
        self.assertEqual(m["elapsed_s"], 20.5)

    def test_a_buy_and_an_order_keep_their_fields(self) -> None:
        buy = self.moment(entry("buy", 100, 2, buff="moose", bought=True, cost=3), "buy")
        self.assertEqual(buy["label"], "buy moose True 3")
        order = self.moment(entry("command", 200, 3, order="rally", pos=[120.0, 80.0]), "command")
        self.assertEqual(order["order"], "rally")
        self.assertEqual(order["label"], "command rally 120.0,80.0")

    def test_pause_lab_reset_quit_and_session_end(self) -> None:
        self.moment(entry("pause_open", 9000, 2), "pause_open")
        self.assertEqual(
            self.moment(entry("pause_close", 9000, 2, paused_s=3.0), "pause_close")["paused_s"],
            3.0,
        )
        lab = self.moment(
            entry("lab_result", 9000, 2, wins=12, runs=30, mean_seconds=19.5),
            "lab_result",
        )
        self.assertEqual(lab["label"], "lab_result 12 30 19.5")
        self.assertEqual(
            self.moment(entry("reset_progress", 9000, 2, files=1), "reset_progress")["files"],
            1,
        )
        self.assertEqual(self.moment(entry("quit", 9000, 2, reason="menu"), "quit")["reason"], "menu")
        end = self.moment(entry("session_end", 9000, 2, reason="exit", elapsed_s=120.0), "session_end")
        self.assertEqual(end["label"], "session_end exit 120.0")

    def test_an_annotation_carries_its_png_and_mark_count(self) -> None:
        row = entry("annotation", 9000, 2, image="/fb/x/annotated.png", marks=3, bundle="/fb/x")
        m = self.moment(row, "annotation")
        self.assertEqual(m["label"], "F12 annotation")
        self.assertEqual(m["png"], "/fb/x/annotated.png")
        self.assertEqual(m["marks"], 3)

    def test_real_engine_errors_are_moments_and_noise_is_not(self) -> None:
        row = entry(
            "engine_error",
            9000,
            2,
            kind="script_error",
            message="boom " * 30,
            file="a.gd",
            line=3,
        )
        m = self.moment(row, "engine_error")
        self.assertEqual(m["error_kind"], "script_error")
        self.assertEqual(m["label"], "engine_error " + ("boom " * 30)[:60])
        self.assertEqual((m["file"], m["line"]), ("a.gd", 3))
        for kind in ("warning", "stderr"):
            self.assertEqual(
                moments.classify([entry("engine_error", 1, 1, kind=kind, message="x")]),
                [],
            )

    def test_sim_events_the_game_may_log_later_pass_through(self) -> None:
        m = self.moment(
            entry("siege_wall_breached", 9000, 2, at=[1, 2], tag="v01"),
            "siege_wall_breached",
        )
        self.assertEqual(m["at"], [1, 2])
        self.assertNotIn("tag", m)
        self.assertNotIn("session", m)
        self.moment(entry("milestone_first_win", 9000, 2), "milestone_first_win")

    def test_everything_else_is_not_a_moment(self) -> None:
        for name in ("recording_sync", "screen", "hitch", "", "perf"):
            self.assertEqual(moments.classify([entry(name, 9000, 2)]), [], name)

    def test_event_name_is_the_event_field(self) -> None:
        self.assertEqual(moments.event_name({"event": "buy"}), "buy")
        self.assertEqual(moments.event_name({}), "")


if __name__ == "__main__":
    unittest.main()
