"""render.py and analyze.py as programs: arguments, exit codes, the faults they print."""

import contextlib
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from typing import ClassVar
from unittest import mock

from helpers import InProcessPool, run_render

from audio import analyze, render

TOOLS = Path(__file__).resolve().parents[2] / "tools" / "audio"


def run_analyze(*argv: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = analyze.main(list(argv))
    return code, out.getvalue(), err.getvalue()


class RenderCliTest(unittest.TestCase):
    def test_the_output_folder_is_required(self) -> None:
        with self.assertRaises(SystemExit) as raised:
            run_render()
        self.assertEqual(raised.exception.code, 2)

    def test_an_unknown_name_is_refused_with_the_hint(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(SystemExit) as raised:
            run_render("--out", tmp, "--only", "nope")
        self.assertEqual(raised.exception.code, 2)

    def test_the_script_runs_as_a_program(self) -> None:
        out = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["render.py", "--list"]),
            contextlib.redirect_stdout(out),
            self.assertRaises(SystemExit) as raised,
        ):
            runpy.run_path(str(TOOLS / "render.py"), run_name="__main__")
        self.assertEqual(raised.exception.code, 0)
        self.assertIn("ui/ui_button.wav", out.getvalue())


class OneFileTest(unittest.TestCase):
    """One cheap effect rendered, then read back, broken and read again."""

    tmp: ClassVar[tempfile.TemporaryDirectory[str]]
    out: ClassVar[Path]

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.out = Path(cls.tmp.name)
        with mock.patch.object(render, "ProcessPoolExecutor", InProcessPool):
            run_render("--out", str(cls.out), "--only", "ui_button")

    def test_a_clean_folder_passes_quietly_without_a_json_file(self) -> None:
        code, out, err = run_analyze(str(self.out), "--quiet")
        self.assertEqual((code, err), (0, ""))
        self.assertNotIn("peak", out)
        self.assertNotIn("worst loop seam", out)
        self.assertIn("audio analysis: 1 of 1 files clean", out)

    def test_a_folder_without_a_manifest_is_a_fault(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, _, err = run_analyze(tmp)
        self.assertEqual(code, 1)
        self.assertIn("FAULT MANIFEST.json: missing", err)

    def test_a_listed_file_that_is_gone_is_a_fault_and_prints_no_numbers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            manifest = json.loads((self.out / "MANIFEST.json").read_text())
            (folder / "MANIFEST.json").write_text(json.dumps(manifest))
            code, out, err = run_analyze(tmp)
        self.assertEqual(code, 1)
        self.assertIn("FAULT ui/ui_button.wav: missing: not on disk", err)
        self.assertNotIn("peak", out)

    def test_the_script_runs_as_a_program(self) -> None:
        out = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["analyze.py", str(self.out), "--quiet"]),
            contextlib.redirect_stdout(out),
            self.assertRaises(SystemExit) as raised,
        ):
            runpy.run_path(str(TOOLS / "analyze.py"), run_name="__main__")
        self.assertEqual(raised.exception.code, 0)

    def test_a_stray_wav_is_pruned_by_the_next_render(self) -> None:
        stray = self.out / "ui" / "stray.wav"
        stray.write_bytes((self.out / "ui" / "ui_button.wav").read_bytes())
        with mock.patch.object(render, "ProcessPoolExecutor", InProcessPool):
            code, text, _ = run_render("--out", str(self.out), "--only", "ui_button")
        self.assertEqual(code, 0)
        self.assertIn("removed ui/stray.wav", text)
        self.assertFalse(stray.exists())


if __name__ == "__main__":
    unittest.main()
