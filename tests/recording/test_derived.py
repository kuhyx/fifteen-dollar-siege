"""Derived moments: several telemetry entries that are one moment together."""

import unittest

from helpers import entry
from recording import moments


class DerivedTest(unittest.TestCase):
    def test_a_burst_of_hitches_is_one_moment(self) -> None:
        rows = [
            entry("hitch", 1000, 1, dur_ms=40, cause="load"),
            entry("hitch", 1500, 2, dur_ms=90),
            entry("hitch", 3400, 3, dur_ms=55),
        ]
        found = moments.derive(rows)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["kind"], "hitch")
        self.assertEqual((found[0]["count"], found[0]["max_ms"]), (3, 90))
        self.assertEqual(found[0]["label"], "hitch x3 max 90 ms")
        self.assertEqual(found[0]["ms"], 1000, "stamped at the first hitch")
        self.assertEqual(found[0]["cause"], "load")
        self.assertTrue(found[0]["derived"])

    def test_hitches_far_apart_are_separate_moments(self) -> None:
        gap_ms = int(moments.HITCH_MERGE_S * 1000) + 1
        rows = [
            entry("hitch", 1000, 1, dur_ms=40),
            entry("hitch", 1000 + gap_ms, 2, dur_ms=20),
        ]
        found = moments.derive(rows)
        self.assertEqual([m["label"] for m in found], ["hitch x1 max 40 ms", "hitch x1 max 20 ms"])

    def test_a_hitch_without_a_duration_counts_as_zero(self) -> None:
        self.assertEqual(moments.derive([entry("hitch", 1000, 1)])[0]["max_ms"], 0)

    def test_other_entries_derive_nothing(self) -> None:
        rows = [
            entry("game_start", 1000, 1, game="watch"),
            entry("command", 2000, 2, order="charge"),
        ]
        self.assertEqual(moments.derive(rows), [])
        self.assertEqual(moments.derive([]), [])


if __name__ == "__main__":
    unittest.main()
