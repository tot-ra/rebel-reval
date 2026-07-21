"""Head and facial-feature assembly for the generated hero body."""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_head(context: BodyContext, shape: dict, features: dict) -> PartBuilder:
    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    head = context.head
    head_center = context.head_center
    neck_base = context.neck_base

    # Head bulk is governed by head_scale, not body bulk. Face-feature boxes
    # stay at base size, which is suitable for the supported +/-10% range.
    head_part = PartBuilder("Hero_Head", frame, bulk=shape["head_scale"])
    head_part.uv_sphere(
        head_center,
        Vector((0.140 * scale, 0.145 * scale, 0.155 * scale)),
        {"head": 1.0},
        "skin",
        rings=14,
    )

    head_part.start_tube()
    head_part.ring(
        neck_base,
        up,
        0.056 * scale,
        0.052 * scale,
        blend_weights("chest", "head", 0.35),
        "skin",
    )
    head_part.ring(
        head + up * 0.045 * scale,
        up,
        0.058 * scale,
        0.054 * scale,
        {"head": 1.0},
        "skin",
    )
    head_part.cap(head + up * 0.065 * scale, {"head": 1.0}, "skin")

    # Ears are small flattened shells on the skull sides.
    for side in (1.0, -1.0):
        head_part.uv_sphere(
            head_center + left * side * 0.134 * scale + up * 0.004 * scale,
            Vector((0.018 * scale, 0.026 * scale, 0.034 * scale)),
            {"head": 1.0},
            "skin",
            rings=6,
        )

    _add_hair(head_part, context, features["hair_style"])
    _add_beard(head_part, context, features["beard_style"])

    head_part.box(
        head_center + forward * 0.146 * scale - up * 0.004 * scale,
        left * 0.024 * scale,
        forward * 0.026 * scale,
        up * 0.036 * scale,
        {"head": 1.0},
        "skin",
    )
    # Eyes and eyebrows.
    for side in (1.0, -1.0):
        head_part.box(
            head_center
            + forward * 0.132 * scale
            + left * side * 0.052 * scale
            + up * 0.032 * scale,
            left * 0.017 * scale,
            forward * 0.010 * scale,
            up * 0.021 * scale,
            {"head": 1.0},
            "eyes",
        )
        head_part.box(
            head_center
            + forward * 0.131 * scale
            + left * side * 0.052 * scale
            + up * 0.060 * scale,
            left * 0.025 * scale,
            forward * 0.009 * scale,
            up * 0.007 * scale,
            {"head": 1.0},
            "hair",
        )
    return head_part


def _add_hair(head_part: PartBuilder, context: BodyContext, style: str) -> None:
    if style == "bald":
        return

    frame = context.frame
    up, forward = frame.up, frame.forward
    scale = context.scale
    head_center = context.head_center
    if style == "short":
        hair_offset = head_center + up * 0.034 * scale - forward * 0.030 * scale
        hair_radii = Vector((0.142 * scale, 0.134 * scale, 0.146 * scale))
    else:
        hair_offset = head_center + up * 0.028 * scale - forward * 0.038 * scale
        hair_radii = Vector((0.148 * scale, 0.140 * scale, 0.152 * scale))
    head_part.uv_sphere(hair_offset, hair_radii, {"head": 1.0}, "hair", rings=13)

    if style == "ponytail":
        tail_base = head_center - forward * 0.140 * scale + up * 0.095 * scale
        head_part.start_tube()
        head_part.ring(
            tail_base,
            up,
            0.032 * scale,
            0.030 * scale,
            {"head": 1.0},
            "hair",
        )
        head_part.ring(
            tail_base - forward * 0.028 * scale - up * 0.100 * scale,
            up,
            0.027 * scale,
            0.025 * scale,
            {"head": 1.0},
            "hair",
        )
        head_part.ring(
            tail_base - forward * 0.036 * scale - up * 0.200 * scale,
            up,
            0.019 * scale,
            0.018 * scale,
            {"head": 1.0},
            "hair",
        )
        head_part.cap(
            tail_base - forward * 0.040 * scale - up * 0.245 * scale,
            {"head": 1.0},
            "hair",
        )
    elif style == "bun":
        head_part.uv_sphere(
            head_center - forward * 0.118 * scale + up * 0.128 * scale,
            Vector((0.052 * scale, 0.050 * scale, 0.048 * scale)),
            {"head": 1.0},
            "hair",
            rings=8,
        )
    elif style == "long":
        head_part.start_tube()
        head_part.ring(
            head_center - forward * 0.115 * scale + up * 0.105 * scale,
            up,
            0.072 * scale,
            0.052 * scale,
            {"head": 1.0},
            "hair",
        )
        head_part.ring(
            head_center - forward * 0.132 * scale - up * 0.045 * scale,
            up,
            0.076 * scale,
            0.056 * scale,
            {"head": 1.0},
            "hair",
        )
        head_part.ring(
            context.neck_base - forward * 0.058 * scale,
            up,
            0.062 * scale,
            0.046 * scale,
            blend_weights("chest", "head", 0.5),
            "hair",
        )
        head_part.cap(
            context.neck_base - forward * 0.056 * scale - up * 0.035 * scale,
            {"head": 1.0},
            "hair",
        )


def _add_beard(head_part: PartBuilder, context: BodyContext, style: str) -> None:
    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    head_center = context.head_center
    if style == "full":
        head_part.box(
            head_center + forward * 0.118 * scale - up * 0.095 * scale,
            left * 0.082 * scale,
            forward * 0.052 * scale,
            up * 0.075 * scale,
            {"head": 1.0},
            "beard",
        )
        # Mustache bar under the nose.
        head_part.box(
            head_center + forward * 0.147 * scale - up * 0.038 * scale,
            left * 0.048 * scale,
            forward * 0.012 * scale,
            up * 0.011 * scale,
            {"head": 1.0},
            "beard",
        )
    elif style == "short":
        head_part.box(
            head_center + forward * 0.110 * scale - up * 0.082 * scale,
            left * 0.060 * scale,
            forward * 0.036 * scale,
            up * 0.048 * scale,
            {"head": 1.0},
            "beard",
        )
