"""Rig a Meshy image-to-3D human onto the shared HumanMotionRig.

Run headless:
  blender -b --factory-startup --python tools/assets/meshy_human/rig_meshy_human.py -- \
      --meshy build/<char>/<task>.glb \
      --donor assets/characters/realistic/<char>/<char>.glb \
      --out build/<char>/rig/<char>_meshy_rigged.glb

Why a donor: the MPFB build of the same character (ADR 0022) already carries the
71-bone HumanMotionRig in T-pose rest, the shared animation clips, separate
eye/hair meshes, and good skin weights. Meshy delivers one fused mesh with
painted eyes and no rig. We keep the Meshy surface (likeness) and borrow
everything else from the donor, so the result plays the shared clips unchanged.

Steps: normalise height -> cut eye openings (eyes found on the texture) ->
decimate -> pose donor arms to the Meshy A-pose -> transfer weights from the
posed donor -> inverse-skin the body into the donor T-pose rest -> fit donor
eyes (on new eye.l / eye.r bones) and hair -> even out over-red hands in the
albedo -> export GLB with all donor actions.

Input expectations: the Meshy source is a bald, nude (or underwear) A-pose
front image, arms clear of the torso, single image, no Meshy T-pose option.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils import geometry

DONOR_BODY_PREFIX = "Anatomy_"
DONOR_DROP = ("Anatomy_Head_Brows", "Anatomy_Head_Lashes", "Anatomy_Head_Teeth", "Clothing_")
HAND_GROUP_PREFIXES = ("hand.", "wrist.", "index_", "middle_", "ring_", "pinky_", "thumb_", "handslot.")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--meshy", required=True)
    p.add_argument("--donor", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--height", type=float, default=0.0, help="metres; default = donor height")
    p.add_argument("--target-tris", type=int, default=50000)
    p.add_argument("--eye-open-w", type=float, default=0.024, help="eye opening width, m")
    p.add_argument("--eye-open-h", type=float, default=0.011, help="eye opening height, m")
    p.add_argument("--iris-tint", default="0.42,0.52,0.40", help="RGB multiplier for donor iris; empty = keep")
    p.add_argument("--hair-donor", default="", help="GLB on the same rig whose Hair_* mesh to use (e.g. a braid)")
    p.add_argument("--hair", default="donor", choices=("donor", "none"), help="without --hair-donor: keep donor hair or none")
    p.add_argument("--no-hand-fix", action="store_true")
    p.add_argument("--debug-blend", default="", help="save a .blend with an is_arm colour layer after segmentation")
    return p.parse_args(argv)


def log(*a):
    print("[rig_meshy_human]", *a, flush=True)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def base_color_image(mat):
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = bsdf.inputs["Base Color"].links[0]
    node = link.from_node
    while node.type != "TEX_IMAGE":  # glTF import may put a mix/multiply in between
        node = next(i.links[0].from_node for i in node.inputs if i.is_linked)
    return node.image


def image_array(img):
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def world_verts(obj, mesh=None):
    mw = obj.matrix_world
    return [mw @ v.co for v in (mesh or obj.data).vertices]


# ---------------------------------------------------------------- donor

def load_donor(path):
    objs = import_glb(path)
    rig = next(o for o in objs if o.type == "ARMATURE")
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    meshes = {o.name: o for o in objs if o.type == "MESH"}
    for name, o in list(meshes.items()):
        if not o.vertex_groups:  # glTF importer's phantom Icosphere
            bpy.data.objects.remove(o, do_unlink=True)
            meshes.pop(name)
    return rig, meshes


def donor_height(meshes):
    zs = [p.z for o in meshes.values() if o.name.startswith(DONOR_BODY_PREFIX) for p in world_verts(o)]
    return min(zs), max(zs)


# ---------------------------------------------------------------- meshy

def load_meshy(path, height, ground):
    objs = import_glb(path)
    m = next(o for o in objs if o.type == "MESH")
    m.data.transform(m.matrix_world)
    m.matrix_world = Matrix()
    zs = [v.co.z for v in m.data.vertices]
    s = height / (max(zs) - min(zs))
    off = Vector((0, 0, min(zs)))
    for v in m.data.vertices:
        v.co = (v.co - off) * s + Vector((0, 0, ground))
    xs = [v.co.x for v in m.data.vertices]
    cx = (max(xs) + min(xs)) / 2
    for v in m.data.vertices:
        v.co.x -= cx
    m.name = "Body"
    return m


def face_texture_map(m, img, x0, x1, z0, z1, st=0.001):
    """Front orthographic ray grid over the face, sampling the albedo."""
    me = m.data
    me.calc_loop_triangles()
    tris = me.loop_triangles
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [t.vertices for t in tris])
    px = image_array(img)
    H, W = px.shape[:2]
    uv = me.uv_layers.active.data
    nx, nz = int((x1 - x0) / st), int((z1 - z0) / st)
    out = np.zeros((nz, nx, 3), np.float32)
    depth = np.full((nz, nx), np.nan, np.float32)
    e = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    for j in range(nz):
        for i in range(nx):
            loc, _n, idx, _d = bvh.ray_cast(Vector((x0 + i * st, -2.0, z0 + j * st)), Vector((0, 1, 0)))
            if idx is None:
                continue
            t = tris[idx]
            a, b, c = (me.vertices[k].co for k in t.vertices)
            w = geometry.barycentric_transform(loc, a, b, c, *e)
            u = sum(uv[t.loops[k]].uv[0] * w[k] for k in range(3))
            v = sum(uv[t.loops[k]].uv[1] * w[k] for k in range(3))
            out[j, i] = px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
            depth[j, i] = loc.y
    return out, depth


def find_eyes(m, img, donor_eye_z):
    """Locate both eye openings on the painted Meshy texture.

    Eye pixels: sclera (bright, unsaturated), pupil (dark) or green iris. The
    eye line is the z-histogram peak of those pixels near the donor eye line,
    which rejects nostrils and brows.
    """
    x0, x1, z0, z1, st = -0.09, 0.09, donor_eye_z - 0.05, donor_eye_z + 0.09, 0.001
    a, depth = face_texture_map(m, img, x0, x1, z0, z1, st)
    mx, mn = a.max(-1), a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    hit = ~np.isnan(depth)
    mask = hit & (((sat < 0.22) & (mx > 0.55)) | ((mx < 0.18) & (mx > 0.0)) | ((a[..., 1] > a[..., 0]) & (mx > 0.05)))
    J, I = np.indices(mask.shape)
    X, Z = x0 + I * st, z0 + J * st
    mask &= (np.abs(X) > 0.008) & (np.abs(X) < 0.06)
    rows = mask.sum(1).astype(np.float32)
    rows = np.convolve(rows, np.ones(9) / 9, mode="same")
    zc = z0 + int(rows.argmax()) * st
    mask &= np.abs(Z - zc) < 0.012
    eyes = {}
    for side, name in ((1, "l"), (-1, "r")):  # character left = +X (faces -Y)
        sm = mask & (X * side > 0)
        if sm.sum() < 20:
            raise RuntimeError(f"eye {name} not found ({int(sm.sum())} px)")
        cx, cz = float(X[sm].mean()), float(Z[sm].mean())
        i, j = int(round((cx - x0) / st)), int(round((cz - z0) / st))
        eyes[name] = Vector((cx, float(np.nanmin(depth[j - 2:j + 3, i - 2:i + 3])), cz))
    return eyes


def cut_eye_openings(m, eyes, w, h):
    bm = bmesh.new()
    bm.from_mesh(m.data)
    bm.faces.ensure_lookup_table()
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        for e in eyes.values():
            if f.normal.y < -0.2 and c.y < e.y + 0.012:
                if ((c.x - e.x) / (w / 2)) ** 2 + ((c.z - e.z) / (h / 2)) ** 2 < 1.0:
                    kill.append(f)
                    break
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(m.data)
    bm.free()
    log("eye faces removed", len(kill))


def decimate(m, target_tris):
    tris = sum(len(p.vertices) - 2 for p in m.data.polygons)
    if tris <= target_tris:
        return
    mod = m.modifiers.new("dec", "DECIMATE")
    mod.ratio = target_tris / tris
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(m.evaluated_get(dg))
    m.modifiers.remove(mod)
    old = m.data
    m.data = new
    bpy.data.meshes.remove(old)
    log("decimated", tris, "->", sum(len(p.vertices) - 2 for p in new.polygons))


# ---------------------------------------------------------------- arm fit

def arm_vertices(m, side, z_top, z_bot):
    """Indices of Meshy vertices on the free-hanging arm (beyond the torso gap)."""
    co = np.array([v.co for v in m.data.vertices])
    idx_all, cents, misses = [], [], 0
    for z in np.arange(z_top, z_bot, -0.01):
        band = np.nonzero((np.abs(co[:, 2] - z) < 0.005) & (co[:, 0] * side > 0.04))[0]
        if len(band) < 4:
            continue
        ax = np.abs(co[band, 0])
        order = np.argsort(ax)
        gaps = np.diff(ax[order])
        g = np.nonzero(gaps > 0.008)[0]
        if len(g) == 0:
            # Elbows or wrists can brush the waist for a few slices; only a long
            # run without a gap means we are past the fingertips.
            misses += 1
            if idx_all and misses > 8:
                break
            continue
        misses = 0
        arm = band[order[g[-1] + 1:]]
        idx_all.extend(arm.tolist())
        cents.append(co[arm].mean(0))
    return np.array(idx_all, int), np.array(cents)


def fit_arms(rig, m):
    """Rotate donor upper arms so the T-pose arms point along the Meshy arms."""
    for side, sfx in ((1, "l"), (-1, "r")):
        pb = rig.pose.bones[f"upperarm.{sfx}"]
        head = rig.matrix_world @ pb.bone.head_local
        idx, cents = arm_vertices(m, side, head.z - 0.08, 0.5)
        if len(cents) < 8:
            raise RuntimeError(f"arm {sfx}: no free-hanging arm found")
        # Direction: shoulder joint -> centroid of the lower half of the arm slices.
        tip = Vector(cents[len(cents) // 2:].mean(0))
        d = (tip - head).normalized()
        rest_dir = (rig.matrix_world.to_3x3() @ (pb.bone.tail_local - pb.bone.head_local)).normalized()
        q = rest_dir.rotation_difference(d)
        inv = rig.matrix_world.inverted()
        hl = pb.bone.head_local
        pb.matrix = Matrix.Translation(hl) @ (inv.to_3x3() @ q.to_matrix() @ rig.matrix_world.to_3x3()).to_4x4() @ Matrix.Translation(-hl) @ pb.bone.matrix_local
        bpy.context.view_layer.update()
        log(f"arm {sfx}: {math.degrees(rest_dir.angle(d)):.1f} deg from T, {len(idx)} verts")


# ---------------------------------------------------------------- weights

class DonorSurface:
    def __init__(self, objs):
        dg = bpy.context.evaluated_depsgraph_get()
        self.verts, self.tris, self.weights = [], [], []
        for o in objs:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            me.calc_loop_triangles()
            base = len(self.verts)
            names = [g.name for g in o.vertex_groups]
            self.verts.extend(o.matrix_world @ v.co for v in me.vertices)
            # Topology is unchanged by the armature modifier, so read weights from the original.
            for v in o.data.vertices:
                self.weights.append({names[g.group]: g.weight for g in v.groups if g.weight > 1e-4})
            self.tris.extend(tuple(base + k for k in t.vertices) for t in me.loop_triangles)
            ev.to_mesh_clear()
        self.bvh = BVHTree.FromPolygons(self.verts, self.tris)

    def sample(self, p):
        loc, _n, idx, _d = self.bvh.find_nearest(p)
        a, b, c = self.tris[idx]
        w = geometry.barycentric_transform(loc, self.verts[a], self.verts[b], self.verts[c],
                                           Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        out = {}
        for k, vi in enumerate((a, b, c)):
            wk = max(0.0, w[k])
            for g, gw in self.weights[vi].items():
                out[g] = out.get(g, 0.0) + gw * wk
        return out


def classify_arm_vertices(m, arm_surface, body_surface, rounds=4, min_island=400):
    """True for Meshy vertices that belong to the hanging arms.

    Hands and elbows rest against the hips in an A-pose, so plain nearest-surface
    transfer leaks hip weights into the arm. A vertex is arm when the posed donor
    arm surface is closer than the donor torso/legs, with a penalty when the
    surface faces the other way (inner arm vs outer hip), then smoothed by
    neighbour majority so islands do not tear off.
    """
    lab = []
    for v in m.data.vertices:
        score = []
        for surf in (arm_surface, body_surface):
            loc, nrm, _i, d = surf.bvh.find_nearest(v.co)
            score.append(d + (0.03 if nrm.dot(v.normal) < 0.0 else 0.0))
        lab.append(score[0] < score[1])
    # Meshy splits vertices along UV seams, so build connectivity on welded
    # positions; otherwise the body falls apart into hundreds of "islands".
    weld, canon = {}, []
    for v in m.data.vertices:
        canon.append(weld.setdefault(tuple(round(c, 5) for c in v.co), len(weld)))
    n_c = len(weld)
    votes = [[0, 0] for _ in range(n_c)]
    for i, arm in enumerate(lab):
        votes[canon[i]][arm] += 1
    clab = [vt[1] > vt[0] for vt in votes]
    nbr = [set() for _ in range(n_c)]
    for e in m.data.edges:
        a, b = canon[e.vertices[0]], canon[e.vertices[1]]
        if a != b:
            nbr[a].add(b)
            nbr[b].add(a)
    for _ in range(rounds):
        clab = [(sum(clab[j] for j in n) * 2 > len(n)) if n else clab[i] for i, n in enumerate(nbr)]
    # Fingertips pressed into the thigh read as body, and the thigh skin under the
    # hand reads as arm. Both are small same-label islands: flip them (decided on
    # a snapshot so a flip does not merge islands mid-scan).
    snap = list(clab)
    seen = [False] * n_c
    flipped = 0
    for start in range(n_c):
        if seen[start]:
            continue
        island, stack = [], [start]
        seen[start] = True
        while stack:
            i = stack.pop()
            island.append(i)
            for j in nbr[i]:
                if not seen[j] and snap[j] == snap[start]:
                    seen[j] = True
                    stack.append(j)
        if len(island) < min_island:
            for i in island:
                clab[i] = not snap[start]
            flipped += len(island)
    log("segmentation islands flipped", flipped, "of", n_c)
    return [clab[c] for c in canon]


def limit_normalize(w, n=4):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:n]
    s = sum(v for _k, v in top) or 1.0
    return {k: v / s for k, v in top if v / s > 1e-3}


def transfer_weights(m, body_parts, arm_parts):
    arm_surface = DonorSurface(arm_parts)
    body_surface = DonorSurface([o for o in body_parts if o not in arm_parts])
    full = DonorSurface(body_parts)  # shoulders blend torso and arm weights
    is_arm = classify_arm_vertices(m, arm_surface, body_surface)
    weights = []
    for v, arm in zip(m.data.vertices, is_arm):
        src = arm_surface if arm else full
        if not arm:
            w = full.sample(v.co)
            # A torso vertex that still picked up hand/forearm weight is a hip
            # touching the hand: take torso-only weights instead.
            if sum(gw for g, gw in w.items() if g.startswith(HAND_GROUP_PREFIXES + ("lowerarm.",))) > 0.2:
                w = body_surface.sample(v.co)
        else:
            w = src.sample(v.co)
        weights.append(limit_normalize(w))
    log("arm vertices", sum(is_arm), "of", len(is_arm))
    return weights, is_arm


def cut_arm_webbing(m, is_arm, z_max):
    """Meshy fuses hands and forearms to the hips where they touch in the source
    image; those bridging faces stretch into sheets once the arm moves. Delete
    faces that mix arm and body vertices below the armpit (vertices stay, so the
    weight list keeps its indices)."""
    bm = bmesh.new()
    bm.from_mesh(m.data)
    kill = [f for f in bm.faces
            if f.calc_center_median().z < z_max and len({is_arm[v.index] for v in f.verts}) > 1]
    bmesh.ops.delete(bm, geom=kill, context="FACES_ONLY")
    bm.to_mesh(m.data)
    bm.free()
    log("arm/body bridge faces removed", len(kill))


def action_fcurves(act):
    """F-curves of a Blender 4.4+ layered action, or a legacy one."""
    if getattr(act, "layers", None):
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    yield from bag.fcurves
    elif hasattr(act, "fcurves"):
        yield from act.fcurves


def bind_pose_as_rest(rig):
    """Make the fitted A-pose the rig rest/bind pose and keep every clip identical.

    glTF stores absolute local bone transforms, and the runtime ignores rest for
    animated bones, so only the clips need fixing: the bones whose rest we rotated
    (upper arms) get basis_new = Q^-1 @ basis_old, so rest_new @ basis_new ==
    rest_old @ basis_old on every frame. Children keep their rest relative to the
    parent and need nothing.
    """
    changed = {pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones if pb.matrix_basis != Matrix()}
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for act in bpy.data.actions:
        for name, Q in changed.items():
            qi = Q.to_quaternion().inverted()
            curves = {(fc.data_path.rsplit(".", 1)[1], fc.array_index): fc for fc in action_fcurves(act)
                      if fc.data_path.startswith(f'pose.bones["{name}"].')}
            for prop, n, ctor in (("rotation_quaternion", 4, Quaternion), ("location", 3, Vector)):
                fcs = [curves.get((prop, i)) for i in range(n)]
                if not all(fcs):
                    continue
                # Channels may carry different key counts: resample on the union of frames.
                frames = sorted({kp.co[0] for fc in fcs for kp in fc.keyframe_points})
                vals = [qi @ ctor([fc.evaluate(f) for fc in fcs]) for f in frames]
                for i, fc in enumerate(fcs):
                    fc.keyframe_points.clear()
                    fc.keyframe_points.add(len(frames))
                    for kp, f, v in zip(fc.keyframe_points, frames, vals):
                        kp.co = (f, v[i])
                        kp.interpolation = "LINEAR"
                    fc.update()
    log("bind pose applied to", sorted(changed))


def bind(obj, rig, weights_or_group):
    obj.vertex_groups.clear()
    if isinstance(weights_or_group, str):
        g = obj.vertex_groups.new(name=weights_or_group)
        g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    else:
        groups = {}
        for i, w in enumerate(weights_or_group):
            for name, gw in w.items():
                if name not in groups:
                    groups[name] = obj.vertex_groups.new(name=name)
                groups[name].add([i], gw, "REPLACE")
    for mod in [md for md in obj.modifiers if md.type == "ARMATURE"]:
        obj.modifiers.remove(mod)
    mw = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = mw
    obj.modifiers.new("Armature", "ARMATURE").object = rig


# ---------------------------------------------------------------- eyes, hair

def add_eye_bones(rig, eyes):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    inv = rig.matrix_world.inverted()
    for sfx, c in eyes.items():
        eb = rig.data.edit_bones.new(f"eye.{sfx}")
        eb.head = inv @ c
        eb.tail = inv @ (c + Vector((0, -0.025, 0)))
        eb.roll = 0.0
        eb.parent = rig.data.edit_bones["head"]
        eb.use_deform = True
    bpy.ops.object.mode_set(mode="OBJECT")


def fit_eyes(donor_eyes, rig, meshy_eyes, iris_tint):
    """Split the donor eye mesh per side and seat each ball behind the Meshy lids."""
    me = donor_eyes.data
    co = world_verts(donor_eyes)
    centres = {}
    for sfx, side in (("l", 1), ("r", -1)):
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (donor_eyes.matrix_world @ v.co).x * side < 0], context="VERTS")
        nm = bpy.data.meshes.new(f"Eye_{sfx}")
        bm.to_mesh(nm)
        bm.free()
        obj = bpy.data.objects.new(f"Eye_{sfx}", nm)
        bpy.context.scene.collection.objects.link(obj)
        obj.matrix_world = donor_eyes.matrix_world.copy()
        pts = [obj.matrix_world @ v.co for v in nm.vertices]
        front = min(p.y for p in pts)
        ball_c = Vector((sum(p.x for p in pts) / len(pts), (front + max(p.y for p in pts)) / 2, sum(p.z for p in pts) / len(pts)))
        tgt = meshy_eyes[sfx]
        # Cornea apex sits 1.5 mm behind the painted lid surface so the lid rim overlaps it.
        shift = Vector((tgt.x - ball_c.x, (tgt.y + 0.0015) - front, tgt.z - ball_c.z))
        nm.transform(obj.matrix_world.inverted() @ Matrix.Translation(shift) @ obj.matrix_world)
        centres[sfx] = ball_c + shift
        for mat in me.materials:
            nm.materials.append(mat)
        bind(obj, rig, f"eye.{sfx}")
    if iris_tint:
        tint = np.array([float(x) for x in iris_tint.split(",")], np.float32)
        for mat in me.materials:
            img = base_color_image(mat) if mat and mat.node_tree else None
            if img is None:
                continue
            px = image_array(img)
            rgb = px[..., :3]
            mx, mn = rgb.max(-1), rgb.min(-1)
            iris = ((mx - mn) / np.maximum(mx, 1e-4)) > 0.25  # coloured iris, not sclera
            lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
            # MPFB irises are dark brown; lift luminance or a light tint reads as black.
            rgb[iris] = np.clip((0.12 + lum[iris, None] * 1.9) * tint / tint.mean(), 0, 1)
            replace_image(img, px, "eyes_tinted")
    bpy.data.objects.remove(donor_eyes, do_unlink=True)
    return centres


def fit_hair(hair, donor_head, body, eye_z_donor, eye_z_meshy):
    """Per-axis affine map of the donor cranium box onto the Meshy cranium, then
    push any strand that ends up inside the scalp back out (shrinkwrap OUTSIDE)."""
    def cranium_box(pts, eye_z):
        sel = [p for p in pts if p.z > eye_z - 0.02 and abs(p.x) < 0.14]
        return [min(p[i] for p in sel) for i in range(3)], [max(p[i] for p in sel) for i in range(3)]
    dmn, dmx = cranium_box(world_verts(donor_head), eye_z_donor)
    mmn, mmx = cranium_box(world_verts(body), eye_z_meshy)
    S = [(mmx[i] - mmn[i]) / (dmx[i] - dmn[i]) for i in range(3)]
    mw = hair.matrix_world
    inv = mw.inverted()
    for v in hair.data.vertices:
        p = mw @ v.co
        v.co = inv @ Vector([mmn[i] + (p[i] - dmn[i]) * S[i] for i in range(3)])
    for mod in [md for md in hair.modifiers if md.type == "ARMATURE"]:
        hair.modifiers.remove(mod)
    sw = hair.modifiers.new("fit", "SHRINKWRAP")
    sw.target = body
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE"
    sw.offset = 0.003
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(hair.evaluated_get(dg))
    hair.modifiers.remove(sw)
    hair.data = new
    hair.modifiers.new("Armature", "ARMATURE").object = body.parent
    log("hair scale", [round(s, 3) for s in S])


# ---------------------------------------------------------------- texture

TEX_DIR = ""


def replace_image(old, px, name):
    """Write edited pixels to a new PNG and point every node at it.

    Editing a packed glTF image in place is lost on export: the exporter re-emits
    the original packed bytes. A fresh file-backed image is exported as edited.
    """
    h, w = px.shape[:2]
    new = bpy.data.images.new(name, w, h, alpha=True)
    new.pixels.foreach_set(px.ravel())
    new.filepath_raw = os.path.join(TEX_DIR, name + ".png")
    new.file_format = "PNG"
    new.save()
    for mat in bpy.data.materials:
        for node in (mat.node_tree.nodes if mat.node_tree else []):
            if node.type == "TEX_IMAGE" and node.image == old:
                node.image = new

def raster_uv_mask(me, faces, W, H):
    mask = np.zeros((H, W), np.float32)
    uv = me.uv_layers.active.data
    for p in faces:
        pts = [uv[li].uv for li in p.loop_indices]
        for k in range(1, len(pts) - 1):
            tri = np.array([pts[0], pts[k], pts[k + 1]]) * [W, H]
            x0, y0 = np.floor(tri.min(0)).astype(int)
            x1, y1 = np.ceil(tri.max(0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay), (bx, by), (cx, cy) = tri
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
            l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
            inside = (l1 >= -0.01) & (l2 >= -0.01) & (1 - l1 - l2 >= -0.01)
            mask[y0:y1 + 1, x0:x1 + 1][inside] = 1.0
    return mask


def box_blur(a, r):
    for axis in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode="edge"), axis=axis)
        a = (np.take(c, range(2 * r + 1, c.shape[axis]), axis) - np.take(c, range(0, c.shape[axis] - 2 * r - 1), axis)) / (2 * r + 1)
    return a


def fix_hand_colour(body, weights):
    """Meshy bakes the concept's flushed hands; match them to the forearm skin."""
    img = base_color_image(body.data.materials[0])
    px = image_array(img)
    H, W = px.shape[:2]
    def faces_where(pred):
        return [p for p in body.data.polygons if all(pred(weights[i]) for i in p.vertices)]
    is_hand = lambda w: sum(v for k, v in w.items() if k.startswith(HAND_GROUP_PREFIXES)) > 0.5
    is_fore = lambda w: sum(v for k, v in w.items() if k.startswith("lowerarm.")) > 0.6
    hand = raster_uv_mask(body.data, faces_where(is_hand), W, H)
    fore = raster_uv_mask(body.data, faces_where(is_fore), W, H)
    if hand.sum() < 50 or fore.sum() < 50:
        log("hand fix skipped")
        return
    rgb = px[..., :3]
    # Keep the hand's own luminance (creases, nails, shading) but take the
    # forearm's chroma; a per-channel mean ratio leaves saturated reds red.
    lum_w = np.array([0.2126, 0.7152, 0.0722], np.float32)
    fore_rgb = rgb[fore > 0].mean(0)
    chroma = fore_rgb / max(float(fore_rgb @ lum_w), 1e-4)
    lum = rgb @ lum_w
    lum = lum * (float((rgb[fore > 0] @ lum_w).mean()) / max(float(lum[hand > 0].mean()), 1e-4))
    target = np.clip(lum[..., None] * chroma, 0, 1)
    soft = np.clip(box_blur(hand, 6) * 1.5, 0, 1)[..., None]
    px[..., :3] = rgb * (1 - soft) + (target * 0.85 + rgb * 0.15) * soft
    replace_image(img, px, "body_albedo")
    log("hand recoloured to forearm chroma", [round(float(c), 3) for c in chroma])


# ---------------------------------------------------------------- main

def main():
    global TEX_DIR
    a = parse_args()
    TEX_DIR = os.path.splitext(os.path.abspath(a.out))[0] + "_textures"
    os.makedirs(TEX_DIR, exist_ok=True)
    clear_scene()
    rig, donor = load_donor(a.donor)
    gmin, gmax = donor_height(donor)
    height = a.height or (gmax - gmin)
    body = load_meshy(a.meshy, height, gmin)
    img = base_color_image(body.data.materials[0])
    donor_eyes = donor["Anatomy_Head_Eyes"]
    eye_z_donor = sum(p.z for p in world_verts(donor_eyes)) / len(donor_eyes.data.vertices)

    eyes = find_eyes(body, img, eye_z_donor)
    log("eyes", {k: tuple(round(x, 4) for x in v) for k, v in eyes.items()})
    cut_eye_openings(body, eyes, a.eye_open_w, a.eye_open_h)
    decimate(body, a.target_tris)

    body_parts = [o for n, o in donor.items() if n.startswith(DONOR_BODY_PREFIX) and not n.startswith(DONOR_DROP) and o is not donor_eyes]
    arm_parts = [donor[n] for n in ("Anatomy_Arms", "Anatomy_Forearms", "Anatomy_Hands")]
    fit_arms(rig, body)
    weights, is_arm = transfer_weights(body, body_parts, arm_parts)
    armpit_z = (rig.matrix_world @ rig.data.bones["upperarm.l"].head_local).z - 0.12
    cut_arm_webbing(body, is_arm, armpit_z)
    if a.debug_blend:
        attr = body.data.color_attributes.new("is_arm", "FLOAT_COLOR", "POINT")
        for i, arm in enumerate(is_arm):
            attr.data[i].color = (1, 0.1, 0.1, 1) if arm else (0.2, 0.4, 1, 1)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.debug_blend), copy=True)
        body.data.color_attributes.remove(attr)
    bind_pose_as_rest(rig)
    bind(body, rig, weights)

    # Eye bones pivot at the seated ball centres, so seat the meshes first.
    centres = fit_eyes(donor_eyes, rig, eyes, a.iris_tint)
    add_eye_bones(rig, centres)

    hair, hair_head, hair_eye_z = None, donor["Anatomy_Head"], eye_z_donor
    if a.hair_donor:
        # Same HumanMotionRig and T-pose rest, so the hair weights carry over by bone name.
        actions_before = set(bpy.data.actions)
        objs = import_glb(a.hair_donor)
        for act in set(bpy.data.actions) - actions_before:  # keep only the main donor's clips
            bpy.data.actions.remove(act)
        hair = next(o for o in objs if o.type == "MESH" and o.name.startswith("Hair"))
        hair_head = next(o for o in objs if o.type == "MESH" and o.name.split(".")[0] == "Anatomy_Head")
        he = next(o for o in objs if o.type == "MESH" and o.name.startswith("Anatomy_Head_Eyes"))
        hair_eye_z = sum(p.z for p in world_verts(he)) / len(he.data.vertices)
        mw = hair.matrix_world.copy()
        hair.parent = rig
        hair.matrix_world = mw
    elif a.hair != "none":
        hair = next((o for n, o in donor.items() if n.startswith("Hair")), None)
    if hair:
        fit_hair(hair, hair_head, body, hair_eye_z, eyes["l"].z)
        for mod in [md for md in hair.modifiers if md.type == "ARMATURE"]:
            mod.object = rig
    if a.hair_donor:
        for o in objs:
            if o is not hair:
                bpy.data.objects.remove(o, do_unlink=True)
    if a.hair_donor or a.hair == "none":
        for n, o in donor.items():
            if n.startswith("Hair"):
                bpy.data.objects.remove(o, do_unlink=True)
    if hair:
        hair.name = "Hair"

    if not a.no_hand_fix:
        fix_hand_colour(body, weights)

    for n in donor:
        o = bpy.data.objects.get(n)  # the donor eye mesh is already gone
        if o and (n.startswith(DONOR_BODY_PREFIX) or n.startswith("Clothing_")):
            bpy.data.objects.remove(o, do_unlink=True)

    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is rig or o.parent is rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True)
    report = {
        "out": a.out, "height_m": round(height, 3),
        "body_tris": sum(len(p.vertices) - 2 for p in body.data.polygons),
        "eyes": {k: [round(x, 4) for x in v] for k, v in centres.items()},
        "bones": len(rig.data.bones), "actions": len(bpy.data.actions),
        "meshes": sorted(o.name for o in bpy.data.objects if o.parent is rig),
    }
    with open(os.path.splitext(a.out)[0] + ".report.json", "w") as f:
        json.dump(report, f, indent=1)
    log("done", json.dumps(report))


main()
