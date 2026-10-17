"""Detail bones for the shared motion rig: neck, collarbones, upper spine.

The inherited 41-bone motion rig bends the trunk at two joints (spine,
chest), hangs the head straight off the chest and the arms straight off the
chest. MPFB weights the body on a finer skeleton (three spine bones, a neck,
two clavicles); build_human used to fold those into the coarse bones. This
module inserts four bones on the MPFB joints instead:

    hips - spine - spine_upper - chest - neck - head
                                 chest - shoulder.l/r - upperarm.l/r

Each new bone copies the rest orientation of the bone it splits (spine_upper
= spine, neck = head, shoulder = upperarm), so a local rotation means the same
thing on both and the clips keep their meaning. ``derive_motion`` then spreads
the clips over the new joints:

* spine and head rotations are split in half between the bone and its new
  neighbour (the trunk and neck bend along their length, not at one hinge);
* the collarbone follows the arm (scapulohumeral rhythm): it lifts as the arm
  rises above the T-pose and draws forward as the arm reaches forward. The upper arm is counter-rotated so it keeps its
  direction; only the shoulder joint moves.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

# new bone -> (bone whose rest orientation it copies, parent, child that is reparented to it)
DETAIL_BONES = {
    "spine_upper": ("spine", "spine", "chest"),
    "neck": ("head", "chest", "head"),
    "shoulder.l": ("upperarm.l", "chest", "upperarm.l"),
    "shoulder.r": ("upperarm.r", "chest", "upperarm.r"),
}
# Share of a clip rotation moved from the bone onto its new neighbour.
SPLIT = {"spine": ("spine_upper", 0.5), "head": ("neck", 0.5)}
# Collarbone per degree of arm elevation above the T-pose (rest), and the
# elevation range it follows (0 = arm hanging, 90 = T-pose, 180 = overhead).
# It only lifts: dropping it for hanging arms pulled every neckline down while
# straps and hand-weighted cloth stayed on the chest.
ELEVATION_GAIN = 0.15
ELEVATION_RANGE = (90.0, 170.0)
PROTRACT_DEG = 10.0   # arm straight forward
RETRACT_DEG = 5.0     # arm straight back


def add_bones(rig, targets):
    """Insert the detail bones on the MPFB joints (edit mode)."""
    bones = rig.data.edit_bones
    for name, (like, parent, child) in DETAIL_BONES.items():
        ref = bones[like]
        direction = (ref.tail - ref.head).normalized()
        head = targets[name]
        to_child = (bones[child].head - head).dot(direction)
        bone = bones.get(name) or bones.new(name)
        bone.head = head
        bone.tail = head + direction * max(0.02, to_child)
        bone.align_roll(ref.matrix.to_3x3() @ Vector((0, 0, 1)))
        bone.parent = bones[parent]
        bone.use_connect = False
        bone.use_deform = True
        bones[child].parent = bone
        bones[child].use_connect = False
    if "head_bone" in targets:
        # The head now turns on the skull base; the neck takes the lower joint.
        head = bones["head"]
        direction = (head.tail - head.head).normalized()
        length = max(0.05, (targets["head_top"] - targets["head_bone"]).dot(direction))
        roll = head.matrix.to_3x3() @ Vector((0, 0, 1))
        head.head = targets["head_bone"]
        head.tail = head.head + direction * length
        head.align_roll(roll)
        neck = bones["neck"]
        neck.tail = neck.head + (neck.tail - neck.head).normalized() * max(0.02, (head.head - neck.head).dot(direction))


def _half(q, share):
    if q.w < 0:
        q = -q
    return Quaternion().slerp(q, share)


def _shoulder_rotation(q_arm, rest_3x3):
    """Collarbone rotation (in the shared upper-arm rest frame) for an arm rotation."""
    inv = rest_3x3.inverted()
    up = (inv @ Vector((0, 0, 1))).normalized()
    front = (inv @ Vector((0, -1, 0))).normalized()
    axis_y = Vector((0, 1, 0))
    d = q_arm @ axis_y
    elevation = 90.0 + math.degrees(math.asin(max(-1.0, min(1.0, d.dot(up)))))
    lo, hi = ELEVATION_RANGE
    lift = math.radians(ELEVATION_GAIN * (min(hi, max(lo, elevation)) - 90.0))
    reach = d.dot(front)
    forward = math.radians(PROTRACT_DEG * max(0.0, reach) - RETRACT_DEG * max(0.0, -reach))
    rot = Quaternion()
    for target, angle in ((up, lift), (front, forward)):
        axis = axis_y.cross(target)
        if axis.length > 1e-6 and abs(angle) > 1e-6:
            rot = Quaternion(axis.normalized(), angle) @ rot
    return rot


def _keyed_frames(action):
    lo, hi = action.frame_range
    return range(int(math.floor(lo)), int(math.ceil(hi)) + 1)


def derive_motion(rig):
    """Spread every clip over the detail bones (sampled per frame, keys rewritten)."""
    scene = bpy.context.scene
    pbs = rig.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
    rest = {s: rig.data.bones[f"upperarm.{s}"].matrix_local.to_3x3() for s in ("l", "r")}
    driven = list(SPLIT) + [f"upperarm.{s}" for s in ("l", "r")]
    new = [v[0] for v in SPLIT.values()] + [f"shoulder.{s}" for s in ("l", "r")]
    animation = rig.animation_data
    for action in list(bpy.data.actions):
        for pb in pbs:
            pb.matrix_basis = Matrix.Identity(4)  # unkeyed bones must not keep the last clip's pose
        animation.action = action
        samples = []
        for frame in _keyed_frames(action):
            scene.frame_set(frame)
            samples.append((frame, {b: pbs[b].rotation_quaternion.copy() for b in driven}))
        for frame, q in samples:
            out = {}
            for bone, (neighbour, share) in SPLIT.items():
                part = _half(q[bone], share)
                out[neighbour] = part
                out[bone] = part.inverted() @ q[bone]
            for s in ("l", "r"):
                c = _shoulder_rotation(q[f"upperarm.{s}"], rest[s])
                out[f"shoulder.{s}"] = c
                out[f"upperarm.{s}"] = c.inverted() @ q[f"upperarm.{s}"]
            for bone, value in out.items():
                pbs[bone].rotation_quaternion = value
                pbs[bone].keyframe_insert("rotation_quaternion", frame=frame, group=bone)
        for bone in new:
            pbs[bone].rotation_quaternion = Quaternion()
    animation.action = None
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    return len(bpy.data.actions)
