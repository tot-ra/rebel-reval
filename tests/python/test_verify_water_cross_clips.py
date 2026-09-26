from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "tools" / "verify_water_cross_clips.py"
WATER_DIR = ROOT / "sounds" / "water"


class VerifyWaterCrossClipsTests(unittest.TestCase):
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
        self.assertIn("water crossing audio verification passed", result.stdout)

    def test_invalid_clip_is_reported_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            water_dir = Path(temp_dir)
            shutil.copy2(WATER_DIR / "submerge.mp3", water_dir / "submerge.mp3")
            shutil.copy2(
                WATER_DIR / "submerge.mp3.import",
                water_dir / "submerge.mp3.import",
            )
            shutil.copy2(WATER_DIR / "emerge.mp3", water_dir / "emerge.mp3")
            shutil.copy2(
                WATER_DIR / "emerge.mp3.import",
                water_dir / "emerge.mp3.import",
            )
            (water_dir / "broken.mp3").write_bytes(b"not an audio file")
            (water_dir / "broken.mp3.import").write_text("", encoding="utf-8")
            (water_dir / "manifest.csv").write_text(
                "clip_id,title,author,license,page,file,notes\n"
                "water.submerge,Harbour submerge splash,project maintainer,"
                "AGPL-3.0-or-later (project author),"
                "tools/audio/generate_water_cross_clips.py,submerge.mp3,ok\n"
                "water.emerge,Harbour emerge splash,project maintainer,"
                "AGPL-3.0-or-later (project author),"
                "tools/audio/generate_water_cross_clips.py,emerge.mp3,ok\n"
                "water.broken,Broken clip,test,CC0,test,broken.mp3,invalid\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["python3", str(VERIFY), "--water-dir", str(water_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ERROR: could not probe broken.mp3 duration:", result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_malformed_manifest_rows_are_reported_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            water_dir = Path(temp_dir)
            shutil.copy2(WATER_DIR / "submerge.mp3", water_dir / "submerge.mp3")
            shutil.copy2(
                WATER_DIR / "submerge.mp3.import",
                water_dir / "submerge.mp3.import",
            )
            (water_dir / "manifest.csv").write_text(
                "clip_id,title,author,license,page,file,notes\n"
                "water.missing,,project maintainer,AGPL,page,,notes\n"
                "water.omitted\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["python3", str(VERIFY), "--water-dir", str(water_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing file field", result.stdout)
        self.assertIn("water.missing", result.stdout)
        self.assertIn("water.omitted", result.stdout)
        self.assertIn("manifest missing clip_id(s)", result.stdout)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
