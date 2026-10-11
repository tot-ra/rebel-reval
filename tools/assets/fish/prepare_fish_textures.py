#!/usr/bin/env python3
"""Cut a generated side-view fish illustration into a texture and a body profile.

Stage 1 of the fish model pipeline (stage 2 is build_fish_models.py in Blender).
Input: a lateral illustration on a white background, snout to the right
(assets/animals/fish/reference/<species>_leonardo.jpg). Output, per species:

- assets/animals/fish/<species>/<species>_albedo.png: the fish cropped to its
  silhouette, background alpha 0 and edge colour bled outward so mipmaps do not
  pick up a white halo;
- build/fish/<species>_profile.json: the silhouette fitted into the CityFish
  mesh-space box (+X forward, nose at x 0.5, tail tip no further back than
  x -0.78, every point inside y -0.24..0.29), the body outline with the fins
  removed, and the cells of the midplane fin card.

Why the envelope fit: the illustration silhouette includes the fins; the lofted
body must not, or the dorsal fin would become a fat hump. Fins stick outward of
the smooth body line, so an asymmetric smoother of the top and bottom edges
(_asls) settles on the body under them. The fins themselves stay on a flat,
alpha-tested card in the midplane.

Usage: python3 tools/assets/fish/prepare_fish_textures.py [herring perch]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
REFERENCE = ROOT / "assets/animals/fish/reference"
OUT_PROFILE = ROOT / "build/fish"
WORK_WIDTH = 1024
PAD = 6
# Mesh-space box shared with CityFish.fish_transform and its bounds test.
NOSE_X = 0.5
TAIL_X = -0.78
Y_MIN = -0.24
Y_MAX = 0.29
FIN_CELL_PX = 16


def _shift_or(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    # Alternating 4- and 8-neighbourhood steps approximate a disk (octagon).
    out = mask.copy()
    for step in range(radius):
        grown = _shift_or(out)
        if step % 2:
            grown[1:, 1:] |= out[:-1, :-1]
            grown[:-1, :-1] |= out[1:, 1:]
            grown[1:, :-1] |= out[:-1, 1:]
            grown[:-1, 1:] |= out[1:, :-1]
        out = grown
    return out


def _erode(mask: np.ndarray, radius: int) -> np.ndarray:
    return ~_dilate(~mask, radius)


def _flood(seed: np.ndarray, allowed: np.ndarray) -> np.ndarray:
    region = seed & allowed
    while True:
        grown = _shift_or(region) & allowed
        if grown.sum() == region.sum():
            return region
        region = grown


def _fish_mask(rgb: np.ndarray) -> np.ndarray:
    # Background: bright and grey, connected to the image border. Silver
    # highlights inside the body are bright too, but not border-connected.
    bright = rgb.min(axis=2) > 222
    grey = (rgb.max(axis=2) - rgb.min(axis=2)) < 22
    border = np.zeros(bright.shape, bool)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    background = _flood(border, bright & grey)
    fish = ~background
    # Keep the one fish: flood from its centre of mass, dropping specks.
    ys, xs = np.nonzero(fish)
    seed = np.zeros_like(fish)
    seed[int(np.median(ys)), int(np.median(xs))] = True
    return _flood(seed, fish)


def _bleed(rgb: np.ndarray, mask: np.ndarray, steps: int = 24) -> np.ndarray:
    out = rgb.copy()
    known = mask.copy()
    for _ in range(steps):
        acc = np.zeros_like(out)
        count = np.zeros(mask.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted_known = np.roll(known, (dy, dx), axis=(0, 1))
            shifted = np.roll(out, (dy, dx), axis=(0, 1))
            acc += shifted * shifted_known[..., None]
            count += shifted_known
        fill = (~known) & (count > 0)
        out[fill] = acc[fill] / count[fill][:, None]
        known = known | fill
    out[~known] = rgb[mask].mean(axis=0)
    return out


def _asls(edge: np.ndarray, outward: float, lam: float = 8e4, p: float = 0.004) -> np.ndarray:
    """Smooth envelope of one outline edge that ignores outward bumps (fins).

    Asymmetric least squares: a stiff second-difference smoother where samples
    lying outward of the current fit (sign `outward`, in image rows) get weight
    p and inward ones 1 - p, so the fit settles on the body line under the fins.
    """
    n = edge.size
    # D'D of the second difference, built directly (pentadiagonal).
    h = np.zeros((n, n))
    for i in range(n - 2):
        h[i : i + 3, i : i + 3] += np.outer([1.0, -2.0, 1.0], [1.0, -2.0, 1.0])
    h *= lam
    w = np.ones(n)
    fit = edge
    for _ in range(15):
        fit = np.linalg.solve(np.diag(w) + h, w * edge)
        w = np.where((edge - fit) * outward > 0, p, 1.0 - p)
    return fit


def _runs(column: np.ndarray) -> tuple[int, int] | None:
    rows = np.nonzero(column)[0]
    if rows.size == 0:
        return None
    return int(rows[0]), int(rows[-1])


def prepare(species: str) -> dict:
    src = Image.open(REFERENCE / f"{species}_leonardo.jpg").convert("RGB")
    scale = WORK_WIDTH / src.width
    src = src.resize((WORK_WIDTH, round(src.height * scale)), Image.LANCZOS)
    rgb = np.asarray(src).astype(np.float32)
    mask = _fish_mask(rgb)
    # One-pixel trim removes the anti-aliased white fringe of the drawing.
    mask = _erode(mask, 1)
    ys, xs = np.nonzero(mask)
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, mask.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, mask.shape[1])
    mask = mask[y0:y1, x0:x1]
    rgb = rgb[y0:y1, x0:x1]
    height, width = mask.shape

    cols = [_runs(mask[:, x]) for x in range(width)]
    filled = [x for x, run in enumerate(cols) if run]
    tail_px, nose_px = filled[0], filled[-1]
    length_px = nose_px - tail_px
    top_px = min(run[0] for run in cols if run)
    bottom_px = max(run[1] for run in cols if run)
    # Caudal stalk: the shallowest column over the rear part of the fish.
    rear = range(tail_px + int(0.08 * length_px), tail_px + int(0.42 * length_px))
    stalk_px = min(rear, key=lambda x: cols[x][1] - cols[x][0])
    xs_body = np.arange(stalk_px, nose_px + 1)
    raw_top = np.array([cols[x][0] for x in xs_body], np.float64)
    raw_bottom = np.array([cols[x][1] for x in xs_body], np.float64)
    fit_top = _asls(raw_top, -1.0)
    fit_bottom = _asls(raw_bottom, 1.0)
    body = np.zeros_like(mask)
    for i, x in enumerate(xs_body):
        top = int(round(max(fit_top[i], raw_top[i])))
        bottom = int(round(min(fit_bottom[i], raw_bottom[i])))
        body[top : bottom + 1, x] = bottom > top

    # Mesh units per texture pixel: fill the box without crossing it.
    s = min((NOSE_X - TAIL_X) / length_px, (Y_MAX - Y_MIN) / (bottom_px - top_px))
    mid_px = 0.5 * (top_px + bottom_px)
    mid_y = 0.5 * (Y_MAX + Y_MIN)

    def to_mesh(px: float, py: float) -> tuple[float, float]:
        return NOSE_X - (nose_px - px) * s, mid_y + (mid_px - py) * s

    samples = []
    for x in range(stalk_px, nose_px + 1):
        run = _runs(body[:, x])
        if run is None:
            continue
        top, bottom = run
        mx, my_top = to_mesh(x, top)
        _, my_bottom = to_mesh(x, bottom)
        samples.append([mx, my_top, my_bottom])
    # Light smoothing of the outline; the snout keeps its exact tip.
    arr = np.array(samples)
    kernel = np.array([1, 2, 3, 2, 1], np.float32) / 9.0
    for k in (1, 2):
        padded = np.pad(arr[:, k], 2, mode="edge")
        arr[:, k] = np.convolve(padded, kernel, mode="valid")

    cells = []
    for cy in range(0, height, FIN_CELL_PX):
        for cx in range(0, width, FIN_CELL_PX):
            block = mask[cy : cy + FIN_CELL_PX + 1, cx : cx + FIN_CELL_PX + 1]
            if block.any():
                # Clamp to the silhouette box, which is what fits the mesh-space box.
                cells.append(
                    [
                        max(cx, tail_px),
                        max(cy, top_px),
                        min(cx + FIN_CELL_PX, nose_px),
                        min(cy + FIN_CELL_PX, bottom_px),
                    ]
                )

    alpha = (mask * 255).astype(np.uint8)
    colour = _bleed(rgb / 255.0, mask)
    rgba = np.dstack([(colour * 255).clip(0, 255).astype(np.uint8), alpha])
    out_dir = ROOT / f"assets/animals/fish/{species}"
    out_dir.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba).save(out_dir / f"{species}_albedo.png", optimize=True)

    tex_left, tex_top = to_mesh(0, 0)
    tex_right, tex_bottom = to_mesh(width - 1, height - 1)
    profile = {
        "species": species,
        "texture": f"{species}_albedo.png",
        "texture_size": [width, height],
        "mesh_per_px": s,
        # Texture rect in mesh units: uv (0,0) at (left, top), (1,1) at (right, bottom).
        "uv_rect": [tex_left, tex_top, tex_right, tex_bottom],
        "body": arr.round(5).tolist(),
        "fin_cells": [[*to_mesh(a, b), *to_mesh(c, d)] for a, b, c, d in cells],
    }
    OUT_PROFILE.mkdir(parents=True, exist_ok=True)
    (OUT_PROFILE / f"{species}_profile.json").write_text(json.dumps(profile, indent=1))
    # Review plate: silhouette (grey), body after opening (white).
    review = np.where(body, 255, np.where(mask, 110, 20)).astype(np.uint8)
    Image.fromarray(review).save(OUT_PROFILE / f"{species}_body_review.png")
    return profile


def main() -> None:
    for species in sys.argv[1:] or ["herring", "perch"]:
        p = prepare(species)
        xs = [b[0] for b in p["body"]]
        print(
            f"{species}: texture {p['texture_size']}, body x {min(xs):.3f}..{max(xs):.3f}, "
            f"{len(p['fin_cells'])} fin cells"
        )


if __name__ == "__main__":
    main()
