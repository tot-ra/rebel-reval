"""Tests for slice performance manifest verification (P3-011)."""

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

from slice_performance import (  # noqa: E402
    verify_manifest_matches_model,
    verify_performance_report,
)

MANIFEST = ROOT / "docs/data/slice_performance_manifest.json"


class TestReportSlicePerformance(unittest.TestCase):
    def test_manifest_matches_authored_model(self) -> None:
        report = verify_manifest_matches_model(ROOT, MANIFEST)
        self.assertTrue(report.valid, report.errors)
        self.assertEqual(report.busiest_scene_profile_id, "lower_town_scene")
        self.assertEqual(report.budget_count, 6)

    def test_performance_report_slice_gates_pass(self) -> None:
        smoke_report = ROOT / "build/benchmarks/performance-smoke.json"
        if not smoke_report.is_file():
            self.skipTest("performance smoke report not generated on this host")
        report = verify_performance_report(ROOT, MANIFEST, smoke_report)
        self.assertTrue(report.valid, report.errors)

    def test_performance_report_fails_when_metric_over_budget(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            report_path = Path(temp_dir) / "report.json"
            report_path.write_text(
                json.dumps(
                    {
                        "headline": {"frame_time_ms_p95": 20.0},
                        "budget_summary": {
                            "profiles": {
                                "lower_town_scene": {
                                    "frame_time_ms_p95": {
                                        "available": True,
                                        "observed": 20.0,
                                        "limit": 16.67,
                                        "pass": False,
                                    }
                                }
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )
            report = verify_performance_report(ROOT, MANIFEST, report_path)
            self.assertFalse(report.valid)
            self.assertTrue(any("frame_time_ms_p95" in error for error in report.errors))


if __name__ == "__main__":
    unittest.main()
