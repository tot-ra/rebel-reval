#!/usr/bin/env python3
"""Tests for the P0-039 blind readability pack generator."""

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

import generate_p039_readability_pack as pack  # noqa: E402


class GenerateP039ReadabilityPackTest(unittest.TestCase):
    def test_current_repository_passes_check(self) -> None:
        self.assertEqual(pack.check(root=ROOT), [])

    def test_build_manifest_lists_every_recognition_target(self) -> None:
        manifest = pack.build_manifest(root=ROOT)
        self.assertEqual(manifest["recognition_targets"], list(pack.RECOGNITION_TARGETS))
        self.assertEqual(len(manifest["stimuli"]), len(pack.BLIND_LABELS))
        labels = [entry["blind_label"] for entry in manifest["stimuli"]]
        self.assertEqual(labels, list(pack.BLIND_LABELS))

    def test_write_creates_blind_copies_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for source in pack.STIMULUS_SOURCES:
                path = root / source["source_path"]
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"png")
            root.joinpath("docs/reports").mkdir(parents=True, exist_ok=True)
            (root / "docs/reports/p0_039_blind_readability_protocol.md").write_text(
                "protocol", encoding="utf-8"
            )
            (root / "docs/reports/data").mkdir(parents=True, exist_ok=True)
            (root / "docs/reports/data/p039_readability_results.template.json").write_text(
                "{}", encoding="utf-8"
            )

            manifest = pack.write_pack(root=root)

            self.assertTrue((root / manifest["stimuli"][0]["blind_copy"]).is_file())
            self.assertTrue((root / "docs/reports/data/p039_readability_pack.json").is_file())

    def test_check_fails_when_sha256_drifted(self) -> None:
        manifest = pack.build_manifest(root=ROOT)
        manifest["stimuli"][0]["sha256"] = "0" * 64
        errors = pack.validate_manifest(manifest, root=ROOT)
        self.assertTrue(any("sha256 mismatch" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
