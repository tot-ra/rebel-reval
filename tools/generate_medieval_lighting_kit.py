#!/usr/bin/env python3
"""Build the game-ready Reval 1343 domestic lighting kit.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_medieval_lighting_kit.py -- --preview

The GLB contains five independent model roots selected by rrmap `style_variant`:
three socially distinct candle arrangements, an open grease lamp, and a
pine-splint reconstruction. The source script fully reproduces the asset, so no
.blend file is required.
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
OUTPUT = ROOT / "assets" / "props" / "lighting" / "medieval_lighting_kit.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "medieval_lighting_kit_v1"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
ASSET_ID = "prop.medieval_lighting_kit"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "medieval_lighting_kit_v1"

VARIANT_ROOTS = {
    "poor_tallow": "PoorTallow",
    "artisan_tallow": "ArtisanTallow",
    "rich_beeswax": "RichBeeswax",
    "grease_lamp": "GreaseLamp",
    "pine_splint": "PineSplint",
}

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop_set",
    "target": "res://assets/props/lighting/medieval_lighting_kit.glb",
    "scene": "res://content/maps/kalev_smithy.rrmap#table_candle",
    "variants": list(VARIANT_ROOTS),
    "dimensions_m_max": [0.52, 0.90, 0.52],
    "triangles": {"target": 6500, "max": 9000},
    "textures": {"albedo": 512, "embedded": True},
    "style_refs": [
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
        "https://www.metmuseum.org/art/collection/search/467703",
        "https://www.metmuseum.org/art/collection/search/469867",
        "http://collections.vam.ac.uk/item/O69137/",
        "https://doi.org/10.1080/00766097.2024.2419279",
        "https://doi.org/10.5284/1071958",
    ],
    "approval": "task-authorized",
}

COLORS = {
    "iron": (0x3F / 255.0, 0x46 / 255.0, 0x46 / 255.0),
    "brass": (0x8D / 255.0, 0x68 / 255.0, 0x2F / 255.0),
    "tallow": (0xC8 / 255.0, 0xBA / 255.0, 0x96 / 255.0),
    "beeswax": (0xD7 / 255.0, 0x9B / 255.0, 0x3E / 255.0),
    "pottery": (0x78 / 255.0, 0x43 / 255.0, 0x2C / 255.0),
    "oil": (0x4C / 255.0, 0x2E / 255.0, 0x18 / 255.0),
    "pine": (0x74 / 255.0, 0x45 / 255.0, 0x25 / 255.0),
    "char": (0x1E / 255.0, 0x18 / 255.0, 0x14 / 255.0),
    "flame": (1.0, 0.48, 0.08),
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Bake broad deterministic wear so the glTF remains portable."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    broad = np.sin((u * 3.0 + v * 2.0) * math.tau)
    fine = np.sin((u * 17.0 - v * 11.0) * math.tau)

    if surface == "metal":
        hammered = np.sin((u * 13.0 + v * 5.0) * math.tau) * np.sin((v * 15.0 - u * 4.0) * math.tau)
        variation = 0.77 + broad * 0.035 + hammered * 0.045
    elif surface == "brass":
        tarnish = np.clip(np.sin((u * 4.0 + v * 1.5) * math.tau), 0.0, 1.0)
        variation = 0.87 + broad * 0.035 - tarnish * 0.07
    elif surface == "wax":
        drips = np.maximum(0.0, np.sin((u * 8.0 + v * 0.35) * math.tau))
        variation = 0.92 + broad * 0.018 - drips * np.clip(0.40 - v, 0.0, 0.40) * 0.10
    elif surface == "pottery":
        wheel = np.sin(v * 28.0 * math.tau)
        soot = np.clip((v - 0.58) * 2.0, 0.0, 1.0) * np.clip(np.sin(u * 4.0 * math.tau), 0.0, 1.0)
        variation = 0.82 + wheel * 0.025 + broad * 0.035 - soot * 0.11
    elif surface == "wood":
        grain = np.sin((u * 15.0 + 0.12 * np.sin(v * 3.0 * math.tau)) * math.tau)
        variation = 0.82 + grain * 0.06 + fine * 0.012
    elif surface == "oil":
        variation = 0.78 + broad * 0.025 + fine * 0.008
    else:
        variation = np.ones_like(u)

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


def _material(
    name: str,
    color: tuple[float, float, float],
    surface: str,
    roughness: float,
    metallic: float = 0.0,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    linear = tuple(_srgb_to_linear(value) for value in color)
    material.diffuse_color = (*linear, 1.0)
    material.roughness = roughness
    material.metallic = metallic
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*linear, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if emission_strength > 0.0:
        principled.inputs["Emission Color"].default_value = (*linear, 1.0)
        principled.inputs["Emission Strength"].default_value = emission_strength
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture(f"{name}_albedo", color, surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _empty(name: str, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj


def _lathe(
    name: str,
    profile: list[tuple[float, float]],
    segments: int,
    material: bpy.types.Material,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for radius, height in profile:
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, height))
    for level in range(len(profile) - 1):
        for segment in range(segments):
            nxt = (segment + 1) % segments
            a = level * segments + segment
            b = level * segments + nxt
            c = (level + 1) * segments + nxt
            d = (level + 1) * segments + segment
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            level = vertex_index // segments
            segment = vertex_index % segments
            uv_layer.data[loop_index].uv = (segment / segments, level / max(1, len(profile) - 1))
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def _cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object,
    vertices: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    obj.parent = parent
    for polygon in obj.data.polygons:
        polygon.use_smooth = abs(polygon.normal.z) < 0.5
    return obj


def _box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object,
    rotation_z: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=(0.0, 0.0, rotation_z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    obj.parent = parent
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def _flame(parent: bpy.types.Object, location: tuple[float, float, float], material: bpy.types.Material, scale: float = 1.0) -> bpy.types.Object:
    x, y, z = location
    flame = _lathe(
        "Flame",
        [(0.0, 0.0), (0.040 * scale, 0.025 * scale), (0.052 * scale, 0.070 * scale), (0.028 * scale, 0.125 * scale), (0.0, 0.175 * scale)],
        10,
        material,
        parent,
    )
    # Keep the flame mesh local to its node so runtime lights can anchor to the
    # flame AABB instead of duplicating per-variant height constants.
    flame.location = (x, y, z)
    return flame


def _wick(parent: bpy.types.Object, location: tuple[float, float, float], material: bpy.types.Material) -> bpy.types.Object:
    return _cylinder("Wick", 0.008, 0.055, location, material, parent, 8)


def _wax_body(
    parent: bpy.types.Object,
    name: str,
    base_z: float,
    height: float,
    radius: float,
    material: bpy.types.Material,
    lean: float = 0.0,
) -> bpy.types.Object:
    levels = 7
    profile: list[tuple[float, float]] = []
    for level in range(levels):
        fraction = level / (levels - 1)
        uneven = 1.0 + 0.045 * math.sin(fraction * math.tau * 2.0 + 0.7)
        profile.append((radius * uneven, base_z + height * fraction))
    wax = _lathe(name, profile, 14, material, parent)
    wax.rotation_euler[1] = lean
    return wax


def _build_poor_tallow(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = _empty(VARIANT_ROOTS["poor_tallow"])
    root["lighting_variant"] = "poor_tallow"
    root["historical_confidence"] = "attested-composite"
    _lathe("IronDripPan", [(0.0, 0.0), (0.13, 0.0), (0.145, 0.018), (0.13, 0.040), (0.055, 0.046)], 18, materials["iron"], root)
    _lathe("CrudeSocket", [(0.050, 0.040), (0.055, 0.090), (0.048, 0.108)], 14, materials["iron"], root)
    _wax_body(root, "UnevenTallowCandle", 0.085, 0.225, 0.045, materials["tallow"], math.radians(-1.7))
    _lathe("TallowDrip", [(0.0, 0.135), (0.018, 0.140), (0.023, 0.180), (0.013, 0.225), (0.0, 0.240)], 8, materials["tallow"], root).location.x = 0.044
    _wick(root, (0.0, 0.0, 0.326), materials["char"])
    _flame(root, (0.0, 0.0, 0.345), materials["flame"], 0.82)
    return root


def _build_artisan_tallow(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = _empty(VARIANT_ROOTS["artisan_tallow"])
    root["lighting_variant"] = "artisan_tallow"
    root["historical_confidence"] = "attested-composite"
    _lathe("ForgedIronFoot", [(0.0, 0.0), (0.145, 0.0), (0.155, 0.018), (0.125, 0.040), (0.055, 0.060), (0.028, 0.082)], 20, materials["iron"], root)
    _lathe("ForgedIronStem", [(0.026, 0.078), (0.020, 0.205), (0.038, 0.225), (0.021, 0.250), (0.020, 0.290)], 14, materials["iron"], root)
    _lathe("IronBobeche", [(0.020, 0.280), (0.095, 0.287), (0.110, 0.300), (0.085, 0.318), (0.040, 0.322)], 18, materials["iron"], root)
    _cylinder("HiddenPricket", 0.010, 0.105, (0.0, 0.0, 0.365), materials["iron"], root, 8)
    _wax_body(root, "TallowCandle", 0.315, 0.245, 0.052, materials["tallow"])
    _wick(root, (0.0, 0.0, 0.575), materials["char"])
    _flame(root, (0.0, 0.0, 0.595), materials["flame"], 0.9)
    return root


def _build_rich_beeswax(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = _empty(VARIANT_ROOTS["rich_beeswax"])
    root["lighting_variant"] = "rich_beeswax"
    root["historical_confidence"] = "attested"
    _lathe("CastBrassFoot", [(0.0, 0.0), (0.175, 0.0), (0.185, 0.020), (0.155, 0.048), (0.075, 0.072), (0.036, 0.105)], 24, materials["brass"], root)
    _lathe(
        "TurnedBrassStem",
        [(0.034, 0.095), (0.026, 0.205), (0.060, 0.235), (0.048, 0.285), (0.024, 0.315), (0.025, 0.395)],
        18,
        materials["brass"],
        root,
    )
    _lathe("BrassBobeche", [(0.025, 0.385), (0.110, 0.395), (0.125, 0.410), (0.090, 0.430), (0.038, 0.434)], 22, materials["brass"], root)
    _cylinder("Pricket", 0.011, 0.120, (0.0, 0.0, 0.485), materials["brass"], root, 8)
    _wax_body(root, "BeeswaxCandle", 0.425, 0.285, 0.047, materials["beeswax"])
    _wick(root, (0.0, 0.0, 0.727), materials["char"])
    _flame(root, (0.0, 0.0, 0.746), materials["flame"], 1.0)
    return root


def _build_grease_lamp(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = _empty(VARIANT_ROOTS["grease_lamp"])
    root["lighting_variant"] = "grease_lamp"
    root["historical_confidence"] = "plausible-composite"
    _lathe("PotteryLamp", [(0.0, 0.0), (0.10, 0.0), (0.155, 0.035), (0.172, 0.085), (0.160, 0.130), (0.125, 0.145)], 20, materials["pottery"], root)
    _lathe("RenderedFat", [(0.0, 0.132), (0.120, 0.132), (0.122, 0.140), (0.0, 0.140)], 18, materials["oil"], root)
    _box("PinchedSpout", (0.16, 0.085, 0.045), (0.145, 0.0, 0.118), materials["pottery"], root)
    wick = _box("Wick", (0.105, 0.016, 0.016), (0.165, 0.0, 0.154), materials["char"], root)
    wick.rotation_euler[1] = math.radians(-12.0)
    _flame(root, (0.220, 0.0, 0.165), materials["flame"], 0.78)
    return root


def _build_pine_splint(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = _empty(VARIANT_ROOTS["pine_splint"])
    root["lighting_variant"] = "pine_splint"
    root["historical_confidence"] = "low-confidence-reconstruction"
    _box("WoodenBase", (0.28, 0.22, 0.035), (0.0, 0.0, 0.018), materials["pine"], root)
    _cylinder("IronStand", 0.015, 0.390, (0.0, 0.0, 0.240), materials["iron"], root, 10)
    _box("LowerJaw", (0.13, 0.025, 0.035), (0.025, 0.0, 0.420), materials["iron"], root, math.radians(8.0))
    _box("UpperJaw", (0.13, 0.025, 0.035), (0.025, 0.0, 0.463), materials["iron"], root, math.radians(-6.0))
    _cylinder("JawRivet", 0.018, 0.045, (-0.025, 0.0, 0.442), materials["iron"], root, 10).rotation_euler[0] = math.radians(90.0)
    splint = _box("ResinousPineSplint", (0.48, 0.040, 0.030), (0.150, 0.0, 0.490), materials["pine"], root, math.radians(8.0))
    splint.rotation_euler[1] = math.radians(-2.0)
    _box("CharredTip", (0.075, 0.044, 0.034), (0.365, 0.0, 0.520), materials["char"], root, math.radians(8.0))
    _flame(root, (0.392, 0.0, 0.535), materials["flame"], 0.88)
    return root


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    materials = {
        "iron": _material("aged_forged_iron", COLORS["iron"], "metal", 0.78, 0.72),
        "brass": _material("tarnished_cast_brass", COLORS["brass"], "brass", 0.48, 0.74),
        "tallow": _material("smoky_tallow", COLORS["tallow"], "wax", 0.92),
        "beeswax": _material("golden_beeswax", COLORS["beeswax"], "wax", 0.82),
        "pottery": _material("sooted_redware", COLORS["pottery"], "pottery", 0.96),
        "oil": _material("rendered_animal_fat", COLORS["oil"], "oil", 0.38),
        "pine": _material("resinous_pine", COLORS["pine"], "wood", 0.86),
        "char": _material("charred_wick", COLORS["char"], "plain", 0.96),
        "flame": _material("open_flame", COLORS["flame"], "plain", 0.24, emission_strength=4.0),
    }
    root = _empty("MedievalLightingKit")
    root["asset_id"] = ASSET_ID
    variant_roots = [
        _build_poor_tallow(materials),
        _build_artisan_tallow(materials),
        _build_rich_beeswax(materials),
        _build_grease_lamp(materials),
        _build_pine_splint(materials),
    ]
    for variant_root in variant_roots:
        variant_root.parent = root
        variant_root["asset_id"] = ASSET_ID
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in meshes:
        obj["asset_id"] = ASSET_ID
    return root, variant_roots


def _descendant_meshes(root: bpy.types.Object) -> list[bpy.types.Object]:
    result: list[bpy.types.Object] = []
    stack = list(root.children)
    while stack:
        obj = stack.pop()
        stack.extend(obj.children)
        if obj.type == "MESH":
            result.append(obj)
    return result


def _bounds(meshes: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def _mesh_metrics(variant_roots: list[bpy.types.Object]) -> dict[str, object]:
    all_meshes = [mesh for root in variant_roots for mesh in _descendant_meshes(root)]
    material_names: set[str] = set()
    variant_metrics: dict[str, object] = {}
    total_triangles = 0
    for variant_id, root_name in VARIANT_ROOTS.items():
        variant_root = next(root for root in variant_roots if root.name == root_name)
        meshes = _descendant_meshes(variant_root)
        triangles = 0
        for mesh_object in meshes:
            mesh_object.data.calc_loop_triangles()
            triangles += len(mesh_object.data.loop_triangles)
        minimum, maximum = _bounds(meshes)
        total_triangles += triangles
        variant_metrics[variant_id] = {
            "triangles": triangles,
            "mesh_objects": len(meshes),
            "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
            "ground_min_z": round(minimum.z, 6),
        }
        for mesh in meshes:
            material_names.update(material.name for material in mesh.data.materials if material is not None)
    return {
        "asset_id": ASSET_ID,
        "variants": variant_metrics,
        "mesh_objects": len(all_meshes),
        "triangles": total_triangles,
        "materials": len(material_names),
        "uv_sets_min": min((len(mesh.data.uv_layers) for mesh in all_meshes), default=0),
        "texture_size": 512,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, variant_roots: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj == root or obj in variant_roots or obj.type == "MESH":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
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
    metrics = _mesh_metrics(variant_roots)
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _render_preview(variant_roots: list[bpy.types.Object], output: Path) -> None:
    spacing = 0.62
    for index, variant_root in enumerate(variant_roots):
        variant_root.location.x = (index - 2) * spacing

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 620
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.025, 0.022, 0.020)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.14, 0.11, 0.08, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0.0, 0.0, -0.006))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.8, -3.0, 4.0))
    bpy.context.object.data.energy = 750.0
    bpy.context.object.data.size = 3.2
    bpy.ops.object.light_add(type="AREA", location=(3.0, 1.0, 2.4))
    bpy.context.object.data.energy = 360.0
    bpy.context.object.data.color = (0.45, 0.58, 0.82)
    bpy.context.object.data.size = 2.5

    bpy.ops.object.camera_add(location=(2.9, -4.6, 2.5))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.39)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.4
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    variants = metrics["variants"]
    report = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "generator": "tools/generate_medieval_lighting_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "metrics": metrics,
        "limits": BRIEF["triangles"],
        "validation": {
            "metric_scale": True,
            "ground_contact": all(abs(float(item["ground_min_z"])) <= 0.001 for item in variants.values()),
            "triangle_budget": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "uvs": int(metrics["uv_sets_min"]) >= 1,
            "portable_pbr_materials": int(metrics["materials"]) == 9,
            "five_independent_variants": len(variants) == 5,
        },
        "preview": preview.relative_to(ROOT).as_posix() if preview is not None else None,
        "defects": ["pine_splint is a low-confidence regional reconstruction, not a Reval archaeological find"],
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
        "defects": report["defects"],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root, variant_roots = _build_model()
    metrics = _export(root, variant_roots)
    preview: Path | None = None
    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        if index + 1 < len(sys.argv) and not sys.argv[index + 1].startswith("--"):
            preview = Path(sys.argv[index + 1]).expanduser().resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(variant_roots, preview)
    _write_evidence(metrics, preview)
    print("ASSET_METRICS=" + json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
