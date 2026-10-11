"""Authored running cycle for the shared motion rig (replaces the inherited Running_B).

The inherited Running_B (KayKit, re-timed for kalev_fresh) is a chunky run:
the feet land ~45 cm apart and the fists pump up and down by ~40 cm, which
reads as a waddle on realistic MPFB bodies. This module rebuilds the clip from running-biomechanics joint
curves so every human keeps the same clip name and contract:

- narrow track: each stance foot lands close to the body midline;
- arms stay bent near 90 degrees and swing mostly fore-aft from the shoulder,
  forearms turning slightly across the body on the forward swing;
- slight forward trunk lean, pelvis/shoulder counter-rotation, head stabilised;
- stance leg solved by two-bone IK: the flat foot slides straight back on
  the ground at constant speed under one smooth pelvis bounce per step.

Phase contract (RealisticRig.consume_foot_plant): the right foot is the stance
foot in the first half of the cycle, the left foot in the second half, and at
phase 0.25 / 0.75 each hand is on the opposite side of the torso from the knee
on its own side.

Rotations are authored in armature rest axes (X = character left, -Y = front,
Z = up) and converted per bone as basis = R_rest^-1 * Q * R_rest, so the same
curves drive every fitted body regardless of limb lengths.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

CLIP = "Running_B"
FRAMES = 16  # 0.67 s at 24 fps = 180 steps/min, a natural running cadence
STANCE = 0.27  # fraction of the cycle each foot is loaded; the rest is swing
TRACK_HALF_WIDTH = 0.055  # m from midline to the ankle at contact
LEAN_DEG = 7.0
BOUNCE_M = 0.025  # half the pelvis rise per step (5 cm peak to peak)

# Stance: the ankle slides straight back along the ground at constant speed
# from CONTACT_REACH ahead of the hip joint to TOE_OFF_REACH behind it
# (fractions of leg length); two-bone IK solves hip and knee under a smooth
# pelvis bounce that bottoms out at mid-stance with MID_STANCE_KNEE flexion.
CONTACT_REACH = 0.30
TOE_OFF_REACH = 0.46
MID_STANCE_KNEE = 44.0
# The pelvis bottoms out a little before mid-stance so the knee takes the
# landing progressively instead of snapping from straight to loaded.
BOUNCE_LOW = 0.42 * STANCE

# Swing curves for the RIGHT side, (phase, degrees); phase 0 = right contact.
# Positive hip = thigh forward, positive knee = flexed, positive ankle = toes
# down, positive toe = toes bent up. Stance keys are filled in from the IK
# solution so swing leaves and meets the ground without a pop.
HIP_SWING = ((0.36, -20), (0.58, 22), (0.82, 46), (0.94, 34))
KNEE_SWING = ((0.42, 78), (0.58, 115), (0.78, 66), (0.92, 26))
ANKLE_PLANTAR = ((0.0, -4), (0.11, -18), (0.27, 24), (0.42, 10), (0.64, -8), (0.90, -6))
# While loaded the foot is driven by its ground pitch instead (positive = heel
# up): slight heel strike, flat through mid-stance, heel rising into toe-off.
FOOT_GROUND_PITCH = ((0.0, -6), (0.05, 0), (0.15, 0), (0.27, 32))
TOE_EXTENSION = ((0.0, 0), (0.15, 4), (0.25, 26), (0.35, 6), (0.50, 0))
# Right arm counter-swings the right leg: forward while the left thigh is forward.
SHOULDER_FLEX = ((0.0, 2), (0.34, 24), (0.54, -6), (0.84, -58), (0.96, -26))
ELBOW_FLEX = ((0.0, 78), (0.34, 72), (0.54, 80), (0.84, 74), (0.96, 78))
ARM_INWARD = ((0.0, 8), (0.34, 18), (0.60, 8), (0.84, 0))  # humeral internal rotation
ARM_LOWER_DEG = 78.0  # from the T-pose down to the side, leaving a little clearance


def _periodic(keys, phase):
    """Periodic Catmull-Rom through (phase, value) keys over [0, 1)."""
    phase %= 1.0
    n = len(keys)
    for i in range(n):
        p0, v0 = keys[i]
        p1, v1 = keys[(i + 1) % n]
        span = (p1 - p0) % 1.0 or 1.0
        t = (phase - p0) % 1.0
        if t <= span:
            vm = keys[(i - 1) % n][1]
            vp = keys[(i + 2) % n][1]
            s = t / span
            return 0.5 * ((2 * v0) + (-vm + v1) * s + (2 * vm - 5 * v0 + 4 * v1 - vp) * s * s
                          + (-vm + 3 * v0 - 3 * v1 + vp) * s * s * s)
    return keys[0][1]


def _linear(keys, x):
    """Clamped piecewise-linear lookup through ascending (x, value) keys."""
    if x <= keys[0][0]:
        return keys[0][1]
    for (x0, v0), (x1, v1) in zip(keys, keys[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * (x - x0) / (x1 - x0)
    return keys[-1][1]


def _rot(axis, degrees):
    return Quaternion(Vector(axis), math.radians(degrees))


def _side_pose(gait, phase, side):
    """Armature-space rotations for one side; the left side runs half a cycle later."""
    p = phase if side == "r" else phase + 0.5
    mirror = 1.0 if side == "l" else -1.0
    hip, knee = gait.leg(p, side)
    ankle = _periodic(ANKLE_PLANTAR, p)
    # The ankle angle that realises the stance ground pitch (the foot's world
    # pitch is -hip + knee + ankle; hips carry no pitch), blended into the free
    # swing curve just after toe-off and just before contact.
    local = p % 1.0
    if local < STANCE:
        weight = 1.0
    elif local < STANCE + 0.1:
        weight = 1.0 - (local - STANCE) / 0.1
    elif local > 0.94:
        weight = (local - 0.94) / 0.06
    else:
        weight = 0.0
    if weight > 0.0:
        pitch = _linear(FOOT_GROUND_PITCH, min(local if local < 0.5 else 0.0, STANCE))
        ankle += weight * (pitch + hip - knee - ankle)
    toe = _periodic(TOE_EXTENSION, p)
    # Legs hang along -Z: a negative X rotation carries the foot forward (-Y).
    pose = {
        f"upperleg.{side}": _rot((1, 0, 0), -hip) @ _rot((0, 1, 0), mirror * gait.adduction),
        f"lowerleg.{side}": _rot((1, 0, 0), knee),
        f"foot.{side}": _rot((1, 0, 0), ankle),
        f"toes.{side}": _rot((1, 0, 0), -toe),
    }
    shoulder = _periodic(SHOULDER_FLEX, p)
    elbow = _periodic(ELBOW_FLEX, p)
    inward = _periodic(ARM_INWARD, p)
    # Lower the T-pose arm to the side, roll it inward about the vertical, then
    # swing it about the shoulder's lateral axis. The forearm bends forward
    # about Z in rest axes (the upper arm delta carries it along).
    pose[f"upperarm.{side}"] = (_rot((1, 0, 0), -shoulder) @ _rot((0, 0, 1), -mirror * inward)
                                @ _rot((0, 1, 0), mirror * ARM_LOWER_DEG))
    pose[f"lowerarm.{side}"] = _rot((0, 0, 1), -mirror * elbow)
    return pose


def _pose(gait, phase):
    pose = {}
    pose.update(_side_pose(gait, phase, "r"))
    pose.update(_side_pose(gait, phase, "l"))
    # Pelvis turns toward the swinging leg, chest counter-rotates; both follow
    # the right thigh (forward at phase 0.84), so yaw peaks there.
    yaw = math.sin(2 * math.pi * (phase - 0.59))
    drop = math.sin(2 * math.pi * (phase + 0.0))  # hip of the swing leg drops a little in stance
    pose["hips"] = _rot((0, 0, 1), 6.0 * yaw) @ _rot((0, 1, 0), 2.5 * drop)
    pose["spine"] = _rot((1, 0, 0), LEAN_DEG * 0.6)
    pose["chest"] = _rot((1, 0, 0), LEAN_DEG * 0.4) @ _rot((0, 0, 1), -14.0 * yaw)
    # Keep the gaze level and forward: undo the lean and most of the net yaw.
    pose["head"] = _rot((1, 0, 0), -LEAN_DEG * 0.8) @ _rot((0, 0, 1), 7.0 * yaw)
    return pose


def _apply(rig, pose, hips_offset=Vector()):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = Vector()
        pb.rotation_quaternion = Quaternion()
        pb.scale = Vector((1, 1, 1))
    for name, q in pose.items():
        pb = rig.pose.bones[name]
        rest = pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion = rest.inverted() @ q @ rest
    hips = rig.pose.bones["hips"]
    hips.location = hips.bone.matrix_local.to_3x3().inverted() @ hips_offset
    bpy.context.view_layer.update()


def _ground_gap(rig, side, sole_rest):
    """Height of the lowest sole point (heel or ball) above its rest height."""
    foot = rig.pose.bones[f"foot.{side}"]
    posed = foot.matrix @ foot.bone.matrix_local.inverted()
    return min((posed @ point).z - point.z for point in sole_rest[side])


def _sole_points(rig):
    """Rest heel and ball points per side: the heel sits under the ankle at ball height."""
    points = {}
    for side in ("l", "r"):
        ankle = rig.data.bones[f"foot.{side}"].head_local
        ball = rig.data.bones[f"toes.{side}"].head_local.copy()
        heel = Vector((ankle.x, ankle.y + 0.03, ball.z))
        points[side] = (heel, ball)
    return points


def _hip_adduction(rig):
    """Adduction that lands the ankle TRACK_HALF_WIDTH from the midline."""
    bones = rig.data.bones
    hip = bones["upperleg.l"].head_local
    ankle = bones["foot.l"].head_local
    leg = (ankle - hip).length
    return math.degrees(math.asin(max(0.0, ankle.x - TRACK_HALF_WIDTH) / leg))


class _Gait:
    """Leg angles per side: IK overrides while loaded, swing curves otherwise."""

    def __init__(self, adduction):
        self.adduction = adduction
        self.hip_keys = HIP_SWING
        self.knee_keys = KNEE_SWING
        self.stance = {}  # (side, phase) -> (hip, knee)
        self.pending = None  # (side, phase, hip, knee) while solving

    def leg(self, p, side):
        phase = p % 1.0  # p is already this side's own phase
        if self.pending and self.pending[:2] == (side, phase):
            return self.pending[2:]
        if (side, phase) in self.stance:
            return self.stance[(side, phase)]
        return _periodic(self.hip_keys, p), _periodic(self.knee_keys, p)


def _two_bone(forward, down, thigh, shank):
    """Hip flexion and knee flexion (degrees) that put the ankle at forward/down of the hip."""
    reach = min(math.hypot(forward, down), 0.999 * (thigh + shank))
    knee = math.pi - math.acos((thigh * thigh + shank * shank - reach * reach) / (2 * thigh * shank))
    lead = math.acos(max(-1.0, min(1.0, (thigh * thigh + reach * reach - shank * shank) / (2 * thigh * reach))))
    return math.degrees(math.atan2(forward, down) + lead), math.degrees(knee)


def _solve_stance(rig, gait, phase, side, offset, ankle_y, sole_rest, lengths):
    """Hip/knee that put this side's ankle at ankle_y (rest axes) with the sole on the ground."""
    stance_phase = phase if side == "r" else (phase + 0.5) % 1.0
    aim = Vector((0.0, ankle_y, rig.data.bones[f"foot.{side}"].head_local.z))
    hip = knee = 0.0
    for _ in range(6):
        gait.pending = None
        _apply(rig, _pose(gait, stance_phase), Vector((0, 0, offset)))
        joint = rig.pose.bones[f"upperleg.{side}"].head
        hip, knee = _two_bone(joint.y - aim.y, joint.z - aim.z, *lengths)
        gait.pending = (side, phase, hip, knee)
        _apply(rig, _pose(gait, stance_phase), Vector((0, 0, offset)))
        aim.y += ankle_y - rig.pose.bones[f"foot.{side}"].head.y
        aim.z -= _ground_gap(rig, side, sole_rest)
    gait.pending = None
    return hip, knee


def author(rig):
    """Replace CLIP on the fitted rig; returns the stance-foot ground speed (m/s at 1x)."""
    fps = bpy.context.scene.render.fps
    bones = rig.data.bones
    sole_rest = _sole_points(rig)
    lengths = (bones["upperleg.r"].length, bones["lowerleg.r"].length)
    leg = sum(lengths)
    hip_y = bones["upperleg.r"].head_local.y
    front, back = hip_y - CONTACT_REACH * leg, hip_y + TOE_OFF_REACH * leg
    gait = _Gait(_hip_adduction(rig))

    def ankle_y(stance_phase):
        return front + (back - front) * stance_phase / STANCE

    # Pelvis: one bounce per step, based so the mid-stance knee flexes MID_STANCE_KNEE.
    mid_y = ankle_y(BOUNCE_LOW) - hip_y
    reach = math.sqrt(lengths[0] ** 2 + lengths[1] ** 2
                      + 2 * lengths[0] * lengths[1] * math.cos(math.radians(MID_STANCE_KNEE)))
    mid_height = math.sqrt(max(reach * reach - mid_y * mid_y, 0.0))
    rest_drop = bones["upperleg.r"].head_local.z - bones["foot.r"].head_local.z
    base = mid_height - rest_drop + BOUNCE_M

    def offset(phase):
        return base - BOUNCE_M * math.cos(4 * math.pi * (phase - BOUNCE_LOW))

    # Solve the right stance at the swing-curve boundary phases first, so the
    # swing curves start and end exactly on the IK poses.
    boundary = {}
    for p in (0.0, STANCE / 2, STANCE):
        boundary[p] = _solve_stance(rig, gait, p, "r", offset(p), ankle_y(p), sole_rest, lengths)
    gait.hip_keys = tuple((p, v[0]) for p, v in boundary.items()) + HIP_SWING
    gait.knee_keys = tuple((p, v[1]) for p, v in boundary.items()) + KNEE_SWING

    phases = [f / FRAMES for f in range(FRAMES)]
    for phase in phases:
        local = phase % 0.5
        if local < STANCE:
            side = "r" if phase < 0.5 else "l"
            gait.stance[(side, local)] = _solve_stance(
                rig, gait, local, side, offset(phase), ankle_y(local), sole_rest, lengths)

    old = bpy.data.actions.get(CLIP)
    if old is not None:
        old.name = CLIP + "_vendor"
    action = bpy.data.actions.new(CLIP)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame in range(FRAMES + 1):
        phase = (frame % FRAMES) / FRAMES
        _apply(rig, _pose(gait, phase), Vector((0, 0, offset(phase))))
        for pb in rig.pose.bones:
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=frame, group=pb.name)
    if old is not None:
        bpy.data.actions.remove(old)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    return (back - front) / (STANCE * FRAMES / fps)
