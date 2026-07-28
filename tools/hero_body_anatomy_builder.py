"""Layered anatomical body assembly for generated humanoid prototypes.

The skeleton remains the single source of pose. This builder adds a continuous
skin envelope shaped around skeletal landmarks, then generates fitted clothing
as a separate envelope. Pose-driven muscle volume is handled at runtime by
`anatomical_muscle_modifier.gd`, so the authored profile and the animation
response remain independent concerns.
"""

from __future__ import annotations

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_anatomical_torso(context: BodyContext, shape: dict) -> PartBuilder:
    """Build the skin layer beneath tunics, mail, and future garments."""
    frame = context.frame
    up = frame.up
    scale = context.scale
    belly = shape["belly"]
    chest = shape["chest_breadth"]

    skin = PartBuilder("Anatomy_SkinTorso", frame, bulk=shape["bulk"])
    skin.start_tube()
    for center, side_radius, front_radius, weights in (
        (context.crotch, 0.100 * belly, 0.078 * belly, {"hips": 1.0}),
        (context.hips - up * 0.025 * scale, 0.140 * belly, 0.101 * belly, {"hips": 1.0}),
        (context.waist, 0.112 * belly, 0.086 * belly, blend_weights("hips", "spine", 0.5)),
        (context.chest_height, 0.158 * chest, 0.103, blend_weights("spine", "chest", 0.65)),
        (context.shoulder_line, 0.178 * chest, 0.095, {"chest": 1.0}),
        (context.neck_base, 0.056, 0.051, {"chest": 1.0}),
    ):
        skin.ring(
            center,
            up,
            side_radius * scale,
            front_radius * scale,
            weights,
            "skin",
        )
    skin.cap(context.neck_base + up * 0.018 * scale, {"chest": 1.0}, "skin")
    return skin


def build_anatomical_limbs(
    context: BodyContext, shape: dict, features: dict
) -> list[PartBuilder]:
    parts = _build_anatomical_arms(context, shape, features)
    parts.extend(_build_anatomical_legs(context, shape))
    return parts


def _build_anatomical_arms(
    context: BodyContext, shape: dict, features: dict
) -> list[PartBuilder]:
    frame = context.frame
    scale = context.scale
    parts: list[PartBuilder] = []

    for suffix, shoulder, elbow, wrist, hand in (
        ("L", context.shoulder_l, context.elbow_l, context.wrist_l, context.hand_l),
        ("R", context.shoulder_r, context.elbow_r, context.wrist_r, context.hand_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        upper_axis = (elbow - shoulder).normalized()
        lower_axis = (wrist - elbow).normalized()
        joint_axis = (upper_axis + lower_axis).normalized()

        # Skin follows deltoid, biceps/triceps, elbow condyles, and the upper
        # forearm mass instead of tapering as one straight cylinder.
        skin = PartBuilder(f"Anatomy_SkinArm{suffix}", frame, bulk=shape["bulk"])
        skin.start_tube()
        for center, axis, side_radius, depth_radius, weights in (
            (shoulder - upper_axis * 0.018 * scale, upper_axis, 0.069, 0.064, {bone("upperarm"): 1.0}),
            (shoulder.lerp(elbow, 0.14), upper_axis, 0.082, 0.077, {bone("upperarm"): 1.0}),
            (shoulder.lerp(elbow, 0.36), upper_axis, 0.075, 0.069, {bone("upperarm"): 1.0}),
            (shoulder.lerp(elbow, 0.68), upper_axis, 0.059, 0.054, {bone("upperarm"): 1.0}),
            (elbow, joint_axis, 0.056, 0.046, blend_weights(bone("upperarm"), bone("lowerarm"), 0.5)),
            (elbow.lerp(wrist, 0.22), lower_axis, 0.059, 0.052, {bone("lowerarm"): 1.0}),
            (elbow.lerp(wrist, 0.48), lower_axis, 0.054, 0.048, {bone("lowerarm"): 1.0}),
            (elbow.lerp(wrist, 0.76), lower_axis, 0.044, 0.040, {bone("lowerarm"): 1.0}),
            (wrist, lower_axis, 0.037, 0.034, blend_weights(bone("lowerarm"), bone("wrist"), 0.55)),
            (hand, (hand - wrist).normalized(), 0.034, 0.032, blend_weights(bone("wrist"), bone("hand"), 0.65)),
        ):
            skin.ring(
                center,
                axis,
                side_radius * scale,
                depth_radius * scale,
                weights,
                "skin",
            )
        skin.cap(
            hand + (hand - wrist).normalized() * 0.010 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        parts.append(skin)

        # Sleeves are intentionally another skinned mesh. Future clothing can
        # be swapped without rebuilding or simplifying the anatomical layer.
        long_sleeves = features["sleeve_style"] == "long"
        sleeve = PartBuilder(f"Clothing_Sleeve{suffix}", frame, bulk=shape["bulk"])
        sleeve.start_tube()
        upper_sleeve_material = (
            "mail" if features["armor_style"] == "mail" else "tunic"
        )
        sleeve_profile = [
            (shoulder - upper_axis * 0.022 * scale, upper_axis, 0.087, 0.083, {bone("upperarm"): 1.0}, upper_sleeve_material),
            (shoulder.lerp(elbow, 0.18), upper_axis, 0.091, 0.086, {bone("upperarm"): 1.0}, upper_sleeve_material),
            (shoulder.lerp(elbow, 0.38), upper_axis, 0.082, 0.076, {bone("upperarm"): 1.0}, upper_sleeve_material),
        ]
        if long_sleeves:
            sleeve_profile.extend(
                [
                    (shoulder.lerp(elbow, 0.72), upper_axis, 0.066, 0.061, {bone("upperarm"): 1.0}, "sleeves"),
                    (elbow, joint_axis, 0.063, 0.054, blend_weights(bone("upperarm"), bone("lowerarm"), 0.5), "sleeves"),
                    (elbow.lerp(wrist, 0.26), lower_axis, 0.066, 0.058, {bone("lowerarm"): 1.0}, "sleeves"),
                    (elbow.lerp(wrist, 0.58), lower_axis, 0.059, 0.052, {bone("lowerarm"): 1.0}, "sleeves"),
                    (elbow.lerp(wrist, 0.84), lower_axis, 0.050, 0.046, {bone("lowerarm"): 1.0}, "sleeve_band"),
                    (wrist - lower_axis * 0.012 * scale, lower_axis, 0.046, 0.043, blend_weights(bone("lowerarm"), bone("wrist"), 0.55), "sleeve_band"),
                ]
            )
        else:
            sleeve_profile.append(
                (shoulder.lerp(elbow, 0.48), upper_axis, 0.076, 0.070, {bone("upperarm"): 1.0}, "tunic")
            )
        for center, axis, side_radius, depth_radius, weights, material in sleeve_profile:
            sleeve.ring(
                center,
                axis,
                side_radius * scale,
                depth_radius * scale,
                weights,
                material,
            )
        end_center, _axis, _side, _depth, end_weights, end_material = sleeve_profile[-1]
        sleeve.cap(end_center + upper_axis * 0.006 * scale, end_weights, end_material)
        parts.append(sleeve)

        hand_axis = (hand - wrist).normalized()
        hand_side, hand_up = frame.basis_for(hand_axis)
        hand_part = PartBuilder(f"Anatomy_Hand{suffix}", frame)
        hand_part.box(
            hand + hand_axis * 0.038 * scale,
            hand_side * 0.036 * scale,
            hand_up * 0.052 * scale,
            hand_axis * 0.066 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        hand_part.box(
            hand + hand_axis * 0.014 * scale + hand_up * 0.056 * scale,
            hand_side * 0.020 * scale,
            hand_up * 0.032 * scale,
            hand_axis * 0.036 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        parts.append(hand_part)
    return parts


def _build_anatomical_legs(context: BodyContext, shape: dict) -> list[PartBuilder]:
    frame = context.frame
    up, forward = frame.up, frame.forward
    scale = context.scale
    parts: list[PartBuilder] = []

    for suffix, socket, knee, ankle, toes in (
        ("L", context.socket_l, context.knee_l, context.ankle_l, context.toes_l),
        ("R", context.socket_r, context.knee_r, context.ankle_r, context.toes_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        thigh_axis = (knee - socket).normalized()
        shin_axis = (ankle - knee).normalized()
        joint_axis = (thigh_axis + shin_axis).normalized()

        # The posterior calf is shifted back from the tibia. That offset and
        # the wider knee condyles are what stop the leg reading as a stick.
        skin_profile = [
            (socket - thigh_axis * 0.035 * scale, thigh_axis, 0.091, 0.084, {bone("upperleg"): 1.0}),
            (socket.lerp(knee, 0.18), thigh_axis, 0.101, 0.092, {bone("upperleg"): 1.0}),
            (socket.lerp(knee, 0.43), thigh_axis, 0.087, 0.079, {bone("upperleg"): 1.0}),
            (socket.lerp(knee, 0.72), thigh_axis, 0.070, 0.063, {bone("upperleg"): 1.0}),
            (knee, joint_axis, 0.066, 0.052, blend_weights(bone("upperleg"), bone("lowerleg"), 0.5)),
            (knee.lerp(ankle, 0.16), shin_axis, 0.060, 0.055, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.34) - forward * 0.010 * scale, shin_axis, 0.075, 0.067, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.55) - forward * 0.008 * scale, shin_axis, 0.068, 0.060, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.78), shin_axis, 0.050, 0.046, {bone("lowerleg"): 1.0}),
            (ankle + up * 0.008 * scale, shin_axis, 0.041, 0.039, blend_weights(bone("lowerleg"), bone("foot"), 0.6)),
        ]
        skin = PartBuilder(f"Anatomy_SkinLeg{suffix}", frame, bulk=shape["bulk"])
        skin.start_tube()
        for center, axis, side_radius, depth_radius, weights in skin_profile:
            skin.ring(
                center,
                axis,
                side_radius * scale,
                depth_radius * scale,
                weights,
                "skin",
            )
        skin.cap(ankle, {bone("foot"): 1.0}, "skin")
        parts.append(skin)

        # Closely fitted medieval hose preserves the underlying thigh, knee,
        # and calf silhouette instead of replacing it with a uniform trouser.
        hose = PartBuilder(f"Clothing_Hose{suffix}", frame, bulk=shape["bulk"])
        hose.start_tube()
        for center, axis, side_radius, depth_radius, weights in skin_profile:
            hose.ring(
                center,
                axis,
                (side_radius + 0.008) * scale,
                (depth_radius + 0.008) * scale,
                weights,
                "pants",
            )
        hose.cap(ankle, {bone("foot"): 1.0}, "pants")
        parts.append(hose)

        # A rounded shaft plus instep/toe tube follows the ankle and foot bones;
        # it avoids the two rectangular blocks used by the legacy prototype.
        boot = PartBuilder(f"Clothing_Boot{suffix}", frame)
        boot.start_tube()
        for center, side_radius, depth_radius, weights in (
            (knee.lerp(ankle, 0.48), 0.082, 0.075, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.70), 0.070, 0.064, {bone("lowerleg"): 1.0}),
            (ankle + up * 0.018 * scale, 0.058, 0.056, blend_weights(bone("lowerleg"), bone("foot"), 0.6)),
        ):
            boot.ring(
                center,
                shin_axis,
                side_radius * scale,
                depth_radius * scale,
                weights,
                "boots",
            )
        boot.cap(ankle, {bone("foot"): 1.0}, "boots")

        foot_forward = toes - ankle
        foot_forward -= up * foot_forward.dot(up)
        foot_forward = foot_forward.normalized()
        ankle_height = ankle.dot(up)
        ground_ankle = ankle - up * ankle_height
        boot.start_tube()
        for center, width, height, weights in (
            (ground_ankle - foot_forward * 0.060 * scale + up * 0.050 * scale, 0.055, 0.046, {bone("foot"): 1.0}),
            (ground_ankle + foot_forward * 0.030 * scale + up * 0.058 * scale, 0.058, 0.055, {bone("foot"): 1.0}),
            (ground_ankle + foot_forward * 0.145 * scale + up * 0.040 * scale, 0.052, 0.039, blend_weights(bone("foot"), bone("toes"), 0.55)),
        ):
            boot.ring(
                center,
                foot_forward,
                width * scale,
                height * scale,
                weights,
                "boots",
            )
        boot.cap(
            ground_ankle + foot_forward * 0.205 * scale + up * 0.035 * scale,
            {bone("toes"): 1.0},
            "boots",
        )
        parts.append(boot)
    return parts
