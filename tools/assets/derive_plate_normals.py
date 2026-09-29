#!/usr/bin/env python3
"""Derive the Kalev smithy interior's tileable texture plates.

The photoreal limestone rubble and floorboard plates ship albedo only. A flat
wall of rubble without relief reads as printed wallpaper (art playbook, material
scale), so the Kalev smithy interior bakes a wrap-around Sobel normal from each
plate's luminance once, offline, instead of calling
Image.bump_map_to_normal_map() on the main thread at load time.

It also prepares the beaten-earth forge floor from its Leonardo candidate
(generated/leonardo/smithy_beaten_earth_v1): quilted seamless with the CO-01
ground helpers, generator lighting divided out, plus a derived normal.

Run from the repository root:
    python3 tools/assets/derive_plate_normals.py
"""

from __future__ import annotations

from pathlib import Path

import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from process_leonardo_terrain_textures import (  # noqa: E402
    _derive_height,
    _derive_normal,
    _make_seamless,
    _resize_tileable,
    _to_image,
)

EARTH_SOURCE = ROOT / "generated" / "leonardo" / "smithy_beaten_earth_v1" / "candidate_2.jpg"
EARTH_SIZE = 1024
OUT_DIR = ROOT / "assets" / "props" / "architecture" / "interiors" / "kalev_smithy_shell" / "textures"
# (source albedo, output stem, strength). Strength scales the height gradient;
# rubble joints are deep, board grain and flag stones are shallow.
PLATES = [
    ("assets/materials/pbr/limestone_rubble/limestone_rubble_albedo.png", "limestone_rubble_normal", 5.0),
    ("assets/materials/pbr/timber_floor/timber_floor_albedo.png", "timber_floor_normal", 2.2),
    ("assets/materials/pbr/smithy_floor/smithy_floor_albedo.png", "smithy_floor_normal", 3.0),
]


def derive(source: Path, strength: float) -> Image.Image:
    rgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.float32) / 255.0
    height = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    # Light blur so single-pixel speckle does not become high-frequency noise.
    blur = (height + np.roll(height, 1, 0) + np.roll(height, -1, 0) + np.roll(height, 1, 1) + np.roll(height, -1, 1)) / 5.0
    dx = (np.roll(blur, -1, 1) - np.roll(blur, 1, 1)) * 0.5
    dy = (np.roll(blur, -1, 0) - np.roll(blur, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(blur)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return Image.fromarray(np.clip((normal * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8))


def beaten_earth() -> None:
    # The candidate's broad mottling is real floor variation (dust, damp), not
    # generator lighting, so it is quilted seamless without de-drifting.
    plate = _make_seamless(Image.open(EARTH_SOURCE).convert("RGB"))
    albedo = _resize_tileable(plate, EARTH_SIZE)
    albedo.save(OUT_DIR / "beaten_earth_albedo.png", optimize=True)
    values = np.asarray(albedo, dtype=np.float64) / 255.0
    normal = _derive_normal(_derive_height(values, 1.2), 3.0)
    _to_image(normal, "RGB").save(OUT_DIR / "beaten_earth_normal.png", optimize=True)
    print("wrote beaten_earth albedo + normal")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    beaten_earth()
    for source, stem, strength in PLATES:
        output = OUT_DIR / f"{stem}.png"
        derive(ROOT / source, strength).save(output, optimize=True)
        print(f"wrote {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
