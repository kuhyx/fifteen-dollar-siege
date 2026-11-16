"""The render pipeline: loop files close the way Godot plays them, files hit their level, the catalogue is whole."""

import contextlib
import io
import re
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from audio.dsp import SR

from audio import analyze, catalog, checks, dsp, grid, loudness, render, wavio


def tone(hz: float, seconds: float, level: float = 0.2) -> np.ndarray:
    return level * np.sin(2.0 * np.pi * hz * np.arange(int(seconds * SR)) / SR)


class WavTest(unittest.TestCase):
    def test_a_loop_is_written_with_its_first_frame_again_at_the_end(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            loop = dsp.pan(tone(100.0, 0.5), 0.3)
            path = wavio.write(Path(tmp) / "loop.wav", loop, SR, loop=True)
            back, rate = wavio.read(path)
            self.assertEqual((rate, back.shape), (SR, (len(loop) + 1, 2)))
            self.assertTrue(wavio.is_closed(back))
            np.testing.assert_allclose(back[:-1], loop, atol=1.0 / 32767.0)

    def test_a_one_shot_keeps_its_length(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            back, _ = wavio.read(wavio.write(Path(tmp) / "hit.wav", tone(300.0, 0.1), SR))
            self.assertEqual(back.shape, (int(0.1 * SR),))

    def test_the_sidecar_is_lossless_and_says_whether_it_loops(self) -> None:
        self.assertIn("compress/mode=0", wavio.sidecar_text(True))
        self.assertIn("edit/loop_mode=2", wavio.sidecar_text(True))
        self.assertIn("edit/loop_mode=1", wavio.sidecar_text(False))

    def test_the_sidecar_is_left_alone_once_godot_has_filled_it_in(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.wav"
            self.assertTrue(wavio.write_sidecar(path, True))
            sidecar = path.with_name("a.wav.import")
            sidecar.write_text(sidecar.read_text().replace("[params]", 'uid="uid://x"\n\n[params]'))
            self.assertFalse(wavio.write_sidecar(path, True))
            self.assertIn("uid://x", sidecar.read_text())
            self.assertTrue(wavio.write_sidecar(path, False), "a changed loop mode rewrites it")


class MixTest(unittest.TestCase):
    def test_a_tail_past_the_end_of_a_loop_comes_back_at_the_start(self) -> None:
        total = np.zeros(10)
        dsp.place(total, 8, np.ones(4), wrap=True)
        np.testing.assert_array_equal(total, [1, 1, 0, 0, 0, 0, 0, 0, 1, 1])
        cut = np.zeros(10)
        dsp.place(cut, 8, np.ones(4))
        np.testing.assert_array_equal(cut, [0, 0, 0, 0, 0, 0, 0, 0, 1, 1])

    def test_a_filter_with_wrap_keeps_a_loop_seamless(self) -> None:
        loop = tone(100.0, 1.0) + tone(3000.0, 1.0, 0.1)
        self.assertLess(checks.seam_ratio(dsp.lowpass(loop, 800.0, wrap=True)[:, None]), 1.5)

    def test_a_written_part_lands_on_the_grid_in_its_key(self) -> None:
        notes = grid.Key("D4", "dorian").line("0 4/.5 -/.5 7/2 | 5")
        self.assertEqual(
            [(n.midi, n.start_beat, n.length_beats) for n in notes], [(62, 0, 1), (69, 1, 0.5), (74, 2, 2), (71, 4, 1)]
        )
        self.assertEqual(grid.length_of("0 4/.5 -/.5 7/2 | 5"), 5.0)

    def test_the_minor_battle_key_differs_from_the_hub_by_one_note(self) -> None:
        hub = {grid.Key("D4", "dorian").note(d) for d in range(7)}
        battle = {grid.Key("D4", "minor").note(d) for d in range(7)}
        self.assertEqual((hub - battle, battle - hub), ({71}, {70}))


class CatalogTest(unittest.TestCase):
    def test_every_file_has_one_name_and_a_known_kind(self) -> None:
        assets = catalog.all_assets()
        self.assertEqual(len({asset.name for asset in assets}), len(assets))
        self.assertEqual({asset.kind for asset in assets} - set(checks.BANDS), set())
        for asset in assets:
            low, high = checks.BANDS[asset.kind]
            self.assertTrue(low <= asset.target_lufs <= high, asset.name)
            self.assertEqual(asset.loop, asset.kind in checks.LOOP_KINDS, asset.name)

    def test_the_battle_stems_and_the_riff_share_a_grid(self) -> None:
        from audio import music_battle, music_rock

        self.assertEqual(music_battle.TEMPO, music_rock.TEMPO)
        self.assertEqual(music_battle.BEATS, 2 * music_rock.BEATS)

    def test_a_finished_one_shot_is_at_its_level_and_ends_at_zero(self) -> None:
        asset = catalog.by_name()["ui_button"]
        done = catalog.finish(asset, asset.build())
        self.assertAlmostEqual(loudness.short_peak(done, SR), asset.target_lufs, delta=0.1)
        self.assertEqual(checks.faults(checks.measure(done, SR), asset.kind, False), [])

    def test_the_game_asks_for_exactly_the_files_the_catalogue_renders(self) -> None:
        cues = (REPO / "src" / "audio" / "audio_cues.gd").read_text()
        asked = set(re.findall(r'"((?:music|sfx|ui)/[a-z0-9_]+)"', cues))
        rendered = {asset.path.removesuffix(".wav") for asset in catalog.all_assets()}
        self.assertEqual(asked, rendered)


class ToolTest(unittest.TestCase):
    def test_render_then_analyse_one_file_and_notice_when_it_goes_stale(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            out = Path(tmp)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(render.main(["--out", tmp, "--check"]), 1, "nothing rendered yet")
            self.assertEqual(render.main(["--out", tmp, "--only", "ui_button", "--jobs", "1"]), 0)
            entry = render.manifest.read(out / "MANIFEST.json")["ui/ui_button.wav"]
            self.assertTrue(render.is_current(entry, out / "ui/ui_button.wav", render.source_hash()))
            self.assertFalse(render.is_current(entry, out / "ui/ui_button.wav", "other code"))
            rows, bad = analyze.report(out)
            self.assertEqual((len(rows), bad), (1, 0))
            (out / "ui" / "stray.wav").write_bytes((out / "ui/ui_button.wav").read_bytes())
            self.assertEqual(analyze.report(out)[1], 1, "a WAV the manifest does not list")
            self.assertEqual(render.prune(out, {"ui/ui_button.wav"}), ["ui/stray.wav"])

    def test_a_loop_without_its_closing_frame_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = wavio.write(Path(tmp) / "open.wav", tone(100.0, 4.0), SR, loop=False)
            _, faults = analyze.inspect(path, "music", True)
            self.assertIn("loop_frame", {fault.check for fault in faults})
            self.assertIn("missing", {f.check for f in analyze.inspect(Path(tmp) / "none.wav", "sfx", False)[1]})


if __name__ == "__main__":
    unittest.main()
