"""Deterministic R-862 audit for the R-575 minimum-hardware crowd evidence packet."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_PROFILE = ROOT / "tools/benchmarks/minimum-hardware.json"
MANIFEST = ROOT / "docs/reports/data/r575_minimum_hardware_crowd_evidence_manifest.json"
REPORT = ROOT / "docs/reports/p0_154_n01_minimum_hardware_crowd_evidence_2026-08-18.md"
EXPECTED_CPU = "Intel Core i5-8250U"
EXPECTED_GPU = "Intel UHD Graphics 620"
EXPECTED_RESOLUTION = "1920x1080"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class R575MinimumHardwareEvidenceTests(unittest.TestCase):
    def test_manifest_matches_declared_target_profile(self) -> None:
        manifest = _load_json(MANIFEST)
        profile = _load_json(TARGET_PROFILE)
        target = manifest["target_hardware"]

        self.assertEqual(target["profile_id"], profile["profile_id"])
        self.assertEqual(target["architecture"], profile["architecture"])
        self.assertIn(EXPECTED_CPU, target["cpu"])
        self.assertIn(EXPECTED_GPU, target["gpu"])
        self.assertEqual(target["display"], EXPECTED_RESOLUTION)

    def test_manifest_records_distinct_host_and_blocked_target_acceptance(self) -> None:
        manifest = _load_json(MANIFEST)
        host = manifest["measurement_host"]
        audit = manifest["r862_audit"]

        self.assertEqual(host["architecture"], "arm64")
        self.assertIn("Apple M5 Pro", host["processor_name"])
        self.assertFalse(host["headless"])
        self.assertEqual(audit["result"], "BLOCKED_FOR_TARGET_ACCEPTANCE")
        self.assertEqual(manifest["acceptance"]["target_run"], "BLOCKED")
        self.assertEqual(manifest["acceptance"]["next_owner"], "R-863")

    def test_manifest_preserves_crowd_distribution_and_gpu_counters(self) -> None:
        manifest = _load_json(MANIFEST)
        crowd = manifest["crowd_character_peak"]
        gpu = manifest["lower_town_scene_gpu_memory"]

        self.assertEqual(crowd["target_count"], 200)
        self.assertTrue(crowd["within_budget"])
        for field in ("median", "p95", "p99", "max"):
            self.assertIn(field, crowd["frame_time_ms"])
        self.assertGreater(gpu["texture_memory_bytes"], 0)
        self.assertGreater(gpu["render_video_memory_bytes"], 0)

    def test_manifest_records_quick_mode_blocker_for_target_acceptance(self) -> None:
        manifest = _load_json(MANIFEST)

        self.assertTrue(manifest["capture"]["quick_mode"])
        self.assertEqual(manifest["crowd_character_peak"]["frame_time_ms"]["samples"], 20)
        self.assertIn("quick_mode_limitation", manifest["r862_audit"])

    def test_report_links_manifest_and_records_blocked_decision(self) -> None:
        text = REPORT.read_text(encoding="utf-8")

        self.assertIn("r575_minimum_hardware_crowd_evidence_manifest.json", text)
        self.assertIn("R-862", text)
        self.assertIn("BLOCKED", text)


if __name__ == "__main__":
    unittest.main()
