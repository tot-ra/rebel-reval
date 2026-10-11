#!/usr/bin/env python3
"""Cut the Leonardo grass sheet into a 2x2 RGBA blade-cluster atlas (R-1103).

Each source quadrant is keyed from its near-white backdrop (alpha from distance
to white, colour un-matted against white so no pale halo survives mipmapping),
cropped to its content, scaled into a 512px cell and bottom-centre aligned so
every cluster root sits on the cell's lower edge (UV.y == 0 at the tuft root).
Cell order: 0 fine meadow, 1 timothy, 2 sedge, 3 dry straw with seed heads.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

CELL = 512
ROOT = Path(__file__).resolve().parent.parent


def key_quadrant(quad: Image.Image) -> Image.Image:
    px = np.asarray(quad.convert("RGB"), dtype=np.float32) / 255.0
    white = np.array([0.975, 0.975, 0.97], dtype=np.float32)
    # Distance from the backdrop; 0.04 floor removes paper noise and soft shadow.
    dist = np.max(white - px, axis=2)
    # Soft shadow under the clump is faint and unsaturated; the ramp starts above it.
    alpha = np.clip((dist - 0.12) / 0.26, 0.0, 1.0) ** 0.85
    # Thin blades blend with the backdrop, so un-matting them yields pale fringes.
    # Take the colour of the nearby solid pixels instead (alpha-weighted blur).
    core = (alpha > 0.7).astype(np.float32)
    blurred = np.zeros_like(px)
    weight = np.zeros(px.shape[:2], dtype=np.float32)
    for radius in (3, 9, 24):
        k = Image.fromarray((core * 255).astype(np.uint8))
        w = np.asarray(k.filter(ImageFilter.BoxBlur(radius)), dtype=np.float32) / 255.0
        chans = [
            np.asarray(
                Image.fromarray((px[..., c] * core * 255).astype(np.uint8)).filter(
                    ImageFilter.BoxBlur(radius)
                ),
                dtype=np.float32,
            )
            / 255.0
            for c in range(3)
        ]
        c3 = np.dstack(chans) / np.maximum(w, 1e-4)[..., None]
        fill = (w > 0.02) & (weight == 0)
        blurred[fill] = c3[fill]
        weight[fill] = 1.0
    colour = np.where((alpha < 0.85)[..., None] & (weight > 0)[..., None], blurred, px)
    out = np.dstack([colour, alpha])
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def main() -> int:
    src = Path(sys.argv[1])
    dest = ROOT / "assets/materials/pbr/grass_blades/grass_blades_atlas.png"
    sheet = Image.open(src)
    half = sheet.width // 2
    atlas = Image.new("RGBA", (CELL * 2, CELL * 2), (0, 0, 0, 0))
    for index in range(4):
        cx, cy = index % 2, index // 2
        quad = sheet.crop((cx * half, cy * half, cx * half + half, cy * half + half))
        keyed = key_quadrant(quad)
        bbox = keyed.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        keyed = keyed.crop(bbox)
        scale = min((CELL - 24) / keyed.width, (CELL - 12) / keyed.height)
        keyed = keyed.resize(
            (max(1, round(keyed.width * scale)), max(1, round(keyed.height * scale))),
            Image.LANCZOS,
        )
        x = index % 2 * CELL + (CELL - keyed.width) // 2
        y = index // 2 * CELL + CELL - keyed.height - 4
        atlas.paste(keyed, (x, y))
    atlas.save(dest)
    print(dest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
