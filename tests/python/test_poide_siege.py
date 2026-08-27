"""Contract checks for the content-only P6-004 Pöide siege package."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import load_package, validate_package  # noqa: E402

PACKAGE_ROOT = ROOT / "content" / "packages" / "act3_poide_siege"
QUEST_PATH = PACKAGE_ROOT / "content" / "quest.json"
BRANCH_MAP_PATH = PACKAGE_ROOT / "branch_map.json"


class PoideSiegeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.quest = json.loads(QUEST_PATH.read_text(encoding="utf-8"))
        cls.branch_map = json.loads(BRANCH_MAP_PATH.read_text(encoding="utf-8"))
        cls.package = load_package(PACKAGE_ROOT)

    def test_package_validates_against_landmark_registry(self) -> None:
        self.assertEqual(validate_package(self.package), [])

    def test_package_keeps_poide_map_as_an_inactive_prototype(self) -> None:
        map_source = (ROOT / "content" / "maps" / "world_poide.rrmap").read_text(encoding="utf-8")
        self.assertIn("active=false", map_source)
        self.assertEqual(
            self.package.manifest["bindings"]["landmark_beats"],
            ["beat.landmark.estonia.poide_church_fortress"],
        )

    def test_three_branches_consume_distinct_forge_and_act2_records(self) -> None:
        branches = self.branch_map["branches"]
        self.assertEqual(len(branches), 3)
        self.assertEqual(
            {branch["id"] for branch in branches},
            {
                "broken_gate_high_losses",
                "honored_record_ordered_assault",
                "hidden_signal_islander_withdrawal",
            },
        )

        condition_keys: set[str] = set()
        for transition in self.quest["transitions"]:
            for condition in transition.get("conditions", []):
                if condition["op"] == "flag_is":
                    condition_keys.add(condition["key"])
        forge_keys = {key for key in condition_keys if key.startswith("flag.act1.forge.siege_materiel.")}
        act2_keys = {key for key in condition_keys if key.startswith("flag.act2.record.")}
        self.assertEqual(
            forge_keys,
            {
                "flag.act1.forge.siege_materiel.honest_work",
                "flag.act1.forge.siege_materiel.secret_feature",
                "flag.act1.forge.siege_materiel.subtle_defect",
            },
        )
        self.assertEqual(
            act2_keys,
            {
                "flag.act2.record.harju_signal",
                "flag.act2.record.viru_break",
                "flag.act2.record.viru_seal",
            },
        )

    def test_each_branch_reaches_a_distinct_terminal_outcome(self) -> None:
        transitions = {row["id"]: row for row in self.quest["transitions"]}
        states = {row["id"]: row for row in self.quest["states"]}
        terminal_states = {state_id for state_id, row in states.items() if row.get("terminal")}
        reached: set[str] = set()

        for branch in self.branch_map["branches"]:
            current = self.quest["initial_state"]
            flags = dict(branch["setup"])
            for transition_id in branch["transitions"]:
                transition = transitions[transition_id]
                self.assertEqual(transition["from_state"], current)
                for condition in transition.get("conditions", []):
                    self.assertEqual(flags.get(condition["key"], False), condition["value"])
                current = transition["to_state"]
                for effect in transition["effects"]:
                    if effect["op"] == "set_flag":
                        flags[effect["key"]] = effect["value"]
            self.assertIn(current, terminal_states)
            self.assertEqual(current, branch["expect"]["quest_state"])
            reached.add(current)

        self.assertEqual(len(reached), 3)

    def test_attested_capture_is_preserved_in_every_outcome(self) -> None:
        self.assertIn("capture is a fixed historical milestone", self.quest["journal_evidence"][0]["text"])
        for state_id in ("taken_broken_gate", "taken_honored_record", "taken_hidden_signal"):
            self.assertTrue(next(row for row in self.quest["states"] if row["id"] == state_id)["terminal"])


if __name__ == "__main__":
    unittest.main()
