"""R-721 Healing Mist persistent-area content and fail-closed validation."""

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

SPELL = ROOT / "content" / "examples" / "valid" / "spell.pagan.healing_mist.json"
GRANT = ROOT / "content" / "examples" / "valid" / "magic.grant.starter_healing_mist.json"
TREMOR = ROOT / "content" / "examples" / "valid" / "spell.pagan.earth_tremor.json"


class MagicHealingMistContentTests(unittest.TestCase):
    def _diagnostics(self, payload: dict) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "spell.pagan.invalid_healing_mist.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return validate_corpus([path], project_root=ROOT)

    def _payload(self, source: Path = SPELL) -> dict:
        return json.loads(source.read_text(encoding="utf-8"))

    def _has_effect_error(self, payload: dict) -> bool:
        return any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload))

    def test_spell_and_explicit_grant_validate(self) -> None:
        self.assertEqual(validate_corpus([SPELL, GRANT], project_root=ROOT), [])
        spell = self._payload()
        self.assertEqual(spell["sequence"], ["element.water", "element.life"])
        self.assertEqual(spell["effect"]["delivery"]["kind"], "persistent_area")
        self.assertEqual(spell["effect"]["delivery"]["target_policy"], "ally")
        self.assertEqual(spell["effect"]["impact"]["kind"], "heal_over_time")

    def test_area_requires_lifetime_radius_and_policy(self) -> None:
        for field in ("duration_sec", "radius", "target_policy"):
            payload = self._payload()
            payload["effect"]["delivery"].pop(field)
            self.assertTrue(self._has_effect_error(payload), field)

    def test_heal_over_time_requires_positive_cadence(self) -> None:
        for field in ("amount", "duration_sec", "tick_interval_sec"):
            payload = self._payload()
            payload["effect"]["impact"].pop(field)
            self.assertTrue(self._has_effect_error(payload), field)
        payload = self._payload()
        payload["effect"]["impact"]["tick_interval_sec"] = 7.0
        self.assertTrue(self._has_effect_error(payload), "must tick inside its duration")

    def test_healing_area_cannot_target_hostiles(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"]["target_policy"] = "hostile"
        self.assertTrue(self._has_effect_error(payload))

    def test_area_requires_heal_over_time_impact(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"] = {"kind": "stagger", "duration_sec": 1.0}
        self.assertTrue(self._has_effect_error(payload))
        payload = self._payload()
        payload["effect"].pop("impact")
        self.assertTrue(self._has_effect_error(payload))

    def test_area_rejects_foreign_placement_and_modules(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"]["speed"] = 200.0
        self.assertTrue(self._has_effect_error(payload))
        payload = self._payload()
        payload["effect"]["impact"]["damage_type"] = "water"
        self.assertTrue(self._has_effect_error(payload))
        payload = self._payload()
        payload["effect"]["modifier"] = {
            "kind": "damage_reduction",
            "modifier_id": "modifier.mist",
            "amount": 0.2,
            "duration_sec": 4.0,
            "stacking": "replace",
        }
        self.assertTrue(self._has_effect_error(payload))

    def test_area_fields_and_heal_are_rejected_on_other_deliveries(self) -> None:
        tremor = self._payload(TREMOR)
        tremor["effect"]["delivery"]["target_policy"] = "ally"
        self.assertTrue(self._has_effect_error(tremor))
        tremor = self._payload(TREMOR)
        tremor["effect"]["impact"] = {
            "kind": "heal_over_time",
            "amount": 4.0,
            "tick_interval_sec": 1.0,
            "duration_sec": 6.0,
        }
        self.assertTrue(self._has_effect_error(tremor))

    def test_schema_caps_area_lifetime_and_policy_values(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"]["duration_sec"] = 45.0
        self.assertNotEqual(self._diagnostics(payload), [])
        payload = self._payload()
        payload["effect"]["delivery"]["target_policy"] = "everyone"
        self.assertNotEqual(self._diagnostics(payload), [])


if __name__ == "__main__":
    unittest.main()
