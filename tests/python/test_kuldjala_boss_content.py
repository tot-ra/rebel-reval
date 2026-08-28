"""P4-027c content contract checks for Kuldjala's authored encounter."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
ENCOUNTER_PATH = ROOT / "content" / "examples" / "valid" / "encounter.kuldjala_boss.json"


class KuldjalaBossContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.encounter = json.loads(ENCOUNTER_PATH.read_text(encoding="utf-8"))

    def test_named_boss_has_only_supported_distinct_outcomes(self) -> None:
        self.assertEqual(self.encounter["id"], "encounter.kuldjala_boss")
        self.assertEqual(self.encounter["resolved_flag"], "flag.kuldjala_boss_resolved")
        self.assertEqual(
            {outcome["kind"] for outcome in self.encounter["outcomes"]},
            {"bypass", "kill"},
        )
        self.assertEqual(
            {outcome["quest_state"] for outcome in self.encounter["outcomes"]},
            {"night_bypassed", "night_fought"},
        )

    def test_content_corpus_accepts_package_and_marks_authored_boundary(self) -> None:
        from validate_content import validate_corpus

        diagnostics = validate_corpus(
            [ROOT / "content" / "examples" / "valid", ROOT / "content" / "examples" / "support"],
            project_root=ROOT,
        )
        self.assertEqual(diagnostics, [])
        notes = " ".join(note["summary"] for note in self.encounter["source_notes"])
        self.assertIn("authored encounter identities", notes)
        self.assertIn("crossbow guard", notes)


if __name__ == "__main__":
    unittest.main()
