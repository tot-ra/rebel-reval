"""R-1320 vegetation benchmark report: schema, determinism compare, budget ratchet."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import vegetation_performance as vp  # noqa: E402


def _bucket(triangles: int = 0, draws: int = 0, instances: int = 0) -> dict[str, int]:
    return {
        "nodes": draws,
        "instances": instances,
        "triangles": triangles,
        "draw_calls": draws,
        "shadow_draw_calls": 0,
    }


def _report(trees: int = 1_000_000, grass_near: int = 50_000) -> dict:
    layers = {layer: _bucket() for layer in vp.LAYERS}
    layers["trees_lod0"] = _bucket(trees, 40, 400)
    layers["grass_near"] = _bucket(grass_near, 4, 2_000)
    layers["other"] = _bucket(300_000, 20, 120)
    return {
        "schema": vp.SCHEMA,
        "godot": "4.7.1",
        "renderer": "gl_compatibility",
        "host": {"gpu": "Test GPU"},
        "resolution": [1920, 1080],
        "layers": list(vp.LAYERS),
        "cameras": [
            {
                "name": "meadow_eye_level",
                "map_id": "viru_gate_foreland",
                "mode": "eye",
                "layers": layers,
                "vegetation_share": {"triangles": 0.8, "draw_calls": 0.7},
                "gpu": {"frame_ms_median": 20.0, "draw_calls_peak": 100},
                "layer_ms": {"trees_lod0": {"frame_ms_saved": 3.0}},
            }
        ],
    }


class SchemaTests(unittest.TestCase):
    def test_valid_report_passes(self) -> None:
        self.assertEqual(vp.validate(_report()), [])

    def test_wrong_schema_is_rejected(self) -> None:
        report = _report()
        report["schema"] = "rr.other.v1"
        self.assertTrue(vp.validate(report))

    def test_missing_layer_and_non_integer_count_are_rejected(self) -> None:
        report = _report()
        del report["cameras"][0]["layers"]["litter"]
        report["cameras"][0]["layers"]["grain"]["triangles"] = 1.5
        errors = vp.validate(report)
        self.assertTrue(any("missing layer litter" in error for error in errors))
        self.assertTrue(any("grain: triangles" in error for error in errors))

    def test_unknown_camera_is_rejected(self) -> None:
        report = _report()
        report["cameras"][0]["name"] = "random_camera"
        self.assertTrue(any("unknown camera" in error for error in vp.validate(report)))

    def test_layer_order_is_part_of_the_contract(self) -> None:
        report = _report()
        report["layers"] = list(reversed(vp.LAYERS))
        self.assertTrue(vp.validate(report))

    def test_load_raises_on_invalid_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text(json.dumps({"schema": "nope"}), encoding="utf-8")
            with self.assertRaises(ValueError):
                vp.load(path)


class CompareTests(unittest.TestCase):
    def test_identical_counts_compare_clean_even_if_timing_differs(self) -> None:
        second = _report()
        second["cameras"][0]["gpu"]["frame_ms_median"] = 31.0
        self.assertEqual(vp.compare(_report(), second), [])

    def test_count_difference_is_reported(self) -> None:
        differences = vp.compare(_report(), _report(trees=1_000_001))
        self.assertEqual(differences, ["meadow_eye_level.trees_lod0.triangles: 1000000 != 1000001"])

    def test_missing_camera_is_reported(self) -> None:
        second = _report()
        second["cameras"] = []
        self.assertEqual(vp.compare(_report(), second), ["meadow_eye_level: present in only one report"])


class BudgetTests(unittest.TestCase):
    def test_vegetation_totals_exclude_other(self) -> None:
        totals = vp.vegetation_totals(_report()["cameras"][0])
        self.assertEqual(totals["triangles"], 1_050_000)
        self.assertEqual(totals["draw_calls"], 44)

    def test_within_target_budget_passes_without_baseline(self) -> None:
        self.assertEqual(vp.check_budgets(_report()), [])

    def test_over_target_fails_without_baseline(self) -> None:
        violations = vp.check_budgets(_report(trees=9_000_000))
        self.assertTrue(any("trees_lod0 triangles" in line for line in violations))
        self.assertTrue(any("vegetation triangles" in line for line in violations))

    def test_ratchet_lets_an_over_budget_layer_stay_but_not_grow(self) -> None:
        baseline = _report(trees=9_000_000)
        self.assertEqual(vp.check_budgets(_report(trees=9_000_000), baseline), [])
        self.assertEqual(vp.check_budgets(_report(trees=8_000_000), baseline), [])
        grown = vp.check_budgets(_report(trees=9_000_001), baseline)
        self.assertTrue(any("trees_lod0 triangles" in line for line in grown))

    def test_layer_under_target_may_grow_up_to_target_only(self) -> None:
        baseline = _report()
        limit = vp.BUDGETS["layers"]["grass_near"][0]
        self.assertEqual(vp.check_budgets(_report(grass_near=limit), baseline), [])
        over = vp.check_budgets(_report(grass_near=limit + 1), baseline)
        self.assertTrue(any("grass_near triangles" in line for line in over))

    def test_layer_milliseconds_warn_but_never_fail(self) -> None:
        report = _report()
        report["cameras"][0]["layer_ms"]["trees_lod0"]["frame_ms_saved"] = 4.5
        self.assertEqual(vp.check_budgets(report), [])
        self.assertTrue(vp.check_timing(report))

    def test_layer_milliseconds_keep_noise_tolerance_over_baseline(self) -> None:
        baseline = _report()
        baseline["cameras"][0]["layer_ms"]["trees_lod0"]["frame_ms_saved"] = 40.0
        report = copy.deepcopy(baseline)
        report["cameras"][0]["layer_ms"]["trees_lod0"]["frame_ms_saved"] = 49.0
        self.assertEqual(vp.check_timing(report, baseline), [])
        report["cameras"][0]["layer_ms"]["trees_lod0"]["frame_ms_saved"] = 51.0
        self.assertTrue(vp.check_timing(report, baseline))


class CliTests(unittest.TestCase):
    def test_summary_and_compare_cli(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "veg.json"
            path.write_text(json.dumps(_report()), encoding="utf-8")
            self.assertIn("trees_lod0", vp.summary(vp.load(path)))
            self.assertEqual(vp.main(["compare", str(path), str(path)]), 0)
            self.assertEqual(vp.main(["budgets", str(path), "--baseline", str(path)]), 0)


if __name__ == "__main__":
    unittest.main()
