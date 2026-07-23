#!/usr/bin/env python3
"""Tests for the P0-053 slice-surface capture verifier."""

from __future__ import annotations

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

from verify_slice_surface_captures import (  # noqa: E402
    EXPECTED_HEIGHT,
    EXPECTED_WIDTH,
    MAP_IDS,
    main,
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


class VerifySliceSurfaceCapturesTest(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate(root=ROOT), [])

    def test_missing_capture_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            capture_dir = root / "docs" / "reports" / "images" / "view3d"
            capture_dir.mkdir(parents=True)
            for map_id in MAP_IDS:
                _write_png(
                    capture_dir / f"{map_id}_day.png",
                    EXPECTED_WIDTH,
                    EXPECTED_HEIGHT,
                    (220, 220, 220, 255),
                )

            errors = validate(root=root)
            self.assertTrue(any("missing P0-053 view3d capture" in error for error in errors))

    def test_identical_day_night_pair_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            capture_dir = root / "docs" / "reports" / "images" / "view3d"
            capture_dir.mkdir(parents=True)
            for map_id in MAP_IDS:
                for suffix in ("day", "night"):
                    _write_png(
                        capture_dir / f"{map_id}_{suffix}.png",
                        EXPECTED_WIDTH,
                        EXPECTED_HEIGHT,
                        (180, 180, 180, 255),
                    )

            errors = validate(root=root)
            self.assertTrue(any("must not be identical" in error for error in errors))

    def test_night_brighter_than_day_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            capture_dir = root / "docs" / "reports" / "images" / "view3d"
            capture_dir.mkdir(parents=True)
            for map_id in MAP_IDS:
                _write_png(
                    capture_dir / f"{map_id}_day.png",
                    EXPECTED_WIDTH,
                    EXPECTED_HEIGHT,
                    (20, 20, 20, 255),
                )
                _write_png(
                    capture_dir / f"{map_id}_night.png",
                    EXPECTED_WIDTH,
                    EXPECTED_HEIGHT,
                    (220, 220, 220, 255),
                )

            errors = validate(root=root)
            self.assertTrue(any("day mean luminance" in error for error in errors))

    def test_main_exits_zero_on_repository(self) -> None:
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
