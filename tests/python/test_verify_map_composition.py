#!/usr/bin/env python3
"""Tests for tools/verify_map_composition.py."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_map_composition as verifier  # noqa: E402


class VerifyMapCompositionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.thresholds = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        cls.registry = verifier.REGISTRY.read_text(encoding="utf-8")

    def test_threshold_cards_cover_registry(self) -> None:
        self.assertEqual(verifier.validate_threshold_contract(), [])

    def test_lower_town_composition_gate_is_explicitly_enforced(self) -> None:
        errors = verifier.validate_lower_town_enforcement()
        self.assertEqual(errors, [])

    def test_lower_town_gate_rejects_advisory_threshold_card(self) -> None:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        payload["maps"]["lower_town_slice"]["enforce"] = False
        path = ROOT / "build" / "test_map_composition_advisory.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.THRESHOLDS
        verifier.THRESHOLDS = path
        try:
            errors = verifier.validate_lower_town_enforcement()
        finally:
            verifier.THRESHOLDS = original
        self.assertTrue(any("composition gate must be explicitly enforced" in error for error in errors))

    def test_lower_town_gate_requires_explicit_open_region_exclusions(self) -> None:
        payload = json.loads(verifier.LOWER_TOWN_OWNERSHIP.read_text(encoding="utf-8"))
        payload["open_regions"][0].pop("exclude_from_unowned_empty_region")
        path = ROOT / "build" / "test_lower_town_ownership.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.LOWER_TOWN_OWNERSHIP
        verifier.LOWER_TOWN_OWNERSHIP = path
        try:
            errors = verifier.validate_lower_town_enforcement()
        finally:
            verifier.LOWER_TOWN_OWNERSHIP = original
        self.assertTrue(any("must explicitly opt out" in error for error in errors))

    def test_seeded_missing_threshold_card_fails(self) -> None:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        payload["maps"].pop("kalev_smithy", None)
        path = ROOT / "build" / "test_map_composition_thresholds.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")
        original = verifier.THRESHOLDS
        verifier.THRESHOLDS = path
        try:
            errors = verifier.validate_threshold_contract()
        finally:
            verifier.THRESHOLDS = original
        self.assertTrue(any("kalev_smithy" in error for error in errors))

    def _with_thresholds(self, mutate) -> list[str]:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        mutate(payload)
        return verifier.validate_density_contract(payload)

    def test_density_contract_is_complete(self) -> None:
        self.assertEqual(verifier.validate_density_contract(self.thresholds), [])

    def test_density_class_must_state_every_key_even_when_null(self) -> None:
        errors = self._with_thresholds(
            lambda p: p["density_contract"]["classes"]["dense_urban"].pop("decals_per_1000_min")
        )
        self.assertTrue(any("dense_urban must state decals_per_1000_min" in e for e in errors))

    def test_every_card_needs_a_known_map_class(self) -> None:
        errors = self._with_thresholds(lambda p: p["maps"]["toompea_quarter"].update(map_class="castle"))
        self.assertTrue(any("toompea_quarter: map_class" in e for e in errors))

    def test_grace_must_name_its_closing_task(self) -> None:
        errors = self._with_thresholds(
            lambda p: p["density_contract"]["production_grace"]["lower_town_slice"].pop("until")
        )
        self.assertTrue(any("density grace for lower_town_slice" in e for e in errors))

    def test_lower_town_grace_is_closed_by_r986(self) -> None:
        grace = self.thresholds["density_contract"]["production_grace"]
        self.assertIn("R-986", grace["lower_town_slice"]["until"])

    def test_historical_band_grace_names_closing_tasks(self) -> None:
        self.assertEqual(verifier.validate_historical_band_grace(self.thresholds), [])
        grace = self.thresholds["historical_band_grace"]
        self.assertIn("R-986", grace["lower_town_slice"]["until"])
        self.assertIn("R-285", grace["monastery_quarter"]["until"])
        self.assertIn("R-282", grace["south_quarter"]["until"])
        for map_id in grace:
            self.assertTrue(self.thresholds["maps"][map_id]["enforce"])

    def test_historical_band_grace_must_name_its_closing_task(self) -> None:
        errors = self._with_band_grace(
            lambda p: p["historical_band_grace"]["lower_town_slice"].pop("until")
        )
        self.assertTrue(any("historical band grace for lower_town_slice" in e for e in errors))

    def test_historical_band_grace_keeps_the_card_enrolled(self) -> None:
        errors = self._with_band_grace(
            lambda p: p["maps"]["south_quarter"].update(enforce=False)
        )
        self.assertTrue(
            any("historical band grace for south_quarter requires enforce=true" in e for e in errors)
        )

    def _with_band_grace(self, mutate) -> list[str]:
        payload = json.loads(verifier.THRESHOLDS.read_text(encoding="utf-8"))
        mutate(payload)
        return verifier.validate_historical_band_grace(payload)

    def test_floors_are_derived_from_the_interior_benchmark(self) -> None:
        contract = self.thresholds["density_contract"]
        benchmark = contract["benchmark"]
        self.assertEqual(benchmark["map_id"], "kalev_smithy")
        fractions = {"interior": 0.5, "dense_urban": 0.25, "sparse_urban": 0.125, "foreland": 0.0625, "rural": 0.0625}
        for class_id, fraction in fractions.items():
            card = contract["classes"][class_id]
            self.assertAlmostEqual(card["props_per_1000_min"], round(benchmark["props_per_1000"] * fraction, 1), places=1)
            self.assertAlmostEqual(card["decals_per_1000_min"], round(benchmark["decals_per_1000"] * fraction, 1), places=1)

    def test_parse_density_rows_ignores_noise(self) -> None:
        output = "\n".join([
            "AUDIT kalev_smithy",
            'DENSITY_JSON {"map_id": "a", "status": "pass", "failing_metrics": []}',
            "DENSITY_JSON {not json",
            'ERROR: DENSITY_JSON {"map_id": "b"}',
        ])
        rows = verifier.parse_density_rows(output)
        self.assertEqual([row["map_id"] for row in rows], ["a"])

    def test_gate_rows_map_scene_aliases_and_flag_unregistered_maps(self) -> None:
        rows = [
            {"map_id": "market_civic_quarter", "status": "fail", "map_class": "dense_urban", "failing_metrics": ["props_per_1000"]},
            {"map_id": "world.harju", "status": "pass", "map_class": "rural", "failing_metrics": []},
        ]
        benchmark = {"maps": [
            {"id": "reval_center", "source_path": "content/maps/market_civic_quarter.rrmap"},
            {"id": "world.harju", "source_path": "content/maps/world_harju.rrmap"},
            {"id": "toompea_small_castle", "source_path": "content/maps/toompea_small_castle.rrmap"},
        ]}
        gate = verifier.density_gate_rows(rows, benchmark)
        self.assertEqual(gate["reval_center"]["status"], "fail")
        self.assertEqual(gate["reval_center"]["failing_metrics"], ["props_per_1000"])
        self.assertEqual(gate["world.harju"]["status"], "pass")
        self.assertEqual(gate["toompea_small_castle"]["status"], "missing")

    def test_benchmark_carries_a_density_row_for_every_map(self) -> None:
        benchmark = json.loads(verifier.BENCHMARK.read_text(encoding="utf-8"))
        for entry in benchmark["maps"]:
            self.assertIn("automated_density", entry, entry["id"])


if __name__ == "__main__":
    unittest.main()
