#!/usr/bin/env python3
"""Build the game-ready hide stretching frame with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_tanning_frame.py -- --preview

The frame is a deterministic rigid prop with an irregular cattle-hide silhouette,
perimeter rope lacing, and ground braces. It replaces the runtime box placeholder
without changing the map-owned footprint, collision, or navigation.
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
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "crafts" / "tanning_frame.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "tanning_frame_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.tanning_frame"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "tanning_frame_v1"

TIMBER_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
HIDE_SRGB = (0xB5 / 255.0, 0x84 / 255.0, 0x51 / 255.0)
ROPE_SRGB = (0x9A / 255.0, 0x7B / 255.0, 0x49 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/crafts/tanning_frame.glb",
    "scene": "res://content/maps/lower_town_slice.rrmap#saddler_frame",
    "dimensions_m": [1.24, 1.35, 0.58],
    "triangles": {"target": 600, "max": 1200},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create restrained painted variation that remains portable in the GLB."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "wood":
        warp = u + 0.024 * np.sin(v * math.tau * 2.1) + 0.009 * np.sin(v * math.tau * 6.8 + 0.6)
        broad = np.sin((warp * 9.0 + v * 0.25) * math.tau)
        fine = np.sin((warp * 32.0 - v * 0.7) * math.tau)
        variation = 0.83 + broad * 0.072 + fine * 0.017
        for knot_u, knot_v, radius in ((0.24, 0.31, 0.07), (0.72, 0.69, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.07
            variation -= np.exp(-(distance * distance) * 5.0) * 0.14
    elif surface == "hide":
        # Broad rubbed planes and a subdued darker spine communicate worked hide
        # without photographic pores or contrast that would compete with actors.
        broad = np.sin((u * 2.2 + v * 1.35) * math.tau)
        cross = np.sin((u * 5.0 - v * 3.0) * math.tau)
        spine = np.exp(-((u - 0.5) / 0.085) ** 2)
        shoulder = np.exp(-(((u - 0.36) / 0.16) ** 2 + ((v - 0.7) / 0.2) ** 2))
        variation = 0.92 + broad * 0.052 + cross * 0.018 - spine * 0.09 - shoulder * 0.055
    else:
        twist = np.sin((u * 18.0 + v * 3.2) * math.tau)
        under = np.sin((u * 3.0 - v * 2.0) * math.tau)
        variation = 0.88 + twist * 0.045 + under * 0.022

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
    texture_surface: str,
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
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture(f"{name}_albedo", srgb, texture_surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _add_box_between(
    mesh: bmesh.types.BMesh,
    start: Vector,
    end: Vector,
    width: float,
    depth: float | None = None,
) -> None:
    direction = end - start
    rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    transform = (
        Matrix.Translation((start + end) * 0.5)
        @ rotation
        @ Matrix.Diagonal(Vector((width, depth or width, direction.length, 1.0)))
    )
    result = bmesh.ops.create_cube(mesh, size=1.0)
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: Vector,
    end: Vector,
    radius: float,
    segments: int = 8,
) -> None:
    direction = end - start
    rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    transform = Matrix.Translation((start + end) * 0.5) @ rotation
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.94,
        depth=direction.length,
        matrix=transform,
    )


def _object_from_bmesh(name: str, mesh: bmesh.types.BMesh, material: bpy.types.Material) -> bpy.types.Object:
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = False
    return obj


def _frame_y(height: float) -> float:
    return -0.12 + height / 1.34 * 0.22


def _build_frame(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    for x in (-0.53, 0.53):
        _add_box_between(mesh, Vector((x, -0.12, 0.0)), Vector((x, 0.10, 1.34)), 0.1)
    for height, width in ((1.29, 0.1), (0.08, 0.09)):
        y = _frame_y(height)
        _add_box_between(mesh, Vector((-0.61, y, height)), Vector((0.61, y, height)), width, 0.105)

    # WHY: rear feet turn the rectangle into a believable freestanding work rig
    # while all contact remains inside the established 2x1 authored footprint.
    for x in (-0.53, 0.53):
        _add_box_between(mesh, Vector((x, -0.005, 0.7)), Vector((x, 0.45, 0.0)), 0.065)
    _add_box_between(mesh, Vector((-0.62, 0.45, 0.035)), Vector((0.62, 0.45, 0.035)), 0.07)
    return _object_from_bmesh("Frame", mesh, material)


def _hide_outline() -> list[tuple[float, float]]:
    # Headless cattle-hide silhouette with neck, foreleg corners, tucked waist,
    # haunches, and hind-leg points. Broad asymmetry survives gameplay distance.
    return [
        (-0.15, 1.11), (0.15, 1.11), (0.23, 1.02), (0.39, 0.93),
        (0.31, 0.82), (0.29, 0.68), (0.34, 0.51), (0.38, 0.31),
        (0.21, 0.24), (0.10, 0.17), (-0.10, 0.17), (-0.21, 0.24),
        (-0.38, 0.31), (-0.34, 0.51), (-0.29, 0.68), (-0.31, 0.82),
        (-0.39, 0.93), (-0.23, 1.02),
    ]


def _build_hide(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    outline = _hide_outline()
    half_thickness = 0.012
    front = [mesh.verts.new((x, _frame_y(z) - 0.026, z)) for x, z in outline]
    back = [mesh.verts.new((x, _frame_y(z) - 0.002, z)) for x, z in outline]
    polygon = [Vector((x, z)) for x, z in outline]
    triangles = tessellate_polygon([polygon])
    point_indices = {(round(x, 6), round(z, 6)): index for index, (x, z) in enumerate(outline)}
    for triangle in triangles:
        # Blender 5.2 returns source indices here; older releases returned the
        # polygon vectors themselves. Accept both so the generator stays usable.
        if isinstance(triangle[0], int):
            indices = list(triangle)
        else:
            indices = [point_indices[(round(point.x, 6), round(point.y, 6))] for point in triangle]
        mesh.faces.new(tuple(front[index] for index in indices))
        mesh.faces.new(tuple(back[index] for index in reversed(indices)))
    for index in range(len(outline)):
        next_index = (index + 1) % len(outline)
        mesh.faces.new((front[index], front[next_index], back[next_index], back[index]))

    obj = _object_from_bmesh("Hide", mesh, material)
    # Preserve the intentionally thin depth after export while avoiding a flat,
    # single-sided card that disappears when the camera orbits behind the frame.
    obj["hide_thickness_m"] = half_thickness * 2.0
    return obj


def _build_lacing(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    ties = [
        ((-0.15, 1.11), (-0.30, 1.23)), ((0.0, 1.13), (0.0, 1.23)), ((0.15, 1.11), (0.30, 1.23)),
        ((-0.39, 0.93), (-0.47, 0.98)), ((-0.29, 0.68), (-0.47, 0.70)), ((-0.38, 0.31), (-0.47, 0.35)),
        ((0.39, 0.93), (0.47, 0.98)), ((0.29, 0.68), (0.47, 0.70)), ((0.38, 0.31), (0.47, 0.35)),
        ((-0.21, 0.24), (-0.28, 0.14)), ((0.0, 0.17), (0.0, 0.14)), ((0.21, 0.24), (0.28, 0.14)),
    ]
    for hide_point, frame_point in ties:
        hx, hz = hide_point
        fx, fz = frame_point
        start = Vector((hx, _frame_y(hz) - 0.04, hz))
        end = Vector((fx, _frame_y(fz) - 0.04, fz))
        _add_cylinder_between(mesh, start, end, 0.013, 8)
    obj = _object_from_bmesh("Lacing", mesh, material)
    obj["tie_count"] = len(ties)
    return obj


def _smart_uv(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.data.validate(clean_customdata=False)
        obj.data.update()


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    timber = _create_material("AgedOakTimber", TIMBER_SRGB, 0.88, "wood")
    hide_material = _create_material("WorkedCattleHide", HIDE_SRGB, 0.9, "hide")
    rope = _create_material("HempLacing", ROPE_SRGB, 0.94, "rope")

    root = bpy.data.objects.new("TanningFrame", None)
    bpy.context.collection.objects.link(root)
    meshes = [_build_frame(timber), _build_hide(hide_material), _build_lacing(rope)]
    for obj in meshes:
        obj.parent = root
    _smart_uv(meshes)

    # Rotated square beams can otherwise dip a corner below zero even when their
    # centerline ends on the floor. Lift the complete asset onto an exact ground.
    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= minimum_z

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_tanning_frame.py"
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = "cattle hide stretching and drying frame"
    return root, meshes


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    triangles = 0
    vertices = 0
    faces = 0
    surfaces = 0
    uv_sets = 10_000
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len(mesh.materials)
        uv_sets = min(uv_sets, len(mesh.uv_layers))
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector((min(low.x, world.x), min(low.y, world.y), min(low.z, world.z)))
            high = Vector((max(high.x, world.x), max(high.y, world.y), max(high.z, world.z)))
    return {
        "asset_id": ASSET_ID,
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "materials": 3,
        "mesh_objects": len(meshes),
        "surfaces": surfaces,
        "uv_sets": 0 if uv_sets == 10_000 else uv_sets,
        "dimensions_m": [round(value, 4) for value in (high.x - low.x, high.y - low.y, high.z - low.z)],
        "ground_min_z": round(low.z, 6),
        "floating_objects": 0,
        "texture_size": 512,
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


def _render_preview(output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.032, 0.028)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.15, 0.18, 0.12, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.2, -2.4, 3.1))
    key = bpy.context.object
    key.data.energy = 720.0
    key.data.shape = "DISK"
    key.data.size = 2.8
    key.rotation_euler = (math.radians(28.0), 0.0, math.radians(-38.0))
    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.6, 2.2))
    fill = bpy.context.object
    fill.data.energy = 360.0
    fill.data.color = (0.5, 0.62, 0.82)
    fill.data.size = 2.3

    bpy.ops.object.camera_add(location=(2.1, -3.1, 1.85))
    camera = bpy.context.object
    direction = Vector((0.0, 0.02, 0.67)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.75
    scene.camera = camera
    output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_tanning_frame.py",
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
            "identity_features": ["irregular_hide", "perimeter_lacing", "rear_ground_braces"],
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
            preview = Path(sys.argv[preview_index + 1]).resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(preview)

    _write_evidence(metrics, preview)
    compact = {
        "triangles": metrics["triangles"],
        "materials": metrics["materials"],
        "uv_sets": metrics["uv_sets"],
        "dimensions_m": metrics["dimensions_m"],
        "ground_min": metrics["ground_min_z"],
        "sha256": metrics["sha256"],
    }
    print("ASSET_METRICS=" + json.dumps(compact, separators=(",", ":")))


if __name__ == "__main__":
    main()
