#!/usr/bin/env python3
"""Deterministic standing wader GLBs for P2-036.

Hunyuan3D image-to-3D was unavailable in this environment, so production meshes
are built from MapViewBirdSpecies catalog proportions with PBR feather maps.
Grey heron keeps long neck/leg overrides, northern lapwing keeps the crown crest,
and common snipe keeps the long probing bill. Reference plates under
generated/comfyui/bird_wader_v1/ document silhouettes; an optional Hunyuan
candidate pass remains a follow-up.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_waders.py
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
EVIDENCE_DIR = ROOT / "generated" / "comfyui" / "bird_wader_v1"
BIRDS_DIR = ROOT / "assets" / "birds"
REPORTS_DIR = ROOT / "docs" / "reports" / "images" / "fauna"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "waders_v1"
TEXTURE_SIZE = 256

# Catalog geometry mirrors scripts/map/view3d/map_view_bird_species.gd
# (GROUP_WADER defaults + per-species overrides).
SPECIES = {
    "grey_heron": {
        "scale_m": 0.94,
        "body": (0.48, 0.19, 0.20),
        "head": 0.12,
        "wing_span": 1.02,
        "wing_chord": 0.31,
        "tail": 0.18,
        "beak": 0.48,
        "neck": 0.66,
        "legs": 0.72,
        "neck_curve": 0.42,
        "crest": False,
        "colors": ((0x85, 0x8D, 0x91), (0x44, 0x4B, 0x4E), (0xD6, 0xB0, 0x50)),
        "breast": (0xC8, 0xC9, 0xC4),
    },
    "northern_lapwing": {
        "scale_m": 0.30,
        "body": (0.45, 0.22, 0.23),
        "head": 0.12,
        "wing_span": 1.02,
        "wing_chord": 0.31,
        "tail": 0.18,
        "beak": 0.16,
        "neck": 0.08,
        "legs": 0.27,
        "neck_curve": 0.04,
        "crest": True,
        "colors": ((0x30, 0x3D, 0x39), (0xDE, 0xDB, 0xD0), (0x6F, 0x8A, 0x69)),
        "breast": (0xDE, 0xDB, 0xD0),
    },
    "common_snipe": {
        "scale_m": 0.27,
        "body": (0.42, 0.19, 0.19),
        "head": 0.12,
        "wing_span": 1.02,
        "wing_chord": 0.31,
        "tail": 0.18,
        "beak": 0.56,
        "neck": 0.05,
        "legs": 0.25,
        "neck_curve": 0.02,
        "crest": False,
        "colors": ((0x76, 0x66, 0x4C), (0x4F, 0x47, 0x38), (0xD0, 0xB5, 0x77)),
        "breast": (0xA8, 0x96, 0x72),
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


def _build_standing_wader(spec: dict) -> bpy.types.Object:
    """Standing wader: long thin legs, folded wings, catalog neck/beak/crest."""
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
    # Thin wader limbs stay readable without ballooning the silhouette.
    leg_radius = max(0.006 * scale, leg_len * 0.018)

    bm = bmesh.new()
    # Author in Y-up / Z-forward, then rotate into Blender Z-up.
    body_center = Vector((0.0, leg_len + body_radius.y * 1.05, 0.0))
    _add_ellipsoid(bm, body_center, body_radius, segments=10, rings=6)

    # Heron: tall S-curve; lapwing/snipe: short stub neck.
    neck_base = body_center + Vector((0.0, body_radius.y * 0.55, -body_radius.z * 0.40))
    if neck_len > body_radius.y * 1.2:
        # Upright rise then slight forward tip (grey heron).
        neck_mid = neck_base + Vector((0.0, neck_len * 0.62 + neck_curve * 0.20, -neck_len * 0.08))
        neck_end = neck_mid + Vector((0.0, neck_len * 0.20 - neck_curve * 0.10, -neck_len * 0.42 - neck_curve * 0.25))
    else:
        neck_mid = neck_base + Vector((0.0, neck_len * 0.55, -neck_len * 0.20))
        neck_end = neck_mid + Vector((0.0, neck_len * 0.35, -neck_len * 0.55))
    for point, radius in (
        (neck_base.lerp(neck_mid, 0.35), head_r * 0.50),
        (neck_mid, head_r * 0.42),
        (neck_mid.lerp(neck_end, 0.55), head_r * 0.38),
    ):
        _add_ellipsoid(bm, point, Vector((radius * 0.80, radius * 1.05, radius * 0.80)), segments=7, rings=4)

    head_center = neck_end + Vector((0.0, head_r * 0.35, -head_r * 0.12))
    _add_ellipsoid(bm, head_center, Vector((head_r * 0.90, head_r, head_r * 0.95)), segments=8, rings=5)

    if spec.get("crest"):
        # Northern lapwing crown crest: thin upright fan from the nape.
        crest_root = head_center + Vector((0.0, head_r * 0.15, head_r * 0.35))
        crest_tip = crest_root + Vector((0.0, head_r * 1.55, head_r * 0.85))
        crest_l = crest_root + Vector((-head_r * 0.18, head_r * 0.55, head_r * 0.20))
        crest_r = crest_root + Vector((head_r * 0.18, head_r * 0.55, head_r * 0.20))
        _add_tri(bm, crest_l, crest_r, crest_tip)
        mid = crest_root.lerp(crest_tip, 0.55)
        _add_tri(
            bm,
            mid + Vector((-head_r * 0.08, 0.0, 0.0)),
            mid + Vector((head_r * 0.08, 0.0, 0.0)),
            crest_tip + Vector((0.0, head_r * 0.12, head_r * 0.10)),
        )

    # Beak: snipe gets a long thin probe; heron a dagger; lapwing short.
    beak_half = head_r * (0.10 if beak_len > head_r * 2.5 else 0.22)
    beak_tip = head_center + Vector((0.0, -head_r * 0.02, -head_r - beak_len))
    beak_base_l = head_center + Vector((-beak_half, -head_r * 0.02, -head_r * 0.70))
    beak_base_r = head_center + Vector((beak_half, -head_r * 0.02, -head_r * 0.70))
    beak_base_t = head_center + Vector((0.0, head_r * 0.08, -head_r * 0.66))
    _add_tri(bm, beak_base_l, beak_base_t, beak_tip)
    _add_tri(bm, beak_base_t, beak_base_r, beak_tip)
    _add_tri(bm, beak_base_r, beak_base_l, beak_tip)

    fold_span = body_radius.x * 1.10
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

    tail_root = body_center + Vector((0.0, body_radius.y * 0.05, body_radius.z * 0.92))
    tip = tail_root + Vector((0.0, -body_radius.y * 0.05, tail_len))
    left = tail_root + Vector((-tail_len * 0.22, 0.0, tail_len * 0.40))
    right = tail_root + Vector((tail_len * 0.22, 0.0, tail_len * 0.40))
    _add_tri(bm, left, right, tip)

    # Thin standing legs and three-toe feet (not webbed waterfowl prints).
    for side in (-1.0, 1.0):
        hip = body_center + Vector((side * body_radius.x * 0.28, -body_radius.y * 0.70, body_radius.z * 0.02))
        ankle = Vector((side * body_radius.x * 0.26, leg_len * 0.16, body_radius.z * 0.01))
        foot = Vector((side * body_radius.x * 0.26, 0.0, -leg_len * 0.04))
        _add_ellipsoid(bm, hip.lerp(ankle, 0.45), Vector((leg_radius, leg_len * 0.34, leg_radius)), segments=5, rings=3)
        _add_ellipsoid(bm, ankle.lerp(foot, 0.45), Vector((leg_radius * 0.85, leg_len * 0.16, leg_radius * 0.85)), segments=5, rings=3)
        toe_len = max(0.018 * scale, leg_len * 0.08)
        for angle in (-0.35, 0.0, 0.35):
            toe_tip = foot + Vector((math.sin(angle) * toe_len * 0.35, 0.003, -math.cos(angle) * toe_len))
            _add_tri(
                bm,
                foot + Vector((-leg_radius, 0.003, 0.0)),
                foot + Vector((leg_radius, 0.003, 0.0)),
                toe_tip,
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
    obj = _build_standing_wader(spec)
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)
    _uv_smart_project(obj)

    out_dir = BIRDS_DIR / species
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*"):
        if stale.is_file():
            stale.unlink()
    path = out_dir / "standing.glb"
    metrics = _export_glb(obj, path)
    metrics["species"] = species
    metrics["pose"] = "standing"
    metrics["neck"] = spec["neck"]
    metrics["legs"] = spec["legs"]
    metrics["beak"] = spec["beak"]
    metrics["crest"] = bool(spec.get("crest"))
    _render_species_preview(obj, EVIDENCE_DIR / "previews" / f"{species}_standing.png")
    preview_report = REPORTS_DIR / f"p2_036_{species}_reference.png"
    preview_report.parent.mkdir(parents=True, exist_ok=True)
    preview_src = EVIDENCE_DIR / "previews" / f"{species}_standing.png"
    if preview_src.exists():
        preview_report.write_bytes(preview_src.read_bytes())
        metrics["reference_plate"] = str(preview_report.relative_to(ROOT))
    return metrics


def _compose_reference_sheet(reports: list[dict[str, object]]) -> str | None:
    """Side-by-side PNG of the three standing previews for verify readability."""
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
    if len(previews) != 3:
        return None
    cell = 512
    sheet = Image.new("RGBA", (cell * 3, cell), (48, 56, 62, 255))
    for index, image in enumerate(previews):
        image.thumbnail((cell - 16, cell - 16))
        ox = index * cell + (cell - image.width) // 2
        oy = (cell - image.height) // 2
        sheet.paste(image, (ox, oy), image)
    out = REPORTS_DIR / "p2_036_wader_reference_sheet.png"
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
        "asset_id": "bird.wader_batch",
        "route": "deterministic_blender",
        "stage": "production_ready",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "note": "Hunyuan3D unavailable; catalog-proportion standing waders with PBR feather maps, heron neck/legs, lapwing crest, snipe bill",
    }
    (EVIDENCE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"ASSET_BATCH={len(all_reports)} report={report_path} sheet={sheet}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
