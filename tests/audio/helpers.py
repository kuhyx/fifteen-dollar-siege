"""Shared pieces of the audio tests: the tools on the path, a pool that stays in this process."""

import contextlib
import io
import sys
from collections.abc import Callable
from concurrent.futures import Future
from pathlib import Path
from typing import Self

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

from audio import render


class InProcessPool:
    """Runs each job at once in this process, so the code under test is measured."""

    def __init__(self, max_workers: int) -> None:
        self.max_workers = max_workers

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def submit(self, fn: Callable[..., object], *args: object) -> Future:
        done: Future = Future()
        done.set_result(fn(*args))
        return done


def run_render(*argv: str) -> tuple[int, str, str]:
    """render.main(argv) with its exit code, stdout and stderr."""
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = render.main(list(argv))
    return code, out.getvalue(), err.getvalue()
