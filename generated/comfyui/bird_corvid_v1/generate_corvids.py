#!/usr/bin/env python3
"""Build the P2-038 custom perched corvid batch.

The approved single-image Hunyuan workflow is retained beside this script, but
its local backend was unavailable. This deterministic cleanup fallback uses the
same Leonardo silhouette references and catalog dimensions while making the two
critical gameplay cues geometric: the hooded crow's grey torso is a separate
material region and the magpie has four graduated tail vanes.

Run from the repository root:
    blender --background --factory-startup --python generated/comfyui/bird_corvid_v1/generate_corvids.py
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
STAGE = ROOT / "generated/comfyui/bird_corvid_v1"
BIRDS = ROOT / "assets/birds"
EVIDENCE = ROOT / "docs/reports/images/fauna"
VERSION = "bird_corvid_v1"

SPECIES = {
    "hooded_crow": {
        "scale": 0.49, "body_len": 0.265, "body_w": 0.125, "body_h": 0.145,
        "head": 0.078, "bill": 0.105, "tail": 0.205,
        "body": "777b78", "dark": "171b1d", "accent": "30383b", "eye": "111315",
    },
    "rook": {
        "scale": 0.46, "body_len": 0.255, "body_w": 0.115, "body_h": 0.135,
        "head": 0.073, "bill": 0.135, "tail": 0.185,
        "body": "202629", "dark": "101416", "accent": "354750", "bill_color": "8f8b7d", "eye": "171512",
    },
    "western_jackdaw": {
        "scale": 0.34, "body_len": 0.205, "body_w": 0.102, "body_h": 0.118,
        "head": 0.067, "bill": 0.073, "tail": 0.135,
        "body": "303638", "dark": "171c1e", "accent": "909b99", "eye": "b9d4d5",
    },
    "eurasian_magpie": {
        "scale": 0.46, "body_len": 0.215, "body_w": 0.105, "body_h": 0.125,
        "head": 0.068, "bill": 0.085, "tail": 0.345,
        "body": "e2e0d8", "dark": "121719", "accent": "315f59", "eye": "151719",
    },
}


def srgb(hex_color: str) -> tuple[float, float, float, float]:
    channels = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return (*linear, 1.0)


def png_rgba(path: Path, rgba: tuple[int, int, int, int]) -> Path:
    """Write a fixed 4x4 RGBA PNG so Blender embeds stable bytes across rebuilds."""
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = b"".join(b"\x00" + bytes(rgba) * 4 for _ in range(4))
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    encoded = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    if not path.exists() or path.read_bytes() != encoded:
        path.write_bytes(encoded)
    return path


def material(name: str, color: str, roughness: float = 0.72, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    # File-backed maps keep both the fauna PBR contract and byte-stable GLBs.
    texture_dir = STAGE / "textures"
    normal_path = png_rgba(texture_dir / (name + "_normal.png"), (128, 128, 255, 255))
    rough = max(0, min(255, round(roughness * 255)))
    rough_path = png_rgba(texture_dir / (name + "_roughness.png"), (rough, rough, rough, 255))
    normal_image = bpy.data.images.load(str(normal_path), check_existing=False)
    normal_image.colorspace_settings.name = "Non-Color"
    rough_image = bpy.data.images.load(str(rough_path), check_existing=False)
    rough_image.colorspace_settings.name = "Non-Color"
    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_tex.image = normal_image
    normal_map = nodes.new("ShaderNodeNormalMap")
    rough_tex = nodes.new("ShaderNodeTexImage")
    rough_tex.image = rough_image
    links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(rough_tex.outputs["Color"], bsdf.inputs["Roughness"])
    return mat


def smooth(obj: bpy.types.Object) -> bpy.types.Object:
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def ellipsoid(name: str, loc, scale, mat, segments=16, rings=10) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return smooth(obj)


def cone_between(name: str, start, end, r1: float, r2: float, mat, vertices=10) -> bpy.types.Object:
    start, end = Vector(start), Vector(end)
    delta = end - start
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=delta.length, location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(delta.normalized())
    obj.data.materials.append(mat)
    return smooth(obj)


def vane(name: str, root, tip, half_width: float, mat, layer: float = 0.004) -> bpy.types.Object:
    root, tip = Vector(root), Vector(tip)
    direction = (tip - root).normalized()
    side = Vector((1, 0, 0))
    verts = [
        root + side * half_width, root - side * half_width,
        tip - side * half_width * 0.28, tip + side * half_width * 0.28,
    ]
    faces = [(0, 1, 2, 3)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    solid = obj.modifiers.new("FeatherThickness", "SOLIDIFY")
    solid.thickness = layer
    bevel = obj.modifiers.new("FeatherEdge", "BEVEL")
    bevel.width = layer * 0.7
    bevel.segments = 2
    return obj


def build(species: str, spec: dict) -> list[bpy.types.Object]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {
        "body": material(f"{species}_body", spec["body"]),
        "dark": material(f"{species}_dark", spec["dark"], 0.61),
        "accent": material(f"{species}_accent", spec["accent"], 0.53, 0.04),
        "bill": material(f"{species}_bill", spec.get("bill_color", "202326"), 0.76),
        "leg": material(f"{species}_leg", "343537", 0.84),
        "eye": material(f"{species}_eye", spec["eye"], 0.22),
        "white": material(f"{species}_white", "e2e0d8", 0.81),
    }
    out = []
    # Feet establish exact ground contact; the crouched legs sell a perched pose without a runtime pedestal.
    for side in (-1, 1):
        x = side * spec["body_w"] * 0.34
        out.append(cone_between(f"Leg_{side}", (x, -0.025, 0.072), (x, -0.015, 0.018), 0.009, 0.006, mats["leg"], 8))
        for toe_i, dx in enumerate((-0.022, 0.0, 0.022)):
            out.append(cone_between(f"Toe_{side}_{toe_i}", (x, -0.014, 0.018), (x + dx, -0.065, 0.0), 0.005, 0.0015, mats["leg"], 7))
        out.append(cone_between(f"BackToe_{side}", (x, -0.010, 0.017), (x - side * 0.012, 0.026, 0.0), 0.0045, 0.0015, mats["leg"], 7))

    body_z = 0.072 + spec["body_h"] * 0.78
    out.append(ellipsoid("Torso", (0, 0, body_z), (spec["body_w"], spec["body_len"], spec["body_h"]), mats["body"]))
    chest_mat = mats["body"] if species == "hooded_crow" else (mats["white"] if species == "eurasian_magpie" else mats["dark"])
    out.append(ellipsoid("ChestPatch", (0, -spec["body_len"] * 0.58, body_z + 0.005), (spec["body_w"] * 0.76, spec["body_len"] * 0.48, spec["body_h"] * 0.78), chest_mat, 14, 9))

    head_y = -spec["body_len"] * 0.80
    head_z = body_z + spec["body_h"] * 0.83
    out.append(ellipsoid("Head", (0, head_y, head_z), (spec["head"] * 0.92, spec["head"], spec["head"]), mats["dark"], 14, 9))
    if species == "western_jackdaw":
        out.append(ellipsoid("SilverNape", (0, head_y + spec["head"] * 0.50, head_z + 0.006), (spec["head"] * 0.93, spec["head"] * 0.62, spec["head"] * 0.74), mats["accent"], 14, 8))
    beak_start = (0, head_y - spec["head"] * 0.55, head_z + 0.002)
    beak_end = (0, beak_start[1] - spec["bill"], head_z - spec["bill"] * 0.10)
    out.append(cone_between("Bill", beak_start, beak_end, spec["head"] * 0.34, 0.003, mats["bill"], 10))
    for side in (-1, 1):
        out.append(ellipsoid(f"Eye_{side}", (side * spec["head"] * 0.78, head_y - spec["head"] * 0.30, head_z + spec["head"] * 0.20), (0.010, 0.007, 0.010), mats["eye"], 10, 6))

    # Closed wings are layered vanes, so color blocking remains visible at the gameplay camera distance.
    wing_mat = mats["dark"]
    for side in (-1, 1):
        x = side * spec["body_w"] * 0.88
        root = (x, -spec["body_len"] * 0.25, body_z + spec["body_h"] * 0.47)
        for i in range(5):
            y_tip = spec["body_len"] * (0.66 + i * 0.055)
            z_tip = body_z - spec["body_h"] * (0.08 + i * 0.045)
            out.append(vane(f"Wing_{side}_{i}", root, (x + side * (0.015 + i * 0.003), y_tip, z_tip), spec["body_w"] * (0.37 - i * 0.025), wing_mat))
        if species == "eurasian_magpie":
            out.append(vane(f"WhiteScapular_{side}", (x, -0.055, body_z + 0.055), (x + side * 0.012, 0.095, body_z + 0.018), spec["body_w"] * 0.25, mats["white"], 0.005))

    tail_root = (0, spec["body_len"] * 0.62, body_z + 0.015)
    tail_count = 4 if species == "eurasian_magpie" else 3
    for i in range(tail_count):
        side = (i - (tail_count - 1) / 2.0)
        graduation = (1.0 - abs(side) * (0.10 if species == "eurasian_magpie" else 0.15))
        length = spec["tail"] * graduation
        out.append(vane(f"Tail_{i}", (side * 0.012, tail_root[1], tail_root[2] + abs(side) * 0.003), (side * 0.020, tail_root[1] + length, tail_root[2] - length * 0.18), spec["body_w"] * (0.20 if species == "eurasian_magpie" else 0.25), mats["accent"] if species == "eurasian_magpie" else mats["dark"], 0.006))

    for obj in out:
        obj.select_set(True)
    # Solidified toe and feather geometry extends beyond source vertices. Normalize
    # evaluated bounds after every modifier so the exported glTF Y-up feet sit at 0.
    evaluated = bpy.context.evaluated_depsgraph_get()
    min_z = min(
        (obj.evaluated_get(evaluated).matrix_world @ Vector(corner)).z
        for obj in out for corner in obj.evaluated_get(evaluated).bound_box
    )
    for obj in out:
        obj.location.z -= min_z
    bpy.context.view_layer.update()
    return out


def scene_bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).bound_box]
    mins = [min(p[i] for p in points) for i in range(3)]
    maxs = [max(p[i] for p in points) for i in range(3)]
    return mins, maxs


def export_and_render(species: str, spec: dict) -> dict:
    objects = build(species, spec)
    target = BIRDS / species / "perched.glb"
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_materials="EXPORT", export_cameras=False, export_lights=False)

    mins, maxs = scene_bounds(objects)
    dimensions = [maxs[i] - mins[i] for i in range(3)]
    bpy.ops.object.camera_add(location=(0.78, -1.02, 0.61))
    camera = bpy.context.object
    camera.name = "EvidenceCamera"
    target_point = Vector((0, 0.05, 0.18))
    camera.rotation_euler = (target_point - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(dimensions) * 1.28
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(-0.7, -0.8, 1.1))
    bpy.context.object.data.energy = 650
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 1.8
    bpy.ops.object.light_add(type="AREA", location=(0.8, 0.2, 0.65))
    bpy.context.object.data.energy = 350
    bpy.context.object.data.size = 1.3
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("EvidenceWorld")
    scene.world.color = (0.075, 0.085, 0.095)
    preview = EVIDENCE / f"p2_038_{species}_reference.png"
    scene.render.filepath = str(preview)
    bpy.ops.render.render(write_still=True)

    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    triangles = sum(len(p.vertices) - 2 for o in objects if o.type == "MESH" for p in o.data.polygons)
    return {"species": species, "pose": "perched", "path": str(target.relative_to(ROOT)), "triangles": triangles, "dimensions_blender_xyz_m": [round(v, 4) for v in dimensions], "ground_min_z": round(mins[2], 5), "sha256": digest, "reference_plate": str(preview.relative_to(ROOT))}


def main() -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    assets = [export_and_render(name, spec) for name, spec in SPECIES.items()]
    report = {"generator": VERSION, "route": "image_to_3d_reference_with_deterministic_blender_cleanup_fallback", "assets": assets, "reference_sheet": "docs/reports/images/fauna/p2_038_corvid_reference_sheet.png"}
    (STAGE / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("ASSET_METRICS=" + json.dumps({a["species"]: {"triangles": a["triangles"], "sha256": a["sha256"][:12]} for a in assets}, separators=(",", ":")))


if __name__ == "__main__":
    main()
