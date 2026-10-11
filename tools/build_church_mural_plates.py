#!/usr/bin/env python3
"""Paint the ornamental church mural plates (R-1396, CI-04) procedurally.

The ornamental plates are geometry (a cross in rings, a hanging curtain, a vine
band), so they are drawn here instead of generated: deterministic, tileable
and free of the gibberish lettering image models add. Figural plates (Last
Judgement, St Christopher, saints) still need an image generator.

Output: RGBA PNGs in assets/textures/churches/murals/, transparent where the
lime wash shows through, faded and flaking like 14th-century secco on lime.
Usage: build_church_mural_plates.py [--check]
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/textures/churches/murals"
# sRGB earth pigments: red ochre, yellow ochre, green earth, lamp black.
RED = np.array([0.58, 0.22, 0.14])
YELLOW = np.array([0.78, 0.58, 0.3])
GREEN = np.array([0.4, 0.46, 0.33])
BLACK = np.array([0.2, 0.16, 0.13])


def noise(h: int, w: int, cells: int, seed: int, octaves: int = 4) -> np.ndarray:
    """Value noise in [0, 1], periodic in x (the strips tile along the wall)."""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cx = cells * 2**o
        cy = max(1, round(cx * h / w))
        grid = rng.random((cy + 1, cx))
        ys = np.linspace(0, cy, h, endpoint=False)
        xs = np.linspace(0, cx, w, endpoint=False)
        y0, x0 = ys.astype(int), xs.astype(int)
        fy, fx = ys - y0, xs - x0
        fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
        x1 = (x0 + 1) % cx
        a = grid[y0][:, x0]
        b = grid[y0][:, x1]
        c = grid[y0 + 1][:, x0]
        d = grid[y0 + 1][:, x1]
        top = a + (b - a) * fx
        bot = c + (d - c) * fx
        total += amp * (top + (bot - top) * fy[:, None])
        norm += amp
        amp *= 0.5
    return total / norm


def stroke(dist: np.ndarray, width: float, soft: float = 1.5) -> np.ndarray:
    """Coverage of a brush line `width` px wide given a distance field in px."""
    return np.clip((width * 0.5 - dist) / soft + 0.5, 0.0, 1.0)


def finish(rgb: np.ndarray, cover: np.ndarray, seed: int, fade: float) -> Image.Image:
    """Age the paint: uneven pigment, flaking losses, overall fading."""
    h, w = cover.shape
    blot = noise(h, w, 6, seed)
    grain = noise(h, w, 48, seed + 1, 2)
    flake = noise(h, w, 64, seed + 2, 2)
    alpha = cover * (0.66 + 0.34 * blot) * fade
    # Small losses where the paint flaked off the wash, more where it is thin.
    alpha *= np.clip((flake - 0.02 - 0.22 * (1.0 - blot)) * 8.0, 0.0, 1.0)
    rgb = rgb * (0.88 + 0.24 * grain[..., None])
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    return Image.fromarray((img * 255).round().astype(np.uint8))


def consecration_cross(size: int = 512) -> Image.Image:
    """A cross pattee in a double ring: red ochre lines, yellow ochre field."""
    y, x = np.mgrid[0:size, 0:size].astype(float)
    # A slight hand wobble so the rings are not compass-perfect.
    wob = (noise(size, size, 3, 11, 2) - 0.5) * size * 0.012
    cx = x - size / 2 + wob
    cy = y - size / 2 - wob
    r = np.hypot(cx, cy)
    u = size / 2
    rings = np.maximum(stroke(np.abs(r - u * 0.93), u * 0.05), stroke(np.abs(r - u * 0.78), u * 0.035))
    field = (r < u * 0.93).astype(float) * 0.55
    # Arms flare from 0.07 u at the centre to 0.3 u at 0.72 u (cross pattee).
    ax, ay = np.abs(cx), np.abs(cy)
    along, across = np.maximum(ax, ay), np.minimum(ax, ay)
    arm = (along < u * 0.72) & (across < u * 0.07 + along * 0.32)
    arm_cov = arm.astype(float)
    rgb = np.ones((size, size, 3)) * YELLOW
    rgb = rgb * (1 - arm_cov[..., None]) + RED * arm_cov[..., None]
    rgb = rgb * (1 - rings[..., None]) + RED * 0.9 * rings[..., None]
    cover = np.maximum(np.maximum(field, rings), arm_cov * 0.95)
    return finish(rgb, cover, 21, 0.85)


def dado_drapery(w: int = 1024, h: int = 512) -> Image.Image:
    """A painted curtain: rod and rings at the top, folds, scalloped hem.

    Tiles horizontally; one tile is two plate heights of wall.
    """
    y, x = np.mgrid[0:h, 0:w].astype(float)
    u, v = x / w, y / h
    folds = 6
    phase = u * folds * 2 * np.pi
    # Folds swell towards the hem; each fold has a lit crest and a dark trough.
    shade = 0.5 + 0.5 * np.cos(phase + 0.35 * np.sin(phase * 0.5))
    hem = 0.86 + 0.05 * np.abs(np.sin(u * folds * np.pi))
    cloth = (v > 0.06) & (v < hem)
    base = RED * 0.95 + (YELLOW - RED) * 0.25
    rgb = base * (0.55 + 0.6 * shade[..., None])
    # Fold lines in darker red, drawn as thin strokes along the troughs.
    trough = np.abs(((u * folds + 0.5) % 1.0) - 0.5) * w / folds
    lines = stroke(trough, 5.0) * (v > 0.1)
    rgb = rgb * (1 - lines[..., None] * 0.6) + RED * 0.55 * lines[..., None] * 0.6
    # Rod with rings, a hem border in yellow ochre.
    rod = stroke(np.abs(y - h * 0.05), h * 0.018)
    ring = stroke(np.abs(np.hypot((u * folds * 2 % 1.0 - 0.5) * w / folds / 2, y - h * 0.075) - h * 0.018), 3.0)
    border = cloth & (v > hem - 0.035)
    rgb[border] = YELLOW * 0.95
    # Small four-dot rosettes on the crests, as in Gotland dado curtains.
    ru = (u * folds) % 1.0
    rv = (v * 5.0) % 1.0
    dots = stroke(np.hypot((ru - 0.5) * w / folds, (rv - 0.5) * h / 5) - 7.0, 4.0, 1.0)
    dots *= (v > 0.15) & (v < hem - 0.08)
    rgb = rgb * (1 - dots[..., None]) + YELLOW * dots[..., None]
    rgb = rgb * (1 - rod[..., None]) + BLACK * rod[..., None]
    rgb = rgb * (1 - ring[..., None]) + BLACK * ring[..., None]
    cover = np.maximum(cloth.astype(float), np.maximum(rod, ring))
    return finish(rgb, cover, 31, 0.8)


def foliage_band(w: int = 1024, h: int = 128) -> Image.Image:
    """A vine scroll between two ochre rules; tiles horizontally."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    u, v = x / w, y / h
    waves = 4
    stem_v = 0.5 + 0.2 * np.sin(u * waves * 2 * np.pi)
    stem = stroke(np.abs(v - stem_v) * h, 7.0)
    rgb = np.ones((h, w, 3)) * GREEN
    cover = stem.copy()
    # A trefoil leaf in each bay of the wave, alternately above and below.
    bay = (u * waves * 2) % 1.0
    k = np.floor(u * waves * 2)
    side = np.where(k % 2 == 0, -1.0, 1.0)
    lx = (bay - 0.5) * w / (waves * 2)
    ly = (v - 0.5 - side * 0.2) * h
    leaf = np.zeros_like(u)
    for ang in (-0.9, 0.0, 0.9):
        cxl = lx - np.sin(ang) * 17.0
        cyl = ly + side * np.cos(ang) * 14.0
        leaf = np.maximum(leaf, stroke(np.hypot(cxl * 0.85, cyl * 1.1), 34.0))
    rgb = rgb * (1 - leaf[..., None]) + GREEN * 0.85 * leaf[..., None]
    cover = np.maximum(cover, leaf)
    # Red berries on the crossings of the stem with the axis.
    by = (v - 0.5) * h
    bx = (((u * waves * 2 + 0.5) % 1.0) - 0.5) * w / (waves * 2)
    berry = stroke(np.hypot(bx, by), 11.0)
    rgb = rgb * (1 - berry[..., None]) + RED * berry[..., None]
    cover = np.maximum(cover, berry)
    rules = np.maximum(stroke(np.abs(v - 0.06) * h, 7.0), stroke(np.abs(v - 0.94) * h, 7.0))
    rgb = rgb * (1 - rules[..., None]) + RED * 0.9 * rules[..., None]
    cover = np.maximum(cover, rules)
    return finish(rgb, cover, 41, 0.85)


PLATES = {
    "consecration_cross.png": consecration_cross,
    "dado_drapery.png": dado_drapery,
    "foliage_band.png": foliage_band,
}


def main() -> int:
    check = "--check" in sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name, paint in PLATES.items():
        buf = io.BytesIO()
        paint().save(buf, "PNG", optimize=True)
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != buf.getvalue():
                stale.append(name)
            continue
        path.write_bytes(buf.getvalue())
        print("wrote", path)
    if stale:
        print("stale mural plates:", ", ".join(stale), "- run tools/build_church_mural_plates.py")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
