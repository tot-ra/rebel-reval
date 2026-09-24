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
        GENERATED / "grass_meadow_v3" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/grass/grass_albedo.png",
    ),
    "mud": (
        GENERATED / "mud_yard_v2" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/mud/mud_albedo.png",
    ),
    "limestone_rubble": (
        GENERATED / "city_wall_limestone_v1" / "candidate_1.jpg",
        ROOT / "assets/materials/pbr/limestone_rubble/limestone_rubble_albedo.png",
    ),
    "timber": (
        GENERATED / "timber_beam_v2" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/timber/timber_albedo.png",
    ),
    "timber_floor": (
        GENERATED / "timber_floor_v2" / "candidate_1.jpg",
        ROOT / "assets/materials/pbr/timber_floor/timber_floor_albedo.png",
    ),
    "cobble": (
        GENERATED / "cobble_street_v3" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/cobble/cobble_albedo.png",
    ),
    "smithy_floor": (
        GENERATED / "smithy_flagstone_v3" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/smithy_floor/smithy_floor_albedo.png",
    ),
    "hay": (
        GENERATED / "hay_thatch_v2" / "candidate_2.jpg",
        ROOT / "assets/materials/pbr/hay/hay_albedo.png",
    ),
}
TARGET_SIZE = 512
# Directional or coursed plates must keep their authored phase. A half-tile
# shift moves the original wrap seam into the middle of a wall face or board.
KEEP_SOURCE_PHASE = {
    "limestone_rubble",
    "timber",
    "timber_floor",
    "cobble",
    "smithy_floor",
}


def _weld_edges(image: Image.Image, *, phase_shift: bool) -> Image.Image:
    """Make both wrap edges equal. Optionally move the original seam off the border."""
    if phase_shift:
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
    prepared = 0
    for family, (source, destination) in OUTPUTS.items():
        if not source.is_file():
            print(f"skip {family}: missing {source.relative_to(ROOT)}")
            continue
        image = Image.open(source).convert("RGB")
        image = image.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
        image = _weld_edges(image, phase_shift=family not in KEEP_SOURCE_PHASE)
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, "PNG", optimize=True)
        prepared += 1
        print(f"prepared {family}: {destination.relative_to(ROOT)}")
    if prepared == 0:
        raise FileNotFoundError("no Leonardo terrain sources were available")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
