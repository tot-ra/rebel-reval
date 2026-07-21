"""Skeleton measurements shared by generated hero body part builders."""

from __future__ import annotations

from dataclasses import dataclass

import bpy
from mathutils import Vector

from hero_body_mesh_builder import Frame, bone_head


def blend_weights(bone_a: str, bone_b: str, ratio: float) -> dict[str, float]:
    """Return deterministic weights for a joint between two bones."""
    return {bone_a: 1.0 - ratio, bone_b: ratio}


@dataclass(frozen=True)
class BodyContext:
    """Bone-derived positions and axes used across all body part builders."""

    armature: bpy.types.Object
    frame: Frame
    hips: Vector
    head: Vector
    shoulder_l: Vector
    shoulder_r: Vector
    elbow_l: Vector
    elbow_r: Vector
    wrist_l: Vector
    wrist_r: Vector
    hand_l: Vector
    hand_r: Vector
    socket_l: Vector
    socket_r: Vector
    knee_l: Vector
    knee_r: Vector
    ankle_l: Vector
    ankle_r: Vector
    toes_l: Vector
    toes_r: Vector
    scale: float
    crotch: Vector
    neck_base: Vector
    shoulder_line: Vector
    chest_height: Vector
    waist: Vector
    knee_center: Vector
    mid_thigh: Vector
    head_center: Vector

    @classmethod
    def from_armature(cls, armature: bpy.types.Object) -> BodyContext:
        frame = Frame(armature)
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

        up = frame.up
        stature_guess = (head - ankle_l).dot(up) + 0.32
        scale = stature_guess / 1.76  # Part radii are tuned for a 1.76 stature.
        crotch = hips - up * 0.05 * scale
        neck_base = hips.lerp(head, 0.88)
        shoulder_line = hips.lerp(head, 0.72)
        chest_height = hips.lerp(head, 0.45)
        waist = hips.lerp(head, 0.16)
        knee_center = (knee_l + knee_r) * 0.5

        return cls(
            armature=armature,
            frame=frame,
            hips=hips,
            head=head,
            shoulder_l=shoulder_l,
            shoulder_r=shoulder_r,
            elbow_l=elbow_l,
            elbow_r=elbow_r,
            wrist_l=wrist_l,
            wrist_r=wrist_r,
            hand_l=hand_l,
            hand_r=hand_r,
            socket_l=socket_l,
            socket_r=socket_r,
            knee_l=knee_l,
            knee_r=knee_r,
            ankle_l=ankle_l,
            ankle_r=ankle_r,
            toes_l=toes_l,
            toes_r=toes_r,
            scale=scale,
            crotch=crotch,
            neck_base=neck_base,
            shoulder_line=shoulder_line,
            chest_height=chest_height,
            waist=waist,
            knee_center=knee_center,
            mid_thigh=crotch.lerp(knee_center, 0.55),
            head_center=head + up * 0.13 * scale,
        )
