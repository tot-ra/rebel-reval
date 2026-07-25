"""Tests for slice platform manifest verification (P3-012)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from slice_platform import verify_manifest_matches_model  # noqa: E402

MANIFEST = ROOT / "docs/data/slice_platform_manifest.json"


class TestReportSlicePlatform(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(report.supported_platform_count, 1)


if __name__ == "__main__":
    unittest.main()
