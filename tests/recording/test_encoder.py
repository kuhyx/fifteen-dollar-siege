"""The ffmpeg command line: encoder choice, window capture, exact timestamps."""

import subprocess
import unittest
from itertools import pairwise
from unittest import mock

from helpers import ROOT  # noqa: F401
from recording import encoder

SPEC = encoder.Spec(window_id=0x4200007, fps=60, t0_unix=1_800_000_000.5, out="/o/s.mkv", audio="default")


class EncoderTest(unittest.TestCase):
    def test_nvenc_is_preferred_when_it_works(self) -> None:
        self.assertEqual(encoder.pick({"h264_nvenc", "libx264"}), "h264_nvenc")

    def test_falls_back_to_x264(self) -> None:
        self.assertEqual(encoder.pick({"libx264"}), "libx264")

    def test_nothing_usable_is_an_error(self) -> None:
        with self.assertRaises(encoder.NoEncoder):
            encoder.pick({"mpeg4"})

    def test_probe_lists_only_the_encoders_that_encode_a_frame(self) -> None:
        def run(cmd: list[str], **_: object) -> subprocess.CompletedProcess[bytes]:
            return subprocess.CompletedProcess(cmd, 0 if "libx264" in cmd else 1)

        with mock.patch.object(encoder.subprocess, "run", side_effect=run) as fake:
            self.assertEqual(encoder.probe_usable(), {"libx264"})
        self.assertEqual(fake.call_count, 2)

    def test_nvenc_is_quality_first(self) -> None:
        cmd = encoder.command(SPEC, "h264_nvenc")
        for pair in (("-preset", "p7"), ("-rc", "vbr"), ("-cq", "17"), ("-b:v", "0")):
            self.assertIn(pair, list(pairwise(cmd)), pair)

    def test_4k_windows_use_a_faster_nvenc_preset_to_stay_real_time(self) -> None:
        big = encoder.Spec(**{**SPEC.__dict__, "width": 3840, "height": 2160})
        cmd = encoder.command(big, "h264_nvenc")
        self.assertIn(("-preset", "p4"), list(pairwise(cmd)))
        qhd = encoder.Spec(**{**SPEC.__dict__, "width": 2560, "height": 1440})
        self.assertIn(("-preset", "p7"), list(pairwise(encoder.command(qhd, "h264_nvenc"))))

    def test_x264_fallback_settings(self) -> None:
        cmd = encoder.command(SPEC, "libx264")
        self.assertIn(("-crf", "16"), list(pairwise(cmd)))
        self.assertIn(("-preset", "veryfast"), list(pairwise(cmd)))

    def test_captures_the_window_by_id_at_the_fps(self) -> None:
        cmd = encoder.command(SPEC, "h264_nvenc")
        self.assertIn(("-window_id", "0x4200007"), list(pairwise(cmd)))
        self.assertIn(("-framerate", "60"), list(pairwise(cmd)))
        self.assertIn("x11grab", cmd)

    def test_output_is_mkv_and_sits_on_the_launcher_clock(self) -> None:
        cmd = encoder.command(SPEC, "h264_nvenc")
        self.assertIn("-copyts", cmd)
        self.assertIn(("-output_ts_offset", "-1800000000.500000"), list(pairwise(cmd)))
        self.assertEqual(cmd[-1], "/o/s.mkv")
        self.assertIn(("-f", "matroska"), list(pairwise(cmd)))

    def test_video_stamps_are_shifted_back_by_the_grab_latency(self) -> None:
        cmd = encoder.command(SPEC, "h264_nvenc")
        pairs = list(pairwise(cmd))
        self.assertIn(("-itsoffset", "-0.025000"), pairs)  # 1.5 frames at 60 fps
        self.assertLess(cmd.index("-itsoffset"), cmd.index("x11grab"), "an input option of the video input")

    def test_ffmpeg_ends_when_the_window_capture_dies(self) -> None:
        self.assertIn("-shortest", encoder.command(SPEC, "h264_nvenc"))

    def test_audio_is_recorded_not_muted(self) -> None:
        cmd = encoder.command(SPEC, "h264_nvenc")
        self.assertIn("pulse", cmd)
        self.assertIn(("-c:a", "flac"), list(pairwise(cmd)))

    def test_pulse_source_is_the_given_monitor(self) -> None:
        spec = encoder.Spec(**{**SPEC.__dict__, "audio": "sink.monitor"})
        cmd = encoder.command(spec, "h264_nvenc")
        self.assertIn(("-i", "sink.monitor"), list(pairwise(cmd)))

    def test_silent_test_source_rides_the_wall_clock(self) -> None:
        spec = encoder.Spec(**{**SPEC.__dict__, "audio": "lavfi"})
        cmd = encoder.command(spec, "h264_nvenc")
        self.assertIn("lavfi", cmd)
        self.assertTrue(any("RTCTIME" in part for part in cmd))

    def test_odd_window_sizes_are_cropped_to_even(self) -> None:
        odd = encoder.Spec(**{**SPEC.__dict__, "width": 1281, "height": 800})
        self.assertIn("-vf", encoder.command(odd, "h264_nvenc"))
        even = encoder.Spec(**{**SPEC.__dict__, "width": 1280, "height": 800})
        self.assertNotIn("-vf", encoder.command(even, "h264_nvenc"))

    def test_no_resize_scaler_in_the_path(self) -> None:
        self.assertNotIn("-vf", encoder.command(SPEC, "h264_nvenc"))


if __name__ == "__main__":
    unittest.main()
