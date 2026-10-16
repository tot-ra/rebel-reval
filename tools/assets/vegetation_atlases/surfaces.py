"""Seamless bark and forest-floor albedo/normal plates."""

from __future__ import annotations

import math

import numpy as np

from .species import PLATE, SEED, LeafSpecies
from .raster import (
    Canvas, draw_capsule, fbm, normal_map, periodic_noise, periodic_voronoi, smoothstep,
)
from .foliage import draw_leaf

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
