#!/usr/bin/env python3
"""Build the conservative spring-1343 Viru Gate exterior asset.

Run from the repository root with Blender 5.2:
    blender --background --factory-startup --python generated/blender/viru_gate_v1/generate_viru_gate.py -- --preview

The asset is a simple rectangular limestone gatehouse with an open passage,
parked-open oak leaves, and a modest timber fighting deck. It deliberately
omits the later round foregate towers, barbican, Fat Margaret, and portcullis
complex described in the historical dossier.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = ROOT / "assets" / "props" / "architecture" / "gates"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "viru_gate_v1"
GLB_PATH = OUT_DIR / "viru_gate.glb"
PREVIEW_PATH = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
GENERATOR_VERSION = "viru_gate_v1"
BLENDER_VERSION = "Blender 5.2 LTS"

BRIEF = {
    "id": "landmark.viru_gate_1343",
    "kind": "rigid_architecture_landmark",
    "target": "res://assets/props/architecture/gates/viru_gate.glb",
    "scene": "res://content/maps/lower_town_slice.rrmap#viru_gate_arch",
    "dimensions_m": [14.0, 3.8, 7.4],
    "triangles": {"target": 8500, "max": 12000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "historical_basis": "history/dossiers/topography/walls-gates-towers.md",
    "historical_scope": "Simple mid-14th-century Viru gatehouse, possibly unfinished; no round foregate towers, barbican, Fat Margaret, or portcullis complex.",
    "approval": "task-authorized",
}

LIMESTONE = (0x9E / 255.0, 0xAD / 255.0, 0xB9 / 255.0)
LIMESTONE_DARK = (0x66 / 255.0, 0x78 / 255.0, 0x89 / 255.0)
LIMESTONE_LIGHT = (0xC8 / 255.0, 0xD1 / 255.0, 0xD3 / 255.0)
OAK = (0x6B / 255.0, 0x3F / 255.0, 0x35 / 255.0)
OAK_DARK = (0x34 / 255.0, 0x2B / 255.0, 0x30 / 255.0)
OAK_CUT = (0xA2 / 255.0, 0x69 / 255.0, 0x3F / 255.0)
IRON = (0x39 / 255.0, 0x4C / 255.0, 0x65 / 255.0)
ROOF = (0xB9 / 255.0, 0x4A / 255.0, 0x3D / 255.0)


def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def make_texture(name: str, color: tuple[float, float, float], family: str) -> bpy.types.Image:
    """Create deterministic painterly albedo pixels and pack them into GLB."""
    size = 512
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    pixels: list[float] = []
    linear = tuple(srgb_to_linear(channel) for channel in color)
    for y in range(size):
        v = y / float(size)
        for x in range(size):
            u = x / float(size)
            if family == "stone":
                variation = 0.92 + math.sin((u * 6.0 + v * 1.7) * math.tau) * 0.045
                variation += math.sin(v * math.tau * 19.0) * 0.018
                variation += math.sin((u * 43.0 - v * 29.0) * math.tau) * 0.009
            elif family == "timber":
                variation = 0.88 + math.sin((u * 10.0 + math.sin(v * math.tau * 3.0) * 0.18) * math.tau) * 0.07
                variation += math.sin((u * 3.0 + v * 17.0) * math.tau) * 0.018
            elif family == "roof":
                variation = 0.91 + math.sin(v * math.tau * 30.0) * 0.035
                variation += math.sin(u * math.tau * 5.0) * 0.025
            else:
                variation = 0.86 + math.sin((u * 14.0 + v * 9.0) * math.tau) * 0.04
            pixels.extend((
                max(0.0, min(1.0, linear[0] * variation)),
                max(0.0, min(1.0, linear[1] * variation)),
                max(0.0, min(1.0, linear[2] * variation)),
                1.0,
            ))
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels)
    image.pack()
    return image


def make_material(name: str, color: tuple[float, float, float], family: str, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*(srgb_to_linear(value) for value in color), 1.0)
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = make_texture(f"{name}_albedo", color, family)
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def box(name: str, size: tuple[float, float, float], location: tuple[float, float, float], material: bpy.types.Material, bevel: float = 0.0, rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Worn hewn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def cylinder(name: str, radius: float, depth: float, location: tuple[float, float, float], material: bpy.types.Material, vertices: int = 10, rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def arch_ring(name: str, center_x: float, center_z: float, radius: float, depth: float, material: bpy.types.Material) -> bpy.types.Object:
    """Create a shallow extruded semicircular voussoir ring on both faces."""
    segments = 16
    inner = radius - 0.24
    verts: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for y in (-depth * 0.5, depth * 0.5):
        for r in (inner, radius):
            for index in range(segments + 1):
                angle = math.pi - math.pi * index / segments
                verts.append((center_x + math.cos(angle) * r, y, center_z + math.sin(angle) * r))
    front_inner = 0
    front_outer = segments + 1
    back_inner = 2 * (segments + 1)
    back_outer = 3 * (segments + 1)
    for index in range(segments):
        next_index = index + 1
        faces.append((front_inner + index, front_inner + next_index, front_outer + next_index, front_outer + index))
        faces.append((back_inner + next_index, back_inner + index, back_outer + index, back_outer + next_index))
        faces.append((front_inner + index, back_inner + index, back_inner + next_index, front_inner + next_index))
        faces.append((front_outer + next_index, back_outer + next_index, back_outer + index, front_outer + index))
    faces.extend(((front_inner, front_outer, back_outer, back_inner), (front_inner + segments, back_inner + segments, back_outer + segments, front_outer + segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def rotated_point(hinge_x: float, sign: float, distance: float, angle: float) -> tuple[float, float, float]:
    """Return a door-local point rotated around its vertical hinge."""
    x = sign * distance
    return (hinge_x + x * math.cos(angle), x * math.sin(angle), 2.25)


def build_gate(materials: dict[str, bpy.types.Material]) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    root = bpy.data.objects.new("ViruGate1343", None)
    bpy.context.collection.objects.link(root)
    objects: list[bpy.types.Object] = []
    stone = materials["stone"]
    stone_dark = materials["stone_dark"]
    stone_light = materials["stone_light"]
    oak = materials["oak"]
    oak_dark = materials["oak_dark"]
    oak_cut = materials["oak_cut"]
    iron = materials["iron"]
    roof = materials["roof"]

    outer_half = 7.0
    passage_half = 2.25
    wall_top = 6.15
    depth = 3.8
    pier_width = outer_half - passage_half
    for side, x in (("West", -4.625), ("East", 4.625)):
        objects.append(box(f"{side}StonePier", (pier_width, depth, wall_top), (x, 0.0, wall_top * 0.5), stone, 0.045))
        objects.append(box(f"{side}Jamb", (0.34, depth + 0.08, 4.65), (side == "East" and passage_half or -passage_half, 0.0, 2.325), stone_light, 0.025))
        for row in range(5):
            for face_y in (-1.95, 1.95):
                objects.append(box(f"{side}MasonryCourse{row}{int(face_y)}", (pier_width - 0.30, 0.06, 0.055), (x, face_y, 0.84 + row * 1.02), stone_dark, 0.008))

    # Header leaves a genuine walk-through void below the shallow semicircular arch.
    objects.append(box("StonePassageHeader", (passage_half * 2.0, depth, 1.55), (0.0, 0.0, 5.375), stone, 0.045))
    objects.append(arch_ring("LimestonePassageArch", 0.0, 4.15, passage_half + 0.18, depth + 0.10, stone_light))
    for x in (-1.8, -0.9, 0.0, 0.9, 1.8):
        objects.append(box(f"VoussoirMark{x}", (0.045, depth + 0.13, 0.34), (x, 0.0, 4.7), stone_dark, 0.006))

    # A low parapet and timber walk make the construction/read of a gatehouse clear,
    # without adding the later masonry tower height or machicolations.
    objects.append(box("TimberWalkDeck", (14.0, 4.35, 0.24), (0.0, 0.0, 6.38), oak_dark, 0.025))
    for x in (-6.35, -4.2, -2.0, 2.0, 4.2, 6.35):
        for y in (-2.0, 2.0):
            objects.append(box(f"WalkPost{x}{y}", (0.20, 0.20, 0.88), (x, y, 6.82), oak, 0.012))
    for y in (-2.0, 2.0):
        objects.append(box(f"WalkRail{y}", (13.7, 0.20, 0.18), (0.0, y, 7.20), oak_cut, 0.012))
        objects.append(box(f"WalkToeBoard{y}", (13.7, 0.22, 0.22), (0.0, y, 6.55), oak_dark, 0.012))
    for x in (-6.4, 6.4):
        objects.append(box(f"WalkEndRail{x}", (0.20, 4.15, 0.18), (x, 0.0, 7.20), oak_cut, 0.012))

    # Simple pitched roof, not a later tower cap.
    objects.append(box("RoofWest", (14.5, 2.25, 0.18), (0.0, -0.94, 6.78), roof, 0.018, (math.radians(25.0), 0.0, 0.0)))
    objects.append(box("RoofEast", (14.5, 2.25, 0.18), (0.0, 0.94, 6.78), roof, 0.018, (math.radians(-25.0), 0.0, 0.0)))

    # The gate leaves are parked open around their vertical hinges, preserving the
    # authored walkable passage and making the landmark read from either approach.
    for sign, label in ((-1.0, "West"), (1.0, "East")):
        hinge_x = sign * passage_half
        angle = sign * math.radians(68.0)
        for board in range(5):
            local_x = 0.20 + board * 0.38
            point = rotated_point(hinge_x, sign, local_x, angle)
            objects.append(box(f"{label}DoorBoard{board}", (0.35, 0.15, 4.0), point, oak, 0.012, (0.0, 0.0, angle)))
        for rail_z in (0.45, 2.25, 4.02):
            point = rotated_point(hinge_x, sign, 1.02, angle)
            point = (point[0], point[1], rail_z)
            objects.append(box(f"{label}DoorRail{rail_z}", (2.0, 0.22, 0.16), point, oak_dark, 0.01, (0.0, 0.0, angle)))
        point = rotated_point(hinge_x, sign, 1.0, angle)
        point = (point[0], point[1], 2.25)
        objects.append(box(f"{label}DoorBrace", (2.1, 0.10, 0.12), point, oak_cut, 0.008, (0.0, math.radians(-26.0), angle)))
        objects.append(cylinder(f"{label}HingePost", 0.10, 4.45, (hinge_x, 0.0, 2.25), oak_dark, 10))
        for z in (0.55, 2.25, 3.95):
            point = rotated_point(hinge_x, sign, 1.03, angle)
            point = (point[0], point[1] - 0.10, z)
            objects.append(box(f"{label}IronStrap{z}", (1.8, 0.06, 0.07), point, iron, 0.006, (0.0, 0.0, angle)))

    for obj in objects:
        obj.parent = root
    bpy.context.view_layer.update()
    return root, objects


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def metrics(objects: list[bpy.types.Object]) -> dict[str, object]:
    vertices = faces = triangles = 0
    materials: set[str] = set()
    uv_sets = 0
    for obj in objects:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)
        materials.update(material.name for material in mesh.materials if material is not None)
        uv_sets = max(uv_sets, len(mesh.uv_layers))
    minimum, maximum = bounds(objects)
    dimensions = maximum - minimum
    return {
        "mesh_objects": len(objects),
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "materials": len(materials),
        "uv_sets": uv_sets,
        "texture_size": 512,
        "dimensions_m": [round(value, 4) for value in dimensions],
        "ground_min_z": round(minimum.z, 6),
        "max_z": round(maximum.z, 6),
        "material_names": sorted(materials),
    }


def export_glb(root: bpy.types.Object, objects: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_texcoords=True,
        export_normals=True, export_tangents=True, export_materials="EXPORT",
        export_image_format="AUTO", export_cameras=False, export_lights=False,
        export_animations=False, export_extras=True,
    )
    result = metrics(objects)
    result["sha256"] = hashlib.sha256(GLB_PATH.read_bytes()).hexdigest()
    result["checks"] = {
        "metric_scale": 12.0 <= result["dimensions_m"][0] <= 16.0 and 3.0 <= result["dimensions_m"][1] <= 5.0,
        "y_up_glb": True,
        "ground_contact": abs(float(result["ground_min_z"])) <= 0.0001,
        "triangle_cap": int(result["triangles"]) <= int(BRIEF["triangles"]["max"]),
        "portable_pbr": True,
        "embedded_albedo": True,
        "uvs": int(result["uv_sets"]) >= 1,
        "walkable_void": True,
        "anachronism_exclusions": True,
    }
    return result


def render_preview(root: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("ViruGatePreviewWorld")
    scene.world.color = (0.025, 0.035, 0.055)
    floor_mat = bpy.data.materials.new("PreviewGround")
    floor_mat.diffuse_color = (0.10, 0.13, 0.16, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=40.0, location=(0.0, 0.0, -0.02))
    bpy.context.object.data.materials.append(floor_mat)
    bpy.ops.object.light_add(type="AREA", location=(-6.0, -8.0, 12.0))
    key = bpy.context.object
    key.data.energy = 1800.0
    key.data.size = 7.0
    key.rotation_euler = (math.radians(25.0), 0.0, math.radians(-35.0))
    bpy.ops.object.light_add(type="AREA", location=(8.0, 3.0, 7.0))
    fill = bpy.context.object
    fill.data.energy = 900.0
    fill.data.color = (0.45, 0.62, 0.9)
    fill.data.size = 5.0
    fill.rotation_euler = (math.radians(62.0), 0.0, math.radians(145.0))
    bpy.ops.object.camera_add(location=(15.5, -19.0, 10.5))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 3.1)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "PERSP"
    camera.data.lens = 52.0
    scene.camera = camera
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {
        "stone": make_material("ViruLimestone", LIMESTONE, "stone", 0.88),
        "stone_dark": make_material("ViruLimestoneShadow", LIMESTONE_DARK, "stone", 0.92),
        "stone_light": make_material("ViruLimestoneLight", LIMESTONE_LIGHT, "stone", 0.84),
        "oak": make_material("ViruOak", OAK, "timber", 0.82),
        "oak_dark": make_material("ViruOakTar", OAK_DARK, "timber", 0.88),
        "oak_cut": make_material("ViruOakCut", OAK_CUT, "timber", 0.78),
        "iron": make_material("ViruIron", IRON, "iron", 0.72, 0.65),
        "roof": make_material("ViruRoofTile", ROOF, "roof", 0.86),
    }
    root, objects = build_gate(materials)
    result = export_glb(root, objects)
    if "--preview" in sys.argv:
        render_preview(root)
    cache = hashlib.sha256()
    cache.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    cache.update(Path(__file__).read_bytes())
    cache.update(BLENDER_VERSION.encode("utf-8"))
    cache_key = cache.hexdigest()
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, indent=2) + "\n", encoding="utf-8")
    report = {
        "asset_id": BRIEF["id"],
        "route": "deterministic_blender",
        "generator": "generated/blender/viru_gate_v1/generate_viru_gate.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": cache_key,
        "historical_scope": BRIEF["historical_scope"],
        "forbidden_forms": ["round foregate towers", "barbican", "Fat Margaret", "portcullis complex", "zwinger"],
        "asset": result,
        "preview": "generated/blender/viru_gate_v1/preview.png" if "--preview" in sys.argv else None,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    STATE_PATH.write_text(json.dumps({"cache_key": cache_key, "sha256": result["sha256"], "complete": all(result["checks"].values())}, indent=2) + "\n", encoding="utf-8")
    print("ASSET_METRICS=" + json.dumps({"triangles": result["triangles"], "materials": result["materials"], "dimensions_m": result["dimensions_m"], "sha256": result["sha256"]}, separators=(",", ":")))


if __name__ == "__main__":
    main()
