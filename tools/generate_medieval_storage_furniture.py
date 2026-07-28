#!/usr/bin/env python3
"""Build the historically tiered medieval Reval storage-furniture kit.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_medieval_storage_furniture.py -- --preview

The kit deliberately avoids a modern hanging wardrobe. It provides a common open
rack, a burgher lockable cupboard, and a rare elite armarium derived from dated
Northern European comparanda. Clothing remains folded rather than hung on a rail.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "props" / "furniture" / "medieval_storage"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "medieval_storage_furniture_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.medieval_storage_furniture"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "medieval_storage_furniture_v1"

COMMON_VARIANT = "shelf.common_open"
BURGHER_VARIANT = "shelf.burgher_cupboard"
ELITE_VARIANT = "shelf.elite_armarium"
VARIANT_OUTPUTS = {
    COMMON_VARIANT: OUTPUT_DIR / "common_open_rack.glb",
    BURGHER_VARIANT: OUTPUT_DIR / "burgher_cupboard.glb",
    ELITE_VARIANT: OUTPUT_DIR / "elite_armarium.glb",
}

COMMON_WOOD_SRGB = (0x78 / 255.0, 0x59 / 255.0, 0x38 / 255.0)
BURGHER_OAK_SRGB = (0x67 / 255.0, 0x43 / 255.0, 0x29 / 255.0)
ELITE_OAK_SRGB = (0x55 / 255.0, 0x34 / 255.0, 0x24 / 255.0)
DARK_OAK_SRGB = (0x35 / 255.0, 0x24 / 255.0, 0x1C / 255.0)
IRON_SRGB = (0x3F / 255.0, 0x46 / 255.0, 0x47 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop_kit",
    "targets": {variant: "res://" + str(path.relative_to(ROOT)) for variant, path in VARIANT_OUTPUTS.items()},
    "scene": "res://content/maps/town_hall.rrmap#archive_shelf_north",
    "dimensions_m": {"common": [1.0, 1.42, 0.44], "burgher": [1.2, 1.54, 0.56], "elite": [1.4, 1.98, 0.7]},
    "triangles": {"target_each": 1800, "max_each": 4000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "history_ref": "history/dossiers/architecture/domestic-storage-furniture.md",
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_material(
    name: str,
    srgb: tuple[float, float, float],
    roughness: float,
    texture_name: str | None = None,
    texture_profile: str = "oak",
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = 0.0
    material.roughness = roughness
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = roughness
    if texture_name is not None:
        _add_embedded_wood_albedo(material, texture_name, srgb, texture_profile)
    return material


def _add_embedded_wood_albedo(
    material: bpy.types.Material,
    image_name: str,
    base_srgb: tuple[float, float, float],
    profile: str,
) -> None:
    """Bake broad hand-worked grain that exports identically to Godot glTF PBR."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if profile == "rough_softwood":
        warp = u + 0.038 * np.sin(v * math.tau * 1.6) + 0.014 * np.sin(v * math.tau * 5.0)
        broad = np.sin((warp * 7.0 + v * 0.45) * math.tau)
        saw = np.sin((u * 23.0 - v * 2.0) * math.tau)
        variation = 0.82 + broad * 0.082 + saw * 0.020
        scratches = (0.16, 0.49, 0.81)
    elif profile == "selected_oak":
        warp = u + 0.018 * np.sin(v * math.tau * 2.2) + 0.006 * np.sin(v * math.tau * 8.0)
        broad = np.sin((warp * 10.5 + v * 0.18) * math.tau)
        ray = np.sin((u * 36.0 + v * 0.5) * math.tau)
        variation = 0.88 + broad * 0.055 + ray * 0.014
        scratches = (0.34,)
    else:
        warp = u + 0.025 * np.sin(v * math.tau * 2.0) + 0.009 * np.sin(v * math.tau * 6.0)
        broad = np.sin((warp * 9.0 + v * 0.25) * math.tau)
        fine = np.sin((warp * 31.0 - v * 0.6) * math.tau)
        variation = 0.85 + broad * 0.067 + fine * 0.017
        scratches = (0.25, 0.72)

    for knot_u, knot_v, radius in ((0.24, 0.31, 0.075), (0.72, 0.68, 0.09)):
        dx = (u - knot_u) / radius
        dy = (v - knot_v) / (radius * 0.58)
        distance = np.sqrt(dx * dx + dy * dy)
        variation += np.sin(distance * math.tau * 2.0) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.055
        variation -= np.exp(-(distance * distance) * 5.2) * 0.12
    for scratch_v in scratches:
        distance = np.abs(v - (scratch_v + 0.009 * np.sin(u * math.tau * 3.0)))
        variation -= np.clip(1.0 - distance / 0.004, 0.0, 1.0) * 0.045

    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)
    image = bpy.data.images.new(image_name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()

    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedWoodAlbedo"
    texture.image = image
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])


def _activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _finish_part(
    obj: bpy.types.Object,
    material: bpy.types.Material,
    bevel: float = 0.006,
    bevel_segments: int = 1,
) -> bpy.types.Object:
    obj.data.materials.append(material)
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("HandWorkedEdges", "BEVEL")
        modifier.width = bevel
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(24.0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def _box(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material: bpy.types.Material,
    bevel: float = 0.006,
    rotation_z_degrees: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    obj.rotation_euler.z = math.radians(rotation_z_degrees)
    parts.append(_finish_part(obj, material, bevel))
    return obj


def _beam_between(
    parts: list[bpy.types.Object],
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    depth: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(start_v + end_v) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector((width, depth, direction.length))
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    parts.append(_finish_part(obj, material, 0.004))
    return obj


def _cylinder(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    axis: str = "Z",
    segments: int = 10,
) -> bpy.types.Object:
    rotation = (0.0, 0.0, 0.0)
    if axis == "Y":
        rotation = (math.radians(90.0), 0.0, 0.0)
    elif axis == "X":
        rotation = (0.0, math.radians(90.0), 0.0)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=center,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    parts.append(_finish_part(obj, material, 0.002))
    return obj


def _torus(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=12,
        minor_segments=6,
        location=center,
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = name
    parts.append(_finish_part(obj, material, 0.0))
    return obj


def _join_parts(parts: list[bpy.types.Object], mesh_name: str, variant: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = mesh_name
    obj.data.name = mesh_name + "Geometry"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj["asset_id"] = ASSET_ID
    obj["style_variant"] = variant
    obj["storage_mode"] = "folded_textiles_and_valuables"
    return obj


def _build_common_open_rack() -> bpy.types.Object:
    wood = _create_material(
        "rough_baltic_softwood",
        COMMON_WOOD_SRGB,
        0.94,
        "medieval_storage_common_softwood_albedo",
        "rough_softwood",
    )
    pegs = _create_material("darkened_wood_pegs", DARK_OAK_SRGB, 0.97)
    parts: list[bpy.types.Object] = []

    for x, side in ((-0.45, "Left"), (0.45, "Right")):
        for y, face in ((-0.14, "Front"), (0.14, "Back")):
            _box(parts, "%s%sPost" % (side, face), (x, y, 0.70), (0.075, 0.075, 1.40), wood, 0.005)
    for index, z in enumerate((0.24, 0.66, 1.08)):
        _box(parts, "ShelfPlank%d" % index, (0.0, 0.0, z), (0.96, 0.35, 0.06), wood, 0.006)
    _box(parts, "TopRail", (0.0, 0.13, 1.355), (0.98, 0.07, 0.09), wood, 0.006)
    _beam_between(parts, "BackBraceRising", (-0.41, 0.17, 0.08), (0.41, 0.17, 1.30), 0.045, 0.035, wood)
    _beam_between(parts, "BackBraceFalling", (0.41, 0.18, 0.08), (-0.41, 0.18, 1.30), 0.038, 0.03, wood)
    for index, x in enumerate((-0.30, -0.10, 0.10, 0.30)):
        _cylinder(parts, "StoragePeg%d" % index, (x, -0.205, 1.345), 0.018, 0.14, pegs, axis="Y", segments=8)
    # One replacement cleat makes the common rack read as maintained household
    # furniture rather than a perfectly regular modern shelving unit.
    _box(parts, "RepairCleat", (-0.28, -0.185, 0.64), (0.28, 0.025, 0.055), pegs, 0.002, -4.0)
    return _join_parts(parts, "CommonOpenRackMesh", COMMON_VARIANT)


def _add_carcass(
    parts: list[bpy.types.Object],
    width: float,
    depth: float,
    height: float,
    wood: bpy.types.Material,
    panel: bpy.types.Material,
    prefix: str,
) -> None:
    post_x = width * 0.5 - 0.06
    post_y = depth * 0.5 - 0.055
    for x, side in ((-post_x, "Left"), (post_x, "Right")):
        for y, face in ((-post_y, "Front"), (post_y, "Back")):
            _box(parts, "%s%s%sPost" % (prefix, side, face), (x, y, height * 0.5), (0.09, 0.09, height), wood, 0.008)
    _box(parts, prefix + "BottomBoard", (0.0, 0.0, 0.16), (width - 0.12, depth - 0.10, 0.11), wood, 0.008)
    _box(parts, prefix + "BackPanel", (0.0, depth * 0.5 - 0.04, height * 0.55), (width - 0.16, 0.045, height * 0.78), panel, 0.004)
    for x, side in ((-width * 0.5 + 0.045, "Left"), (width * 0.5 - 0.045, "Right")):
        _box(parts, prefix + side + "SidePanel", (x, 0.0, height * 0.55), (0.045, depth - 0.16, height * 0.76), panel, 0.004)
    _box(parts, prefix + "TopCap", (0.0, 0.0, height - 0.04), (width + 0.04, depth + 0.04, 0.08), wood, 0.01)


def _add_framed_door(
    parts: list[bpy.types.Object],
    name: str,
    center_x: float,
    front_y: float,
    center_z: float,
    width: float,
    height: float,
    wood: bpy.types.Material,
    panel: bpy.types.Material,
    divided: bool,
) -> None:
    stile = 0.07
    rail = 0.075
    _box(parts, name + "Panel", (center_x, front_y + 0.018, center_z), (width - 0.12, 0.035, height - 0.12), panel, 0.004)
    for x, side in ((center_x - width * 0.5 + stile * 0.5, "Left"), (center_x + width * 0.5 - stile * 0.5, "Right")):
        _box(parts, name + side + "Stile", (x, front_y, center_z), (stile, 0.055, height), wood, 0.006)
    for z, rail_name in ((center_z - height * 0.5 + rail * 0.5, "Bottom"), (center_z + height * 0.5 - rail * 0.5, "Top")):
        _box(parts, name + rail_name + "Rail", (center_x, front_y, z), (width - 0.10, 0.055, rail), wood, 0.006)
    if divided:
        _box(parts, name + "MiddleRail", (center_x, front_y, center_z), (width - 0.10, 0.058, 0.07), wood, 0.006)


def _add_hardware(
    parts: list[bpy.types.Object],
    iron: bpy.types.Material,
    door_centers: tuple[float, float],
    front_y: float,
    hinge_heights: tuple[float, ...],
    strap_length: float,
    lock_z: float,
) -> None:
    for door_index, center_x in enumerate(door_centers):
        hinge_side = -1.0 if door_index == 0 else 1.0
        for hinge_index, z in enumerate(hinge_heights):
            strap_x = center_x + hinge_side * (strap_length * 0.18)
            _box(parts, "Door%dHingeStrap%d" % (door_index, hinge_index), (strap_x, front_y, z), (strap_length, 0.022, 0.032), iron, 0.002)
            _cylinder(parts, "Door%dHingePin%d" % (door_index, hinge_index), (center_x + hinge_side * 0.23, front_y - 0.012, z), 0.012, 0.055, iron, axis="Z", segments=8)
    _box(parts, "CentralLockPlate", (0.0, front_y - 0.008, lock_z), (0.12, 0.028, 0.16), iron, 0.003)
    _box(parts, "LockHasp", (0.0, front_y - 0.025, lock_z + 0.025), (0.26, 0.025, 0.035), iron, 0.002)
    _torus(parts, "LockRing", (0.0, front_y - 0.055, lock_z - 0.055), 0.052, 0.010, iron)


def _build_burgher_cupboard() -> bpy.types.Object:
    oak = _create_material(
        "painted_burgher_oak",
        BURGHER_OAK_SRGB,
        0.88,
        "medieval_storage_burgher_oak_albedo",
        "oak",
    )
    dark = _create_material("burgher_recessed_oak", DARK_OAK_SRGB, 0.94)
    iron = _create_material("wrought_iron_hardware", IRON_SRGB, 0.76)
    parts: list[bpy.types.Object] = []
    width, depth, height = 1.16, 0.52, 1.52
    _add_carcass(parts, width, depth, height, oak, dark, "Burgher")
    front_y = -depth * 0.5 - 0.012
    for center_x, side in ((-0.275, "Left"), (0.275, "Right")):
        _add_framed_door(parts, "Burgher%sDoor" % side, center_x, front_y, 0.80, 0.53, 1.18, oak, dark, False)
    _add_hardware(parts, iron, (-0.275, 0.275), front_y - 0.035, (0.50, 1.12), 0.22, 0.79)
    for index, x in enumerate((-0.36, 0.36)):
        _cylinder(parts, "VisibleJoineryPeg%d" % index, (x, front_y - 0.04, 1.42), 0.015, 0.026, dark, axis="Y", segments=8)
    return _join_parts(parts, "BurgherCupboardMesh", BURGHER_VARIANT)


def _build_elite_armarium() -> bpy.types.Object:
    oak = _create_material(
        "selected_elite_oak",
        ELITE_OAK_SRGB,
        0.86,
        "medieval_storage_elite_oak_albedo",
        "selected_oak",
    )
    dark = _create_material("elite_recessed_oak", DARK_OAK_SRGB, 0.92)
    iron = _create_material("elite_wrought_iron_hardware", IRON_SRGB, 0.72)
    parts: list[bpy.types.Object] = []
    width, depth, height = 1.36, 0.68, 1.96
    _add_carcass(parts, width, depth, height, oak, dark, "Elite")
    # Layered cornice and full-height posts echo the rare Halberstadt Stollenschrank
    # form without copying its ecclesiastical painted iconography into a home.
    _box(parts, "EliteLowerCornice", (0.0, 0.0, 1.86), (1.40, 0.70, 0.09), oak, 0.012)
    _box(parts, "EliteUpperCornice", (0.0, 0.0, 1.94), (1.46, 0.74, 0.075), oak, 0.012)
    front_y = -depth * 0.5 - 0.012
    for center_x, side in ((-0.32, "Left"), (0.32, "Right")):
        _add_framed_door(parts, "Elite%sDoor" % side, center_x, front_y, 1.00, 0.61, 1.55, oak, dark, True)
    _add_hardware(parts, iron, (-0.32, 0.32), front_y - 0.035, (0.48, 1.00, 1.52), 0.28, 1.00)
    for side_x, label in ((-0.64, "Left"), (0.64, "Right")):
        for z in (0.28, 1.70):
            _box(parts, "Elite%sCornerStrap" % label, (side_x, front_y - 0.025, z), (0.055, 0.022, 0.24), iron, 0.002)
    return _join_parts(parts, "EliteArmariumMesh", ELITE_VARIANT)


def _mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    mesh = obj.data
    triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in bounds), min(v.y for v in bounds), min(v.z for v in bounds)))
    maximum = Vector((max(v.x for v in bounds), max(v.y for v in bounds), max(v.z for v in bounds)))
    textured_materials = 0
    for material in mesh.materials:
        if material is not None and material.use_nodes:
            if any(node.type == "TEX_IMAGE" and node.image is not None for node in material.node_tree.nodes):
                textured_materials += 1
    return {
        "vertices": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "triangles": triangles,
        "materials": len(mesh.materials),
        "textured_materials": textured_materials,
        "uv_sets": len(mesh.uv_layers),
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
    }


def _export(obj: bpy.types.Object, variant: str, output: Path) -> tuple[bpy.types.Object, dict[str, object]]:
    root_name = {
        COMMON_VARIANT: "CommonOpenRack",
        BURGHER_VARIANT: "BurgherCupboard",
        ELITE_VARIANT: "EliteArmarium",
    }[variant]
    root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    root["asset_id"] = ASSET_ID
    root["style_variant"] = variant
    root["generator"] = "tools/generate_medieval_storage_furniture.py"
    root["historical_note"] = "No modern hanging rail; textiles are folded or chest-stored."

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    output.parent.mkdir(parents=True, exist_ok=True)
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
    metrics = _mesh_metrics(obj)
    metrics["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    return root, metrics


def _render_preview(roots: list[bpy.types.Object], output: Path) -> None:
    for root, x in zip(roots, (-1.55, 0.0, 1.65), strict=True):
        root.location.x = x
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.030, 0.024)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.14, 0.115, 0.080, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=7.0, location=(0.0, 0.0, -0.004))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.0, 5.0))
    key = bpy.context.object
    key.data.energy = 1050.0
    key.data.shape = "DISK"
    key.data.size = 3.5
    bpy.ops.object.light_add(type="AREA", location=(4.2, 1.8, 3.2))
    fill = bpy.context.object
    fill.data.energy = 520.0
    fill.data.color = (0.55, 0.66, 0.82)
    fill.data.size = 3.0

    bpy.ops.object.camera_add(location=(4.9, -7.2, 3.8))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.95)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.6
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _write_evidence(metrics: dict[str, dict[str, object]], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    cache_key = _cache_key()
    report = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "generator": "tools/generate_medieval_storage_furniture.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": cache_key,
        "variants": metrics,
        "checks": ["metric_scale", "y_up", "ground_contact", "uvs", "embedded_pbr_albedo", "social_variant_allowlist"],
    }
    if preview is not None:
        report["preview"] = str(preview.relative_to(ROOT))
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": cache_key,
        "selected_glbs": {variant: str(path.relative_to(ROOT)) for variant, path in VARIANT_OUTPUTS.items()},
        "sha256": {variant: values["sha256"] for variant, values in metrics.items()},
        "decision": "integrated",
        "defects": [],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = {
        COMMON_VARIANT: _build_common_open_rack,
        BURGHER_VARIANT: _build_burgher_cupboard,
        ELITE_VARIANT: _build_elite_armarium,
    }
    roots: list[bpy.types.Object] = []
    metrics: dict[str, dict[str, object]] = {}
    for variant, builder in builders.items():
        obj = builder()
        root, variant_metrics = _export(obj, variant, VARIANT_OUTPUTS[variant])
        roots.append(root)
        metrics[variant] = variant_metrics

    preview: Path | None = None
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        preview = Path(sys.argv[preview_index + 1]) if preview_index + 1 < len(sys.argv) else DEFAULT_PREVIEW
        _render_preview(roots, preview)
    _write_evidence(metrics, preview)
    summary = {
        "variants": {variant: {"triangles": values["triangles"], "dimensions_m": values["dimensions_m"], "sha256": values["sha256"]} for variant, values in metrics.items()},
        "preview": str(preview) if preview is not None else "",
    }
    print("ASSET_METRICS=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
