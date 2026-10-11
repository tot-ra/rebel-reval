#!/usr/bin/env python3
"""Generate the vegetation texture set procedurally (R-1329, VEGR-1).

Replaces the image-generator leaf-card atlas (Leonardo leaf_cards_v1 plus the
OpenAI needle plates) with textures drawn in code from parametric species data,
so the canopy pipeline carries no external image-generator rights risk.

Every output is a pure function of the parameters below and SEED: numpy PCG64
streams, FFT-filtered noise and a fixed PNG encoder, no timestamps or metadata.
Two runs on the same machine give byte-identical files.

Outputs
- assets/materials/pbr/foliage_cards/leaf_card_atlas.png (4x2 tiles of 512 px,
  RGBA). Runtime contract unchanged from R-1194: tile order is
  MapViewLeafGeometry.CARD_TILES, image bottom is the petiole end (card UV.y = 0),
  RGB is relative detail around neutral 0.5 grey (the canopy shader multiplies
  albedo by 2 * texture and owns species tint, season and wetness), alpha is
  coverage, and transparent texels carry the nearby leaf colour so mipmaps do
  not halo.
- leaf_card_normal.png (OpenGL tangent space, +Y up) and leaf_card_surface.png
  (R roughness, G translucency, B baked occlusion), same layout. Produced for
  VEGR-6 (R-1324); the canopy shader does not sample them yet.
- assets/vegetation/bark/bark_<kind>_{albedo,normal}.png: seamless 512 px plates
  per bark family (birch, oak, grey, pine, spruce, cherry).
- assets/vegetation/ground/ground_<kind>_{albedo,normal}.png: seamless 512 px
  forest-floor plates (moss, leaf_litter, needle_litter).
- assets/vegetation/grain/grain_ear_atlas.png: 4x1 tiles of 256x512 RGBA ears
  (rye, barley, oat, flax), same relative-detail contract as the leaf atlas.

Usage:
  python3 tools/assets/generate_vegetation_atlases.py [--out-root DIR]
      [--compare-old OLD_ATLAS.png --sheets DIR]
--out-root writes the same relative tree elsewhere (tests use a temp dir).
--compare-old writes per-species before/after review sheets (near and
canopy-distance, tinted like the canopy shader) into --sheets.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SEED = 1343
TILE = 512
SS = 2  # supersampling factor for every drawn tile
GRID = (4, 2)
# Tile order is a runtime contract: MapViewLeafGeometry.CARD_TILES.
TILES = ["birch", "oak", "maple", "linden", "apple", "spruce", "pine"]
LEAF_DIR = Path("assets/materials/pbr/foliage_cards")
VEG_DIR = Path("assets/vegetation")
BARK_KINDS = ["birch", "oak", "grey", "pine", "spruce", "cherry"]
GROUND_KINDS = ["moss", "leaf_litter", "needle_litter"]
EARS = ["rye", "barley", "oat", "flax"]
PLATE = 512
EAR_TILE = (256, 512)


# --------------------------------------------------------------------------
# Species parameters. Colours are linear-ish sRGB 0..1 before normalisation;
# only their relative variation survives in the atlas, so they set hue shifts
# between leaves, veins, wear and twig, not the final crown colour.


@dataclass(frozen=True)
class LeafSpecies:
    shape: str
    length: float  # leaf blade length as a fraction of the cluster height
    width: float  # blade width / length
    colour: tuple[float, float, float]
    leaves: int
    layout: str
    petiole: float  # petiole length / blade length
    vein_pairs: int
    vein_slope: float  # how far a secondary vein runs tipward per unit across
    serrations: int
    serration_depth: float
    lobes: int = 0
    lobe_depth: float = 0.0
    roughness: float = 0.6
    translucency: float = 0.75
    wear: float = 0.15  # share of leaves with browned tips or margins
    coverage: float = 0.40  # alpha coverage the tile is tuned to (old tile's value)
    size_scale: float = 1.0  # foliage size multiplier found by --tune for `coverage`
    side_shoots: tuple[tuple[float, int, float, int], ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class NeedleSpecies:
    colour: tuple[float, float, float]
    tip_colour: tuple[float, float, float]
    needle_length: float
    needle_radius: float
    spacing: float
    fascicle: int  # needles per attachment point (1 spruce, 2 pine)
    spread: tuple[float, float]  # needle angle from the shoot, radians
    shoots: tuple[tuple[float, int, float], ...]  # (t on axis, side, length)
    curve: float
    roughness: float
    translucency: float
    coverage: float = 0.40
    size_scale: float = 1.0


LEAVES: dict[str, LeafSpecies] = {
    # Silver birch: small deltoid leaves, double-serrate, alternate on fine
    # branched twigs; several short side shoots carry the cluster.
    "birch": LeafSpecies(
        shape="deltoid", length=0.15, width=0.70, colour=(0.40, 0.56, 0.20), leaves=15,
        layout="alternate", petiole=0.35, vein_pairs=7, vein_slope=0.75, serrations=16,
        serration_depth=0.07, roughness=0.55, translucency=0.85, wear=0.10, coverage=0.34, size_scale=2.1,
        side_shoots=((0.22, 1, 0.50, 5), (0.34, -1, 0.60, 6), (0.52, 1, 0.55, 5),
                     (0.70, -1, 0.40, 4)),
    ),
    # Pedunculate oak: obovate, 5 rounded lobes a side, near-sessile, crowded
    # into rosettes at the shoot tip.
    "oak": LeafSpecies(
        shape="lobed", length=0.33, width=0.62, colour=(0.30, 0.43, 0.16), leaves=9,
        layout="rosette", petiole=0.05, vein_pairs=6, vein_slope=0.55, serrations=0,
        serration_depth=0.0, lobes=4, lobe_depth=0.42, roughness=0.62, translucency=0.62,
        wear=0.25, coverage=0.45, size_scale=2.6,
    ),
    # Norway maple: palmate, five pointed lobes, long petioles, opposite pairs.
    "maple": LeafSpecies(
        shape="palmate", length=0.36, width=1.0, colour=(0.34, 0.52, 0.18), leaves=5,
        layout="opposite", petiole=0.30, vein_pairs=5, vein_slope=0.0, serrations=0,
        serration_depth=0.0, lobes=5, lobe_depth=0.55, roughness=0.5, translucency=0.8,
        wear=0.12, coverage=0.41, size_scale=3.6,
    ),
    # Small-leaved linden: cordate, oblique base, fine serration, two-ranked.
    "linden": LeafSpecies(
        shape="cordate", length=0.24, width=0.92, colour=(0.33, 0.50, 0.19), leaves=12,
        layout="distichous", petiole=0.40, vein_pairs=6, vein_slope=0.6, serrations=24,
        serration_depth=0.035, roughness=0.5, translucency=0.82, wear=0.12, coverage=0.47, size_scale=1.9,
        side_shoots=((0.30, -1, 0.50, 4), (0.50, 1, 0.45, 4)),
    ),
    # Apple: elliptic, finely crenate, clustered on short spurs.
    "apple": LeafSpecies(
        shape="elliptic", length=0.21, width=0.55, colour=(0.31, 0.47, 0.18), leaves=12,
        layout="spurs", petiole=0.30, vein_pairs=8, vein_slope=0.7, serrations=30,
        serration_depth=0.025, roughness=0.58, translucency=0.7, wear=0.18, coverage=0.39, size_scale=3.0,
    ),
}

NEEDLES: dict[str, NeedleSpecies] = {
    # Norway spruce: short stiff single needles around every shoot, side shoots
    # alternate at a forward angle, pale new growth at the shoot tips.
    "spruce": NeedleSpecies(
        colour=(0.15, 0.27, 0.13), tip_colour=(0.21, 0.35, 0.15), needle_length=0.050,
        needle_radius=0.0042, spacing=0.0080, fascicle=1, spread=(0.80, 1.30),
        shoots=((0.12, -1, 0.46), (0.20, 1, 0.48), (0.30, -1, 0.44), (0.40, 1, 0.42),
                (0.50, -1, 0.36), (0.60, 1, 0.32), (0.70, -1, 0.25), (0.79, 1, 0.19),
                (0.87, -1, 0.12)),
        curve=0.05, roughness=0.45, translucency=0.35, coverage=0.39, size_scale=3.3,
    ),
    # Scots pine: long twisted needles in pairs, splaying forward from the
    # shoot, blue-green, a whorl of side shoots at the base.
    "pine": NeedleSpecies(
        colour=(0.25, 0.36, 0.24), tip_colour=(0.30, 0.42, 0.26), needle_length=0.21,
        needle_radius=0.0085, spacing=0.008, fascicle=2, spread=(0.30, 0.95),
        shoots=((0.14, -1, 0.58), (0.16, 1, 0.56), (0.20, -1, 0.42), (0.22, 1, 0.44),
                (0.40, -1, 0.34), (0.44, 1, 0.32)),
        curve=0.18, roughness=0.42, translucency=0.30, coverage=0.52, size_scale=1.8,
    ),
}

TWIG = (0.30, 0.22, 0.15)


# --------------------------------------------------------------------------
# Raster canvas: premultiplied "over" compositing of anti-aliased shapes.


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.w, self.h = width, height
        self.rgb = np.zeros((height, width, 3), dtype=np.float64)
        self.alpha = np.zeros((height, width), dtype=np.float64)
        self.height = np.zeros((height, width), dtype=np.float64)
        self.rough = np.zeros((height, width), dtype=np.float64)
        self.trans = np.zeros((height, width), dtype=np.float64)
        self.occ = np.ones((height, width), dtype=np.float64)

    def window(self, x0: float, y0: float, x1: float, y1: float):
        xa, xb = max(int(math.floor(x0)), 0), min(int(math.ceil(x1)) + 1, self.w)
        ya, yb = max(int(math.floor(y0)), 0), min(int(math.ceil(y1)) + 1, self.h)
        if xa >= xb or ya >= yb:
            return None
        ys, xs = np.mgrid[ya:yb, xa:xb].astype(np.float64)
        return (slice(ya, yb), slice(xa, xb)), xs + 0.5, ys + 0.5

    def shade(self, win, cover: np.ndarray, strength: float) -> None:
        """Darken what is already drawn under a soft contact shadow."""
        sl = win
        self.rgb[sl] *= (1.0 - strength * cover * self.alpha[sl])[..., None]
        self.occ[sl] *= 1.0 - strength * cover * self.alpha[sl]

    def paint(self, win, cover: np.ndarray, rgb: np.ndarray, height: np.ndarray,
              rough: np.ndarray, trans: np.ndarray) -> None:
        sl = win
        c = cover[..., None]
        self.rgb[sl] = rgb * c + self.rgb[sl] * (1.0 - c)
        self.height[sl] = height * cover + self.height[sl] * (1.0 - cover)
        self.rough[sl] = rough * cover + self.rough[sl] * (1.0 - cover)
        self.trans[sl] = trans * cover + self.trans[sl] * (1.0 - cover)
        self.occ[sl] = 1.0 * cover + self.occ[sl] * (1.0 - cover)
        self.alpha[sl] = cover + self.alpha[sl] * (1.0 - cover)


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def periodic_noise(rng: np.random.Generator, shape: tuple[int, int], wavelength: float,
                   stretch: float = 1.0) -> np.ndarray:
    """Seamless Gaussian-filtered noise (FFT, so it tiles exactly), unit std.
    `stretch` > 1 elongates features along y."""
    h, w = shape
    white = rng.standard_normal(shape)
    ky = np.fft.fftfreq(h)[:, None] * stretch
    kx = np.fft.fftfreq(w)[None, :]
    sigma = 1.0 / max(wavelength, 1.0)
    filt = np.exp(-(kx * kx + ky * ky) / (2.0 * sigma * sigma))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out -= out.mean()
    return out / max(out.std(), 1e-9)


def fbm(rng: np.random.Generator, shape: tuple[int, int], wavelength: float,
        octaves: int = 4, stretch: float = 1.0, gain: float = 0.5) -> np.ndarray:
    total = np.zeros(shape)
    amp = 1.0
    for octave in range(octaves):
        total += amp * periodic_noise(rng, shape, wavelength / (2 ** octave), stretch)
        amp *= gain
    return total / max(total.std(), 1e-9)


def periodic_voronoi(rng: np.random.Generator, size: int, count: int,
                     aspect: float = 1.0) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """F1, F2 distances (in cell units) and nearest-cell id on a wrapping square.
    aspect > 1 stretches cells along y."""
    points = rng.uniform(0.0, 1.0, (count, 2))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) / size
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    ident = np.zeros((size, size), dtype=np.int64)
    scale = math.sqrt(count)
    for index, (px, py) in enumerate(points):
        dx = np.abs(xs - px)
        dx = np.minimum(dx, 1.0 - dx)
        dy = np.abs(ys - py)
        dy = np.minimum(dy, 1.0 - dy) / aspect
        d = np.sqrt(dx * dx + dy * dy) * scale
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ident = np.where(closer, index, ident)
        f1 = np.where(closer, d, f1)
    return f1, f2, ident


# --------------------------------------------------------------------------
# Leaf outlines: signed distance-like value in leaf-length units, > 0 inside.
# u runs 0 (petiole end) to 1 (tip) along the midrib, v across it.


def _serrate(w: np.ndarray, u: np.ndarray, sp: LeafSpecies) -> np.ndarray:
    if sp.serrations <= 0:
        return w
    teeth = np.mod(u * sp.serrations, 1.0)
    # Forward-pointing teeth; birch adds a second, smaller row (double serrate).
    tooth = teeth ** 1.6
    if sp.shape == "deltoid":
        tooth = 0.7 * tooth + 0.3 * np.mod(u * sp.serrations * 2.0, 1.0) ** 1.6
    return w * (1.0 - sp.serration_depth * tooth * smoothstep(0.05, 0.2, u))


def leaf_half_width(u: np.ndarray, v: np.ndarray, sp: LeafSpecies) -> np.ndarray:
    uc = np.clip(u, 0.0, 1.0)
    half = sp.width * 0.5
    if sp.shape == "elliptic":
        w = half * np.sin(np.pi * uc) ** 0.85 * (1.0 + 0.12 * (0.5 - uc))
        w *= 1.0 - 0.35 * smoothstep(0.82, 1.0, uc)
    elif sp.shape == "deltoid":
        rise = np.clip(uc / 0.28, 0.0, 1.0) ** 0.55
        fall = np.clip((1.0 - uc) / 0.72, 0.0, 1.0) ** 1.15
        w = half * rise * fall * 1.05
    elif sp.shape == "cordate":
        w = half * np.sin(np.pi * (0.10 + 0.90 * uc)) ** 0.75
        w *= 1.0 - 0.45 * smoothstep(0.78, 1.0, uc)
        # Oblique heart base: one side reaches lower and wider.
        w *= np.where(v > 0.0, 1.07, 0.95)
    elif sp.shape == "lobed":
        # Obovate envelope, widest two thirds up, as in pedunculate oak.
        envelope = half * 1.95 * uc ** 0.7 * (1.0 - uc) ** 0.35
        # Broad rounded lobes separated by narrow sinuses; the sides are out of
        # phase so lobes alternate instead of pairing.
        offset = np.where(v > 0.0, 0.0, 0.5)
        position = np.mod(sp.lobes * uc + 0.15 + offset, 1.0)
        sinus = np.exp(-((position - 0.5) / 0.11) ** 2) * smoothstep(0.08, 0.25, uc)
        w = envelope * (1.0 - sp.lobe_depth * sinus)
        # Small auricles at the base, typical for pedunculate oak.
        w += half * 0.22 * np.exp(-((uc - 0.04) / 0.035) ** 2)
    else:
        raise ValueError(sp.shape)
    w = _serrate(w, uc, sp)
    return np.where((u < 0.0) | (u > 1.0), -1.0, w)


def palmate_distance(u: np.ndarray, v: np.ndarray, sp: LeafSpecies) -> np.ndarray:
    cx = 0.40
    du, dv = u - cx, v
    r = np.sqrt(du * du + dv * dv)
    theta = np.arctan2(dv, du)
    angles = np.array([0.0, 1.0, -1.0, 2.0, -2.0])
    reach = np.array([0.60, 0.56, 0.56, 0.40, 0.40])
    radius = np.full(u.shape, 0.26)
    for angle, length in zip(angles, reach):
        delta = np.abs(np.angle(np.exp(1j * (theta - angle))))
        # Broad lobe with rounded shoulders, a drawn-out point at the tip and
        # one large tooth either side (Norway maple, not a star).
        lobe = length * np.clip(1.0 - delta / 0.62, 0.0, 1.0) ** 0.55
        tip = 0.10 * length * np.exp(-(delta / 0.07) ** 2)
        teeth = 0.10 * length * np.exp(-((delta - 0.30) / 0.045) ** 2)
        radius = np.maximum(radius, lobe + tip + teeth)
    # Heart-shaped base sinus around the petiole.
    radius *= 1.0 - 0.55 * smoothstep(2.55, 3.05, np.abs(theta))
    return radius - r


def draw_capsule(canvas: Canvas, p0, p1, r0: float, r1: float, colour, height: float,
                 rough: float, trans: float, shadow: float = 0.0) -> None:
    x0, y0 = p0
    x1, y1 = p1
    pad = max(r0, r1) + 2.0
    win = canvas.window(min(x0, x1) - pad, min(y0, y1) - pad, max(x0, x1) + pad,
                        max(y0, y1) + pad)
    if win is None:
        return
    sl, xs, ys = win
    dx, dy = x1 - x0, y1 - y0
    length2 = max(dx * dx + dy * dy, 1e-9)
    t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / length2, 0.0, 1.0)
    px, py = x0 + t * dx, y0 + t * dy
    dist = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
    radius = r0 + (r1 - r0) * t
    cover = np.clip(radius - dist + 0.5, 0.0, 1.0)
    if not cover.any():
        return
    if shadow > 0.0:
        canvas.shade(sl, np.clip(radius * 1.8 - dist, 0.0, 1.0) * 0.7, shadow)
    across = np.clip(dist / np.maximum(radius, 1e-6), 0.0, 1.0)
    dome = np.sqrt(np.clip(1.0 - across * across, 0.0, 1.0))
    rgb = np.asarray(colour)[None, None, :] * (0.78 + 0.30 * dome)[..., None]
    canvas.paint(sl, cover, rgb, height + 0.6 * dome * radius / 6.0,
                 np.full(cover.shape, rough), np.full(cover.shape, trans))


def draw_leaf(canvas: Canvas, rng: np.random.Generator, sp: LeafSpecies, base,
              angle: float, length: float, depth: float, mottle: np.ndarray,
              unit: float = SS) -> None:
    bx, by = base
    reach = length * (0.75 if sp.shape == "palmate" else 0.62) + 3.0
    cx = bx + math.cos(angle) * length * 0.45
    cy = by + math.sin(angle) * length * 0.45
    win = canvas.window(cx - reach - 8, cy - reach - 8, cx + reach + 8, cy + reach + 8)
    if win is None:
        return
    sl, xs, ys = win
    ca, sa = math.cos(angle), math.sin(angle)

    def coords(ox: float = 0.0, oy: float = 0.0):
        dx, dy = xs - ox - bx, ys - oy - by
        return (dx * ca + dy * sa) / length, (-dx * sa + dy * ca) / length

    def distance(u: np.ndarray, v: np.ndarray) -> np.ndarray:
        if sp.shape == "palmate":
            return palmate_distance(u, v, sp)
        return leaf_half_width(u, v, sp) - np.abs(v)

    u, v = coords()
    d = distance(u, v)
    cover = np.clip(d * length + 0.5, 0.0, 1.0)
    if not cover.any():
        return
    # Soft contact shadow cast down-right onto what is already drawn.
    su, sv = coords(length * 0.035, length * 0.05)
    shadow = smoothstep(-0.05, 0.04, distance(su, sv))
    canvas.shade(sl, shadow, 0.38)

    tone = np.array(sp.colour) * (1.0 + rng.normal(0.0, 0.06, 3))
    tone *= rng.uniform(0.86, 1.10) * (0.78 + 0.22 * depth)
    # Yellower or bluer leaves: a per-leaf hue swing that survives normalisation.
    tone *= np.array([1.0 + rng.uniform(-0.06, 0.08), 1.0, 1.0 + rng.uniform(-0.08, 0.04)])
    if sp.shape == "palmate":
        du, dv = u - 0.40, v
        theta = np.arctan2(dv, du)
        r = np.sqrt(du * du + dv * dv)
        vein = np.zeros(u.shape)
        for lobe_angle in (0.0, 1.0, -1.0, 2.0, -2.0):
            delta = np.angle(np.exp(1j * (theta - lobe_angle)))
            off = np.abs(np.sin(delta)) * r * length
            vein = np.maximum(vein, np.clip(1.6 - off, 0.0, 1.0) * (np.abs(delta) < 1.2))
        midrib = vein
        width_norm = np.clip(r / 0.6, 0.0, 1.0)
        fold = np.sin(theta * 2.5) * 0.5
        secondary = np.zeros(u.shape)
    else:
        half = np.maximum(leaf_half_width(u, v, sp), 1e-4)
        width_norm = np.clip(np.abs(v) / half, 0.0, 1.0)
        rib_px = (1.6 + 1.6 * (1.0 - np.clip(u, 0, 1))) * unit * 0.5
        midrib = np.clip(rib_px - np.abs(v) * length + 0.5, 0.0, 1.0)
        fold = np.sign(v) * width_norm
        q = (u - np.abs(v) * sp.vein_slope) * sp.vein_pairs
        vein_dist = np.abs(q - np.round(q)) / sp.vein_pairs * length
        secondary = np.clip(1.1 * unit * 0.5 - vein_dist + 0.5, 0.0, 1.0)
        secondary *= smoothstep(0.98, 0.6, width_norm) * smoothstep(0.02, 0.12, u)
    dome = 1.0 - width_norm ** 2
    light = (0.90 + 0.10 * dome) * (1.0 - 0.07 * fold)
    rgb = tone[None, None, :] * light[..., None]
    rgb *= (1.0 + 0.06 * mottle[sl])[..., None]
    rgb = rgb * (1.0 - midrib[..., None] * 0.25) + np.array([0.62, 0.66, 0.36]) * tone.mean() \
        / 0.36 * midrib[..., None] * 0.25
    rgb *= (1.0 + 0.07 * secondary)[..., None]
    if rng.uniform() < sp.wear:
        wear = smoothstep(0.035, 0.0, d) * 0.6 + smoothstep(0.86, 1.0, u) * 0.5
        wear = np.clip(wear * rng.uniform(0.5, 1.0), 0.0, 1.0)
        rgb = rgb * (1.0 - wear[..., None]) + np.array([0.42, 0.33, 0.17])[None, None, :] \
            * wear[..., None] * tone.mean() / 0.33
    height = 0.6 + depth * 0.5 + 0.35 * dome - 0.10 * secondary + 0.06 * midrib
    rough = sp.roughness + 0.12 * secondary + 0.05 * mottle[sl]
    trans = sp.translucency * (1.0 - 0.45 * secondary - 0.6 * midrib)
    canvas.paint(sl, cover, rgb, height, rough, trans)


# --------------------------------------------------------------------------
# Cluster layouts. Coordinates are in tile units (0..1, y down); the twig enters
# at the bottom centre so the stub sits on the petiole edge of the card.


def axis_points(rng: np.random.Generator, start, end, bend: float, count: int = 24):
    t = np.linspace(0.0, 1.0, count)
    sx, sy = start
    ex, ey = end
    nx, ny = -(ey - sy), ex - sx
    norm = math.hypot(nx, ny) or 1.0
    wobble = bend * np.sin(np.pi * t) + 0.25 * bend * np.sin(2.0 * np.pi * t + rng.uniform(0, 6))
    xs = sx + (ex - sx) * t + nx / norm * wobble
    ys = sy + (ey - sy) * t + ny / norm * wobble
    return np.stack([xs, ys], axis=1)


def point_on(points: np.ndarray, t: float):
    index = t * (len(points) - 1)
    lo = int(math.floor(index))
    hi = min(lo + 1, len(points) - 1)
    f = index - lo
    p = points[lo] * (1 - f) + points[hi] * f
    d = points[hi] - points[lo] if hi != lo else points[lo] - points[lo - 1]
    return p, math.atan2(d[1], d[0])


@dataclass
class LeafOp:
    attach: tuple[float, float]
    angle: float
    length: float
    depth: float


def leaf_layout(rng: np.random.Generator, sp: LeafSpecies, mult: float = 1.0):
    """Return twig polylines (points, base radius) and leaf ops in tile units."""
    twigs = []
    leaves: list[LeafOp] = []
    main = axis_points(rng, (0.5, 1.0), (0.5 + rng.uniform(-0.06, 0.06), 0.18), 0.04)
    twigs.append((main, 0.010))
    size = sp.length * mult

    def leaf_at(axis, t, side, spread, scale, depth):
        p, heading = point_on(axis, t)
        angle = heading + side * spread
        leaves.append(LeafOp((float(p[0]), float(p[1])), angle, size * scale, depth))

    if sp.layout in ("alternate", "distichous"):
        n = sp.leaves
        for i in range(n):
            t = 0.20 + 0.72 * i / max(n - 1, 1)
            side = 1 if i % 2 else -1
            spread = rng.uniform(0.55, 0.95) if sp.layout == "alternate" else rng.uniform(0.95, 1.25)
            scale = (0.72 + 0.38 * math.sin(math.pi * min(t + 0.15, 1.0))) * rng.uniform(0.9, 1.08)
            leaf_at(main, t, side, spread, scale, rng.uniform(0.3, 1.0))
        leaf_at(main, 0.985, 0, rng.uniform(-0.1, 0.1), 0.85, 1.0)
        for t, side, rel, count in sp.side_shoots:
            p, heading = point_on(main, t)
            angle = heading + side * rng.uniform(0.6, 0.85)
            end = (p[0] + math.cos(angle) * rel * 0.55, p[1] + math.sin(angle) * rel * 0.55)
            shoot = axis_points(rng, tuple(p), end, 0.02, 12)
            twigs.append((shoot, 0.006))
            for j in range(count):
                tj = 0.25 + 0.70 * j / max(count - 1, 1)
                leaf_at(shoot, tj, 1 if j % 2 else -1, rng.uniform(0.6, 1.0),
                        rng.uniform(0.75, 0.95), rng.uniform(0.0, 0.8))
    elif sp.layout == "opposite":
        for t, scale in ((0.22, 0.62), (0.40, 0.76), (0.56, 0.86), (0.72, 0.92)):
            for side in (-1, 1):
                leaf_at(main, t, side, rng.uniform(0.55, 0.80), scale * rng.uniform(0.92, 1.05),
                        rng.uniform(0.2, 0.7))
        leaf_at(main, 0.98, 0, rng.uniform(-0.12, 0.12), 1.0, 1.0)
    elif sp.layout == "rosette":
        for t, side in ((0.36, -1), (0.48, 1)):
            leaf_at(main, t, side, rng.uniform(0.9, 1.2), rng.uniform(0.6, 0.72), 0.2)
        count = sp.leaves - 2
        tip, heading = point_on(main, 0.93)
        for i in range(count):
            spread = -1.65 + 3.3 * i / max(count - 1, 1) + rng.uniform(-0.12, 0.12)
            leaves.append(LeafOp((float(tip[0]), float(tip[1])), heading + spread,
                                 size * rng.uniform(0.72, 1.0) * (1.0 - 0.18 * abs(spread) / 1.65),
                                 0.35 + 0.65 * (1.0 - abs(spread) / 1.65)))
    elif sp.layout == "spurs":
        for t, side in ((0.32, -1), (0.55, 1), (0.80, -1)):
            p, heading = point_on(main, t)
            angle = heading + side * 0.9
            spur_end = (p[0] + math.cos(angle) * 0.05, p[1] + math.sin(angle) * 0.05)
            twigs.append((axis_points(rng, tuple(p), spur_end, 0.0, 4), 0.007))
            for k in range(4):
                spread = -1.1 + 2.2 * k / 3 + rng.uniform(-0.15, 0.15)
                leaves.append(LeafOp(spur_end, angle + spread, size * rng.uniform(0.8, 1.05),
                                     rng.uniform(0.2, 1.0)))
        tip, heading = point_on(main, 0.97)
        for spread in (-0.5, 0.0, 0.5):
            leaves.append(LeafOp((float(tip[0]), float(tip[1])), heading + spread,
                                 size * rng.uniform(0.85, 1.0), 1.0))
    else:
        raise ValueError(sp.layout)
    leaves.sort(key=lambda op: op.depth)
    return twigs, leaves


def fit_transform(points: list[tuple[float, float]]):
    """Scale and shift tile-unit geometry so the cluster fills the card while
    the twig still enters at the bottom centre."""
    xs = np.array([p[0] for p in points])
    ys = np.array([p[1] for p in points])
    top = ys.min()
    half_span = max(abs(xs.min() - 0.5), abs(xs.max() - 0.5))
    scale = min(0.95 / max(1.0 - top, 1e-3), 0.47 / max(half_span, 1e-3))

    def apply(p):
        return (0.5 + (p[0] - 0.5) * scale, 1.0 - (1.0 - p[1]) * scale)

    return apply, scale


def leaf_extent_points(sp: LeafSpecies, op: LeafOp):
    """Outline sample points of one leaf (tile units) for card fitting."""
    pts = []
    pet = sp.petiole * op.length
    base = (op.attach[0] + math.cos(op.angle) * pet, op.attach[1] + math.sin(op.angle) * pet)
    if sp.shape == "palmate":
        # Lobe tips around the blade centre (see palmate_distance), plus margin.
        centre = (base[0] + math.cos(op.angle) * op.length * 0.40,
                  base[1] + math.sin(op.angle) * op.length * 0.40)
        for lobe, reach in ((0.0, 0.60), (1.0, 0.56), (-1.0, 0.56), (2.0, 0.40), (-2.0, 0.40)):
            radius = reach * 1.12 * op.length
            pts.append((centre[0] + math.cos(op.angle + lobe) * radius,
                        centre[1] + math.sin(op.angle + lobe) * radius))
        return pts
    for a in (-0.5, -0.25, 0.0, 0.25, 0.5):
        ang = op.angle + a * 0.6
        pts.append((base[0] + math.cos(ang) * op.length * (1 - abs(a) * 0.4),
                    base[1] + math.sin(ang) * op.length * (1 - abs(a) * 0.4)))
    return pts


def draw_broadleaf_tile(species: str, size: int = TILE * SS, mult: float = 1.0) -> Canvas:
    sp = LEAVES[species]
    rng = species_rng("leaf", species)
    unit = size / TILE
    canvas = Canvas(size, size)
    twigs, leaves = leaf_layout(rng, sp, mult)
    extent = [tuple(p) for axis, _ in twigs for p in axis]
    for op in leaves:
        extent.extend(leaf_extent_points(sp, op))
    fit, scale = fit_transform(extent)
    mottle = fbm(rng, (size, size), 11.0 * unit, 4)
    for axis, radius in twigs:
        pts = [fit(tuple(p)) for p in axis]
        for i in range(len(pts) - 1):
            taper = 1.0 - 0.55 * i / len(pts)
            r = radius * scale * size * taper
            draw_capsule(canvas, (pts[i][0] * size, pts[i][1] * size),
                         (pts[i + 1][0] * size, pts[i + 1][1] * size), r, r * 0.97, TWIG,
                         0.2, 0.8, 0.05)
    for op in leaves:
        attach = fit(op.attach)
        length = op.length * scale * size
        pet = sp.petiole * length
        base = (attach[0] * size + math.cos(op.angle) * pet,
                attach[1] * size + math.sin(op.angle) * pet)
        if pet > 1.0:
            petiole = (np.array(sp.colour) + np.array(TWIG)) * 0.5
            draw_capsule(canvas, (attach[0] * size, attach[1] * size), base, 1.0 * unit,
                         0.8 * unit, tuple(petiole), 0.4 + op.depth * 0.5, 0.6, 0.3)
        draw_leaf(canvas, rng, sp, base, op.angle, length, op.depth, mottle, unit)
    return canvas


def draw_needle_tile(species: str, size: int = TILE * SS, mult: float = 1.0) -> Canvas:
    sp = NEEDLES[species]
    rng = species_rng("leaf", species)
    canvas = Canvas(size, size)
    main = axis_points(rng, (0.5, 1.0), (0.5 + rng.uniform(-0.04, 0.04), 0.05), 0.03, 32)
    shoots = [(main, 0.012)]
    for t, side, length in sp.shoots:
        p, heading = point_on(main, t)
        angle = heading + side * rng.uniform(0.62, 0.85)
        end = (p[0] + math.cos(angle) * length, p[1] + math.sin(angle) * length)
        shoots.append((axis_points(rng, tuple(p), end, side * 0.02, 20), 0.007))
    needles = []
    for axis, radius in shoots:
        lengths = np.sqrt(np.sum(np.diff(axis, axis=0) ** 2, axis=1))
        total = float(lengths.sum())
        steps = max(int(total / sp.spacing), 2)
        for i in range(steps):
            t = (i + rng.uniform(0.0, 0.6)) / steps
            p, heading = point_on(axis, min(t, 1.0))
            near_tip = smoothstep(0.65, 1.0, np.array(t)).item()
            for side in (-1, 1):
                for k in range(sp.fascicle):
                    spread = rng.uniform(*sp.spread) * (1.0 - 0.35 * near_tip)
                    angle = heading + side * spread + (k - 0.5 * (sp.fascicle - 1)) * 0.18 * side
                    # Foreshortening: some needles point at the camera.
                    length = sp.needle_length * mult * rng.uniform(0.55, 1.0) \
                        * (1.0 - 0.3 * near_tip)
                    depth = rng.uniform(0.0, 1.0)
                    colour = np.array(sp.colour) * (1.0 - near_tip) + np.array(sp.tip_colour) \
                        * near_tip
                    colour = colour * rng.uniform(0.82, 1.15) * (0.75 + 0.25 * depth)
                    needles.append((depth, p, angle, length, colour))
        # A few needles straight along the shoot hide the bare tip.
        p, heading = point_on(axis, 1.0)
        for spread in (-0.25, 0.0, 0.25):
            needles.append((1.0, p, heading + spread, sp.needle_length * mult * 0.7,
                            np.array(sp.tip_colour)))
    extent = [tuple(p) for axis, _ in shoots for p in axis]
    for _, p, angle, length, _ in needles:
        extent.append((p[0] + math.cos(angle) * length, p[1] + math.sin(angle) * length))
    fit, scale = fit_transform(extent)
    for axis, radius in shoots:
        pts = [fit(tuple(p)) for p in axis]
        for i in range(len(pts) - 1):
            r = radius * scale * size * (1.0 - 0.5 * i / len(pts))
            draw_capsule(canvas, (pts[i][0] * size, pts[i][1] * size),
                         (pts[i + 1][0] * size, pts[i + 1][1] * size), r, r, TWIG, 0.1, 0.85, 0.05)
    needles.sort(key=lambda item: item[0])
    for depth, p, angle, length, colour in needles:
        start = fit(tuple(p))
        bend = rng.uniform(-sp.curve, sp.curve)
        segments = 3
        prev = (start[0] * size, start[1] * size)
        for s in range(1, segments + 1):
            f = s / segments
            a = angle + bend * f
            seg_len = length * scale * size / segments
            nxt = (prev[0] + math.cos(a) * seg_len, prev[1] + math.sin(a) * seg_len)
            radius = sp.needle_radius * math.sqrt(mult) * scale * size
            r0 = radius * (1.0 - 0.55 * (f - 1 / segments))
            r1 = radius * (1.0 - 0.55 * f) if s < segments else 0.3 * size / TILE
            draw_capsule(canvas, prev, nxt, r0, r1, tuple(colour), 0.5 + depth * 0.5,
                         sp.roughness, sp.translucency, shadow=0.22 if s == 1 else 0.0)
            prev = nxt
    return canvas


# --------------------------------------------------------------------------
# Atlas finishing: downsample, normalise to relative detail, fill the rim.


def downsample(canvas: Canvas, factor: int = SS) -> dict[str, np.ndarray]:
    def box(a: np.ndarray) -> np.ndarray:
        h, w = a.shape[:2]
        return a.reshape(h // factor, factor, w // factor, factor, *a.shape[2:]).mean(axis=(1, 3))

    alpha = box(canvas.alpha)
    weight = np.maximum(alpha, 1e-6)
    out = {"alpha": alpha}
    out["rgb"] = box(canvas.rgb * canvas.alpha[..., None]) / weight[..., None]
    for name in ("height", "rough", "trans", "occ"):
        out[name] = box(getattr(canvas, name) * canvas.alpha) / weight
    return out


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        n = a.shape[axis]
        a = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
             - np.take(c, np.arange(0, n), axis=axis)) / (2 * r + 1)
    return a


def rim_fill(values: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """Spread colour from covered texels into empty ones (normalised blur), so
    linear mips never mix the empty texel colour into leaf edges."""
    filled = values.copy()
    known = solid.astype(np.float64)
    channels = values[..., None] if values.ndim == 2 else values
    out = filled[..., None] if values.ndim == 2 else filled
    for radius in (2, 6, 18, 48):
        def blur(a: np.ndarray, r: int = radius) -> np.ndarray:
            return box_blur(box_blur(a, r), r)
        weight = blur(known)
        colour = np.dstack([blur(channels[..., c] * known) for c in range(channels.shape[2])])
        colour /= np.maximum(weight, 1e-6)[..., None]
        empty = (known < 0.5) & (weight > 1e-4)
        out[empty] = colour[empty]
        channels = out
        known = np.maximum(known, (weight > 1e-4).astype(np.float64))
    mean = out[solid > 0.5].mean(axis=0) if (solid > 0.5).any() else out.mean(axis=(0, 1))
    out[known < 0.5] = mean
    return out[..., 0] if values.ndim == 2 else out


def relative_detail(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Scale each channel so the mean opaque colour is neutral 0.5 grey (the
    R-1194 contract: species colour comes from the shader)."""
    opaque = alpha > 0.5
    mean = rgb[opaque].mean(axis=0)
    return np.clip(rgb / mean[None, None, :] * 0.5, 0.0, 1.0)


def normal_map(height: np.ndarray, strength: float, wrap: bool) -> np.ndarray:
    if wrap:
        dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
        dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    else:
        dy, dx = np.gradient(height)
    n = np.dstack([-dx * strength, dy * strength, np.ones_like(dx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def to_u8(a: np.ndarray) -> np.ndarray:
    return (np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def finish_card(canvas: Canvas) -> dict[str, np.ndarray]:
    small = downsample(canvas)
    alpha = small["alpha"]
    solid = alpha > 0.5
    detail = relative_detail(small["rgb"], alpha)
    detail = rim_fill(detail, solid)
    height = small["height"] * smoothstep(0.0, 0.5, alpha)
    normal = normal_map(height, 6.0, wrap=False)
    normal[~solid] = (0.5, 0.5, 1.0)
    surface = np.dstack([small["rough"], small["trans"], small["occ"]])
    surface = rim_fill(surface, solid)
    return {
        "albedo": np.dstack([detail, alpha]),
        "normal": normal,
        "surface": surface,
    }


# --------------------------------------------------------------------------
# Bark, ground cover and grain ears.


def bark_plate(kind: str, rng: np.random.Generator) -> tuple[np.ndarray, np.ndarray]:
    n = PLATE
    shape = (n, n)
    fine = fbm(rng, shape, 6.0, 3)
    if kind == "oak":
        ridges = periodic_noise(rng, shape, 22.0, stretch=8.0)
        ridge = 1.0 - np.abs(np.tanh(ridges * 1.4))
        cracks = periodic_noise(rng, shape, 30.0, stretch=0.15)
        height = ridge ** 1.5 - 0.25 * smoothstep(0.8, 1.6, np.abs(cracks)) + 0.08 * fine
        lichen = smoothstep(0.9, 1.6, fbm(rng, shape, 90.0, 3))
        base = np.array([0.40, 0.36, 0.31])
        dark = np.array([0.11, 0.09, 0.08])
        colour = dark + (base - dark) * smoothstep(0.1, 0.85, height)[..., None]
        colour = colour * (1 - 0.5 * lichen[..., None]) + np.array([0.48, 0.52, 0.40]) \
            * 0.5 * lichen[..., None]
        strength = 9.0
    elif kind == "pine":
        f1, f2, ident = periodic_voronoi(rng, n, 46, aspect=2.6)
        gap = smoothstep(0.0, 0.16, f2 - f1)
        cell_tone = rng.uniform(0.82, 1.15, 46)[ident]
        flake = fbm(rng, shape, 14.0, 3, stretch=2.5)
        height = gap * (0.7 + 0.12 * flake) + 0.05 * fine
        plate = np.array([0.56, 0.34, 0.21]) * cell_tone[..., None]
        plate = plate * (1.0 + 0.08 * flake[..., None])
        colour = np.array([0.14, 0.09, 0.06]) * (1 - gap[..., None]) + plate * gap[..., None]
        strength = 8.0
    elif kind == "spruce":
        f1, f2, ident = periodic_voronoi(rng, n, 240, aspect=1.25)
        gap = smoothstep(0.0, 0.22, f2 - f1)
        scale = (1.0 - np.clip(f1, 0.0, 1.0)) * gap
        tone = rng.uniform(0.85, 1.15, 240)[ident]
        reddish = (rng.uniform(0, 1, 240) < 0.25)[ident]
        height = 0.5 * scale + 0.4 * gap + 0.06 * fine
        base = np.where(reddish[..., None], np.array([0.46, 0.30, 0.24]), np.array([0.40, 0.33, 0.28]))
        colour = np.array([0.16, 0.12, 0.10]) * (1 - gap[..., None]) + base * tone[..., None] \
            * gap[..., None]
        strength = 7.0
    elif kind in ("birch", "cherry", "grey"):
        lenticel = np.zeros(shape)
        ys, xs = np.mgrid[0:n, 0:n].astype(np.float64)
        count = {"birch": 70, "cherry": 90, "grey": 40}[kind]
        for _ in range(count):
            cx, cy = rng.uniform(0, n, 2)
            half_w = rng.uniform(6, 26 if kind != "grey" else 10)
            half_h = rng.uniform(0.8, 2.2)
            dx = np.abs(xs - cx)
            dx = np.minimum(dx, n - dx)
            dy = np.abs(ys - cy)
            dy = np.minimum(dy, n - dy)
            lenticel = np.maximum(lenticel, np.clip(1.0 - (dx / half_w) ** 2 - (dy / half_h) ** 2,
                                                    0.0, 1.0))
        if kind == "birch":
            fissure = smoothstep(1.0, 1.5, fbm(rng, shape, 70.0, 4, stretch=0.6))
            peel = smoothstep(0.6, 1.4, periodic_noise(rng, shape, 40.0, stretch=0.12))
            white = np.array([0.86, 0.85, 0.80]) * (1.0 + 0.04 * fine[..., None])
            white = white * (1 - 0.25 * peel[..., None]) + np.array([0.86, 0.76, 0.70]) \
                * 0.25 * peel[..., None]
            black = np.array([0.12, 0.11, 0.10]) * (1.0 + 0.2 * fine[..., None])
            colour = white * (1 - fissure[..., None]) + black * fissure[..., None]
            colour = colour * (1 - 0.75 * lenticel[..., None]) + np.array([0.20, 0.18, 0.17]) \
                * 0.75 * lenticel[..., None]
            height = 0.5 - 0.35 * fissure + 0.15 * fissure * fine - 0.12 * lenticel + 0.03 * fine
            strength = 5.0
        elif kind == "cherry":
            bands = smoothstep(0.3, 1.2, periodic_noise(rng, shape, 30.0, stretch=0.1))
            base = np.array([0.38, 0.19, 0.15]) * (1.0 + 0.06 * fine[..., None])
            colour = base * (1 - 0.15 * bands[..., None]) + np.array([0.30, 0.22, 0.20]) \
                * 0.15 * bands[..., None]
            colour = colour * (1 - 0.7 * lenticel[..., None]) + np.array([0.55, 0.46, 0.40]) \
                * 0.7 * lenticel[..., None]
            height = 0.5 + 0.12 * lenticel + 0.08 * bands + 0.03 * fine
            strength = 4.0
        else:
            lichen = smoothstep(1.0, 1.7, fbm(rng, shape, 50.0, 3))
            base = np.array([0.44, 0.44, 0.39]) * (1.0 + 0.05 * fine[..., None])
            colour = base * (1 - 0.5 * lichen[..., None]) + np.array([0.58, 0.62, 0.48]) \
                * 0.5 * lichen[..., None]
            colour = colour * (1 - 0.4 * lenticel[..., None]) + np.array([0.30, 0.28, 0.25]) \
                * 0.4 * lenticel[..., None]
            height = 0.5 + 0.05 * fine + 0.06 * lichen - 0.05 * lenticel
            strength = 3.5
    else:
        raise ValueError(kind)
    return np.clip(colour, 0.0, 1.0), normal_map(height, strength, wrap=True)


def stamp_wrapped(canvas: Canvas, draw) -> None:
    """Draw a shape and its copies shifted by the plate size so it tiles."""
    for ox in (-canvas.w, 0, canvas.w):
        for oy in (-canvas.h, 0, canvas.h):
            draw(ox, oy)


def ground_plate(kind: str, rng: np.random.Generator) -> tuple[np.ndarray, np.ndarray]:
    n = PLATE
    shape = (n, n)
    soil_noise = fbm(rng, shape, 18.0, 4)
    soil = np.array([0.20, 0.15, 0.11]) * (1.0 + 0.12 * soil_noise[..., None])
    if kind == "moss":
        f1, _f2, ident = periodic_voronoi(rng, n, 320)
        cushion = np.clip(1.0 - f1, 0.0, 1.0) ** 0.7
        fibre = fbm(rng, shape, 2.5, 2)
        tone = rng.uniform(0.80, 1.20, 320)[ident]
        moss = np.array([0.30, 0.42, 0.15]) * tone[..., None] * (1.0 + 0.30 * fibre[..., None])
        cover = smoothstep(0.05, 0.35, cushion)
        colour = soil * (1 - cover[..., None]) + moss * cover[..., None]
        height = cushion * 0.8 + 0.08 * fibre
        return np.clip(colour, 0, 1), normal_map(height, 6.0, wrap=True)
    canvas = Canvas(n, n)
    canvas.rgb[:] = soil
    canvas.alpha[:] = 1.0
    canvas.height[:] = 0.1 * soil_noise
    if kind == "leaf_litter":
        litter = LeafSpecies(shape="elliptic", length=0.0, width=0.55, colour=(0.45, 0.30, 0.14),
                             leaves=0, layout="alternate", petiole=0.0, vein_pairs=6,
                             vein_slope=0.7, serrations=0, serration_depth=0.0, wear=0.6,
                             roughness=0.8, translucency=0.2)
        mottle = fbm(rng, shape, 10.0, 3)
        palette = [(0.48, 0.30, 0.13), (0.55, 0.38, 0.15), (0.36, 0.22, 0.12), (0.50, 0.42, 0.20)]
        for i in range(140):
            x, y = rng.uniform(0, n, 2)
            angle = rng.uniform(0, 2 * math.pi)
            length = rng.uniform(26, 52)
            colour = palette[int(rng.integers(0, len(palette)))]
            sp = LeafSpecies(**{**litter.__dict__, "colour": colour,
                                "shape": "elliptic" if i % 3 else "deltoid"})
            leaf_rng = np.random.default_rng([SEED, 7, i])

            def draw(ox, oy, x=x, y=y, angle=angle, length=length, sp=sp, leaf_rng=leaf_rng):
                draw_leaf(canvas, np.random.default_rng(leaf_rng.integers(1 << 30)), sp,
                          (x + ox, y + oy), angle, length, 0.3 + 0.7 * i / 140, mottle, 1.0)

            stamp_wrapped(canvas, draw)
    elif kind == "needle_litter":
        for i in range(900):
            x, y = rng.uniform(0, n, 2)
            angle = rng.uniform(0, 2 * math.pi)
            length = rng.uniform(10, 30)
            tone = np.array([0.52, 0.34, 0.18]) * rng.uniform(0.7, 1.15)
            end = (math.cos(angle) * length, math.sin(angle) * length)

            def draw(ox, oy, x=x, y=y, end=end, tone=tone, i=i):
                draw_capsule(canvas, (x + ox, y + oy), (x + ox + end[0], y + oy + end[1]), 1.3,
                             0.5, tuple(tone), 0.3 + 0.7 * i / 900, 0.8, 0.2, shadow=0.15)

            stamp_wrapped(canvas, draw)
    else:
        raise ValueError(kind)
    return np.clip(canvas.rgb, 0, 1), normal_map(canvas.height * 8.0, 2.5, wrap=True)


def draw_ear_tile(kind: str, rng: np.random.Generator) -> Canvas:
    w, h = EAR_TILE[0] * SS, EAR_TILE[1] * SS
    canvas = Canvas(w, h)
    straw = (0.55, 0.58, 0.30)
    grain = (0.62, 0.62, 0.30)
    awn = (0.66, 0.64, 0.36)
    cx = w * 0.5
    stem_top = h * (0.64 if kind in ("rye", "barley") else 0.40)
    nod = rng.uniform(0.06, 0.12) * w
    stem = axis_points(rng, (cx / w, 1.0), ((cx + nod * 0.3) / w, stem_top / h), 0.01, 20)
    for i in range(len(stem) - 1):
        draw_capsule(canvas, (stem[i][0] * w, stem[i][1] * h), (stem[i + 1][0] * w,
                     stem[i + 1][1] * h), 3.2 * SS, 3.0 * SS, straw, 0.2, 0.6, 0.4)
    top = (stem[-1][0] * w, stem[-1][1] * h)
    if kind in ("rye", "barley"):
        ear_len = h * (0.30 if kind == "rye" else 0.22)
        count = 22 if kind == "rye" else 16
        lean = rng.uniform(-0.18, -0.05) if kind == "rye" else rng.uniform(-0.06, 0.06)
        for i in range(count):
            f = i / (count - 1)
            ang = -math.pi / 2 + lean * (1 + 2 * f)
            px = top[0] + math.cos(ang) * ear_len * f
            py = top[1] + math.sin(ang) * ear_len * f
            for side in (-1, 1):
                spread = 0.32 if kind == "rye" else 0.18
                ga = ang + side * spread
                gl = (8.5 if kind == "barley" else 6.5) * SS
                gx, gy = px + math.cos(ga) * gl * 0.5, py + math.sin(ga) * gl * 0.5
                tone = tuple(np.array(grain) * rng.uniform(0.85, 1.1))
                draw_capsule(canvas, (px, py), (gx, gy), (3.6 if kind == "barley" else 2.8) * SS,
                             2.2 * SS, tone, 0.6 + 0.2 * f, 0.55, 0.45, shadow=0.2)
                awn_len = h * (0.12 if kind == "rye" else 0.20) * rng.uniform(0.8, 1.05)
                aa = ang + side * (0.10 if kind == "barley" else 0.16)
                draw_capsule(canvas, (gx, gy), (gx + math.cos(aa) * awn_len,
                             gy + math.sin(aa) * awn_len), 0.9 * SS, 0.35 * SS, awn, 0.8, 0.5, 0.6)
    elif kind == "oat":
        branches = 6
        for b in range(branches):
            f = b / (branches - 1)
            side = 1 if b % 2 else -1
            start = (top[0], top[1] - h * 0.30 * f)
            ang = -math.pi / 2 + side * rng.uniform(0.6, 1.1)
            blen = h * rng.uniform(0.10, 0.16) * (1.0 - 0.4 * f)
            end = (start[0] + math.cos(ang) * blen, start[1] + math.sin(ang) * blen)
            draw_capsule(canvas, start, end, 1.2 * SS, 0.8 * SS, straw, 0.4, 0.6, 0.5)
            # Pendant spikelets hang from the branch tips like small lanterns.
            for s in range(2):
                hx = end[0] + side * s * 6 * SS
                hy = end[1] + s * 4 * SS
                drop = h * rng.uniform(0.05, 0.07)
                draw_capsule(canvas, (hx, hy), (hx + side * 2 * SS, hy + drop), 3.4 * SS,
                             1.5 * SS, tuple(np.array(grain) * rng.uniform(0.9, 1.1)), 0.7, 0.5,
                             0.5, shadow=0.2)
        draw_capsule(canvas, top, (top[0], top[1] - h * 0.32), 1.4 * SS, 0.8 * SS, straw, 0.4,
                     0.6, 0.5)
    elif kind == "flax":
        for b in range(5):
            side = (b - 2) / 2.0
            ang = -math.pi / 2 + side * 0.55 + rng.uniform(-0.08, 0.08)
            blen = h * rng.uniform(0.10, 0.16)
            end = (top[0] + math.cos(ang) * blen, top[1] + math.sin(ang) * blen)
            draw_capsule(canvas, top, end, 1.3 * SS, 0.9 * SS, straw, 0.4, 0.6, 0.5)
            # Round five-chambered boll on a short stalk.
            draw_capsule(canvas, end, end, 7.5 * SS, 7.5 * SS, (0.60, 0.55, 0.28), 0.8, 0.5,
                         0.35, shadow=0.25)
            draw_capsule(canvas, (end[0], end[1] - 7 * SS), (end[0], end[1] - 10 * SS), 1.0 * SS,
                         0.3 * SS, (0.45, 0.40, 0.22), 0.9, 0.6, 0.3)
    else:
        raise ValueError(kind)
    return canvas


# --------------------------------------------------------------------------
# Output.


def save_png(array: np.ndarray, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = "RGBA" if array.shape[2] == 4 else "RGB"
    # Fixed encoder settings and no metadata: identical bytes on every run.
    Image.fromarray(to_u8(array)).save(path, format="PNG", compress_level=9)
    return hashlib.sha256(path.read_bytes()).hexdigest()


def species_rng(*keys: int | str) -> np.random.Generator:
    ints = [SEED] + [k if isinstance(k, int) else int.from_bytes(k.encode(), "little") % (1 << 31)
                     for k in keys]
    return np.random.default_rng(ints)


TUNE_STEPS = np.round(np.arange(0.8, 4.01, 0.1), 2)


def tile_coverage(species: str, mult: float) -> float:
    draw = draw_needle_tile if species in NEEDLES else draw_broadleaf_tile
    small = downsample(draw(species, TILE * SS, mult))
    return float((small["alpha"] >= 0.5).mean())


def tune(species: str) -> tuple[float, float]:
    """Size multiplier whose card coverage is closest to the species target.
    Offline (--tune): the result is pinned as size_scale so a normal run renders
    each tile once. The layout is scale-fitted to the card, so larger foliage
    means a denser card."""
    target = (NEEDLES.get(species) or LEAVES[species]).coverage
    best, best_coverage = 1.0, 0.0
    for mult in TUNE_STEPS:
        coverage = tile_coverage(species, float(mult))
        if abs(coverage - target) < abs(best_coverage - target):
            best, best_coverage = float(mult), coverage
    return best, best_coverage


def build_leaf_atlas() -> dict[str, np.ndarray]:
    atlas = {
        "albedo": np.zeros((GRID[1] * TILE, GRID[0] * TILE, 4)),
        "normal": np.zeros((GRID[1] * TILE, GRID[0] * TILE, 3)),
        "surface": np.zeros((GRID[1] * TILE, GRID[0] * TILE, 3)),
    }
    atlas["albedo"][..., :3] = 0.5
    atlas["normal"][..., :] = (0.5, 0.5, 1.0)
    atlas["surface"][..., :] = (0.6, 0.5, 1.0)
    for index, species in enumerate(TILES):
        mult = (NEEDLES.get(species) or LEAVES[species]).size_scale
        draw = draw_needle_tile if species in NEEDLES else draw_broadleaf_tile
        tile = finish_card(draw(species, TILE * SS, mult))
        col, row = index % GRID[0], index // GRID[0]
        sl = (slice(row * TILE, (row + 1) * TILE), slice(col * TILE, (col + 1) * TILE))
        for key in atlas:
            atlas[key][sl] = tile[key]
    return atlas


def build_ear_atlas() -> np.ndarray:
    tw, th = EAR_TILE
    atlas = np.zeros((th, tw * len(EARS), 4))
    atlas[..., :3] = 0.5
    for index, kind in enumerate(EARS):
        small = downsample(draw_ear_tile(kind, species_rng("ear", kind)))
        alpha = small["alpha"]
        solid = alpha > 0.5
        detail = rim_fill(relative_detail(small["rgb"], alpha), solid)
        atlas[:, index * tw:(index + 1) * tw] = np.dstack([detail, alpha])
    return atlas


def generate(out_root: Path) -> dict[str, str]:
    """Write every output under out_root; returns relative path -> SHA-256."""
    digests: dict[str, str] = {}

    def write(array: np.ndarray, relative: Path) -> None:
        digests[relative.as_posix()] = save_png(array, out_root / relative)

    leaf = build_leaf_atlas()
    write(leaf["albedo"], LEAF_DIR / "leaf_card_atlas.png")
    write(leaf["normal"], LEAF_DIR / "leaf_card_normal.png")
    write(leaf["surface"], LEAF_DIR / "leaf_card_surface.png")
    for kind in BARK_KINDS:
        albedo, normal = bark_plate(kind, species_rng("bark", kind))
        write(albedo, VEG_DIR / "bark" / f"bark_{kind}_albedo.png")
        write(normal, VEG_DIR / "bark" / f"bark_{kind}_normal.png")
    for kind in GROUND_KINDS:
        albedo, normal = ground_plate(kind, species_rng("ground", kind))
        write(albedo, VEG_DIR / "ground" / f"ground_{kind}_albedo.png")
        write(normal, VEG_DIR / "ground" / f"ground_{kind}_normal.png")
    write(build_ear_atlas(), VEG_DIR / "grain" / "grain_ear_atlas.png")
    return digests


# --------------------------------------------------------------------------
# Review sheets: old vs new tile, tinted like map_view_canopy.gdshader.

SHADER_TINT = {
    "birch": ((96, 118, 60), 0.74), "oak": ((96, 118, 60), 0.74),
    "maple": ((96, 118, 60), 0.74), "linden": ((96, 118, 60), 0.74),
    "apple": ((92, 128, 60), 0.74), "spruce": ((58, 84, 56), 0.84),
    "pine": ((72, 96, 52), 0.84),
}
SKY = np.array([0.62, 0.68, 0.72])


def tinted(tile: np.ndarray, species: str, far: bool) -> np.ndarray:
    colour, gain = SHADER_TINT[species]
    rgba = tile.astype(np.float64) / 255.0
    if far:
        # Canopy distance: what a 32 px mip level keeps of the card.
        image = Image.fromarray(tile).resize((32, 32), Image.Resampling.BOX)
        rgba = np.asarray(image.resize((256, 256), Image.Resampling.BILINEAR),
                          dtype=np.float64) / 255.0
    else:
        rgba = np.asarray(Image.fromarray(tile).resize((256, 256),
                          Image.Resampling.LANCZOS), dtype=np.float64) / 255.0
    rgb = np.array(colour) / 255.0 * 2.0 * rgba[..., :3] * gain
    keep = (rgba[..., 3] >= 0.5)[..., None]
    return np.where(keep, np.clip(rgb, 0, 1), SKY)


def review_sheets(old_atlas: Path, new_atlas: Path, out_dir: Path) -> list[Path]:
    old = np.asarray(Image.open(old_atlas).convert("RGBA"))
    new = np.asarray(Image.open(new_atlas).convert("RGBA"))
    written = []
    for index, species in enumerate(TILES):
        col, row = index % GRID[0], index // GRID[0]
        sl = (slice(row * TILE, (row + 1) * TILE), slice(col * TILE, (col + 1) * TILE))
        panels = [tinted(old[sl], species, False), tinted(new[sl], species, False),
                  tinted(old[sl], species, True), tinted(new[sl], species, True)]
        sheet = np.concatenate(panels, axis=1)
        path = out_dir / f"{species}_before_after.png"
        out_dir.mkdir(parents=True, exist_ok=True)
        Image.fromarray(to_u8(sheet)).save(path, format="PNG", compress_level=9)
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out-root", type=Path, default=ROOT)
    parser.add_argument("--tune", action="store_true",
                        help="print the size_scale per leaf species for its coverage target")
    parser.add_argument("--compare-old", type=Path)
    parser.add_argument("--sheets", type=Path, default=ROOT / "docs/reports/images/vegetation_atlases")
    args = parser.parse_args()
    if args.tune:
        for species in TILES:
            mult, coverage = tune(species)
            print(f"{species}: size_scale={mult} coverage={coverage:.3f}")
        return 0
    for relative, digest in generate(args.out_root).items():
        print(f"{relative} SHA-256 {digest}")
    if args.compare_old:
        for path in review_sheets(args.compare_old, args.out_root / LEAF_DIR / "leaf_card_atlas.png",
                                  args.sheets):
            print(f"review sheet {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
