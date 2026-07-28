#!/usr/bin/env python3
"""Tests for the harbor fishing-net weather-wind capture verifier."""

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

from verify_harbor_fishing_net_wind_captures import (  # noqa: E402
    FRAME_COUNT,
    WEATHER_GROUPS,
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
    raw = b"".join(b"\x00" + bytes(rgba) * width for _ in range(height))
    idat = zlib.compress(raw, 9)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


class VerifyHarborFishingNetWindCapturesTest(unittest.TestCase):
    def test_current_repository_passes(self) -> None:
        self.assertEqual(validate(root=ROOT), [])

    def test_missing_capture_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            errors = validate(root=root)
            self.assertTrue(any("missing harbor fishing-net wind capture" in error for error in errors))

    def test_main_exits_zero_on_current_repository(self) -> None:
        self.assertEqual(main(), 0)


if __name__ == "__main__":
    unittest.main()
