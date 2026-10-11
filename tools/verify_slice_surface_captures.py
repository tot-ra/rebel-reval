#!/usr/bin/env python3
"""Verify P0-053 matched day/night view3d evidence captures.

Checks the production slice maps rendered by ``tools/capture_map_view_3d.gd``:
files exist at the expected resolution, day frames read brighter than night while
preserving non-blank detail, and each day/night pair is not a byte-identical copy.

Usage:
    python3 tools/verify_slice_surface_captures.py
"""

from __future__ import annotations

import hashlib
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_DIR = ROOT / "docs" / "reports" / "images" / "view3d"
MAP_IDS = ("kalev_smithy", "lower_town_slice")
TIMES_OF_DAY = ("day", "night")
EXPECTED_WIDTH = 1280
EXPECTED_HEIGHT = 720
MIN_DAY_MEAN_LUMINANCE = 20.0
MAX_NIGHT_MEAN_LUMINANCE = 20.0
MIN_DAY_NIGHT_LUMINANCE_DELTA = 10.0
MIN_LUMINANCE_STDEV = 5.0


@dataclass(frozen=True)
class CaptureStats:
    width: int
    height: int
    mean_luminance: float
    luminance_stdev: float
    digest: str


def _chunk_iter(data: bytes):
    pos = 8
    while pos + 8 <= len(data):
        length = int.from_bytes(data[pos : pos + 4], "big")
        pos += 4
        chunk_type = data[pos : pos + 4]
        pos += 4
        chunk = data[pos : pos + length]
        pos += length
        pos += 4  # crc
        yield chunk_type, chunk


def _paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _decode_png_rgb(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.relative_to(ROOT)} is not a PNG")

    width = height = 0
    bit_depth = color_type = 0
    idat = bytearray()
    for chunk_type, chunk in _chunk_iter(data):
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif chunk_type == b"IDAT":
            idat.extend(chunk)

    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(
            f"{path.relative_to(ROOT)}: expected 8-bit RGB/RGBA, got depth={bit_depth} type={color_type}"
        )

    bytes_per_pixel = 3 if color_type == 2 else 4
    stride = width * bytes_per_pixel
    raw = zlib.decompress(bytes(idat))
    rows: list[bytes] = []
    offset = 0
    previous = bytes([0]) * stride
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        scanline = bytearray(raw[offset : offset + stride])
        offset += stride
        if filter_type == 1:
            for index in range(stride):
                left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                scanline[index] = (scanline[index] + left) & 0xFF
        elif filter_type == 2:
            for index in range(stride):
                up = previous[index]
                scanline[index] = (scanline[index] + up) & 0xFF
        elif filter_type == 3:
            for index in range(stride):
                left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                up = previous[index]
                scanline[index] = (scanline[index] + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                up = previous[index]
                up_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                scanline[index] = (scanline[index] + _paeth_predictor(left, up, up_left)) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"{path.relative_to(ROOT)}: unsupported PNG filter {filter_type}")
        rows.append(bytes(scanline))
        previous = bytes(scanline)

    rgb = bytearray()
    for row in rows:
        for index in range(0, len(row), bytes_per_pixel):
            rgb.extend(row[index : index + 3])
    return width, height, bytes(rgb)


def capture_stats(path: Path) -> CaptureStats:
    width, height, rgb = _decode_png_rgb(path)
    pixel_count = len(rgb) // 3
    if pixel_count == 0:
        raise ValueError(f"{path.relative_to(ROOT)}: empty image")

    luminances = [
        0.2126 * rgb[index] + 0.7152 * rgb[index + 1] + 0.0722 * rgb[index + 2]
        for index in range(0, len(rgb), 3)
    ]
    mean = sum(luminances) / pixel_count
    variance = sum((value - mean) ** 2 for value in luminances) / pixel_count
    return CaptureStats(
        width=width,
        height=height,
        mean_luminance=mean,
        luminance_stdev=variance**0.5,
        digest=hashlib.sha256(path.read_bytes()).hexdigest(),
    )


def validate(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    capture_dir = root / CAPTURE_DIR.relative_to(ROOT)

    for map_id in MAP_IDS:
        paths = {
            time_of_day: capture_dir / f"{map_id}_{time_of_day}.png"
            for time_of_day in TIMES_OF_DAY
        }
        stats: dict[str, CaptureStats] = {}
        for time_of_day, path in paths.items():
            rel = path.relative_to(root)
            if not path.is_file():
                errors.append(f"missing P0-053 view3d capture: {rel.as_posix()}")
                continue
            try:
                stats[time_of_day] = capture_stats(path)
            except ValueError as exc:
                errors.append(str(exc))
                continue

            captured = stats[time_of_day]
            if captured.width != EXPECTED_WIDTH or captured.height != EXPECTED_HEIGHT:
                errors.append(
                    f"{rel.as_posix()}: expected {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}, "
                    f"got {captured.width}x{captured.height}"
                )
            if captured.luminance_stdev < MIN_LUMINANCE_STDEV:
                errors.append(
                    f"{rel.as_posix()}: capture looks flat or blank "
                    f"(luminance stdev {captured.luminance_stdev:.2f} < {MIN_LUMINANCE_STDEV})"
                )

        if "day" not in stats or "night" not in stats:
            continue

        day = stats["day"]
        night = stats["night"]
        if day.digest == night.digest:
            errors.append(f"{map_id}: day and night captures must not be identical")
        if day.mean_luminance <= night.mean_luminance:
            errors.append(
                f"{map_id}: day mean luminance ({day.mean_luminance:.1f}) must exceed "
                f"night ({night.mean_luminance:.1f})"
            )
        if day.mean_luminance - night.mean_luminance < MIN_DAY_NIGHT_LUMINANCE_DELTA:
            errors.append(
                f"{map_id}: day/night luminance delta "
                f"({day.mean_luminance - night.mean_luminance:.1f}) "
                f"is below {MIN_DAY_NIGHT_LUMINANCE_DELTA}"
            )
        if day.mean_luminance < MIN_DAY_MEAN_LUMINANCE:
            errors.append(
                f"{map_id}_day.png: mean luminance {day.mean_luminance:.1f} "
                f"is below {MIN_DAY_MEAN_LUMINANCE}"
            )
        if night.mean_luminance > MAX_NIGHT_MEAN_LUMINANCE:
            errors.append(
                f"{map_id}_night.png: mean luminance {night.mean_luminance:.1f} "
                f"exceeds {MAX_NIGHT_MEAN_LUMINANCE}"
            )

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("slice surface capture verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "slice surface capture verification passed "
        f"({len(MAP_IDS)} playable maps x {len(TIMES_OF_DAY)} times of day)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
