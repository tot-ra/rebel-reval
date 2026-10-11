"""P4-003 branch map contract checks for Bread and Iron."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOT = ROOT / "content" / "packages" / "bread_and_iron"
BRANCH_MAP_DOC = ROOT / "docs" / "SCENES" / "bread-and-iron-branch-map.md"
SCENE_DOC = ROOT / "docs" / "SCENES" / "bread-and-iron.md"
REQUIRED_SYSTEMS = (
    "evidence",
    "supplier",
    "inventory",
    "location-state",
)
FAMILY_FLAGS = (
    "flag.family.raide_supplied",
    "flag.family.raide_rationed",
    "flag.family.raide_debt",
)


class BreadAndIronBranchMapTests(unittest.TestCase):
    def test_scene_and_branch_map_docs_exist(self) -> None:
        self.assertTrue(SCENE_DOC.is_file())
        self.assertTrue(BRANCH_MAP_DOC.is_file())

    def test_docs_reference_required_systems(self) -> None:
        combined = SCENE_DOC.read_text(encoding="utf-8") + BRANCH_MAP_DOC.read_text(encoding="utf-8")
        lowered = combined.casefold()
        for system in REQUIRED_SYSTEMS:
            with self.subTest(system=system):
                self.assertIn(system.replace("-", " "), lowered.replace("-", " "))

    def test_branch_map_declares_three_family_branches(self) -> None:
        branch_map = json.loads((PACKAGE_ROOT / "branch_map.json").read_text(encoding="utf-8"))
        branches = branch_map.get("branches", [])
        self.assertEqual(len(branches), 3)
        branch_ids = {branch["id"] for branch in branches}
        self.assertEqual(
            branch_ids,
            {
                "honest_brackets_supplied",
                "rigged_pivot_rationed",
                "smuggler_chute_debt",
            },
        )

    def test_quest_package_supports_commission_and_mechanism(self) -> None:
        commission = json.loads(
            (PACKAGE_ROOT / "content" / "commission.bread_and_iron.json").read_text(encoding="utf-8")
        )
        mechanism = json.loads(
            (PACKAGE_ROOT / "content" / "mechanism.bread_and_iron_scales.json").read_text(encoding="utf-8")
        )
        self.assertEqual(commission["type"], "commission")
        self.assertEqual(mechanism["type"], "mechanism")
        self.assertEqual(mechanism["commission_id"], commission["id"])
        option_ids = {option["id"] for option in commission["forging_options"]}
        self.assertEqual(option_ids, {"honest_work", "subtle_defect", "secret_feature"})

    def test_family_outcome_flags_are_mutually_declared(self) -> None:
        quest = json.loads((PACKAGE_ROOT / "content" / "quest.json").read_text(encoding="utf-8"))
        transition_flags: set[str] = set()
        for transition in quest.get("transitions", []):
            for effect in transition.get("effects", []):
                if effect.get("op") == "set_flag":
                    transition_flags.add(str(effect["key"]))
        for flag in FAMILY_FLAGS:
            with self.subTest(flag=flag):
                self.assertIn(flag, transition_flags)

    def test_supplier_and_inventory_items_exist(self) -> None:
        supplier_item = json.loads(
            (PACKAGE_ROOT / "content" / "item.supplier_iron_stock.json").read_text(encoding="utf-8")
        )
        evidence_item = json.loads(
            (PACKAGE_ROOT / "content" / "item.evidence.grain_tally_chit.json").read_text(encoding="utf-8")
        )
        self.assertEqual(supplier_item["id"], "item.supplier_iron_stock")
        self.assertEqual(evidence_item["id"], "item.evidence.grain_tally_chit")
        self.assertEqual(supplier_item["category"], "material")
        self.assertEqual(evidence_item["category"], "evidence")


if __name__ == "__main__":
    unittest.main()
