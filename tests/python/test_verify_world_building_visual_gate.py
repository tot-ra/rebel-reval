"""Tests for the R-716 world-building visual benchmark gate."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_world_building_visual_gate import (  # noqa: E402
    REQUIRED_CAPTURE_CATEGORIES,
    REQUIRED_RUBRIC_CRITERIA,
    verify_manifest,
)


class WorldBuildingVisualGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(
            (ROOT / "docs/data/world_building_visual_benchmark.json").read_text(encoding="utf-8")
        )

    def test_checked_in_manifest_is_fail_closed_and_covers_registry(self) -> None:
        result = verify_manifest(ROOT, self.manifest)
        self.assertFalse(result.valid)
        self.assertEqual(result.expected_map_ids, result.manifest_map_ids)
        self.assertTrue(any("not accepted: pending" in error for error in result.errors))
        self.assertTrue(any("performance evidence minimum is not accepted: pending" in error for error in result.errors))
        self.assertTrue(any("comparison_sheet requires an ISO-8601 generated_utc timestamp" in error for error in result.errors))

    def test_performance_evidence_requires_both_tiers_and_host_identity(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        del manifest["performance_evidence"]["minimum"]["measurement_host"]
        result = verify_manifest(ROOT, manifest)
        self.assertFalse(result.valid)
        self.assertTrue(any("performance evidence minimum requires measurement_host identity" in error for error in result.errors))

    def test_comparison_sheet_requires_revision_and_timestamp(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["comparison_sheet"] = {
            "status": "pass",
            "evidence": "docs/WORLD_BUILDING_VISUAL_GATE.md",
            "revision": "",
            "generated_utc": "not-a-timestamp",
        }
        result = verify_manifest(ROOT, manifest)
        self.assertFalse(result.valid)
        self.assertTrue(any("revision must be a non-empty version identifier" in error for error in result.errors))
        self.assertTrue(any("generated_utc must be an ISO-8601 timestamp" in error for error in result.errors))
        manifest = copy.deepcopy(self.manifest)
        manifest["maps"] = manifest["maps"][1:]
        result = verify_manifest(ROOT, manifest)
        self.assertFalse(result.valid)
        self.assertTrue(any("missing active/candidate map IDs" in error for error in result.errors))

    def test_capture_and_rubric_contract_is_explicit(self) -> None:
        for entry in self.manifest["maps"]:
            self.assertEqual(list(entry["captures"]), list(REQUIRED_CAPTURE_CATEGORIES))
            self.assertEqual(list(entry["rubric_reviews"]), list(REQUIRED_RUBRIC_CRITERIA))

    def test_complete_fixture_passes_with_real_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for relative in (
                "content/transitions/active_destinations.json",
                "docs/data/location_activation_manifest.json",
                "docs/data/p6_002_activation_manifest.json",
            ):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            for entry in self.manifest["maps"]:
                source = root / entry["source_path"]
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text("fixture\n", encoding="utf-8")
            evidence = root / "evidence.txt"
            evidence.write_text("accepted\n", encoding="utf-8")

            manifest = copy.deepcopy(self.manifest)
            manifest["comparison_sheet"] = {
                "status": "pass",
                "evidence": "evidence.txt",
                "revision": "r716-comparison-v1",
                "generated_utc": "2026-08-25T12:00:00Z",
            }
            for check in manifest["automated_checks"].values():
                check["status"] = "pass"
                check["evidence"] = "evidence.txt"
            for performance in manifest["performance_evidence"].values():
                performance["status"] = "pass"
                performance["evidence"] = "evidence.txt"
            for entry in manifest["maps"]:
                for capture in entry["captures"].values():
                    capture["status"] = "pass"
                    capture["evidence"] = "evidence.txt"
                for review in entry["rubric_reviews"].values():
                    review["status"] = "pass"
                    review["evidence"] = "evidence.txt"
                entry["human_review"] = {
                    "status": "approved",
                    "reviewer": "Maintainer",
                    "review_date": "2026-08-25",
                    "evidence": "evidence.txt",
                }

            result = verify_manifest(root, manifest)
            self.assertTrue(result.valid, result.errors)

    def test_absolute_evidence_path_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["comparison_sheet"] = {"status": "pass", "evidence": "/tmp/comparison.png"}
        result = verify_manifest(ROOT, manifest)
        self.assertFalse(result.valid)
        self.assertTrue(any("repository-relative" in error for error in result.errors))


if __name__ == "__main__":
    unittest.main()
