"""Separate skinned garment assembly for generated hero characters."""

from __future__ import annotations

from hero_body_context import BodyContext
from hero_body_mesh_builder import PartBuilder


def build_garments(context: BodyContext) -> dict[str, PartBuilder]:
    frame = context.frame
    up, forward = frame.up, frame.forward
    scale = context.scale

    cape = PartBuilder("Garment_Cape", frame)
    cape.start_tube()
    cape_top = context.shoulder_line - forward * 0.115 * scale + up * 0.02 * scale
    cape.ring(cape_top, up, 0.155 * scale, 0.022 * scale, {"chest": 1.0}, "cape")
    cape.ring(
        context.waist - forward * 0.128 * scale,
        up,
        0.168 * scale,
        0.024 * scale,
        {"spine": 1.0},
        "cape",
    )
    cape.ring(
        context.hips - forward * 0.132 * scale,
        up,
        0.172 * scale,
        0.024 * scale,
        {"hips": 1.0},
        "cape",
    )
    hem = (context.socket_l + context.socket_r).lerp(
        context.knee_l + context.knee_r, 0.82
    ) * 0.5
    cape.ring(
        hem - forward * 0.135 * scale,
        up,
        0.160 * scale,
        0.022 * scale,
        {"hips": 1.0},
        "cape",
    )
    cape.cap(
        hem - forward * 0.135 * scale - up * 0.01 * scale,
        {"hips": 1.0},
        "cape",
    )

    hat = PartBuilder("Garment_Hat", frame)
    hat.start_tube()
    brim = context.head_center + up * 0.105 * scale
    hat.ring(brim, up, 0.190 * scale, 0.200 * scale, {"head": 1.0}, "hat")
    hat.ring(
        brim + up * 0.020 * scale,
        up,
        0.150 * scale,
        0.160 * scale,
        {"head": 1.0},
        "hat",
    )
    hat.ring(
        brim + up * 0.085 * scale,
        up,
        0.110 * scale,
        0.118 * scale,
        {"head": 1.0},
        "hat",
    )
    hat.cap(brim + up * 0.125 * scale, {"head": 1.0}, "hat")

    return {"cape": cape, "hat": hat}
