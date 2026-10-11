#!/usr/bin/env python3
"""Assemble the church stained-glass plates into one texture-array strip.

Source plates live in assets/textures/churches/glass/plates/ (512x768 each,
not imported by Godot: the folder has a .gdignore). The strip
assets/textures/churches/glass/glass_plates.png lays them side by side in
LAYERS order; its .import sidecar imports it as a Texture2DArray with one
horizontal slice per plate. The layer index is a stable API: the glazing
programmes in scripts/city/city_stained_glass.gdshader refer to it, so append
new plates at the end, never reorder.

Usage: python3 tools/build_church_glass_plates.py [--check]
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GLASS = ROOT / "assets/textures/churches/glass"
LAYERS = (
    "crucifixion",
    "virgin_child",
    "annunciation",
    "st_olaf",
    "st_nicholas",
    "st_mary",
    "st_catherine",
    "grisaille",
)
SIZE = (512, 768)


def build() -> Image.Image:
    strip = Image.new("RGB", (SIZE[0] * len(LAYERS), SIZE[1]))
    for k, name in enumerate(LAYERS):
        plate = Image.open(GLASS / "plates" / f"{name}.png").convert("RGB")
        if plate.size != SIZE:
            raise SystemExit(f"{name}.png is {plate.size}, expected {SIZE}")
        strip.paste(plate, (k * SIZE[0], 0))
    return strip


def main() -> int:
    strip = build()
    out = GLASS / "glass_plates.png"
    if "--check" in sys.argv:
        same = out.is_file() and Image.open(out).convert("RGB").tobytes() == strip.tobytes()
        print("glass_plates.png up to date" if same else "glass_plates.png is stale: rebuild")
        return 0 if same else 1
    strip.save(out, optimize=True)
    print("saved", out.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
