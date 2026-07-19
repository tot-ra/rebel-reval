"""Generate our own hero body mesh around the retargeted adult skeleton.

Runs inside Blender (build-time tool only, never at runtime):

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python tools/generate_hero_body.py [-- --character=<spec>]

Input:  the character's skeleton intermediate (see tools/character_specs.py)
        with adult proportions and all 76 CC0 animation clips, produced by
        tools/build_heroic_humanoid_glb.py. Its meshes are placeholders.
Output: the spec's runtime glb — same skeleton and clips, but every visible
        mesh is generated here from scratch, sized from the bone layout so
        proportion changes in the bake flow through, then shaped by the
        spec's `shape` and `palette` overrides.

Skinning is deterministic: each generated vertex is assigned weights at
creation time (rings at joints blend between the two adjacent bones), so no
automatic-weight heuristics are involved.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_specs import spec as character_spec  # noqa: E402
from hero_body_mesh_builder import (  # noqa: E402
    Frame,
    PartBuilder,
    bone_head,
    find_armature,
)

GARMENT_OUTPUTS = {
    "cape": ROOT / "assets/characters/shared/hero_cape.glb",
    "hat": ROOT / "assets/characters/shared/hero_hat.glb",
}

# Default hero palette aligned with the legacy Kalev pixel sprite (img/user__idle.gif):
# brown long tunic, tan belt, dark trousers, brown boots, brown hair/beard.
PALETTE = {
    "skin": (0.80, 0.58, 0.42, 1.0),
    "tunic": (0.38, 0.24, 0.14, 1.0),
    "sleeves": (0.84, 0.83, 0.80, 1.0),
    "sleeve_band": (0.22, 0.42, 0.72, 1.0),
    "pants": (0.16, 0.12, 0.10, 1.0),
    "boots": (0.42, 0.28, 0.16, 1.0),
    "belt": (0.62, 0.46, 0.28, 1.0),
    "hair": (0.48, 0.32, 0.20, 1.0),
    "beard": (0.42, 0.28, 0.16, 1.0),
    "eyes": (0.06, 0.05, 0.05, 1.0),
    "armor": (0.45, 0.47, 0.50, 1.0),
    "cape": (0.42, 0.24, 0.14, 1.0),
    "hat": (0.32, 0.36, 0.28, 1.0),
}


# Effective palette for the selected character: PALETTE plus spec overrides.
_active_palette: dict = dict(PALETTE)


def _material(name: str) -> bpy.types.Material:
    existing = bpy.data.materials.get(f"hero_{name}")
    if existing is not None:
        return existing
    material = bpy.data.materials.new(f"hero_{name}")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    # The palette is authored in sRGB; base color factors are linear.
    srgb = _active_palette[name]
    linear = tuple(pow(channel, 2.2) for channel in srgb[:3]) + (srgb[3],)
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.1
    return material


def _blend(a: str, b: str, t: float) -> dict[str, float]:
    return {a: 1.0 - t, b: t}


def _mix(center_a: Vector, center_b: Vector, t: float) -> Vector:
    return center_a.lerp(center_b, t)


def generate(character: str) -> None:
    selected = character_spec(character)
    shape = selected["shape"]
    features = selected["features"]
    _active_palette.update(selected["palette"])
    source = ROOT / selected["skeleton_intermediate"]
    output = ROOT / selected["output"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    armature = find_armature()
    frame = Frame(armature)
    up, forward, left = frame.up, frame.forward, frame.left

    hips = bone_head(armature, "hips")
    head = bone_head(armature, "head")
    shoulder_l = bone_head(armature, "upperarm.l")
    shoulder_r = bone_head(armature, "upperarm.r")
    elbow_l = bone_head(armature, "lowerarm.l")
    elbow_r = bone_head(armature, "lowerarm.r")
    wrist_l = bone_head(armature, "wrist.l")
    wrist_r = bone_head(armature, "wrist.r")
    hand_l = bone_head(armature, "hand.l")
    hand_r = bone_head(armature, "hand.r")
    socket_l = bone_head(armature, "upperleg.l")
    socket_r = bone_head(armature, "upperleg.r")
    knee_l = bone_head(armature, "lowerleg.l")
    knee_r = bone_head(armature, "lowerleg.r")
    ankle_l = bone_head(armature, "foot.l")
    ankle_r = bone_head(armature, "foot.r")
    toes_l = bone_head(armature, "toes.l")
    toes_r = bone_head(armature, "toes.r")

    stature_guess = (head - ankle_l).dot(up) + 0.32
    scale = stature_guess / 1.76  # radii below are tuned for a 1.76 stature

    parts: list[PartBuilder] = []

    # ---- torso -------------------------------------------------------------
    torso = PartBuilder("Hero_Torso", frame, bulk=shape["bulk"])
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]
    crotch = hips - up * 0.05 * scale
    neck_base = _mix(hips, head, 0.88)
    shoulder_line = _mix(hips, head, 0.72)
    chest_height = _mix(hips, head, 0.45)
    waist = _mix(hips, head, 0.16)
    knee_center = (knee_l + knee_r) * 0.5
    mid_thigh = crotch.lerp(knee_center, 0.55)

    torso.start_tube()
    # Pelvis cap; hidden under a long tunic skirt, visible with a short one.
    torso.ring(
        crotch, up, 0.095 * scale * belly, 0.078 * scale * belly, {"hips": 1.0}, "pants"
    )
    torso.cap(crotch - up * 0.005 * scale, {"hips": 1.0}, "pants")
    torso.start_tube()
    if features["tunic_length"] == "long":
        # Long tunic hem — flares over the thighs like the legacy sprite silhouette.
        torso.ring(
            knee_center + up * 0.04 * scale,
            up,
            0.175 * scale,
            0.108 * scale,
            {"hips": 1.0},
            "tunic",
        )
        torso.ring(
            mid_thigh, up, 0.160 * scale, 0.112 * scale, {"hips": 1.0}, "tunic"
        )
    else:
        # Short tunic ends in a hip-length hem; the thighs stay pants-covered.
        torso.ring(
            hips - up * 0.10 * scale,
            up,
            0.152 * scale * belly,
            0.112 * scale * belly,
            {"hips": 1.0},
            "tunic",
        )
    torso.ring(
        hips - up * 0.03 * scale,
        up,
        0.143 * scale * belly,
        0.104 * scale * belly,
        {"hips": 1.0},
        "tunic",
    )
    torso.ring(
        hips + up * 0.02, up, 0.130 * scale * belly, 0.100 * scale * belly,
        {"hips": 1.0}, "belt",
    )
    torso.ring(
        waist, up, 0.118 * scale * belly, 0.092 * scale * belly,
        _blend("hips", "spine", 0.5), "tunic",
    )
    torso.ring(
        chest_height,
        up,
        0.172 * scale * chest_breadth,
        0.110 * scale,
        _blend("spine", "chest", 0.6),
        "tunic",
    )
    torso.ring(
        shoulder_line, up, 0.196 * scale * chest_breadth, 0.104 * scale,
        {"chest": 1.0}, "tunic",
    )
    torso.ring(neck_base, up, 0.062 * scale, 0.056 * scale, {"chest": 1.0}, "tunic")
    torso.cap(neck_base + up * 0.02, {"chest": 1.0}, "tunic")
    # Deltoid bulges follow the upper arm so the shoulder joint stays covered
    # when the arms swing.
    for suffix, shoulder in (("l", shoulder_l), ("r", shoulder_r)):
        torso.uv_sphere(
            shoulder + up * 0.012 * scale,
            Vector((0.082 * scale, 0.074 * scale, 0.078 * scale)),
            {f"upperarm.{suffix}": 1.0},
            "tunic",
            rings=9,
        )
        if features["pauldrons"]:
            # Flattened steel dome riding the deltoid, pushed slightly outward.
            outward = shoulder - neck_base
            outward -= up * outward.dot(up)
            outward = outward.normalized()
            torso.uv_sphere(
                shoulder + up * 0.034 * scale + outward * 0.028 * scale,
                Vector((0.096 * scale, 0.082 * scale, 0.056 * scale)),
                {f"upperarm.{suffix}": 1.0},
                "armor",
                rings=9,
            )
    parts.append(torso)

    # ---- head --------------------------------------------------------------
    # Head bulk is governed by the head_scale shape knob, not body bulk;
    # face-feature boxes stay at base size, which reads fine for the
    # ±10 % head_scale range specs should stay within.
    head_part = PartBuilder("Hero_Head", frame, bulk=shape["head_scale"])
    head_center = head + up * 0.13 * scale
    head_part.uv_sphere(
        head_center,
        Vector((0.140 * scale, 0.145 * scale, 0.155 * scale)),
        {"head": 1.0},
        "skin",
        rings=14,
    )
    # neck
    head_part.start_tube()
    head_part.ring(
        neck_base, up, 0.056 * scale, 0.052 * scale,
        _blend("chest", "head", 0.35), "skin",
    )
    head_part.ring(
        head + up * 0.045 * scale, up, 0.058 * scale, 0.054 * scale, {"head": 1.0}, "skin"
    )
    head_part.cap(head + up * 0.065 * scale, {"head": 1.0}, "skin")
    # ears: small flattened shells on the skull sides
    for side in (1.0, -1.0):
        head_part.uv_sphere(
            head_center + left * side * 0.134 * scale + up * 0.004 * scale,
            Vector((0.018 * scale, 0.026 * scale, 0.034 * scale)),
            {"head": 1.0},
            "skin",
            rings=6,
        )
    # hair: a back-top shell for every non-bald style, then style geometry
    hair_style = features["hair_style"]
    if hair_style != "bald":
        if hair_style == "short":
            hair_offset = head_center + up * 0.034 * scale - forward * 0.030 * scale
            hair_radii = Vector((0.142 * scale, 0.134 * scale, 0.146 * scale))
        else:
            hair_offset = head_center + up * 0.028 * scale - forward * 0.038 * scale
            hair_radii = Vector((0.148 * scale, 0.140 * scale, 0.152 * scale))
        head_part.uv_sphere(hair_offset, hair_radii, {"head": 1.0}, "hair", rings=13)
        if hair_style == "ponytail":
            tail_base = head_center - forward * 0.140 * scale + up * 0.095 * scale
            head_part.start_tube()
            head_part.ring(
                tail_base, up, 0.032 * scale, 0.030 * scale, {"head": 1.0}, "hair"
            )
            head_part.ring(
                tail_base - forward * 0.028 * scale - up * 0.100 * scale,
                up, 0.027 * scale, 0.025 * scale, {"head": 1.0}, "hair",
            )
            head_part.ring(
                tail_base - forward * 0.036 * scale - up * 0.200 * scale,
                up, 0.019 * scale, 0.018 * scale, {"head": 1.0}, "hair",
            )
            head_part.cap(
                tail_base - forward * 0.040 * scale - up * 0.245 * scale,
                {"head": 1.0}, "hair",
            )
        elif hair_style == "bun":
            head_part.uv_sphere(
                head_center - forward * 0.118 * scale + up * 0.128 * scale,
                Vector((0.052 * scale, 0.050 * scale, 0.048 * scale)),
                {"head": 1.0},
                "hair",
                rings=8,
            )
        elif hair_style == "long":
            head_part.start_tube()
            head_part.ring(
                head_center - forward * 0.115 * scale + up * 0.105 * scale,
                up, 0.072 * scale, 0.052 * scale, {"head": 1.0}, "hair",
            )
            head_part.ring(
                head_center - forward * 0.132 * scale - up * 0.045 * scale,
                up, 0.076 * scale, 0.056 * scale, {"head": 1.0}, "hair",
            )
            head_part.ring(
                neck_base - forward * 0.058 * scale,
                up, 0.062 * scale, 0.046 * scale,
                _blend("chest", "head", 0.5), "hair",
            )
            head_part.cap(
                neck_base - forward * 0.056 * scale - up * 0.035 * scale,
                {"head": 1.0}, "hair",
            )
    # beard: full wedge + mustache, a tight short wedge, or clean-shaven
    beard_style = features["beard_style"]
    if beard_style == "full":
        head_part.box(
            head_center + forward * 0.118 * scale - up * 0.095 * scale,
            left * 0.082 * scale,
            forward * 0.052 * scale,
            up * 0.075 * scale,
            {"head": 1.0},
            "beard",
        )
        # mustache bar under the nose
        head_part.box(
            head_center + forward * 0.147 * scale - up * 0.038 * scale,
            left * 0.048 * scale,
            forward * 0.012 * scale,
            up * 0.011 * scale,
            {"head": 1.0},
            "beard",
        )
    elif beard_style == "short":
        head_part.box(
            head_center + forward * 0.110 * scale - up * 0.082 * scale,
            left * 0.060 * scale,
            forward * 0.036 * scale,
            up * 0.048 * scale,
            {"head": 1.0},
            "beard",
        )
    # nose
    head_part.box(
        head_center + forward * 0.146 * scale - up * 0.004 * scale,
        left * 0.024 * scale,
        forward * 0.026 * scale,
        up * 0.036 * scale,
        {"head": 1.0},
        "skin",
    )
    # eyes and eyebrows
    for side in (1.0, -1.0):
        head_part.box(
            head_center + forward * 0.132 * scale + left * side * 0.052 * scale
            + up * 0.032 * scale,
            left * 0.017 * scale,
            forward * 0.010 * scale,
            up * 0.021 * scale,
            {"head": 1.0},
            "eyes",
        )
        head_part.box(
            head_center + forward * 0.131 * scale + left * side * 0.052 * scale
            + up * 0.060 * scale,
            left * 0.025 * scale,
            forward * 0.009 * scale,
            up * 0.007 * scale,
            {"head": 1.0},
            "hair",
        )
    parts.append(head_part)

    # ---- arms and hands ----------------------------------------------------
    # Long sleeves: short brown tunic sleeves over grey undersleeves with blue
    # cuffs. Bare style: the tunic sleeve ends mid-upper-arm, skin below.
    for suffix, shoulder, elbow, wrist, hand in (
        ("L", shoulder_l, elbow_l, wrist_l, hand_l),
        ("R", shoulder_r, elbow_r, wrist_r, hand_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        arm = PartBuilder(f"Hero_Arm{suffix}", frame, bulk=shape["bulk"])
        long_sleeves = features["sleeve_style"] == "long"
        forearm_material = "sleeves" if long_sleeves else "skin"
        arm.start_tube()
        axis_upper = (elbow - shoulder).normalized()
        axis_lower = (wrist - elbow).normalized()
        arm.ring(
            shoulder - axis_upper * 0.02,
            axis_upper,
            0.076 * scale,
            0.076 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            _mix(shoulder, elbow, 0.20),
            axis_upper,
            0.070 * scale,
            0.070 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            _mix(shoulder, elbow, 0.42),
            axis_upper,
            0.064 * scale,
            0.064 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            _mix(shoulder, elbow, 0.65),
            axis_upper,
            0.056 * scale,
            0.056 * scale,
            {bone("upperarm"): 1.0},
            forearm_material,
        )
        arm.ring(
            elbow,
            (axis_upper + axis_lower).normalized(),
            0.050 * scale,
            0.050 * scale,
            _blend(bone("upperarm"), bone("lowerarm"), 0.5),
            forearm_material,
        )
        arm.ring(
            _mix(elbow, wrist, 0.45),
            axis_lower,
            0.046 * scale,
            0.046 * scale,
            {bone("lowerarm"): 1.0},
            forearm_material,
        )
        arm.ring(
            _mix(elbow, wrist, 0.78),
            axis_lower,
            0.042 * scale,
            0.042 * scale,
            {bone("lowerarm"): 1.0},
            "sleeve_band" if long_sleeves else "skin",
        )
        arm.ring(
            wrist,
            axis_lower,
            0.038 * scale,
            0.038 * scale,
            _blend(bone("lowerarm"), bone("wrist"), 0.5),
            "skin",
        )
        arm.ring(
            hand,
            (hand - wrist).normalized(),
            0.034 * scale,
            0.034 * scale,
            _blend(bone("wrist"), bone("hand"), 0.6),
            "skin",
        )
        arm.cap(hand + (hand - wrist).normalized() * 0.01, {bone("hand"): 1.0}, "skin")
        parts.append(arm)

        # Hand mitt: built in a frame perpendicular to the hand direction (the
        # body frame is degenerate here because rest arms lie along it).
        hand_axis = (hand - wrist).normalized()
        hand_side, hand_up = frame.basis_for(hand_axis)
        hand_part = PartBuilder(f"Hero_Hand{suffix}", frame)
        hand_part.box(
            hand + hand_axis * 0.038 * scale,
            hand_side * 0.036 * scale,
            hand_up * 0.052 * scale,
            hand_axis * 0.066 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        # thumb
        hand_part.box(
            hand + hand_axis * 0.014 * scale + hand_up * 0.056 * scale,
            hand_side * 0.020 * scale,
            hand_up * 0.032 * scale,
            hand_axis * 0.036 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        parts.append(hand_part)

    # ---- legs and boots ----------------------------------------------------
    for suffix, socket, knee, ankle, toes in (
        ("L", socket_l, knee_l, ankle_l, toes_l),
        ("R", socket_r, knee_r, ankle_r, toes_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        leg = PartBuilder(f"Hero_Leg{suffix}", frame, bulk=shape["bulk"])
        leg.start_tube()
        axis_thigh = (knee - socket).normalized()
        axis_shin = (ankle - knee).normalized()
        leg.ring(
            socket - axis_thigh * 0.06 * scale,
            axis_thigh,
            0.082 * scale,
            0.080 * scale,
            {bone("upperleg"): 1.0},
            "pants",
        )
        leg.ring(
            _mix(socket, knee, 0.5),
            axis_thigh,
            0.066 * scale,
            0.066 * scale,
            {bone("upperleg"): 1.0},
            "pants",
        )
        leg.ring(
            knee,
            (axis_thigh + axis_shin).normalized(),
            0.050 * scale,
            0.050 * scale,
            _blend(bone("upperleg"), bone("lowerleg"), 0.5),
            "pants",
        )
        leg.ring(
            _mix(knee, ankle, 0.35),
            axis_shin,
            0.052 * scale,
            0.054 * scale,
            {bone("lowerleg"): 1.0},
            "boots",
        )
        leg.ring(
            ankle + up * 0.01,
            axis_shin,
            0.040 * scale,
            0.044 * scale,
            _blend(bone("lowerleg"), bone("foot"), 0.6),
            "boots",
        )
        leg.cap(ankle, {bone("foot"): 1.0}, "boots")
        parts.append(leg)

        # Boot: heel-to-toe box sitting on the ground, tall enough to swallow
        # the ankle, plus a toe cap weighted toward the toe bone.
        boot = PartBuilder(f"Hero_Boot{suffix}", frame)
        foot_forward = toes - ankle
        foot_forward -= up * foot_forward.dot(up)
        foot_forward = foot_forward.normalized()
        ankle_height = ankle.dot(up)
        ground_ankle = ankle - up * ankle_height
        half_height = ankle_height * 0.62
        heel_to_toe = 0.20 * scale
        boot_center = (
            ground_ankle
            + foot_forward * (heel_to_toe * 0.5 - 0.055 * scale)
            + up * half_height
        )
        boot.box(
            boot_center,
            left * 0.047 * scale,
            foot_forward * (heel_to_toe * 0.5),
            up * half_height,
            {bone("foot"): 1.0},
            "boots",
        )
        boot.box(
            boot_center + foot_forward * (heel_to_toe * 0.5 + 0.024 * scale)
            - up * half_height * 0.30,
            left * 0.044 * scale,
            foot_forward * 0.026 * scale,
            up * half_height * 0.70,
            _blend(bone("foot"), bone("toes"), 0.6),
            "boots",
        )
        parts.append(boot)

    body_objects = [part.build(armature, _material) for part in parts]

    # Report stature so the rig scene can pin its uniform model scale
    # (model_scale = 2.0 / BODY_STATURE).
    crown = head_center + up * 0.150 * scale * shape["head_scale"]
    print(f"BODY_STATURE={crown.dot(up):.4f}")
    print(f"BODY_ACTIONS={len(bpy.data.actions)}")

    _export(output, animations=True)
    print(f"Wrote {output}")

    # ---- garments: separate skinned glbs bound to the same skeleton --------
    if not selected["garments"]:
        return
    for obj in body_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

    garments: dict[str, PartBuilder] = {}

    cape = PartBuilder("Garment_Cape", frame)
    cape.start_tube()
    cape_top = shoulder_line - forward * 0.115 * scale + up * 0.02 * scale
    cape.ring(cape_top, up, 0.155 * scale, 0.022 * scale, {"chest": 1.0}, "cape")
    cape.ring(
        waist - forward * 0.128 * scale, up, 0.168 * scale, 0.024 * scale,
        {"spine": 1.0}, "cape",
    )
    cape.ring(
        hips - forward * 0.132 * scale, up, 0.172 * scale, 0.024 * scale,
        {"hips": 1.0}, "cape",
    )
    hem = _mix(socket_l + socket_r, knee_l + knee_r, 0.82) * 0.5
    cape.ring(
        hem - forward * 0.135 * scale, up, 0.160 * scale, 0.022 * scale,
        {"hips": 1.0}, "cape",
    )
    cape.cap(hem - forward * 0.135 * scale - up * 0.01 * scale, {"hips": 1.0}, "cape")
    garments["cape"] = cape

    hat = PartBuilder("Garment_Hat", frame)
    hat.start_tube()
    brim = head_center + up * 0.105 * scale
    hat.ring(brim, up, 0.190 * scale, 0.200 * scale, {"head": 1.0}, "hat")
    hat.ring(brim + up * 0.020 * scale, up, 0.150 * scale, 0.160 * scale, {"head": 1.0}, "hat")
    hat.ring(brim + up * 0.085 * scale, up, 0.110 * scale, 0.118 * scale, {"head": 1.0}, "hat")
    hat.cap(brim + up * 0.125 * scale, {"head": 1.0}, "hat")
    garments["hat"] = hat

    for name, builder in garments.items():
        if name not in selected["garments"]:
            continue
        garment_object = builder.build(armature, _material)
        _export(GARMENT_OUTPUTS[name], animations=False)
        print(f"Wrote {GARMENT_OUTPUTS[name]}")
        bpy.data.objects.remove(garment_object, do_unlink=True)


def _export(path: Path, animations: bool) -> None:
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_yup=True,
    )


def _character_argument() -> str:
    argv = sys.argv
    if "--" in argv:
        for argument in argv[argv.index("--") + 1 :]:
            if argument.startswith("--character="):
                return argument.split("=", 1)[1]
    return "hero"


if __name__ == "__main__":
    try:
        generate(_character_argument())
    except Exception as exc:
        import traceback

        traceback.print_exc()
        sys.exit(1)
