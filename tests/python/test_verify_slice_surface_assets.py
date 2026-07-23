#!/usr/bin/env python3
"""Tests for the P0-053 slice-surface asset verifier."""

from __future__ import annotations

import csv
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

from verify_slice_surface_assets import (  # noqa: E402
    REQUIRED_FAMILIES,
    TEXTURE_SIZE,
    main,
    png_dimensions,
    validate,
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
    raw = b"".join(
        b"\x00" + bytes(rgba) * width
        for _ in range(height)
    )
    idat = zlib.compress(raw, 9)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def _write_sources(root: Path, rows: list[dict[str, str]]) -> None:
    sources = root / "assets" / "SOURCES.csv"
    sources.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "asset_id",
        "path",
        "creator_or_tool",
        "model_version",
        "prompt_or_url",
        "seed",
        "license",
        "edits",
        "approval",
    ]
    with sources.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class VerifySliceSurfaceAssetsTest(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate(root=ROOT), [])

    def test_missing_texture_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "docs").mkdir()
            (root / "docs" / "MATERIAL_STYLE_LOCK_KIT.md").write_text("kit", encoding="utf-8")
            _write_sources(root, [])

            errors = validate(root=root)
            self.assertTrue(any("missing style-lock texture" in error for error in errors))

    def test_wrong_dimensions_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "docs").mkdir()
            (root / "docs" / "MATERIAL_STYLE_LOCK_KIT.md").write_text("kit", encoding="utf-8")
            style_lock = root / "assets" / "materials" / "style_lock"
            style_lock.mkdir(parents=True)
            for family in REQUIRED_FAMILIES:
                _write_png(style_lock / f"{family}.png", 256, 256, (128, 128, 128, 255))
            _write_sources(
                root,
                [
                    {
                        "asset_id": f"assets.materials.style_lock.{family}",
                        "path": f"assets/materials/style_lock/{family}.png",
                        "creator_or_tool": "maintainer",
                        "model_version": "style-lock-v1.0",
                        "prompt_or_url": "fixture",
                        "seed": "1",
                        "license": "AGPL-3.0-or-later",
                        "edits": "fixture",
                        "approval": "approved - fixture",
                    }
                    for family in REQUIRED_FAMILIES
                ],
            )

            errors = validate(root=root)
            self.assertEqual(len([error for error in errors if "expected 512x512" in error]), 8)

    def test_placeholder_provenance_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "docs").mkdir()
            (root / "docs" / "MATERIAL_STYLE_LOCK_KIT.md").write_text("kit", encoding="utf-8")
            style_lock = root / "assets" / "materials" / "style_lock"
            style_lock.mkdir(parents=True)
            for family in REQUIRED_FAMILIES:
                _write_png(style_lock / f"{family}.png", TEXTURE_SIZE, TEXTURE_SIZE, (128, 128, 128, 255))
            _write_sources(
                root,
                [
                    {
                        "asset_id": f"assets.materials.style_lock.{family}",
                        "path": f"assets/materials/style_lock/{family}.png",
                        "creator_or_tool": "unknown",
                        "model_version": "style-lock-v1.0",
                        "prompt_or_url": "fixture",
                        "seed": "1",
                        "license": "AGPL-3.0-or-later",
                        "edits": "fixture",
                        "approval": "approved - fixture",
                    }
                    for family in REQUIRED_FAMILIES
                ],
            )

            errors = validate(root=root)
            self.assertTrue(any("placeholder creator_or_tool" in error for error in errors))

    def test_png_dimensions_helper(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "sample.png"
            _write_png(path, 512, 256, (10, 20, 30, 255))
            self.assertEqual(png_dimensions(path), (512, 256))

    def test_main_exits_zero_on_repository(self) -> None:
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
