"""Finding the game's window by pid: xdotool is faked, the clock is stepped by hand."""

import subprocess
import unittest
from unittest import mock

from helpers import ROOT
from recording import window

GEOMETRY = {
    "1": "WINDOW=1\nX=0\nY=0\nWIDTH=1280\nHEIGHT=800\nSCREEN=0\n",
    "2": "WIDTH=32\nHEIGHT=32\n",
    "3": "WIDTH=1920\nHEIGHT=1080\n",
    "4": "WIDTH=wide\nHEIGHT=1080\n",
}


def fake_xdotool(*args: str) -> str:
    if args[0] == "search":
        return "1 2 3 4 5\n"
    return GEOMETRY.get(args[-1], "")


class RunTest(unittest.TestCase):
    def test_xdotool_output_is_returned_on_success_and_empty_on_failure(self) -> None:
        done = subprocess.CompletedProcess([], 0, stdout="out")
        with mock.patch.object(window.subprocess, "run", return_value=done) as run:
            self.assertEqual(window._run("search", "--pid", "7"), "out")
        self.assertEqual(run.call_args.args[0], ["xdotool", "search", "--pid", "7"])
        with mock.patch.object(window.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, stdout="x")):
            self.assertEqual(window._run("search"), "")


class SourceTest(unittest.TestCase):
    def test_xdotool_is_the_only_program_it_runs(self) -> None:
        source = (ROOT / "tools/recording/window.py").read_text()
        self.assertEqual(source.count("subprocess.run("), 1)
        self.assertIn('["xdotool", *args]', source)


class LargestTest(unittest.TestCase):
    def test_the_biggest_real_window_wins(self) -> None:
        with mock.patch.object(window, "_run", side_effect=fake_xdotool):
            self.assertEqual(window.largest(7), window.Window(3, 1920, 1080))

    def test_helper_and_unreadable_windows_are_not_the_game(self) -> None:
        with mock.patch.object(window, "_run", return_value=""):
            self.assertIsNone(window.largest(7))

    def test_a_window_with_odd_geometry_text_is_skipped(self) -> None:
        with mock.patch.object(window, "_run", side_effect=fake_xdotool):
            self.assertIsNone(window._geometry("4"))
            self.assertIsNone(window._geometry("5"))


class WaitStableTest(unittest.TestCase):
    A = window.Window(1, 1280, 800)
    B = window.Window(1, 1920, 1080)

    def wait(self, sizes: list[window.Window | None], alive: list[bool] | None = None) -> window.Window | None:
        clock = iter(range(1000))
        with (
            mock.patch.object(window, "largest", side_effect=sizes),
            mock.patch.object(window.time, "monotonic", side_effect=lambda: next(clock)),
            mock.patch.object(window.time, "sleep") as sleep,
        ):
            flags = iter(alive or [True] * len(sizes))
            result = window.wait_stable(7, 50.0, lambda: next(flags, False))
        self.assertLessEqual(sleep.call_count, len(sizes))
        return result

    def test_the_window_is_returned_once_it_holds_still(self) -> None:
        self.assertEqual(self.wait([self.A, self.A, self.A]), self.A)

    def test_a_resize_restarts_the_count(self) -> None:
        self.assertEqual(self.wait([self.A, self.A, self.B, self.B, self.B]), self.B)

    def test_no_window_yet_keeps_waiting(self) -> None:
        self.assertEqual(self.wait([None, None, self.A, self.A, self.A]), self.A)

    def test_a_game_that_exits_ends_the_wait(self) -> None:
        self.assertIsNone(self.wait([self.A, self.A, self.A], alive=[True, False]))

    def test_the_deadline_ends_the_wait(self) -> None:
        clock = iter([0.0, 1.0, 100.0])
        with (
            mock.patch.object(window, "largest", return_value=None),
            mock.patch.object(window.time, "monotonic", side_effect=lambda: next(clock)),
            mock.patch.object(window.time, "sleep"),
        ):
            self.assertIsNone(window.wait_stable(7, 5.0, lambda: True))


if __name__ == "__main__":
    unittest.main()
