"""Carry a shipped conformed body onto a rebuilt MPFB body with the same topology (new rig, same shape).

  blender -b --factory-startup --python tools/assets/meshy_human/graft_conformed_shape.py -- \
      --rebuilt build/<char>_mpfb/<char>/<char>.glb \
      --shipped build/<char>_shipped/<char>/<char>.glb \
      --out build/<char>_graft/<char>_conformed.glb

Why: a rig change (ADR 0056 detail bones) needs every human rebuilt, but a Meshy-conformed body
(route A of the meshy-human skill) cannot be conformed again without its scan. The conformed body
keeps the MPFB topology and rest pose, so its rest shape (and every shape key) can be copied vertex
for vertex onto the rebuilt MPFB body, which brings the new rig, weights and clips. Only the
Anatomy_* meshes are written (the shape of the conformed GLB); feed the result to
fit_wearables_to_conform.py as --conformed, with the rebuilt body as --donor, to dress it again.
Meshes the shipped body dropped (Anatomy_Head_Brows) are dropped too.

The skin regions (Anatomy_Torso, _Arms, ...) are split by dominant bone, so a rig change can move border vertices
from one region to the next. Vertices are therefore matched by their MPFB UV (one non-overlapping layout for the
whole skin) across all regions, and only proxies (eyes, lashes, teeth) by mesh name and index.
"""

import argparse
import os
import sys

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

BODY = "Anatomy_"


def log(*a):
    print("[graft]", *a, flush=True)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    objs = [o for o in bpy.data.objects if o not in before]
    for o in [o for o in objs if o.type == "MESH" and not o.vertex_groups]:
        objs.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    rig = next(o for o in objs if o.type == "ARMATURE")
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    return rig, [o for o in objs if o.type == "MESH"]


def vertex_uvs(o):
    """One UV per vertex (the first loop's)."""
    uv = o.data.uv_layers.active.data
    out = [None] * len(o.data.vertices)
    for loop in o.data.loops:
        if out[loop.vertex_index] is None:
            out[loop.vertex_index] = tuple(uv[loop.index].uv)
    return out


PROXIES = ("Anatomy_Head_Eyes", "Anatomy_Head_Lashes", "Anatomy_Head_Teeth", "Anatomy_Head_Brows")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--rebuilt", required=True)
    p.add_argument("--shipped", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    s_rig, s_meshes = import_glb(a.shipped)
    shipped = {}
    skin_pts, skin_keys, skin_uv = [], {}, []
    for o in s_meshes:
        if not o.name.startswith(BODY):
            continue
        keys = o.data.shape_keys.key_blocks if o.data.shape_keys else None
        mw = o.matrix_world
        rest = [mw @ v.co for v in o.data.vertices]
        kd = {kb.name: [mw @ d.co for d in kb.data] for kb in keys} if keys else {}
        shipped[o.name] = {"rest": rest, "keys": kd}
        if not o.name.startswith(PROXIES):
            for i, uv in enumerate(vertex_uvs(o)):
                skin_uv.append(uv); skin_pts.append(rest[i])
                for name, values in kd.items():
                    skin_keys.setdefault(name, {})[len(skin_pts) - 1] = values[i]
    tree = KDTree(len(skin_uv))
    for i, uv in enumerate(skin_uv):
        tree.insert((uv[0], uv[1], 0.0), i)
    tree.balance()
    for o in s_meshes:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.objects.remove(s_rig, do_unlink=True)
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)

    rig, meshes = import_glb(a.rebuilt)
    keep = []
    for o in meshes:
        if not o.name.startswith(BODY) or o.name not in shipped and o.name.startswith(PROXIES):
            log(f"drop {o.name}")
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        mwi = o.matrix_world.inverted()
        keys = o.data.shape_keys.key_blocks if o.data.shape_keys else None
        n = len(o.data.vertices)
        if o.name.startswith(PROXIES):
            src = shipped[o.name]
            if len(src["rest"]) != n:
                sys.exit(f"[graft] {o.name}: {n} vertices, shipped {len(src['rest'])}")
            rest = src["rest"]; key_values = {name: src["keys"].get(name, rest) for name in (kb.name for kb in keys)} if keys else {}
            far = 0
        else:
            idx, far = [], 0
            for uv in vertex_uvs(o):
                _co, j, dist = tree.find((uv[0], uv[1], 0.0))
                far += dist > 2e-4
                idx.append(j)
            rest = [skin_pts[j] for j in idx]
            key_values = {}
            if keys:
                for kb in keys:
                    table = skin_keys.get(kb.name, {})
                    key_values[kb.name] = [table.get(j, skin_pts[j]) for j in idx]
        moved = 0.0
        for i, v in enumerate(o.data.vertices):
            moved = max(moved, (mwi @ rest[i] - v.co).length)
            v.co = mwi @ rest[i]
        if keys:
            for kb in keys:
                for i, d in enumerate(kb.data):
                    d.co = mwi @ key_values[kb.name][i]
        log(f"{o.name}: {n} vertices, {far} without an exact UV match, largest move {moved * 1000:.1f} mm, "
            f"{len(keys) if keys else 0} shape keys")
        if far > 0.01 * n:
            sys.exit(f"[graft] {o.name}: {far} of {n} vertices have no UV match; not the same MPFB topology")
        keep.append(o)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is rig or o in keep)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_skins=True, export_morph=True, export_keep_originals=True)
    log(f"wrote {a.out}: {len(rig.data.bones)} bones, {len(bpy.data.actions)} clips, {len(keep)} meshes")


main()
