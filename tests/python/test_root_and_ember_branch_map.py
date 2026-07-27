"""P4-007 branch map contract checks for Root and Ember."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOT = ROOT / "content" / "packages" / "root_and_ember"
BRANCH_MAP_DOC = ROOT / "docs" / "SCENES" / "root-and-ember-branch-map.md"
SCENE_DOC = ROOT / "docs" / "SCENES" / "root-and-ember.md"
REQUIRED_SYSTEMS = (
    "ellen",
    "ember",
    "root",
    "hingepuu",
    "folklore",
)
ELLEN_FLAGS = (
    "flag.ellen.belief_honored",
    "flag.ellen.remedy_trusted",
    "flag.ellen.skepticism_respected",
)


class RootAndEmberBranchMapTests(unittest.TestCase):
    def test_scene_and_branch_map_docs_exist(self) -> None:
        self.assertTrue(SCENE_DOC.is_file())
        self.assertTrue(BRANCH_MAP_DOC.is_file())

    def test_docs_reference_required_systems(self) -> None:
        combined = SCENE_DOC.read_text(encoding="utf-8") + BRANCH_MAP_DOC.read_text(encoding="utf-8")
        lowered = combined.casefold()
        for system in REQUIRED_SYSTEMS:
            with self.subTest(system=system):
                self.assertIn(system, lowered)

    def test_branch_map_declares_three_ellen_branches(self) -> None:
        branch_map = json.loads((PACKAGE_ROOT / "branch_map.json").read_text(encoding="utf-8"))
        branches = branch_map.get("branches", [])
        self.assertEqual(len(branches), 3)
        branch_ids = {branch["id"] for branch in branches}
        self.assertEqual(
            branch_ids,
            {
                "ember_song_peace",
                "root_ward_peace",
                "iron_bracket_practical",
            },
        )

    def test_quest_package_supports_commission_and_mechanism(self) -> None:
        commission = json.loads(
            (PACKAGE_ROOT / "content" / "commission.root_and_ember.json").read_text(encoding="utf-8")
        )
        mechanism = json.loads(
            (PACKAGE_ROOT / "content" / "mechanism.root_and_ember_hearth.json").read_text(
                encoding="utf-8"
            )
        )
        forging_ids = {opt["id"] for opt in commission.get("forging_options", [])}
        self.assertEqual(forging_ids, {"ember_rite", "root_ward", "iron_bracket"})
        self.assertEqual(mechanism.get("commission_id"), "commission.root_and_ember")
        self.assertEqual(len(mechanism.get("responses", [])), 3)

    def test_ellen_character_support_exists(self) -> None:
        ellen = json.loads(
            (ROOT / "content" / "examples" / "support" / "character.ellen.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(ellen.get("id"), "char.ellen")


if __name__ == "__main__":
    unittest.main()
