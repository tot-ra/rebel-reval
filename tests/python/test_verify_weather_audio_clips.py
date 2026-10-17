from __future__ import annotations

import csv
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "tools" / "verify_weather_audio_clips.py"
WEATHER_DIR = ROOT / "sounds" / "weather"


class VerifyWeatherAudioClipsTests(unittest.TestCase):
    def test_verify_passes_on_current_manifest(self) -> None:
        result = subprocess.run(
            ["python3", str(VERIFY)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(
            result.returncode,
            0,
            msg=result.stdout + result.stderr,
        )
        self.assertIn("weather audio verification passed", result.stdout)

    def test_manifest_credits_both_weather_field_recordings(self) -> None:
        with (WEATHER_DIR / "manifest.csv").open(encoding="utf-8", newline="") as handle:
            rows = {row["clip_id"]: row for row in csv.DictReader(handle)}

        self.assertEqual(set(rows), {"weather.rain_outdoor", "weather.rain_roof"})
        self.assertEqual(rows["weather.rain_outdoor"]["author"], "Andron827")
        self.assertIn("publicdomain/zero/1.0", rows["weather.rain_outdoor"]["license"])
        self.assertIn("/142936/", rows["weather.rain_outdoor"]["page"])
        self.assertEqual(rows["weather.rain_roof"]["author"], "marsal.oido")
        self.assertIn("licenses/by/4.0", rows["weather.rain_roof"]["license"])
        self.assertIn("/415848/", rows["weather.rain_roof"]["page"])
        for row in rows.values():
            self.assertIn("48 s field-recording loop", row["notes"])
            self.assertIn("equal-power loop seam", row["notes"])

    def test_invalid_clip_is_reported_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            weather_dir = Path(temp_dir)
            shutil.copy2(WEATHER_DIR / "rain_roof.mp3", weather_dir / "valid.mp3")
            shutil.copy2(
                WEATHER_DIR / "rain_roof.mp3.import",
                weather_dir / "valid.mp3.import",
            )
            (weather_dir / "broken.mp3").write_bytes(b"not an audio file")
            (weather_dir / "broken.mp3.import").write_text("", encoding="utf-8")
            (weather_dir / "manifest.csv").write_text(
                "clip_id,file,license,source,notes\n"
                "weather.broken,broken.mp3,CC0,test,invalid fixture\n"
                "weather.valid,valid.mp3,CC0,test,valid fixture\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["python3", str(VERIFY), "--weather-dir", str(weather_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ERROR: could not probe broken.mp3 duration:", result.stdout)
        self.assertIn("weather audio verification failed with 1 error(s)", result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_malformed_manifest_rows_are_reported_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            weather_dir = Path(temp_dir)
            shutil.copy2(WEATHER_DIR / "rain_roof.mp3", weather_dir / "valid.mp3")
            shutil.copy2(
                WEATHER_DIR / "rain_roof.mp3.import",
                weather_dir / "valid.mp3.import",
            )
            (weather_dir / "manifest.csv").write_text(
                "clip_id,file,license,source,notes\n"
                "weather.missing,,CC0,test,missing file\n"
                "weather.omitted\n"
                "weather.valid,valid.mp3,CC0,test,valid fixture\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["python3", str(VERIFY), "--weather-dir", str(weather_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count("missing file field"), 2)
        self.assertIn("weather.missing", result.stdout)
        self.assertIn("weather.omitted", result.stdout)
        self.assertIn("weather audio verification failed with 2 error(s)", result.stdout)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
