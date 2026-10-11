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
FORCED_FORGE_QUEST_PATH = ROOT / "content" / "packages" / "forced_forge" / "content" / "quest.json"
VIRU_GATE_QUEST_PATH = ROOT / "content" / "packages" / "bell_and_chain" / "content" / "quest.json"


class PoideSiegeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.quest = json.loads(QUEST_PATH.read_text(encoding="utf-8"))
        cls.branch_map = json.loads(BRANCH_MAP_PATH.read_text(encoding="utf-8"))
        cls.forced_forge_quest = json.loads(FORCED_FORGE_QUEST_PATH.read_text(encoding="utf-8"))
        cls.viru_gate_quest = json.loads(VIRU_GATE_QUEST_PATH.read_text(encoding="utf-8"))
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

    def test_three_branches_consume_published_forge_and_act2_records(self) -> None:
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

        condition_keys = {
            condition["key"]
            for transition in self.quest["transitions"]
            for condition in transition.get("conditions", [])
            if condition["op"] == "flag_is"
        }
        forced_forge_effect_keys = {
            effect["key"]
            for transition in self.forced_forge_quest["transitions"]
            for effect in transition.get("effects", [])
            if effect["op"] == "set_flag"
        }
        viru_gate_effect_keys = {
            effect["key"]
            for transition in self.viru_gate_quest["transitions"]
            for effect in transition.get("effects", [])
            if effect["op"] == "set_flag"
        }
        expected_forge_keys = {
            "flag.forced_forge_compliant",
            "flag.forced_forge_flaw_undiscovered",
            "flag.forced_forge_secret_undiscovered",
        }
        expected_act2_keys = {
            "flag.act_climax_viru_break",
            "flag.act_climax_viru_open",
            "flag.act_climax_viru_seal",
        }
        self.assertEqual(condition_keys, expected_forge_keys | expected_act2_keys)
        self.assertLessEqual(expected_forge_keys, forced_forge_effect_keys)
        self.assertLessEqual(expected_act2_keys, viru_gate_effect_keys)

        input_pairs = {frozenset(branch["setup"]) for branch in branches}
        self.assertEqual(len(input_pairs), 3)
        for branch in branches:
            setup_keys = set(branch["setup"])
            self.assertEqual(len(setup_keys & expected_forge_keys), 1)
            self.assertEqual(len(setup_keys & expected_act2_keys), 1)
            self.assertEqual(branch["setup"], branch["require_flags"])

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

    def test_mismatched_forge_and_act2_records_do_not_unlock_an_outcome(self) -> None:
        resolution_transitions = [
            transition
            for transition in self.quest["transitions"]
            if transition["from_state"] == "ready"
        ]
        branches = self.branch_map["branches"]
        for index, branch in enumerate(branches):
            mismatched_flags = dict(branch["setup"])
            next_branch = branches[(index + 1) % len(branches)]
            act2_key = next(
                key for key in next_branch["setup"] if key.startswith("flag.act_climax_")
            )
            mismatched_flags[act2_key] = True
            own_act2_key = next(
                key for key in branch["setup"] if key.startswith("flag.act_climax_")
            )
            mismatched_flags.pop(own_act2_key)

            unlocked = [
                transition["id"]
                for transition in resolution_transitions
                if all(
                    mismatched_flags.get(condition["key"], False) == condition["value"]
                    for condition in transition.get("conditions", [])
                )
            ]
            self.assertEqual(unlocked, [], branch["id"])

    def test_attested_capture_is_preserved_in_every_outcome(self) -> None:
        self.assertIn("capture is a fixed historical milestone", self.quest["journal_evidence"][0]["text"])
        for state_id in ("taken_broken_gate", "taken_honored_record", "taken_hidden_signal"):
            self.assertTrue(next(row for row in self.quest["states"] if row["id"] == state_id)["terminal"])


if __name__ == "__main__":
    unittest.main()
