"""Grain-ear drawing and atlas assembly for rye, barley, oat and flax."""

from __future__ import annotations

import math

import numpy as np

from .species import EARS, EAR_TILE, SS
from .raster import Canvas, downsample, draw_capsule, relative_detail, rim_fill, species_rng
from .foliage import axis_points

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
