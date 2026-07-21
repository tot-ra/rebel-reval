"""Torso assembly for the generated hero body."""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_torso(context: BodyContext, shape: dict, features: dict) -> PartBuilder:
    frame = context.frame
    up = frame.up
    scale = context.scale
    hips = context.hips
    neck_base = context.neck_base
    shoulder_line = context.shoulder_line
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]

    torso = PartBuilder("Hero_Torso", frame, bulk=shape["bulk"])
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
