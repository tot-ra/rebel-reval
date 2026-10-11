"""Tests for slice branch consequence manifest verification (P3-005)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from slice_branch_consequences import verify_manifest_matches_model  # noqa: E402

MANIFEST = ROOT / "docs/data/slice_branch_consequence_manifest.json"


class TestReportSliceBranchConsequences(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(len(report.choice_groups), 4)
        self.assertEqual(report.choice_count, 12)

    def test_manifest_lists_expected_groups(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertIn("makers_mark.ledger", report.choice_groups)
        self.assertIn("reflection.conviction", report.choice_groups)


if __name__ == "__main__":
    unittest.main()
