#!/usr/bin/env python3
"""Build the game-ready low-poly smithy chair with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_smithy_chair.py

The model is intentionally procedural rather than image-to-3D generated. A rigid
wooden prop benefits from deterministic dimensions, clean topology, one material,
and a sub-second rebuild; generative 3D remains useful for complex silhouettes.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "furniture" / "smithy_chair.glb"
DEFAULT_PREVIEW = Path("/tmp/rebel_reval_smithy_chair_preview.png")
ASSET_ID = "prop.smithy_chair"
BLENDER_VERSION = "Blender 5.2 LTS"

WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
DARK_WOOD_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
PEG_SRGB = (0x32 / 255.0, 0x22 / 255.0, 0x1B / 255.0)
ROUGHNESS = 0.84
BEVEL_WIDTH = 0.008


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _add_prism(
    mesh: bmesh.types.BMesh,
    name: str,
    bottom_center: tuple[float, float, float],
    top_center: tuple[float, float, float],
    bottom_size: tuple[float, float],
    top_size: tuple[float, float],
    material_index: int = 0,
) -> None:
    """Add one tapered or leaning timber with outward-wound quad faces."""
    bx, by, bz = bottom_center
    tx, ty, tz = top_center
    bdx, bdy = bottom_size[0] * 0.5, bottom_size[1] * 0.5
    tdx, tdy = top_size[0] * 0.5, top_size[1] * 0.5
    vertices = [
        mesh.verts.new((bx - bdx, by - bdy, bz)),
        mesh.verts.new((bx + bdx, by - bdy, bz)),
        mesh.verts.new((bx + bdx, by + bdy, bz)),
        mesh.verts.new((bx - bdx, by + bdy, bz)),
        mesh.verts.new((tx - tdx, ty - tdy, tz)),
        mesh.verts.new((tx + tdx, ty - tdy, tz)),
        mesh.verts.new((tx + tdx, ty + tdy, tz)),
        mesh.verts.new((tx - tdx, ty + tdy, tz)),
    ]
    for face_indices in (
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ):
        face = mesh.faces.new([vertices[index] for index in face_indices])
        face.material_index = material_index


def _add_box(
    mesh: bmesh.types.BMesh,
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    rotation_z_degrees: float = 0.0,
    material_index: int = 0,
) -> None:
    result = bmesh.ops.create_cube(mesh, size=1.0)
    vertices = [element for element in result["verts"] if isinstance(element, bmesh.types.BMVert)]
    sx, sy, sz = size
    angle = math.radians(rotation_z_degrees)
    cos_angle, sin_angle = math.cos(angle), math.sin(angle)
    for vertex in vertices:
        local = Vector((vertex.co.x * sx, vertex.co.y * sy, vertex.co.z * sz))
        rotated = Vector(
            (
                local.x * cos_angle - local.y * sin_angle,
                local.x * sin_angle + local.y * cos_angle,
                local.z,
            )
        )
        vertex.co = rotated + Vector(center)
    for face in {linked for vertex in vertices for linked in vertex.link_faces}:
        face.material_index = material_index



def _add_cylinder(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    axis: str = "Z",
    segments: int = 10,
    material_index: int = 2,
) -> None:
    transform = Matrix.Translation(Vector(center))
    if axis == "Y":
        transform @= Matrix.Rotation(math.radians(90.0), 4, "X")
    elif axis == "X":
        transform @= Matrix.Rotation(math.radians(90.0), 4, "Y")
    result = bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.92,
        depth=depth,
        matrix=transform,
    )
    vertices = [element for element in result["verts"] if isinstance(element, bmesh.types.BMVert)]
    for face in {linked for vertex in vertices for linked in vertex.link_faces}:
        face.material_index = material_index


def _create_material(name: str, srgb: tuple[float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = 0.0
    material.roughness = roughness
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = roughness
    return material

def _add_oak_grain(material: bpy.types.Material) -> None:
    """Create a deterministic painted oak texture and embed it in the GLB.

    glTF cannot represent Blender's procedural Wave/Noise graph faithfully.
    Building the compact albedo here keeps Blender preview and Godot import
    identical, with no external texture dependency or generated runtime file.
    """
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    # Wide, slightly wandering growth lines plus restrained fine tool marks.
    warp = u + 0.028 * np.sin(v * math.tau * 2.3) + 0.012 * np.sin(v * math.tau * 7.0 + 0.8)
    broad = np.sin((warp * 9.0 + 0.16 * np.sin(v * math.tau * 1.7)) * math.tau)
    fine = np.sin((warp * 38.0 + v * 0.75) * math.tau)
    plane = np.sin((u * 2.0 + v * 1.25) * math.tau)
    variation = 0.80 + broad * 0.075 + fine * 0.022 + plane * 0.025

    # Sparse elliptical knots interrupt the parallel grain without becoming
    # photographic micro-detail at the game's dimetric viewing distance.
    for knot_u, knot_v, radius in ((0.22, 0.28, 0.065), (0.72, 0.66, 0.085), (0.47, 0.87, 0.045)):
        dx = (u - knot_u) / radius
        dy = (v - knot_v) / (radius * 0.58)
        distance = np.sqrt(dx * dx + dy * dy)
        ring = np.sin(distance * math.tau * 2.4) * np.clip(1.0 - distance / 2.2, 0.0, 1.0)
        variation += ring * 0.075
        variation -= np.exp(-(distance * distance) * 5.0) * 0.17

    # A few broad scratches communicate hand-planing and forge use. They remain
    # softer than silhouette edges, preserving the project's value hierarchy.
    for scratch_v in (0.18, 0.52, 0.79):
        distance = np.abs(v - (scratch_v + 0.012 * np.sin(u * math.tau * 3.0)))
        variation -= np.clip(1.0 - distance / 0.005, 0.0, 1.0) * 0.055

    base_linear = np.array([_srgb_to_linear(value) for value in WOOD_SRGB], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)

    image = bpy.data.images.new("smithy_oak_albedo", width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedOakAlbedo"
    texture.image = image
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])

def _build_mesh() -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new("SmithyChairMesh")
    object_data = bpy.data.objects.new("ChairMesh", mesh_data)
    bpy.context.collection.objects.link(object_data)

    mesh = bmesh.new()
    # Individual source calls below retain semantic part names while Blender
    # joins all timbers into one draw-friendly runtime mesh.

    for x, name in ((-0.225, "front_leg_left"), (0.225, "front_leg_right")):
        _add_prism(mesh, name, (x, 0.18, 0.0), (x, 0.18, 0.44), (0.055, 0.055), (0.074, 0.074))
    for x, name in ((-0.225, "back_post_left"), (0.225, "back_post_right")):
        _add_prism(mesh, name, (x, -0.18, 0.0), (x, -0.225, 1.04), (0.06, 0.06), (0.078, 0.07))

    # Thick board seat and four under-seat aprons make the chair readable at the
    # game's distant dimetric camera without noisy ornamental geometry.
    # Three separately fitted seat boards keep visible join lines and lightly
    # varied heights, as expected from hand-planed workshop furniture.
    _add_box(mesh, "seat_left", (-0.19, 0.0, 0.478), (0.175, 0.50, 0.082))
    _add_box(mesh, "seat_center", (0.0, -0.004, 0.484), (0.178, 0.50, 0.086))
    _add_box(mesh, "seat_right", (0.19, 0.003, 0.48), (0.175, 0.50, 0.084))
    _add_box(mesh, "apron_front", (0.0, 0.205, 0.405), (0.46, 0.055, 0.115))
    _add_box(mesh, "apron_back", (0.0, -0.205, 0.405), (0.46, 0.055, 0.115))
    _add_box(mesh, "apron_left", (-0.225, 0.0, 0.405), (0.055, 0.36, 0.115))
    _add_box(mesh, "apron_right", (0.225, 0.0, 0.405), (0.055, 0.36, 0.115))

    _add_box(mesh, "stretcher_front", (0.0, 0.18, 0.19), (0.40, 0.05, 0.055))
    _add_box(mesh, "stretcher_back", (0.0, -0.18, 0.20), (0.40, 0.05, 0.055))
    _add_box(mesh, "stretcher_left", (-0.225, 0.0, 0.205), (0.05, 0.31, 0.055))
    _add_box(mesh, "stretcher_right", (0.225, 0.0, 0.205), (0.05, 0.31, 0.055))

    # A workshop chair uses two broad slats and a subtly crowned top rail. The
    # darker inset strips suggest smoke-darkened end grain and old handling wear.
    _add_box(mesh, "back_slat_low", (0.0, -0.206, 0.675), (0.43, 0.055, 0.105))
    _add_box(mesh, "back_slat_low_inset", (0.0, -0.238, 0.675), (0.34, 0.012, 0.052), material_index=1)
    _add_box(mesh, "back_slat_high", (0.0, -0.218, 0.845), (0.43, 0.055, 0.11))
    _add_box(mesh, "back_slat_high_inset", (0.0, -0.250, 0.845), (0.34, 0.012, 0.055), material_index=1)
    _add_box(mesh, "back_rail_top", (0.0, -0.228, 0.985), (0.54, 0.07, 0.095))
    _add_box(mesh, "back_rail_crown", (0.0, -0.228, 1.035), (0.44, 0.076, 0.035))

    # Visible oak pegs explain the mortise-and-tenon construction. They are
    # oversized just enough to survive the 64 px character-scale camera.
    for x in (-0.225, 0.225):
        for z in (0.405, 0.675, 0.845, 0.985):
            _add_cylinder(mesh, (x, -0.259, z), 0.013, 0.018, axis="Y")
    for x in (-0.19, 0.0, 0.19):
        _add_cylinder(mesh, (x, 0.12, 0.530), 0.012, 0.012, axis="Z")

    # Small corner blocks and a central front wedge communicate repairs and
    # bracing without adding armrests or ornament inappropriate to a smithy.
    for x in (-0.205, 0.205):
        _add_box(mesh, "corner_block", (x, 0.16, 0.375), (0.08, 0.08, 0.10), rotation_z_degrees=45.0, material_index=1)
    _add_box(mesh, "front_wedge", (0.0, 0.237, 0.382), (0.105, 0.018, 0.075), material_index=1)

    mesh.normal_update()
    mesh.to_mesh(mesh_data)
    mesh.free()

    for polygon in mesh_data.polygons:
        polygon.use_smooth = False

    wood_material = _create_material("smithy_oak", WOOD_SRGB, ROUGHNESS)
    _add_oak_grain(wood_material)
    dark_material = _create_material("smoke_darkened_oak", DARK_WOOD_SRGB, 0.9)
    peg_material = _create_material("oak_pegs", PEG_SRGB, 0.94)
    object_data.data.materials.append(wood_material)
    object_data.data.materials.append(dark_material)
    object_data.data.materials.append(peg_material)

    bpy.context.view_layer.objects.active = object_data
    object_data.select_set(True)
    bevel = object_data.modifiers.new("EdgeSoftening", "BEVEL")
    bevel.width = BEVEL_WIDTH
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(30.0)
    bpy.ops.object.modifier_apply(modifier=bevel.name)

    # GLB carries a valid UV channel even though this first production pass uses
    # a palette-led scalar material. It can accept a later painted albedo without
    # requiring geometry or integration changes.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    object_data.data.validate(clean_customdata=False)
    object_data.data.update()
    object_data["asset_id"] = ASSET_ID
    object_data["intended_location"] = "loc.kalev_smithy"
    return object_data


def _mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    mesh = obj.data
    triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in bounds), min(v.y for v in bounds), min(v.z for v in bounds)))
    maximum = Vector((max(v.x for v in bounds), max(v.y for v in bounds), max(v.z for v in bounds)))
    return {
        "asset_id": ASSET_ID,
        "vertices": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "triangles": triangles,
        "materials": len(mesh.materials),
        "uv_layers": len(mesh.uv_layers),
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
    }


def _export(obj: bpy.types.Object) -> dict[str, object]:
    root = bpy.data.objects.new("SmithyChair", None)
    bpy.context.collection.objects.link(root)
    obj.parent = root
    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_smithy_chair.py"
    root["blender_version"] = BLENDER_VERSION

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
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
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    return _mesh_metrics(obj)


def _render_preview(obj: bpy.types.Object, output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.03, 0.025)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.12, 0.09, 0.065, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(2.5, 2.0, 3.2))
    key = bpy.context.object
    key.data.energy = 700.0
    key.data.shape = "DISK"
    key.data.size = 3.0
    key.rotation_euler = (math.radians(25.0), 0.0, math.radians(135.0))
    bpy.ops.object.light_add(type="AREA", location=(-2.0, -1.5, 2.2))
    fill = bpy.context.object
    fill.data.energy = 350.0
    fill.data.color = (0.45, 0.58, 0.8)
    fill.data.size = 2.5

    bpy.ops.object.camera_add(location=(2.2, 2.5, 1.8))
    camera = bpy.context.object
    direction = Vector((0.0, 0.0, 0.48)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.55
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = _build_mesh()
    metrics = _export(obj)
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        preview = Path(sys.argv[preview_index + 1]) if preview_index + 1 < len(sys.argv) else DEFAULT_PREVIEW
        _render_preview(obj, preview)
        metrics["preview"] = str(preview)
    print("SMITHY_CHAIR_METRICS=" + json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    main()
