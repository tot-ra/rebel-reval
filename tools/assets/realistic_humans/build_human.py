"""Build a realistic human from an MPFB/MakeHuman CC0 body (ADR 0022).

Blender 5.2 headless, MPFB 2.0.17 installed by install_mpfb.sh:

    blender -b --python-exit-code 1 --python tools/assets/realistic_humans/build_human.py -- --character=kalev

Pipeline:
1. MPFB creates the base body from the spec's macros and detail targets and
   fits eyes, brows, lashes, teeth and hair proxies with MakeHuman's authored
   weights on its `game_engine` rig.
2. The body is posed into the shared motion rig's T-pose (palms down, loose
   fist) and that pose is applied as the new rest shape.
3. The shared 41-bone motion rig (from the committed Kalev source blend, 76
   clips) has its joints moved onto the MPFB joints without changing any bone
   orientation, so every clip keeps its meaning. MPFB weights are renamed onto
   the shared bones.
4. The body is split into the stable wardrobe regions, surfaced, and exported
   with all clips. Garments come from garments.py against the same rig.

Coordinates: metres, Blender Z up, character front toward -Y.
"""
from pathlib import Path
import argparse
import importlib
import json
import math
import os
import struct
import sys

import addon_utils
import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402
import specs as spec_module  # noqa: E402
import surfaces  # noqa: E402
import garments  # noqa: E402
LOCATION_DATA = None

MOTION_BLEND = ROOT / "assets/characters/kalev_fresh/source/kalev_fresh.blend"
MOTION_RIG = "KalevMotionRig"
OUT_ROOT = ROOT / "assets/characters/realistic"
WORK = ROOT / "build/realistic_humans"
MPFB = "bl_ext.user_default.mpfb"

# MPFB game_engine bone -> {shared bone: share}. Fingers fold into the hand:
# the shared rig has no finger bones, so the hand is baked as a loose fist.
WEIGHT_MAP = {
    "Root": {"hips": 1.0}, "pelvis": {"hips": 1.0},
    "spine_01": {"spine": 1.0}, "spine_02": {"spine": 1.0}, "spine_03": {"chest": 1.0},
    "neck_01": {"chest": 0.3, "head": 0.7}, "head": {"head": 1.0},
}
for _s in ("l", "r"):
    WEIGHT_MAP.update({
        f"clavicle_{_s}": {"chest": 1.0},
        f"upperarm_{_s}": {f"upperarm.{_s}": 1.0},
        f"lowerarm_{_s}": {f"lowerarm.{_s}": 1.0},
        f"hand_{_s}": {f"hand.{_s}": 1.0},
        f"thigh_{_s}": {f"upperleg.{_s}": 1.0},
        f"calf_{_s}": {f"lowerleg.{_s}": 1.0},
        f"foot_{_s}": {f"foot.{_s}": 1.0},
        f"ball_{_s}": {f"toes.{_s}": 1.0},
    })
    for _f in ("thumb", "index", "middle", "ring", "pinky"):
        for _i in (1, 2, 3):
            WEIGHT_MAP[f"{_f}_0{_i}_{_s}"] = {f"hand.{_s}": 1.0}

# Mesh names are a stable API: CharacterWearable.covered_meshes hides them.
REGIONS = ("Anatomy_Head", "Anatomy_Torso", "Anatomy_Arms", "Anatomy_Forearms", "Anatomy_Hands",
           "Anatomy_Legs", "Anatomy_Calves", "Anatomy_Feet")
TEXTILES = OUT_ROOT / "textiles"
MAKEHUMAN_TEXTURES = OUT_ROOT / "makehuman"


def log(*args):
    print("[realistic_humans]", *args, flush=True)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def mpfb():
    addon_utils.enable(MPFB, default_set=True)
    services = {}
    for name in ("humanservice", "targetservice", "locationservice"):
        services[name] = importlib.import_module(f"{MPFB}.services.{name}")
    return (services["humanservice"].HumanService, services["targetservice"].TargetService,
            services["locationservice"].LocationService)


# --------------------------------------------------------------------------
# 1. MPFB body
# --------------------------------------------------------------------------

def create_mpfb_body(spec):
    HumanService, TargetService, LocationService = mpfb()
    data = LocationService.get_user_data()
    targets_dir = LocationService.get_mpfb_data("targets")
    body = HumanService.create_human(macro_detail_dict=spec["macros"], scale=0.1)
    for name, weight in spec["targets"].items():
        # Sided targets (l-/r-) may be named once and apply symmetrically.
        variants = [name] if list(Path(targets_dir).glob(f"*/{name}.target.gz")) else [f"l-{name}", f"r-{name}"]
        for variant in variants:
            found = list(Path(targets_dir).glob(f"*/{variant}.target.gz"))
            if not found:
                raise SystemExit(f"unknown MakeHuman target {name}")
            TargetService.load_target(body, str(found[0]), weight=weight, name=variant)
    HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
    sources = {"Anatomy_Head_Eyes": ("Eyes", "eyes/high-poly/high-poly.mhclo"),
               "Anatomy_Head_Brows": ("Eyebrows", f"eyebrows/{spec['eyebrows']}/{spec['eyebrows']}.mhclo"),
               "Anatomy_Head_Lashes": ("Eyelashes", f"eyelashes/{spec['eyelashes']}/{spec['eyelashes']}.mhclo"),
               "Anatomy_Head_Teeth": ("Teeth", "teeth/teeth_base/teeth_base.mhclo")}
    if spec.get("hair") and spec.get("hair_cards", True):
        sources["Hair_Scalp"] = ("Hair", f"hair/{spec['hair']}/{spec['hair']}.mhclo")
    proxies = {}
    for name, (kind, rel) in sources.items():
        proxy = HumanService.add_mhclo_asset(os.path.join(data, rel), body, asset_type=kind,
                                             subdiv_levels=0, material_type="MAKESKIN")
        proxy.name = name
        proxy.data.name = name
        proxies[name] = proxy
    TargetService.bake_targets(body)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig.name = "MPFBRig"
    body.name = "MPFBBody"
    return body, rig, data, proxies


# --------------------------------------------------------------------------
# 2. T-pose with a loose fist
# --------------------------------------------------------------------------

def _rotate_pose_bone(rig, name, pivot, rotation):
    pb = rig.pose.bones[name]
    rot = rotation.to_matrix().to_4x4() if hasattr(rotation, "to_matrix") else rotation
    pb.matrix = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ pb.matrix
    bpy.context.view_layer.update()


def _bone_dir(rig, name):
    pb = rig.pose.bones[name]
    return (pb.tail - pb.head).normalized()


def _palm_roll(rig, s):
    """Signed roll about the hand axis that turns the back of the hand to +Z."""
    pbs = rig.pose.bones
    hand = pbs[f"hand_{s}"].head
    # Left hand points +X with the thumb forward (-Y): index x pinky points up
    # from the back of the hand. The mirrored right hand flips the sign.
    back = (pbs[f"index_01_{s}"].head - hand).cross(pbs[f"pinky_01_{s}"].head - hand)
    if s == "r":
        back = -back
    axis = _bone_dir(rig, f"hand_{s}")
    back_flat = (back - axis * back.dot(axis)).normalized()
    up_flat = (Vector((0, 0, 1)) - axis * axis.z).normalized()
    angle = back_flat.angle(up_flat)
    return angle if back_flat.cross(up_flat).dot(axis) >= 0 else -angle


def pose_to_motion_rest(rig, motion_rest):
    """Rotate MPFB limbs onto the shared rig's rest directions."""
    chains = []
    for s in ("l", "r"):
        chains += [(f"upperarm_{s}", f"upperarm.{s}"), (f"lowerarm_{s}", f"lowerarm.{s}"),
                   (f"hand_{s}", f"hand.{s}"), (f"thigh_{s}", f"upperleg.{s}"),
                   (f"calf_{s}", f"lowerleg.{s}"), (f"foot_{s}", f"foot.{s}")]
    for mpfb_name, shared in chains:
        head, tail = motion_rest[shared]
        target = (tail - head).normalized()
        current = _bone_dir(rig, mpfb_name)
        _rotate_pose_bone(rig, mpfb_name, rig.pose.bones[mpfb_name].head.copy(),
                          current.rotation_difference(target))
    pbs = rig.pose.bones
    for s in ("l", "r"):
        # Roll the straight arm about its own axis until the back of the hand
        # faces up. Half at the shoulder, half along the forearm: putting the
        # whole roll on the hand bone candy-wraps the wrist.
        angle = _palm_roll(rig, s)
        axis = _bone_dir(rig, f"lowerarm_{s}")
        _rotate_pose_bone(rig, f"upperarm_{s}", pbs[f"upperarm_{s}"].head.copy(),
                          Matrix.Rotation(angle * 0.4, 4, axis))
        _rotate_pose_bone(rig, f"lowerarm_{s}", pbs[f"lowerarm_{s}"].head.copy(),
                          Matrix.Rotation(angle * 0.6, 4, axis))
        log(f"palm roll {s}: {math.degrees(angle):.1f} deg, residual {math.degrees(_palm_roll(rig, s)):.1f}")
        hand = pbs[f"hand_{s}"].head
        # Loose fist around a front-to-back grip (the shared handslot barrel).
        curl_axis = Vector((0, 1, 0)) if s == "l" else Vector((0, -1, 0))
        for finger, curls in (("index", (48, 62, 38)), ("middle", (52, 66, 40)),
                              ("ring", (56, 68, 42)), ("pinky", (60, 70, 44))):
            for i, degrees in enumerate(curls, start=1):
                bone = f"{finger}_0{i}_{s}"
                _rotate_pose_bone(rig, bone, pbs[bone].head.copy(),
                                  Matrix.Rotation(math.radians(degrees), 4, curl_axis))
        for i, degrees in enumerate((22, 28, 24), start=1):
            bone = f"thumb_0{i}_{s}"
            thumb_axis = _bone_dir(rig, f"hand_{s}")
            _rotate_pose_bone(rig, bone, pbs[bone].head.copy(),
                              Matrix.Rotation(math.radians(degrees if s == "l" else -degrees), 4, thumb_axis))


def apply_pose_as_rest(objects):
    for obj in objects:
        activate(obj)
        for mod in list(obj.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
        for mod in list(obj.modifiers):
            if mod.type == "MASK":
                bpy.ops.object.modifier_apply(modifier=mod.name)


# --------------------------------------------------------------------------
# 3. Shared motion rig fit
# --------------------------------------------------------------------------

def load_motion_rig():
    with bpy.data.libraries.load(str(MOTION_BLEND), link=False) as (src, dst):
        dst.objects = [MOTION_RIG]
        dst.actions = list(src.actions)
    rig = dst.objects[0]
    bpy.context.scene.collection.objects.link(rig)
    rig.animation_data_create()
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    for action in bpy.data.actions:
        action.use_fake_user = True
    rig.name = "HumanMotionRig"
    return rig


def motion_rest_directions(rig):
    return {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones}


def joint_targets(mpfb_rig):
    p = {b.name: (mpfb_rig.matrix_world @ b.head, mpfb_rig.matrix_world @ b.tail)
         for b in mpfb_rig.pose.bones}
    t = {}
    thigh_mid = (p["thigh_l"][0] + p["thigh_r"][0]) / 2
    t["hips"] = Vector((0, thigh_mid.y, thigh_mid.z))
    t["spine"] = Vector((0, *p["spine_01"][0].yz))
    t["chest"] = Vector((0, *p["spine_03"][0].yz))
    neck_head, neck_tail = p["neck_01"]
    t["head"] = neck_head.lerp(neck_tail, 0.3)
    t["neck_base"] = neck_head.copy()
    t["head_top"] = p["head"][1]
    for s in ("l", "r"):
        t[f"upperarm.{s}"] = p[f"upperarm_{s}"][0]
        t[f"lowerarm.{s}"] = p[f"lowerarm_{s}"][0]
        t[f"wrist.{s}"] = p[f"hand_{s}"][0]
        axis = (p[f"hand_{s}"][1] - p[f"hand_{s}"][0]).normalized()
        t[f"hand.{s}"] = p[f"hand_{s}"][0] + axis * 0.012
        knuckle = p[f"middle_01_{s}"][0]
        # Grip barrel centre: under the palm, level with the curled middle finger.
        t[f"handslot.{s}"] = t[f"wrist.{s}"].lerp(knuckle, 0.78) + Vector((0, 0, -0.035))
        t[f"upperleg.{s}"] = p[f"thigh_{s}"][0]
        t[f"lowerleg.{s}"] = p[f"calf_{s}"][0]
        t[f"foot.{s}"] = p[f"foot_{s}"][0]
        t[f"toes.{s}"] = p[f"ball_{s}"][0]
        t[f"toes_tip.{s}"] = p[f"ball_{s}"][1]
    return t


CHILD = {"hips": "spine", "spine": "chest", "chest": "head", "head": "head_top"}
for _s in ("l", "r"):
    CHILD.update({f"upperarm.{_s}": f"lowerarm.{_s}", f"lowerarm.{_s}": f"wrist.{_s}",
                  f"wrist.{_s}": f"hand.{_s}", f"upperleg.{_s}": f"lowerleg.{_s}",
                  f"lowerleg.{_s}": f"foot.{_s}", f"foot.{_s}": f"toes.{_s}",
                  f"toes.{_s}": f"toes_tip.{_s}"})


def fit_motion_rig(rig, targets, scale):
    """Move joints onto the body without changing a single bone orientation."""
    activate(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in rig.data.edit_bones:
        bone.use_connect = False
    edits = {}
    for bone in rig.data.edit_bones:
        direction = (bone.tail - bone.head)
        length = direction.length
        direction.normalize()
        roll_matrix = bone.matrix.copy()
        if bone.name in targets:
            head = targets[bone.name]
            child = CHILD.get(bone.name)
            if child in targets:
                length = max(0.01, (targets[child] - head).dot(direction))
            elif bone.name.startswith("hand."):
                length = length * 0.9
        else:
            # Non-deforming IK/control bones scale with the body.
            head = bone.head * scale
            length *= scale
        edits[bone.name] = (head, direction, length, roll_matrix)
    for name, (head, direction, length, roll_matrix) in edits.items():
        bone = rig.data.edit_bones[name]
        bone.head = head
        bone.tail = head + direction * length
        bone.align_roll(roll_matrix.to_3x3() @ Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")


def rename_weights(obj):
    """Fold MPFB deform groups into the shared bone names."""
    names = {g.index: g.name for g in obj.vertex_groups}
    shared = {}
    # Surface masks (lips, scalp, ears, nails) stay; the exporter skips groups
    # that are not bones.
    for vertex in obj.data.vertices:
        mix = {}
        for g in vertex.groups:
            for bone, share in WEIGHT_MAP.get(names[g.group], {}).items():
                mix[bone] = mix.get(bone, 0.0) + g.weight * share
        if mix:
            top = sorted(mix.items(), key=lambda kv: kv[1], reverse=True)[:4]
            total = sum(w for _, w in top)
            shared[vertex.index] = [(b, w / total) for b, w in top if w / total > 0.002]
    for group in list(obj.vertex_groups):
        if group.name in WEIGHT_MAP or group.name.startswith(("joint-", "helper-")):
            obj.vertex_groups.remove(group)
    groups = {}
    for index, weights in shared.items():
        for bone, weight in weights:
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([index], weight, "REPLACE")
    return shared


def bind(obj, rig):
    obj.parent = rig
    obj.matrix_parent_inverse = Matrix.Identity(4)
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# --------------------------------------------------------------------------
# 4. Regions, surfaces, export
# --------------------------------------------------------------------------

def collar_plane(targets):
    """Neckline height as a function of depth: low at the throat, higher behind."""
    base = targets["neck_base"]
    front_y, back_y = base.y - 0.07, base.y + 0.07
    z_front, z_back = base.z - 0.035, base.z + 0.005
    def collar(y):
        s = min(1.0, max(0.0, (y - front_y) / (back_y - front_y)))
        s = s * s * (3 - 2 * s)
        return z_front + (z_back - z_front) * s
    return collar


def dominant_region(weights, co, collar):
    if not weights:
        return "Anatomy_Torso"
    bone = weights[0][0]
    # Skin stays visible 3 cm below any neckline so gaps never show the hollow body.
    if bone == "head" or (bone in ("chest", "spine") and co.z > collar(co.y) - 0.03):
        return "Anatomy_Head"
    if bone in ("hips", "spine", "chest"):
        return "Anatomy_Torso"
    if bone.startswith(("hand", "wrist")):
        return "Anatomy_Hands"
    if bone.startswith("upperarm"):
        return "Anatomy_Arms"
    if bone.startswith("lowerarm"):
        return "Anatomy_Forearms"
    if bone.startswith("upperleg"):
        return "Anatomy_Legs"
    if bone.startswith("lowerleg"):
        return "Anatomy_Calves"
    return "Anatomy_Feet"


def split_regions(body, shared, collar):
    """Separate the body into wardrobe regions keeping seamless custom normals."""
    mesh = body.data
    mesh.shade_smooth()
    region_of_face = []
    for poly in mesh.polygons:
        votes = {}
        for vi in poly.vertices:
            region = dominant_region(shared.get(vi, []), mesh.vertices[vi].co, collar)
            votes[region] = votes.get(region, 0) + 1
        region_of_face.append(max(votes.items(), key=lambda kv: kv[1])[0])
    # Freeze the continuous normals before cutting so seams stay invisible.
    corner_normals = [Vector(n.vector) for n in mesh.corner_normals]
    mesh.normals_split_custom_set(corner_normals)
    parts = []
    for region in REGIONS:
        part = body.copy()
        part.data = body.data.copy()
        part.name = region
        part.data.name = region
        bpy.context.scene.collection.objects.link(part)
        bm = bmesh.new()
        bm.from_mesh(part.data)
        bm.faces.ensure_lookup_table()
        doomed = [f for f in bm.faces if region_of_face[f.index] != region]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(part.data)
        bm.free()
        if part.data.polygons:
            parts.append(part)
        else:
            bpy.data.objects.remove(part, do_unlink=True)
    bpy.data.objects.remove(body, do_unlink=True)
    return parts


def surface_character(spec, body, proxies, shared, collar, targets, data, texture_dir):
    # complexion_fields expects: 0 head, 2 upper arm/forearm (sleeve exposure), 3 hands.
    legacy = {"Anatomy_Head": 0, "Anatomy_Torso": 1, "Anatomy_Arms": 2, "Anatomy_Forearms": 2,
              "Anatomy_Hands": 3, "Anatomy_Legs": 4, "Anatomy_Calves": 5, "Anatomy_Feet": 6}
    regions_of_vertex = np.array([
        legacy[dominant_region(shared.get(v.index, []), v.co, collar)] for v in body.data.vertices])
    lm = surfaces.landmarks(body, proxies["Anatomy_Head_Eyes"], targets)
    hair_texture = None
    if "Hair_Scalp" in proxies:
        # Recolour the card texture by luminance to the spec's hair colour, so
        # any MakeHuman style can take any natural colour and the painted
        # scalp underneath matches the cards.
        card = next((Path(data) / "hair" / spec["hair"]).glob("*diffuse*.png"))
        spec.setdefault("hair_color", tuple(surfaces.opaque_median(card)))
        hair_texture = surfaces.recolor_hair(card, spec["hair_color"], texture_dir / f"{spec['fit']}_hair.png")
    skin_dir = Path(data) / "skins" / spec["skin"]
    albedo = next(skin_dir.glob("*diffuse*.png"))
    size = 2048 if spec.get("tier", 1) == 0 else 1024
    maps = surfaces.bake_skin(body, spec, lm, regions_of_vertex, albedo, texture_dir, size=size)
    # Crowd skin-tone variation rides on the material factor, so one baked
    # albedo can serve lighter and darker seeded bodies.
    tint = tuple(spec.get("complexion", {}).get("skin_tint", (1.0, 1.0, 1.0)))
    skin = surfaces.pbr_material(f"{spec['fit']}_skin", maps["albedo"], maps["normal"], maps["roughness"],
                                 color=tint, specular=0.45)
    surfaces.assign(body, skin)
    eye_png = Path(data) / "eyes" / "materials" / f"{spec['eyes']}_eye.png"
    surfaces.assign(proxies["Anatomy_Head_Eyes"],
                    surfaces.pbr_material(f"{spec['fit']}_eyes_cutout", eye_png, color=(0.8, 0.77, 0.74),
                                          roughness=0.06, specular=0.6, alpha_clip=True))
    brows = Path(data) / "eyebrows" / spec["eyebrows"] / f"{spec['eyebrows']}.png"
    lashes = Path(data) / "eyelashes" / spec["eyelashes"] / f"{spec['eyelashes']}.png"
    hair_tint = tuple(spec.get("brow_tint", (0.8, 0.8, 0.8)))
    surfaces.assign(proxies["Anatomy_Head_Brows"],
                    surfaces.pbr_material(f"{spec['fit']}_brows_cutout", brows, color=hair_tint,
                                          roughness=0.7, alpha_clip=True))
    surfaces.assign(proxies["Anatomy_Head_Lashes"],
                    surfaces.pbr_material(f"{spec['fit']}_lashes_cutout", lashes, roughness=0.7, alpha_clip=True))
    teeth = Path(data) / "teeth" / "teeth_base" / "teeth.png"
    surfaces.assign(proxies["Anatomy_Head_Teeth"],
                    surfaces.pbr_material(f"{spec['fit']}_teeth", teeth, color=(0.82, 0.78, 0.68), roughness=0.4))
    if "Hair_Scalp" in proxies:
        hair_dir = Path(data) / "hair" / spec["hair"]
        # MakeHuman hair normals use the opposite green convention and shade
        # the crown black in Godot; card geometry carries enough relief.
        surfaces.assign(proxies["Hair_Scalp"],
                        surfaces.pbr_material(f"{spec['fit']}_hair_cutout", hair_texture,
                                              roughness=0.72, alpha_clip=True, specular=0.3))
    grooming = []
    if spec.get("hair") and (spec.get("scalp_fur") or "Hair_Scalp" not in proxies):
        fur = surfaces.scalp_shells(body, lm, spec, texture_dir, size=size)
        if "Hair_Scalp" not in proxies:
            # Without cards the fur is the hair and takes the wardrobe's
            # Hair_Scalp name, so hoods and helmets still hide it.
            fur.name = fur.data.name = "Hair_Scalp"
        grooming.append(fur)
    if spec.get("beard"):
        grooming.append(surfaces.beard_shells(body, lm, spec, texture_dir, size=size))
    decimate(proxies["Anatomy_Head_Teeth"], 0.3)
    return grooming, lm


def decimate(obj, ratio):
    mod = obj.modifiers.new("Budget", "DECIMATE")
    mod.ratio = ratio
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def patch_alpha_modes(path):
    """Hair, brow, lash, eye and fur materials (`*_cutout`) are alpha-tested.

    Never name them `*_alpha`: Godot's scene importer treats that suffix as
    "force alpha blending" and strips it.
    """
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    for material in doc.get("materials", []):
        name = material.get("name", "")
        if name.endswith("_cutout"):
            material["alphaMode"] = "MASK"
            # Fur shells encode strand length against exactly 0.5 (surfaces.py);
            # hair cards carry soft alpha at the crown, where a high cutoff opens holes.
            material["alphaCutoff"] = 0.5 if name.endswith("_fur_cutout") else \
                0.12 if name.endswith("hair_cutout") else 0.35
            material["doubleSided"] = True
        factor = surfaces.MATERIAL_FACTORS.get(name)
        if factor is not None:
            pbr = material.setdefault("pbrMetallicRoughness", {})
            alpha = pbr.get("baseColorFactor", [1, 1, 1, 1])[3]
            pbr["baseColorFactor"] = factor + [alpha]
    blob = json.dumps(doc, separators=(",", ":")).encode()
    blob += b" " * ((-len(blob)) % 4)
    rest = raw[20 + length:]
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(blob) + len(rest))
    path.write_bytes(header + struct.pack("<II", len(blob), 0x4E4F534A) + blob + rest)


def clearance_bvh(body):
    """Body surface garments keep their ease from, with nipples smoothed flat:
    cloth spans the breast, it never tents on skin detail."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    deform = bm.verts.layers.deform.verify()
    groups = [body.vertex_groups[n].index for n in ("nipple", "nippleTip") if n in body.vertex_groups]
    ring = {v for v in bm.verts if any(v[deform].get(g, 0.0) > 0.02 for g in groups)}
    for v in list(ring):
        ring.update(e.other_vert(v) for e in v.link_edges)
    if ring:
        for _ in range(25):
            bmesh.ops.smooth_vert(bm, verts=list(ring), factor=0.8, use_axis_x=True, use_axis_y=True,
                                  use_axis_z=True)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def finish_glb(path, character_dir):
    patch_alpha_modes(path)
    link_textures(path, [character_dir / "textures", TEXTILES, MAKEHUMAN_TEXTURES])


def link_textures(path, directories):
    """Reference shared PNGs by relative URI instead of embedding copies."""
    sys.path.insert(0, str(ROOT / "tools"))
    import share_character_textures as share
    gltf, bin_data = share.parse_glb(path)
    users = share._buffer_view_users(gltf)
    drop = set()
    for image in gltf.get("images", []):
        stem = str(image.get("name", "")).removesuffix(".png")
        target = next((d / f"{stem}.png" for d in directories if (d / f"{stem}.png").exists()), None)
        if target is None and "bufferView" in image and stem:
            # MakeHuman CC0 texture: copy once into the shared runtime folder.
            source = next(Path(LOCATION_DATA).rglob(f"{stem}.png"), None) if LOCATION_DATA else None
            if source is not None:
                MAKEHUMAN_TEXTURES.mkdir(parents=True, exist_ok=True)
                target = MAKEHUMAN_TEXTURES / source.name
                if not target.exists():
                    copy_texture(source, target, 1024)
        if target is None or "bufferView" not in image:
            continue
        view = image.pop("bufferView")
        image.pop("mimeType", None)
        image["uri"] = os.path.relpath(target, path.parent).replace(os.sep, "/")
        if all(kind == "image" and "bufferView" not in gltf["images"][i] for kind, i in users.get(view, [])):
            drop.add(view)
    bin_data = share._compact_bin(gltf, bin_data, drop)
    share.write_glb(path, gltf, bin_data)


def prune_makehuman_textures():
    """Drop copied MakeHuman maps that no realistic GLB references any more."""
    sys.path.insert(0, str(ROOT / "tools"))
    import share_character_textures as share
    used = set()
    for glb in OUT_ROOT.rglob("*.glb"):
        gltf, _ = share.parse_glb(glb)
        for image in gltf.get("images", []):
            if "uri" in image:
                used.add((glb.parent / image["uri"]).resolve())
    for png in MAKEHUMAN_TEXTURES.glob("*.png"):
        if png.resolve() not in used:
            png.unlink()
            Path(str(png) + ".import").unlink(missing_ok=True)


def copy_texture(source, target, max_px):
    """Copy a CC0 map, downscaled to the Tier 1 cap so any tier may share it."""
    img = bpy.data.images.load(str(source), check_existing=False)
    if max(img.size) > max_px:
        img.scale(max_px, max_px)
        img.filepath_raw = str(target)
        img.file_format = "PNG"
        img.save()
    else:
        target.write_bytes(source.read_bytes())
    bpy.data.images.remove(img)


def write_wearable(spec, name, garment, slot, covered):
    res = f"res://assets/characters/realistic/{name}"
    covered_list = ", ".join(f'&"{c}"' for c in covered)
    (OUT_ROOT / name / f"{garment}.tres").write_text(f"""[gd_resource type="Resource" script_class="CharacterWearable" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/characters/character_wearable.gd" id="1"]
[ext_resource type="PackedScene" path="{res}/{garment}/{garment}.glb" id="2"]

[resource]
script = ExtResource("1")
stable_id = &"wearable.{spec['fit']}.{garment}"
slot = "{slot}"
fitted_body = "{name}"
scene = ExtResource("2")
covered_meshes = Array[StringName]([{covered_list}])
""")


def write_outfits(spec, name):
    (OUT_ROOT / name / "outfits.json").write_text(json.dumps(spec.get("outfits", {}), indent=2) + "\n")


def export_glb(path, objects, animations):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_animations=animations, export_animation_mode="ACTIONS",
        export_force_sampling=True, export_frame_range=False,
        export_anim_single_armature=True, export_image_format="AUTO",
        export_all_influences=False, export_apply=False, export_yup=True)


def build(name, only_body=False):
    spec = spec_module.SPECS[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    motion = load_motion_rig()
    motion_rest = motion_rest_directions(motion)
    global LOCATION_DATA
    body, mpfb_rig, data, named_proxies = create_mpfb_body(spec)
    LOCATION_DATA = data
    proxies = list(named_proxies.values())
    pose_to_motion_rest(mpfb_rig, motion_rest)
    apply_pose_as_rest([body] + proxies)
    targets = joint_targets(mpfb_rig)

    # Uniform scale to the spec stature; the rig joints follow.
    top = max(v.co.z for v in body.data.vertices)
    scale = spec["height_m"] / top
    for obj in [body] + proxies:
        obj.data.transform(Matrix.Scale(scale, 4))
    targets = {k: v * scale for k, v in targets.items()}
    bpy.data.objects.remove(mpfb_rig, do_unlink=True)
    fit_motion_rig(motion, targets, targets["hips"].z / motion_rest["hips"][0].z)

    shared = rename_weights(body)
    for proxy in proxies:
        rename_weights(proxy)
    collar = collar_plane(targets)
    out = OUT_ROOT / name
    grooming, lm = surface_character(spec, body, named_proxies, shared, collar, targets, data, out / "textures")
    ctx = garments.Ctx(spec=spec, body=body, rig=motion, t=targets, lm=lm, collar=collar, out=out)
    ctx.bvh = clearance_bvh(body)
    braies = garments.braies(ctx)
    wardrobe = {}
    for garment in spec.get("garments", []):
        slot, covered, builder = garments.WARDROBE[garment]
        wardrobe[garment] = (slot, covered, builder(ctx))
        if slot == "torso":
            ctx.layers[garment] = BVHTree.FromObject(wardrobe[garment][2][0], bpy.context.evaluated_depsgraph_get())
        log(f"garment {garment}: {sum(len(o.data.polygons) for o in wardrobe[garment][2])} faces")
    regions = split_regions(body, shared, collar)
    meshes = regions + [braies] + proxies + grooming
    for obj in meshes:
        bind(obj, motion)
    export_glb(out / f"{name}.glb", [motion] + meshes, animations=True)
    finish_glb(out / f"{name}.glb", out)
    for garment, (slot, covered, objects) in wardrobe.items():
        for obj in objects:
            bind(obj, motion)
            obj["garment"] = garment
            obj["covers"] = ",".join(covered)
        path = out / garment / f"{garment}.glb"
        export_glb(path, [motion] + objects, animations=False)
        finish_glb(path, out)
        write_wearable(spec, name, garment, slot, covered)
    write_outfits(spec, name)
    WORK.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / f"{name}.blend"))
    stats = {
        "character": name, "height_m": spec["height_m"],
        "triangles": {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes},
        "clips": len(bpy.data.actions),
    }
    stats["triangles_total"] = sum(stats["triangles"].values())
    log(json.dumps(stats))
    return stats


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", default="kalev")
    args = parser.parse_args(argv)
    build(args.character)
    prune_makehuman_textures()


if __name__ == "__main__":
    main()
