"""Rig a Meshy image-to-3D quadruped scan onto the shared mammal rig, add hair cards
with baked secondary motion, and export LOD0/LOD1/LOD2 GLBs.

Usage (Blender 4+/5, headless):
  blender -b --factory-startup --python tools/assets/meshy_animal/rig_meshy_quadruped.py -- \
    --meshy build/horse_meshy/bare/01a14bbf-8905-71a9-a340-f28cf12319ba.glb \
    --landmarks tools/assets/meshy_animal/horse_landmarks.json \
    --out assets/animals/horse/horse.glb \
    --lod1 assets/animals/horse/horse_lod1.glb --lod2 assets/animals/horse/horse_lod2.glb \
    --report generated/blender/horse_v2/report.json

Rig: the runtime (map_view_medieval_animal_models.gd) drives mammals by bone names
(Body, Head, Tail, Leg/Shin/Ankle/Foot.{LF,RF,LB,RB}), six clips (Idle Walk Run Graze
LookAround Alert) and the walk/run_reference_speed extras. The armature is built like
import_realistic_mammals.create_rig() with joints from the landmarks JSON, and the clips
come from its animate(): the shared mammal_limb_anatomy solver re-plants the hooves for
these leg lengths. WHY not copy the old horse's clips (rig_meshy_bird.py keeps a donor):
they were solved for the old legs, so on the scan the soles sank through the ground and
lost support (test_mammal_limb_anatomy). Weights are analytic because scan topology is
arbitrary.

Hair: the scan body is bare (task R-1173 decision). Mane, forelock and tail are the
procedural alpha cards from tools/assets/build_horse_source.py (hair(), hair_atlas()),
re-rooted on this body's crest and dock. Mane locks and the tail plume get short bone
chains; a small spring simulation (inertia from the clip + periodic wind) is baked into
every clip so the hair moves in Godot without any runtime code. Clips stay seamless loops.
"""
import argparse
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[3]
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--meshy", required=True)
ap.add_argument("--landmarks", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--lod1")
ap.add_argument("--lod2")
ap.add_argument("--report")
a = ap.parse_args(argv)
L = json.load(open(a.landmarks))
W = L["weights"]
H = L["hair"]


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def tris_of(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# --- scan -------------------------------------------------------------------------------
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(Path(a.meshy).resolve()))
mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o not in before)
for o in list(bpy.data.objects):
    if o not in before and o is not mesh:
        bpy.data.objects.remove(o, do_unlink=True)
mesh.parent = None
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Hooves on z=0, centred on x, withers at the target height. Landmarks are in scan space
# and go through the same transform.
co = np.array([v.co[:] for v in mesh.data.vertices])
ground = co[:, 2].min()
cx = (co[:, 0].max() + co[:, 0].min()) / 2
K = L["withers_height"] / (L["withers"][2] - ground)


def T(p):
    return Vector(((p[0] - cx) * K, p[1] * K, (p[2] - ground) * K))


def Tz(z):
    return (z - ground) * K


for v in mesh.data.vertices:
    v.co = T(v.co)
mesh.data.update()
mesh.name = L.get("mesh_name", "surface")

# Straighten a turned head. The scan's face sits up to ~0.15 to one side, so x=0 (where
# the rig, the crest ray-casts and the forelock live) missed the midline. Shift each
# cross-section in front of the withers by its own bounding-box midpoint (legs excluded
# by height), faded in from the withers so the trunk is untouched.
co = np.array([v.co[:] for v in mesh.data.vertices])
y_w = T(L["withers"]).y
z_cut = Tz(W["belly_z"]) + 0.25 * K
bins = np.arange(co[:, 1].min(), y_w + 0.02, 0.02)
mids = []
for b0 in bins:
    s = (np.abs(co[:, 1] - b0) < 0.02) & (co[:, 2] > z_cut)
    mids.append((co[s, 0].max() + co[s, 0].min()) / 2 if s.sum() > 8 else 0.0)
mids = np.convolve(np.pad(mids, 3, mode="edge"), np.ones(7) / 7, mode="valid")
mids *= smooth(-bins, -y_w, -y_w + 0.15 * K)
co[:, 0] -= np.interp(co[:, 1], bins, mids, right=0.0)
for v, c in zip(mesh.data.vertices, co):
    v.co = c
print("head straightened by", round(float(np.abs(mids).max()), 3))
print("scale", K, "ground", ground)

# Coat material: opaque, non-metallic (the scan's metal channel only adds a plastic
# sheen to a horse), roughness/normal maps kept.
coat = mesh.data.materials[0]
coat.name = "horse_coat"
nt = coat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
for inp in ("Alpha", "Metallic"):
    for link in list(bsdf.inputs[inp].links):
        nt.links.remove(link)
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Alpha"].default_value = 1.0
coat.blend_method = "OPAQUE" if hasattr(coat, "blend_method") else None
if hasattr(coat, "surface_render_method"):
    coat.surface_render_method = "DITHERED"
for n in nt.nodes:
    if n.type == "TEX_IMAGE" and n.image:
        out = [l.to_socket.name for l in n.outputs["Color"].links] + [l.to_node.type for l in n.outputs["Color"].links]
        tag = "albedo" if "Base Color" in out else "normal" if "NORMAL_MAP" in out else "orm"
        n.image.name = f"horse_coat_{tag}"

# --- LOD bodies: decimate copies of the full scan. Collapse keeps the Meshy UV atlas. -----
full = mesh
full_tris = tris_of(full)
bodies = {}
for key in ("lod0", "lod1", "lod2"):
    if key != "lod0" and not getattr(a, key):
        continue
    obj = full.copy()
    obj.data = full.data.copy()
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = min(1.0, L["lods"][key]["tris"] / full_tris)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.name = mesh.name if key == "lod0" else f"{mesh.name}_{key}"
    bodies[key] = obj
    print(key, "tris", full_tris, "->", tris_of(obj))
bpy.data.objects.remove(full, do_unlink=True)
body0 = bodies["lod0"]
body0.name = L.get("mesh_name", "surface")

# --- rig and clips (import_realistic_mammals.create_rig/animate) -----------------------
sys.path.insert(0, str(ROOT / "tools/assets"))
import import_realistic_mammals as irm  # noqa: E402  (needs bpy; tools/assets on sys.path)
from mammal_limb_anatomy import Limb  # noqa: E402

bone_pos = {n: (T(h), T(t)) for n, (h, t) in L["bones"].items()}
arm = bpy.data.armatures.new("AnatomicalRig")
rig = bpy.data.objects.new("AnatomicalRig", arm)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
PARENT = {"Head": "Body", "Tail": "Body"}
for sfx in ("LF", "RF", "LB", "RB"):
    PARENT.update({f"Leg.{sfx}": "Body", f"Shin.{sfx}": f"Leg.{sfx}",
                   f"Ankle.{sfx}": f"Shin.{sfx}", f"Foot.{sfx}": f"Ankle.{sfx}"})
for name in ["Body"] + [n for n in L["bones"] if n != "Body"]:
    b = arm.edit_bones.new(name)
    b.head, b.tail = bone_pos[name]
    if name in PARENT:
        b.parent = arm.edit_bones[PARENT[name]]
bpy.ops.object.mode_set(mode="OBJECT")
h_total = max(v.co.z for v in body0.data.vertices)
limbs = []
for sfx in ("LF", "RF", "LB", "RB"):
    # Limb points: shoulder/hip, elbow/stifle, carpus/hock, coronet (ball), toe.
    pts = [tuple(bone_pos[f"Leg.{sfx}"][0])] + [tuple(bone_pos[f"{p}.{sfx}"][1]) for p in ("Leg", "Shin", "Ankle", "Foot")]
    limbs.append(Limb(sfx, tuple(pts), .03 * h_total, .035 * h_total, .035 * h_total, 2, True))
bz = bone_pos["Body"][0].z
irm.animate(rig, limbs, "horse", bz)
rig["species"] = "horse"
rig["anatomy_revision"] = "meshy-scan-v1"
rig["source_url"] = "Meshy image-to-3D " + Path(a.meshy).stem
print("reference speeds", {k: rig.get(k) for k in ("walk_reference_speed", "run_reference_speed")})

# --- body weights -----------------------------------------------------------------------
LIMBS = ("LF", "RF", "LB", "RB")
SEG = ("Leg.", "Shin.", "Ankle.", "Foot.")
withers = T(L["withers"])
poll = bone_pos["Head"][0]


def seg_dist(P, a_, b_):
    d = np.array(b_ - a_)
    t = np.clip(((P - np.array(a_)) @ d) / max(d @ d, 1e-9), 0, 1)
    return np.linalg.norm(P - (np.array(a_) + t[:, None] * d), axis=1)


def body_weights(P):
    """Analytic skin weights. Legs: each quadrant owns its four-bone chain below the
    trunk, fading into Body over the shoulder/hip muscle and between the limbs. Trunk:
    Body, with Head rising along the withers->poll line and Tail on the dock."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    side = np.where(x >= 0, "L", "R")
    out = {}
    belly = Tz(W["belly_z"])
    lat0, lat1 = W["limb_lateral"][0] * K, W["limb_lateral"][1] * K
    limb_total = np.zeros(len(P))
    for fam in LIMBS:
        own = side == fam[0]
        fore = np.array(bone_pos["Leg." + fam[0] + "F"][0])
        rear = np.array(bone_pos["Leg." + fam[0] + "B"][0])
        df, db = np.abs(y - fore[1]), np.abs(y - rear[1])
        mine = own & ((df < db) if fam[1] == "F" else (df >= db))
        top = bone_pos["Leg." + fam][0].z + W["limb_top_pad"] * K
        # Full limb below the belly line; above it only on the flank over the joint.
        mix = 1 - smooth(z, belly - 0.04 * K, top)
        mix *= np.maximum(smooth(np.abs(x), lat0, lat1), 1 - smooth(z, belly - 0.10 * K, belly + 0.03 * K))
        # No competing front/rear chain across the flank: blend to the trunk midway.
        mix *= smooth(np.abs(df - db) / np.maximum(df + db, 1e-3), 0, 0.55)
        mix = np.where(mine, mix, 0.0)
        dist = np.stack([seg_dist(P, *bone_pos[s + fam]) for s in SEG], 1)
        inv = 1.0 / np.maximum(dist, 0.02) ** 2
        # Keep the two nearest of Leg/Shin/Ankle plus Foot for the hoof.
        upper = inv[:, :3].copy()
        drop = np.argmin(upper, axis=1)
        upper[np.arange(len(P)), drop] = 0.0
        sole = 1 - smooth(z, 0.05 * K, 0.11 * K)
        foot = sole
        ups = upper / np.maximum(upper.sum(1, keepdims=True), 1e-9) * (1 - sole)[:, None]
        for i, s in enumerate(SEG[:3]):
            out[s + fam] = ups[:, i] * mix
        # Foot shares the lowest segment's influence near the coronet and owns the hoof.
        out["Foot." + fam] = foot * mix
        limb_total += mix
    trunk = 1 - limb_total
    wv = np.array(withers)
    pv = np.array(poll)
    d = pv[1:] - wv[1:]
    t = ((P[:, 1:] - wv[1:]) @ d) / (d @ d)
    head = smooth(t, *W["head_t"]) * (y < wv[1])
    tail = smooth(y, W["tail_y"][0] * K, W["tail_y"][1] * K) * smooth(z, Tz(W["tail_z"][0]), Tz(W["tail_z"][1]))
    out["Head"] = head * trunk
    out["Tail"] = tail * (1 - head) * trunk
    out["Body"] = np.clip(trunk - out["Head"] - out["Tail"], 0, 1)
    return out


def apply_weights(obj, weights):
    for name, w in weights.items():
        vg = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
        idx = np.nonzero(w > 0.002)[0]
        for i in idx:
            vg.add([int(i)], float(w[i]), "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


dock_a, dock_b = (np.array(p_) for p_ in bone_pos["Tail"])
for obj in bodies.values():
    P = np.array([v.co[:] for v in obj.data.vertices])
    bw = body_weights(P)
    # The scan keeps a coat-coloured dock stump thicker than the card ring that roots
    # the tail plume, so it showed as an orange club above the hair. Pull dock vertices
    # toward the Tail bone axis; the cards then wrap it.
    d = dock_b - dock_a
    t = np.clip(((P - dock_a) @ d) / (d @ d), 0, 1)
    axis = dock_a + t[:, None] * d
    P = axis + (P - axis) * (1 - W["dock_squash"] * bw["Tail"])[:, None]
    for v, c in zip(obj.data.vertices, P):
        v.co = c
    apply_weights(obj, bw)
    print(obj.name, {k: int((v > 0.5).sum()) for k, v in bw.items()})

# --- hair cards (reuse build_horse_source.py) -------------------------------------------
spec = importlib.util.spec_from_file_location("build_horse_source", ROOT / "tools/assets/build_horse_source.py")
bhs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bhs)
# Rebind the card roots to this body (forward f = -y, heights in world units).
bhs.MANE_POLL_F = -H["mane_poll_y"] * K + 0.03
bhs.MANE_SPAN = (H["mane_withers_y"] - H["mane_poll_y"]) * K
bhs.DOCK_ROOT = (-H["dock_root"][0] * K, Tz(H["dock_root"][1]))
bhs.DOCK_TIP = (-H["dock_tip"][0] * K, Tz(H["dock_tip"][1]))
# Forelock frame: hp(u, v) runs from the poll down the face line; v=0.054 is the skin.
# Only the two heights come from landmarks; the face profile at x=0 is ray-cast so the
# ears (which stand in front of the poll in a side view) cannot be mistaken for it.


def face_f(z):
    hit = tree.ray_cast(Vector((0.0, -5.0, z)), Vector((0.0, 1.0, 0.0)))
    return -hit[0].y


tree = bhs.crest_height_fn(body0)[1]
fr = Vector((face_f(Tz(H["forelock_root_z"])), Tz(H["forelock_root_z"])))
fp = Vector((face_f(Tz(H["face_point_z"])), Tz(H["face_point_z"])))
theta = math.atan2(fr.y - fp.y, fp.x - fr.x)
bhs.HS = H["head_scale"]
bhs.HEAD_THETA = theta
bhs.HEAD_P0 = (fr.x - bhs.HS * 0.054 * math.sin(theta), fr.y - bhs.HS * 0.054 * math.cos(theta))

rng = random.Random(bhs.SEED)
hair_mat = bhs.make_hair_material(bhs.hair_atlas(rng))
hair_mat.name = "horse_hair"
crest, tree = bhs.crest_height_fn(body0)
# The scanned brow bulges in front of the straight poll-to-face line, which buried the
# forelock. Ray-cast the forehead along the forelock path and push the frame out until
# every card row clears the skin (hair() lays rows at v = .054 + .014 sin(pi u)).
n_face = Vector((0.0, -math.sin(theta), math.cos(theta)))  # +v in Blender axes (nose is -Y)
clear = -1.0
for k in range(12):
    u = -0.012 + 0.230 * k / 11
    far = bhs.hp(u, 0.6, 0.0)
    hit = tree.ray_cast(far, -n_face, 1.0)
    if hit[0] is not None:
        v_skin = 0.6 - (hit[0] - far).length / bhs.HS
        clear = max(clear, v_skin - (0.054 + 0.014 * math.sin(math.pi * k / 11)))
shift = (clear + 0.010) * bhs.HS
bhs.HEAD_P0 = (bhs.HEAD_P0[0] + shift * math.sin(theta), bhs.HEAD_P0[1] + shift * math.cos(theta))
print("forelock offset", round(shift, 4))
hair = {}
for group, cards in bhs.hair(rng, crest, tree).items():
    cards.name = f"horse_{group}"
    for poly in cards.data.polygons:
        poly.use_smooth = True
    cards.data.materials.append(hair_mat)
    hair[group] = cards

# Mane roots: hair() starts each lock 1.2 cm over the midline on the off side, which on
# this narrower crest showed as a row of square card ends seen from the right. Sink the
# root row (v=0) to the near side under the skin; the arch row still covers the crest.
bm = bmesh.new()
bm.from_mesh(hair["mane"].data)
uv = bm.loops.layers.uv.active
for vert in bm.verts:
    if any(lp[uv].uv.y < 1e-4 for lp in vert.link_loops):
        vert.co.x = abs(vert.co.x) * 0.5 + 0.012
        vert.co.z -= 0.012
bm.to_mesh(hair["mane"].data)
bm.free()

# --- hair bone chains -------------------------------------------------------------------
n_mane = int(H["mane_chains"])
f_poll = -H["mane_poll_y"] * K
f_with = -H["mane_withers_y"] * K
mane_f = [f_with + (f_poll - f_with) * (i + 0.5) / n_mane for i in range(n_mane)]
MANE_SEG = 0.11  # world units per bone, two bones per lock

chains = {}
for i, f in enumerate(mane_f):
    y = -f
    top = crest(f)
    pts = [Vector((0.0, y, top))]
    for k in (1, 2):
        z = top - MANE_SEG * k
        pts.append(Vector((bhs.surface_x(tree, y, z) + 0.015 * k, y + 0.02 * k, z)))
    hw = float(body_weights(np.array([[0.0, y, top - 0.03]]))["Head"][0])
    chains[f"Mane.{i}"] = {"parent": "Head" if hw > 0.5 else "Body", "joints": pts, "kind": "mane", "phase": 0.8 * i}

# Tail plume chain follows the generated cards: centroid per height band.
tv = np.array([v.co[:] for v in hair["tail"].data.vertices])
dock_tip = Vector((0.0, -bhs.DOCK_TIP[0], bhs.DOCK_TIP[1]))
zs = np.linspace(dock_tip.z, tv[:, 2].min() + 0.05, 5)
tjoints = [dock_tip.copy()]
for zz in zs[1:]:
    band = tv[np.abs(tv[:, 2] - zz) < 0.05]
    tjoints.append(Vector((0.0, float(band[:, 1].mean()) if len(band) else dock_tip.y, float(zz))))
chains["TailHair"] = {"parent": "Tail", "joints": tjoints, "kind": "tail", "phase": 0.0}

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = rig.data.edit_bones
chain_bones = {}
for cname, c in chains.items():
    parent = eb[c["parent"]]
    names = []
    for k in range(len(c["joints"]) - 1):
        b = eb.new(f"{cname}.{k}")
        b.head, b.tail = c["joints"][k], c["joints"][k + 1]
        b.roll = 0.0
        b.parent = parent
        b.use_connect = k > 0
        parent = b
        names.append(b.name)
    chain_bones[cname] = names
bpy.ops.object.mode_set(mode="OBJECT")
for names in chain_bones.values():
    for n in names:
        rig.pose.bones[n].rotation_mode = "QUATERNION"


# --- hair weights -----------------------------------------------------------------------
def chain_param(joints, p):
    """Arc position (0..n_bones) of p projected onto a chain's joints, by height."""
    zj = [j.z for j in joints]
    if p.z >= zj[0]:
        return 0.0
    for k in range(len(zj) - 1):
        if p.z >= zj[k + 1]:
            return k + (zj[k] - p.z) / max(zj[k] - zj[k + 1], 1e-6)
    return float(len(zj) - 1)


def chain_mix(names, s, anchor):
    """Weights along a chain at arc position s, rooted on `anchor` near the skin."""
    w = dict()
    root = 1 - float(smooth(np.array(s), 0.0, 0.35))
    for n, v in anchor.items():
        w[n] = w.get(n, 0) + v * root
    rest = 1 - root
    s = min(max(s - 0.5, 0.0), len(names) - 1.0)
    k = min(int(s), len(names) - 1)
    frac = s - k
    w[names[k]] = w.get(names[k], 0) + rest * (1 - frac)
    if frac > 0 and k + 1 < len(names):
        w[names[k + 1]] = w.get(names[k + 1], 0) + rest * frac
    return w


def hair_weights(obj, group):
    out = {}
    for v in obj.data.vertices:
        p = v.co
        if group == "forelock":
            w = {"Head": 1.0}
        elif group == "tail":
            c = chains["TailHair"]
            w = chain_mix(chain_bones["TailHair"], chain_param(c["joints"], p), {"Tail": 1.0})
        else:
            # Blend the two nearest locks along the crest.
            f = -p.y
            pos = (f - mane_f[0]) / (mane_f[1] - mane_f[0])
            i0 = int(np.clip(math.floor(pos), 0, n_mane - 2))
            t = float(np.clip(pos - i0, 0, 1))
            anchor = {k: float(val[0]) for k, val in body_weights(np.array([[0.0, p.y, crest(f) - 0.03]])).items() if val[0] > 0.002}
            w = {}
            for idx, share in ((i0, 1 - t), (i0 + 1, t)):
                c = chains[f"Mane.{idx}"]
                s = (c["joints"][0].z - p.z) / MANE_SEG
                for n, val in chain_mix(chain_bones[f"Mane.{idx}"], max(s, 0.0), anchor).items():
                    w[n] = w.get(n, 0) + val * share
        for n, val in w.items():
            out.setdefault(n, np.zeros(len(obj.data.vertices)))[v.index] = val
    return out


for group, obj in hair.items():
    apply_weights(obj, hair_weights(obj, group))


# --- secondary motion: spring chains baked into every clip -------------------------------
WIND_DIR = Vector((1.0, 0.35, 0.0)).normalized()
DOWN = Vector((0.0, 0.0, -1.0))
PARAMS = {  # stiffness toward the rigid pose (1/s^2), damping (1/s), wind and gravity (m/s^2)
    "mane": dict(ks=110.0, damp=7.0, wind=2.6, grav=6.0),
    "tail": dict(ks=38.0, damp=4.5, wind=2.2, grav=7.0),
}
fps = scene.render.fps / scene.render.fps_base
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
rig.animation_data_create()


def bake_action(act):
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(round(x)) for x in act.frame_range)
    n = max(f1 - f0, 1)
    period = n / fps
    for names in chain_bones.values():
        for nme in names:
            rig.pose.bones[nme].rotation_quaternion = Quaternion()
    # Parent poses for every frame of the loop.
    parent_pose = {}
    for f in range(f0, f1):
        scene.frame_set(f)
        parent_pose[f] = {c["parent"]: rig.pose.bones[c["parent"]].matrix.copy() for c in chains.values()}
    keys = {}
    for cname, c in chains.items():
        prm = PARAMS[c["kind"]]
        J = c["joints"]
        lens = [(J[k + 1] - J[k]).length for k in range(len(J) - 1)]
        par = c["parent"]
        to_local = rest[par].inverted()

        def targets(f):
            M = parent_pose[f][par]
            return [M @ (to_local @ j) for j in J], M.to_3x3().normalized() @ rest[par].to_3x3().normalized().inverted()

        tg, _ = targets(f0)
        pos = [p.copy() for p in tg]
        prev = [p.copy() for p in tg]
        sub = 6
        dt = 1.0 / fps / sub
        record = {}
        for loop in range(4):
            for f in range(f0, f1):
                tg, R = targets(f)
                tg_next, _ = targets(f0 + (f - f0 + 1) % n)
                # Gravity only acts on the change of parent orientation from rest, so
                # the authored card shape is the equilibrium of a still horse.
                grav = (DOWN - R @ DOWN) * prm["grav"]
                for s_ in range(sub):
                    u = s_ / sub
                    tgt = [a_.lerp(b_, u) for a_, b_ in zip(tg, tg_next)]
                    t = ((f - f0) + u) / fps
                    pos[0] = tgt[0]
                    for k in range(1, len(J)):
                        ph = c["phase"] + 0.7 * k
                        gust = 0.55 + 0.45 * math.sin(math.tau * t / period + ph) + 0.25 * math.sin(2 * math.tau * t / period + 2.1 * ph)
                        acc = (tgt[k] - pos[k]) * prm["ks"] + WIND_DIR * (prm["wind"] * gust * k / (len(J) - 1)) + grav
                        vel = (pos[k] - prev[k]) * (1 - prm["damp"] * dt)
                        prev[k] = pos[k].copy()
                        pos[k] = pos[k] + vel + acc * dt * dt
                    for _ in range(3):
                        for k in range(1, len(J)):
                            d = pos[k] - pos[k - 1]
                            pos[k] = pos[k - 1] + d.normalized() * lens[k - 1]
                if loop == 3:
                    record[f] = [p.copy() for p in pos]
        # Positions -> local bone rotations, walking down the chain.
        names = chain_bones[cname]
        for f in range(f0, f1):
            M_par = parent_pose[f][par]
            q_list = []
            for k, nme in enumerate(names):
                pr = par if k == 0 else names[k - 1]
                M_id = M_par @ rest[pr].inverted() @ rest[nme]
                cur = M_id.to_3x3().normalized()
                want = record[f][k + 1] - record[f][k]
                dq = (cur @ Vector((0, 1, 0))).rotation_difference(want.normalized())
                local = (cur.inverted() @ dq.to_matrix() @ cur).to_quaternion()
                q_list.append(local)
                M_par = M_id @ local.to_matrix().to_4x4()
            keys[(cname, f)] = q_list
    for cname, names in chain_bones.items():
        for f in list(range(f0, f1)) + [f1]:
            qs = keys[(cname, f0 if f == f1 else f)]  # last key equals the first: seamless loop
            for nme, q in zip(names, qs):
                pb = rig.pose.bones[nme]
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
    print("baked hair motion", act.name, f0, f1)


for act in list(bpy.data.actions):
    bake_action(act)
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix()
scene.frame_set(0)


# --- LOD2 hair: keep every Nth card ------------------------------------------------------
def thinned(obj, keep):
    cp = obj.copy()
    cp.data = obj.data.copy()
    cp.name = obj.name + "_lod2"
    scene.collection.objects.link(cp)
    bm = bmesh.new()
    bm.from_mesh(cp.data)
    bm.faces.ensure_lookup_table()
    seen, islands = set(), []
    for face in bm.faces:
        if face.index in seen:
            continue
        stack, island = [face], []
        seen.add(face.index)
        while stack:
            cur = stack.pop()
            island.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        islands.append(island)
    dead = [f for i, isl in enumerate(islands) if i % keep for f in isl]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(cp.data)
    bm.free()
    for m in cp.modifiers:
        m.object = rig
    return cp


# --- export -----------------------------------------------------------------------------
def export(path, objs, tex):
    for img in bpy.data.images:
        if img.size[0] > tex:
            img.scale(tex, tex)
    for o in bpy.data.objects:
        o.select_set(o in objs or o is rig)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(Path(path).resolve()), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
        export_apply=False, export_image_format="JPEG", export_jpeg_quality=85,
        export_yup=True, export_extras=True,
    )
    report = {"path": path, "body_tris": tris_of(objs[0]), "hair_tris": sum(tris_of(o) for o in objs[1:]),
              "tex": tex, "bytes": Path(path).stat().st_size}
    print("wrote", report)
    return report


hair_objs = list(hair.values())
reports = [export(a.out, [bodies["lod0"]] + hair_objs, L["lods"]["lod0"]["tex"])]
if a.lod1:
    reports.append(export(a.lod1, [bodies["lod1"]] + hair_objs, L["lods"]["lod1"]["tex"]))
if a.lod2:
    thin = [thinned(o, L["lods"]["lod2"]["hair_keep"]) for o in hair_objs]
    reports.append(export(a.lod2, [bodies["lod2"]] + thin, L["lods"]["lod2"]["tex"]))

if a.report:
    pts = np.array([v.co[:] for v in body0.data.vertices])
    rep = {
        "scan": Path(a.meshy).name, "scan_tris": full_tris, "scale": K,
        "withers_height_units": L["withers_height"],
        "bounds_min": pts.min(0).round(3).tolist(), "bounds_max": pts.max(0).round(3).tolist(),
        "reference_speeds": {k: rig.get(k) for k in ("walk_reference_speed", "run_reference_speed")},
        "hair_bones": chain_bones, "lods": reports,
        "actions": [x.name for x in bpy.data.actions],
    }
    Path(a.report).parent.mkdir(parents=True, exist_ok=True)
    Path(a.report).write_text(json.dumps(rep, indent=2) + "\n")
    print("report", a.report)
