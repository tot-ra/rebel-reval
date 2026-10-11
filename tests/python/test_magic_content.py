"""P7-010 starter fixtures use authored IDs and closed recipe lookup."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_content import validate_corpus  # noqa: E402

VALID_MAGIC_ROOT = ROOT / "content" / "examples" / "valid"
VALID_MAGIC_FILES = [
    VALID_MAGIC_ROOT / "spell.pagan.spark.json",
    VALID_MAGIC_ROOT / "rite.blessing.json",
    VALID_MAGIC_ROOT / "magic.grant.starter_spark.json",
    VALID_MAGIC_ROOT / "magic.revoke.starter_spark.json",
]
INVALID_MAGIC = ROOT / "content" / "examples" / "invalid" / "spell.pagan.runtime_combo.json"


class MagicContentTests(unittest.TestCase):
    def test_starter_spell_rite_and_explicit_grants_validate(self) -> None:
        diagnostics = validate_corpus(VALID_MAGIC_FILES, project_root=ROOT)
        self.assertEqual(diagnostics, [])

        records = [
            json.loads(path.read_text(encoding="utf-8"))
            for path in VALID_MAGIC_FILES
        ]
        self.assertEqual(
            [record["id"] for record in records],
            [
                "spell.pagan.spark",
                "rite.blessing",
                "magic.grant.starter_spark",
                "magic.revoke.starter_spark",
            ],
        )
        self.assertEqual(records[0]["resolution"], "authored_lookup")
        self.assertFalse(records[0]["runtime_combination_allowed"])
        self.assertTrue(records[1]["fixed_liturgy"])
        self.assertEqual(
            {records[2]["operation"], records[3]["operation"]},
            {"grant", "revoke"},
        )

    def test_runtime_invented_combination_is_rejected(self) -> None:
        diagnostics = validate_corpus([INVALID_MAGIC], project_root=ROOT)
        codes = {diagnostic.code for diagnostic in diagnostics}
        self.assertIn("SCHEMA", codes)
        self.assertTrue(
            any("authored_lookup" in diagnostic.message for diagnostic in diagnostics),
            diagnostics,
        )


if __name__ == "__main__":
    unittest.main()
