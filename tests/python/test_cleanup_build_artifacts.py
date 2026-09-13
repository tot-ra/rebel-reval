#!/usr/bin/env python3
"""Tests for tools/cleanup_build_artifacts.py."""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import cleanup_build_artifacts as cleanup  # noqa: E402


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _write(path: Path, payload: bytes | str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(payload, bytes):
        path.write_bytes(payload)
    else:
        path.write_text(payload, encoding="utf-8")


def _init_git(root: Path) -> None:
    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)


def _fixture_manifest(extra: dict | None = None) -> dict:
    payload = {
        "schema_version": 1,
        "policy": {
            "never_rm_rf_build": True,
            "default_mode": "dry-run",
            "scope": "build/",
        },
        "protected_prefixes": ["music/", "docs/", ".git/", ".godot/"],
        "tracked_release_fingerprints": [
            "build/act1/PACKAGE_SHA256.txt",
            "build/act1/package_fingerprint.json",
        ],
        "retained_prefixes": ["build/act1/"],
        "retained_paths": [
            "build/act1/rr.dmg",
            "build/act1/PACKAGE_SHA256.txt",
            "build/act1/package_fingerprint.json",
        ],
        "allowlisted_removable": [
            {"path": "build/rr.dmg", "reason": "regenerable rr export"},
            {"path": "build/Reval Rebel.app", "reason": "unpacked leftover"},
            {"path": "build/test-logs", "reason": "regenerable QA logs"},
            {"path": "build/inventory", "reason": "side-path PCK proofs"},
            {"glob": "build/test_*.json", "reason": "local probe JSON"},
        ],
        "packaging_scripts": ["export_presets.cfg"],
        "rebuild": {"rr": {"command": "godot --headless --export-release rr ./build/rr.dmg"}},
    }
    if extra:
        payload.update(extra)
    return payload


def _seed_release(root: Path, package: bytes = b"frozen-act1-dmg") -> str:
    digest = _sha256_bytes(package)
    _write(
        root / "docs/data/act1_release_manifest.json",
        json.dumps(
            {
                "package_sha256": digest,
                "package_bytes": len(package),
                "package_path": "build/act1/rr.dmg",
                "package_fingerprint_path": "build/act1/package_fingerprint.json",
                "package_sha256_sidecar": "build/act1/PACKAGE_SHA256.txt",
            }
        ),
    )
    _write(
        root / "build/act1/package_fingerprint.json",
        json.dumps({"package_sha256": digest, "package_bytes": len(package)}),
    )
    _write(root / "build/act1/PACKAGE_SHA256.txt", f"{digest}  build/act1/rr.dmg\n")
    _write(root / "build/act1/rr.dmg", package)
    _write(root / "export_presets.cfg", 'name="rr"\n')
    return digest


class CleanupBuildArtifactsTest(unittest.TestCase):
    def test_repository_manifest_is_valid(self) -> None:
        manifest = cleanup.load_manifest(ROOT / "docs/data/build_artifact_retention.json")
        self.assertEqual(cleanup.validate_manifest(manifest), [])
        self.assertTrue(manifest["policy"]["never_rm_rf_build"])
        self.assertEqual(manifest["policy"]["scope"], "build/")
        self.assertIn("build/act1/rr.dmg", manifest["retained_paths"])
        self.assertFalse(any(
            str(row.get("path", "")).rstrip("/") == "build"
            for row in manifest["allowlisted_removable"]
            if isinstance(row, dict)
        ))

    def test_repository_dry_run_retains_act1_bind(self) -> None:
        manifest = cleanup.load_manifest(ROOT / "docs/data/build_artifact_retention.json")
        plan = cleanup.build_plan(ROOT, manifest, mode="dry-run")
        retained = {action.path for action in plan.retained}
        removable = {action.path for action in plan.removable}
        self.assertIn("build/act1", retained)
        self.assertNotIn("build/act1", removable)
        self.assertTrue(plan.retained_release_valid, msg="\n".join(plan.errors))
        self.assertEqual(plan.clone_bytes_planned, 0)
        self.assertEqual(plan.errors, [])

    def test_allowlisting_whole_build_is_rejected(self) -> None:
        manifest = _fixture_manifest()
        manifest["allowlisted_removable"] = [{"path": "build", "reason": "unsafe"}]
        errors = cleanup.validate_manifest(manifest)
        self.assertTrue(any("whole build/" in error for error in errors))

    def test_dry_run_changes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _init_git(root)
            digest = _seed_release(root)
            removable = root / "build/rr.dmg"
            _write(removable, b"current-rr")
            _write(root / "docs/data/build_artifact_retention.json", json.dumps(_fixture_manifest()))
            subprocess.run(
                ["git", "add", "-f", "build/act1/PACKAGE_SHA256.txt", "build/act1/package_fingerprint.json"],
                cwd=root,
                check=True,
                capture_output=True,
            )
            before = removable.read_bytes()
            before_mtime = removable.stat().st_mtime_ns
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = cleanup.main(
                    [
                        "--root",
                        str(root),
                        "--manifest",
                        str(root / "docs/data/build_artifact_retention.json"),
                    ]
                )
            self.assertEqual(exit_code, 0)
            self.assertEqual(removable.read_bytes(), before)
            self.assertEqual(removable.stat().st_mtime_ns, before_mtime)
            self.assertTrue((root / "build/act1/rr.dmg").is_file())
            self.assertIn("dry-run", stdout.getvalue())
            self.assertIn(digest[:8], (root / "build/act1/PACKAGE_SHA256.txt").read_text())

    def test_apply_removes_only_allowlisted_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _init_git(root)
            package = b"frozen-act1-dmg"
            _seed_release(root, package)
            _write(root / "build/rr.dmg", b"current-rr")
            _write(root / "build/Reval Rebel.app/Contents/MacOS/Reval Rebel", b"binary")
            _write(root / "build/test-logs/well.log", b"log-output")
            _write(root / "build/inventory/act1-after.pck", b"pck")
            _write(root / "build/secret-keep.bin", b"unclassified")
            _write(root / "music/keep.mp3", b"ID3")
            _write(root / "docs/data/build_artifact_retention.json", json.dumps(_fixture_manifest()))
            subprocess.run(
                ["git", "add", "-f", "build/act1/PACKAGE_SHA256.txt", "build/act1/package_fingerprint.json"],
                cwd=root,
                check=True,
                capture_output=True,
            )
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = cleanup.main(
                    [
                        "--root",
                        str(root),
                        "--manifest",
                        str(root / "docs/data/build_artifact_retention.json"),
                        "--apply",
                        "--require-package",
                    ]
                )
            self.assertEqual(exit_code, 0, msg=stdout.getvalue())
            self.assertFalse((root / "build/rr.dmg").exists())
            self.assertFalse((root / "build/Reval Rebel.app").exists())
            self.assertFalse((root / "build/test-logs").exists())
            self.assertFalse((root / "build/inventory").exists())
            self.assertTrue((root / "build/act1/rr.dmg").is_file())
            self.assertEqual((root / "build/act1/rr.dmg").read_bytes(), package)
            self.assertTrue((root / "build/secret-keep.bin").is_file())
            self.assertTrue((root / "music/keep.mp3").is_file())
            self.assertIn("clone removed: 0 bytes", stdout.getvalue())

    def test_cli_confirms_selected_json_basename(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _init_git(root)
            _seed_release(root)
            _write(root / "build/rr.dmg", b"current-rr")
            _write(root / "docs/data/build_artifact_retention.json", json.dumps(_fixture_manifest()))
            subprocess.run(
                ["git", "add", "-f", "build/act1/PACKAGE_SHA256.txt", "build/act1/package_fingerprint.json"],
                cwd=root,
                check=True,
                capture_output=True,
            )
            report = Path(temp_dir) / "alternate-cleanup-plan.json"
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                exit_code = cleanup.main(
                    [
                        "--root",
                        str(root),
                        "--manifest",
                        str(root / "docs/data/build_artifact_retention.json"),
                        "--json",
                        str(report),
                    ]
                )
            self.assertEqual(exit_code, 0)
            payload = json.loads(report.read_text(encoding="utf-8"))
            self.assertEqual(payload["mode"], "dry-run")
            self.assertEqual(payload["clone_bytes_planned"], 0)
            self.assertIn(f"JSON report written: {report.name}", stdout.getvalue())
            self.assertNotIn("JSON report written: cleanup-plan.json", stdout.getvalue())

    def test_apply_refuses_json_under_build(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _init_git(root)
            _seed_release(root)
            _write(root / "docs/data/build_artifact_retention.json", json.dumps(_fixture_manifest()))
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                exit_code = cleanup.main(
                    [
                        "--root",
                        str(root),
                        "--manifest",
                        str(root / "docs/data/build_artifact_retention.json"),
                        "--json",
                        str(root / "build/cleanup.json"),
                    ]
                )
            self.assertEqual(exit_code, 2)
            self.assertIn("under build/", stderr.getvalue())

    def test_busy_allowlisted_path_is_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            _init_git(root)
            _seed_release(root)
            target = root / "build/rr.dmg"
            _write(target, b"current-rr")
            _write(root / "docs/data/build_artifact_retention.json", json.dumps(_fixture_manifest()))
            subprocess.run(
                ["git", "add", "-f", "build/act1/PACKAGE_SHA256.txt", "build/act1/package_fingerprint.json"],
                cwd=root,
                check=True,
                capture_output=True,
            )
            with mock.patch.object(cleanup, "path_is_busy", return_value=True):
                plan = cleanup.build_plan(
                    root,
                    cleanup.load_manifest(root / "docs/data/build_artifact_retention.json"),
                    mode="dry-run",
                )
            skipped = {action.path for action in plan.skipped_active_jobs}
            self.assertIn("build/rr.dmg", skipped)
            self.assertTrue(target.is_file())

    def test_delete_path_refuses_build_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "build").mkdir()
            with self.assertRaisesRegex(RuntimeError, "whole build tree"):
                cleanup.delete_path(root, "build")


if __name__ == "__main__":
    unittest.main()
