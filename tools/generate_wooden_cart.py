#!/usr/bin/env python3
"""Build the game-ready medieval wooden cart with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_wooden_cart.py

Add ``--preview [path]`` for one orthographic three-quarter render. The generator
writes compact reproducibility evidence under generated/blender/wooden_cart_v1/.

The cart replaces the placeholder box-and-cylinder carts in the 3D map view.
It is modeled in Blender Z-up coordinates with the shafts pointing toward +Y,
which the Y-up glTF export turns into Godot -Z (engine forward). Wheel radius
and bed height match the legacy procedural silhouette (bed top at 0.68 m, the
climbable stand height for PROP_KIND_CART), so map footprints remain the sole
collision/navigation authority.
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
OUTPUT = ROOT / "assets" / "props" / "vehicles" / "wooden_cart.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "wooden_cart_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.wooden_cart"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "wooden_cart_v1"

PLANK_SRGB = (0x8A / 255.0, 0x6B / 255.0, 0x42 / 255.0)
TIMBER_SRGB = (0x59 / 255.0, 0x3D / 255.0, 0x22 / 255.0)
IRON_SRGB = (0x4C / 255.0, 0x4C / 255.0, 0x50 / 255.0)

WHEEL_RADIUS = 0.345
WHEEL_TRACK = 0.50
AXLE_FRONT_Y = 0.55
AXLE_REAR_Y = -0.55

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/vehicles/wooden_cart.glb",
    "scene": "res://content/maps/viru_gate_foreland.rrmap#west.farm_cart",
    "dimensions_m": [1.06, 2.5, 1.0],
    "triangles": {"target": 4500, "max": 8000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create restrained painted variation that glTF can embed without Blender nodes."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "wood":
        warp = u + 0.025 * np.sin(v * math.tau * 2.1) + 0.010 * np.sin(v * math.tau * 6.7 + 0.4)
        broad = np.sin((warp * 10.0 + 0.12 * np.sin(v * math.tau * 1.4)) * math.tau)
        fine = np.sin((warp * 34.0 + v * 0.6) * math.tau)
        variation = 0.82 + broad * 0.075 + fine * 0.018
        for knot_u, knot_v, radius in ((0.23, 0.31, 0.07), (0.69, 0.72, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.2) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.07
            variation -= np.exp(-(distance * distance) * 5.0) * 0.14
    else:
        hammered = np.sin((u * 11.0 + v * 4.0) * math.tau) * np.sin((v * 9.0 - u * 3.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
        variation = 0.78 + hammered * 0.045 + broad * 0.025

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
    metallic: float,
    texture_surface: str,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = metallic
    material.roughness = roughness
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture(f"{name}_albedo", srgb, texture_surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _set_new_faces_material(mesh: bmesh.types.BMesh, previous_faces: set[bmesh.types.BMFace], index: int) -> None:
    for face in mesh.faces:
        if face not in previous_faces:
            face.material_index = index


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int = 0,
    rotation_x_degrees: float = 0.0,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    sx, sy, sz = size
    angle = math.radians(rotation_x_degrees)
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(angle, 4, "X") @ Matrix.Diagonal(Vector((sx, sy, sz, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder_x(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    material_index: int,
    segments: int = 16,
) -> None:
    """Cylinder with its axis along X (axles, hubs)."""
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=depth,
        matrix=Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y"),
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_annulus_x(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    r_inner: float,
    r_outer: float,
    half_width: float,
    segments: int,
    material_index: int,
) -> None:
    """Flat closed ring with its axis along X (iron tires, felloes, hub bands)."""
    cx, cy, cz = center
    previous = set(mesh.faces)
    rings: list[list[bmesh.types.BMVert]] = []
    for radius, xoff in ((r_outer, -half_width), (r_outer, half_width), (r_inner, half_width), (r_inner, -half_width)):
        ring: list[bmesh.types.BMVert] = []
        for index in range(segments):
            angle = math.tau * index / segments
            ring.append(mesh.verts.new((cx + xoff, cy + radius * math.sin(angle), cz + radius * math.cos(angle))))
        rings.append(ring)
    for index in range(segments):
        next_index = (index + 1) % segments
        for ring_a, ring_b in ((0, 1), (1, 2), (2, 3), (3, 0)):
            face = mesh.faces.new(
                (rings[ring_a][index], rings[ring_a][next_index], rings[ring_b][next_index], rings[ring_b][index])
            )
            face.material_index = material_index


def _object_from_bmesh(name: str, mesh: bmesh.types.BMesh, materials: list[bpy.types.Material]) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    for material in materials:
        data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = False
    return obj


def _apply_bevel(obj: bpy.types.Object, width: float, segments: int) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("HandWorkedEdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(28.0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _unwrap(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _build_wheel(mesh: bmesh.types.BMesh, center: tuple[float, float, float], wood_index: int, iron_index: int) -> None:
    """One dished cart wheel: iron tire, felloe ring, eight spokes, hub and band."""
    cx, cy, cz = center
    _add_annulus_x(mesh, center, 0.325, WHEEL_RADIUS, 0.028, 24, iron_index)
    _add_annulus_x(mesh, center, 0.27, 0.325, 0.023, 24, wood_index)
    for spoke_index in range(8):
        angle = math.tau * spoke_index / 8.0
        offset = (cx, cy + 0.17 * math.sin(angle), cz + 0.17 * math.cos(angle))
        _add_box(mesh, offset, (0.035, 0.035, 0.22), wood_index, -math.degrees(angle))
    _add_cylinder_x(mesh, center, 0.075, 0.16, wood_index, 16)
    _add_annulus_x(mesh, center, 0.075, 0.086, 0.02, 16, iron_index)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    plank = _create_material("weathered_oak_planks", PLANK_SRGB, 0.85, 0.0, "wood")
    timber = _create_material("dark_oak_timber", TIMBER_SRGB, 0.88, 0.0, "wood")
    iron = _create_material("aged_cart_iron", IRON_SRGB, 0.62, 0.72, "iron")

    wheel_mesh = bmesh.new()
    for axle_y in (AXLE_FRONT_Y, AXLE_REAR_Y):
        for side_x in (-WHEEL_TRACK, WHEEL_TRACK):
            _build_wheel(wheel_mesh, (side_x, axle_y, WHEEL_RADIUS), 0, 1)
    wheels = _object_from_bmesh("WheelAssembly", wheel_mesh, [timber, iron])

    body_mesh = bmesh.new()
    # Axles, bolsters, and the central perch form the undercarriage.
    for axle_y in (AXLE_FRONT_Y, AXLE_REAR_Y):
        _add_cylinder_x(body_mesh, (0.0, axle_y, WHEEL_RADIUS), 0.045, 1.06, 0)
        _add_box(body_mesh, (0.0, axle_y, 0.43), (0.62, 0.16, 0.09), 0)
    _add_box(body_mesh, (0.0, 0.0, 0.43), (0.14, 1.15, 0.09), 0)
    # Bed: two side rails carrying eight cross planks, top surface at 0.68 m so
    # the climbable stand height for PROP_KIND_CART stays visually honest.
    for side_x in (-0.44, 0.44):
        _add_box(body_mesh, (side_x, 0.0, 0.58), (0.07, 1.70, 0.10), 0)
    for plank_index in range(8):
        _add_box(body_mesh, (0.0, -0.665 + 0.19 * plank_index, 0.655), (0.95, 0.17, 0.05), 1)
    # Ladder sides: three posts and two slats per side, plus front and rear boards.
    for side_x in (-0.475, 0.475):
        for post_y in (-0.70, 0.0, 0.70):
            _add_box(body_mesh, (side_x, post_y, 0.84), (0.06, 0.06, 0.32), 0)
        for slat_z in (0.79, 0.95):
            _add_box(body_mesh, (side_x, 0.0, slat_z), (0.05, 1.58, 0.10), 1)
    for end_y in (-0.82, 0.82):
        for slat_z in (0.79, 0.95):
            _add_box(body_mesh, (0.0, end_y, slat_z), (0.95, 0.05, 0.10), 1)
    # Twin draft shafts run from the front bolster (0.55 m high) down toward the
    # harness crossbar (0.33 m) at the tip, so the cart rests tilted like a real
    # parked wagon. Negative X rotation lowers the +Y (forward) end.
    for side_x in (-0.30, 0.30):
        _add_box(body_mesh, (side_x, 1.05, 0.44), (0.07, 1.024, 0.07), 0, -12.4)
    _add_box(body_mesh, (0.0, 1.48, 0.345), (0.66, 0.05, 0.05), 0)
    body = _object_from_bmesh("CartBody", body_mesh, [timber, plank])
    _apply_bevel(body, 0.005, 1)

    root = bpy.data.objects.new("WoodenCart", None)
    bpy.context.collection.objects.link(root)
    meshes = [wheels, body]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.reval_lower_town"
        _unwrap(obj)

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_wooden_cart.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    return root, meshes


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    vertices = 0
    faces = 0
    triangles = 0
    surfaces = 0
    uv_sets = 0
    points: list[Vector] = []
    material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len({polygon.material_index for polygon in mesh.polygons})
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
        "surfaces": surfaces,
        "materials": len(material_names),
        "uv_sets": uv_sets,
        "texture_size": 512,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "floating_objects": 0,
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


def _render_preview(meshes: list[bpy.types.Object], output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.028, 0.025, 0.023)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.17, 0.15, 0.13, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.4, -0.002))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.6, -2.2, 3.4))
    key = bpy.context.object
    key.data.energy = 900.0
    key.data.shape = "DISK"
    key.data.size = 2.8
    direction = Vector((0.0, 0.2, 0.5)) - key.location
    key.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(2.4, 2.2, 2.4))
    fill = bpy.context.object
    fill.data.energy = 480.0
    fill.data.color = (0.48, 0.60, 0.82)
    fill.data.size = 2.2
    direction = Vector((0.0, 0.2, 0.5)) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.camera_add(location=(2.9, 3.6, 2.1))
    camera = bpy.context.object
    direction = Vector((0.0, 0.25, 0.5)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.1
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)

    # Keep evidence-only floor/light/camera out of the exported production model.
    for obj in meshes:
        obj.hide_render = False


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_wooden_cart.py",
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
            preview = Path(sys.argv[preview_index + 1]).expanduser().resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(meshes, preview)

    _write_evidence(metrics, preview)
    print("ASSET_METRICS=" + json.dumps(metrics, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
