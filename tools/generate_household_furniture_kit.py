#!/usr/bin/env python3
"""Build the Reval 1343 household furniture kit (benches, stools, beds, firewood) with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_household_furniture_kit.py

The pieces fill the gaps the existing furniture GLBs leave in an ordinary town
house (docs/SYSTEMS/HOUSEHOLDS.md): somewhere to sit at the table for a whole
household, a plain bed for the poor, and the firewood a household carries home
and burns. Every piece is a separate root so the city furnisher instances only
what it needs. Front faces Godot +Z (Blender -Y); origin is the floor centre.

Roots:
    Bench              split-plank bench with four splayed, wedged legs
    Stool              round three-legged stool
    StrawPallet        plank bed box with a lumpy straw tick and a wool blanket
    FirewoodLog        one split birch log (carried or tossed on the fire)
    FirewoodArmful     an armful of split logs, carried home from the woodyard
    FirewoodPileFull   the household's indoor pile by the hearth, full
    FirewoodPileHalf   the same pile half burnt
    FirewoodPileLow    a few logs left
    Basket             wicker basket with a bail handle
    ClayPot            wheel-thrown redware storage pot
"""

from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "furniture" / "household_kit" / "household_furniture_kit.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "household_furniture_kit_v1"
ASSET_ID = "prop.household_furniture_kit"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "household_furniture_kit_v1"
TEXTURE_SIZE = 512

OAK_SRGB = (0x7A, 0x55, 0x36)
SPLIT_SRGB = (0xB8, 0x98, 0x6C)
BARK_SRGB = (0x6E, 0x62, 0x55)
BIRCH_BARK_SRGB = (0xC9, 0xC2, 0xB2)
STRAW_SRGB = (0xC2, 0xA2, 0x5E)
WOOL_SRGB = (0x8E, 0x84, 0x74)  # undyed grey-brown wool
LINEN_SRGB = (0xC4, 0xB8, 0x9E)
WICKER_SRGB = (0x9C, 0x7A, 0x4C)
POTTERY_SRGB = (0x8E, 0x4E, 0x33)


def _lin(c: int) -> float:
    v = c / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _pattern(kind: str, base: tuple[int, int, int]):
    import numpy as np

    n = TEXTURE_SIZE
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u = xx / n
    v = yy / n
    rng = np.random.default_rng(sum(map(ord, kind)) * 7919)
    noise = rng.random((n // 16, n // 16)).astype(np.float32)
    noise = np.kron(noise, np.ones((16, 16), dtype=np.float32))
    noise = (noise + np.roll(noise, 8, 0) + np.roll(noise, 8, 1) + np.roll(np.roll(noise, 8, 0), 8, 1)) / 4.0
    fine = rng.random((n, n)).astype(np.float32)
    if kind == "oak":
        grain = np.sin((v * 40.0 + np.sin(u * 9.0) * 0.6 + noise * 2.0) * math.tau)
        var = 0.80 + grain * 0.06 + noise * 0.12 + fine * 0.04
    elif kind == "split":
        grain = np.sin((v * 55.0 + noise * 3.0) * math.tau)
        var = 0.86 + grain * 0.05 + noise * 0.08 + fine * 0.05
    elif kind == "bark":
        ridges = np.abs(np.sin((u * 18.0 + noise * 2.5) * math.tau))
        var = 0.62 + ridges * 0.32 + fine * 0.1
    elif kind == "birch":
        lent = (np.sin((v * 22.0 + noise * 4.0) * math.tau) > 0.93).astype(np.float32)
        patches = (noise > 0.62).astype(np.float32)
        var = 0.95 - lent * 0.55 - patches * 0.25 + fine * 0.05
    elif kind == "straw":
        stalks = np.sin((u * 90.0 + np.sin(v * 7.0) * 2.0 + noise * 5.0) * math.tau)
        var = 0.78 + stalks * 0.12 + noise * 0.2 + fine * 0.08
    elif kind == "wool":
        weave = np.sin(u * 160.0 * math.tau) * np.sin(v * 160.0 * math.tau)
        check = ((np.sin(u * 5.0 * math.tau) > 0.9) | (np.sin(v * 5.0 * math.tau) > 0.9)).astype(np.float32)
        var = 0.9 + weave * 0.05 + noise * 0.1 - check * 0.22 + fine * 0.04
    elif kind == "linen":
        weave = np.sin(u * 200.0 * math.tau) * np.sin(v * 200.0 * math.tau)
        var = 0.9 + weave * 0.04 + noise * 0.08
    elif kind == "wicker":
        over = np.sign(np.sin(u * 24.0 * math.tau)) * np.sign(np.sin(v * 16.0 * math.tau))
        rods = np.abs(np.sin(v * 32.0 * math.tau))
        var = 0.72 + over * 0.08 + rods * 0.18 + fine * 0.05
    else:  # pottery
        rings = np.sin((v * 34.0 + noise * 0.4) * math.tau)
        var = 0.84 + rings * 0.03 + noise * 0.12 + fine * 0.03
    base_lin = np.array([_lin(c) for c in base], dtype=np.float32)
    rgb = np.clip(base_lin[None, None, :] * var[:, :, None], 0.0, 1.0)
    return np.concatenate((rgb, np.ones((n, n, 1), dtype=np.float32)), axis=2)


def _material(name: str, kind: str, base: tuple[int, int, int], roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    image = bpy.data.images.new(f"{name}_albedo", width=TEXTURE_SIZE, height=TEXTURE_SIZE, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(_pattern(kind, base).ravel())
    image.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# --- geometry helpers ------------------------------------------------------------


def _finish(obj, mat, bevel: float = 0.0):
    obj.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Soft", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40.0))
    return obj


def box(parts, name, center, size, mat, rot=(0.0, 0.0, 0.0), bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    parts.append(_finish(obj, mat, bevel))
    return obj


def rod(parts, name, p0, p1, r0, r1, mat, segments=10):
    """Tapered round rod from p0 (radius r0) to p1 (radius r1)."""
    a, b = Vector(p0), Vector(p1)
    axis = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=segments, radius1=r0, radius2=r1, depth=axis.length, location=(a + b) * 0.5
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = axis.normalized().to_track_quat("Z", "Y")
    parts.append(_finish(obj, mat))
    return obj


def lathe(parts, name, profile, mat, segments=20, center=(0.0, 0.0, 0.0), jitter=0.0, seed=0):
    """Surface of revolution from a (radius, z) profile, bottom to top, with cylindrical UVs."""
    rnd = random.Random(seed)
    mesh = bpy.data.meshes.new(name)
    verts, faces, uvs = [], [], []
    rows = len(profile)
    for i, (r, z) in enumerate(profile):
        for s in range(segments + 1):
            ang = s / segments * math.tau
            rr = r * (1.0 + (rnd.uniform(-jitter, jitter) if s < segments else 0.0))
            verts.append((center[0] + math.cos(ang) * rr, center[1] + math.sin(ang) * rr, center[2] + z))
    for i in range(rows - 1):
        for s in range(segments):
            a = i * (segments + 1) + s
            faces.append((a, a + 1, a + segments + 2, a + segments + 1))
            uvs.append([(s / segments, i / (rows - 1)), ((s + 1) / segments, i / (rows - 1)),
                        ((s + 1) / segments, (i + 1) / (rows - 1)), (s / segments, (i + 1) / (rows - 1))])
    # Seal the seam so the jitter cannot open it.
    for i in range(rows):
        verts[i * (segments + 1) + segments] = verts[i * (segments + 1)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for poly, quad in zip(mesh.polygons, uvs):
        for loop, uv in zip(poly.loop_indices, quad):
            layer.data[loop].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    parts.append(_finish(obj, mat))
    obj.data.validate()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def lumpy(parts, name, center, size, mat, cuts=6, amount=0.02, seed=0, top_only=True):
    """Subdivided box with its top pushed about by noise: straw ticks, folded cloth."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.subdivide(number_cuts=cuts)
    bpy.ops.object.mode_set(mode="OBJECT")
    rnd = random.Random(seed)
    bumps = [(rnd.uniform(-0.5, 0.5) * size[0], rnd.uniform(-0.5, 0.5) * size[1], rnd.uniform(0.4, 1.0))
             for _ in range(7)]
    half_h = size[2] * 0.5
    for v in obj.data.vertices:
        if top_only and v.co.z < half_h - 1e-4:
            # Round the long edges a little so the tick bulges over its box.
            continue
        lift = 0.0
        for bx, by, w in bumps:
            d2 = ((v.co.x - bx) / (size[0] * 0.35)) ** 2 + ((v.co.y - by) / (size[1] * 0.45)) ** 2
            lift += w * math.exp(-d2)
        edge = min(1.0, (0.5 - abs(v.co.x) / size[0]) * 6.0, (0.5 - abs(v.co.y) / size[1]) * 6.0)
        v.co.z += amount * lift * max(edge, 0.0) - amount * 0.6 * (1.0 - max(edge, 0.0))
        v.co.z += rnd.uniform(-amount, amount) * 0.15
    parts.append(_finish(obj, mat))
    return obj


def split_log(parts, name, center, length, radius, yaw, mats, seed, pitch=0.0, roll=0.0):
    """A split log (half or a little less): bark on the outer arc, pale split face, end grain."""
    rnd = random.Random(seed)
    arc = math.radians(rnd.uniform(150.0, 210.0))
    steps = 8
    mesh = bpy.data.meshes.new(name)
    section = [(0.0, 0.0)]
    for s in range(steps + 1):
        a = -arc * 0.5 + arc * s / steps
        r = radius * (1.0 + rnd.uniform(-0.06, 0.06))
        section.append((math.cos(a) * r, math.sin(a) * r))
    # Centre the section on its own centroid so the log lies where it is put.
    cx = sum(p[0] for p in section) / len(section)
    cy = sum(p[1] for p in section) / len(section)
    section = [(p[0] - cx, p[1] - cy) for p in section]
    n = len(section)
    verts = [(-length * 0.5, y, z) for y, z in section] + [(length * 0.5, y, z) for y, z in section]
    faces, mat_index = [], []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
        bark = 1 <= i < n - 1  # the arc between section points 1..n-1 is bark
        mat_index.append(0 if bark else 1)
    faces.append(tuple(reversed(range(n))))
    mat_index.append(2)
    faces.append(tuple(range(n, 2 * n)))
    mat_index.append(2)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for k, loop in enumerate(poly.loop_indices):
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            layer.data[loop].uv = ((co.x / length + 0.5) * 2.0, math.atan2(co.z, co.y) / math.tau + 0.5)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m in mats:
        obj.data.materials.append(m)
    for poly, idx in zip(mesh.polygons, mat_index):
        poly.material_index = idx
    obj.location = center
    obj.rotation_euler = (roll, pitch, yaw)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    parts.append(obj)
    return obj


def _dome(v: float, c: float, r: float) -> float:
    t = max(0.0, 1.0 - ((v - c) / r) ** 2)
    return math.sqrt(t)


def _tick_height(length: float, width: float, top: float, seed: int = 11):
    """Height field of a straw tick: lumpy, sagging where people lie, rounded at the edges."""
    rnd = random.Random(seed)
    bumps = [(rnd.uniform(-0.45, 0.45) * length, rnd.uniform(-0.4, 0.4) * width, rnd.uniform(0.006, 0.02))
             for _ in range(9)]

    def height(x: float, y: float) -> float:
        h = top
        for bx, by, w in bumps:
            h += w * math.exp(-(((x - bx) / 0.25) ** 2 + ((y - by) / 0.2) ** 2))
        h -= 0.025 * math.exp(-((x / (length * 0.3)) ** 2))  # the sag
        edge = min(0.5 * length - abs(x), 0.5 * width - abs(y))
        if edge < 0.08:
            h -= (0.08 - max(edge, 0.0)) * 0.6
        return h

    return height


def _sheet(parts, name, x0, x1, y0, y1, height, thick, mat, res):
    """A thick sheet following `height(x, y)`: ticks, bolsters, blankets."""
    nx, ny = res
    verts, faces = [], []
    for layer, dz in ((0, 0.0), (1, -thick)):
        for j in range(ny + 1):
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx
                y = y0 + (y1 - y0) * j / ny
                verts.append((x, y, height(x, y) + dz))
    row = nx + 1
    off = row * (ny + 1)
    for j in range(ny):
        for i in range(nx):
            a = j * row + i
            faces.append((a, a + 1, a + row + 1, a + row))
            faces.append((off + a, off + a + row, off + a + row + 1, off + a + 1))
    for i in range(nx):  # side skirts
        faces.append((i + 1, i, off + i, off + i + 1))
        a, b = ny * row + i, ny * row + i + 1
        faces.append((a, b, off + b, off + a))
    for j in range(ny):
        a, b = j * row, (j + 1) * row
        faces.append((b, a, off + a, off + b))
        a, b = j * row + nx, (j + 1) * row + nx
        faces.append((a, b, off + b, off + a))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for loop in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            layer.data[loop].uv = ((co.x - x0) / 0.8, (co.y - y0) / 0.8 + co.z)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    parts.append(_finish(obj, mat))
    return obj


# --- pieces --------------------------------------------------------------------


def build_bench(parts, m):
    length, depth, top = 1.62, 0.30, 0.46
    box(parts, "Seat", (0, 0, top - 0.03), (length, depth, 0.06), m["oak"], bevel=0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            foot = (sx * (length * 0.5 - 0.06), sy * 0.17, 0.0)
            head = (sx * (length * 0.5 - 0.17), sy * 0.06, top)
            rod(parts, f"Leg{sx}{sy}", foot, head, 0.032, 0.026, m["oak"])
            # Wedged through-tenon showing on the seat.
            box(parts, f"Wedge{sx}{sy}", (head[0], head[1], top + 0.002), (0.05, 0.012, 0.006), m["split"], bevel=0.0)
    for sx in (-1, 1):
        rod(parts, f"Stretcher{sx}", (sx * (length * 0.5 - 0.115), -0.115, 0.2),
            (sx * (length * 0.5 - 0.115), 0.115, 0.2), 0.018, 0.018, m["oak"], 8)
    rod(parts, "LongStretcher", (-(length * 0.5 - 0.115), 0, 0.2), (length * 0.5 - 0.115, 0, 0.2),
        0.02, 0.02, m["oak"], 8)


def build_stool(parts, m):
    top = 0.44
    lathe(parts, "Seat", [(0.0, top - 0.055), (0.16, top - 0.055), (0.175, top - 0.03),
                          (0.172, top), (0.0, top + 0.004)], m["oak"], 24, jitter=0.015, seed=3)
    for k in range(3):
        a = math.radians(90 + k * 120)
        foot = (math.cos(a) * 0.24, math.sin(a) * 0.24, 0.0)
        head = (math.cos(a) * 0.09, math.sin(a) * 0.09, top - 0.02)
        rod(parts, f"Leg{k}", foot, head, 0.026, 0.022, m["oak"])


def build_straw_pallet(parts, m):
    # A plank box bed, wide enough for two (town households shared beds).
    length, width, side = 1.92, 1.02, 0.34
    for sy in (-1, 1):
        box(parts, f"SideBoard{sy}", (0, sy * (width * 0.5 - 0.02), side * 0.5 + 0.04), (length, 0.04, side - 0.02),
            m["oak"], bevel=0.008)
    for sx in (-1, 1):
        box(parts, f"EndBoard{sx}", (sx * (length * 0.5 - 0.02), 0, side * 0.5 + 0.06 + (0.08 if sx < 0 else 0.0)),
            (0.04, width, side + (0.16 if sx < 0 else 0.0)), m["oak"], bevel=0.008)
        for sy in (-1, 1):
            box(parts, f"Post{sx}{sy}", (sx * (length * 0.5 - 0.03), sy * (width * 0.5 - 0.03), 0.2 + (0.06 if sx < 0 else 0)),
                (0.07, 0.07, 0.4 + (0.12 if sx < 0 else 0)), m["oak"], bevel=0.01)
    for k in range(5):
        box(parts, f"Slat{k}", (-0.76 + k * 0.38, 0, 0.12), (0.1, width - 0.06, 0.025), m["split"], bevel=0.0)
    tick_top = _tick_height(length - 0.1, width - 0.1, 0.34)
    _sheet(parts, "StrawTick", -(length - 0.1) * 0.5, (length - 0.1) * 0.5, -(width - 0.1) * 0.5,
           (width - 0.1) * 0.5, tick_top, 0.2, m["straw"], (24, 12))
    _sheet(parts, "Bolster", -length * 0.5 + 0.08, -length * 0.5 + 0.4, -(width - 0.2) * 0.5,
           (width - 0.2) * 0.5, lambda x, y: tick_top(x, y) + 0.09 * _dome(x, -length * 0.5 + 0.24, 0.16)
           * _dome(y, 0.0, (width - 0.2) * 0.5) + 0.012, 0.04, m["linen"], (8, 10))
    # The wool blanket drapes the tick inside the box, its top turned back.
    inner = (width - 0.1) * 0.5
    drop = lambda x, y: tick_top(x, y) + 0.018
    _sheet(parts, "Blanket", -0.32, length * 0.5 - 0.08, -inner, inner, drop, 0.016, m["wool"], (18, 14))
    fold = lambda x, y: drop(x, y) + 0.02 + 0.015 * _dome(x, -0.36, 0.08)
    _sheet(parts, "BlanketFold", -0.44, -0.28, -inner, inner, fold, 0.016, m["wool"], (4, 14))
    rnd = random.Random(15)
    for k in range(14):
        x = rnd.uniform(-length * 0.45, length * 0.45)
        y = rnd.choice((-1, 1)) * (width * 0.5 - 0.09)
        rod(parts, f"Straw{k}", (x, y, 0.3), (x + rnd.uniform(-0.08, 0.08), y, 0.3 + rnd.uniform(0.03, 0.07)),
            0.006, 0.002, m["straw"], 4)


def _wood_mats(m):
    return [m["birch"], m["split"], m["split"]]


def build_firewood_log(parts, m):
    split_log(parts, "Log", (0, 0, 0.06), 0.5, 0.075, 0.0, _wood_mats(m), seed=21)


def build_firewood_armful(parts, m):
    rnd = random.Random(31)
    k = 0
    for row, count in ((0, 3), (1, 2), (2, 1)):
        for i in range(count):
            y = (i - (count - 1) * 0.5) * 0.11
            split_log(parts, f"Log{k}", (rnd.uniform(-0.03, 0.03), y, 0.055 + row * 0.095), 0.48,
                      0.07, rnd.uniform(-0.12, 0.12), _wood_mats(m), seed=40 + k, roll=rnd.uniform(-0.6, 0.6))
            k += 1


def build_firewood_pile(parts, m, rows):
    """Indoor pile by the hearth: logs crosswise to the wall in courses."""
    rnd = random.Random(50 + rows)
    k = 0
    for row in range(rows):
        count = 5 - row
        for i in range(count):
            x = (i - (count - 1) * 0.5) * 0.15
            split_log(parts, f"Log{k}", (x, rnd.uniform(-0.03, 0.03), 0.06 + row * 0.12), 0.52, 0.078,
                      math.pi * 0.5 + rnd.uniform(-0.06, 0.06), _wood_mats(m), seed=60 + rows * 20 + k,
                      roll=math.pi + rnd.uniform(-0.3, 0.3))
            k += 1
    if rows <= 1:
        # A couple of logs lying loose where the pile was.
        split_log(parts, f"Log{k}", (0.42, 0.1, 0.06), 0.5, 0.075, 0.4, _wood_mats(m), seed=99)


def build_basket(parts, m):
    lathe(parts, "Body", [(0.0, 0.0), (0.15, 0.0), (0.17, 0.04), (0.2, 0.2), (0.215, 0.27),
                          (0.205, 0.27), (0.19, 0.2), (0.16, 0.05), (0.0, 0.03)], m["wicker"], 24, jitter=0.02, seed=5)
    lathe(parts, "Rim", [(0.205, 0.265), (0.228, 0.27), (0.228, 0.29), (0.205, 0.295)], m["wicker"], 24)
    prev = None
    for s in range(13):
        a = math.pi * s / 12
        p = (math.cos(a) * 0.215, 0.0, 0.28 + math.sin(a) * 0.2)
        if prev is not None:
            rod(parts, f"Handle{s}", prev, p, 0.014, 0.014, m["wicker"], 6)
        prev = p


def build_clay_pot(parts, m):
    lathe(parts, "Body", [(0.0, 0.0), (0.075, 0.0), (0.11, 0.05), (0.135, 0.13), (0.12, 0.2),
                          (0.085, 0.235), (0.09, 0.255), (0.1, 0.262), (0.092, 0.27), (0.075, 0.255),
                          (0.07, 0.2), (0.0, 0.19)], m["pottery"], 24, jitter=0.012, seed=7)


PIECES = {
    "Bench": build_bench,
    "Stool": build_stool,
    "StrawPallet": build_straw_pallet,
    "FirewoodLog": build_firewood_log,
    "FirewoodArmful": build_firewood_armful,
    "FirewoodPileFull": lambda p, m: build_firewood_pile(p, m, 3),
    "FirewoodPileHalf": lambda p, m: build_firewood_pile(p, m, 2),
    "FirewoodPileLow": lambda p, m: build_firewood_pile(p, m, 1),
    "Basket": build_basket,
    "ClayPot": build_clay_pot,
}


def _ground(root, parts) -> None:
    low = min((obj.matrix_world @ Vector(c)).z for obj in parts for c in obj.bound_box)
    for obj in parts:
        obj.location.z -= low


def build_kit():
    m = {
        "oak": _material("HouseholdOak", "oak", OAK_SRGB, 0.74),
        "split": _material("HouseholdSplitWood", "split", SPLIT_SRGB, 0.82),
        "birch": _material("HouseholdBirchBark", "birch", BIRCH_BARK_SRGB, 0.78),
        "straw": _material("HouseholdStraw", "straw", STRAW_SRGB, 0.92),
        "wool": _material("HouseholdWool", "wool", WOOL_SRGB, 0.95),
        "linen": _material("HouseholdLinen", "linen", LINEN_SRGB, 0.9),
        "wicker": _material("HouseholdWicker", "wicker", WICKER_SRGB, 0.85),
        "pottery": _material("HouseholdPottery", "pottery", POTTERY_SRGB, 0.8),
    }
    kit = bpy.data.objects.new("HouseholdFurnitureKit", None)
    bpy.context.collection.objects.link(kit)
    report = {}
    for name, build in PIECES.items():
        root = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(root)
        root.parent = kit
        parts: list = []
        build(parts, m)
        _ground(root, parts)
        for obj in parts:
            obj.parent = root
        tris = sum(len(p.vertices) - 2 for obj in parts for p in obj.data.polygons)
        lo = [min((obj.matrix_world @ Vector(c))[i] for obj in parts for c in obj.bound_box) for i in range(3)]
        hi = [max((obj.matrix_world @ Vector(c))[i] for obj in parts for c in obj.bound_box) for i in range(3)]
        # Report in Godot axes: x, y (up), z.
        report[name] = {"triangles": tris,
                        "size_m": [round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)]}
    return kit, report


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit, report = build_kit()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [kit, *kit.children_recursive]:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT), export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
        export_image_format="AUTO", export_cameras=False, export_lights=False, export_animations=False,
    )
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    summary = {
        "asset_id": ASSET_ID,
        "generator": "tools/generate_household_furniture_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "pieces": report,
    }
    (EVIDENCE_DIR / "report.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("ASSET_METRICS=" + json.dumps(summary, separators=(",", ":")))


if __name__ == "__main__":
    main()
