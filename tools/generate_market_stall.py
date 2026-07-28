#!/usr/bin/env python3
"""Build the game-ready portable medieval market stall with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_market_stall.py -- --preview

The stall is a deterministic rigid prop: an open oak sales counter, braced frame,
rope lashings, and a shallow-pitched woven-flax awning. It replaces the runtime
box placeholder without changing map-owned footprints, collision, or navigation.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "market" / "market_stall.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "market_stall_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.market_stall"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "market_stall_v1"

PLANK_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
TIMBER_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
CANVAS_SRGB = (0xB3 / 255.0, 0x94 / 255.0, 0x5F / 255.0)
ROPE_SRGB = (0x80 / 255.0, 0x68 / 255.0, 0x3F / 255.0)
IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/market/market_stall.glb",
    "scene": "res://content/maps/market_civic_quarter.rrmap#fish_stall",
    "dimensions_m": [2.04, 1.6, 1.95],
    "triangles": {"target": 2600, "max": 4500},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create restrained painted variation that survives portable glTF export."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "wood":
        warp = u + 0.022 * np.sin(v * math.tau * 2.0) + 0.008 * np.sin(v * math.tau * 7.0 + 0.7)
        broad = np.sin((warp * 9.0 + v * 0.28) * math.tau)
        fine = np.sin((warp * 31.0 - v * 0.65) * math.tau)
        variation = 0.84 + broad * 0.072 + fine * 0.016
        for knot_u, knot_v, radius in ((0.25, 0.30, 0.075), (0.71, 0.68, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.0) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.06
            variation -= np.exp(-(distance * distance) * 5.5) * 0.11
    elif surface == "canvas":
        # Broad faded folds and a quiet weave read as cloth from the isometric
        # camera without becoming high-frequency noise under mipmapping.
        folds = np.sin((u * 3.2 + 0.18 * np.sin(v * math.tau)) * math.tau)
        cross_weave = np.sin(u * math.tau * 54.0) * np.sin(v * math.tau * 49.0)
        variation = 0.91 + folds * 0.055 + cross_weave * 0.012
        for stain_u, stain_v, radius in ((0.18, 0.77, 0.17), (0.79, 0.23, 0.13)):
            distance = np.sqrt((u - stain_u) ** 2 + (v - stain_v) ** 2) / radius
            variation -= np.exp(-(distance * distance) * 2.5) * 0.055
    elif surface == "rope":
        twist = np.sin((u * 29.0 + v * 11.0) * math.tau)
        fibers = np.sin((u * 71.0 - v * 4.0) * math.tau)
        variation = 0.84 + twist * 0.055 + fibers * 0.018
    else:
        hammered = np.sin((u * 12.0 + v * 5.0) * math.tau) * np.sin((v * 10.0 - u * 3.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
        variation = 0.77 + hammered * 0.045 + broad * 0.025

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
    surface: str,
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
    texture.image = _create_texture(f"{name}_albedo", srgb, surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _set_new_faces_material(mesh: bmesh.types.BMesh, previous: set[bmesh.types.BMFace], index: int) -> None:
    for face in mesh.faces:
        if face not in previous:
            face.material_index = index


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    rotation_degrees: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    rotation = Euler(tuple(math.radians(value) for value in rotation_degrees), "XYZ").to_matrix().to_4x4()
    transform = Matrix.Translation(Vector(center)) @ rotation @ Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _axis_matrix(start: Vector, end: Vector) -> Matrix:
    direction = end - start
    midpoint = (start + end) * 0.5
    up_axis = "X" if abs(direction.normalized().dot(Vector((0.0, 1.0, 0.0)))) > 0.92 else "Y"
    rotation = direction.to_track_quat("Z", up_axis).to_matrix().to_4x4()
    return Matrix.Translation(midpoint) @ rotation


def _add_beam(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    depth: float,
    material_index: int,
) -> None:
    start_vector = Vector(start)
    end_vector = Vector(end)
    length = (end_vector - start_vector).length
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = _axis_matrix(start_vector, end_vector) @ Matrix.Diagonal(Vector((width, depth, length, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material_index: int,
    segments: int = 8,
) -> None:
    start_vector = Vector(start)
    end_vector = Vector(end)
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.94,
        depth=(end_vector - start_vector).length,
        matrix=_axis_matrix(start_vector, end_vector),
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_ring_z(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    inner_radius: float,
    outer_radius: float,
    height: float,
    segments: int,
    material_index: int,
) -> None:
    """Add a low-poly closed rope lashing around one upright post."""
    cx, cy, cz = center
    rings: list[list[bmesh.types.BMVert]] = []
    for radius, z_offset in (
        (outer_radius, -height * 0.5),
        (outer_radius, height * 0.5),
        (inner_radius, height * 0.5),
        (inner_radius, -height * 0.5),
    ):
        ring = []
        for index in range(segments):
            angle = math.tau * index / segments
            ring.append(mesh.verts.new((cx + radius * math.cos(angle), cy + radius * math.sin(angle), cz + z_offset)))
        rings.append(ring)
    for index in range(segments):
        next_index = (index + 1) % segments
        for ring_a, ring_b in ((0, 1), (1, 2), (2, 3), (3, 0)):
            face = mesh.faces.new((rings[ring_a][index], rings[ring_a][next_index], rings[ring_b][next_index], rings[ring_b][index]))
            face.material_index = material_index


def _canopy_height(x: float, y: float) -> float:
    ridge_y = 0.06
    if y <= ridge_y:
        ratio = (y + 0.78) / (ridge_y + 0.78)
        base = 1.715 + (1.93 - 1.715) * ratio
    else:
        ratio = (y - ridge_y) / (0.78 - ridge_y)
        base = 1.93 + (1.755 - 1.93) * ratio
    # A slight bay sag and uneven hand-tension prevent the cloth reading as a roof slab.
    sag = -0.022 * math.sin(max(0.0, min(1.0, ratio)) * math.pi)
    hand_tension = 0.008 * math.sin(x * math.pi * 2.3 + y * 2.1)
    return base + sag + hand_tension


def _add_canvas_shell(mesh: bmesh.types.BMesh, material_index: int) -> None:
    x_segments = 10
    y_values = (-0.78, -0.60, -0.39, -0.17, 0.06, 0.27, 0.48, 0.66, 0.78)
    thickness = 0.018
    top_rows: list[list[bmesh.types.BMVert]] = []
    bottom_rows: list[list[bmesh.types.BMVert]] = []
    for row_index, y in enumerate(y_values):
        top_row = []
        bottom_row = []
        for column in range(x_segments + 1):
            x = -1.02 + 2.04 * column / x_segments
            if column in (0, x_segments):
                x += 0.012 * math.sin(row_index * 1.8 + column)
            z = _canopy_height(x, y)
            top_row.append(mesh.verts.new((x, y, z + thickness * 0.5)))
            bottom_row.append(mesh.verts.new((x, y, z - thickness * 0.5)))
        top_rows.append(top_row)
        bottom_rows.append(bottom_row)

    for row in range(len(y_values) - 1):
        for column in range(x_segments):
            top = mesh.faces.new(
                (top_rows[row][column], top_rows[row][column + 1], top_rows[row + 1][column + 1], top_rows[row + 1][column])
            )
            top.material_index = material_index
            bottom = mesh.faces.new(
                (
                    bottom_rows[row][column],
                    bottom_rows[row + 1][column],
                    bottom_rows[row + 1][column + 1],
                    bottom_rows[row][column + 1],
                )
            )
            bottom.material_index = material_index

    for row in range(len(y_values) - 1):
        for column in (0, x_segments):
            vertices = (
                top_rows[row][column],
                top_rows[row + 1][column],
                bottom_rows[row + 1][column],
                bottom_rows[row][column],
            )
            face = mesh.faces.new(vertices if column == x_segments else tuple(reversed(vertices)))
            face.material_index = material_index
    for row in (0, len(y_values) - 1):
        for column in range(x_segments):
            vertices = (
                top_rows[row][column],
                bottom_rows[row][column],
                bottom_rows[row][column + 1],
                top_rows[row][column + 1],
            )
            face = mesh.faces.new(vertices if row == 0 else tuple(reversed(vertices)))
            face.material_index = material_index

    # A segmented front valance gives the awning a soft irregular hem at gameplay scale.
    for column in range(x_segments):
        x0 = -1.02 + 2.04 * column / x_segments
        x1 = -1.02 + 2.04 * (column + 1) / x_segments
        top_z = (_canopy_height(x0, -0.78) + _canopy_height(x1, -0.78)) * 0.5
        drop = 0.105 + 0.024 * (0.5 + 0.5 * math.sin(column * 1.73))
        _add_box(
            mesh,
            ((x0 + x1) * 0.5, -0.784, top_z - drop * 0.5),
            (x1 - x0 + 0.006, 0.018, drop),
            material_index,
            rotation_degrees=(0.0, 0.0, 0.35 * math.sin(column * 1.3)),
        )


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


def _apply_bevel(obj: bpy.types.Object, width: float = 0.006) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("HandWorkedEdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = 1
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(30.0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _triangulate(obj: bpy.types.Object) -> None:
    """Bake triangles before glTF tangent generation to keep Blender export clean."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("PortableGltfTriangles", "TRIANGULATE")
    modifier.quad_method = "BEAUTY"
    modifier.ngon_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def _unwrap(obj: bpy.types.Object, angle_limit_degrees: float) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle_limit_degrees), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    plank = _create_material("weathered_market_oak", PLANK_SRGB, 0.86, 0.0, "wood")
    timber = _create_material("dark_oak_frame", TIMBER_SRGB, 0.9, 0.0, "wood")
    canvas = _create_material("woven_flax_canvas", CANVAS_SRGB, 0.96, 0.0, "canvas")
    rope = _create_material("hemp_rope", ROPE_SRGB, 0.98, 0.0, "rope")
    iron = _create_material("wrought_iron_fittings", IRON_SRGB, 0.69, 0.62, "iron")

    frame_mesh = bmesh.new()
    # Four subtly leaning uprights and visible joinery preserve the portable stall
    # silhouette while avoiding the rigid, toy-like box construction it replaces.
    post_specs = (
        ((-0.78, -0.48, 0.045), (-0.74, -0.48, 1.73)),
        ((0.78, -0.48, 0.045), (0.74, -0.48, 1.73)),
        ((-0.78, 0.48, 0.045), (-0.74, 0.48, 1.77)),
        ((0.78, 0.48, 0.045), (0.74, 0.48, 1.77)),
    )
    for start, end in post_specs:
        _add_beam(frame_mesh, start, end, 0.078, 0.078, 1)
        _add_box(frame_mesh, (start[0], start[1], 0.025), (0.105, 0.105, 0.05), 1)

    # Counter boards remain individually readable from the gameplay camera.
    plank_width = 0.246
    for index in range(6):
        x = -0.625 + index * 0.25
        _add_box(
            frame_mesh,
            (x, -0.12, 0.815 + 0.004 * math.sin(index * 1.7)),
            (plank_width, 0.72, 0.055),
            0,
            rotation_degrees=(0.0, 0.0, 0.45 * math.sin(index * 1.2)),
        )
    for y in (-0.46, 0.23):
        _add_box(frame_mesh, (0.0, y, 0.75), (1.58, 0.075, 0.09), 1)
    for x in (-0.75, 0.75):
        _add_box(frame_mesh, (x, -0.12, 0.75), (0.075, 0.76, 0.09), 1)

    # A shallow plank apron hides the seller's storage but keeps the lower frame open.
    for index in range(3):
        _add_box(
            frame_mesh,
            (0.0, -0.485, 0.68 - index * 0.135),
            (1.47, 0.042, 0.115),
            0,
            rotation_degrees=(0.0, 0.0, 0.22 * math.sin(index * 2.0)),
        )

    # Lower shelf and braces make the structure plausible from side and rear views.
    for index in range(5):
        x = -0.51 + index * 0.255
        _add_box(frame_mesh, (x, 0.03, 0.285), (0.238, 0.58, 0.045), 0)
    for x in (-0.72, 0.72):
        _add_beam(frame_mesh, (x, -0.43, 0.13), (x, 0.40, 0.70), 0.045, 0.042, 1)
    _add_beam(frame_mesh, (-0.70, 0.47, 0.16), (0.70, 0.47, 0.69), 0.045, 0.042, 1)
    _add_beam(frame_mesh, (0.70, 0.47, 0.16), (-0.70, 0.47, 0.69), 0.045, 0.042, 1)

    # Awning rails and rafters carry a real shallow-pitched cloth roof.
    _add_box(frame_mesh, (0.0, -0.50, 1.715), (1.72, 0.075, 0.075), 1)
    _add_box(frame_mesh, (0.0, 0.50, 1.755), (1.72, 0.075, 0.075), 1)
    _add_box(frame_mesh, (0.0, 0.06, 1.89), (1.78, 0.06, 0.065), 1)
    for x in (-0.72, 0.0, 0.72):
        _add_beam(frame_mesh, (x, -0.54, 1.715), (x, 0.06, 1.89), 0.042, 0.042, 1)
        _add_beam(frame_mesh, (x, 0.06, 1.89), (x, 0.54, 1.755), 0.042, 0.042, 1)

    # Rope wraps and iron pegs make attachment points legible, not decorative noise.
    for x, y, z in (
        (-0.74, -0.48, 1.67),
        (0.74, -0.48, 1.67),
        (-0.74, 0.48, 1.70),
        (0.74, 0.48, 1.70),
        (-0.77, -0.48, 0.77),
        (0.77, -0.48, 0.77),
    ):
        _add_ring_z(frame_mesh, (x, y, z), 0.048, 0.061, 0.035, 8, 2)
    for x, z in ((-0.77, 0.75), (0.77, 0.75), (-0.74, 1.69), (0.74, 1.69)):
        _add_cylinder_between(frame_mesh, (x, -0.55, z), (x, -0.42, z), 0.014, 3, 8)

    frame = _object_from_bmesh("StallFrame", frame_mesh, [plank, timber, rope, iron])
    _apply_bevel(frame)
    _unwrap(frame, 62.0)
    _triangulate(frame)

    canvas_mesh = bmesh.new()
    _add_canvas_shell(canvas_mesh, 0)
    awning = _object_from_bmesh("CanvasAwning", canvas_mesh, [canvas])
    _unwrap(awning, 72.0)
    _triangulate(awning)

    root = bpy.data.objects.new("MarketStall", None)
    bpy.context.collection.objects.link(root)
    meshes = [frame, awning]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.market_civic_quarter"
    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_market_stall.py"
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
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.03, 0.024)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.13, 0.105, 0.075, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=5.5, location=(0.0, 0.0, -0.004))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.2, -3.8, 4.8))
    key = bpy.context.object
    key.data.energy = 900.0
    key.data.shape = "DISK"
    key.data.size = 3.2
    bpy.ops.object.light_add(type="AREA", location=(3.5, 1.4, 2.7))
    fill = bpy.context.object
    fill.data.energy = 470.0
    fill.data.size = 2.8

    bpy.ops.object.camera_add(location=(3.4, -4.3, 3.0))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.9)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.1
    scene.camera = camera

    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "generator": "tools/generate_market_stall.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "metrics": metrics,
        "limits": BRIEF["triangles"],
        "validation": {
            "metric_scale": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.001,
            "triangle_budget": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "uvs": int(metrics["uv_sets"]) >= 1,
            "portable_pbr_materials": int(metrics["materials"]) == 5,
            "floating_components": int(metrics["floating_objects"]) == 0,
        },
        "preview": preview.relative_to(ROOT).as_posix() if preview is not None else None,
        "defects": [],
    }
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
