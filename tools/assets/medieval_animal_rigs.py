"""Reusable low-cost quadruped rigs and animation clips for livestock GLBs.

This module is intentionally separate from the asset build pipeline. It contains
only authored skeletal details so mesh cleanup, material generation, and export
can evolve without obscuring the shared animation contract.
"""

from __future__ import annotations

import math

import bpy
from mathutils import Vector


def create_flat_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    """Create a portable material for small authored facial/tail details."""
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = 0.72
    shader.inputs["Metallic"].default_value = 0.0
    return material


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_tapered_segment(
    name: str,
    start: Vector,
    end: Vector,
    start_radius: float,
    end_radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=10,
        radius1=end_radius,
        radius2=start_radius,
        depth=direction.length,
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def parent_to_bone(obj: bpy.types.Object, armature: bpy.types.Object, bone_name: str) -> None:
    """Rigidly attach authored detail geometry while preserving its world pose."""
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def create_quadruped_rig(
    obj: bpy.types.Object,
    rig_name: str,
    body_head: tuple[float, float, float],
    body_tail: tuple[float, float, float],
    bone_specs: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]],
    group_rules: dict[str, object],
    eye_specs: list[tuple[str, float, float, float, str]] | None = None,
    tail_specs: tuple[tuple[float, float, float], tuple[float, float, float], float, float] | None = None,
) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Shared low-cost quadruped rig for approved single-surface livestock scans."""
    coat = obj.data.materials[0]
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = rig_name
    armature.data.name = f"{rig_name}Skeleton"
    armature.show_in_front = True

    body = armature.data.edit_bones[0]
    body.name = "Body"
    body.head = body_head
    body.tail = body_tail

    for name, (head, tail) in bone_specs.items():
        bone = armature.data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.parent = body
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")

    groups = {name: obj.vertex_groups.new(name=name) for name in bone_specs | {"Body": None}}
    assignments: dict[str, list[int]] = {name: [] for name in groups}
    for vertex in obj.data.vertices:
        point = vertex.co
        group_name = "Body"
        if point.x < group_rules["neck_x"] and point.z > group_rules["neck_z"]:
            group_name = "Neck"
        elif (
            point.x > group_rules["tail_x"]
            and point.z > group_rules["tail_z"]
            and abs(point.y) < group_rules["tail_y"]
        ):
            group_name = "Tail"
        elif point.z < group_rules["leg_z"] and point.x < group_rules["front_leg_x"]:
            group_name = "FrontLeftLeg" if point.y >= 0.0 else "FrontRightLeg"
        elif point.z < group_rules["leg_z"] and point.x > group_rules["back_leg_x"]:
            group_name = "BackLeftLeg" if point.y >= 0.0 else "BackRightLeg"
        assignments[group_name].append(vertex.index)
    for name, indices in assignments.items():
        if indices:
            groups[name].add(indices, 1.0, "REPLACE")

    modifier = obj.modifiers.new(f"{rig_name}Armature", "ARMATURE")
    modifier.object = armature
    obj.parent = armature

    details: list[bpy.types.Object] = []
    if eye_specs is not None:
        eye_white = create_flat_material(f"{rig_name.lower()}_eye_white", (0.58, 0.47, 0.31, 1.0))
        pupil_black = create_flat_material(f"{rig_name.lower()}_pupil", (0.012, 0.008, 0.005, 1.0))
        for side, y, z, bone_name in eye_specs:
            eye = add_uv_sphere(f"Eye{side}", (-group_rules["eye_x"], y, z), group_rules["eye_scale"], eye_white)
            pupil_y = y + (group_rules["pupil_offset"] if y > 0.0 else -group_rules["pupil_offset"])
            pupil = add_uv_sphere(
                f"Pupil{side}",
                (-group_rules["eye_x"] - 0.015, pupil_y, z),
                group_rules["pupil_scale"],
                pupil_black,
            )
            parent_to_bone(eye, armature, bone_name)
            parent_to_bone(pupil, armature, bone_name)
            details.extend([eye, pupil])
        armature["animated_eyes"] = True

    if tail_specs is not None:
        tail_start, tail_end, start_radius, end_radius = tail_specs
        tail = add_tapered_segment(
            "TailTuftStem",
            Vector(tail_start),
            Vector(tail_end),
            start_radius,
            end_radius,
            coat,
        )
        tuft = add_uv_sphere("TailTuft", tuple(tail_end), group_rules["tail_tuft_scale"], coat)
        parent_to_bone(tail, armature, "Tail")
        parent_to_bone(tuft, armature, "Tail")
        details.extend([tail, tuft])
        armature["animated_tail"] = True

    create_livestock_animations(armature)
    return armature, details


def create_cattle_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Compact cattle rig with readable eyes and swishing tail."""
    return create_quadruped_rig(
        obj,
        "CattleRig",
        (0.0, 0.0, 0.48),
        (0.0, 0.0, 1.02),
        {
            "Neck": ((-0.48, 0.0, 0.88), (-0.90, 0.0, 1.15)),
            "Tail": ((0.64, 0.0, 0.90), (0.98, 0.0, 0.50)),
            "FrontLeftLeg": ((-0.55, 0.27, 0.70), (-0.55, 0.27, 0.08)),
            "FrontRightLeg": ((-0.55, -0.27, 0.70), (-0.55, -0.27, 0.08)),
            "BackLeftLeg": ((0.60, 0.27, 0.70), (0.60, 0.27, 0.08)),
            "BackRightLeg": ((0.60, -0.27, 0.70), (0.60, -0.27, 0.08)),
            "EyeLeft": ((-0.80, 0.42, 1.20), (-0.80, 0.42, 1.29)),
            "EyeRight": ((-0.80, -0.42, 1.20), (-0.80, -0.42, 1.29)),
        },
        {
            "neck_x": -0.48,
            "neck_z": 0.68,
            "tail_x": 0.70,
            "tail_z": 0.54,
            "tail_y": 0.36,
            "leg_z": 0.72,
            "front_leg_x": -0.24,
            "back_leg_x": 0.26,
            "eye_x": 0.82,
            "eye_scale": (0.070, 0.026, 0.058),
            "pupil_scale": (0.030, 0.014, 0.034),
            "pupil_offset": 0.024,
            "tail_tuft_scale": (0.075, 0.065, 0.105),
        },
        eye_specs=[
            ("Left", 0.425, 1.205, "EyeLeft"),
            ("Right", -0.425, 1.205, "EyeRight"),
        ],
        tail_specs=((0.67, 0.0, 0.90), (0.98, 0.0, 0.50), 0.050, 0.025),
    )


def create_sheep_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Compact sheep rig scaled to the smaller fleece body envelope."""
    return create_quadruped_rig(
        obj,
        "SheepRig",
        (0.0, 0.0, 0.30),
        (0.0, 0.0, 0.58),
        {
            "Neck": ((-0.26, 0.0, 0.52), (-0.50, 0.0, 0.68)),
            "Tail": ((0.34, 0.0, 0.52), (0.52, 0.0, 0.30)),
            "FrontLeftLeg": ((-0.30, 0.14, 0.44), (-0.30, 0.14, 0.06)),
            "FrontRightLeg": ((-0.30, -0.14, 0.44), (-0.30, -0.14, 0.06)),
            "BackLeftLeg": ((0.32, 0.14, 0.44), (0.32, 0.14, 0.06)),
            "BackRightLeg": ((0.32, -0.14, 0.44), (0.32, -0.14, 0.06)),
            "EyeLeft": ((-0.44, 0.22, 0.70), (-0.44, 0.22, 0.76)),
            "EyeRight": ((-0.44, -0.22, 0.70), (-0.44, -0.22, 0.76)),
        },
        {
            "neck_x": -0.22,
            "neck_z": 0.42,
            "tail_x": 0.35,
            "tail_z": 0.38,
            "tail_y": 0.18,
            "leg_z": 0.46,
            "front_leg_x": -0.10,
            "back_leg_x": 0.12,
            "eye_x": 0.44,
            "eye_scale": (0.048, 0.018, 0.040),
            "pupil_scale": (0.022, 0.010, 0.024),
            "pupil_offset": 0.016,
            "tail_tuft_scale": (0.055, 0.048, 0.075),
        },
        eye_specs=[
            ("Left", 0.22, 0.70, "EyeLeft"),
            ("Right", -0.22, 0.70, "EyeRight"),
        ],
        tail_specs=((0.36, 0.0, 0.52), (0.52, 0.0, 0.30), 0.038, 0.020),
    )


def create_pack_horse_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Taller pack-horse rig with longer legs and a readable swishing tail.

    WHY: the v3 Hunyuan horse has a much narrower head (~±0.19 m) than the older
    wall-artifact mesh. Eyes at ±0.34 m floated beside the skull, so the orbit
    anchors stay inside the measured head envelope.
    """
    return create_quadruped_rig(
        obj,
        "PackHorseRig",
        (0.0, 0.0, 0.55),
        (0.0, 0.0, 1.12),
        {
            "Neck": ((-0.50, 0.0, 0.98), (-0.95, 0.0, 1.28)),
            "Tail": ((0.68, 0.0, 0.95), (1.02, 0.0, 0.52)),
            "FrontLeftLeg": ((-0.60, 0.22, 0.80), (-0.60, 0.22, 0.10)),
            "FrontRightLeg": ((-0.60, -0.22, 0.80), (-0.60, -0.22, 0.10)),
            "BackLeftLeg": ((0.65, 0.22, 0.80), (0.65, 0.22, 0.10)),
            "BackRightLeg": ((0.65, -0.22, 0.80), (0.65, -0.22, 0.10)),
            "EyeLeft": ((-0.94, 0.14, 1.38), (-0.94, 0.14, 1.46)),
            "EyeRight": ((-0.94, -0.14, 1.38), (-0.94, -0.14, 1.46)),
        },
        {
            "neck_x": -0.45,
            "neck_z": 0.85,
            "tail_x": 0.65,
            "tail_z": 0.70,
            "tail_y": 0.28,
            "leg_z": 0.95,
            "front_leg_x": -0.20,
            "back_leg_x": 0.30,
            "eye_x": 0.94,
            "eye_scale": (0.048, 0.020, 0.042),
            "pupil_scale": (0.022, 0.010, 0.024),
            "pupil_offset": 0.012,
            "tail_tuft_scale": (0.082, 0.070, 0.110),
        },
        eye_specs=[
            ("Left", 0.14, 1.38, "EyeLeft"),
            ("Right", -0.14, 1.38, "EyeRight"),
        ],
        tail_specs=((0.70, 0.0, 0.95), (1.02, 0.0, 0.52), 0.055, 0.028),
    )


def create_pig_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Lean landrace-pig rig preserving the licensed model's cloven-foot anatomy."""
    return create_quadruped_rig(
        obj,
        "PigRig",
        (0.0, 0.0, 0.22),
        (0.0, 0.0, 0.50),
        {
            "Neck": ((-0.34, 0.0, 0.40), (-0.60, 0.0, 0.55)),
            "Tail": ((0.38, 0.0, 0.52), (0.62, 0.0, 0.54)),
            "FrontLeftLeg": ((-0.28, 0.12, 0.32), (-0.28, 0.12, 0.04)),
            "FrontRightLeg": ((-0.28, -0.12, 0.32), (-0.28, -0.12, 0.04)),
            "BackLeftLeg": ((0.28, 0.12, 0.32), (0.28, 0.12, 0.04)),
            "BackRightLeg": ((0.28, -0.12, 0.32), (0.28, -0.12, 0.04)),
            "EyeLeft": ((-0.58, 0.17, 0.52), (-0.58, 0.17, 0.56)),
            "EyeRight": ((-0.58, -0.17, 0.52), (-0.58, -0.17, 0.56)),
        },
        {
            "neck_x": -0.34,
            "neck_z": 0.30,
            "tail_x": 0.38,
            "tail_z": 0.45,
            "tail_y": 0.18,
            "leg_z": 0.35,
            "front_leg_x": -0.12,
            "back_leg_x": 0.12,
            "eye_x": 0.58,
            "eye_scale": (0.026, 0.012, 0.022),
            "pupil_scale": (0.012, 0.007, 0.012),
            "pupil_offset": 0.010,
            "tail_tuft_scale": (0.025, 0.020, 0.025),
        },
        eye_specs=[
            ("Left", 0.17, 0.52, "EyeLeft"),
            ("Right", -0.17, 0.52, "EyeRight"),
        ],
        # The source's small curled tail is retained and weighted to Tail directly.
        tail_specs=None,
    )


def create_dog_rig(
    obj: bpy.types.Object,
    coord_scale: "Vector | None" = None,
) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Lean hound rig with amber eyes and a dark nose on the pricked-ear head.

    WHY: the P2-024 street dog is met at arm's length, so its muzzle needs a
    readable dark nose detail just like the livestock need visible eyes. The
    nose is a separate closed detail parented to the head (Neck) bone; the
    sickle tail stays part of the authored mesh and follows the Tail vertex
    group, matching the pig route.

    The builder normalizes the mesh to metric dimensions before rigging, so
    every literal below is authored in raw mesh space and must be scaled by
    ``coord_scale`` (the measured normalization factors); otherwise eyes, nose,
    and bones drift off the final body (scaled skull vs unscaled eye anchors).
    """
    scale = coord_scale if coord_scale is not None else Vector((1.0, 1.0, 1.0))

    def at(point: tuple[float, float, float]) -> tuple[float, float, float]:
        return (point[0] * scale.x, point[1] * scale.y, point[2] * scale.z)

    def dim(sizes: tuple[float, float, float]) -> tuple[float, float, float]:
        return (sizes[0] * scale.x, sizes[1] * scale.y, sizes[2] * scale.z)

    armature, details = create_quadruped_rig(
        obj,
        "DogRig",
        at((0.0, 0.0, 0.26)),
        at((0.0, 0.0, 0.50)),
        {
            "Neck": (at((-0.30, 0.0, 0.47)), at((-0.50, 0.0, 0.60))),
            "Tail": (at((0.38, 0.0, 0.48)), at((0.52, 0.0, 0.68))),
            "FrontLeftLeg": (at((-0.26, 0.078, 0.38)), at((-0.27, 0.078, 0.04))),
            "FrontRightLeg": (at((-0.26, -0.078, 0.38)), at((-0.27, -0.078, 0.04))),
            "BackLeftLeg": (at((0.24, 0.085, 0.40)), at((0.24, 0.085, 0.04))),
            "BackRightLeg": (at((0.24, -0.085, 0.40)), at((0.24, -0.085, 0.04))),
            "EyeLeft": (at((-0.53, 0.068, 0.58)), at((-0.53, 0.068, 0.63))),
            "EyeRight": (at((-0.53, -0.068, 0.58)), at((-0.53, -0.068, 0.63))),
        },
        {
            "neck_x": -0.34 * scale.x,
            "neck_z": 0.50 * scale.z,
            "tail_x": 0.40 * scale.x,
            "tail_z": 0.50 * scale.z,
            "tail_y": 0.08 * scale.y,
            "leg_z": 0.26 * scale.z,
            "front_leg_x": -0.10 * scale.x,
            "back_leg_x": 0.10 * scale.x,
            "eye_x": 0.53 * scale.x,
            "eye_scale": dim((0.026, 0.014, 0.024)),
            "pupil_scale": dim((0.012, 0.006, 0.013)),
            "pupil_offset": 0.011 * scale.y,
            "tail_tuft_scale": dim((0.030, 0.026, 0.040)),
        },
        eye_specs=[
            ("Left", 0.068 * scale.y, 0.58 * scale.z, "EyeLeft"),
            ("Right", -0.068 * scale.y, 0.58 * scale.z, "EyeRight"),
        ],
        tail_specs=None,
    )
    nose_material = create_flat_material("dogrig_nose", (0.028, 0.020, 0.016, 1.0))
    nose = add_uv_sphere("NoseTip", at((-0.685, 0.0, 0.522)), dim((0.022, 0.019, 0.016)), nose_material)
    parent_to_bone(nose, armature, "Neck")
    details.append(nose)
    create_dog_animations(armature)
    return armature, details


def create_dog_animations(armature: bpy.types.Object) -> None:
    """Replace the generic livestock motion with dog-specific ambient clips.

    WHY: the shared two-pose livestock walk is readable on large animals but a
    small street dog still appears to slide at the map camera distance. Wider
    contact/ passing poses, body weight shifts, and a strong lateral tail arc
    make each state legible without increasing the skeleton or runtime cost.
    """
    pose_bones = armature.pose.bones
    animated_bones = [
        "Body",
        "Neck",
        "Tail",
        "FrontLeftLeg",
        "FrontRightLeg",
        "BackLeftLeg",
        "BackRightLeg",
        "EyeLeft",
        "EyeRight",
    ]
    for name in animated_bones:
        pose_bones[name].rotation_mode = "XYZ"

    # This builder runs in its own clean Blender scene, so replacing the generic
    # clips cannot affect the other livestock exports.
    for action_name in ("Idle-loop", "Walk-loop"):
        action = bpy.data.actions.get(action_name)
        if action is not None:
            bpy.data.actions.remove(action)

    def make_action(name: str) -> bpy.types.Action:
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        armature.animation_data.action = action
        return action

    def key_pose(
        frame: int,
        rotations: dict[str, tuple[float, float, float]],
        body_location: tuple[float, float, float] = (0.0, 0.0, 0.0),
        eye_open: float = 1.0,
    ) -> None:
        for name in animated_bones:
            bone = pose_bones[name]
            bone.rotation_euler = rotations.get(name, (0.0, 0.0, 0.0))
            bone.keyframe_insert("rotation_euler", frame=frame, group=name)
        pose_bones["Body"].location = body_location
        pose_bones["Body"].keyframe_insert("location", frame=frame, group="Body")
        for name in ("EyeLeft", "EyeRight"):
            pose_bones[name].scale = (1.0, 1.0, eye_open)
            pose_bones[name].keyframe_insert("scale", frame=frame, group=name)

    idle = make_action("Idle-loop")
    for frame, tail_yaw, head_pitch, body_z, eye_open in (
        (1, -0.34, -0.02, 0.000, 1.0),
        (10, 0.36, 0.01, 0.006, 1.0),
        (20, -0.30, 0.03, 0.000, 1.0),
        (30, 0.38, 0.00, 0.006, 1.0),
        (40, -0.34, -0.02, 0.000, 0.12),
        (43, -0.12, -0.01, 0.003, 1.0),
        (50, 0.36, 0.02, 0.006, 1.0),
        (61, -0.34, -0.02, 0.000, 1.0),
    ):
        key_pose(
            frame,
            {
                "Tail": (0.08, tail_yaw, tail_yaw * 0.20),
                "Neck": (0.0, head_pitch, -tail_yaw * 0.04),
            },
            (0.0, 0.0, body_z),
            eye_open,
        )

    walk = make_action("Walk-loop")
    for frame, diagonal_a, diagonal_b, body_z, body_roll in (
        (1, 0.46, -0.46, 0.000, -0.035),
        (5, 0.26, -0.26, 0.014, 0.000),
        (9, 0.00, 0.00, 0.026, 0.035),
        (13, -0.26, 0.26, 0.014, 0.000),
        (17, -0.46, 0.46, 0.000, -0.035),
        (21, -0.26, 0.26, 0.014, 0.000),
        (25, 0.00, 0.00, 0.026, 0.035),
        (29, 0.26, -0.26, 0.014, 0.000),
        (33, 0.46, -0.46, 0.000, -0.035),
    ):
        key_pose(
            frame,
            {
                "FrontLeftLeg": (0.0, diagonal_a, 0.0),
                "BackRightLeg": (0.0, diagonal_a, 0.0),
                "FrontRightLeg": (0.0, diagonal_b, 0.0),
                "BackLeftLeg": (0.0, diagonal_b, 0.0),
                "Body": (0.0, 0.0, body_roll),
                "Tail": (0.12, diagonal_b * 0.42, diagonal_b * 0.16),
                "Neck": (0.0, -0.04 + abs(diagonal_a) * 0.08, -body_roll * 0.45),
            },
            (0.0, 0.0, body_z),
        )

    trot = make_action("Trot-loop")
    for frame, diagonal_a, diagonal_b, body_z in (
        (1, 0.58, -0.58, 0.010),
        (4, 0.12, -0.12, 0.038),
        (7, -0.58, 0.58, 0.010),
        (10, -0.12, 0.12, 0.038),
        (13, 0.58, -0.58, 0.010),
    ):
        key_pose(
            frame,
            {
                "FrontLeftLeg": (0.0, diagonal_a, 0.0),
                "BackRightLeg": (0.0, diagonal_a, 0.0),
                "FrontRightLeg": (0.0, diagonal_b, 0.0),
                "BackLeftLeg": (0.0, diagonal_b, 0.0),
                "Tail": (0.02, diagonal_b * 0.28, diagonal_b * 0.10),
                "Neck": (0.0, 0.055, 0.0),
            },
            (0.0, 0.0, body_z),
        )

    sniff = make_action("Sniff-loop")
    for frame, head_pitch, head_yaw, tail_yaw, body_z in (
        (1, 0.10, -0.16, -0.20, 0.000),
        (10, 0.32, -0.08, 0.18, -0.012),
        (20, 0.42, 0.12, -0.16, -0.018),
        (30, 0.28, 0.18, 0.20, -0.010),
        (40, 0.10, -0.16, -0.20, 0.000),
    ):
        key_pose(
            frame,
            {
                "Neck": (0.0, head_pitch, head_yaw),
                "Tail": (0.04, tail_yaw, tail_yaw * 0.14),
                "FrontLeftLeg": (0.0, 0.08, 0.0),
                "FrontRightLeg": (0.0, -0.04, 0.0),
            },
            (0.0, 0.0, body_z),
        )

    armature.animation_data.action = idle
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61


def create_livestock_animations(armature: bpy.types.Object) -> None:
    """Author two short looping clips with diagonal walk and independent blinks."""
    armature.animation_data_create()
    pose_bones = armature.pose.bones
    animated_bones = [
        "Body",
        "Neck",
        "Tail",
        "FrontLeftLeg",
        "FrontRightLeg",
        "BackLeftLeg",
        "BackRightLeg",
        "EyeLeft",
        "EyeRight",
    ]
    for name in animated_bones:
        pose_bones[name].rotation_mode = "XYZ"

    def key_pose(
        frame: int,
        rotations: dict[str, tuple[float, float, float]],
        body_lift: float = 0.0,
        eye_open: float = 1.0,
    ) -> None:
        for name in animated_bones:
            bone = pose_bones[name]
            bone.rotation_euler = rotations.get(name, (0.0, 0.0, 0.0))
            bone.keyframe_insert("rotation_euler", frame=frame, group=name)
        pose_bones["Body"].location = (0.0, 0.0, body_lift)
        pose_bones["Body"].keyframe_insert("location", frame=frame, group="Body")
        for name in ["EyeLeft", "EyeRight"]:
            pose_bones[name].scale = (1.0, 1.0, eye_open)
            pose_bones[name].keyframe_insert("scale", frame=frame, group=name)

    idle = bpy.data.actions.new("Idle-loop")
    idle.use_fake_user = True
    armature.animation_data.action = idle
    idle_poses = [
        (1, -0.18, 0.01, 1.0),
        (14, 0.22, -0.025, 1.0),
        (27, 0.08, 0.035, 1.0),
        (38, -0.24, -0.01, 1.0),
        (45, -0.08, 0.01, 0.12),
        (48, 0.02, 0.01, 1.0),
        (61, -0.18, 0.01, 1.0),
    ]
    for frame, tail_swing, neck_pitch, eye_open in idle_poses:
        key_pose(
            frame,
            {"Tail": (tail_swing, 0.0, tail_swing * 0.35), "Neck": (0.0, neck_pitch, 0.0)},
            body_lift=0.008 * math.sin((frame - 1) / 60.0 * math.tau),
            eye_open=eye_open,
        )

    walk = bpy.data.actions.new("Walk-loop")
    walk.use_fake_user = True
    armature.animation_data.action = walk
    walk_poses = [
        (1, 0.34, -0.34, 0.0),
        (8, 0.0, 0.0, 0.025),
        (16, -0.34, 0.34, 0.0),
        (23, 0.0, 0.0, 0.025),
        (31, 0.34, -0.34, 0.0),
    ]
    for frame, diagonal_a, diagonal_b, body_lift in walk_poses:
        key_pose(
            frame,
            {
                "FrontLeftLeg": (0.0, diagonal_a, 0.0),
                "BackRightLeg": (0.0, diagonal_a, 0.0),
                "FrontRightLeg": (0.0, diagonal_b, 0.0),
                "BackLeftLeg": (0.0, diagonal_b, 0.0),
                "Tail": (diagonal_b * 0.55, 0.0, diagonal_b * 0.20),
                "Neck": (0.0, -0.035 + abs(diagonal_a) * 0.06, 0.0),
            },
            body_lift=body_lift,
            eye_open=1.0,
        )

    armature.animation_data.action = idle
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61


RIG_BUILDERS = {
    "cattle": create_cattle_rig,
    "dog": create_dog_rig,
    "pig": create_pig_rig,
    "sheep": create_sheep_rig,
    "pack_horse": create_pack_horse_rig,
}
