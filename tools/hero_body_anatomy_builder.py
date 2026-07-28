"""Layered anatomical body assembly for generated humanoid prototypes.

The skeleton remains the single source of pose. This builder adds a continuous
skin envelope shaped around skeletal landmarks, then generates fitted clothing
as a separate envelope. Pose-driven muscle volume is handled at runtime by
`anatomical_muscle_modifier.gd`, so the authored profile and the animation
response remain independent concerns.
"""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def torso_profile(context: BodyContext, shape: dict) -> list[tuple]:
    """Shared cross-sections from crotch to neck, front and back radii apart.

    Both the skin envelope and the fitted clothing shell above it read this
    profile, so a garment can never disagree with the body it covers. The
    shoulder girdle is part of the profile rather than a bolted-on sphere: the
    clavicle section reaches the arm sockets measured from the skeleton, which
    is what closes the shoulder and gives the silhouette real deltoids.
    """
    up = context.frame.up
    scale = context.scale
    belly = shape["belly"]
    chest = shape["chest_breadth"]

    # Bone-derived reach, expressed in the same pre-bulk authoring units as the
    # literals below (`ring` multiplies by bulk, the call sites by scale), so a
    # broad or slight spec still lands its clavicle on its own arm sockets.
    half_span = (context.shoulder_l - context.shoulder_r).length * 0.5
    clavicle_reach = half_span / (scale * max(shape["bulk"], 0.01))
    shoulder_mid = (context.shoulder_l + context.shoulder_r) * 0.5

    return [
        (context.crotch, 0.101 * belly, 0.076 * belly, 0.086 * belly, {"hips": 1.0}),
        # Pelvis and buttocks: the posterior mass is what stops the hips
        # reading as a straight tube in profile and from the gameplay camera.
        (
            context.hips - up * 0.025 * scale,
            0.142 * belly,
            0.096 * belly,
            0.134 * belly,
            {"hips": 1.0},
        ),
        (
            context.hips + up * 0.055 * scale,
            0.130 * belly,
            0.092 * belly,
            0.106 * belly,
            blend_weights("hips", "spine", 0.35),
        ),
        (
            context.waist,
            0.112 * belly,
            0.086 * belly,
            0.090 * belly,
            blend_weights("hips", "spine", 0.5),
        ),
        # Ribcage: deeper at the front (pectorals), flatter behind.
        (
            context.chest_height,
            0.158 * chest,
            0.110,
            0.098,
            blend_weights("spine", "chest", 0.65),
        ),
        (
            context.chest_height.lerp(shoulder_mid, 0.55),
            0.172 * chest,
            0.108,
            0.100,
            {"chest": 1.0},
        ),
        # Clavicle line, level with the arm sockets.
        (
            shoulder_mid - up * 0.030 * scale,
            clavicle_reach,
            0.099,
            0.094,
            {"chest": 1.0},
        ),
        # Trapezius slope into the neck.
        (context.neck_base - up * 0.004 * scale, 0.097, 0.074, 0.078, {"chest": 1.0}),
        # Slightly inside the head builder's neck tube: same skin colour, and
        # the clearance keeps the two layers from z-fighting when the head turns.
        (context.neck_base + up * 0.030 * scale, 0.051, 0.047, 0.049, {"chest": 1.0}),
    ]


def build_anatomical_torso(context: BodyContext, shape: dict) -> PartBuilder:
    """Build the skin layer beneath tunics, mail, and future garments."""
    frame = context.frame
    up = frame.up
    scale = context.scale

    skin = PartBuilder("Anatomy_SkinTorso", frame, bulk=shape["bulk"])
    skin.start_tube()
    for center, side_radius, front_radius, back_radius, weights in torso_profile(
        context, shape
    ):
        skin.ring(
            center,
            up,
            side_radius * scale,
            front_radius * scale,
            weights,
            "skin",
            radius_back=back_radius * scale,
        )
    skin.cap(context.neck_base + up * 0.042 * scale, {"chest": 1.0}, "skin")
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

        # Deltoid cap. The clavicle section of the torso profile reaches the
        # socket from the inside; this rounds the joint from the outside and
        # rides the upper arm, so the shoulder stays closed through the whole
        # swing range instead of opening the hole the arm tube alone leaves.
        deltoid_center = shoulder + upper_axis * 0.026 * scale + frame.up * 0.012 * scale
        skin.uv_sphere(
            deltoid_center,
            Vector((0.081 * scale, 0.076 * scale, 0.083 * scale)),
            {bone("upperarm"): 1.0},
            "skin",
            rings=10,
        )

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
        upper_sleeve_material = (
            "mail" if features["armor_style"] == "mail" else "tunic"
        )

        # Sleeve head over the deltoid: cloth has to cover the joint the skin
        # layer just closed, or the shoulder shows bare skin through the tunic.
        sleeve.uv_sphere(
            shoulder + upper_axis * 0.024 * scale + frame.up * 0.012 * scale,
            Vector((0.092 * scale, 0.087 * scale, 0.093 * scale)),
            {bone("upperarm"): 1.0},
            upper_sleeve_material,
            rings=10,
        )

        sleeve.start_tube()
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
    up = frame.up
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
        # The top section sits above the socket, inside the pelvis: it carries
        # the buttock mass on a hip/thigh weight blend and closes the tube,
        # where a bare top ring used to leave an open hole at the hip.
        glute_weights = blend_weights("hips", bone("upperleg"), 0.55)
        skin_profile = [
            (socket - thigh_axis * 0.045 * scale, thigh_axis, 0.093, 0.084, 0.104, glute_weights),
            (socket + thigh_axis * 0.010 * scale, thigh_axis, 0.098, 0.088, 0.118, glute_weights),
            (socket.lerp(knee, 0.18), thigh_axis, 0.101, 0.092, 0.099, {bone("upperleg"): 1.0}),
            (socket.lerp(knee, 0.43), thigh_axis, 0.087, 0.079, 0.084, {bone("upperleg"): 1.0}),
            (socket.lerp(knee, 0.72), thigh_axis, 0.070, 0.063, 0.066, {bone("upperleg"): 1.0}),
            (knee, joint_axis, 0.066, 0.052, 0.056, blend_weights(bone("upperleg"), bone("lowerleg"), 0.5)),
            (knee.lerp(ankle, 0.16), shin_axis, 0.060, 0.052, 0.062, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.34), shin_axis, 0.070, 0.055, 0.082, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.55), shin_axis, 0.062, 0.050, 0.070, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.78), shin_axis, 0.050, 0.044, 0.050, {bone("lowerleg"): 1.0}),
            (ankle + up * 0.008 * scale, shin_axis, 0.041, 0.039, 0.042, blend_weights(bone("lowerleg"), bone("foot"), 0.6)),
        ]
        skin = PartBuilder(f"Anatomy_SkinLeg{suffix}", frame, bulk=shape["bulk"])
        _build_leg_tube(skin, skin_profile, context, socket, thigh_axis, ankle, bone, "skin", 0.0)
        parts.append(skin)

        # Closely fitted medieval hose preserves the underlying thigh, knee,
        # and calf silhouette instead of replacing it with a uniform trouser.
        hose = PartBuilder(f"Clothing_Hose{suffix}", frame, bulk=shape["bulk"])
        _build_leg_tube(
            hose, skin_profile, context, socket, thigh_axis, ankle, bone, "pants", 0.008
        )
        parts.append(hose)

        # A rounded shaft plus instep/toe tube follows the ankle and foot bones;
        # it avoids the two rectangular blocks used by the legacy prototype.
        # The shaft continues past the ankle down to the heel so that shaft and
        # foot overlap: anchoring the foot on the world ground plane instead
        # left it floating a boot's height below the leg in every pose.
        foot_forward = toes - ankle
        foot_forward -= up * foot_forward.dot(up)
        foot_forward = foot_forward.normalized()
        # Sole height measured from the toe bone, not from world zero, so the
        # foot travels with the skeleton in every clip.
        heel_drop = (ankle - toes).dot(up) + 0.012 * scale
        sole = ankle - up * heel_drop

        boot = PartBuilder(f"Clothing_Boot{suffix}", frame)
        boot.start_tube()
        for center, side_radius, depth_radius, weights in (
            (knee.lerp(ankle, 0.48), 0.082, 0.075, {bone("lowerleg"): 1.0}),
            (knee.lerp(ankle, 0.70), 0.070, 0.064, {bone("lowerleg"): 1.0}),
            (ankle + up * 0.018 * scale, 0.058, 0.056, blend_weights(bone("lowerleg"), bone("foot"), 0.6)),
            (ankle - up * 0.045 * scale, 0.056, 0.058, {bone("foot"): 1.0}),
        ):
            boot.ring(
                center,
                shin_axis,
                side_radius * scale,
                depth_radius * scale,
                weights,
                "boots",
            )
        boot.cap(sole + up * 0.030 * scale, {bone("foot"): 1.0}, "boots")

        boot.start_tube()
        for center, width, height, weights in (
            (sole - foot_forward * 0.058 * scale + up * 0.054 * scale, 0.055, 0.054, {bone("foot"): 1.0}),
            (sole + foot_forward * 0.035 * scale + up * 0.052 * scale, 0.058, 0.052, {bone("foot"): 1.0}),
            (sole + foot_forward * 0.145 * scale + up * 0.038 * scale, 0.052, 0.038, blend_weights(bone("foot"), bone("toes"), 0.55)),
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
            sole + foot_forward * 0.205 * scale + up * 0.032 * scale,
            {bone("toes"): 1.0},
            "boots",
        )
        parts.append(boot)
    return parts


def _build_leg_tube(
    part: PartBuilder,
    profile: list[tuple],
    context: BodyContext,
    socket,
    thigh_axis,
    ankle,
    bone,
    material: str,
    clearance: float,
) -> None:
    """Emit one closed leg envelope; `clearance` offsets a clothing layer.

    Both ends are capped. The hip end matters: an open top ring showed its
    backfaces through the pelvis whenever the camera rose above the character.
    """
    scale = context.scale
    part.start_tube()
    for center, axis, side_radius, depth_radius, back_radius, weights in profile:
        part.ring(
            center,
            axis,
            (side_radius + clearance) * scale,
            (depth_radius + clearance) * scale,
            weights,
            material,
            radius_back=(back_radius + clearance) * scale,
        )
    part.cap(ankle, {bone("foot"): 1.0}, material)

    top_center, top_axis, top_side, top_depth, top_back, top_weights = profile[0]
    part.start_tube()
    part.ring(
        top_center,
        top_axis,
        (top_side + clearance) * scale,
        (top_depth + clearance) * scale,
        top_weights,
        material,
        radius_back=(top_back + clearance) * scale,
    )
    part.cap(socket - thigh_axis * 0.105 * scale, top_weights, material)
