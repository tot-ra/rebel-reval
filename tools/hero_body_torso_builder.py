"""Torso assembly for the generated hero body."""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_torso(context: BodyContext, shape: dict, features: dict) -> PartBuilder:
    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    hips = context.hips
    neck_base = context.neck_base
    shoulder_line = context.shoulder_line
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]

    torso = PartBuilder("Hero_Torso", frame, bulk=shape["bulk"])
    if features["anatomical_layers"]:
        # The anatomical builder owns skin and limbs. This builder contributes
        # only fitted torso clothing and role-specific outerwear above it.
        _add_anatomical_clothing(torso, context, shape, features)
        _add_outerwear(torso, context, shape, features["outerwear"])
        return torso
    torso.start_tube()
    # Pelvis cap; hidden under a long tunic skirt, visible with a short one.
    torso.ring(
        context.crotch,
        up,
        0.095 * scale * belly,
        0.078 * scale * belly,
        {"hips": 1.0},
        "pants",
    )
    torso.cap(context.crotch - up * 0.005 * scale, {"hips": 1.0}, "pants")
    torso.start_tube()
    if features["tunic_length"] == "long":
        # Long tunic hem flares over the thighs like the legacy sprite silhouette.
        torso.ring(
            context.knee_center + up * 0.04 * scale,
            up,
            0.175 * scale,
            0.108 * scale,
            {"hips": 1.0},
            "tunic",
        )
        torso.ring(
            context.mid_thigh,
            up,
            0.160 * scale,
            0.112 * scale,
            {"hips": 1.0},
            "tunic",
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
        hips + up * 0.02,
        up,
        0.130 * scale * belly,
        0.100 * scale * belly,
        {"hips": 1.0},
        "belt",
    )
    torso.ring(
        context.waist,
        up,
        0.118 * scale * belly,
        0.092 * scale * belly,
        blend_weights("hips", "spine", 0.5),
        "tunic",
    )
    torso.ring(
        context.chest_height,
        up,
        0.172 * scale * chest_breadth,
        0.110 * scale,
        blend_weights("spine", "chest", 0.6),
        "tunic",
    )
    torso.ring(
        shoulder_line,
        up,
        0.196 * scale * chest_breadth,
        0.104 * scale,
        {"chest": 1.0},
        "tunic",
    )
    torso.ring(
        neck_base,
        up,
        0.062 * scale,
        0.056 * scale,
        {"chest": 1.0},
        "tunic",
    )
    torso.cap(neck_base + up * 0.02, {"chest": 1.0}, "tunic")

    _add_outerwear(torso, context, shape, features["outerwear"])

    # Deltoid bulges follow the upper arm so the shoulder joint stays covered
    # when the arms swing.
    for suffix, shoulder in (("l", context.shoulder_l), ("r", context.shoulder_r)):
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
    return torso


def _add_anatomical_clothing(
    torso: PartBuilder, context: BodyContext, shape: dict, features: dict
) -> None:
    """Build a fitted tunic or mail shell outside the anatomical skin.

    A small radial clearance prevents z-fighting while preserving ribcage,
    waist, and pelvic landmarks. Profession/rank outerwear is added afterward
    by the existing role-specific builder, keeping clothing independent from
    the body envelope.
    """
    up = context.frame.up
    scale = context.scale
    belly = shape["belly"]
    chest = shape["chest_breadth"]
    material = "mail" if features["armor_style"] == "mail" else "tunic"

    torso.start_tube()
    if features["tunic_length"] == "long":
        torso.ring(
            context.knee_center + up * 0.04 * scale,
            up,
            0.168 * scale,
            0.111 * scale,
            {"hips": 1.0},
            material,
        )
        torso.ring(
            context.mid_thigh,
            up,
            0.157 * scale,
            0.113 * scale,
            {"hips": 1.0},
            material,
        )
    else:
        torso.ring(
            context.hips - up * 0.13 * scale,
            up,
            0.151 * scale * belly,
            0.111 * scale * belly,
            {"hips": 1.0},
            material,
        )
    for center, side_radius, front_radius, weights in (
        (context.hips - up * 0.03 * scale, 0.148 * belly, 0.109 * belly, {"hips": 1.0}),
        (context.waist, 0.122 * belly, 0.096 * belly, blend_weights("hips", "spine", 0.5)),
        (context.chest_height, 0.169 * chest, 0.114, blend_weights("spine", "chest", 0.65)),
        (context.shoulder_line, 0.190 * chest, 0.108, {"chest": 1.0}),
        (context.neck_base - up * 0.015 * scale, 0.068, 0.062, {"chest": 1.0}),
    ):
        torso.ring(
            center,
            up,
            side_radius * scale,
            front_radius * scale,
            weights,
            material,
        )
    torso.cap(context.neck_base + up * 0.005 * scale, {"chest": 1.0}, material)


def _add_outerwear(
    torso: PartBuilder, context: BodyContext, shape: dict, style: str
) -> None:
    """Add role-specific clothing as skinned geometry on the shared body.

    These layers are intentionally generated into each named character GLB:
    their proportions and weights therefore follow that body's skeleton in
    locomotion, combat and social animations instead of floating as props.
    """
    if style == "none":
        return

    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]

    if style == "apron":
        # Leather work apron: bib, skirt, neck strap and belt ties.
        torso.box(
            context.chest_height + forward * 0.118 * scale,
            left * 0.105 * scale * chest_breadth,
            forward * 0.012 * scale,
            up * 0.170 * scale,
            blend_weights("spine", "chest", 0.55),
            "outerwear",
        )
        apron_center = context.hips.lerp(context.knee_center, 0.42) + forward * 0.122 * scale
        torso.box(
            apron_center,
            left * 0.135 * scale * belly,
            forward * 0.014 * scale,
            up * 0.250 * scale,
            {"hips": 1.0},
            "outerwear",
        )
        torso.box(
            context.hips + up * 0.025 * scale + forward * 0.128 * scale,
            left * 0.155 * scale * belly,
            forward * 0.018 * scale,
            up * 0.025 * scale,
            {"hips": 1.0},
            "trim",
        )
        for side in (-1.0, 1.0):
            torso.box(
                context.shoulder_line
                + left * side * 0.078 * scale
                + forward * 0.100 * scale,
                left * 0.012 * scale,
                forward * 0.009 * scale,
                up * 0.125 * scale,
                {"chest": 1.0},
                "trim",
            )
        return

    if style in ("vest", "surcoat"):
        # Sleeveless wool/leather layer. The centre opening and edging create a
        # readable garment rather than another uniformly coloured torso shell.
        torso.start_tube()
        hem_height = context.hips - up * (0.10 if style == "vest" else 0.22) * scale
        for center, side_radius, front_radius, weights in (
            (hem_height, 0.151 * belly, 0.113 * belly, {"hips": 1.0}),
            (context.waist, 0.127 * belly, 0.103 * belly, blend_weights("hips", "spine", 0.5)),
            (context.chest_height, 0.181 * chest_breadth, 0.119, blend_weights("spine", "chest", 0.65)),
            (context.shoulder_line, 0.190 * chest_breadth, 0.111, {"chest": 1.0}),
            (context.neck_base - up * 0.035 * scale, 0.074, 0.066, {"chest": 1.0}),
        ):
            torso.ring(
                center,
                up,
                side_radius * scale,
                front_radius * scale,
                weights,
                "outerwear",
            )
        torso.cap(context.neck_base - up * 0.01 * scale, {"chest": 1.0}, "outerwear")
        trim_center = context.hips.lerp(context.shoulder_line, 0.55) + forward * 0.122 * scale
        for side in (-1.0, 1.0):
            torso.box(
                trim_center + left * side * 0.018 * scale,
                left * 0.008 * scale,
                forward * 0.008 * scale,
                up * 0.285 * scale,
                blend_weights("spine", "chest", 0.5),
                "trim",
            )
        if style == "surcoat":
            torso.box(
                context.hips + up * 0.025 * scale + forward * 0.124 * scale,
                left * 0.158 * scale,
                forward * 0.014 * scale,
                up * 0.026 * scale,
                {"hips": 1.0},
                "trim",
            )
        return

    if style == "kirtle":
        # Contrasting over-dress/apron panel with shoulder straps. The main
        # long tunic still supplies the animated skirt volume beneath it.
        panel_center = context.hips.lerp(context.knee_center, 0.38) + forward * 0.120 * scale
        torso.box(
            panel_center,
            left * 0.125 * scale,
            forward * 0.012 * scale,
            up * 0.330 * scale,
            {"hips": 1.0},
            "outerwear",
        )
        torso.box(
            context.chest_height + forward * 0.115 * scale,
            left * 0.105 * scale,
            forward * 0.012 * scale,
            up * 0.125 * scale,
            blend_weights("spine", "chest", 0.6),
            "outerwear",
        )
        for side in (-1.0, 1.0):
            torso.box(
                context.shoulder_line
                + left * side * 0.078 * scale
                + forward * 0.105 * scale,
                left * 0.013 * scale,
                forward * 0.009 * scale,
                up * 0.125 * scale,
                {"chest": 1.0},
                "trim",
            )
