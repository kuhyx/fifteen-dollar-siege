"""The whole catalogue rendered once, in this process, then read back by the offline gate."""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from typing import ClassVar
from unittest import mock

from helpers import InProcessPool, run_render

from audio import analyze, catalog, render


class FullRenderTest(unittest.TestCase):
    tmp: ClassVar[tempfile.TemporaryDirectory[str]]
    out: ClassVar[Path]
    first: ClassVar[tuple[int, str, str]]

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        pool = mock.patch.object(render, "ProcessPoolExecutor", InProcessPool)
        pool.start()
        cls.addClassCleanup(pool.stop)
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.first = run_render("--out", str(cls.out), "--jobs", "1")

    def test_every_file_of_the_catalogue_is_rendered(self) -> None:
        code, text, _ = self.first
        self.assertEqual(code, 0)
        for asset in catalog.all_assets():
            self.assertTrue((self.out / asset.path).is_file(), asset.path)
            self.assertTrue((self.out / f"{asset.path}.import").is_file(), asset.path)
        self.assertIn(f"audio: {len(catalog.all_assets())} rendered, 0 current", text)

    def test_the_offline_gate_passes_every_rendered_file(self) -> None:
        rows, bad = analyze.report(self.out)
        self.assertEqual((len(rows), bad), (len(catalog.all_assets()), 0))

    def test_a_second_run_renders_nothing(self) -> None:
        code, text, _ = run_render("--out", str(self.out))
        self.assertEqual(code, 0)
        self.assertIn("0 rendered", text)
        self.assertEqual(run_render("--out", str(self.out), "--check")[0], 0)

    def test_the_analyzer_cli_prints_a_row_per_file_and_the_summary(self) -> None:
        json_out = self.out / "rows" / "report.json"
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            self.assertEqual(analyze.main([str(self.out), "--json", str(json_out)]), 0)
        self.assertIn("ui/ui_button.wav", out.getvalue())
        self.assertIn("worst loop seam", out.getvalue())
        self.assertIn(
            f"audio analysis: {len(catalog.all_assets())} of {len(catalog.all_assets())} files clean", out.getvalue()
        )
        self.assertEqual(len(json.loads(json_out.read_text())), len(catalog.all_assets()))
        json_out.unlink()
        json_out.parent.rmdir()

    def test_the_list_names_every_file(self) -> None:
        code, text, _ = run_render("--list")
        self.assertEqual(code, 0)
        self.assertEqual(len(text.splitlines()), len(catalog.all_assets()))


if __name__ == "__main__":
    unittest.main()
