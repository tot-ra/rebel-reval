#!/usr/bin/env python3
"""Remove pale matte fringes from an RGBA foliage atlas in place.

Why: alpha-scissor cards sample linear mipmaps, so any light texel colour next
to the cut-out edge (leftover white/blue backdrop) mixes into the visible leaf
rim and reads as a white outline. We shave the alpha edge by `--erode` pixels
and repaint every non-solid texel with the nearest solid leaf colour, so mips
can only blend leaf colour. Tiles are processed separately so colour never
bleeds across atlas cells.

Usage: python3 tools/assets/defringe_atlas.py <atlas.png> --grid 4x2 [--erode 2]
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def defringe_tile(tile: np.ndarray, erode: int) -> np.ndarray:
    rgb = tile[..., :3].astype(np.float32)
    alpha = tile[..., 3]
    if not (alpha > 127).any():
        return tile
    if erode > 0:
        shrunk = Image.fromarray(alpha).filter(ImageFilter.MinFilter(erode * 2 + 1))
        alpha = np.asarray(shrunk.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.uint8)
        alpha = np.minimum(alpha, tile[..., 3])
    # Colour only trusted deep inside the shape; the rim is repainted from it.
    solid_img = Image.fromarray(((alpha > 250) * 255).astype(np.uint8))
    solid = np.asarray(solid_img.filter(ImageFilter.MinFilter(3))) > 0
    known = solid.copy()
    fill = np.where(known[..., None], rgb, 0.0)
    for _ in range(40):
        if known.all():
            break
        padded_f = np.pad(fill, ((1, 1), (1, 1), (0, 0)))
        padded_k = np.pad(known.astype(np.float32), 1)
        acc = np.zeros_like(fill)
        cnt = np.zeros(known.shape, dtype=np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                ys, xs = slice(1 + dy, 1 + dy + known.shape[0]), slice(1 + dx, 1 + dx + known.shape[1])
                acc += padded_f[ys, xs] * padded_k[ys, xs, None]
                cnt += padded_k[ys, xs]
        grow = (~known) & (cnt > 0)
        fill[grow] = acc[grow] / cnt[grow, None]
        known |= grow
    mean = rgb[solid].mean(axis=0) if solid.any() else np.full(3, 128.0)
    fill[~known] = mean
    out = np.dstack([fill, alpha.astype(np.float32)])
    return np.clip(out.round(), 0, 255).astype(np.uint8)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("atlas", type=Path)
    parser.add_argument("--grid", default="1x1")
    parser.add_argument("--erode", type=int, default=2)
    args = parser.parse_args()
    cols, rows = (int(v) for v in args.grid.split("x"))
    image = np.asarray(Image.open(args.atlas).convert("RGBA")).copy()
    h, w = image.shape[0] // rows, image.shape[1] // cols
    for r in range(rows):
        for c in range(cols):
            sl = (slice(r * h, (r + 1) * h), slice(c * w, (c + 1) * w))
            image[sl] = defringe_tile(image[sl], args.erode)
    Image.fromarray(image).save(args.atlas, optimize=True)
    print(f"defringed {args.atlas}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
