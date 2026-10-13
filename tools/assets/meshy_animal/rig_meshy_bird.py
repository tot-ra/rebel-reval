"""Rig a Meshy image-to-3D bird scan onto the shared 9-bone StorybookRig.

Usage (Blender 4+/5, headless):
  blender -b --factory-startup --python tools/assets/meshy_animal/rig_meshy_bird.py -- \
    --meshy build/duck_meshy/<task>.glb --donor assets/birds/duck/duck.glb \
    --landmarks tools/assets/meshy_animal/duck_landmarks.json --out build/duck_meshy/duck_rigged.glb

WHY a donor rig: the runtime (map_view_bird_assets.gd, bird flight, penned fauna) drives
the bird by bone names (Body, Head, Leg.L/R, Tail, Wing.L/R, WingTip.L/R) and eight clips
(Idle Walk Hop Peck Fly Glide TakeOff Land). Those clips are rotation keys on bones, so
any mesh that is skinned to the same bone names and axes animates unchanged. The script
keeps the donor armature and its actions, moves the joints onto the scan and replaces the
mesh. Weights are analytic (smoothstep on position) because the scan topology is arbitrary.
"""
import argparse, json, sys
import bpy, numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--meshy", required=True)
ap.add_argument("--donor", required=True)
ap.add_argument("--landmarks", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--target-tris", type=int, default=30000)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--scale", type=float, default=1.0)
a = ap.parse_args(argv)
L = json.load(open(a.landmarks))


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- donor: keep armature + actions, drop its meshes -----------------------------------
bpy.ops.import_scene.gltf(filepath=a.donor)
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
n_donor = {o.name for o in bpy.data.objects}

# --- scan -------------------------------------------------------------------------------
bpy.ops.import_scene.gltf(filepath=a.meshy)
mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o.name not in n_donor)
for o in list(bpy.data.objects):
    if o.type == "EMPTY" and o is not rig:
        for c in o.children:
            c.parent = None
        bpy.data.objects.remove(o, do_unlink=True)
mesh.parent = None
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Feet on z=0, centred on x; scale to the donor's size.
co = np.array([v.co[:] for v in mesh.data.vertices])
off = Vector((-(co[:, 0].max() + co[:, 0].min()) / 2, 0.0, -co[:, 2].min()))
for v in mesh.data.vertices:
    v.co = (v.co + off) * a.scale
mesh.data.update()

# Decimate in place. Collapse keeps the UV layout so the Meshy atlas still fits.
tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
mod = mesh.modifiers.new("dec", "DECIMATE")
mod.ratio = min(1.0, a.target_tris / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="dec")
print("decimated tris", tris, "->", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
mesh.name = "Bird"
for p in mesh.data.polygons:
    p.use_smooth = True

# --- joints -----------------------------------------------------------------------------
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = rig.data.edit_bones
for name, (head, tail) in L["bones"].items():
    b = eb[name]
    b.head = Vector(head)
    b.tail = Vector(tail)
bpy.ops.object.mode_set(mode="OBJECT")

# --- weights ----------------------------------------------------------------------------
P = np.array([v.co[:] for v in mesh.data.vertices])
x, y, z = P[:, 0], P[:, 1], P[:, 2]
ax = np.abs(x)
W = L["weights"]
# Wing root grows outward below the shoulder line so the belly stays on Body.
xs = W["wing_x0"] + np.maximum(0.0, W["wing_z0"] - z) * W["wing_belly_slope"]
wing = smooth(ax, xs, xs + W["wing_blend"]) * smooth(z, W["wing_zmin"], W["wing_zmin"] + 0.08)
tip = smooth(ax, W["tip_x0"], W["tip_x0"] + W["tip_blend"])
head = smooth(z, W["head_z0"], W["head_z0"] + W["head_blend"]) * (1 - smooth(ax, 0.12, 0.22)) * (y < W["head_ymax"])
leg = (1 - smooth(z, W["leg_z0"], W["leg_z0"] + W["leg_blend"])) * (1 - smooth(y, W["leg_ymax"], W["leg_ymax"] + 0.12))
tail = smooth(y, W["tail_y0"], W["tail_y0"] + W["tail_blend"]) * (1 - smooth(z, W["tail_zmax"], W["tail_zmax"] + 0.15))
sx = np.where(x >= 0, 1.0, 0.0)  # +x is the .L side in the donor rig (Wing.L tail x>0)
raw = {
    "Wing.L": wing * (1 - tip) * sx, "WingTip.L": wing * tip * sx,
    "Wing.R": wing * (1 - tip) * (1 - sx), "WingTip.R": wing * tip * (1 - sx),
    "Head": head * (1 - wing), "Leg.L": leg * sx * (1 - wing), "Leg.R": leg * (1 - sx) * (1 - wing),
    "Tail": tail * (1 - wing) * (1 - head),
}
tot = sum(raw.values())
scale = np.where(tot > 1.0, 1.0 / np.maximum(tot, 1e-6), 1.0)
for k in raw:
    raw[k] = raw[k] * scale
raw["Body"] = np.clip(1.0 - sum(raw.values()), 0.0, 1.0)
for name, w in raw.items():
    vg = mesh.vertex_groups.new(name=name)
    for i in np.nonzero(w > 0.002)[0]:
        vg.add([int(i)], float(w[i]), "REPLACE")
mesh.parent = rig
mm = mesh.modifiers.new("Armature", "ARMATURE")
mm.object = rig
print({k: int((v > 0.5).sum()) for k, v in raw.items()})

# --- folded wings -------------------------------------------------------------------------
# WHY: the donor ground clips (Idle Walk Peck Hop ...) hold the wings in one constant fold
# tuned to a thin donor wing. A scan wing is a broad flat sheet, so that fold leaves it
# sticking out. Rebuild the fold for the scan: roll the sheet upright, sweep it back along the
# flank, bend the tip down. Only keys that sit on the donor fold are replaced, so Fly, Glide
# and the transitions keep their own values.
from mathutils import Euler, Quaternion, Matrix
F = L.get("fold")
if F:
    def rest_rot(bn):
        return rig.data.bones[bn].matrix_local.to_3x3()

    def local_quat(bn, world_delta):
        r = rest_rot(bn)
        return (r.inverted() @ world_delta @ r).to_quaternion()

    def fold_for(side):
        s_ = 1.0 if side == "L" else -1.0
        roll = Matrix.Rotation(-s_ * np.radians(F["roll"]), 3, "X")
        yaw = Matrix.Rotation(s_ * np.radians(F["yaw"]), 3, "Z")
        wing = local_quat("Wing." + side, yaw @ roll)
        # Tip bends about its own rest axis most aligned with world Y (sheet normal after roll).
        r = rest_rot("WingTip." + side)
        axes = [r.col[i].normalized() for i in range(3)]
        ai = max(range(3), key=lambda i: abs(axes[i][2]))
        tip = Quaternion(Vector((1 if i == ai else 0) for i in range(3)), np.radians(F["tip"] * s_))
        return wing, tip

    def channels(act):
        if hasattr(act, "fcurves"):
            return list(act.fcurves)
        return [fc for ly in act.layers for st in ly.strips for cb in st.channelbags for fc in cb.fcurves]

    fold_frames = {}
    for act in bpy.data.actions:
        by = {}
        for fc in channels(act):
            for side in "LR":
                for bn in ("Wing.", "WingTip."):
                    if fc.data_path == f'pose.bones["{bn}{side}"].rotation_quaternion':
                        by.setdefault((bn, side), {})[fc.array_index] = fc
        for side in "LR":
            wq, tq = fold_for(side)
            fw = by.get(("Wing.", side))
            if not fw or len(fw) < 4:
                continue
            for k in range(len(fw[0].keyframe_points)):
                cur = Quaternion([fw[i].keyframe_points[k].co[1] for i in range(4)])
                # donor fold has |w| ~ 0.55 and is far from identity; flight keys are near identity
                if abs(cur.w) > 0.8:
                    continue
                for i in range(4):
                    fw[i].keyframe_points[k].co[1] = wq[i]
                ft = by.get(("WingTip.", side))
                if ft and len(ft) == 4:
                    for i in range(4):
                        ft[i].keyframe_points[k].co[1] = tq[i]
                fold_frames.setdefault(act.name, set()).add(round(fw[0].keyframe_points[k].co[0]))
                print("fold key", act.name, side, k)
    # A scan wing is a fan: flight feathers diverge, so a rigid rotation can never lay them
    # parallel against the flank. Squash the fan across the chord (bone-local X) and slightly
    # along the span while folded, then restore scale 1 in the flight keys.
    SC = F.get("scale", [1, 1, 1])
    rig.animation_data_create()
    for aname, frames in fold_frames.items():
        rig.animation_data.action = bpy.data.actions[aname]
        for fr in sorted(frames):
            bpy.context.scene.frame_set(fr)
            for side in "LR":
                for bn in ("Wing.", "WingTip."):
                    pb = rig.pose.bones[bn + side]
                    pb.scale = Vector(SC)
                    pb.keyframe_insert("scale", frame=fr)
    rig.animation_data.action = None

# --- textures: cap the atlas so the GLB stays under the LFS line -----------------------
for img in bpy.data.images:
    if img.size[0] > a.tex:
        img.scale(a.tex, a.tex)

# --- export -----------------------------------------------------------------------------
for o in bpy.data.objects:
    o.select_set(o in (mesh, rig))
bpy.ops.export_scene.gltf(
    filepath=a.out, export_format="GLB", use_selection=True, export_animations=True,
    export_animation_mode="ACTIONS", export_skins=True, export_apply=False,
    export_image_format="JPEG", export_jpeg_quality=88, export_yup=True,
)
print("wrote", a.out, "actions", [x.name for x in bpy.data.actions])
