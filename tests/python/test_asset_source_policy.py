#!/usr/bin/env python3
"""Tests for the asset provenance approval policy."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import validate_asset_sources as validator  # noqa: E402


class AssetSourcePolicyTest(unittest.TestCase):
    def test_repository_asset_sources_pass(self) -> None:
        self.assertEqual(validator.validate(), [])

    def test_estonia_world_map_records_embedded_c2pa_provenance(self) -> None:
        row = next(
            source
            for source in validator.read_sources()
            if source["path"] == "assets/UI/estonia_world_map.png"
        )
        self.assertTrue(row["approval"].startswith("approved"))
        self.assertIn("OpenAI API", row["creator_or_tool"])
        self.assertIn("GPT-4o", row["model_version"])
        self.assertIn("C2PA", row["prompt_or_url"])

    def test_approved_asset_rejects_placeholder_provenance(self) -> None:
        row = {
            "asset_id": "assets.test.approved",
            "path": "assets/test/approved.png",
            "creator_or_tool": "unknown",
            "model_version": "1.0",
            "prompt_or_url": "https://example.invalid/source",
            "seed": "not applicable",
            "license": "CC0-1.0",
            "edits": "none",
            "approval": "approved - test fixture",
        }
        with (
            mock.patch.object(validator, "read_sources", return_value=[row]),
            mock.patch.object(validator, "inventory_paths", return_value=set()),
            mock.patch.object(validator, "active_runtime_paths", return_value=set()),
            mock.patch.object(validator, "_asset_file_exists", return_value=True),
        ):
            errors = validator.validate()

        self.assertEqual(
            errors,
            [
                "line 2: approved asset 'assets/test/approved.png' "
                "has placeholder creator_or_tool: 'unknown'"
            ],
        )


if __name__ == "__main__":
    unittest.main()
