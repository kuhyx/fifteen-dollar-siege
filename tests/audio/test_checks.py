"""The offline audio gate must be RED on every fault it names and green on a clean file."""

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

from audio.dsp import SR

from audio import checks, loudness


def tone(hz: float, seconds: float, level: float = 0.2) -> np.ndarray:
    times = np.arange(int(seconds * SR)) / SR
    return level * np.sin(2.0 * np.pi * hz * times)


def faded(signal: np.ndarray) -> np.ndarray:
    ramp = int(0.01 * SR)
    out = signal.copy()
    out[-ramp:] *= np.linspace(1.0, 0.0, ramp)
    return out


def names(signal: np.ndarray, kind: str, loop: bool = False) -> set[str]:
    return {fault.check for fault in checks.faults(checks.measure(signal, SR), kind, loop)}


class FaultsTest(unittest.TestCase):
    def test_a_clean_sfx_passes(self) -> None:
        self.assertEqual(names(faded(tone(440.0, 0.5, 0.25)), "sfx"), set())

    def test_clipping_fails(self) -> None:
        clipped = np.clip(tone(440.0, 0.5, 1.6), -1.0, 1.0)
        self.assertIn("clipping", names(faded(clipped), "sfx"))

    def test_silence_fails(self) -> None:
        self.assertIn("silence", names(np.zeros(SR // 2), "sfx"))

    def test_a_late_start_fails_for_a_one_shot(self) -> None:
        late = np.concatenate((np.zeros(int(0.2 * SR)), faded(tone(440.0, 0.4, 0.25))))
        self.assertIn("late_start", names(late, "sfx"))

    def test_dc_offset_fails(self) -> None:
        self.assertIn("dc_offset", names(faded(tone(440.0, 0.5, 0.2) + 0.05), "sfx"))

    def test_a_one_shot_that_ends_loud_fails(self) -> None:
        self.assertIn("abrupt_end", names(tone(440.0, 0.5, 0.25), "sfx"))

    def test_a_one_shot_that_starts_mid_wave_fails(self) -> None:
        started = faded(np.cos(2.0 * np.pi * 440.0 * np.arange(SR // 2) / SR) * 0.25)
        self.assertIn("abrupt_start", names(started, "sfx"))

    def test_a_shrill_sfx_fails(self) -> None:
        self.assertIn("shrill", names(faded(tone(9000.0, 0.5, 0.25)), "sfx"))

    def test_loudness_outside_the_band_fails(self) -> None:
        self.assertIn("loudness", names(faded(tone(440.0, 0.5, 0.004)), "sfx"))
        self.assertIn("loudness", names(faded(tone(440.0, 0.5, 0.85)), "sfx"))

    def test_a_loop_cut_mid_wave_fails_at_the_seam(self) -> None:
        whole = tone(100.0, 4.0, 0.2)
        cut = tone(100.0, 4.0025, 0.2)
        self.assertNotIn("loop_seam", names(whole, "music", loop=True))
        self.assertIn("loop_seam", names(cut, "music", loop=True))

    def test_a_loop_may_end_loud_and_start_at_once(self) -> None:
        found = names(tone(100.0, 4.0, 0.2), "music", loop=True)
        self.assertNotIn("abrupt_end", found)
        self.assertNotIn("late_start", found)

    def test_a_low_sample_rate_fails(self) -> None:
        low = checks.measure(faded(tone(440.0, 0.5, 0.25))[::2], SR // 2)
        self.assertIn("sample_rate", {fault.check for fault in checks.faults(low, "sfx", False)})

    def test_stereo_is_measured_per_channel(self) -> None:
        left = faded(tone(440.0, 0.5, 0.25))
        stereo = np.stack((left, np.zeros_like(left) + 0.05), axis=1)
        self.assertIn("dc_offset", names(stereo, "sfx"))


class LoudnessTest(unittest.TestCase):
    def test_a_997_hz_sine_reads_its_known_loudness(self) -> None:
        # BS.1770: a 0 dBFS 997 Hz sine in one channel reads -3.01 LKFS.
        self.assertAlmostEqual(loudness.integrated(tone(997.0, 5.0, 1.0), SR), -3.01, delta=0.15)

    def test_half_the_amplitude_is_six_decibels_down(self) -> None:
        loud = loudness.integrated(tone(997.0, 5.0, 0.5), SR)
        quiet = loudness.integrated(tone(997.0, 5.0, 0.25), SR)
        self.assertAlmostEqual(loud - quiet, 6.02, delta=0.05)

    def test_gating_ignores_a_silent_tail(self) -> None:
        body = tone(997.0, 4.0, 0.25)
        tailed = np.concatenate((body, np.zeros(4 * SR)))
        self.assertAlmostEqual(loudness.integrated(tailed, SR), loudness.integrated(body, SR), delta=0.3)

    def test_the_short_window_peak_finds_the_burst(self) -> None:
        burst = np.concatenate((np.zeros(SR), tone(997.0, 0.2, 0.25), np.zeros(SR)))
        self.assertAlmostEqual(
            loudness.short_peak(burst, SR), loudness.integrated(tone(997.0, 4.0, 0.25), SR), delta=0.5
        )


if __name__ == "__main__":
    unittest.main()
