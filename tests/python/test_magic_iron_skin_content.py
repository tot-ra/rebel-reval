"""R-725 Iron Skin self-modifier content and fail-closed validation."""

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

SPELL = ROOT / "content" / "examples" / "valid" / "spell.pagan.iron_skin.json"
GRANT = ROOT / "content" / "examples" / "valid" / "magic.grant.starter_iron_skin.json"


class MagicIronSkinContentTests(unittest.TestCase):
    def _diagnostics(self, payload: dict) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "spell.pagan.invalid_iron_skin.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return validate_corpus([path], project_root=ROOT)

    def _payload(self) -> dict:
        return json.loads(SPELL.read_text(encoding="utf-8"))

    def test_spell_and_explicit_grant_validate(self) -> None:
        self.assertEqual(validate_corpus([SPELL, GRANT], project_root=ROOT), [])
        spell = self._payload()
        self.assertEqual(spell["sequence"], ["element.earth", "element.metal"])
        self.assertEqual(spell["effect"]["delivery"], {"kind": "self"})
        self.assertEqual(spell["effect"]["modifier"]["stacking"], "replace")

    def test_self_delivery_requires_modifier(self) -> None:
        payload = self._payload()
        payload["effect"].pop("modifier")
        self.assertTrue(any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)))

    def test_modifier_requires_self_delivery(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"] = {"kind": "area_pulse", "radius": 64.0}
        self.assertTrue(any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)))

    def test_self_effects_cannot_hit_others(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"] = {"kind": "stagger", "duration_sec": 1.0}
        self.assertTrue(any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)))

    def test_stacking_rules_are_explicit(self) -> None:
        payload = self._payload()
        payload["effect"]["modifier"]["stacking"] = "stack"
        self.assertTrue(any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)))
        payload["effect"]["modifier"]["max_stacks"] = 3
        self.assertEqual(self._diagnostics(payload), [])
        payload["effect"]["modifier"]["stacking"] = "replace"
        self.assertTrue(any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)))

    def test_schema_caps_reduction_and_modifier_id_form(self) -> None:
        payload = self._payload()
        payload["effect"]["modifier"]["amount"] = 0.95
        self.assertNotEqual(self._diagnostics(payload), [])
        payload = self._payload()
        payload["effect"]["modifier"]["modifier_id"] = "iron_skin"
        self.assertNotEqual(self._diagnostics(payload), [])


if __name__ == "__main__":
    unittest.main()
