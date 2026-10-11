#!/usr/bin/env python3
"""Regression tests for the tourist landmarks document generator."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_tourist_landmarks as generator  # noqa: E402


class GenerateTouristLandmarksTest(unittest.TestCase):
    def test_render_matches_checked_in_catalog(self) -> None:
        expected = generator.OUT.read_text(encoding="utf-8")
        self.assertEqual(generator.render(), expected)

    def test_check_mode_passes_when_catalog_is_current(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOLS / "generate_tourist_landmarks.py"), "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr or result.stdout)
        self.assertIn("up to date", result.stdout)


if __name__ == "__main__":
    unittest.main()
