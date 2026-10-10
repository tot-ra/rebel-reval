"""Tests for tools/validate_named_npcs.py (task R-1562)."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import validate_named_npcs as v  # noqa: E402


class NamedNpcRegistryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.data = json.loads(v.REGISTRY.read_text(encoding="utf-8"))
        cls.factions = v.known_factions()
        cls.anchors = v.known_anchors()
        cls.census_ids, cls.card_slugs = v.census_index()

    def errors(self, data: dict) -> list[str]:
        return v.validate(data, factions=self.factions, anchors=self.anchors,
                          census_ids=self.census_ids, card_slugs=self.card_slugs)

    def mutated(self, change) -> dict:
        data = copy.deepcopy(self.data)
        change(data["npcs"])
        return data

    def test_registry_is_valid(self) -> None:
        self.assertEqual(self.errors(self.data), [])
        self.assertEqual(v.main(["validate_named_npcs.py"]), 0)

    def test_faction_set_comes_from_the_ledger(self) -> None:
        self.assertIn("faction.danish_crown", self.factions)
        self.assertIn("faction.blackheads", self.factions)
        self.assertNotIn("faction.lizard_union", self.factions)

    def test_wave_a_has_two_npcs_at_the_forum_at_ten(self) -> None:
        at_forum = [
            n["id"] for n in self.data["npcs"]
            if n["act_gate"] == 1 and any(
                p["anchor"] == "poi.forum" and p["from"] <= 10 < p["to"] for p in n["schedule"])
        ]
        self.assertGreaterEqual(len(at_forum), 2, at_forum)

    def test_duplicate_id(self) -> None:
        data = self.mutated(lambda npcs: npcs.append(copy.deepcopy(npcs[0])))
        self.assertTrue(any("duplicate id" in e for e in self.errors(data)))

    def test_unknown_faction(self) -> None:
        data = self.mutated(lambda npcs: npcs[0].update(faction="faction.lizard_union"))
        self.assertTrue(any("unknown faction" in e for e in self.errors(data)))

    def test_missing_sheet(self) -> None:
        data = self.mutated(lambda npcs: npcs[0].update(source_sheet="characters/nobody.md"))
        self.assertTrue(any("source_sheet" in e for e in self.errors(data)))

    def test_missing_portrait(self) -> None:
        data = self.mutated(lambda npcs: npcs[0].update(portrait="res://assets/nope.png"))
        self.assertTrue(any("portrait" in e for e in self.errors(data)))

    def test_schedule_gap(self) -> None:
        data = self.mutated(lambda npcs: npcs[0]["schedule"].pop(1))
        self.assertTrue(any("gap or overlap" in e for e in self.errors(data)))

    def test_unknown_anchor(self) -> None:
        data = self.mutated(lambda npcs: npcs[0]["schedule"][1].update(anchor="poi.moon"))
        self.assertTrue(any("not a city anchor" in e for e in self.errors(data)))

    def test_census_linked_twice(self) -> None:
        cit = sorted(self.census_ids)[0]

        def link(npcs: list) -> None:
            for npc in npcs[:2]:
                npc.update(census_mode="replaces", census_id=cit)

        errors = self.errors(self.mutated(link))
        self.assertTrue(any("already linked" in e for e in errors), errors)

    def test_extra_must_not_carry_census_id(self) -> None:
        cit = sorted(self.census_ids)[0]
        data = self.mutated(lambda npcs: npcs[0].update(census_id=cit))
        self.assertTrue(any("census_id null" in e for e in self.errors(data)))

    def test_deep_card_slug_needs_link(self) -> None:
        slug = sorted(self.card_slugs)[0]
        data = self.mutated(lambda npcs: npcs[0].update(id=slug))
        self.assertTrue(any("deep card" in e for e in self.errors(data)))


if __name__ == "__main__":
    unittest.main()
