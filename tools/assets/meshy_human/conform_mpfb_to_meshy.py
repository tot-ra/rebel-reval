"""Conform a character's MPFB body to a Meshy scan: Meshy shape + texture, MPFB topology.

  blender -b --factory-startup --python tools/assets/meshy_human/conform_mpfb_to_meshy.py -- \
      --meshy build/<char>_meshy/<task>.glb \
      --donor assets/characters/realistic/<char>/<char>.glb \
      --out build/<char>_meshy/conform/<char>_conformed.glb [--tex 2048] [--keep-hair]

Why: a raw Meshy mesh is scan-like topology. It deforms badly at the armpits and
has no eyelids, lips or edge loops for facial animation. The MPFB build of the
same character has all of that (71-bone rig, weights, 76 clips, eyeballs,
lashes, brows, teeth and face shape keys). So we keep MPFB and only move its
surface onto the Meshy shape and bake the Meshy albedo into the MPFB UVs.

Steps:
  1. Scale the Meshy scan to the donor height; pose the donor arms and legs
     along the scan limbs (the scan is a wide T-pose).
  2. Fit the head rigidly (skull ICP for tilt and depth, painted eye line for
     height); the turn becomes the `head` pose, the shift part of the offset.
  3. Per vertex, project the posed MPFB surface onto the scan (normal ray, then
     nearest), reject wild hits, and smooth the displacement on welded
     topology. Full-detail displacement on body skin; only the smooth
     low-frequency part on hands, lips, nose and ears; lids move rigidly with
     the eyeball; mouth/nostril/ear cavities follow the skin around them.
  4. Bake the scan albedo onto the conformed posed MPFB skin (Cycles,
     selected-to-active), with tinted donor skin on the lids and cavities.
  5. Carry the displacement (without the head shift) back to rest with each
     vertex's inverse skinning matrix and add it to every shape key, so
     blink/smile/jaw keep working. Eyes and lashes follow their lid ring,
     teeth the nearest skin vertex; the headcloth keeps its donor fit.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, geometry
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

BODY = "Anatomy_"
FACE_PARTS = ("Anatomy_Head_Eyes", "Anatomy_Head_Lashes", "Anatomy_Head_Brows", "Anatomy_Head_Teeth")
HAND_GROUPS = ("hand.", "wrist.", "index_", "middle_", "ring_", "pinky_", "thumb_")


def log(*a):
    print("[conform]", *a, flush=True)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--meshy", required=True)
    p.add_argument("--donor", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--tex", type=int, default=2048)
    p.add_argument("--max-dist", type=float, default=0.045, help="reject scan hits farther than this, m")
    p.add_argument("--smooth-iters", type=int, default=40)
    p.add_argument("--keep-hair", action="store_true")
    p.add_argument("--keep-brows", action="store_true",
                   help="keep the MPFB brow mesh (the scan albedo usually paints brows lower)")
    p.add_argument("--headcloth", default="", help="wearable GLB on the same rig (e.g. the widow's linen headscarf)")
    p.add_argument("--debug-blend", default="")
    return p.parse_args(argv)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    return [o for o in bpy.data.objects if o not in before]


# ---------------------------------------------------------------- inputs

def load_wearable(path, rig):
    """Import a wearable GLB built on the same rig and rebind its meshes to `rig`."""
    acts = set(bpy.data.actions)
    objs = import_glb(path)
    meshes = [o for o in objs if o.type == "MESH" and o.vertex_groups]
    arms = [o for o in objs if o.type == "ARMATURE"]
    for o in [o for o in objs if o not in meshes and o not in arms]:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = mw
        for m in o.modifiers:
            if m.type == "ARMATURE":
                m.object = rig
    for o in arms:
        bpy.data.objects.remove(o, do_unlink=True)
    for act in set(bpy.data.actions) - acts:
        bpy.data.actions.remove(act)
    log("wearable", [o.name for o in meshes])
    return meshes


def clear_cloth(cloth, skin, gap=0.004):
    """Push cloth vertices that the new body shape swallowed back out by `gap` (rest pose, basis only)."""
    bm = bmesh.new()
    for o in skin:
        me = o.data
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(o.matrix_world)
        me2 = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me2)
        tmp.free()
        bm.from_mesh(me2)
        bpy.data.meshes.remove(me2)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    moved = 0
    for o in cloth:
        mw, mwi = o.matrix_world, o.matrix_world.inverted()
        for v in o.data.vertices:
            p = mw @ v.co
            hit, n, _i, _d = bvh.find_nearest(p, 0.05)
            if hit is not None and (p - hit).dot(n) < gap:
                v.co = mwi @ (hit + n * gap)
                moved += 1
    log(f"headcloth: {moved} vertices pushed out of the body")


def load_donor(path, keep_hair, keep_brows=False):
    objs = import_glb(path)
    rig = next(o for o in objs if o.type == "ARMATURE")
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix()
    for o in list(objs):
        if o.type != "MESH":
            continue
        drop = (not o.vertex_groups or o.name.startswith("Clothing_") or (o.name.startswith("Hair") and not keep_hair)
                or (o.name == "Anatomy_Head_Brows" and not keep_brows))
        if drop:
            objs.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    skin = [o for o in objs if o.type == "MESH" and o.name.startswith(BODY) and o.name not in FACE_PARTS]
    face = [o for o in objs if o.type == "MESH" and o.name in FACE_PARTS]
    other = [o for o in objs if o.type == "MESH" and o not in skin and o not in face]
    return rig, skin, face, other


_SCAN_CO0 = {}


def load_scan(path):
    objs = import_glb(path)
    m = next(o for o in objs if o.type == "MESH" and len(o.data.vertices) > 1000)
    for o in objs:
        if o is not m and o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    m.data.transform(m.matrix_world)
    m.parent = None
    m.matrix_world = Matrix()
    m.name = "Scan"
    _SCAN_CO0[m.name] = np.array([v.co for v in m.data.vertices])
    return m


def place_scan(m, z0, height, y_torso):
    """Scale the original scan to `height`, stand it on z0, centre x, and match the torso depth."""
    co = _SCAN_CO0[m.name].copy()
    s = height / (co[:, 2].max() - co[:, 2].min())
    co = (co - [0, 0, co[:, 2].min()]) * s + [0, 0, z0]
    co[:, 0] -= (co[:, 0].max() + co[:, 0].min()) / 2
    zr = z0 + height * np.array([0.55, 0.7])  # belly to chest
    torso = co[(np.abs(co[:, 0]) < 0.1) & (co[:, 2] > zr[0]) & (co[:, 2] < zr[1])]
    co[:, 1] += y_torso - (torso[:, 1].max() + torso[:, 1].min()) / 2
    m.data.vertices.foreach_set("co", co.ravel())
    m.data.update()


def world_co(objs, evaluated=True):
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        me = o.evaluated_get(dg).to_mesh() if evaluated else o.data
        out.append(np.array([o.matrix_world @ v.co for v in me.vertices]))
        if evaluated:
            o.evaluated_get(dg).to_mesh_clear()
    return out


# ---------------------------------------------------------------- limb fit

def principal_dir(pts, hint):
    c = pts.mean(0)
    _u, _s, vt = np.linalg.svd(pts - c, full_matrices=False)
    d = Vector(vt[0])
    return d if d.dot(hint) > 0 else -d


def axis_fit(pts, root, d, t0, t1, n=7):
    """Limb axis direction between distances t0..t1 from `root` along `d`.

    Surface-point PCA on a short, thick segment (a thigh) picks its width, not
    its length. Cross-section centroids lie on the axis of a tube, so fit the
    line through those instead; re-slice twice with the refined axis.
    """
    root = np.array(root)
    for _ in range(3):
        dv = np.array(d)
        t = (pts - root) @ dv
        cents = [pts[np.abs(t - ti) < 0.015].mean(0) for ti in np.linspace(t0, t1, n)
                 if (np.abs(t - ti) < 0.015).sum() > 8]
        if len(cents) < 3:
            return d
        d = principal_dir(np.array(cents), d)
    return d


def rotate_bone(rig, name, q):
    """Rotate a pose bone by world-space quaternion q about its head."""
    pb = rig.pose.bones[name]
    mw3 = rig.matrix_world.to_3x3()
    head = pb.head.copy()
    R = (mw3.inverted() @ q.to_matrix() @ mw3).to_4x4()
    pb.matrix = Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def fit_limbs(rig, scan, skin):
    """Turn donor upper/lower arms and legs so their flesh axes match the scan limbs; keep feet flat.

    The bone axis is not the flesh axis (MPFB thighs carry a Q-angle and the hip
    skinning bends the thigh), so aiming a bone at the scan axis misses by about
    10 degrees. Instead measure the same slice-centroid axis on the scan and on
    the posed donor skin and rotate each bone by the difference, a few times,
    because skinning makes the response non-linear.
    """
    co = np.array([v.co for v in scan.data.vertices])
    mw = rig.matrix_world
    B = lambda n: mw @ rig.data.bones[n].head_local
    L = lambda n: rig.data.bones[n].length * mw.to_scale()[0]
    donor_pts = lambda: np.concatenate(world_co(skin))

    def limb(pts, kind, sfx, side):
        sh, hip = B(f"upperarm.{sfx}"), B(f"upperleg.{sfx}")
        if kind == "arm":
            # From 6 cm past the shoulder to the wrist, near shoulder height.
            la = L(f"upperarm.{sfx}") + L(f"lowerarm.{sfx}")
            return pts[(pts[:, 0] * side > abs(sh.x) + 0.06) & (pts[:, 0] * side < abs(sh.x) + la)
                       & (np.abs(pts[:, 2] - sh.z) < 0.2)]
        # That side, from 12 cm below the hip joint to above the ankle.
        return pts[(pts[:, 0] * side > 0.02) & (pts[:, 2] < hip.z - 0.12) & (pts[:, 2] > 0.12)]

    for sfx, side in (("l", 1), ("r", -1)):
        for kind, (up, lo), hint in (("arm", ("upperarm", "lowerarm"), Vector((side, 0, 0))),
                                     ("leg", ("upperleg", "lowerleg"), Vector((0, 0, -1)))):
            root = B(f"{up}.{sfx}")
            l1, l2 = L(f"{up}.{sfx}"), L(f"{lo}.{sfx}")
            s_pts = limb(co, kind, sfx, side)
            if len(s_pts) < 50:
                raise RuntimeError(f"{kind}.{sfx}: scan limb not found ({len(s_pts)} pts)")
            s0 = axis_fit(s_pts, root, principal_dir(s_pts, hint), 0.1, 0.9 * (l1 + l2))
            for bone, lo_t, hi_t in ((up, 0.3 * l1, 0.9 * l1), (lo, l1 + 0.1 * l2, l1 + 0.85 * l2)):
                ds = axis_fit(s_pts, root, s0, lo_t, hi_t)
                for _ in range(10):
                    d_pts = limb(donor_pts(), kind, sfx, side)
                    d0 = axis_fit(d_pts, root, principal_dir(d_pts, hint), 0.1, 0.9 * (l1 + l2))
                    dd = axis_fit(d_pts, root, d0, lo_t, hi_t)
                    err = math.degrees(dd.angle(ds))
                    if err < 0.3:
                        break
                    rotate_bone(rig, f"{bone}.{sfx}", dd.rotation_difference(ds))
                log(f"{bone}.{sfx}: scan axis {tuple(round(x, 3) for x in ds)}, residual {err:.1f} deg")
        # Feet: the scan stands with flat soles, so undo the tilt the leg turn gave the foot.
        pb = rig.pose.bones[f"foot.{sfx}"]
        pb.matrix = Matrix.Translation(pb.matrix.translation) @ pb.bone.matrix_local.to_3x3().to_4x4()
        bpy.context.view_layer.update()


# ---------------------------------------------------------------- conform

def weld_graph(chunks, faces_per_part):
    """Canonical ids over all parts (MPFB parts and UV seams duplicate verts)."""
    weld, canon = {}, []
    for pts in chunks:
        for p in pts:
            canon.append(weld.setdefault(tuple(np.round(p, 5)), len(weld)))
    canon = np.array(canon)
    nbr = [set() for _ in range(len(weld))]
    base = 0
    for pts, faces in zip(chunks, faces_per_part):
        for f in faces:
            ids = [canon[base + i] for i in f]
            for a, b in zip(ids, ids[1:] + ids[:1]):
                if a != b:
                    nbr[a].add(b)
                    nbr[b].add(a)
        base += len(pts)
    return canon, [np.fromiter(n, int) for n in nbr]


def smooth_field(d, w, nbr, iters):
    """Weighted Laplacian smoothing on the welded graph (vectorised over edges).

    Entries with w=0 (no scan hit) are filled in from their neighbours; their
    weight grows as soon as a neighbour carries information.
    """
    if not hasattr(smooth_field, "_edges") or smooth_field._n != len(nbr):
        src = np.concatenate([np.full(len(n), i) for i, n in enumerate(nbr)])
        dst = np.concatenate(nbr)
        smooth_field._edges, smooth_field._n = (src.astype(int), dst.astype(int)), len(nbr)
    src, dst = smooth_field._edges
    d = d.astype(float).copy()
    w = w.astype(float).copy()
    for _ in range(iters):
        acc = d * (2 * w)[:, None]
        wsum = 2 * w
        np.add.at(acc, src, d[dst] * w[dst, None])
        np.add.at(wsum, src, w[dst])
        ok = wsum > 1e-9
        d[ok] = acc[ok] / wsum[ok, None]
        w = np.maximum(w, np.minimum(1.0, wsum / 4.0))
    return d


def detail_mask(skin, chunks, rig, face_pts):
    """1 = follow the scan in full detail; 0 = smooth offset only (keep MPFB feature)."""
    masks = []
    eye_l = Vector(face_pts.get("eye_l", (0, 0, 0)))
    eye_r = Vector(face_pts.get("eye_r", (0, 0, 0)))
    mouth = Vector(face_pts.get("mouth", (0, 0, 0)))
    nose = Vector(face_pts.get("nose", (0, 0, 0)))
    for o, pts in zip(skin, chunks):
        names = [g.name for g in o.vertex_groups]
        m = np.ones(len(pts))
        for i, v in enumerate(o.data.vertices):
            hand = sum(g.weight for g in v.groups if names[g.group].startswith(HAND_GROUPS))
            m[i] = 1.0 - min(1.0, hand * 1.5)
        if o.name == "Anatomy_Head":
            P = pts
            for c, r in ((eye_l, 0.028), (eye_r, 0.028), (mouth, 0.03), (nose, 0.022)):
                dist = np.linalg.norm(P - np.array(c), axis=1)
                m = np.minimum(m, np.clip((dist - r) / 0.012, 0, 1))
            # Ears: high-curvature MPFB features the scan blurs.
            ear = np.abs(P[:, 0]) > 0.062
            m[ear] = np.minimum(m[ear], 0.3)
        masks.append(m)
    return masks


def project(scan_bvh, pts, normals, max_dist):
    d = np.zeros_like(pts)
    w = np.zeros(len(pts))
    for i, (p, n) in enumerate(zip(pts, normals)):
        p, n = Vector(p), Vector(n)
        best = None
        for sgn in (1, -1):
            hit, hn, _i, dist = scan_bvh.ray_cast(p, n * sgn, max_dist)
            if hit is not None and hn.dot(n) > 0.2 and (best is None or dist < best[1]):
                best = (hit, dist)
        if best is None:
            hit, hn, _i, dist = scan_bvh.find_nearest(p, max_dist)
            if hit is not None and hn.dot(n) > 0.4:
                best = (hit, dist)
        if best is not None:
            d[i] = np.array(best[0]) - pts[i]
            w[i] = 1.0
    return d, w


def scan_eye_z(scan, z_guess, st=0.001):
    """Eye-line height on the scan, from its painted albedo (front orthographic ray grid).

    Eye pixels are sclera (bright, unsaturated), pupil (dark) or a green iris; the
    eye line is the smoothed row-histogram peak, which rejects nostrils and brows.
    """
    me = scan.data
    tris = me.loop_triangles
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [t.vertices for t in tris])
    img = scan_albedo(scan)
    W, H = img.size
    px = np.empty(W * H * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(H, W, 4)
    uv = me.uv_layers.active.data
    xs = np.arange(-0.06, 0.06, st)
    zs = np.arange(z_guess - 0.05, z_guess + 0.06, st)
    a = np.zeros((len(zs), len(xs), 3), np.float32)
    hitm = np.zeros((len(zs), len(xs)), bool)
    e = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    for j, z in enumerate(zs):
        for i, x in enumerate(xs):
            loc, _n, idx, _d = bvh.ray_cast(Vector((x, -2.0, z)), Vector((0, 1, 0)))
            if idx is None:
                continue
            t = tris[idx]
            w = geometry.barycentric_transform(loc, *(me.vertices[k].co for k in t.vertices), *e)
            u = sum(uv[t.loops[k]].uv[0] * w[k] for k in range(3))
            v = sum(uv[t.loops[k]].uv[1] * w[k] for k in range(3))
            a[j, i] = px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
            hitm[j, i] = True
    mx, mn = a.max(-1), a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    mask = hitm & (((sat < 0.22) & (mx > 0.55)) | ((mx < 0.18) & (mx > 0.0)) | ((a[..., 1] > a[..., 0]) & (mx > 0.05)))
    mask &= (np.abs(xs) > 0.012)[None, :] & (np.abs(xs) < 0.055)[None, :]
    rows = np.convolve(mask.sum(1).astype(np.float32), np.ones(9) / 9, mode="same")
    if rows.max() < 4:
        return None
    return float(zs[int(rows.argmax())])


def fit_head(rig, scan_bvh, head_obj, eyes_obj, scan, iters=12):
    """Rigid fit of the donor skull and face to the scan head (ICP with Kabsch).

    Meshy guesses head pose and depth from a front image: Aita v4 came out with
    the head tilted back and about 6 cm behind the MPFB posture while the torso
    matched, so every face feature sat 2-3 cm too high and the jaw opened on
    the chin. The rotation goes into the `head` bone pose (so the rest pose
    keeps the MPFB posture and the neck bends by its weights); there is no neck
    bone for the translation, so it is returned and added to the displacement
    blended by the `head` weight.
    """
    hz = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    t = np.zeros(3)
    for _ in range(iters):
        P = world_co([head_obj])[0]
        P = P[P[:, 2] > hz + 0.04]  # skull and face, not the neck
        Q, keep = [], []
        for i, p in enumerate(P):
            hit = scan_bvh.find_nearest(Vector(p + t), 0.12)[0]
            if hit is not None:
                Q.append(np.array(hit))
                keep.append(i)
        P, Q = P[keep] + t, np.array(Q)
        pc, qc = P.mean(0), Q.mean(0)
        U, _s, Vt = np.linalg.svd((P - pc).T @ (Q - qc))
        R = Vt.T @ np.diag([1, 1, np.sign(np.linalg.det(Vt.T @ U.T))]) @ U.T
        # p -> R (p - pc) + qc, written as a rotation about the head joint plus a shift.
        j = np.array(rig.matrix_world @ rig.pose.bones["head"].head) + t
        t = t + (R @ (j - pc) + qc) - j
        rotate_bone(rig, "head", Matrix(R.tolist()).to_quaternion())
        ang = math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(R) - 1) / 2))))
        if ang < 0.1 and np.linalg.norm(qc - pc) < 0.0005:
            break
    # The skull fit sets tilt and depth, but the cranium height differs (a bald
    # Meshy scalp sits about 2 cm lower than MPFB's), which drags the face down.
    # Height comes from the eye line instead: eye-to-mouth matches within a few mm.
    eye_d = world_co([eyes_obj])[0][:, 2].mean() + t[2]
    eye_s = scan_eye_z(scan, eye_d)
    if eye_s is None:
        log("head: WARNING no painted eye line on the scan, keeping the skull-fit height")
    else:
        log(f"head: eye line scan {eye_s:.3f} / donor {eye_d:.3f}")
        t[2] += eye_s - eye_d
    return t, rig.pose.bones["head"].matrix_basis.to_quaternion()


def cavity_mask(pts, normals, faces, reach=0.025):
    """True for head vertices inside the mouth, nostrils or ear canals.

    The scan has no cavities, so these vertices must not be projected or baked:
    projected, the mouth bag lands on the chin skin and pokes through it; baked,
    it gets face skin. A vertex is a cavity vertex when a short ray along its
    normal hits the head itself.
    """
    bvh = BVHTree.FromPolygons([Vector(p) for p in pts], faces)
    out = np.zeros(len(pts), bool)
    for i, (p, n) in enumerate(zip(pts, normals)):
        n = Vector(n)
        hit = bvh.ray_cast(Vector(p) + n * 0.001, n, reach)[0]
        out[i] = hit is not None
    return out


def head_weights(obj):
    gi = obj.vertex_groups.get("head")
    w = np.zeros(len(obj.data.vertices))
    if gi is None:
        return w
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group == gi.index:
                w[v.index] = g.weight
    return w


def deform_inverse(obj, rig):
    """Per-vertex inverse of the blended skinning matrix (linear part) at the current pose."""
    mw, mwi = rig.matrix_world, rig.matrix_world.inverted()
    D = {pb.name: (mw @ pb.matrix @ pb.bone.matrix_local.inverted() @ mwi).to_3x3() for pb in rig.pose.bones}
    names = [g.name for g in obj.vertex_groups]
    inv = []
    for v in obj.data.vertices:
        M = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
        tot = 0.0
        for g in v.groups:
            if names[g.group] in D and g.weight > 0:
                M += D[names[g.group]] * g.weight
                tot += g.weight
        inv.append(np.array(M.inverted_safe() if tot > 0 else Matrix.Identity(3)))
    return np.array(inv)


# ---------------------------------------------------------------- bake

def scan_albedo(scan):
    mat = scan.data.materials[0]
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            src = n.inputs["Base Color"].links[0].from_node
            while src.type != "TEX_IMAGE":
                src = next(i.links[0].from_node for i in src.inputs if i.is_linked)
            return src.image


def donor_albedo(skin):
    for mat in (m for o in skin for m in o.data.materials if m):
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "albedo" in n.image.name:
                return n.image
    raise RuntimeError("donor skin albedo not found")


def raster_uv_weights(skin, weights, size):
    """Rasterise per-vertex weights through the MPFB UVs into a size x size map (max blend)."""
    out = np.zeros((size, size), np.float32)
    for o, w in zip(skin, weights):
        if not w.any():
            continue
        uvs = o.data.uv_layers.active.data
        for poly in o.data.polygons:
            vw = w[list(poly.vertices)]
            if not vw.any():
                continue
            uv = np.array([uvs[li].uv for li in poly.loop_indices]) * size
            for k in range(1, len(uv) - 1):  # fan triangles
                tri, tw = uv[[0, k, k + 1]], vw[[0, k, k + 1]]
                x0, y0 = np.floor(tri.min(0)).astype(int)
                x1, y1 = np.ceil(tri.max(0)).astype(int)
                X, Y = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, size)), np.arange(max(y0, 0), min(y1 + 1, size)))
                (ax, ay), (bx, by), (cx, cy) = tri
                den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
                if abs(den) < 1e-9:
                    continue
                l1 = ((by - cy) * (X + 0.5 - cx) + (cx - bx) * (Y + 0.5 - cy)) / den
                l2 = ((cy - ay) * (X + 0.5 - cx) + (ax - cx) * (Y + 0.5 - cy)) / den
                l3 = 1 - l1 - l2
                inside = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
                val = l1 * tw[0] + l2 * tw[1] + l3 * tw[2]
                out[Y[inside], X[inside]] = np.maximum(out[Y[inside], X[inside]], val[inside])
    return out


def bake_albedo(skin, conformed_posed, keep, scan, size, out_png, donor_w=None):
    """Build one posed, conformed copy of the skin with MPFB UVs and bake the scan colour onto it.

    Only faces whose vertices are all in `keep` (not a cavity) are baked. Texels
    the bake does not reach (cavities, faces too far from the scan, faces bmesh
    rejects as duplicates) are filled with the donor albedo, tinted to the
    scan's mean skin colour. `donor_w` (per-vertex, 0..1) blends that tinted
    donor skin over the bake with a soft edge, for the lids.
    """
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    skipped = 0
    for o, pts, kp in zip(skin, conformed_posed, keep):
        verts = [bm.verts.new(p) for p in pts]
        uvs = o.data.uv_layers.active.data
        for poly in o.data.polygons:
            if not all(kp[i] for i in poly.vertices):
                continue
            try:
                f = bm.faces.new([verts[i] for i in poly.vertices])
            except ValueError:
                skipped += 1
                continue
            for loop, li in zip(f.loops, poly.loop_indices):
                loop[uv_layer].uv = uvs[li].uv
    me = bpy.data.meshes.new("BakeSkin")
    bm.to_mesh(me)
    bm.free()
    tgt = bpy.data.objects.new("BakeSkin", me)
    bpy.context.scene.collection.objects.link(tgt)
    if skipped:
        log(f"bake: {skipped} duplicate faces skipped")
    img = bpy.data.images.new("skin_albedo_baked", size, size, alpha=True)
    img.generated_color = (1, 0, 1, 0)  # sentinel: texels the bake never writes keep it
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    me.materials.append(mat)
    # Scan: emit its albedo so lighting does not leak into the bake.
    smat = scan.data.materials[0]
    nt = smat.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = scan_albedo(scan)
    nt.links.new(tex.outputs[0], em.inputs[0])
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(em.outputs[0], out.inputs[0])
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = 4
    s.cycles.device = "CPU"
    s.render.bake.use_selected_to_active = True
    s.render.bake.cage_extrusion = 0.02
    s.render.bake.max_ray_distance = 0.06
    s.render.bake.margin = 8
    for o in bpy.data.objects:
        o.select_set(False)
    scan.select_set(True)
    tgt.select_set(True)
    bpy.context.view_layer.objects.active = tgt
    bpy.ops.object.bake(type="EMIT")
    px = np.empty(size * size * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    don = donor_albedo(skin).copy()
    don.scale(size, size)
    dp = np.empty(size * size * 4, np.float32)
    don.pixels.foreach_get(dp)
    dp = dp.reshape(-1, 4)
    # Cycles writes black (alpha 1) where a target texel's ray misses the scan, and
    # leaves texels outside the bake islands at the sentinel; skin is never pure black.
    sentinel = (np.abs(px - [1, 0, 1, 0]).max(1) < 1e-3)
    baked = ~sentinel & (px[:, :3].max(1) > 0.004)
    tint = px[baked, :3].mean(0) / np.maximum(dp[baked, :3].mean(0), 1e-4)
    px[~baked, :3] = np.clip(dp[~baked, :3] * tint, 0, 1)
    if donor_w is not None:
        m = raster_uv_weights(skin, donor_w, size).reshape(-1)[:, None]
        px[:, :3] = px[:, :3] * (1 - m) + np.clip(dp[:, :3] * tint, 0, 1) * m
    px[:, 3] = 1.0
    img.pixels.foreach_set(px.ravel())
    bpy.data.images.remove(don)
    log(f"bake: {baked.mean():.0%} of texels from the scan, rest donor x {tuple(round(float(t), 2) for t in tint)}")
    img.filepath_raw = out_png
    img.file_format = "PNG"
    img.save()
    bpy.data.objects.remove(tgt, do_unlink=True)
    log("baked", out_png)
    return img


# ---------------------------------------------------------------- main

def main():
    a = parse_args()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    rig, skin, face, other = load_donor(a.donor, a.keep_hair, a.keep_brows)
    cloth = load_wearable(a.headcloth, rig) if a.headcloth else []
    rest_chunks = world_co(skin, evaluated=False)
    allz = np.concatenate([c[:, 2] for c in rest_chunks])
    scan = load_scan(a.meshy)
    torso_rest = rest_chunks[[o.name for o in skin].index("Anatomy_Torso")]
    y_torso = (torso_rest[:, 1].max() + torso_rest[:, 1].min()) / 2

    eyes_obj = next(o for o in face if o.name == "Anatomy_Head_Eyes")
    ec = world_co([eyes_obj], evaluated=False)[0]
    head_rest = rest_chunks[[o.name for o in skin].index("Anatomy_Head")]
    lips_z = ec[:, 2].mean() - 0.075  # MPFB adult: mouth about 7.5 cm under the eye line
    # Nose: front-most midline point between the eye line and the mouth (tip to nostrils).
    mid = head_rest[(np.abs(head_rest[:, 0]) < 0.01) & (head_rest[:, 2] < ec[:, 2].mean() - 0.02) & (head_rest[:, 2] > lips_z + 0.01)]
    nose_tip = mid[mid[:, 1].argmin()]
    face_pts = {"eye_l": ec[ec[:, 0] > 0].mean(0), "eye_r": ec[ec[:, 0] < 0].mean(0),
                "mouth": (0.0, head_rest[:, 1].min() + 0.012, lips_z),
                "nose": (0.0, nose_tip[1] + 0.012, nose_tip[2] - 0.008)}

    # The scan stands wide, so it is shorter than the donor at rest. Scale it to the
    # height of the donor posed in the same stance; the stance depends on the scale,
    # so alternate fit and rescale until the height settles.
    z0, h = allz.min(), allz.max() - allz.min()
    for it in range(4):
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix()
        bpy.context.view_layer.update()
        place_scan(scan, z0, h, y_torso)
        fit_limbs(rig, scan, skin)
        pz = np.concatenate([c[:, 2] for c in world_co(skin)])
        log(f"scale pass {it}: scan height {h:.3f} -> posed donor {pz.max() - pz.min():.3f}")
        if abs((pz.max() - pz.min()) - h) < 0.002 and abs(pz.min() - z0) < 0.002:
            break
        z0, h = pz.min(), pz.max() - pz.min()
    scan.data.calc_loop_triangles()
    bvh = BVHTree.FromPolygons([v.co for v in scan.data.vertices], [t.vertices for t in scan.data.loop_triangles])
    t_head, q_head = fit_head(rig, bvh, next(o for o in skin if o.name == "Anatomy_Head"), eyes_obj, scan)
    log(f"head: turn {math.degrees(q_head.angle):.1f} deg about {tuple(round(x, 2) for x in q_head.axis)}, "
        f"shift {tuple(round(float(x) * 1000, 1) for x in t_head)} mm")
    posed = world_co(skin)
    dg = bpy.context.evaluated_depsgraph_get()
    normals = []
    for o in skin:
        me = o.evaluated_get(dg).to_mesh()
        normals.append(np.array([o.matrix_world.to_3x3() @ v.normal for v in me.vertices]))
        o.evaluated_get(dg).to_mesh_clear()

    faces = [[list(p.vertices) for p in o.data.polygons] for o in skin]
    canon, nbr = weld_graph(posed, faces)
    n_c = len(nbr)

    # Seat the head first (see fit_head), then project only the remaining detail.
    w_head = np.zeros(n_c)
    off = 0
    for o, pts in zip(skin, posed):
        np.maximum.at(w_head, canon[off:off + len(pts)], head_weights(o))
        off += len(pts)
    w_head = smooth_field(w_head[:, None], np.ones(n_c), nbr, 6)[:, 0]
    d_head = w_head[:, None] * t_head
    posed = [pts + d_head[canon[o0:o0 + len(pts)]]
             for pts, o0 in zip(posed, np.cumsum([0] + [len(p) for p in posed[:-1]]))]

    # Per canonical vertex: raw displacement and validity (average over welded duplicates).
    d_raw, w_raw = np.zeros((n_c, 3)), np.zeros(n_c)
    cnt = np.zeros(n_c)
    off = 0
    cavity = np.zeros(n_c, bool)
    for o, pts, nr, fc in zip(skin, posed, normals, faces):
        d, w = project(bvh, pts, nr, a.max_dist)
        if o.name == "Anatomy_Head":
            # Eye sockets face each other too, but the lids must keep the smooth offset.
            ep = world_co([eyes_obj])[0]
            near_eye = np.minimum(*(np.linalg.norm(pts - ep[ep[:, 0] * sd > 0].mean(0), axis=1) for sd in (1, -1)))
            cav = cavity_mask(pts, nr, fc) & (near_eye > 0.03)
            w[cav] = 0.0
            cavity[canon[off:off + len(pts)][cav]] = True
            log(f"  cavity vertices: {int(cav.sum())}")
        hit = w > 0
        log(f"  {o.name}: hit {hit.mean():.0%}, median |d| {np.median(np.linalg.norm(d[hit], axis=1)) * 1000 if hit.any() else 0:.1f} mm")
        ids = canon[off:off + len(pts)]
        np.add.at(d_raw, ids, d * w[:, None])
        np.add.at(w_raw, ids, w)
        np.add.at(cnt, ids, 1)
        off += len(pts)
    valid = w_raw > 0
    d_raw[valid] /= w_raw[valid, None]
    w_c = (w_raw / np.maximum(cnt, 1))
    log("projected", int(valid.sum()), "of", n_c)

    d_low = smooth_field(d_raw.copy(), w_c, nbr, a.smooth_iters)
    d_fill = smooth_field(d_raw.copy(), w_c, nbr, 3)  # light denoise, holes filled
    masks = detail_mask(skin, rest_chunks, rig, face_pts)
    m_c = np.ones(n_c)
    off = 0
    for mk in masks:
        np.minimum.at(m_c, canon[off:off + len(mk)], mk)
        off += len(mk)
    m_c[cavity] = 0.0
    m_c = smooth_field(m_c[:, None], np.ones(n_c), nbr, 4)[:, 0]
    d_fin = d_low + (m_c * valid)[:, None] * (d_fill - d_low)
    d_fin = smooth_field(d_fin, np.ones(n_c), nbr, 2)
    # Cavities take the local offset of the skin around them (lips, nostril rims),
    # not the 40-pass smooth field: where the scan chin sits deeper than MPFB the
    # skin moves in with full detail and a smooth-only mouth bag pokes through it.
    if cavity.any():
        d_cav = smooth_field(np.where(cavity[:, None], 0.0, d_fin), (~cavity).astype(float), nbr, 12)
        d_fin[cavity] = d_cav[cavity]
    # Lids move rigidly with their eyeball. The scan brow ridge sits up to 1 cm
    # deeper than MPFB's, and even the smooth field then drags the upper lid
    # behind the eyeball, which pokes through and blink no longer closes it.
    # Constant offset inside 1.4 cm of each eye centre, blending out by 2.8 cm.
    flat = np.concatenate(posed)
    P_c = np.zeros((n_c, 3))
    P_c[canon] = flat
    ep = world_co([eyes_obj])[0] + t_head
    for sd in (1, -1):
        r = np.linalg.norm(P_c - ep[ep[:, 0] * sd > 0].mean(0), axis=1)
        c_eye = d_fin[(r < 0.016) & ~cavity].mean(0)
        f = np.clip((r - 0.014) / 0.014, 0.0, 1.0)[:, None]
        d_fin = c_eye * (1 - f) + d_fin * f
    # `posed` carries the head shift for projection and bake only. The rest pose
    # gets d_fin alone: the head stays over its joint in the MPFB posture (the
    # scan's head sat 6 cm back) and only the shape is carried over.
    conformed_posed = []
    off = 0
    for pts in posed:
        conformed_posed.append(pts + d_fin[canon[off:off + len(pts)]])
        off += len(pts)

    tex_dir = os.path.splitext(os.path.abspath(a.out))[0] + "_textures"
    os.makedirs(tex_dir, exist_ok=True)
    # Cavities are not baked: they would get face skin (see cavity_mask). Faces a
    # little off the scan (lids, lips, neck fill) still bake from the nearest scan
    # surface, which matches the neighbours better than tinted donor skin.
    # Lids get tinted donor skin, blended in softly: the scan paints its eye
    # whites and iris there, which would land on the MPFB lids.
    keep, lid_w, off = [], [], 0
    for pts, rp in zip(conformed_posed, rest_chunks):
        r = np.minimum(*(np.linalg.norm(rp - np.array(face_pts[k]), axis=1) for k in ("eye_l", "eye_r")))
        lid_w.append(np.clip((0.018 - r) / 0.006, 0.0, 1.0))
        keep.append(~cavity[canon[off:off + len(pts)]])
        off += len(pts)
    baked = bake_albedo(skin, conformed_posed, keep, scan, a.tex, os.path.join(tex_dir, "skin_albedo.png"),
                        donor_w=lid_w)

    # Back to rest: rest delta = inverse skinning (linear part) applied to the posed delta.
    off = 0
    rest_dr = []
    for o, pts in zip(skin, posed):
        inv = deform_inverse(o, rig)
        dr = np.einsum("nij,nj->ni", inv, d_fin[canon[off:off + len(pts)]])
        mwi = o.matrix_world.inverted().to_3x3()
        local = np.array([mwi @ Vector(x) for x in dr])
        if o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks:
                for i, x in enumerate(local):
                    kb.data[i].co += Vector(x)
        else:
            for i, x in enumerate(local):
                o.data.vertices[i].co += Vector(x)
        rest_dr.append(dr)
        off += len(pts)
    head_obj = next(o for o in skin if o.name == "Anatomy_Head")

    # Eyes, lashes, brows, teeth, kept hair and the headcloth ride on the rest offset
    # of the nearest skin vertex (smooth around eyes and mouth, see detail_mask).
    all_rest, all_dr = np.concatenate(rest_chunks), np.concatenate(rest_dr)
    kd = KDTree(len(all_rest))
    for i, p in enumerate(all_rest):
        kd.insert(p, i)
    kd.balance()
    # Eyeballs and lashes move rigidly per side with the mean offset of the lid
    # ring. Their nearest skin vertex is often the socket wall behind the eye,
    # whose offset differs from the lids', and the eye then pokes through.
    eye_dr = {}
    for sd in (1, -1):
        c = np.array(face_pts["eye_l" if sd > 0 else "eye_r"])
        ring = (np.linalg.norm(all_rest - c, axis=1) < 0.016) & ~cavity[canon]  # lid margins
        eye_dr[sd] = all_dr[ring].mean(0)
        log(f"eye {'l' if sd > 0 else 'r'}: {int(ring.sum())} lid vertices, "
            f"offset {tuple(round(float(x) * 1000, 1) for x in eye_dr[sd])} mm")
    # The headcloth stays as fitted to the donor: following the skull detail would
    # slide its brim over the eyes where the scan cranium is lower. clear_cloth
    # then pushes out what the new body swallowed.
    for o in face + other:
        P = world_co([o], evaluated=False)[0]
        mwi = o.matrix_world.inverted().to_3x3()
        rigid_eye = o.name in ("Anatomy_Head_Eyes", "Anatomy_Head_Lashes")
        for i, p in enumerate(P):
            dv = eye_dr[1 if p[0] > 0 else -1] if rigid_eye else all_dr[kd.find(p)[1]]
            delta = Vector(mwi @ Vector(dv))
            if o.data.shape_keys:
                for kb in o.data.shape_keys.key_blocks:
                    kb.data[i].co += delta
            else:
                o.data.vertices[i].co += delta
    if cloth:
        clear_cloth(cloth, skin)

    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()

    old_albedo = donor_albedo(skin)
    for mat in {m for o in skin for m in o.data.materials if m}:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image is old_albedo:
                n.image = baked
    if a.debug_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.debug_blend), copy=True)
    bpy.data.objects.remove(scan, do_unlink=True)

    for o in bpy.data.objects:
        o.select_set(o is rig or o.parent is rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=True)
    rep = {"out": a.out, "projected": int(valid.sum()), "verts": n_c,
           "meshes": sorted(o.name for o in bpy.data.objects if o.parent is rig),
           "shape_keys": [k.name for k in head_obj.data.shape_keys.key_blocks] if head_obj.data.shape_keys else [],
           "actions": len(bpy.data.actions), "bones": len(rig.data.bones)}
    json.dump(rep, open(os.path.splitext(a.out)[0] + ".report.json", "w"), indent=1)
    log("done", json.dumps(rep))


main()
