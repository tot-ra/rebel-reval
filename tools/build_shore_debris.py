#!/usr/bin/env python3
"""Build the CO-02 shore debris prop family with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/build_shore_debris.py
    blender --background --factory-startup --python tools/build_shore_debris.py -- --only=shore_pebble_patch_a

Writes geometry-only GLBs plus shared seamless PBR plates under
assets/props/environment/shore/. The GLBs carry named material slots
(``shore_granite``, ``shore_barnacle``, ``shore_limestone``, ``shore_shingle``,
``shore_wrack``, ``shore_algae``) but no images: the runtime resolves each slot
through ``MapViewMaterials.shore_debris()`` so every boulder, cluster and wrack
strand on a coast shares one material per surface family instead of one
extracted texture copy per GLB.

Everything is deterministic: meshes are displaced with seeded value noise
written here (not Blender's global noise state), textures come from seeded
numpy generators, and outputs are written in a fixed order.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "props" / "environment" / "shore"
GENERATOR_VERSION = "shore_debris_v1"
BLENDER_VERSION = "Blender 5.2 LTS"
TEXTURE_SIZE = 512
BASE_SEED = 0xC002

# Metres of surface covered by one texture repeat on box-projected rock UVs.
ROCK_UV_METRES = 0.9

# name -> (kind, parameters). Sizes are metres across (the CO-02 contract).
PARTS: list[tuple[str, str, dict]] = [
    ("shore_boulder_granite_small", "boulder", {"size": 0.6, "subdiv": 3, "seed": 11}),
    ("shore_boulder_granite_medium", "boulder", {"size": 1.2, "subdiv": 4, "seed": 23}),
    ("shore_boulder_granite_large", "boulder", {"size": 2.1, "subdiv": 4, "seed": 37}),
    (
        "shore_boulder_granite_barnacled",
        "boulder",
        # Taller, upright stone: it stands in deeper water with its crusted
        # foot (lower 55%) reaching up to the Baltic's near-tideless waterline.
        {"size": 1.6, "subdiv": 4, "seed": 41, "barnacle_band": 0.55, "squash": 0.82},
    ),
    ("shore_stone_cluster_a", "cluster", {"count": 7, "seed": 53, "limestone_share": 0.0}),
    ("shore_stone_cluster_b", "cluster", {"count": 9, "seed": 67, "limestone_share": 0.45}),
    ("shore_pebble_patch_a", "pebble_patch", {"radius": 0.75, "seed": 71}),
    ("shore_pebble_patch_b", "pebble_patch", {"radius": 0.85, "seed": 83, "elongation": 1.6, "spacing": 0.11}),
    ("shore_wrack_line_a", "wrack", {"length": 1.8, "seed": 97, "curve": 0.18}),
    ("shore_wrack_line_b", "wrack", {"length": 2.4, "seed": 101, "curve": -0.32}),
    ("shore_algae_skirt", "algae_skirt", {"radius": 0.5, "seed": 113}),
]

TEXTURES = ["shore_granite", "shore_barnacle", "shore_wrack", "shore_algae", "shore_limestone"]


# --- deterministic value noise ------------------------------------------------


def _hash3(ix: int, iy: int, iz: int, seed: int) -> float:
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 144269504) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFF) / float(0xFFFFFF)


def _smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def _value_noise3(p: Vector, seed: int) -> float:
    ix, iy, iz = math.floor(p.x), math.floor(p.y), math.floor(p.z)
    fx, fy, fz = _smooth(p.x - ix), _smooth(p.y - iy), _smooth(p.z - iz)
    total = 0.0
    for dz in (0, 1):
        for dy in (0, 1):
            for dx in (0, 1):
                w = (fx if dx else 1.0 - fx) * (fy if dy else 1.0 - fy) * (fz if dz else 1.0 - fz)
                total += w * _hash3(ix + dx, iy + dy, iz + dz, seed)
    return total * 2.0 - 1.0


def _fbm3(p: Vector, seed: int, octaves: int = 4) -> float:
    amplitude, frequency, total, norm = 1.0, 1.0, 0.0, 0.0
    for octave in range(octaves):
        total += amplitude * _value_noise3(p * frequency, seed + octave * 31)
        norm += amplitude
        amplitude *= 0.5
        frequency *= 2.03
    return total / norm


# --- scene helpers --------------------------------------------------------------


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.images):
        for item in list(block):
            block.remove(item)


def _material(name: str) -> bpy.types.Material:
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
    return material


def _box_uv(bm: bmesh.types.BMesh, metres_per_repeat: float) -> None:
    """Per-face dominant-axis projection; rock plates are isotropic noise, so the
    few projection seams stay invisible while the top face never pinches."""
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop in face.loops:
            co = loop.vert.co
            if axis == 0:
                u, v = co.y, co.z
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            loop[uv_layer].uv = (u / metres_per_repeat, v / metres_per_repeat)


def _set_alpha(bm: bmesh.types.BMesh, alpha_of) -> None:
    """Per-corner colour with alpha fading the rim, so flat dressing (shingle,
    wrack, weed) dissolves into the ground instead of ending on a cut edge."""
    layer = bm.loops.layers.float_color.new("Col")
    for face in bm.faces:
        for loop in face.loops:
            loop[layer] = (1.0, 1.0, 1.0, max(0.0, min(1.0, alpha_of(loop.vert.co))))


def _finish_object(name: str, bm: bmesh.types.BMesh, materials: list[str]) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    # The rim-fade layer must be the active colour or the exporter writes a
    # white COLOR_0 and demotes it to COLOR_1, which Godot never reads.
    if "Col" in mesh.color_attributes:
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
    for material_name in materials:
        mesh.materials.append(_material(material_name))
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _rock_bmesh(size: float, subdiv: int, seed: int, squash: float = 0.62) -> bmesh.types.BMesh:
    """Glacially rounded erratic: an icosphere pushed by low-frequency noise, flattened
    underneath and sheared so it leans like a stone that settled in the till."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    stretch = Vector(
        (
            1.0 + 0.22 * _hash3(seed, 1, 0, 7),
            1.0 - 0.18 * _hash3(seed, 2, 0, 7),
            squash + 0.12 * _hash3(seed, 3, 0, 7),
        )
    )
    offset = Vector((seed * 1.37, seed * 0.61, seed * 2.03))
    planes = []
    for index in range(3):
        azimuth = math.tau * _hash3(seed, index, 11, 7)
        elevation = (_hash3(seed, index, 12, 7) - 0.3) * 1.1
        normal = Vector(
            (math.cos(azimuth) * math.cos(elevation), math.sin(azimuth) * math.cos(elevation), math.sin(elevation))
        )
        planes.append((normal, 0.34 + 0.08 * _hash3(seed, index, 13, 7)))
    for vert in bm.verts:
        direction = vert.co.normalized()
        broad = _fbm3(direction * 1.6 + offset, seed, 3)
        chip = _fbm3(direction * 4.2 + offset, seed + 5, 2)
        radius = 0.5 * (1.0 + 0.24 * broad + 0.11 * chip)
        co = direction * radius
        co = Vector((co.x * stretch.x, co.y * stretch.y, co.z * stretch.z))
        # Glacial erratics keep a few flat fracture faces under the rounding;
        # without them every stone reads as the same smooth blob.
        for plane in planes:
            excess = co.dot(plane[0]) - plane[1]
            if excess > 0.0:
                co -= plane[0] * excess * 0.82
        # Flatten the buried underside so the stone sits instead of balancing.
        floor_z = -0.5 * stretch.z * 0.55
        if co.z < floor_z:
            co.z = floor_z + (co.z - floor_z) * 0.18
        vert.co = co * size
    # Rest the lowest point on z = 0 so scatter lifts are simple sink fractions.
    lowest = min(v.co.z for v in bm.verts)
    for vert in bm.verts:
        vert.co.z -= lowest
    return bm


def _build_boulder(name: str, params: dict) -> bpy.types.Object:
    bm = _rock_bmesh(params["size"], params["subdiv"], params["seed"], params.get("squash", 0.62))
    bm.normal_update()
    _box_uv(bm, ROCK_UV_METRES)
    materials = ["shore_granite"]
    band = params.get("barnacle_band")
    if band is not None:
        # Faces below the band sit in the tide swash: barnacles and green algae.
        materials.append("shore_barnacle")
        top = max(v.co.z for v in bm.verts)
        for face in bm.faces:
            centre = face.calc_center_median()
            wobble = 0.06 * _fbm3(centre * 3.0, params["seed"] + 9, 2) * top
            face.material_index = 1 if centre.z < band * top + wobble else 0
    return _finish_object(name, bm, materials)


def _build_cluster(name: str, params: dict) -> bpy.types.Object:
    bm = bmesh.new()
    seed = params["seed"]
    count = params["count"]
    limestone_share = params["limestone_share"]
    uv_layer = bm.loops.layers.uv.verify()
    for index in range(count):
        # Fist- to head-size stones (0.09-0.28 m) in a loose storm-thrown group.
        size = 0.09 + 0.19 * _hash3(seed, index, 1, 3)
        angle = math.tau * _hash3(seed, index, 2, 3)
        reach = 0.42 * math.sqrt(_hash3(seed, index, 3, 3))
        stone = _rock_bmesh(size, 2, seed * 7 + index, squash=0.55)
        yaw = math.tau * _hash3(seed, index, 4, 3)
        cos_y, sin_y = math.cos(yaw), math.sin(yaw)
        centre = Vector((math.cos(angle) * reach, math.sin(angle) * reach, -0.18 * size))
        limestone = _hash3(seed, index, 5, 3) < limestone_share
        stone_map = {}
        for vert in stone.verts:
            co = vert.co
            rotated = Vector((co.x * cos_y - co.y * sin_y, co.x * sin_y + co.y * cos_y, co.z))
            stone_map[vert] = bm.verts.new(rotated + centre)
        for face in stone.faces:
            new_face = bm.faces.new([stone_map[v] for v in face.verts])
            new_face.material_index = 1 if limestone else 0
        stone.free()
    bm.normal_update()
    _box_uv(bm, ROCK_UV_METRES * 0.5)
    del uv_layer
    lowest = min(v.co.z for v in bm.verts)
    for vert in bm.verts:
        vert.co.z -= lowest
    return _finish_object(name, bm, ["shore_granite", "shore_limestone"])


def _build_pebble_patch(name: str, params: dict) -> bpy.types.Object:
    """A storm-thrown bed of loose beach pebbles (R-1606). It used to be a flat
    disc carrying the shore_shingle plate behind a vertex-alpha rim, which read as
    a sticker with no depth and a different pebble scale from the ground. Now
    every pebble is its own small rounded stone, half bedded in the sand, so the
    patch has real silhouettes and contact shadow. Density and size fall off
    towards a ragged rim, so the bed thins into scattered stones instead of
    ending on an edge. Pebbles are granite and (mostly, on the Estonian north
    coast) limestone; z = 0 is the ground, buried parts sit below it."""
    seed = params["seed"]
    radius = params["radius"]
    elongation = params.get("elongation", 1.0)
    spacing = params.get("spacing", 0.1)
    limestone_share = params.get("limestone_share", 0.5)
    bm = bmesh.new()
    reach_x = radius * elongation * 1.25
    reach_y = radius * 1.25
    columns = int(math.ceil(2.0 * reach_x / spacing))
    rows = int(math.ceil(2.0 * reach_y / spacing))
    index = 0
    for row in range(rows):
        for column in range(columns):
            # Jittered grid: no two pebbles stack, no visible rows.
            x = -reach_x + (column + 0.15 + 0.7 * _hash3(column, row, 1, seed)) * spacing
            y = -reach_y + (row + 0.15 + 0.7 * _hash3(column, row, 2, seed)) * spacing
            reach = math.hypot(x / elongation, y) / radius
            ragged = 0.25 * _fbm3(Vector((x * 2.5, y * 2.5, seed)), seed + 7, 2)
            density = 1.0 - _smooth(max(0.0, min(1.0, (reach + ragged - 0.25) / 0.85)))
            if _hash3(column, row, 3, seed) >= 0.9 * density:
                continue
            # Big stones gather in the middle of the bed, small ones at its rim.
            roll = _hash3(column, row, 4, seed)
            size = 0.028 + 0.05 * roll * (0.45 + 0.55 * density)
            if roll > 0.94 and density > 0.6:
                size = 0.09 + 0.05 * _hash3(column, row, 5, seed)
            # bmesh subdivisions=1 is the bare 20-face icosahedron, which reads as a
            # crystal close up; 2 (80 faces) is round enough. Only stones under
            # 3.5 cm, sub-pixel at gameplay range, keep 20 faces.
            stone = _rock_bmesh(size, 1 if size < 0.035 else 2, seed * 131 + index, squash=0.42)
            index += 1
            height = max(v.co.z for v in stone.verts)
            # Bedded 30-55% deep: pebbles sit in the sand, they do not balance on it.
            sink = height * (0.3 + 0.25 * _hash3(column, row, 6, seed))
            yaw = math.tau * _hash3(column, row, 7, seed)
            tilt = (_hash3(column, row, 8, seed) - 0.5) * 0.5
            cos_y, sin_y = math.cos(yaw), math.sin(yaw)
            cos_t, sin_t = math.cos(tilt), math.sin(tilt)
            limestone = _hash3(column, row, 9, seed) < limestone_share
            stone_map = {}
            for vert in stone.verts:
                co = vert.co
                # Tilt about X, then yaw about Z.
                ty = co.y * cos_t - co.z * sin_t
                tz = co.y * sin_t + co.z * cos_t
                rotated = Vector((co.x * cos_y - ty * sin_y, co.x * sin_y + ty * cos_y, tz))
                stone_map[vert] = bm.verts.new(rotated + Vector((x, y, -sink)))
            for face in stone.faces:
                new_face = bm.faces.new([stone_map[v] for v in face.verts])
                new_face.material_index = 1 if limestone else 0
            stone.free()
    bm.normal_update()
    _box_uv(bm, ROCK_UV_METRES * 0.25)
    return _finish_object(name, bm, ["shore_granite", "shore_limestone"])


def _build_wrack(name: str, params: dict) -> bpy.types.Object:
    """Drift line of bladderwrack and broken reed: a ragged, lumpy ribbon lying
    along the shore on its local X axis, thicker in the middle of the heap."""
    seed = params["seed"]
    length = params["length"]
    curve = params["curve"]
    columns, rows = 24, 4
    bm = bmesh.new()
    grid = []
    for column in range(columns + 1):
        s = column / columns
        x = (s - 0.5) * length
        bend = curve * (4.0 * s * (1.0 - s)) * length * 0.35
        width = 0.34 * (0.55 + 0.45 * math.sin(math.pi * s)) * (
            1.0 + 0.35 * _fbm3(Vector((s * 5.0, seed, 0.0)), seed, 2)
        )
        row_verts = []
        for row in range(rows + 1):
            t = row / rows - 0.5
            y = bend + t * width
            heap = 0.07 * (1.0 - 4.0 * t * t) * (0.6 + 0.4 * math.sin(math.pi * s))
            lump = 0.025 * _fbm3(Vector((x * 5.0, y * 5.0, seed)), seed + 1, 3)
            z = max(0.004, heap + lump * (1.0 - 2.0 * abs(t)))
            row_verts.append(bm.verts.new((x, y, z)))
        grid.append(row_verts)
    for column in range(columns):
        for row in range(rows):
            bm.faces.new(
                (grid[column][row], grid[column + 1][row], grid[column + 1][row + 1], grid[column][row + 1])
            )
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            loop[uv_layer].uv = (loop.vert.co.x / 0.8, loop.vert.co.y / 0.8)

    def wrack_alpha(co: Vector) -> float:
        s_along = co.x / length + 0.5
        bend = curve * (4.0 * s_along * (1.0 - s_along)) * length * 0.35
        across = abs(co.y - bend) / 0.2
        ends = min(s_along, 1.0 - s_along) / 0.12
        ragged = 0.35 * _fbm3(Vector((co.x * 4.0, co.y * 4.0, seed)), seed + 5, 2)
        return min(1.0 - _smooth(max(0.0, min(1.0, across - 0.35 + ragged))), max(0.0, min(1.0, ends + ragged)))

    _set_alpha(bm, wrack_alpha)
    return _finish_object(name, bm, ["shore_wrack"])


def _build_algae_skirt(name: str, params: dict) -> bpy.types.Object:
    """Low, broken apron of weed clumps round a boulder foot or crib post: lip
    radius 0.5 m, foot 0.85 m, so the scatter scales it to the stone it dresses.
    Vertex alpha opens gaps between clumps and rags the lip; the runtime cuts it."""
    seed = params["seed"]
    radius = params["radius"]
    segments, rows = 48, 5
    bm = bmesh.new()
    ring_verts = []
    for row in range(rows + 1):
        t = row / rows
        current = []
        for segment in range(segments):
            angle = math.tau * segment / segments
            ragged = 0.5 + 0.5 * _fbm3(Vector((math.cos(angle) * 2.0, math.sin(angle) * 2.0, seed)), seed, 2)
            r = radius * (1.7 - 0.7 * t)
            z = math.sin(t * math.pi * 0.5) * (0.08 + 0.12 * ragged)
            current.append(bm.verts.new((math.cos(angle) * r, math.sin(angle) * r, z)))
        ring_verts.append(current)
    for row in range(rows):
        for segment in range(segments):
            nxt = (segment + 1) % segments
            bm.faces.new(
                (ring_verts[row][segment], ring_verts[row][nxt], ring_verts[row + 1][nxt], ring_verts[row + 1][segment])
            )
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv_layer].uv = ((math.atan2(co.y, co.x) / math.tau + 0.5) * 4.0, math.hypot(co.x, co.y) / 0.5)

    def clump_alpha(co: Vector) -> float:
        angle = math.atan2(co.y, co.x)
        clumps = 0.5 + 0.5 * _fbm3(Vector((math.cos(angle) * 3.5, math.sin(angle) * 3.5, seed + 1)), seed + 3, 2)
        reach = (math.hypot(co.x, co.y) / radius - 1.0) / 0.7
        return clumps * 1.6 - 0.35 - 0.5 * reach

    _set_alpha(bm, clump_alpha)
    return _finish_object(name, bm, ["shore_algae"])


BUILDERS = {
    "boulder": _build_boulder,
    "cluster": _build_cluster,
    "pebble_patch": _build_pebble_patch,
    "wrack": _build_wrack,
    "algae_skirt": _build_algae_skirt,
}


# --- seamless PBR plates --------------------------------------------------------


def _periodic_noise(rng: np.random.Generator, size: int, frequency: float) -> np.ndarray:
    """Band-limited periodic noise via an FFT filter, so every plate tiles exactly."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * size
    fx = np.fft.fftfreq(size)[None, :] * size
    radius = np.sqrt(fx * fx + fy * fy)
    band = np.exp(-((radius - frequency) ** 2) / (2.0 * (frequency * 0.45 + 0.5) ** 2))
    band[0, 0] = 0.0
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * band))
    field -= field.min()
    peak = field.max()
    return field / peak if peak > 0 else field


def _fractal(rng: np.random.Generator, size: int, base: float, octaves: int) -> np.ndarray:
    total = np.zeros((size, size))
    amplitude, norm, frequency = 1.0, 0.0, base
    for _ in range(octaves):
        total += amplitude * _periodic_noise(rng, size, frequency)
        norm += amplitude
        amplitude *= 0.55
        frequency *= 2.1
    return total / norm


def _normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    # OpenGL convention (green up), which Godot expects.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    return np.stack([(-dx / length) * 0.5 + 0.5, (dy / length) * 0.5 + 0.5, nz / length * 0.5 + 0.5], -1)


def _mix(a, b, t):
    t = t[..., None]
    return np.asarray(a)[None, None, :] * (1.0 - t) + np.asarray(b)[None, None, :] * t


def _granite(rng: np.random.Generator, size: int):
    # Baltic erratics: grey and pink rapakivi granite, dark biotite flecks,
    # faint lichen and a weathered, sea-rounded rind.
    grain = _periodic_noise(rng, size, 90.0)
    grain2 = _periodic_noise(rng, size, 55.0)
    broad = _fractal(rng, size, 3.0, 3)
    feldspar = np.clip((grain2 - 0.52) * 5.0, 0.0, 1.0)
    mica = np.clip((grain - 0.78) * 9.0, 0.0, 1.0)
    # Linear values: ~0.2 grey and ~0.26 pink feldspar land near sRGB 0.5, a
    # weathered erratic rather than polished paving.
    albedo = _mix((0.19, 0.185, 0.175), (0.27, 0.19, 0.16), feldspar * (0.55 + 0.45 * broad))
    albedo = albedo * (1.0 - mica[..., None] * 0.78)
    lichen = np.clip((broad - 0.62) * 4.0, 0.0, 1.0) * 0.35
    albedo = albedo * (1.0 - lichen[..., None]) + np.array([0.30, 0.31, 0.22]) * lichen[..., None]
    albedo *= (0.9 + 0.2 * broad)[..., None]
    height = broad * 0.5 + grain * 0.35 + grain2 * 0.15
    roughness = np.clip(0.78 + 0.12 * broad - 0.22 * mica, 0.0, 1.0)
    return albedo, _normal_from_height(height, 6.0), roughness


def _barnacle(rng: np.random.Generator, size: int):
    # Swash zone: dark wet stone, pale barnacle crust and green filamentous algae.
    base_albedo, _, _ = _granite(rng, size)
    crust = _periodic_noise(rng, size, 70.0)
    crust2 = _periodic_noise(rng, size, 140.0)
    algae = _fractal(rng, size, 5.0, 3)
    barnacles = np.clip((crust - 0.66) * 7.0, 0.0, 1.0) * np.clip((crust2 - 0.3) * 3.0, 0.0, 1.0)
    weed = np.clip((algae - 0.45) * 3.0, 0.0, 1.0)
    albedo = base_albedo * 0.55
    albedo = albedo * (1.0 - weed[..., None]) + np.array([0.20, 0.30, 0.12]) * weed[..., None]
    albedo = albedo * (1.0 - barnacles[..., None]) + np.array([0.74, 0.72, 0.64]) * barnacles[..., None]
    height = barnacles * 0.8 + algae * 0.25 + crust2 * 0.1
    roughness = np.clip(0.42 + 0.35 * barnacles + 0.08 * weed, 0.0, 1.0)
    return albedo, _normal_from_height(height, 4.5), roughness


def _wrack(rng: np.random.Generator, size: int):
    # Bladderwrack drift (olive-brown fronds, darker air bladders) with straw reed.
    fronds = _fractal(rng, size, 12.0, 3)
    bladders = _periodic_noise(rng, size, 80.0)
    reed_noise = _periodic_noise(rng, size, 24.0)
    y = np.linspace(0.0, math.tau * 9.0, size, endpoint=False)[:, None]
    streak = (np.sin(y + reed_noise * 7.0) * 0.5 + 0.5) ** 8
    reed = np.clip(streak * np.clip((reed_noise - 0.45) * 4.0, 0.0, 1.0), 0.0, 1.0)
    albedo = _mix((0.16, 0.13, 0.07), (0.36, 0.30, 0.13), fronds)
    dots = np.clip((bladders - 0.74) * 8.0, 0.0, 1.0)
    albedo = albedo * (1.0 - dots[..., None] * 0.55)
    albedo = albedo * (1.0 - reed[..., None]) + np.array([0.66, 0.58, 0.40]) * reed[..., None]
    height = fronds * 0.6 + dots * 0.3 + reed * 0.4
    roughness = np.clip(0.38 + 0.25 * fronds + 0.35 * reed, 0.0, 1.0)
    return albedo, _normal_from_height(height, 3.0), roughness


def _algae(rng: np.random.Generator, size: int):
    # Submerged green and brown weed hanging from stone; wet and fairly glossy.
    strands_noise = _periodic_noise(rng, size, 30.0)
    x = np.linspace(0.0, math.tau * 14.0, size, endpoint=False)[None, :]
    strands = (np.sin(x + strands_noise * 9.0) * 0.5 + 0.5) ** 3
    tone = _fractal(rng, size, 4.0, 3)
    albedo = _mix((0.10, 0.17, 0.08), (0.27, 0.34, 0.12), tone)
    albedo = albedo * (0.7 + 0.3 * strands)[..., None]
    height = strands * 0.7 + tone * 0.3
    roughness = np.clip(0.34 + 0.2 * (1.0 - strands), 0.0, 1.0)
    return albedo, _normal_from_height(height, 2.4), roughness


def _limestone(rng: np.random.Generator, size: int):
    # North Estonian Ordovician limestone pebbles: pale grey-beige, fine pitting,
    # faint bedding streaks and darker fossil fragments; sea-worn, so matte.
    tone = _fractal(rng, size, 3.0, 3)
    pits = _periodic_noise(rng, size, 110.0)
    fossils = _periodic_noise(rng, size, 38.0)
    y = np.linspace(0.0, math.tau * 5.0, size, endpoint=False)[:, None]
    bedding = (np.sin(y + tone * 4.0) * 0.5 + 0.5) ** 6
    albedo = _mix((0.36, 0.34, 0.30), (0.46, 0.43, 0.37), tone)
    albedo = albedo * (1.0 - 0.18 * bedding[..., None])
    speck = np.clip((fossils - 0.8) * 7.0, 0.0, 1.0)
    albedo = albedo * (1.0 - speck[..., None] * 0.35)
    pit = np.clip((pits - 0.7) * 5.0, 0.0, 1.0)
    height = tone * 0.5 - pit * 0.35 + bedding * 0.1
    roughness = np.clip(0.86 + 0.1 * pit, 0.0, 1.0)
    return albedo, _normal_from_height(height, 4.0), roughness


PLATES = {
    "shore_limestone": _limestone,
    "shore_granite": _granite,
    "shore_barnacle": _barnacle,
    "shore_wrack": _wrack,
    "shore_algae": _algae,
}


def _linear_to_srgb(values: np.ndarray) -> np.ndarray:
    values = np.clip(values, 0.0, 1.0)
    return np.where(values <= 0.0031308, values * 12.92, 1.055 * np.power(values, 1.0 / 2.4) - 0.055)


def _save_png(path: Path, rgb: np.ndarray) -> None:
    size = rgb.shape[0]
    if rgb.ndim == 2:
        rgb = np.repeat(rgb[..., None], 3, axis=2)
    rgba = np.concatenate([rgb, np.ones((size, size, 1))], axis=2)
    # Blender images are stored bottom-up.
    flat = np.flipud(rgba).astype(np.float32).ravel()
    image = bpy.data.images.new(path.stem, size, size, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(flat)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def _write_textures() -> dict[str, str]:
    digests = {}
    for index, name in enumerate(TEXTURES):
        rng = np.random.default_rng(BASE_SEED + index * 1009)
        albedo, normal, roughness = PLATES[name](rng, TEXTURE_SIZE)
        # Albedo math above is linear; the PNG is sRGB like every other plate.
        for suffix, data in (
            ("albedo", _linear_to_srgb(albedo)),
            ("normal", normal),
            ("roughness", roughness),
        ):
            path = OUTPUT_DIR / f"{name}_{suffix}.png"
            _save_png(path, data)
            digests[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return digests


def _export_part(obj: bpy.types.Object, path: Path) -> None:
    for other in bpy.context.scene.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_image_format="NONE",
        export_extras=False,
    )


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    _reset_scene()
    # `-- --only=name[,name]` rebuilds just those parts and merges them into the
    # existing report, leaving every other GLB and the shared plates untouched.
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    only = next((a[len("--only=") :].split(",") for a in argv if a.startswith("--only=")), [])
    report_path = OUTPUT_DIR / "shore_debris_report.json"
    report = {"generator": GENERATOR_VERSION, "blender": BLENDER_VERSION, "parts": {}, "textures": {}}
    if only and report_path.exists():
        report = json.loads(report_path.read_text())
    for name, kind, params in PARTS:
        if only and name not in only:
            continue
        obj = BUILDERS[kind](name, params)
        triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        dims = obj.dimensions
        path = OUTPUT_DIR / f"{name}.glb"
        _export_part(obj, path)
        report["parts"][name] = {
            "kind": kind,
            "triangles": triangles,
            "dimensions_m": [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
            "materials": [m.name for m in obj.data.materials],
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    if not only:
        report["textures"] = _write_textures()
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
