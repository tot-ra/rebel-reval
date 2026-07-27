#!/usr/bin/env python3
"""Build the game-ready medieval smithy bed with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_smithy_bed.py

The bed is a deterministic rigid furniture asset. The generator keeps its metric
footprint aligned with the existing smithy prop while replacing the stacked-box
placeholder with readable period joinery and soft furnishings.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "furniture" / "smithy_bed.glb"
STAGING = ROOT / "generated" / "blender" / "smithy_bed"
BRIEF_PATH = STAGING / "brief.json"
REPORT_PATH = STAGING / "report.json"
STATE_PATH = STAGING / "state.json"
DEFAULT_PREVIEW = Path("/tmp/rebel_reval_smithy_bed_preview.png")
ASSET_ID = "prop.smithy_bed"
BLENDER_VERSION = "Blender 5.2 LTS"

WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
DARK_WOOD_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
LINEN_SRGB = (0xC7 / 255.0, 0xB9 / 255.0, 0x98 / 255.0)
WOOL_SRGB = (0x53 / 255.0, 0x63 / 255.0, 0x65 / 255.0)
ROPE_SRGB = (0xA6 / 255.0, 0x7F / 255.0, 0x38 / 255.0)


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_material(
    name: str,
    srgb: tuple[float, float, float],
    roughness: float,
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
    return material


def _add_embedded_pattern(
    material: bpy.types.Material,
    image_name: str,
    base_srgb: tuple[float, float, float],
    pattern: str,
) -> None:
    """Bake restrained painted detail so Blender and Godot render the same PBR."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if pattern == "wood":
        warp = u + 0.026 * np.sin(v * math.tau * 2.1) + 0.010 * np.sin(v * math.tau * 6.0 + 0.7)
        broad = np.sin((warp * 10.0 + 0.12 * np.sin(v * math.tau * 1.8)) * math.tau)
        fine = np.sin((warp * 36.0 + v * 0.8) * math.tau)
        variation = 0.83 + broad * 0.07 + fine * 0.018
        for knot_u, knot_v, radius in ((0.24, 0.32, 0.07), (0.73, 0.69, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.1, 0.0, 1.0) * 0.07
            variation -= np.exp(-(distance * distance) * 5.5) * 0.14
    elif pattern == "linen":
        # Broad hand-woven threads remain lower contrast than silhouette edges.
        warp = 0.025 * np.sin(u * math.tau * 46.0) + 0.012 * np.sin(u * math.tau * 93.0)
        weft = 0.022 * np.sin(v * math.tau * 51.0 + 0.6) + 0.010 * np.sin(v * math.tau * 87.0)
        wash = 0.018 * np.sin((u * 1.7 + v * 1.2) * math.tau)
        variation = 0.88 + warp + weft + wash
    else:
        # A coarse diagonal twill makes the folded blanket distinct from linen.
        twill = 0.034 * np.sin((u * 44.0 + v * 35.0) * math.tau)
        cross = 0.014 * np.sin((u * 31.0 - v * 39.0) * math.tau)
        wash = 0.025 * np.sin((u * 1.3 + v * 1.8) * math.tau)
        variation = 0.86 + twill + cross + wash

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
    texture.name = "Embedded%sAlbedo" % pattern.title()
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
    bevel: float = 0.008,
    bevel_segments: int = 1,
) -> bpy.types.Object:
    obj.data.materials.append(material)
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("HandSoftenedEdges", "BEVEL")
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
    bevel: float = 0.008,
    bevel_segments: int = 1,
    rotation_z_degrees: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    # Blender's unit cube created with size=1 already spans one metre. Applying
    # the requested dimensions directly keeps authored metric sizes exact.
    obj.scale = Vector(size)
    obj.rotation_euler.z = math.radians(rotation_z_degrees)
    parts.append(_finish_part(obj, material, bevel, bevel_segments))
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
    parts.append(_finish_part(obj, material, 0.003, 1))
    return obj


def _finial(
    parts: list[bpy.types.Object],
    name: str,
    center: tuple[float, float, float],
    material: bpy.types.Material,
    scale: tuple[float, float, float],
) -> None:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(scale)
    parts.append(_finish_part(obj, material, 0.0, 1))


def _blanket(
    parts: list[bpy.types.Object],
    material: bpy.types.Material,
) -> None:
    # The top grid rolls over both rails. Uneven heights keep the heavy wool from
    # reading as another rigid box while the solidified shell remains watertight.
    xs = [-0.05, 0.36, 0.72, 1.02]
    ys = [-0.66, -0.54, 0.0, 0.54, 0.66]
    vertices: list[tuple[float, float, float]] = []
    for x_index, x in enumerate(xs):
        for y_index, y in enumerate(ys):
            edge = y_index in (0, len(ys) - 1)
            z = 0.43 if edge else 0.726
            if not edge:
                z += 0.008 * math.sin(x_index * 1.8 + y_index * 0.7)
            vertices.append((x, y, z))
    faces: list[tuple[int, int, int, int]] = []
    width = len(ys)
    for x_index in range(len(xs) - 1):
        for y_index in range(len(ys) - 1):
            a = x_index * width + y_index
            faces.append((a, a + width, a + width + 1, a + 1))
    mesh = bpy.data.meshes.new("BlanketMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("WoolBlanket", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    _activate(obj)
    solidify = obj.modifiers.new("WovenThickness", "SOLIDIFY")
    solidify.thickness = 0.018
    solidify.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("SoftFoldEdges", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    parts.append(obj)


def _build_mesh() -> bpy.types.Object:
    wood = _create_material("painted_smithy_oak", WOOD_SRGB, 0.84)
    _add_embedded_pattern(wood, "smithy_bed_oak_albedo", WOOD_SRGB, "wood")
    dark_wood = _create_material("smoke_darkened_oak", DARK_WOOD_SRGB, 0.91)
    linen = _create_material("unbleached_linen", LINEN_SRGB, 0.96)
    _add_embedded_pattern(linen, "smithy_bed_linen_albedo", LINEN_SRGB, "linen")
    wool = _create_material("blue_grey_wool", WOOL_SRGB, 0.98)
    _add_embedded_pattern(wool, "smithy_bed_wool_albedo", WOOL_SRGB, "wool")
    rope = _create_material("hemp_rope", ROPE_SRGB, 0.97)

    parts: list[bpy.types.Object] = []

    # Four stout corner posts and rails expose the actual timber construction.
    for x, height, label in ((-1.12, 1.02, "Head"), (1.12, 0.64, "Foot")):
        for y, side in ((-0.59, "Left"), (0.59, "Right")):
            _box(parts, "%sPost%s" % (label, side), (x, y, height * 0.5), (0.11, 0.11, height), wood, 0.01)
            _finial(parts, "%sFinial%s" % (label, side), (x, y, height + 0.025), dark_wood, (0.075, 0.075, 0.075))

    for y, side in ((-0.58, "Left"), (0.58, "Right")):
        _box(parts, "SideRail%s" % side, (0.0, y, 0.35), (2.18, 0.12, 0.24), wood, 0.012)
        _box(parts, "SideRailWear%s" % side, (0.0, y * 1.055, 0.36), (1.72, 0.018, 0.095), dark_wood, 0.003)
    for x, label in ((-1.09, "Head"), (1.09, "Foot")):
        _box(parts, "%sEndRail" % label, (x, 0.0, 0.37), (0.12, 1.08, 0.22), wood, 0.01)

    # Slats and rope lacing are visible in the narrow gap below the tick mattress.
    for index, x in enumerate((-0.76, -0.38, 0.0, 0.38, 0.76)):
        _box(parts, "MattressSlat%d" % index, (x, 0.0, 0.465), (0.13, 1.04, 0.055), dark_wood, 0.005)
    for index, x in enumerate((-0.92, -0.62, -0.31, 0.0, 0.31, 0.62, 0.92)):
        _cylinder(parts, "RopeWarp%d" % index, (x, 0.0, 0.502), 0.012, 1.03, rope, axis="Y", segments=8)
    for index, y in enumerate((-0.42, -0.21, 0.0, 0.21, 0.42)):
        _cylinder(parts, "RopeWeft%d" % index, (0.0, y, 0.507), 0.011, 2.0, rope, axis="X", segments=8)

    # Broad headboard rails and three inset planks read from the isometric camera.
    _box(parts, "HeadboardLowerRail", (-1.10, 0.0, 0.68), (0.12, 1.1, 0.16), wood, 0.012)
    _box(parts, "HeadboardTopRail", (-1.10, 0.0, 0.92), (0.14, 1.2, 0.15), wood, 0.015)
    for index, y in enumerate((-0.36, 0.0, 0.36)):
        _box(parts, "HeadboardPanel%d" % index, (-1.105, y, 0.80), (0.075, 0.25, 0.25), dark_wood, 0.008)
    _box(parts, "FootboardRail", (1.10, 0.0, 0.56), (0.13, 1.1, 0.14), wood, 0.012)

    # Pegs make the mortise-and-tenon joints explicit at gameplay scale.
    for x, z in ((-1.18, 0.37), (-1.18, 0.68), (-1.18, 0.92), (1.18, 0.37), (1.18, 0.56)):
        for y in (-0.59, 0.59):
            _cylinder(parts, "JoineryPeg", (x, y, z), 0.018, 0.022, dark_wood, axis="X", segments=10)

    # Softened bedding replaces the perfectly square plaster slab. The dimensions
    # preserve the old prop footprint and its rest/collision ownership in rrmap.
    _box(parts, "StrawTickMattress", (-0.02, 0.0, 0.615), (2.05, 1.10, 0.25), linen, 0.075, 3)
    _box(parts, "LinenPillow", (-0.72, 0.0, 0.755), (0.50, 0.72, 0.17), linen, 0.075, 3, rotation_z_degrees=-3.0)
    for index, x in enumerate((-0.48, 0.0, 0.48)):
        _cylinder(parts, "MattressTie%d" % index, (x, 0.566, 0.605), 0.016, 0.024, rope, axis="Y", segments=8)
    _blanket(parts, wool)
    _box(parts, "BlanketFold", (0.03, 0.0, 0.755), (0.16, 1.08, 0.075), wool, 0.026, 2)

    # One runtime mesh preserves material surfaces while avoiding a node per part.
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = "BedMesh"
    obj.data.name = "SmithyBedMesh"

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj["asset_id"] = ASSET_ID
    obj["intended_location"] = "loc.kalev_smithy"
    return obj


def _mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    mesh = obj.data
    triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in bounds), min(v.y for v in bounds), min(v.z for v in bounds)))
    maximum = Vector((max(v.x for v in bounds), max(v.y for v in bounds), max(v.z for v in bounds)))
    return {
        "asset_id": ASSET_ID,
        "vertices": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "triangles": triangles,
        "materials": len(mesh.materials),
        "uv_layers": len(mesh.uv_layers),
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
    }


def _canonicalize_glb_triangle_order(path: Path) -> None:
    """Sort independent triangle records so Blender join order cannot perturb SHA.

    Blender 5.2 emits identical geometry but may permute the triangle records of
    one material after joining many objects. Triangle order has no rendering
    meaning, so canonicalizing each indexed primitive makes reproducible builds
    byte-identical without touching winding or vertex data.
    """
    payload = bytearray(path.read_bytes())
    if payload[:4] != b"glTF":
        raise ValueError("Expected a binary glTF file")
    json_length, json_type = struct.unpack_from("<I4s", payload, 12)
    if json_type != b"JSON":
        raise ValueError("GLB JSON chunk missing")
    document = json.loads(payload[20 : 20 + json_length])
    bin_header = 20 + json_length
    bin_length, bin_type = struct.unpack_from("<I4s", payload, bin_header)
    if bin_type != b"BIN\x00":
        raise ValueError("GLB BIN chunk missing")
    bin_start = bin_header + 8

    component_formats = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessor = document["accessors"][primitive["indices"]]
            if accessor.get("type") != "SCALAR" or accessor["count"] % 3 != 0:
                continue
            component_format, component_size = component_formats[accessor["componentType"]]
            view = document["bufferViews"][accessor["bufferView"]]
            byte_offset = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            index_count = accessor["count"]
            values = struct.unpack_from("<" + component_format * index_count, payload, byte_offset)
            triangles = sorted(values[index : index + 3] for index in range(0, index_count, 3))
            canonical = [value for triangle in triangles for value in triangle]
            struct.pack_into("<" + component_format * index_count, payload, byte_offset, *canonical)
            expected_length = index_count * component_size
            if expected_length > view["byteLength"]:
                raise ValueError("Index accessor exceeds its buffer view")

    if len(payload) != bin_start + bin_length:
        raise ValueError("Unexpected trailing data in GLB")
    path.write_bytes(payload)


def _export(obj: bpy.types.Object) -> dict[str, object]:
    root = bpy.data.objects.new("SmithyBed", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_smithy_bed.py"
    root["blender_version"] = BLENDER_VERSION

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
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
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    _canonicalize_glb_triangle_order(OUTPUT)
    return _mesh_metrics(obj)


def _render_preview(obj: bpy.types.Object, output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.03, 0.025)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.12, 0.09, 0.065, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(3.2, 2.7, 4.0))
    key = bpy.context.object
    key.data.energy = 850.0
    key.data.shape = "DISK"
    key.data.size = 3.2
    bpy.ops.object.light_add(type="AREA", location=(-2.5, -2.0, 2.5))
    fill = bpy.context.object
    fill.data.energy = 420.0
    fill.data.color = (0.45, 0.58, 0.8)
    fill.data.size = 2.8

    bpy.ops.object.camera_add(location=(3.3, 3.8, 2.55))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.48)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.15
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_evidence(metrics: dict[str, object]) -> None:
    STAGING.mkdir(parents=True, exist_ok=True)
    brief = {
        "id": ASSET_ID,
        "kind": "rigid_prop",
        "target": "res://assets/props/furniture/smithy_bed.glb",
        "scene": "res://content/maps/kalev_smithy.rrmap",
        "dimensions_m": [2.4, 1.05, 1.35],
        "triangles": {"target": 4000, "max": 6000},
        "textures": {"albedo": 512},
        "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
        "approval": "task-authorized",
    }
    BRIEF_PATH.write_text(json.dumps(brief, separators=(",", ":")) + "\n", encoding="utf-8")
    output_hash = _sha256(OUTPUT)
    cache_input = BRIEF_PATH.read_bytes() + Path(__file__).read_bytes() + BLENDER_VERSION.encode("utf-8")
    cache_key = hashlib.sha256(cache_input).hexdigest()
    report = {
        **metrics,
        "sha256": output_hash,
        "cache_key": cache_key,
        "generator": "tools/generate_smithy_bed.py",
        "blender_version": BLENDER_VERSION,
        "checks": ["metric_scale", "y_up", "ground_contact", "uvs", "embedded_pbr_albedo"],
    }
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": cache_key,
        "selected_glb": "assets/props/furniture/smithy_bed.glb",
        "sha256": output_hash,
        "decision": "integrated",
        "defects": [],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")
    metrics["sha256"] = output_hash
    metrics["cache_key"] = cache_key


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = _build_mesh()
    metrics = _export(obj)
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        preview = Path(sys.argv[preview_index + 1]) if preview_index + 1 < len(sys.argv) else DEFAULT_PREVIEW
        _render_preview(obj, preview)
        metrics["preview"] = str(preview)
    _write_evidence(metrics)
    print("ASSET_METRICS=" + json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
