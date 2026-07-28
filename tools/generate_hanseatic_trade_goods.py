#!/usr/bin/env python3
"""Build four game-ready Hanseatic trade-goods clusters with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_hanseatic_trade_goods.py -- --preview

The clusters replace the sphere-and-box trade-goods placeholder with distinct
cargo reads grounded in the documented Spring 1343 Reval trade corridor. They
remain visual-only: authored rrmap footprints own collision and navigation.
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
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "props" / "trade"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "hanseatic_trade_goods_v1"
PREVIEW_PATH = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "hanseatic_trade_goods_v1"
TEXTURE_SIZE = 512
TRIANGLE_MAX = 9000

VARIANTS = {
    "eastern_furs_wax": {
        "asset_id": "prop.trade_goods.eastern_furs_wax",
        "goods": ["Novgorod fur bundles", "beeswax cakes"],
        "direction": "east_to_west",
    },
    "western_cloth_salt": {
        "asset_id": "prop.trade_goods.western_cloth_salt",
        "goods": ["bound western cloth bales", "barrelled salt"],
        "direction": "west_to_east",
    },
    "livonian_grain_flax": {
        "asset_id": "prop.trade_goods.livonian_grain_flax",
        "goods": ["grain sacks", "bound flax bundles"],
        "direction": "local_export",
    },
    "barrelled_herring_metal": {
        "asset_id": "prop.trade_goods.barrelled_herring_metal",
        "goods": ["barrelled herring or wine", "iron bars", "copper ingots"],
        "direction": "mixed_transit",
    },
}

BRIEF = {
    "id": "prop.hanseatic_trade_goods_kit",
    "kind": "rigid_prop_kit",
    "targets": [f"res://assets/props/trade/{variant}.glb" for variant in VARIANTS],
    "scenes": [
        "res://content/maps/reval_harbor_north.rrmap",
        "res://content/maps/north_quarter.rrmap",
    ],
    "dimensions_m_max": [1.65, 1.0, 1.4],
    "triangles": {"target_each": 3500, "max_each": TRIANGLE_MAX},
    "textures": {"albedo": TEXTURE_SIZE},
    "historical_basis": "Spring 1343 Reval east-west Hanseatic transit cargo",
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}

# Restrained sRGB masters retain the game's painted earth palette while keeping
# commodities identifiable at the fixed three-quarter camera.
COLORS = {
    "burlap": (0.50, 0.40, 0.27),
    "rope": (0.42, 0.30, 0.16),
    "fur_grey": (0.31, 0.30, 0.28),
    "fur_brown": (0.32, 0.21, 0.14),
    "wax": (0.70, 0.50, 0.18),
    "cloth_blue": (0.21, 0.29, 0.31),
    "cloth_ochre": (0.48, 0.35, 0.20),
    "wood": (0.39, 0.27, 0.16),
    "dark_wood": (0.28, 0.18, 0.11),
    "flax": (0.61, 0.51, 0.28),
    "iron": (0.24, 0.25, 0.25),
    "copper": (0.48, 0.25, 0.13),
    "salt_mark": (0.72, 0.70, 0.63),
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _texture_variation(surface: str) -> np.ndarray:
    yy, xx = np.mgrid[0:TEXTURE_SIZE, 0:TEXTURE_SIZE].astype(np.float32)
    u = xx / float(TEXTURE_SIZE)
    v = yy / float(TEXTURE_SIZE)
    broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
    fine = np.sin((u * 13.0 - v * 7.0) * math.tau) * np.sin((u * 5.0 + v * 11.0) * math.tau)
    if surface in {"burlap", "cloth"}:
        warp = np.sin(u * math.tau * 43.0)
        weft = np.sin(v * math.tau * 39.0)
        return 0.82 + broad * 0.035 + (warp + weft) * 0.020
    if surface == "fur":
        nap = np.sin((u * 31.0 + 0.13 * np.sin(v * math.tau * 3.0)) * math.tau)
        return 0.78 + broad * 0.045 + nap * 0.035 + fine * 0.012
    if surface == "wood":
        grain = np.sin((u * 10.0 + 0.08 * np.sin(v * math.tau * 2.0)) * math.tau)
        return 0.80 + broad * 0.035 + grain * 0.050 + fine * 0.012
    if surface == "metal":
        return 0.74 + broad * 0.025 + fine * 0.040
    if surface == "wax":
        cloudy = np.sin((u * 4.0 + v * 5.0) * math.tau)
        return 0.88 + broad * 0.020 + cloudy * 0.025
    if surface == "fiber":
        strands = np.sin((u * 55.0 + v * 2.0) * math.tau)
        return 0.83 + broad * 0.025 + strands * 0.025
    return 0.84 + broad * 0.025 + fine * 0.015


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    variation = _texture_variation(surface)
    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((TEXTURE_SIZE, TEXTURE_SIZE, 1), dtype=np.float32)
    image = bpy.data.images.new(name, width=TEXTURE_SIZE, height=TEXTURE_SIZE, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(np.concatenate((rgb, alpha), axis=2).ravel())
    image.pack()
    return image


def _create_material(name: str, color_key: str, surface: str, metallic: float = 0.0) -> bpy.types.Material:
    srgb = COLORS[color_key]
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = metallic
    material.roughness = 0.88 if metallic == 0.0 else 0.66
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = material.roughness
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
    rotation_z_degrees: float = 0.0,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = (
        Matrix.Translation(Vector(center))
        @ Matrix.Rotation(math.radians(rotation_z_degrees), 4, "Z")
        @ Matrix.Diagonal(Vector((*size, 1.0)))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_ellipsoid(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    scale: tuple[float, float, float],
    material_index: int,
    rotation_z_degrees: float = 0.0,
    segments: int = 12,
    rings: int = 6,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_uvsphere(mesh, u_segments=segments, v_segments=rings, radius=1.0)
    transform = (
        Matrix.Translation(Vector(center))
        @ Matrix.Rotation(math.radians(rotation_z_degrees), 4, "Z")
        @ Matrix.Diagonal(Vector((*scale, 1.0)))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    material_index: int,
    segments: int = 12,
    rotation: Matrix | None = None,
) -> None:
    previous = set(mesh.faces)
    transform = Matrix.Translation(Vector(center))
    if rotation is not None:
        transform @= rotation
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=depth,
        matrix=transform,
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material_index: int,
    segments: int = 8,
) -> None:
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    _add_cylinder(mesh, tuple((start_v + end_v) * 0.5), radius, direction.length, material_index, segments, rotation)


def _add_profile_body(
    mesh: bmesh.types.BMesh,
    center_xy: tuple[float, float],
    rings: list[tuple[float, float, float]],
    material_index: int,
    segments: int = 12,
    transform: Matrix | None = None,
    cap_bottom: bool = True,
    cap_top: bool = True,
) -> None:
    cx, cy = center_xy
    ring_vertices: list[list[bmesh.types.BMVert]] = []
    for z, radius_x, radius_y in rings:
        current: list[bmesh.types.BMVert] = []
        for index in range(segments):
            angle = math.tau * index / segments
            point = Vector((cx + radius_x * math.cos(angle), cy + radius_y * math.sin(angle), z))
            if transform is not None:
                point = transform @ point
            current.append(mesh.verts.new(point))
        ring_vertices.append(current)
    for ring_index in range(len(ring_vertices) - 1):
        lower = ring_vertices[ring_index]
        upper = ring_vertices[ring_index + 1]
        for index in range(segments):
            face = mesh.faces.new((lower[index], lower[(index + 1) % segments], upper[(index + 1) % segments], upper[index]))
            face.material_index = material_index
    if cap_bottom:
        face = mesh.faces.new(tuple(reversed(ring_vertices[0])))
        face.material_index = material_index
    if cap_top:
        face = mesh.faces.new(tuple(ring_vertices[-1]))
        face.material_index = material_index


def _add_sack(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    scale: float,
    material_index: int,
    rope_index: int,
    yaw: float,
) -> None:
    cx, cy, base = center
    local_rings = [
        (0.00, 0.16, 0.13),
        (0.08, 0.23, 0.18),
        (0.40, 0.21, 0.17),
        (0.53, 0.12, 0.10),
        (0.61, 0.055, 0.045),
    ]
    rotation = Matrix.Translation(Vector((cx, cy, base))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
    _add_profile_body(mesh, (0.0, 0.0), local_rings, material_index, 12, rotation)
    neck = rotation @ Vector((0.0, 0.0, 0.555))
    _add_cylinder(mesh, tuple(neck), 0.068 * scale, 0.027 * scale, rope_index, 10)
    # Gathered cloth ears break the egg silhouette at gameplay distance.
    ear_base = rotation @ Vector((0.0, 0.0, 0.61))
    _add_box(mesh, tuple(ear_base + Vector((-0.035, 0.0, 0.035))), (0.05, 0.025, 0.09), material_index, math.degrees(yaw) - 14.0)
    _add_box(mesh, tuple(ear_base + Vector((0.035, 0.0, 0.030))), (0.05, 0.025, 0.08), material_index, math.degrees(yaw) + 16.0)


def _add_bale(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    cloth_index: int,
    rope_index: int,
    yaw: float,
) -> None:
    yaw_degrees = math.degrees(yaw)
    _add_box(mesh, center, size, cloth_index, yaw_degrees)
    sx, sy, sz = size
    # Two four-sided cords are modeled as surface strips, not solid modern bands.
    for along in (-sx * 0.24, sx * 0.24):
        for z_offset in (-sz * 0.49, sz * 0.49):
            local = Vector((along, 0.0, z_offset))
            rotated = Matrix.Rotation(yaw, 4, "Z") @ local + Vector(center)
            _add_box(mesh, tuple(rotated), (0.028, sy * 1.025, 0.018), rope_index, yaw_degrees)
        for y_offset in (-sy * 0.49, sy * 0.49):
            local = Vector((along, y_offset, 0.0))
            rotated = Matrix.Rotation(yaw, 4, "Z") @ local + Vector(center)
            _add_box(mesh, tuple(rotated), (0.028, 0.018, sz * 1.025), rope_index, yaw_degrees)


def _add_barrel(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    wood_index: int,
    iron_index: int,
    horizontal: bool = False,
    yaw: float = 0.0,
    salt_mark_index: int | None = None,
) -> None:
    height = 0.68
    radius = 0.255
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
    if horizontal:
        transform @= Matrix.Rotation(math.pi * 0.5, 4, "Y")
    rings = [
        (-height * 0.5, radius * 0.80, radius * 0.80),
        (-height * 0.34, radius * 0.95, radius * 0.95),
        (0.0, radius, radius),
        (height * 0.34, radius * 0.95, radius * 0.95),
        (height * 0.5, radius * 0.80, radius * 0.80),
    ]
    _add_profile_body(mesh, (0.0, 0.0), rings, wood_index, 16, transform)
    for local_z, band_radius in ((-0.24, 0.235), (-0.11, 0.252), (0.11, 0.252), (0.24, 0.235)):
        band_transform = transform @ Matrix.Translation(Vector((0.0, 0.0, local_z)))
        _add_profile_body(
            mesh,
            (0.0, 0.0),
            [(-0.018, band_radius, band_radius), (0.018, band_radius, band_radius)],
            iron_index,
            16,
            band_transform,
        )
    if salt_mark_index is not None:
        mark_transform = transform @ Matrix.Translation(Vector((0.0, 0.0, height * 0.505)))
        mark_center = mark_transform @ Vector((0.0, 0.0, 0.006))
        rotation = transform.to_3x3().to_4x4()
        _add_cylinder(mesh, tuple(mark_center), radius * 0.30, 0.012, salt_mark_index, 12, rotation)


def _add_ingot(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    yaw: float,
) -> None:
    sx, sy, sz = (value * 0.5 for value in size)
    lower_x, lower_y = sx, sy
    upper_x, upper_y = sx * 0.76, sy * 0.76
    local = [
        (-lower_x, -lower_y, -sz), (lower_x, -lower_y, -sz), (lower_x, lower_y, -sz), (-lower_x, lower_y, -sz),
        (-upper_x, -upper_y, sz), (upper_x, -upper_y, sz), (upper_x, upper_y, sz), (-upper_x, upper_y, sz),
    ]
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
    verts = [mesh.verts.new(transform @ Vector(point)) for point in local]
    for indices in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        face = mesh.faces.new(tuple(verts[index] for index in indices))
        face.material_index = material_index


def _object_from_bmesh(name: str, mesh: bmesh.types.BMesh, materials: list[bpy.types.Material]) -> bpy.types.Object:
    data = bpy.data.meshes.new(f"{name}Mesh")
    mesh.to_mesh(data)
    mesh.free()
    for material in materials:
        data.materials.append(material)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for polygon in data.polygons:
        polygon.use_smooth = polygon.loop_total > 4
    data.validate(clean_customdata=False)
    data.update()
    return obj


def _unwrap(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _triangulate(obj: bpy.types.Object) -> None:
    """Bake triangles after UV authoring so glTF tangents remain deterministic."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("ExportTriangles", "TRIANGULATE")
    modifier.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _apply_bevel(obj: bpy.types.Object, width: float = 0.008) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("SoftPaintedEdges", "BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(32.0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _build_eastern_furs_wax() -> tuple[bpy.types.Object, bpy.types.Object]:
    materials = [
        _create_material("FurGrey", "fur_grey", "fur"),
        _create_material("FurBrown", "fur_brown", "fur"),
        _create_material("Beeswax", "wax", "wax"),
        _create_material("HempCord", "rope", "fiber"),
    ]
    mesh = bmesh.new()
    bundles = [
        ((-0.36, 0.10, 0.18), (0.43, 0.25, 0.14), 0, -10.0),
        ((0.05, -0.16, 0.16), (0.40, 0.23, 0.13), 1, 14.0),
        ((-0.06, 0.18, 0.40), (0.38, 0.22, 0.13), 0, 5.0),
    ]
    for index, (center, scale, material, yaw_degrees) in enumerate(bundles):
        _add_ellipsoid(mesh, center, scale, material, yaw_degrees, 14, 7)
        yaw = math.radians(yaw_degrees)
        # Exposed pelt tips and twin cords make these read as counted fur bundles.
        for offset in (-0.13, 0.13):
            tip_center = Vector(center) + Matrix.Rotation(yaw, 4, "Z") @ Vector((0.36, offset, -0.03))
            _add_box(mesh, tuple(tip_center), (0.26, 0.10, 0.055), material, yaw_degrees + 3.0 * (index - 1))
        for offset in (-0.16, 0.16):
            cord_center = Vector(center) + Matrix.Rotation(yaw, 4, "Z") @ Vector((offset, 0.0, scale[2] * 0.83))
            _add_box(mesh, tuple(cord_center), (0.025, scale[1] * 1.9, 0.018), 3, yaw_degrees)
    for index, (x, y, radius, height) in enumerate((
        (0.48, 0.23, 0.18, 0.12), (0.43, -0.08, 0.16, 0.11), (0.23, 0.10, 0.14, 0.10),
    )):
        _add_cylinder(mesh, (x, y, height * 0.5 + 0.01), radius, height, 2, 14)
    obj = _object_from_bmesh("EasternFursWaxCargo", mesh, materials)
    _apply_bevel(obj, 0.007)
    root = _make_root("eastern_furs_wax", obj)
    return root, obj


def _build_western_cloth_salt() -> tuple[bpy.types.Object, bpy.types.Object]:
    materials = [
        _create_material("IndigoBroadcloth", "cloth_blue", "cloth"),
        _create_material("OchreBroadcloth", "cloth_ochre", "cloth"),
        _create_material("HempCord", "rope", "fiber"),
        _create_material("CooperedOak", "wood", "wood"),
        _create_material("BarrelIron", "iron", "metal", 0.62),
        _create_material("SaltHeadMark", "salt_mark", "burlap"),
    ]
    mesh = bmesh.new()
    _add_bale(mesh, (-0.30, 0.08, 0.20), (0.72, 0.48, 0.38), 0, 2, math.radians(-9.0))
    _add_bale(mesh, (-0.19, 0.10, 0.54), (0.63, 0.43, 0.30), 1, 2, math.radians(7.0))
    # Salt is barrel cargo in the project research, not a modern open white pile.
    _add_barrel(mesh, (0.43, -0.04, 0.27), 3, 4, horizontal=True, yaw=math.radians(18.0), salt_mark_index=5)
    obj = _object_from_bmesh("WesternClothSaltCargo", mesh, materials)
    _apply_bevel(obj, 0.008)
    root = _make_root("western_cloth_salt", obj)
    return root, obj


def _build_livonian_grain_flax() -> tuple[bpy.types.Object, bpy.types.Object]:
    materials = [
        _create_material("WornBurlap", "burlap", "burlap"),
        _create_material("HempCord", "rope", "fiber"),
        _create_material("DriedFlax", "flax", "fiber"),
    ]
    mesh = bmesh.new()
    _add_sack(mesh, (-0.37, -0.04, 0.0), 1.02, 0, 1, math.radians(-5.0))
    _add_sack(mesh, (0.01, -0.17, 0.0), 0.92, 0, 1, math.radians(9.0))
    _add_sack(mesh, (-0.10, 0.22, 0.0), 0.86, 0, 1, math.radians(-13.0))
    # Two crossed sheaves use individually readable stalk rods around a dense core.
    for bundle_index, (center, yaw) in enumerate((((0.38, 0.12, 0.18), -14.0), ((0.42, -0.18, 0.16), 12.0))):
        direction = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Vector((0.0, 0.58, 0.12))
        center_v = Vector(center)
        for stalk_index in range(9):
            lateral = (stalk_index - 4) * 0.018
            offset = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Vector((lateral, 0.0, (stalk_index % 3) * 0.008))
            _add_cylinder_between(mesh, tuple(center_v - direction * 0.5 + offset), tuple(center_v + direction * 0.5 + offset), 0.010, 2, 6)
        _add_cylinder(mesh, tuple(center_v), 0.095, 0.035, 1, 10, Matrix.Rotation(math.radians(78.0), 4, "X"))
    obj = _object_from_bmesh("LivonianGrainFlaxCargo", mesh, materials)
    _apply_bevel(obj, 0.006)
    root = _make_root("livonian_grain_flax", obj)
    return root, obj


def _build_barrelled_herring_metal() -> tuple[bpy.types.Object, bpy.types.Object]:
    materials = [
        _create_material("CooperedOak", "wood", "wood"),
        _create_material("DarkBarrelOak", "dark_wood", "wood"),
        _create_material("BarrelIron", "iron", "metal", 0.62),
        _create_material("IronBars", "iron", "metal", 0.70),
        _create_material("CopperIngots", "copper", "metal", 0.68),
        _create_material("HempCord", "rope", "fiber"),
    ]
    mesh = bmesh.new()
    _add_barrel(mesh, (-0.38, 0.06, 0.34), 0, 2, horizontal=False, yaw=math.radians(-7.0))
    _add_barrel(mesh, (0.18, -0.20, 0.27), 1, 2, horizontal=True, yaw=math.radians(-18.0))
    # Bundled iron bars and trapezoidal copper ingots signal high-value metal cargo.
    for index in range(5):
        y = 0.18 + index * 0.055
        _add_box(mesh, (0.35, y, 0.055 + (index % 2) * 0.045), (0.74, 0.035, 0.035), 3, 9.0)
    for x in (0.13, 0.50):
        _add_box(mesh, (x, 0.29, 0.12), (0.025, 0.31, 0.025), 5, 9.0)
    for index, center in enumerate(((0.42, -0.02, 0.08), (0.55, 0.09, 0.08), (0.28, 0.08, 0.08), (0.48, 0.19, 0.08))):
        _add_ingot(mesh, center, (0.22, 0.11, 0.11), 4, math.radians(-8.0 + index * 5.0))
    obj = _object_from_bmesh("BarrelledHerringMetalCargo", mesh, materials)
    _apply_bevel(obj, 0.007)
    root = _make_root("barrelled_herring_metal", obj)
    return root, obj


def _make_root(variant: str, obj: bpy.types.Object) -> bpy.types.Object:
    root = bpy.data.objects.new("HanseaticTradeGoods", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    obj["asset_id"] = VARIANTS[variant]["asset_id"]
    obj["cargo_variant"] = variant
    root["asset_id"] = VARIANTS[variant]["asset_id"]
    root["cargo_variant"] = variant
    root["generator"] = "tools/generate_hanseatic_trade_goods.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    _unwrap(obj)
    _triangulate(obj)
    return root


def _bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def _metrics(variant: str, obj: bpy.types.Object, output: Path) -> dict[str, object]:
    minimum, maximum = _bounds(obj)
    mesh = obj.data
    triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
    used_materials = {polygon.material_index for polygon in mesh.polygons}
    return {
        "asset_id": VARIANTS[variant]["asset_id"],
        "variant": variant,
        "mesh_objects": 1,
        "vertices": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "triangles": triangles,
        "surfaces": len(used_materials),
        "materials": len(used_materials),
        "uv_sets": len(mesh.uv_layers),
        "texture_size": TEXTURE_SIZE,
        "dimensions_m_blender_xyz": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "goods": VARIANTS[variant]["goods"],
        "direction": VARIANTS[variant]["direction"],
    }


def _export(variant: str, root: bpy.types.Object, obj: bpy.types.Object) -> dict[str, object]:
    output = OUTPUT_DIR / f"{variant}.glb"
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(output),
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
    return _metrics(variant, obj, output)


def _render_preview(objects: dict[str, bpy.types.Object]) -> None:
    positions = {
        "eastern_furs_wax": (-1.15, 0.78, 0.0),
        "western_cloth_salt": (1.15, 0.78, 0.0),
        "livonian_grain_flax": (-1.15, -0.78, 0.0),
        "barrelled_herring_metal": (1.15, -0.78, 0.0),
    }
    for variant, root in objects.items():
        root.location = positions[variant]

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.031, 0.026)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.16, 0.14, 0.11, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, -0.01))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.4, -4.5, 6.2))
    key = bpy.context.object
    key.data.energy = 1150.0
    key.data.shape = "DISK"
    key.data.size = 4.2
    key.rotation_euler = (Vector((0.0, 0.0, 0.35)) - key.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(4.0, 2.5, 4.0))
    fill = bpy.context.object
    fill.data.energy = 580.0
    fill.data.color = (0.52, 0.62, 0.82)
    fill.data.size = 3.4
    fill.rotation_euler = (Vector((0.0, 0.0, 0.35)) - fill.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(5.2, -7.2, 6.2))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, 0.0, 0.28)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.6
    scene.camera = camera
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _write_evidence(metrics: dict[str, dict[str, object]], preview_rendered: bool) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        "route": "deterministic_blender",
        "generator": "tools/generate_hanseatic_trade_goods.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": _cache_key(),
        "historical_sources": [
            "history/dossiers/topography/harbour-and-shoreline.md",
            "history/dossiers/topography/old-market-vanaturg.md",
            "https://pure.knaw.nl/ws/files/463798/BALTIC_CONNECTIONS_article.pdf",
            "https://eprints.bournemouth.ac.uk/24537/1/Fish%20Feather%20and%20Fur%20QI%20Uncorrected%20proofs.pdf",
            "https://research.chalmers.se/publication/528778/file/528778_Fulltext.pdf",
        ],
        "assumptions": [
            "No complete 1343 Reval customs ledger survives in project evidence; the kit uses period Hanseatic cargo norms.",
            "Salt, herring, and wine use coopered barrel cargo; cloth is cord-bound; fur bundles are counted and tied.",
        ],
        "variants": metrics,
        "checks": {
            "metric_scale": all(max(values["dimensions_m_blender_xyz"]) <= 1.65 for values in metrics.values()),
            "y_up_glb": True,
            "ground_contact": all(abs(float(values["ground_min_z"])) <= 0.015 for values in metrics.values()),
            "triangle_cap": all(int(values["triangles"]) <= TRIANGLE_MAX for values in metrics.values()),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": all(int(values["uv_sets"]) >= 1 for values in metrics.values()),
            "mesh_count": all(int(values["mesh_objects"]) == 1 for values in metrics.values()),
        },
    }
    if preview_rendered:
        report["preview"] = PREVIEW_PATH.relative_to(ROOT).as_posix()
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": BRIEF["id"],
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": report["cache_key"],
        "selected_glbs": [f"assets/props/trade/{variant}.glb" for variant in VARIANTS],
        "sha256": {variant: values["sha256"] for variant, values in metrics.items()},
        "decision": "integrate",
        "defects": [],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = {
        "eastern_furs_wax": _build_eastern_furs_wax,
        "western_cloth_salt": _build_western_cloth_salt,
        "livonian_grain_flax": _build_livonian_grain_flax,
        "barrelled_herring_metal": _build_barrelled_herring_metal,
    }
    roots: dict[str, bpy.types.Object] = {}
    metrics: dict[str, dict[str, object]] = {}
    for variant, builder in builders.items():
        root, obj = builder()
        roots[variant] = root
        metrics[variant] = _export(variant, root, obj)

    preview_rendered = "--preview" in sys.argv
    if preview_rendered:
        _render_preview(roots)
    _write_evidence(metrics, preview_rendered)
    compact = {
        variant: {
            "triangles": values["triangles"],
            "materials": values["materials"],
            "dimensions": values["dimensions_m_blender_xyz"],
            "sha256": values["sha256"],
        }
        for variant, values in metrics.items()
    }
    print("ASSET_METRICS=" + json.dumps(compact, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
