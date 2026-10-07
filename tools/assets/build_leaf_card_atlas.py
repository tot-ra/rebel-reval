#!/usr/bin/env python3
"""Build the R-1194 leaf-cluster card atlas from Leonardo plates.

Each species plate under generated/leonardo/leaf_cards_v1/<species>/ is a
top-down leaf (or needle) cluster on a white backdrop; prompt.json names the
selected candidate. This tool keys the backdrop to alpha, trims the bare twig
below the foliage, and packs the clusters into a 4x2 RGBA atlas.

Why the colour is normalised: the canopy shader keeps owning species tint,
spring freshness, autumn hue and wetness (R-1187). The atlas therefore stores
only relative detail: every channel is scaled so the mean opaque colour is
approximately neutral 0.5 grey, and the shader multiplies albedo by 2 * texture.rgb.
Transparent texels are set to that neutral grey so mipmaps do not bleed the
white backdrop into leaf edges.

Usage: python3 tools/assets/build_leaf_card_atlas.py [--preview out.png]
Tile order must match MapViewLeafGeometry.CARD_TILES.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "generated/leonardo/leaf_cards_v1"
OUTPUT = ROOT / "assets/materials/pbr/foliage_cards/leaf_card_atlas.png"
TILES = ["birch", "oak", "maple", "linden", "apple", "spruce", "pine"]
GRID = (4, 2)
TILE = 512


def key_alpha(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Alpha from distance to the (near-white) backdrop sampled at the border,
    plus the colour with the backdrop unmixed from partially covered edges."""
    border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3),
                             rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)])
    backdrop = np.median(border, axis=0)
    # Leaves and twigs are darker than the backdrop in at least one channel
    # (blue for greens, all channels for bark), so the max deficit separates them.
    deficit = np.max(backdrop[None, None, :] - rgb, axis=2)
    alpha = np.clip((deficit - 22.0) / 38.0, 0.0, 1.0)
    # Edge texels are leaf blended with white; without unmixing, mipmaps give
    # every leaf and needle a pale halo against the sky.
    cover = np.maximum(alpha, 0.25)[..., None]
    pure = (rgb - (1.0 - cover) * backdrop[None, None, :]) / cover
    return alpha, np.clip(pure, 0.0, 255.0)


def foliage_box(alpha: np.ndarray) -> tuple[int, int, int, int]:
    """Bounding box of the cluster with the long bare twig trimmed off."""
    solid = alpha > 0.5
    if not solid.any():
        raise ValueError("Leaf plate contains no foreground after backdrop keying")
    rows = solid.sum(axis=1)
    cols = np.nonzero(solid.sum(axis=0) > 2)[0]
    filled = np.nonzero(rows > 2)[0]
    if not len(cols) or not len(filled):
        raise ValueError("Leaf plate foreground is too thin for a foliage cluster")
    top, bottom = int(filled[0]), int(filled[-1])
    # Twig rows are a few pixels wide; foliage rows are much wider. Keep a short
    # stub of twig under the lowest wide row so the card still reads as attached.
    wide = np.nonzero(rows > rows.max() * 0.18)[0]
    foliage_bottom = int(wide[-1])
    bottom = min(bottom, foliage_bottom + int((foliage_bottom - top) * 0.10))
    return int(cols[0]), top, int(cols[-1]), bottom


def build_tile(plate: Path) -> Image.Image:
    rgb = np.asarray(Image.open(plate).convert("RGB"), dtype=np.float32)
    alpha, rgb = key_alpha(rgb)
    left, top, right, bottom = foliage_box(alpha)
    side = int(max(right - left, bottom - top) * 1.04) + 1
    centre_x = (left + right) // 2
    # Card UV.y = 0 is the petiole end, so the twig stub sits on the bottom edge.
    x0, y0 = centre_x - side // 2, bottom - side + 2
    canvas_rgb = np.full((side, side, 3), 255.0, dtype=np.float32)
    canvas_a = np.zeros((side, side), dtype=np.float32)
    sx0, sy0 = max(x0, 0), max(y0, 0)
    sx1, sy1 = min(x0 + side, rgb.shape[1]), min(y0 + side, rgb.shape[0])
    canvas_rgb[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = rgb[sy0:sy1, sx0:sx1]
    canvas_a[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = alpha[sy0:sy1, sx0:sx1]
    # Premultiplied resize keeps the white backdrop out of the edge texels.
    premul = np.dstack([canvas_rgb * canvas_a[..., None], canvas_a * 255.0])
    # Resize scalar channels: Pillow RGBA resize premultiplies internally, so
    # feeding it our already premultiplied RGB would multiply alpha twice.
    small = np.stack([
        np.asarray(Image.fromarray(premul[..., channel]).resize(
            (TILE, TILE), Image.Resampling.LANCZOS
        )) for channel in range(4)
    ], axis=2)
    small = np.clip(small, 0.0, 255.0)
    a = small[..., 3] / 255.0
    colour = small[..., :3] / np.maximum(a[..., None], 1.0 / 255.0)
    opaque = a > 0.5
    mean = colour[opaque].mean(axis=0)
    detail = np.clip(colour / mean[None, None, :] * 127.5, 0.0, 255.0)
    # Faint texels (backdrop haze between needles) fall below the shader's
    # scissor anyway; fade them to neutral so mip averaging stays leaf-coloured.
    keep = np.clip((a - 0.3) / 0.3, 0.0, 1.0)[..., None]
    detail = detail * keep + 127.5 * (1.0 - keep)
    return Image.fromarray(np.dstack([detail, a * 255.0]).round().astype(np.uint8))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="optional preview over a dark backdrop")
    args = parser.parse_args()
    atlas = Image.new("RGBA", (GRID[0] * TILE, GRID[1] * TILE), (128, 128, 128, 0))
    for index, species in enumerate(TILES):
        meta = json.loads((SOURCE_DIR / species / "prompt.json").read_text())
        tile = build_tile(ROOT / meta["source"])
        atlas.paste(tile, ((index % GRID[0]) * TILE, (index // GRID[0]) * TILE))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    temp = OUTPUT.with_suffix(".tmp.png")
    atlas.save(temp, optimize=True)
    temp.replace(OUTPUT)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    print(f"{OUTPUT.relative_to(ROOT)} SHA-256 {digest}")
    if args.preview:
        backdrop = Image.new("RGBA", atlas.size, (40, 46, 52, 255))
        tinted = np.asarray(atlas, dtype=np.float32)
        tinted[..., :3] *= np.array([0.55, 0.85, 0.45]) * 2.0 * 0.6
        backdrop.alpha_composite(Image.fromarray(np.clip(tinted, 0, 255).astype(np.uint8)))
        backdrop.convert("RGB").save(args.preview)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
