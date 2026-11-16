"""The rarely taken branches of the audio tools: bad input, empty input, flat input."""

import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

import numpy as np
from helpers import InProcessPool

from audio import catalog, checks, dsp, loudness, music_hub, wavio

SR = dsp.SR


class DspEdgeTest(unittest.TestCase):
    def test_an_unknown_filter_is_refused(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown filter 'notch'"):
            dsp.response("notch", 1000.0, 0.7, 64)

    def test_a_flat_sweep_is_a_plain_band_pass(self) -> None:
        noise = np.random.default_rng(1).normal(size=2000)
        flat = dsp.sweep_bandpass(noise, np.full(2000, 800.0))
        np.testing.assert_allclose(flat, dsp.bandpass(noise, 800.0, 2.0))

    def test_a_fade_of_no_length_leaves_the_signal_alone(self) -> None:
        signal = np.ones(100)
        np.testing.assert_array_equal(dsp.fade_out(signal, 0.0), signal)

    def test_placing_into_nothing_or_out_of_range_changes_nothing(self) -> None:
        empty = np.zeros(0)
        dsp.place(empty, 0, np.ones(3))
        self.assertEqual(len(empty), 0)
        total = np.zeros(10)
        dsp.place(total, 3, np.zeros(0))
        dsp.place(total, 12, np.ones(3))
        dsp.place(total, -2, np.ones(3))
        self.assertEqual(float(total.sum()), 0.0)


class MeasureEdgeTest(unittest.TestCase):
    def test_a_file_too_short_to_have_a_seam_has_none(self) -> None:
        self.assertEqual(checks.seam_ratio(np.ones((4, 2))), 0.0)

    def test_an_unknown_kind_is_a_fault_and_stops_the_other_checks(self) -> None:
        found = checks.measure(np.zeros(SR // 2), SR)
        self.assertEqual([fault.check for fault in checks.faults(found, "podcast", False)], ["kind"])

    def test_one_frame_is_weighed_without_filtering(self) -> None:
        weighed = loudness.k_weighted(np.array([0.5]), SR)
        np.testing.assert_array_equal(weighed, [[0.5]])

    def test_silence_has_no_sound_to_trim_when_finishing_a_one_shot(self) -> None:
        done = catalog._one_shot(np.zeros(SR // 10))
        self.assertEqual((len(done), float(np.max(np.abs(done)))), (SR // 10, 0.0))


class FileEdgeTest(unittest.TestCase):
    def test_a_wav_that_is_not_16_bit_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "eight.wav"
            with wave.open(str(path), "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(1)
                handle.setframerate(SR)
                handle.writeframes(bytes(100))
            with self.assertRaisesRegex(ValueError, "is not 16-bit PCM"):
                wavio.read(path)


class HubEdgeTest(unittest.TestCase):
    def test_a_hub_section_that_does_not_add_up_is_refused(self) -> None:
        short = (("0 1 2", (1,), "......", False),)
        with (
            mock.patch.object(music_hub, "SECTIONS", short),
            self.assertRaisesRegex(ValueError, r"hub section 0 is 3\.0 beats, not 24\.0"),
        ):
            music_hub.render()

    def test_the_pool_double_hands_back_a_finished_job(self) -> None:
        with InProcessPool(2) as pool:
            self.assertEqual(pool.submit(max, 3, 9).result(), 9)


if __name__ == "__main__":
    unittest.main()
