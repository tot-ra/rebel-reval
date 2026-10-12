"""Drape a widow's linen headcloth on a conformed (Meshy-shaped) MPFB head.

  blender -b --factory-startup --python tools/assets/meshy_human/drape_headcloth.py -- \
      --body build/<char>_meshy/conform/<char>_conformed.glb \
      --out build/<char>_meshy/headcloth/<char>_draped.glb \
      [--wearable-out build/<char>_meshy/headcloth/headscarf/headscarf.glb]

Why: the donor's MPFB headscarf (conform --headcloth / fit --wearable-keep) is a stiff
hood fitted to the MPFB skull. On the scan skull its brim stands off the forehead like
a visor, and its side tails reach the shoulders, where the raised arm cuts into them.

What it does, all in the rest pose:
1. Drops the body's Garment_headscarf* meshes (keeping their linen material and texel
   density) and the glTF importer's phantom meshes.
2. Builds the cloth column by column round the head: a shell `--ease` off the skull
   (ray-cast from outside, so the ears are covered) down to ear level, then a drop that
   hangs straight from the widest point of the skull and is pushed out of the neck and
   back. Each column ends at the face opening line: the hairline over the brow, the jaw
   beside the face (in front of the ears), the nape at the back. Soft folds grow
   towards the hem.
3. Lifts anything still inside the body out along its ray from the head centre. No
   cloth simulation: Blender cloth (pinned crown, body colliders) crumpled the free hem
   against the ear and the upper back; the hanging profile above already drapes.
4. Skins it to `head` and `chest` only, from the nearest head/torso skin weights (the
   rig has no neck bone): the arm bones never move the cloth, so a raised arm cannot
   drag a tail with it.
5. Writes the body with the new cloth (--out) and optionally the cloth alone as a
   wearable on the same rig without animations (--wearable-out), like the MPFB
   wearables.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

CLOTH = "Garment_headscarf"
BONES = ("head", "chest")


def log(*a):
    print("[drape_headcloth]", *a, flush=True)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--body", required=True, help="conformed GLB (nude or with the donor headcloth)")
    p.add_argument("--out", required=True)
    p.add_argument("--wearable-out", default="")
    p.add_argument("--ease", type=float, default=0.007, help="cloth gap over the skull, m")
    p.add_argument("--hairline", type=float, default=0.050, help="brim height above the eye centres, m")
    p.add_argument("--jaw", type=float, default=-0.085, help="side hem height relative to the eyes, m")
    p.add_argument("--nape", type=float, default=-0.175, help="back hem height relative to the eyes, m")
    p.add_argument("--volume", type=float, default=0.014,
                   help="extra fullness over the back of the skull (the hair knotted under the cloth), m")
    p.add_argument("--folds", type=float, default=0.009, help="fold depth at the hem, m")
    p.add_argument("--thickness", type=float, default=0.0025)
    p.add_argument("--columns", type=int, default=128)
    p.add_argument("--rows", type=int, default=44)
    return p.parse_args(argv)


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def horizontal(theta):
    """Unit vector round the head; theta 0 = front (-Y), positive towards +X (character's left)."""
    return Vector((math.sin(theta), -math.cos(theta), 0.0))


def body_bvh(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(o.matrix_world)
        me2 = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me2)
        tmp.free()
        bm.from_mesh(me2)
        bpy.data.meshes.remove(me2)
        o.evaluated_get(dg).to_mesh_clear()
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    return bvh


def texel_scale(cloth):
    """UV units per metre of the old headcloth, so the linen weave keeps its size."""
    uv_area = world_area = 0.0
    for o in cloth:
        me = o.data
        uv = me.uv_layers.active.data if me.uv_layers else None
        if uv is None:
            continue
        for poly in me.polygons:
            pts = [uv[li].uv for li in poly.loop_indices]
            uv_area += abs(sum(pts[i].x * pts[i - 1].y - pts[i - 1].x * pts[i].y for i in range(len(pts)))) / 2
            world_area += poly.area * o.matrix_world.to_scale().x ** 2
    return math.sqrt(uv_area / world_area) if world_area > 0 else 4.0


def clear_outermost(pts, bvh, centre, gap):
    """Move each point out to the outermost body surface + `gap` along its own ray (from the
    head centre above it, horizontal from the head axis below it). Unlike a nearest-point
    test this catches the thin ear rim, whose nearest face is its back."""
    moved = 0
    for p in pts:
        o = centre if p.z >= centre.z else Vector((centre.x, centre.y, p.z))
        d = p - o
        if d.length < 1e-6:
            continue
        d.normalize()
        hit = bvh.ray_cast(o + d * 0.6, -d)
        if hit[0] is not None and (hit[0] - o).dot(d) + gap > (p - o).dot(d):
            p[:] = o + d * ((hit[0] - o).dot(d) + gap)
            moved += 1
    return moved


def build_cloth(a, bvh, eyes_c, centre, head_top):
    """Column polylines from the crown to the hem line, resampled to a quad grid."""
    eye_z = eyes_c.z
    hair_z, jaw_z, nape_z = eye_z + a.hairline, eye_z + a.jaw, eye_z + a.nape

    def hem_z(theta):
        f = math.degrees(min(theta % (2 * math.pi), 2 * math.pi - theta % (2 * math.pi)))  # 0 front .. 180 back
        brow = hair_z - 0.012 * min(1.0, f / 28.0) ** 2  # the hairline dips a little at the temples
        z = brow + (jaw_z - brow) * smoothstep(28, 62, f)
        return z + (nape_z - jaw_z) * smoothstep(110, 180, f)

    def fullness(theta, el):
        """Ease plus the hair knot: largest over the back of the skull, none at the brow."""
        f = math.degrees(min(theta % (2 * math.pi), 2 * math.pi - theta % (2 * math.pi)))
        e = math.degrees(el)
        return a.ease + a.volume * smoothstep(70, 170, f) * math.sin(math.radians(max(0.0, min(180.0, e * 2.4))))

    def envelope(raw, reach_c, reach_r):
        """Dilate (max over a window) then blur a [column][sample] radius field, never below
        `raw`: the cloth bridges over the ears and other thin detail instead of following
        it (a chord across a thin ear rim cuts it)."""
        C, n = len(raw), len(raw[0])
        dil = [[max(raw[(c + dc) % C][min(n - 1, max(0, r + dr))]
                    for dc in range(-reach_c, reach_c + 1) for dr in range(-reach_r, reach_r + 1))
                for r in range(n)] for c in range(C)]
        out = dil
        for _ in range(4):
            out = [[max(raw[c][r], (out[(c + 1) % C][r] + out[c - 1][r] + out[c][max(0, r - 1)]
                                          + out[c][min(n - 1, r + 1)] + out[c][r] * 2) / 6)
                    for r in range(n)] for c in range(C)]
        return out

    C = a.columns
    thetas = [c / C * 2 * math.pi for c in range(C)]
    elevs = [math.radians(e) for e in range(86, -1, -2)]
    bottom = [hem_z(t) for t in thetas]
    zs = []
    z = centre.z - 0.005
    while z > min(bottom) - 0.01:
        zs.append(z)
        z -= 0.005

    def dirs(theta, el):
        return horizontal(theta) * math.cos(el) + Vector((0, 0, math.sin(el)))

    def outermost(o, d):
        hit = bvh.ray_cast(o + d * 0.6, -d)
        return (hit[0] - o).dot(d) if hit[0] is not None else 0.0

    # Shell: radius from the head centre per (column, elevation); drop: horizontal radius
    # from the head axis per (column, height), hanging from the widest point of the skull.
    # Each sample keeps the outermost of a 3x3 cluster of rays, so a thin ear rim between
    # two sample rays still lifts the cloth.
    dt, de, dz = math.pi / C, math.radians(1.0), 0.0025
    shell_raw = [[max(max(outermost(centre, dirs(t + i * dt, el + j * de)) for i in (-1, 0, 1) for j in (-1, 0, 1)),
                      0.06) + fullness(t, el) for el in elevs] for t in thetas]
    shell = envelope(shell_raw, 4, 3)
    drop_raw = []
    for c, t in enumerate(thetas):
        h = horizontal(t)
        r_hang = max(r * math.cos(el) for r, el in zip(shell[c], elevs))
        drop_raw.append([max(r_hang, max(outermost(Vector((centre.x, centre.y, z + j * dz)), horizontal(t + i * dt)
                                                   ) for i in (-1, 0, 1) for j in (-1, 0, 1)) + a.ease) for z in zs])
    drop = envelope(drop_raw, 4, 3)

    grid = []
    for c, theta in enumerate(thetas):
        h = horizontal(theta)
        pts = [centre + dirs(theta, el) * r for el, r in zip(elevs, shell[c])]
        pts += [Vector((centre.x, centre.y, z)) + h * r for z, r in zip(zs, drop[c])]
        # Below the widest point of the skull the cloth falls straight instead of tucking
        # back in towards the ear (which left a ledge where the drop starts)...
        widest = max(range(len(elevs)), key=lambda i: shell[c][i] * math.cos(elevs[i]))
        rad = [(p - centre).to_2d().dot(h.to_2d()) for p in pts]
        hang = rad[:]
        for i in range(widest + 1, len(pts)):
            hang[i] = max(hang[i], hang[i - 1])  # hanging cloth never tucks back in
        for i in range(len(pts) - 2, widest, -1):
            # ...and meets the ear below it on a slope, not a ledge. Only above the jaw: the
            # shoulders and back must not lift the whole drape into a bell.
            if pts[i + 1].z > jaw_z:
                hang[i] = max(hang[i], hang[i + 1] - 0.6 * (pts[i].z - pts[i + 1].z))
        for i in range(widest + 1, len(pts)):
            pts[i] += h * (hang[i] - rad[i])
        bottom_z = bottom[c]
        # Cut at the hem line, then resample evenly by arc length.
        cut = [pts[0]]
        for p0, p1 in zip(pts, pts[1:]):
            if p1.z >= bottom_z:
                cut.append(p1)
                continue
            if p0.z > bottom_z:
                cut.append(p0.lerp(p1, (p0.z - bottom_z) / (p0.z - p1.z)))
            break
        lens = [0.0]
        for p0, p1 in zip(cut, cut[1:]):
            lens.append(lens[-1] + (p1 - p0).length)
        col = []
        j = 0
        for r in range(a.rows + 1):
            s = lens[-1] * r / a.rows
            while j < len(lens) - 2 and lens[j + 1] < s:
                j += 1
            seg = max(lens[j + 1] - lens[j], 1e-9)
            col.append(cut[j].lerp(cut[j + 1], (s - lens[j]) / seg))
        grid.append(col)

    # Relax the grid (neighbour average) so the crease where the cloth turns over the
    # widest point of the skull rounds off, re-clearing the body after every pass. The
    # envelope above already bridged the ears, so this cannot fold the cloth into them.
    C, R = a.columns, a.rows
    for _ in range(10):
        new = [[None] * (R + 1) for _ in range(C)]
        for c in range(C):
            for r in range(R + 1):
                nb = [grid[(c + 1) % C][r], grid[c - 1][r]]
                nb += [grid[c][r - 1]] if r > 0 else []
                nb += [grid[c][r + 1]] if r < R else []
                new[c][r] = (grid[c][r] * 2 + sum(nb, Vector())) / (2 + len(nb))
        grid = new
        moved = clear_outermost([p for col in grid for p in col], bvh, centre, a.ease)
    log(f"cloth: {moved} grid points cleared after the last relax pass")

    # Soft folds, added after relaxing (which would flatten them): radial waves that grow
    # from nothing at ear level to --folds at the hem.
    out = []
    for theta, col in zip(thetas, grid):
        h = horizontal(theta)
        row = []
        for p in col:
            drop = smoothstep(centre.z, hem_z(theta), p.z) if p.z < centre.z else 0.0
            # Outward only: an inward fold would cut into the ear or jaw it hangs past.
            wave = 0.5 + 0.5 * (math.sin(theta * 9 + 0.6) * 0.6 + math.sin(theta * 5 + 1.9) * 0.4)
            row.append(p + h * (a.folds * drop * wave))
        out.append(row)
    grid = out

    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    verts = [[bm.verts.new(p) for p in col] for col in grid]
    top = bm.verts.new(Vector((centre.x, centre.y, max(head_top + a.ease, max(c[0].z for c in grid) + 0.002))))
    # Grain UVs in metres: u round the head at the brim's circumference, v down each column.
    circ = sum((grid[(c + 1) % C][R // 3] - grid[c][R // 3]).length for c in range(C))
    arc = [[0.0] * (R + 1) for _ in range(C)]
    for c in range(C):
        for r in range(1, R + 1):
            arc[c][r] = arc[c][r - 1] + (grid[c][r] - grid[c][r - 1]).length

    def uv(c, r):
        return Vector((c / C * circ, -(arc[c % C][r] + 0.03)))

    for c in range(C):
        n = (c + 1) % C
        f = bm.faces.new((top, verts[c][0], verts[n][0]))
        for loop, val in zip(f.loops, (Vector(((c + 0.5) / C * circ, 0.0)), uv(c, 0), uv(c + 1, 0))):
            loop[uv_layer].uv = val
        for r in range(R):
            f = bm.faces.new((verts[c][r], verts[c][r + 1], verts[n][r + 1], verts[n][r]))
            for loop, val in zip(f.loops, (uv(c, r), uv(c, r + 1), uv(c + 1, r + 1), uv(c + 1, r))):
                loop[uv_layer].uv = val
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Normals must point away from the head (Solidify grows inwards from them below).
    f0 = bm.faces[0]
    if f0.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(CLOTH)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(CLOTH, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def skin_weights(obj, skin, rig, head_z):
    """head/chest weights from the nearest head or torso skin vertex, smoothed over the cloth."""
    pts, ws = [], []
    for o in skin:
        gi = {g.index: g.name for g in o.vertex_groups if g.name in BONES}
        for v in o.data.vertices:
            w = {b: 0.0 for b in BONES}
            for g in v.groups:
                if g.group in gi:
                    w[gi[g.group]] += g.weight
            pts.append(o.matrix_world @ v.co)
            ws.append(w)
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    me = obj.data
    head = []
    for v in me.vertices:
        acc = {b: 0.0 for b in BONES}
        for _p, i, d in kd.find_n(v.co, 6):
            for b in BONES:
                acc[b] += ws[i][b] / (d + 1e-4)
        tot = sum(acc.values())
        h = acc["head"] / tot if tot > 0 else 1.0
        # Everything above the jaw follows the skull rigidly (a tilted head must not shear the shell).
        lock = smoothstep(head_z + 0.01, head_z + 0.05, v.co.z)
        head.append(max(h, lock))
    nbr = [[] for _ in me.vertices]
    for e in me.edges:
        i, j = e.vertices
        nbr[i].append(j)
        nbr[j].append(i)
    for _ in range(12):
        head = [0.5 * head[i] + 0.5 * sum(head[j] for j in nbr[i]) / len(nbr[i]) if nbr[i] else head[i]
                for i in range(len(head))]
    gh, gc = obj.vertex_groups.new(name="head"), obj.vertex_groups.new(name="chest")
    for i, h in enumerate(head):
        gh.add([i], h, "REPLACE")
        gc.add([i], 1.0 - h, "REPLACE")
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    log(f"weights: head {min(head):.2f}..{max(head):.2f}")


def solidify(obj, thickness):
    mod = obj.modifiers.new("solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1.0  # grow towards the head, the outer surface stays where it was draped
    mod.use_rim = True
    obj.modifiers.move(obj.modifiers.find("solidify"), 0)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier="solidify")


def export(path, objs, animations):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(path), export_format="GLB", use_selection=True,
                              export_animations=animations, export_animation_mode="ACTIONS",
                              export_skins=True, export_morph=True)
    log("wrote", path)


def main():
    a = parse_args()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.body))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
        bpy.data.objects.remove(o, do_unlink=True)  # glTF importer's phantom Icosphere / Cube
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()

    old = [o for o in bpy.data.objects if o.name.startswith(CLOTH)]
    mat = next((m for o in old for m in o.data.materials if m), None)
    scale = texel_scale(old) if old else 4.0
    for o in old:
        bpy.data.objects.remove(o, do_unlink=True)
    log(f"dropped {len(old)} old headcloth meshes; linen {scale:.2f} uv/m, material {mat.name if mat else None}")

    head_obj = bpy.data.objects["Anatomy_Head"]
    skin = [head_obj, bpy.data.objects["Anatomy_Torso"]]
    eyes = bpy.data.objects["Anatomy_Head_Eyes"]
    ec = [eyes.matrix_world @ Vector(c) for c in eyes.bound_box]
    eyes_c = sum(ec, Vector()) / 8
    hb = [head_obj.matrix_world @ Vector(c) for c in head_obj.bound_box]
    head_top = max(p.z for p in hb)
    centre = Vector((0.0, (min(p.y for p in hb) + max(p.y for p in hb)) / 2, eyes_c.z + 0.01))
    head_z = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    log(f"eyes {tuple(round(x, 3) for x in eyes_c)}, centre {tuple(round(x, 3) for x in centre)}, head joint z {head_z:.3f}")

    bvh = body_bvh(skin)
    obj = build_cloth(a, bvh, eyes_c, centre, head_top)
    # Ray test only: a nearest-point push-out follows the normal of the ear's back face
    # and folds the cloth into the gap behind the ear.
    log(f"outermost: {clear_outermost([v.co for v in obj.data.vertices], bvh, centre, a.ease)} vertices cleared")
    for uvl in obj.data.uv_layers:
        for d in uvl.data:
            d.uv *= scale
    if mat:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    skin_weights(obj, skin, rig, head_z)
    solidify(obj, a.thickness)

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent is rig]
    export(a.out, [rig] + meshes, True)
    rep = {"out": a.out, "cloth_verts": len(obj.data.vertices), "meshes": sorted(o.name for o in meshes)}
    if a.wearable_out:
        # Wearable GLB: same rig, cloth only, no clips (like the MPFB wearables).
        acts = rig.animation_data.action if rig.animation_data else None
        if rig.animation_data:
            rig.animation_data.action = None
        export(a.wearable_out, [rig, obj], False)
        if acts:
            rig.animation_data.action = acts
        rep["wearable"] = a.wearable_out
    json.dump(rep, open(os.path.splitext(a.out)[0] + ".report.json", "w"), indent=1)
    log("done", json.dumps(rep))


main()
