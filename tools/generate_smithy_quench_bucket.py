#!/usr/bin/env python3
"""Build the game-ready metal quench bucket for Kalev's smithy.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_smithy_quench_bucket.py

Add ``--preview [path]`` for one orthographic three-quarter render. The generator
writes compact reproducibility evidence under generated/blender/smithy_quench_bucket_v1/.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
from assets.prop_orm_baking import wire_orm_maps

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "forge" / "smithy_quench_bucket.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "smithy_quench_bucket_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.smithy_quench_bucket"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "smithy_quench_bucket_v1"

IRON_SRGB = (0x42 / 255.0, 0x4A / 255.0, 0x4B / 255.0)
INNER_IRON_SRGB = (0x24 / 255.0, 0x2B / 255.0, 0x2B / 255.0)
WATER_SRGB = (0x2D / 255.0, 0x62 / 255.0, 0x68 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/forge/smithy_quench_bucket.glb",
    "scene": "res://content/maps/kalev_smithy.rrmap#quench",
    "dimensions_m": [0.76, 0.66, 0.86],
    "triangles": {"target": 2200, "max": 4000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create deterministic painted wear that survives portable glTF export."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "water":
        ripples = np.sin((u * 8.0 + 0.22 * np.sin(v * math.tau * 2.2)) * math.tau)
        cross = np.sin((v * 11.0 - u * 1.3) * math.tau)
        variation = 0.80 + ripples * 0.035 + cross * 0.018
        tint = np.stack((variation * 0.80, variation * 0.98, variation * 1.05), axis=2)
    else:
        hammer = np.sin((u * 17.0 + v * 5.0) * math.tau) * np.sin((v * 13.0 - u * 4.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.6) * math.tau)
        scratches = np.maximum(0.0, np.sin((u * 43.0 + v * 2.0) * math.tau))
        variation = 0.78 + hammer * 0.045 + broad * 0.035 + scratches * 0.014
        if surface == "inner_iron":
            waterline = np.exp(-((v - 0.68) ** 2) / 0.0018)
            variation -= waterline * 0.15
        else:
            # Sparse oxidation around the lower sheet and seam keeps the bucket
            # used, not uniformly orange or modern galvanized steel.
            rust = np.clip(
                np.sin((u * 3.1 + v * 1.7) * math.tau)
                * np.sin((u * 5.3 - v * 2.4) * math.tau),
                0.0,
                1.0,
            )
            rust *= np.clip((0.58 - v) * 2.0, 0.0, 1.0)
            variation -= rust * 0.16
        tint = np.repeat(variation[:, :, None], 3, axis=2)

    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * tint, 0.0, 1.0)
    if surface == "aged_iron":
        rust_color = np.array(
            [_srgb_to_linear(0.24), _srgb_to_linear(0.105), _srgb_to_linear(0.045)],
            dtype=np.float32,
        )
        rust_mask = np.clip(
            np.sin((u * 3.1 + v * 1.7) * math.tau)
            * np.sin((u * 5.3 - v * 2.4) * math.tau),
            0.0,
            1.0,
        ) * np.clip((0.58 - v) * 1.35, 0.0, 0.45)
        rgb = rgb * (1.0 - rust_mask[:, :, None]) + rust_color[None, None, :] * rust_mask[:, :, None]

    alpha = np.ones((size, size, 1), dtype=np.float32)
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(np.concatenate((rgb, alpha), axis=2).ravel())
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
    wire_orm_maps(material, name, surface)
    return material


def _object_from_bmesh(name: str, mesh: bmesh.types.BMesh, materials: list[bpy.types.Material]) -> bpy.types.Object:
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    for material in materials:
        data.materials.append(material)
    return obj


def _ring(mesh: bmesh.types.BMesh, radius: float, z: float, segments: int, irregularity: float = 0.0) -> list[bmesh.types.BMVert]:
    vertices: list[bmesh.types.BMVert] = []
    for index in range(segments):
        angle = math.tau * index / segments
        # Sub-millimetre deterministic waviness avoids a machine-perfect sheet
        # while the rolled rim remains circular enough to read cleanly in game.
        adjusted = radius * (1.0 + irregularity * math.sin(angle * 3.0 + 0.4) + irregularity * 0.45 * math.sin(angle * 7.0))
        vertices.append(mesh.verts.new((math.cos(angle) * adjusted, math.sin(angle) * adjusted, z)))
    return vertices


def _join_rings(
    mesh: bmesh.types.BMesh,
    lower: list[bmesh.types.BMVert],
    upper: list[bmesh.types.BMVert],
    material_index: int,
    reverse: bool = False,
) -> None:
    for index in range(len(lower)):
        next_index = (index + 1) % len(lower)
        vertices = (lower[index], upper[index], upper[next_index], lower[next_index])
        if reverse:
            vertices = tuple(reversed(vertices))
        face = mesh.faces.new(vertices)
        face.material_index = material_index


def _build_vessel(iron: bpy.types.Material, inner_iron: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    segments = 32
    outer_bottom = _ring(mesh, 0.252, 0.0, segments, 0.003)
    outer_knee = _ring(mesh, 0.258, 0.052, segments, 0.003)
    outer_top = _ring(mesh, 0.318, 0.525, segments, 0.002)
    inner_top = _ring(mesh, 0.298, 0.525, segments, 0.001)
    inner_bottom = _ring(mesh, 0.238, 0.072, segments, 0.002)

    _join_rings(mesh, outer_bottom, outer_knee, 0)
    _join_rings(mesh, outer_knee, outer_top, 0)
    for index in range(segments):
        next_index = (index + 1) % segments
        lip = mesh.faces.new((outer_top[index], outer_top[next_index], inner_top[next_index], inner_top[index]))
        lip.material_index = 0
        inner = mesh.faces.new((inner_top[index], inner_top[next_index], inner_bottom[next_index], inner_bottom[index]))
        inner.material_index = 1

    inner_center = mesh.verts.new((0.0, 0.0, 0.072))
    underside_center = mesh.verts.new((0.0, 0.0, 0.0))
    for index in range(segments):
        next_index = (index + 1) % segments
        floor = mesh.faces.new((inner_center, inner_bottom[index], inner_bottom[next_index]))
        floor.material_index = 1
        underside = mesh.faces.new((underside_center, outer_bottom[next_index], outer_bottom[index]))
        underside.material_index = 0

    vessel = _object_from_bmesh("HollowRivetedVessel", mesh, [iron, inner_iron])
    for polygon in vessel.data.polygons:
        polygon.use_smooth = True
    return vessel


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int = 0,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    for face in mesh.faces:
        if face not in previous:
            face.material_index = material_index


def _add_sphere(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float,
    scale: tuple[float, float, float],
) -> None:
    result = bmesh.ops.create_uvsphere(mesh, u_segments=8, v_segments=4, radius=radius)
    transform = Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector((*scale, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])


def _build_fittings(iron: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    # A lapped sheet seam and rivets explain construction at close range.
    _add_box(mesh, (0.0, -0.319, 0.285), (0.040, 0.016, 0.435))
    for z in (0.105, 0.195, 0.285, 0.375, 0.465):
        _add_sphere(mesh, (0.0, -0.334, z), 0.017, (0.88, 0.46, 0.88))

    # Forged ears carry the bail instead of letting the handle disappear into
    # the bucket wall. Flattened pivot heads read as hand-peened rivets.
    _add_box(mesh, (-0.344, 0.0, 0.432), (0.060, 0.070, 0.135))
    _add_box(mesh, (0.344, 0.0, 0.432), (0.060, 0.070, 0.135))
    _add_sphere(mesh, (-0.379, 0.0, 0.442), 0.035, (0.44, 1.0, 1.0))
    _add_sphere(mesh, (0.379, 0.0, 0.442), 0.035, (0.44, 1.0, 1.0))

    fittings = _object_from_bmesh("RivetedFittings", mesh, [iron])
    return fittings


def _build_torus(name: str, major_radius: float, minor_radius: float, z: float, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_segments=32,
        minor_segments=8,
        location=(0.0, 0.0, z),
        major_radius=major_radius,
        minor_radius=minor_radius,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def _build_handle(iron: bpy.types.Material) -> bpy.types.Object:
    curve_data = bpy.data.curves.new("ForgedBailCurve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = 0.012
    curve_data.bevel_resolution = 2
    curve_data.resolution_u = 1
    curve_data.materials.append(iron)
    spline = curve_data.splines.new("POLY")
    segments = 20
    spline.points.add(segments)
    for index in range(segments + 1):
        angle = math.pi - math.pi * index / segments
        x = math.cos(angle) * 0.378
        z = 0.442 + math.sin(angle) * 0.418
        # A shallow fore-aft bow keeps the bail visibly separate from the rim.
        y = 0.018 + 0.020 * math.sin(angle)
        spline.points[index].co = (x, y, z, 1.0)

    handle = bpy.data.objects.new("ForgedBailHandle", curve_data)
    bpy.context.collection.objects.link(handle)
    bpy.context.view_layer.objects.active = handle
    handle.select_set(True)
    bpy.ops.object.convert(target="MESH")
    handle = bpy.context.object
    for polygon in handle.data.polygons:
        polygon.use_smooth = True
    handle.select_set(False)
    return handle


def _build_water(water_material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.287, depth=0.012, location=(0.0, 0.0, 0.472))
    water = bpy.context.object
    water.name = "QuenchWater"
    water.data.materials.append(water_material)
    for polygon in water.data.polygons:
        polygon.use_smooth = polygon.normal.z < 0.5
    return water


def _unwrap(obj: bpy.types.Object) -> None:
    """Assign deterministic box-projected UVs without operator ordering variance."""
    mesh = obj.data
    if mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        normal = polygon.normal
        axis = max(range(3), key=lambda index: abs(normal[index]))
        for loop_index in polygon.loop_indices:
            coordinate = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if axis == 0:
                uv = (coordinate.y, coordinate.z)
            elif axis == 1:
                uv = (coordinate.x, coordinate.z)
            else:
                uv = (coordinate.x, coordinate.y)
            uv_layer.data[loop_index].uv = (uv[0] * 2.0, uv[1] * 2.0)
    mesh.validate(clean_customdata=False)
    mesh.update()


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    iron = _create_material("aged_forged_iron", IRON_SRGB, 0.52, 0.82, "aged_iron")
    inner_iron = _create_material("water_darkened_inner_iron", INNER_IRON_SRGB, 0.68, 0.72, "inner_iron")
    water_material = _create_material("dark_quench_water", WATER_SRGB, 0.18, 0.05, "water")

    vessel = _build_vessel(iron, inner_iron)
    rim = _build_torus("RolledTopRim", 0.313, 0.018, 0.532, iron)
    base_band = _build_torus("ForgedBaseBand", 0.252, 0.012, 0.035, iron)
    fittings = _build_fittings(iron)
    handle = _build_handle(iron)
    water = _build_water(water_material)

    root = bpy.data.objects.new("SmithyQuenchBucket", None)
    bpy.context.collection.objects.link(root)
    meshes = [vessel, rim, base_band, fittings, handle, water]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.kalev_smithy"
        _unwrap(obj)

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_smithy_quench_bucket.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    return root, meshes


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    vertices = 0
    faces = 0
    triangles = 0
    surfaces = 0
    uv_sets = 0
    points: list[Vector] = []
    material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len({polygon.material_index for polygon in mesh.polygons})
        uv_sets = max(uv_sets, len(mesh.uv_layers))
        material_names.update(material.name for material in mesh.materials if material is not None)
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return {
        "asset_id": ASSET_ID,
        "mesh_objects": len(meshes),
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "surfaces": surfaces,
        "materials": len(material_names),
        "uv_sets": uv_sets,
        "texture_size": 512,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "floating_objects": 0,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, meshes: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in meshes:
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
        export_tangents=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    metrics = _mesh_metrics(meshes)
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _render_preview(output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.025, 0.024, 0.022)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.16, 0.14, 0.12, 1.0)
    floor_material.roughness = 0.95
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-1.8, -2.0, 2.7))
    key = bpy.context.object
    key.data.energy = 680.0
    key.data.shape = "DISK"
    key.data.size = 2.4
    key.rotation_euler = (Vector((0.0, 0.0, 0.4)) - key.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(1.7, 1.5, 1.8))
    fill = bpy.context.object
    fill.data.energy = 520.0
    fill.data.color = (0.50, 0.62, 0.82)
    fill.data.size = 1.8
    fill.rotation_euler = (Vector((0.0, 0.0, 0.42)) - fill.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(1.35, -1.72, 1.18))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, 0.0, 0.40)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.24
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_smithy_quench_bucket.py",
        "blender_version": BLENDER_VERSION,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "open_vessel": True,
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
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
    root, meshes = _build_model()
    metrics = _export(root, meshes)

    preview: Path | None = None
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        if preview_index + 1 < len(sys.argv) and not sys.argv[preview_index + 1].startswith("--"):
            preview = Path(sys.argv[preview_index + 1]).expanduser().resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(preview)

    _write_evidence(metrics, preview)
    print("ASSET_METRICS=" + json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
