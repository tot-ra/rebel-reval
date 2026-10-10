"""Tests for tools/validate_faction_identity.py (task R-1565)."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import validate_faction_identity as v  # noqa: E402
from validate_named_npcs import known_factions  # noqa: E402


class FactionIdentityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = json.loads(v.IDENTITY.read_text(encoding="utf-8"))
        self.factions = known_factions()
        self.canon = v.CANON.read_text(encoding="utf-8")

    def errors(self, data: object) -> list[str]:
        return v.validate(data, factions=self.factions, canon_text=self.canon)

    def mutated(self, change) -> dict:
        data = copy.deepcopy(self.data)
        change(data["factions"])
        return data

    def test_shipped_file_is_valid(self) -> None:
        self.assertEqual(self.errors(self.data), [])

    def test_every_ledger_faction_and_candidate_is_covered(self) -> None:
        ids = {row["id"] for row in self.data["factions"]}
        self.assertTrue(self.factions <= ids)
        self.assertTrue(v.EXTRA_FACTIONS <= ids)

    def test_missing_launch_faction(self) -> None:
        data = self.mutated(lambda rows: rows.pop(0))
        self.assertTrue(any("missing identity row" in e for e in self.errors(data)))

    def test_shared_emblem_is_rejected(self) -> None:
        data = self.mutated(lambda rows: rows[1].update(emblem=rows[0]["emblem"]))
        self.assertTrue(any("shared with" in e for e in self.errors(data)))

    def test_low_contrast_pair(self) -> None:
        data = self.mutated(lambda rows: rows[0].update(secondary=rows[0]["primary"]))
        self.assertTrue(any("contrast" in e for e in self.errors(data)))

    def test_hero_crimson_is_reserved(self) -> None:
        data = self.mutated(lambda rows: rows[0].update(marker_tint=v.HERO_CRIMSON))
        self.assertTrue(any("reserved" in e for e in self.errors(data)))

    def test_canon_label_must_match(self) -> None:
        data = self.mutated(lambda rows: rows[0].update(canon="attested"))
        self.assertTrue(any("CANON.md label differs" in e for e in self.errors(data)))

    def test_missing_emblem_file(self) -> None:
        data = self.mutated(lambda rows: rows[0].update(emblem="res://assets/UI/factions/nope.png"))
        self.assertTrue(any("emblem file missing" in e for e in self.errors(data)))

    def test_bad_accent(self) -> None:
        data = self.mutated(lambda rows: rows[0]["accent"].update(placement="hat"))
        self.assertTrue(any("placement" in e for e in self.errors(data)))


if __name__ == "__main__":
    unittest.main()
