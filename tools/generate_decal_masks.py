#!/usr/bin/env python3
"""Generate soft-edged RGBA alpha masks for P0-157 projected wear decals.

Leonardo MCP was unavailable in this session, so masks are deterministic
procedural blotches (seeded per kind). Output is RGBA where RGB is white and
alpha encodes the stain; MapViewDecals multiplies by DECAL_TINTS at runtime.
"""

from __future__ import annotations

import argparse
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "materials" / "decals"

# kind -> (seed, blob_count, softness, density)
KINDS: dict[str, tuple[int, int, float, float]] = {
    "soot": (15701, 7, 0.42, 0.85),
    "mud": (15702, 5, 0.38, 0.78),
    "blood": (15703, 4, 0.28, 0.70),
    "scorch": (15704, 6, 0.48, 0.80),
    "grime": (15705, 9, 0.55, 0.55),
    "wet_threshold": (15706, 3, 0.60, 0.50),
}

SIZE = 256


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_rgba_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    raw = b""
    stride = width * 4
    for y in range(height):
        raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", zlib.compress(raw, 9))
        + _png_chunk(b"IEND", b"")
    )


class _Rng:
    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF

    def next_u32(self) -> int:
        # xorshift32
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 17) & 0xFFFFFFFF
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def unit(self) -> float:
        return self.next_u32() / 0xFFFFFFFF

    def uniform(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * self.unit()


def _radial(dx: float, dy: float, radius: float, softness: float) -> float:
    if radius <= 1e-6:
        return 0.0
    d = math.hypot(dx, dy) / radius
    if d >= 1.0:
        return 0.0
    # Smoothstep falloff controlled by softness (higher = softer rim).
    edge = max(0.05, min(0.95, softness))
    t = (1.0 - d) / edge
    if t >= 1.0:
        return 1.0
    if t <= 0.0:
        return 0.0
    return t * t * (3.0 - 2.0 * t)


def render_mask(seed: int, blob_count: int, softness: float, density: float) -> bytes:
    rng = _Rng(seed)
    # Accumulate coverage then clamp.
    cover = [0.0] * (SIZE * SIZE)
    for _ in range(blob_count):
        cx = rng.uniform(0.28, 0.72) * (SIZE - 1)
        cy = rng.uniform(0.28, 0.72) * (SIZE - 1)
        rx = rng.uniform(0.18, 0.42) * SIZE
        ry = rng.uniform(0.16, 0.40) * SIZE
        amp = rng.uniform(0.55, 1.0) * density
        # Mild ellipse rotation via shear of axes.
        shear = rng.uniform(-0.35, 0.35)
        for y in range(SIZE):
            for x in range(SIZE):
                dx = (x - cx) / rx
                dy = (y - cy) / ry
                dx2 = dx + shear * dy
                cover[y * SIZE + x] += amp * _radial(dx2, dy, 1.0, softness)

    # Global circular window so quads never show hard square corners.
    mid = (SIZE - 1) * 0.5
    out = bytearray(SIZE * SIZE * 4)
    for y in range(SIZE):
        for x in range(SIZE):
            i = y * SIZE + x
            window = _radial(x - mid, y - mid, mid * 0.98, 0.35)
            alpha = max(0.0, min(1.0, cover[i])) * window
            o = i * 4
            out[o] = 255
            out[o + 1] = 255
            out[o + 2] = 255
            out[o + 3] = int(round(alpha * 255.0))
    return bytes(out)


def generate_all(out_dir: Path = OUT_DIR) -> list[Path]:
    written: list[Path] = []
    for kind, (seed, blobs, soft, dens) in KINDS.items():
        path = out_dir / f"{kind}.png"
        write_rgba_png(path, SIZE, SIZE, render_mask(seed, blobs, soft, dens))
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        default=OUT_DIR,
        help="Output directory for decal masks",
    )
    args = parser.parse_args()
    paths = generate_all(args.out)
    for path in paths:
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
