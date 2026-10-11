"""R-724 Earth Tremor area-pulse content and fail-closed validation."""

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

SPELL = ROOT / "content" / "examples" / "valid" / "spell.pagan.earth_tremor.json"
GRANT = ROOT / "content" / "examples" / "valid" / "magic.grant.starter_earth_tremor.json"
FIREBALL = ROOT / "content" / "examples" / "valid" / "spell.pagan.fireball.json"


class MagicEarthTremorContentTests(unittest.TestCase):
    def _diagnostics(self, payload: dict) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "spell.pagan.invalid_earth_tremor.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return validate_corpus([path], project_root=ROOT)

    def _payload(self, source: Path = SPELL) -> dict:
        return json.loads(source.read_text(encoding="utf-8"))

    def _has_effect_error(self, payload: dict) -> bool:
        return any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload))

    def test_spell_and_explicit_grant_validate(self) -> None:
        self.assertEqual(validate_corpus([SPELL, GRANT], project_root=ROOT), [])
        spell = self._payload()
        self.assertEqual(spell["sequence"], ["element.earth"])
        self.assertEqual(spell["effect"]["delivery"], {"kind": "area_pulse", "radius": 96.0})
        self.assertEqual(spell["effect"]["impact"], {"kind": "stagger", "duration_sec": 1.5})
        grant = self._payload(GRANT)
        self.assertEqual(grant["operation"], "grant")
        self.assertEqual(grant["target_id"], spell["id"])

    def test_area_pulse_requires_radius_and_supported_impact(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"].pop("radius")
        self.assertTrue(self._has_effect_error(payload))
        payload = self._payload()
        payload["effect"].pop("impact")
        self.assertTrue(self._has_effect_error(payload))

    def test_area_pulse_rejects_foreign_placement_fields(self) -> None:
        for field, value in (("speed", 300.0), ("lifetime_sec", 2.0), ("duration_sec", 4.0)):
            payload = self._payload()
            payload["effect"]["delivery"][field] = value
            self.assertTrue(self._has_effect_error(payload), field)
        payload = self._payload()
        payload["effect"]["area"] = {
            "radius": 40.0,
            "effect": {"kind": "damage", "amount": 2.0, "damage_type": "earth"},
        }
        self.assertTrue(self._has_effect_error(payload))

    def test_stagger_duration_is_capped_and_carries_no_damage(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"]["duration_sec"] = 3.0
        self.assertEqual(self._diagnostics(payload), [])
        payload["effect"]["impact"]["duration_sec"] = 3.5
        self.assertTrue(self._has_effect_error(payload))
        payload = self._payload()
        payload["effect"]["impact"]["amount"] = 4.0
        self.assertTrue(self._has_effect_error(payload))

    def test_area_pulse_damage_needs_amount(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"] = {"kind": "damage", "amount": 6.0, "damage_type": "earth"}
        self.assertEqual(self._diagnostics(payload), [])
        payload["effect"]["impact"].pop("amount")
        self.assertTrue(self._has_effect_error(payload))

    def test_stagger_is_rejected_on_projectiles(self) -> None:
        payload = self._payload(FIREBALL)
        payload["effect"]["impact"] = {"kind": "stagger", "duration_sec": 1.0}
        self.assertTrue(self._has_effect_error(payload))


if __name__ == "__main__":
    unittest.main()
