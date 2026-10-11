"""P4-027d content contract checks for the Rentenitorn authored encounter."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
ENCOUNTER_PATH = ROOT / "content" / "examples" / "valid" / "encounter.rentenitorn_boss.json"
REVIEW_PATH = ROOT / "docs" / "reports" / "rentenitorn_interior_review.md"


class RentenitornBossContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.encounter = json.loads(ENCOUNTER_PATH.read_text(encoding="utf-8"))

    def test_named_boss_has_only_supported_distinct_outcomes(self) -> None:
        self.assertEqual(self.encounter["id"], "encounter.rentenitorn_boss")
        self.assertEqual(self.encounter["resolved_flag"], "flag.rentenitorn_boss_resolved")
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
        self.assertIn("strongarm", notes)

    def test_unknown_fabric_stays_reversible_and_labelled(self) -> None:
        """P4-027d requires the invented tower fabric to remain explicitly reversible."""
        self.assertEqual(self.encounter["confidence"], "invented")
        self.assertEqual(self.encounter["canon_status"], "draft")
        self.assertEqual(self.encounter["approval"]["status"], "draft")

        review = REVIEW_PATH.read_text(encoding="utf-8")
        self.assertIn("HUMAN SIGN-OFF PENDING", review)
        self.assertIn("developer-only", review)
        for citation in (
            "content/maps/rentenitorn_interior.rrmap",
            "history/dossiers/topography/walls-gates-towers.md",
        ):
            self.assertIn(citation, review)

        rrmap = (ROOT / "content" / "maps" / "rentenitorn_interior.rrmap").read_text(
            encoding="utf-8"
        )
        self.assertIn("active=false", rrmap)
        self.assertIn("minimum-claim reconstruction", rrmap)


if __name__ == "__main__":
    unittest.main()
