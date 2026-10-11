"""Tests for slice information design manifest verification (P3-008)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from slice_information_design import verify_manifest_matches_model  # noqa: E402

MANIFEST = ROOT / "docs/data/slice_information_design_manifest.json"


class TestReportSliceInformationDesign(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(report.beat_count, 23)
        self.assertEqual(report.historical_concept_count, 6)

    def test_maintainer_report_exists(self) -> None:
        report_path = ROOT / "docs/reports/p3_008_information_design.md"
        self.assertTrue(report_path.is_file(), "maintainer report must exist")


if __name__ == "__main__":
    unittest.main()
