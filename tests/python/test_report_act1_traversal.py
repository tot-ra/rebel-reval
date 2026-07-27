"""Tests for Act 1 traversal manifest verification (P4-011)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from act1_traversal import verify_manifest_matches_model  # noqa: E402

MANIFEST = ROOT / "docs/data/act1_traversal_manifest.json"


class TestReportAct1Traversal(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(len(report.intended_endings), 3)
        self.assertEqual(len(report.invalid_transition_ids), 5)
        self.assertEqual(len(report.cycle_test_filters), 6)

    def test_manifest_lists_expected_invalid_ids(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertIn("invalid.climax.before_approach", report.invalid_transition_ids)
        self.assertIn("invalid.climax.terminal_recommit", report.invalid_transition_ids)
        self.assertIn("invalid.act1.record_without_flag", report.invalid_transition_ids)


if __name__ == "__main__":
    unittest.main()
