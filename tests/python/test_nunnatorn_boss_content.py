"""R-625 content contract checks for the authored Nunnatorn boss encounter."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
ENCOUNTER_PATH = ROOT / "content" / "examples" / "valid" / "encounter.nunnatorn_boss.json"


class NunnatornBossContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.encounter = json.loads(ENCOUNTER_PATH.read_text(encoding="utf-8"))

    def test_named_boss_and_reserved_route_contract(self) -> None:
        self.assertEqual(self.encounter["id"], "encounter.nunnatorn_boss")
        self.assertEqual(self.encounter["title"], "Marten of Nunnatorn at the open-backed tower")
        self.assertEqual(self.encounter["resolved_flag"], "flag.nunnatorn_boss_resolved")
        self.assertEqual(
            {outcome["kind"] for outcome in self.encounter["outcomes"]},
            {"bypass", "kill"},
        )
        self.assertEqual(
            {outcome["quest_state"] for outcome in self.encounter["outcomes"]},
            {"night_bypassed", "night_fought"},
        )

    def test_content_corpus_accepts_encounter_and_preserves_historical_boundary(self) -> None:
        from validate_content import validate_corpus

        diagnostics = validate_corpus(
            [ROOT / "content" / "examples" / "valid", ROOT / "content" / "examples" / "support"],
            project_root=ROOT,
        )
        self.assertEqual(diagnostics, [])
        notes = " ".join(note["summary"] for note in self.encounter["source_notes"])
        self.assertIn("authored encounter identity", notes)
        self.assertIn("reserved boss anchor", notes)

    def test_unsupported_outcome_is_not_authored(self) -> None:
        self.assertNotIn("surrender", {outcome["kind"] for outcome in self.encounter["outcomes"]})
        self.assertNotIn("escape", {outcome["kind"] for outcome in self.encounter["outcomes"]})
        self.assertNotIn("bribe", {outcome["kind"] for outcome in self.encounter["outcomes"]})


if __name__ == "__main__":
    unittest.main()
