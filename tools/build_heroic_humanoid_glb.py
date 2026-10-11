#!/usr/bin/env python3
"""Bake adult heroic proportions into the KayKit humanoid at skeleton level.

The KayKit Adventurers rig is a chibi (roughly three heads tall). Earlier
passes only warped vertices, which left the skeleton short and forced runtime
bone-scale hacks that fought the animations. This bake retargets the rig
itself so mesh, skeleton, and clips stay mutually consistent:

1. Bone rest translations are scaled per segment (longer legs and arms,
   compressed torso, narrower shoulders), and the hips are raised to match
   the new leg length.
2. Inverse bind matrices are recomputed for the moved joints.
3. Skinned vertices and normals are re-deformed through their skin weights
   with a per-bone volume matrix (slimmer torso, smaller head and hands), so
   the mesh follows the new skeleton exactly.
4. Animation translation tracks are scaled with the same per-node factors,
   which keeps root bobbing and stride poses proportional.

Skin weights, clip names, materials, and accessory nodes are untouched, so
SharedCharacterRig keeps the same API. Proportions come from
tools/character_specs.py; a body-type variant is just another spec entry:

    python3 tools/build_heroic_humanoid_glb.py [spec_name]
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import numpy as np

from character_specs import spec as character_spec

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/shared/kaykit_barbarian.glb"

# Proportions come from tools/character_specs.py (BASE_PROPORTIONS plus the
# selected character's overrides): adult stature with legs about half the
# height. The KayKit meshes ride along only as placeholders;
# tools/generate_hero_body.py strips them and models our own body around
# this skeleton, so the values that matter here are the bone-layout ones
# (lengths and widths).

# Per-bone volume shaping applied to skinned vertices in bone-local space
# (X across, Y along the segment, Z front-to-back).
def _volume_scales(p: dict) -> dict[str, np.ndarray]:
    scales = {
        "hips": np.array([0.86, 1.0, 0.82]),
        "spine": np.array([0.84, p["torso_length"], 0.80]),
        "chest": np.array([0.84, p["torso_length"], 0.80]),
        "head": np.array([p["head_size"]] * 3),
        "upperarm": np.array([0.80, p["arm_length"], 0.80]),
        "lowerarm": np.array([0.80, p["arm_length"], 0.80]),
        "wrist": np.array([0.85, 1.0, 0.85]),
        "hand": np.array([p["hand_size"]] * 3),
        "handslot": np.array([p["hand_size"]] * 3),
        "upperleg": np.array([0.84, p["leg_length"], 0.84]),
        "lowerleg": np.array([0.84, p["leg_length"], 0.84]),
        "foot": np.array([0.90, 1.0, 0.90]),
        "toes": np.array([0.90, 1.0, 0.90]),
    }
    return scales


# Componentwise factors for bone rest translations and their animation
# translation tracks. A child bone's translation is its parent's segment, so
# lengthening the thigh means scaling the lowerleg offset, and so on.
def _translation_factors(p: dict, hips_lift: float) -> dict[str, np.ndarray]:
    return {
        "hips": np.array([1.0, hips_lift, 1.0]),
        "spine": np.array([1.0, p["torso_length"], 1.0]),
        "chest": np.array([1.0, p["torso_length"], 1.0]),
        "head": np.array([1.0, p["torso_length"], 1.0]),
        "upperarm.l": np.array([p["shoulder_width"], p["shoulder_drop"], 1.0]),
        "upperarm.r": np.array([p["shoulder_width"], p["shoulder_drop"], 1.0]),
        "lowerarm.l": np.array([1.0, p["arm_length"], 1.0]),
        "lowerarm.r": np.array([1.0, p["arm_length"], 1.0]),
        "wrist.l": np.array([1.0, p["arm_length"], 1.0]),
        "wrist.r": np.array([1.0, p["arm_length"], 1.0]),
        # Pull the grip point into the center of our generated mitt: the
        # vendor handslot sits at the fingertip-front of the KayKit hand,
        # outside the blockier generated fist.
        "handslot.l": np.array([p["hand_size"] * 0.45] * 3),
        "handslot.r": np.array([p["hand_size"] * 0.45] * 3),
        "upperleg.l": np.array([p["hip_socket_width"], 1.0, 1.0]),
        "upperleg.r": np.array([p["hip_socket_width"], 1.0, 1.0]),
        "lowerleg.l": np.array([1.0, p["leg_length"], 1.0]),
        "lowerleg.r": np.array([1.0, p["leg_length"], 1.0]),
        "foot.l": np.array([1.0, p["leg_length"], 1.0]),
        "foot.r": np.array([1.0, p["leg_length"], 1.0]),
    }


def _load_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    offset = 12
    json_chunk = None
    bin_chunk = b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk_data = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:
            json_chunk = json.loads(chunk_data)
        elif chunk_type == 0x004E4942:
            bin_chunk = chunk_data
    if json_chunk is None:
        raise ValueError(f"{path} has no JSON chunk")
    return json_chunk, bin_chunk


def _write_glb(gltf: dict, bin_chunk: bytearray) -> bytes:
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - len(bin_chunk) % 4) % 4
    bin_chunk.extend(b"\x00" * bin_pad)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_chunk)
    out = bytearray()
    out.extend(struct.pack("<4sII", b"glTF", 2, total))
    out.extend(struct.pack("<II", len(json_bytes), 0x4E4F534A))
    out.extend(json_bytes)
    out.extend(struct.pack("<II", len(bin_chunk), 0x004E4942))
    out.extend(bin_chunk)
    return bytes(out)


def _component_dtype(component_type: int) -> np.dtype:
    return {
        5120: np.int8,
        5121: np.uint8,
        5122: np.int16,
        5123: np.uint16,
        5125: np.uint32,
        5126: np.float32,
    }[component_type]


def _num_components(accessor_type: str) -> int:
    return {
        "SCALAR": 1,
        "VEC2": 2,
        "VEC3": 3,
        "VEC4": 4,
        "MAT2": 4,
        "MAT3": 9,
        "MAT4": 16,
    }[accessor_type]


def _read_accessor(gltf: dict, bin_chunk: bytes, accessor_index: int) -> np.ndarray:
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = _component_dtype(accessor["componentType"])
    ncomp = _num_components(accessor["type"])
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    count = accessor["count"]
    stride = view.get("byteStride", ncomp * dtype().itemsize)
    if stride != ncomp * dtype().itemsize:
        # Packed layout with custom stride is not used in the KayKit export.
        raise ValueError("unsupported buffer stride")
    arr = np.frombuffer(
        bin_chunk,
        dtype=dtype,
        count=count * ncomp,
        offset=start,
    ).reshape(count, ncomp)
    return arr.copy()


def _write_accessor(
    gltf: dict,
    bin_chunk: bytearray,
    accessor_index: int,
    values: np.ndarray,
) -> None:
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = _component_dtype(accessor["componentType"])
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    flat = np.asarray(values, dtype=dtype).reshape(-1)
    bin_chunk[start : start + flat.nbytes] = flat.tobytes()
    accessor["min"] = values.min(axis=0).tolist()
    accessor["max"] = values.max(axis=0).tolist()


def _quat_multiply(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Hamilton product for glTF-order quaternions [x, y, z, w]; either side
    may be a single quaternion or an (N, 4) array."""
    ax, ay, az, aw = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    bx, by, bz, bw = b[..., 0], b[..., 1], b[..., 2], b[..., 3]
    return np.stack(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ],
        axis=-1,
    )


def _axis_angle_quat(axis: np.ndarray, degrees: float) -> np.ndarray:
    radians = np.deg2rad(degrees)
    axis = axis / np.linalg.norm(axis)
    return np.append(axis * np.sin(radians / 2.0), np.cos(radians / 2.0))


def _axis_angle_quat_array(axis: np.ndarray, degrees: np.ndarray) -> np.ndarray:
    """One quaternion per angle about a shared axis, shaped (..., 4)."""
    radians = np.deg2rad(np.asarray(degrees, dtype=np.float64))
    axis = axis / np.linalg.norm(axis)
    sin_half = np.sin(radians / 2.0)[..., None]
    return np.concatenate(
        [axis * sin_half, np.cos(radians / 2.0)[..., None]], axis=-1
    )


def _quat_inverse(q: np.ndarray) -> np.ndarray:
    inverse = q.copy()
    inverse[..., :3] *= -1.0
    return inverse


def _quat_to_euler_xyz_degrees(q: np.ndarray) -> np.ndarray:
    x, y, z, w = q[..., 0], q[..., 1], q[..., 2], q[..., 3]
    roll = np.arctan2(2.0 * (w * x + y * z), 1.0 - 2.0 * (x * x + y * y))
    pitch = np.arcsin(np.clip(2.0 * (w * y - z * x), -1.0, 1.0))
    yaw = np.arctan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z))
    return np.degrees(np.stack([roll, pitch, yaw], axis=-1))


def _euler_xyz_degrees_to_quat(euler: np.ndarray) -> np.ndarray:
    roll, pitch, yaw = np.radians(euler[..., 0]), np.radians(euler[..., 1]), np.radians(euler[..., 2])
    cr, sr = np.cos(roll / 2.0), np.sin(roll / 2.0)
    cp, sp = np.cos(pitch / 2.0), np.sin(pitch / 2.0)
    cy, sy = np.cos(yaw / 2.0), np.sin(yaw / 2.0)
    return np.stack(
        [
            sr * cp * cy - cr * sp * sy,
            cr * sp * cy + sr * cp * sy,
            cr * cp * sy - sr * sp * cy,
            cr * cp * cy + sr * sp * sy,
        ],
        axis=-1,
    )


# Locomotion arm carriage is rebuilt rather than attenuated.
#
# The KayKit source clips were authored on a barrel-wide chibi: it walks and
# runs with the elbows folded past a right angle, carried at chest height and
# driven far behind the back. Scaling those deltas only shrinks a cycle around
# the wrong neutral pose, and the euler axes of the source bones mix swing with
# abduction, so per-axis attenuation traded one review defect for another.
#
# Instead the arm swing is authored here in body terms and only its *phase* is
# taken from the clip, which keeps stride timing and the contralateral relation
# that test_character_rig.gd asserts. Each arm bone is posed as
#
#     rotate(lateral_axis, neutral + amplitude * phase(t)) x rest_with_relax
#
# where `phase(t)` is the source sagittal signal normalised to [-1, 1]. Angles
# are therefore real degrees of shoulder swing and elbow bend measured from the
# rest carriage, which is what tools/audit_arm_swing.py reports.
#
# Every Walking_*/Running_* clip is treated, not just the canonical pair,
# because CharacterVariant.animation_overrides may pick any of them.
_LOCOMOTION_PREFIXES = ("Walking_", "Running_")

# Body axes in glTF world space (Y up, Z forward). Rotating about the lateral
# axis swings a hanging arm sagittally (negated so a positive angle carries the
# arm forward); rotating about the forward axis draws the elbow in toward the
# ribs. Both are mapped into each bone's parent space (`_swing_axes`), because
# the arm bones' local frames are mirrored and twisted relative to the body -
# assuming a shared local axis instead sent one elbow outward and
# desynchronised the two arms.
#
# Adduction has to be authored here because the rest carriage is not a usable
# neutral: the retargeted A-pose leaves the elbows ~39 degrees abducted, and
# rebuilding the swing from that rest alone parked them far outside the hips.
_WORLD_SWING_AXIS = np.array([-1.0, 0.0, 0.0])
_WORLD_ADDUCT_AXIS = np.array([0.0, 0.0, 1.0])

# Walk and run are different gaits, not one gait at two speeds. A walking arm
# hangs nearly straight and swings from the shoulder; a running arm holds a
# bent elbow and drives it back. `neutral` offsets the whole cycle (positive =
# forward), `amplitude` is the half-range of the swing, and `adduct` pulls the
# limb in toward the body - all in degrees.
# The forearm entries are elbow angles: the retargeted rest carries a 129
# degree elbow, and a negative angle straightens it toward 180 while a positive
# one folds it. A walking arm is nearly straight; a running arm is near a right
# angle.
_ARM_SWING: dict[str, dict[str, dict[str, float]]] = {
    "Walking_": {
        "upperarm": {"neutral": 2.0, "amplitude": 20.0, "adduct": 33.0},
        # A relaxed walking elbow stays slightly bent all cycle and pumps a
        # little as the arm comes forward.
        "lowerarm": {"neutral": -31.0, "amplitude": 8.0, "adduct": 0.0},
    },
    "Running_": {
        # The shoulder cycle is centred slightly behind vertical and the elbow
        # pumps hard: it opens toward 140 degrees as the arm goes back and
        # closes past a right angle in front. That pump is what carries the
        # hand behind the hip at the back of the stride without driving the
        # elbow itself straight back, which was the original review defect.
        "upperarm": {"neutral": -18.0, "amplitude": 40.0, "adduct": 30.0},
        "lowerarm": {"neutral": 26.0, "amplitude": 36.0, "adduct": 0.0},
    },
}


def _locomotion_family(animation_name: str) -> str | None:
    for prefix in _LOCOMOTION_PREFIXES:
        if animation_name.startswith(prefix):
            return prefix
    return None


def _swing_phase(source_rest: np.ndarray, values: np.ndarray) -> np.ndarray:
    """Normalised [-1, 1] stride phase from the source clip's sagittal signal.

    The signal is centred on its own mean first. The chibi source carries a
    large constant offset in this component - and a mirrored one per side - so
    normalising the raw signal yielded a near-constant phase that froze one arm
    forward and the other back instead of swinging them.

    Centring and normalising per bone and clip also equalises the two arms'
    amplitude, which the source does not do, while preserving each arm's timing
    and sign, so the contralateral relation survives.
    """
    deltas = _quat_multiply(_quat_inverse(source_rest), values)
    signal = _quat_to_euler_xyz_degrees(deltas)[..., 2]
    signal = signal - float(np.mean(signal))
    peak = float(np.max(np.abs(signal)))
    if peak < 1e-4:
        return np.zeros_like(signal)
    return signal / peak


def _shape_locomotion_arm(
    source_rest: np.ndarray,
    offset: np.ndarray,
    values: np.ndarray,
    animation_name: str,
    bone_name: str,
    parent_rest_rotation: np.ndarray,
) -> np.ndarray | None:
    """Rebuilt locomotion arm track, or None when the clip is not locomotion."""
    family = _locomotion_family(animation_name)
    if family is None:
        return None
    if bone_name.startswith("upperarm"):
        limb = "upperarm"
    elif bone_name.startswith("lowerarm"):
        limb = "lowerarm"
    else:
        return None

    swing = _ARM_SWING[family][limb]
    # Mirrors the rest fold's convention: -relax on the left, +relax on the
    # right.
    side = -1.0 if bone_name.endswith(".l") else 1.0

    swing_axis_world = _WORLD_SWING_AXIS
    adduct_axis_world = _WORLD_ADDUCT_AXIS
    if limb == "lowerarm":
        # The forearm is posed inside an upper arm this pass has already
        # re-aimed, so its parent frame is no longer the rest frame the axes
        # were measured in. Undoing the shoulder's adduction keeps the elbow
        # hinging on the body's lateral axis; the shoulder's swing needs no
        # correction because it turns about that axis itself. Skipping this
        # left the elbow bend leaking into forearm twist - the running arms
        # came out straighter than the walking ones.
        correction = _quat_to_matrix(
            _axis_angle_quat(
                _WORLD_ADDUCT_AXIS, -side * _ARM_SWING[family]["upperarm"]["adduct"]
            )
        )
        swing_axis_world = correction @ swing_axis_world
        adduct_axis_world = correction @ adduct_axis_world

    inverse_parent = np.linalg.inv(parent_rest_rotation)
    swing_axis = inverse_parent @ swing_axis_world
    swing_axis /= np.linalg.norm(swing_axis)
    adduct_axis = inverse_parent @ adduct_axis_world
    adduct_axis /= np.linalg.norm(adduct_axis)

    # The mirrored source bones report the same physical swing with opposite
    # sign, so the left arm's phase is flipped back here. Without it both arms
    # swung together, and the left arm moved with the left leg instead of
    # against it (verified against the knee traces in tools/audit_arm_swing.py).
    phase = side * _swing_phase(source_rest, values)
    angles = swing["neutral"] + swing["amplitude"] * phase
    pose = _quat_multiply(offset, source_rest)
    if swing["adduct"]:
        pose = _quat_multiply(
            _axis_angle_quat(adduct_axis, side * swing["adduct"]), pose
        )
    return _quat_multiply(_axis_angle_quat_array(swing_axis, angles), pose)


def _parent_rest_rotations(
    gltf: dict,
    globals_by_node: dict[int, np.ndarray],
    name_to_index: dict[str, int],
    bone_names: tuple[str, ...],
) -> dict[int, np.ndarray]:
    """Rotation part of each arm bone's parent global rest transform.

    Locomotion angles are authored in body space, so they have to be mapped
    through this to reach the bone's own parent space.
    """
    parent_of: dict[int, int] = {}
    for index, node in enumerate(gltf["nodes"]):
        for child in node.get("children", []):
            parent_of[child] = index

    rotations: dict[int, np.ndarray] = {}
    for name in bone_names:
        index = name_to_index[name]
        parent = parent_of.get(index)
        linear = globals_by_node[parent][:3, :3] if parent is not None else np.eye(3)
        # Drop retarget scale so only orientation remains.
        columns = [
            column / (np.linalg.norm(column) or 1.0) for column in linear.T
        ]
        rotations[index] = np.stack(columns, axis=1)
    return rotations


def _quat_to_matrix(q: np.ndarray) -> np.ndarray:
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def _local_matrix(node: dict, translation: np.ndarray) -> np.ndarray:
    matrix = np.eye(4)
    linear = np.eye(3)
    if "rotation" in node:
        linear = _quat_to_matrix(np.array(node["rotation"], dtype=np.float64))
    if "scale" in node:
        linear = linear @ np.diag(node["scale"])
    matrix[:3, :3] = linear
    matrix[:3, 3] = translation
    return matrix


def _global_rest_transforms(gltf: dict, translations: dict[int, np.ndarray]) -> dict[int, np.ndarray]:
    nodes = gltf["nodes"]
    parents: dict[int, int] = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[child] = index
    globals_cache: dict[int, np.ndarray] = {}

    def global_of(index: int) -> np.ndarray:
        if index in globals_cache:
            return globals_cache[index]
        node = nodes[index]
        translation = translations.get(
            index, np.array(node.get("translation", [0.0, 0.0, 0.0]), dtype=np.float64)
        )
        local = _local_matrix(node, translation)
        parent = parents.get(index)
        matrix = local if parent is None else global_of(parent) @ local
        globals_cache[index] = matrix
        return matrix

    for index in range(len(nodes)):
        global_of(index)
    return globals_cache


def _node_name_map(gltf: dict) -> dict[int, str]:
    return {index: node.get("name", "") for index, node in enumerate(gltf["nodes"])}


def _segment_length(gltf: dict, name_to_index: dict[str, int], child: str) -> float:
    node = gltf["nodes"][name_to_index[child]]
    return float(np.linalg.norm(np.array(node.get("translation", [0.0, 0.0, 0.0]))))


def build(character: str) -> None:
    selected = character_spec(character)
    output_path = ROOT / selected["skeleton_intermediate"]
    gltf, bin_data = _load_glb(SOURCE)
    bin_chunk = bytearray(bin_data)
    nodes = gltf["nodes"]
    names = _node_name_map(gltf)
    name_to_index = {name: index for index, name in names.items()}

    p = selected["proportions"]
    # The hips rise by exactly the leg length added below them.
    thigh = _segment_length(gltf, name_to_index, "lowerleg.l")
    shin = _segment_length(gltf, name_to_index, "foot.l")
    hips_node = nodes[name_to_index["hips"]]
    hips_rest_y = float(hips_node.get("translation", [0.0, 0.0, 0.0])[1])
    hips_lift = (hips_rest_y + (p["leg_length"] - 1.0) * (thigh + shin)) / hips_rest_y
    translation_factors = _translation_factors(p, hips_lift)
    volume_scales = _volume_scales(p)

    old_globals = _global_rest_transforms(gltf, {})

    # 1. Retarget bone rest translations.
    new_translations: dict[int, np.ndarray] = {}
    for name, factors in translation_factors.items():
        if name not in name_to_index:
            raise ValueError(f"expected bone missing from glb: {name}")
        index = name_to_index[name]
        old = np.array(nodes[index].get("translation", [0.0, 0.0, 0.0]), dtype=np.float64)
        new = old * factors
        new_translations[index] = new
        nodes[index]["translation"] = new.tolist()

    # 1b. Fold the arms toward +Z. Upper-arm and forearm angles are authored
    # separately so elbows can stay nearer the ribs while handslots sit on
    # the stride axis; see arm_relax_degrees / forearm_relax_degrees in
    # character_specs.
    rotation_offsets: dict[str, np.ndarray] = {}
    upper_relax = float(p.get("arm_relax_degrees", 0.0))
    lower_relax = float(p.get("forearm_relax_degrees", upper_relax))
    source_arm_rests: dict[int, np.ndarray] = {}
    if upper_relax or lower_relax:
        forward_axis = np.array([0.0, 0.0, 1.0])
        rotation_offsets = {
            "upperarm.l": _axis_angle_quat(forward_axis, -upper_relax),
            "upperarm.r": _axis_angle_quat(forward_axis, upper_relax),
            "lowerarm.l": _axis_angle_quat(forward_axis, -lower_relax),
            "lowerarm.r": _axis_angle_quat(forward_axis, lower_relax),
        }
    for name, offset in rotation_offsets.items():
        index = name_to_index[name]
        node = nodes[index]
        rest_rotation = np.array(node.get("rotation", [0.0, 0.0, 0.0, 1.0]))
        source_arm_rests[index] = rest_rotation
        node["rotation"] = _quat_multiply(offset, rest_rotation).tolist()

    new_globals = _global_rest_transforms(gltf, new_translations)

    # 2. Recompute inverse bind matrices and collect per-joint deformation.
    for skin in gltf.get("skins", []):
        joints: list[int] = skin["joints"]
        ibm_accessor = skin["inverseBindMatrices"]
        ibms = _read_accessor(gltf, bin_chunk, ibm_accessor).reshape(-1, 4, 4)
        deform: list[np.ndarray] = []
        normal_deform: list[np.ndarray] = []
        for slot, joint in enumerate(joints):
            old_global = old_globals[joint]
            new_global = new_globals[joint]
            base_name = names[joint].split(".")[0]
            volume = volume_scales.get(base_name, np.ones(3))
            scale_matrix = np.diag(np.append(volume, 1.0))
            matrix = new_global @ scale_matrix @ np.linalg.inv(old_global)
            deform.append(matrix)
            linear = matrix[:3, :3]
            normal_deform.append(np.linalg.inv(linear).T)
            # glTF stores matrices column-major.
            old_ibm = ibms[slot].T
            new_ibm = np.linalg.inv(new_global) @ old_global @ old_ibm
            ibms[slot] = new_ibm.T
        _write_accessor(gltf, bin_chunk, ibm_accessor, ibms.reshape(-1, 16))
        skin["_deform"] = deform
        skin["_normal_deform"] = normal_deform

    # 3. Re-deform skinned vertices and normals through their weights.
    for node in nodes:
        if "mesh" not in node or "skin" not in node:
            continue
        skin = gltf["skins"][node["skin"]]
        deform = skin["_deform"]
        normal_deform = skin["_normal_deform"]
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            attributes = prim["attributes"]
            positions = _read_accessor(gltf, bin_chunk, attributes["POSITION"]).astype(np.float64)
            joints_arr = _read_accessor(gltf, bin_chunk, attributes["JOINTS_0"]).astype(np.int64)
            weights = _read_accessor(gltf, bin_chunk, attributes["WEIGHTS_0"]).astype(np.float64)
            weights_accessor = gltf["accessors"][attributes["WEIGHTS_0"]]
            if weights_accessor["componentType"] != 5126:
                weights /= np.iinfo(
                    _component_dtype(weights_accessor["componentType"])
                ).max
            totals = weights.sum(axis=1, keepdims=True)
            totals[totals == 0.0] = 1.0
            weights = weights / totals

            homogeneous = np.concatenate(
                [positions, np.ones((positions.shape[0], 1))], axis=1
            )
            blended = np.zeros_like(homogeneous)
            for influence in range(joints_arr.shape[1]):
                slot_indices = joints_arr[:, influence]
                influence_weights = weights[:, influence : influence + 1]
                matrices = np.stack([deform[slot] for slot in slot_indices])
                blended += influence_weights * np.einsum(
                    "nij,nj->ni", matrices, homogeneous
                )
            _write_accessor(gltf, bin_chunk, attributes["POSITION"], blended[:, :3])

            if "NORMAL" in attributes:
                normals = _read_accessor(gltf, bin_chunk, attributes["NORMAL"]).astype(np.float64)
                blended_normals = np.zeros_like(normals)
                for influence in range(joints_arr.shape[1]):
                    slot_indices = joints_arr[:, influence]
                    influence_weights = weights[:, influence : influence + 1]
                    matrices = np.stack([normal_deform[slot] for slot in slot_indices])
                    blended_normals += influence_weights * np.einsum(
                        "nij,nj->ni", matrices, normals
                    )
                lengths = np.linalg.norm(blended_normals, axis=1, keepdims=True)
                lengths[lengths == 0.0] = 1.0
                _write_accessor(
                    gltf, bin_chunk, attributes["NORMAL"], blended_normals / lengths
                )

    for skin in gltf.get("skins", []):
        skin.pop("_deform", None)
        skin.pop("_normal_deform", None)

    # 4. Scale animation translation tracks with the same per-node factors.
    factor_by_node = {
        name_to_index[name]: factors for name, factors in translation_factors.items()
    }
    offset_by_node = {
        name_to_index[name]: offset for name, offset in rotation_offsets.items()
    }
    parent_rotation_by_node = _parent_rest_rotations(
        gltf, new_globals, name_to_index, tuple(rotation_offsets)
    )
    scaled_outputs: dict[int, int] = {}
    rotated_outputs: dict[int, int] = {}
    for animation in gltf.get("animations", []):
        animation_name = animation.get("name", "")
        for channel in animation["channels"]:
            target = channel["target"]
            path = target.get("path")
            node_index = target.get("node")
            sampler = animation["samplers"][channel["sampler"]]
            output = sampler["output"]
            if path == "translation" and node_index in factor_by_node:
                if output in scaled_outputs:
                    if scaled_outputs[output] != node_index:
                        raise ValueError("animation sampler shared across bones")
                    continue
                scaled_outputs[output] = node_index
                values = _read_accessor(gltf, bin_chunk, output).astype(np.float64)
                _write_accessor(
                    gltf, bin_chunk, output, values * factor_by_node[node_index]
                )
            elif path == "rotation" and node_index in offset_by_node:
                if output in rotated_outputs:
                    if rotated_outputs[output] != node_index:
                        raise ValueError("animation sampler shared across bones")
                    continue
                rotated_outputs[output] = node_index
                values = _read_accessor(gltf, bin_chunk, output).astype(np.float64)
                source_rest = source_arm_rests[node_index]
                offset = offset_by_node[node_index]
                shaped = _shape_locomotion_arm(
                    source_rest,
                    offset,
                    values,
                    animation_name,
                    names[node_index],
                    parent_rotation_by_node[node_index],
                )
                _write_accessor(
                    gltf,
                    bin_chunk,
                    output,
                    shaped if shaped is not None else _quat_multiply(offset, values),
                )

    # Report resulting stature for the uniform Model scale constant.
    ymin = float("inf")
    ymax = float("-inf")
    for node in nodes:
        name = node.get("name", "")
        if not name.startswith("Barbarian_") or "mesh" not in node or "skin" not in node:
            continue
        prim = gltf["meshes"][node["mesh"]]["primitives"][0]
        pos = _read_accessor(gltf, bytes(bin_chunk), prim["attributes"]["POSITION"])
        ymin = min(ymin, float(pos[:, 1].min()))
        ymax = max(ymax, float(pos[:, 1].max()))
    height = ymax - ymin
    print(f"Retargeted body height: {height:.4f} units (ymin={ymin:.4f})")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(_write_glb(gltf, bin_chunk))
    print(f"Wrote {output_path.relative_to(ROOT)}")


if __name__ == "__main__":
    try:
        build(sys.argv[1] if len(sys.argv) > 1 else "hero")
    except Exception as exc:  # pragma: no cover - CLI surface
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
