#!/usr/bin/env python3
"""Verify the P6-001 Act 3 design contract and canon boundary."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs" / "data" / "act3_design_manifest.json"
REPORT_PATH = ROOT / "docs" / "reports" / "p6_001_act3_design.md"
CANON_PATH = ROOT / "docs" / "CANON.md"
ENDING_MANIFEST_PATH = ROOT / "docs" / "data" / "act3_ending_manifest.json"

ALLOWED_CONFIDENCE = {"attested", "plausible composite", "folklore", "invented"}
REQUIRED_LOCATIONS = {
    "world_padise",
    "world_paide",
    "world_saaremaa",
    "world_poide",
    "loc.maasilinna_castle",
}
REQUIRED_TASKS = {"P5-009", "P6-001", "P6-002", "P6-003", "P6-004", "P6-005", "P6-006", "P6-007", "P6-009"}
REQUIRED_ENDING_DIMENSIONS = {"kalev", "forge", "people", "land"}


class TestAct3DesignManifest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.report = REPORT_PATH.read_text(encoding="utf-8")
        cls.canon = CANON_PATH.read_text(encoding="utf-8")
        cls.ending_manifest = json.loads(ENDING_MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_design_identity_and_artifacts(self) -> None:
        self.assertEqual(self.manifest["task"], "P6-001")
        self.assertEqual(self.manifest["status"], "approved_for_implementation")
        self.assertTrue(REPORT_PATH.is_file())
        self.assertIn("P6-001", self.report)
        self.assertIn("p6_001_act3_design.md", self.canon)

    def test_occupation_state_is_explicit_and_non_moralizing(self) -> None:
        state_model = self.manifest["occupation_state"]
        self.assertEqual(state_model["opening_phase_id"], "phase.act3_occupation_day")
        states = state_model["states"]
        self.assertGreaterEqual(len(states), 3)
        for state in states:
            self.assertIn(state["confidence"], ALLOWED_CONFIDENCE)
        self.assertIn("event.sale_estonia_1346 remains the terminal campaign milestone", state_model["invariants"])
        forbidden = {"morality", "alignment", "karma", "virtue", "sin", "good_evil", "morality_score"}
        state_ids = {state["id"] for state in states}
        self.assertTrue(forbidden.isdisjoint(state_ids))
        self.assertEqual(set(self.ending_manifest["forbidden_aggregate_keys"]), forbidden)

    def test_forced_forge_reuses_existing_contract(self) -> None:
        forced_forge = self.manifest["forced_forge"]
        self.assertEqual(forced_forge["commission_id"], "commission.forced_forge")
        self.assertEqual(forced_forge["package_id"], "package.forced_forge")
        self.assertEqual(forced_forge["implementation_task"], "P6-003")
        self.assertEqual({branch["id"] for branch in forced_forge["branches"]}, {"honest_work", "subtle_defect", "secret_feature"})

    def test_required_locations_and_padise_phases(self) -> None:
        locations = {location["id"]: location for location in self.manifest["locations"]}
        self.assertEqual(set(locations), REQUIRED_LOCATIONS)
        self.assertEqual(
            {phase["id"] for phase in locations["world_padise"]["phases"]},
            {"padise.before_sack", "padise.after_sack"},
        )
        self.assertEqual(locations["loc.maasilinna_castle"]["runtime_status"], "metadata_only")
        for location in locations.values():
            self.assertIn(location["confidence"], ALLOWED_CONFIDENCE)

    def test_ending_dimensions_match_runtime_model(self) -> None:
        ending = self.manifest["ending_families"]
        self.assertEqual(set(ending["dimensions"]), REQUIRED_ENDING_DIMENSIONS)
        self.assertEqual(ending["sale_event"], self.ending_manifest["sale_event"])
        self.assertEqual(set(ending["choice_mapping"]), {
            "choice.rebuild_with_the_city",
            "choice.serve_the_new_order",
            "choice.hide_the_hammer",
        })
        for dimension in ending["dimensions"].values():
            self.assertEqual(len(dimension), 3)

    def test_historical_milestones_are_labelled_and_in_canon(self) -> None:
        milestones = self.manifest["historical_milestones"]
        self.assertEqual(len(milestones), 4)
        for milestone in milestones:
            self.assertEqual(milestone["confidence"], "attested")
            self.assertIn(milestone["canon_anchor"], self.canon)
        self.assertIn("`attested`", self.report)

    def test_all_implementation_owners_are_named(self) -> None:
        self.assertEqual(set(self.manifest["implementation_tasks"]), REQUIRED_TASKS)
        for task_id in REQUIRED_TASKS:
            self.assertIn(task_id, self.report)


if __name__ == "__main__":
    unittest.main()
