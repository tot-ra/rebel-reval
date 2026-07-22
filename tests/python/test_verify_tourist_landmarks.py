#!/usr/bin/env python3
"""Tests for tools/verify_tourist_landmarks.py."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_tourist_landmarks as verifier  # noqa: E402


class VerifyTouristLandmarksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.landmarks = verifier.LANDMARKS.read_text(encoding="utf-8")
        cls.canon = verifier.CANON.read_text(encoding="utf-8")

    def validate(self, *, landmarks: str | None = None, canon: str | None = None) -> list[str]:
        return verifier.validate(
            landmarks_text=landmarks if landmarks is not None else self.landmarks,
            canon_text=canon if canon is not None else self.canon,
        )

    def test_repository_catalog_passes_contract(self) -> None:
        self.assertEqual(self.validate(), [])

    def test_missing_1343_status_rows_are_rejected(self) -> None:
        stripped = self.landmarks.replace("* **1343 Status:**", "* **Status:**")
        errors = self.validate(landmarks=stripped)
        self.assertTrue(any("1343 status" in error for error in errors))

    def test_missing_canon_backlink_is_rejected(self) -> None:
        errors = self.validate(canon=self.canon.replace("TOURIST_LANDMARKS", "MISSING_LINK"))
        self.assertTrue(any("CANON.md must link back" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
