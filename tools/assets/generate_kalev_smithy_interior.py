#!/usr/bin/env python3
"""Build the authored Kalev smithy interior (room shell, loft ceiling, forge kit).

Run from the repository root:
    blender --background --factory-startup --python tools/assets/generate_kalev_smithy_interior.py

Why a bespoke interior: the generic interior-wall path dressed every wall with the
same plinth/rail/post grid and a flat plank ceiling, which read as a modern
panelled box. This generator models the room from the smithy dossier instead
(history/dossiers/architecture/smithy-workshop-layout.md): a stone-footed craft
house with a limestone fire wall between a limewashed living bay and a sooted
rubble forge bay, deep splayed window embrasures with board shutters, an oak loft
floor on girders and braces, a raised limestone hearth under a clay smoke hood,
a block anvil in an oak stump, great bellows worked from a rocker pole, and a
coopered slack tub.

All geometry is authored in map world units (1 unit = 1 rrmap cell, +Z south,
Y up) so the shell lines up with the rrmap wall footprints that remain the only
collision authority. Materials are named `ksi_<surface>` and carry no textures:
Godot's MapViewKalevSmithyInterior swaps them for the shared PBR plates with
world triplanar mapping, and COLOR_0 carries soot, grime and wear.
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
# Room architecture lives with the other architecture props; each forge
# workstation gets its own per-model folder under assets/props/forge/.
INTERIOR_DIR = ROOT / "assets" / "props" / "architecture" / "interiors"
FORGE_DIR = ROOT / "assets" / "props" / "forge"
KIT_DIRS = {
    "kalev_smithy_shell": INTERIOR_DIR,
    "kalev_smithy_ceiling": INTERIOR_DIR,
}
EVIDENCE_DIR = ROOT / "generated" / "blender" / "kalev_smithy_interior_v1"
GENERATOR_VERSION = "kalev_smithy_interior_v1"

WALL_HEIGHT = 3.75  # rrmap wall_height 120 px / 32 px cell
LIVING_X = (1.0, 14.0)
FORGE_X = (15.0, 25.0)
ROOM_Z = (1.0, 13.0)
# World centres of the rrmap props this kit replaces (footprint centres).
HEARTH_CENTER = (20.5, 2.5)  # forge_furnace rect 3x3 at (19,1)
ANVIL_CENTER = (19.5, 6.0)  # forge_anvil rect 3x2 at (18,5)
BELLOWS_CENTER = (17.5, 3.0)  # forge_bellows rect 3x2 at (16,2)
TUB_CENTER = (17.0, 6.0)  # quench rect 2x2 at (16,5)
RACK_CENTER = (23.0, 3.0)  # tool_shelf rect 2x2 at (22,2)
SCRAP_CENTER = (21.5, 5.5)  # iron_scrap_store at (21,5)
BENCH_CENTER = (19.5, 8.5)  # finishing_bench rect 3x1 at (18,8)
DOMESTIC_HEARTH = (12.0, 1.5)
# Fire pot in hearth-local coordinates; the bellows nozzle meets its tuyere.
FIRE_POT_LOCAL = (-0.2, 0.72, -0.2)
HEARTH_TOP = 0.74
HEARTH_HALF_WIDTH = 1.0
TUYERE_WORLD = (HEARTH_CENTER[0] - HEARTH_HALF_WIDTH - 0.15, 0.68, HEARTH_CENTER[1] + FIRE_POT_LOCAL[2])
HOOD_POINT = (20.5, 2.6, 1.6)  # where the smoke plume is densest (world)


# --- deterministic noise ------------------------------------------------------


def _hash(ix: int, iy: int, iz: int, seed: int) -> float:
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 144665) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFF) / float(0xFFFFFF)


def _smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def vnoise(x: float, y: float, z: float, seed: int = 0) -> float:
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = _smooth(x - ix), _smooth(y - iy), _smooth(z - iz)
    total = 0.0
    for dx in (0, 1):
        wx = fx if dx else 1.0 - fx
        for dy in (0, 1):
            wy = fy if dy else 1.0 - fy
            for dz in (0, 1):
                wz = fz if dz else 1.0 - fz
                total += wx * wy * wz * _hash(ix + dx, iy + dy, iz + dz, seed)
    return total * 2.0 - 1.0


def fbm(x: float, y: float, z: float, seed: int = 0, octaves: int = 3) -> float:
    amplitude, frequency, total, norm = 1.0, 1.0, 0.0, 0.0
    for octave in range(octaves):
        total += amplitude * vnoise(x * frequency, y * frequency, z * frequency, seed + octave * 31)
        norm += amplitude
        amplitude *= 0.5
        frequency *= 2.03
    return total / norm


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    return _smooth(clamp01((value - edge0) / (edge1 - edge0)))


def mix(a, b, t: float):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def scale_color(color, factor: float):
    return tuple(max(0.0, c * factor) for c in color)


# --- colour recipes (linear multipliers over the Godot PBR plates) -------------

SOOT = (0.11, 0.095, 0.085)
GRIME = (0.52, 0.46, 0.38)


def _plume(p, point, radius: float) -> float:
    dx, dy, dz = p[0] - point[0], (p[1] - point[1]) * 0.55, p[2] - point[2]
    return math.exp(-(dx * dx + dy * dy + dz * dz) / (radius * radius))


def room_occlusion(p) -> float:
    """Cheap baked ambient occlusion: wall/floor/ceiling junctions and corners."""
    bay = LIVING_X if p[0] < 14.5 else FORGE_X
    dx = min(abs(p[0] - bay[0]), abs(bay[1] - p[0]))
    dz = min(abs(p[2] - ROOM_Z[0]), abs(ROOM_Z[1] - p[2]))
    corner = (1.0 - smoothstep(0.0, 0.7, dx)) * (1.0 - smoothstep(0.0, 0.7, dz))
    floor = 1.0 - smoothstep(0.0, 0.35, p[1])
    ceiling = smoothstep(WALL_HEIGHT - 0.45, WALL_HEIGHT, p[1])
    return clamp01(0.45 * corner + 0.25 * floor + 0.3 * ceiling)


def forge_soot(p) -> float:
    # Smoke rolls up out of the hood throat, blackens the fire wall around it,
    # and pools under the loft boards across the whole bay.
    s = 0.95 * _plume(p, HOOD_POINT, 2.8)
    s += 0.5 * smoothstep(1.1, WALL_HEIGHT, p[1])
    s += 0.3 * smoothstep(2.9, WALL_HEIGHT, p[1])
    s += 0.2 * fbm(p[0] * 0.9, p[1] * 1.7, p[2] * 0.9, 7)
    return clamp01(s)


def stone_forge(p):
    # The forge bay was never limewashed after the fire went in: grey rubble,
    # smoke-black from the hood outwards and along the loft line.
    base = scale_color((0.8, 0.78, 0.74), 1.0 + 0.14 * fbm(p[0] * 1.3, p[1] * 1.3, p[2] * 1.3, 3))
    grime = 0.4 * (1.0 - smoothstep(0.0, 0.5, p[1]))
    base = mix(base, GRIME, grime)
    base = scale_color(base, 1.0 - 0.35 * room_occlusion(p))
    return mix(base, SOOT, forge_soot(p) * 0.92)


def stone_reveal(p):
    base = scale_color((0.9, 0.88, 0.84), 1.0 + 0.08 * fbm(p[0] * 2.0, p[1] * 2.0, p[2] * 2.0, 5))
    return mix(base, SOOT, 0.25 * forge_soot(p))


def stone_exterior(p):
    base = scale_color((0.95, 0.94, 0.9), 1.0 + 0.1 * fbm(p[0] * 0.7, p[1] * 0.9, p[2] * 0.7, 11))
    damp = 0.35 * (1.0 - smoothstep(0.0, 0.7, p[1]))
    return mix(base, (0.55, 0.57, 0.5), damp)


def stone_top(p):
    return scale_color((0.7, 0.68, 0.64), 1.0 + 0.1 * fbm(p[0], p[2], 0.0, 13))


def limewash(p):
    # Several coats of lime wash wear unevenly: broad cloudy patches plus a
    # faint yellowing where old coats show through.
    tone = 1.0 + 0.07 * fbm(p[0] * 0.7, p[1] * 0.9, p[2] * 0.7, 17) + 0.03 * fbm(p[0] * 4, p[1] * 4, p[2] * 4, 18)
    base = mix(scale_color((0.97, 0.95, 0.9), tone), (0.9, 0.84, 0.7), 0.35 * clamp01(fbm(p[0] * 0.5, p[1] * 0.8, p[2] * 0.5, 16)))
    # Floor splash and hand grime: a soft brown band, heavier near the door.
    door = math.exp(-(((p[0] - 13.0) / 2.2) ** 2 + ((p[2] - 13.0) / 1.5) ** 2))
    band = (1.0 - smoothstep(0.0, 0.42, p[1])) * (0.45 + 0.3 * fbm(p[0] * 2.0, 0.0, p[2] * 2.0, 19))
    base = mix(base, GRIME, clamp01(band + 0.25 * door * (1.0 - smoothstep(0.0, 1.6, p[1]))))
    # The domestic heater and the forge doorway both leave a soot plume.
    hearth = math.exp(-(((p[0] - DOMESTIC_HEARTH[0]) / 1.0) ** 2)) * smoothstep(1.1, 3.4, p[1])
    hearth *= math.exp(-(((p[2] - 1.0) / 1.6) ** 2))
    doorway = math.exp(-(((p[2] - 8.0) / 1.4) ** 2)) * smoothstep(1.6, 3.2, p[1])
    doorway *= math.exp(-(((p[0] - 14.0) / 0.9) ** 2))
    ceiling = 0.28 * smoothstep(3.1, WALL_HEIGHT, p[1])
    base = scale_color(base, 1.0 - 0.3 * room_occlusion(p))
    return mix(base, SOOT, clamp01(0.7 * hearth + 0.45 * doorway + ceiling))


def oak_living(p):
    tone = 0.92 + 0.12 * fbm(p[0] * 1.9, p[1] * 1.9, p[2] * 1.9, 23)
    base = scale_color((0.86, 0.78, 0.7), tone)
    hearth = math.exp(-(((p[0] - DOMESTIC_HEARTH[0]) / 2.2) ** 2 + ((p[2] - 1.5) / 2.5) ** 2))
    return mix(base, SOOT, 0.35 * hearth + 0.12 * smoothstep(3.3, WALL_HEIGHT, p[1]))


def oak_forge(p):
    tone = 0.9 + 0.12 * fbm(p[0] * 1.9, p[1] * 1.9, p[2] * 1.9, 29)
    base = scale_color((0.78, 0.7, 0.62), tone)
    return mix(base, SOOT, 0.25 + 0.6 * forge_soot(p))


def oak_for(p):
    return oak_forge(p) if p[0] > 14.5 else oak_living(p)


def board_floor(seed: int):
    rng = random.Random(seed)
    tone = 0.82 + rng.random() * 0.26
    warm = rng.random() * 0.06

    def color(p):
        wear = math.exp(-(((p[2] - 7.6) / 1.4) ** 2)) * math.exp(-(((p[0] - 12.0) / 3.5) ** 2))
        edge = 1.0 - smoothstep(0.0, 0.5, min(p[0] - LIVING_X[0], LIVING_X[1] - p[0], p[2] - 1.0, 13.0 - p[2]))
        base = (tone + warm, tone, tone - warm)
        base = scale_color(base, 1.0 + 0.06 * fbm(p[0] * 9.0, 0.0, p[2] * 3.0, seed))
        base = mix(base, (1.08, 1.02, 0.92), 0.25 * wear)
        return mix(base, GRIME, 0.35 * edge)

    return color


def earth_floor(p):
    # Beaten clay: broad damp/dry patches, charcoal dust and hammer scale
    # concentrated at the hearth, coal corner and anvil, a paler trodden path
    # from the courtyard door, and grime banked against the walls.
    tone = 1.0 + 0.16 * fbm(p[0] * 0.8, 0.0, p[2] * 0.8, 31) + 0.08 * fbm(p[0] * 6.0, 0.0, p[2] * 6.0, 32)
    base = scale_color((1.05, 1.0, 0.94), tone)
    dust = 0.9 * math.exp(-(((p[0] - 20.5) / 3.0) ** 2 + ((p[2] - 3.4) / 2.2) ** 2))
    dust += 0.8 * math.exp(-(((p[0] - 23.3) / 1.3) ** 2 + ((p[2] - 4.4) / 1.3) ** 2))
    dust += 0.75 * math.exp(-(((p[0] - ANVIL_CENTER[0]) / 1.4) ** 2 + ((p[2] - 6.5) / 1.2) ** 2))
    dust += 0.3 * max(0.0, fbm(p[0] * 1.6, 0.0, p[2] * 1.6, 37))
    speckle = fbm(p[0] * 14.0, 0.0, p[2] * 14.0, 38)
    dust += 0.35 * smoothstep(0.35, 0.7, speckle) * smoothstep(0.1, 0.5, dust)
    wall = 1.0 - smoothstep(0.0, 0.6, min(p[0] - FORGE_X[0], FORGE_X[1] - p[0], p[2] - 1.0, 13.0 - p[2]))
    dust += 0.4 * wall
    path = math.exp(-(((p[0] - (15.0 + (p[2] - 13.0) * -0.6)) / 1.2) ** 2)) * smoothstep(6.0, 12.5, p[2])
    wet = 0.5 * math.exp(-(((p[0] - TUB_CENTER[0] - 0.3) / 1.0) ** 2 + ((p[2] - TUB_CENTER[1] - 0.25) / 1.0) ** 2))
    base = mix(base, (1.08, 1.02, 0.94), 0.3 * path * (1.0 - clamp01(dust)))
    base = mix(base, (0.34, 0.31, 0.28), wet)
    return mix(base, SOOT, clamp01(dust) * 0.9)


def flat(color):
    return lambda _p: color


def iron_color(p):
    return scale_color((0.95, 0.95, 0.95), 1.0 + 0.12 * fbm(p[0] * 7.0, p[1] * 7.0, p[2] * 7.0, 41))


# --- mesh accumulator -----------------------------------------------------------


def to_blender(p) -> tuple[float, float, float]:
    return (p[0], -p[2], p[1])


class Acc:
    """Accumulates faces for one material in world (map) coordinates."""

    def __init__(self, material: str, offset=(0.0, 0.0, 0.0)) -> None:
        self.material = material
        # Colour recipes are written in map world space; prop kits are authored
        # around their rrmap footprint centre and shift back for colouring.
        self.offset = offset
        self.verts: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.colors: list[tuple[float, float, float]] = []
        self.smooth: list[bool] = []

    def vertex(self, p) -> int:
        self.verts.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.verts) - 1

    def face(self, indices, color_fn, smooth: bool = False) -> None:
        pts = [Vector(self.verts[i]) for i in indices]
        if len(pts) >= 3:
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if len(pts) == 4:
                normal += (pts[2] - pts[0]).cross(pts[3] - pts[0])
            if normal.length < 1e-10:
                return
        self.faces.append(tuple(indices))
        ox, oy, oz = self.offset
        for i in indices:
            v = self.verts[i]
            c = color_fn((v[0] + ox, v[1] + oy, v[2] + oz))
            self.colors.append((clamp01(c[0]), clamp01(c[1]), clamp01(c[2])))
        self.smooth.append(smooth)

    def poly(self, points, color_fn, hint=None, smooth: bool = False) -> None:
        pts = [Vector(p) for p in points]
        # Drop consecutive duplicates so collapsed wedge corners become triangles.
        unique: list[Vector] = []
        for p in pts:
            if not unique or (p - unique[-1]).length > 1e-7:
                unique.append(p)
        if len(unique) > 1 and (unique[0] - unique[-1]).length <= 1e-7:
            unique.pop()
        if len(unique) < 3:
            return
        if hint is not None:
            normal = Vector((0.0, 0.0, 0.0))
            for i in range(1, len(unique) - 1):
                normal += (unique[i] - unique[0]).cross(unique[i + 1] - unique[0])
            if normal.dot(Vector(hint)) < 0.0:
                unique.reverse()
        self.face([self.vertex(p) for p in unique], color_fn, smooth)


def hexa(acc: Acc, corners, color_fn, skip: tuple[str, ...] = ()) -> None:
    """Six-sided solid from 8 corners: bottom b0..b3 then top t0..t3 (same order)."""
    c = [Vector(p) for p in corners]
    centroid = sum(c, Vector((0.0, 0.0, 0.0))) / 8.0
    faces = {
        "bottom": (c[0], c[1], c[2], c[3]),
        "top": (c[4], c[5], c[6], c[7]),
        "s0": (c[0], c[1], c[5], c[4]),
        "s1": (c[1], c[2], c[6], c[5]),
        "s2": (c[2], c[3], c[7], c[6]),
        "s3": (c[3], c[0], c[4], c[7]),
    }
    for key, quad in faces.items():
        if key in skip:
            continue
        center = sum(quad, Vector((0.0, 0.0, 0.0))) / 4.0
        acc.poly(quad, color_fn, hint=center - centroid)


def box(acc: Acc, center, size, color_fn, rot_y: float = 0.0, skip: tuple[str, ...] = ()) -> None:
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    cos_r, sin_r = math.cos(rot_y), math.sin(rot_y)
    corners = []
    for y in (-hy, hy):
        for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)):
            rx = x * cos_r + z * sin_r
            rz = -x * sin_r + z * cos_r
            corners.append((center[0] + rx, center[1] + y, center[2] + rz))
    hexa(acc, corners, color_fn, skip)


def aabb(acc: Acc, lo, hi, color_fn, skip: tuple[str, ...] = ()) -> None:
    center = [(lo[i] + hi[i]) * 0.5 for i in range(3)]
    size = [hi[i] - lo[i] for i in range(3)]
    box(acc, center, size, color_fn, 0.0, skip)


def oriented_box(acc: Acc, p0, p1, width: float, height: float, color_fn, up=(0.0, 1.0, 0.0)) -> None:
    """Beam from p0 to p1 with a rectangular section (width across, height along `up`)."""
    a, b = Vector(p0), Vector(p1)
    axis = (b - a).normalized()
    up_v = Vector(up)
    side = axis.cross(up_v)
    if side.length < 1e-6:
        side = axis.cross(Vector((1.0, 0.0, 0.0)))
    side.normalize()
    upn = side.cross(axis).normalized()
    hw, hh = side * (width * 0.5), upn * (height * 0.5)
    corners = []
    for end in (a, b):
        corners.extend([end - hw - hh, end + hw - hh, end + hw + hh, end - hw + hh])
    # hexa expects bottom ring then top ring; here the rings are the two ends.
    hexa(acc, [tuple(v) for v in corners], color_fn)


def tube(acc: Acc, p0, p1, r0: float, r1: float, segments: int, color_fn, caps: bool = True,
         jitter: float = 0.0, seed: int = 0, rings: int = 1) -> None:
    a, b = Vector(p0), Vector(p1)
    axis = b - a
    length = axis.length
    if length < 1e-6:
        return
    axis_n = axis / length
    ref = Vector((0.0, 1.0, 0.0)) if abs(axis_n.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = axis_n.cross(ref).normalized()
    v = axis_n.cross(u).normalized()
    ring_ids: list[list[int]] = []
    for ring in range(rings + 1):
        t = ring / rings
        center = a + axis * t
        radius = r0 + (r1 - r0) * t
        ids = []
        for s in range(segments):
            ang = math.tau * s / segments
            wobble = 1.0 + jitter * vnoise(math.cos(ang) * 1.7, t * 2.3, math.sin(ang) * 1.7, seed)
            p = center + (u * math.cos(ang) + v * math.sin(ang)) * radius * wobble
            ids.append(acc.vertex(tuple(p)))
        ring_ids.append(ids)
    for ring in range(rings):
        lower, upper = ring_ids[ring], ring_ids[ring + 1]
        for s in range(segments):
            n = (s + 1) % segments
            quad = [lower[s], lower[n], upper[n], upper[s]]
            pts = [Vector(acc.verts[i]) for i in quad]
            mid = sum(pts, Vector((0.0, 0.0, 0.0))) / 4.0
            closest = a + axis_n * (mid - a).dot(axis_n)
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if normal.dot(mid - closest) < 0.0:
                quad.reverse()
            acc.face(quad, color_fn, smooth=True)
    if caps:
        for ids, direction in ((ring_ids[0], -axis_n), (ring_ids[-1], axis_n)):
            pts = [acc.verts[i] for i in ids]
            acc.poly(pts, color_fn, hint=tuple(direction))


def panel(acc: Acc, origin, u_vec, v_vec, normal, color_fn, step: float = 0.3,
          disp: float = 0.0, seed: int = 0, border: float = 0.12) -> None:
    """Gridded quad with optional noise relief (zero at the border, no cracks)."""
    o, uv, vv, n = Vector(origin), Vector(u_vec), Vector(v_vec), Vector(normal).normalized()
    lu, lv = uv.length, vv.length
    if lu < 1e-6 or lv < 1e-6:
        return
    nu, nv = max(1, round(lu / step)), max(1, round(lv / step))
    grid = []
    for j in range(nv + 1):
        row = []
        for i in range(nu + 1):
            fu, fv = i / nu, j / nv
            p = o + uv * fu + vv * fv
            if disp > 0.0 and 0 < i < nu and 0 < j < nv:
                edge = min(fu * lu, (1.0 - fu) * lu, fv * lv, (1.0 - fv) * lv)
                falloff = smoothstep(0.0, border, edge)
                p = p + n * (disp * falloff * fbm(p.x * 1.6, p.y * 1.6, p.z * 1.6, seed))
            row.append(acc.vertex(tuple(p)))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            quad = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            pts = [Vector(acc.verts[k]) for k in quad]
            if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) < 0.0:
                quad.reverse()
            acc.face(quad, color_fn, smooth=disp > 0.0)


class Kit:
    """Named accumulators for one GLB plus marker empties."""

    def __init__(self, name: str, origin=(0.0, 0.0)) -> None:
        self.name = name
        self.offset = (origin[0], 0.0, origin[1])
        self.accs: dict[str, Acc] = {}
        self.markers: list[tuple[str, tuple, tuple, float]] = []

    def acc(self, material: str) -> Acc:
        if material not in self.accs:
            self.accs[material] = Acc(material, self.offset)
        return self.accs[material]

    def marker(self, name: str, position, scale, rot_y: float = 0.0) -> None:
        self.markers.append((name, tuple(position), tuple(scale), rot_y))

    def triangles(self) -> int:
        return sum(len(f) - 2 for acc in self.accs.values() for f in acc.faces)


# --- room shell: walls ----------------------------------------------------------

SIDE_FRAMES = {
    "+x": lambda lo, hi: ((hi[0], lo[1], lo[2]), (0, 0, hi[2] - lo[2]), (0, hi[1] - lo[1], 0), (1, 0, 0)),
    "-x": lambda lo, hi: ((lo[0], lo[1], lo[2]), (0, 0, hi[2] - lo[2]), (0, hi[1] - lo[1], 0), (-1, 0, 0)),
    "+y": lambda lo, hi: ((lo[0], hi[1], lo[2]), (hi[0] - lo[0], 0, 0), (0, 0, hi[2] - lo[2]), (0, 1, 0)),
    "+z": lambda lo, hi: ((lo[0], lo[1], hi[2]), (hi[0] - lo[0], 0, 0), (0, hi[1] - lo[1], 0), (0, 0, 1)),
    "-z": lambda lo, hi: ((lo[0], lo[1], lo[2]), (hi[0] - lo[0], 0, 0), (0, hi[1] - lo[1], 0), (0, 0, -1)),
}

LIMESTONE = "ksi_limestone"
LIMEWASH = "ksi_limewash"
OAK = "ksi_oak"
BOARDS = "ksi_boards"
EARTH = "ksi_earth"
SLAB = "ksi_slab"
CLAY = "ksi_clay"
IRON = "ksi_iron"
IRON_BRIGHT = "ksi_iron_bright"
LEATHER = "ksi_leather"
CHARCOAL = "ksi_charcoal"
ASH = "ksi_ash"
STRAW = "ksi_straw"
WATER = "ksi_water"
LOFT = "ksi_loft_shadow"


def wall_block(kit: Kit, lo, hi, faces: dict, seed: int = 0) -> None:
    for side, spec in faces.items():
        if spec is None:
            continue
        material, color_fn, disp = spec
        origin, u, v, n = SIDE_FRAMES[side](lo, hi)
        panel(kit.acc(material), origin, u, v, n, color_fn, step=0.3, disp=disp, seed=seed)


def inner_spec(x_center: float, reveal: bool = False):
    if reveal:
        return (LIMESTONE, stone_reveal, 0.0)
    if x_center < 14.5:
        return (LIMEWASH, limewash, 0.06)
    return (LIMESTONE, stone_forge, 0.03)


OUTER = (LIMESTONE, stone_exterior, 0.0)
TOP = (LIMESTONE, stone_top, 0.0)
HIDDEN = None


def build_walls(kit: Kit) -> None:
    h = WALL_HEIGHT
    # North wall z 0..1, inner face +z. Window gaps at x 5..6 and 23..24.
    for x0, x1 in ((0.0, 5.0), (6.0, 14.5), (14.5, 23.0), (24.0, 26.0)):
        wall_block(kit, (x0, 0.0, 0.0), (x1, h, 1.0), {
            "+z": inner_spec((x0 + x1) * 0.5), "-z": OUTER, "+y": TOP,
            "-x": OUTER if x0 == 0.0 else HIDDEN, "+x": OUTER if x1 == 26.0 else HIDDEN,
        }, seed=int(x0 * 7))
    # South wall z 13..14, inner face -z. Courtyard door gap x 12..14.
    for x0, x1 in ((0.0, 12.0), (14.0, 14.5), (14.5, 26.0)):
        wall_block(kit, (x0, 0.0, 13.0), (x1, h, 14.0), {
            "-z": inner_spec((x0 + x1) * 0.5), "+z": OUTER, "+y": TOP,
            "-x": OUTER if x0 == 0.0 else HIDDEN, "+x": OUTER if x1 == 26.0 else HIDDEN,
        }, seed=int(x0 * 11) + 3)
    # West wall x 0..1 (living), window gap z 6..8.
    for z0, z1 in ((1.0, 6.0), (8.0, 13.0)):
        wall_block(kit, (0.0, 0.0, z0), (1.0, h, z1), {
            "+x": inner_spec(1.0), "-x": OUTER, "+y": TOP,
        }, seed=int(z0 * 13) + 5)
    # East wall x 25..26 (forge), window gap z 6..8.
    for z0, z1 in ((1.0, 6.0), (8.0, 13.0)):
        wall_block(kit, (25.0, 0.0, z0), (26.0, h, z1), {
            "-x": inner_spec(20.0), "+x": OUTER, "+y": TOP,
        }, seed=int(z0 * 17) + 7)
    # Divider fire wall x 14..15: limewashed living face, sooted rubble forge
    # face, stone reveals where the rrmap opening (z 7..9) passes through.
    for z0, z1 in ((1.0, 7.0), (9.0, 13.0)):
        wall_block(kit, (14.0, 0.0, z0), (15.0, h, z1), {
            "-x": inner_spec(10.0), "+x": inner_spec(20.0), "+y": TOP,
            "+z": inner_spec(0.0, reveal=True) if z1 == 7.0 else HIDDEN,
            "-z": inner_spec(0.0, reveal=True) if z0 == 9.0 else HIDDEN,
        }, seed=int(z0 * 19) + 9)
    build_divider_doorway(kit)
    build_courtyard_door_reveal(kit)
    for spec in WINDOWS:
        build_embrasure(kit, spec)


def build_divider_doorway(kit: Kit) -> None:
    h = WALL_HEIGHT
    head = 2.3
    # Masonry over the passage, then an oak door case on the living face.
    wall_block(kit, (14.0, head, 7.0), (15.0, h, 9.0), {
        "-x": inner_spec(10.0), "+x": inner_spec(20.0), "+y": TOP,
        "-z": HIDDEN, "+z": HIDDEN,
    }, seed=41)
    panel(kit.acc(LIMESTONE), (14.0, head, 7.0), (1.0, 0, 0), (0, 0, 2.0), (0, -1, 0), stone_reveal)
    oak = kit.acc(OAK)
    aabb(oak, (13.93, 0.0, 6.98), (14.12, head + 0.02, 7.16), oak_living)
    aabb(oak, (13.93, 0.0, 8.84), (14.12, head + 0.02, 9.02), oak_living)
    aabb(oak, (13.9, head - 0.04, 6.8), (14.14, head + 0.22, 9.2), oak_living)
    # Forge-side lintel: a sooted oak beam carrying the rubble over the opening.
    aabb(oak, (14.86, head - 0.02, 6.75), (15.05, head + 0.24, 9.25), oak_forge)
    # Stone threshold step keeps forge ash out of the living bay (dossier).
    slab = kit.acc(SLAB)
    aabb(slab, (13.97, 0.0, 7.0), (15.08, 0.075, 9.0), flat((0.78, 0.76, 0.72)))
    # Board door hung on the living face, standing open against the wall.
    leaf_color = lambda p: scale_color((0.8, 0.72, 0.64), 0.95 + 0.1 * fbm(p[1] * 4.0, p[2] * 9.0, 0.0, 43))
    for index in range(5):
        z0 = 9.04 + index * 0.25
        aabb(oak, (13.86, 0.03, z0), (13.915, 2.16, z0 + 0.245), leaf_color)
    iron = kit.acc(IRON)
    for y in (0.35, 1.8):
        aabb(iron, (13.84, y, 9.02), (13.865, y + 0.05, 10.2), iron_color)
    for y in (0.5, 1.2, 1.9):
        aabb(oak, (13.8, y, 9.08), (13.86, y + 0.12, 10.24), leaf_color)


def build_courtyard_door_reveal(kit: Kit) -> None:
    # The transition door leaf (1.5 x 2.5 m plus 0.13 m frame) stays procedural;
    # the shell supplies the stone reveal and the oak lintel around it.
    h = WALL_HEIGHT
    head = 2.63
    for x0, x1 in ((12.0, 12.12), (13.88, 14.0)):
        wall_block(kit, (x0, 0.0, 13.0), (x1, head, 14.0), {
            "-z": inner_spec(10.0, reveal=True), "+z": OUTER, "+y": HIDDEN,
            "-x": inner_spec(0.0, reveal=True), "+x": inner_spec(0.0, reveal=True),
        }, seed=47)
    wall_block(kit, (12.0, head, 13.0), (14.0, h, 14.0), {
        "-z": inner_spec(10.0), "+z": OUTER, "+y": TOP,
    }, seed=53)
    panel(kit.acc(LIMESTONE), (12.0, head, 13.0), (2.0, 0, 0), (0, 0, 1.0), (0, -1, 0), stone_reveal)
    aabb(kit.acc(OAK), (11.55, head, 12.93), (14.45, head + 0.26, 13.2), oak_living)


# Window embrasures: gap along the wall, splayed reveals (narrow outside, wide
# inside), a flat outer sill under the frame and a sloping inner sill.
WINDOWS = [
    {"id": "window.north_living", "axis": "x", "center": 5.5, "outer": (0.0, 0.0, 0.0),
     "gap": 1.0, "w_out": 0.24, "w_in": 0.46, "sill": 1.2, "sill_in": 1.02, "head": 2.02,
     "bars": 0, "mullion": False, "lattice": True, "bay": "living"},
    {"id": "window.north_forge", "axis": "x", "center": 23.5, "outer": (0.0, 0.0, 0.0),
     "gap": 1.0, "w_out": 0.27, "w_in": 0.46, "sill": 2.15, "sill_in": 1.92, "head": 2.95,
     "bars": 2, "mullion": False, "lattice": False, "bay": "forge"},
    {"id": "window.west", "axis": "z", "center": 7.0, "outer": (0.0, 0.0, 0.0),
     "gap": 2.0, "w_out": 0.55, "w_in": 0.9, "sill": 1.05, "sill_in": 0.88, "head": 2.1,
     "bars": 0, "mullion": True, "lattice": True, "bay": "living"},
    {"id": "window.east", "axis": "z", "center": 7.0, "outer": (26.0, 0.0, 0.0),
     "gap": 2.0, "w_out": 0.5, "w_in": 0.86, "sill": 1.25, "sill_in": 1.02, "head": 2.2,
     "bars": 3, "mullion": True, "lattice": False, "bay": "forge"},
]


def _window_frame(spec):
    """(to_world(a, d, y), along unit, depth unit) for an embrasure."""
    if spec["axis"] == "x":
        along, depth = Vector((1, 0, 0)), Vector((0, 0, 1))
        origin = Vector((spec["center"], 0.0, 0.0))
    elif spec["outer"][0] == 0.0:
        along, depth = Vector((0, 0, 1)), Vector((1, 0, 0))
        origin = Vector((0.0, 0.0, spec["center"]))
    else:
        along, depth = Vector((0, 0, -1)), Vector((-1, 0, 0))
        origin = Vector((26.0, 0.0, spec["center"]))

    def to_world(a: float, d: float, y: float):
        p = origin + along * a + depth * d
        return (p.x, y, p.z)

    return to_world, along, depth


def build_embrasure(kit: Kit, spec) -> None:
    h = WALL_HEIGHT
    to_world, along, depth = _window_frame(spec)
    forge = spec["bay"] == "forge"
    face_color = stone_forge if forge else limewash
    reveal_mat = LIMESTONE if forge else LIMEWASH
    reveal_color = stone_forge if forge else limewash
    g = spec["gap"] * 0.5
    w_o, w_i = spec["w_out"], spec["w_in"]
    sill, sill_in, head = spec["sill"], spec["sill_in"], spec["head"]
    frame_d = 0.24

    def width_at(d: float) -> float:
        return w_o + (w_i - w_o) * d

    stone = kit.acc(LIMESTONE)
    wash = kit.acc(reveal_mat)
    # Outer sill block (flat) and inner sloping sill.
    hexa(stone, [to_world(-g, 0, 0), to_world(g, 0, 0), to_world(g, 0.4, 0), to_world(-g, 0.4, 0),
                 to_world(-g, 0, sill), to_world(g, 0, sill), to_world(g, 0.4, sill), to_world(-g, 0.4, sill)],
         stone_reveal, skip=("bottom",))
    hexa(wash, [to_world(-g, 0.4, 0), to_world(g, 0.4, 0), to_world(g, 1.0, 0), to_world(-g, 1.0, 0),
                to_world(-g, 0.4, sill), to_world(g, 0.4, sill), to_world(g, 1.0, sill_in), to_world(-g, 1.0, sill_in)],
         reveal_color, skip=("bottom",))
    # Head over the opening, full thickness.
    hexa(wash, [to_world(-g, 0, head), to_world(g, 0, head), to_world(g, 1.0, head), to_world(-g, 1.0, head),
                to_world(-g, 0, h), to_world(g, 0, h), to_world(g, 1.0, h), to_world(-g, 1.0, h)],
         lambda p: stone_top(p) if p[1] >= h - 1e-4 else reveal_color(p))
    # Splayed jambs.
    for sign in (-1.0, 1.0):
        pts = [to_world(sign * g, 0, sill_in - 0.01), to_world(sign * w_o, 0, sill_in - 0.01),
               to_world(sign * w_i, 1.0, sill_in - 0.01), to_world(sign * g, 1.0, sill_in - 0.01)]
        top = [(p[0], head, p[2]) for p in pts]
        hexa(wash, pts + top, reveal_color, skip=("bottom",))
    # Oak lintel across the inner face, proud of the wall by 3 cm.
    oak = kit.acc(OAK)
    lintel_color = oak_forge if forge else oak_living
    lw = w_i + 0.2
    hexa(oak, [to_world(-lw, 0.8, head), to_world(lw, 0.8, head), to_world(lw, 1.03, head), to_world(-lw, 1.03, head),
               to_world(-lw, 0.8, head + 0.2), to_world(lw, 0.8, head + 0.2), to_world(lw, 1.03, head + 0.2),
               to_world(-lw, 1.03, head + 0.2)], lintel_color)
    # Oak window frame in the outer third, with pane marker for Godot.
    wf = width_at(frame_d)
    fr = 0.07

    def frame_member(a0, a1, y0, y1, d0=frame_d - 0.045, d1=frame_d + 0.045):
        hexa(oak, [to_world(a0, d0, y0), to_world(a1, d0, y0), to_world(a1, d1, y0), to_world(a0, d1, y0),
                   to_world(a0, d0, y1), to_world(a1, d0, y1), to_world(a1, d1, y1), to_world(a0, d1, y1)],
             lintel_color)

    frame_member(-wf, -wf + fr, sill, head)
    frame_member(wf - fr, wf, sill, head)
    frame_member(-wf, wf, head - fr, head)
    frame_member(-wf, wf, sill, sill + fr)
    if spec["mullion"]:
        frame_member(-0.04, 0.04, sill, head)
    if spec["lattice"]:
        # Split-oak lattice holding the oiled linen: two bars each way.
        inner_w = wf - fr
        for k in (1, 2):
            a = -inner_w + 2.0 * inner_w * k / 3.0
            frame_member(a - 0.012, a + 0.012, sill + fr, head - fr, frame_d - 0.03, frame_d - 0.01)
            y = sill + fr + (head - sill - 2 * fr) * k / 3.0
            frame_member(-inner_w, inner_w, y - 0.012, y + 0.012, frame_d - 0.03, frame_d - 0.01)
    iron = kit.acc(IRON)
    for k in range(spec["bars"]):
        a = -wf + 2.0 * wf * (k + 1) / (spec["bars"] + 1)
        tube(iron, to_world(a, 0.12, sill - 0.05), to_world(a, 0.12, head + 0.05), 0.014, 0.014, 6, iron_color)
    pane_w = 2.0 * (wf - fr)
    pane_h = head - sill - 2.0 * fr
    center = to_world(0.0, frame_d, sill + fr + pane_h * 0.5)
    rot_y = 0.0 if spec["axis"] == "x" else math.pi * 0.5
    kit.marker("WindowPane_" + spec["id"].replace(".", "_"), center, (pane_w, pane_h, 0.02), rot_y)
    # Board shutters opened back against the splayed reveals.
    hinge_d = frame_d + 0.06
    leaf_w = wf - 0.02
    for sign in (-1.0, 1.0):
        hinge = Vector(to_world(sign * width_at(hinge_d), hinge_d, 0.0))
        reveal_dir = (Vector(to_world(sign * w_i, 1.0, 0.0)) - Vector(to_world(sign * w_o, 0.0, 0.0))).normalized()
        inward = Vector(to_world(-sign * 1.0, 0.0, 0.0)) - Vector(to_world(0.0, 0.0, 0.0))
        inward.normalize()
        offset = inward * 0.025
        end = hinge + reveal_dir * leaf_w
        for y0, y1 in ((sill + 0.02, head - 0.02),):
            quad_lo = [hinge + offset, end + offset, end + offset + inward * 0.03, hinge + offset + inward * 0.03]
            corners = [(p.x, y0, p.z) for p in quad_lo] + [(p.x, y1, p.z) for p in quad_lo]
            hexa(oak, corners, lintel_color)
        for yb in (sill + 0.18, head - 0.2):
            strap = [hinge + offset + inward * 0.03, end + offset + inward * 0.03,
                     end + offset + inward * 0.045, hinge + offset + inward * 0.045]
            corners = [(p.x, yb, p.z) for p in strap] + [(p.x, yb + 0.04, p.z) for p in strap]
            hexa(iron, corners, iron_color)


# --- room shell: floors -----------------------------------------------------------


def build_floors(kit: Kit) -> None:
    # Living bay: pine/oak boards running east-west over a dark sub-floor so the
    # hairline joints read as gaps rather than showing the terrain beneath.
    panel(kit.acc(LOFT), (LIVING_X[0], 0.004, ROOM_Z[0]), (LIVING_X[1] - LIVING_X[0], 0, 0),
          (0, 0, ROOM_Z[1] - ROOM_Z[0]), (0, 1, 0), flat((0.05, 0.045, 0.04)), step=13.0)
    rng = random.Random(1343)
    boards = kit.acc(BOARDS)
    x = LIVING_X[0]
    row = 0
    while x < LIVING_X[1] - 0.05:
        width = min(0.24 + rng.random() * 0.12, LIVING_X[1] - x)
        z = ROOM_Z[0] - rng.random() * 1.8
        while z < ROOM_Z[1]:
            length = 2.2 + rng.random() * 2.6
            z0, z1 = max(z, ROOM_Z[0]), min(z + length, ROOM_Z[1])
            if z1 - z0 > 0.05:
                top = 0.02 + (rng.random() - 0.5) * 0.006
                aabb(boards, (x + 0.003, -0.01, z0 + 0.003), (x + width - 0.003, top, z1 - 0.003),
                     board_floor(row * 97 + int(z0 * 13)), skip=("bottom",))
            z += length
        x += width
        row += 1
    # Rush mat on the opening-shot runner (rrmap floor.start_runner x10..14 z6..8).
    straw = kit.acc(STRAW)
    aabb(straw, (10.18, 0.0, 6.16), (13.82, 0.034, 7.84),
         lambda p: scale_color((0.9, 0.84, 0.7), 1.0 + 0.1 * fbm(p[0] * 5, 0, p[2] * 5, 59)), skip=("bottom",))
    # Forge bay: beaten clay and ash, gently uneven.
    panel(kit.acc(EARTH), (FORGE_X[0], 0.012, ROOM_Z[0]), (FORGE_X[1] - FORGE_X[0], 0, 0),
          (0, 0, ROOM_Z[1] - ROOM_Z[0]), (0, 1, 0), earth_floor, step=0.25, disp=0.008, seed=61, border=0.3)
    # Laid limestone flags in front of the hearth and under the slack tub.
    build_flags(kit, 18.7, 22.3, 2.75, 4.45, 67)
    build_flags(kit, 16.25, 17.95, 5.2, 6.85, 71)
    # Door sill stones.
    aabb(kit.acc(SLAB), (11.95, 0.0, 12.86), (14.05, 0.05, 13.02), flat((0.8, 0.78, 0.74)), skip=("bottom",))


def build_flags(kit: Kit, x0: float, x1: float, z0: float, z1: float, seed: int) -> None:
    rng = random.Random(seed)
    slab = kit.acc(SLAB)
    z = z0
    while z < z1 - 0.1:
        depth = min(0.42 + rng.random() * 0.3, z1 - z)
        x = x0
        while x < x1 - 0.1:
            width = min(0.45 + rng.random() * 0.45, x1 - x)
            j = [(rng.random() - 0.5) * 0.05 for _ in range(4)]
            y = 0.03 + rng.random() * 0.012
            corners_lo = [(x + 0.012 + j[0], 0.0, z + 0.012 + j[1]), (x + width - 0.012 + j[2], 0.0, z + 0.012),
                          (x + width - 0.012, 0.0, z + depth - 0.012 + j[3]), (x + 0.012, 0.0, z + depth - 0.012)]
            corners_hi = [(c[0], y + (rng.random() - 0.5) * 0.008, c[2]) for c in corners_lo]
            tone = 0.72 + rng.random() * 0.14
            color = lambda p, tone=tone: mix((tone, tone * 0.98, tone * 0.94), SOOT,
                                             0.45 * math.exp(-(((p[0] - 20.5) / 2.0) ** 2 + ((p[2] - 3.0) / 1.2) ** 2)))
            hexa(slab, corners_lo + corners_hi, color, skip=("bottom",))
            x += width
        z += depth


# --- room shell: wall dressing -------------------------------------------------------


def hammer(kit: Kit, head_center, handle_dir, head_len: float, handle_len: float, seed: int) -> None:
    """Forging hammer: iron head across the handle, ash haft."""
    iron = kit.acc(IRON)
    oak = kit.acc(OAK)
    hc = Vector(head_center)
    hd = Vector(handle_dir).normalized()
    across = hd.cross(Vector((1, 0, 0)) if abs(hd.x) < 0.9 else Vector((0, 0, 1))).normalized()
    tube(iron, tuple(hc - across * head_len * 0.5), tuple(hc + across * head_len * 0.5), 0.022, 0.026, 8, iron_color)
    tube(oak, tuple(hc), tuple(hc + hd * handle_len), 0.014, 0.017, 6,
         lambda p: scale_color((0.9, 0.8, 0.66), 0.9 + 0.1 * vnoise(p[1] * 9, seed, 0, seed)), caps=True)


def tongs(kit: Kit, pivot, down, spread: float, handle_len: float, jaw_len: float) -> None:
    """Riveted tongs hanging jaws-down from a peg: two reins and two jaws."""
    iron = kit.acc(IRON)
    pv = Vector(pivot)
    dn = Vector(down).normalized()
    side = dn.cross(Vector((0, 1, 0))).normalized() if abs(dn.y) < 0.9 else Vector((1, 0, 0))
    if abs(dn.y) >= 0.9:
        side = Vector((1, 0, 0)) if abs(dn.x) < 0.5 else Vector((0, 0, 1))
    for sign in (-1.0, 1.0):
        tube(iron, tuple(pv), tuple(pv - dn * handle_len + side * sign * spread), 0.009, 0.007, 5, iron_color)
        tube(iron, tuple(pv), tuple(pv + dn * jaw_len + side * sign * 0.02), 0.012, 0.01, 5, iron_color)
    tube(iron, tuple(pv - side * 0.018), tuple(pv + side * 0.018), 0.014, 0.014, 6, iron_color)


def build_tool_wall(kit: Kit) -> None:
    # East wall of the forge bay, well clear of the fire (dossier zone F): two
    # oak rails spiked into the rubble carrying tongs, hammers and punches.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    face = 25.0
    for y in (1.28, 1.86):
        aabb(oak, (face - 0.07, y, 1.35), (face, y + 0.1, 5.7), oak_forge)
        for z in (1.6, 3.5, 5.45):
            aabb(iron, (face - 0.085, y + 0.03, z - 0.02), (face - 0.065, y + 0.07, z + 0.02), iron_color)
    # Pegs on the upper rail with tongs hanging jaws-down.
    for i, z in enumerate((1.75, 2.15, 2.55, 2.95)):
        tube(oak, (face - 0.07, 1.93, z), (face - 0.2, 1.97, z), 0.016, 0.014, 6, oak_forge)
        tongs(kit, (face - 0.16, 1.9, z), (0, -1, 0), 0.035 + i * 0.01, 0.46 + i * 0.05, 0.14 + i * 0.02)
    # Hammers hang head-up between peg pairs on the lower rail.
    for i, z in enumerate((3.55, 3.9, 4.28)):
        for dz in (-0.045, 0.045):
            tube(oak, (face - 0.07, 1.35, z + dz), (face - 0.17, 1.38, z + dz), 0.012, 0.011, 6, oak_forge)
        hammer(kit, (face - 0.12, 1.47, z), (0, -1, 0), 0.14 + i * 0.02, 0.36 + i * 0.04, 70 + i)
    # Punches, chisels and a fuller stand in a drilled oak block on the rail.
    aabb(oak, (face - 0.16, 1.2, 4.6), (face - 0.02, 1.28, 5.5), oak_forge)
    for i in range(7):
        z = 4.68 + i * 0.12
        tube(iron, (face - 0.09, 1.2, z), (face - 0.09, 1.2 + 0.2 + (i % 3) * 0.04, z), 0.011, 0.008, 6, iron_color)
    # Horseshoe blanks on nails above.
    for i, z in enumerate((2.0, 2.35, 2.7, 3.05)):
        aabb(iron, (face - 0.05, 2.34, z - 0.005), (face - 0.01, 2.36, z + 0.005), iron_color)
        _horseshoe(kit, (face - 0.035, 2.2, z), 0.058)


def _horseshoe(kit: Kit, center, radius: float) -> None:
    iron = kit.acc(IRON)
    c = Vector(center)
    points = []
    for k in range(9):
        ang = math.radians(-20 + k * 27.5)
        points.append(c + Vector((0.0, math.sin(ang) * radius, math.cos(ang) * radius)))
    for a, b in zip(points, points[1:]):
        oriented_box(iron, tuple(a), tuple(b), 0.02, 0.008, iron_color, up=(1, 0, 0))


def build_finished_goods_shelf(kit: Kit) -> None:
    # Finished work waits on a plank shelf by the courtyard door for pickup.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    face = 13.0
    aabb(oak, (15.3, 1.42, face - 0.34), (17.9, 1.47, face), oak_forge)
    for x in (15.6, 17.6):
        oriented_box(oak, (x, 1.42, face - 0.3), (x, 1.12, face - 0.02), 0.05, 0.05, oak_forge)
    # Strap hinges, a pot hook and a pair of horseshoes.
    for i in range(3):
        aabb(iron, (15.45 + i * 0.12, 1.47, face - 0.3), (15.5 + i * 0.12, 1.475, face - 0.05), iron_color)
    tube(iron, (16.2, 1.475, face - 0.2), (16.75, 1.475, face - 0.22), 0.009, 0.009, 5, iron_color)
    _horseshoe(kit, (17.2, 1.53, face - 0.035), 0.058)
    _horseshoe(kit, (17.45, 1.53, face - 0.035), 0.058)
    # Chain and pot hooks hang from a wall spike below.
    aabb(iron, (16.95, 1.05, face - 0.05), (17.0, 1.08, face), iron_color)
    for k in range(7):
        y = 1.02 - k * 0.055
        tube(iron, (16.975, y, face - 0.03), (16.975, y - 0.045, face - 0.03), 0.008, 0.008, 5, iron_color)


def build_living_dressing(kit: Kit) -> None:
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    # Peg rail by the courtyard door for cloaks and the smith's leather apron.
    aabb(oak, (8.6, 1.62, 12.92), (11.6, 1.72, 13.0), oak_living)
    for x in (8.9, 9.6, 10.3, 11.0):
        tube(oak, (x, 1.67, 12.93), (x, 1.7, 12.78), 0.016, 0.014, 6, oak_living)
    # Wall aumbry (cupboard niche) framed in oak beside the ledger.
    aabb(oak, (1.0, 1.25, 4.9), (1.06, 1.33, 5.8), oak_living)
    aabb(oak, (1.0, 1.95, 4.9), (1.06, 2.03, 5.8), oak_living)
    for z in (4.9, 5.72):
        aabb(oak, (1.0, 1.25, z), (1.06, 2.03, z + 0.08), oak_living)
    aabb(kit.acc(LOFT), (0.93, 1.33, 4.98), (1.005, 1.95, 5.72), flat((0.06, 0.05, 0.045)))
    # Pine-splint holder on the forge face of the fire wall (candle prop
    # forge_wayfinding_splint sits at y 0.875 on this bracket).
    aabb(iron, (15.0, 0.8, 5.47), (15.14, 0.83, 5.53), iron_color)
    tube(iron, (15.13, 0.83, 5.5), (15.13, 0.9, 5.5), 0.012, 0.016, 6, iron_color)


# --- loft ceiling ---------------------------------------------------------------------

FLUE_HOLE = (19.95, 21.05, 1.0, 1.72)  # x0, x1, z0, z1 around the hearth flue


def _outside_flue(x0: float, x1: float, z0: float, z1: float) -> bool:
    fx0, fx1, fz0, fz1 = FLUE_HOLE
    return x1 <= fx0 or x0 >= fx1 or z1 <= fz0 or z0 >= fz1


def build_ceiling(kit: Kit) -> None:
    h = WALL_HEIGHT
    oak = kit.acc(OAK)
    stone = kit.acc(LIMESTONE)
    joist_d, girder_d = 0.2, 0.32
    joist_bottom = h - joist_d
    girder_bottom = joist_bottom - girder_d
    bays = (LIVING_X, FORGE_X)
    # Wall plates on every inner face carry the joist ends.
    for bx0, bx1 in bays:
        aabb(oak, (bx0, joist_bottom, 1.0), (bx1, h, 1.18), oak_for)
        aabb(oak, (bx0, joist_bottom, 12.82), (bx1, h, 13.0), oak_for)
        aabb(oak, (bx0, joist_bottom, 1.0), (bx0 + 0.18, h, 13.0), oak_for)
        aabb(oak, (bx1 - 0.18, joist_bottom, 1.0), (bx1, h, 13.0), oak_for)
    # Two summer beams per bay on limestone corbels with curved-look braces.
    for bx0, bx1 in bays:
        for zc in (4.8, 9.2):
            aabb(oak, (bx0, girder_bottom, zc - 0.15), (bx1, joist_bottom, zc + 0.15), oak_for)
            for wall_x, sign in ((bx0, 1.0), (bx1, -1.0)):
                aabb(stone, (min(wall_x, wall_x + sign * 0.3), girder_bottom - 0.22, zc - 0.2),
                     (max(wall_x, wall_x + sign * 0.3), girder_bottom, zc + 0.2), stone_reveal)
                foot = (wall_x + sign * 0.05, girder_bottom - 0.85, zc)
                top = (wall_x + sign * 0.95, girder_bottom + 0.02, zc)
                oriented_box(oak, foot, top, 0.14, 0.13, oak_for, up=(0.0, 0.0, 1.0))
    # Joists span north-south over the beams.
    for bx0, bx1 in bays:
        x = bx0 + 0.42
        while x < bx1 - 0.3:
            z_ranges = [(1.18, 12.82)]
            if not _outside_flue(x - 0.08, x + 0.08, 1.0, 12.82):
                z_ranges = [(FLUE_HOLE[3] + 0.16, 12.82)]
            for z0, z1 in z_ranges:
                aabb(oak, (x - 0.075, joist_bottom, z0), (x + 0.075, h, z1), oak_for, skip=("top",))
            x += 0.72
    # Trimmer framing the flue hole.
    fx0, fx1, fz0, fz1 = FLUE_HOLE
    aabb(oak, (fx0 - 0.5, joist_bottom, fz1), (fx1 + 0.5, h, fz1 + 0.16), oak_forge)
    # Loft boards laid east-west on the joists; seen from below only.
    rng = random.Random(1344)
    boards = kit.acc(BOARDS)
    for bx0, bx1 in ((0.0, 14.5), (14.5, 26.0)):
        z = 0.0
        while z < 14.0:
            width = min(0.26 + rng.random() * 0.1, 14.0 - z)
            tone = 0.75 + rng.random() * 0.2
            color = (lambda p, tone=tone: mix((tone, tone * 0.95, tone * 0.9), SOOT,
                                              0.3 + 0.62 * forge_soot(p)) if p[0] > 14.5
                     else scale_color((tone, tone * 0.95, tone * 0.88), 0.95 - 0.35 * math.exp(
                         -(((p[0] - DOMESTIC_HEARTH[0]) / 2.0) ** 2 + ((p[2] - 1.5) / 2.5) ** 2))))
            segments = [(bx0, bx1)]
            if bx0 > 14.0 and not _outside_flue(bx0, bx1, z, z + width):
                segments = [(bx0, fx0), (fx1, bx1)]
            for x0, x1 in segments:
                panel(boards, (x0, h, z), (x1 - x0, 0, 0), (0, 0, width - 0.004), (0, -1, 0), color, step=1.4)
            z += width
    # Dark loft void above the boards closes the room against the sky dome.
    panel(kit.acc(LOFT), (0.0, h + 0.25, 0.0), (26.0, 0, 0), (0, 0, 14.0), (0, -1, 0),
          flat((0.03, 0.028, 0.025)), step=26.0)
    build_ceiling_dressing(kit, joist_bottom)


def build_ceiling_dressing(kit: Kit, joist_bottom: float) -> None:
    oak = kit.acc(OAK)
    straw = kit.acc(STRAW)
    # Drying pole with herb and onion-top bundles above the kitchen board.
    for x in (6.1, 8.9):
        tube(straw, (x, joist_bottom, 2.4), (x, 2.95, 2.4), 0.006, 0.006, 4, flat((0.7, 0.62, 0.45)), caps=False)
    tube(oak, (5.9, 2.95, 2.4), (9.1, 2.95, 2.4), 0.022, 0.022, 7, oak_living)
    rng = random.Random(1345)
    for k in range(7):
        x = 6.25 + k * 0.4 + (rng.random() - 0.5) * 0.08
        length = 0.3 + rng.random() * 0.18
        green = (0.55 + rng.random() * 0.15, 0.62 + rng.random() * 0.12, 0.38)
        tube(straw, (x, 2.93, 2.4), (x, 2.93 - length, 2.4 + (rng.random() - 0.5) * 0.05),
             0.03, 0.075 + rng.random() * 0.03, 7, flat(green), jitter=0.25, seed=k)


# --- forge kit: hearth, anvil, bellows, tub, stock rack ---------------------------------


def hearth_soot(p) -> float:
    # The plume sits over the fire pot and in the hood throat.
    p = (p[0] - HEARTH_CENTER[0], p[1], p[2] - HEARTH_CENTER[1])
    s = 0.8 * math.exp(-(((p[0] - FIRE_POT_LOCAL[0]) / 0.9) ** 2 + ((p[2] + 0.6) / 1.1) ** 2)) * smoothstep(0.5, 1.6, p[1])
    s += 0.45 * smoothstep(1.7, 3.2, p[1])
    s += 0.1 * fbm(p[0] * 2.0, p[1] * 2.0, p[2] * 2.0, 83)
    return clamp01(s)


def hearth_stone(p):
    base = scale_color((0.82, 0.8, 0.76), 1.0 + 0.1 * fbm(p[0] * 2.2, p[1] * 2.2, p[2] * 2.2, 89))
    base = mix(base, GRIME, 0.35 * (1.0 - smoothstep(0.0, 0.3, p[1])))
    # Heat and smoke blacken the masonry nearest the fire first.
    local = (p[0] - HEARTH_CENTER[0], p[1], p[2] - HEARTH_CENTER[1])
    near_fire = math.exp(-(((local[0] - FIRE_POT_LOCAL[0]) / 0.8) ** 2 + ((local[2] - FIRE_POT_LOCAL[2]) / 0.9) ** 2
                           + ((local[1] - HEARTH_TOP) / 0.6) ** 2))
    return mix(base, SOOT, clamp01(0.85 * hearth_soot(p) + 0.55 * near_fire))


def hearth_clay(p):
    # Fireback, fire-bed lining and hood interior: clay baked and smoke-black.
    base = scale_color((0.95, 0.9, 0.84), 1.0 + 0.08 * fbm(p[0] * 3.0, p[1] * 3.0, p[2] * 3.0, 97))
    return mix(base, SOOT, clamp01(0.62 + 0.38 * hearth_soot(p) + 0.1 * fbm(p[0] * 6, p[1] * 6, p[2] * 6, 98)))


def hood_daub(p):
    # Lime-washed daub over the hood frame: soot licks up from the lip and
    # gathers into the throat, the broad faces stay a smoky cream.
    base = scale_color((0.95, 0.92, 0.86), 1.0 + 0.07 * fbm(p[0] * 2.5, p[1] * 2.5, p[2] * 2.5, 99))
    lip = math.exp(-(((p[1] - 2.05) / 0.3) ** 2))
    throat = smoothstep(2.5, 3.0, p[1])
    streak = 0.18 * max(0.0, fbm(p[0] * 5.0, p[1] * 0.6, p[2] * 5.0, 105))
    return mix(base, SOOT, clamp01(0.3 + 0.5 * lip + 0.45 * throat + streak))


def hearth_oak(p):
    return mix(scale_color((0.72, 0.64, 0.56), 0.9 + 0.12 * fbm(p[0] * 3, p[1] * 3, p[2] * 3, 101)), SOOT,
               clamp01(0.35 + 0.6 * hearth_soot(p)))


def slab_between(acc: Acc, bottom_a, bottom_b, top_a, top_b, inward, thickness: float, color_fn) -> None:
    """Quad slab from an outer quad (two bottom, two top corners) pushed `inward`."""
    offset = Vector(inward).normalized() * thickness
    outer = [Vector(bottom_a), Vector(bottom_b), Vector(top_b), Vector(top_a)]
    inner = [v + offset for v in outer]
    hexa(acc, [tuple(v) for v in (outer[0], outer[1], inner[1], inner[0])]
         + [tuple(v) for v in (outer[3], outer[2], inner[2], inner[3])], color_fn)


def _hood_face(kit: Kit, bottom_a, bottom_b, top_a, top_b, inward) -> None:
    clay = kit.acc(CLAY)
    ba, bb, ta, tb = Vector(bottom_a), Vector(bottom_b), Vector(top_a), Vector(top_b)
    n_in = Vector(inward).normalized()
    rows, cols = 6, 10
    outer, inner = [], []
    for j in range(rows + 1):
        v = j / rows
        left, right = ba.lerp(ta, v), bb.lerp(tb, v)
        row_o, row_i = [], []
        for i in range(cols + 1):
            u = i / cols
            p = left.lerp(right, u)
            edge = min(u, 1.0 - u, v, 1.0 - v)
            bump = 0.02 * smoothstep(0.0, 0.12, edge) * fbm(p.x * 3.0, p.y * 3.0, p.z * 3.0, 233)
            row_o.append(clay.vertex(tuple(p - n_in * bump)))
            row_i.append(clay.vertex(tuple(p + n_in * 0.07)))
        outer.append(row_o)
        inner.append(row_i)
    for j in range(rows):
        for i in range(cols):
            for grid, flip, color in ((outer, False, hood_daub), (inner, True, hearth_clay)):
                quad = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
                pts = [Vector(clay.verts[k]) for k in quad]
                normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
                want = n_in if flip else -n_in
                if normal.dot(want) < 0.0:
                    quad.reverse()
                clay.face(quad, color, smooth=True)
    for j in (0, rows):
        for i in range(cols):
            clay.poly([clay.verts[outer[j][i]], clay.verts[outer[j][i + 1]], clay.verts[inner[j][i + 1]],
                       clay.verts[inner[j][i]]], hearth_clay, hint=(0.0, -1.0 if j == 0 else 1.0, 0.0))


def build_hearth(kit: Kit) -> None:
    stone = kit.acc(LIMESTONE)
    clay = kit.acc(CLAY)
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    hw = HEARTH_HALF_WIDTH
    back, front = -1.5, 0.3
    base_top = HEARTH_TOP - 0.12
    # Raised limestone hearth (Haapsalu-type raised forge, dossier zone A).
    wall_block(kit, (-hw, 0.0, back), (hw, base_top, front), {
        "-x": (LIMESTONE, hearth_stone, 0.02), "+x": (LIMESTONE, hearth_stone, 0.02),
        "+z": (LIMESTONE, hearth_stone, 0.02),
    }, seed=103)
    # Coping slabs frame the clay-lined fire bed.
    slab = kit.acc(SLAB)
    coping = lambda p: mix((0.78, 0.76, 0.72), SOOT, 0.35 + 0.5 * hearth_soot(p))
    aabb(slab, (-hw - 0.04, base_top, front - 0.3), (hw + 0.04, HEARTH_TOP, front + 0.04), coping)
    aabb(slab, (-hw - 0.04, base_top, -1.12), (-0.76, HEARTH_TOP, front - 0.3), coping)
    aabb(slab, (0.76, base_top, -1.12), (hw + 0.04, HEARTH_TOP, front - 0.3), coping)
    aabb(clay, (-0.76, base_top, -1.12), (0.76, HEARTH_TOP - 0.06, front - 0.3), hearth_clay, skip=("bottom",))
    # Ash and clinker banked round the fire pot; Godot lays live coals in it.
    fx, _, fz = FIRE_POT_LOCAL
    tube(kit.acc(ASH), (fx, HEARTH_TOP - 0.065, fz), (fx, HEARTH_TOP - 0.04, fz), 0.46, 0.34, 14,
         lambda p: scale_color((0.55, 0.53, 0.5), 0.8 + 0.3 * fbm(p[0] * 6, 0, p[2] * 6, 107)), jitter=0.12, seed=5)
    # Fireback and cheeks: three-wall hearth open to the smith (dossier plate .03).
    wall_block(kit, (-hw, base_top, back), (hw, 1.98, -1.12), {
        "+z": (LIMESTONE, hearth_stone, 0.015), "-x": (LIMESTONE, hearth_stone, 0.0),
        "+x": (LIMESTONE, hearth_stone, 0.0), "+y": (LIMESTONE, hearth_stone, 0.0),
    }, seed=109)
    for x0, x1 in ((-hw, -0.76), (0.76, hw)):
        hexa(stone, [(x0, HEARTH_TOP, -1.12), (x1, HEARTH_TOP, -1.12), (x1, HEARTH_TOP, -0.4), (x0, HEARTH_TOP, -0.4),
                     (x0, 1.16, -1.12), (x1, 1.16, -1.12), (x1, 0.9, -0.4), (x0, 0.9, -0.4)], hearth_stone)
    # Clay tuyere through the left cheek, bound with an iron ring at the mouth.
    ty = TUYERE_WORLD[1]
    tube(clay, (-hw - 0.16, ty, fz), (-0.55, ty + 0.02, fz), 0.07, 0.05, 10, hearth_clay)
    tube(iron, (-hw - 0.17, ty, fz), (-hw - 0.1, ty, fz), 0.078, 0.078, 10, iron_color)
    # Smoke hood: daub over a timber frame, sloping to the masonry flue.
    y0, y1 = 1.98, 3.0
    hx0, hz_front = 1.22, 0.36
    tx, tz = 0.42, -0.88
    inward_front = (0.0, 0.0, -1.0)
    # Each hood face: an uneven daubed outer skin, a sooted inner skin and a
    # thin top/bottom edge, rather than a machined sheet.
    faces = [
        ((-hx0, y0, hz_front), (hx0, y0, hz_front), (-tx, y1, tz), (tx, y1, tz), (0.0, 0.0, -1.0)),
        ((-hx0, y0, back), (-hx0, y0, hz_front), (-tx, y1, back), (-tx, y1, tz), (1.0, 0.0, 0.0)),
        ((hx0, y0, hz_front), (hx0, y0, back), (tx, y1, tz), (tx, y1, back), (-1.0, 0.0, 0.0)),
    ]
    for bottom_a, bottom_b, top_a, top_b, inward in faces:
        _hood_face(kit, bottom_a, bottom_b, top_a, top_b, inward)
    # Oak studs of the hood frame show through the daub on the front face.
    for k in range(5):
        t = (k + 0.5) / 5.0
        a = Vector((-hx0, y0, hz_front)).lerp(Vector((hx0, y0, hz_front)), t)
        b = Vector((-tx, y1, tz)).lerp(Vector((tx, y1, tz)), t)
        oriented_box(oak, tuple(a + Vector((0, 0.02, 0.04))), tuple(b + Vector((0, -0.02, 0.03))), 0.07, 0.035,
                     hearth_oak, up=(0.0, 0.62, 0.78))
    # Oak rim beams carry the hood; iron hangers tie the front to the loft joists.
    aabb(oak, (-hx0 - 0.08, y0 - 0.18, hz_front - 0.04), (hx0 + 0.08, y0 + 0.02, hz_front + 0.12), hearth_oak)
    for sx in (-1.0, 1.0):
        aabb(oak, (sx * hx0 - 0.08, y0 - 0.18, back), (sx * hx0 + 0.08, y0 + 0.02, hz_front), hearth_oak)
        tube(iron, (sx * (hx0 - 0.1), y0, hz_front + 0.04), (sx * (hx0 - 0.1), WALL_HEIGHT - 0.2, hz_front + 0.04),
             0.012, 0.012, 6, iron_color)
    # Masonry flue rises through the loft.
    wall_block(kit, (-tx - 0.08, y1 - 0.05, back), (tx + 0.08, WALL_HEIGHT + 0.45, tz - 0.02), {
        "-x": (LIMESTONE, hearth_stone, 0.0), "+x": (LIMESTONE, hearth_stone, 0.0),
        "+z": (LIMESTONE, hearth_stone, 0.0), "+y": (LIMESTONE, flat((0.2, 0.18, 0.17)), 0.0),
    }, seed=113)
    # Charcoal box on the right, poker and rake against the left cheek.
    box_color = hearth_oak
    aabb(oak, (hw + 0.04, 0.0, -1.2), (hw + 0.46, 0.5, 0.15), box_color, skip=("top",))
    aabb(kit.acc(LOFT), (hw + 0.07, 0.3, -1.17), (hw + 0.43, 0.46, 0.12), flat((0.04, 0.035, 0.03)), skip=("bottom",))
    rng = random.Random(117)
    char = kit.acc(CHARCOAL)
    for _ in range(46):
        cx = hw + 0.08 + rng.random() * 0.34
        cz = -1.14 + rng.random() * 1.24
        cy = 0.44 + rng.random() * 0.08
        box(char, (cx, cy, cz), (0.05 + rng.random() * 0.05, 0.035 + rng.random() * 0.03, 0.04 + rng.random() * 0.05),
            flat((0.9, 0.9, 0.9)), rot_y=rng.random() * math.pi)
    tube(iron, (-hw - 0.05, 0.012, 0.55), (-hw + 0.02, 1.05, 0.2), 0.011, 0.011, 6, iron_color)
    tube(iron, (-hw + 0.02, 1.05, 0.2), (-hw + 0.06, 1.12, 0.24), 0.011, 0.011, 6, iron_color)
    tube(iron, (-hw - 0.14, 0.012, 0.62), (-hw - 0.06, 1.1, 0.27), 0.01, 0.01, 6, iron_color)
    aabb(iron, (-hw - 0.2, 0.0, 0.58), (-hw - 0.08, 0.012, 0.74), iron_color)


def build_anvil(kit: Kit) -> None:
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    bright = kit.acc(IRON_BRIGHT)
    cz = 0.5
    stump_color = lambda p: mix(scale_color((0.66, 0.58, 0.5), 0.9 + 0.15 * fbm(p[0] * 6, p[1] * 3, p[2] * 6, 131)),
                                SOOT, 0.25 + 0.25 * (1.0 - smoothstep(0.0, 0.25, p[1])))
    tube(oak, (0.0, 0.0, cz), (0.0, 0.5, cz), 0.34, 0.3, 18, stump_color, jitter=0.07, seed=11, rings=4)
    for y in (0.1, 0.4):
        tube(iron, (0.0, y, cz), (0.0, y + 0.035, cz), 0.345 - y * 0.1, 0.342 - y * 0.1, 18, iron_color, caps=False)
    # Block anvil (no horn: the London pattern is post-medieval), spiked into
    # the stump; the steel face is welded on and polished by work.
    def block(y0, y1, hx0, hz0, hx1, hz1, acc, color_fn):
        hexa(acc, [(-hx0, y0, cz - hz0), (hx0, y0, cz - hz0), (hx0, y0, cz + hz0), (-hx0, y0, cz + hz0),
                   (-hx1, y1, cz - hz1), (hx1, y1, cz - hz1), (hx1, y1, cz + hz1), (-hx1, y1, cz + hz1)], color_fn)

    block(0.47, 0.6, 0.13, 0.1, 0.11, 0.085, iron, iron_color)
    block(0.6, 0.765, 0.11, 0.085, 0.165, 0.11, iron, iron_color)
    block(0.765, 0.8, 0.168, 0.112, 0.165, 0.11, bright, flat((1.0, 1.0, 1.0)))
    aabb(kit.acc(LOFT), (0.11, 0.799, cz - 0.014), (0.138, 0.8015, cz + 0.014), flat((0.02, 0.02, 0.02)))
    # Beak iron (bickern) driven into the stump beside the anvil.
    tube(iron, (-0.2, 0.46, cz + 0.12), (-0.2, 0.7, cz + 0.12), 0.018, 0.022, 6, iron_color)
    tube(iron, (-0.2, 0.71, cz + 0.12), (-0.42, 0.72, cz + 0.1), 0.034, 0.005, 8, iron_color)
    tube(iron, (-0.2, 0.71, cz + 0.12), (-0.12, 0.71, cz + 0.12), 0.034, 0.03, 8, iron_color)
    # Scale and slack-quench drips darken a ring of floor round the stump.
    tube(kit.acc(ASH), (0.0, 0.0, cz), (0.0, 0.016, cz), 0.62, 0.6, 20,
         lambda p: scale_color((0.25, 0.23, 0.22), 0.8 + 0.3 * fbm(p[0] * 7, 0, p[2] * 7, 137)), jitter=0.18, seed=13, caps=True)


def _teardrop(t: float, half_back: float, half_front: float) -> float:
    return half_front + (half_back - half_front) * math.sqrt(max(0.0, 1.0 - t ** 1.7))


def build_bellows(kit: Kit) -> None:
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    leather = kit.acc(LEATHER)
    zc = HEARTH_CENTER[1] + FIRE_POT_LOCAL[2] - BELLOWS_CENTER[1]  # align with the tuyere
    x_back, x_front, x_tip = -0.72, 1.0, TUYERE_WORLD[0] - BELLOWS_CENTER[0]
    y_bottom, y_top_back, y_top_front = 0.5, 0.9, 0.68
    half_back, half_front = 0.4, 0.12
    board_color = lambda p: mix(scale_color((0.74, 0.66, 0.58), 0.9 + 0.12 * fbm(p[0] * 4, p[1] * 4, p[2] * 4, 149)),
                                SOOT, 0.2)
    samples = 14

    def outline(y_fn, grow: float):
        pts = []
        for i in range(samples + 1):
            t = i / samples
            x = x_back + (x_front - x_back) * t
            pts.append((x, y_fn(t), zc - _teardrop(t, half_back, half_front) * grow))
        for i in range(samples, -1, -1):
            t = i / samples
            x = x_back + (x_front - x_back) * t
            pts.append((x, y_fn(t), zc + _teardrop(t, half_back, half_front) * grow))
        return pts

    def board(y_fn, thickness: float):
        lower = outline(lambda t: y_fn(t) - thickness * 0.5, 1.0)
        upper = outline(lambda t: y_fn(t) + thickness * 0.5, 1.0)
        n = len(lower)
        for i in range(n):
            j = (i + 1) % n
            mid = Vector(((lower[i][0] + lower[j][0]) * 0.5, 0.0, (lower[i][2] + lower[j][2]) * 0.5))
            outward = mid - Vector((x_back + 0.55, 0.0, zc))
            oak.poly([lower[i], lower[j], upper[j], upper[i]], board_color, hint=tuple(outward))
        oak.poly(upper, board_color, hint=(0.0, 1.0, 0.0))
        oak.poly(lower, board_color, hint=(0.0, -1.0, 0.0))

    board(lambda t: y_bottom, 0.05)
    top_y = lambda t: y_top_back + (y_top_front - y_top_back) * t
    board(top_y, 0.045)
    # Pleated leather between the boards: five folds bulging alternately.
    folds = 8
    rings = []
    for k in range(folds + 1):
        f = k / folds
        # Alternate ridge/valley rings so the pleats catch the forge light.
        ridge = 0.16 if k % 2 else -0.04
        grow = 1.0 + ridge * (0.35 + 0.65 * math.sin(math.pi * f))
        rings.append(outline(lambda t, f=f: (y_bottom + 0.025) + (top_y(t) - 0.022 - y_bottom - 0.025) * f, grow))
    leather_color = lambda p: scale_color((1.0, 0.92, 0.8), 0.9 + 0.2 * fbm(p[0] * 5, p[1] * 9, p[2] * 5, 151))
    for k in range(folds):
        lo, hi = rings[k], rings[k + 1]
        n = len(lo)
        for i in range(n):
            j = (i + 1) % n
            mid = Vector(((lo[i][0] + lo[j][0]) * 0.5, 0.0, (lo[i][2] + lo[j][2]) * 0.5))
            outward = mid - Vector((x_back + 0.55, 0.0, zc))
            leather.poly([lo[i], lo[j], hi[j], hi[i]], leather_color, hint=tuple(outward))
    # Iron tacks along the leather-to-board seams.
    for y_fn in (lambda t: y_bottom + 0.028, lambda t: top_y(t) - 0.025):
        for i in range(0, samples + 1, 2):
            t = i / samples
            x = x_back + (x_front - x_back) * t
            for sz in (-1.0, 1.0):
                z = zc + sz * (_teardrop(t, half_back, half_front) + 0.004)
                box(iron, (x, y_fn(t), z), (0.018, 0.018, 0.012), iron_color)
    # Iron-bound nozzle into the clay tuyere.
    ny = TUYERE_WORLD[1]
    tube(oak, (x_front - 0.05, ny, zc), (x_front + 0.35, ny, zc), 0.1, 0.07, 10, board_color)
    tube(iron, (x_front + 0.33, ny, zc), (x_tip, ny, zc), 0.05, 0.03, 10, iron_color)
    for x in (x_front + 0.05, x_front + 0.3):
        tube(iron, (x, ny, zc), (x + 0.03, ny, zc), 0.105 - (x - x_front) * 0.1, 0.103 - (x - x_front) * 0.1, 10,
             iron_color)
    # Trestle under the fixed board.
    for x in (-0.45, 0.6):
        for sz in (-1.0, 1.0):
            oriented_box(oak, (x, 0.036, zc + sz * 0.3), (x, y_bottom - 0.025, zc + sz * 0.2), 0.07, 0.07, oak_forge)
        aabb(oak, (x - 0.05, y_bottom - 0.1, zc - 0.34), (x + 0.05, y_bottom - 0.025, zc + 0.34), oak_forge)
    # Stone weight that presses the top board down between strokes.
    box(kit.acc(LIMESTONE), (-0.25, top_y(0.28) + 0.09, zc), (0.28, 0.14, 0.22), hearth_stone, rot_y=0.1)
    # Rocker: post by the nozzle, pole over the boards, handle at the back
    # where the apprentice stands (routine ap.forge.bellows faces +x).
    post_x, post_z = 1.2, zc + 0.42
    aabb(oak, (post_x - 0.07, 0.0, post_z - 0.07), (post_x + 0.07, 1.82, post_z + 0.07), oak_forge)
    pivot = (post_x, 1.78, zc)
    aabb(oak, (post_x - 0.05, 1.7, zc - 0.05), (post_x + 0.05, 1.8, post_z), oak_forge)
    handle_end = (x_back - 0.3, 1.46, zc)
    oriented_box(oak, handle_end, (post_x + 0.2, 1.84, zc), 0.08, 0.09, oak_forge)
    tube(oak, (handle_end[0], handle_end[1] - 0.02, zc - 0.22), (handle_end[0], handle_end[1] - 0.02, zc + 0.22),
         0.022, 0.022, 7, oak_forge)
    tube(iron, (pivot[0], pivot[1] + 0.02, zc - 0.08), (pivot[0], pivot[1] + 0.02, zc + 0.5), 0.012, 0.012, 6, iron_color)
    # Iron link rod from the pole down to the top board.
    rod_x = 0.05
    t_rod = (rod_x - x_back) / (x_front - x_back)
    pole_y = handle_end[1] + (1.84 - handle_end[1]) * ((rod_x - handle_end[0]) / (post_x + 0.2 - handle_end[0]))
    tube(iron, (rod_x, top_y(t_rod) + 0.02, zc), (rod_x, pole_y - 0.03, zc), 0.011, 0.011, 6, iron_color)
    # Water bucket with swab and a charcoal basket in the free south half.
    build_bucket(kit, (0.55, 0.0, 0.55), 0.17, 0.32, 211)
    tube(oak, (0.55, 0.12, 0.55), (0.72, 0.95, 0.45), 0.012, 0.012, 6, oak_forge)
    basket = lambda p: scale_color((0.72, 0.62, 0.46), 0.85 + 0.2 * fbm(p[0] * 20, p[1] * 30, p[2] * 20, 157))
    tube(kit.acc(STRAW), (-0.35, 0.0, 0.52), (-0.35, 0.36, 0.52), 0.2, 0.25, 16, basket, caps=False)
    tube(kit.acc(STRAW), (-0.35, 0.0, 0.52), (-0.35, 0.01, 0.52), 0.2, 0.2, 16, basket)
    rng = random.Random(163)
    char = kit.acc(CHARCOAL)
    for _ in range(26):
        a, r = rng.random() * math.tau, rng.random() * 0.2
        box(char, (-0.35 + math.cos(a) * r, 0.3 + rng.random() * 0.07, 0.52 + math.sin(a) * r),
            (0.05 + rng.random() * 0.04, 0.035, 0.045), flat((0.9, 0.9, 0.9)), rot_y=rng.random() * 3.0)


def build_bucket(kit: Kit, base, radius: float, height: float, seed: int) -> None:
    oak = kit.acc(OAK)
    staves = 12
    rng = random.Random(seed)
    bx, by, bz = base
    for s in range(staves):
        a0 = math.tau * s / staves
        a1 = math.tau * (s + 1) / staves - 0.02
        r0, r1 = radius, radius * 1.1
        hh = height * (0.97 + rng.random() * 0.06)
        corners = []
        for y, rr in ((by, r0), (by + hh, r1)):
            corners.extend([(bx + math.cos(a0) * rr, y, bz + math.sin(a0) * rr),
                            (bx + math.cos(a1) * rr, y, bz + math.sin(a1) * rr),
                            (bx + math.cos(a1) * (rr - 0.022), y, bz + math.sin(a1) * (rr - 0.022)),
                            (bx + math.cos(a0) * (rr - 0.022), y, bz + math.sin(a0) * (rr - 0.022))])
        tone = 0.78 + rng.random() * 0.14
        hexa(oak, corners, flat((tone, tone * 0.92, tone * 0.84)))
    tube(oak, (bx, by + 0.01, bz), (bx, by + 0.035, bz), radius - 0.01, radius - 0.01, 12, flat((0.6, 0.55, 0.5)))
    tube(kit.acc(WATER), (bx, by + height * 0.78, bz), (bx, by + height * 0.8, bz), radius * 1.06, radius * 1.06, 14,
         flat((1.0, 1.0, 1.0)))
    for y in (0.12, 0.75):
        rr = radius + (radius * 0.1) * y + 0.004
        tube(kit.acc(STRAW), (bx, by + height * y, bz), (bx, by + height * y + 0.025, bz), rr, rr + 0.002, 14,
             flat((0.66, 0.56, 0.42)), caps=False)


def build_slack_tub(kit: Kit) -> None:
    # Coopered oak half-tub with split-hazel hoops; the apprentice quenches from
    # the west side (routine ap.forge.quench stands at x 16.5 facing +x).
    oak = kit.acc(OAK)
    # Centred so the forge tongs prop (cell 17,6) stands cooling in the water.
    cx, cz = 0.32, 0.25
    staves = 22
    rng = random.Random(173)
    r_bottom, r_top, height = 0.37, 0.42, 0.56
    for s in range(staves):
        a0 = math.tau * s / staves
        a1 = math.tau * (s + 1) / staves - 0.012
        hh = height + (rng.random() - 0.5) * 0.025
        corners = []
        for y, rr in ((0.0, r_bottom), (hh, r_top)):
            corners.extend([(cx + math.cos(a0) * rr, y, cz + math.sin(a0) * rr),
                            (cx + math.cos(a1) * rr, y, cz + math.sin(a1) * rr),
                            (cx + math.cos(a1) * (rr - 0.035), y, cz + math.sin(a1) * (rr - 0.035)),
                            (cx + math.cos(a0) * (rr - 0.035), y, cz + math.sin(a0) * (rr - 0.035))])
        tone = 0.62 + rng.random() * 0.18
        wet = lambda p, tone=tone: mix((tone, tone * 0.9, tone * 0.82), (0.3, 0.27, 0.25),
                                       0.5 * (1.0 - smoothstep(0.0, 0.25, p[1])))
        hexa(oak, corners, wet)
    tube(kit.acc(WATER), (cx, 0.44, cz), (cx, 0.455, cz), 0.4, 0.4, 20, flat((1.0, 1.0, 1.0)))
    for y in (0.08, 0.3, 0.5):
        rr = r_bottom + (r_top - r_bottom) * (y / height) + 0.006
        tube(kit.acc(STRAW), (cx, y, cz), (cx, y + 0.045, cz), rr, rr + 0.002, 22,
             lambda p: scale_color((0.62, 0.52, 0.38), 0.85 + 0.2 * fbm(p[0] * 30, p[1] * 30, p[2] * 30, 179)),
             caps=False)
    # Swab stick for sprinkling the fire, left standing in the tub.
    tube(oak, (cx + 0.1, 0.1, cz - 0.05), (cx + 0.28, 1.0, cz - 0.24), 0.013, 0.013, 6, oak_forge)
    build_bucket(kit, (0.66, 0.0, -0.6), 0.16, 0.3, 181)


def build_stock_rack(kit: Kit) -> None:
    # Iron stock is racked away from the quench splash (dossier zone E): bar
    # iron, Swedish osmund lumps in a keg, nail rod, sand for welding flux.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    x0, x1, z0, z1 = -0.88, 0.88, -0.32, 0.32
    for x in (x0, x1):
        for z in (z0, z1):
            aabb(oak, (x - 0.045, 0.0, z - 0.045), (x + 0.045, 1.62, z + 0.045), oak_forge)
    for y in (0.3, 0.86, 1.38):
        aabb(oak, (x0 - 0.06, y, z0 - 0.06), (x1 + 0.06, y + 0.045, z1 + 0.06), oak_forge)
        for z in (z0, z1):
            aabb(oak, (x0, y - 0.08, z - 0.03), (x1, y, z + 0.03), oak_forge)
    rng = random.Random(191)
    # Bundle of flat bar on the bottom shelf, tied with withies.
    for k in range(14):
        row, col = divmod(k, 5)
        y = 0.345 + row * 0.018
        z = -0.16 + col * 0.045 + row * 0.02
        aabb(iron, (x0 + 0.02, y, z), (x1 - 0.1 + rng.random() * 0.08, y + 0.016, z + 0.038), iron_color)
    for x in (-0.5, 0.45):
        aabb(kit.acc(STRAW), (x, 0.34, -0.19), (x + 0.03, 0.42, 0.1), flat((0.62, 0.52, 0.38)))
    # Osmund keg on the middle shelf.
    build_bucket(kit, (-0.45, 0.905, 0.0), 0.17, 0.3, 193)
    for k in range(9):
        a = rng.random() * math.tau
        r = rng.random() * 0.12
        box(iron, (-0.45 + math.cos(a) * r, 1.19 + rng.random() * 0.04, math.sin(a) * r),
            (0.07, 0.05, 0.06), iron_color, rot_y=rng.random() * 3.0)
    # Nail rod bundle and horseshoe blanks.
    for k in range(10):
        z = -0.1 + (k % 5) * 0.022
        y = 0.91 + (k // 5) * 0.012
        aabb(iron, (-0.15, y, z), (0.7, y + 0.01, z + 0.01), iron_color)
    for k in range(5):
        _flat_shoe(kit, (0.52, 0.91 + k * 0.012, 0.2), 0.06)
    # Top shelf: clay pot of welding sand and a lidded oak box.
    tube(kit.acc(CLAY), (-0.4, 1.425, 0.0), (-0.4, 1.62, 0.0), 0.1, 0.085, 12,
         lambda p: scale_color((1.0, 0.85, 0.7), 0.9 + 0.1 * fbm(p[0] * 9, p[1] * 9, p[2] * 9, 197)), jitter=0.04, seed=3)
    tube(kit.acc(SLAB), (-0.4, 1.6, 0.0), (-0.4, 1.605, 0.0), 0.078, 0.078, 12, flat((0.95, 0.9, 0.78)))
    aabb(oak, (0.1, 1.425, -0.2), (0.7, 1.62, 0.18), oak_forge)
    # Long bars leaning against the east end.
    for k in range(4):
        z = -0.2 + k * 0.1
        tube(iron, (x1 + 0.25, 0.012, z), (x1 + 0.07, 1.75, z * 0.9), 0.012, 0.012, 4, iron_color)


def build_scrap_heap(kit: Kit) -> None:
    # Customer trade-ins and offcuts kept for rework (materials dossier: scrap,
    # nails, worn tools) in a low oak crate, not a free heap of plates.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    x0, x1, z0, z1, h = -0.4, 0.4, -0.3, 0.3, 0.24
    crate = lambda p: mix(scale_color((0.7, 0.62, 0.54), 0.9 + 0.12 * fbm(p[0] * 5, p[1] * 5, p[2] * 5, 223)), SOOT, 0.3)
    aabb(oak, (x0, 0.0, z0), (x1, 0.03, z1), crate)
    for lo, hi in (((x0, 0.0, z0), (x1, h, z0 + 0.025)), ((x0, 0.0, z1 - 0.025), (x1, h, z1)),
                   ((x0, 0.0, z0), (x0 + 0.025, h, z1)), ((x1 - 0.025, 0.0, z0), (x1, h, z1))):
        aabb(oak, lo, hi, crate)
    rng = random.Random(227)
    rust = lambda p: scale_color((0.85, 0.72, 0.62), 0.8 + 0.3 * fbm(p[0] * 9, p[1] * 9, p[2] * 9, 229))
    for _ in range(26):
        x = x0 + 0.06 + rng.random() * (x1 - x0 - 0.12)
        z = z0 + 0.06 + rng.random() * (z1 - z0 - 0.12)
        y = 0.05 + rng.random() * 0.17
        length = 0.08 + rng.random() * 0.22
        ang = rng.random() * math.tau
        tilt = (rng.random() - 0.5) * 0.12
        a = (x - math.cos(ang) * length * 0.5, y - tilt, z - math.sin(ang) * length * 0.5)
        b = (x + math.cos(ang) * length * 0.5, y + tilt, z + math.sin(ang) * length * 0.5)
        oriented_box(iron, a, b, 0.012 + rng.random() * 0.03, 0.006 + rng.random() * 0.012, rust)
    for k in range(3):
        _flat_shoe(kit, (-0.2 + k * 0.17, 0.2 + k * 0.012, 0.05 - k * 0.07), 0.055)
    # A worn axe head and a bent strap hinge on top of the pile.
    box(iron, (0.18, 0.24, -0.1), (0.16, 0.05, 0.07), rust, rot_y=0.5)
    oriented_box(iron, (-0.3, 0.26, -0.18), (0.05, 0.3, -0.02), 0.035, 0.006, rust)


def build_finishing_bench(kit: Kit) -> None:
    # Dossier zone: "finishing bench between anvil and street door for filing,
    # riveting". Without it the whole south half of the forge bay was bare
    # beaten earth, which no working smithy ever is. A screw vice would be an
    # anachronism here, so holding work is done on a stake iron driven through
    # the bench top and on a hardy block, both attested by the Mendel plates.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    bright = kit.acc(IRON_BRIGHT)
    # Free-standing on the bay floor rather than flush to the south wall: the
    # gameplay isometric camera hides the wall row behind the wall head, and a
    # finishing bench is worked from both sides anyway.
    z_back, z_front = 0.33, -0.33
    top_y, slab = 0.88, 0.075
    x0, x1 = -1.25, 1.25
    aabb(oak, (x0, top_y - slab, z_front), (x1, top_y, z_back), oak_forge)
    # Splayed square legs, stretchers and a front apron: trestle joinery, not
    # a modern four-square table.
    for x in (x0 + 0.2, x1 - 0.2):
        for z in (z_front + 0.12, z_back - 0.12):
            oriented_box(oak, (x + (0.0 if z > 0 else 0.03), 0.0, z),
                         (x, top_y - slab, z), 0.05, 0.05, oak_forge)
        aabb(oak, (x - 0.05, 0.24, z_front + 0.1), (x + 0.05, 0.31, z_back - 0.1), oak_forge)
    aabb(oak, (x0 + 0.15, 0.24, -0.06), (x1 - 0.15, 0.3, 0.02), oak_forge)
    aabb(oak, (x0 + 0.05, top_y - slab - 0.16, z_front), (x1 - 0.05, top_y - slab, z_front + 0.05), oak_forge)
    # Stake iron through the left end of the top, polished where work is drawn
    # over it, plus a hardy block for cutting.
    aabb(iron, (x0 + 0.18, top_y, 0.06), (x0 + 0.26, top_y + 0.16, 0.14), iron_color)
    hexa(bright, [(x0 + 0.13, top_y + 0.16, 0.01), (x0 + 0.31, top_y + 0.16, 0.01),
                  (x0 + 0.31, top_y + 0.16, 0.19), (x0 + 0.13, top_y + 0.16, 0.19),
                  (x0 + 0.15, top_y + 0.2, 0.03), (x0 + 0.29, top_y + 0.2, 0.03),
                  (x0 + 0.29, top_y + 0.2, 0.17), (x0 + 0.15, top_y + 0.2, 0.17)], flat((1.0, 1.0, 1.0)))
    aabb(iron, (x0 + 0.5, top_y, 0.1), (x0 + 0.62, top_y + 0.09, 0.22), iron_color)
    # Files and a rivet set laid out where the smith stands, handles to the room.
    rng = random.Random(311)
    for i in range(3):
        x = -0.28 + i * 0.17
        z = 0.02 + rng.random() * 0.12
        oriented_box(iron, (x, top_y + 0.012, z - 0.16), (x + 0.02, top_y + 0.012, z + 0.14),
                     0.014 - i * 0.002, 0.008, iron_color)
        oriented_box(oak, (x + 0.02, top_y + 0.012, z + 0.14), (x + 0.03, top_y + 0.012, z + 0.26),
                     0.019, 0.016, oak_forge)
    hammer(kit, (0.42, top_y + 0.035, 0.3), (1, 0, -0.25), 0.12, 0.3, 313)
    # Shallow oak tray of rivets and nails on the back edge.
    aabb(oak, (0.62, top_y, 0.16), (0.98, top_y + 0.055, 0.4), oak_forge)
    aabb(kit.acc(LOFT), (0.645, top_y + 0.025, 0.185), (0.955, top_y + 0.03, 0.375), flat((0.05, 0.04, 0.04)))
    for _ in range(22):
        x = 0.66 + rng.random() * 0.27
        z = 0.2 + rng.random() * 0.16
        tube(iron, (x, top_y + 0.028, z), (x, top_y + 0.042, z), 0.007, 0.006, 5, iron_color)
    # Part-finished work waiting on the bench: a blade blank and a strap hinge.
    oriented_box(bright, (-0.95, top_y + 0.01, 0.34), (-0.5, top_y + 0.012, 0.22), 0.016, 0.005,
                 flat((0.92, 0.92, 0.94)))
    oriented_box(iron, (-0.5, top_y + 0.012, 0.22), (-0.38, top_y + 0.012, 0.19), 0.011, 0.009, iron_color)
    oriented_box(iron, (0.05, top_y + 0.01, -0.14), (0.52, top_y + 0.01, -0.1), 0.026, 0.006, iron_color)
    # Under the bench: nail keg, offcut crate and a coil of rod.
    staves = 11
    for s in range(staves):
        a0, a1 = math.tau * s / staves, math.tau * (s + 1) / staves - 0.02
        corners = []
        for y, rr in ((0.0, 0.15), (0.34, 0.16)):
            corners.extend([(0.72 + math.cos(a0) * rr, y, 0.16 + math.sin(a0) * rr),
                            (0.72 + math.cos(a1) * rr, y, 0.16 + math.sin(a1) * rr),
                            (0.72 + math.cos(a1) * (rr - 0.02), y, 0.16 + math.sin(a1) * (rr - 0.02)),
                            (0.72 + math.cos(a0) * (rr - 0.02), y, 0.16 + math.sin(a0) * (rr - 0.02))])
        hexa(oak, corners, oak_forge)
    for y in (0.06, 0.28):
        tube(kit.acc(STRAW), (0.72, y, 0.16), (0.72, y + 0.022, 0.16), 0.158, 0.16, 12,
             flat((0.64, 0.54, 0.4)), caps=False)
    for _ in range(14):
        a = rng.random() * math.tau
        r = rng.random() * 0.1
        tube(iron, (0.72 + math.cos(a) * r, 0.3, 0.16 + math.sin(a) * r),
             (0.72 + math.cos(a) * r, 0.36 + rng.random() * 0.03, 0.16 + math.sin(a) * r),
             0.006, 0.004, 5, iron_color)
    crate = lambda p: mix(scale_color((0.68, 0.6, 0.52), 0.9 + 0.12 * fbm(p[0] * 5, p[1] * 5, p[2] * 5, 317)), SOOT, 0.35)
    aabb(oak, (-0.72, 0.0, 0.02), (-0.16, 0.03, 0.4), crate)
    for lo, hi in (((-0.72, 0.0, 0.02), (-0.16, 0.2, 0.045)), ((-0.72, 0.0, 0.375), (-0.16, 0.2, 0.4)),
                   ((-0.72, 0.0, 0.02), (-0.695, 0.2, 0.4)), ((-0.185, 0.0, 0.02), (-0.16, 0.2, 0.4))):
        aabb(oak, lo, hi, crate)
    rust = lambda p: scale_color((0.82, 0.7, 0.6), 0.8 + 0.3 * fbm(p[0] * 9, p[1] * 9, p[2] * 9, 319))
    for _ in range(16):
        x = -0.66 + rng.random() * 0.44
        z = 0.07 + rng.random() * 0.28
        y = 0.04 + rng.random() * 0.13
        ang = rng.random() * math.tau
        length = 0.07 + rng.random() * 0.16
        oriented_box(iron, (x - math.cos(ang) * length * 0.5, y, z - math.sin(ang) * length * 0.5),
                     (x + math.cos(ang) * length * 0.5, y, z + math.sin(ang) * length * 0.5),
                     0.011 + rng.random() * 0.02, 0.006, rust)
    coil_r = 0.13
    for k in range(26):
        a0, a1 = math.tau * k / 26, math.tau * (k + 1) / 26
        y = 0.012 + (k % 3) * 0.013
        oriented_box(iron, (0.16 + math.cos(a0) * coil_r, y, 0.36 + math.sin(a0) * coil_r),
                     (0.16 + math.cos(a1) * coil_r, y, 0.36 + math.sin(a1) * coil_r), 0.007, 0.007, rust)
    # Scale, filings and swept charcoal trodden into the earth under the bench.
    tube(kit.acc(ASH), (0.0, 0.0, 0.08), (0.0, 0.014, 0.08), 1.25, 1.2, 22,
         lambda p: scale_color((0.28, 0.26, 0.24), 0.8 + 0.3 * fbm(p[0] * 6, 0, p[2] * 6, 321)),
         jitter=0.2, seed=17, caps=True)


def build_forge_bay_dressing(kit: Kit) -> None:
    # The south-west corner of the forge bay had nothing between the divider
    # doorway and the finished-goods shelf. Long stock cannot be racked flat in
    # a room this size, so it leans in the corner as it does in the Mendel and
    # Hausbuch smithy plates; the swept ash and shovel sit where the floor is
    # raked out to the yard.
    oak = kit.acc(OAK)
    iron = kit.acc(IRON)
    # Everything here stays north of z 10.5. The 3.75 m south wall head hides the
    # far floor rows at the shipped dimetric camera pitch, so dressing placed
    # flush to that wall would only ever be seen in close-camera mode.
    rng = random.Random(331)
    for k in range(7):
        z = 8.3 + k * 0.22
        lean = 2.5 + rng.random() * 0.5
        tube(iron, (15.12 + rng.random() * 0.05, 0.01, z), (15.5 + rng.random() * 0.12, lean, z - 0.1),
             0.016 + rng.random() * 0.008, 0.013, 5, iron_color)
    for k in range(3):
        z = 9.9 + k * 0.2
        tube(oak, (15.1, 0.01, z), (15.44, 2.2 + rng.random() * 0.3, z - 0.06), 0.035, 0.028, 6, oak_forge)
    # Ash and clinker raked into a low heap with a wooden shovel stood in it.
    tube(kit.acc(ASH), (16.7, 0.0, 10.2), (16.7, 0.12, 10.2), 0.42, 0.22, 16,
         lambda p: scale_color((0.3, 0.28, 0.26), 0.75 + 0.35 * fbm(p[0] * 7, p[1] * 7, p[2] * 7, 333)),
         jitter=0.2, seed=19)
    oriented_box(oak, (16.62, 0.05, 10.25), (16.4, 1.34, 10.61), 0.028, 0.028, oak_forge)
    oriented_box(oak, (16.7, 0.03, 10.11), (16.56, 0.05, 10.37), 0.11, 0.012, oak_forge)
    # Standing water and quench oil by the east wall: urban fire law required a
    # filled vessel in any house with a hearth. Wheel-thrown greyware with a
    # bellied body and a thrown rim, not a smooth cone - a straight taper read
    # as a painted marker at gameplay distance.
    def crock(cx, cz, scale, seed):
        earthen = lambda p: scale_color((0.5, 0.41, 0.35), 0.82 + 0.3 * fbm(p[0] * 9, p[1] * 9, p[2] * 9, seed))
        profile = ((0.0, 0.52), (0.14, 0.78), (0.34, 1.0), (0.58, 0.92), (0.74, 0.7), (0.8, 0.66))
        for (y0, r0), (y1, r1) in zip(profile, profile[1:]):
            tube(kit.acc(CLAY), (cx, y0 * scale, cz), (cx, y1 * scale, cz),
                 r0 * scale * 0.42, r1 * scale * 0.42, 14, earthen, caps=False, jitter=0.02, seed=seed)
        # Thrown rim rolled out over the neck.
        tube(kit.acc(CLAY), (cx, 0.78 * scale, cz), (cx, 0.84 * scale, cz),
             0.31 * scale, 0.28 * scale, 14, earthen, caps=False)
        return 0.8 * scale, 0.26 * scale

    top, rim = crock(23.45, 9.15, 0.62, 337)
    # Oiled linen tied over the oil pot keeps grit out.
    tube(kit.acc(STRAW), (23.45, top - 0.02, 9.15), (23.45, top + 0.015, 9.15), rim * 1.12, rim * 1.06, 14,
         flat((0.72, 0.66, 0.54)))
    top, rim = crock(23.92, 9.68, 0.78, 339)
    tube(kit.acc(WATER), (23.92, top - 0.07, 9.68), (23.92, top - 0.05, 9.68), rim * 0.96, rim * 0.96, 14,
         flat((1.0, 1.0, 1.0)))


def _flat_shoe(kit: Kit, center, radius: float) -> None:
    iron = kit.acc(IRON)
    c = Vector(center)
    points = [c + Vector((math.cos(math.radians(a)) * radius, 0.0, math.sin(math.radians(a)) * radius))
              for a in range(-200, 21, 27)]
    for a, b in zip(points, points[1:]):
        oriented_box(iron, tuple(a), tuple(b), 0.022, 0.009, iron_color)


# --- export ---------------------------------------------------------------------------

MATERIAL_PREVIEW = {
    LIMESTONE: (0.62, 0.6, 0.55), LIMEWASH: (0.85, 0.82, 0.76), OAK: (0.36, 0.25, 0.16),
    BOARDS: (0.45, 0.33, 0.22), EARTH: (0.35, 0.3, 0.25), SLAB: (0.6, 0.58, 0.54),
    CLAY: (0.55, 0.45, 0.36), IRON: (0.2, 0.2, 0.21), IRON_BRIGHT: (0.5, 0.5, 0.52),
    LEATHER: (0.3, 0.19, 0.11), CHARCOAL: (0.05, 0.05, 0.05), ASH: (0.35, 0.34, 0.33),
    STRAW: (0.62, 0.52, 0.3), WATER: (0.03, 0.035, 0.035), LOFT: (0.02, 0.02, 0.02),
}


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _material(name: str) -> bpy.types.Material:
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        color = MATERIAL_PREVIEW.get(name, (0.5, 0.5, 0.5))
        principled.inputs["Base Color"].default_value = (*color, 1.0)
        principled.inputs["Roughness"].default_value = 0.85
        material.diffuse_color = (*color, 1.0)
    return material


def _object_from_acc(kit: Kit, acc: Acc) -> bpy.types.Object:
    name = f"{kit.name}_{acc.material.removeprefix('ksi_')}"
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_blender(v) for v in acc.verts], [], acc.faces)
    mesh.validate(clean_customdata=False)
    colors = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    flat_colors = []
    for rgb in acc.colors:
        flat_colors.extend((rgb[0], rgb[1], rgb[2], 1.0))
    colors.data.foreach_set("color", flat_colors)
    # The exporter only writes COLOR_0 from the active + render colour layer.
    mesh.color_attributes.active_color = colors
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
    # Grain-aligned UVs in metres: V follows each face's longest edge, so wood
    # plates (grain along V) run along beams, boards and handles. Masonry and
    # earth ignore UVs; Godot projects them triplanar in world space.
    uv = mesh.uv_layers.new(name="UVMap")
    uvs = []
    for poly in mesh.polygons:
        corners = [mesh.vertices[mesh.loops[i].vertex_index].co for i in poly.loop_indices]
        grain = max(((corners[(k + 1) % len(corners)] - corners[k]) for k in range(len(corners))),
                    key=lambda edge: edge.length)
        grain = grain.normalized() if grain.length > 1e-9 else Vector((0.0, 0.0, 1.0))
        across = poly.normal.cross(grain)
        across = across.normalized() if across.length > 1e-9 else Vector((1.0, 0.0, 0.0))
        for co in corners:
            uvs.extend((co.dot(across), co.dot(grain)))
    uv.data.foreach_set("uv", uvs)
    mesh.polygons.foreach_set("use_smooth", acc.smooth)
    mesh.materials.append(_material(acc.material))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# Props sit on the rrmap floor plane; the shell and loft may reach below it
# (floorboard undersides) or above the walls (flue), so only props are checked.
GROUNDED_KITS = {"kalev_smithy_hearth", "kalev_smithy_anvil", "kalev_smithy_bellows",
                 "kalev_smithy_slack_tub", "kalev_smithy_stock_rack", "kalev_smithy_scrap_heap"}


def check_kit(kit: Kit) -> None:
    lowest = min(v[1] for acc in kit.accs.values() for v in acc.verts)
    if kit.name in GROUNDED_KITS and lowest < -0.001:
        raise SystemExit(f"{kit.name}: geometry sinks {lowest:.4f} below the prop ground plane")


def export_kit(kit: Kit) -> dict:
    check_kit(kit)
    _reset_scene()
    objects = [_object_from_acc(kit, acc) for acc in kit.accs.values() if acc.faces]
    for name, position, scale, rot_y in kit.markers:
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "CUBE"
        empty.empty_display_size = 0.5
        empty.location = to_blender(position)
        empty.rotation_euler = (0.0, 0.0, rot_y)
        empty.scale = (scale[0], scale[2], scale[1])
        bpy.context.scene.collection.objects.link(empty)
        objects.append(empty)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    output = KIT_DIRS.get(kit.name, FORGE_DIR) / kit.name / f"{kit.name}.glb"
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_image_format="NONE",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=False,
    )
    return {
        "path": f"res://{output.relative_to(ROOT).as_posix()}",
        "triangles": kit.triangles(),
        "materials": sorted(acc.material for acc in kit.accs.values() if acc.faces),
        "markers": [name for name, *_ in kit.markers],
    }


def build_all() -> list[Kit]:
    shell = Kit("kalev_smithy_shell")
    build_walls(shell)
    build_floors(shell)
    build_tool_wall(shell)
    build_finished_goods_shelf(shell)
    build_forge_bay_dressing(shell)
    build_living_dressing(shell)
    ceiling = Kit("kalev_smithy_ceiling")
    build_ceiling(ceiling)
    hearth = Kit("kalev_smithy_hearth", HEARTH_CENTER)
    build_hearth(hearth)
    anvil = Kit("kalev_smithy_anvil", ANVIL_CENTER)
    build_anvil(anvil)
    bellows = Kit("kalev_smithy_bellows", BELLOWS_CENTER)
    build_bellows(bellows)
    tub = Kit("kalev_smithy_slack_tub", TUB_CENTER)
    build_slack_tub(tub)
    rack = Kit("kalev_smithy_stock_rack", RACK_CENTER)
    build_stock_rack(rack)
    scrap = Kit("kalev_smithy_scrap_heap", SCRAP_CENTER)
    build_scrap_heap(scrap)
    bench = Kit("kalev_smithy_finishing_bench", BENCH_CENTER)
    build_finishing_bench(bench)
    return [shell, ceiling, hearth, anvil, bellows, tub, rack, scrap, bench]


def main() -> None:
    kits = build_all()
    manifest = {
        "generator": GENERATOR_VERSION,
        "source": "tools/assets/generate_kalev_smithy_interior.py",
        "dossier": "history/dossiers/architecture/smithy-workshop-layout.md",
        "wall_height": WALL_HEIGHT,
        "fire_pot_local": list(FIRE_POT_LOCAL),
        "kits": {},
    }
    for kit in kits:
        manifest["kits"][kit.name] = export_kit(kit)
        print(f"exported {kit.name}: {kit.triangles()} triangles")
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    (EVIDENCE_DIR / "report.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
