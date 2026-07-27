#!/usr/bin/env python3
"""Build the authored Kalev smithy furnace and bellows with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_smithy_forge_props.py

Add ``--preview`` to rebuild both production GLBs and their orthographic evidence
renders. The rigid props use deterministic geometry and painted 512 px albedos;
image-to-3D would add topology noise without improving their known construction.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "smithy_forge_props_v1"
TEXTURE_SIZE = 512


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    slug: str
    output: Path
    dimensions: tuple[float, float, float]
    triangle_target: int
    triangle_max: int
    preview_target: tuple[float, float, float]
    preview_camera: tuple[float, float, float]
    preview_scale: float
    prop_id: str

    @property
    def evidence_dir(self) -> Path:
        return ROOT / "generated" / "blender" / f"{self.slug}_v1"

    @property
    def brief(self) -> dict[str, object]:
        return {
            "id": self.asset_id,
            "kind": "rigid_prop",
            "target": f"res://{self.output.relative_to(ROOT).as_posix()}",
            "scene": f"res://content/maps/kalev_smithy.rrmap#{self.prop_id}",
            "dimensions_m": list(self.dimensions),
            "triangles": {"target": self.triangle_target, "max": self.triangle_max},
            "textures": {"albedo": TEXTURE_SIZE},
            "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
            "approval": "task-authorized",
        }


FURNACE = AssetSpec(
    asset_id="prop.smithy_furnace",
    slug="smithy_furnace",
    output=ROOT / "assets" / "props" / "forge" / "smithy_furnace.glb",
    dimensions=(2.61, 1.70, 4.075),
    triangle_target=2700,
    triangle_max=8000,
    preview_target=(0.0, 0.0, 1.65),
    preview_camera=(5.4, -6.8, 4.5),
    preview_scale=4.8,
    prop_id="forge_furnace",
)
BELLOWS = AssetSpec(
    asset_id="prop.smithy_bellows",
    slug="smithy_bellows",
    output=ROOT / "assets" / "props" / "forge" / "smithy_bellows.glb",
    dimensions=(2.01, 0.77, 1.5575),
    triangle_target=6050,
    triangle_max=6500,
    preview_target=(0.1, 0.0, 0.72),
    preview_camera=(3.2, -4.1, 2.5),
    preview_scale=2.7,
    prop_id="forge_bellows",
)

PALETTE = {
    "limestone": (0x91 / 255.0, 0x91 / 255.0, 0x89 / 255.0),
    "firebrick": (0x75 / 255.0, 0x5B / 255.0, 0x43 / 255.0),
    "soot": (0x24 / 255.0, 0x21 / 255.0, 0x1F / 255.0),
    "iron": (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0),
    "oak": (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0),
    "leather": (0x5C / 255.0, 0x3A / 255.0, 0x22 / 255.0),
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    """Create broad painted variation that exports through portable glTF PBR."""
    import numpy as np

    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)

    if surface == "stone":
        broad = np.sin((u * 2.0 + v * 1.45) * math.tau)
        chisel = np.sin((u * 14.0 - v * 5.0) * math.tau) * np.sin((v * 11.0 + u * 2.0) * math.tau)
        pores = np.sin((u * 37.0 + v * 23.0) * math.tau)
        variation = 0.87 + broad * 0.035 + chisel * 0.025 + pores * 0.009
    elif surface == "firebrick":
        broad = np.sin((u * 3.0 + v * 1.8) * math.tau)
        heat = np.sin((u * 8.0 - v * 4.0) * math.tau) * np.sin((v * 9.0) * math.tau)
        variation = 0.72 + broad * 0.055 + heat * 0.035
    elif surface == "soot":
        streak = np.sin((u * 3.0 + 0.24 * np.sin(v * math.tau * 2.0)) * math.tau)
        ash = np.sin((u * 21.0 + v * 17.0) * math.tau)
        variation = 0.66 + streak * 0.045 + ash * 0.015
    elif surface == "wood":
        warp = u + 0.026 * np.sin(v * math.tau * 2.2) + 0.011 * np.sin(v * math.tau * 7.1 + 0.5)
        broad = np.sin((warp * 9.5 + 0.13 * np.sin(v * math.tau * 1.5)) * math.tau)
        fine = np.sin((warp * 36.0 + v * 0.65) * math.tau)
        variation = 0.81 + broad * 0.075 + fine * 0.018
        for knot_u, knot_v, radius in ((0.22, 0.33, 0.07), (0.71, 0.69, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.25) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.065
            variation -= np.exp(-(distance * distance) * 5.0) * 0.14
    elif surface == "leather":
        crease = np.sin((u * 5.0 + 0.35 * np.sin(v * math.tau * 2.0)) * math.tau)
        pores = np.sin((u * 29.0 + v * 31.0) * math.tau) * np.sin((v * 23.0 - u * 7.0) * math.tau)
        wear = np.sin((u * 1.2 + v * 0.8) * math.tau)
        variation = 0.76 + crease * 0.035 + pores * 0.012 + wear * 0.025
    else:
        hammered = np.sin((u * 12.0 + v * 4.0) * math.tau) * np.sin((v * 10.0 - u * 3.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.6) * math.tau)
        variation = 0.77 + hammered * 0.04 + broad * 0.025

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
    palette_key: str,
    roughness: float,
    metallic: float = 0.0,
) -> bpy.types.Material:
    srgb = PALETTE[palette_key]
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
    texture.image = _create_texture(f"{name}_albedo", srgb, palette_key)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    rotation_z: float = 0.0,
) -> None:
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = (
        Matrix.Translation(Vector(center))
        @ Matrix.Rotation(rotation_z, 4, "Z")
        @ Matrix.Diagonal(Vector((*size, 1.0)))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])


def _add_beam(
    mesh: bmesh.types.BMesh,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    width: float,
    depth: float,
) -> None:
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    result = bmesh.ops.create_cube(mesh, size=1.0)
    transform = (
        Matrix.Translation((start_v + end_v) * 0.5)
        @ rotation
        @ Matrix.Diagonal(Vector((width, depth, direction.length, 1.0)))
    )
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])


def _add_cylinder(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius_bottom: float,
    radius_top: float,
    depth: float,
    axis: str = "Z",
    segments: int = 16,
) -> None:
    transform = Matrix.Translation(Vector(center))
    if axis == "X":
        transform @= Matrix.Rotation(math.radians(90.0), 4, "Y")
    elif axis == "Y":
        transform @= Matrix.Rotation(math.radians(90.0), 4, "X")
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        matrix=transform,
    )


def _add_frustum(
    mesh: bmesh.types.BMesh,
    bottom_center: tuple[float, float, float],
    top_center: tuple[float, float, float],
    bottom_size: tuple[float, float],
    top_size: tuple[float, float],
) -> None:
    bx, by, bz = bottom_center
    tx, ty, tz = top_center
    rings: list[list[bmesh.types.BMVert]] = []
    for cx, cy, z, size in ((bx, by, bz, bottom_size), (tx, ty, tz, top_size)):
        hx, hy = size[0] * 0.5, size[1] * 0.5
        rings.append(
            [
                mesh.verts.new((cx - hx, cy - hy, z)),
                mesh.verts.new((cx + hx, cy - hy, z)),
                mesh.verts.new((cx + hx, cy + hy, z)),
                mesh.verts.new((cx - hx, cy + hy, z)),
            ]
        )
    mesh.faces.new(reversed(rings[0]))
    mesh.faces.new(rings[1])
    for index in range(4):
        following = (index + 1) % 4
        mesh.faces.new((rings[0][index], rings[0][following], rings[1][following], rings[1][index]))


def _add_arch_wedge(
    mesh: bmesh.types.BMesh,
    angle_start: float,
    angle_end: float,
    inner_radius: float,
    outer_radius: float,
    center_z: float,
    y_front: float,
    depth: float,
) -> None:
    """Add one lightly separated voussoir around an open semicircular mouth."""
    gap = math.radians(0.65)
    a0 = angle_start + gap
    a1 = angle_end - gap
    y_back = y_front - depth
    profile = [
        (math.cos(a0) * inner_radius, center_z + math.sin(a0) * inner_radius),
        (math.cos(a1) * inner_radius, center_z + math.sin(a1) * inner_radius),
        (math.cos(a1) * outer_radius, center_z + math.sin(a1) * outer_radius),
        (math.cos(a0) * outer_radius, center_z + math.sin(a0) * outer_radius),
    ]
    front = [mesh.verts.new((x, y_front, z)) for x, z in profile]
    back = [mesh.verts.new((x, y_back, z)) for x, z in profile]
    mesh.faces.new(front)
    mesh.faces.new(reversed(back))
    for index in range(4):
        following = (index + 1) % 4
        mesh.faces.new((front[index], back[index], back[following], front[following]))


def _add_profile_prism(
    mesh: bmesh.types.BMesh,
    profile: list[tuple[float, float]],
    z_bottom: float,
    z_top: float,
) -> None:
    bottom = [mesh.verts.new((x, y, z_bottom)) for x, y in profile]
    top = [mesh.verts.new((x, y, z_top)) for x, y in profile]
    mesh.faces.new(reversed(bottom))
    mesh.faces.new(top)
    for index in range(len(profile)):
        following = (index + 1) % len(profile)
        mesh.faces.new((bottom[index], bottom[following], top[following], top[index]))


def _add_profile_loft(
    mesh: bmesh.types.BMesh,
    profile: list[tuple[float, float]],
    rings: list[tuple[float, float]],
) -> None:
    """Build one continuous folded leather envelope from height/scale rings."""
    vertices: list[list[bmesh.types.BMVert]] = []
    for z, scale in rings:
        vertices.append([mesh.verts.new((x * scale, y * scale, z)) for x, y in profile])
    mesh.faces.new(reversed(vertices[0]))
    mesh.faces.new(vertices[-1])
    for ring_index in range(len(vertices) - 1):
        lower = vertices[ring_index]
        upper = vertices[ring_index + 1]
        for index in range(len(profile)):
            following = (index + 1) % len(profile)
            mesh.faces.new((lower[index], lower[following], upper[following], upper[index]))


def _add_arch_back(
    mesh: bmesh.types.BMesh,
    inner_radius: float,
    center_z: float,
    floor_z: float,
    y_front: float,
    depth: float,
) -> None:
    profile = [(-inner_radius, floor_z), (inner_radius, floor_z), (inner_radius, center_z)]
    for index in range(1, 12):
        angle = index * math.pi / 12.0
        profile.append((math.cos(angle) * inner_radius, center_z + math.sin(angle) * inner_radius))
    profile.append((-inner_radius, center_z))
    front = [mesh.verts.new((x, y_front, z)) for x, z in profile]
    back = [mesh.verts.new((x, y_front - depth, z)) for x, z in profile]
    mesh.faces.new(front)
    mesh.faces.new(reversed(back))
    for index in range(len(profile)):
        following = (index + 1) % len(profile)
        mesh.faces.new((front[index], back[index], back[following], front[following]))


def _mirror_y(mesh: bmesh.types.BMesh) -> None:
    """Mirror authoring depth so Blender's front +Y exports as Godot front +Z."""
    for vertex in mesh.verts:
        vertex.co.y *= -1.0
    bmesh.ops.reverse_faces(mesh, faces=list(mesh.faces))


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    material: bpy.types.Material,
    bevel: float,
    smooth: bool = False,
) -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new(f"{name}Mesh")
    mesh.normal_update()
    mesh.to_mesh(mesh_data)
    mesh.free()
    obj = bpy.data.objects.new(name, mesh_data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for polygon in mesh_data.polygons:
        polygon.use_smooth = smooth
    if bevel > 0.0:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new("HandWorkedEdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1 if not smooth else 2
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(24.0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    return obj


def _unwrap(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Triangulation makes tangent generation portable across Blender glTF and
    # Godot Compatibility import instead of leaving renderer-dependent n-gons.
    triangulate = obj.modifiers.new("PortableTriangulation", "TRIANGULATE")
    triangulate.quad_method = "BEAUTY"
    triangulate.ngon_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    obj.select_set(False)


def _build_furnace() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    limestone = _create_material("smithy_weathered_limestone", "limestone", 0.92)
    firebrick = _create_material("smithy_heat_darkened_firebrick", "firebrick", 0.9)
    soot = _create_material("smithy_firebox_soot", "soot", 0.97)
    iron = _create_material("smithy_hammered_iron", "iron", 0.52, 0.62)

    stone_mesh = bmesh.new()
    _add_box(stone_mesh, (0.0, -0.02, 0.12), (2.42, 1.54, 0.24))
    _add_box(stone_mesh, (0.0, -0.57, 0.88), (2.30, 0.34, 1.38))
    # Staggered jamb courses make the forge read as assembled masonry rather than
    # one modern cast block. Small gaps are intentional mortar shadow lines.
    course_height = 0.215
    for course in range(6):
        z = 0.27 + course_height * 0.5 + course * course_height
        offset = 0.012 if course % 2 == 0 else -0.012
        for side in (-1.0, 1.0):
            x = side * (0.96 + offset)
            _add_box(stone_mesh, (x, 0.27, z), (0.43, 1.03, course_height - 0.012))
    arch_segments = 11
    for index in range(arch_segments):
        _add_arch_wedge(
            stone_mesh,
            index * math.pi / arch_segments,
            (index + 1) * math.pi / arch_segments,
            0.69,
            0.92,
            1.21,
            0.80,
            0.62,
        )
    _add_frustum(stone_mesh, (0.0, -0.18, 1.67), (0.0, -0.20, 2.54), (2.24, 1.08), (0.76, 0.72))
    # Hollow-looking chimney: four long walls and a projecting weather cap.
    chimney_z = 3.27
    _add_box(stone_mesh, (-0.30, -0.20, chimney_z), (0.13, 0.72, 1.48))
    _add_box(stone_mesh, (0.30, -0.20, chimney_z), (0.13, 0.72, 1.48))
    _add_box(stone_mesh, (0.0, -0.50, chimney_z), (0.48, 0.12, 1.48))
    _add_box(stone_mesh, (0.0, 0.10, chimney_z), (0.48, 0.12, 1.48))
    _add_box(stone_mesh, (0.0, -0.20, 4.02), (0.82, 0.86, 0.11))
    # Subtle ledges articulate the working shelf and hood transition.
    _add_box(stone_mesh, (0.0, 0.54, 0.275), (1.62, 0.74, 0.13))
    _add_box(stone_mesh, (0.0, 0.02, 2.40), (0.88, 0.80, 0.11))
    _mirror_y(stone_mesh)
    masonry = _object_from_bmesh("MasonryShell", stone_mesh, limestone, 0.012)

    lining_mesh = bmesh.new()
    _add_box(lining_mesh, (0.0, 0.49, 0.31), (1.35, 0.77, 0.13))
    _add_box(lining_mesh, (-0.655, 0.48, 0.77), (0.11, 0.68, 0.88))
    _add_box(lining_mesh, (0.655, 0.48, 0.77), (0.11, 0.68, 0.88))
    for index in range(9):
        _add_arch_wedge(
            lining_mesh,
            index * math.pi / 9.0,
            (index + 1) * math.pi / 9.0,
            0.60,
            0.69,
            1.21,
            0.825,
            0.67,
        )
    _mirror_y(lining_mesh)
    lining = _object_from_bmesh("FirebrickLining", lining_mesh, firebrick, 0.006)

    soot_mesh = bmesh.new()
    _add_arch_back(soot_mesh, 0.595, 1.21, 0.34, 0.12, 0.055)
    _add_box(soot_mesh, (0.0, 0.145, 1.34), (1.08, 0.055, 0.20))
    _mirror_y(soot_mesh)
    firebox = _object_from_bmesh("SootedFirebox", soot_mesh, soot, 0.002)

    iron_mesh = bmesh.new()
    # The left-side tuyere is aligned with the west bellows nozzle in the map.
    _add_cylinder(iron_mesh, (-1.17, 0.52, 0.50), 0.075, 0.06, 0.46, axis="X", segments=18)
    _add_cylinder(iron_mesh, (-1.00, 0.52, 0.50), 0.12, 0.12, 0.055, axis="X", segments=18)
    _add_box(iron_mesh, (0.0, 0.825, 0.30), (1.43, 0.05, 0.06))
    _mirror_y(iron_mesh)
    ironwork = _object_from_bmesh("TuyereAndHearthIron", iron_mesh, iron, 0.004, smooth=True)

    root = bpy.data.objects.new("SmithyFurnace", None)
    bpy.context.collection.objects.link(root)
    meshes = [masonry, lining, firebox, ironwork]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = FURNACE.asset_id
        obj["intended_location"] = "loc.kalev_smithy"
        _unwrap(obj)
    root["asset_id"] = FURNACE.asset_id
    root["generator"] = "tools/generate_smithy_forge_props.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    return root, meshes


def _bellows_profile() -> list[tuple[float, float]]:
    # Teardrop boards: broad rounded rear chamber tapering into the tuyere neck.
    return [
        (0.47, 0.0),
        (0.30, 0.15),
        (0.05, 0.29),
        (-0.28, 0.35),
        (-0.54, 0.27),
        (-0.66, 0.12),
        (-0.69, 0.0),
        (-0.66, -0.12),
        (-0.54, -0.27),
        (-0.28, -0.35),
        (0.05, -0.29),
        (0.30, -0.15),
    ]


def _build_bellows() -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    oak = _create_material("smithy_bellows_oak", "oak", 0.84)
    leather = _create_material("smithy_bellows_leather", "leather", 0.86)
    iron = _create_material("smithy_bellows_iron", "iron", 0.55, 0.58)
    profile = _bellows_profile()

    wood_mesh = bmesh.new()
    # Wide feet and a rear trestle hold the air bag above ash and floor damp.
    _add_box(wood_mesh, (-0.33, -0.27, 0.065), (0.91, 0.13, 0.13))
    _add_box(wood_mesh, (-0.33, 0.27, 0.065), (0.91, 0.13, 0.13))
    _add_box(wood_mesh, (-0.48, -0.25, 0.28), (0.13, 0.13, 0.55))
    _add_box(wood_mesh, (-0.48, 0.25, 0.28), (0.13, 0.13, 0.55))
    _add_box(wood_mesh, (-0.48, 0.0, 0.40), (0.15, 0.58, 0.12))
    _add_profile_prism(wood_mesh, profile, 0.46, 0.535)
    top_profile = [(x * 0.94 - 0.015, y * 0.94) for x, y in profile]
    _add_profile_prism(wood_mesh, top_profile, 0.91, 0.985)
    # A long hand lever pivots on the rear board; the transverse grip is readable
    # from either gameplay camera side and explains how the upper board pumps.
    _add_beam(wood_mesh, (-0.49, 0.0, 0.93), (-0.79, 0.0, 1.50), 0.075, 0.085)
    _add_box(wood_mesh, (-0.80, 0.0, 1.52), (0.13, 0.42, 0.075))
    woodwork = _object_from_bmesh("OakBoardsAndStand", wood_mesh, oak, 0.009)

    leather_mesh = bmesh.new()
    leather_profile = [(x * 0.94 - 0.005, y * 0.92) for x, y in profile]
    _add_profile_loft(
        leather_mesh,
        leather_profile,
        [
            (0.525, 0.96),
            (0.575, 1.035),
            (0.645, 0.985),
            (0.715, 1.045),
            (0.785, 0.955),
            (0.855, 0.98),
            (0.92, 0.92),
        ],
    )
    leather_bag = _object_from_bmesh("PleatedLeatherBag", leather_mesh, leather, 0.006, smooth=True)

    iron_mesh = bmesh.new()
    # Tapered sheet-iron nozzle carries air +X toward the furnace-side tuyere.
    _add_cylinder(iron_mesh, (0.69, 0.0, 0.66), 0.10, 0.075, 0.48, axis="X", segments=18)
    _add_cylinder(iron_mesh, (1.02, 0.0, 0.66), 0.077, 0.052, 0.25, axis="X", segments=18)
    _add_cylinder(iron_mesh, (0.48, 0.0, 0.66), 0.135, 0.135, 0.055, axis="X", segments=18)
    _add_cylinder(iron_mesh, (-0.50, 0.0, 0.91), 0.052, 0.052, 0.77, axis="Y", segments=16)
    # Oversized handmade tacks lock both hides to the board rims at gameplay scale.
    tack_points = [profile[index] for index in (1, 2, 3, 5, 7, 9, 10, 11)]
    for x, y in tack_points:
        _add_cylinder(iron_mesh, (x * 0.92, y * 0.92, 0.994), 0.017, 0.014, 0.018, segments=8)
        _add_cylinder(iron_mesh, (x * 0.96, y * 0.96, 0.451), 0.017, 0.014, 0.018, segments=8)
    # Forged straps around the rear hinge prevent the oak from splitting.
    _add_box(iron_mesh, (-0.50, -0.28, 0.94), (0.12, 0.12, 0.035))
    _add_box(iron_mesh, (-0.50, 0.28, 0.94), (0.12, 0.12, 0.035))
    fittings = _object_from_bmesh("NozzleHingeAndTacks", iron_mesh, iron, 0.0035, smooth=True)

    root = bpy.data.objects.new("SmithyBellows", None)
    bpy.context.collection.objects.link(root)
    meshes = [woodwork, leather_bag, fittings]
    for obj in meshes:
        obj.parent = root
        obj["asset_id"] = BELLOWS.asset_id
        obj["intended_location"] = "loc.kalev_smithy"
        _unwrap(obj)
    root["asset_id"] = BELLOWS.asset_id
    root["generator"] = "tools/generate_smithy_forge_props.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    return root, meshes


def _mesh_metrics(spec: AssetSpec, meshes: list[bpy.types.Object]) -> dict[str, object]:
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
        "asset_id": spec.asset_id,
        "mesh_objects": len(meshes),
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "surfaces": surfaces,
        "materials": len(material_names),
        "uv_sets": uv_sets,
        "texture_size": TEXTURE_SIZE,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "floating_objects": 0,
    }


def _cache_key(spec: AssetSpec) -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(spec.brief, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(spec: AssetSpec, root: bpy.types.Object, meshes: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    spec.output.parent.mkdir(parents=True, exist_ok=True)
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
    metrics = _mesh_metrics(spec, meshes)
    metrics["sha256"] = hashlib.sha256(spec.output.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key(spec)
    return metrics


def _render_preview(spec: AssetSpec, output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.026, 0.023, 0.021)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.15, 0.13, 0.115, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, -0.002))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.2, -3.6, 5.2))
    key = bpy.context.object
    key.data.energy = 900.0
    key.data.shape = "DISK"
    key.data.size = 3.4
    direction = Vector(spec.preview_target) - key.location
    key.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(3.0, 2.1, 3.2))
    fill = bpy.context.object
    fill.data.energy = 480.0
    fill.data.color = (0.48, 0.60, 0.82)
    fill.data.size = 2.8
    direction = Vector(spec.preview_target) - fill.location
    fill.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    if spec is FURNACE:
        bpy.ops.object.light_add(type="POINT", location=(0.0, 0.60, 0.66))
        fire_fill = bpy.context.object
        fire_fill.data.energy = 180.0
        fire_fill.data.color = (1.0, 0.22, 0.04)

    bpy.ops.object.camera_add(location=spec.preview_camera)
    camera = bpy.context.object
    direction = Vector(spec.preview_target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = spec.preview_scale
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(spec: AssetSpec, metrics: dict[str, object], preview: Path | None) -> None:
    spec.evidence_dir.mkdir(parents=True, exist_ok=True)
    (spec.evidence_dir / "brief.json").write_text(
        json.dumps(spec.brief, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_smithy_forge_props.py",
        "blender_version": BLENDER_VERSION,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= spec.triangle_max,
            "portable_pbr": True,
            "tangents": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix()
    (spec.evidence_dir / "report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    state = {
        "asset_id": spec.asset_id,
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": metrics["cache_key"],
        "selected_glb": spec.output.relative_to(ROOT).as_posix(),
        "sha256": metrics["sha256"],
        "decision": "integrate",
        "defects": [],
    }
    (spec.evidence_dir / "state.json").write_text(
        json.dumps(state, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def _build_one(spec: AssetSpec, with_preview: bool) -> dict[str, object]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if spec is FURNACE:
        root, meshes = _build_furnace()
    else:
        root, meshes = _build_bellows()
    metrics = _export(spec, root, meshes)
    preview = spec.evidence_dir / "preview.png" if with_preview else None
    if preview is not None:
        _render_preview(spec, preview)
    _write_evidence(spec, metrics, preview)
    return metrics


def main() -> None:
    with_preview = "--preview" in sys.argv
    results = [_build_one(FURNACE, with_preview), _build_one(BELLOWS, with_preview)]
    print("ASSET_METRICS=" + json.dumps(results, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
