"""Arm, hand, leg, and boot assembly for the generated hero body."""

from __future__ import annotations

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_limbs(
    context: BodyContext, shape: dict, features: dict
) -> list[PartBuilder]:
    parts = _build_arms(context, shape, features)
    parts.extend(_build_legs(context, shape))
    return parts


def _build_arms(
    context: BodyContext, shape: dict, features: dict
) -> list[PartBuilder]:
    frame = context.frame
    scale = context.scale
    parts: list[PartBuilder] = []
    # Long sleeves use a tunic sleeve, undersleeve and cuff. Bare style ends the
    # tunic sleeve at mid-upper-arm and exposes skin down to the wrist.
    for suffix, shoulder, elbow, wrist, hand in (
        ("L", context.shoulder_l, context.elbow_l, context.wrist_l, context.hand_l),
        ("R", context.shoulder_r, context.elbow_r, context.wrist_r, context.hand_r),
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
            shoulder.lerp(elbow, 0.20),
            axis_upper,
            0.070 * scale,
            0.070 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            shoulder.lerp(elbow, 0.42),
            axis_upper,
            0.064 * scale,
            0.064 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            shoulder.lerp(elbow, 0.65),
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
            blend_weights(bone("upperarm"), bone("lowerarm"), 0.5),
            forearm_material,
        )
        arm.ring(
            elbow.lerp(wrist, 0.45),
            axis_lower,
            0.046 * scale,
            0.046 * scale,
            {bone("lowerarm"): 1.0},
            forearm_material,
        )
        arm.ring(
            elbow.lerp(wrist, 0.78),
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
            blend_weights(bone("lowerarm"), bone("wrist"), 0.5),
            "skin",
        )
        arm.ring(
            hand,
            (hand - wrist).normalized(),
            0.034 * scale,
            0.034 * scale,
            blend_weights(bone("wrist"), bone("hand"), 0.6),
            "skin",
        )
        arm.cap(
            hand + (hand - wrist).normalized() * 0.01,
            {bone("hand"): 1.0},
            "skin",
        )
        parts.append(arm)

        # The hand mitt uses a frame perpendicular to the hand direction. The
        # body frame is degenerate because rest arms lie along it.
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


def _build_legs(context: BodyContext, shape: dict) -> list[PartBuilder]:
    frame = context.frame
    up, left = frame.up, frame.left
    scale = context.scale
    parts: list[PartBuilder] = []
    for suffix, socket, knee, ankle, toes in (
        ("L", context.socket_l, context.knee_l, context.ankle_l, context.toes_l),
        ("R", context.socket_r, context.knee_r, context.ankle_r, context.toes_r),
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
            socket.lerp(knee, 0.5),
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
            blend_weights(bone("upperleg"), bone("lowerleg"), 0.5),
            "pants",
        )
        leg.ring(
            knee.lerp(ankle, 0.35),
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
            blend_weights(bone("lowerleg"), bone("foot"), 0.6),
            "boots",
        )
        leg.cap(ankle, {bone("foot"): 1.0}, "boots")
        parts.append(leg)

        # Boot box sits on the ground and swallows the ankle; its toe cap is
        # weighted toward the toe bone.
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
            boot_center
            + foot_forward * (heel_to_toe * 0.5 + 0.024 * scale)
            - up * half_height * 0.30,
            left * 0.044 * scale,
            foot_forward * 0.026 * scale,
            up * half_height * 0.70,
            blend_weights(bone("foot"), bone("toes"), 0.6),
            "boots",
        )
        parts.append(boot)
    return parts
