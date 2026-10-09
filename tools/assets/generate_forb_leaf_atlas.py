#!/usr/bin/env python3
"""Draw the leaf-detail atlas for the wild plants of the seamless city (R-1519).

Why: flat single-tone leaves read as low-poly cut-outs. Real dandelion,
plantain, clover and burdock leaves are recognised by their venation (a pale
midrib, plantain's parallel ribs, clover's pale chevron, burdock's quilted vein
net). The leaf silhouettes stay real geometry (CityForbMeshes); this atlas only
adds the interior detail, mapped on UV2 in each leaf's own parameter space.

Encoding: a detail multiplier stored at half scale (128 = x1.0). The shader
multiplies the vertex albedo by texel * 2, so vertex colours keep the gross
tone and this texture adds veins, mottling and margin shading.

Tiles (4 x 2, 256 px each; order is a runtime contract with
scripts/city/city_forb_meshes.gd TILE_*):
  0 dandelion leaf      strip space: u = across (-1..1), v = base..tip
  1 plantain leaf       strip space
  2 white clover leaflet strip space
  3 red clover leaflet  strip space
  4 burdock leaf        polar space: centre = petiole, +v = midrib
  5 neutral (stems, heads, petals)
  6, 7 neutral spare

Deterministic (fixed seeds), numpy + Pillow only.
Usage: python3 tools/assets/generate_forb_leaf_atlas.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vegetation/forbs/forb_leaf_detail.png"
TILE = 256
GRID = (4, 2)


def smooth_noise(seed: int, cells: int, size: int = TILE) -> np.ndarray:
    """Value noise in -1..1: a random grid upsampled bicubically."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 127.5 - 1.0


def line(dist: np.ndarray, width: float) -> np.ndarray:
    """Soft vein profile from a distance field."""
    return np.exp(-((dist / width) ** 2))


def seg_dist(px: np.ndarray, py: np.ndarray, a: tuple, b: tuple) -> np.ndarray:
    """Distance from every pixel to segment a-b."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0.0, 1.0)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def polyline_dist(px, py, pts) -> np.ndarray:
    d = np.full(px.shape, np.inf, dtype=np.float32)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(px, py, a, b))
    return d


def base_field(seed: int) -> np.ndarray:
    """Mottling and fine grain shared by every leaf, as a multiplier near 1."""
    mottle = smooth_noise(seed, 7) * 0.05 + smooth_noise(seed + 1, 23) * 0.035
    grain = smooth_noise(seed + 2, 96) * 0.025
    return 1.0 + mottle + grain


def strip_coords():
    """s across the blade -1..1, t base (0) .. tip (1)."""
    s = np.linspace(-1.0, 1.0, TILE, dtype=np.float32)
    t = np.linspace(0.0, 1.0, TILE, dtype=np.float32)
    return np.meshgrid(s, t)


def tint(mult: np.ndarray, amount: np.ndarray, colour: tuple) -> np.ndarray:
    """Blend a per-channel multiplier toward `colour` (also a multiplier)."""
    out = np.repeat(mult[..., None], 3, axis=2)
    target = np.array(colour, dtype=np.float32)[None, None, :]
    return out * (1.0 - amount[..., None]) + target * amount[..., None]


def dandelion() -> np.ndarray:
    s, t = strip_coords()
    m = base_field(11)
    # Midrib: broad, pale, almost white near the base, fading toward the tip.
    rib_w = 0.07 * (1.0 - 0.7 * t) + 0.015
    rib = line(np.abs(s), rib_w) * (1.0 - 0.45 * t)
    # Lateral veins leave the midrib angled toward the tip, one per lobe-ish step.
    lat = np.zeros_like(s)
    for k in range(14):
        t0 = 0.12 + k * 0.062
        lat = np.maximum(lat, line(np.abs(t - (t0 + 0.11 * np.abs(s))), 0.008) * (np.abs(s) > 0.05))
    m = m * (1.0 - 0.06 * smooth_noise(12, 40) ** 2)
    m = m * (1.0 - 0.10 * np.clip((np.abs(s) - 0.75) / 0.25, 0.0, 1.0))
    out = tint(m, rib * 0.85, (1.55, 1.55, 1.25))
    out = out * (1.0 + 0.10 * lat[..., None])
    return out


def plantain() -> np.ndarray:
    s, t = strip_coords()
    m = base_field(21)
    # Five strong ribs run base to tip (they converge with the blade outline,
    # which is already narrow at both ends in strip space), two faint outer ones.
    veins = np.zeros_like(s)
    for pos, strength, width in ((0.0, 1.0, 0.045), (0.667, 0.85, 0.035), (0.9, 0.35, 0.025)):
        veins = np.maximum(veins, line(np.abs(np.abs(s) - pos), width) * strength)
    # Blade puckers between ribs: shade the troughs next to each rib.
    pucker = 0.5 + 0.5 * np.cos(np.abs(s) * np.pi * 3.0)
    m = m * (1.0 - 0.07 * pucker)
    # Faint cross veinlets.
    cross = line(np.abs(((t * 34.0 + np.abs(s) * 2.0) % 1.0) - 0.5), 0.05) * 0.04
    m = m * (1.0 + cross)
    m = m * (1.0 - 0.08 * np.clip((np.abs(s) - 0.85) / 0.15, 0.0, 1.0))
    return tint(m, veins * 0.6, (1.35, 1.40, 1.12))


def clover(chevron_at: float, chevron_slope: float, chevron_w: float, strength: float, seed: int):
    s, t = strip_coords()
    m = base_field(seed)
    # The pale V (white clover) or crescent (red clover).
    band = np.abs(t - (chevron_at + chevron_slope * np.abs(s) ** 1.3))
    chev = line(band, chevron_w) * (np.abs(s) < 0.92)
    # Fine straight laterals from midrib to margin, angled forward.
    lat = np.zeros_like(s)
    for k in range(16):
        t0 = 0.05 + k * 0.058
        lat = np.maximum(lat, line(np.abs(t - (t0 + 0.30 * np.abs(s))), 0.007))
    rib = line(np.abs(s), 0.025) * (1.0 - t)
    m = m * (1.0 + 0.10 * lat + 0.12 * rib)
    m = m * (1.0 - 0.12 * np.clip((np.abs(s) - 0.8) / 0.2, 0.0, 1.0))
    return tint(m, chev * strength, (1.65, 1.62, 1.45))


def burdock() -> np.ndarray:
    # Polar tile: x along the midrib (0 at the petiole, 1 at the tip), z across.
    u = np.linspace(-1.0, 1.0, TILE, dtype=np.float32)
    z, x = np.meshgrid(u, u)
    m = base_field(41)
    main = polyline_dist(x, z, [(0.0, 0.0), (0.5, 0.01), (1.0, 0.0)])
    veins = line(main, 0.022) * 1.0
    # Strong basal veins fan from the petiole into the heart lobes, and laterals
    # leave the midrib curving toward the tip.
    for side in (-1.0, 1.0):
        for ang, length in ((0.9, 0.85), (1.6, 0.7), (2.3, 0.5)):
            pts = []
            for i in range(9):
                tau = i / 8.0
                a = ang - 0.35 * tau
                pts.append((np.cos(a) * length * tau, side * np.sin(a) * length * tau))
            veins = np.maximum(veins, line(polyline_dist(x, z, pts), 0.016) * 0.85)
        for x0 in (0.18, 0.34, 0.5, 0.66, 0.8):
            length = 0.75 * (1.0 - x0) + 0.08
            pts = []
            for i in range(7):
                tau = i / 6.0
                a = 0.95 - 0.45 * tau
                pts.append((x0 + np.cos(a) * length * tau, side * np.sin(a) * length * tau))
            veins = np.maximum(veins, line(polyline_dist(x, z, pts), 0.012) * 0.7)
    # Quilted areolae: a ridged-noise net of fine veinlets with the blade
    # bulging (darker rims, lighter centres) between them.
    net = np.abs(smooth_noise(42, 20)) + 0.6 * np.abs(smooth_noise(43, 34))
    veinlet = line(net, 0.07)
    m = m * (1.0 + 0.08 * veinlet - 0.05 * np.clip(net, 0.0, 1.0))
    r = np.hypot(x, z)
    m = m * (1.0 - 0.10 * np.clip((r - 0.75) / 0.25, 0.0, 1.0))
    return tint(m, veins * 0.6, (1.40, 1.42, 1.18))


def neutral() -> np.ndarray:
    return np.ones((TILE, TILE, 3), dtype=np.float32)


def main() -> None:
    tiles = [
        dandelion(),
        plantain(),
        clover(0.40, 0.28, 0.035, 0.75, 31),
        clover(0.50, 0.10, 0.07, 0.45, 32),
        burdock(),
        neutral(),
        neutral(),
        neutral(),
    ]
    atlas = np.zeros((TILE * GRID[1], TILE * GRID[0], 3), dtype=np.float32)
    for i, tile in enumerate(tiles):
        r, c = divmod(i, GRID[0])
        atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = tile
    pixels = np.clip(atlas * 128.0, 0, 255).astype(np.uint8)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels).save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
