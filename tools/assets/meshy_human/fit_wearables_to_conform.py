"""Refit a character's MPFB wearables onto its conformed (Meshy-shaped) body.

  blender -b --factory-startup --python tools/assets/meshy_human/fit_wearables_to_conform.py -- \
      --donor assets/characters/realistic/<char>/<char>.glb \
      --conformed build/<char>_meshy/conform/<char>_conformed.glb \
      --wearable assets/characters/realistic/<char>/work_gown/work_gown.glb \
      --wearable assets/characters/realistic/<char>/waist_apron/waist_apron.glb \
      --wearable assets/characters/realistic/<char>/boots/boots.glb \
      --wearable-keep assets/characters/realistic/<char>/headscarf/headscarf.glb \
      --albedo build/<char>_meshy/conform/<char>_skin_albedo_rgb.png \
      --out-dir build/<char>_meshy/dressed

--out-dir may be the character's asset folder itself (assets/characters/realistic/<char>)
to install the result in place: the GLBs keep referencing the shared texture files
(textures/, ../makehuman/, ../textiles/) like the MPFB build does, instead of embedding
copies. Re-running in place is safe: the donor then equals the conformed body, the
offsets are zero and the cloth is only pushed out again.

Why this works: conform_mpfb_to_meshy.py keeps the MPFB topology, so every body
vertex has a known rest offset (conformed - donor). Cloth vertices take a smooth
inverse-distance blend of the offsets of their nearest body vertices, then any
vertex the new body (or an inner layer) still swallows is pushed out by a small gap.

Writes:
- <out-dir>/<char>.glb: the conformed body without the baked headcloth, plus the
  donor's Clothing_* underlayer (fitted the same way) and Hair_* (riding on the
  nearest scalp offset), so it has the same mesh set as the shipped MPFB body and
  wearables that cover Hair_Scalp still equip.
- <out-dir>/<wearable>/<wearable>.glb for every --wearable / --wearable-keep, on the
  same 71-bone rig, without animations (like the MPFB wearables).
- <out-dir>/textures/<char>_skin_albedo.png: a copy of --albedo (the scan albedo baked
  onto the MPFB UVs by the conform step; convert it to RGB first). The body's other
  textures are relinked to the donor's files, which the conformed GLB had embedded.
- <out-dir>/fit.report.json with per-wearable offsets and push-out counts.

--wearable-keep keeps the donor fit and moves only by the outward part of the body
growth, then pushes out swallowed vertices: a headcloth that follows the scan skull
slides its brim over the eyes (see SKILL.md), but an ear the scan made bigger must
not poke through it.
Wearables are fitted in the given order; each later one is also pushed out of the
earlier ones, so list inner layers first (gown before apron).
"""

import argparse
import json
import os
import re
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

BODY = "Anatomy_"


def log(*a):
    print("[fit]", *a, flush=True)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--donor", required=True)
    p.add_argument("--conformed", required=True)
    p.add_argument("--wearable", action="append", default=[])
    p.add_argument("--wearable-keep", action="append", default=[])
    p.add_argument("--out-dir", required=True)
    p.add_argument("--albedo", required=True, help="baked scan albedo on the MPFB UVs (RGB PNG)")
    p.add_argument("--body-name", default="", help="body GLB basename (default: donor basename)")
    p.add_argument("--k", type=int, default=24, help="body vertices blended per cloth vertex")
    p.add_argument("--gap", type=float, default=0.003, help="push-out clearance over the layer below, m")
    return p.parse_args(argv)


def import_glb(path):
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    objs = [o for o in bpy.data.objects if o not in before_o]
    # glTF importer adds a phantom Icosphere (no vertex groups) for skinned scenes.
    for o in [o for o in objs if o.type == "MESH" and not o.vertex_groups]:
        objs.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    return objs, [a for a in bpy.data.actions if a not in before_a]


def rest_pose(rig):
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()


def world_rest(o):
    mw = o.matrix_world
    return np.array([tuple(mw @ v.co) for v in o.data.vertices])


def remove(objs):
    for o in objs:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)


def rebind(objs, rig):
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = mw
        for m in o.modifiers:
            if m.type == "ARMATURE":
                m.object = rig


def bvh_of(objs):
    bm = bmesh.new()
    for o in objs:
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


class OffsetField:
    """Rest-pose body offset (conformed - donor), sampled as an inverse-distance blend."""

    def __init__(self, donor_pts, offsets, k):
        self.pts, self.off, self.k = donor_pts, offsets, k
        self.kd = KDTree(len(donor_pts))
        for i, p in enumerate(donor_pts):
            self.kd.insert(p, i)
        self.kd.balance()

    def at(self, p):
        hits = self.kd.find_n(p, self.k)
        idx = np.array([h[1] for h in hits])
        d = np.array([h[2] for h in hits])
        # Weight by distance relative to the nearest hit: a skirt hem far from the
        # legs still gets a smooth blend instead of one leg's offset.
        w = 1.0 / (d - d.min() + 0.01) ** 2
        return (self.off[idx] * w[:, None]).sum(0) / w.sum()


    def outward(self, p):
        """Only the part of the offset that grows the body towards `p`.

        A keep-fit headcloth must clear an ear the scan made bigger, but must not
        follow a cranium the scan set lower (its brim would slide over the eyes).
        """
        _co, i, _d = self.kd.find(p)
        out = np.asarray(p) - self.pts[i]
        out /= max(np.linalg.norm(out), 1e-6)
        return max(0.0, float(self.at(p) @ out)) * out


def shift_mesh(o, field, follow=True):
    """Move every vertex (and shape key) by the field offset at its donor rest position."""
    mwi = o.matrix_world.inverted().to_3x3()
    pts = world_rest(o)
    offs = [field.at(p) if follow else field.outward(p) for p in pts]
    keys = o.data.shape_keys.key_blocks if o.data.shape_keys else None
    for i, dv in enumerate(offs):
        delta = mwi @ Vector(dv)
        if keys:
            for kb in keys:
                kb.data[i].co += delta
        else:
            o.data.vertices[i].co += delta
    return float(np.median(np.linalg.norm(np.array(offs), axis=1))) if offs else 0.0


def push_out(objs, under, gap):
    """Push vertices the layer below swallowed back out along its surface normal."""
    tree = bvh_of(under)
    moved = 0
    for o in objs:
        mw, mwi = o.matrix_world, o.matrix_world.inverted()
        for v in o.data.vertices:
            p = mw @ v.co
            hit, n, _i, _d = tree.find_nearest(p, 0.05)
            if hit is not None and (p - hit).dot(n) < gap:
                v.co = mwi @ (hit + n * gap)
                moved += 1
    return moved


def relink_images(meshes, donor_images, albedo_old, albedo_new):
    """Point the body at the donor's texture files, and the baked albedo at its install copy.

    The conformed GLB embeds every image; exporting with keep-originals needs file-backed
    images so the GLB references the shared textures like the MPFB build does.
    """
    for mat in {m for o in meshes for m in o.data.materials if m and m.node_tree}:
        for n in mat.node_tree.nodes:
            if n.type != "TEX_IMAGE" or n.image is None:
                continue
            base = re.sub(r"\.\d{3}$", "", n.image.name)
            if base == albedo_old:
                n.image = albedo_new
            elif base in donor_images:
                n.image = donor_images[base]
            elif not n.image.filepath:
                sys.exit(f"[fit] {mat.name}: embedded image {n.image.name} has no donor file to relink")


def export(rig, meshes, path, animations):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is rig or o in meshes)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(path), export_format="GLB", use_selection=True,
                              export_animations=animations, export_animation_mode="ACTIONS",
                              export_skins=True, export_morph=True, export_keep_originals=True)


def main():
    a = parse_args()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    # Donor: rest positions of every Anatomy_* mesh, plus the underlayer/hair to carry over.
    d_objs, d_acts = import_glb(a.donor)
    d_rig = next(o for o in d_objs if o.type == "ARMATURE")
    donor_images = {i.name: i for i in bpy.data.images if i.filepath}
    rest_pose(d_rig)
    donor_rest = {o.name: world_rest(o) for o in d_objs if o.type == "MESH" and o.name.startswith(BODY)}
    carry = [o for o in d_objs if o.type == "MESH" and o.name.startswith(("Clothing_", "Hair_"))]
    carry_names = [o.name for o in carry]
    for o in carry:  # free their names before the conformed import
        o.name = "carry__" + o.name
    remove([o for o in d_objs if o not in carry and o.type == "MESH"])
    # Donor actions would collide with the conformed clip names (Idle -> Idle.001).
    for act in d_acts:
        bpy.data.actions.remove(act)

    c_objs, _ = import_glb(a.conformed)
    rig = next(o for o in c_objs if o.type == "ARMATURE")
    rest_pose(rig)
    rebind(carry, rig)
    bpy.data.objects.remove(d_rig, do_unlink=True)
    for o, name in zip(carry, carry_names):
        o.name = name
        o.data.name = name

    baked_cloth = [o for o in c_objs if o.type == "MESH" and o.name.startswith("Garment_")]
    remove(baked_cloth)
    body = [o for o in rig.children if o.type == "MESH" and o.name.startswith(BODY)]
    skin = [o for o in body if o.name in donor_rest and len(donor_rest[o.name]) == len(o.data.vertices)]
    mismatch = sorted(set(o.name for o in body) - set(o.name for o in skin))
    if mismatch:
        sys.exit(f"[fit] topology differs from donor for {mismatch}: conformed body must come from this donor")
    donor_pts = np.concatenate([donor_rest[o.name] for o in skin])
    offsets = np.concatenate([world_rest(o) for o in skin]) - donor_pts
    field = OffsetField(donor_pts, offsets, a.k)
    log(f"body offset field: {len(donor_pts)} verts, median {np.median(np.linalg.norm(offsets, axis=1)) * 1000:.1f} mm, "
        f"max {np.linalg.norm(offsets, axis=1).max() * 1000:.1f} mm")

    report = {"conformed": a.conformed, "donor": a.donor, "wearables": {}}
    # Underlayer (braies) and hair: follow the body, then clear the skin.
    for o in carry:
        med = shift_mesh(o, field)
        moved = push_out([o], skin, a.gap * 0.5)
        report["wearables"][o.name] = {"median_offset_mm": round(med * 1000, 1), "pushed_out": moved}
        log(f"{o.name}: median offset {med * 1000:.1f} mm, pushed out {moved}")

    body_name = a.body_name or os.path.splitext(os.path.basename(a.donor))[0]
    albedo_path = os.path.join(a.out_dir, "textures", f"{body_name}_skin_albedo.png")
    os.makedirs(os.path.dirname(albedo_path), exist_ok=True)
    if os.path.abspath(a.albedo) != os.path.abspath(albedo_path):
        shutil.copyfile(a.albedo, albedo_path)
    albedo = bpy.data.images.load(os.path.abspath(albedo_path), check_existing=False)
    albedo.name = f"{body_name}_skin_albedo"
    # conform_mpfb_to_meshy.py names its baked image skin_albedo.
    relink_images(body + carry, donor_images, "skin_albedo", albedo)
    body_out = os.path.join(a.out_dir, body_name + ".glb")
    export(rig, body + carry, body_out, animations=True)
    report["body"] = {"out": body_out, "meshes": sorted(o.name for o in body + carry),
                      "actions": len(bpy.data.actions), "bones": len(rig.data.bones),
                      "shape_keys": sorted({k.name for o in body if o.data.shape_keys
                                            for k in o.data.shape_keys.key_blocks})}

    under = list(skin)
    jobs = [(p, True) for p in a.wearable] + [(p, False) for p in a.wearable_keep]
    for path, follow in jobs:
        w_objs, w_acts = import_glb(path)
        for act in w_acts:
            bpy.data.actions.remove(act)
        w_rig = next(o for o in w_objs if o.type == "ARMATURE")
        meshes = [o for o in w_objs if o.type == "MESH"]
        rebind(meshes, rig)
        bpy.data.objects.remove(w_rig, do_unlink=True)
        meds = [shift_mesh(o, field, follow) for o in meshes]
        moved = push_out(meshes, under, a.gap)
        stem = os.path.splitext(os.path.basename(path))[0]
        out = os.path.join(a.out_dir, stem, stem + ".glb")
        export(rig, meshes, out, animations=False)
        report["wearables"][stem] = {"out": out, "follow_body": follow, "meshes": sorted(o.name for o in meshes),
                                     "median_offset_mm": round(float(np.median(meds)) * 1000, 1),
                                     "pushed_out": moved}
        log(f"{stem}: follow={follow} median offset {np.median(meds) * 1000:.1f} mm, pushed out {moved}")
        # Later layers clear this one too (apron over gown). Keep-fit headcloths
        # are not layers anyone sits on.
        if follow:
            under += meshes
        else:
            remove(meshes)

    os.makedirs(a.out_dir, exist_ok=True)
    json.dump(report, open(os.path.join(a.out_dir, "fit.report.json"), "w"), indent=1)
    log("done", json.dumps(report))


main()
