#!/usr/bin/env python3
"""Tests for tools/verify_runtime_glb_budget.py and oak texture externalize."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import optimize_runtime_glbs as optimizer  # noqa: E402
import verify_runtime_glb_budget as verifier  # noqa: E402


def _write_manifest(root: Path, **overrides: object) -> Path:
    payload = {
        "schema_version": 1,
        "owner": "P0-183",
        "policy": {"roots": ["assets"], "suffixes": [".glb"]},
        "rules": [
            {
                "id": "landmark_oak",
                "paths": [
                    "assets/props/environment/sacred_grove_ancient_oak/sacred_grove_ancient_oak.glb"
                ],
                "max_file_bytes": 8388608,
                "max_triangles": 70000,
            },
            {
                "id": "runtime_default",
                "glob": "assets/**/*.glb",
                "max_file_bytes": 10485759,
            },
        ],
        "exceptions": [],
    }
    payload.update(overrides)
    path = root / "docs" / "data" / "runtime_glb_budget.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _write_minimal_glb(path: Path, extra: bytes = b"") -> None:
    payload = extra + b"\x00" * ((-len(extra)) % 4)
    gltf = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": len(payload)}]}
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((-len(json_bytes)) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(payload)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"glTF"
        + struct.pack("<II", 2, total)
        + struct.pack("<I", len(json_bytes))
        + b"JSON"
        + json_bytes
        + struct.pack("<I", len(payload))
        + b"BIN\x00"
        + payload
    )


class VerifyRuntimeGlbBudgetTest(unittest.TestCase):
    def test_repository_budget_passes(self) -> None:
        self.assertEqual(verifier.validate(), [])

    def test_oak_maps_are_uri_referenced(self) -> None:
        self.assertFalse(optimizer.oak_has_embedded_maps())

    def test_oversized_file_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            glb = (
                root
                / "assets"
                / "props"
                / "environment"
                / "sacred_grove_ancient_oak"
                / "sacred_grove_ancient_oak.glb"
            )
            _write_minimal_glb(glb, extra=b"\x00" * 9_000_000)
            manifest = _write_manifest(root)
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertTrue(any("exceeds landmark_oak cap" in error for error in errors))

    def test_lfs_pointer_uses_declared_size(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            glb = root / "assets" / "props" / "prop.glb"
            glb.parent.mkdir(parents=True)
            glb.write_text(
                "version https://git-lfs.github.com/spec/v1\n"
                "oid sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
                "size 12000000\n",
                encoding="utf-8",
            )
            manifest = _write_manifest(root)
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertTrue(any("12000000 bytes exceeds runtime_default cap" in error for error in errors))

    def test_exception_path_is_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            glb = root / "assets" / "props" / "kept.glb"
            _write_minimal_glb(glb, extra=b"\x00" * 9_000_000)
            manifest = _write_manifest(
                root,
                exceptions=[{"path": "assets/props/kept.glb", "task": "P0-183"}],
            )
            errors = verifier.validate(root=root, manifest_path=manifest)
        self.assertEqual(errors, [])

    def test_missing_manifest_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            errors = verifier.validate(
                root=Path(temp_dir),
                manifest_path=Path("docs/data/runtime_glb_budget.json"),
            )
        self.assertTrue(any("missing runtime GLB budget" in error for error in errors))

    def test_shared_lod0_rule_matches_body_not_lod(self) -> None:
        rules = [
            {"id": "lod2", "glob": "assets/characters/shared/*_lod2.glb"},
            {"id": "lod1", "glob": "assets/characters/shared/*_lod1.glb"},
            {"id": "lod0", "glob": "assets/characters/shared/*.glb"},
        ]
        self.assertEqual(
            verifier.match_rule("assets/characters/shared/mart.glb", rules)["id"],
            "lod0",
        )
        self.assertEqual(
            verifier.match_rule("assets/characters/shared/mart_lod1.glb", rules)["id"],
            "lod1",
        )
        self.assertEqual(
            verifier.match_rule("assets/characters/shared/mart_lod2.glb", rules)["id"],
            "lod2",
        )


if __name__ == "__main__":
    unittest.main()
