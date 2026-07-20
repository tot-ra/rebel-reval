#!/usr/bin/env python3
"""Tests for tools/verify_storage_hygiene.py."""

from __future__ import annotations

import json
import hashlib
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

import verify_storage_hygiene as verifier  # noqa: E402


class VerifyStorageHygieneTest(unittest.TestCase):
    def test_repository_storage_passes(self) -> None:
        self.assertEqual(verifier.validate(), [])

    def test_generated_and_release_paths_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self._write_manifest(root, [])
            with mock.patch.object(
                verifier,
                "tracked_paths",
                return_value=["bin/rr.zip", "build/benchmarks/result.json", "tools/__pycache__/tool.pyc"],
            ):
                errors = verifier.validate(root)

        self.assertTrue(any("bin/rr.zip" in error for error in errors))
        self.assertTrue(any("build/benchmarks/result.json" in error for error in errors))
        self.assertTrue(any("tools/__pycache__/tool.pyc" in error for error in errors))

    def test_unapproved_large_binary_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload = root / "assets" / "new.bin"
            payload.parent.mkdir(parents=True)
            payload.write_bytes(b"x")
            self._write_manifest(root, [])
            with (
                mock.patch.object(verifier, "LARGE_FILE_BYTES", 1),
                mock.patch.object(verifier, "tracked_paths", return_value=["assets/new.bin"]),
                mock.patch.object(verifier, "is_lfs_tracked", return_value=False),
            ):
                errors = verifier.validate(root)

        self.assertTrue(any("without an exception" in error for error in errors))

    def test_missing_tracked_worktree_file_does_not_mask_a_stale_exception(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self._write_manifest(
                root,
                [
                    {
                        "path": "assets/missing.bin",
                        "size_bytes": str(verifier.LARGE_FILE_BYTES),
                        "sha256": "0" * 64,
                        "owner": "test owner",
                        "rationale": "missing fixture",
                        "follow_up": "P0-TEST",
                    }
                ],
            )
            with mock.patch.object(verifier, "tracked_paths", return_value=["assets/missing.bin"]):
                errors = verifier.validate(root)

        self.assertTrue(any("stale binary exception" in error for error in errors))

    def test_exception_hash_drift_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload = root / "assets" / "legacy.bin"
            payload.parent.mkdir(parents=True)
            payload.write_bytes(b"changed")
            self._write_manifest(
                root,
                [
                    {
                        "path": "assets/legacy.bin",
                        "size_bytes": str(payload.stat().st_size),
                        "sha256": hashlib.sha256(b"original").hexdigest(),
                        "owner": "test owner",
                        "rationale": "legacy test fixture",
                        "follow_up": "P0-TEST",
                    }
                ],
            )
            with (
                mock.patch.object(verifier, "LARGE_FILE_BYTES", 1),
                mock.patch.object(verifier, "tracked_paths", return_value=["assets/legacy.bin"]),
                mock.patch.object(verifier, "is_lfs_tracked", return_value=False),
            ):
                errors = verifier.validate(root)

        self.assertTrue(any("SHA-256 mismatch" in error for error in errors))

    def test_main_returns_nonzero_for_seeded_violation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            generated = root / "build" / "result.json"
            generated.parent.mkdir()
            generated.write_text("{}\n", encoding="utf-8")
            self._write_manifest(root, [])
            subprocess.run(["git", "add", "-f", "build/result.json", "docs/storage_binary_exceptions.csv"], cwd=root, check=True)

            self.assertEqual(verifier.main(["--root", str(root)]), 1)

    @staticmethod
    def _write_manifest(root: Path, rows: list[dict[str, object]]) -> None:
        path = root / "docs" / "storage_binary_exceptions.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
