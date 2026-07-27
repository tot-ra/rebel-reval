"""P4-005 branch map contract checks for The Price of a Name."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOT = ROOT / "content" / "packages" / "price_of_a_name"
BRANCH_MAP_DOC = ROOT / "docs" / "SCENES" / "the-price-of-a-name-branch-map.md"
SCENE_DOC = ROOT / "docs" / "SCENES" / "the-price-of-a-name.md"
REQUIRED_SYSTEMS = (
    "relationship",
    "detention",
    "false evidence",
    "hingepuu",
)
MART_FLAGS = (
    "flag.mart.name_cleared",
    "flag.mart.name_redirected",
    "flag.mart.name_concealed",
)


class PriceOfANameBranchMapTests(unittest.TestCase):
    def test_scene_and_branch_map_docs_exist(self) -> None:
        self.assertTrue(SCENE_DOC.is_file())
        self.assertTrue(BRANCH_MAP_DOC.is_file())

    def test_docs_reference_required_systems(self) -> None:
        combined = SCENE_DOC.read_text(encoding="utf-8") + BRANCH_MAP_DOC.read_text(encoding="utf-8")
        lowered = combined.casefold()
        for system in REQUIRED_SYSTEMS:
            with self.subTest(system=system):
                self.assertIn(system, lowered)

    def test_branch_map_declares_three_mart_branches(self) -> None:
        branch_map = json.loads((PACKAGE_ROOT / "branch_map.json").read_text(encoding="utf-8"))
        branches = branch_map.get("branches", [])
        self.assertEqual(len(branches), 3)
        branch_ids = {branch["id"] for branch in branches}
        self.assertEqual(
            branch_ids,
            {
                "honest_plates_cleared",
                "false_clerk_redirected",
                "swapped_plate_concealed",
            },
        )

    def test_quest_package_supports_commission_and_mechanism(self) -> None:
        commission = json.loads(
            (PACKAGE_ROOT / "content" / "commission.price_of_a_name.json").read_text(encoding="utf-8")
        )
        mechanism = json.loads(
            (PACKAGE_ROOT / "content" / "mechanism.price_of_a_name_detention.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(commission["type"], "commission")
        self.assertEqual(mechanism["type"], "mechanism")
        self.assertEqual(mechanism["commission_id"], commission["id"])
        option_ids = {option["id"] for option in commission["forging_options"]}
        self.assertEqual(option_ids, {"honest_work", "subtle_defect", "secret_feature"})

    def test_mart_outcome_flags_are_mutually_declared(self) -> None:
        quest = json.loads((PACKAGE_ROOT / "content" / "quest.json").read_text(encoding="utf-8"))
        transition_flags: set[str] = set()
        for transition in quest.get("transitions", []):
            for effect in transition.get("effects", []):
                if effect.get("op") == "set_flag":
                    transition_flags.add(str(effect["key"]))
        for flag in MART_FLAGS:
            with self.subTest(flag=flag):
                self.assertIn(flag, transition_flags)

    def test_false_evidence_item_exists(self) -> None:
        evidence_item = json.loads(
            (PACKAGE_ROOT / "content" / "item.evidence.seized_dispatch.json").read_text(encoding="utf-8")
        )
        self.assertEqual(evidence_item["id"], "item.evidence.seized_dispatch")
        self.assertEqual(evidence_item["category"], "evidence")


if __name__ == "__main__":
    unittest.main()
