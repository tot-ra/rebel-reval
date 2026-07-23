#!/usr/bin/env python3
"""Tests for the P0-038 comparison report generator."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_p038_comparison_report as generator  # noqa: E402


SAMPLE_EVIDENCE = {
    "schema_version": 1,
    "recorded_utc": "2026-07-23T16:00:00+00:00",
    "git_commit": "deadbeef",
    "target_hardware": {
        "profile_id": "development-baseline-m5-pro",
        "status": "development_baseline_not_minimum",
        "platform": "macOS 26.3",
        "cpu": "Apple M5 Pro, 18 logical cores",
        "gpu": "Apple M5 Pro, 20 cores",
        "memory_gib": 48,
    },
    "measurement_host": {
        "os": "macOS",
        "processor_name": "Apple M5 Pro",
        "video_adapter": "",
        "headless": True,
    },
    "import_time_seconds": 3.01,
    "import_procedure": "tools/run_godot_checked.sh clean-import godot --headless --editor --quit",
    "benchmark_report_path": "build/benchmarks/p038-evidence.json",
    "performance": {
        "renderer_mode": "headless_dummy",
        "frame_time_ms_p95": 7.56,
        "frame_time_budget_ms": 16.67,
        "memory_static_bytes": 327127139,
        "memory_delta_mib": 261.47,
        "texture_memory_bytes": 0,
        "render_video_memory_bytes": 0,
        "pipeline_cpu_ms_p95": 120.0,
        "scene_startup_ms": 16500.0,
        "actor_count": 3,
    },
    "navigation": {
        "slice_navigation_bake_ms": 17.075,
        "slice_navigation_polygon_count": 0,
        "synthetic_128_navigation_bake_ms": 64.136,
        "synthetic_128_navigation_polygon_count": 818,
        "slice_route_tests": "green",
        "note": "slice green",
    },
    "animation_reuse": {
        "canonical_clip_count": 76,
        "shared_skeleton": True,
        "per_direction_assets": False,
        "source_report": "docs/reports/character_rig_production_p0_037.md",
        "focused_test_filter": "test_character_rig",
        "focused_test_count": 16,
    },
    "npc_variant_production": {
        "innkeeper_rebuild_seconds": 16.83,
        "pickup_integration_seconds": 21.0,
        "variant_budget_working_day_seconds": 86400,
        "animation_budget_seconds": 3600,
        "source_report": "docs/reports/character_rig_production_p0_037.md",
    },
    "renderer_escalation": {
        "required_before_gpu_acceptance": True,
        "current_status": "development_baseline_headless_only",
        "next_step": "Run non-headless benchmark before GPU acceptance.",
    },
    "verdict": "pass_headless_development_baseline_pending_gpu_confirmation",
}


class GenerateP038ComparisonReportTest(unittest.TestCase):
    def test_render_contains_required_sections(self) -> None:
        report = generator.render(SAMPLE_EVIDENCE)
        for heading in (
            "## Verdict",
            "## Repeatable procedure",
            "## Hardware",
            "## Raw measurements",
            "## Results",
            "### Import time",
            "### Frame time",
            "### Texture memory",
            "### Navigation defects",
            "### Animation reuse",
            "### NPC-variant production time",
            "### Renderer-setting escalation",
            "## Embedded evidence",
        ):
            self.assertIn(heading, report)

    def test_verdict_passes_on_headless_budget(self) -> None:
        verdict = generator._verdict(
            {"frame_time_ms_p95": 7.5},
            {"measurement_host": {"headless": True}},
        )
        self.assertEqual(verdict, "pass_headless_development_baseline_pending_gpu_confirmation")

    def test_verdict_fails_when_headless_budget_exceeded(self) -> None:
        verdict = generator._verdict(
            {"frame_time_ms_p95": 20.0},
            {"measurement_host": {"headless": True}},
        )
        self.assertEqual(verdict, "fail_headless_frame_budget")

    def test_check_passes_when_report_matches_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence_path = root / "docs" / "reports" / "data" / "p038_comparison_evidence.json"
            report_path = root / "docs" / "reports" / "p0_038_3d_view_comparison.md"
            evidence_path.parent.mkdir(parents=True)
            evidence_path.write_text(json.dumps(SAMPLE_EVIDENCE, indent=2) + "\n", encoding="utf-8")
            report_path.write_text(generator.render(SAMPLE_EVIDENCE), encoding="utf-8")

            original_evidence = generator.EVIDENCE
            original_report = generator.REPORT
            generator.EVIDENCE = evidence_path
            generator.REPORT = report_path
            try:
                self.assertEqual(generator.check_outputs(root), [])
            finally:
                generator.EVIDENCE = original_evidence
                generator.REPORT = original_report

    def test_committed_report_is_current(self) -> None:
        errors = generator.check_outputs(ROOT)
        self.assertEqual(errors, [], msg="; ".join(errors))


if __name__ == "__main__":
    unittest.main()
