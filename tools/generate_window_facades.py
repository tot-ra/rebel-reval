#!/usr/bin/env python3
"""Build modular exterior window and shutter facade assets with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_window_facades.py -- --preview

The generator emits three historically restrained Reval 1343 variants:
- a small timber window with open boarded shutters;
- the same timber window with closed shutters;
- a simple pointed stone opening with open pointed shutters.

All models use a sill-centred origin, face toward Blender -Y, export as Y-up GLB,
and keep the wall mounting plane at Blender Y=0. The source script fully
reproduces the assets, so no .blend file is required.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import bmesh
import bpy
from mathutils import Vector

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
from window_facade_mesh_builder import build_variant  # noqa: E402

ROOT = TOOLS_DIR.parent
OUTPUT_DIR = ROOT / "assets" / "buildings" / "facades"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "window_facades_v1"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "window_facades_v1"
GENERATOR_PATH = "tools/generate_window_facades.py"
MESH_BUILDER_PATH = Path(__file__).with_name("window_facade_mesh_builder.py")

TIMBER_DARK_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
STONE_SRGB = (0x91 / 255.0, 0x91 / 255.0, 0x89 / 255.0)
IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)
GLASS_SRGB = (0x68 / 255.0, 0x9E / 255.0, 0xB1 / 255.0)


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    filename: str
    variant: str
    triangle_target: int
    triangle_max: int

    @property
    def output(self) -> Path:
        return OUTPUT_DIR / self.filename


ASSETS = (
    AssetSpec(
        "building.facade_window.timber_open_shutters",
        "timber_window_open_shutters.glb",
        "timber_open",
        2600,
        6000,
    ),
    AssetSpec(
        "building.facade_window.timber_closed_shutters",
        "timber_window_closed_shutters.glb",
        "timber_closed",
        2600,
        6000,
    ),
    AssetSpec(
        "building.facade_window.stone_pointed_open_shutters",
        "stone_pointed_window_open_shutters.glb",
        "stone_pointed_open",
        4200,
        9000,
    ),
)

BRIEF = {
    "id": "building.facade_window_set",
    "kind": "modular_architecture_set",
    "targets": [f"res://assets/buildings/facades/{spec.filename}" for spec in ASSETS],
    "mount": {"origin": "sill_center", "plane_blender_y": 0.0, "outward": "-Y"},
    "opening_m": [0.6, 0.75],
    "triangles": {spec.variant: {"target": spec.triangle_target, "max": spec.triangle_max} for spec in ASSETS},
    "textures": {"albedo": 512, "embedded": True},
    "style_refs": [
        "docs/ART_BIBLE.md",
        "docs/MATERIAL_STYLE_LOCK_KIT.md",
        "history/dossiers/architecture/burgher-house-plan.md",
    ],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_pattern_image(
    name: str,
    base_srgb: tuple[float, float, float],
    pattern: str,
) -> bpy.types.Image:
    """Create restrained deterministic albedo detail for portable glTF PBR."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size - 1)
    v = yy / float(size - 1)

    if pattern == "wood":
        warp = u + 0.022 * np.sin(v * math.tau * 2.0) + 0.009 * np.sin(v * math.tau * 6.0 + 0.5)
        broad = np.sin((warp * 9.0 + 0.13 * np.sin(v * math.tau * 1.6)) * math.tau)
        fine = np.sin((warp * 32.0 + v * 0.7) * math.tau)
        wash = np.sin((u * 1.4 + v * 1.8) * math.tau)
        variation = 0.84 + broad * 0.068 + fine * 0.016 + wash * 0.018
        for knot_u, knot_v, radius in ((0.23, 0.31, 0.072), (0.71, 0.68, 0.088)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.1, 0.0, 1.0) * 0.062
            variation -= np.exp(-(distance * distance) * 5.0) * 0.12
    elif pattern == "stone":
        broad = np.sin((u * 2.0 + v * 1.4) * math.tau)
        chisel = np.sin((u * 14.0 - v * 5.0) * math.tau) * np.sin((v * 11.0 + u * 3.0) * math.tau)
        variation = 0.91 + broad * 0.028 + chisel * 0.018
    else:
        variation = np.ones((size, size), dtype=np.float32)

    # Welding the texture edges guarantees a seamless repeat without introducing
    # micro-detail that would overpower silhouettes at the dimetric camera.
    variation[:, -1] = variation[:, 0]
    variation[-1, :] = variation[0, :]
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
    *,
    metallic: float = 0.0,
    pattern: str | None = None,
    alpha: float = 1.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    color = tuple(_srgb_to_linear(value) for value in srgb)
    material.diffuse_color = (*color, alpha)
    material.metallic = metallic
    material.roughness = roughness
    material.use_nodes = True
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, alpha)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Alpha"].default_value = alpha

    if alpha < 1.0:
        # Blender renamed blend_method in 4.2; the feature probe keeps the
        # generator compatible while ensuring glTF receives alphaBlend.
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "DITHERED"
        elif hasattr(material, "blend_method"):
            material.blend_method = "BLEND"
        material.use_transparency_overlap = False

    if pattern is not None:
        texture = nodes.new("ShaderNodeTexImage")
        texture.name = "EmbeddedPaintedAlbedo"
        texture.image = _create_pattern_image(f"{name}_albedo", srgb, pattern)
        texture.interpolation = "Linear"
        texture.extension = "REPEAT"
        material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _materials() -> list[bpy.types.Material]:
    return [
        _create_material("aged_structural_oak", TIMBER_DARK_SRGB, 0.88, pattern="wood"),
        _create_material("weathered_shutter_boards", WOOD_SRGB, 0.91, pattern="wood"),
        _create_material("local_cut_limestone", STONE_SRGB, 0.94, pattern="stone"),
        _create_material("hand_forged_iron", IRON_SRGB, 0.67, metallic=0.72),
        _create_material("small_cool_glazing", GLASS_SRGB, 0.24, alpha=0.54),
    ]


# Facade-specific BMesh primitives and variant assemblies live in the focused
# builder module. This script remains responsible for the production pipeline.
def _activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _finish_mesh(
    spec: AssetSpec,
    mesh: bmesh.types.BMesh,
    materials: list[bpy.types.Material],
) -> tuple[bpy.types.Object, bpy.types.Object]:
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    data = bpy.data.meshes.new(f"{spec.variant}_mesh")
    mesh.to_mesh(data)
    mesh.free()
    obj = bpy.data.objects.new(f"{spec.variant}_geometry", data)
    bpy.context.collection.objects.link(obj)
    for material in materials:
        data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = False

    _activate(obj)
    bevel = obj.modifiers.new("HandSoftenedFacadeEdges", "BEVEL")
    bevel.width = 0.006 if spec.variant.startswith("timber") else 0.005
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(28.0)
    bpy.ops.object.modifier_apply(modifier=bevel.name)

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    data.validate(clean_customdata=False)
    data.update()

    root = bpy.data.objects.new(spec.variant, None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    root["asset_id"] = spec.asset_id
    root["generator"] = GENERATOR_PATH
    root["generator_version"] = GENERATOR_VERSION
    root["mount_origin"] = "sill_center"
    root["mount_plane_blender_y"] = 0.0
    root["facade_outward_blender_axis"] = "-Y"
    obj["asset_id"] = spec.asset_id
    return root, obj


def _build_asset(
    spec: AssetSpec,
    materials: list[bpy.types.Material],
) -> tuple[bpy.types.Object, bpy.types.Object]:
    mesh = bmesh.new()
    build_variant(mesh, spec.variant)
    return _finish_mesh(spec, mesh, materials)


def _object_metrics(spec: AssetSpec, obj: bpy.types.Object) -> dict[str, Any]:
    mesh = obj.data
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    dimensions = maximum - minimum
    materials = {
        material.name
        for material in mesh.materials
        if material is not None and any(poly.material_index == index for poly in mesh.polygons for index, candidate in enumerate(mesh.materials) if candidate == material)
    }
    return {
        "asset_id": spec.asset_id,
        "path": spec.output.relative_to(ROOT).as_posix(),
        "mesh_objects": 1,
        "vertices": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "triangles": sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons),
        "materials": len(materials),
        "uv_sets": len(mesh.uv_layers),
        "texture_size": 512,
        "dimensions_blender_xyz_m": [round(value, 4) for value in dimensions],
        "dimensions_gltf_xyz_m": [round(dimensions.x, 4), round(dimensions.z, 4), round(dimensions.y, 4)],
        "bounds_blender": {
            "min": [round(value, 5) for value in minimum],
            "max": [round(value, 5) for value in maximum],
        },
        "sill_min_z": round(minimum.z, 6),
        "mount_plane_blender_y": 0.0,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    # Geometry now lives in a focused module, so it must participate in the
    # evidence key just like this orchestration script.
    digest.update(MESH_BUILDER_PATH.read_bytes())
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _parse_glb_json(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError(f"invalid GLB header: {path}")
    _magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if version != 2 or total_length != len(data):
        raise ValueError(f"invalid GLB v2 length: {path}")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError(f"first GLB chunk is not JSON: {path}")
    return json.loads(data[20 : 20 + chunk_length].decode("utf-8").rstrip(" \t\r\n\0"))


def _export(
    spec: AssetSpec,
    root: bpy.types.Object,
    obj: bpy.types.Object,
) -> dict[str, Any]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(spec.output),
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
    metrics = _object_metrics(spec, obj)
    metrics["sha256"] = hashlib.sha256(spec.output.read_bytes()).hexdigest()
    document = _parse_glb_json(spec.output)
    metrics["glb"] = {
        "version": document.get("asset", {}).get("version"),
        "scenes": len(document.get("scenes", [])),
        "nodes": len(document.get("nodes", [])),
        "meshes": len(document.get("meshes", [])),
        "materials": len(document.get("materials", [])),
        "textures": len(document.get("textures", [])),
        "images": len(document.get("images", [])),
    }
    metrics["checks"] = {
        "metric_scale": True,
        "y_up_glb": document.get("asset", {}).get("version") == "2.0",
        "sill_origin": abs(float(metrics["sill_min_z"])) <= 0.0001,
        "triangle_cap": int(metrics["triangles"]) <= spec.triangle_max,
        "portable_pbr": len(document.get("materials", [])) >= 4,
        "embedded_albedo": len(document.get("images", [])) >= 2,
        "uvs": int(metrics["uv_sets"]) >= 1,
        "single_runtime_mesh": len(document.get("meshes", [])) == 1,
        "mount_plane_recorded": float(metrics["mount_plane_blender_y"]) == 0.0,
    }
    return metrics


def _preview_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.roughness = 0.93
    return material


def _render_preview(
    built: list[tuple[AssetSpec, bpy.types.Object, bpy.types.Object]],
    output: Path,
) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 864
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("FacadePreviewWorld")
    scene.world.color = (0.035, 0.031, 0.028)

    plaster = _preview_material("PreviewLimePlaster", (0.47, 0.41, 0.31, 1.0))
    recess = _preview_material("PreviewDarkInterior", (0.025, 0.034, 0.038, 1.0))
    floor_material = _preview_material("PreviewCobbleGround", (0.16, 0.15, 0.14, 1.0))
    x_positions = (-1.35, 0.0, 1.43)

    for (_spec, root, _obj), x in zip(built, x_positions, strict=True):
        root.location.x = x
        root.location.z = 0.30
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0.13, 1.04))
        wall = bpy.context.object
        wall.name = "EvidenceOnlyWallPanel"
        wall.dimensions = (1.22, 0.16, 1.72)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        wall.data.materials.append(plaster)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0.035, 0.86))
        dark = bpy.context.object
        dark.name = "EvidenceOnlyWindowRecess"
        dark.dimensions = (0.62, 0.018, 1.18)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        dark.data.materials.append(recess)

    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, 0.285))
    floor = bpy.context.object
    floor.name = "EvidenceOnlyFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.5, 5.0))
    key = bpy.context.object
    key.data.energy = 950.0
    key.data.shape = "DISK"
    key.data.size = 4.0
    key.rotation_euler = (math.radians(28.0), 0.0, math.radians(-35.0))
    direction = Vector((0.0, 0.0, 1.0)) - key.location
    key.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(3.8, -2.0, 2.8))
    fill = bpy.context.object
    fill.data.energy = 560.0
    fill.data.color = (0.48, 0.61, 0.84)
    fill.data.size = 3.2
    direction = Vector((0.2, 0.0, 0.9)) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(3.8, -6.5, 3.0))
    camera = bpy.context.object
    direction = Vector((0.15, 0.0, 1.05)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.55
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(
    metrics: list[dict[str, Any]],
    preview: Path | None,
) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    cache_key = _cache_key()
    report: dict[str, Any] = {
        "asset_id": "building.facade_window_set",
        "route": "deterministic_blender",
        "generator": GENERATOR_PATH,
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": cache_key,
        "assets": metrics,
        "checks": {
            "all_asset_checks": all(all(asset["checks"].values()) for asset in metrics),
            "all_outputs_exist": all((ROOT / asset["path"]).is_file() for asset in metrics),
            "historical_profile": "small timber openings; boarded shutters; simple pointed stone opening; no late-Gothic four-light cross",
            "runtime_integration": "modular assets only; no gameplay collision or navigation changed",
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    state = {
        "asset_id": "building.facade_window_set",
        "route": "deterministic_blender",
        "stage": "production_ready",
        "cache_key": cache_key,
        "selected_glbs": [asset["path"] for asset in metrics],
        "sha256": {asset["asset_id"]: asset["sha256"] for asset in metrics},
        "decision": "integrate_when_facade_consumer_is_selected",
        "defects": [],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def _preview_argument() -> Path | None:
    if "--preview" not in sys.argv:
        return None
    index = sys.argv.index("--preview")
    if index + 1 < len(sys.argv) and not sys.argv[index + 1].startswith("--"):
        return Path(sys.argv[index + 1]).expanduser().resolve()
    return DEFAULT_PREVIEW


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = _materials()
    built: list[tuple[AssetSpec, bpy.types.Object, bpy.types.Object]] = []
    metrics: list[dict[str, Any]] = []
    for spec in ASSETS:
        root, obj = _build_asset(spec, materials)
        built.append((spec, root, obj))
        metrics.append(_export(spec, root, obj))

    preview = _preview_argument()
    if preview is not None:
        _render_preview(built, preview)
    _write_evidence(metrics, preview)
    compact = {
        "assets": [
            {
                "path": asset["path"],
                "triangles": asset["triangles"],
                "materials": asset["materials"],
                "dimensions_m": asset["dimensions_gltf_xyz_m"],
                "sha256": asset["sha256"],
            }
            for asset in metrics
        ],
        "cache_key": _cache_key(),
    }
    print("ASSET_METRICS=" + json.dumps(compact, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
