"""Build game-ready medieval animal models from approved Hunyuan3D candidates.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_medieval_animal_models.py
    blender -t 1 -b --python tools/assets/build_medieval_animal_models.py -- cattle

Raw image-to-3D meshes stay under generated/comfyui and are never copied into
runtime paths. This pass keeps their approved silhouettes but rebuilds topology,
sets explicit metric dimensions, creates portable UV/PBR materials, and emits
compact reports next to the staging inputs. Each approved livestock mesh receives
a purpose-built low-cost rig, visible eyes, and looping idle/walk animation.
"""

from __future__ import annotations

import bmesh
import bpy
import hashlib
import json
import math
import os
import random
import sys
from pathlib import Path

import numpy as np
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "generated/comfyui/medieval_animals_v1"
RUNTIME = ROOT / "assets/animals/medieval"
REPORTS = STAGING / "production/reports"
TEXTURES = STAGING / "production/textures"
TEXTURE_SIZE = 512

# Dimensions use the game contract's Y-up order: length, height, width.
SPECS = {
    "cattle": {
        "source": STAGING / "cattle_candidate.glb",
        "output": RUNTIME / "medieval_cattle.glb",
        "dimensions_m": (2.20, 1.45, 1.02),
        "triangles": 8_000,
        "voxel_divisor": 72.0,
        "base_color": (0.30, 0.115, 0.055),
        "accent_color": (0.48, 0.235, 0.095),
        "seed": 208744131,
        "animated": True,
    },
    "pig": {
        "source": STAGING / "pig_hendrik_reyneke_cc_by_source.glb",
        "output": RUNTIME / "medieval_pig.glb",
        "dimensions_m": (1.35, 0.75, 0.48),
        "triangles": 7_000,
        "voxel_divisor": 72.0,
        "base_color": (0.19, 0.105, 0.055),
        "accent_color": (0.40, 0.205, 0.095),
        "seed": 208744134,
        "animated": True,
        # WHY: this licensed source already has four clean, articulated legs and
        # cloven feet. Voxel remeshing would erase anatomy instead of repairing it.
        "preserve_topology": True,
        "source_long_axis": "y",
        "route": "licensed_existing_mesh_to_blender_cleanup",
        "source_license": "CC BY 4.0 - hendrikReyneke",
        "anatomy_decision": "approved_four_separate_weight_bearing_legs",
        "scale_basis": "1.35 m nose-to-rump length; 0.75 m standing height",
    },
    "sheep": {
        "source": STAGING / "sheep_candidate.glb",
        "output": RUNTIME / "medieval_sheep.glb",
        "dimensions_m": (1.25, 0.90, 0.55),
        "triangles": 6_000,
        "voxel_divisor": 72.0,
        "base_color": (0.58, 0.51, 0.38),
        "accent_color": (0.78, 0.72, 0.59),
        "seed": 208744132,
        "animated": True,
    },
    "pack_horse": {
        "source": STAGING / "pack_horse_candidate.glb",
        "output": RUNTIME / "medieval_pack_horse.glb",
        "dimensions_m": (2.35, 1.65, 0.78),
        "triangles": 10_000,
        "voxel_divisor": 20.0,
        "base_color": (0.27, 0.17, 0.085),
        "accent_color": (0.49, 0.34, 0.16),
        "seed": 208744133,
        "animated": True,
    },
}


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def topology(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    unseen = set(bm.verts)
    component_sizes: list[int] = []
    while unseen:
        stack = [unseen.pop()]
        count = 0
        while stack:
            vertex = stack.pop()
            count += 1
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in unseen:
                    unseen.remove(other)
                    stack.append(other)
        component_sizes.append(count)
    component_sizes.sort(reverse=True)
    result = {
        "vertices": len(mesh.vertices),
        "polygons": len(mesh.polygons),
        "triangles": sum(max(0, len(face.vertices) - 2) for face in mesh.polygons),
        "components": len(component_sizes),
        "component_vertices": component_sizes,
        "boundary_edges": sum(1 for edge in bm.edges if edge.is_boundary),
        "non_manifold_edges": sum(1 for edge in bm.edges if not edge.is_manifold),
        "loose_vertices": sum(1 for vertex in bm.verts if not vertex.link_edges),
    }
    bm.free()
    return result


def flatten_imported_hierarchy() -> bpy.types.Object:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("Candidate contains no mesh")
    for obj in meshes:
        # WHY: glTF roots can carry axis-conversion transforms. Baking world space
        # first gives PCA, ground contact, and metric normalization stable inputs.
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        obj.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    return obj


def remove_tiny_islands(obj: bpy.types.Object, fraction: float) -> int:
    """Remove only detached scan noise, retaining substantial tack/fleece parts."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    unseen = set(bm.verts)
    islands: list[list[bmesh.types.BMVert]] = []
    while unseen:
        stack = [unseen.pop()]
        island: list[bmesh.types.BMVert] = []
        while stack:
            vertex = stack.pop()
            island.append(vertex)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in unseen:
                    unseen.remove(other)
                    stack.append(other)
        islands.append(island)
    largest = max((len(island) for island in islands), default=0)
    discarded = [island for island in islands if len(island) < max(12, largest * fraction)]
    if discarded:
        bmesh.ops.delete(bm, geom=[vertex for island in discarded for vertex in island], context="VERTS")
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    return len(discarded)


def align_long_axis(obj: bpy.types.Object) -> None:
    points = np.array([(vertex.co.x, vertex.co.y) for vertex in obj.data.vertices], dtype=np.float64)
    centered = points - points.mean(axis=0)
    covariance = np.cov(centered, rowvar=False)
    values, vectors = np.linalg.eigh(covariance)
    axis = vectors[:, int(np.argmax(values))]
    angle = math.atan2(float(axis[1]), float(axis[0]))
    obj.rotation_euler.z = -angle
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def rebuild_surface(obj: bpy.types.Object, divisor: float, target_triangles: int) -> None:
    max_dimension = max(obj.dimensions)
    obj.data.remesh_voxel_size = max_dimension / divisor
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.voxel_remesh()
    remove_tiny_islands(obj, 0.006)

    smooth = obj.modifiers.new("OrganicSurfaceCleanup", "SMOOTH")
    smooth.factor = 0.42
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    current_triangles = topology(obj)["triangles"]
    if current_triangles > target_triangles:
        decimate = obj.modifiers.new("ProductionTriangleBudget", "DECIMATE")
        decimate.ratio = target_triangles / current_triangles
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def normalize_dimensions(obj: bpy.types.Object, dimensions_y_up: tuple[float, float, float]) -> None:
    target_length, target_height, target_width = dimensions_y_up
    # WHY: imported glTF roots can leave stale bound boxes on obj.dimensions even
    # after baking matrix_world into mesh data. Vertex extents keep metric scaling
    # stable for preserve_topology livestock such as the licensed pig source.
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_y = min(point.y for point in points)
    max_y = max(point.y for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    current = Vector((max_x - min_x, max_y - min_y, max_z - min_z))
    obj.scale = (
        target_length / max(current.x, 1e-6),
        target_width / max(current.y, 1e-6),
        target_height / max(current.z, 1e-6),
    )
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    points = [vertex.co for vertex in obj.data.vertices]
    min_z = min(point.z for point in points)
    center_x = (min(point.x for point in points) + max(point.x for point in points)) * 0.5
    center_y = (min(point.y for point in points) + max(point.y for point in points)) * 0.5
    for vertex in obj.data.vertices:
        vertex.co.x -= center_x
        vertex.co.y -= center_y
        vertex.co.z -= min_z
    obj.data.update()


def make_uv(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.05, island_margin=0.025, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def create_albedo(name: str, spec: dict) -> bpy.types.Image:
    """Create deterministic restrained coat variation as a portable texture."""
    rng = np.random.default_rng(spec["seed"])
    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size]
    broad = (
        np.sin(xx / 29.0 + spec["seed"] * 0.001)
        + np.sin(yy / 41.0)
        + np.sin((xx + yy) / 67.0)
    ) / 6.0 + 0.5
    grain = rng.random((size, size))
    mix = np.clip(broad * 0.78 + grain * 0.22, 0.0, 1.0)[..., None]
    base = np.array(spec["base_color"], dtype=np.float32)
    accent = np.array(spec["accent_color"], dtype=np.float32)
    rgb = base + (accent - base) * mix
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=2)

    image = bpy.data.images.new(f"{name}_albedo", size, size, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(rgba.astype(np.float32).ravel().tolist())
    image.filepath_raw = str(TEXTURES / f"{name}_albedo.png")
    image.file_format = "PNG"
    image.save()
    return image


def assign_material(obj: bpy.types.Object, name: str, image: bpy.types.Image) -> None:
    material = bpy.data.materials.new(f"medieval_{name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.84
    shader.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(material)


def create_flat_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    """Create a portable material for small authored facial/tail details."""
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = 0.72
    shader.inputs["Metallic"].default_value = 0.0
    return material


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_tapered_segment(
    name: str,
    start: Vector,
    end: Vector,
    start_radius: float,
    end_radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=10,
        radius1=end_radius,
        radius2=start_radius,
        depth=direction.length,
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def parent_to_bone(obj: bpy.types.Object, armature: bpy.types.Object, bone_name: str) -> None:
    """Rigidly attach authored detail geometry while preserving its world pose."""
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def create_quadruped_rig(
    obj: bpy.types.Object,
    rig_name: str,
    body_head: tuple[float, float, float],
    body_tail: tuple[float, float, float],
    bone_specs: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]],
    group_rules: dict[str, object],
    eye_specs: list[tuple[str, float, float, float, str]] | None = None,
    tail_specs: tuple[tuple[float, float, float], tuple[float, float, float], float, float] | None = None,
) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Shared low-cost quadruped rig for approved single-surface livestock scans."""
    coat = obj.data.materials[0]
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = rig_name
    armature.data.name = f"{rig_name}Skeleton"
    armature.show_in_front = True

    body = armature.data.edit_bones[0]
    body.name = "Body"
    body.head = body_head
    body.tail = body_tail

    for name, (head, tail) in bone_specs.items():
        bone = armature.data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.parent = body
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")

    groups = {name: obj.vertex_groups.new(name=name) for name in bone_specs | {"Body": None}}
    assignments: dict[str, list[int]] = {name: [] for name in groups}
    for vertex in obj.data.vertices:
        point = vertex.co
        group_name = "Body"
        if point.x < group_rules["neck_x"] and point.z > group_rules["neck_z"]:
            group_name = "Neck"
        elif (
            point.x > group_rules["tail_x"]
            and point.z > group_rules["tail_z"]
            and abs(point.y) < group_rules["tail_y"]
        ):
            group_name = "Tail"
        elif point.z < group_rules["leg_z"] and point.x < group_rules["front_leg_x"]:
            group_name = "FrontLeftLeg" if point.y >= 0.0 else "FrontRightLeg"
        elif point.z < group_rules["leg_z"] and point.x > group_rules["back_leg_x"]:
            group_name = "BackLeftLeg" if point.y >= 0.0 else "BackRightLeg"
        assignments[group_name].append(vertex.index)
    for name, indices in assignments.items():
        if indices:
            groups[name].add(indices, 1.0, "REPLACE")

    modifier = obj.modifiers.new(f"{rig_name}Armature", "ARMATURE")
    modifier.object = armature
    obj.parent = armature

    details: list[bpy.types.Object] = []
    if eye_specs is not None:
        eye_white = create_flat_material(f"{rig_name.lower()}_eye_white", (0.58, 0.47, 0.31, 1.0))
        pupil_black = create_flat_material(f"{rig_name.lower()}_pupil", (0.012, 0.008, 0.005, 1.0))
        for side, y, z, bone_name in eye_specs:
            eye = add_uv_sphere(f"Eye{side}", (-group_rules["eye_x"], y, z), group_rules["eye_scale"], eye_white)
            pupil_y = y + (group_rules["pupil_offset"] if y > 0.0 else -group_rules["pupil_offset"])
            pupil = add_uv_sphere(
                f"Pupil{side}",
                (-group_rules["eye_x"] - 0.015, pupil_y, z),
                group_rules["pupil_scale"],
                pupil_black,
            )
            parent_to_bone(eye, armature, bone_name)
            parent_to_bone(pupil, armature, bone_name)
            details.extend([eye, pupil])
        armature["animated_eyes"] = True

    if tail_specs is not None:
        tail_start, tail_end, start_radius, end_radius = tail_specs
        tail = add_tapered_segment(
            "TailTuftStem",
            Vector(tail_start),
            Vector(tail_end),
            start_radius,
            end_radius,
            coat,
        )
        tuft = add_uv_sphere("TailTuft", tuple(tail_end), group_rules["tail_tuft_scale"], coat)
        parent_to_bone(tail, armature, "Tail")
        parent_to_bone(tuft, armature, "Tail")
        details.extend([tail, tuft])
        armature["animated_tail"] = True

    create_livestock_animations(armature)
    return armature, details


def create_cattle_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Compact cattle rig with readable eyes and swishing tail."""
    return create_quadruped_rig(
        obj,
        "CattleRig",
        (0.0, 0.0, 0.48),
        (0.0, 0.0, 1.02),
        {
            "Neck": ((-0.48, 0.0, 0.88), (-0.90, 0.0, 1.15)),
            "Tail": ((0.64, 0.0, 0.90), (0.98, 0.0, 0.50)),
            "FrontLeftLeg": ((-0.55, 0.27, 0.70), (-0.55, 0.27, 0.08)),
            "FrontRightLeg": ((-0.55, -0.27, 0.70), (-0.55, -0.27, 0.08)),
            "BackLeftLeg": ((0.60, 0.27, 0.70), (0.60, 0.27, 0.08)),
            "BackRightLeg": ((0.60, -0.27, 0.70), (0.60, -0.27, 0.08)),
            "EyeLeft": ((-0.80, 0.42, 1.20), (-0.80, 0.42, 1.29)),
            "EyeRight": ((-0.80, -0.42, 1.20), (-0.80, -0.42, 1.29)),
        },
        {
            "neck_x": -0.48,
            "neck_z": 0.68,
            "tail_x": 0.70,
            "tail_z": 0.54,
            "tail_y": 0.36,
            "leg_z": 0.72,
            "front_leg_x": -0.24,
            "back_leg_x": 0.26,
            "eye_x": 0.82,
            "eye_scale": (0.070, 0.026, 0.058),
            "pupil_scale": (0.030, 0.014, 0.034),
            "pupil_offset": 0.024,
            "tail_tuft_scale": (0.075, 0.065, 0.105),
        },
        eye_specs=[
            ("Left", 0.425, 1.205, "EyeLeft"),
            ("Right", -0.425, 1.205, "EyeRight"),
        ],
        tail_specs=((0.67, 0.0, 0.90), (0.98, 0.0, 0.50), 0.050, 0.025),
    )


def create_sheep_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Compact sheep rig scaled to the smaller fleece body envelope."""
    return create_quadruped_rig(
        obj,
        "SheepRig",
        (0.0, 0.0, 0.30),
        (0.0, 0.0, 0.58),
        {
            "Neck": ((-0.26, 0.0, 0.52), (-0.50, 0.0, 0.68)),
            "Tail": ((0.34, 0.0, 0.52), (0.52, 0.0, 0.30)),
            "FrontLeftLeg": ((-0.30, 0.14, 0.44), (-0.30, 0.14, 0.06)),
            "FrontRightLeg": ((-0.30, -0.14, 0.44), (-0.30, -0.14, 0.06)),
            "BackLeftLeg": ((0.32, 0.14, 0.44), (0.32, 0.14, 0.06)),
            "BackRightLeg": ((0.32, -0.14, 0.44), (0.32, -0.14, 0.06)),
            "EyeLeft": ((-0.44, 0.22, 0.70), (-0.44, 0.22, 0.76)),
            "EyeRight": ((-0.44, -0.22, 0.70), (-0.44, -0.22, 0.76)),
        },
        {
            "neck_x": -0.22,
            "neck_z": 0.42,
            "tail_x": 0.35,
            "tail_z": 0.38,
            "tail_y": 0.18,
            "leg_z": 0.46,
            "front_leg_x": -0.10,
            "back_leg_x": 0.12,
            "eye_x": 0.44,
            "eye_scale": (0.048, 0.018, 0.040),
            "pupil_scale": (0.022, 0.010, 0.024),
            "pupil_offset": 0.016,
            "tail_tuft_scale": (0.055, 0.048, 0.075),
        },
        eye_specs=[
            ("Left", 0.22, 0.70, "EyeLeft"),
            ("Right", -0.22, 0.70, "EyeRight"),
        ],
        tail_specs=((0.36, 0.0, 0.52), (0.52, 0.0, 0.30), 0.038, 0.020),
    )


def create_pack_horse_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Taller pack-horse rig with longer legs and a readable swishing tail."""
    return create_quadruped_rig(
        obj,
        "PackHorseRig",
        (0.0, 0.0, 0.55),
        (0.0, 0.0, 1.12),
        {
            "Neck": ((-0.50, 0.0, 0.98), (-0.95, 0.0, 1.28)),
            "Tail": ((0.68, 0.0, 0.95), (1.02, 0.0, 0.52)),
            "FrontLeftLeg": ((-0.60, 0.22, 0.80), (-0.60, 0.22, 0.10)),
            "FrontRightLeg": ((-0.60, -0.22, 0.80), (-0.60, -0.22, 0.10)),
            "BackLeftLeg": ((0.65, 0.22, 0.80), (0.65, 0.22, 0.10)),
            "BackRightLeg": ((0.65, -0.22, 0.80), (0.65, -0.22, 0.10)),
            "EyeLeft": ((-0.86, 0.34, 1.24), (-0.86, 0.34, 1.34)),
            "EyeRight": ((-0.86, -0.34, 1.24), (-0.86, -0.34, 1.34)),
        },
        {
            "neck_x": -0.45,
            "neck_z": 0.85,
            "tail_x": 0.65,
            "tail_z": 0.70,
            "tail_y": 0.28,
            "leg_z": 0.95,
            "front_leg_x": -0.20,
            "back_leg_x": 0.30,
            "eye_x": 0.88,
            "eye_scale": (0.074, 0.028, 0.062),
            "pupil_scale": (0.032, 0.015, 0.036),
            "pupil_offset": 0.022,
            "tail_tuft_scale": (0.082, 0.070, 0.110),
        },
        eye_specs=[
            ("Left", 0.34, 1.24, "EyeLeft"),
            ("Right", -0.34, 1.24, "EyeRight"),
        ],
        tail_specs=((0.70, 0.0, 0.95), (1.02, 0.0, 0.52), 0.055, 0.028),
    )


def create_pig_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Lean landrace-pig rig preserving the licensed model's cloven-foot anatomy."""
    return create_quadruped_rig(
        obj,
        "PigRig",
        (0.0, 0.0, 0.22),
        (0.0, 0.0, 0.50),
        {
            "Neck": ((-0.34, 0.0, 0.40), (-0.60, 0.0, 0.55)),
            "Tail": ((0.38, 0.0, 0.52), (0.62, 0.0, 0.54)),
            "FrontLeftLeg": ((-0.28, 0.12, 0.32), (-0.28, 0.12, 0.04)),
            "FrontRightLeg": ((-0.28, -0.12, 0.32), (-0.28, -0.12, 0.04)),
            "BackLeftLeg": ((0.28, 0.12, 0.32), (0.28, 0.12, 0.04)),
            "BackRightLeg": ((0.28, -0.12, 0.32), (0.28, -0.12, 0.04)),
            "EyeLeft": ((-0.58, 0.17, 0.52), (-0.58, 0.17, 0.56)),
            "EyeRight": ((-0.58, -0.17, 0.52), (-0.58, -0.17, 0.56)),
        },
        {
            "neck_x": -0.34,
            "neck_z": 0.30,
            "tail_x": 0.38,
            "tail_z": 0.45,
            "tail_y": 0.18,
            "leg_z": 0.35,
            "front_leg_x": -0.12,
            "back_leg_x": 0.12,
            "eye_x": 0.58,
            "eye_scale": (0.026, 0.012, 0.022),
            "pupil_scale": (0.012, 0.007, 0.012),
            "pupil_offset": 0.010,
            "tail_tuft_scale": (0.025, 0.020, 0.025),
        },
        eye_specs=[
            ("Left", 0.17, 0.52, "EyeLeft"),
            ("Right", -0.17, 0.52, "EyeRight"),
        ],
        # The source's small curled tail is retained and weighted to Tail directly.
        tail_specs=None,
    )


def create_livestock_animations(armature: bpy.types.Object) -> None:
    """Author two short looping clips with diagonal walk and independent blinks."""
    armature.animation_data_create()
    pose_bones = armature.pose.bones
    animated_bones = [
        "Body",
        "Neck",
        "Tail",
        "FrontLeftLeg",
        "FrontRightLeg",
        "BackLeftLeg",
        "BackRightLeg",
        "EyeLeft",
        "EyeRight",
    ]
    for name in animated_bones:
        pose_bones[name].rotation_mode = "XYZ"

    def key_pose(
        frame: int,
        rotations: dict[str, tuple[float, float, float]],
        body_lift: float = 0.0,
        eye_open: float = 1.0,
    ) -> None:
        for name in animated_bones:
            bone = pose_bones[name]
            bone.rotation_euler = rotations.get(name, (0.0, 0.0, 0.0))
            bone.keyframe_insert("rotation_euler", frame=frame, group=name)
        pose_bones["Body"].location = (0.0, 0.0, body_lift)
        pose_bones["Body"].keyframe_insert("location", frame=frame, group="Body")
        for name in ["EyeLeft", "EyeRight"]:
            pose_bones[name].scale = (1.0, 1.0, eye_open)
            pose_bones[name].keyframe_insert("scale", frame=frame, group=name)

    idle = bpy.data.actions.new("Idle-loop")
    idle.use_fake_user = True
    armature.animation_data.action = idle
    idle_poses = [
        (1, -0.18, 0.01, 1.0),
        (14, 0.22, -0.025, 1.0),
        (27, 0.08, 0.035, 1.0),
        (38, -0.24, -0.01, 1.0),
        (45, -0.08, 0.01, 0.12),
        (48, 0.02, 0.01, 1.0),
        (61, -0.18, 0.01, 1.0),
    ]
    for frame, tail_swing, neck_pitch, eye_open in idle_poses:
        key_pose(
            frame,
            {"Tail": (tail_swing, 0.0, tail_swing * 0.35), "Neck": (0.0, neck_pitch, 0.0)},
            body_lift=0.008 * math.sin((frame - 1) / 60.0 * math.tau),
            eye_open=eye_open,
        )

    walk = bpy.data.actions.new("Walk-loop")
    walk.use_fake_user = True
    armature.animation_data.action = walk
    walk_poses = [
        (1, 0.34, -0.34, 0.0),
        (8, 0.0, 0.0, 0.025),
        (16, -0.34, 0.34, 0.0),
        (23, 0.0, 0.0, 0.025),
        (31, 0.34, -0.34, 0.0),
    ]
    for frame, diagonal_a, diagonal_b, body_lift in walk_poses:
        key_pose(
            frame,
            {
                "FrontLeftLeg": (0.0, diagonal_a, 0.0),
                "BackRightLeg": (0.0, diagonal_a, 0.0),
                "FrontRightLeg": (0.0, diagonal_b, 0.0),
                "BackLeftLeg": (0.0, diagonal_b, 0.0),
                "Tail": (diagonal_b * 0.55, 0.0, diagonal_b * 0.20),
                "Neck": (0.0, -0.035 + abs(diagonal_a) * 0.06, 0.0),
            },
            body_lift=body_lift,
            eye_open=1.0,
        )

    armature.animation_data.action = idle
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61


def export_glb(
    obj: bpy.types.Object,
    output: Path,
    armature: bpy.types.Object | None = None,
    details: list[bpy.types.Object] | None = None,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    export_objects = [obj]
    if armature is not None:
        export_objects.append(armature)
        export_objects.extend(details or [])
    for export_object in export_objects:
        export_object.select_set(True)
    bpy.context.view_layer.objects.active = armature or obj
    animated = armature is not None
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        # Applying transforms during export can destroy skin bind matrices.
        export_apply=not animated,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_skins=animated,
        export_animations=animated,
        export_animation_mode="ACTIONS" if animated else "ACTIVE_ACTIONS",
        export_force_sampling=animated,
        export_def_bones=True,
    )


def build(name: str, spec: dict) -> dict:
    source: Path = spec["source"]
    if not source.exists():
        raise FileNotFoundError(f"Missing approved candidate: {source}")
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    obj = flatten_imported_hierarchy()
    raw = topology(obj)
    discarded_before = remove_tiny_islands(obj, 0.0015)
    if spec.get("source_long_axis") == "y":
        # Keep authored head/tail orientation stable: source -Y becomes runtime -X.
        obj.rotation_euler.z = -math.pi * 0.5
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    else:
        align_long_axis(obj)
    if not spec.get("preserve_topology", False):
        rebuild_surface(obj, spec["voxel_divisor"], spec["triangles"])
    else:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    # Pack-horse scans retain tack islands; discard more aggressively before rigging.
    if name == "pack_horse":
        remove_tiny_islands(obj, 0.0025)
    normalize_dimensions(obj, spec["dimensions_m"])
    make_uv(obj)
    albedo = create_albedo(name, spec)
    assign_material(obj, name, albedo)
    production = topology(obj)
    armature: bpy.types.Object | None = None
    details: list[bpy.types.Object] = []
    if spec.get("animated", False):
        rig_builder = {
            "cattle": create_cattle_rig,
            "pig": create_pig_rig,
            "sheep": create_sheep_rig,
            "pack_horse": create_pack_horse_rig,
        }.get(name, create_cattle_rig)
        armature, details = rig_builder(obj)
    output: Path = spec["output"]
    export_glb(obj, output, armature, details)

    report = {
        "asset_id": f"creature.{name}",
        "route": spec.get("route", "leonardo_reference_to_hunyuan3d_to_blender_cleanup"),
        "source_license": spec.get("source_license", "project-authored AI generation"),
        "anatomy_decision": spec.get("anatomy_decision", "approved_reference_silhouette"),
        "scale_basis": spec.get("scale_basis", "brief metric dimensions"),
        "source": str(source.relative_to(ROOT)),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output": str(output.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "discarded_raw_noise_components": discarded_before,
        "metric_dimensions_m_y_up": list(spec["dimensions_m"]),
        "ground_min_y": 0.0,
        "uv_sets": len(obj.data.uv_layers),
        "materials": len(obj.data.materials),
        "texture_size": TEXTURE_SIZE,
        "static_prop": True,
        "rigged": armature is not None,
        "animations": ["Idle-loop", "Walk-loop"] if armature is not None else [],
        "animated_parts": ["legs", "neck", "tail", "eyes"] if armature is not None else [],
    }
    report_path = REPORTS / f"{name}_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(
        "ASSET_METRICS="
        + json.dumps(
            {
                "asset": name,
                "triangles": production["triangles"],
                "components": production["components"],
                "dimensions_m": spec["dimensions_m"],
                "sha256": report["output_sha256"],
            },
            separators=(",", ":"),
        )
    )
    return report


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    names = selected or list(SPECS)
    unknown = sorted(set(names) - set(SPECS))
    if unknown:
        raise ValueError(f"Unknown animal specs: {unknown}")
    for name in names:
        build(name, SPECS[name])


if __name__ == "__main__":
    main()
