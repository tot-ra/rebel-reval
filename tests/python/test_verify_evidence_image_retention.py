#!/usr/bin/env python3
"""Tests for tools/verify_evidence_image_retention.py."""

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

import verify_evidence_image_retention as verifier  # noqa: E402


class VerifyEvidenceImageRetentionTest(unittest.TestCase):
    def test_repository_retention_passes(self) -> None:
        self.assertEqual(verifier.validate(), [])

    def test_missing_gdignore_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path = root / "docs" / "data" / "evidence_image_retention.json"
            images_root = root / "docs" / "reports" / "images" / "view3d"
            images_root.mkdir(parents=True)
            (images_root / "sample.png").write_bytes(
                b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
                b"\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\n"
                b"IDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
            )
            manifest_path.parent.mkdir(parents=True)
            manifest_path.write_text(
                json.dumps(
                    {
                        "baseline": {
                            "p0_186_start_docs_reports_images_bytes": 10,
                        },
                        "budget": {"target_docs_reports_images_bytes": 10},
                        "policy": {"gdignore_path": "docs/reports/images/.gdignore"},
                        "active_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "active"}
                        ],
                        "archived_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "archived"}
                        ],
                    }
                ),
                encoding="utf-8",
            )
            errors = verifier.validate(root=root, manifest_path=manifest_path)
        self.assertTrue(any("Godot exclusion marker" in error for error in errors))

    def test_import_sidecars_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path = root / "docs" / "data" / "evidence_image_retention.json"
            images_root = root / "docs" / "reports" / "images" / "view3d"
            images_root.mkdir(parents=True)
            (root / "docs" / "reports" / "images" / ".gdignore").write_text("", encoding="utf-8")
            (images_root / "sample.png.import").write_text("importer=texture", encoding="utf-8")
            manifest_path.parent.mkdir(parents=True)
            manifest_path.write_text(
                json.dumps(
                    {
                        "baseline": {"p0_186_start_docs_reports_images_bytes": 1},
                        "budget": {"target_docs_reports_images_bytes": 1},
                        "policy": {"gdignore_path": "docs/reports/images/.gdignore"},
                        "active_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "active"}
                        ],
                        "archived_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "archived"}
                        ],
                    }
                ),
                encoding="utf-8",
            )
            errors = verifier.validate(root=root, manifest_path=manifest_path)
        self.assertTrue(any("import sidecars" in error for error in errors))

    def test_run_acceptance_executes_manifest_commands(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path = root / "docs" / "data" / "evidence_image_retention.json"
            images_root = root / "docs" / "reports" / "images" / "view3d"
            images_root.mkdir(parents=True)
            (root / "docs" / "reports" / "images" / ".gdignore").write_text("", encoding="utf-8")
            manifest_path.parent.mkdir(parents=True)
            manifest_path.write_text(
                json.dumps(
                    {
                        "baseline": {"p0_186_start_docs_reports_images_bytes": 10},
                        "budget": {"target_docs_reports_images_bytes": 10},
                        "policy": {"gdignore_path": "docs/reports/images/.gdignore"},
                        "active_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "active"}
                        ],
                        "archived_directories": [
                            {"path": "docs/reports/images/view3d", "tier": "archived"}
                        ],
                        "active_acceptance_verifiers": [
                            {"id": "fixture", "command": ["python3", "-c", "import sys; sys.exit(0)"]}
                        ],
                    }
                ),
                encoding="utf-8",
            )
            errors = verifier.validate(
                root=root,
                manifest_path=manifest_path,
                run_acceptance=True,
            )
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
