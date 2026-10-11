#!/usr/bin/env python3
"""Build the species leaf atlas for falling leaves and forest-floor litter.

Input: one Leonardo photo per species, a single leaf (or a needle cluster) on a
white background, petiole down, in generated/leonardo/leaf_species_v1/<cell>.jpg
(gitignored raw sources; generation IDs in generations.csv next to them).

Output: assets/vegetation/leaves/leaf_species_atlas.png, a 4x4 grid of 256 px
cells in CELLS order (scripts/map/view3d/leaf_atlas.gd mirrors it).

WHY grey and not the photo colours: the runtime tints each leaf by species and
date (VegetationPhenology palettes: green in summer, yellow birch, red maple,
brown oak). The atlas therefore stores only the shape (alpha) and the vein and
edge detail as a neutral luminance whose leaf median is about 0.8 linear, so
the tint colour survives the multiply. RGB is dilated into the transparent
margin so mipmaps do not pull a white fringe into the alpha-scissored edge.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "generated" / "leonardo" / "leaf_species_v1"
OUTPUT = ROOT / "assets" / "vegetation" / "leaves" / "leaf_species_atlas.png"

CELLS = [
    "birch", "oak", "maple", "linden",
    "aspen", "alder", "ash", "elm",
    "willow", "rowan", "cherry", "apple",
    "hazel", "hawthorn", "blackthorn", "pine_needles",
]
GRID = 4
CELL = 256
# Share of the cell the leaf's longer side fills; the rest is mip padding.
FILL = 0.88
TARGET_MEDIAN_LINEAR = 0.8


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def cut_out(path: Path) -> Image.Image:
    """RGBA leaf cropped to its bounds. Alpha keys off the white background:
    leaves and needles are low in at least one channel, paper is high in all."""
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    darkest = rgb.min(axis=2)
    alpha = np.clip((0.93 - darkest) / 0.18, 0.0, 1.0)
    # Drop specks: keep only alpha that survives a small blur.
    mask = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))
    alpha = np.asarray(mask, dtype=np.float32) / 255.0
    ys, xs = np.nonzero(alpha > 0.5)
    if xs.size == 0:
        raise SystemExit(f"no leaf found in {path}")
    pad = 4
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, alpha.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, alpha.shape[1])
    lum = srgb_to_linear(rgb) @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    leaf = alpha > 0.9
    lum = lum * (TARGET_MEDIAN_LINEAR / max(float(np.median(lum[leaf])), 1e-3))
    grey = linear_to_srgb(lum)
    out = np.dstack([grey, grey, grey, alpha])[y0:y1, x0:x1]
    return Image.fromarray((out * 255).round().astype(np.uint8))


def dilate_rgb(cell: np.ndarray, passes: int = 24) -> np.ndarray:
    """Push opaque RGB outward into transparent pixels (mip-safe edges)."""
    rgb = cell[..., :3].astype(np.float32)
    known = cell[..., 3] > 128
    for _ in range(passes):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), axis=(0, 1))
            acc += np.roll(rgb, (dy, dx), axis=(0, 1)) * k[..., None]
            cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    fill = rgb[cell[..., 3] > 128].mean(axis=0) if (cell[..., 3] > 128).any() else 200.0
    rgb[~known] = fill
    out = cell.copy()
    out[..., :3] = rgb.round().astype(np.uint8)
    return out


def build(source_dir: Path, output: Path) -> None:
    atlas = np.zeros((GRID * CELL, GRID * CELL, 4), dtype=np.uint8)
    for index, name in enumerate(CELLS):
        leaf = cut_out(source_dir / f"{name}.jpg")
        scale = FILL * CELL / max(leaf.size)
        size = (max(1, round(leaf.width * scale)), max(1, round(leaf.height * scale)))
        leaf = leaf.resize(size, Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.paste(leaf, ((CELL - size[0]) // 2, (CELL - size[1]) // 2))
        col, row = index % GRID, index // GRID
        atlas[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = dilate_rgb(np.asarray(cell))
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas).save(output, optimize=True)
    print(f"wrote {output.relative_to(ROOT)}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=SOURCE_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args(argv)
    build(args.source, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
