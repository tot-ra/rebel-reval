"""Model the shield variants (heater, buckler, pavise) and export them as GLBs.

Task R-2013 (EQ-11), pipeline docs/SYSTEMS/EQUIPMENT_VARIANTS.md. Unlike the
scanned weapons a shield is a flat painted board, and heraldry must be exact
(the Order's black cross on white, the crown's plain red), so the geometry is
modelled here from measured outlines and the paint is drawn procedurally; no
Meshy scan is involved. Run through Blender:

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/equipment/build_shields.py -- [--only heater_order_p3_w1 ...]

Every file follows the equipment conventions: face toward glTF +Z (what
CitizenShield and the held pose expect), up = +Y, origin at the middle of the
board, `socket_forearm` at the origin and `socket_back` on the back of the
board. Surfaces: `shield_face` (paint, own texture), `shield_wood` (board back,
edge and plank grain), `shield_leather` (enarmes, guige, rim binding) and
`shield_iron` (boss, rivets, buckler rim).

Prints one `SHIELD {json}` line per file (tris, size).
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
WOOD_PLATE = ROOT / "assets/materials/equipment/ash_shaft_used/ash_shaft_used_albedo.png"
TEX = 1024

# name -> spec. `kind` picks the outline, `paint` the face artwork, `wear` 0..2.
VARIANTS = {
    "heater_order_p3_w0": dict(dir="heater_shield", kind="heater", paint="order", wear=0),
    "heater_order_p3_w1": dict(dir="heater_shield", kind="heater", paint="order", wear=1),
    "heater_crown_p2_w1": dict(dir="heater_shield", kind="heater", paint="crown", wear=1),
    "heater_field_p3_w1": dict(dir="heater_shield", kind="heater", paint="field", wear=1),
    "heater_plain_p1_w0": dict(dir="heater_shield", kind="heater", paint="plain", wear=0),
    "heater_plain_p1_w2": dict(dir="heater_shield", kind="heater", paint="plain", wear=2),
    "buckler_p1_w1": dict(dir="buckler", kind="buckler", paint="buckler_plain", wear=1),
    "buckler_p2_w1": dict(dir="buckler", kind="buckler", paint="buckler_red", wear=1),
    "pavise_p1_w1": dict(dir="pavise", kind="pavise", paint="pavise", wear=1),
}

# sRGB paint colours. Order: white wool-and-chalk field, black cross (the Order's only arms).
# Crown: plain red, no invented heraldry (docs/SYSTEMS/CITIZEN_WARDROBE.md).
ORDER_WHITE = (0.88, 0.86, 0.80)
ORDER_BLACK = (0.07, 0.07, 0.07)
CROWN_RED = (0.60, 0.15, 0.11)
LIME_WOOD = (0.62, 0.50, 0.33)
PLAIN_PAINT = (0.42, 0.30, 0.17)
PAVISE_RED = (0.50, 0.16, 0.11)
BUCKLER_LEATHER = (0.22, 0.15, 0.10)


# --- outlines -----------------------------------------------------------------

HEATER_HW, HEATER_TOP, HEATER_POINT, HEATER_SHOULDER = 0.23, 0.30, -0.32, 0.06


def heater_bottom(x: float) -> float:
    """Lower edge of the heater: straight sides to the shoulder, then curving to the point."""
    t = min(abs(x) / HEATER_HW, 1.0)
    return HEATER_POINT + (HEATER_SHOULDER - HEATER_POINT) * t**1.9


PAVISE_HW, PAVISE_TOP, PAVISE_BOTTOM = 0.23, 0.45, -0.45


def face_z(kind: str, x: float, y: float) -> float:
    """Height of the painted face above the mid plane: the board's curve."""
    if kind == "heater":
        # Wrapped round the arm: a shallow vertical-axis curve, 3 cm at the centre line.
        return 0.03 * (1.0 - (x / HEATER_HW) ** 2)
    if kind == "pavise":
        # Convex with a central ridge so the quarrel glances off (arms dossier).
        ridge = math.sqrt(x * x + 0.012**2)
        return 0.055 * (1.0 - ridge / PAVISE_HW) + 0.015 * (1.0 - (x / PAVISE_HW) ** 2)
    # Buckler: a shallow dish, centre forward.
    r = math.hypot(x, y) / 0.15
    return 0.018 * (1.0 - min(r, 1.0) ** 2)


# --- face paint ---------------------------------------------------------------


def _noise(rng: np.random.Generator, h: int, w: int, cells: int) -> np.ndarray:
    """Smooth value noise 0..1 on `cells` grid cells, bilinear."""
    g = rng.random((cells + 2, cells + 2))
    ys = np.linspace(0, cells, h)
    xs = np.linspace(0, cells, w)
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x0 + 1] * fx
    b = g[y0 + 1][:, x0] * (1 - fx) + g[y0 + 1][:, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def _planform(kind: str) -> tuple[float, float, float, float]:
    """x0, x1, y0, y1 of the texture's planform in metres (u, v run over these)."""
    if kind == "heater":
        return -HEATER_HW, HEATER_HW, HEATER_POINT, HEATER_TOP
    if kind == "pavise":
        return -PAVISE_HW, PAVISE_HW, PAVISE_BOTTOM, PAVISE_TOP
    return -0.15, 0.15, -0.15, 0.15


def paint_face(spec: dict, seed: int) -> np.ndarray:
    """RGB float image (v up, row 0 = bottom) of the face paint on its board."""
    rng = np.random.default_rng(seed)
    kind, paint, wear = spec["kind"], spec["paint"], spec["wear"]
    x0, x1, y0, y1 = _planform(kind)
    h = w = TEX
    xs = np.linspace(x0, x1, w)[None, :].repeat(h, 0)
    ys = np.linspace(y0, y1, h)[:, None].repeat(w, 1)

    # Wood under the paint: lime boards, vertical grain, plank seams every ~9 cm.
    grain = _noise(rng, h, w, 6)[:, :, None] * 0.0
    streak = _noise(rng, 8, w, 90)
    streak = np.repeat(streak, h // 8, axis=0)[:, :, None]
    wood = np.array(LIME_WOOD)[None, None, :] * (0.82 + 0.3 * streak + grain)
    plank_w = 0.09 if kind != "buckler" else 0.30
    seam = np.abs(((xs - x0) / plank_w) % 1.0 - 0.0)
    seam = np.minimum(seam, 1.0 - seam) * plank_w
    seam_dark = np.clip(1.0 - seam / 0.0035, 0.0, 1.0)[:, :, None]

    colours = {
        "order": ORDER_WHITE, "crown": CROWN_RED, "field": (0.92, 0.92, 0.92),
        "plain": PLAIN_PAINT, "buckler_plain": BUCKLER_LEATHER, "buckler_red": CROWN_RED,
        "pavise": PAVISE_RED,
    }
    base = np.array(colours[paint])[None, None, :]
    mottle = 0.9 + 0.2 * _noise(rng, h, w, 14)[:, :, None]
    img = base * mottle

    if paint == "order":
        img = _order_cross(img, xs, ys)
    if paint == "pavise":
        # Town paint: a pale vertical band along the ridge, otherwise plain.
        band = (np.abs(xs) < 0.018)[:, :, None]
        img = np.where(band, np.array((0.80, 0.74, 0.62))[None, None, :] * mottle, img)

    # Edge dirt: darker toward the outline, more with wear.
    if kind == "heater":
        edge = np.minimum.reduce([HEATER_HW - np.abs(xs), HEATER_TOP - ys, ys - np.vectorize(heater_bottom)(xs)])
    elif kind == "pavise":
        edge = np.minimum.reduce([PAVISE_HW - np.abs(xs), PAVISE_TOP - ys, ys - PAVISE_BOTTOM])
    else:
        edge = 0.15 - np.hypot(xs, ys)
    dirt = np.clip(1.0 - edge / 0.05, 0.0, 1.0)[:, :, None]
    amount = (0.10, 0.22, 0.38)[wear]
    img = img * (1.0 - amount * dirt)

    # Fade and paint loss: scuffs (w1) and flaking down to the wood (w2); chips cluster on the edge.
    loss_noise = _noise(rng, h, w, 9) * 0.6 + _noise(rng, h, w, 40) * 0.4
    threshold = (2.0, 0.86, 0.52)[wear] - 0.22 * dirt[:, :, 0]
    lost = (loss_noise > threshold)[:, :, None]
    if paint == "plain":  # bare wood is the point of the plain shield
        lost = lost | (loss_noise > threshold - 0.12)[:, :, None]
    fade = (0.0, 0.12, 0.30)[wear]
    img = img * (1.0 - fade) + np.array((0.55, 0.52, 0.47))[None, None, :] * fade * 0.7
    img = np.where(lost, wood * 0.9, img)
    # Scratches: a few thin pale lines on a used face.
    if wear >= 1:
        for _ in range(8 + 10 * wear):
            ang = rng.uniform(-0.6, 0.6)
            cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
            d = np.abs((xs - cx) * math.cos(ang) + (ys - cy) * math.sin(ang))
            along = np.abs(-(xs - cx) * math.sin(ang) + (ys - cy) * math.cos(ang))
            mark = ((d < 0.0015) & (along < rng.uniform(0.04, 0.12)))[:, :, None]
            img = np.where(mark, img * 0.55 + 0.25, img)
    img = img * (1.0 - 0.45 * seam_dark)
    return np.clip(img, 0.0, 1.0)


def _order_cross(img: np.ndarray, xs: np.ndarray, ys: np.ndarray) -> np.ndarray:
    """The Order's black cross: arms flare toward the ends (cross pattee), long foot."""
    cy, cx = 0.07, 0.0
    # Vertical arm from the base of the shield to the chief, horizontal arm across the chest.
    dy = np.abs(ys - 0.015) / 0.285
    vert = (np.abs(xs - cx) < 0.034 + 0.026 * dy**2) & (ys > -0.285) & (ys < 0.285)
    dx = np.abs(xs - cx) / 0.205
    horiz = (np.abs(ys - cy) < 0.034 + 0.026 * dx**2) & (np.abs(xs - cx) < 0.205)
    mask = (vert | horiz)[:, :, None]
    return np.where(mask, np.array(ORDER_BLACK)[None, None, :] * (0.9 + 0.2 * (xs[:, :, None] % 0.02 > 0.01)), img)


# --- geometry -----------------------------------------------------------------


def _material(name: str, colour=None, image=None, rough=0.7, metal=0.0, uv_tile=False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image is not None:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    return mat


def _image(name: str, rgb: np.ndarray) -> bpy.types.Image:
    img = bpy.data.images.new(name, rgb.shape[1], rgb.shape[0], alpha=False)
    # Blender stores sRGB images as sRGB-encoded floats in `pixels`; our colours are sRGB.
    rgba = np.concatenate([rgb, np.ones(rgb.shape[:2] + (1,))], axis=2)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.pack()
    return img


def _grid_board(spec: dict, name: str, mats: list) -> bpy.types.Object:
    """Front surface as a grid over the planform with a thickness extrusion behind it.

    Faces: material 0 = painted front, 1 = wood back and edge (the outer edge strip is
    material 2, leather binding)."""
    kind = spec["kind"]
    bm = bmesh.new()
    x0, x1, y0, y1 = _planform(kind)
    cols, rows = {"heater": (28, 14), "pavise": (20, 24), "buckler": (24, 12)}[kind]
    thick = {"heater": 0.016, "pavise": 0.020, "buckler": 0.012}[kind]
    uv_layer = bm.loops.layers.uv.new("UVMap")
    verts = {}
    if kind == "buckler":
        # Polar grid: rings x spokes, so the rim is round.
        spokes, rings = 32, 8
        centre = bm.verts.new((0, 0, face_z(kind, 0, 0)))
        ring_v = []
        for ri in range(1, rings + 1):
            r = 0.15 * ri / rings
            row = [bm.verts.new((r * math.cos(2 * math.pi * s / spokes), r * math.sin(2 * math.pi * s / spokes),
                                 face_z(kind, r * math.cos(2 * math.pi * s / spokes), r * math.sin(2 * math.pi * s / spokes))))
                   for s in range(spokes)]
            ring_v.append(row)
        faces = []
        for s in range(spokes):
            faces.append(bm.faces.new((centre, ring_v[0][s], ring_v[0][(s + 1) % spokes])))
        for ri in range(rings - 1):
            for s in range(spokes):
                a, b = ring_v[ri][s], ring_v[ri][(s + 1) % spokes]
                c, d = ring_v[ri + 1][(s + 1) % spokes], ring_v[ri + 1][s]
                faces.append(bm.faces.new((a, d, c, b)))
        for f in faces:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    else:
        grid = []
        for c in range(cols + 1):
            x = x0 + (x1 - x0) * c / cols
            low = heater_bottom(x) if kind == "heater" else y0
            col = []
            for r in range(rows + 1):
                y = low + (y1 - low) * r / rows
                col.append(bm.verts.new((x, y, face_z(kind, x, y))))
            grid.append(col)
        faces = []
        for c in range(cols):
            for r in range(rows):
                f = bm.faces.new((grid[c][r], grid[c + 1][r], grid[c + 1][r + 1], grid[c][r + 1]))
                faces.append(f)
        for f in faces:
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
        # Heater point: the bottom row collapses at x = 0 only through the curve; fine as is.
    for f in faces:
        f.material_index = 0
    ext = bmesh.ops.extrude_face_region(bm, geom=faces)
    moved = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    for v in moved:
        v.co.z -= thick
    new_faces = [f for f in ext["geom"] if isinstance(f, bmesh.types.BMFace)]
    for f in new_faces:
        f.material_index = 2 if abs(f.normal.z) < 0.5 else 1
    for f in bm.faces:
        if f.material_index != 0 and f.normal.z < -0.5:
            f.material_index = 1
    # Planar UVs: front over the planform, back and edge in metres / 0.5 for the wood plate.
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            if f.material_index == 0:
                loop[uv_layer].uv = ((co.x - x0) / (x1 - x0), (co.y - y0) / (y1 - y0))
            else:
                loop[uv_layer].uv = (co.x * 2.0 + co.z * 3.0, co.y * 2.0)
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m in mats:
        mesh.materials.append(m)
    mesh.shade_smooth()
    return obj


def _strip(name, points, width, thick, mat, up=Vector((0, 0, 1))):
    """A flat strap along a polyline (blender coords), `width` wide in the `up`-cross direction."""
    bm = bmesh.new()
    prev = None
    for i, p in enumerate(points):
        p = Vector(p)
        tangent = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        side = tangent.cross(up).normalized() * (width / 2)
        ring = [bm.verts.new(p + side), bm.verts.new(p - side),
                bm.verts.new(p - side + up * thick), bm.verts.new(p + side + up * thick)]
        if prev:
            for k in range(4):
                bm.faces.new((prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k]))
        prev = ring
    first = []
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def _cyl(name, centre, radius, depth, mat, axis="Z", verts=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=centre)
    obj = bpy.context.active_object
    obj.name = name
    if axis == "X":
        obj.rotation_euler = (0, math.pi / 2, 0)
    obj.data.materials.append(mat)
    return obj


def _cone(name, centre, r0, r1, depth, mat, verts=16):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=depth, location=centre)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def _fittings(spec: dict, mats: dict, thick: float) -> list:
    """Enarmes, guige, boss and rivets: the inside of the shield must read right from behind."""
    kind, paint = spec["kind"], spec["paint"]
    leather, iron = mats["leather"], mats["iron"]
    out = []
    back = -thick - 0.003
    if kind == "heater":
        # Two enarmes straps across the back (the forearm goes through the lower, the fist holds the upper).
        for i, y in enumerate((0.13, -0.05)):
            pts = []
            for k in range(9):
                x = -0.075 + 0.15 * k / 8
                # bowed away from the board so the arm fits under it
                pts.append((x, y, back - 0.028 * math.sin(math.pi * k / 8) - 0.0))
            out.append(_strip(f"Enarmes{i}", pts, 0.030, 0.006, leather, up=Vector((0, 1, 0))))
            for x in (-0.075, 0.075):
                out.append(_cyl(f"Rivet{i}", (x, y, back + 0.002), 0.008, 0.012, iron, verts=6))
        # Guige: a long strap hung from two rings at the chief, sagging behind the board.
        pts = []
        for k in range(17):
            t = k / 16
            pts.append((-0.19 + 0.38 * t, 0.26 - 0.07 * math.sin(math.pi * t), back - 0.018 * math.sin(math.pi * t)))
        out.append(_strip("Guige", pts, 0.026, 0.004, leather, up=Vector((0, 0, 1))))
        for x in (-0.19, 0.19):
            out.append(_cyl("GuigeRing", (x, 0.26, back + 0.002), 0.012, 0.010, iron, verts=8))
        if paint == "plain":
            out.append(_cone("Boss", (0.0, 0.05, 0.03 + 0.012), 0.050, 0.020, 0.024, iron, verts=12))
    elif kind == "buckler":
        out.append(_cone("Boss", (0.0, 0.0, 0.018 + 0.026), 0.062, 0.020, 0.052, iron, verts=16))
        # Iron grip bar across the hollow of the boss, held in the fist.
        out.append(_cyl("Grip", (0.0, 0.0, back - 0.012), 0.011, 0.12, iron, axis="X", verts=8))
        for x in (-0.06, 0.06):
            out.append(_cyl("GripStaple", (x, 0.0, back - 0.004), 0.007, 0.018, iron, verts=6))
        # Iron rim band on the edge and four rivets on the face.
        bpy.ops.mesh.primitive_torus_add(major_radius=0.150, minor_radius=0.007, major_segments=32, minor_segments=6,
                                         location=(0, 0, -0.006))
        rim = bpy.context.active_object
        rim.name = "Rim"
        rim.data.materials.append(iron)
        out.append(rim)
        for a in range(8):
            ang = a * math.pi / 4
            out.append(_cyl("Rivet", (0.11 * math.cos(ang), 0.11 * math.sin(ang), 0.012), 0.007, 0.008, iron, verts=6))
    else:  # pavise
        # Handle strap across the back and a prop-stick hinged on a leather loop, resting on the ground.
        pts = [(x, 0.08, back - 0.03 * math.sin(math.pi * (x + 0.07) / 0.14)) for x in np.linspace(-0.07, 0.07, 7)]
        out.append(_strip("Handle", pts, 0.035, 0.006, leather, up=Vector((0, 1, 0))))
        pts = [(x, 0.30, back - 0.025 * math.sin(math.pi * (x + 0.07) / 0.14)) for x in np.linspace(-0.07, 0.07, 7)]
        out.append(_strip("ArmStrap", pts, 0.035, 0.006, leather, up=Vector((0, 1, 0))))
        stick = _cyl("PropStick", (0.0, -0.09, back - 0.116), 0.016, 0.62, mats["wood"], verts=8)
        stick.rotation_euler = (math.radians(-110), 0, 0)
        out.append(stick)
        for x in (-0.07, 0.07):
            out.append(_cyl("Rivet", (x, 0.08, back + 0.002), 0.008, 0.012, iron, verts=6))
        # Iron nail heads along the ridge.
        for y in np.linspace(-0.38, 0.38, 7):
            out.append(_cyl("Nail", (0.0, float(y), face_z("pavise", 0.0, 0.0) + 0.002), 0.007, 0.006, iron, verts=6))
    return out


def _empty(name: str, loc) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.04
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    return obj


def build(name: str, spec: dict, out_dir: Path) -> dict:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    seed = sum(ord(c) * (i + 3) for i, c in enumerate(name))
    face_img = _image(f"{name}_face", paint_face(spec, seed))
    wood_img = bpy.data.images.load(str(WOOD_PLATE))
    wood_img.pack()
    mats = {
        "face": _material("shield_face", image=face_img, rough=0.78),
        "wood": _material("shield_wood", image=wood_img, rough=0.82),
        "leather": _material("shield_leather", colour=(0.20, 0.13, 0.08), rough=0.7),
        "iron": _material("shield_iron", colour=(0.30, 0.30, 0.31), rough=0.55, metal=0.85),
    }
    thick = {"heater": 0.016, "pavise": 0.020, "buckler": 0.012}[spec["kind"]]
    board = _grid_board(spec, name, [mats["face"], mats["wood"], mats["leather"]])
    parts = [board] + _fittings(spec, mats, thick)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = board
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    # Materials from fittings arrive in their own slots after the join; merge duplicates by name.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Build space: x right, y up, z toward the viewer. glTF export maps Blender z -> up and
    # Blender -y -> toward the viewer, so turn the board +90 deg about X (build y -> z, z -> -y)
    # and apply it; the sockets are placed at the same turned positions.
    obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    sockets = [_empty("socket_forearm", (0, thick + 0.03, 0)), _empty("socket_back", (0, thick, 0))]
    tris = sum(len(p.vertices) for p in obj.data.polygons) and sum(len(p.vertices) - 2 for p in obj.data.polygons)
    path = out_dir / spec["dir"] / "variants"
    path.mkdir(parents=True, exist_ok=True)
    glb = path / f"{name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", export_yup=True, export_apply=True,
        export_image_format="JPEG", export_jpeg_quality=88, export_materials="EXPORT",
    )
    dims = [round(v, 3) for v in obj.dimensions]
    info = {"name": name, "tris": tris, "dimensions_build_xyz": dims, "bytes": glb.stat().st_size, "path": str(glb.relative_to(ROOT))}
    print("SHIELD " + json.dumps(info))
    return info


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--only", nargs="*", default=[])
    p.add_argument("--out", default=str(ROOT / "assets/props/weapons"))
    args = p.parse_args(argv)
    for name, spec in VARIANTS.items():
        if args.only and name not in args.only:
            continue
        build(name, spec, Path(args.out))


main()
