"""Head and facial-feature assembly for generated rigged characters."""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_head(
    context: BodyContext, shape: dict, face: dict, features: dict
) -> PartBuilder:
    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    head = context.head
    head_center = context.head_center
    neck_base = context.neck_base

    # Named characters alter the facial mesh, never the head bone. Attachments,
    # hit reactions and all retargeted clips therefore keep a stable contract.
    head_part = PartBuilder("Character_Head", frame, bulk=shape["head_scale"])
    skull_radius = Vector(
        (
            0.132 * scale * face["width"],
            0.142 * scale * face["depth"],
            0.151 * scale * face["length"],
        )
    )
    head_part.uv_sphere(
        head_center + up * 0.012 * scale,
        skull_radius,
        {"head": 1.0},
        "skin",
        rings=16,
    )

    # A separate lower-face volume breaks the old spherical toy-head read and
    # gives each spec an independent jaw silhouette.
    jaw_center = head_center + forward * 0.018 * scale - up * 0.075 * scale
    head_part.uv_sphere(
        jaw_center,
        Vector(
            (
                0.102 * scale * face["jaw_width"],
                0.126 * scale * face["depth"],
                0.092 * scale * face["length"],
            )
        ),
        {"head": 1.0},
        "skin",
        rings=12,
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

    for side in (1.0, -1.0):
        head_part.uv_sphere(
            head_center
            + left * side * 0.132 * scale * face["width"]
            + up * 0.002 * scale,
            Vector((0.016 * scale, 0.024 * scale, 0.032 * scale)),
            {"head": 1.0},
            "skin",
            rings=7,
        )

    _add_hair(head_part, context, features["hair_style"], face)
    _add_beard(head_part, context, features["beard_style"], face)

    nose_length = face["nose_length"]
    head_part.uv_sphere(
        head_center + forward * 0.143 * scale * nose_length - up * 0.008 * scale,
        Vector((0.024 * scale, 0.033 * scale * nose_length, 0.043 * scale)),
        {"head": 1.0},
        "skin",
        rings=7,
    )
    head_part.uv_sphere(
        head_center + forward * 0.158 * scale * nose_length - up * 0.025 * scale,
        Vector((0.029 * scale, 0.024 * scale, 0.023 * scale)),
        {"head": 1.0},
        "skin",
        rings=6,
    )

    eye_spacing = 0.048 * scale * face["eye_spacing"]
    eye_forward = 0.132 * scale * face["depth"]
    eye_height = 0.031 * scale
    for side in (1.0, -1.0):
        eye_center = (
            head_center
            + forward * eye_forward
            + left * side * eye_spacing
            + up * eye_height
        )
        head_part.uv_sphere(
            eye_center,
            Vector((0.021 * scale, 0.010 * scale, 0.014 * scale)),
            {"head": 1.0},
            "eye_white",
            rings=7,
        )
        head_part.uv_sphere(
            eye_center + forward * 0.009 * scale,
            Vector((0.009 * scale, 0.006 * scale, 0.010 * scale)),
            {"head": 1.0},
            "eyes",
            rings=6,
        )
        head_part.box(
            eye_center
            - forward * 0.001 * scale
            + up * 0.029 * scale * face["brow_height"],
            left * 0.025 * scale,
            forward * 0.006 * scale,
            up * 0.005 * scale,
            {"head": 1.0},
            "hair",
        )

    # The mouth remains neutral geometry so dialogue/attack animations can move
    # the whole head without a frozen painted expression.
    head_part.box(
        head_center + forward * 0.132 * scale - up * 0.071 * scale,
        left * 0.043 * scale,
        forward * 0.006 * scale,
        up * 0.006 * scale,
        {"head": 1.0},
        "lips",
    )
    return head_part


def _add_hair(
    head_part: PartBuilder, context: BodyContext, style: str, face: dict
) -> None:
    if style == "bald":
        return

    frame = context.frame
    up, forward = frame.up, frame.forward
    scale = context.scale
    head_center = context.head_center
    if style == "short":
        hair_offset = head_center + up * 0.052 * scale - forward * 0.030 * scale
        hair_radii = Vector(
            (
                0.136 * scale * face["width"],
                0.133 * scale * face["depth"],
                0.122 * scale * face["length"],
            )
        )
    else:
        hair_offset = head_center + up * 0.044 * scale - forward * 0.038 * scale
        hair_radii = Vector(
            (
                0.142 * scale * face["width"],
                0.139 * scale * face["depth"],
                0.136 * scale * face["length"],
            )
        )
    head_part.uv_sphere(hair_offset, hair_radii, {"head": 1.0}, "hair", rings=14)

    if style == "ponytail":
        tail_base = head_center - forward * 0.140 * scale + up * 0.095 * scale
        head_part.start_tube()
        for center, radius in (
            (tail_base, 0.032),
            (tail_base - forward * 0.028 * scale - up * 0.100 * scale, 0.027),
            (tail_base - forward * 0.036 * scale - up * 0.200 * scale, 0.019),
        ):
            head_part.ring(
                center,
                up,
                radius * scale,
                radius * 0.94 * scale,
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
            rings=9,
        )
    elif style == "long":
        head_part.start_tube()
        for center, side_radius, front_radius, weights in (
            (
                head_center - forward * 0.115 * scale + up * 0.105 * scale,
                0.072,
                0.052,
                {"head": 1.0},
            ),
            (
                head_center - forward * 0.132 * scale - up * 0.045 * scale,
                0.076,
                0.056,
                {"head": 1.0},
            ),
            (
                context.neck_base - forward * 0.058 * scale,
                0.062,
                0.046,
                blend_weights("chest", "head", 0.5),
            ),
        ):
            head_part.ring(
                center,
                up,
                side_radius * scale,
                front_radius * scale,
                weights,
                "hair",
            )
        head_part.cap(
            context.neck_base - forward * 0.056 * scale - up * 0.035 * scale,
            {"head": 1.0},
            "hair",
        )


def _add_beard(
    head_part: PartBuilder, context: BodyContext, style: str, face: dict
) -> None:
    if style == "none":
        return

    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    head_center = context.head_center
    jaw_width = face["jaw_width"]
    if style == "full":
        head_part.uv_sphere(
            head_center + forward * 0.108 * scale - up * 0.094 * scale,
            Vector(
                (
                    0.080 * scale * jaw_width,
                    0.047 * scale,
                    0.082 * scale,
                )
            ),
            {"head": 1.0},
            "beard",
            rings=9,
        )
        head_part.box(
            head_center + forward * 0.144 * scale - up * 0.039 * scale,
            left * 0.048 * scale,
            forward * 0.010 * scale,
            up * 0.009 * scale,
            {"head": 1.0},
            "beard",
        )
    elif style == "short":
        head_part.uv_sphere(
            head_center + forward * 0.105 * scale - up * 0.086 * scale,
            Vector(
                (
                    0.064 * scale * jaw_width,
                    0.030 * scale,
                    0.050 * scale,
                )
            ),
            {"head": 1.0},
            "beard",
            rings=8,
        )
