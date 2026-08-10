#!/usr/bin/env python3
"""Prepare selected Leonardo terrain albedos for the Godot runtime.

The generator output is treated as an authored candidate, not as a drop-in
runtime texture: it is resized with Lanczos and moved to a half-tile phase so
large AI marks do not sit on the wrap seam. The final border pixels are welded
for deterministic repeatability. Runtime terrain resizes these 512px sources to
its existing 128px texture-array tier.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "generated" / "leonardo"
OUTPUTS = {
    "grass": (
        GENERATED / "76bae8e4-00a6-406f-9471-5f8133eca660-1.jpg",
        ROOT / "assets/materials/pbr/grass/grass_albedo.png",
    ),
    "timber_floor": (
        GENERATED / "85f90518-4e44-4457-aa49-bc744568f807-1.jpg",
        ROOT / "assets/materials/pbr/timber_floor/timber_floor_albedo.png",
    ),
    "smithy_floor": (
        GENERATED / "3713e478-8edb-4e36-87c1-88a14fce5b24-1.jpg",
        ROOT / "assets/materials/pbr/smithy_floor/smithy_floor_albedo.png",
    ),
}
TARGET_SIZE = 512


def _weld_edges(image: Image.Image) -> Image.Image:
    """Relocate the candidate's strongest seam, then make both wrap edges equal."""
    image = ImageChops.offset(image, TARGET_SIZE // 2, TARGET_SIZE // 2)
    pixels = image.load()
    for y in range(TARGET_SIZE):
        edge = tuple((pixels[0, y][channel] + pixels[TARGET_SIZE - 1, y][channel]) // 2 for channel in range(3))
        pixels[0, y] = edge
        pixels[TARGET_SIZE - 1, y] = edge
    for x in range(TARGET_SIZE):
        edge = tuple((pixels[x, 0][channel] + pixels[x, TARGET_SIZE - 1][channel]) // 2 for channel in range(3))
        pixels[x, 0] = edge
        pixels[x, TARGET_SIZE - 1] = edge
    return image


def main() -> int:
    for family, (source, destination) in OUTPUTS.items():
        if not source.is_file():
            raise FileNotFoundError(source)
        image = Image.open(source).convert("RGB")
        image = image.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
        image = _weld_edges(image)
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, "PNG", optimize=True)
        print(f"prepared {family}: {destination.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
