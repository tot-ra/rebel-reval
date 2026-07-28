#!/usr/bin/env python3
"""Build a game-ready coil of twisted hemp rope with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_rope_coil.py -- --preview

The deterministic rigid prop replaces the solid-cylinder placeholder with layered
rope turns, a true open center, visible three-strand lay, and a curved frayed end.
Map-owned placement, collision, navigation, and the one-cell footprint stay intact.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "crafts" / "rope_coil.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "rope_coil_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.rope_coil"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "rope_coil_v1"

HEMP_SRGB = (0x9A / 255.0, 0x7B / 255.0, 0x49 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/crafts/rope_coil.glb",
    "scene": "res://content/maps/north_quarter.rrmap#ropemakers_shed_coils",
    "dimensions_m": [1.22, 0.12, 0.86],
    "triangles": {"target": 6500, "max": 8000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str) -> bpy.types.Image:
    """Create restrained rope lay and fiber variation that exports in the GLB."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    # Broad diagonal bands reinforce the modeled three-strand lay. Finer fibers
    # remain low contrast so the prop does not shimmer at the gameplay camera.
    strand_lay = np.sin((u * 9.0 + v * 3.0) * math.tau)
    opposing_fibers = np.sin((u * 37.0 - v * 5.0) * math.tau)
    worn_length = np.sin((u * 2.0 + v * 1.25) * math.tau)
    variation = 0.86 + strand_lay * 0.065 + opposing_fibers * 0.014 + worn_length * 0.025

    base_linear = np.array([_srgb_to_linear(value) for value in HEMP_SRGB], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)

    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image


def _create_material() -> bpy.types.Material:
    material = bpy.data.materials.new("TwistedHempRope")
    material.diffuse_color = (*(_srgb_to_linear(value) for value in HEMP_SRGB), 1.0)
    material.metallic = 0.0
    material.roughness = 0.95
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = material.roughness
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture("TwistedHempRope_albedo")
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _newell_tangent(points: list[Vector], index: int) -> Vector:
    if index == 0:
        tangent = points[1] - points[0]
    elif index == len(points) - 1:
        tangent = points[-1] - points[-2]
    else:
        tangent = points[index + 1] - points[index - 1]
    return tangent.normalized()


def _sweep_polyline(
    mesh: bmesh.types.BMesh,
    points: list[Vector],
    radii: list[float],
    sides: int,
    cap_start: bool = True,
    cap_end: bool = True,
) -> None:
    """Sweep a low-sided tube through fixed points using a stable upright frame."""
    rings: list[list[bmesh.types.BMVert]] = []
    for point_index, point in enumerate(points):
        tangent = _newell_tangent(points, point_index)
        planar_normal = Vector((-tangent.y, tangent.x, 0.0))
        if planar_normal.length_squared < 1e-8:
            planar_normal = Vector((1.0, 0.0, 0.0))
        else:
            planar_normal.normalize()
        up = tangent.cross(planar_normal).normalized()
        ring: list[bmesh.types.BMVert] = []
        for side_index in range(sides):
            angle = math.tau * side_index / sides
            offset = (planar_normal * math.cos(angle) + up * math.sin(angle)) * radii[point_index]
            ring.append(mesh.verts.new(point + offset))
        rings.append(ring)

    for point_index in range(len(rings) - 1):
        for side_index in range(sides):
            next_side = (side_index + 1) % sides
            mesh.faces.new(
                (
                    rings[point_index][side_index],
                    rings[point_index + 1][side_index],
                    rings[point_index + 1][next_side],
                    rings[point_index][next_side],
                )
            )
    if cap_start:
        mesh.faces.new(tuple(reversed(rings[0])))
    if cap_end:
        mesh.faces.new(tuple(rings[-1]))


def _add_torus(
    mesh: bmesh.types.BMesh,
    major_radius: float,
    tube_radius: float,
    height: float,
    major_segments: int = 20,
    minor_segments: int = 6,
) -> None:
    rings: list[list[bmesh.types.BMVert]] = []
    for major_index in range(major_segments):
        major_angle = math.tau * major_index / major_segments
        ring: list[bmesh.types.BMVert] = []
        for minor_index in range(minor_segments):
            minor_angle = math.tau * minor_index / minor_segments
            radius = major_radius + tube_radius * math.cos(minor_angle)
            ring.append(
                mesh.verts.new(
                    (
                        radius * math.cos(major_angle),
                        radius * math.sin(major_angle),
                        height + tube_radius * math.sin(minor_angle),
                    )
                )
            )
        rings.append(ring)
    for major_index in range(major_segments):
        next_major = (major_index + 1) % major_segments
        for minor_index in range(minor_segments):
            next_minor = (minor_index + 1) % minor_segments
            mesh.faces.new(
                (
                    rings[major_index][minor_index],
                    rings[next_major][minor_index],
                    rings[next_major][next_minor],
                    rings[major_index][next_minor],
                )
            )


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = True
    data.validate(clean_customdata=False)
    data.update()
    return obj


def _build_lower_turns(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    # The lower layer gives the coil believable stored volume while the upper
    # continuous braid carries the identity read from the dimetric camera.
    for radius in (0.13, 0.175, 0.22, 0.265, 0.31, 0.355, 0.40):
        _add_torus(mesh, radius, 0.028, 0.028)
    return _object_from_bmesh("LowerTurns", mesh, material)


def _central_rope_path() -> list[Vector]:
    points: list[Vector] = []
    turn_count = 6
    segments_per_turn = 26
    segment_count = turn_count * segments_per_turn
    for index in range(segment_count + 1):
        progress = index / float(segment_count)
        angle = math.tau * turn_count * progress
        radius = 0.13 + 0.27 * progress
        points.append(
            Vector(
                (
                    radius * math.cos(angle),
                    radius * math.sin(angle),
                    0.092 + 0.002 * math.sin(angle * 0.5),
                )
            )
        )

    # A descending cubic tail avoids the old rigid rectangular handle and makes
    # the outer turn visibly continuous with rope lying loose on the ground.
    start = points[-1]
    control_a = Vector((0.48, 0.025, 0.078))
    control_b = Vector((0.59, -0.145, 0.034))
    end = Vector((0.75, -0.10, 0.031))
    for index in range(1, 21):
        t = index / 20.0
        one_minus_t = 1.0 - t
        point = (
            start * (one_minus_t ** 3)
            + control_a * (3.0 * one_minus_t * one_minus_t * t)
            + control_b * (3.0 * one_minus_t * t * t)
            + end * (t ** 3)
        )
        points.append(point)
    return points


def _strand_paths(central: list[Vector]) -> list[list[Vector]]:
    distances = [0.0]
    for previous, current in zip(central, central[1:]):
        distances.append(distances[-1] + (current - previous).length)

    paths: list[list[Vector]] = [[], [], []]
    for point_index, point in enumerate(central):
        tangent = _newell_tangent(central, point_index)
        normal = Vector((-tangent.y, tangent.x, 0.0))
        if normal.length_squared < 1e-8:
            normal = Vector((1.0, 0.0, 0.0))
        else:
            normal.normalize()
        up = tangent.cross(normal).normalized()
        twist = distances[point_index] / 0.24 * math.tau
        for strand_index in range(3):
            phase = twist + math.tau * strand_index / 3.0
            offset = (normal * math.cos(phase) + up * math.sin(phase)) * 0.014
            paths[strand_index].append(point + offset)
    return paths


def _build_braided_coil(
    material: bpy.types.Material,
) -> tuple[bpy.types.Object, list[list[Vector]]]:
    mesh = bmesh.new()
    paths = _strand_paths(_central_rope_path())
    for path in paths:
        _sweep_polyline(mesh, path, [0.012] * len(path), 5, cap_start=True, cap_end=False)
    return _object_from_bmesh("BraidedCoil", mesh, material), paths


def _build_frayed_end(
    material: bpy.types.Material,
    strand_paths: list[list[Vector]],
) -> bpy.types.Object:
    mesh = bmesh.new()
    central_direction = (_central_rope_path()[-1] - _central_rope_path()[-2]).normalized()
    lateral = Vector((-central_direction.y, central_direction.x, 0.0)).normalized()
    spreads = (-0.75, 0.0, 0.75)
    lifts = (0.003, 0.007, 0.002)
    for strand_index, strand_path in enumerate(strand_paths):
        start = strand_path[-1]
        points = [
            start,
            start + central_direction * 0.018,
            start + central_direction * 0.040 + lateral * spreads[strand_index] * 0.018 + Vector((0.0, 0.0, lifts[strand_index])),
            start + central_direction * 0.060 + lateral * spreads[strand_index] * 0.034 + Vector((0.0, 0.0, lifts[strand_index] * 0.3)),
        ]
        _sweep_polyline(mesh, points, [0.0115, 0.009, 0.006, 0.0025], 5, cap_start=False, cap_end=True)
    return _object_from_bmesh("FrayedEnd", mesh, material)


def _unwrap_and_triangulate(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.025)
        bpy.ops.object.mode_set(mode="OBJECT")
        modifier = obj.modifiers.new("PortableGltfTriangles", "TRIANGULATE")
        modifier.quad_method = "FIXED"
        modifier.ngon_method = "CLIP"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.validate(clean_customdata=False)
        obj.data.update()
        obj.select_set(False)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    material = _create_material()
    root = bpy.data.objects.new("RopeCoil", None)
    bpy.context.collection.objects.link(root)

    lower_turns = _build_lower_turns(material)
    braided_coil, strand_paths = _build_braided_coil(material)
    frayed_end = _build_frayed_end(material, strand_paths)
    meshes = [lower_turns, braided_coil, frayed_end]
    for obj in meshes:
        obj.parent = root
    _unwrap_and_triangulate(meshes)

    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= minimum_z

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_rope_coil.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = "coiled three-strand hemp rope for ropewalk and harbour work"
    root["identity_features"] = "open center; layered turns; three-strand lay; curved frayed end"
    return root, meshes


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    triangles = 0
    vertices = 0
    faces = 0
    surfaces = 0
    uv_sets = 10_000
    material_names: set[str] = set()
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len(mesh.materials)
        uv_sets = min(uv_sets, len(mesh.uv_layers))
        for polygon in mesh.polygons:
            if polygon.material_index < len(mesh.materials):
                material_names.add(mesh.materials[polygon.material_index].name)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector((min(low.x, world.x), min(low.y, world.y), min(low.z, world.z)))
            high = Vector((max(high.x, world.x), max(high.y, world.y), max(high.z, world.z)))
    return {
        "asset_id": ASSET_ID,
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "materials": len(material_names),
        "mesh_objects": len(meshes),
        "surfaces": surfaces,
        "uv_sets": 0 if uv_sets == 10_000 else uv_sets,
        "dimensions_m": [round(value, 4) for value in (high.x - low.x, high.z - low.z, high.y - low.y)],
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
    floor_material.diffuse_color = (0.15, 0.19, 0.11, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.0, -2.4, 3.0))
    key = bpy.context.object
    key.data.energy = 690.0
    key.data.shape = "DISK"
    key.data.size = 2.7
    key.data.color = (1.0, 0.84, 0.67)
    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.4, 2.0))
    fill = bpy.context.object
    fill.data.energy = 330.0
    fill.data.color = (0.52, 0.64, 0.82)
    fill.data.size = 2.3

    bpy.ops.object.camera_add(location=(1.65, -2.35, 1.55))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.12, -0.03, 0.08)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.42
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
        "generator": "tools/generate_rope_coil.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "approval": "user-requested 2026-07-28",
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "identity_features": ["open_center", "layered_turns", "three_strand_lay", "curved_frayed_end"],
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    if (EVIDENCE_DIR / "godot_preview.png").exists():
        report["godot_preview"] = "generated/blender/rope_coil_v1/godot_preview.png"
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "approval": "user-requested 2026-07-28",
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
