"""Listing and opening a recording at a moment."""

import unittest
from pathlib import Path

from helpers import ROOT  # noqa: F401
from recording import library

DOC = {
    "session": "s1",
    "tag": "v02",
    "video": {"start_s": 0.052, "duration_s": 100.0, "end_s": 100.052, "file": "s1.mkv"},
    "sync": {"approx": False},
    "events": [
        {"t": -2.0, "label": "game_start watch", "before_recording": True},
        {"t": 1.0, "label": "pause_open"},
        {"t": 42.5, "label": "command rally"},
        {"t": 400.0, "label": "late", "after_recording": True},
    ],
}


class LibraryTest(unittest.TestCase):
    def test_stamp_is_minutes_seconds_millis(self) -> None:
        self.assertEqual(library.stamp(75.5), "01:15.500")
        self.assertEqual(library.stamp(0.0), "00:00.000")

    def test_table_numbers_only_moments_inside_the_file(self) -> None:
        lines = library.table(DOC).splitlines()
        self.assertIn("  1  00:01.000  pause_open", "  ".join(lines[1:2]).replace("   ", "  "))
        self.assertEqual(len(lines), 3)
        self.assertTrue(lines[2].lstrip().startswith("2  00:42.500  command rally"))

    def test_open_seeks_a_little_before_the_moment_on_the_files_own_timeline(self) -> None:
        cmd = library.open_command(DOC, Path("/rec"), 2)
        self.assertEqual(cmd[0], "mpv")
        self.assertIn("--rebase-start-time=no", cmd)
        self.assertIn("--start=39.500", cmd)
        self.assertEqual(cmd[-1], "/rec/s1.mkv")

    def test_open_never_seeks_before_the_first_frame(self) -> None:
        self.assertIn("--start=0.052", library.open_command(DOC, Path("/rec"), 1))

    def test_open_without_a_number_plays_from_the_start(self) -> None:
        self.assertFalse(any(a.startswith("--start") for a in library.open_command(DOC, Path("/rec"), None)))

    def test_open_of_a_missing_moment_says_the_range(self) -> None:
        with self.assertRaises(IndexError):
            library.open_command(DOC, Path("/rec"), 9)


PARTED = {
    "session": "s2",
    "video": {
        "start_s": 0.05, "duration_s": 30.0, "end_s": 30.05, "file": "s2.mkv",
        "parts": [
            {"file": "s2.mkv", "start_s": 0.05, "duration_s": 10.0},
            {"file": "s2.part2.mkv", "start_s": 20.0, "duration_s": 10.0},
        ],
    },
    "sync": {"approx": False},
    "events": [
        {"t": 5.0, "label": "a", "file": "s2.mkv"},
        {"t": 15.0, "label": "in the gap", "in_gap": True},
        {"t": 21.0, "label": "b", "file": "s2.part2.mkv"},
    ],
}  # fmt: skip


class PartsTest(unittest.TestCase):
    def test_gap_moments_are_not_listed(self) -> None:
        self.assertEqual([e["label"] for e in library.shown(PARTED)], ["a", "b"])

    def test_open_uses_the_part_that_holds_the_moment(self) -> None:
        cmd = library.open_command(PARTED, Path("/rec"), 2)
        self.assertEqual(cmd[-1], "/rec/s2.part2.mkv")
        self.assertIn("--start=20.000", cmd, "clamped to the part's first frame, not 18.0")

    def test_the_table_says_the_window_went_away(self) -> None:
        text = library.table(PARTED)
        self.assertIn("2 parts", text)
        self.assertIn("[s2.part2.mkv]", text)


if __name__ == "__main__":
    unittest.main()
