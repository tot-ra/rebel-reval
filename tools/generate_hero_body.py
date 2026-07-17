"""Generate our own hero body mesh around the retargeted adult skeleton.

Runs inside Blender (build-time tool only, never at runtime):

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python tools/generate_hero_body.py [-- --character=<spec>]

Input:  the character's skeleton intermediate (see tools/character_specs.py)
        with adult proportions and all 76 CC0 animation clips, produced by
        tools/build_heroic_humanoid_glb.py. Its meshes are placeholders.
Output: the spec's runtime glb — same skeleton and clips, but every visible
        mesh is generated here from scratch, sized from the bone layout so
        proportion changes in the bake flow through, then shaped by the
        spec's `shape` and `palette` overrides.

Skinning is deterministic: each generated vertex is assigned weights at
creation time (rings at joints blend between the two adjacent bones), so no
automatic-weight heuristics are involved.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_specs import spec as character_spec  # noqa: E402

GARMENT_OUTPUTS = {
    "cape": ROOT / "assets/characters/shared/hero_cape.glb",
    "hat": ROOT / "assets/characters/shared/hero_hat.glb",
}

RING_SEGMENTS = 10

PALETTE = {
    "skin": (0.80, 0.58, 0.42, 1.0),
    "tunic": (0.28, 0.38, 0.44, 1.0),
    "pants": (0.34, 0.25, 0.18, 1.0),
    "boots": (0.24, 0.17, 0.12, 1.0),
    "belt": (0.58, 0.26, 0.14, 1.0),
    "hair": (0.78, 0.62, 0.34, 1.0),
    "beard": (0.46, 0.33, 0.17, 1.0),
    "eyes": (0.06, 0.05, 0.05, 1.0),
    "cape": (0.42, 0.24, 0.14, 1.0),
    "hat": (0.32, 0.36, 0.28, 1.0),
}


def _find_armature() -> bpy.types.Object:
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("no armature in imported scene")


def _bone_head(armature: bpy.types.Object, name: str) -> Vector:
    bone = armature.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"missing bone {name}")
    return bone.head_local.copy()


class Frame:
    """Orthonormal body frame derived from the skeleton itself."""

    def __init__(self, armature: bpy.types.Object) -> None:
        hips = _bone_head(armature, "hips")
        head = _bone_head(armature, "head")
        foot = _bone_head(armature, "foot.l")
        toes = _bone_head(armature, "toes.l")
        self.up = (head - hips).normalized()
        forward = toes - foot
        forward -= self.up * forward.dot(self.up)
        self.forward = forward.normalized()
        self.left = self.up.cross(self.forward).normalized()

    def basis_for(self, axis: Vector) -> tuple[Vector, Vector]:
        """Two directions spanning the plane perpendicular to axis."""
        reference = self.up if abs(axis.dot(self.up)) < 0.9 else self.forward
        side = axis.cross(reference).normalized()
        return side, axis.cross(side).normalized()


class PartBuilder:
    """Accumulates ring-loop tube geometry with per-vertex bone weights.

    `bulk` multiplies every ring radius (mass carriers: torso, limbs); parts
    whose size is governed separately (the head group) pass bulk 1.0.
    """

    def __init__(self, name: str, frame: Frame, bulk: float = 1.0) -> None:
        self.name = name
        self.frame = frame
        self.bulk = bulk
        self.vertices: list[Vector] = []
        self.weights: list[dict[str, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.face_materials: list[str] = []
        self._last_ring: list[int] | None = None
        self._last_ring_material: str | None = None

    def _add_vertex(self, position: Vector, weights: dict[str, float]) -> int:
        self.vertices.append(position)
        self.weights.append(weights)
        return len(self.vertices) - 1

    def start_tube(self) -> None:
        self._last_ring = None
        self._last_ring_material = None

    def ring(
        self,
        center: Vector,
        axis: Vector,
        radius_side: float,
        radius_forward: float,
        weights: dict[str, float],
        material: str,
    ) -> list[int]:
        side, forward = self.frame.basis_for(axis.normalized())
        radius_side *= self.bulk
        radius_forward *= self.bulk
        indices: list[int] = []
        for step in range(RING_SEGMENTS):
            angle = math.tau * step / RING_SEGMENTS
            offset = side * (math.cos(angle) * radius_side)
            offset += forward * (math.sin(angle) * radius_forward)
            indices.append(self._add_vertex(center + offset, weights))
        if self._last_ring is not None:
            for step in range(RING_SEGMENTS):
                next_step = (step + 1) % RING_SEGMENTS
                self.faces.append(
                    (
                        self._last_ring[step],
                        self._last_ring[next_step],
                        indices[next_step],
                        indices[step],
                    )
                )
                self.face_materials.append(self._last_ring_material or material)
        self._last_ring = indices
        self._last_ring_material = material
        return indices

    def cap(self, center: Vector, weights: dict[str, float], material: str) -> None:
        if self._last_ring is None:
            return
        apex = self._add_vertex(center, weights)
        for step in range(RING_SEGMENTS):
            next_step = (step + 1) % RING_SEGMENTS
            self.faces.append((self._last_ring[step], self._last_ring[next_step], apex))
            self.face_materials.append(material)

    def box(
        self,
        center: Vector,
        axis_x: Vector,
        axis_y: Vector,
        axis_z: Vector,
        weights: dict[str, float],
        material: str,
    ) -> None:
        corners = []
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                for sz in (-1.0, 1.0):
                    corners.append(
                        self._add_vertex(
                            center + axis_x * sx + axis_y * sy + axis_z * sz, weights
                        )
                    )
        quads = [
            (0, 1, 3, 2),
            (6, 7, 5, 4),
            (0, 2, 6, 4),
            (5, 7, 3, 1),
            (2, 3, 7, 6),
            (4, 5, 1, 0),
        ]
        for quad in quads:
            self.faces.append(tuple(corners[i] for i in quad))
            self.face_materials.append(material)

    def uv_sphere(
        self,
        center: Vector,
        radius: Vector,
        weights: dict[str, float],
        material: str,
        rings: int = 7,
    ) -> None:
        up, forward, left = self.frame.up, self.frame.forward, self.frame.left
        self.start_tube()
        self.cap_pending = None
        bottom = center - up * radius.z
        top = center + up * radius.z
        first = True
        for ring_index in range(1, rings):
            polar = math.pi * ring_index / rings
            ring_radius = math.sin(polar)
            height = -math.cos(polar)
            ring_center = center + up * (height * radius.z)
            indices = self.ring(
                ring_center,
                up,
                radius.x * ring_radius,
                radius.y * ring_radius,
                weights,
                material,
            )
            if first:
                apex = self._add_vertex(bottom, weights)
                for step in range(RING_SEGMENTS):
                    next_step = (step + 1) % RING_SEGMENTS
                    self.faces.append((indices[next_step], indices[step], apex))
                    self.face_materials.append(material)
                first = False
        self.cap(top, weights, material)

    def build(self, armature: bpy.types.Object) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([v[:] for v in self.vertices], [], self.faces)
        mesh.update()

        materials = sorted(set(self.face_materials))
        material_slots = {}
        for slot, material_name in enumerate(materials):
            mesh.materials.append(_material(material_name))
            material_slots[material_name] = slot
        for polygon, material_name in zip(mesh.polygons, self.face_materials):
            polygon.material_index = material_slots[material_name]
        for polygon in mesh.polygons:
            polygon.use_smooth = False

        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)

        groups: dict[str, bpy.types.VertexGroup] = {}
        for index, weight_map in enumerate(self.weights):
            for bone_name, weight in weight_map.items():
                if weight <= 0.0:
                    continue
                group = groups.get(bone_name)
                if group is None:
                    group = obj.vertex_groups.new(name=bone_name)
                    groups[bone_name] = group
                group.add([index], weight, "REPLACE")

        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        obj.parent = armature

        # Consistent outward normals.
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        return obj


# Effective palette for the selected character: PALETTE plus spec overrides.
_active_palette: dict = dict(PALETTE)


def _material(name: str) -> bpy.types.Material:
    existing = bpy.data.materials.get(f"hero_{name}")
    if existing is not None:
        return existing
    material = bpy.data.materials.new(f"hero_{name}")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    # The palette is authored in sRGB; base color factors are linear.
    srgb = _active_palette[name]
    linear = tuple(pow(channel, 2.2) for channel in srgb[:3]) + (srgb[3],)
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.1
    return material


def _blend(a: str, b: str, t: float) -> dict[str, float]:
    return {a: 1.0 - t, b: t}


def _mix(center_a: Vector, center_b: Vector, t: float) -> Vector:
    return center_a.lerp(center_b, t)


def generate(character: str) -> None:
    selected = character_spec(character)
    shape = selected["shape"]
    _active_palette.update(selected["palette"])
    source = ROOT / selected["skeleton_intermediate"]
    output = ROOT / selected["output"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    armature = _find_armature()
    frame = Frame(armature)
    up, forward, left = frame.up, frame.forward, frame.left

    hips = _bone_head(armature, "hips")
    head = _bone_head(armature, "head")
    shoulder_l = _bone_head(armature, "upperarm.l")
    shoulder_r = _bone_head(armature, "upperarm.r")
    elbow_l = _bone_head(armature, "lowerarm.l")
    elbow_r = _bone_head(armature, "lowerarm.r")
    wrist_l = _bone_head(armature, "wrist.l")
    wrist_r = _bone_head(armature, "wrist.r")
    hand_l = _bone_head(armature, "hand.l")
    hand_r = _bone_head(armature, "hand.r")
    socket_l = _bone_head(armature, "upperleg.l")
    socket_r = _bone_head(armature, "upperleg.r")
    knee_l = _bone_head(armature, "lowerleg.l")
    knee_r = _bone_head(armature, "lowerleg.r")
    ankle_l = _bone_head(armature, "foot.l")
    ankle_r = _bone_head(armature, "foot.r")
    toes_l = _bone_head(armature, "toes.l")
    toes_r = _bone_head(armature, "toes.r")

    stature_guess = (head - ankle_l).dot(up) + 0.32
    scale = stature_guess / 1.76  # radii below are tuned for a 1.76 stature

    parts: list[PartBuilder] = []

    # ---- torso -------------------------------------------------------------
    torso = PartBuilder("Hero_Torso", frame, bulk=shape["bulk"])
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]
    crotch = hips - up * 0.05 * scale
    neck_base = _mix(hips, head, 0.88)
    shoulder_line = _mix(hips, head, 0.72)
    chest_height = _mix(hips, head, 0.45)
    waist = _mix(hips, head, 0.16)
    torso.start_tube()
    torso.ring(
        crotch, up, 0.085 * scale * belly, 0.070 * scale * belly, {"hips": 1.0}, "pants"
    )
    # Close the pelvis so nothing shows through between the legs.
    torso.cap(crotch - up * 0.005 * scale, {"hips": 1.0}, "pants")
    torso.ring(
        hips + up * 0.02, up, 0.120 * scale * belly, 0.092 * scale * belly,
        {"hips": 1.0}, "belt",
    )
    torso.ring(
        waist, up, 0.108 * scale * belly, 0.085 * scale * belly,
        _blend("hips", "spine", 0.5), "tunic",
    )
    torso.ring(
        chest_height,
        up,
        0.158 * scale * chest_breadth,
        0.100 * scale,
        _blend("spine", "chest", 0.6),
        "tunic",
    )
    torso.ring(
        shoulder_line, up, 0.180 * scale * chest_breadth, 0.095 * scale,
        {"chest": 1.0}, "tunic",
    )
    torso.ring(neck_base, up, 0.055 * scale, 0.050 * scale, {"chest": 1.0}, "tunic")
    torso.cap(neck_base + up * 0.02, {"chest": 1.0}, "tunic")
    # Deltoid bulges follow the upper arm so the shoulder joint stays covered
    # when the arms swing.
    for suffix, shoulder in (("l", shoulder_l), ("r", shoulder_r)):
        torso.uv_sphere(
            shoulder + up * 0.012 * scale,
            Vector((0.068 * scale, 0.062 * scale, 0.066 * scale)),
            {f"upperarm.{suffix}": 1.0},
            "tunic",
            rings=5,
        )
    parts.append(torso)

    # ---- head --------------------------------------------------------------
    # Head bulk is governed by the head_scale shape knob, not body bulk;
    # face-feature boxes stay at base size, which reads fine for the
    # ±10 % head_scale range specs should stay within.
    head_part = PartBuilder("Hero_Head", frame, bulk=shape["head_scale"])
    head_center = head + up * 0.13 * scale
    head_part.uv_sphere(
        head_center,
        Vector((0.140 * scale, 0.145 * scale, 0.155 * scale)),
        {"head": 1.0},
        "skin",
    )
    # neck
    head_part.start_tube()
    head_part.ring(
        neck_base, up, 0.048 * scale, 0.045 * scale,
        _blend("chest", "head", 0.35), "skin",
    )
    head_part.ring(
        head + up * 0.045 * scale, up, 0.050 * scale, 0.047 * scale, {"head": 1.0}, "skin"
    )
    head_part.cap(head + up * 0.065 * scale, {"head": 1.0}, "skin")
    # hair cap: back-top shell, pulled back so the face stays open
    head_part.uv_sphere(
        head_center + up * 0.028 * scale - forward * 0.038 * scale,
        Vector((0.148 * scale, 0.140 * scale, 0.152 * scale)),
        {"head": 1.0},
        "hair",
        rings=6,
    )
    # beard wedge
    head_part.box(
        head_center + forward * 0.118 * scale - up * 0.095 * scale,
        left * 0.082 * scale,
        forward * 0.052 * scale,
        up * 0.075 * scale,
        {"head": 1.0},
        "beard",
    )
    # nose
    head_part.box(
        head_center + forward * 0.145 * scale - up * 0.005 * scale,
        left * 0.020 * scale,
        forward * 0.022 * scale,
        up * 0.030 * scale,
        {"head": 1.0},
        "skin",
    )
    # eyes
    for side in (1.0, -1.0):
        head_part.box(
            head_center + forward * 0.132 * scale + left * side * 0.052 * scale
            + up * 0.032 * scale,
            left * 0.017 * scale,
            forward * 0.010 * scale,
            up * 0.021 * scale,
            {"head": 1.0},
            "eyes",
        )
    parts.append(head_part)

    # ---- arms and hands ----------------------------------------------------
    for suffix, shoulder, elbow, wrist, hand in (
        ("L", shoulder_l, elbow_l, wrist_l, hand_l),
        ("R", shoulder_r, elbow_r, wrist_r, hand_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        arm = PartBuilder(f"Hero_Arm{suffix}", frame, bulk=shape["bulk"])
        arm.start_tube()
        axis_upper = (elbow - shoulder).normalized()
        axis_lower = (wrist - elbow).normalized()
        arm.ring(
            shoulder - axis_upper * 0.02,
            axis_upper,
            0.062 * scale,
            0.062 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            _mix(shoulder, elbow, 0.5),
            axis_upper,
            0.052 * scale,
            0.052 * scale,
            {bone("upperarm"): 1.0},
            "tunic",
        )
        arm.ring(
            elbow,
            (axis_upper + axis_lower).normalized(),
            0.044 * scale,
            0.044 * scale,
            _blend(bone("upperarm"), bone("lowerarm"), 0.5),
            "skin",
        )
        arm.ring(
            _mix(elbow, wrist, 0.5),
            axis_lower,
            0.040 * scale,
            0.040 * scale,
            {bone("lowerarm"): 1.0},
            "skin",
        )
        arm.ring(
            wrist,
            axis_lower,
            0.032 * scale,
            0.032 * scale,
            _blend(bone("lowerarm"), bone("wrist"), 0.5),
            "skin",
        )
        arm.ring(
            hand,
            (hand - wrist).normalized(),
            0.028 * scale,
            0.028 * scale,
            _blend(bone("wrist"), bone("hand"), 0.6),
            "skin",
        )
        arm.cap(hand + (hand - wrist).normalized() * 0.01, {bone("hand"): 1.0}, "skin")
        parts.append(arm)

        # Hand mitt: built in a frame perpendicular to the hand direction (the
        # body frame is degenerate here because rest arms lie along it).
        hand_axis = (hand - wrist).normalized()
        hand_side, hand_up = frame.basis_for(hand_axis)
        hand_part = PartBuilder(f"Hero_Hand{suffix}", frame)
        hand_part.box(
            hand + hand_axis * 0.035 * scale,
            hand_side * 0.030 * scale,
            hand_up * 0.045 * scale,
            hand_axis * 0.058 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        # thumb
        hand_part.box(
            hand + hand_axis * 0.012 * scale + hand_up * 0.050 * scale,
            hand_side * 0.016 * scale,
            hand_up * 0.026 * scale,
            hand_axis * 0.030 * scale,
            {bone("hand"): 1.0},
            "skin",
        )
        parts.append(hand_part)

    # ---- legs and boots ----------------------------------------------------
    for suffix, socket, knee, ankle, toes in (
        ("L", socket_l, knee_l, ankle_l, toes_l),
        ("R", socket_r, knee_r, ankle_r, toes_r),
    ):
        bone = lambda base: f"{base}.{suffix.lower()}"
        leg = PartBuilder(f"Hero_Leg{suffix}", frame, bulk=shape["bulk"])
        leg.start_tube()
        axis_thigh = (knee - socket).normalized()
        axis_shin = (ankle - knee).normalized()
        leg.ring(
            socket - axis_thigh * 0.06 * scale,
            axis_thigh,
            0.082 * scale,
            0.080 * scale,
            {bone("upperleg"): 1.0},
            "pants",
        )
        leg.ring(
            _mix(socket, knee, 0.5),
            axis_thigh,
            0.066 * scale,
            0.066 * scale,
            {bone("upperleg"): 1.0},
            "pants",
        )
        leg.ring(
            knee,
            (axis_thigh + axis_shin).normalized(),
            0.050 * scale,
            0.050 * scale,
            _blend(bone("upperleg"), bone("lowerleg"), 0.5),
            "pants",
        )
        leg.ring(
            _mix(knee, ankle, 0.35),
            axis_shin,
            0.052 * scale,
            0.054 * scale,
            {bone("lowerleg"): 1.0},
            "boots",
        )
        leg.ring(
            ankle + up * 0.01,
            axis_shin,
            0.040 * scale,
            0.044 * scale,
            _blend(bone("lowerleg"), bone("foot"), 0.6),
            "boots",
        )
        leg.cap(ankle, {bone("foot"): 1.0}, "boots")
        parts.append(leg)

        # Boot: heel-to-toe box sitting on the ground, tall enough to swallow
        # the ankle, plus a toe cap weighted toward the toe bone.
        boot = PartBuilder(f"Hero_Boot{suffix}", frame)
        foot_forward = toes - ankle
        foot_forward -= up * foot_forward.dot(up)
        foot_forward = foot_forward.normalized()
        ankle_height = ankle.dot(up)
        ground_ankle = ankle - up * ankle_height
        half_height = ankle_height * 0.62
        heel_to_toe = 0.20 * scale
        boot_center = (
            ground_ankle
            + foot_forward * (heel_to_toe * 0.5 - 0.055 * scale)
            + up * half_height
        )
        boot.box(
            boot_center,
            left * 0.047 * scale,
            foot_forward * (heel_to_toe * 0.5),
            up * half_height,
            {bone("foot"): 1.0},
            "boots",
        )
        boot.box(
            boot_center + foot_forward * (heel_to_toe * 0.5 + 0.024 * scale)
            - up * half_height * 0.30,
            left * 0.044 * scale,
            foot_forward * 0.026 * scale,
            up * half_height * 0.70,
            _blend(bone("foot"), bone("toes"), 0.6),
            "boots",
        )
        parts.append(boot)

    body_objects = [part.build(armature) for part in parts]

    # Report stature so the rig scene can pin its uniform model scale
    # (model_scale = 2.0 / BODY_STATURE).
    crown = head_center + up * 0.150 * scale * shape["head_scale"]
    print(f"BODY_STATURE={crown.dot(up):.4f}")
    print(f"BODY_ACTIONS={len(bpy.data.actions)}")

    _export(output, animations=True)
    print(f"Wrote {output}")

    # ---- garments: separate skinned glbs bound to the same skeleton --------
    if not selected["garments"]:
        return
    for obj in body_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

    garments: dict[str, PartBuilder] = {}

    cape = PartBuilder("Garment_Cape", frame)
    cape.start_tube()
    cape_top = shoulder_line - forward * 0.115 * scale + up * 0.02 * scale
    cape.ring(cape_top, up, 0.155 * scale, 0.022 * scale, {"chest": 1.0}, "cape")
    cape.ring(
        waist - forward * 0.128 * scale, up, 0.168 * scale, 0.024 * scale,
        {"spine": 1.0}, "cape",
    )
    cape.ring(
        hips - forward * 0.132 * scale, up, 0.172 * scale, 0.024 * scale,
        {"hips": 1.0}, "cape",
    )
    hem = _mix(socket_l + socket_r, knee_l + knee_r, 0.82) * 0.5
    cape.ring(
        hem - forward * 0.135 * scale, up, 0.160 * scale, 0.022 * scale,
        {"hips": 1.0}, "cape",
    )
    cape.cap(hem - forward * 0.135 * scale - up * 0.01 * scale, {"hips": 1.0}, "cape")
    garments["cape"] = cape

    hat = PartBuilder("Garment_Hat", frame)
    hat.start_tube()
    brim = head_center + up * 0.105 * scale
    hat.ring(brim, up, 0.190 * scale, 0.200 * scale, {"head": 1.0}, "hat")
    hat.ring(brim + up * 0.020 * scale, up, 0.150 * scale, 0.160 * scale, {"head": 1.0}, "hat")
    hat.ring(brim + up * 0.085 * scale, up, 0.110 * scale, 0.118 * scale, {"head": 1.0}, "hat")
    hat.cap(brim + up * 0.125 * scale, {"head": 1.0}, "hat")
    garments["hat"] = hat

    for name, builder in garments.items():
        if name not in selected["garments"]:
            continue
        garment_object = builder.build(armature)
        _export(GARMENT_OUTPUTS[name], animations=False)
        print(f"Wrote {GARMENT_OUTPUTS[name]}")
        bpy.data.objects.remove(garment_object, do_unlink=True)


def _export(path: Path, animations: bool) -> None:
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_yup=True,
    )


def _character_argument() -> str:
    argv = sys.argv
    if "--" in argv:
        for argument in argv[argv.index("--") + 1 :]:
            if argument.startswith("--character="):
                return argument.split("=", 1)[1]
    return "hero"


if __name__ == "__main__":
    try:
        generate(_character_argument())
    except Exception as exc:
        import traceback

        traceback.print_exc()
        sys.exit(1)
