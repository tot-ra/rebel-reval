"""Tests for deterministic R-716 capture planning."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from generate_world_building_capture_plan import build_plan  # noqa: E402


class WorldBuildingCapturePlanTests(unittest.TestCase):
    def test_plan_is_versioned_and_covers_every_matrix_category(self) -> None:
        manifest = json.loads(
            (ROOT / "docs/data/world_building_visual_benchmark.json").read_text(encoding="utf-8")
        )
        plan = build_plan(manifest)
        expected_count = len(manifest["maps"]) * len(manifest["capture_matrix"]["required_categories"])
        self.assertEqual(plan["schema_version"], 1)
        self.assertEqual(plan["task_id"], "R-716")
        self.assertEqual(plan["job_count"], expected_count)
        self.assertEqual(len(plan["jobs"]), expected_count)
        self.assertEqual(
            {job["acceptance_status"] for job in plan["jobs"]}, {"pending"}
        )
        self.assertEqual(
            {tuple(job["performance_tiers"]) for job in plan["jobs"]},
            {("minimum", "recommended")},
        )

    def test_plan_keeps_fixed_settings_and_stable_job_ids(self) -> None:
        manifest = json.loads(
            (ROOT / "docs/data/world_building_visual_benchmark.json").read_text(encoding="utf-8")
        )
        plan = build_plan(manifest)
        first_job = plan["jobs"][0]
        self.assertEqual(first_job["job_id"], "lower_town_slice.close_up")
        self.assertEqual(first_job["settings"], manifest["fixed_capture_settings"])
        self.assertTrue(first_job["output_path"].endswith("lower_town_slice/close_up.png"))


if __name__ == "__main__":
    unittest.main()
