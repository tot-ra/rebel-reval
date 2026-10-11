#!/usr/bin/env python3
"""Deterministic harbour gull / tern GLBs for P2-034.

Hunyuan3D image-to-3D was unavailable in this environment, so production meshes
are built from MapViewBirdSpecies catalog proportions with PBR feather maps.
Reference plates under generated/comfyui/bird_gull_v1/references/ document the
intended silhouettes; a Hunyuan candidate pass remains a follow-up.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_harbour_gulls.py
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
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_DIR = ROOT / "generated" / "comfyui" / "bird_gull_v1"
BIRDS_DIR = ROOT / "assets" / "birds"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "harbour_gulls_v1"
TEXTURE_SIZE = 256
FLAP_KEYFRAMES = [-0.6, -0.3, 0.0, 0.4, 0.7, 0.4, 0.0, -0.3]

# Catalog geometry mirrors scripts/map/view3d/map_view_bird_species.gd.
SPECIES = {
    "herring_gull": {
        "group": "gull",
        "scale_m": 0.60,
        "body": (0.52, 0.24, 0.25),
        "head": 0.15,
        "wing_span": 1.20,
        "wing_chord": 0.36,
        "tail": 0.24,
        "beak": 0.19,
        "neck": 0.08,
        "legs": 0.19,
        "forked_tail": False,
        "colors": ((0xD9, 0xD8, 0xCF), (0x66, 0x6D, 0x73), (0xF0, 0xE8, 0xCE)),
        "cap": None,
    },
    "common_gull": {
        "group": "gull",
        "scale_m": 0.43,
        "body": (0.52, 0.24, 0.25),
        "head": 0.15,
        "wing_span": 1.20,
        "wing_chord": 0.36,
        "tail": 0.24,
        "beak": 0.19,
        "neck": 0.08,
        "legs": 0.19,
        "forked_tail": False,
        "colors": ((0xDE, 0xDD, 0xD4), (0x81, 0x88, 0x8D), (0xF2, 0xE4, 0xBD)),
        "cap": None,
    },
    "common_tern": {
        "group": "tern",
        "scale_m": 0.35,
        "body": (0.44, 0.18, 0.18),
        "head": 0.12,
        "wing_span": 1.32,
        "wing_chord": 0.27,
        "tail": 0.42,
        "beak": 0.25,
        "neck": 0.06,
        "legs": 0.12,
        "forked_tail": True,
        "colors": ((0xD8, 0xD9, 0xD4), (0x2D, 0x33, 0x36), (0xC7, 0x4A, 0x39)),
        "cap": (0x1A, 0x1C, 0x1E),
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


def _create_feather_maps(species: str, body_srgb: tuple[int, int, int], wing_srgb: tuple[int, int, int]) -> dict[str, bpy.types.Image]:
    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    body = np.array([c / 255.0 for c in body_srgb], dtype=np.float32)
    wing = np.array([c / 255.0 for c in wing_srgb], dtype=np.float32)
    wing_mask = np.clip((u - 0.42) * 3.2 + 0.15 * np.sin(v * math.tau * 2.0), 0.0, 1.0)
    feather = 0.5 + 0.5 * np.sin((u * 28.0 + v * 4.0) * math.tau)
    mix = body * (1.0 - wing_mask)[:, :, None] + wing * wing_mask[:, :, None]
    mix *= 0.92 + 0.08 * feather[:, :, None]
    alpha = np.ones((size, size, 1), dtype=np.float32)
    albedo_pixels = np.concatenate((mix, alpha), axis=2).ravel()

    albedo = bpy.data.images.new(f"{species}_albedo", size, size, alpha=False)
    albedo.pixels.foreach_set(albedo_pixels.tolist())
    albedo.colorspace_settings.name = "sRGB"
    albedo.file_format = "PNG"
    albedo.pack()

    # Soft bump from feather bars; packed as RGB normal-ish + height in B.
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

    roughness_vals = 0.74 + 0.14 * (0.5 + 0.5 * feather)
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
    bsdf.inputs["Roughness"].default_value = 0.82
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


def _add_ellipsoid(bm: bmesh.types.BMesh, center: Vector, radii: Vector, segments: int = 10, rings: int = 6) -> list[bmesh.types.BMVert]:
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
    return verts


def _add_quad(bm: bmesh.types.BMesh, a: Vector, b: Vector, c: Vector, d: Vector) -> None:
    va, vb, vc, vd = bm.verts.new(a), bm.verts.new(b), bm.verts.new(c), bm.verts.new(d)
    bm.faces.new((va, vb, vc, vd))


def _add_tri(bm: bmesh.types.BMesh, a: Vector, b: Vector, c: Vector) -> None:
    bm.faces.new((bm.verts.new(a), bm.verts.new(b), bm.verts.new(c)))


def _build_bird_mesh(spec: dict, wing_lift: float) -> bpy.types.Object:
    scale = _scale_factor(spec)
    body = Vector(spec["body"]) * scale
    body_radius = Vector((body.z, body.y, body.x)) * 0.5
    head_r = float(spec["head"]) * scale
    neck_len = float(spec["neck"]) * scale
    leg_len = float(spec["legs"]) * scale
    beak_len = float(spec["beak"]) * scale
    wing_span = float(spec["wing_span"]) * scale
    wing_chord = float(spec["wing_chord"]) * scale
    tail_len = float(spec["tail"]) * scale

    bm = bmesh.new()
    body_center = Vector((0.0, leg_len + body_radius.y * 1.05, 0.0))
    _add_ellipsoid(bm, body_center, body_radius, segments=10, rings=6)

    neck_start = body_center + Vector((0.0, body_radius.y * 0.38, -body_radius.z * 0.58))
    neck_end = neck_start + Vector((0.0, neck_len * 0.86, -neck_len * 0.28))
    head_center = neck_end + Vector((0.0, head_r * 0.48, -head_r * 0.18))
    _add_ellipsoid(bm, head_center, Vector((head_r * 0.88, head_r, head_r * 0.92)), segments=8, rings=5)

    # Cap for tern.
    if spec.get("cap"):
        _add_ellipsoid(
            bm,
            head_center + Vector((0.0, head_r * 0.35, -head_r * 0.05)),
            Vector((head_r * 0.78, head_r * 0.42, head_r * 0.70)),
            segments=8,
            rings=3,
        )

    beak_tip = head_center + Vector((0.0, -head_r * 0.08, -head_r - beak_len))
    beak_base_l = head_center + Vector((-head_r * 0.22, -head_r * 0.05, -head_r * 0.75))
    beak_base_r = head_center + Vector((head_r * 0.22, -head_r * 0.05, -head_r * 0.75))
    beak_base_t = head_center + Vector((0.0, head_r * 0.12, -head_r * 0.70))
    _add_tri(bm, beak_base_l, beak_base_t, beak_tip)
    _add_tri(bm, beak_base_t, beak_base_r, beak_tip)
    _add_tri(bm, beak_base_r, beak_base_l, beak_tip)

    half_span = max(wing_span * 0.5, body_radius.x * 1.4)
    lift = wing_lift * body_radius.y * 1.8
    for side in (-1.0, 1.0):
        shoulder = body_center + Vector((side * body_radius.x * 0.58, body_radius.y * 0.32 + lift, -body_radius.z * 0.08))
        elbow = shoulder + Vector((side * half_span * 0.30, half_span * 0.03 + lift * 0.15, -wing_chord * 0.03))
        wrist = shoulder + Vector((side * half_span * 0.62, half_span * 0.07 + lift * 0.30, wing_chord * 0.05))
        tip = shoulder + Vector((side * half_span, half_span * 0.10 + lift * 0.40, wing_chord * 0.14))
        rear_shoulder = shoulder + Vector((0.0, -half_span * 0.015, body_radius.z * 0.82))
        rear_elbow = elbow + Vector((-side * half_span * 0.03, -half_span * 0.02, wing_chord * 0.66))
        rear_wrist = wrist + Vector((-side * half_span * 0.05, -half_span * 0.03, wing_chord * 0.52))
        rear_tip = tip + Vector((-side * half_span * 0.10, -half_span * 0.035, wing_chord * 0.30))
        _add_quad(bm, shoulder, elbow, rear_elbow, rear_shoulder)
        _add_quad(bm, elbow, wrist, rear_wrist, rear_elbow)
        _add_quad(bm, wrist, tip, rear_tip, rear_wrist)
        for feather_index in range(5):
            feather_t = feather_index / 5.0
            anchor = wrist.lerp(tip, 0.15 + feather_t * 0.55)
            rear_anchor = rear_wrist.lerp(rear_tip, 0.15 + feather_t * 0.55)
            feather_tip = tip + Vector(
                (-side * half_span * feather_t * 0.10, -half_span * feather_t * 0.02, wing_chord * (0.16 + feather_t * 0.22))
            )
            width = max(wing_chord * (0.11 - feather_t * 0.03), 0.010)
            base = anchor.lerp(rear_anchor, 0.25)
            side_vec = (feather_tip - base).cross(Vector((0.0, 1.0, 0.0)))
            if side_vec.length < 1e-6:
                side_vec = Vector((side, 0.0, 0.0))
            side_vec.normalize()
            side_vec *= width * 0.5
            _add_tri(bm, base - side_vec, base + side_vec, feather_tip)

    # Tail - forked for tern.
    tail_root = body_center + Vector((0.0, body_radius.y * 0.05, body_radius.z * 0.92))
    if spec["forked_tail"]:
        for side in (-1.0, 1.0):
            tip = tail_root + Vector((side * tail_len * 0.28, -body_radius.y * 0.05, tail_len))
            left = tail_root + Vector((side * tail_len * 0.08 - 0.01, 0.0, tail_len * 0.35))
            right = tail_root + Vector((side * tail_len * 0.08 + 0.01, 0.0, tail_len * 0.35))
            _add_tri(bm, left, right, tip)
    else:
        tip = tail_root + Vector((0.0, -body_radius.y * 0.02, tail_len))
        left = tail_root + Vector((-tail_len * 0.18, 0.0, tail_len * 0.35))
        right = tail_root + Vector((tail_len * 0.18, 0.0, tail_len * 0.35))
        _add_tri(bm, left, right, tip)

    # Tucked legs for gliding silhouette.
    for side in (-1.0, 1.0):
        hip = body_center + Vector((side * body_radius.x * 0.28, -body_radius.y * 0.55, body_radius.z * 0.10))
        foot = hip + Vector((0.0, -leg_len * 0.55, body_radius.z * 0.08))
        _add_ellipsoid(bm, hip.lerp(foot, 0.5), Vector((0.012, leg_len * 0.28, 0.012)), segments=5, rings=3)

    mesh = bpy.data.meshes.new("BirdMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("BirdBody", mesh)
    bpy.context.collection.objects.link(obj)

    # Center XZ, keep Y (up in Blender before Y-up export) grounded relatively.
    # glTF Y-up export remaps Blender Z-up: we author Blender Z-forward X-right Y-up already via Vector layout.
    # Our vectors use Y as up and Z as forward - Blender default is Z-up, so rotate -90 X after build.
    obj.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    # Ground so lowest vertex sits at y=0 after rotation into Blender Z-up.
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
    scene.world.color = (0.45, 0.45, 0.48)

    bpy.ops.object.light_add(type="AREA", location=(-1.4, -1.8, 2.2))
    key = bpy.context.object
    key.data.energy = 480.0
    key.data.size = 2.0

    dims = _mesh_metrics(obj)["dimensions_m"]
    span = max(float(dims[0]), float(dims[1]), float(dims[2]), 0.4)
    bpy.ops.object.camera_add(location=(span * 0.9, -span * 1.2, span * 0.55))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, span * 0.2)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.35
    scene.camera = camera
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)


def build_species(species: str, spec: dict) -> list[dict[str, object]]:
    maps = _create_feather_maps(species, spec["colors"][0], spec["colors"][1])
    material = _make_material(f"{species}_feather", maps, _hex_to_linear(spec["colors"][0]))
    out_dir = BIRDS_DIR / species
    reports: list[dict[str, object]] = []

    for frame_index, lift in enumerate(FLAP_KEYFRAMES):
        _reset_scene()
        # Recreate packed images/material after factory reset.
        maps = _create_feather_maps(species, spec["colors"][0], spec["colors"][1])
        material = _make_material(f"{species}_feather", maps, _hex_to_linear(spec["colors"][0]))
        obj = _build_bird_mesh(spec, lift)
        if obj.data.materials:
            obj.data.materials[0] = material
        else:
            obj.data.materials.append(material)
        _uv_smart_project(obj)
        path = out_dir / f"gliding_{frame_index:02d}.glb"
        metrics = _export_glb(obj, path)
        metrics["species"] = species
        metrics["frame"] = frame_index
        metrics["wing_lift"] = lift
        reports.append(metrics)
        if frame_index == 2:
            # Neutral flap also published as static gliding.glb.
            gliding_path = out_dir / "gliding.glb"
            gliding_path.write_bytes(path.read_bytes())
            reports.append({**metrics, "path": str(gliding_path.relative_to(ROOT)), "frame": "neutral"})
            _render_species_preview(obj, EVIDENCE_DIR / "previews" / f"{species}_gliding.png")
    return reports


def main() -> int:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    all_reports: list[dict[str, object]] = []
    for species, spec in SPECIES.items():
        print(f"Building {species}...", flush=True)
        all_reports.extend(build_species(species, spec))

    report_path = EVIDENCE_DIR / "report.json"
    report_path.write_text(json.dumps({"generator": GENERATOR_VERSION, "assets": all_reports}, indent=2) + "\n", encoding="utf-8")
    state = {
        "asset_id": "bird.harbour_gull_batch",
        "route": "deterministic_blender",
        "stage": "production_ready",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "note": "Hunyuan3D unavailable; catalog-proportion Blender meshes with PBR feather maps",
    }
    (EVIDENCE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"ASSET_BATCH={len(all_reports)} report={report_path}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
