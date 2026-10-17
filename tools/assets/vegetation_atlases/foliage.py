"""Broadleaf and needle silhouettes, twig layouts, atlas assembly and tuning."""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from .species import GRID, LEAVES, NEEDLES, SS, TILE, TILES, TWIG, LeafSpecies
from .raster import (
    Canvas, downsample, draw_capsule, fbm, finish_card, smoothstep, species_rng,
)

TUNE_STEPS = np.round(np.arange(0.8, 4.01, 0.1), 2)


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
