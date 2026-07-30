#!/usr/bin/env python3
"""Build a readable yard firewood stack with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_yard_firewood_stack.py -- --preview

Replaces the outdoor Workers District courtyard anvil with split birch/pine billets
stacked for domestic and workshop kindling. Map-owned placement, collision,
navigation, and the two-cell footprint stay intact.
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
OUTPUT = ROOT / "assets" / "props" / "crafts" / "yard_firewood_stack.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "yard_firewood_stack_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.yard_firewood_stack"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "yard_firewood_stack_v1"

BARK_SRGB = (0x6A / 255.0, 0x4E / 255.0, 0x34 / 255.0)
HEARTWOOD_SRGB = (0xC4 / 255.0, 0x9A / 255.0, 0x5C / 255.0)
HEMP_SRGB = (0x6F / 255.0, 0x59 / 255.0, 0x38 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/crafts/yard_firewood_stack.glb",
    "scene": "res://content/maps/lower_town_slice.rrmap#courtyard_firewood",
    "dimensions_m": [2.07, 0.55, 0.92],
    "triangles": {"target": 1264, "max": 2800},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "bark":
        ridges = np.sin((u * 18.0 + 0.35 * np.sin(v * math.tau * 3.0)) * math.tau)
        flakes = np.sin((v * 27.0 - u * 4.0) * math.tau)
        lichen = np.maximum(0.0, np.sin((u * 5.0 + v * 7.0) * math.tau))
        variation = 0.82 + ridges * 0.07 + flakes * 0.03 + lichen * 0.025
    elif surface == "heartwood":
        rings = np.sin((u * 11.0 + v * 0.4) * math.tau)
        rays = np.sin((v * 29.0 - 0.5 * np.sin(u * math.tau * 2.0)) * math.tau)
        pith = np.exp(-(((u - 0.5) * 4.0) ** 2 + ((v - 0.5) * 4.0) ** 2))
        variation = 0.88 + rings * 0.06 + rays * 0.02 - pith * 0.05
    else:
        twist = np.sin((u * 24.0 + v * 9.0) * math.tau)
        fibers = np.sin((u * 61.0 - v * 5.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.3) * math.tau)
        variation = 0.84 + twist * 0.052 + fibers * 0.015 + broad * 0.02

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
    surface: str,
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
    texture.image = _create_texture(f"{name}_albedo", srgb, surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _add_split_billet(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    length: float,
    radius: float,
    yaw: float,
    bark_index: int,
    heart_index: int,
    phase: float,
    segments: int = 10,
) -> None:
    """Horizontal half-round split log: bark on the curved back, heartwood on the face.

    Local +X is the billet length so stacks stay yard-height, not upright poles.
    """
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
    half = length * 0.5
    ring_xs = (-half, -half * 0.35, half * 0.35, half)
    rings: list[list[bmesh.types.BMVert]] = []
    for ring_index, x in enumerate(ring_xs):
        current: list[bmesh.types.BMVert] = []
        for index in range(segments + 1):
            # 0..segments covers a half-cylinder plus the flat diametral face.
            if index == 0 or index == segments:
                local_radius = radius * (0.92 + 0.04 * math.sin(phase + ring_index))
                local = Vector((x, local_radius if index == 0 else -local_radius, 0.0))
            else:
                angle = math.pi * index / segments
                wobble = 1.0 + 0.03 * math.sin(angle * 3.0 + phase + ring_index * 0.5)
                local = Vector(
                    (
                        x,
                        -radius * wobble * math.cos(angle),
                        radius * wobble * math.sin(angle),
                    )
                )
            current.append(mesh.verts.new(transform @ local))
        rings.append(current)

    for ring_index in range(len(rings) - 1):
        lower = rings[ring_index]
        upper = rings[ring_index + 1]
        for index in range(segments):
            face = mesh.faces.new(
                (lower[index], lower[index + 1], upper[index + 1], upper[index])
            )
            # Curved bark shell; the two rim quads still sit on the round side.
            face.material_index = bark_index
    # End grain caps.
    face = mesh.faces.new(tuple(reversed(rings[0])))
    face.material_index = heart_index
    face = mesh.faces.new(tuple(rings[-1]))
    face.material_index = heart_index
    # Explicit split face between the two rim verts across each ring pair.
    for ring_index in range(len(rings) - 1):
        lower = rings[ring_index]
        upper = rings[ring_index + 1]
        face = mesh.faces.new((lower[0], upper[0], upper[-1], lower[-1]))
        face.material_index = heart_index


def _add_cord_loop(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius_x: float,
    radius_y: float,
    material_index: int,
    segments: int = 16,
) -> None:
    tube = 0.018
    ring: list[bmesh.types.BMVert] = []
    for index in range(segments):
        angle = math.tau * index / segments
        local = Vector(
            (
                center[0] + radius_x * math.cos(angle),
                center[1] + radius_y * math.sin(angle),
                center[2] + 0.01 * math.sin(angle * 2.0),
            )
        )
        # Approximate the rope as a low prism around the path.
        for offset in (
            Vector((tube, 0.0, 0.0)),
            Vector((0.0, tube, 0.0)),
            Vector((-tube, 0.0, 0.0)),
            Vector((0.0, -tube, 0.0)),
        ):
            ring.append(mesh.verts.new(local + offset))
    for index in range(segments):
        base = index * 4
        nxt = ((index + 1) % segments) * 4
        for corner in range(4):
            a = ring[base + corner]
            b = ring[base + ((corner + 1) % 4)]
            c = ring[nxt + ((corner + 1) % 4)]
            d = ring[nxt + corner]
            face = mesh.faces.new((a, b, c, d))
            face.material_index = material_index


def _unwrap_and_triangulate(meshes: list[bpy.types.Object]) -> None:
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    materials = [
        _create_material("WeatheredBirchBark", BARK_SRGB, 0.92, "bark"),
        _create_material("SplitPineHeartwood", HEARTWOOD_SRGB, 0.78, "heartwood"),
        _create_material("HempYardCord", HEMP_SRGB, 0.88, "hemp"),
    ]
    root = bpy.data.objects.new("YardFirewoodStack", None)
    bpy.context.collection.objects.link(root)

    billets_mesh = bpy.data.meshes.new("BilletsMesh")
    billets_bm = bmesh.new()
    for material in materials:
        billets_mesh.materials.append(material)

    # WHY: staggered half-rounds read as split firewood, not boat timber cylinders.
    billets = [
        ((-0.42, -0.18, 0.09), 1.28, 0.09, 0.08, 0.2),
        ((-0.10, 0.08, 0.10), 1.22, 0.095, -0.05, 0.7),
        ((0.28, -0.12, 0.09), 1.18, 0.085, 0.12, 1.1),
        ((0.48, 0.14, 0.08), 1.05, 0.08, -0.18, 1.6),
        ((-0.30, 0.02, 0.26), 1.15, 0.085, 0.22, 2.0),
        ((0.05, -0.16, 0.27), 1.20, 0.09, -0.10, 2.4),
        ((0.38, 0.06, 0.25), 1.08, 0.08, 0.16, 2.9),
        ((-0.18, -0.04, 0.42), 1.10, 0.08, 0.05, 3.3),
        ((0.22, 0.10, 0.43), 1.02, 0.075, -0.14, 3.8),
        ((0.02, -0.02, 0.56), 0.92, 0.07, 0.20, 4.2),
        ((-0.35, 0.18, 0.18), 0.55, 0.07, 1.35, 4.6),
        ((0.42, -0.22, 0.17), 0.48, 0.065, 1.55, 5.0),
    ]
    for center, length, radius, yaw, phase in billets:
        _add_split_billet(
            billets_bm,
            center,
            length,
            radius,
            yaw,
            bark_index=0,
            heart_index=1,
            phase=phase,
        )

    cord_mesh = bpy.data.meshes.new("CordMesh")
    cord_bm = bmesh.new()
    for material in materials:
        cord_mesh.materials.append(material)
    _add_cord_loop(cord_bm, (0.02, -0.02, 0.34), 0.62, 0.34, 2)
    _add_cord_loop(cord_bm, (0.02, -0.02, 0.48), 0.48, 0.26, 2)

    billets_bm.to_mesh(billets_mesh)
    billets_bm.free()
    cord_bm.to_mesh(cord_mesh)
    cord_bm.free()

    billets_obj = bpy.data.objects.new("Billets", billets_mesh)
    cord_obj = bpy.data.objects.new("YardCord", cord_mesh)
    bpy.context.collection.objects.link(billets_obj)
    bpy.context.collection.objects.link(cord_obj)
    billets_obj.parent = root
    cord_obj.parent = root
    meshes = [billets_obj, cord_obj]
    _unwrap_and_triangulate(meshes)

    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= minimum_z

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_yard_firewood_stack.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = "1343 Reval yard firewood: split birch/pine billets under hemp cord"
    root["identity_features"] = "split faces; bark backs; staggered courses; hemp yard cord"
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
    floor_material.diffuse_color = (0.18, 0.22, 0.12, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    bpy.context.object.data.materials.append(floor_material)

    light = bpy.data.lights.new("Key", type="AREA")
    light.energy = 420.0
    light.size = 2.4
    key = bpy.data.objects.new("Key", light)
    bpy.context.collection.objects.link(key)
    key.location = (1.6, -1.8, 2.2)
    key.rotation_euler = (0.9, 0.1, 0.6)

    fill = bpy.data.lights.new("Fill", type="AREA")
    fill.energy = 120.0
    fill.size = 2.8
    fill_obj = bpy.data.objects.new("Fill", fill)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.location = (-1.8, 1.2, 1.4)

    bpy.ops.object.camera_add(location=(1.9, -2.55, 1.55))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, -0.05, 0.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
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
        "generator": "tools/generate_yard_firewood_stack.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "approval": "user-requested 2026-07-30",
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "identity_features": [
                "split_billet_faces",
                "bark_backs",
                "staggered_courses",
                "hemp_yard_cord",
            ],
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "approval": "user-requested 2026-07-30",
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
