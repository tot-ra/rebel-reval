"""R-720 authored summon content and fail-closed delivery validation."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_content import validate_corpus  # noqa: E402

SPELL = ROOT / "content" / "examples" / "valid" / "spell.pagan.illusionary_double.json"
GRANT = ROOT / "content" / "examples" / "valid" / "magic.grant.starter_illusionary_double.json"


class MagicIllusionaryDoubleContentTests(unittest.TestCase):
    def test_spell_and_explicit_grant_validate(self) -> None:
        diagnostics = validate_corpus([SPELL, GRANT], project_root=ROOT)
        self.assertEqual(diagnostics, [])

        spell = json.loads(SPELL.read_text(encoding="utf-8"))
        self.assertEqual(spell["sequence"], ["element.mind", "element.deception"])
        self.assertEqual(spell["effect"]["delivery"]["summon_kind"], "illusionary_double")

    def test_summon_contract_rejects_missing_lifecycle_fields(self) -> None:
        payload = json.loads(SPELL.read_text(encoding="utf-8"))
        payload["effect"]["delivery"].pop("lifetime_sec")
        with tempfile.TemporaryDirectory() as temp_dir:
            invalid_path = Path(temp_dir) / "spell.pagan.invalid_double.json"
            invalid_path.write_text(json.dumps(payload), encoding="utf-8")
            diagnostics = validate_corpus([invalid_path], project_root=ROOT)
        self.assertTrue(
            any(
                diagnostic.code == "MAGIC_EFFECT"
                and "positive lifetime_sec" in diagnostic.message
                for diagnostic in diagnostics
            ),
            diagnostics,
        )

    def test_summon_contract_rejects_direct_impact(self) -> None:
        payload = json.loads(SPELL.read_text(encoding="utf-8"))
        payload["effect"]["impact"] = {
            "kind": "damage",
            "amount": 99,
            "damage_type": "magic",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            invalid_path = Path(temp_dir) / "spell.pagan.invalid_double.json"
            invalid_path.write_text(json.dumps(payload), encoding="utf-8")
            diagnostics = validate_corpus([invalid_path], project_root=ROOT)
        self.assertTrue(
            any(
                diagnostic.code == "MAGIC_EFFECT"
                and "must not define a direct impact" in diagnostic.message
                for diagnostic in diagnostics
            ),
            diagnostics,
        )


if __name__ == "__main__":
    unittest.main()
