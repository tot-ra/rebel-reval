#!/usr/bin/env python3
"""Deterministic standing waterfowl GLBs for P2-035.

Hunyuan3D image-to-3D was unavailable in this environment, so production meshes
are built from MapViewBirdSpecies catalog proportions with PBR feather maps.
Long-neck overrides (swan, goose, cormorant) come from the species geometry
table. Reference plates under generated/comfyui/bird_waterfowl_v1/ document
silhouettes; an optional Hunyuan candidate pass remains a follow-up.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_waterfowl.py
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = ROOT / "generated" / "comfyui" / "bird_waterfowl_v1"
BIRDS_DIR = ROOT / "assets" / "birds"
REPORTS_DIR = ROOT / "docs" / "reports" / "images" / "fauna"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "waterfowl_v1"
TEXTURE_SIZE = 256

# Catalog geometry mirrors scripts/map/view3d/map_view_bird_species.gd
# (GROUP_WATERFOWL defaults + per-species overrides).
SPECIES = {
    "mute_swan": {
        "scale_m": 1.45,
        "body": (0.72, 0.32, 0.38),
        "head": 0.13,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.25,
        "neck": 0.72,
        "legs": 0.17,
        "neck_curve": 0.55,
        "colors": ((0xE8, 0xE5, 0xDC), (0xD8, 0xD5, 0xCC), (0xD7, 0x7A, 0x36)),
        "cap": None,
        "breast": None,
    },
    "mallard": {
        "scale_m": 0.56,
        "body": (0.62, 0.30, 0.34),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.26,
        "neck": 0.13,
        "legs": 0.17,
        "neck_curve": 0.12,
        "colors": ((0x76, 0x6A, 0x4D), (0x33, 0x5B, 0x4D), (0xD3, 0xA4, 0x42)),
        "cap": (0x33, 0x5B, 0x4D),
        "breast": (0x77, 0x50, 0x3A),
    },
    "greylag_goose": {
        "scale_m": 0.82,
        "body": (0.68, 0.31, 0.36),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.18,
        "beak": 0.22,
        "neck": 0.46,
        "legs": 0.17,
        "neck_curve": 0.28,
        "colors": ((0x93, 0x8D, 0x7C), (0x6F, 0x71, 0x68), (0xD6, 0x8C, 0x4C)),
        "cap": None,
        "breast": None,
    },
    "great_cormorant": {
        "scale_m": 0.88,
        "body": (0.58, 0.25, 0.28),
        "head": 0.16,
        "wing_span": 1.10,
        "wing_chord": 0.42,
        "tail": 0.30,
        "beak": 0.29,
        "neck": 0.52,
        "legs": 0.17,
        "neck_curve": 0.18,
        "colors": ((0x25, 0x2B, 0x2B), (0x15, 0x19, 0x1A), (0xC9, 0xA8, 0x5B)),
        "cap": None,
        "breast": None,
    },
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _hex_to_linear(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    return tuple(_srgb_to_linear(c / 255.0) for c in rgb)


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _scale_factor(spec: dict) -> float:
    return float(spec["scale_m"]) / max(float(spec["body"][0]), 0.01)


def _create_feather_maps(
    species: str,
    body_srgb: tuple[int, int, int],
    wing_srgb: tuple[int, int, int],
    breast_srgb: tuple[int, int, int] | None,
) -> dict[str, bpy.types.Image]:
    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    body = np.array([c / 255.0 for c in body_srgb], dtype=np.float32)
    wing = np.array([c / 255.0 for c in wing_srgb], dtype=np.float32)
    wing_mask = np.clip((u - 0.48) * 2.8 + 0.12 * np.sin(v * math.tau * 2.0), 0.0, 1.0)
    breast_mask = np.clip((0.42 - v) * 3.5, 0.0, 1.0) * (1.0 - wing_mask)
    feather = 0.5 + 0.5 * np.sin((u * 26.0 + v * 5.0) * math.tau)
    mix = body * (1.0 - wing_mask)[:, :, None] + wing * wing_mask[:, :, None]
    if breast_srgb is not None:
        breast = np.array([c / 255.0 for c in breast_srgb], dtype=np.float32)
        mix = mix * (1.0 - breast_mask)[:, :, None] + breast * breast_mask[:, :, None]
    mix *= 0.92 + 0.08 * feather[:, :, None]
    alpha = np.ones((size, size, 1), dtype=np.float32)
    albedo_pixels = np.concatenate((mix, alpha), axis=2).ravel()

    albedo = bpy.data.images.new(f"{species}_albedo", size, size, alpha=False)
    albedo.pixels.foreach_set(albedo_pixels.tolist())
    albedo.colorspace_settings.name = "sRGB"
    albedo.file_format = "PNG"
    albedo.pack()

    height = (0.45 + 0.18 * feather + 0.08 * np.sin((v * 18.0 - u * 3.0) * math.tau)).astype(np.float32)
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    nx = -dx * 4.0
    ny = -dy * 4.0
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    normal_rgb = np.stack(((nx + 1.0) * 0.5, (ny + 1.0) * 0.5, (nz + 1.0) * 0.5), axis=2)
    normal = bpy.data.images.new(f"{species}_normal", size, size, alpha=False)
    normal.pixels.foreach_set(np.concatenate((normal_rgb, alpha), axis=2).ravel().tolist())
    normal.colorspace_settings.name = "Non-Color"
    normal.file_format = "PNG"
    normal.pack()

    roughness_vals = 0.70 + 0.16 * (0.5 + 0.5 * feather)
    rough_rgb = np.repeat(roughness_vals[:, :, None], 3, axis=2)
    roughness = bpy.data.images.new(f"{species}_roughness", size, size, alpha=False)
    roughness.pixels.foreach_set(np.concatenate((rough_rgb, alpha), axis=2).ravel().tolist())
    roughness.colorspace_settings.name = "Non-Color"
    roughness.file_format = "PNG"
    roughness.pack()

    return {"albedo": albedo, "normal": normal, "roughness": roughness}


def _make_material(name: str, maps: dict[str, bpy.types.Image], base_rgb: tuple[float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*base_rgb, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.78
    tex_albedo = nodes.new("ShaderNodeTexImage")
    tex_albedo.image = maps["albedo"]
    tex_normal = nodes.new("ShaderNodeTexImage")
    tex_normal.image = maps["normal"]
    tex_rough = nodes.new("ShaderNodeTexImage")
    tex_rough.image = maps["roughness"]
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(tex_albedo.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex_rough.outputs["Color"], bsdf.inputs["Roughness"])
    links.new(tex_normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return material


def _uv_smart_project(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def _add_ellipsoid(bm: bmesh.types.BMesh, center: Vector, radii: Vector, segments: int = 10, rings: int = 6) -> None:
    verts: list[bmesh.types.BMVert] = []
    for ring in range(rings + 1):
        v_t = ring / rings
        pitch = math.pi * (v_t - 0.5)
        y = math.sin(pitch) * radii.y
        ring_r = math.cos(pitch)
        for seg in range(segments):
            u_t = seg / segments
            yaw = u_t * math.tau
            x = math.cos(yaw) * radii.x * ring_r
            z = math.sin(yaw) * radii.z * ring_r
            verts.append(bm.verts.new(center + Vector((x, y, z))))
    bm.verts.ensure_lookup_table()
    for ring in range(rings):
        for seg in range(segments):
            a = ring * segments + seg
            b = ring * segments + ((seg + 1) % segments)
            c = (ring + 1) * segments + ((seg + 1) % segments)
            d = (ring + 1) * segments + seg
            bm.faces.new((verts[a], verts[b], verts[c], verts[d]))


def _add_quad(bm: bmesh.types.BMesh, a: Vector, b: Vector, c: Vector, d: Vector) -> None:
    va, vb, vc, vd = bm.verts.new(a), bm.verts.new(b), bm.verts.new(c), bm.verts.new(d)
    bm.faces.new((va, vb, vc, vd))


def _add_tri(bm: bmesh.types.BMesh, a: Vector, b: Vector, c: Vector) -> None:
    bm.faces.new((bm.verts.new(a), bm.verts.new(b), bm.verts.new(c)))


def _build_standing_bird(spec: dict) -> bpy.types.Object:
    """Standing waterfowl: grounded legs, folded wings, catalog neck length."""
    scale = _scale_factor(spec)
    body = Vector(spec["body"]) * scale
    body_radius = Vector((body.z, body.y, body.x)) * 0.5
    head_r = float(spec["head"]) * scale
    neck_len = float(spec["neck"]) * scale
    neck_curve = float(spec["neck_curve"]) * scale
    leg_len = float(spec["legs"]) * scale
    beak_len = float(spec["beak"]) * scale
    wing_chord = float(spec["wing_chord"]) * scale
    tail_len = float(spec["tail"]) * scale

    bm = bmesh.new()
    # Author in Y-up / Z-forward, then rotate into Blender Z-up like harbour gulls.
    body_center = Vector((0.0, leg_len + body_radius.y * 1.05, 0.0))
    _add_ellipsoid(bm, body_center, body_radius, segments=10, rings=6)

    # S-curve neck toward -Z (forward): rise, then tip forward for swan/goose.
    neck_base = body_center + Vector((0.0, body_radius.y * 0.55, -body_radius.z * 0.55))
    neck_mid = neck_base + Vector((0.0, neck_len * 0.55 + neck_curve * 0.35, -neck_len * 0.18))
    neck_end = neck_mid + Vector((0.0, neck_len * 0.25 - neck_curve * 0.15, -neck_len * 0.55 - neck_curve * 0.35))
    for point, radius in (
        (neck_base.lerp(neck_mid, 0.35), head_r * 0.55),
        (neck_mid, head_r * 0.48),
        (neck_mid.lerp(neck_end, 0.55), head_r * 0.42),
    ):
        _add_ellipsoid(bm, point, Vector((radius * 0.85, radius * 1.05, radius * 0.85)), segments=7, rings=4)

    head_center = neck_end + Vector((0.0, head_r * 0.35, -head_r * 0.15))
    _add_ellipsoid(bm, head_center, Vector((head_r * 0.90, head_r, head_r * 0.95)), segments=8, rings=5)

    if spec.get("cap"):
        _add_ellipsoid(
            bm,
            head_center + Vector((0.0, head_r * 0.28, -head_r * 0.05)),
            Vector((head_r * 0.82, head_r * 0.48, head_r * 0.78)),
            segments=8,
            rings=3,
        )

    beak_tip = head_center + Vector((0.0, -head_r * 0.05, -head_r - beak_len))
    beak_base_l = head_center + Vector((-head_r * 0.24, -head_r * 0.04, -head_r * 0.72))
    beak_base_r = head_center + Vector((head_r * 0.24, -head_r * 0.04, -head_r * 0.72))
    beak_base_t = head_center + Vector((0.0, head_r * 0.10, -head_r * 0.68))
    _add_tri(bm, beak_base_l, beak_base_t, beak_tip)
    _add_tri(bm, beak_base_t, beak_base_r, beak_tip)
    _add_tri(bm, beak_base_r, beak_base_l, beak_tip)

    # Folded wings: short slabs along the flanks (not a glide span).
    fold_span = body_radius.x * 1.15
    for side in (-1.0, 1.0):
        shoulder = body_center + Vector((side * body_radius.x * 0.72, body_radius.y * 0.18, -body_radius.z * 0.05))
        tip = shoulder + Vector((side * fold_span * 0.35, -body_radius.y * 0.55, body_radius.z * 0.55))
        rear = tip + Vector((-side * fold_span * 0.08, -body_radius.y * 0.08, wing_chord * 0.35))
        front = shoulder + Vector((side * fold_span * 0.05, body_radius.y * 0.05, -wing_chord * 0.22))
        _add_quad(bm, shoulder, front, tip, rear)
        mid = shoulder.lerp(tip, 0.55)
        _add_tri(
            bm,
            mid,
            tip,
            tip + Vector((-side * fold_span * 0.12, -body_radius.y * 0.12, wing_chord * 0.18)),
        )

    # Tail fan.
    tail_root = body_center + Vector((0.0, body_radius.y * 0.05, body_radius.z * 0.92))
    tip = tail_root + Vector((0.0, -body_radius.y * 0.05, tail_len))
    left = tail_root + Vector((-tail_len * 0.22, 0.0, tail_len * 0.40))
    right = tail_root + Vector((tail_len * 0.22, 0.0, tail_len * 0.40))
    _add_tri(bm, left, right, tip)

    # Standing legs and webbed feet.
    for side in (-1.0, 1.0):
        hip = body_center + Vector((side * body_radius.x * 0.32, -body_radius.y * 0.72, body_radius.z * 0.05))
        ankle = Vector((side * body_radius.x * 0.30, leg_len * 0.18, body_radius.z * 0.02))
        foot = Vector((side * body_radius.x * 0.30, 0.0, -leg_len * 0.08))
        _add_ellipsoid(bm, hip.lerp(ankle, 0.45), Vector((0.014, leg_len * 0.32, 0.014)), segments=5, rings=3)
        _add_ellipsoid(bm, ankle.lerp(foot, 0.45), Vector((0.012, leg_len * 0.18, 0.012)), segments=5, rings=3)
        # Simple web footprint.
        _add_tri(
            bm,
            foot + Vector((-0.018, 0.004, -0.010)),
            foot + Vector((0.018, 0.004, -0.010)),
            foot + Vector((0.0, 0.004, -0.045)),
        )

    mesh = bpy.data.meshes.new("BirdMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("BirdBody", mesh)
    bpy.context.collection.objects.link(obj)

    obj.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    coords = [obj.matrix_world @ Vector(v.co) for v in obj.data.vertices]
    min_z = min(c.z for c in coords)
    obj.location.z -= min_z
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    obj.select_set(False)
    return obj


def _mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    coords = [obj.matrix_world @ Vector(v.co) for v in obj.data.vertices]
    xs = [c.x for c in coords]
    ys = [c.y for c in coords]
    zs = [c.z for c in coords]
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return {
        "triangles": triangles,
        "dimensions_m": [
            round(max(xs) - min(xs), 4),
            round(max(zs) - min(zs), 4),
            round(max(ys) - min(ys), 4),
        ],
        "largest_axis_m": round(max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)), 4),
        "ground_min_z": round(min(zs), 6),
    }


def _export_glb(obj: bpy.types.Object, path: Path) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path),
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
    )
    metrics = _mesh_metrics(obj)
    metrics["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    metrics["path"] = str(path.relative_to(ROOT))
    return metrics


def _render_species_preview(obj: bpy.types.Object, path: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.42, 0.48, 0.52)

    bpy.ops.object.light_add(type="AREA", location=(-1.4, -1.8, 2.2))
    key = bpy.context.object
    key.data.energy = 480.0
    key.data.size = 2.0

    dims = _mesh_metrics(obj)["dimensions_m"]
    span = max(float(dims[0]), float(dims[1]), float(dims[2]), 0.4)
    bpy.ops.object.camera_add(location=(span * 1.05, -span * 1.35, span * 0.62))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, span * 0.25)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.45
    scene.camera = camera
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)


def build_species(species: str, spec: dict) -> dict[str, object]:
    _reset_scene()
    maps = _create_feather_maps(species, spec["colors"][0], spec["colors"][1], spec.get("breast"))
    material = _make_material(f"{species}_feather", maps, _hex_to_linear(spec["colors"][0]))
    obj = _build_standing_bird(spec)
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)
    _uv_smart_project(obj)

    out_dir = BIRDS_DIR / species
    # Replace prior Sketchfab/import mallard assets with the catalog mesh.
    if out_dir.exists():
        for stale in out_dir.glob("*"):
            if stale.is_file():
                stale.unlink()
    path = out_dir / "standing.glb"
    metrics = _export_glb(obj, path)
    metrics["species"] = species
    metrics["pose"] = "standing"
    metrics["neck"] = spec["neck"]
    _render_species_preview(obj, EVIDENCE_DIR / "previews" / f"{species}_standing.png")
    preview_report = REPORTS_DIR / f"p2_035_{species}_reference.png"
    preview_report.parent.mkdir(parents=True, exist_ok=True)
    preview_src = EVIDENCE_DIR / "previews" / f"{species}_standing.png"
    if preview_src.exists():
        preview_report.write_bytes(preview_src.read_bytes())
        metrics["reference_plate"] = str(preview_report.relative_to(ROOT))
    return metrics


def _compose_reference_sheet(reports: list[dict[str, object]]) -> str | None:
    """Side-by-side PNG of the four standing previews for verify readability."""
    try:
        from PIL import Image
    except ImportError:
        return None
    previews = []
    for report in reports:
        species = str(report["species"])
        path = EVIDENCE_DIR / "previews" / f"{species}_standing.png"
        if path.exists():
            previews.append(Image.open(path).convert("RGBA"))
    if len(previews) != 4:
        return None
    cell = 512
    sheet = Image.new("RGBA", (cell * 4, cell), (48, 56, 62, 255))
    for index, image in enumerate(previews):
        image.thumbnail((cell - 16, cell - 16))
        ox = index * cell + (cell - image.width) // 2
        oy = (cell - image.height) // 2
        sheet.paste(image, (ox, oy), image)
    out = REPORTS_DIR / "p2_035_waterfowl_reference_sheet.png"
    sheet.convert("RGB").save(out, "PNG")
    return str(out.relative_to(ROOT))


def main() -> int:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    all_reports: list[dict[str, object]] = []
    for species, spec in SPECIES.items():
        print(f"Building {species}...", flush=True)
        all_reports.append(build_species(species, spec))

    sheet = _compose_reference_sheet(all_reports)
    report_path = EVIDENCE_DIR / "report.json"
    report_path.write_text(
        json.dumps({"generator": GENERATOR_VERSION, "assets": all_reports, "reference_sheet": sheet}, indent=2) + "\n",
        encoding="utf-8",
    )
    state = {
        "asset_id": "bird.waterfowl_batch",
        "route": "deterministic_blender",
        "stage": "production_ready",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "note": "Hunyuan3D unavailable; catalog-proportion standing waterfowl with PBR feather maps and long-neck overrides",
    }
    (EVIDENCE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"ASSET_BATCH={len(all_reports)} report={report_path} sheet={sheet}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
