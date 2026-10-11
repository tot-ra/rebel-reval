"""Deterministic R-863/R-864/R-865 audit for the R-653 minimum-hardware GPU evidence packet."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_PROFILE = ROOT / "tools/benchmarks/minimum-hardware.json"
MANIFEST = ROOT / "docs/reports/data/r653_minimum_hardware_gpu_evidence_manifest.json"
REPORT = ROOT / "docs/reports/r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md"
EXPECTED_CPU = "Intel Core i5-8250U"
EXPECTED_GPU = "Intel UHD Graphics 620"
EXPECTED_RESOLUTION = "1920x1080"
EXPECTED_RAW_SHA256 = "fddda43c820383c4c247d5b2b9e85a4dd3be0541f9a3f9adad30ddc771604e04"
EXPECTED_CAPTURE_REVISION = "847c9277320983c0398d25a5199e18f005b39d99"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class R653MinimumHardwareEvidenceManifestTests(unittest.TestCase):
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
        audit = manifest["r709_audit"]

        self.assertEqual(host["architecture"], "arm64")
        self.assertIn("Apple M5 Pro", host["processor_name"])
        self.assertFalse(host["headless"])
        self.assertEqual(audit["result"], "BLOCKED_FOR_TARGET_ACCEPTANCE")
        self.assertEqual(manifest["acceptance"]["target_run"], "BLOCKED")

    def test_manifest_preserves_frame_distribution_and_gpu_counters(self) -> None:
        manifest = _load_json(MANIFEST)
        metrics = manifest["raw_metrics"]
        frame_time = metrics["frame_time_ms"]

        self.assertEqual(frame_time["samples"], 120)
        for field in ("median", "p95", "p99", "max"):
            self.assertIn(field, frame_time)
        self.assertGreater(metrics["texture_memory_bytes"], 0)
        self.assertGreater(metrics["render_video_memory_bytes"], 0)

    def test_manifest_preserves_capture_provenance(self) -> None:
        manifest = _load_json(MANIFEST)
        capture = manifest["capture"]

        self.assertEqual(manifest["capture_revision"], EXPECTED_CAPTURE_REVISION)
        self.assertEqual(capture["raw_report_sha256"], EXPECTED_RAW_SHA256)
        self.assertEqual(capture["requested_renderer"], "gl_compatibility")
        self.assertEqual(capture["resolution"], EXPECTED_RESOLUTION)

    def test_manifest_records_r863_hardware_blocker_without_substitution(self) -> None:
        manifest = _load_json(MANIFEST)
        audit = manifest["r863_audit"]

        self.assertEqual(audit["task"], "R-863")
        self.assertEqual(audit["result"], "BLOCKED_TARGET_HARDWARE_UNAVAILABLE")
        self.assertFalse(audit["target_hardware_available"])
        self.assertFalse(audit["declared_target_run_executed"])
        self.assertIn("renderer_comparison_benchmark.tscn", audit["required_command"])
        self.assertIn("Do not substitute", audit["substitution_policy"])

    def test_manifest_records_r864_ledger_validation_and_handoff(self) -> None:
        manifest = _load_json(MANIFEST)
        audit = manifest["r864_audit"]
        acceptance = manifest["acceptance"]

        self.assertEqual(audit["task"], "R-864")
        self.assertEqual(audit["result"], "BLOCKED_LEDGER_PUBLISHED")
        self.assertEqual(audit["ledger_validation"], "PASS")
        self.assertTrue(audit["r709_audit_preserved"])
        self.assertEqual(audit["r863_hardware_gate"], "BLOCKED_TARGET_HARDWARE_UNAVAILABLE")
        self.assertEqual(audit["report_manifest_agreement"], "PASS")
        self.assertEqual(acceptance["ledger_validation"], "PASS - R-864 published checked manifest/report packet")

    def test_manifest_records_r865_independent_verification_and_handoff(self) -> None:
        manifest = _load_json(MANIFEST)
        audit = manifest["r865_audit"]
        acceptance = manifest["acceptance"]

        self.assertEqual(audit["task"], "R-865")
        self.assertEqual(audit["result"], "BLOCKED_INDEPENDENT_VERIFICATION_COMPLETE")
        self.assertEqual(audit["r864_ledger_validation"], "PASS")
        self.assertEqual(audit["declared_target_run"], "BLOCKED - no Intel UHD 620 host measured")
        self.assertEqual(audit["next_owner"], "R-563")
        self.assertIn("19/19", audit["focused_tests"])
        self.assertIn("independent_verification", acceptance)
        self.assertEqual(acceptance["next_owner"], "R-563")

    def test_report_links_manifest_and_records_r864_validation(self) -> None:
        text = REPORT.read_text(encoding="utf-8")

        self.assertIn("r653_minimum_hardware_gpu_evidence_manifest.json", text)
        self.assertIn("R-863", text)
        self.assertIn("R-864", text)
        self.assertIn("R-865", text)
        self.assertIn(EXPECTED_RAW_SHA256, text)
        self.assertIn("BLOCKED", text)


if __name__ == "__main__":
    unittest.main()
