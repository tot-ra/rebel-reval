#!/usr/bin/env python3
"""Tests for generated asset inventory classification policy."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_asset_inventory as inventory  # noqa: E402


class AssetInventoryPolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        inventory.source_approvals_by_path.cache_clear()

    def tearDown(self) -> None:
        inventory.source_approvals_by_path.cache_clear()

    def test_approved_visual_source_is_classified_as_approved(self) -> None:
        with mock.patch.object(
            inventory,
            "source_approvals_by_path",
            return_value={"assets/test/visual.png": "approved - test fixture"},
        ):
            classification, reason = inventory.classify(Path("assets/test/visual.png"))

        self.assertEqual(classification, "approved")
        self.assertIn("assets/SOURCES.csv", reason)

    def test_unapproved_visual_source_remains_prototype(self) -> None:
        with mock.patch.object(inventory, "source_approvals_by_path", return_value={}):
            classification, _reason = inventory.classify(Path("assets/test/visual.png"))

        self.assertEqual(classification, "prototype")


if __name__ == "__main__":
    unittest.main()
