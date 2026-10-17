#!/usr/bin/env python3
"""Project-authored draught/cob horse surface (replaces the Hunyuan3D pack horse).

Builds the standing horse as anatomical masses (elliptical lofts for trunk, neck,
head and limb segments, ellipsoids for muscle and joints), welds them with a
voxel remesh, smooths the union, then adds eyes, ears, mane, forelock, tail and
fetlock feathering as separate hair shells. The bay coat (black points, a star
and one white hind sock) is stored as vertex colour with low-frequency shading.

Output is a static, unrigged source GLB at build/animal_redo/sources/horse.glb;
`tools/assets/import_realistic_mammals.py --only horse` rigs and animates it
exactly like the other mammals. Blender coordinates: +Z up, -Y toward the nose,
feet on Z=0, metres.

  blender -b --python tools/assets/build_horse_source.py -- [--preview DIR]
"""
from __future__ import annotations
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'build/animal_redo/sources/horse.glb'
VOXEL = 0.014
BODY_TRIANGLES = 30000
# Head frame: P0 is the top of the poll between the ears; the axis runs poll to
# muzzle, pitched THETA below horizontal; v is the offset toward the face.
HEAD_P0 = (1.00, 1.83)  # (forward, height)
HEAD_THETA = math.radians(56.0)
HEAD_LENGTH = 0.625
HS = 1.08  # head scale about the poll
SEED = 1343


def fz(f: float, z: float, x: float = 0.0) -> Vector:
    """Anatomical (forward, height, lateral) to Blender (x, y, z): nose is -Y."""
    return Vector((x, -f, z))


def _frame(tangent: Vector) -> tuple[Vector, Vector]:
    lateral = Vector((1.0, 0.0, 0.0))
    a = lateral - tangent * lateral.dot(tangent)
    if a.length < 1e-6:
        a = Vector((0.0, 1.0, 0.0))
    a.normalize()
    return a, tangent.cross(a).normalized()


def loft(name: str, nodes, sides: int = 16, cap: bool = True):
    """Closed tube through nodes (position, lateral radius, profile radius).
    A node may be (position, rl, rp, squareness) for a boxier section."""
    bm = bmesh.new()
    rings = []
    for i, node in enumerate(nodes):
        pos, rl, rp = node[0], node[1], node[2]
        square = node[3] if len(node) > 3 else 0.0
        if i == 0:
            t = nodes[1][0] - pos
        elif i == len(nodes) - 1:
            t = pos - nodes[i - 1][0]
        else:
            t = nodes[i + 1][0] - nodes[i - 1][0]
        a, b = _frame(t.normalized())
        ring = []
        for k in range(sides):
            ang = math.tau * k / sides
            c, s = math.cos(ang), math.sin(ang)
            # Superellipse: square 0 is an ellipse, towards 1 a rounded box.
            e = 2.0 / (2.0 + 6.0 * square)
            c = math.copysign(abs(c) ** e, c)
            s = math.copysign(abs(s) ** e, s)
            ring.append(bm.verts.new(pos + a * (c * rl) + b * (s * rp)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new(
                (rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k])
            )
    if cap:
        for ring, node in ((rings[0], nodes[0]), (rings[-1], nodes[-1])):
            centre = bm.verts.new(node[0])
            for k in range(sides):
                bm.faces.new((ring[k], ring[(k + 1) % sides], centre))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _commit(name, bm)


def blob(name: str, centre: Vector, radii, rotate_x: float = 0.0, rotate_z: float = 0.0):
    """Ellipsoid with radii (lateral x, along y, vertical z)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=1.0)
    rot = Matrix.Rotation(rotate_z, 3, 'Z') @ Matrix.Rotation(rotate_x, 3, 'X')
    for v in bm.verts:
        p = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
        v.co = centre + rot @ p
    return _commit(name, bm)


def _commit(name: str, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def mirror(builder, **kw):
    return [builder(sign=s, **kw) for s in (1.0, -1.0)]


# ---------------------------------------------------------------- anatomy

def trunk_and_neck():
    parts = []
    # Stations rump to chest: forward, top line, belly line, half width.
    stations = [
        (-0.84, 1.40, 1.14, 0.085),
        (-0.77, 1.43, 1.02, 0.169),
        (-0.62, 1.48, .91, 0.243),
        (-0.46, 1.50, .85, 0.262),
        (-0.28, 1.44, .79, 0.243),
        (-0.08, 1.42, .73, 0.251),
        (0.14, 1.44, .69, 0.262),
        (0.34, 1.49, .69, 0.251),
        (0.50, 1.50, .73, 0.232),
        (0.64, 1.45, .79, 0.209),
        (0.74, 1.36, .88, 0.175),
        (0.80, 1.27, .96, 0.130),
    ]
    parts.append(loft('trunk', [
        (fz(f, (top + belly) / 2), w, (top - belly) / 2, .04) for f, top, belly, w in stations
    ], sides=26))
    # Neck rises from the withers/chest to the poll; crest convex, throat slim.
    neck = [
        (0.50, 1.28, 0.209, .320),
        (0.65, 1.43, 0.176, .275),
        (0.78, 1.57, 0.143, .228),
        (0.88, 1.66, 0.119, .178),
        (0.935, 1.725, 0.101, .125),
    ]
    parts.append(loft('neck', [(fz(f, z), rl, rp) for f, z, rl, rp in neck], sides=18))
    # Withers ridge, loin and croup definition.
    parts.append(blob('withers', fz(0.45, 1.49), (.060, .20, .065)))
    parts.append(blob('crest', fz(0.84, 1.70), (.040, .20, .050), rotate_x=-0.85))
    return parts


def hp(u: float, v: float = 0.0, w: float = 0.0) -> Vector:
    """Head-local (along the axis, toward the face, lateral) to world."""
    f = HEAD_P0[0] + HS * (math.cos(HEAD_THETA) * u + math.sin(HEAD_THETA) * v)
    z = HEAD_P0[1] + HS * (-math.sin(HEAD_THETA) * u + math.cos(HEAD_THETA) * v)
    return fz(f, z, w * HS)


def to_head(p: Vector) -> tuple[float, float]:
    """World point to head-local (u, v)."""
    df, dz = (-p.y - HEAD_P0[0]) / HS, (p.z - HEAD_P0[1]) / HS
    u = df * math.cos(HEAD_THETA) - dz * math.sin(HEAD_THETA)
    v = df * math.sin(HEAD_THETA) + dz * math.cos(HEAD_THETA)
    return u, v


HEAD_TILT = -(math.pi / 2 - HEAD_THETA)  # blob rotate_x that aligns a vertical blob with the head axis


def head():
    parts = []
    # u, face-side edge, throat-side edge, half width, squareness.
    stations = [
        (0.000, .050, -.078, .058, .08),
        (0.050, .068, -.104, .080, .08),
        (0.110, .078, -.138, .094, .10),
        (0.190, .068, -.168, .094, .10),
        (0.270, .056, -.150, .082, .12),
        (0.350, .048, -.108, .063, .18),
        (0.440, .046, -.076, .054, .20),
        (0.510, .050, -.074, .059, .14),
        (0.565, .054, -.080, .066, .06),
        (0.605, .050, -.078, .064, .0),
        (0.632, .036, -.058, .046, .0),
    ]
    parts.append(loft('face', [
        (hp(u, (vf + vb) / 2), w * HS, (vf - vb) / 2 * HS, sq) for u, vf, vb, w, sq in stations
    ], sides=20))
    for sign in (1.0, -1.0):
        # Orbit and brow over the eye, masseter on the cheek, raised nostril wings.
        parts.append(blob('orbit', hp(0.115, 0.024, .082 * sign), (0.0238, 0.0324, 0.0324), rotate_x=HEAD_TILT))
        parts.append(blob('cheek', hp(0.200, -0.110, .062 * sign), (0.0346, 0.0648, 0.0670), rotate_x=HEAD_TILT))
        parts.append(blob('nostril', hp(0.566, 0.026, .038 * sign), (0.0173, 0.0238, 0.0324), rotate_x=HEAD_TILT))
    parts.append(blob('chin', hp(0.590, -0.060), (0.0346, 0.0432, 0.0389), rotate_x=HEAD_TILT))
    return parts


def scale_about(parts, pivot: Vector, factor: float, shift: Vector = Vector()):
    for obj in parts:
        for v in obj.data.vertices:
            v.co = pivot + (v.co - pivot) * factor + shift
    return parts


def foreleg(sign: float):
    x = .125 * sign
    parts = []
    parts.append(loft('arm', [
        (fz(0.50, 1.00, .105 * sign), .078, .130),
        (fz(0.43, 0.86, x), .074, .105),
    ], sides=14))
    parts.append(blob('elbow', fz(0.31, 0.83, .150 * sign), (.050, .070, .070)))
    parts.append(loft('forearm', [
        (fz(0.43, 0.88, x + .02 * sign), .080, .105),
        (fz(0.44, 0.70, x + .005 * sign), .070, .084),
        (fz(0.465, 0.52, x), .052, .056),
    ], sides=14))
    parts.append(blob('chestnut_knee', fz(0.475, 0.50, x), (.050, .052, .055)))
    parts.append(loft('cannon', [
        (fz(0.465, 0.50, x), .046, .050),
        (fz(0.462, 0.36, x), .036, .046, .25),
        (fz(0.46, 0.24, x), .036, .048, .25),
    ], sides=12))
    parts.append(blob('fetlock', fz(0.455, 0.205, x), (.040, .056, .052)))
    parts.append(loft('pastern', [
        (fz(0.455, 0.215, x), .040, .046),
        (fz(0.505, 0.100, x), .040, .046),
    ], sides=12))
    parts.append(loft('hoof', [
        (fz(0.500, 0.105, x), .050, .056),
        (fz(0.522, 0.050, x), .058, .068),
        (fz(0.545, 0.000, x), .064, .080, .3),
    ], sides=14))
    return parts


def hindleg(sign: float):
    x = .140 * sign
    parts = []
    parts.append(blob('stifle', fz(-0.30, 0.97, .150 * sign), (.075, .105, .095)))
    parts.append(loft('gaskin', [
        (fz(-0.52, 1.20, .115 * sign), .130, .225),
        (fz(-0.50, 0.98, .120 * sign), .108, .175),
        (fz(-0.60, 0.78, .105 * sign), .074, .128),
        (fz(-0.72, 0.57, x), .050, .085),
    ], sides=16))
    parts.append(blob('hock', fz(-0.735, 0.54, x), (.052, .075, .070)))
    parts.append(loft('hind_cannon', [
        (fz(-0.725, 0.50, x), .046, .058),
        (fz(-0.700, 0.36, x), .036, .048, .25),
        (fz(-0.680, 0.24, x), .036, .048, .25),
    ], sides=12))
    parts.append(blob('hind_fetlock', fz(-0.675, 0.205, x), (.040, .056, .052)))
    parts.append(loft('hind_pastern', [
        (fz(-0.675, 0.215, x), .040, .046),
        (fz(-0.630, 0.100, x), .040, .046),
    ], sides=12))
    parts.append(loft('hind_hoof', [
        (fz(-0.630, 0.105, x), .050, .056),
        (fz(-0.610, 0.050, x), .058, .066),
        (fz(-0.588, 0.000, x), .064, .078, .3),
    ], sides=14))
    return parts


def weld(parts, name: str):
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = name
    body.data.name = name
    body.data.remesh_voxel_size = VOXEL
    body.data.remesh_voxel_adaptivity = 0.0
    bpy.ops.object.voxel_remesh()
    # Blend the masses into one skin: smooth the union, then restore volume.
    smooth = body.modifiers.new('smooth', 'CORRECTIVE_SMOOTH')
    smooth.iterations = 30
    smooth.smooth_type = 'SIMPLE'
    smooth.rest_source = 'BIND'
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    lap = body.modifiers.new('lap', 'SMOOTH')
    lap.factor = 0.5
    lap.iterations = 10
    bpy.ops.object.modifier_apply(modifier=lap.name)
    for poly in body.data.polygons:
        poly.use_smooth = True
    return body


# ---------------------------------------------------------------- hair
#
# Mane, forelock and tail are hair cards: thin quad ribbons textured with a
# strand atlas whose alpha is clipped (glTF alphaMode MASK, Godot alpha
# scissor). Solid tubes read as plastic fringes; layered cards with a few
# hundred painted strands each give the soft, broken silhouette of real hair
# at a fraction of the strand-geometry cost.

ATLAS_SIZE = 1024
ATLAS_COLUMNS = 8  # each column is one strand clump; cards sample one column
# Where hair() roots its cards: the mane runs back from MANE_POLL_F (forward
# position at the poll) over MANE_SPAN along the crest; the tail plume roots on
# the dock between DOCK_ROOT and DOCK_TIP (forward, height). Defaults fit this
# file's lofted body; tools/assets/meshy_animal/rig_meshy_quadruped.py rebinds
# them (and HEAD_P0/HEAD_THETA/HS for the forelock) to a scanned body.
MANE_POLL_F = 1.03
MANE_SPAN = 0.66
DOCK_ROOT = (-0.835, 1.405)
DOCK_TIP = (-0.905, 1.15)


def hair_atlas(rng: random.Random):
    """Straight-alpha RGBA strand atlas. V runs root (0) to tip (1); every
    column holds one clump of tapered strands with ragged tip lengths."""
    import numpy as np
    n = ATLAS_SIZE
    col_w = n // ATLAS_COLUMNS
    rgb = np.zeros((n, n, 3), dtype=np.float32)
    alpha = np.zeros((n, n), dtype=np.float32)
    rows = np.arange(n, dtype=np.float32) / (n - 1)  # v, root to tip
    nrng = np.random.default_rng(SEED)
    for col in range(ATLAS_COLUMNS):
        x0 = col * col_w
        for _ in range(150):
            length = rng.uniform(.55, 1.0)
            # Strand path across the column: a drift plus a slow wave.
            cx = rng.uniform(.10, .90) * col_w
            drift = rng.uniform(-.18, .18) * col_w
            wave = rng.uniform(1.0, 4.0)
            phase = rng.uniform(0, math.tau)
            xs = cx + drift * rows + wave * np.sin(phase + rows * rng.uniform(4, 11))
            width = rng.uniform(.7, 1.7)
            opacity = rng.uniform(.65, 1.0)
            # Bay mane: near-black with a few rusty, sun-bleached strands.
            tone = rng.random()
            if tone < .80:
                c = np.array([.018, .014, .012]) * rng.uniform(.8, 1.6)
            elif tone < .95:
                c = np.array([.055, .030, .018]) * rng.uniform(.8, 1.3)
            else:
                c = np.array([.12, .060, .030])
            # Ragged roots too: strands start at slightly different heights, so
            # the root edge of a card never reads as a cut line.
            start = rng.uniform(0, .07)
            live = (rows <= length) & (rows >= start)
            taper = np.clip((length - rows) / .18, 0, 1)  # thin to a point at the tip
            for dx in range(-2, 3):
                px = np.floor(xs).astype(int) + dx
                cover = np.clip(width * taper - np.abs(px + .5 - xs) + .5, 0, 1) * opacity
                cover = np.where(live & (px >= 0) & (px < col_w), cover, 0.0)
                cols = np.clip(px, 0, col_w - 1) + x0
                idx = np.nonzero(cover > 0)[0]
                if not len(idx):
                    continue
                prev = alpha[idx, cols[idx]]
                # Root-to-tip shading: darker at the root, a faint sheen mid-length.
                shade = (0.85 + 0.35 * np.sin(np.pi * rows[idx]))[:, None]
                w = cover[idx][:, None]
                rgb[idx, cols[idx]] = rgb[idx, cols[idx]] * (1 - w) + c * shade * w
                alpha[idx, cols[idx]] = prev + (1 - prev) * cover[idx]
        # Fade the clump edges so card borders never show as a straight line.
        edge = np.minimum(np.arange(col_w), col_w - 1 - np.arange(col_w)) / (col_w * .12)
        alpha[:, x0:x0 + col_w] *= np.clip(edge, 0, 1)[None, :]
    # Uncovered texels take the mean strand colour so mip filtering does not
    # bleed a light fringe around the clipped edges.
    rgb[alpha < .01] = (.02, .015, .013)
    rgba = np.dstack([rgb, alpha]).astype(np.float32)
    rgba += nrng.normal(0, .002, rgba.shape).astype(np.float32) * (rgba[..., 3:4] > 0)
    img = bpy.data.images.new('horse_hair_strands', ATLAS_SIZE, ATLAS_SIZE, alpha=True)
    img.alpha_mode = 'STRAIGHT'
    # Blender image rows run bottom to top; v=0 (root) is the bottom row.
    img.pixels.foreach_set(np.clip(rgba, 0, 1).ravel())
    img.pack()
    return img


class Cards:
    """Accumulates hair cards into one bmesh with a UV layer."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UVMap')

    def add(self, points, outward, width0: float, width1: float, column: int):
        """Ribbon through `points` (root first). `outward(p)` is the direction the
        card faces; its width lies across the tangent, in the surface plane."""
        n = len(points)
        u0 = column / ATLAS_COLUMNS + .004
        u1 = (column + 1) / ATLAS_COLUMNS - .004
        rows = []
        for i, p in enumerate(points):
            t = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
            side = t.cross(outward(p))
            # A tangent along the facing direction has no defined width axis.
            side = side.normalized() if side.length > 1e-5 else Vector((0.0, 1.0, 0.0))
            w = (width0 + (width1 - width0) * i / (n - 1)) / 2
            rows.append((self.bm.verts.new(p - side * w), self.bm.verts.new(p + side * w)))
        for i in range(n - 1):
            a, b = rows[i]
            c, d = rows[i + 1]
            face = self.bm.faces.new((a, b, d, c))
            v0, v1 = i / (n - 1), (i + 1) / (n - 1)
            for loop, uv in zip(face.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
                loop[self.uv].uv = uv

    def commit(self):
        return _commit(self.name, self.bm)


def surface_x(tree, y: float, z: float) -> float:
    """Lateral (+x) surface of the body at a given height and station."""
    hit = tree.ray_cast(Vector((0.8, y, z)), Vector((-1, 0, 0)))
    return hit[0].x if hit[0] is not None else 0.0


def hair(rng: random.Random, crest, tree):
    mane = Cards('mane')
    # Mane: a cob's mane lies on the near (+x) side. Each lock rises from the
    # crest, arches over it and falls along the neck; three layers stand off the
    # skin a little more each so the inner ones fill and the outer ones break up.
    side_out = lambda p: Vector((1.0, 0.0, 0.25)).normalized()
    for layer in range(3):
        count = (42, 36, 26)[layer]
        stand = .006 + .010 * layer
        for i in range(count):
            t = (i + rng.uniform(-.3, .3)) / (count - 1)
            f = MANE_POLL_F - MANE_SPAN * min(1.0, max(0.0, t))
            y = -f
            top = crest(f)
            length = rng.uniform(.17, .27) * (0.80 + 0.30 * math.sin(math.pi * min(1.0, t * 1.1)))
            length *= (1.0, .92, .80)[layer]
            # Behind the poll the mane is short (the bridle path), else it hangs over the jowl.
            length *= .45 + .55 * min(1.0, max(0.0, (MANE_POLL_F - .03 - f) / .10))
            phase = rng.uniform(0, math.tau)
            arch = top + rng.uniform(-.002, .008) + .003 * layer
            pts = [Vector((-.012, y, top - .010)), Vector((surface_x(tree, y, top - .015) * .45, y, arch))]
            for k in range(1, 7):
                u = k / 6.0
                z = top - .012 - length * u
                sway = .010 * math.sin(phase + u * 3.6)
                lift = stand + .012 * u * u
                pts.append(Vector((surface_x(tree, y, z) + lift, y + .028 * u * u + sway, z)))
            mane.add(pts, side_out, rng.uniform(.010, .016), rng.uniform(.040, .056), rng.randrange(ATLAS_COLUMNS))

    forelock = Cards('forelock')
    # Forelock: overlapping cards from the poll falling down the forehead.
    face_out = (hp(0.1, 1.0) - hp(0.1, 0.0)).normalized()
    for i in range(14):
        w = rng.uniform(-.026, .026)
        pts = []
        for k in range(6):
            u = k / 5.0
            pts.append(hp(-.012 + .230 * u, .050 + .014 * math.sin(math.pi * u) + .004, w * (1 + u * .8) + .006 * math.sin(i + u * 3)))
        forelock.add(pts, lambda p: face_out, rng.uniform(.010, .016), rng.uniform(.020, .030), rng.randrange(ATLAS_COLUMNS))

    tail = Cards('tail')
    # Tail: hair grows from the whole dock, so cards root along it on a ring and
    # fall as a plume that widens slightly and ends ragged.
    dock_root = fz(*DOCK_ROOT)
    dock_tip = fz(*DOCK_TIP)
    for i in range(130):
        a = rng.uniform(0, math.tau)
        s = rng.uniform(0.0, 1.0)
        root = dock_root.lerp(dock_tip, s)
        ring = Vector((math.cos(a) * .040, -abs(math.sin(a)) * .030 - .010, 0.0))
        base = root + ring
        length = rng.uniform(.72, 1.05) - .20 * s
        phase = rng.uniform(0, math.tau)
        flare = Vector((math.cos(a) * .075, -.040 * abs(math.sin(a)) + .03, 0.0))
        pts = []
        for k in range(8):
            u = k / 7.0
            # Arch back off the dock, then hang; a slow wave breaks the plume.
            back = Vector((0.0, .085 * math.sin(min(1.0, u * 2.2) * math.pi / 2) + .02 * u, 0.0))
            pts.append(base + back + flare * u + Vector((.012 * math.sin(phase + u * 5.0) * u, 0.0, -length * u)))
        centre = dock_root + Vector((0.0, .06, 0.0))
        tail.add(pts, lambda p, c=centre: Vector((p.x - c.x, p.y - c.y, 0.0)).normalized() if (p.x - c.x) ** 2 + (p.y - c.y) ** 2 > 1e-8 else Vector((0, 1, 0)),
                 rng.uniform(.050, .070), rng.uniform(.055, .080), rng.randrange(ATLAS_COLUMNS))
    return {'mane': mane.commit(), 'forelock': forelock.commit(), 'tail': tail.commit()}


def ears():
    out = []
    for sign in (1.0, -1.0):
        base = hp(0.026, -0.034, .046 * sign)
        k = HS
        out.append(loft('ear', [
            (base, 0.0324, 0.0162),
            (base + fz(-0.006, .040, .008 * sign), 0.0367, 0.0184),
            (base + fz(-0.008, .088, .019 * sign), 0.0346, 0.0184),
            (base + fz(0.002, .134, .029 * sign), 0.0238, 0.0140),
            (base + fz(0.020, .170, .034 * sign), 0.0097, 0.0076),
            (base + fz(0.034, .188, .036 * sign), 0.0022, 0.0022),
        ], sides=12))
    return out


EYE_RADIUS = .027  # a horse eye is about 5 cm across, among the largest of land mammals


def eyes(tree):
    """Eyeball set into the orbit plus an almond lid ring of dark bare skin.
    The ball is placed from the welded head surface so it neither floats nor
    disappears under the skin; about a third of it shows through the lids."""
    balls, lids = [], []
    axis = (hp(1.0) - hp(0.0)).normalized()  # poll to muzzle
    for sign in (1.0, -1.0):
        anchor = hp(0.128, -0.030, 0.0)
        hit = tree.ray_cast(anchor + Vector((.5 * sign, 0, 0)), Vector((-sign, 0, 0)))
        surface = hit[0] if hit[0] is not None else hp(0.128, -0.030, .09 * sign)
        # Eyes face sideways and a little forward.
        out = (Vector((sign, 0, 0)) + axis * .30).normalized()
        centre = surface - out * EYE_RADIUS * .40
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=32, radius=EYE_RADIUS)
        rot = out.to_track_quat('Z', 'Y').to_matrix()
        for v in bm.verts:
            v.co = centre + rot @ Vector((v.co.x * 1.15, v.co.y * .90, v.co.z))
        balls.append(_commit('eye', bm))
        # Lid ring: an elliptical torus around the visible part of the ball, its
        # long axis along the head, upper lid heavier than the lower.
        bm = bmesh.new()
        ring_n, tube_n = 32, 8
        long_axis = (axis - out * axis.dot(out)).normalized()
        up = out.cross(long_axis).normalized()
        if up.z < 0:
            up = -up
        # Ring sits where the ball surface meets the opening, half sunk in skin.
        lid_c = centre + out * EYE_RADIUS * .34
        grid = []
        for i in range(ring_n):
            a = math.tau * i / ring_n
            upper = math.sin(a) > 0
            ax, ay = EYE_RADIUS * 1.02, EYE_RADIUS * (.74 if upper else .62)
            # Almond: the opening narrows toward the corners.
            p = lid_c + long_axis * (math.cos(a) * ax) + up * (math.sin(a) * ay * (1 - .25 * abs(math.cos(a)) ** 3))
            radial = (long_axis * math.cos(a) + up * math.sin(a)).normalized()
            r = (.0070 if upper else .0050) * (1 - .25 * abs(math.cos(a)) ** 4)
            row = []
            for j in range(tube_n):
                b = math.tau * j / tube_n
                row.append(bm.verts.new(p + (radial * math.cos(b) + out * math.sin(b)) * r - out * r * .2))
            grid.append(row)
        for i in range(ring_n):
            for j in range(tube_n):
                bm.faces.new((grid[i][j], grid[(i + 1) % ring_n][j], grid[(i + 1) % ring_n][(j + 1) % tube_n], grid[i][(j + 1) % tube_n]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        lids.append(_commit('eyelid', bm))
    return balls, lids, axis


def paint_eye(eye, axis):
    """Dark brown iris band with a horizontal black pupil and a thin dark rim;
    the glossy material supplies the catch-light."""
    mesh = eye.data
    layer = mesh.color_attributes.new('Col', 'BYTE_COLOR', 'POINT')
    centre = sum((v.co for v in mesh.vertices), Vector()) / len(mesh.vertices)
    for i, v in enumerate(mesh.vertices):
        d = v.co - centre
        sign = 1.0 if centre.x > 0 else -1.0
        out = (Vector((sign, 0, 0)) + axis * .30).normalized()
        along = d.dot(out) / EYE_RADIUS  # 1 at the cornea pole
        long_axis = (axis - out * axis.dot(out)).normalized()
        lx = d.dot(long_axis) / EYE_RADIUS
        ly = d.dot(out.cross(long_axis)) / EYE_RADIUS
        c = (0.030, 0.016, 0.009)  # iris
        if along < .55:
            c = (0.020, 0.012, 0.008)  # dark sclera hidden by the lids
        elif (lx / .55) ** 2 + (ly / .26) ** 2 < 1.0:
            c = (0.004, 0.003, 0.003)  # horizontal pupil
        elif (lx / .78) ** 2 + (ly / .62) ** 2 < 1.0:
            c = (0.060, 0.030, 0.013)  # warm inner iris
        layer.data[i].color = (*c, 1.0)


# ---------------------------------------------------------------- colour

def _noise(p: Vector, scale: float, seed: int) -> float:
    """Smooth value noise in [0, 1] from lattice hashes."""
    q = p / scale
    i = Vector((math.floor(q.x), math.floor(q.y), math.floor(q.z)))
    f = q - i

    def h(ix, iy, iz):
        n = int(ix) * 73856093 ^ int(iy) * 19349663 ^ int(iz) * 83492791 ^ seed * 2654435761
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return (n ^ (n >> 16)) / 0xFFFFFFFF

    def s(t):
        return t * t * (3 - 2 * t)

    fx, fy, fzz = s(f.x), s(f.y), s(f.z)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fzz if dz else 1 - fzz)
                out += w * h(i.x + dx, i.y + dy, i.z + dz)
    return out


def _lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def paint_body(body, crest=None):
    """Bay: warm brown, lighter muzzle ring and belly, black legs below the
    knees/hocks, dark muzzle, a thin star and one white hind sock."""
    mesh = body.data
    layer = mesh.color_attributes.new('Col', 'BYTE_COLOR', 'POINT')
    bay = (0.245, 0.115, 0.052)
    light = (0.320, 0.165, 0.080)
    dark = (0.020, 0.014, 0.012)
    white = (0.62, 0.60, 0.56)
    for i, v in enumerate(mesh.vertices):
        p = v.co
        f, z, x = -p.y, p.z, p.x
        c = bay
        # Dappled shading and large-scale tone variation.
        tone = 0.55 * _noise(p, .18, 3) + 0.30 * _noise(p, .07, 5) + 0.15 * _noise(p, .03, 9)
        c = _lerp(bay, light, (tone - .35) * 1.6)
        # Belly and flank inner thigh lighter, spine line slightly darker.
        c = _lerp(c, light, (1.0 - (z - .70) / .25) * .6 if z < .95 and abs(f) < .6 else 0.0)
        c = _lerp(c, (0.12, 0.045, 0.02), max(0.0, (z - 1.40) / .10) * .7 if abs(x) < .05 else 0.0)
        # Skin under the mane is dark, so no gap shows between locks.
        if crest is not None and .38 < f < 1.05 and abs(x) < .10 and z > crest(f) - .06 and z > 1.35:
            c = _lerp(c, (0.025, 0.018, 0.015), .9)
        # Black points: lower legs (blend above the knee/hock), ears, muzzle.
        leg = z < .70 and abs(f) < .90 and (f > .3 or f < -.4)
        if leg:
            c = _lerp(c, dark, (.70 - z) / .16)
        # Head: dark muzzle skin, nostrils, eye rims, a narrow star.
        hu, hv = to_head(p)
        if 0.0 <= hu <= 0.66 and -0.2 < hv < 0.12 and z > 1.15:
            if hu > .50:
                c = _lerp(c, (0.075, 0.052, 0.045), (hu - .50) / .05)
            if hu > .55 and hv > .02 and abs(x) > .014 and abs(x) < .052:
                c = _lerp(c, (0.012, 0.008, 0.007), min(1.0, (hu - .55) / .02) * .95)
            if .06 < hu < .20 and hv > .03 and abs(x) < .017:
                c = _lerp(c, white, .85)
            # Mouth cleft: a dark line along the lips, up the cheek.
            if .43 < hu < .60 and abs(hv + .045) < .006 and abs(x) > .01:
                c = _lerp(c, (0.03, 0.02, 0.018), .85)
            eye_d = math.hypot(hu - .125, (hv + .032)) 
            if abs(x) > .06 and eye_d < .052:
                c = _lerp(c, (0.04, 0.020, 0.012), (0.052 - eye_d) / .022)
        if x > 0 and f < -.55 and z < .27:
            c = _lerp(c, white, ((.27 - z) / .05))
        # Hooves: dark horn, lighter where the sock is.
        if z < .085 and abs(f) > .3:
            c = _lerp(c, (0.045, 0.036, 0.03) if not (x > 0 and f < -.55) else (0.30, 0.27, 0.22), .95)
        layer.data[i].color = (*c, 1.0)
    return layer


def crest_height_fn(body):
    """Height of the neck's top line at forward position f, ray-cast on the body."""
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(body, deps)

    def crest(f: float) -> float:
        hit = tree.ray_cast(Vector((0.0, -f, 3.0)), Vector((0, 0, -1)))
        return hit[0].z if hit[0] is not None else 1.6

    return crest, tree


def paint_flat(obj, rgb, jitter=0.0, rng=None):
    mesh = obj.data
    layer = mesh.color_attributes.new('Col', 'BYTE_COLOR', 'POINT')
    for i in range(len(mesh.vertices)):
        k = 1.0 + (rng.uniform(-jitter, jitter) if rng else 0.0)
        layer.data[i].color = (rgb[0] * k, rgb[1] * k, rgb[2] * k, 1.0)


def make_material(name: str, roughness: float):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes['Principled BSDF']
    attr = tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Col'
    tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = 0.0
    return mat


def make_hair_material(atlas):
    """Strand atlas as base colour and clipped alpha. The ROUND node is how the
    glTF exporter recognises alpha clipping (alphaMode MASK, cutoff 0.5)."""
    mat = bpy.data.materials.new('horse_hair')
    mat.use_nodes = True
    mat.use_backface_culling = False  # cards are seen from both sides
    tree = mat.node_tree
    bsdf = tree.nodes['Principled BSDF']
    tex = tree.nodes.new('ShaderNodeTexImage')
    tex.image = atlas
    clip = tree.nodes.new('ShaderNodeMath')
    clip.operation = 'ROUND'
    tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    tree.links.new(tex.outputs['Alpha'], clip.inputs[0])
    tree.links.new(clip.outputs['Value'], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 0.75
    bsdf.inputs['Metallic'].default_value = 0.0
    return mat


# ---------------------------------------------------------------- main

def preview(path: Path, objs):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1100, 800
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.43, .50, .55, 1)
    scene.world = world
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.lens = 90
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    path.mkdir(parents=True, exist_ok=True)
    views = {
        'side': (Vector((10.0, -0.15, 1.0)), Vector((0, -0.2, 0.95))),
        'three_quarter': (Vector((6.5, -6.5, 2.4)), Vector((0, -0.2, 1.0))),
        'front': (Vector((0.4, -9.0, 1.2)), Vector((0, 0, 1.0))),
        'head': (Vector((2.6, -1.2, 1.65)), Vector((0, -1.15, 1.58))),
        'head34': (Vector((1.8, -3.0, 1.9)), Vector((0, -1.1, 1.6))),
        'ref34': (Vector((5.2, -4.4, 1.9)), Vector((0, -0.2, 1.0))),
        'eye': (Vector((0.75, -1.35, 1.80)), Vector((0.09, -1.05, 1.70))),
        'tail': (Vector((3.2, 3.6, 1.6)), Vector((0, 0.75, 1.0))),
    }
    for name, (loc, look) in views.items():
        cam.location = loc
        cam.rotation_euler = (look - loc).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(path / f'{name}.png')
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    preview_dir = Path(argv[argv.index('--preview') + 1]) if '--preview' in argv else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(SEED)

    parts = trunk_and_neck() + head()
    parts += foreleg(1.0) + foreleg(-1.0) + hindleg(1.0) + hindleg(-1.0)
    body = weld(parts, 'horse_body')
    paint_body(body, crest_height_fn(body)[0])
    body.data.materials.append(make_material('horse_coat', 0.82))
    # Collapse to the runtime budget after painting: colour survives collapse.
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    bpy.context.view_layer.objects.active = body
    dec = body.modifiers.new('budget', 'DECIMATE')
    dec.ratio = min(1.0, BODY_TRIANGLES / tris)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in body.data.polygons:
        poly.use_smooth = True

    hair_mat = make_hair_material(hair_atlas(rng))
    crest, tree = crest_height_fn(body)
    shells = []
    for group, cards in hair(rng, crest, tree).items():
        cards.name = f'horse_{group}'
        for poly in cards.data.polygons:
            poly.use_smooth = True
        cards.data.materials.append(hair_mat)
        shells.append(cards)
    for ear in ears():
        for poly in ear.data.polygons:
            poly.use_smooth = True
        paint_flat(ear, (0.15, 0.06, 0.028))
        ear.data.materials.append(make_material('horse_ear', 0.85))
        shells.append(ear)
    balls, lids, axis = eyes(tree)
    eye_mat = make_material('horse_eye', 0.04)
    for eye in balls:
        for poly in eye.data.polygons:
            poly.use_smooth = True
        paint_eye(eye, axis)
        eye.data.materials.append(eye_mat)
        shells.append(eye)
    lid_mat = make_material('horse_eyelid', 0.55)
    for lid in lids:
        for poly in lid.data.polygons:
            poly.use_smooth = True
        paint_flat(lid, (0.022, 0.014, 0.011))
        lid.data.materials.append(lid_mat)
        shells.append(lid)

    everything = [body] + shells
    if preview_dir:
        preview(preview_dir, everything)
    # Join everything into one skinned-ready surface? Keep hair/eyes as separate
    # meshes so the rig importer weights them by region like the body.
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    for obj in bpy.data.objects:
        obj.select_set(obj in everything)
    bpy.ops.export_scene.gltf(
        filepath=str(SOURCE), export_format='GLB', use_selection=True, export_yup=True,
        export_apply=False, export_attributes=True
    )
    tris = sum(len(p.vertices) - 2 for o in everything for p in o.data.polygons)
    pts = [o.matrix_world @ v.co for o in everything for v in o.data.vertices]
    lo = Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    print('bounds', tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi))
    print(f'horse source: {len(everything)} meshes, {tris} triangles -> {SOURCE}')


if __name__ == '__main__':
    main()
