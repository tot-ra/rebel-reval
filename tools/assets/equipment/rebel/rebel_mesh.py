"""Blender half of build_rebel_weapons.py (R-2014): mesh, materials, sockets, export.

Run only through the host driver, which writes build/rebel_weapons/<variant>/
(shape.json + albedo/normal/orm maps for photo items) first:

    python3 tools/assets/equipment/rebel/build_rebel_weapons.py --only club_oak_p1_w1

Builds by manifest `build`:
- `lathe` (clubs): rings along the silhouette's centre line, radius = half the
  photo width, UVs projected back onto the photo (the back half mirrors the
  front, the side the camera never saw);
- `flat` (sickle): the plate mask as a 3 mm plate, the grip turned round from
  its measured half-width, both projected onto the photo;
- `flail`, `fork`: procedural tubes on an ash plate, rawhide loops, cord mends.

Conventions (docs/SYSTEMS/EQUIPMENT_VARIANTS.md): long axis Godot +Y, flat face
Godot +Z, origin at the grip, socket empties as children. Prints one
`EQUIPMENT {json}` line.
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
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "build" / "rebel_weapons"
LEATHER = (0.20, 0.12, 0.065)
CORD = (0.15, 0.115, 0.075)


def _args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--manifest", required=True)
    p.add_argument("--variant", required=True)
    return p.parse_args(argv)


# ---------------------------------------------------------------- mesh accumulator


class Mesh:
    """Vertices, faces, per-loop UVs and a material index per face."""

    def __init__(self) -> None:
        self.v: list[tuple[float, float, float]] = []
        self.f: list[tuple[int, ...]] = []
        self.uv: list[list[tuple[float, float]]] = []
        self.mat: list[int] = []

    def add_vert(self, co) -> int:
        self.v.append((float(co[0]), float(co[1]), float(co[2])))
        return len(self.v) - 1

    def add_face(self, idx: tuple[int, ...], uvs: list[tuple[float, float]], mat: int) -> None:
        self.f.append(idx)
        self.uv.append(uvs)
        self.mat.append(mat)

    def tube(self, path: np.ndarray, radius, seg: int, mat: int, uv_repeat: float = 0.5,
             cap0: bool = True, cap1: bool = True, closed: bool = False, uv_fn=None) -> None:
        """Swept ring along `path` (n x 3), parallel-transport frames.

        radius(i, t, phi) -> metres; uv_fn(i, t, phi) -> (u, v) overrides the
        default wrap (u round the tube, v down its length in uv_repeat units)."""
        n = len(path)
        tang = np.gradient(path, axis=0)
        tang /= np.linalg.norm(tang, axis=1, keepdims=True)
        ref = np.array([1.0, 0.0, 0.0]) if abs(tang[0][0]) < 0.9 else np.array([0.0, 1.0, 0.0])
        nrm = np.cross(tang[0], ref)
        nrm /= np.linalg.norm(nrm)
        frames = []
        for i in range(n):
            if i:
                nrm = nrm - tang[i] * np.dot(nrm, tang[i])
                nrm /= np.linalg.norm(nrm)
            frames.append((nrm.copy(), np.cross(tang[i], nrm)))
        arc = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
        total = arc[-1] if arc[-1] > 0 else 1.0
        rings = []
        uvs = []
        for i in range(n):
            nn, bb = frames[i]
            t = arc[i] / total
            ring, ruv = [], []
            for s in range(seg + 1):
                phi = s / seg * math.tau
                r = radius(i, t, phi)
                co = path[i] + r * (math.cos(phi) * nn + math.sin(phi) * bb)
                ring.append(self.add_vert(co))
                ruv.append(uv_fn(i, t, phi) if uv_fn else (s / seg, arc[i] / uv_repeat))
            rings.append(ring)
            uvs.append(ruv)
        last = n if closed else n - 1
        for i in range(last):
            j = (i + 1) % n
            for s in range(seg):
                self.add_face(
                    (rings[i][s], rings[i][s + 1], rings[j][s + 1], rings[j][s]),
                    [uvs[i][s], uvs[i][s + 1], uvs[j][s + 1], uvs[j][s]], mat)
        if closed:
            return
        for end, cap in ((0, cap0), (n - 1, cap1)):
            if not cap:
                continue
            sign = -1.0 if end == 0 else 1.0
            r_end = radius(end, 0.0 if end == 0 else 1.0, 0.0)
            pole = self.add_vert(path[end] + tang[end] * sign * r_end * 0.35)
            pu = uv_fn(end, 0.0 if end == 0 else 1.0, math.pi * 0.5) if uv_fn else (0.5, arc[end] / uv_repeat + sign * 0.01)
            ring = rings[end]
            for s in range(seg):
                a, b = (ring[s + 1], ring[s]) if end == 0 else (ring[s], ring[s + 1])
                ua, ub = (uvs[end][s + 1], uvs[end][s]) if end == 0 else (uvs[end][s], uvs[end][s + 1])
                self.add_face((pole, a, b), [pu, ua, ub], mat)

    def build(self, name: str, mats: list[bpy.types.Material], smooth: bool = True) -> bpy.types.Object:
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f)
        uv = me.uv_layers.new(name="UVMap")
        for poly, puv, m in zip(me.polygons, self.uv, self.mat):
            poly.material_index = m
            poly.use_smooth = smooth
            for li, u in zip(poly.loop_indices, puv):
                uv.data[li].uv = u
        for m in mats:
            me.materials.append(m)
        me.validate()
        # Winding of the generated faces is not hand-checked: make every normal point out.
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# ---------------------------------------------------------------- materials


def _img(path: Path, data: bool) -> bpy.types.Image:
    img = bpy.data.images.load(str(path))
    if data:
        img.colorspace_settings.name = "Non-Color"
    return img


def _photo_material(name: str, work: Path) -> bpy.types.Material:
    """Base colour + normal + ORM (roughness G, metal B) from the prepared photo maps."""
    mat = bpy.data.materials.new(f"{name}_photo")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = _img(work / "albedo.png", False)
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    o = nt.nodes.new("ShaderNodeTexImage")
    o.image = _img(work / "orm.png", True)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(o.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = _img(work / "normal.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _plate_material(name: str, plate: str) -> bpy.types.Material:
    """Tileable wood plate (albedo, normal, roughness) from assets/materials/equipment/."""
    stem = Path(plate).name
    mat = bpy.data.materials.new(f"{name}_wood")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 0.0
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = _img(ROOT / plate / f"{stem}_albedo.png", False)
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeTexImage")
    r.image = _img(ROOT / plate / f"{stem}_roughness.png", True)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = _img(ROOT / plate / f"{stem}_normal.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _flat_material(name: str, rgb: tuple[float, float, float], rough: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    # Palette constants are sRGB; Blender factors are linear.
    bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in rgb], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


# ---------------------------------------------------------------- photo items


def build_lathe(it: dict, shape: dict, work: Path) -> tuple[bpy.types.Object, dict]:
    xs = np.array(shape["x"], np.float64)
    cs = np.array(shape["c"], np.float64)
    rs = np.array(shape["r"], np.float64)
    mpp = float(shape["m_per_px"])
    f, tw, th = float(shape["f"]), float(shape["tex_w"]), float(shape["tex_h"])
    xa, xb = xs[0], xs[-1]
    c_ref = float(np.median(cs))
    # Rings: half evenly spaced, half bunched toward the rounded ends.
    n = 72
    k = np.linspace(0, 1, n)
    t = 0.5 * k + 0.5 * (1 - np.cos(k * math.pi)) / 2
    xr = xa + 1.5 + t * (xb - xa - 3.0)
    cr = np.interp(xr, xs, cs)
    rr = np.maximum(np.interp(xr, xs, rs), 1.5)
    path = np.stack([-(cr - c_ref) * mpp, np.zeros(n), (xr - xa) * mpp], -1)
    lumps = float(it.get("lumps", 0.0))
    seed = sum(map(ord, it["variant"]))

    def radius(i: int, _t: float, phi: float) -> float:
        # Low-frequency knobbles on a natural club; the depth is a little under the width.
        z = xr[i] * mpp
        bump = math.sin(z * 23 + phi * 2 + seed) * math.sin(z * 9 - phi * 3 + seed * 0.7)
        oval = 1.0 - 0.05 * math.cos(phi) ** 2  # cos -> Blender Y, the depth the photo never saw
        return rr[i] * mpp * oval * (1.0 + lumps * bump)

    def uv(i: int, _t: float, phi: float) -> tuple[float, float]:
        # The tube frame starts at Blender +Y (normal) and -X (binormal), so a ring point
        # sits at X = -r sin(phi): the photo row across the club is c + r sin(phi). The
        # camera saw the face toward Blender -Y (Godot +Z); the back mirrors it.
        row = cr[i] + 0.9 * rr[i] * math.sin(phi)
        return (xr[i] * f / tw, 1.0 - row * f / th)

    m = Mesh()
    m.tube(path, radius, 16, 0, uv_fn=uv)
    obj = m.build(it["variant"], [_photo_material(it["variant"], work)])
    length = float(path[-1][2] - path[0][2])
    pivot = float(it["pivot_from_base_m"])
    return obj, {"pivot": pivot, "socket_tip": length, "socket_butt": 0.0}


def _mask_from_png(path: Path) -> np.ndarray:
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1, :, 0] > 0.5  # Blender rows run bottom-up


def build_flat(it: dict, shape: dict, work: Path) -> tuple[bpy.types.Object, dict]:
    mask = _mask_from_png(work / "plate_mask.png")
    mpp = float(shape["m_per_px"])
    f, tw, th = float(shape["f"]), float(shape["tex_w"]), float(shape["tex_h"])
    g0 = np.array(shape["grip_g0"])
    a = np.array(shape["grip_a"])
    b = np.array([-a[1], a[0]])
    glen = float(shape["grip_len_px"])
    thick = float(it["blade_thick_m"])

    def to_blender(px: np.ndarray) -> tuple[float, float]:
        rel = px - g0
        return float(rel @ b) * mpp, float(rel @ a) * mpp  # (X across, Z along the grip)

    def px_uv(px) -> tuple[float, float]:
        return (px[0] * f / tw, 1.0 - px[1] * f / th)

    # Plate: one quad per 4 px cell inside the mask, dissolved to an outline, smoothed.
    cell = 4
    h, w = mask.shape
    bm = bmesh.new()
    verts: dict[tuple[int, int], bmesh.types.BMVert] = {}

    def vert(i: int, j: int) -> bmesh.types.BMVert:
        key = (i, j)
        if key not in verts:
            verts[key] = bm.verts.new((i * cell, j * cell, 0.0))
        return verts[key]

    for j in range(h // cell):
        for i in range(w // cell):
            if mask[min(h - 1, j * cell + cell // 2), min(w - 1, i * cell + cell // 2)]:
                bm.faces.new((vert(i, j), vert(i + 1, j), vert(i + 1, j + 1), vert(i, j + 1)))
    bmesh.ops.dissolve_faces(bm, faces=list(bm.faces), use_verts=True)
    bm.verts.ensure_lookup_table()
    for _ in range(4):
        new = {}
        for face in bm.faces:
            loop = list(face.verts)
            for k, v in enumerate(loop):
                p, q = loop[k - 1].co, loop[(k + 1) % len(loop)].co
                new[v] = v.co * 0.5 + (p + q) * 0.25
        for v, co in new.items():
            v.co = co
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(5), verts=list(bm.verts), edges=list(bm.edges))
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
    m = Mesh()
    bm.verts.index_update()
    base_top = {}
    base_bot = {}
    for v in bm.verts:
        px, py = v.co.x, v.co.y
        x, z = to_blender(np.array([px, py]))
        base_top[v.index] = m.add_vert((x, -thick / 2, z))
        base_bot[v.index] = m.add_vert((x, thick / 2, z))
    for face in bm.faces:
        ids = [v.index for v in face.verts]
        uvs = [px_uv((v.co.x, v.co.y)) for v in face.verts]
        m.add_face(tuple(base_top[i] for i in ids), uvs, 0)
        m.add_face(tuple(base_bot[i] for i in reversed(ids)), list(reversed(uvs)), 0)
    for e in bm.edges:
        if not e.is_boundary:
            continue
        v0, v1 = e.verts
        # Keep the rim's winding with its face: walk the face loop's direction.
        loop = e.link_loops[0]
        if loop.vert is not v0:
            v0, v1 = v1, v0
        u0, u1 = px_uv((v0.co.x, v0.co.y)), px_uv((v1.co.x, v1.co.y))
        m.add_face((base_top[v1.index], base_top[v0.index], base_bot[v0.index], base_bot[v1.index]), [u1, u0, u0, u1], 0)
    bm.free()

    # Grip: turned round from the measured half-width, projected onto the photo.
    st = np.array(shape["grip_stations"])
    half = np.array(shape["grip_half"])
    ns = 20
    ss = np.linspace(st[0] + 1, st[-1] - 1, ns)
    hs = np.maximum(np.interp(ss, st, half), 2.0)
    path = np.stack([np.zeros(ns), np.zeros(ns), ss * mpp], -1)

    def radius(i: int, _t: float, phi: float) -> float:
        return hs[i] * mpp

    def uv(i: int, _t: float, phi: float) -> tuple[float, float]:
        px = g0 + a * ss[i] + b * (0.9 * hs[i] * math.cos(phi))
        return px_uv(px)

    plate_faces = len(m.f)
    m.tube(path, radius, 14, 0, uv_fn=uv)
    obj = m.build(it["variant"], [_photo_material(it["variant"], work)], smooth=False)
    # Blade faces flat-shaded, the turned grip smooth.
    for poly in obj.data.polygons:
        poly.use_smooth = poly.index >= plate_faces
    co = np.array([v.co for v in obj.data.vertices])
    pivot = glen * mpp * 0.5
    d = np.hypot(co[:, 0], co[:, 2] - pivot)
    tip = co[int(np.argmax(d))]
    return obj, {"pivot": pivot, "socket_butt": 0.0, "socket_tip_xyz": [float(tip[0]), float(tip[2]), float(-tip[1])]}


# ---------------------------------------------------------------- procedural poles


def _coil(m: Mesh, centre_at, r_at, z0: float, z1: float, turns: float, mat: int) -> None:
    """Cord wound round a pole between heights z0..z1 (centre_at(z) -> xyz, r_at(z) -> pole radius)."""
    n = int(turns * 14)
    pts = []
    for k in range(n + 1):
        u = k / n
        z = z0 + (z1 - z0) * u
        ang = u * turns * math.tau
        c = np.array(centre_at(z))
        r = r_at(z) + 0.0018
        pts.append(c + np.array([r * math.cos(ang), r * math.sin(ang), 0.0]))
    m.tube(np.array(pts), lambda i, t, p: 0.0024, 6, mat, uv_repeat=0.05)


def _torus(m: Mesh, centre, axis_a, axis_b, major: float, minor: float, mat: int) -> None:
    pts = [np.array(centre) + major * (math.cos(t) * np.array(axis_a) + math.sin(t) * np.array(axis_b))
           for t in np.linspace(0, math.tau, 24, endpoint=False)]
    m.tube(np.array(pts), lambda i, t, p: minor, 8, mat, closed=True, uv_repeat=0.05)


def build_flail(it: dict) -> tuple[bpy.types.Object, dict]:
    m = Mesh()
    L = float(it["staff_m"])
    B = float(it["beater_m"])
    zs = np.linspace(0, L, 27)
    staff = np.stack([0.006 * np.sin(np.pi * zs / L), np.zeros_like(zs), zs], -1)
    m.tube(staff, lambda i, t, p: 0.0165 - 0.0015 * t, 12, 0)
    # Rawhide cap over the staff head, the staff loop above it.
    cz = np.linspace(L - 0.055, L + 0.004, 4)
    m.tube(np.stack([np.zeros(4), np.zeros(4), cz], -1), lambda i, t, p: 0.0182, 12, 1, uv_repeat=0.05)
    R = 0.016
    top = L + 0.004 + R * 0.75
    _torus(m, (0.0, 0.0, top), (1, 0, 0), (0, 0, 1), R, 0.0035, 1)
    # Beater hangs from the link, swung 12 degrees out so it clears the staff.
    tilt = math.radians(12)
    d = np.array([math.sin(tilt), 0.0, -math.cos(tilt)])
    t0 = np.array([0.04, 0.0, L - 0.004])
    ss = np.linspace(0, B, 15)
    beater = t0 + ss[:, None] * d

    def r_beater(i: int, t: float, p: float) -> float:
        neck = min(1.0, ss[i] / 0.05)
        return 0.0125 + (0.0195 + 0.002 * t - 0.0125) * neck

    m.tube(beater, r_beater, 12, 0)
    band = t0 + np.linspace(0.0, 0.04, 3)[:, None] * d
    m.tube(band, lambda i, t, p: 0.0145, 12, 1, cap0=False, cap1=False, uv_repeat=0.05)
    # Beater loop: through the staff loop and round the beater neck.
    _torus(m, ((0.0 + t0[0]) * 0.5 + 0.006, 0.0, top - R * 0.55), (0, 1, 0), (0, 0, 1), R * 0.95, 0.0035, 1)
    if it.get("mend"):
        _coil(m, lambda z: (0.006 * math.sin(math.pi * z / L), 0.0, z), lambda z: 0.0153, L - 0.25, L - 0.20, 5, 1)
        # Crack in the beater bound tight: wound about the beater's own axis.
        n = 70
        pts = []
        for k in range(n + 1):
            u = k / n
            c = t0 + d * (0.26 + 0.07 * u)
            ang = u * 6 * math.tau
            e1 = np.array([0.0, 1.0, 0.0])
            e2 = np.cross(d, e1)
            pts.append(c + 0.0215 * (math.cos(ang) * e1 + math.sin(ang) * e2))
        m.tube(np.array(pts), lambda i, t, p: 0.0024, 6, 1, uv_repeat=0.05)
    obj = m.build(it["variant"], [_plate_material(it["variant"], it["plate"]),
                                  _flat_material(f"{it['variant']}_rawhide", LEATHER, 0.72)])
    end = t0 + d * B
    return obj, {"pivot": float(it["pivot_from_base_m"]), "socket_butt": 0.0, "socket_tip": top + R,
                 "extra": {"socket_beater": [float(end[0]), float(end[2]), float(-end[1])]}}


def build_fork(it: dict) -> tuple[bpy.types.Object, dict]:
    m = Mesh()
    L = float(it["stem_m"])
    seed = sum(map(ord, it["variant"])) * 0.01
    zs = np.linspace(0, L, 31)
    wob = lambda z: (0.008 * math.sin(2.1 * z + seed) + 0.004 * math.sin(5.3 * z), 0.006 * math.sin(1.7 * z + 2 * seed))
    stem = np.array([[*wob(z), z] for z in zs])
    knots = [(0.23, 0.6), (0.51, 2.9), (0.78, 4.7)]

    def r_stem(i: int, t: float, phi: float) -> float:
        z = zs[i]
        r = 0.0175 - 0.002 * t
        r += 0.0065 * max(0.0, (z - (L - 0.13)) / 0.13) ** 2  # swelling into the crotch
        for kt, ka in knots:
            da = (phi - ka + math.pi) % math.tau - math.pi
            r += 0.0035 * math.exp(-((t - kt) / 0.018) ** 2 - (da / 0.6) ** 2)
        return r

    m.tube(stem, r_stem, 12, 0)
    top = stem[-1]
    tip_top = 0.0
    for side, tl in zip((1.0, -1.0), it["tines_m"]):
        full = max(it["tines_m"])
        broken = tl < 0.75 * full
        n = 12
        ss = np.linspace(0, tl, n)
        u = ss / full
        pts = np.stack([top[0] + side * (0.006 + 0.30 * ss - 0.10 * ss * u),
                        top[1] - 0.06 * u ** 2,
                        top[2] - 0.04 + ss * 0.98], -1)

        def r_tine(i: int, t: float, phi: float, broken=broken, u=u) -> float:
            r = 0.0145 - 0.006 * u[i]
            if not broken and u[i] > 0.8:
                r *= max(0.12, (1.0 - u[i]) / 0.2)  # whittled point
            return r

        m.tube(pts, r_tine, 10, 0, cap0=False)
        tip_top = max(tip_top, float(pts[-1][2]))
    if it.get("mend"):
        _coil(m, lambda z: (*wob(z), z), lambda z: 0.0175 + 0.0065 * max(0.0, (z - (L - 0.13)) / 0.13) ** 2,
              L - 0.10, L - 0.035, 6, 1)
    obj = m.build(it["variant"], [_plate_material(it["variant"], it["plate"]),
                                  _flat_material(f"{it['variant']}_cord", CORD, 0.9)])
    return obj, {"pivot": float(it["pivot_from_base_m"]), "socket_butt": 0.0, "socket_tip": tip_top}


# ---------------------------------------------------------------- export


def _tris(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _decimate(obj: bpy.types.Object, budget: int) -> None:
    if budget and _tris(obj) > budget:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = budget / _tris(obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)


def _export(path: Path, objects: list) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=88, export_yup=True, export_apply=True)


def main() -> None:
    a = _args()
    man = json.loads(Path(a.manifest).read_text())
    it = next(i for i in man["items"] if i["variant"] == a.variant)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    work = WORK / it["variant"]
    shape = json.loads((work / "shape.json").read_text())
    obj, info = {
        "lathe": lambda: build_lathe(it, shape, work),
        "flat": lambda: build_flat(it, shape, work),
        "flail": lambda: build_flail(it),
        "fork": lambda: build_fork(it),
    }[it["build"]]()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    pivot = info["pivot"]
    obj.data.transform(Matrix.Translation((0, 0, -pivot)))
    obj.data.update()
    bpy.context.view_layer.update()
    # Sockets in Godot metres (x, y, z = Blender x, z, -y) relative to the grip.
    sockets = {"socket_grip": [0.0, 0.0, 0.0], "socket_butt": [0.0, round(info["socket_butt"] - pivot, 3), 0.0]}
    if "socket_tip" in info:
        sockets["socket_tip"] = [0.0, round(info["socket_tip"] - pivot, 3), 0.0]
    if "socket_tip_xyz" in info:
        x, y, z = info["socket_tip_xyz"]
        sockets["socket_tip"] = [round(x, 3), round(y - pivot, 3), round(z, 3)]
    for k, (x, y, z) in info.get("extra", {}).items():
        sockets[k] = [round(x, 3), round(y - pivot, 3), round(z, 3)]
    empties = []
    for sname, (gx, gy, gz) in sorted(sockets.items()):
        e = bpy.data.objects.new(sname, None)
        e.location = (gx, -gz, gy)
        bpy.context.scene.collection.objects.link(e)
        empties.append(e)
    _decimate(obj, int(man["tris"]))
    out = ROOT / man["out_dir"] / it["family"] / "variants" / f"{it['variant']}.glb"
    _export(out, [obj, *empties])
    lod0 = _tris(obj)
    _decimate(obj, int(man["lod1_tris"]))
    lod1 = _tris(obj)
    _export(ROOT / "build" / "equipment" / f"{it['variant']}_lod1.glb", [obj, *empties])
    co = np.array([v.co for v in obj.data.vertices])
    lo, hi = co.min(0), co.max(0)
    print("EQUIPMENT " + json.dumps({
        "variant": it["variant"],
        "out": str(out.relative_to(ROOT)),
        "lod0_tris": lod0,
        "lod1_tris": lod1,
        "godot_size_xyz": [round(float(hi[0] - lo[0]), 3), round(float(hi[2] - lo[2]), 3), round(float(hi[1] - lo[1]), 3)],
        "sockets": sockets,
    }))


main()
