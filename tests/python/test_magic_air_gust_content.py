"""R-722 Air Gust knockback cone content and fail-closed validation."""

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

SPELL = ROOT / "content" / "examples" / "valid" / "spell.pagan.air_gust.json"
GRANT = ROOT / "content" / "examples" / "valid" / "magic.grant.starter_air_gust.json"
FIREBALL = ROOT / "content" / "examples" / "valid" / "spell.pagan.fireball.json"
HEALING_MIST = ROOT / "content" / "examples" / "valid" / "spell.pagan.healing_mist.json"


class MagicAirGustContentTests(unittest.TestCase):
    def _diagnostics(self, payload: dict) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "spell.pagan.invalid_air_gust.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return validate_corpus([path], project_root=ROOT)

    def _payload(self, source: Path = SPELL) -> dict:
        return json.loads(source.read_text(encoding="utf-8"))

    def _has_error(self, payload: dict) -> bool:
        return bool(self._diagnostics(payload))

    def test_spell_and_explicit_grant_validate(self) -> None:
        self.assertEqual(validate_corpus([SPELL, GRANT], project_root=ROOT), [])
        spell = self._payload()
        self.assertEqual(spell["sequence"], ["element.air"])
        self.assertEqual(
            spell["effect"]["delivery"], {"kind": "area_pulse", "radius": 112.0, "arc_deg": 90.0}
        )
        self.assertEqual(
            spell["effect"]["impact"], {"kind": "knockback", "distance": 96.0, "duration_sec": 0.6}
        )
        grant = self._payload(GRANT)
        self.assertEqual(grant["operation"], "grant")
        self.assertEqual(grant["target_id"], spell["id"])

    def test_knockback_requires_bounded_distance_and_duration(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"]["distance"] = 160.0
        payload["effect"]["impact"]["duration_sec"] = 1.0
        self.assertEqual(self._diagnostics(payload), [])
        for field, value in (("distance", 161.0), ("duration_sec", 1.2)):
            payload = self._payload()
            payload["effect"]["impact"][field] = value
            self.assertTrue(self._has_error(payload), field)
        for field in ("distance", "duration_sec"):
            payload = self._payload()
            payload["effect"]["impact"].pop(field)
            self.assertTrue(self._has_error(payload), field)

    def test_knockback_carries_no_damage_fields(self) -> None:
        for field, value in (("amount", 4.0), ("damage_type", "air"), ("tick_interval_sec", 0.5)):
            payload = self._payload()
            payload["effect"]["impact"][field] = value
            self.assertTrue(self._has_error(payload), field)

    def test_arc_is_optional_and_bounded(self) -> None:
        payload = self._payload()
        payload["effect"]["delivery"].pop("arc_deg")
        self.assertEqual(self._diagnostics(payload), [])
        payload["effect"]["delivery"]["arc_deg"] = 360.0
        self.assertEqual(self._diagnostics(payload), [])
        for value in (0.0, -30.0, 361.0):
            payload = self._payload()
            payload["effect"]["delivery"]["arc_deg"] = value
            self.assertTrue(self._has_error(payload), value)

    def test_stagger_rejects_distance(self) -> None:
        payload = self._payload()
        payload["effect"]["impact"] = {"kind": "stagger", "duration_sec": 1.0, "distance": 40.0}
        self.assertTrue(self._has_error(payload))

    def test_knockback_is_rejected_on_other_deliveries(self) -> None:
        impact = {"kind": "knockback", "distance": 60.0, "duration_sec": 0.5}
        for source in (FIREBALL, HEALING_MIST):
            payload = self._payload(source)
            payload["effect"]["impact"] = dict(impact)
            self.assertTrue(
                any(d.code == "MAGIC_EFFECT" for d in self._diagnostics(payload)), source.name
            )


if __name__ == "__main__":
    unittest.main()
