"""Timeline builder: telemetry entries -> recording timestamps."""

import json
import unittest
from typing import ClassVar

from helpers import SESSION, SYNC_MS, SYNC_UNIX, entry, sync_entry
from recording import timeline

# The recorder started 0.5 s after the game's sync instant (t0 on the unix clock).
T0 = SYNC_UNIX + 0.5
BUILD = {"t0_unix": T0, "video_start_s": 0.052, "duration_s": 600.0}


def build(entries: list[dict], **kw: object) -> dict:
    args = {**BUILD, **kw}
    return timeline.build_events(entries, session=SESSION, **args)


def kinds(doc: dict) -> list[str]:
    return [e["kind"] for e in doc["events"]]


class OffsetTest(unittest.TestCase):
    def test_event_time_is_sync_unix_plus_ms_delta_minus_t0(self) -> None:
        # event 5000 ms after the sync entry -> unix SYNC+5.0 -> 4.5 s after t0
        doc = build([sync_entry(), entry("command", SYNC_MS + 5000, 2, order="rally", pos=[1, 2])])
        order = next(e for e in doc["events"] if e["kind"] == "command")
        self.assertAlmostEqual(order["t"], 4.5, places=6)

    def test_offset_is_exact_to_a_millisecond(self) -> None:
        doc = build([sync_entry(), entry("command", SYNC_MS + 1234, 2, order="rally", pos=[1, 2])])
        order = next(e for e in doc["events"] if e["kind"] == "command")
        self.assertAlmostEqual(order["t"], 1.234 - 0.5, places=3)

    def test_unix_us_integer_microseconds_is_read(self) -> None:
        sync = {**sync_entry(), "unix_us": round(SYNC_UNIX * 1_000_000)}
        del sync["unix"]
        doc = build([sync, entry("command", SYNC_MS + 5000, 2, order="rally", pos=[1, 2])])
        self.assertAlmostEqual(doc["events"][0]["t"], 4.5, places=6)

    def test_sync_entry_itself_is_not_a_moment(self) -> None:
        self.assertNotIn("recording_sync", kinds(build([sync_entry()])))

    def test_events_before_the_recorder_started_are_flagged_not_dropped(self) -> None:
        doc = build([sync_entry(), entry("game_start", SYNC_MS + 100, 2, game="watch")])
        start = next(e for e in doc["events"] if e["kind"] == "game_start")
        self.assertLess(start["t"], 0.052)
        self.assertTrue(start["before_recording"])

    def test_events_after_the_file_ended_are_flagged(self) -> None:
        doc = build(
            [sync_entry(), entry("command", SYNC_MS + 700_000, 2, order="rally", pos=[1, 2])],
            duration_s=10.0,
        )
        self.assertTrue(doc["events"][-1]["after_recording"])

    def test_no_sync_entry_falls_back_to_wall_time_and_says_so(self) -> None:
        start = entry("session_start", 0, 1)
        doc = build([start, entry("command", 3000, 2, order="rally", pos=[1, 2])])
        self.assertTrue(doc["sync"]["approx"])
        self.assertEqual(doc["sync"]["method"], "session_start.time")

    def test_exact_sync_is_not_approx(self) -> None:
        doc = build([sync_entry()])
        self.assertFalse(doc["sync"]["approx"])
        self.assertEqual(doc["sync"]["method"], "recording_sync")

    def test_other_sessions_are_ignored(self) -> None:
        other = entry("command", 9000, 5, order="rally", pos=[1, 2])
        other["session"] = "someone-else"
        self.assertNotIn("command", kinds(build([sync_entry(), other])))

    def test_events_are_sorted_by_time(self) -> None:
        rows = [
            sync_entry(),
            entry("pause_open", 9000, 3),
            entry("pause_close", 4000, 2),
        ]
        times = [e["t"] for e in build(rows)["events"]]
        self.assertEqual(times, sorted(times))


class ChaptersTest(unittest.TestCase):
    def meta(self, rows: list[dict]) -> str:
        doc = build([sync_entry(), *rows])
        return timeline.chapters_ffmetadata(doc["events"], duration_s=600.0, video_start_s=0.052)

    def test_events_in_the_same_millisecond_share_one_chapter(self) -> None:
        # the muxer drops a second chapter with the same start
        text = self.meta(
            [
                entry("pause_open", SYNC_MS + 10_500, 2),
                entry("reset_progress", SYNC_MS + 10_500, 3, files=2),
                entry("pause_close", SYNC_MS + 12_500, 4),
            ]
        )
        self.assertEqual(text.count("[CHAPTER]"), 2)
        title = next(line for line in text.splitlines() if line.startswith("title=pause_open"))
        self.assertIn("reset_progress", title)

    def test_header_and_chapter_block(self) -> None:
        text = self.meta([entry("command", SYNC_MS + 10_500, 2, order="rally", pos=[1, 2])])
        lines = text.splitlines()
        self.assertEqual(lines[0], ";FFMETADATA1")
        self.assertIn("[CHAPTER]", lines)
        self.assertIn("TIMEBASE=1/1000", lines)
        self.assertIn("START=10000", lines)
        self.assertTrue(any(line.startswith("title=") for line in lines))

    def test_chapters_do_not_overlap_and_end_at_the_next_start(self) -> None:
        text = self.meta(
            [
                entry("command", SYNC_MS + 5500, 2, order="rally", pos=[1, 2]),
                entry("pause_open", SYNC_MS + 9500, 3),
            ]
        )
        starts = [int(x.split("=")[1]) for x in text.splitlines() if x.startswith("START=")]
        ends = [int(x.split("=")[1]) for x in text.splitlines() if x.startswith("END=")]
        self.assertEqual(starts, [5000, 9000])
        self.assertEqual(ends[0], starts[1] - 1)
        self.assertGreaterEqual(ends[1], starts[1])

    def test_events_outside_the_file_get_no_chapter(self) -> None:
        text = self.meta([entry("game_start", SYNC_MS + 100, 2, game="watch")])
        self.assertNotIn("[CHAPTER]", text)

    def test_titles_escape_ffmetadata_specials(self) -> None:
        self.assertEqual(timeline.escape_meta("a=b;c#d\\e\nf"), "a\\=b\\;c\\#d\\\\e\\\nf")


class FilesTest(unittest.TestCase):
    def test_load_session_reads_only_that_session(self) -> None:
        import tempfile
        from pathlib import Path

        other = {**entry("command", 1, 1, order="rally", pos=[1, 2]), "session": "other"}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "feedback.jsonl"
            rows = [sync_entry(), other, entry("pause_open", 9000, 3)]
            path.write_text("\n".join(json.dumps(r) for r in rows) + "\nnot json\n")
            loaded = timeline.load_session(path, SESSION)
        self.assertEqual([r["event"] for r in loaded], ["recording_sync", "pause_open"])

    def test_document_is_json_serialisable(self) -> None:
        doc = build([sync_entry(), entry("command", 9000, 2, order="rally", pos=[1, 2])])
        self.assertEqual(json.loads(json.dumps(doc))["session"], SESSION)


if __name__ == "__main__":
    unittest.main()


class PartsTest(unittest.TestCase):
    """The recorder restarts when the window goes away (workspace switch): one part per run."""

    PARTS: ClassVar[list[dict]] = [
        {"file": "s.mkv", "start_s": 0.05, "duration_s": 10.0},
        {"file": "s.part2.mkv", "start_s": 20.0, "duration_s": 10.0},
    ]

    def doc(self, ms_after_sync: int) -> dict:
        rows = [
            sync_entry(),
            entry("command", SYNC_MS + ms_after_sync, 2, order="rally", pos=[1, 2]),
        ]
        return timeline.build_events(rows, session=SESSION, t0_unix=T0, parts=self.PARTS)

    def event(self, t: float) -> dict:
        # t seconds on the file timeline <-> ms in the game clock (t0 is 0.5 s after the sync)
        return next(e for e in self.doc(round((t + 0.5) * 1000))["events"] if e["kind"] == "command")

    def test_event_in_a_part_names_that_file(self) -> None:
        self.assertEqual(self.event(5.0)["file"], "s.mkv")
        self.assertEqual(self.event(25.0)["file"], "s.part2.mkv")

    def test_event_between_the_parts_is_flagged_in_gap(self) -> None:
        e = self.event(15.0)
        self.assertTrue(e["in_gap"])
        self.assertNotIn("file", e)
        self.assertFalse(timeline.in_recording(e))

    def test_before_the_first_and_after_the_last_part(self) -> None:
        self.assertTrue(self.event(0.0)["before_recording"])
        self.assertTrue(self.event(40.0)["after_recording"])

    def test_document_lists_the_parts_and_the_overall_span(self) -> None:
        video = self.doc(6000)["video"]
        self.assertEqual([p["file"] for p in video["parts"]], ["s.mkv", "s.part2.mkv"])
        self.assertEqual((video["start_s"], video["end_s"]), (0.05, 30.0))

    def test_chapters_are_per_part(self) -> None:
        doc = self.doc(25_500)
        text = timeline.chapters_ffmetadata(doc["events"], 10.0, 20.0, file="s.part2.mkv")
        self.assertIn("START=25000", text)
        self.assertNotIn(
            "[CHAPTER]",
            timeline.chapters_ffmetadata(doc["events"], 10.0, 0.05, file="s.mkv"),
        )
