"""Tests for slice traversal manifest verification (P3-001)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from slice_traversal import verify_manifest_matches_model  # noqa: E402

MANIFEST = ROOT / "docs/data/slice_traversal_manifest.json"


class TestReportSliceTraversal(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(len(report.intended_endings), 3)
        self.assertEqual(len(report.invalid_transition_ids), 9)

    def test_manifest_lists_expected_invalid_ids(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertIn("invalid.night.honest_bypass", report.invalid_transition_ids)
        self.assertIn("invalid.encounter.unknown_kind", report.invalid_transition_ids)


if __name__ == "__main__":
    unittest.main()
