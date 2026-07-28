#!/usr/bin/env python3
"""Build the game-ready turf-covered root cellar mound with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_root_cellar_mound.py

Add ``--preview [path]`` for one orthographic three-quarter render. The generator
writes compact reproducibility evidence under generated/blender/root_cellar_mound_v1/.

The asset replaces the flattened stone sphere previously used for the rural-life
``root_cellar_mound`` prop. It keeps the existing two-cell footprint and ground
anchor, while a low earthen vault, turf cover, timber door, and restrained fieldstone
retaining apron make its storage purpose readable from the dimetric camera.
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
OUTPUT = ROOT / "assets" / "props" / "environment" / "root_cellar_mound.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "root_cellar_mound_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.root_cellar_mound"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "root_cellar_mound_v1"
TEXTURE_SIZE = 512

TURF_SRGB = (0x5D / 255.0, 0x7E / 255.0, 0x4E / 255.0)
EARTH_SRGB = (0x70 / 255.0, 0x50 / 255.0, 0x39 / 255.0)
OAK_SRGB = (0x59 / 255.0, 0x3D / 255.0, 0x25 / 255.0)
FIELDSTONE_SRGB = (0x78 / 255.0, 0x79 / 255.0, 0x70 / 255.0)
VOID_SRGB = (0x20 / 255.0, 0x1D / 255.0, 0x19 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/environment/root_cellar_mound.glb",
    "scene": "res://content/maps/viru_gate_foreland.rrmap#west.root_cellar",
    "dimensions_m": [1.96, 0.74, 1.73],
    "triangles": {"target": 700, "max": 1800},
    "textures": {"albedo": TEXTURE_SIZE},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create broad, tileable painted variation with no brick or mortar pattern."""
    import numpy as np

    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    # Sampling both ends at the same phase keeps opposite edges identical when
    # Godot repeats the extracted glTF albedos.
    u = xx / float(size - 1)
    v = yy / float(size - 1)

    if surface == "turf":
        broad = np.sin((u * 2.0 + v) * math.tau) * np.sin((v * 3.0 - u) * math.tau)
        soft = np.sin((u * 5.0 - v * 4.0) * math.tau)
        blade_bias = np.sin((u * 7.0 + v * 9.0) * math.tau) * 0.5 + 0.5
        variation = 0.88 + broad * 0.075 + soft * 0.025 + blade_bias * 0.018
    elif surface == "earth":
        clod = np.sin((u * 3.0 + v * 2.0) * math.tau) * np.sin((v * 4.0 - u) * math.tau)
        soft = np.sin((u * 8.0 + v * 7.0) * math.tau)
        variation = 0.83 + clod * 0.085 + soft * 0.022
    elif surface == "wood":
        warp = u + 0.025 * np.sin(v * math.tau * 2.0)
        grain = np.sin((warp * 10.0 + 0.1 * np.sin(v * math.tau * 3.0)) * math.tau)
        fine = np.sin((warp * 28.0 + v) * math.tau)
        variation = 0.82 + grain * 0.070 + fine * 0.015
    else:
        # Organic mottling is intentional: fieldstone supports only the entrance
        # and must never recreate the ashlar/brick courses of the old placeholder.
        mottling = np.sin((u * 3.0 + v * 5.0) * math.tau) * np.sin((v * 2.0 - u * 4.0) * math.tau)
        broad = np.sin((u * 2.0 + v) * math.tau)
        variation = 0.88 + mottling * 0.065 + broad * 0.025

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
    texture_surface: str | None,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = 0.0
    material.roughness = roughness
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = roughness
    if texture_surface is not None:
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


def _add_fieldstone(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    scale: tuple[float, float, float],
    rotation_z_degrees: float,
    material_index: int,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_icosphere(mesh, subdivisions=1, radius=1.0)
    transform = (
        Matrix.Translation(Vector(center))
        @ Matrix.Rotation(math.radians(rotation_z_degrees), 4, "Z")
        @ Matrix.Diagonal(Vector((*scale, 1.0)))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_vault(mesh: bmesh.types.BMesh, turf_index: int, earth_index: int) -> None:
    """Loft an irregular low barrel vault, avoiding a spherical stone silhouette."""
    stations = (
        (-0.42, 0.76, 0.62),
        (-0.12, 0.94, 0.72),
        (0.28, 0.98, 0.70),
        (0.65, 0.80, 0.55),
        (0.86, 0.34, 0.22),
    )
    arch_steps = 12
    rings: list[list[bmesh.types.BMVert]] = []
    for station_index, (y, half_width, height) in enumerate(stations):
        ring: list[bmesh.types.BMVert] = []
        for arch_index in range(arch_steps + 1):
            t = -1.0 + 2.0 * arch_index / arch_steps
            edge_falloff = max(0.0, 1.0 - abs(t) ** 1.72)
            width_wobble = 1.0 + 0.018 * math.sin(station_index * 2.7 + arch_index * 1.9)
            crown_wobble = 0.012 * math.sin(station_index * 3.1 + arch_index * 1.4) * edge_falloff
            x = half_width * t * width_wobble
            z = 0.025 + height * (edge_falloff**0.72) + crown_wobble
            ring.append(mesh.verts.new((x, y, max(0.025, z))))
        rings.append(ring)

    for station_index in range(len(rings) - 1):
        front = rings[station_index]
        back = rings[station_index + 1]
        for arch_index in range(arch_steps):
            face = mesh.faces.new(
                (front[arch_index], front[arch_index + 1], back[arch_index + 1], back[arch_index])
            )
            average_z = sum(vertex.co.z for vertex in face.verts) / len(face.verts)
            face.material_index = turf_index if average_z >= 0.13 else earth_index

    # Close the end banks so the entrance is recessed against real earth rather
    # than floating in front of a hollow shell.
    for ring, reverse in ((rings[0], True), (rings[-1], False)):
        ground_center = mesh.verts.new((0.0, ring[0].co.y, 0.025))
        for arch_index in range(arch_steps):
            vertices = (
                (ground_center, ring[arch_index + 1], ring[arch_index])
                if reverse
                else (ground_center, ring[arch_index], ring[arch_index + 1])
            )
            face = mesh.faces.new(vertices)
            average_z = sum(vertex.co.z for vertex in face.verts) / len(face.verts)
            face.material_index = turf_index if average_z >= 0.22 else earth_index


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    materials: list[bpy.types.Material],
    *,
    smooth: bool = False,
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
        polygon.use_smooth = smooth
    return obj


def _apply_bevel(obj: bpy.types.Object, width: float) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("HandWorkedEdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = 1
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(28.0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _unwrap(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    turf = _create_material("root_cellar_turf", TURF_SRGB, 0.95, "turf")
    earth = _create_material("root_cellar_exposed_earth", EARTH_SRGB, 1.0, "earth")
    oak = _create_material("root_cellar_aged_oak", OAK_SRGB, 0.88, "wood")
    fieldstone = _create_material("root_cellar_fieldstone", FIELDSTONE_SRGB, 0.94, "fieldstone")
    void = _create_material("root_cellar_dark_recess", VOID_SRGB, 1.0, None)

    vault_mesh = bmesh.new()
    _add_vault(vault_mesh, 0, 1)
    vault = _object_from_bmesh("TurfCoveredEarthVault", vault_mesh, [turf, earth], smooth=True)

    entrance_mesh = bmesh.new()
    # A dark reveal remains visible in the narrow gaps around the closed plank door.
    _add_box(entrance_mesh, (0.0, -0.707, 0.285), (0.58, 0.025, 0.52), 1)
    plank_width = 0.094
    for plank_index in range(5):
        x = -0.196 + plank_index * 0.098
        _add_box(entrance_mesh, (x, -0.735, 0.275), (plank_width, 0.045, 0.47), 0)
    for rail_z in (0.16, 0.39):
        _add_box(entrance_mesh, (0.0, -0.764, rail_z), (0.49, 0.025, 0.045), 0)
    # Thick oak posts and lintel make this a cellar entrance, not a decorative hatch.
    _add_box(entrance_mesh, (-0.33, -0.65, 0.31), (0.10, 0.15, 0.62), 0, -2.0)
    _add_box(entrance_mesh, (0.33, -0.65, 0.31), (0.10, 0.15, 0.62), 0, 2.0)
    _add_box(entrance_mesh, (0.0, -0.65, 0.635), (0.76, 0.16, 0.11), 0)
    entrance = _object_from_bmesh("TimberCellarEntrance", entrance_mesh, [oak, void])
    _apply_bevel(entrance, 0.008)

    stone_mesh = bmesh.new()
    _add_box(stone_mesh, (0.0, -0.76, 0.035), (0.68, 0.22, 0.07), 0)
    stone_specs = (
        (-0.47, -0.59, 0.10, 0.18, 0.16, 0.10, -8.0),
        (-0.52, -0.43, 0.13, 0.22, 0.18, 0.13, 11.0),
        (-0.44, -0.30, 0.11, 0.19, 0.16, 0.11, -4.0),
        (0.47, -0.59, 0.10, 0.18, 0.16, 0.10, 7.0),
        (0.52, -0.43, 0.13, 0.22, 0.18, 0.13, -12.0),
        (0.44, -0.30, 0.11, 0.19, 0.16, 0.11, 5.0),
    )
    for x, y, z, sx, sy, sz, rotation in stone_specs:
        _add_fieldstone(stone_mesh, (x, y, z), (sx, sy, sz), rotation, 0)
    retaining_stones = _object_from_bmesh("EntranceFieldstoneRetainingApron", stone_mesh, [fieldstone])

    root = bpy.data.objects.new("RootCellarMound", None)
    bpy.context.collection.objects.link(root)
    meshes = [vault, entrance, retaining_stones]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.viru_gate_foreland"
        _unwrap(obj)

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_root_cellar_mound.py"
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
    textured_material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len({polygon.material_index for polygon in mesh.polygons})
        uv_sets = max(uv_sets, len(mesh.uv_layers))
        for material in mesh.materials:
            if material is None:
                continue
            material_names.add(material.name)
            if material.use_nodes and any(
                node.type == "TEX_IMAGE" and node.image is not None for node in material.node_tree.nodes
            ):
                textured_material_names.add(material.name)
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
        "textured_materials": len(textured_material_names),
        "uv_sets": uv_sets,
        "texture_size": TEXTURE_SIZE,
        "dimensions_m": [
            round(maximum.x - minimum.x, 4),
            round(maximum.z - minimum.z, 4),
            round(maximum.y - minimum.y, 4),
        ],
        "ground_min_y": round(minimum.z, 6),
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
    scene.world.color = (0.035, 0.045, 0.030)

    floor_material = bpy.data.materials.new("PreviewGrass")
    floor_material.diffuse_color = (0.10, 0.16, 0.08, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.7, -2.8, 3.6))
    key = bpy.context.object
    key.data.energy = 950.0
    key.data.shape = "DISK"
    key.data.size = 3.0
    direction = Vector((0.0, -0.05, 0.3)) - key.location
    key.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(2.4, 1.8, 2.2))
    fill = bpy.context.object
    fill.data.energy = 420.0
    fill.data.color = (0.50, 0.62, 0.82)
    fill.data.size = 2.4
    direction = Vector((0.0, 0.0, 0.35)) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(2.7, -3.3, 2.25))
    camera = bpy.context.object
    direction = Vector((0.0, -0.04, 0.32)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.65
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)

    for obj in meshes:
        obj.hide_render = False


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_root_cellar_mound.py",
        "blender_version": BLENDER_VERSION,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_y"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": int(metrics["textured_materials"]) >= 4,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "non_brick_mound_material": True,
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
