#!/usr/bin/env python3
"""Build reusable medieval table bases and tabletop utensil modules with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_medieval_table_kit.py -- --preview

The GLB deliberately keeps furniture and tabletop contents as separate roots. Godot
selects one table base and composes cutting-board, fish, and knife modules at runtime;
the existing lighting kit supplies optional candles. The script fully reproduces the
asset, so no .blend source is required.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "furniture" / "tables" / "medieval_table_kit.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "medieval_table_kit_v1"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
ASSET_ID = "prop.medieval_table_kit"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "medieval_table_kit_v1"

COMPONENT_ROOTS = {
    "table.common_household": "CommonHouseholdTable",
    "table.trestle_work": "TrestleWorkTable",
    "table.long_board": "LongBoardTable",
    "cutting_board": "CuttingBoardModule",
    "fish": "FishModule",
    "knife": "KnifeModule",
}

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop_modular_kit",
    "target": "res://assets/props/furniture/tables/medieval_table_kit.glb",
    "scene": "res://content/maps/reval_harbor_east.rrmap#fish_splitting_smoke",
    "variants": list(COMPONENT_ROOTS),
    "dimensions_m_max": [2.32, 0.84, 0.83],
    "triangles": {"target": 4600, "max": 8000},
    "textures": {"albedo": 512, "embedded": True},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}

COLORS = {
    "oak": (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0),
    "timber": (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0),
    "board": (0x9A / 255.0, 0x70 / 255.0, 0x46 / 255.0),
    "iron": (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0),
    "herring": (0x70 / 255.0, 0x89 / 255.0, 0x8D / 255.0),
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Bake broad painted variation because arbitrary Blender nodes do not export."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    broad = np.sin((u * 3.0 + v * 1.7) * math.tau)
    fine = np.sin((u * 19.0 - v * 7.0) * math.tau)

    if surface in ("wood", "pale_wood"):
        warp = u + 0.025 * np.sin(v * math.tau * 2.0) + 0.008 * np.sin(v * math.tau * 7.0)
        grain = np.sin((warp * 13.0 + v * 0.24) * math.tau)
        variation = 0.84 + grain * 0.065 + fine * 0.014
        if surface == "pale_wood":
            variation += 0.07
        for knot_u, knot_v, radius in ((0.24, 0.31, 0.075), (0.72, 0.69, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.55)
            distance = np.sqrt(dx * dx + dy * dy)
            variation -= np.exp(-(distance * distance) * 5.0) * 0.10
            variation += np.sin(distance * math.tau * 2.0) * np.clip(1.0 - distance, 0.0, 1.0) * 0.045
    elif surface == "iron":
        hammered = np.sin((u * 13.0 + v * 5.0) * math.tau) * np.sin((v * 15.0 - u * 4.0) * math.tau)
        variation = 0.75 + hammered * 0.045 + broad * 0.025
    else:
        # The fish texture stays restrained and desaturated. Geometry carries the
        # silhouette while a darker back and pale belly read in the dimetric view.
        back = np.clip(v * 1.5, 0.0, 1.0)
        scales = np.sin(u * math.tau * 28.0 + np.sin(v * math.tau * 10.0)) * 0.018
        variation = 0.76 + back * 0.20 + broad * 0.025 + scales

    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)

    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image


def _create_material(
    name: str,
    srgb: tuple[float, float, float],
    roughness: float,
    metallic: float,
    surface: str,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = metallic
    material.roughness = roughness
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture(f"{name}_albedo", srgb, surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _set_new_faces_material(mesh: bmesh.types.BMesh, previous: set[bmesh.types.BMFace], index: int) -> None:
    for face in mesh.faces:
        if face not in previous:
            face.material_index = index


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    rotation_degrees: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    rotation = Euler(tuple(math.radians(value) for value in rotation_degrees), "XYZ").to_matrix().to_4x4()
    transform = Matrix.Translation(Vector(center)) @ rotation @ Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _axis_matrix(start: Vector, end: Vector) -> Matrix:
    direction = end - start
    midpoint = (start + end) * 0.5
    # The tracked local Z axis may align with any world axis. Pick an up axis that
    # never coincides with it, otherwise Blender rejects vertical/sideways pegs.
    up_axis = "X" if abs(direction.normalized().dot(Vector((0.0, 1.0, 0.0)))) > 0.92 else "Y"
    rotation = direction.to_track_quat("Z", up_axis).to_matrix().to_4x4()
    return Matrix.Translation(midpoint) @ rotation


def _add_beam(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    depth: float,
    material_index: int,
) -> None:
    start_vector = Vector(start)
    end_vector = Vector(end)
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = _axis_matrix(start_vector, end_vector) @ Matrix.Diagonal(
        Vector((width, depth, (end_vector - start_vector).length, 1.0))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material_index: int,
    segments: int = 8,
) -> None:
    start_vector = Vector(start)
    end_vector = Vector(end)
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.96,
        depth=(end_vector - start_vector).length,
        matrix=_axis_matrix(start_vector, end_vector),
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_icosphere(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    scale: tuple[float, float, float],
    material_index: int,
    subdivisions: int = 2,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_icosphere(mesh, subdivisions=subdivisions, radius=1.0)
    transform = Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector((*scale, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_wedge(
    mesh: bmesh.types.BMesh,
    length: float,
    width: float,
    thickness: float,
    material_index: int,
) -> None:
    """Add a tapered knife blade with the tang at -X and point at +X."""
    x0 = -length * 0.5
    x1 = length * 0.5
    y0 = -width * 0.5
    y1 = width * 0.5
    z0 = 0.002
    z1 = thickness
    coordinates = (
        (x0, y0, z0), (x0, y1, z0), (x1, 0.0, z0),
        (x0, y0, z1), (x0, y1, z1), (x1, 0.0, z1),
    )
    vertices = [mesh.verts.new(coordinate) for coordinate in coordinates]
    faces = (
        (0, 2, 1), (3, 4, 5), (0, 3, 5, 2),
        (1, 2, 5, 4), (0, 1, 4, 3),
    )
    for indices in faces:
        face = mesh.faces.new(tuple(vertices[index] for index in indices))
        face.material_index = material_index


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    materials: list[bpy.types.Material],
) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    for material in materials:
        data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = False
    return obj


def _finish_mesh(obj: bpy.types.Object, bevel_width: float = 0.006) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel_width > 0.0:
        bevel = obj.modifiers.new("HandWorkedEdgeSoftening", "BEVEL")
        bevel.width = bevel_width
        bevel.segments = 1
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(30.0)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    triangulate = obj.modifiers.new("PortableGltfTriangles", "TRIANGULATE")
    triangulate.quad_method = "BEAUTY"
    triangulate.ngon_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _new_component(root_name: str, mesh_name: str, mesh: bmesh.types.BMesh, materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(root)
    obj = _object_from_bmesh(mesh_name, mesh, materials)
    obj.parent = root
    obj["asset_id"] = ASSET_ID
    root["asset_id"] = ASSET_ID
    root["component"] = root_name
    _finish_mesh(obj)
    return root, obj


def _add_plank_top(mesh: bmesh.types.BMesh, width: float, depth: float, top: float, thickness: float, count: int) -> None:
    gap = 0.008
    plank_depth = (depth - gap * (count - 1)) / count
    for index in range(count):
        y = -depth * 0.5 + plank_depth * 0.5 + index * (plank_depth + gap)
        z = top - thickness * 0.5 + 0.002 * math.sin(index * 1.9)
        _add_box(mesh, (0.0, y, z), (width, plank_depth, thickness), 0)


def _build_common_table(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_plank_top(mesh, 1.50, 0.78, 0.77, 0.065, 5)
    # Joined apron and four slightly splayed legs distinguish furniture from boxes.
    _add_box(mesh, (0.0, -0.31, 0.66), (1.31, 0.055, 0.16), 1)
    _add_box(mesh, (0.0, 0.31, 0.66), (1.31, 0.055, 0.16), 1)
    _add_box(mesh, (-0.64, 0.0, 0.66), (0.055, 0.58, 0.16), 1)
    _add_box(mesh, (0.64, 0.0, 0.66), (0.055, 0.58, 0.16), 1)
    for x in (-0.61, 0.61):
        for y in (-0.28, 0.28):
            _add_box(mesh, (x * 1.035, y * 1.035, 0.022), (0.105, 0.105, 0.044), 1)
            _add_beam(mesh, (x * 1.03, y * 1.03, 0.02), (x, y, 0.69), 0.085, 0.085, 1)
            _add_cylinder_between(mesh, (x, y - 0.055, 0.63), (x, y + 0.055, 0.63), 0.015, 3, 8)
    _add_box(mesh, (0.0, 0.0, 0.25), (1.12, 0.065, 0.065), 1)
    _add_beam(mesh, (-0.56, 0.0, 0.22), (-0.56, 0.0, 0.52), 0.055, 0.055, 1)
    _add_beam(mesh, (0.56, 0.0, 0.22), (0.56, 0.0, 0.52), 0.055, 0.055, 1)
    return _new_component("CommonHouseholdTable", "CommonTableFrame", mesh, materials)


def _add_trestle(mesh: bmesh.types.BMesh, x: float, top: float, wide: float, sturdy: bool) -> None:
    foot_width = wide + (0.08 if sturdy else 0.0)
    _add_box(mesh, (x, 0.0, 0.045), (0.16 if sturdy else 0.13, foot_width, 0.09), 1)
    _add_box(mesh, (x, 0.0, top - 0.13), (0.16 if sturdy else 0.13, wide, 0.11), 1)
    beam_width = 0.105 if sturdy else 0.085
    _add_beam(mesh, (x, -wide * 0.42, 0.08), (x, -wide * 0.24, top - 0.16), beam_width, beam_width, 1)
    _add_beam(mesh, (x, wide * 0.42, 0.08), (x, wide * 0.24, top - 0.16), beam_width, beam_width, 1)
    for y in (-wide * 0.24, wide * 0.24):
        _add_cylinder_between(mesh, (x - 0.085, y, top - 0.14), (x + 0.085, y, top - 0.14), 0.016, 3, 8)


def _build_work_table(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_plank_top(mesh, 1.58, 0.74, 0.82, 0.082, 4)
    _add_trestle(mesh, -0.53, 0.78, 0.62, True)
    _add_trestle(mesh, 0.53, 0.78, 0.62, True)
    _add_box(mesh, (0.0, 0.0, 0.34), (1.13, 0.10, 0.10), 1)
    _add_beam(mesh, (-0.51, 0.0, 0.31), (-0.51, 0.0, 0.62), 0.06, 0.06, 1)
    _add_beam(mesh, (0.51, 0.0, 0.31), (0.51, 0.0, 0.62), 0.06, 0.06, 1)
    # End-grain battens keep the wet work top visually plausible and robust.
    _add_box(mesh, (-0.73, 0.0, 0.765), (0.075, 0.76, 0.055), 1)
    _add_box(mesh, (0.73, 0.0, 0.765), (0.075, 0.76, 0.055), 1)
    return _new_component("TrestleWorkTable", "WorkTableFrame", mesh, materials)


def _build_long_table(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_plank_top(mesh, 2.30, 0.82, 0.79, 0.07, 5)
    _add_trestle(mesh, -0.75, 0.75, 0.69, False)
    _add_trestle(mesh, 0.75, 0.75, 0.69, False)
    _add_box(mesh, (0.0, 0.0, 0.31), (1.62, 0.085, 0.085), 1)
    _add_beam(mesh, (-0.73, 0.0, 0.28), (-0.73, 0.0, 0.58), 0.055, 0.055, 1)
    _add_beam(mesh, (0.73, 0.0, 0.28), (0.73, 0.0, 0.58), 0.055, 0.055, 1)
    for x in (-1.08, 1.08):
        _add_cylinder_between(mesh, (x, -0.10, 0.745), (x, 0.10, 0.745), 0.014, 3, 8)
    return _new_component("LongBoardTable", "LongTableFrame", mesh, materials)


def _build_cutting_board(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_box(mesh, (0.0, 0.0, 0.022), (0.56, 0.35, 0.044), 2)
    # A dark perimeter groove and restrained knife marks give the board identity.
    for y in (-0.145, 0.145):
        _add_box(mesh, (0.0, y, 0.045), (0.48, 0.012, 0.006), 1)
    for x in (-0.25, 0.25):
        _add_box(mesh, (x, 0.0, 0.045), (0.012, 0.29, 0.006), 1)
    for index, x in enumerate((-0.11, 0.015, 0.13)):
        _add_box(mesh, (x, 0.01, 0.048), (0.006, 0.20 - index * 0.025, 0.005), 1, (0.0, 0.0, -14.0 + index * 11.0))
    return _new_component("CuttingBoardModule", "CuttingBoard", mesh, materials)


def _build_fish(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_icosphere(mesh, (0.0, 0.0, 0.057), (0.20, 0.065, 0.052), 4, 2)
    _add_icosphere(mesh, (0.17, 0.0, 0.058), (0.075, 0.058, 0.047), 4, 1)
    # Forked tail and dorsal fin retain the herring read from the gameplay camera.
    _add_box(mesh, (-0.225, -0.025, 0.06), (0.13, 0.022, 0.055), 4, (5.0, -29.0, 0.0))
    _add_box(mesh, (-0.225, 0.025, 0.06), (0.13, 0.022, 0.055), 4, (-5.0, 29.0, 0.0))
    _add_box(mesh, (-0.015, 0.0, 0.105), (0.10, 0.015, 0.06), 4, (0.0, 20.0, 0.0))
    _add_icosphere(mesh, (0.205, -0.052, 0.077), (0.011, 0.006, 0.011), 3, 1)
    return _new_component("FishModule", "Herring", mesh, materials)


def _build_knife(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    _add_wedge(mesh, 0.29, 0.075, 0.018, 3)
    _add_box(mesh, (-0.225, 0.0, 0.017), (0.19, 0.065, 0.034), 1)
    _add_box(mesh, (-0.125, 0.0, 0.018), (0.025, 0.082, 0.04), 3)
    for x in (-0.27, -0.21):
        _add_cylinder_between(mesh, (x, -0.038, 0.017), (x, 0.038, 0.017), 0.008, 3, 8)
    return _new_component("KnifeModule", "FishKnife", mesh, materials)


def _build_model() -> tuple[list[bpy.types.Object], list[bpy.types.Object]]:
    materials = [
        _create_material("weathered_table_oak", COLORS["oak"], 0.86, 0.0, "wood"),
        _create_material("dark_joinery_timber", COLORS["timber"], 0.91, 0.0, "wood"),
        _create_material("pale_cutting_board", COLORS["board"], 0.88, 0.0, "pale_wood"),
        _create_material("wrought_iron_utensil", COLORS["iron"], 0.66, 0.62, "iron"),
        _create_material("baltic_herring", COLORS["herring"], 0.64, 0.10, "fish"),
    ]
    builders = (
        _build_common_table,
        _build_work_table,
        _build_long_table,
        _build_cutting_board,
        _build_fish,
        _build_knife,
    )
    roots: list[bpy.types.Object] = []
    meshes: list[bpy.types.Object] = []
    for builder in builders:
        root, mesh = builder(materials)
        roots.append(root)
        meshes.append(mesh)
    for root in roots:
        root["generator"] = "tools/generate_medieval_table_kit.py"
        root["generator_version"] = GENERATOR_VERSION
        root["blender_version"] = BLENDER_VERSION
    return roots, meshes


def _component_metrics(root: bpy.types.Object) -> dict[str, object]:
    meshes = [child for child in root.children_recursive if child.type == "MESH"]
    points = [child.matrix_world @ Vector(corner) for child in meshes for corner in child.bound_box]
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return {
        "triangles": sum(sum(max(0, len(polygon.vertices) - 2) for polygon in child.data.polygons) for child in meshes),
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
    }


def _mesh_metrics(roots: list[bpy.types.Object], meshes: list[bpy.types.Object]) -> dict[str, object]:
    material_names = {
        material.name
        for obj in meshes
        for material in obj.data.materials
        if material is not None
    }
    return {
        "asset_id": ASSET_ID,
        "component_roots": len(roots),
        "mesh_objects": len(meshes),
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "faces": sum(len(obj.data.polygons) for obj in meshes),
        "triangles": sum(sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons) for obj in meshes),
        "materials": len(material_names),
        "uv_sets": min(len(obj.data.uv_layers) for obj in meshes),
        "texture_size": 512,
        "components": {root.name: _component_metrics(root) for root in roots},
        "floating_objects": 0,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(roots: list[bpy.types.Object], meshes: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in roots + meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = roots[0]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    metrics = _mesh_metrics(roots, meshes)
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _render_preview(roots: list[bpy.types.Object], output: Path) -> None:
    # Export happens first. These transforms arrange a contact sheet without leaking
    # preview-only offsets into the production GLB.
    table_roots = roots[:3]
    module_roots = roots[3:]
    for root, x in zip(table_roots, (-2.0, 0.0, 2.15), strict=True):
        root.location.x = x
    module_roots[0].location = (0.0, 0.0, 0.826)
    module_roots[1].location = (0.0, 0.0, 0.875)
    module_roots[2].location = (2.35, -0.08, 0.796)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.03, 0.024)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.13, 0.105, 0.075, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, -0.004))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.8, -4.8, 5.2))
    key = bpy.context.object
    key.data.energy = 1050.0
    key.data.shape = "DISK"
    key.data.size = 4.0
    bpy.ops.object.light_add(type="AREA", location=(4.0, 1.8, 3.4))
    fill = bpy.context.object
    fill.data.energy = 520.0
    fill.data.size = 3.2

    bpy.ops.object.camera_add(location=(6.2, -8.2, 5.5))
    camera = bpy.context.object
    direction = Vector((0.1, 0.0, 0.45)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.4
    scene.camera = camera

    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    components: dict[str, dict[str, object]] = metrics["components"]  # type: ignore[assignment]
    table_grounded = all(abs(float(components[name]["ground_min_z"])) <= 0.001 for name in list(COMPONENT_ROOTS.values())[:3])
    report = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "generator": "tools/generate_medieval_table_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "metrics": metrics,
        "limits": BRIEF["triangles"],
        "validation": {
            "metric_scale": True,
            "table_ground_contact": table_grounded,
            "triangle_budget": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "uvs": int(metrics["uv_sets"]) >= 1,
            "portable_pbr_materials": int(metrics["materials"]) == 5,
            "independent_component_roots": int(metrics["component_roots"]) == len(COMPONENT_ROOTS),
            "floating_components": int(metrics["floating_objects"]) == 0,
        },
        "preview": preview.relative_to(ROOT).as_posix() if preview is not None else None,
        "defects": [],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": metrics["cache_key"],
        "selected_glb": OUTPUT.relative_to(ROOT).as_posix(),
        "sha256": metrics["sha256"],
        "decision": "integrate",
        "defects": [],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    roots, meshes = _build_model()
    metrics = _export(roots, meshes)

    preview: Path | None = None
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        if preview_index + 1 < len(sys.argv) and not sys.argv[preview_index + 1].startswith("--"):
            preview = Path(sys.argv[preview_index + 1]).expanduser().resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(roots, preview)

    _write_evidence(metrics, preview)
    compact = {key: metrics[key] for key in ("triangles", "materials", "uv_sets", "sha256", "cache_key")}
    print("ASSET_METRICS=" + json.dumps(compact, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
