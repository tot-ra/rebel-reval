#!/usr/bin/env python3
"""Shared deterministic builders for the 1343 Reval burgher-house kits (v2).

Historical basis: history/dossiers/architecture/burgher-house-plan.md (R-003).
Every builder follows the dossier Brief ship decisions: gable end to street,
ridge perpendicular to the lane, 1343-safe openings (pointed stone portals,
shuttered openings, no late-Gothic four-light crosses or blind niches),
loading hatches with hoist beam on merchant tiers, tile/shingle/thatch roof
bands by tier.

v2 adds the "lived-in by 1343" layer the v1 boxes lacked:
- materials read as local fabric: coursed limestone rubble (paekivi) in lime
  mortar, lime render and limewash that has flaked back to rubble or daub,
  silver-grey weathered oak, horizontal log walls caulked with moss,
  monk-and-nun clay tile, split wood shingle, and water-reed thatch;
- every texture ships with a tangent-space normal map so mortar joints, tile
  channels and reed courses read under raking light;
- wear is baked into vertex colours (rising damp and splash-back at the
  plinth, runoff under eaves, moss on roofs, soot above flues) and into the
  geometry (sagging ridges, uneven coping, hand-cut irregular timbers,
  skewed shutters, missing coping stones, patched shingles).

Consumed by the per-tier generators:
    tools/generate_burgher_house_merchant_stone.py
    tools/generate_burgher_house_merchant_timber.py
    tools/generate_burgher_house_craft_boda.py

Blender coordinates: X = facade width, Y = plot depth, Z = up. The wall body
is centred on the origin (facade plane at y = -depth / 2, front towards -Y) so
the Godot loader can fit the body to the authored footprint without an offset.
glTF export with ``export_yup=True`` maps the facade to Godot +Z.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

GENERATOR_VERSION = "burgher_house_kit_v2"
BLENDER_VERSION = "Blender 5.2 LTS"

ROOF_PITCH_DEG = 48.0  # dossier: steep vernacular pitch (~45 deg analogy)
TEXTURE_SIZE = 512
# v2 houses carry real relief (logs, coping, ridge tiles); the budget stays
# far below one crowd character so the 43-house Lower Town row remains cheap.
TRIANGLE_BUDGET = (400, 16000)


# --- deterministic noise ----------------------------------------------------


def _np_rng(name: str) -> np.random.Generator:
    return np.random.default_rng(int(hashlib.sha256(name.encode("utf-8")).hexdigest()[:12], 16))


def _value_noise(size: int, freq_u: int, freq_v: int, rng: np.random.Generator) -> np.ndarray:
    """Tileable value noise; freq_u/freq_v set anisotropy (grain, reed)."""
    grid = rng.random((freq_v, freq_u), dtype=np.float32)
    coords = np.arange(size, dtype=np.float32) + 0.5

    def axis(freq: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        position = coords * (freq / size)
        index = np.floor(position).astype(np.int64)
        frac = position - index
        smooth = frac * frac * (3.0 - 2.0 * frac)
        return index % freq, (index + 1) % freq, smooth

    u0, u1, su = axis(freq_u)
    v0, v1, sv = axis(freq_v)
    row0 = grid[v0]
    row1 = grid[v1]
    top = row0[:, u0] * (1.0 - su[None, :]) + row0[:, u1] * su[None, :]
    bottom = row1[:, u0] * (1.0 - su[None, :]) + row1[:, u1] * su[None, :]
    return top * (1.0 - sv[:, None]) + bottom * sv[:, None]


def _fbm(
    size: int,
    rng: np.random.Generator,
    base_u: int = 4,
    base_v: int | None = None,
    octaves: int = 4,
    gain: float = 0.5,
) -> np.ndarray:
    base_v = base_u if base_v is None else base_v
    total = np.zeros((size, size), dtype=np.float32)
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        scale = 2**octave
        total += amplitude * _value_noise(
            size, min(size, base_u * scale), min(size, base_v * scale), rng
        )
        norm += amplitude
        amplitude *= gain
    return total / norm


def _smooth(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _rgb(hex_color: int) -> np.ndarray:
    return np.array(
        [((hex_color >> 16) & 0xFF) / 255.0, ((hex_color >> 8) & 0xFF) / 255.0, (hex_color & 0xFF) / 255.0],
        dtype=np.float32,
    )


def _mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    return a * (1.0 - t[..., None]) + b * t[..., None]


# --- procedural surfaces (sRGB albedo + height) ------------------------------
# Arrays are indexed [v, u] with v = 0 at the bottom row (Blender pixel order).


def _surface_coursed(
    rng: np.random.Generator,
    size: int,
    stone: int,
    mortar: int,
    courses: tuple[float, float],
    lengths: tuple[float, float],
    mortar_px: float,
    tone_sigma: float,
    split_chance: float = 0.0,
) -> tuple[np.ndarray, np.ndarray]:
    """Irregular coursed masonry: flat limestone slabs in rough beds."""
    dist = np.zeros((size, size), dtype=np.float32)
    tone = np.ones((size, size, 3), dtype=np.float32)
    heights: list[float] = []
    while sum(heights) < 1.0:
        heights.append(float(rng.uniform(*courses)))
    scale = 1.0 / sum(heights)
    pixels = np.arange(size, dtype=np.float32) + 0.5
    # Local limestone (paekivi) is a cool grey slab stone; weathered beds go
    # buff or brown-grey, fresh splits bluish.
    hues = [
        np.array([1.0, 1.0, 1.0], dtype=np.float32),
        np.array([1.0, 1.0, 1.0], dtype=np.float32),
        np.array([1.03, 1.01, 0.95], dtype=np.float32),
        np.array([0.96, 0.98, 1.02], dtype=np.float32),
        np.array([0.9, 0.88, 0.84], dtype=np.float32),
    ]
    corner = mortar_px * 1.6
    y = 0.0
    for course in heights:
        y0 = int(round(y * size))
        y += course * scale
        y1 = int(round(y * size)) if y < 0.9999 else size
        if y1 <= y0:
            continue
        rows = pixels[y0:y1]
        dv = np.minimum(rows - y0, y1 - rows)
        spans: list[float] = []
        while sum(spans) < 1.0:
            spans.append(float(rng.uniform(*lengths)))
        span_scale = 1.0 / sum(spans)
        x = float(rng.uniform(0.0, 1.0))
        for span in spans:
            x0 = x * size
            x += span * span_scale
            x1 = x * size
            cols = np.arange(int(math.floor(x0)), int(math.ceil(x1)))
            local = cols.astype(np.float32) + 0.5
            du = np.minimum(local - x0, x1 - local)
            wrapped = cols % size
            # Thin slabs: some stones are two beds stacked in one course.
            split = y0 + (y1 - y0) * float(rng.uniform(0.35, 0.65)) if (rng.random() < split_chance and y1 - y0 > mortar_px * 6) else None
            dv_stone = dv if split is None else np.minimum(dv, np.abs(rows - split))
            # Soft-min rounds slab corners so the wall does not read as brick.
            a = du[None, :]
            b = dv_stone[:, None]
            soft = -corner * np.log(np.exp(-a / corner) + np.exp(-b / corner) + 1e-6)
            dist[y0:y1, wrapped] = np.maximum(np.minimum(a, b) * 0.35 + soft * 0.65, 0.0)
            hue = hues[int(rng.integers(0, len(hues)))]
            tone[y0:y1, wrapped, :] = hue * float(rng.normal(1.0, tone_sigma))
    jitter = (_fbm(size, rng, 16, octaves=3) - 0.5) * mortar_px * 2.4
    edge = dist + jitter
    stone_mask = _smooth(mortar_px - 1.0, mortar_px + 1.2, edge)
    rounded = _smooth(0.0, mortar_px * 3.5, edge)
    grain = _fbm(size, rng, 32, octaves=3)
    pits = _smooth(0.78, 0.9, _fbm(size, rng, 64, octaves=2))
    stone_rgb = _rgb(stone)[None, None, :] * tone * (0.74 + 0.26 * rounded)[..., None]
    stone_rgb *= (0.86 + 0.24 * grain - 0.18 * pits)[..., None]
    broad = _fbm(size, rng, 3, octaves=3)
    stone_rgb *= (0.9 + 0.2 * broad)[..., None]
    mortar_rgb = _rgb(mortar)[None, None, :] * (0.8 + 0.2 * _fbm(size, rng, 24, octaves=2))[..., None]
    rgb = _mix(mortar_rgb, stone_rgb, stone_mask)
    height = stone_mask * (0.45 + 0.55 * rounded) * (0.9 + 0.1 * grain) - pits * 0.08
    return rgb, height


def _surface_limewash(
    rng: np.random.Generator,
    size: int,
    under: tuple[np.ndarray, np.ndarray],
    loss: float,
    patch_freq: int = 5,
    lime_hex: int = 0xC4BCA6,
) -> tuple[np.ndarray, np.ndarray]:
    """Lime coat with hairline cracks, flaked back to what is underneath."""
    under_rgb, under_height = under
    # Aged lime coat: grey-buff, dirtied, not fresh white.
    lime = _rgb(lime_hex)
    mottle = _fbm(size, rng, 6, octaves=4)
    runoff = _fbm(size, rng, 48, 3, octaves=3)
    coat = lime[None, None, :] * (0.86 + 0.14 * mottle - 0.1 * runoff)[..., None]
    ridge = 1.0 - np.abs(2.0 * _fbm(size, rng, 6, octaves=3) - 1.0)
    cracks = _smooth(0.986, 0.996, ridge)
    coat *= (1.0 - 0.22 * cracks)[..., None]
    patches = _fbm(size, rng, patch_freq, octaves=4)
    threshold = 1.0 - loss
    lost = _smooth(threshold - 0.01, threshold + 0.01, patches)
    rim = _smooth(threshold - 0.05, threshold - 0.01, patches) * (1.0 - lost)
    coat *= (1.0 - 0.28 * rim)[..., None]
    rgb = _mix(coat, under_rgb, lost)
    height = (0.78 + 0.05 * mottle - 0.2 * cracks) * (1.0 - lost) + under_height * 0.6 * lost
    return rgb, height


def _surface_daub(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    clay = _rgb(0x8C7B62)
    noise = _fbm(size, rng, 12, octaves=4)
    straw = _smooth(0.7, 0.85, _fbm(size, rng, 96, 8, octaves=2))
    rgb = clay[None, None, :] * (0.82 + 0.3 * noise)[..., None]
    rgb = _mix(rgb, _rgb(0xA89066)[None, None, :] * np.ones_like(rgb), straw * 0.5)
    return rgb, 0.4 + 0.3 * noise


def _surface_wattle(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Woven hazel rods on upright stakes, where the daub has fallen away."""
    v = (np.arange(size, dtype=np.float32) + 0.5) / size
    u = v.copy()
    rows = 14
    row_index = np.floor(v * rows)
    row_frac = v * rows - row_index
    rod = np.sin(np.pi * row_frac)
    weave = np.sin((u[None, :] * 6.0 + (row_index[:, None] % 2) * 0.5) * 2.0 * np.pi)
    height = rod[:, None] * (0.7 + 0.3 * weave)
    wood = _rgb(0x6E5A40)
    rgb = wood[None, None, :] * (0.55 + 0.45 * height)[..., None]
    daub_rgb, _ = _surface_daub(rng, size)
    clinging = _smooth(0.62, 0.7, _fbm(size, rng, 6, octaves=3))
    return _mix(rgb, daub_rgb, clinging), height * (1.0 - clinging) + 0.5 * clinging


def _surface_timber(
    rng: np.random.Generator, size: int, base: int, planks: int, weather: float
) -> tuple[np.ndarray, np.ndarray]:
    """Grain along v; weathered oak goes silver-grey, checks split along grain."""
    grain = _fbm(size, rng, 48, 3, octaves=4)
    fine = _fbm(size, rng, 160, 6, octaves=2)
    checks_ridge = 1.0 - np.abs(2.0 * _fbm(size, rng, 24, 2, octaves=3) - 1.0)
    checks = _smooth(0.965, 0.99, checks_ridge)
    rgb = _rgb(base)[None, None, :] * (0.78 + 0.28 * grain + 0.08 * fine)[..., None]
    silver = _rgb(0x8E8A82)[None, None, :] * (0.85 + 0.2 * fine)[..., None]
    rgb = _mix(rgb, silver, np.clip(weather * (0.55 + 0.6 * _fbm(size, rng, 4, octaves=3)), 0.0, 1.0))
    height = 0.6 + 0.25 * grain - 0.45 * checks
    if planks > 0:
        u = (np.arange(size, dtype=np.float32) + 0.5) / size
        plank_index = np.floor(u * planks).astype(np.int64)
        plank_frac = u * planks - plank_index
        tones = rng.normal(1.0, 0.09, planks).astype(np.float32)
        rgb *= tones[plank_index][None, :, None]
        seam = 1.0 - _smooth(0.0, 0.05, np.minimum(plank_frac, 1.0 - plank_frac))
        rgb *= (1.0 - 0.75 * seam)[None, :, None]
        height = height - 0.6 * seam[None, :]
    rgb *= (1.0 - 0.6 * checks)[..., None]
    return rgb, height


def _surface_log(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    rgb, height = _surface_timber(rng, size, 0x6A5A48, 0, 0.75)
    bark = _smooth(0.74, 0.8, _fbm(size, rng, 10, 3, octaves=3))
    rgb = _mix(rgb, _rgb(0x4A3A2C)[None, None, :] * np.ones_like(rgb), bark)
    return rgb, height + bark * 0.15


def _surface_caulk(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Dried moss and tow packed between logs."""
    fibres = _fbm(size, rng, 96, 12, octaves=3)
    rgb = _mix(_rgb(0x3E3A26)[None, None, :] * np.ones((size, size, 3), np.float32), _rgb(0x6A6038)[None, None, :] * np.ones((size, size, 3), np.float32), fibres)
    return rgb, 0.3 + 0.4 * fibres


def _surface_tile(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Monk-and-nun clay tile: convex monks over concave nuns, lichen crust."""
    rows, cols = 9, 8
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    row_pos = coords * rows
    row_index = np.floor(row_pos).astype(np.int64)
    row_frac = row_pos - row_index
    shift = (row_index % 2).astype(np.float32) * 0.0  # monk-and-nun runs in straight lanes
    col_pos = coords[None, :] * cols + shift[:, None]
    col_index = np.floor(col_pos).astype(np.int64)
    col_frac = col_pos - col_index
    channel = np.sin(np.pi * col_frac)
    monk = (col_index % 2) == 0
    height = np.where(monk, 0.55 + 0.45 * channel, 0.42 - 0.3 * channel)
    # Butt of each tile overlaps the one below it: thick at the lower edge.
    height = height + 0.22 * (1.0 - row_frac[:, None])
    tones = rng.normal(1.0, 0.08, (rows, cols)).astype(np.float32)
    replaced = rng.random((rows, cols)) < 0.04
    tone = tones[row_index[:, None] % rows, col_index % cols]
    base = _rgb(0x98533A)[None, None, :] * np.ones((size, size, 3), np.float32)
    rgb = base * tone[..., None]
    fresh = replaced[row_index[:, None] % rows, col_index % cols]
    rgb = np.where(fresh[..., None], _rgb(0xB8653E)[None, None, :] * tone[..., None], rgb)
    rgb *= np.where(monk, 0.82 + 0.26 * channel, 0.62 + 0.12 * channel)[..., None]
    butt_shadow = 1.0 - 0.45 * (1.0 - _smooth(0.0, 0.08, row_frac))
    rgb *= butt_shadow[:, None, None]
    grime = _fbm(size, rng, 8, octaves=4)
    rgb *= (0.84 + 0.2 * grime)[..., None]
    lichen_noise = _fbm(size, rng, 40, octaves=3)
    lichen = _smooth(0.66, 0.72, lichen_noise)
    orange = _smooth(0.74, 0.78, _fbm(size, rng, 56, octaves=2))
    rgb = _mix(rgb, _rgb(0xA49D80)[None, None, :] * np.ones_like(rgb), lichen * 0.8)
    rgb = _mix(rgb, _rgb(0xB88A3E)[None, None, :] * np.ones_like(rgb), orange * 0.7)
    return rgb, height + lichen * 0.05


def _surface_shingle(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Split wood shingle weathered to grey, with splits and lost pieces."""
    rows, cols = 10, 7
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    row_pos = coords * rows
    row_index = np.floor(row_pos).astype(np.int64)
    row_frac = row_pos - row_index
    offsets = rng.random(rows).astype(np.float32)
    col_pos = coords[None, :] * cols + offsets[row_index][:, None]
    col_index = np.floor(col_pos).astype(np.int64)
    col_frac = col_pos - col_index
    tones = rng.normal(1.0, 0.12, (rows, cols + 1)).astype(np.float32)
    missing = rng.random((rows, cols + 1)) < 0.03
    tone = tones[row_index[:, None] % rows, col_index % (cols + 1)]
    lost = missing[row_index[:, None] % rows, col_index % (cols + 1)]
    grain = _fbm(size, rng, 96, 6, octaves=3)
    base = _rgb(0x6C665C)[None, None, :] * np.ones((size, size, 3), np.float32)
    rgb = base * (tone * (0.8 + 0.3 * grain))[..., None]
    brown = _smooth(0.55, 0.8, _fbm(size, rng, 6, octaves=3))
    rgb = _mix(rgb, _rgb(0x5A4636)[None, None, :] * np.ones_like(rgb), brown * 0.6)
    seam = 1.0 - _smooth(0.0, 0.035, np.minimum(col_frac, 1.0 - col_frac))
    split_ridge = 1.0 - np.abs(2.0 * _fbm(size, rng, 64, 4, octaves=2) - 1.0)
    split = _smooth(0.975, 0.99, split_ridge)
    rgb *= (1.0 - 0.7 * np.maximum(seam, split))[..., None]
    rgb *= (0.62 + 0.38 * _smooth(0.0, 0.12, row_frac))[:, None, None]
    rgb = np.where(lost[..., None], _rgb(0x2A221C)[None, None, :] * np.ones_like(rgb), rgb)
    height = 0.35 + 0.5 * (1.0 - row_frac[:, None]) + 0.1 * grain - 0.4 * np.maximum(seam, split)
    height = np.where(lost, 0.05, height)
    return rgb, height


def _surface_thatch(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Water-reed thatch: butt ends dressed down the slope, weathered grey."""
    streak = _fbm(size, rng, 192, 5, octaves=3)
    stems = _smooth(0.35, 0.75, _value_noise(size, 256, 12, rng))
    coarse = _fbm(size, rng, 24, 2, octaves=3)
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    course = coords * 6.0 - np.floor(coords * 6.0)
    sway = 1.0 - 0.35 * (1.0 - _smooth(0.0, 0.08, course))
    base = _rgb(0x8E7E5E)[None, None, :] * np.ones((size, size, 3), np.float32)
    rgb = base * (0.6 + 0.35 * streak + 0.25 * stems + 0.1 * coarse)[..., None]
    grey = _smooth(0.45, 0.72, _fbm(size, rng, 4, octaves=3))
    rgb = _mix(rgb, _rgb(0x76705F)[None, None, :] * (0.7 + 0.3 * streak + 0.2 * stems)[..., None], grey * 0.6)
    rgb *= sway[:, None, None]
    height = 0.3 + 0.35 * streak + 0.35 * stems + 0.1 * coarse
    return rgb, height * sway[:, None]


def _surface_iron(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    hammer = _fbm(size, rng, 24, octaves=3)
    rust = _smooth(0.5, 0.7, _fbm(size, rng, 10, octaves=4))
    rgb = _rgb(0x3A3836)[None, None, :] * (0.8 + 0.3 * hammer)[..., None]
    rgb = _mix(rgb, _rgb(0x6E422A)[None, None, :] * np.ones_like(rgb), rust * 0.85)
    return rgb, 0.5 + 0.3 * hammer


def _surface_rope(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    twist = np.sin((coords[None, :] * 3.0 + coords[:, None] * 24.0) * 2.0 * np.pi)
    rgb = _rgb(0x8C7A58)[None, None, :] * (0.8 + 0.15 * twist)[..., None]
    return rgb * (0.9 + 0.1 * _fbm(size, rng, 16, octaves=2))[..., None], 0.5 + 0.4 * twist


def _surface_brick(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Hand-moulded Hanseatic brick in lime mortar: 12 courses, running bond.

    AR-03: one plate covers about 1.2 m, so a course is ~0.1 m and a brick
    ~0.3 m long - the Baltic 'Klosterformat' scale, not modern 65 mm brick.
    """
    rows, cols = 12, 4
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    row_pos = coords * rows
    row_index = np.floor(row_pos).astype(np.int64)
    row_frac = row_pos - row_index
    shift = (row_index % 2).astype(np.float32) * 0.5
    col_pos = coords[None, :] * cols + shift[:, None]
    col_index = np.floor(col_pos).astype(np.int64)
    col_frac = col_pos - col_index
    joint_u = np.minimum(col_frac, 1.0 - col_frac) * (size / cols)
    joint_v = np.minimum(row_frac, 1.0 - row_frac)[:, None] * (size / rows)
    jitter = (_fbm(size, rng, 24, octaves=2) - 0.5) * 1.6
    edge = np.minimum(joint_u, joint_v) + jitter
    brick_mask = _smooth(1.6, 3.0, edge)
    rounded = _smooth(0.0, 7.0, edge)
    tones = rng.normal(1.0, 0.09, (rows, cols + 1)).astype(np.float32)
    burnt = rng.random((rows, cols + 1)) < 0.12
    tone = tones[row_index[:, None] % rows, col_index % (cols + 1)]
    dark = burnt[row_index[:, None] % rows, col_index % (cols + 1)]
    base = _rgb(0x8E4A34)[None, None, :] * np.ones((size, size, 3), np.float32)
    rgb = base * tone[..., None]
    rgb = np.where(dark[..., None], _rgb(0x5A3226)[None, None, :] * tone[..., None], rgb)
    grain = _fbm(size, rng, 48, octaves=3)
    rgb *= (0.8 + 0.22 * grain + 0.1 * rounded)[..., None]
    mortar = _rgb(0xA8A08E)[None, None, :] * (0.8 + 0.2 * _fbm(size, rng, 32, octaves=2))[..., None]
    rgb = _mix(mortar, rgb, brick_mask)
    height = brick_mask * (0.55 + 0.35 * rounded + 0.1 * grain)
    return rgb, height


def _surface_log_courses(
    rng: np.random.Generator, size: int, base: int = 0x6A5A48, weather: float = 0.75
) -> tuple[np.ndarray, np.ndarray]:
    """Horizontal round-log wall face for box walls: 8 logs per plate, moss caulk.

    The existing ``log`` kind is bark and grain only because the burgher GLBs
    carry real log geometry; flat box walls need the courses painted in.
    """
    logs = 8
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    wobble = (_fbm(size, rng, 6, 2, octaves=2) - 0.5) * 0.18
    row_pos = coords[:, None] * logs + wobble
    row_index = np.floor(row_pos).astype(np.int64)
    row_frac = row_pos - row_index
    profile = np.sqrt(np.clip(1.0 - (2.0 * row_frac - 1.0) ** 2, 0.0, 1.0))
    wood_rgb, wood_height = _surface_timber(rng, size, base, 0, weather)
    # Timber grain runs along v; logs lie horizontally, so turn the grain.
    wood_rgb = np.transpose(wood_rgb, (1, 0, 2))
    wood_height = wood_height.T
    tones = rng.normal(1.0, 0.08, logs + 1).astype(np.float32)
    rgb = wood_rgb * tones[row_index % (logs + 1)][..., None]
    rgb *= (0.55 + 0.45 * profile)[..., None]
    caulk_rgb, _ = _surface_caulk(rng, size)
    seam = 1.0 - _smooth(0.05, 0.2, profile)
    rgb = _mix(rgb, caulk_rgb, seam * 0.85)
    height = profile * (0.75 + 0.25 * wood_height) * (1.0 - seam) + 0.12 * seam
    return rgb, height


def _surface_boards_horizontal(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Horizontal weatherboard: the vertical ``boards`` plate turned 90 degrees."""
    rgb, height = _surface_timber(rng, size, 0x6A5C4C, 7, 0.8)
    return np.transpose(rgb, (1, 0, 2)), height.T


def _surface_gable_board(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Board-and-batten gable field: narrow upright boards with raised cover strips."""
    rgb, height = _surface_timber(rng, size, 0x5E5244, 8, 0.95)
    u = (np.arange(size, dtype=np.float32) + 0.5) / size
    batten_frac = u * 8.0 - np.floor(u * 8.0)
    batten = _smooth(0.07, 0.03, np.minimum(batten_frac, 1.0 - batten_frac))
    rgb *= (1.0 + 0.18 * batten)[None, :, None]
    height = height + 0.7 * batten[None, :]
    return rgb, height


def _surface_straw(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Long-straw (rye) thatch: paler, finer and more ragged than water reed."""
    streak = _fbm(size, rng, 256, 4, octaves=3)
    stems = _smooth(0.3, 0.8, _value_noise(size, 320, 8, rng))
    coarse = _fbm(size, rng, 16, 3, octaves=3)
    coords = (np.arange(size, dtype=np.float32) + 0.5) / size
    course = coords * 8.0 - np.floor(coords * 8.0)
    ragged = (_fbm(size, rng, 48, 8, octaves=2) - 0.5) * 0.08
    fringe = 1.0 - 0.28 * (1.0 - _smooth(0.0, 0.12, course[:, None] + ragged))
    base = _rgb(0xA89468)[None, None, :] * np.ones((size, size, 3), np.float32)
    rgb = base * (0.62 + 0.3 * streak + 0.22 * stems + 0.12 * coarse)[..., None]
    rot = _smooth(0.55, 0.8, _fbm(size, rng, 5, octaves=3))
    rgb = _mix(rgb, _rgb(0x6E6450)[None, None, :] * (0.7 + 0.3 * streak)[..., None], rot * 0.5)
    rgb *= fringe[..., None]
    height = (0.25 + 0.4 * streak + 0.3 * stems + 0.1 * coarse) * fringe
    return rgb, height


def _surface_soot(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Smoke-room lime face: limewash over rubble, blackened upward by hearth smoke."""
    rgb, height = _surface_limewash(rng, size, _surface_coursed(
        rng, size, 0x8E8C85, 0xA39D8E, (0.04, 0.12), (0.1, 0.34), 4.2, 0.1, 0.35
    ), 0.28, 4, 0xA8A090)
    # A plate repeats up the wall, so a bottom-to-top gradient would band at
    # every repeat. Soot is carried by tileable vertical smoke streaks instead
    # (fast along u, slow along v); the wall-scale rise belongs to AR-04 decals.
    plumes = _fbm(size, rng, 6, 2, octaves=4)
    streaks = _fbm(size, rng, 14, 2, octaves=3)
    soot = np.clip(_smooth(0.3, 0.75, 0.5 * plumes + 0.5 * streaks) * 0.9 + 0.1, 0.0, 1.0)
    black = _rgb(0x231E1A)[None, None, :] * (0.8 + 0.4 * plumes)[..., None]
    return _mix(rgb, black, soot * 0.82), height


def _surface_recess(rng: np.random.Generator, size: int) -> tuple[np.ndarray, np.ndarray]:
    rgb = _rgb(0x16120F)[None, None, :] * (0.9 + 0.2 * _fbm(size, rng, 8, octaves=2))[..., None]
    return rgb, np.full((size, size), 0.5, dtype=np.float32)


def surface_texture(kind: str, rng: np.random.Generator, size: int = TEXTURE_SIZE) -> tuple[np.ndarray, np.ndarray]:
    if kind == "rubble":
        return _surface_coursed(rng, size, 0x8E8C85, 0xA39D8E, (0.04, 0.12), (0.1, 0.34), 4.2, 0.1, 0.35)
    if kind == "rubble_dark":
        return _surface_coursed(rng, size, 0x6E6C66, 0x847E72, (0.06, 0.14), (0.14, 0.4), 4.6, 0.12, 0.2)
    if kind == "ashlar":
        return _surface_coursed(rng, size, 0x9C988C, 0xA6A08E, (0.22, 0.3), (0.3, 0.55), 2.4, 0.05)
    if kind == "render":
        # Double-size tile: loss zones must be metre-scale, so the rubble under
        # the render repeats 2x2 inside one 4 m render tile.
        rubble_rgb, rubble_height = surface_texture("rubble", rng, size)
        under = (np.tile(rubble_rgb, (2, 2, 1)), np.tile(rubble_height, (2, 2)))
        return _surface_limewash(rng, size * 2, under, 0.36, 3, 0xB4AC98)
    if kind == "limewash":
        return _surface_limewash(rng, size, _surface_daub(rng, size), 0.2)
    if kind == "wattle":
        return _surface_wattle(rng, size)
    if kind == "oak":
        return _surface_timber(rng, size, 0x6E5C48, 0, 0.7)
    if kind == "oak_dark":
        return _surface_timber(rng, size, 0x4C3D2E, 4, 0.35)
    if kind == "boards":
        return _surface_timber(rng, size, 0x6A5C4C, 6, 0.8)
    if kind == "log":
        return _surface_log(rng, size)
    if kind == "caulk":
        return _surface_caulk(rng, size)
    if kind == "tile":
        return _surface_tile(rng, size)
    if kind == "shingle":
        return _surface_shingle(rng, size)
    if kind == "thatch":
        return _surface_thatch(rng, size)
    if kind == "iron":
        return _surface_iron(rng, size)
    if kind == "rope":
        return _surface_rope(rng, size)
    if kind == "daub":
        return _surface_daub(rng, size)
    if kind == "brick":
        return _surface_brick(rng, size)
    if kind == "log_course":
        return _surface_log_courses(rng, size)
    if kind == "boards_horizontal":
        return _surface_boards_horizontal(rng, size)
    if kind == "gable_board":
        return _surface_gable_board(rng, size)
    if kind == "straw":
        return _surface_straw(rng, size)
    if kind == "soot":
        return _surface_soot(rng, size)
    return _surface_recess(rng, size)


def _normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    """OpenGL-convention (+Y up) tangent-space normal map, as glTF expects."""
    du = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dv = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -du * strength
    ny = -dv * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack((nx / length, ny / length, nz / length), axis=-1) * 0.5 + 0.5


def _image(name: str, rgb: np.ndarray, non_color: bool) -> bpy.types.Image:
    size = rgb.shape[0]
    pixels = np.concatenate((np.clip(rgb, 0.0, 1.0), np.ones((size, size, 1), dtype=np.float32)), axis=2)
    image = bpy.data.images.new(name, width=size, height=size, alpha=False)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.file_format = "PNG"
    # Byte images store display-encoded values, so sRGB albedo is written as-is.
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.pack()
    return image


# --- materials ----------------------------------------------------------------

# key: (surface, metres per texture tile, roughness, metallic, normal strength, UV grain rule)
MATERIAL_TABLE: dict[str, tuple[str, float, float, float, float, str]] = {
    "rubble": ("rubble", 2.0, 0.94, 0.0, 6.0, "up"),
    "rubble_dark": ("rubble_dark", 2.0, 0.95, 0.0, 6.0, "up"),
    "ashlar": ("ashlar", 1.2, 0.9, 0.0, 4.0, "up"),
    "render": ("render", 4.0, 0.93, 0.0, 5.0, "up"),
    "limewash": ("limewash", 2.2, 0.93, 0.0, 3.0, "up"),
    "wattle": ("wattle", 1.0, 0.95, 0.0, 6.0, "up"),
    "oak": ("oak", 1.4, 0.86, 0.0, 3.0, "long"),
    "oak_dark": ("oak_dark", 1.0, 0.84, 0.0, 3.0, "up"),
    "boards": ("boards", 1.5, 0.88, 0.0, 3.5, "up"),
    "log": ("log", 1.6, 0.9, 0.0, 3.0, "long"),
    "caulk": ("caulk", 0.8, 1.0, 0.0, 3.0, "long"),
    "tile": ("tile", 1.5, 0.8, 0.0, 7.0, "roof"),
    "shingle": ("shingle", 1.4, 0.9, 0.0, 6.0, "roof"),
    "thatch": ("thatch", 1.6, 0.97, 0.0, 9.0, "roof"),
    "iron": ("iron", 0.6, 0.6, 0.55, 2.0, "long"),
    "rope": ("rope", 0.3, 0.95, 0.0, 2.0, "long"),
    "recess": ("recess", 1.0, 1.0, 0.0, 0.0, "up"),
}

MATERIAL_LABELS = {
    "rubble": "LimestoneRubble",
    "rubble_dark": "LimestonePlinth",
    "ashlar": "LimestoneDressed",
    "render": "LimeRender",
    "limewash": "Limewash",
    "wattle": "Wattle",
    "oak": "OakWeathered",
    "oak_dark": "OakPlank",
    "boards": "Boards",
    "log": "Log",
    "caulk": "MossCaulk",
    "tile": "ClayTile",
    "shingle": "WoodShingle",
    "thatch": "ReedThatch",
    "iron": "WroughtIron",
    "rope": "Rope",
    "recess": "Recess",
}

WALL_KEYS = {"rubble", "rubble_dark", "ashlar", "render", "limewash", "wattle", "boards", "caulk"}
TIMBER_KEYS = {"oak", "oak_dark", "log"}
ROOF_KEYS = {"tile", "shingle", "thatch"}


class Materials:
    """Lazily created, shared per kit so variant GLBs stay visually consistent."""

    def __init__(self, prefix: str) -> None:
        self.prefix = prefix
        self._cache: dict[str, bpy.types.Material] = {}

    def __getitem__(self, key: str) -> bpy.types.Material:
        if key not in self._cache:
            self._cache[key] = self._create(key)
        return self._cache[key]

    def items(self):
        return self._cache.items()

    def _create(self, key: str) -> bpy.types.Material:
        surface, _tile, roughness, metallic, normal_strength, _grain = MATERIAL_TABLE[key]
        name = f"{self.prefix}{MATERIAL_LABELS[key]}"
        rng = _np_rng(f"{self.prefix}:{key}")
        rgb, height = surface_texture(surface, rng)
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        mean = rgb.reshape(-1, 3).mean(axis=0)
        material.diffuse_color = (float(mean[0]), float(mean[1]), float(mean[2]), 1.0)
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        principled = nodes.get("Principled BSDF")
        principled.inputs["Metallic"].default_value = metallic
        principled.inputs["Roughness"].default_value = roughness
        albedo = nodes.new("ShaderNodeTexImage")
        albedo.name = "Albedo"
        albedo.image = _image(f"{name}_albedo", rgb, False)
        links.new(albedo.outputs["Color"], principled.inputs["Base Color"])
        if normal_strength > 0.0:
            normal_tex = nodes.new("ShaderNodeTexImage")
            normal_tex.image = _image(f"{name}_normal", _normal_from_height(height, normal_strength), True)
            normal_map = nodes.new("ShaderNodeNormalMap")
            links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
        material["kit_key"] = key
        return material


def enable_preview_vertex_colors(materials: Materials) -> None:
    """Multiply albedo by the baked wear colours for the Blender evidence plates.

    Export keeps albedo wired straight to Base Color (the glTF exporter then
    writes a plain baseColorTexture) and ships the wear as COLOR_0, which Godot
    multiplies into albedo on import.
    """
    for _key, material in materials.items():
        nodes = material.node_tree.nodes
        if nodes.get("WearMultiply") is not None:
            continue
        links = material.node_tree.links
        principled = nodes.get("Principled BSDF")
        albedo = nodes.get("Albedo")
        attribute = nodes.new("ShaderNodeVertexColor")
        attribute.layer_name = "Col"
        mix = nodes.new("ShaderNodeMix")
        mix.name = "WearMultiply"
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        links.new(albedo.outputs["Color"], mix.inputs[6])
        links.new(attribute.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], principled.inputs["Base Color"])


# --- transforms ---------------------------------------------------------------


def at(x: float, y: float, z: float) -> Matrix:
    return Matrix.Translation((x, y, z))


def rot_x(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "X")


def rot_y(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "Y")


def rot_z(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "Z")


# --- house builder --------------------------------------------------------------


class House:
    """Collects kit objects for one house and bakes UVs, wear and export."""

    def __init__(self, name: str, materials: Materials, width: float, depth: float) -> None:
        self.name = name
        self.materials = materials
        self.width = width
        self.depth = depth
        self.front = -depth * 0.5
        self.back = depth * 0.5
        self.rng = random.Random(int(hashlib.sha256(name.encode("utf-8")).hexdigest()[:12], 16))
        self.objects: list[bpy.types.Object] = []
        self.eave = 0.0
        self.ridge = 0.0
        # (world point, radius, strength) - soot darkening above flues and vents.
        self.soot: list[tuple[Vector, float, float]] = []
        # (x centre, face y, top z, half width, length) - runoff below sills.
        self.stains: list[tuple[float, float, float, float, float]] = []
        self.features: dict[str, object] = {}
        # Blender-space point where the hearth smoke leaves (flue top or gable vent).
        self.smoke_outlet: Vector | None = None

    # -- primitive objects ------------------------------------------------------

    def _link(self, name: str, bm: bmesh.types.BMesh, key: str, transform: Matrix, smooth: bool) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(f"{name}Mesh")
        bm.to_mesh(mesh)
        bm.free()
        for polygon in mesh.polygons:
            polygon.use_smooth = smooth
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.matrix_world = transform
        obj.data.materials.append(self.materials[key])
        obj["kit_key"] = key
        self.objects.append(obj)
        return obj

    def box(
        self,
        name: str,
        size: tuple[float, float, float],
        transform: Matrix,
        key: str,
        bevel: float = 0.0,
    ) -> bpy.types.Object:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for vert in bm.verts:
            vert.co = Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2]))
        if bevel > 0.0:
            limit = min(size) * 0.45
            bmesh.ops.bevel(
                bm,
                geom=list(bm.verts) + list(bm.edges),
                offset=min(bevel, limit),
                segments=1,
                affect="EDGES",
                profile=0.5,
            )
        return self._link(name, bm, key, transform, False)

    def cylinder(
        self,
        name: str,
        radius: float,
        length: float,
        transform: Matrix,
        key: str,
        segments: int = 8,
        radius_end: float | None = None,
    ) -> bpy.types.Object:
        """Cylinder along local Z, centred on the transform origin."""
        bm = bmesh.new()
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=False,
            segments=segments,
            radius1=radius,
            radius2=radius if radius_end is None else radius_end,
            depth=length,
        )
        obj = self._link(name, bm, key, transform, True)
        # Caps stay flat so log ends read as sawn faces.
        for polygon in obj.data.polygons:
            if abs(polygon.normal.z) > 0.9:
                polygon.use_smooth = False
        return obj

    def prism(
        self,
        name: str,
        outline: list[tuple[float, float]],
        thickness: float,
        transform: Matrix,
        key: str,
    ) -> bpy.types.Object:
        """Extrude an XZ outline along +Y by ``thickness`` (front face at y=0)."""
        bm = bmesh.new()
        front = [bm.verts.new((x, 0.0, z)) for x, z in outline]
        back = [bm.verts.new((x, thickness, z)) for x, z in outline]
        count = len(outline)
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for index in range(count):
            nxt = (index + 1) % count
            bm.faces.new((front[index], front[nxt], back[nxt], back[index]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._link(name, bm, key, transform, False)

    def slab(
        self,
        name: str,
        top: list[list[Vector]],
        offset: Vector,
        key: str,
        uvs: list[list[tuple[float, float]]],
    ) -> bpy.types.Object:
        """Closed slab from a (rows x cols) top grid and a constant offset to the underside."""
        bm = bmesh.new()
        rows = len(top)
        cols = len(top[0])
        upper = [[bm.verts.new(top[r][c]) for c in range(cols)] for r in range(rows)]
        lower = [[bm.verts.new(top[r][c] + offset) for c in range(cols)] for r in range(rows)]
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for r in range(rows - 1):
            for c in range(cols - 1):
                face = bm.faces.new((upper[r][c], upper[r][c + 1], upper[r + 1][c + 1], upper[r + 1][c]))
                for loop, (rr, cc) in zip(face.loops, ((r, c), (r, c + 1), (r + 1, c + 1), (r + 1, c))):
                    loop[uv_layer].uv = uvs[rr][cc]
                bm.faces.new((lower[r][c], lower[r + 1][c], lower[r + 1][c + 1], lower[r][c + 1]))
        rim = (
            [(0, c) for c in range(cols)]
            + [(r, cols - 1) for r in range(1, rows)]
            + [(rows - 1, c) for c in range(cols - 2, -1, -1)]
            + [(r, 0) for r in range(rows - 2, 0, -1)]
        )
        for index in range(len(rim)):
            a = rim[index]
            b = rim[(index + 1) % len(rim)]
            bm.faces.new((upper[a[0]][a[1]], lower[a[0]][a[1]], lower[b[0]][b[1]], upper[b[0]][b[1]]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = self._link(name, bm, key, Matrix.Identity(4), True)
        obj["kit_uv_done"] = True
        return obj

    def blob(
        self,
        name: str,
        centre: tuple[float, float],
        radius: tuple[float, float],
        face: str,
        plane: float,
        key: str,
        proud: float = 0.012,
        points: int = 11,
    ) -> bpy.types.Object:
        """Irregular flat patch (render remnant, fallen daub, soot) on a wall face."""
        outline = []
        for index in range(points):
            angle = math.tau * index / points
            wobble = 0.65 + 0.5 * self.rng.random()
            outline.append((math.cos(angle) * radius[0] * wobble, math.sin(angle) * radius[1] * wobble))
        if face == "front":
            transform = at(centre[0], plane - proud, centre[1])
        elif face == "back":
            transform = at(centre[0], plane + proud, centre[1]) @ rot_z(math.pi)
        elif face == "left":
            transform = at(plane - proud, centre[0], centre[1]) @ rot_z(-math.pi * 0.5)
        else:
            transform = at(plane + proud, centre[0], centre[1]) @ rot_z(math.pi * 0.5)
        return self.prism(name, outline, proud * 0.8, transform, key)

    # -- post-processing ----------------------------------------------------------

    def densify(self, obj: bpy.types.Object, step: float = 1.2) -> None:
        """Cut large faces so baked vertex-colour wear has vertices to live on."""
        mw = obj.matrix_world
        inverse = mw.inverted()
        normal_matrix = mw.to_3x3().transposed()
        corners = [mw @ Vector(corner) for corner in obj.bound_box]
        low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
        high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        cuts: list[tuple[int, float]] = []
        for level in (0.18, 0.45, 0.85, 1.35, 2.0):
            if low.z + 0.05 < level < high.z - 0.05:
                cuts.append((2, level))
        for axis in range(3):
            span = high[axis] - low[axis]
            if span > step * 1.5:
                count = int(span / step)
                for index in range(1, count + 1):
                    value = low[axis] + span * index / (count + 1)
                    if axis == 2 and value < 2.2:
                        continue
                    cuts.append((axis, value))
        for axis, value in cuts:
            point = Vector((0.0, 0.0, 0.0))
            point[axis] = value
            normal = Vector((0.0, 0.0, 0.0))
            normal[axis] = 1.0
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
            bmesh.ops.bisect_plane(
                bm,
                geom=geom,
                plane_co=inverse @ point,
                plane_no=(normal_matrix @ normal).normalized(),
                clear_inner=False,
                clear_outer=False,
            )
        bm.to_mesh(obj.data)
        bm.free()

    def _box_uv(self, obj: bpy.types.Object) -> None:
        key = str(obj["kit_key"])
        _surface, tile, _r, _m, _n, grain = MATERIAL_TABLE[key]
        mesh = obj.data
        layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
        coords = [vert.co for vert in mesh.vertices]
        mins = [min(c[i] for c in coords) for i in range(3)]
        maxs = [max(c[i] for c in coords) for i in range(3)]
        spans = [maxs[i] - mins[i] for i in range(3)]
        long_axis = max(range(3), key=lambda i: spans[i])
        offset_u = self.rng.random()
        offset_v = self.rng.random()
        world = obj.matrix_world
        for polygon in mesh.polygons:
            normal = polygon.normal
            axis = max(range(3), key=lambda i: abs(normal[i]))
            plane_axes = [i for i in range(3) if i != axis]
            if grain == "long" and long_axis in plane_axes:
                v_axis = long_axis
                u_axis = plane_axes[0] if plane_axes[1] == long_axis else plane_axes[1]
            elif axis == 2:
                u_axis, v_axis = 0, 1
            else:
                u_axis, v_axis = plane_axes[0], 2
            for loop_index in polygon.loop_indices:
                co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
                if grain == "up" and axis != 2:
                    # World-height v keeps masonry courses level across objects.
                    world_co = world @ co
                    u = co[u_axis]
                    v = world_co.z
                else:
                    u = co[u_axis]
                    v = co[v_axis]
                layer.data[loop_index].uv = (u / tile + offset_u, v / tile + offset_v)

    def _wear_colours(self, obj: bpy.types.Object) -> None:
        key = str(obj["kit_key"])
        mesh = obj.data
        world = obj.matrix_world
        attribute = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        seed = int(hashlib.sha256(self.name.encode("utf-8")).hexdigest()[:6], 16)
        is_chimney = obj.name.startswith("Chimney")
        per_vertex: list[tuple[float, float, float]] = []
        for vert in mesh.vertices:
            p = world @ vert.co
            r = g = b = 1.0
            variation = 0.94 + 0.12 * _noise3(p.x * 0.9, p.y * 0.9, p.z * 0.9, seed)
            r *= variation
            g *= variation
            b *= variation
            if key not in ROOF_KEYS:
                # Rising damp and splash-back: dark, slightly green-brown band.
                damp = float(_smooth_scalar(1.25, 0.0, p.z))
                damp *= 0.75 + 0.5 * _noise3(p.x * 1.7, p.y * 1.7, 3.1, seed + 7)
                r *= 1.0 - 0.52 * damp
                g *= 1.0 - 0.45 * damp
                b *= 1.0 - 0.58 * damp
                splash = float(_smooth_scalar(0.32, 0.0, p.z))
                r *= 1.0 - 0.12 * splash
                g *= 1.0 - 0.16 * splash
                b *= 1.0 - 0.22 * splash
            if key in WALL_KEYS or key in TIMBER_KEYS:
                # Runoff streaks: long vertical noise, stronger under the eaves.
                streak = _noise3(p.x * 2.6, p.y * 2.6, p.z * 0.18, seed + 11)
                under_eave = float(_smooth_scalar(self.eave - 1.6, self.eave, p.z)) if self.eave > 0.0 else 0.0
                dirt = max(0.0, streak - 0.42) * 0.8 + 0.2 * under_eave
                r *= 1.0 - dirt
                g *= 1.0 - dirt
                b *= 1.0 - dirt * 1.1
            if key in ROOF_KEYS:
                lowness = 1.0 - float(_smooth_scalar(self.eave, self.ridge, p.z)) if self.ridge > self.eave else 0.5
                moss_field = _noise3(p.x * 0.55, p.y * 0.55, p.z * 0.55, seed + 23)
                moss = max(0.0, min(1.0, (moss_field - 0.5) * 3.0)) * (0.35 + 0.65 * lowness)
                if key == "tile":
                    moss *= 0.75
                elif key == "thatch":
                    moss *= 0.6
                # Olive-dark rather than saturated green: Godot's linear
                # multiply reads much greener than the AgX evidence plates.
                r *= 1.0 - 0.3 * moss
                g *= 1.0 - 0.2 * moss
                b *= 1.0 - 0.38 * moss
                grime = 0.9 + 0.1 * _noise3(p.x * 2.2, p.y * 2.2, p.z * 2.2, seed + 29)
                r *= grime
                g *= grime
                b *= grime
            if key in WALL_KEYS:
                for sx, sy, top, half_w, length in self.stains:
                    dx = abs(p.x - sx)
                    if abs(p.y - sy) < 0.35 and dx < half_w and top - length < p.z < top:
                        fade = (1.0 - (top - p.z) / length) * (1.0 - dx / half_w)
                        stain = 0.32 * fade
                        r *= 1.0 - stain
                        g *= 1.0 - stain * 0.95
                        b *= 1.0 - stain * 0.85
            for point, radius, strength in self.soot:
                distance = (p - point).length
                if distance < radius and p.z >= point.z - 0.3:
                    soot = strength * (1.0 - distance / radius)
                    r *= 1.0 - soot
                    g *= 1.0 - soot
                    b *= 1.0 - soot
            if is_chimney:
                soot = float(_smooth_scalar(self.ridge - 0.5, self.ridge + 1.2, p.z)) * 0.55
                r *= 1.0 - soot
                g *= 1.0 - soot
                b *= 1.0 - soot
            per_vertex.append((max(0.0, r), max(0.0, g), max(0.0, b)))
        for loop in mesh.loops:
            colour = per_vertex[loop.vertex_index]
            attribute.data[loop.index].color = (colour[0], colour[1], colour[2], 1.0)
        mesh.color_attributes.active_color = attribute

    def finish(self) -> bpy.types.Object:
        """Bake UVs + wear, join per material, parent under one root empty."""
        # Data-API objects have no evaluated bounds until the depsgraph updates.
        bpy.context.view_layer.update()
        for obj in self.objects:
            key = str(obj["kit_key"])
            corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
            extent = max(
                max(c[i] for c in corners) - min(c[i] for c in corners) for i in range(3)
            )
            if (key in WALL_KEYS or key in TIMBER_KEYS) and extent > 1.6 and not obj.get("kit_uv_done"):
                # Logs only need a few cuts along their length for streaks.
                self.densify(obj, 0.7 if key in WALL_KEYS else (2.6 if key == "log" else 1.2))
            if not obj.get("kit_uv_done"):
                self._box_uv(obj)
            self._wear_colours(obj)
        root = bpy.data.objects.new(self.name, None)
        bpy.context.collection.objects.link(root)
        groups: dict[str, list[bpy.types.Object]] = {}
        for obj in self.objects:
            groups.setdefault(str(obj["kit_key"]), []).append(obj)
        joined: list[bpy.types.Object] = []
        for key in sorted(groups):
            members = groups[key]
            bpy.ops.object.select_all(action="DESELECT")
            for member in members:
                member.select_set(True)
            bpy.context.view_layer.objects.active = members[0]
            if len(members) > 1:
                bpy.ops.object.join()
            merged = bpy.context.view_layer.objects.active
            # Bake the placement so the exported node carries identity transforms.
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            # glTF tangents (normal maps) need triangles; concave n-gons such as
            # arch rings must be split by Blender, not by the importer.
            bm = bmesh.new()
            bm.from_mesh(merged.data)
            bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
            bm.to_mesh(merged.data)
            bm.free()
            merged.name = f"{self.name}{MATERIAL_LABELS[key]}"
            merged.data.name = f"{merged.name}Mesh"
            colours = merged.data.color_attributes.get("Col")
            if colours is not None:
                merged.data.color_attributes.active_color = colours
            merged.parent = root
            joined.append(merged)
        self.objects = joined
        bpy.context.view_layer.update()
        return root

    # -- roofs --------------------------------------------------------------------

    def roof(
        self,
        cover: str,
        eave: float,
        overhang: float,
        ext_front: float,
        ext_back: float,
        thickness: float,
        sag: float,
        jitter: float,
        pitch_deg: float = ROOF_PITCH_DEG,
    ) -> dict[str, float]:
        """Two sagging slabs on a gable roof, ridge along the plot depth."""
        pitch = math.radians(pitch_deg)
        half = self.width * 0.5
        lift = thickness / math.cos(pitch)
        ridge_top = eave + lift + half * math.tan(pitch)
        run = half + overhang
        eave_top = ridge_top - run * math.tan(pitch)
        y0 = self.front - ext_front
        y1 = self.back + ext_back
        length = y1 - y0
        slope = math.hypot(run, ridge_top - eave_top)
        cols = max(10, int(length / (0.5 if cover == "thatch" else 0.65)))
        rows = max(5, int(slope / (0.5 if cover == "thatch" else 0.65)))
        seed = int(hashlib.sha256(f"{self.name}:{cover}".encode("utf-8")).hexdigest()[:6], 16)
        _surface, tile, *_rest = MATERIAL_TABLE[cover]

        def point(side: float, a: float, t: float) -> Vector:
            # a: 0 at the eave, 1 at the ridge; t: 0 at the front, 1 at the back.
            x = side * run * (1.0 - a)
            z = eave_top + (ridge_top - eave_top) * a
            y = y0 + length * t
            z -= sag * math.sin(math.pi * t) * (0.3 + 0.7 * a)
            wave = _noise3(x * 0.8, y * 0.8, side * 3.0, seed) - 0.5
            z += wave * jitter * (0.6 + 0.4 * (1.0 - a))
            if a < 0.02:
                # Eave line wanders where rafters settled unevenly.
                z += (_noise3(0.0, y * 0.35, side * 5.0, seed + 3) - 0.5) * jitter * 2.0
            return Vector((x, y, z))

        for side in (1.0, -1.0):
            normal = Vector((side * math.sin(pitch), 0.0, math.cos(pitch)))
            grid = [[point(side, r / rows, c / cols) for c in range(cols + 1)] for r in range(rows + 1)]
            uvs = [
                [(y0 / tile + length * c / cols / tile, (1.0 - r / rows) * -slope / tile) for c in range(cols + 1)]
                for r in range(rows + 1)
            ]
            if side < 0.0:
                # Keep the quad winding consistent after mirroring.
                grid = [list(reversed(row)) for row in grid]
                uvs = [list(reversed(row)) for row in uvs]
            self.slab(f"RoofSlope{'E' if side > 0 else 'W'}", grid, -normal * thickness, cover, uvs)
        self.eave = eave
        self.ridge = ridge_top
        return {
            "ridge_top": ridge_top,
            "eave_top": eave_top,
            "run": run,
            "y0": y0,
            "y1": y1,
            "pitch": pitch,
            "sag": sag,
            "length": length,
            "thickness": thickness,
        }

    def roof_surface(self, roof: dict[str, float], side: float, a: float, t: float) -> Vector:
        """Undisturbed top-surface point (sag included) for placing roof dressing."""
        x = side * roof["run"] * (1.0 - a)
        z = roof["eave_top"] + (roof["ridge_top"] - roof["eave_top"]) * a
        z -= roof["sag"] * math.sin(math.pi * t) * (0.3 + 0.7 * a)
        return Vector((x, roof["y0"] + roof["length"] * t, z))

    def ridge_tiles(self, roof: dict[str, float]) -> None:
        count = max(6, int(roof["length"] / 0.42))
        for index in range(count):
            t = (index + 0.5) / count
            p = self.roof_surface(roof, 1.0, 1.0, t)
            roll = self.rng.uniform(-0.05, 0.05)
            self.cylinder(
                f"RidgeTile{index:02d}",
                0.15,
                roof["length"] / count + 0.03,
                at(self.rng.uniform(-0.02, 0.02), p.y, p.z + 0.04) @ rot_y(roll) @ rot_x(math.pi * 0.5),
                "tile",
                segments=8,
            )

    def ridge_boards(self, roof: dict[str, float], key: str = "boards") -> None:
        segments = 6
        pitch = roof["pitch"]
        seg_len = roof["length"] / segments
        for index in range(segments):
            t = (index + 0.5) / segments
            p = self.roof_surface(roof, 1.0, 1.0, t)
            for side in (1.0, -1.0):
                self.box(
                    f"RidgeBoard{index}{'E' if side > 0 else 'W'}",
                    (0.26, seg_len + 0.02, 0.035),
                    at(side * 0.1, p.y, p.z + 0.035) @ rot_y(side * pitch),
                    key,
                )

    def thatch_ridge(self, roof: dict[str, float]) -> None:
        """Rolled reed ridge weighted by crossed rider poles (Estonian harjapuud)."""
        # The roll stops short of the verges; a full-length roll reads as a log end.
        inset = 0.35
        segments = max(6, int(roof["length"] / 0.9))
        seg_len = (roof["length"] - inset * 2.0) / segments
        pitch = roof["pitch"]
        for index in range(segments):
            t = (inset + seg_len * (index + 0.5)) / roof["length"]
            p = self.roof_surface(roof, 1.0, 1.0, t)
            self.cylinder(
                f"ThatchRidgeRoll{index:02d}",
                0.26,
                seg_len + 0.06,
                at(0.0, p.y, p.z - 0.04) @ rot_x(math.pi * 0.5),
                "thatch",
                segments=10,
            )
        riders = max(3, int(roof["length"] / 1.05))
        for index in range(riders):
            t = (index + 0.5) / riders
            p = self.roof_surface(roof, 1.0, 1.0, t)
            skew = self.rng.uniform(-0.06, 0.06)
            for side in (1.0, -1.0):
                direction = Vector((side * math.cos(pitch), 0.0, -math.sin(pitch)))
                normal = Vector((side * math.sin(pitch), 0.0, math.cos(pitch)))
                centre = Vector((0.0, p.y, p.z)) + direction * 0.3 + normal * 0.26
                self.box(
                    f"Rider{index:02d}{'E' if side > 0 else 'W'}",
                    (1.45, 0.08, 0.08),
                    at(centre.x, centre.y, centre.z) @ rot_z(skew) @ rot_y(side * pitch),
                    "oak",
                )

    def verge_boards(self, roof: dict[str, float]) -> None:
        pitch = roof["pitch"]
        slope = roof["run"] / math.cos(pitch)
        for end, y in (("Front", roof["y0"] + 0.02), ("Back", roof["y1"] - 0.02)):
            for side in (1.0, -1.0):
                mid = self.roof_surface(roof, side, 0.5, 0.0 if end == "Front" else 1.0)
                self.box(
                    f"Verge{end}{'E' if side > 0 else 'W'}",
                    (slope + 0.1, 0.045, 0.24),
                    at(mid.x, y, mid.z - roof["thickness"] * 0.5) @ rot_y(side * pitch),
                    "boards",
                )

    def roof_patches(self, roof: dict[str, float], key: str, count: int) -> None:
        """Mismatched repairs laid over the old cover."""
        pitch = roof["pitch"]
        for index in range(count):
            side = 1.0 if self.rng.random() < 0.5 else -1.0
            a = self.rng.uniform(0.15, 0.75)
            t = self.rng.uniform(0.15, 0.85)
            p = self.roof_surface(roof, side, a, t)
            normal = Vector((side * math.sin(pitch), 0.0, math.cos(pitch)))
            p = p + normal * 0.02
            self.box(
                f"RoofPatch{index}",
                (self.rng.uniform(0.6, 1.1), self.rng.uniform(0.5, 1.2), 0.03),
                at(p.x, p.y, p.z) @ rot_y(side * pitch) @ rot_z(self.rng.uniform(-0.04, 0.04)),
                key,
            )

    # -- gables -------------------------------------------------------------------

    def gable_under_roof(self, name: str, y_face: float, depth: float, eave: float, pitch_deg: float, key: str, facing: float) -> None:
        """Triangle closing the roof void; ``facing`` -1 front, +1 back."""
        half = self.width * 0.5
        apex = eave + half * math.tan(math.radians(pitch_deg))
        outline = [(-half, eave), (half, eave), (0.0, apex)]
        y = y_face if facing < 0.0 else y_face - depth
        self.prism(name, outline, depth, at(0.0, y, 0.0), key)

    def parapet_gable(
        self, name: str, roof: dict[str, float], facing: float, thickness: float = 0.55, key: str = "rubble"
    ) -> None:
        """Stone gable carried above the roof with rough coping (fire wall)."""
        half = self.width * 0.5
        pitch = roof["pitch"]
        lift = 0.32
        shoulder = self.eave + roof["thickness"] / math.cos(pitch) + lift
        apex = roof["ridge_top"] + lift
        outline = [(-half, self.eave), (half, self.eave), (half, shoulder), (0.0, apex), (-half, shoulder)]
        y = self.front if facing < 0.0 else self.back - thickness
        self.prism(name, outline, thickness, at(0.0, y, 0.0), key)
        slope = math.hypot(half, apex - shoulder)
        stones = 9
        seg = slope / stones
        skip = self.rng.randrange(1, stones - 1) if facing < 0.0 else -1
        y_mid = y + thickness * 0.5
        for side in (1.0, -1.0):
            for index in range(stones):
                if side > 0.0 and index == skip:
                    continue  # one coping stone lost to frost
                f = (index + 0.5) / stones
                x = side * half * (1.0 - f)
                z = shoulder + (apex - shoulder) * f + 0.07
                self.box(
                    f"{name}Coping{'E' if side > 0 else 'W'}{index}",
                    (seg + 0.02, thickness + 0.12, 0.13),
                    at(x, y_mid + self.rng.uniform(-0.02, 0.02), z)
                    @ rot_y(side * pitch + self.rng.uniform(-0.03, 0.03)),
                    "ashlar",
                )
            self.box(
                f"{name}Kneeler{'E' if side > 0 else 'W'}",
                (0.5, thickness + 0.14, 0.34),
                at(side * (half - 0.2), y_mid, shoulder - 0.02),
                "ashlar",
                0.02,
            )
        self.box(f"{name}Apex", (0.34, thickness + 0.14, 0.4), at(0.0, y_mid, apex + 0.18), "ashlar", 0.02)

    def board_gable(self, name: str, eave: float, pitch_deg: float, facing: float, jetty: float = 0.06) -> None:
        """Vertical board cladding with battens, slightly proud of the wall below."""
        half = self.width * 0.5
        rise = math.tan(math.radians(pitch_deg))
        apex = eave + half * rise
        y_face = (self.front - jetty) if facing < 0.0 else (self.back + jetty)
        depth = 0.12
        outline = [(-half - jetty, eave), (half + jetty, eave), (0.0, apex + jetty * rise)]
        y = y_face if facing < 0.0 else y_face - depth
        self.prism(name, outline, depth, at(0.0, y, 0.0), "boards")
        self.box(f"{name}Girt", (self.width + 0.2, depth + 0.08, 0.2), at(0.0, y + depth * 0.5, eave + 0.02), "oak")
        battens = int(self.width / 0.55)
        for index in range(battens + 1):
            x = -half + self.width * index / battens
            top = apex - abs(x) * rise - 0.08
            height = top - eave - 0.1
            if height < 0.25:
                continue
            y_batten = y_face - 0.02 if facing < 0.0 else y_face + 0.02
            self.box(
                f"{name}Batten{index}",
                (0.07, 0.04, height),
                at(x + self.rng.uniform(-0.03, 0.03), y_batten, eave + 0.1 + height * 0.5),
                "boards",
            )

    # -- openings ------------------------------------------------------------------

    def recess(self, name: str, x: float, z0: float, width: float, height: float, face_y: float, facing: float = -1.0) -> None:
        self.box(f"{name}Recess", (width, 0.06, height), at(x, face_y + facing * 0.012, z0 + height * 0.5), "recess")

    def plank_leaf(
        self, name: str, x: float, z0: float, width: float, height: float, face_y: float, facing: float, key: str = "oak_dark"
    ) -> None:
        """Ledged plank leaf with strap hinges; set just inside the frame."""
        y = face_y + facing * 0.045
        self.box(f"{name}Leaf", (width, 0.06, height), at(x, y, z0 + height * 0.5), key, 0.01)
        for index, f in enumerate((0.18, 0.82)):
            self.box(
                f"{name}Strap{index}",
                (width * 0.78, 0.02, 0.05),
                at(x - width * 0.1, y + facing * 0.035, z0 + height * f),
                "iron",
            )

    def timber_frame_opening(
        self, name: str, x: float, z0: float, width: float, height: float, face_y: float, facing: float = -1.0
    ) -> None:
        y = face_y + facing * 0.06
        for side in (-1.0, 1.0):
            self.box(
                f"{name}Jamb{'R' if side > 0 else 'L'}",
                (0.13, 0.16, height + 0.12),
                at(x + side * (width * 0.5 + 0.065), y, z0 + height * 0.5)
                @ rot_y(self.rng.uniform(-0.012, 0.012)),
                "oak",
            )
        self.box(f"{name}Head", (width + 0.42, 0.18, 0.16), at(x, y, z0 + height + 0.08), "oak")
        self.box(f"{name}Sill", (width + 0.3, 0.2, 0.1), at(x, y - facing * 0.01, z0 - 0.05), "oak")

    def stone_frame_opening(
        self, name: str, x: float, z0: float, width: float, height: float, face_y: float, facing: float = -1.0
    ) -> None:
        y = face_y + facing * 0.06
        blocks = max(2, int(height / 0.42))
        for side in (-1.0, 1.0):
            for index in range(blocks):
                long = index % 2 == 0
                h = height / blocks
                self.box(
                    f"{name}Jamb{'R' if side > 0 else 'L'}{index}",
                    (0.3 if long else 0.2, 0.16, h - 0.02),
                    at(x + side * (width * 0.5 + (0.15 if long else 0.1)), y, z0 + h * (index + 0.5)),
                    "ashlar",
                )
        self.box(f"{name}Lintel", (width + 0.5, 0.18, 0.26), at(x, y, z0 + height + 0.13), "ashlar", 0.015)
        self.box(f"{name}Sill", (width + 0.4, 0.24, 0.12), at(x, y - facing * 0.02, z0 - 0.06), "ashlar", 0.015)

    def shuttered_opening(
        self,
        name: str,
        x: float,
        z0: float,
        width: float,
        height: float,
        face_y: float,
        state: str,
        stone: bool,
        facing: float = -1.0,
    ) -> None:
        """Unglazed opening: 1343 ordinary houses close with board shutters."""
        self.recess(name, x, z0, width, height, face_y, facing)
        self.stains.append((x, face_y, z0, width * 0.5 + 0.2, min(2.2, z0)))
        if stone:
            self.stone_frame_opening(name, x, z0, width, height, face_y, facing)
        else:
            self.timber_frame_opening(name, x, z0, width, height, face_y, facing)
        leaf = width * 0.5
        if state == "closed":
            for side in (-1.0, 1.0):
                self.box(
                    f"{name}Shutter{'R' if side > 0 else 'L'}",
                    (leaf - 0.02, 0.05, height - 0.04),
                    at(x + side * leaf * 0.5, face_y + facing * 0.04, z0 + height * 0.5),
                    "oak_dark",
                )
        elif state in {"open", "askew"}:
            for side in (-1.0, 1.0):
                hinge_x = x + side * (width * 0.5 + 0.14)
                tilt = self.rng.uniform(0.05, 0.1) if (state == "askew" and side > 0) else 0.0
                drop = 0.08 if tilt else 0.0
                self.box(
                    f"{name}Shutter{'R' if side > 0 else 'L'}",
                    (leaf - 0.02, 0.05, height - 0.04),
                    at(hinge_x + side * leaf * 0.5, face_y + facing * 0.11, z0 + height * 0.5 - drop)
                    @ rot_y(side * tilt),
                    "oak_dark",
                )

    def counter_shutter(self, name: str, x: float, z0: float, width: float, height: float, face_y: float) -> None:
        """Medieval shop window: lower leaf drops as a counter, upper leaf props up."""
        self.recess(name, x, z0, width, height, face_y)
        self.stains.append((x, face_y, z0, width * 0.5 + 0.2, min(1.5, z0)))
        self.timber_frame_opening(name, x, z0, width, height, face_y)
        self.box(f"{name}Counter", (width - 0.04, height * 0.5, 0.06), at(x, face_y - height * 0.25 - 0.06, z0 - 0.02), "oak_dark", 0.01)
        for side in (-1.0, 1.0):
            self.box(
                f"{name}Bracket{'R' if side > 0 else 'L'}",
                (0.07, 0.07, height * 0.62),
                at(x + side * (width * 0.5 - 0.1), face_y - height * 0.2, z0 - height * 0.26) @ rot_x(-0.72),
                "oak",
            )
        awning = height * 0.5
        self.box(
            f"{name}Awning",
            (width - 0.04, 0.06, awning),
            at(x, face_y - awning * 0.34, z0 + height + awning * 0.36) @ rot_x(0.95),
            "oak_dark",
            0.01,
        )
        self.box(
            f"{name}Prop",
            (0.045, 0.045, awning * 1.05),
            at(x + width * 0.3, face_y - awning * 0.34, z0 + height + 0.1) @ rot_x(-0.35),
            "oak",
        )

    def plank_door(self, name: str, x: float, z0: float, width: float, height: float, face_y: float, facing: float = -1.0) -> None:
        self.recess(name, x, z0, width, height, face_y, facing)
        self.timber_frame_opening(name, x, z0, width, height, face_y, facing)
        self.plank_leaf(name, x, z0, width - 0.06, height - 0.04, face_y, facing)
        self.box(f"{name}Ring", (0.1, 0.03, 0.1), at(x + width * 0.3, face_y + facing * 0.1, z0 + height * 0.5), "iron")

    def pointed_portal(self, name: str, x: float, z0: float, width: float, height: float, face_y: float) -> None:
        """Pointed-arch stone portal (1343-safe Gothic street entry)."""
        spring = z0 + height * 0.66
        apex = z0 + height
        inner = _pointed_arch_outline(width, spring, apex)
        opening = [(width * 0.5, z0)] + inner + [(-width * 0.5, z0)]
        self.prism(f"{name}Recess", opening, 0.05, at(x, face_y - 0.012, 0.0), "recess")
        leaf = [(px * 0.94, pz - 0.03 if pz > z0 + 0.01 else pz) for px, pz in opening]
        self.prism(f"{name}Leaf", leaf, 0.06, at(x, face_y - 0.07, 0.0), "oak_dark")
        for index, f in enumerate((0.2, 0.55)):
            self.box(
                f"{name}Strap{index}",
                (width * 0.74, 0.02, 0.055),
                at(x - width * 0.08, face_y - 0.1, z0 + (spring - z0) * f + 0.1),
                "iron",
            )
        self.box(f"{name}Ring", (0.11, 0.03, 0.11), at(x + width * 0.28, face_y - 0.11, z0 + height * 0.48), "iron")
        ring = _arch_ring_outline(width + 0.02, spring, apex, 0.24)
        self.prism(f"{name}Arch", ring, 0.2, at(x, face_y - 0.12, 0.0), "ashlar")
        blocks = max(3, int((spring - z0) / 0.4))
        for side in (-1.0, 1.0):
            for index in range(blocks):
                long = index % 2 == 0
                h = (spring - z0) / blocks
                self.box(
                    f"{name}Jamb{'R' if side > 0 else 'L'}{index}",
                    (0.34 if long else 0.24, 0.2, h - 0.02),
                    at(x + side * (width * 0.5 + (0.17 if long else 0.12)), face_y - 0.07, z0 + h * (index + 0.5)),
                    "ashlar",
                )

    def steps(self, name: str, x: float, width: float, face_y: float, count: int, rise: float = 0.16, tread: float = 0.34, base_z: float = 0.0) -> float:
        """Worn stone steps; returns the landing height."""
        for index in range(count):
            level = count - index
            z_top = base_z + rise * level
            y = face_y - tread * (index + 0.5) - 0.02
            if index == count - 1 and count > 1:
                # The bottom step has cracked and settled.
                for part, shift in ((0, -0.26), (1, 0.26)):
                    self.box(
                        f"{name}Step{index}_{part}",
                        (width * 0.48, tread, rise),
                        at(x + shift * width, y, z_top - rise * 0.5 - 0.02 * part) @ rot_z(self.rng.uniform(-0.03, 0.03)),
                        "ashlar",
                        0.025,
                    )
                continue
            self.box(
                f"{name}Step{index}",
                (width - index * 0.06, tread, rise),
                at(x + self.rng.uniform(-0.03, 0.03), y, z_top - rise * 0.5) @ rot_z(self.rng.uniform(-0.02, 0.02)),
                "ashlar",
                0.025,
            )
        return base_z + rise * count

    def cellar_neck(self, name: str, x: float, width: float, face_y: float) -> None:
        """Kellerhals: low stone cheek walls and sloping plank hatch to the cellar."""
        depth = 1.3
        height = 0.55
        for side in (-1.0, 1.0):
            self.box(
                f"{name}Cheek{'R' if side > 0 else 'L'}",
                (0.26, depth, height),
                at(x + side * (width * 0.5 - 0.13), face_y - depth * 0.5, height * 0.5),
                "rubble_dark",
                0.02,
            )
        slope = math.atan2(height - 0.12, depth)
        hatch_len = math.hypot(depth, height - 0.12)
        for side in (-1.0, 1.0):
            self.box(
                f"{name}Hatch{'R' if side > 0 else 'L'}",
                ((width - 0.52) * 0.5 - 0.02, hatch_len, 0.06),
                at(x + side * (width - 0.52) * 0.25, face_y - depth * 0.5, (height + 0.12) * 0.5 + 0.03)
                @ rot_x(slope)
                @ rot_y(self.rng.uniform(-0.02, 0.02)),
                "oak_dark",
            )
            self.box(
                f"{name}HatchStrap{'R' if side > 0 else 'L'}",
                ((width - 0.52) * 0.4, 0.05, 0.02),
                at(x + side * (width - 0.52) * 0.25, face_y - depth * 0.6, (height + 0.12) * 0.5 + 0.02) @ rot_x(slope),
                "iron",
            )

    def hoist(self, x: float, z: float, face_y: float, hook_z: float, protrude: float = 1.5) -> None:
        """Protruding hoisting beam with brace, sheave, rope and hook."""
        embed = 0.4
        length = protrude + embed
        self.box("HoistBeam", (0.2, length, 0.24), at(x, face_y - protrude + length * 0.5, z), "oak", 0.02)
        run = protrude - 0.3
        rise = 0.9
        brace = math.hypot(run, rise)
        self.box(
            "HoistBrace",
            (0.13, brace, 0.13),
            at(x, face_y - run * 0.5 - 0.05, z - rise * 0.5 - 0.06) @ rot_x(-math.atan2(rise, run)),
            "oak",
        )
        tip_y = face_y - protrude + 0.16
        self.cylinder("HoistSheave", 0.13, 0.08, at(x, tip_y, z - 0.24) @ rot_y(math.pi * 0.5), "oak", 10)
        rope_len = max(0.4, z - 0.3 - hook_z)
        self.cylinder("HoistRope", 0.018, rope_len, at(x + 0.1, tip_y, z - 0.3 - rope_len * 0.5), "rope", 6)
        self.box("HoistHook", (0.07, 0.07, 0.2), at(x + 0.1, tip_y, hook_z - 0.1), "iron", 0.015)

    def chimney(self, x: float, y: float, base_z: float, top_z: float, key: str = "rubble") -> None:
        height = top_z - base_z
        self.box("ChimneyStack", (0.72, 0.72, height), at(x, y, base_z + height * 0.5), key, 0.03)
        self.box("ChimneyCorbel", (0.9, 0.9, 0.12), at(x, y, top_z - 0.18), "ashlar", 0.02)
        self.box("ChimneyCap", (0.62, 0.62, 0.16), at(x + 0.02, y, top_z + 0.04), key, 0.02)
        self.soot.append((Vector((x, y, top_z)), 1.1, 0.5))
        self.smoke_outlet = Vector((x + 0.02, y, top_z + 0.2))

    def putlog_holes(self, face: str, rows: list[float], avoid: list[tuple[float, float, float, float]]) -> None:
        """Scaffold holes left in medieval rubble walls."""
        span = self.width if face in {"front", "back"} else self.depth
        for row_index, z in enumerate(rows):
            if z > self.eave - 0.4:
                continue
            count = max(2, int(span / 1.6))
            for index in range(count):
                u = -span * 0.5 + span * (index + 0.5) / count + self.rng.uniform(-0.25, 0.25)
                if any(x0 - 0.3 < u < x1 + 0.3 and z0 - 0.3 < z < z1 + 0.3 for x0, x1, z0, z1 in avoid) and face == "front":
                    continue
                if self.rng.random() < 0.6:
                    continue
                if face == "front":
                    transform = at(u, self.front - 0.012, z)
                elif face == "back":
                    transform = at(u, self.back + 0.012, z)
                elif face == "left":
                    transform = at(-self.width * 0.5 - 0.012, u, z)
                else:
                    transform = at(self.width * 0.5 + 0.012, u, z)
                size = (0.12, 0.03, 0.11) if face in {"front", "back"} else (0.03, 0.12, 0.11)
                self.box(f"Putlog{face}{row_index}_{index}", size, transform, "recess")

    def quoins(self, height: float, corners: list[tuple[float, float]], base: float = 0.0) -> None:
        """Irregular dressed corner stones, alternating stretcher/header."""
        z = base
        level = 0
        while z < height - 0.2:
            course = self.rng.uniform(0.3, 0.46)
            course = min(course, height - z)
            for cx, cy in corners:
                long_front = level % 2 == 0
                front_len = self.rng.uniform(0.42, 0.62) if long_front else self.rng.uniform(0.24, 0.34)
                side_len = self.rng.uniform(0.24, 0.34) if long_front else self.rng.uniform(0.42, 0.62)
                sx = 1.0 if cx > 0 else -1.0
                sy = 1.0 if cy > 0 else -1.0
                self.box(
                    f"Quoin{level}_{'E' if sx > 0 else 'W'}{'N' if sy > 0 else 'S'}",
                    (front_len, side_len, course - 0.03),
                    at(cx - sx * front_len * 0.5 + sx * 0.035, cy - sy * side_len * 0.5 + sy * 0.035, z + course * 0.5)
                    @ rot_z(self.rng.uniform(-0.015, 0.015)),
                    "ashlar",
                )
            z += course
            level += 1

    def firewood(self, x: float, y: float, along_y: bool, length: float, rows: int) -> None:
        for row in range(rows):
            count = int(length / 0.2)
            for index in range(count):
                offset = -length * 0.5 + (index + 0.5 + (row % 2) * 0.5) * (length / count)
                if offset > length * 0.5:
                    continue
                z = 0.1 + row * 0.17
                if along_y:
                    transform = at(x, y + offset, z) @ rot_y(math.pi * 0.5)
                else:
                    transform = at(x + offset, y, z) @ rot_x(math.pi * 0.5)
                self.cylinder(f"Firewood{row}_{index}", self.rng.uniform(0.07, 0.095), 0.55, transform, "log", 5)


# --- log walls ------------------------------------------------------------------


def build_log_walls(
    house: House,
    base_z: float,
    top_z: float,
    openings: dict[str, list[tuple[float, float, float, float]]],
    radius: float = 0.14,
    course: float = 0.25,
    overhang: float = 0.3,
) -> None:
    """Horizontal log walls with saddle-notched corner overhangs.

    Front/back logs sit half a course above/below the side logs, the way
    interlocking notches stack. Openings cut the logs and get board jambs.
    """
    half_w = house.width * 0.5
    half_d = house.depth * 0.5
    # Moss-caulked core behind the logs hides the gaps between rounds.
    house.box("LogCore", (house.width - radius * 1.6, house.depth - radius * 1.6, top_z - base_z), at(0.0, 0.0, (base_z + top_z) * 0.5), "caulk")
    faces = {
        "front": (-half_d, True),
        "back": (half_d, True),
        "left": (-half_w, False),
        "right": (half_w, False),
    }
    for face, (plane, along_x) in faces.items():
        z = base_z + radius * 0.9 + (0.0 if along_x else course * 0.5)
        index = 0
        span_half = half_w if along_x else half_d
        while z < top_z - radius * 0.4:
            intervals = [(-span_half - overhang, span_half + overhang)]
            for x0, x1, z0, z1 in openings.get(face, []):
                if z + radius * 0.7 > z0 and z - radius * 0.7 < z1:
                    split: list[tuple[float, float]] = []
                    for a, b in intervals:
                        if x1 <= a or x0 >= b:
                            split.append((a, b))
                            continue
                        if x0 > a:
                            split.append((a, x0))
                        if x1 < b:
                            split.append((x1, b))
                    intervals = split
            r = radius * house.rng.uniform(0.9, 1.1)
            for part, (a, b) in enumerate(intervals):
                length = b - a
                if length < 0.2:
                    continue
                centre = (a + b) * 0.5
                if along_x:
                    transform = at(centre, plane, z) @ rot_y(math.pi * 0.5)
                else:
                    transform = at(plane, centre, z) @ rot_x(math.pi * 0.5)
                house.cylinder(f"Log{face}{index:02d}_{part}", r, length, transform, "log", 6, r * house.rng.uniform(0.9, 1.0))
            z += course
            index += 1


# --- small geometry helpers ----------------------------------------------------------


def _pointed_arch_outline(width: float, spring_z: float, apex_z: float, segments: int = 7) -> list[tuple[float, float]]:
    """Pointed (Gothic) arch: two circular arcs meeting at the apex (right to left)."""
    half = width * 0.5
    rise = apex_z - spring_z
    # The right-hand arc is centred on the spring line left of the axis, so it
    # passes through the right springer and the apex (cusp for rise > half).
    centre_x = (half * half - rise * rise) / (2.0 * half) if half > 0.0 else 0.0
    radius = half - centre_x
    apex_angle = math.atan2(rise, -centre_x)
    right: list[tuple[float, float]] = []
    for index in range(segments + 1):
        t = index / segments
        angle = apex_angle * t
        right.append((centre_x + radius * math.cos(angle), spring_z + radius * math.sin(angle)))
    left = [(-x, z) for x, z in reversed(right[:-1])]
    return right + left


def _arch_ring_outline(width: float, spring_z: float, apex_z: float, band: float) -> list[tuple[float, float]]:
    """Closed outline of a voussoir band around a pointed arch, down to the springers."""
    inner = _pointed_arch_outline(width, spring_z, apex_z)
    outer = _pointed_arch_outline(width + band * 2.0, spring_z, apex_z + band * 1.1)
    return inner + list(reversed(outer))


def _hash_lattice(ix: int, iy: int, iz: int, seed: int) -> float:
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 15)) * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 3266489917) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFF) / 65535.0


def _noise3(x: float, y: float, z: float, seed: int) -> float:
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    sx = fx * fx * (3.0 - 2.0 * fx)
    sy = fy * fy * (3.0 - 2.0 * fy)
    sz = fz * fz * (3.0 - 2.0 * fz)
    total = 0.0
    for dx in (0, 1):
        wx = sx if dx else 1.0 - sx
        for dy in (0, 1):
            wy = sy if dy else 1.0 - sy
            for dz in (0, 1):
                wz = sz if dz else 1.0 - sz
                total += wx * wy * wz * _hash_lattice(ix + dx, iy + dy, iz + dz, seed)
    return total


def _smooth_scalar(edge0: float, edge1: float, value: float) -> float:
    t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


# --- export, metrics, evidence ---------------------------------------------------


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def mesh_metrics(house: House, asset_id: str) -> dict[str, object]:
    triangles = 0
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    has_colours = True
    for obj in house.objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        has_colours = has_colours and mesh.color_attributes.get("Col") is not None
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_v = Vector(map(min, min_v, world))
            max_v = Vector(map(max, max_v, world))
    dims = max_v - min_v
    return {
        "asset_id": asset_id,
        "triangles": triangles,
        "surfaces": len(house.objects),
        "dimensions_m": [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)],
        # Wall body the Godot loader fits to the footprint: width, eave height, depth.
        "body_m": [round(house.width, 4), round(house.eave, 4), round(house.depth, 4)],
        "ridge_m": round(house.ridge, 4),
        # Godot model space (x, up, -blender_y): where ChimneySmoke3D is moved to.
        "smoke_outlet_m": (
            None
            if house.smoke_outlet is None
            else [round(house.smoke_outlet.x, 4), round(house.smoke_outlet.z, 4), round(-house.smoke_outlet.y, 4)]
        ),
        "features": house.features,
        "checks": {
            "triangles_in_budget": TRIANGLE_BUDGET[0] <= triangles <= TRIANGLE_BUDGET[1],
            "non_empty": triangles > 0 and dims.x > 0.0 and dims.z > 0.0,
            "grounded": min_v.z > -0.05,
            "body_centred": abs(min_v.y + max_v.y) < 4.0 and abs(min_v.x + max_v.x) < 1.0,
            "wear_vertex_colours": has_colours,
        },
    }


def export_glb(root: bpy.types.Object, house: House, output: Path, asset_id: str) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in house.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_vertex_color="ACTIVE",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=False,
    )
    metrics = mesh_metrics(house, asset_id)
    metrics["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    return metrics


def write_evidence(evidence_dir: Path, brief: dict[str, object], reports: dict[str, object]) -> None:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / "brief.json").write_text(json.dumps(brief, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report = {
        "generator": GENERATOR_VERSION,
        "blender": BLENDER_VERSION,
        "historical_basis": "history/dossiers/architecture/burgher-house-plan.md",
        "assets": reports,
    }
    (evidence_dir / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (evidence_dir / "state.json").write_text(
        json.dumps(
            {
                "outputs": {asset_id: reports[asset_id]["sha256"] for asset_id in reports},
                "complete": all(all(metrics["checks"].values()) for metrics in reports.values()),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


# --- reference plates (evidence, non-runtime) ------------------------------------------


def render_plate(house: House, root: bpy.types.Object, output: Path, view: str) -> None:
    """Render one EEVEE evidence plate of an already built house."""
    enable_preview_vertex_colors(house.materials)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PlateWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.42, 0.47, 0.55, 1.0)
    background.inputs["Strength"].default_value = 0.7

    temporary: list[bpy.types.Object] = []
    bpy.ops.mesh.primitive_plane_add(size=80.0, location=(0.0, 0.0, -0.01))
    floor = bpy.context.object
    floor_mat = bpy.data.materials.get("PlateFloor") or bpy.data.materials.new("PlateFloor")
    floor_mat.diffuse_color = (0.2, 0.17, 0.13, 1.0)
    floor_mat.use_nodes = True
    floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.16, 0.13, 0.1, 1.0)
    floor.data.materials.append(floor_mat)
    temporary.append(floor)

    bpy.ops.object.light_add(type="SUN", location=(-6.0, -8.0, 12.0))
    sun = bpy.context.object
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.94, 0.84)
    sun.rotation_euler = (math.radians(50.0), 0.0, math.radians(-38.0))
    temporary.append(sun)

    width = house.width
    depth = house.depth
    height = house.ridge
    if view == "street":
        cam_pos = Vector((width * 1.05, -depth * 0.5 - width * 1.6, height * 0.45))
        target = Vector((0.0, -depth * 0.3, height * 0.42))
    else:
        cam_pos = Vector((-width * 1.4, depth * 0.5 + width * 1.5, height * 0.62))
        target = Vector((0.0, depth * 0.1, height * 0.38))
    bpy.ops.object.camera_add(location=cam_pos)
    camera = bpy.context.object
    camera.data.lens = 32.0
    camera.rotation_euler = (target - cam_pos).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    temporary.append(camera)

    output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    for obj in temporary:
        bpy.data.objects.remove(obj)


def remove_house(root: bpy.types.Object, house: House) -> None:
    for obj in house.objects:
        bpy.data.objects.remove(obj)
    bpy.data.objects.remove(root)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
