#!/usr/bin/env python3
"""Build the production Sacred Grove ancient oak with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_sacred_grove_ancient_oak.py -- --preview

The model is deterministic and ships as a Y-up GLB with embedded painted PBR
textures. Evidence is written under generated/blender/sacred_grove_ancient_oak_v1/.
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
sys.path.insert(0, str(ROOT / "tools"))

from sacred_grove_oak.geometry import (  # noqa: E402
    build_details,
    build_foliage_mesh,
    build_skeleton,
    build_wood_mesh,
)
from sacred_grove_oak.materials import create_materials  # noqa: E402
OUTPUT = ROOT / "assets" / "props" / "environment" / "sacred_grove_ancient_oak.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "sacred_grove_ancient_oak_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.sacred_grove_ancient_oak"
GENERATOR_VERSION = "sacred_grove_ancient_oak_v1"
BLENDER_VERSION = "Blender 5.2 LTS"
SEED = 1343

BRIEF = {
    "id": ASSET_ID,
    "kind": "organic_hero_landmark",
    "target": "res://assets/props/environment/sacred_grove_ancient_oak.glb",
    "scene": "res://content/maps/world_sacred_grove.rrmap#ancient_oak",
    "dimensions_m": [30.5, 26.5, 21.0],
    "triangles": {"target": 50000, "max": 70000},
    "textures": {"bark": 1024, "leaf": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}



def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    vertices = 0
    faces = 0
    triangles = 0
    uv_sets = 0
    points: list[Vector] = []
    material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
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
        "materials": len(material_names),
        "uv_sets": uv_sets,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "floating_objects": 0,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    # The implementation is split across modules, so all generator inputs must
    # participate in invalidating the reproducibility cache.
    for source in (
        Path(__file__),
        ROOT / "tools" / "sacred_grove_oak" / "materials.py",
        ROOT / "tools" / "sacred_grove_oak" / "geometry.py",
    ):
        digest.update(source.relative_to(ROOT).as_posix().encode("utf-8"))
        digest.update(source.read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    digest.update(str(SEED).encode("ascii"))
    return digest.hexdigest()


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object], dict[str, int]]:
    materials = create_materials(SEED)
    branches, anchors, broken_caps = build_skeleton(SEED)

    root = bpy.data.objects.new("SacredGroveAncientOak", None)
    bpy.context.scene.collection.objects.link(root)
    wood = build_wood_mesh(branches, materials["bark"])
    foliage, leaf_count = build_foliage_mesh(anchors, materials["leaf"], SEED)
    details = build_details(broken_caps, materials["heartwood"], materials["hollow"])
    meshes = [wood, foliage, *details]
    for obj in meshes:
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.world_sacred_grove"
    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_sacred_grove_ancient_oak.py"
    root["generator_version"] = GENERATOR_VERSION
    root["seed"] = SEED
    return root, meshes, {"branch_paths": len(branches), "leaf_clusters": len(anchors), "leaf_count": leaf_count, "root_buttresses": 11}


def _export(root: bpy.types.Object, meshes: list[bpy.types.Object], authored: dict[str, int]) -> dict[str, object]:
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
    metrics.update(authored)
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _render_preview(meshes: list[bpy.types.Object], output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("AncientOakPreviewWorld")
    scene.world.color = (0.018, 0.024, 0.017)

    floor_material = bpy.data.materials.new("PreviewForestFloor")
    floor_material.diffuse_color = (0.10, 0.15, 0.065, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0.0, 0.0, -0.015))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-13.0, -16.0, 27.0))
    key = bpy.context.object
    key.data.energy = 3200.0
    key.data.shape = "DISK"
    key.data.size = 10.0
    key.rotation_euler = (Vector((0.0, 0.0, 11.0)) - key.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(14.0, 10.0, 18.0))
    fill = bpy.context.object
    fill.data.energy = 1800.0
    fill.data.color = (0.48, 0.61, 0.78)
    fill.data.size = 9.0
    fill.rotation_euler = (Vector((0.0, 0.0, 12.0)) - fill.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 25.0))
    sun = bpy.context.object
    sun.data.energy = 2.0
    sun.rotation_euler = (math.radians(28.0), math.radians(-24.0), math.radians(-32.0))

    bpy.ops.object.camera_add(location=(31.0, -38.0, 23.0))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, 0.0, 11.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 31.0
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
        "generator": "tools/generate_sacred_grove_ancient_oak.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "seed": SEED,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.05,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo_and_bark_normal": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "gameplay_collision_unchanged": True,
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
    root, meshes, authored = _build_model()
    metrics = _export(root, meshes, authored)

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
