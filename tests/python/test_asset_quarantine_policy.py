#!/usr/bin/env python3
"""Tests for the asset quarantine approval policy."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import quarantine_assets as quarantine  # noqa: E402


class AssetQuarantinePolicyTest(unittest.TestCase):
    def test_repository_has_no_active_unapproved_visual_exceptions(self) -> None:
        rows = quarantine.read_sources()
        refs = quarantine.referenced_runtime_paths()
        paths = quarantine.candidate_paths(rows)

        self.assertEqual(paths & refs, set())
        self.assertEqual(quarantine.check_quarantine(paths, refs), [])

    def test_referenced_unapproved_asset_remains_a_quarantine_candidate(self) -> None:
        rows = [
            {
                "path": "assets/test/referenced.png",
                "approval": "not approved - prototype pending provenance/style review",
            }
        ]

        self.assertEqual(
            quarantine.candidate_paths(rows),
            {"assets/test/referenced.png"},
        )

    def test_check_rejects_runtime_reference_to_quarantined_asset(self) -> None:
        path = "assets/test/referenced.png"
        with mock.patch.object(quarantine, "QUARANTINE_GDIGNORE", Path(__file__)):
            errors = quarantine.check_quarantine({path}, {path})

        self.assertTrue(any("runtime files reference quarantined paths" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
