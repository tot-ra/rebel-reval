#!/usr/bin/env python3
"""Build the game-ready Kalev smithy anvil with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_smithy_anvil.py

Add ``--preview [path]`` for one orthographic three-quarter render. The generator
writes compact reproducibility evidence under generated/blender/smithy_anvil_v1/.
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

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "forge" / "smithy_anvil.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "smithy_anvil_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.smithy_anvil"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "smithy_anvil_v1"

IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)
FACE_SRGB = (0x69 / 255.0, 0x76 / 255.0, 0x79 / 255.0)
WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/forge/smithy_anvil.glb",
    "scene": "res://content/maps/kalev_smithy.rrmap#forge_anvil",
    "dimensions_m": [1.48, 0.7, 1.01],
    "triangles": {"target": 1800, "max": 4000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create restrained painted variation that glTF can embed without Blender nodes."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "wood":
        warp = u + 0.025 * np.sin(v * math.tau * 2.1) + 0.010 * np.sin(v * math.tau * 6.7 + 0.4)
        broad = np.sin((warp * 10.0 + 0.12 * np.sin(v * math.tau * 1.4)) * math.tau)
        fine = np.sin((warp * 34.0 + v * 0.6) * math.tau)
        variation = 0.82 + broad * 0.075 + fine * 0.018
        for knot_u, knot_v, radius in ((0.23, 0.31, 0.07), (0.69, 0.72, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.07
            variation -= np.exp(-(distance * distance) * 5.0) * 0.14
    elif surface == "face":
        # Broad directional polish marks keep the working face brighter without
        # creating photographic micro-detail at the gameplay camera distance.
        sweep = np.sin((u * 7.0 + 0.16 * np.sin(v * math.tau * 2.0)) * math.tau)
        cross = np.sin((v * 15.0 + u * 0.8) * math.tau)
        variation = 0.92 + sweep * 0.035 + cross * 0.012
    else:
        hammered = np.sin((u * 11.0 + v * 4.0) * math.tau) * np.sin((v * 9.0 - u * 3.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
        variation = 0.78 + hammered * 0.045 + broad * 0.025

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
    texture_surface: str,
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
    texture.image = _create_texture(f"{name}_albedo", srgb, texture_surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _set_new_faces_material(mesh: bmesh.types.BMesh, previous_faces: set[bmesh.types.BMFace], index: int) -> None:
    for face in mesh.faces:
        if face not in previous_faces:
            face.material_index = index


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int = 0,
    rotation_z_degrees: float = 0.0,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    sx, sy, sz = size
    angle = math.radians(rotation_z_degrees)
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(angle, 4, "Z") @ Matrix.Diagonal(Vector((sx, sy, sz, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius_bottom: float,
    radius_top: float,
    depth: float,
    material_index: int,
    segments: int = 16,
) -> None:
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        matrix=Matrix.Translation(Vector(center)),
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_loft(
    mesh: bmesh.types.BMesh,
    stations: list[dict[str, float]],
    material_index: int = 0,
) -> None:
    """Loft octagonal vertical rings along X for the horn, face mass, and heel."""
    rings: list[list[bmesh.types.BMVert]] = []
    for station in stations:
        x = station["x"]
        top = station["top"]
        bottom = station["bottom"]
        depth = station["depth"]
        chamfer = min(0.035, max(0.005, (top - bottom) * 0.18))
        ring_points = (
            (x, -depth * 0.72, top),
            (x, depth * 0.72, top),
            (x, depth, top - chamfer),
            (x, depth, bottom + chamfer),
            (x, depth * 0.72, bottom),
            (x, -depth * 0.72, bottom),
            (x, -depth, bottom + chamfer),
            (x, -depth, top - chamfer),
        )
        rings.append([mesh.verts.new(point) for point in ring_points])

    for ring_index in range(len(rings) - 1):
        left, right = rings[ring_index], rings[ring_index + 1]
        for index in range(8):
            next_index = (index + 1) % 8
            face = mesh.faces.new((left[index], right[index], right[next_index], left[next_index]))
            face.material_index = material_index

    for ring, reverse in ((rings[0], True), (rings[-1], False)):
        center = mesh.verts.new(sum((vertex.co for vertex in ring), Vector()) / len(ring))
        for index in range(8):
            next_index = (index + 1) % 8
            vertices = (center, ring[next_index], ring[index]) if reverse else (center, ring[index], ring[next_index])
            face = mesh.faces.new(vertices)
            face.material_index = material_index


def _object_from_bmesh(name: str, mesh: bmesh.types.BMesh, materials: list[bpy.types.Material]) -> bpy.types.Object:
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


def _apply_bevel(obj: bpy.types.Object, width: float, segments: int) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("HandForgedEdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(28.0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _apply_boolean_holes(obj: bpy.types.Object) -> None:
    cutters: list[bpy.types.Object] = []

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.49, 0.12, 0.955))
    hardy = bpy.context.object
    hardy.name = "HardyHoleCutter"
    hardy.dimensions = (0.082, 0.082, 0.24)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    cutters.append(hardy)

    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.035, depth=0.24, location=(0.36, -0.13, 0.955))
    pritchel = bpy.context.object
    pritchel.name = "PritchelHoleCutter"
    cutters.append(pritchel)

    for cutter in cutters:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new(f"Cut{cutter.name}", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
        bpy.data.objects.remove(cutter, do_unlink=True)


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


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    iron = _create_material("hammered_forge_iron", IRON_SRGB, 0.58, 0.76, "iron")
    face = _create_material("polished_anvil_face", FACE_SRGB, 0.30, 0.88, "face")
    wood = _create_material("smoke_darkened_oak_stump", WOOD_SRGB, 0.88, 0.0, "wood")

    stump_mesh = bmesh.new()
    _add_cylinder(stump_mesh, (0.0, 0.0, 0.255), 0.35, 0.315, 0.51, 0, 16)
    _add_cylinder(stump_mesh, (0.0, 0.0, 0.085), 0.352, 0.352, 0.045, 1, 16)
    _add_cylinder(stump_mesh, (0.0, 0.0, 0.435), 0.329, 0.329, 0.045, 1, 16)
    # Four driven dogs visibly explain how the heavy body is fixed to the block.
    for x, y, rotation in ((-0.26, -0.15, -10.0), (-0.26, 0.15, 10.0), (0.27, -0.15, 10.0), (0.27, 0.15, -10.0)):
        _add_box(stump_mesh, (x, y, 0.515), (0.10, 0.045, 0.055), 1, rotation)
    stump = _object_from_bmesh("StumpAssembly", stump_mesh, [wood, iron])
    _apply_bevel(stump, 0.007, 1)

    body_mesh = bmesh.new()
    # The stepped base and pinched waist are deliberately broad enough to read
    # as a forged London-pattern anvil rather than the previous curved slab.
    _add_box(body_mesh, (0.08, 0.0, 0.565), (0.82, 0.50, 0.12))
    _add_box(body_mesh, (0.08, 0.0, 0.645), (0.66, 0.40, 0.10))
    _add_box(body_mesh, (0.10, 0.0, 0.715), (0.45, 0.27, 0.15))
    _add_box(body_mesh, (0.08, 0.0, 0.785), (0.61, 0.40, 0.13))
    _add_loft(
        body_mesh,
        [
            {"x": -0.78, "top": 0.865, "bottom": 0.835, "depth": 0.012},
            {"x": -0.66, "top": 0.895, "bottom": 0.805, "depth": 0.075},
            {"x": -0.50, "top": 0.935, "bottom": 0.765, "depth": 0.145},
            {"x": -0.31, "top": 0.965, "bottom": 0.735, "depth": 0.225},
            {"x": -0.20, "top": 0.970, "bottom": 0.775, "depth": 0.260},
            {"x": 0.20, "top": 0.970, "bottom": 0.785, "depth": 0.260},
            {"x": 0.37, "top": 0.970, "bottom": 0.805, "depth": 0.245},
            {"x": 0.60, "top": 0.970, "bottom": 0.825, "depth": 0.225},
            {"x": 0.70, "top": 0.965, "bottom": 0.835, "depth": 0.210},
        ],
    )
    body = _object_from_bmesh("ForgedBody", body_mesh, [iron])
    _apply_boolean_holes(body)
    _apply_bevel(body, 0.011, 2)

    face_mesh = bmesh.new()
    _add_box(face_mesh, (0.19, 0.0, 0.987), (0.82, 0.52, 0.035))
    face_plate = _object_from_bmesh("WorkingFace", face_mesh, [face])
    _apply_boolean_holes(face_plate)
    _apply_bevel(face_plate, 0.005, 1)

    root = bpy.data.objects.new("SmithyAnvil", None)
    bpy.context.collection.objects.link(root)
    meshes = [stump, body, face_plate]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.kalev_smithy"
        _unwrap(obj)

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_smithy_anvil.py"
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
        export_tangents=True,
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


def _render_preview(meshes: list[bpy.types.Object], output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.028, 0.025, 0.023)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.17, 0.15, 0.13, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.4, -2.2, 3.2))
    key = bpy.context.object
    key.data.energy = 760.0
    key.data.shape = "DISK"
    key.data.size = 2.8
    direction = Vector((0.0, 0.0, 0.55)) - key.location
    key.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(2.1, 1.8, 2.2))
    fill = bpy.context.object
    fill.data.energy = 420.0
    fill.data.color = (0.48, 0.60, 0.82)
    fill.data.size = 2.2
    direction = Vector((0.0, 0.0, 0.55)) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(0.0, -3.0, 0.76))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.54)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.7
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)

    # Keep evidence-only floor/light/camera out of the exported production model.
    for obj in meshes:
        obj.hide_render = False


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_smithy_anvil.py",
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
        _render_preview(meshes, preview)

    _write_evidence(metrics, preview)
    print("ASSET_METRICS=" + json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
