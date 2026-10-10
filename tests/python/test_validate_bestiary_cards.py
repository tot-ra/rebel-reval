"""Bestiary validator: the shipped roster passes, and bad rows or cards are caught."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_bestiary_cards as v  # noqa: E402


def row(**kw) -> dict:
    base = {"ID": "bst.test", "Name": "Test", "Layer": "spirit", "Tier": "act1", "Habitat": "x", "Factions": "-",
            "Basis": "folklore", "Images": "-", "Card": "planned", "Reasoning": "A sufficiently long reason."}
    base.update(kw)
    return base


CARD = """# Test

> A hook.

| Field | Value |
|---|---|
| ID | `bst.test` |
| Layer | `spirit` |
| Tier | `act1` |
| Confidence | `folklore` |
| Habitat | x |
| Faction ties | none |
| Archive reference images | none |

""" + "\n".join(f"## {s}\n" + ("\n".join(f"- **{b}:** x" for b in v.APPEARANCE_BULLETS) if s == "Appearance" else "text") + "\n"
                for s in v.SECTIONS)


class RosterTests(unittest.TestCase):
    def test_shipped_roster_and_cards_pass(self):
        self.assertEqual(v.main([]), 0)

    def test_duplicate_id_and_bad_enums(self):
        errors: list[str] = []
        v.check_roster([row(), row(), row(ID="bst.b", Layer="mythic"), row(ID="Bad", Tier="soon")], errors)
        text = "\n".join(errors)
        self.assertIn("duplicate ID bst.test", text)
        self.assertIn("layer 'mythic'", text)
        self.assertIn("bad ID 'Bad'", text)
        self.assertIn("tier 'soon'", text)

    def test_rejected_rows_have_no_tier_or_card(self):
        errors: list[str] = []
        v.check_roster([row(Layer="rejected", Tier="act1", Card="planned")], errors)
        self.assertEqual(len(errors), 2)

    def test_short_reasoning_rejected(self):
        errors: list[str] = []
        v.check_roster([row(Reasoning="no")], errors)
        self.assertTrue(any("reasoning" in e for e in errors))


class CardTests(unittest.TestCase):
    def check(self, text: str, roster: dict) -> list[str]:
        errors: list[str] = []
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = Path(tmp) / "test.md"
            path.write_text(text, encoding="utf-8")
            v.check_card(path, {"bst.test": roster}, errors)
        return errors

    def test_good_card(self):
        self.assertEqual(self.check(CARD, row()), [])

    def test_layer_mismatch_and_missing_section(self):
        errors = self.check(CARD.replace("## Voice", "## Barks"), row(Layer="physical"))
        text = "\n".join(errors)
        self.assertIn("Layer differs", text)
        self.assertIn("sections must be exactly", text)

    def test_placeholder_left_in_card(self):
        self.assertTrue(any("placeholder" in e for e in self.check(CARD + "\n<fill me>\n", row())))


if __name__ == "__main__":
    unittest.main()
