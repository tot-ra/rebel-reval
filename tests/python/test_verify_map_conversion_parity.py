#!/usr/bin/env python3
"""Tests for the P2-021a map conversion parity verifier."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_map_conversion_parity import (  # noqa: E402
    DEFAULT_MANIFEST,
    ValidationError,
    load_manifest,
    validate,
    validate_anchor_accounting,
    validate_captures,
    validate_report,
)


def _write_png(path: Path, width: int, height: int, rgba: tuple[int, int, int, int]) -> None:
    def chunk(chunk_type: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + chunk_type
            + data
            + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + bytes(rgba) * width for _ in range(height))
    idat = zlib.compress(raw, 9)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


class VerifyMapConversionParityTest(unittest.TestCase):
    def test_current_repository_passes_with_skip_godot(self) -> None:
        errors = validate(skip_godot=True)
        self.assertEqual(errors, [], [error.message for error in errors])

    def test_manifest_loads(self) -> None:
        manifest = load_manifest(DEFAULT_MANIFEST)
        self.assertEqual(manifest["task_id"], "P2-021a")
        self.assertEqual(len(manifest["maps"]), 2)

    def test_missing_anchor_fails_accounting(self) -> None:
        manifest = load_manifest(DEFAULT_MANIFEST)
        broken = json.loads(json.dumps(manifest))
        broken["maps"] = [broken["maps"][0]]
        broken["maps"][0]["required_anchors"].append("missing_anchor_id")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_dest = root / "tests/fixtures/maps/lower_town_slice.parity.json"
            fixture_dest.parent.mkdir(parents=True)
            fixture_dest.write_text(
                (ROOT / "tests/fixtures/maps/lower_town_slice.parity.json").read_text(
                    encoding="utf-8"
                ),
                encoding="utf-8",
            )
            errors = validate_anchor_accounting(root, broken)
        self.assertTrue(any("missing_anchor_id" in error.message for error in errors))

    def test_human_sign_off_required_only_when_requested(self) -> None:
        manifest = load_manifest(DEFAULT_MANIFEST)
        report_path = ROOT / str(manifest["report_path"])
        self.assertEqual(validate_report(ROOT, manifest, require_human_sign_off=False), [])
        errors = validate_report(ROOT, manifest, require_human_sign_off=True)
        self.assertTrue(any("human visual review is not signed" in error.message for error in errors))

    def test_flat_capture_fails(self) -> None:
        manifest = load_manifest(DEFAULT_MANIFEST)
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for entry in manifest["captures"]:
                path = root / str(entry["path"])
                path.parent.mkdir(parents=True, exist_ok=True)
                color = (40, 40, 40, 255) if entry["role"] == "converted_night" else (220, 220, 220, 255)
                _write_png(path, 1280, 720, color)
            errors = validate_captures(root, manifest)
        self.assertTrue(any("flat or blank" in error.message for error in errors))

    def test_missing_capture_fails(self) -> None:
        manifest = load_manifest(DEFAULT_MANIFEST)
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            errors = validate_captures(root, manifest)
        self.assertTrue(any("missing capture" in error.message for error in errors))


if __name__ == "__main__":
    unittest.main()
