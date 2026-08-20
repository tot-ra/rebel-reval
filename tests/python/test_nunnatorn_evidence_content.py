"""R-626 content contract checks for Nunnatorn loot and evidence."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

ITEM_PATH = ROOT / "content" / "examples" / "valid" / "item.nunnatorn_evidence.json"
QUEST_PATH = ROOT / "content" / "examples" / "valid" / "quest.nunnatorn_evidence.json"


class NunnatornEvidenceContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.item = json.loads(ITEM_PATH.read_text(encoding="utf-8"))
        self.quest = json.loads(QUEST_PATH.read_text(encoding="utf-8"))

    def test_authored_item_and_separate_journal_records_are_stable(self) -> None:
        self.assertEqual(self.item["id"], "item.nunnatorn_evidence")
        self.assertEqual(self.item["category"], "evidence")
        self.assertEqual(self.quest["id"], "quest.nunnatorn_evidence")
        self.assertEqual(self.quest["content_links"]["item_ids"], ["item.nunnatorn_evidence"])
        self.assertEqual(
            {entry["fact_id"] for entry in self.quest["journal_evidence"]},
            {
                "fact.nunnatorn.evidence.ledger",
                "fact.nunnatorn.evidence.witness_account",
            },
        )

    def test_collection_transitions_are_outcome_aware_and_idempotent(self) -> None:
        transitions = {entry["id"]: entry for entry in self.quest["transitions"]}
        self.assertEqual(set(transitions), {"collect_lethal", "collect_alternate"})
        lethal_effects = {effect["op"]: effect for effect in transitions["collect_lethal"]["effects"]}
        alternate_effects = {effect["op"]: effect for effect in transitions["collect_alternate"]["effects"]}
        self.assertEqual(lethal_effects["add_item"]["key"], "item.nunnatorn_evidence")
        self.assertEqual(lethal_effects["set_fact"]["key"], "fact.nunnatorn.evidence.ledger")
        self.assertEqual(alternate_effects["set_fact"]["key"], "fact.nunnatorn.evidence.witness_account")
        self.assertNotIn("add_item", alternate_effects)
        self.assertIn(
            {"op": "flag_not", "key": "flag.nunnatorn_loot_collected", "value": True},
            transitions["collect_lethal"]["conditions"],
        )
        self.assertIn(
            {"op": "flag_not", "key": "flag.nunnatorn_evidence_recorded", "value": True},
            transitions["collect_alternate"]["conditions"],
        )

    def test_scoped_content_corpus_is_valid(self) -> None:
        from validate_content import validate_corpus

        diagnostics = validate_corpus(
            [ROOT / "content" / "examples" / "valid", ROOT / "content" / "examples" / "support"],
            project_root=ROOT,
        )
        self.assertEqual(diagnostics, [])


if __name__ == "__main__":
    unittest.main()
