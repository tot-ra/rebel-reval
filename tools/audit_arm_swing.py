"""Numeric arm-pose audit for the generated character rig (Blender, headless).

Locomotion arm readability is a pose problem, not a mesh problem: the CC0
KayKit source clips were authored on a barrel-wide chibi, and the retarget in
`build_heroic_humanoid_glb.py` re-aims them with `arm_relax_degrees` /
`forearm_relax_degrees` plus per-axis swing attenuation. Those knobs were
previously tuned by eye, which is how the run cycle ended up with elbows
pinned behind the back and nearly touching.

This tool samples the exported body and reports, per clip, the measurements a
reviewer actually judges:

  shoulder_gap   rest distance between the arm sockets, the scale reference
  elbow_gap      distance between the two elbows (chibi flare -> too small)
  elbow_behind   how far an elbow trails the shoulder along the stride axis
                 (positive = behind the torso)
  elbow_angle    upper-arm/forearm angle in degrees (180 = straight arm,
                 90 = right angle); walking should stay well above a right
                 angle, running may approach it
  hand_gap       distance between the hand bones

All distances are normalised by stature so they compare across body specs.

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python tools/audit_arm_swing.py -- [--body=PATH] [--clips=Idle,Walking_A]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_BODY = ROOT / "assets/characters/shared/heroic_humanoid.glb"
DEFAULT_CLIPS = ("Idle", "Walking_A", "Running_B")
SAMPLES = 8


def _argument(prefix: str, default: str) -> str:
    for argument in sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []:
        if argument.startswith(prefix):
            return argument[len(prefix) :]
    return default


def _clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _armature() -> bpy.types.Object:
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("no armature in imported body")


def _stride_frame(armature: bpy.types.Object) -> tuple[Vector, Vector, Vector]:
    """Rest-pose body axes: (up, forward, left)."""
    bones = armature.data.bones
    hips = bones["hips"].head_local
    head = bones["head"].head_local
    foot = bones["foot.l"].head_local
    toes = bones["toes.l"].head_local
    up = (head - hips).normalized()
    forward = toes - foot
    forward -= up * forward.dot(up)
    forward = forward.normalized()
    return up, forward, up.cross(forward).normalized()


def _pose_head(armature: bpy.types.Object, name: str) -> Vector:
    return armature.matrix_world @ armature.pose.bones[name].head


def audit(body_path: Path, clip_names: tuple[str, ...]) -> None:
    _clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(body_path))
    armature = _armature()
    up, forward, _left = _stride_frame(armature)
    stature = (
        armature.data.bones["head"].head_local - armature.data.bones["foot.l"].head_local
    ).dot(up) + 0.32

    print(f"ARM_AUDIT body={body_path.name} stature={stature:.3f}")
    for clip_name in clip_names:
        action = bpy.data.actions.get(clip_name)
        if action is None:
            print(f"ARM_AUDIT clip={clip_name} MISSING")
            continue
        armature.animation_data_create()
        armature.animation_data.action = action
        start, end = action.frame_range
        rows: list[tuple[float, float, float, float, float]] = []
        for sample in range(SAMPLES):
            frame = start + (end - start) * sample / SAMPLES
            bpy.context.scene.frame_set(int(round(frame)))
            bpy.context.view_layer.update()

            elbow_l = _pose_head(armature, "lowerarm.l")
            elbow_r = _pose_head(armature, "lowerarm.r")
            shoulder_l = _pose_head(armature, "upperarm.l")
            shoulder_r = _pose_head(armature, "upperarm.r")
            hand_l = _pose_head(armature, "hand.l")
            hand_r = _pose_head(armature, "hand.r")
            wrist_l = _pose_head(armature, "wrist.l")
            wrist_r = _pose_head(armature, "wrist.r")

            hips = _pose_head(armature, "hips")
            knee_l = _pose_head(armature, "lowerleg.l")
            knee_r = _pose_head(armature, "lowerleg.r")
            rows.append(
                {
                    "gap": (elbow_l - elbow_r).length / stature,
                    "behind_l": -(elbow_l - shoulder_l).dot(forward) / stature,
                    "behind_r": -(elbow_r - shoulder_r).dot(forward) / stature,
                    "angle_l": 180.0
                    - math.degrees((elbow_l - shoulder_l).angle(wrist_l - elbow_l, 0.0)),
                    "angle_r": 180.0
                    - math.degrees((elbow_r - shoulder_r).angle(wrist_r - elbow_r, 0.0)),
                    # Positive = hand hangs below the hips, which is where a
                    # walking arm spends most of its cycle.
                    "hand_drop": min(
                        (hips - hand_l).dot(up), (hips - hand_r).dot(up)
                    )
                    / stature,
                    "hand_gap": (hand_l - hand_r).length / stature,
                    # Hand travel along the stride axis, measured from the body
                    # midline like test_character_rig.gd does: the hands have to
                    # straddle it, not ride in front of the chest all cycle.
                    "hand_fwd_l": (hand_l - hips).dot(forward) / stature,
                    "hand_fwd_r": (hand_r - hips).dot(forward) / stature,
                    # Knee travel, for checking that each arm still opposes the
                    # leg on its own side (contralateral stride).
                    "knee_l": (knee_l - hips).dot(forward) / stature,
                    "knee_r": (knee_r - hips).dot(forward) / stature,
                    "shoulder_gap": (shoulder_l - shoulder_r).length / stature,
                }
            )

        def series(key: str) -> list[float]:
            return [row[key] for row in rows]

        print(
            f"ARM_AUDIT clip={clip_name} "
            f"shoulder_gap={sum(series('shoulder_gap')) / len(rows):.3f} "
            f"elbow_gap min={min(series('gap')):.3f} max={max(series('gap')):.3f} "
            f"elbow_behind l={max(series('behind_l')):.3f} "
            f"r={max(series('behind_r')):.3f} "
            f"elbow_angle l={min(series('angle_l')):.0f}-{max(series('angle_l')):.0f} "
            f"r={min(series('angle_r')):.0f}-{max(series('angle_r')):.0f} "
            f"hand_drop min={min(series('hand_drop')):.3f} "
            f"max={max(series('hand_drop')):.3f} "
            f"hand_gap max={max(series('hand_gap')):.3f}"
        )
        # Per-frame series: the two arms must mirror each other across the
        # cycle (contralateral stride), which a min/max summary can hide.
        for key in (
            "behind_l",
            "behind_r",
            "angle_l",
            "angle_r",
            "hand_fwd_l",
            "hand_fwd_r",
            "knee_l",
            "knee_r",
        ):
            values_text = " ".join(f"{value:6.2f}" for value in series(key))
            print(f"ARM_TRACE {clip_name} {key:9s} {values_text}")


def main() -> None:
    body = Path(_argument("--body=", str(DEFAULT_BODY)))
    clips = tuple(_argument("--clips=", ",".join(DEFAULT_CLIPS)).split(","))
    audit(body, clips)


if __name__ == "__main__":
    main()
