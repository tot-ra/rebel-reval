"""P4-001 branch map contract checks for The Bell and the Chain."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOT = ROOT / "content" / "packages" / "bell_and_chain"
BRANCH_MAP_DOC = ROOT / "docs" / "SCENES" / "the-bell-and-the-chain-branch-map.md"
SCENE_DOC = ROOT / "docs" / "SCENES" / "the-bell-and-the-chain.md"
REQUIRED_SYSTEMS = (
    "commission",
    "mechanism",
    "gate",
    "patrol",
    "consequence",
)
CLIMAX_FLAGS = (
    "flag.act_climax_viru_seal",
    "flag.act_climax_viru_break",
    "flag.act_climax_viru_open",
)


class BellAndChainBranchMapTests(unittest.TestCase):
    def test_scene_and_branch_map_docs_exist(self) -> None:
        self.assertTrue(SCENE_DOC.is_file())
        self.assertTrue(BRANCH_MAP_DOC.is_file())

    def test_docs_reference_required_systems(self) -> None:
        combined = SCENE_DOC.read_text(encoding="utf-8") + BRANCH_MAP_DOC.read_text(encoding="utf-8")
        lowered = combined.casefold()
        for system in REQUIRED_SYSTEMS:
            with self.subTest(system=system):
                self.assertIn(system, lowered)

    def test_branch_map_declares_three_climax_branches(self) -> None:
        branch_map = json.loads((PACKAGE_ROOT / "branch_map.json").read_text(encoding="utf-8"))
        branches = branch_map.get("branches", [])
        self.assertEqual(len(branches), 3)
        branch_ids = {branch["id"] for branch in branches}
        self.assertEqual(
            branch_ids,
            {
                "honest_chain_seal_bias",
                "hidden_fracture_break_bias",
                "secret_release_open_bias",
            },
        )

    def test_quest_package_supports_commission_and_mechanism(self) -> None:
        commission = json.loads(
            (PACKAGE_ROOT / "content" / "commission.bell_and_chain.json").read_text(encoding="utf-8")
        )
        mechanism = json.loads(
            (PACKAGE_ROOT / "content" / "mechanism.bell_and_chain_gate.json").read_text(encoding="utf-8")
        )
        self.assertEqual(commission["type"], "commission")
        self.assertEqual(mechanism["type"], "mechanism")
        self.assertEqual(mechanism["commission_id"], commission["id"])
        option_ids = {option["id"] for option in commission["forging_options"]}
        self.assertEqual(option_ids, {"honest_work", "subtle_defect", "secret_feature"})

    def test_climax_bias_flags_are_mutually_declared(self) -> None:
        quest = json.loads((PACKAGE_ROOT / "content" / "quest.json").read_text(encoding="utf-8"))
        transition_flags: set[str] = set()
        for transition in quest.get("transitions", []):
            for effect in transition.get("effects", []):
                if effect.get("op") == "set_flag":
                    transition_flags.add(str(effect["key"]))
        for flag in CLIMAX_FLAGS:
            with self.subTest(flag=flag):
                self.assertIn(flag, transition_flags)


if __name__ == "__main__":
    unittest.main()
