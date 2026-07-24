from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "tools" / "verify_weather_audio_clips.py"


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


if __name__ == "__main__":
    unittest.main()
