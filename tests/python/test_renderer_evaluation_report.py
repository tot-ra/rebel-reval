#!/usr/bin/env python3
"""Tests for the P0-142 renderer evaluation report generator."""

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

import generate_renderer_evaluation_report as generator  # noqa: E402


def _sample_renderer(method: str) -> dict:
    return {
        "rendering_method": method,
        "display_driver": "headless",
        "headless": True,
        "scene_startup_ms": 1200.0,
        "memory_static_bytes": 320000000,
        "memory_delta_mib": 250.0,
        "texture_memory_bytes": 0,
        "render_video_memory_bytes": 0,
        "frame_time_ms": {
            "samples": 20,
            "median": 5.0,
            "p95": 7.0,
            "p99": 8.0,
            "max": 9.0,
        },
        "fidelity_features": {
            "ssao_supported": method != "gl_compatibility",
            "ssil_supported": method == "forward_plus",
            "sdfgi_supported": method == "forward_plus",
            "volumetric_fog_supported": method != "gl_compatibility",
            "screen_space_reflections_supported": method == "forward_plus",
            "glow_enabled": True,
            "tonemap_mode": 3,
            "fog_enabled": False,
            "directional_shadow_enabled": True,
        },
    }


SAMPLE_EVIDENCE = {
    "schema_version": 1,
    "task_id": "P0-142",
    "recorded_utc": "2026-07-29T10:00:00Z",
    "git_commit": "abc123",
    "target_hardware": {
        "profile_id": "development-baseline-m5-pro",
        "status": "development_baseline_not_minimum",
        "platform": "macOS",
        "cpu": "Apple M5 Pro",
        "gpu": "Apple M5 Pro",
        "memory_gib": 48,
    },
    "measurement_host": {
        "headless": True,
        "display_driver": "headless",
    },
    "renderers": [
        _sample_renderer("gl_compatibility"),
        _sample_renderer("mobile"),
        _sample_renderer("forward_plus"),
    ],
    "export_support": {
        "macos_rr_preset": {
            "renderer": "gl_compatibility",
            "status": "supported",
            "note": "shipped preset",
        },
    },
    "recommendation": {
        "stay_on": "gl_compatibility",
        "follow_up_task": "P0-157",
        "rationale": "stay on compatibility for export path",
    },
}


class RendererEvaluationReportTests(unittest.TestCase):
    def test_build_markdown_contains_required_sections(self) -> None:
        markdown = generator._build_markdown(SAMPLE_EVIDENCE)
        self.assertIn("P0-142 renderer evaluation report", markdown)
        self.assertIn("gl_compatibility", markdown)
        self.assertIn("forward_plus", markdown)
        self.assertIn("Export compatibility", markdown)
        self.assertIn("P0-157", markdown)

    def test_verify_requires_all_renderers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            evidence_path = root / "evidence.json"
            report_path = root / "report.md"
            capture_dir = root / "captures"
            capture_dir.mkdir()
            for method in generator.REQUIRED_RENDERERS:
                (capture_dir / f"{method}_lower_town_day.png").write_bytes(b"png")

            bad_evidence = dict(SAMPLE_EVIDENCE)
            bad_evidence["renderers"] = [_sample_renderer("gl_compatibility")]
            evidence_path.write_text(json.dumps(bad_evidence), encoding="utf-8")
            report_path.write_text(generator._build_markdown(bad_evidence), encoding="utf-8")

            original_capture_dir = generator.CAPTURE_DIR
            generator.CAPTURE_DIR = capture_dir
            try:
                errors = generator.verify(evidence_path, report_path)
            finally:
                generator.CAPTURE_DIR = original_capture_dir

            self.assertTrue(any("mobile" in error for error in errors))

    def test_write_and_check_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            evidence_path = root / "evidence.json"
            report_path = root / "report.md"
            capture_dir = root / "captures"
            capture_dir.mkdir()
            for method in generator.REQUIRED_RENDERERS:
                (capture_dir / f"{method}_lower_town_day.png").write_bytes(b"png")

            evidence_path.write_text(json.dumps(SAMPLE_EVIDENCE), encoding="utf-8")
            original_capture_dir = generator.CAPTURE_DIR
            generator.CAPTURE_DIR = capture_dir
            try:
                generator._build_markdown(SAMPLE_EVIDENCE)
                report_path.write_text(
                    generator._build_markdown(SAMPLE_EVIDENCE), encoding="utf-8"
                )
                errors = generator.verify(evidence_path, report_path)
            finally:
                generator.CAPTURE_DIR = original_capture_dir

            self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
