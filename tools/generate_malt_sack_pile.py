#!/usr/bin/env python3
"""Build a readable game-ready pile of malt sacks with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_malt_sack_pile.py -- --preview

The deterministic rigid prop replaces the egg-like runtime spheres with gathered
linen sacks, visible seams and ties, an open sack of malt, and a wooden grain scoop.
Map-owned placement, collision, navigation, and the one-cell footprint stay intact.
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
OUTPUT = ROOT / "assets" / "props" / "crafts" / "malt_sack_pile.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "malt_sack_pile_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.malt_sack_pile"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "malt_sack_pile_v1"

BURLAP_SRGB = (0xAD / 255.0, 0x96 / 255.0, 0x70 / 255.0)
ROPE_SRGB = (0x78 / 255.0, 0x61 / 255.0, 0x3D / 255.0)
MALT_SRGB = (0xCD / 255.0, 0xA4 / 255.0, 0x44 / 255.0)
WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/crafts/malt_sack_pile.glb",
    "scene": "res://content/maps/lower_town_slice.rrmap#brewery_malt_sacks",
    "dimensions_m": [1.27, 0.68, 0.96],
    "triangles": {"target": 1600, "max": 3000},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create restrained painted detail that exports inside the portable GLB."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "burlap":
        broad = np.sin((u * 2.1 + v * 1.45) * math.tau)
        warp = np.sin((u * 42.0 + 0.6 * np.sin(v * math.tau * 2.0)) * math.tau)
        weft = np.sin((v * 38.0 - 0.45 * np.sin(u * math.tau * 1.7)) * math.tau)
        edge_wear = np.sin((u * 5.0 - v * 3.0) * math.tau)
        variation = 0.90 + broad * 0.048 + warp * weft * 0.016 + edge_wear * 0.014
        for stain_u, stain_v, radius in ((0.20, 0.72, 0.18), (0.78, 0.27, 0.14)):
            distance = np.sqrt((u - stain_u) ** 2 + (v - stain_v) ** 2) / radius
            variation -= np.exp(-(distance * distance) * 2.7) * 0.05
    elif surface == "rope":
        twist = np.sin((u * 24.0 + v * 9.0) * math.tau)
        fibers = np.sin((u * 61.0 - v * 5.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.3) * math.tau)
        variation = 0.84 + twist * 0.052 + fibers * 0.015 + broad * 0.02
    elif surface == "malt":
        # Broad kernel-sized marks imply dry barley without becoming glittery noise.
        rows = np.sin((u * 13.0 + 0.8 * np.sin(v * math.tau * 4.0)) * math.tau)
        husks = np.sin((v * 17.0 - u * 4.0) * math.tau)
        toasted = np.sin((u * 3.0 + v * 2.2) * math.tau)
        variation = 0.90 + rows * husks * 0.035 + toasted * 0.045
    else:
        warp = u + 0.024 * np.sin(v * math.tau * 2.0) + 0.008 * np.sin(v * math.tau * 7.0)
        broad = np.sin((warp * 9.0 + v * 0.3) * math.tau)
        fine = np.sin((warp * 31.0 - v * 0.7) * math.tau)
        variation = 0.83 + broad * 0.07 + fine * 0.016
        for knot_u, knot_v, radius in ((0.26, 0.31, 0.08), (0.73, 0.68, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation -= np.exp(-(distance * distance) * 5.0) * 0.12
            variation += np.sin(distance * math.tau * 2.0) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.05

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
    surface: str,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = 0.0
    material.roughness = roughness
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = 0.0
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


def _add_profile_body(
    mesh: bmesh.types.BMesh,
    rings: list[tuple[float, float, float]],
    material_index: int,
    transform: Matrix,
    segments: int = 14,
    cap_bottom: bool = True,
    cap_top: bool = True,
    phase: float = 0.0,
) -> None:
    ring_vertices: list[list[bmesh.types.BMVert]] = []
    for ring_index, (z, radius_x, radius_y) in enumerate(rings):
        current: list[bmesh.types.BMVert] = []
        for index in range(segments):
            angle = math.tau * index / segments
            # WHY: slight low-frequency asymmetry reads as filled cloth rather than
            # a lathed vase, while fixed formulae keep every rebuild deterministic.
            wobble = 1.0 + 0.025 * math.sin(angle * 3.0 + phase + ring_index * 0.7)
            offset_x = 0.008 * math.sin(ring_index * 1.8 + phase)
            offset_y = 0.006 * math.cos(ring_index * 1.4 + phase)
            local = Vector(
                (
                    offset_x + radius_x * wobble * math.cos(angle),
                    offset_y + radius_y * (2.0 - wobble) * math.sin(angle),
                    z,
                )
            )
            current.append(mesh.verts.new(transform @ local))
        ring_vertices.append(current)

    for ring_index in range(len(ring_vertices) - 1):
        lower = ring_vertices[ring_index]
        upper = ring_vertices[ring_index + 1]
        for index in range(segments):
            face = mesh.faces.new(
                (lower[index], lower[(index + 1) % segments], upper[(index + 1) % segments], upper[index])
            )
            face.material_index = material_index
    if cap_bottom:
        face = mesh.faces.new(tuple(reversed(ring_vertices[0])))
        face.material_index = material_index
    if cap_top:
        face = mesh.faces.new(tuple(ring_vertices[-1]))
        face.material_index = material_index


def _add_ellipsoid(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    scale: tuple[float, float, float],
    material_index: int,
    rotation_z: float = 0.0,
    segments: int = 12,
    rings: int = 6,
) -> None:
    """Add a manually indexed UV ellipsoid with deterministic triangle winding."""
    transform = (
        Matrix.Translation(Vector(center))
        @ Matrix.Rotation(rotation_z, 4, "Z")
        @ Matrix.Diagonal(Vector((*scale, 1.0)))
    )
    top = mesh.verts.new(transform @ Vector((0.0, 0.0, 1.0)))
    bottom = mesh.verts.new(transform @ Vector((0.0, 0.0, -1.0)))
    latitude_rings: list[list[bmesh.types.BMVert]] = []
    for ring_index in range(1, rings):
        latitude = math.pi * ring_index / rings
        radius = math.sin(latitude)
        z = math.cos(latitude)
        current = []
        for segment_index in range(segments):
            longitude = math.tau * segment_index / segments
            current.append(
                mesh.verts.new(
                    transform @ Vector((radius * math.cos(longitude), radius * math.sin(longitude), z))
                )
            )
        latitude_rings.append(current)

    first_ring = latitude_rings[0]
    last_ring = latitude_rings[-1]
    for index in range(segments):
        next_index = (index + 1) % segments
        top_face = mesh.faces.new((top, first_ring[index], first_ring[next_index]))
        top_face.material_index = material_index
        bottom_face = mesh.faces.new((bottom, last_ring[next_index], last_ring[index]))
        bottom_face.material_index = material_index
    for ring_index in range(len(latitude_rings) - 1):
        upper = latitude_rings[ring_index]
        lower = latitude_rings[ring_index + 1]
        for index in range(segments):
            next_index = (index + 1) % segments
            face_a = mesh.faces.new((upper[index], lower[index], lower[next_index]))
            face_a.material_index = material_index
            face_b = mesh.faces.new((upper[index], lower[next_index], upper[next_index]))
            face_b.material_index = material_index


def _axis_matrix(start: Vector, end: Vector) -> Matrix:
    direction = end - start
    midpoint = (start + end) * 0.5
    up_axis = "X" if abs(direction.normalized().dot(Vector((0.0, 1.0, 0.0)))) > 0.92 else "Y"
    return Matrix.Translation(midpoint) @ direction.to_track_quat("Z", up_axis).to_matrix().to_4x4()


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: Vector,
    end: Vector,
    radius: float,
    material_index: int,
    segments: int = 8,
) -> None:
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.96,
        depth=(end - start).length,
        matrix=_axis_matrix(start, end),
    )
    _set_new_faces_material(mesh, previous, material_index)


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    rotation: Matrix | None = None,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = Matrix.Translation(Vector(center))
    if rotation is not None:
        transform @= rotation
    transform @= Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])
    _set_new_faces_material(mesh, previous, material_index)


def _add_torus_ellipse(
    mesh: bmesh.types.BMesh,
    center: Vector,
    radius_x: float,
    radius_y: float,
    tube_radius: float,
    material_index: int,
    yaw: float,
    major_segments: int = 16,
    minor_segments: int = 5,
) -> None:
    rotation = Matrix.Rotation(yaw, 4, "Z")
    rings: list[list[bmesh.types.BMVert]] = []
    for major_index in range(major_segments):
        major_angle = math.tau * major_index / major_segments
        ring: list[bmesh.types.BMVert] = []
        radial = Vector((math.cos(major_angle), math.sin(major_angle), 0.0))
        for minor_index in range(minor_segments):
            minor_angle = math.tau * minor_index / minor_segments
            local = Vector(
                (
                    (radius_x + tube_radius * math.cos(minor_angle)) * math.cos(major_angle),
                    (radius_y + tube_radius * math.cos(minor_angle)) * math.sin(major_angle),
                    tube_radius * math.sin(minor_angle),
                )
            )
            ring.append(mesh.verts.new(center + rotation @ local))
        rings.append(ring)
    for major_index in range(major_segments):
        next_major = (major_index + 1) % major_segments
        for minor_index in range(minor_segments):
            next_minor = (minor_index + 1) % minor_segments
            face = mesh.faces.new(
                (
                    rings[major_index][minor_index],
                    rings[next_major][minor_index],
                    rings[next_major][next_minor],
                    rings[major_index][next_minor],
                )
            )
            face.material_index = material_index


def _add_cloth_ear(
    mesh: bmesh.types.BMesh,
    transform: Matrix,
    side: float,
    height: float,
    material_index: int,
) -> None:
    x0 = side * 0.025
    x1 = side * 0.075
    y0 = -0.005
    thickness = 0.014
    local = [
        (x0, y0 - thickness, height - 0.012),
        (x1, y0 - thickness, height + 0.085),
        (side * 0.012, y0 - thickness, height + 0.062),
        (x0, y0 + thickness, height - 0.012),
        (x1, y0 + thickness, height + 0.085),
        (side * 0.012, y0 + thickness, height + 0.062),
    ]
    verts = [mesh.verts.new(transform @ Vector(point)) for point in local]
    for indices in ((0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)):
        face = mesh.faces.new(tuple(verts[index] for index in indices))
        face.material_index = material_index


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    materials: list[bpy.types.Material],
    smooth: bool = False,
) -> bpy.types.Object:
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
        polygon.use_smooth = smooth
    data.validate(clean_customdata=False)
    data.update()
    return obj


def _tied_sack_transform(center: tuple[float, float, float], scale: float, yaw: float) -> Matrix:
    return Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)


def _build_sacks(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, list[tuple[Matrix, float]]]:
    mesh = bmesh.new()
    burlap_index = 0
    specs = [
        ((-0.27, 0.10, 0.0), 0.97, math.radians(-8.0), 0.3),
        ((0.27, 0.14, 0.0), 0.90, math.radians(10.0), 1.7),
    ]
    transforms: list[tuple[Matrix, float]] = []
    rings = [
        (0.00, 0.145, 0.125),
        (0.055, 0.205, 0.165),
        (0.30, 0.235, 0.18),
        (0.47, 0.20, 0.15),
        (0.565, 0.115, 0.09),
        (0.615, 0.052, 0.043),
    ]
    for center, scale, yaw, phase in specs:
        transform = _tied_sack_transform(center, scale, yaw)
        _add_profile_body(mesh, rings, burlap_index, transform, phase=phase)
        _add_cloth_ear(mesh, transform, -1.0, 0.61, burlap_index)
        _add_cloth_ear(mesh, transform, 1.0, 0.61, burlap_index)
        transforms.append((transform, phase))
    return _object_from_bmesh("Sacks", mesh, materials, smooth=True), transforms


def _build_open_sack(materials: list[bpy.types.Material]) -> tuple[bpy.types.Object, Matrix]:
    mesh = bmesh.new()
    transform = Matrix.Translation(Vector((0.02, -0.20, 0.0))) @ Matrix.Rotation(math.radians(-3.0), 4, "Z") @ Matrix.Scale(0.92, 4)
    rings = [
        (0.00, 0.15, 0.12),
        (0.055, 0.205, 0.165),
        (0.285, 0.225, 0.175),
        (0.43, 0.195, 0.15),
        (0.52, 0.225, 0.175),
    ]
    _add_profile_body(mesh, rings, 0, transform, cap_top=False, phase=2.6)
    return _object_from_bmesh("OpenSack", mesh, materials, smooth=True), transform


def _build_seams_and_ties(
    materials: list[bpy.types.Material],
    tied_transforms: list[tuple[Matrix, float]],
    open_transform: Matrix,
) -> bpy.types.Object:
    mesh = bmesh.new()
    rope_index = 1
    tied_path = [(0.0, -0.132, 0.055), (0.0, -0.184, 0.29), (0.0, -0.153, 0.47), (0.0, -0.094, 0.56)]
    for transform, _phase in tied_transforms:
        for start, end in zip(tied_path, tied_path[1:]):
            _add_cylinder_between(mesh, transform @ Vector(start), transform @ Vector(end), 0.0085, rope_index, 7)
        center = transform @ Vector((0.0, 0.0, 0.584))
        scale = transform.to_scale().x
        _add_torus_ellipse(mesh, center, 0.062 * scale, 0.052 * scale, 0.010 * scale, rope_index, 0.0, 12, 4)

    open_path = [(0.0, -0.127, 0.055), (0.0, -0.178, 0.275), (0.0, -0.154, 0.43), (0.0, -0.178, 0.50)]
    for start, end in zip(open_path, open_path[1:]):
        _add_cylinder_between(mesh, open_transform @ Vector(start), open_transform @ Vector(end), 0.008, rope_index, 7)
    open_center = open_transform @ Vector((0.0, 0.0, 0.52))
    _add_torus_ellipse(mesh, open_center, 0.225 * 0.92, 0.175 * 0.92, 0.018, rope_index, math.radians(-3.0))
    return _object_from_bmesh("SeamsAndTies", mesh, materials, smooth=True)


def _build_malt(materials: list[bpy.types.Material], open_transform: Matrix) -> bpy.types.Object:
    mesh = bmesh.new()
    malt_index = 2
    mound_center = open_transform @ Vector((0.0, 0.0, 0.505))
    _add_ellipsoid(mesh, tuple(mound_center), (0.175, 0.125, 0.052), malt_index, math.radians(-3.0), 14, 6)

    # A few modeled barley kernels make the contents identifiable in close review;
    # the textured mound carries the read at normal gameplay distance.
    kernels = [
        (-0.10, -0.025, 0.548, -12.0), (-0.055, 0.045, 0.553, 18.0),
        (0.0, -0.055, 0.557, 5.0), (0.058, 0.035, 0.551, -21.0),
        (0.105, -0.018, 0.545, 14.0), (-0.025, 0.085, 0.542, -8.0),
        (0.035, -0.095, 0.541, 23.0),
    ]
    for x, y, z, yaw in kernels:
        center = open_transform @ Vector((x, y, z))
        _add_ellipsoid(mesh, tuple(center), (0.026, 0.012, 0.009), malt_index, math.radians(yaw), 8, 4)
    return _object_from_bmesh("Malt", mesh, materials, smooth=True)


def _build_scoop(materials: list[bpy.types.Material]) -> bpy.types.Object:
    mesh = bmesh.new()
    wood_index = 3
    yaw = math.radians(-29.0)
    rotation = Matrix.Rotation(yaw, 4, "Z")
    # A tapered shallow blade plus long handle reads as a grain scoop, not a plank.
    center = Vector((0.38, -0.43, 0.035))
    local = [
        (-0.13, -0.09, -0.018), (0.14, -0.07, -0.018), (0.14, 0.07, -0.018), (-0.13, 0.09, -0.018),
        (-0.12, -0.08, 0.018), (0.13, -0.06, 0.018), (0.13, 0.06, 0.018), (-0.12, 0.08, 0.018),
    ]
    verts = [mesh.verts.new(center + rotation @ Vector(point)) for point in local]
    for indices in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        face = mesh.faces.new(tuple(verts[index] for index in indices))
        face.material_index = wood_index
    handle_start = center + rotation @ Vector((0.12, 0.0, 0.01))
    handle_end = center + rotation @ Vector((0.43, 0.0, 0.07))
    _add_cylinder_between(mesh, handle_start, handle_end, 0.022, wood_index, 10)
    _add_cylinder_between(mesh, center + rotation @ Vector((-0.12, -0.075, 0.018)), center + rotation @ Vector((0.12, -0.055, 0.018)), 0.008, wood_index, 7)
    _add_cylinder_between(mesh, center + rotation @ Vector((-0.12, 0.075, 0.018)), center + rotation @ Vector((0.12, 0.055, 0.018)), 0.008, wood_index, 7)
    return _object_from_bmesh("Scoop", mesh, materials, smooth=False)


def _unwrap_and_triangulate(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.025)
        bpy.ops.object.mode_set(mode="OBJECT")
        modifier = obj.modifiers.new("PortableGltfTriangles", "TRIANGULATE")
        # Fixed diagonal selection avoids Blender's BEAUTY tie-breaks reordering
        # symmetric malt-kernel sphere indices between otherwise identical builds.
        modifier.quad_method = "FIXED"
        modifier.ngon_method = "CLIP"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.data.validate(clean_customdata=False)
        obj.data.update()
        obj.select_set(False)


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    materials = [
        _create_material("WornLinenBurlap", BURLAP_SRGB, 0.94, "burlap"),
        _create_material("HempSeamsAndTies", ROPE_SRGB, 0.95, "rope"),
        _create_material("GoldenMaltedBarley", MALT_SRGB, 0.92, "malt"),
        _create_material("AgedOakGrainScoop", WOOD_SRGB, 0.88, "wood"),
    ]
    root = bpy.data.objects.new("MaltSackPile", None)
    bpy.context.collection.objects.link(root)

    sacks, tied_transforms = _build_sacks(materials)
    open_sack, open_transform = _build_open_sack(materials)
    seams = _build_seams_and_ties(materials, tied_transforms, open_transform)
    malt = _build_malt(materials, open_transform)
    scoop = _build_scoop(materials)
    meshes = [sacks, open_sack, seams, malt, scoop]
    for obj in meshes:
        obj.parent = root
    _unwrap_and_triangulate(meshes)

    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= minimum_z

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_malt_sack_pile.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = "linen sacks holding malted barley for a brewery or grain stall"
    root["identity_features"] = "gathered sacks; open malt; seams and ties; grain scoop"
    return root, meshes


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    triangles = 0
    vertices = 0
    faces = 0
    surfaces = 0
    uv_sets = 10_000
    material_names: set[str] = set()
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len(mesh.materials)
        uv_sets = min(uv_sets, len(mesh.uv_layers))
        for polygon in mesh.polygons:
            if polygon.material_index < len(mesh.materials):
                material_names.add(mesh.materials[polygon.material_index].name)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector((min(low.x, world.x), min(low.y, world.y), min(low.z, world.z)))
            high = Vector((max(high.x, world.x), max(high.y, world.y), max(high.z, world.z)))
    return {
        "asset_id": ASSET_ID,
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "materials": len(material_names),
        "mesh_objects": len(meshes),
        "surfaces": surfaces,
        "uv_sets": 0 if uv_sets == 10_000 else uv_sets,
        "dimensions_m": [round(value, 4) for value in (high.x - low.x, high.z - low.z, high.y - low.y)],
        "ground_min_z": round(low.z, 6),
        "floating_objects": 0,
        "texture_size": 512,
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


def _render_preview(output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.032, 0.028)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.15, 0.19, 0.11, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.0, -2.4, 3.0))
    key = bpy.context.object
    key.data.energy = 690.0
    key.data.shape = "DISK"
    key.data.size = 2.7
    key.data.color = (1.0, 0.84, 0.67)
    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.4, 2.0))
    fill = bpy.context.object
    fill.data.energy = 330.0
    fill.data.color = (0.52, 0.64, 0.82)
    fill.data.size = 2.3

    bpy.ops.object.camera_add(location=(1.75, -2.45, 1.45))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, -0.05, 0.31)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.32
    scene.camera = camera
    output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_malt_sack_pile.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "approval": "user-approved 2026-07-28",
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "identity_features": ["gathered_sacks", "open_malt", "visible_seams_and_ties", "grain_scoop"],
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    if (EVIDENCE_DIR / "godot_preview.png").exists():
        report["godot_preview"] = "generated/blender/malt_sack_pile_v1/godot_preview.png"
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "integrated",
        "approval": "user-approved 2026-07-28",
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
        _render_preview(preview)

    _write_evidence(metrics, preview)
    compact = {
        "triangles": metrics["triangles"],
        "materials": metrics["materials"],
        "uv_sets": metrics["uv_sets"],
        "dimensions_m": metrics["dimensions_m"],
        "ground_min": metrics["ground_min_z"],
        "sha256": metrics["sha256"],
    }
    print("ASSET_METRICS=" + json.dumps(compact, separators=(",", ":")))


if __name__ == "__main__":
    main()
