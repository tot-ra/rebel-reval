#!/usr/bin/env python3
"""Build yard kit A for Reval 1343 burgher plots (privy, plot gates, water butt) with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_yard_kit.py

Task R-1417 (WB-13g, parent R-985). The city plan places these objects per plot
(`plots[].items` privy / water_butt, `plots[].wall.gate`); the runtime that
instances them is R-1420 (gates) and R-1421 (items). Evidence and rejects come
from the WB-12 authoring table in docs/tasks/world/WB-13_burgher_plot_prefab.md:
the privy is a timber shed over an unlined pit (no stone Tartu latrine
dimensions), gates are riven-plank or wattle leaves with no iron beyond hinges,
the water butt is a coopered cask with withy hoops under a roof drain.

No textures: every material is a flat PBR factor so Godot extracts no PNGs and
the asset freeze (P0-040) gains only this GLB. Board-to-board tone variation
comes from three timber shades picked deterministically per board.

Front faces Godot +Z (Blender -Y); origin is the floor centre of each root.

Roots:
    PrivyShed          plank privy over a pit, lean-to board roof, ledged door
    PrivyShedWattle    the poor-yard variant: wattle walls on the same frame
    PlotGateWattle     wattle hurdle leaf on two round posts, 1.5 m wall
    PlotGatePlank      ledged-and-braced riven-plank leaf, square posts, 1.8 m wall
    PlotGateStone      plank leaf between limestone rubble piers, 2.0 m wall
    WaterButt          coopered butt on two sleepers, withy hoops, water inside
    WaterButtChannel   short hollowed eaves-channel stub that drains into the butt

Each gate root holds three children: PostLeft, PostRight and Leaf. The gates
are authored for a 1.6 m clear opening (posts outside x = +-0.8). Leaf has its
origin on the hinge line (x = -0.78, 2 cm hinge gap) so the runtime can swing it open about Y,
and scales Leaf in X (and moves PostRight) for the 1.4 / 2.0 m gates the plan
also emits.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import re
import struct
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "yard" / "yard_kit_a.glb"
ASSET_ID = "prop.yard_kit_a"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "yard_kit_a_v1"

GATE_OPENING_M = 1.6
# Matches PLOT_WALL_HEIGHT_M in tools/city/build_reval_city_plan.py so a gate
# post never stands lower than the wall run it closes.
WALL_HEIGHT_M = {"wattle": 1.5, "plank": 1.8, "stone": 2.0}

TIMBER_SRGB = [(0x7E, 0x72, 0x63), (0x6E, 0x62, 0x55), (0x8C, 0x7B, 0x66)]  # weathered spruce/pine boards
OAK_SRGB = (0x5E, 0x4A, 0x38)  # posts, ledges, sleepers
WATTLE_SRGB = (0x8A, 0x72, 0x50)  # peeled hazel/willow rods
STAKE_SRGB = (0x5B, 0x4E, 0x40)  # bark-on stakes
LIMESTONE_SRGB = (0xA8, 0xA3, 0x94)  # Reval grey limestone rubble
IRON_SRGB = (0x3A, 0x36, 0x33)
WATER_SRGB = (0x1C, 0x26, 0x27)
CASK_SRGB = (0x7C, 0x5C, 0x3E)


def _lin(c: int) -> float:
    v = c / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _material(name: str, srgb: tuple[int, int, int], roughness: float, metallic: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*[_lin(c) for c in srgb], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
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
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40.0))
    return obj


def box(parts, name, center, size, mat, rot=(0.0, 0.0, 0.0), bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    parts.append(_finish(obj, mat, bevel))
    return obj


def rod(parts, name, p0, p1, r0, r1, mat, segments=8):
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


def ring(parts, name, z, radius, minor, mat, segments=28):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=segments, minor_segments=6, major_radius=radius, minor_radius=minor, location=(0.0, 0.0, z)
    )
    obj = bpy.context.object
    obj.name = name
    parts.append(_finish(obj, mat))
    return obj


def boards(parts, name, axis, span, z0, z1, plane, thick, m, rnd, top=None, gap=0.008):
    """Vertical riven boards side by side along one axis.

    axis "x": boards run along X from span[0] to span[1], the wall plane is y=plane.
    axis "y": boards run along Y, the wall plane is x=plane. `top(t)` optionally
    gives the top edge at position t (lean-to roof slope).
    """
    t = span[0]
    i = 0
    while t < span[1] - 0.02:
        w = min(rnd.uniform(0.15, 0.24), span[1] - t)
        c = t + w / 2.0
        top_z = top(c) if top else z1
        h = top_z - z0 - rnd.uniform(0.0, 0.03)
        mat = m["timber"][rnd.randrange(3)]
        lean = rnd.uniform(-0.012, 0.012)
        if axis == "x":
            box(parts, f"{name}{i}", (c, plane, z0 + h / 2.0), (w - gap, thick, h), mat, rot=(0.0, lean, 0.0))
        else:
            box(parts, f"{name}{i}", (plane, c, z0 + h / 2.0), (thick, w - gap, h), mat, rot=(lean, 0.0, 0.0))
        t += w
        i += 1


def wattle_panel(parts, name, axis, span, z0, z1, plane, m, rnd, stake_step=0.26, row=0.055):
    """Stakes with horizontal withies woven in and out between them."""
    n_stakes = max(2, int(round((span[1] - span[0]) / stake_step)) + 1)
    stakes = [span[0] + (span[1] - span[0]) * k / (n_stakes - 1) for k in range(n_stakes)]
    for k, s in enumerate(stakes):
        p0 = (s, plane, z0) if axis == "x" else (plane, s, z0)
        p1 = (s, plane, z1 + 0.04) if axis == "x" else (plane, s, z1 + 0.04)
        rod(parts, f"{name}Stake{k}", p0, p1, 0.022, 0.018, m["stake"], segments=6)
    z = z0 + 0.05
    r = 0
    while z < z1 - 0.01:
        # Each withy is drawn as short straight runs that alternate sides of the
        # stakes; the next row starts on the other side, which reads as weave.
        for k in range(n_stakes - 1):
            side = 0.022 if (k + r) % 2 == 0 else -0.022
            a, b = stakes[k], stakes[k + 1]
            jz = rnd.uniform(-0.006, 0.006)
            if axis == "x":
                rod(parts, f"{name}W{r}_{k}", (a, plane + side, z + jz), (b, plane - side, z - jz),
                    0.013, 0.013, m["wattle"], segments=5)
            else:
                rod(parts, f"{name}W{r}_{k}", (plane + side, a, z + jz), (plane - side, b, z - jz),
                    0.013, 0.013, m["wattle"], segments=5)
        z += row
        r += 1


def _join(parts, name):
    """Merge a list of parts into one mesh per material to keep draw calls low."""
    by_mat: dict = {}
    for obj in parts:
        by_mat.setdefault(obj.data.materials[0].name, []).append(obj)
    merged = []
    for mat_name, objs in sorted(by_mat.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = f"{name}_{mat_name}"
        obj.data.name = obj.name
        merged.append(obj)
    return merged


# --- pieces ----------------------------------------------------------------------

PRIVY_W = 1.1  # X, inside the corner posts
PRIVY_D = 1.3  # Y
PRIVY_FRONT_H = 2.05
PRIVY_BACK_H = 1.75


def _privy_frame(parts, m):
    hx, hy = PRIVY_W / 2.0, PRIVY_D / 2.0

    def top(y):  # lean-to: high at the door (-Y), low at the back
        return PRIVY_FRONT_H + (y + hy) / PRIVY_D * (PRIVY_BACK_H - PRIVY_FRONT_H)

    for sx in (-1, 1):
        for sy in (-1, 1):
            h = top(sy * hy)
            box(parts, f"Post{sx}{sy}", (sx * hx, sy * hy, h / 2.0), (0.09, 0.09, h), m["oak"])
    # Sill beams on the ground and the two roof plates.
    for sy in (-1, 1):
        box(parts, f"Sill{sy}", (0.0, sy * hy, 0.05), (PRIVY_W + 0.09, 0.1, 0.1), m["oak"])
        box(parts, f"Plate{sy}", (0.0, sy * hy, top(sy * hy) - 0.05), (PRIVY_W + 0.09, 0.1, 0.1), m["oak"])
    # Seat board with the hole, over the pit (visible through the door gap).
    box(parts, "SeatFront", (0.0, 0.18, 0.24), (PRIVY_W, 0.03, 0.44), m["timber"][1])
    box(parts, "SeatL", (-0.33, 0.38, 0.47), (0.44, 0.42, 0.04), m["timber"][0])
    box(parts, "SeatR", (0.33, 0.38, 0.47), (0.44, 0.42, 0.04), m["timber"][0])
    box(parts, "SeatBack", (0.0, 0.52, 0.47), (0.22, 0.14, 0.04), m["timber"][0])
    # Roof boards front to back with an overhang and a slope that drains backwards.
    rnd = random.Random(1417)
    slope = math.atan2(PRIVY_FRONT_H - PRIVY_BACK_H, PRIVY_D)
    run = math.hypot(PRIVY_D + 0.36, PRIVY_FRONT_H - PRIVY_BACK_H)
    x = -hx - 0.16
    i = 0
    while x < hx + 0.16:
        w = rnd.uniform(0.17, 0.25)
        cz = (PRIVY_FRONT_H + PRIVY_BACK_H) / 2.0 + 0.02
        box(parts, f"Roof{i}", (x + w / 2.0, 0.0, cz), (w - 0.006, run, 0.025),
            m["timber"][rnd.randrange(3)], rot=(-slope, 0.0, 0.0))
        x += w
        i += 1
    return top


def _privy_door(parts, m, rnd):
    hy = PRIVY_D / 2.0
    y = -hy - 0.05
    h = PRIVY_FRONT_H - 0.22
    boards(parts, "Door", "x", (-0.36, 0.36), 0.06, 0.06 + h, y, 0.03, m, rnd, gap=0.006)
    for k, z in enumerate((0.35, h - 0.25)):
        box(parts, f"DoorLedge{k}", (0.0, y - 0.03, z), (0.68, 0.03, 0.1), m["oak"])
        box(parts, f"DoorHinge{k}", (-0.2, y - 0.05, z), (0.34, 0.008, 0.035), m["iron"], bevel=0.0)
    brace = math.atan2(h - 0.6, 0.62)
    box(parts, "DoorBrace", (0.0, y - 0.03, (0.35 + h - 0.25) / 2.0), (math.hypot(0.62, h - 0.6), 0.03, 0.09),
        m["oak"], rot=(0.0, -brace, 0.0))
    rod(parts, "DoorLatch", (0.3, y - 0.02, 1.0), (0.3, y - 0.12, 1.0), 0.015, 0.012, m["oak"], segments=6)
    # Narrow boards either side of the door fill the front wall.
    for sx in (-1, 1):
        box(parts, f"DoorJamb{sx}", (sx * 0.47, -hy, (PRIVY_FRONT_H - 0.1) / 2.0), (0.16, 0.03, PRIVY_FRONT_H - 0.1),
            m["timber"][2])
    box(parts, "DoorHead", (0.0, -hy, PRIVY_FRONT_H - 0.13), (0.8, 0.03, 0.06), m["timber"][2])


def build_privy_plank(parts, m):
    rnd = random.Random(14171)
    top = _privy_frame(parts, m)
    hx, hy = PRIVY_W / 2.0, PRIVY_D / 2.0
    for sx in (-1, 1):
        boards(parts, f"Side{sx}", "y", (-hy, hy), 0.02, None, sx * (hx + 0.06), 0.03, m, rnd, top=lambda y: top(y) - 0.04)
    boards(parts, "Back", "x", (-hx, hx), 0.02, PRIVY_BACK_H - 0.04, hy + 0.06, 0.03, m, rnd)
    _privy_door(parts, m, rnd)


def build_privy_wattle(parts, m):
    rnd = random.Random(14172)
    _privy_frame(parts, m)
    hx, hy = PRIVY_W / 2.0, PRIVY_D / 2.0
    for sx in (-1, 1):
        wattle_panel(parts, f"Side{sx}", "y", (-hy + 0.08, hy - 0.08), 0.06, PRIVY_BACK_H - 0.12, sx * hx, m, rnd)
    wattle_panel(parts, "Back", "x", (-hx + 0.08, hx - 0.08), 0.06, PRIVY_BACK_H - 0.12, hy, m, rnd)
    _privy_door(parts, m, rnd)


def _gate_leaf_plank(parts, m, rnd, height, width):
    # Leaf root origin is the hinge line, so the leaf spans x = 0..width here.
    boards(parts, "Board", "x", (0.02, width - 0.02), 0.08, 0.08 + height, 0.0, 0.032, m, rnd, gap=0.005)
    lo, hi = 0.32, height - 0.12
    for k, z in enumerate((lo, hi)):
        box(parts, f"Ledge{k}", (width / 2.0, 0.035, z), (width - 0.08, 0.035, 0.11), m["oak"])
        # Strap hinge: the only iron on the gate (WB-12: no ironwork beyond hinges).
        box(parts, f"Hinge{k}", (0.22, 0.056, z), (0.42, 0.008, 0.04), m["iron"], bevel=0.0)
    span = math.hypot(width - 0.16, hi - lo)
    box(parts, "Brace", (width / 2.0, 0.035, (lo + hi) / 2.0), (span, 0.035, 0.1), m["oak"],
        rot=(0.0, math.atan2(hi - lo, width - 0.16), 0.0))
    rod(parts, "Latch", (width - 0.1, 0.04, 1.0), (width - 0.1, 0.14, 1.0), 0.016, 0.013, m["oak"], segments=6)


def _gate_leaf_wattle(parts, m, rnd, height, width):
    # A hurdle: a timber frame with withies woven between its uprights.
    for k, x in enumerate((0.04, width - 0.04)):
        rod(parts, f"Frame{k}", (x, 0.0, 0.08), (x, 0.0, 0.1 + height), 0.035, 0.03, m["stake"], segments=7)
    for k, z in enumerate((0.12, 0.08 + height)):
        rod(parts, f"Rail{k}", (0.0, 0.0, z), (width, 0.0, z), 0.03, 0.03, m["stake"], segments=7)
    wattle_panel(parts, "Hurdle", "x", (0.04, width - 0.04), 0.15, 0.05 + height, 0.0, m, rnd, stake_step=0.3)
    # Withy loops tie the hurdle to its post instead of iron hinges.
    for k, z in enumerate((0.35, height - 0.15)):
        bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4, major_radius=0.07, minor_radius=0.012,
                                         location=(-0.04, 0.0, z))
        obj = bpy.context.object
        obj.name = f"Tie{k}"
        parts.append(_finish(obj, m["wattle"]))


def _limestone_pier(parts, name, cx, height, m, rnd):
    """Rubble pier in rough courses of grey limestone, each block a little off-true."""
    z = 0.0
    k = 0
    while z < height - 0.02:
        course = min(rnd.uniform(0.14, 0.24), height - z)
        x = cx - 0.27
        while x < cx + 0.27 - 0.02:
            w = min(rnd.uniform(0.16, 0.3), cx + 0.27 - x)
            for y0 in (-0.27, 0.0):
                d = rnd.uniform(0.24, 0.28)
                box(parts, f"{name}B{k}", (x + w / 2.0, y0 + 0.135 + rnd.uniform(-0.01, 0.01), z + course / 2.0),
                    (w - 0.012, d, course - 0.012), m["stone"], rot=(0.0, 0.0, rnd.uniform(-0.04, 0.04)),
                    bevel=0.015)
                k += 1
            x += w
        z += course
    box(parts, f"{name}Cap", (cx, 0.0, height + 0.05), (0.6, 0.6, 0.1), m["stone"], bevel=0.02)


def build_gate(kind):
    def build(root, m):
        rnd = random.Random({"wattle": 1, "plank": 2, "stone": 3}[kind] * 7919)
        wall_h = WALL_HEIGHT_M[kind]
        half = GATE_OPENING_M / 2.0
        posts = {}
        for side, sx in (("PostLeft", -1), ("PostRight", 1)):
            parts: list = []
            if kind == "wattle":
                rod(parts, side, (sx * (half + 0.07), 0.0, 0.0), (sx * (half + 0.07), 0.0, wall_h + 0.12),
                    0.075, 0.065, m["stake"], segments=10)
            elif kind == "plank":
                box(parts, side, (sx * (half + 0.08), 0.0, (wall_h + 0.15) / 2.0), (0.16, 0.16, wall_h + 0.15),
                    m["oak"])
                box(parts, side + "Cap", (sx * (half + 0.08), 0.0, wall_h + 0.17), (0.2, 0.2, 0.04), m["oak"])
            else:
                _limestone_pier(parts, side, sx * (half + 0.27), wall_h + 0.05, m, rnd)
            posts[side] = parts
        leaf: list = []
        leaf_h = {"wattle": wall_h - 0.2, "plank": wall_h - 0.2, "stone": wall_h - 0.15}[kind]
        width = GATE_OPENING_M - 0.04
        if kind == "wattle":
            _gate_leaf_wattle(leaf, m, rnd, leaf_h, width)
        else:
            _gate_leaf_plank(leaf, m, rnd, leaf_h, width)
        children = []
        for name, parts in (("PostLeft", posts["PostLeft"]), ("PostRight", posts["PostRight"]), ("Leaf", leaf)):
            node = bpy.data.objects.new(name, None)
            bpy.context.collection.objects.link(node)
            node.parent = root
            if name == "Leaf":
                # The leaf was built from x = 0 at its hinge; the hinge sits on the
                # inner face of the left post.
                node.location = (-half + 0.02, 0.0, 0.0)
            for obj in _join(parts, f"{kind.capitalize()}{name}"):
                obj.parent = node
            children.append(node)
        return children

    return build


def _stave_mesh(name, n_staves, height, r_end, r_belly, thick, gap, mat):
    """Coopered body: separate bulged staves with a small gap between them."""
    rows = 9
    verts, faces = [], []
    for s in range(n_staves):
        a0 = s / n_staves * math.tau + gap / 2.0
        a1 = (s + 1) / n_staves * math.tau - gap / 2.0
        base = len(verts)
        for i in range(rows):
            z = height * i / (rows - 1)
            t = 2.0 * z / height - 1.0
            r = r_end + (r_belly - r_end) * (1.0 - t * t)
            for a in (a0, a1):
                verts.append((math.cos(a) * r, math.sin(a) * r, z))
                verts.append((math.cos(a) * (r - thick), math.sin(a) * (r - thick), z))
        for i in range(rows - 1):
            o0 = base + i * 4  # outer a0, inner a0, outer a1, inner a1
            o1 = o0 + 4
            faces.append((o0, o0 + 2, o1 + 2, o1))  # outer face
            faces.append((o0 + 1, o1 + 1, o1 + 3, o0 + 3))  # inner face
            faces.append((o0, o1, o1 + 1, o0 + 1))  # side a0
            faces.append((o0 + 2, o0 + 3, o1 + 3, o1 + 2))  # side a1
        top = base + (rows - 1) * 4
        faces.append((top, top + 1, top + 3, top + 2))
        faces.append((base, base + 2, base + 3, base + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return _finish(obj, mat)


BUTT_H = 0.92
BUTT_END_R = 0.31
BUTT_BELLY_R = 0.36
SLEEPER_H = 0.08


def build_water_butt(parts, m):
    for k, x in enumerate((-0.2, 0.2)):
        box(parts, f"Sleeper{k}", (x, 0.0, SLEEPER_H / 2.0), (0.09, 0.78, SLEEPER_H), m["oak"], bevel=0.01)
    body = _stave_mesh("Staves", 20, BUTT_H, BUTT_END_R, BUTT_BELLY_R, 0.025, 0.012, m["cask"])
    body.location.z = SLEEPER_H
    parts.append(body)
    # Head (bottom) inside the chime, water surface a hand below the rim.
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=BUTT_END_R - 0.02, depth=0.03,
                                        location=(0.0, 0.0, SLEEPER_H + 0.06))
    obj = bpy.context.object
    obj.name = "Head"
    parts.append(_finish(obj, m["cask"]))
    water_z = SLEEPER_H + BUTT_H - 0.11
    t = 2.0 * (BUTT_H - 0.11) / BUTT_H - 1.0
    water_r = BUTT_END_R + (BUTT_BELLY_R - BUTT_END_R) * (1.0 - t * t) - 0.026
    bpy.ops.mesh.primitive_circle_add(vertices=24, radius=water_r, fill_type="NGON", location=(0.0, 0.0, water_z))
    obj = bpy.context.object
    obj.name = "Water"
    parts.append(_finish(obj, m["water"]))
    # Split hazel hoops: two at each chime, one each side of the belly.
    for k, frac in enumerate((0.07, 0.3, 0.7, 0.93)):
        z = BUTT_H * frac
        tt = 2.0 * frac - 1.0
        r = BUTT_END_R + (BUTT_BELLY_R - BUTT_END_R) * (1.0 - tt * tt) + 0.008
        ring(parts, f"Hoop{k}", SLEEPER_H + z, r, 0.014, m["wattle"])


def build_water_butt_channel(parts, m):
    # A hollowed half-log trough from the eaves (back, +Y, high) to the butt
    # mouth, on a forked prop stake. Godot +Z front means the wall is behind.
    p0 = Vector((0.0, 0.55, 1.75))
    p1 = Vector((0.0, 0.05, SLEEPER_H + BUTT_H + 0.08))
    axis = p1 - p0
    length = axis.length
    pitch = math.atan2(-axis.z, -axis.y)
    mid = (p0 + p1) * 0.5
    for k, sx in enumerate((-1, 1)):
        box(parts, f"Side{k}", (sx * 0.055, mid.y, mid.z + 0.02), (0.022, length, 0.07), m["timber"][k],
            rot=(pitch, 0.0, 0.0), bevel=0.003)
    box(parts, "Floor", (0.0, mid.y, mid.z - 0.015), (0.13, length, 0.022), m["timber"][2], rot=(pitch, 0.0, 0.0),
        bevel=0.003)
    prop_top = p0 + axis * 0.35
    rod(parts, "Prop", (0.0, prop_top.y + 0.05, 0.0), (0.0, prop_top.y, prop_top.z - 0.05), 0.025, 0.02,
        m["stake"], segments=6)
    for k, sx in enumerate((-1, 1)):
        rod(parts, f"Fork{k}", (0.0, prop_top.y, prop_top.z - 0.06), (sx * 0.06, prop_top.y, prop_top.z + 0.03),
            0.014, 0.01, m["stake"], segments=5)


PIECES = {
    "PrivyShed": build_privy_plank,
    "PrivyShedWattle": build_privy_wattle,
    "WaterButt": build_water_butt,
    "WaterButtChannel": build_water_butt_channel,
}
GATES = {"PlotGateWattle": "wattle", "PlotGatePlank": "plank", "PlotGateStone": "stone"}


def _measure(objs):
    meshes = [o for o in objs if o.type == "MESH"]
    lo = [min((o.matrix_world @ Vector(c))[i] for o in meshes for c in o.bound_box) for i in range(3)]
    hi = [max((o.matrix_world @ Vector(c))[i] for o in meshes for c in o.bound_box) for i in range(3)]
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    # Report in Godot axes: x, y (up), z.
    return {"triangles": tris, "size_m": [round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)]}


def build_kit():
    m = {
        "timber": [_material(f"YardBoard{k}", c, 0.86) for k, c in enumerate(TIMBER_SRGB)],
        "oak": _material("YardOak", OAK_SRGB, 0.8),
        "wattle": _material("YardWattle", WATTLE_SRGB, 0.85),
        "stake": _material("YardStake", STAKE_SRGB, 0.9),
        "stone": _material("YardLimestone", LIMESTONE_SRGB, 0.92),
        "iron": _material("YardIron", IRON_SRGB, 0.6, metallic=0.7),
        "water": _material("YardWater", WATER_SRGB, 0.08),
        "cask": _material("YardCask", CASK_SRGB, 0.78),
    }
    kit = bpy.data.objects.new("YardKitA", None)
    bpy.context.collection.objects.link(kit)
    report = {}
    for name, build in PIECES.items():
        root = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(root)
        root.parent = kit
        parts: list = []
        build(parts, m)
        for obj in _join(parts, name):
            obj.parent = root
        report[name] = _measure(root.children_recursive)
    for name, kind in GATES.items():
        root = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(root)
        root.parent = kit
        build_gate(kind)(root, m)
        bpy.context.view_layer.update()
        report[name] = _measure(root.children_recursive)
    return kit, report


def _strip_name_suffixes(path: Path) -> None:
    """Rename `PostLeft.001` back to `PostLeft` in the exported GLB.

    Blender object names are global, so the second and third gate get numbered
    copies of PostLeft / PostRight / Leaf. The runtime looks the children up by
    name under each gate root (names are unique per parent), so the suffix is
    removed from the glTF JSON chunk after export.
    """
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    for node in doc["nodes"]:
        node["name"] = re.sub(r"\.\d{3}$", "", node["name"])
    chunk = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    chunk += b" " * (-len(chunk) % 4)  # glTF pads the JSON chunk with spaces
    rest = data[20 + json_len:]
    total = 12 + 8 + len(chunk) + len(rest)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(chunk), 0x4E4F534A)
                     + chunk + rest)


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
        export_cameras=False, export_lights=False, export_animations=False,
    )
    _strip_name_suffixes(OUTPUT)
    summary = {
        "asset_id": ASSET_ID,
        "generator": "tools/generate_yard_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "pieces": report,
    }
    print("ASSET_METRICS=" + json.dumps(summary, separators=(",", ":")))


if __name__ == "__main__":
    main()
