"""P4-008a branch map contract checks for St. George's Night."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOT = ROOT / "content" / "packages" / "st_georges_night"
BRANCH_MAP_DOC = ROOT / "docs" / "SCENES" / "st-georges-night-branch-map.md"
SCENE_DOC = ROOT / "docs" / "SCENES" / "st-georges-night.md"
REQUIRED_SYSTEMS = (
    "mechanism",
    "gate",
    "patrol",
    "ledger",
    "consequence",
)
BOUNDARY_FLAGS = (
    "flag.act_boundary.viru_seal",
    "flag.act_boundary.viru_break",
    "flag.act_boundary.viru_open",
)


class StGeorgesNightBranchMapTests(unittest.TestCase):
    def test_scene_and_branch_map_docs_exist(self) -> None:
        self.assertTrue(SCENE_DOC.is_file())
        self.assertTrue(BRANCH_MAP_DOC.is_file())

    def test_docs_reference_required_systems(self) -> None:
        combined = SCENE_DOC.read_text(encoding="utf-8") + BRANCH_MAP_DOC.read_text(encoding="utf-8")
        lowered = combined.casefold()
        for system in REQUIRED_SYSTEMS:
            with self.subTest(system=system):
                self.assertIn(system, lowered)

    def test_branch_map_declares_three_act_boundary_branches(self) -> None:
        branch_map = json.loads((PACKAGE_ROOT / "branch_map.json").read_text(encoding="utf-8"))
        branches = branch_map.get("branches", [])
        self.assertEqual(len(branches), 3)
        branch_ids = {branch["id"] for branch in branches}
        self.assertEqual(
            branch_ids,
            {
                "seal_act_boundary",
                "break_act_boundary",
                "open_act_boundary",
            },
        )

    def test_quest_package_supports_climax_mechanism(self) -> None:
        mechanism = json.loads(
            (
                PACKAGE_ROOT / "content" / "mechanism.st_georges_night_gate.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(mechanism["type"], "mechanism")
        behaviors = {response["behavior"] for response in mechanism["responses"]}
        self.assertEqual(behaviors, {"hold", "fail", "release"})

    def test_act_boundary_flags_are_mutually_declared(self) -> None:
        quest = json.loads((PACKAGE_ROOT / "content" / "quest.json").read_text(encoding="utf-8"))
        transition_flags: set[str] = set()
        for transition in quest.get("transitions", []):
            for effect in transition.get("effects", []):
                if effect.get("op") == "set_flag":
                    transition_flags.add(str(effect["key"]))
        for flag in BOUNDARY_FLAGS:
            with self.subTest(flag=flag):
                self.assertIn(flag, transition_flags)
        self.assertIn("flag.act_transition.act1_recorded", transition_flags)

    def test_mechanism_maps_climax_bias_to_gate_behavior(self) -> None:
        mechanism = json.loads(
            (
                PACKAGE_ROOT / "content" / "mechanism.st_georges_night_gate.json"
            ).read_text(encoding="utf-8")
        )
        bias_keys = set()
        for response in mechanism["responses"]:
            for requirement in response.get("requires", []):
                if requirement.get("op") == "flag_is":
                    bias_keys.add(str(requirement["key"]))
        self.assertEqual(
            bias_keys,
            {
                "flag.act_climax_viru_seal",
                "flag.act_climax_viru_break",
                "flag.act_climax_viru_open",
            },
        )


if __name__ == "__main__":
    unittest.main()
