"""P4-044: bind Act 1 release acceptance to the exact P4-013 package."""

from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/data/act1_release_manifest.json"
FINGERPRINT = ROOT / "build/act1/package_fingerprint.json"
SHA_SIDECAR = ROOT / "build/act1/PACKAGE_SHA256.txt"
DMG = ROOT / "build/act1/rr.dmg"
ACCEPTANCE_REPORT = ROOT / "docs/reports/p4_044_act1_release_acceptance.md"
VERIFY_SCRIPT = ROOT / "tools/verify_act1_release.sh"
GODOT_TEST = ROOT / "tests/godot/test_act1_release_acceptance.gd"

EXPECTED_SHA = "ea3cf41493394ab6bd01e17de38011b05bf3ee199fd4710a08a4eb3dc1eafbdc"
EXPECTED_BYTES = 1143742554
REQUIRED_CHECKS = {
    "package_sha_fingerprint",
    "act1_traversal",
    "accessibility",
    "licences",
    "supported_input",
    "packaged_platform_smoke",
}


class TestAct1ReleaseCandidate(unittest.TestCase):
    def test_manifest_binds_exact_p4_013_package(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        fingerprint = json.loads(FINGERPRINT.read_text(encoding="utf-8"))
        sidecar_sha = SHA_SIDECAR.read_text(encoding="utf-8").strip().split()[0]

        self.assertEqual(manifest["task_id"], "P4-044")
        self.assertEqual(manifest["package_task_id"], "P4-013")
        self.assertEqual(manifest["release_tag"], "v0.2.0-act1")
        self.assertEqual(manifest["export_preset"], "act1")
        self.assertEqual(manifest["package_path"], "build/act1/rr.dmg")
        self.assertEqual(manifest["package_sha256"], EXPECTED_SHA)
        self.assertEqual(manifest["package_bytes"], EXPECTED_BYTES)
        self.assertEqual(sidecar_sha, EXPECTED_SHA)
        self.assertEqual(fingerprint["task_id"], "P4-013")
        self.assertEqual(fingerprint["package_sha256"], EXPECTED_SHA)
        self.assertEqual(int(fingerprint["package_bytes"]), EXPECTED_BYTES)
        self.assertEqual(
            manifest["frozen_contracts"]["gate_report"],
            "docs/reports/p4_012_act1_gate.md",
        )
        self.assertEqual(
            set(manifest["required_checks"]),
            REQUIRED_CHECKS,
        )

    def test_live_dmg_matches_manifest_fingerprint(self) -> None:
        self.assertTrue(DMG.is_file(), f"missing Act 1 package: {DMG}")
        digest = hashlib.sha256(DMG.read_bytes()).hexdigest()
        self.assertEqual(digest, EXPECTED_SHA)
        self.assertEqual(DMG.stat().st_size, EXPECTED_BYTES)

    def test_acceptance_harness_artifacts_exist(self) -> None:
        self.assertTrue(ACCEPTANCE_REPORT.is_file(), "acceptance report missing")
        self.assertTrue(VERIFY_SCRIPT.is_file(), "verify script missing")
        self.assertTrue(GODOT_TEST.is_file(), "Godot acceptance test missing")
        self.assertTrue(
            VERIFY_SCRIPT.stat().st_mode & 0o111,
            "verify_act1_release.sh must be executable",
        )
        report = ACCEPTANCE_REPORT.read_text(encoding="utf-8")
        self.assertIn("P4-044", report)
        self.assertIn(EXPECTED_SHA, report)
        self.assertIn("critical/high", report.lower() or "critical")


if __name__ == "__main__":
    unittest.main()
