"""Build a game-ready European hedgehog GLB with a keratin spine mantle.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_hedgehog_model.py

WHY: the catalog insectivore is a six-segment ellipsoid with no quills. At garden
range it reads as a loaf, not Erinaceus europaeus. Voxel remesh fuses thin cones
into that loaf, so the hide is remeshed first and the banded spines are a second
surface planted on the dorsal mantle. Witcher 3 is the fidelity reference only;
no game assets are copied.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ASSET_TOOL_DIR = Path(__file__).resolve().parent
if str(ASSET_TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOL_DIR))

import build_medieval_animal_models as pipeline
from medieval_animal_rigs import (
    add_tapered_segment,
    add_uv_sphere,
    create_flat_material,
    create_quadruped_rig,
    parent_to_bone,
    snap_point_to_mesh_surface,
)

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "assets/animals/medieval"
REPORTS = ROOT / "generated/comfyui/medieval_animals_v1/production/reports"
TEXTURES = ROOT / "generated/comfyui/medieval_animals_v1/production/textures"
OUTPUT = RUNTIME / "medieval_hedgehog.glb"

# Y-up contract after export: length, height, width of the hide. Spines add
# about 2 cm outside this box. Slightly heroic so the snout still reads.
DIMENSIONS_M = (0.25, 0.095, 0.118)

SURFACE_PROFILE = {
    "noise_scale": 148.0,
    "noise_detail": 5.0,
    "bump_strength": 0.34,
    "rough_min": 0.88,
    "rough_max": 0.98,
    "normal_strength": 0.72,
}

SPINE_BASE = (0.86, 0.78, 0.58)
SPINE_MID = (0.58, 0.32, 0.12)
SPINE_UPPER = (0.24, 0.12, 0.05)
SPINE_TIP = (0.05, 0.03, 0.02)


def create_hedgehog_mesh() -> bpy.types.Object:
    """Closed insectivore volumes. Head points along -X and the paws sit on Z=0."""
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 20,
        ring_count: int = 12,
    ) -> bpy.types.Object:
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=segments, ring_count=ring_count, location=location
        )
        part = bpy.context.object
        part.name = part_name
        part.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        parts.append(part)
        return part

    def segment(
        part_name: str,
        start: tuple[float, float, float],
        end: tuple[float, float, float],
        start_radius: float,
        end_radius: float,
        vertices: int = 14,
    ) -> bpy.types.Object:
        start_v = Vector(start)
        end_v = Vector(end)
        direction = end_v - start_v
        bpy.ops.mesh.primitive_cone_add(
            vertices=vertices,
            radius1=end_radius,
            radius2=start_radius,
            depth=direction.length,
            location=(start_v + end_v) * 0.5,
        )
        part = bpy.context.object
        part.name = part_name
        part.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        parts.append(part)
        return part

    # Low oval. The snout is a short cone on the front of the skull, not a bill,
    # and the belly nearly meets the paws so the legs stay tucked.
    sphere("HedgehogMantle", (0.012, 0.0, 0.052), (0.092, 0.062, 0.034), 28, 16)
    sphere("HedgehogRibcage", (0.000, 0.0, 0.044), (0.072, 0.052, 0.028), 24, 14)
    sphere("HedgehogRump", (0.062, 0.0, 0.046), (0.046, 0.050, 0.030), 20, 12)
    sphere("HedgehogChest", (-0.042, 0.0, 0.044), (0.040, 0.044, 0.026), 18, 12)
    sphere("HedgehogBelly", (0.008, 0.0, 0.028), (0.070, 0.046, 0.016), 16, 10)
    segment("HedgehogNeck", (-0.062, 0.0, 0.046), (-0.082, 0.0, 0.044), 0.026, 0.020)
    sphere("HedgehogSkull", (-0.096, 0.0, 0.046), (0.030, 0.026, 0.022), 20, 12)
    sphere("HedgehogBrow", (-0.102, 0.0, 0.058), (0.020, 0.020, 0.010), 14, 8)
    sphere("HedgehogCheekLeft", (-0.088, 0.022, 0.040), (0.016, 0.012, 0.012), 12, 8)
    sphere("HedgehogCheekRight", (-0.088, -0.022, 0.040), (0.016, 0.012, 0.012), 12, 8)
    segment("HedgehogMuzzle", (-0.118, 0.0, 0.044), (-0.150, 0.0, 0.039), 0.011, 0.004, 12)
    sphere("HedgehogMuzzleStop", (-0.134, 0.0, 0.038), (0.012, 0.010, 0.008), 12, 8)
    sphere("HedgehogJaw", (-0.118, 0.0, 0.034), (0.022, 0.014, 0.010), 14, 8)

    for side, y in (("Left", 0.036), ("Right", -0.036)):
        segment(f"HedgehogFront{side}Upper", (-0.028, y, 0.026), (-0.030, y, 0.012), 0.012, 0.009)
        sphere(f"HedgehogFront{side}Paw", (-0.032, y, 0.008), (0.014, 0.011, 0.007), 12, 8)
    for side, y in (("Left", 0.040), ("Right", -0.040)):
        segment(f"HedgehogBack{side}Upper", (0.048, y, 0.026), (0.052, y, 0.012), 0.013, 0.009)
        sphere(f"HedgehogBack{side}Paw", (0.050, y, 0.008), (0.014, 0.011, 0.007), 12, 8)
    segment("HedgehogTail", (0.100, 0.0, 0.040), (0.116, 0.0, 0.036), 0.010, 0.005, 10)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj["procedural_anatomy"] = True
    obj["plantigrade_paws"] = True
    obj["species"] = "hedgehog"
    return obj


def apply_face_fur_displacement(obj: bpy.types.Object) -> None:
    """Soften the face and belly. The dorsal mantle stays smooth for spine roots."""
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    length = max(max_x - min_x, 1e-6)
    height = max(max_z - min_z, 1e-6)
    fur_group = obj.vertex_groups.new(name="HedgehogFurDisplace")
    fur_indices = []
    for vertex in obj.data.vertices:
        point = vertex.co
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        face = 0.06 < nose_to_rump < 0.34 and height_ratio < 0.78
        belly = height_ratio < 0.34 and 0.20 < nose_to_rump < 0.88
        paw = height_ratio < 0.14
        if (face or belly) and not paw:
            fur_indices.append(vertex.index)
    if fur_indices:
        fur_group.add(fur_indices, 1.0, "REPLACE")
    texture = bpy.data.textures.new("HedgehogFurNoise", type="CLOUDS")
    texture.noise_scale = 0.045
    texture.noise_depth = 4
    texture.nabla = 0.015
    displace = obj.modifiers.new("HedgehogFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = 0.0045
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("HedgehogWeightedNormals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    bpy.ops.object.shade_smooth()


def _coat_tick(color: tuple[float, float, float], point: Vector) -> tuple[float, float, float]:
    band = 0.5 + 0.5 * np.sin(point.x * 70.0 + point.z * 40.0 + point.y * 28.0)
    grain = 0.5 + 0.5 * np.sin(point.x * 120.0 - point.y * 90.0 + point.z * 50.0)
    mix = 0.82 + 0.12 * band + 0.06 * (grain - 0.5)
    return tuple(float(np.clip(channel * mix, 0.0, 1.0)) for channel in color)


def paint_hedgehog_coat(obj: bpy.types.Object) -> None:
    """Grizzled face, dirty belly, dark plantigrade feet. Spines are a second mesh."""
    color_layer = obj.data.color_attributes.new(
        name="hedgehog_regions", type="BYTE_COLOR", domain="POINT"
    )
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    length = max(max_x - min_x, 1e-6)
    height = max(max_z - min_z, 1e-6)
    body_width = max((abs(point.y) for point in points), default=1e-6)
    face = (0.34, 0.24, 0.16)
    snout = (0.40, 0.28, 0.18)
    belly = (0.50, 0.40, 0.30)
    dorsal = (0.26, 0.16, 0.09)
    for index, vertex in enumerate(obj.data.vertices):
        point = vertex.co
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        side_ratio = abs(point.y) / max(body_width, 1e-6)
        if height_ratio < 0.10:
            color = (0.10, 0.06, 0.035)
        elif nose_to_rump < 0.035 and 0.22 < height_ratio < 0.50:
            color = (0.07, 0.04, 0.028)
        elif height_ratio < 0.24:
            color = _coat_tick((0.30, 0.20, 0.13), point)
        elif nose_to_rump < 0.14 and height_ratio < 0.58:
            color = _coat_tick(snout, point)
        elif nose_to_rump < 0.30 and height_ratio < 0.70 and side_ratio < 0.78:
            color = _coat_tick(face, point)
        elif height_ratio < 0.30 and side_ratio < 0.42 and 0.30 < nose_to_rump < 0.86:
            color = _coat_tick(belly, point)
        else:
            color = _coat_tick(dorsal, point)
        color_layer.data[index].color = (*color, 1.0)


def _hash01(index: int) -> float:
    value = (index * 1103515245 + 12345) & 0x7FFFFFFF
    return value / 2147483647.0


def _spine_basis(direction: Vector) -> tuple[Vector, Vector]:
    helper = Vector((0.0, 0.0, 1.0)) if abs(direction.z) < 0.85 else Vector((1.0, 0.0, 0.0))
    side = direction.cross(helper).normalized()
    up = side.cross(direction).normalized()
    return side, up


def create_spine_mantle(body: bpy.types.Object) -> bpy.types.Object:
    """Banded keratin quills on the dorsal mantle, raked toward the rump.

    WHY: a displace or normal map reads as fur at this size. Erinaceus spines are
    a silhouette. They are authored after remesh so the voxel size cannot eat them.
    """
    points = [vertex.co.copy() for vertex in body.data.vertices]
    normals = [vertex.normal.copy() for vertex in body.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    length = max(max_x - min_x, 1e-6)
    height = max(max_z - min_z, 1e-6)

    bm = bmesh.new()
    bands: list[tuple[float, float, float]] = []
    sides = 6
    accepted = 0

    def add_vert(position: Vector, color: tuple[float, float, float]) -> bmesh.types.BMVert:
        vert = bm.verts.new(position)
        bands.append(color)
        return vert

    def try_spine(point: Vector, normal_v: Vector, salt: int) -> None:
        nonlocal accepted
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        # Face, belly, and paws stay fur. Spines start behind the brow.
        if nose_to_rump < 0.20 or height_ratio < 0.30:
            return
        # Vertical leg normals are not the skirt. Side quills need some upward normal.
        if height_ratio < 0.46 and normal_v.z < 0.22:
            return
        face_fade = min(1.0, max(0.0, (nose_to_rump - 0.20) / 0.10))
        crown = max(normal_v.z, 0.0)
        # Short overlapping quills read as a coat. Long isolated cones read as horns.
        spine_length = (0.012 + 0.014 * crown) * (0.55 + 0.45 * face_fade)
        spine_length *= 0.88 + 0.24 * _hash01(salt + 17)
        rake = 0.08 + 0.28 * nose_to_rump
        outward = (normal_v + Vector((rake, 0.0, 0.08))).normalized()
        base = point - normal_v * 0.0012
        tip = base + outward * spine_length
        if tip.z < 0.010:
            outward = (outward + Vector((0.0, 0.0, 0.9))).normalized()
            tip = base + outward * spine_length
        radius = 0.00105 * (0.80 + 0.35 * _hash01(salt + 3))
        pale = _hash01(salt + 9) > 0.82
        colors = (
            tuple(min(1.0, channel + 0.08) for channel in SPINE_BASE) if pale else SPINE_BASE,
            SPINE_MID,
            SPINE_UPPER,
            SPINE_TIP,
        )
        side, up = _spine_basis(outward)
        rings: list[list[bmesh.types.BMVert]] = []
        for height_frac, radius_frac, color in (
            (0.00, 1.00, colors[0]),
            (0.40, 0.72, colors[1]),
            (0.74, 0.40, colors[2]),
        ):
            center = base + outward * (spine_length * height_frac)
            ring_radius = radius * radius_frac
            ring = []
            for side_index in range(sides):
                ang = (side_index / sides) * math.tau
                offset = side * math.cos(ang) + up * math.sin(ang)
                ring.append(add_vert(center + offset * ring_radius, color))
            rings.append(ring)
        tip_vert = add_vert(base + outward * spine_length, colors[3])
        for ring_index in range(len(rings) - 1):
            ring_a = rings[ring_index]
            ring_b = rings[ring_index + 1]
            for side_index in range(sides):
                nxt = (side_index + 1) % sides
                bm.faces.new((ring_a[side_index], ring_a[nxt], ring_b[nxt], ring_b[side_index]))
        for side_index in range(sides):
            nxt = (side_index + 1) % sides
            bm.faces.new((rings[-1][nxt], rings[-1][side_index], tip_vert))
        accepted += 1

    # One quill per 4.5 mm of hide. Analytic ovals missed the shoulders and
    # left a bald ring between the face and the crown.
    buckets: dict[tuple[int, int], tuple[Vector, Vector]] = {}
    for point, normal in zip(points, normals):
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        if nose_to_rump < 0.20 or height_ratio < 0.30:
            continue
        if height_ratio < 0.46 and normal.z < 0.22:
            continue
        key = (round(point.x / 0.0036), round(point.y / 0.0036))
        current = buckets.get(key)
        if current is None or normal.z > current[1].z:
            buckets[key] = (point, normal)
    for salt, (point, normal) in enumerate(buckets.values()):
        try_spine(point, normal.normalized(), salt)

    if accepted < 180:
        raise RuntimeError(f"hedgehog spine mantle is too sparse: {accepted}")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new("SpineMantleMesh")
    bm.to_mesh(mesh)
    bm.free()
    if len(mesh.vertices) != len(bands):
        raise RuntimeError("spine vertex colors drifted from the bmesh order")
    color_layer = mesh.color_attributes.new(
        name="hedgehog_spine_regions", type="BYTE_COLOR", domain="POINT"
    )
    for index, color in enumerate(bands):
        color_layer.data[index].color = (*color, 1.0)
    mesh.color_attributes.active_color = color_layer
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("SpineMantle", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["spine_count"] = accepted
    _assign_spine_material(obj)
    return obj


def _assign_spine_material(obj: bpy.types.Object) -> None:
    """Keratin is harder and slightly glossier than the face fur."""
    material = bpy.data.materials.new("medieval_hedgehog_spines")
    material.use_nodes = True
    material.use_backface_culling = False
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    output = nodes.get("Material Output")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    attribute = nodes.new("ShaderNodeAttribute")
    attribute.attribute_name = "hedgehog_spine_regions"
    attribute.attribute_type = "GEOMETRY"
    links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.46
    shader.inputs["Metallic"].default_value = 0.0
    specular = shader.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.38
    obj.data.materials.append(material)


def create_hedgehog_rig(obj: bpy.types.Object):
    """Fit bead eyes, a wet nose, small ears, and muzzle whiskers at species scale."""
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    max_y = max(abs(point.y) for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)

    def ax(fraction: float) -> float:
        return min_x + fraction * (max_x - min_x)

    def az(fraction: float) -> float:
        return min_z + fraction * (max_z - min_z)

    # Fraction probes landed one eye under the snout. Pick the lateral skull
    # vertex and the actual nose tip instead.
    def lateral_eye(y_sign: float) -> Vector:
        best_point = Vector((ax(0.24), max_y * 0.4 * y_sign, az(0.5)))
        best_score = -1.0
        for point in points:
            nose_to_rump = (point.x - min_x) / (max_x - min_x)
            height_ratio = (point.z - min_z) / (max_z - min_z)
            if not (0.16 <= nose_to_rump <= 0.36 and 0.35 <= height_ratio <= 0.72):
                continue
            if point.y * y_sign <= 0.0:
                continue
            score = abs(point.y) * 2.0 + height_ratio
            if score > best_score:
                best_score = score
                best_point = point
        return snap_point_to_mesh_surface(obj, best_point, outward=-0.0008)

    eye_left = lateral_eye(1.0)
    eye_right = lateral_eye(-1.0)
    tip = min(points, key=lambda point: (point.x, -point.z))
    nose = snap_point_to_mesh_surface(obj, tip + Vector((-0.001, 0.0, 0.001)), outward=0.0004)
    ear_left = snap_point_to_mesh_surface(
        obj, Vector((ax(0.28), max_y * 0.72, az(0.62))), outward=0.001
    )
    ear_right = snap_point_to_mesh_surface(
        obj, Vector((ax(0.28), -max_y * 0.72, az(0.62))), outward=0.001
    )
    # Neck catches the low snout before the leg test can swing it with the paws.
    armature, details = create_quadruped_rig(
        obj,
        "HedgehogRig",
        (ax(0.48), 0.0, az(0.42)),
        (ax(0.70), 0.0, az(0.48)),
        {
            "Neck": ((ax(0.36), 0.0, az(0.40)), (ax(0.12), 0.0, az(0.36))),
            "Tail": ((ax(0.90), 0.0, az(0.40)), (ax(0.98), 0.0, az(0.36))),
            "FrontLeftLeg": ((ax(0.34), max_y * 0.55, az(0.28)), (ax(0.32), max_y * 0.55, 0.004)),
            "FrontRightLeg": (
                (ax(0.34), -max_y * 0.55, az(0.28)),
                (ax(0.32), -max_y * 0.55, 0.004),
            ),
            "BackLeftLeg": ((ax(0.64), max_y * 0.58, az(0.28)), (ax(0.66), max_y * 0.58, 0.004)),
            "BackRightLeg": (
                (ax(0.64), -max_y * 0.58, az(0.28)),
                (ax(0.66), -max_y * 0.58, 0.004),
            ),
            "EyeLeft": (tuple(eye_left), (eye_left.x, eye_left.y, eye_left.z + 0.008)),
            "EyeRight": (tuple(eye_right), (eye_right.x, eye_right.y, eye_right.z + 0.008)),
        },
        {
            "neck_x": ax(0.34),
            "neck_z": az(0.10),
            "tail_x": ax(0.92),
            "tail_z": az(0.22),
            "tail_y": max_y * 0.35,
            "leg_z": az(0.24),
            "front_leg_x": ax(0.46),
            "back_leg_x": ax(0.56),
            "eye_x": abs(float(eye_left.x)),
            "eye_scale": (0.003, 0.003, 0.003),
            "pupil_scale": (0.002, 0.002, 0.002),
            "pupil_offset": 0.001,
            "tail_tuft_scale": (0.004, 0.004, 0.004),
        },
        eye_specs=None,
        tail_specs=None,
    )

    eye_material = create_flat_material("hedgehogrig_eye", (0.015, 0.010, 0.008, 1.0))
    eye_shader = eye_material.node_tree.nodes.get("Principled BSDF")
    eye_shader.inputs["Roughness"].default_value = 0.08
    specular = eye_shader.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.55
    pupil_material = create_flat_material("hedgehogrig_pupil", (0.004, 0.003, 0.002, 1.0))
    for side, anchor, bone_name in (
        ("Left", eye_left, "EyeLeft"),
        ("Right", eye_right, "EyeRight"),
    ):
        eye = add_uv_sphere(f"Eye{side}", tuple(anchor), (0.0032, 0.0028, 0.0030), eye_material)
        outward = Vector((-0.0011, 0.0007 if anchor.y > 0.0 else -0.0007, 0.0003))
        pupil = add_uv_sphere(
            f"Pupil{side}",
            tuple(anchor + outward),
            (0.0018, 0.0015, 0.0017),
            pupil_material,
        )
        parent_to_bone(eye, armature, bone_name)
        parent_to_bone(pupil, armature, bone_name)
        details.extend([eye, pupil])

    nose_material = create_flat_material("hedgehogrig_nose", (0.025, 0.012, 0.010, 1.0))
    nose_shader = nose_material.node_tree.nodes.get("Principled BSDF")
    nose_shader.inputs["Roughness"].default_value = 0.16
    nose_obj = add_uv_sphere("NoseTip", tuple(nose), (0.0034, 0.0028, 0.0016), nose_material)
    parent_to_bone(nose_obj, armature, "Neck")
    details.append(nose_obj)

    ear_material = create_flat_material("hedgehogrig_ear", (0.34, 0.24, 0.16, 1.0))
    ear_shader = ear_material.node_tree.nodes.get("Principled BSDF")
    ear_shader.inputs["Roughness"].default_value = 0.82
    inner_material = create_flat_material("hedgehogrig_ear_inner", (0.48, 0.32, 0.28, 1.0))
    for side, anchor in (("Left", ear_left), ("Right", ear_right)):
        ear = add_uv_sphere(f"Ear{side}", tuple(anchor), (0.007, 0.0045, 0.009), ear_material)
        outward_y = 0.002 if anchor.y > 0.0 else -0.002
        inner = add_uv_sphere(
            f"EarInner{side}",
            tuple(anchor + Vector((0.0, outward_y, 0.0))),
            (0.004, 0.002, 0.006),
            inner_material,
        )
        parent_to_bone(ear, armature, "Neck")
        parent_to_bone(inner, armature, "Neck")
        details.extend([ear, inner])

    whisker_material = create_flat_material("hedgehogrig_whisker", (0.08, 0.06, 0.04, 1.0))
    for y_sign in (1.0, -1.0):
        side_name = "Left" if y_sign > 0.0 else "Right"
        for whisker_index, reach in enumerate((0.016, 0.020, 0.014)):
            start = snap_point_to_mesh_surface(
                obj,
                nose + Vector((0.006, 0.004 * y_sign, 0.002 + whisker_index * 0.0015)),
                outward=0.0004,
            )
            end = start + Vector(
                (-0.004, reach * y_sign, 0.002 + whisker_index * 0.001)
            )
            whisker = add_tapered_segment(
                f"Whisker{side_name}{whisker_index}",
                start,
                end,
                0.00045,
                0.00012,
                whisker_material,
            )
            bpy.context.view_layer.objects.active = whisker
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
            bpy.ops.object.mode_set(mode="OBJECT")
            parent_to_bone(whisker, armature, "Neck")
            details.append(whisker)

    # A hedgehog shuffle covers a few centimetres per cycle. The shared livestock
    # clip assumes a much longer stride, so these extras keep the feet from skating.
    armature["walk_reference_speed"] = 0.16
    armature["run_reference_speed"] = 0.32
    armature["procedural_hedgehog"] = True
    return armature, details


def render_preview() -> None:
    scene = bpy.context.scene
    engine_items = scene.render.bl_rna.properties["engine"].enum_items
    engine_ids = {item.identifier for item in engine_items}
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engine_ids else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("HedgehogPreviewWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.42, 0.46, 0.36, 1.0)
    background.inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("HedgehogKey", "SUN")
    sun.energy = 3.6
    sun_object = bpy.data.objects.new("HedgehogKey", sun)
    scene.collection.objects.link(sun_object)
    sun_object.rotation_euler = (0.9, 0.1, 0.7)
    fill = bpy.data.lights.new("HedgehogFill", "SUN")
    fill.energy = 1.1
    fill_object = bpy.data.objects.new("HedgehogFill", fill)
    scene.collection.objects.link(fill_object)
    fill_object.rotation_euler = (1.1, -0.4, -1.6)
    camera_data = bpy.data.cameras.new("HedgehogCam")
    camera_data.lens = 70
    camera = bpy.data.objects.new("HedgehogCam", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (-0.42, -0.34, 0.14)
    aim = Vector((-0.02, 0.0, 0.06)) - camera.location
    camera.rotation_euler = aim.to_track_quat("-Z", "Y").to_euler()
    preview = REPORTS / "hedgehog_preview.png"
    scene.render.filepath = str(preview)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    pipeline.TEXTURES = TEXTURES
    pipeline.clear_scene()
    obj = create_hedgehog_mesh()
    raw = pipeline.topology(obj)
    pipeline.rebuild_surface(
        obj,
        140.0,
        9_000,
        smooth_factor=0.05,
        smooth_iterations=1,
    )
    apply_face_fur_displacement(obj)
    pipeline.normalize_dimensions(obj, DIMENSIONS_M)
    pipeline.make_uv(obj)
    normal = pipeline.bake_normal_map(obj, "hedgehog", SURFACE_PROFILE)
    roughness = pipeline.bake_roughness_map(obj, "hedgehog", SURFACE_PROFILE)
    paint_hedgehog_coat(obj)
    albedo = pipeline.new_image("hedgehog_albedo", (0.40, 0.28, 0.18, 1.0))
    albedo.filepath_raw = str(TEXTURES / "hedgehog_albedo.png")
    albedo.file_format = "PNG"
    albedo.save()
    pipeline.assign_pbr_material(obj, "hedgehog", albedo, normal, roughness, SURFACE_PROFILE)
    coat = obj.data.materials[0]
    coat_shader = coat.node_tree.nodes.get("Principled BSDF")
    specular = coat_shader.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.14
    sheen = coat_shader.inputs.get("Sheen Weight")
    if sheen is not None:
        sheen.default_value = 0.16
    production = pipeline.topology(obj)
    # Spines are planted while the hide is still at the origin. Rig parenting
    # moves the body object, and a later BVH would no longer match local coords.
    spines = create_spine_mantle(obj)
    armature, details = create_hedgehog_rig(obj)
    parent_to_bone(spines, armature, "Body")
    details.append(spines)
    render_preview()
    pipeline.export_glb(obj, OUTPUT, armature, details)
    report = {
        "asset_id": "creature.hedgehog",
        "route": "authored_closed_anatomy_blender_pbr",
        "source_license": "project-authored",
        "anatomy_decision": "remeshed_european_hedgehog_pointed_snout_banded_spine_mantle",
        "scale_basis": "0.25 m nose-to-rump hide; 0.095 m body height; overlapping spines add about 2 cm",
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "spine_count": int(spines.get("spine_count", 0)),
        "metric_dimensions_m_y_up": list(DIMENSIONS_M),
        "animations": ["Idle-loop", "Walk-loop"],
    }
    (REPORTS / "hedgehog_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        "ASSET_METRICS="
        + json.dumps(
            {
                "triangles": production["triangles"],
                "spines": report["spine_count"],
                "sha256": report["output_sha256"],
            }
        )
    )


if __name__ == "__main__":
    main()
