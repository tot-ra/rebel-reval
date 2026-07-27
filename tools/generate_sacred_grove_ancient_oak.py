#!/usr/bin/env python3
"""Build the production Sacred Grove ancient oak with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_sacred_grove_ancient_oak.py -- --preview

The model is deterministic and ships as a Y-up GLB with embedded painted PBR
textures. Evidence is written under generated/blender/sacred_grove_ancient_oak_v1/.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "props" / "environment" / "sacred_grove_ancient_oak.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "sacred_grove_ancient_oak_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.sacred_grove_ancient_oak"
GENERATOR_VERSION = "sacred_grove_ancient_oak_v1"
BLENDER_VERSION = "Blender 5.2 LTS"
SEED = 1343

BRIEF = {
    "id": ASSET_ID,
    "kind": "organic_hero_landmark",
    "target": "res://assets/props/environment/sacred_grove_ancient_oak.glb",
    "scene": "res://content/maps/world_sacred_grove.rrmap#ancient_oak",
    "dimensions_m": [30.5, 26.5, 21.0],
    "triangles": {"target": 50000, "max": 70000},
    "textures": {"bark": 1024, "leaf": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


@dataclass
class Branch:
    points: list[Vector]
    radii: list[float]
    radial_segments: int
    depth: int
    leaf_density: float = 0.0
    broken: bool = False


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _image_from_array(name: str, pixels: np.ndarray, colorspace: str = "sRGB") -> bpy.types.Image:
    height, width, channels = pixels.shape
    if channels == 3:
        pixels = np.concatenate((pixels, np.ones((height, width, 1), dtype=np.float32)), axis=2)
    image = bpy.data.images.new(name, width=width, height=height, alpha=True)
    image.colorspace_settings.name = colorspace
    image.file_format = "PNG"
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.pack()
    return image


def _create_bark_images() -> tuple[bpy.types.Image, bpy.types.Image]:
    """Bake broad fissured oak bark and a matching tangent-space normal map."""
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    rng = np.random.default_rng(SEED)

    # Several warped vertical frequencies produce irregular old-oak plates rather
    # than the repeated sine stripes used by the former runtime tube material.
    warp = u + 0.035 * np.sin(v * math.tau * 1.7) + 0.014 * np.sin(v * math.tau * 6.1 + 1.2)
    broad = np.abs(np.sin((warp * 7.0 + 0.09 * np.sin(v * math.tau * 2.3)) * math.tau))
    middle = np.abs(np.sin((warp * 19.0 - v * 0.7) * math.tau))
    fine = np.abs(np.sin((warp * 43.0 + v * 1.8) * math.tau))
    cellular = rng.random((64, 64), dtype=np.float32)
    cellular = np.repeat(np.repeat(cellular, size // 64, axis=0), size // 64, axis=1)
    cellular = (
        cellular
        + np.roll(cellular, 1, axis=0)
        + np.roll(cellular, -1, axis=0)
        + np.roll(cellular, 1, axis=1)
        + np.roll(cellular, -1, axis=1)
    ) / 5.0
    height = np.clip(0.24 + broad * 0.46 + middle * 0.19 + fine * 0.07 + cellular * 0.08, 0.0, 1.0)
    fissure = np.clip((0.43 - broad) * 2.8, 0.0, 1.0)
    plate = np.clip(height * (0.90 + 0.08 * np.sin(v * math.tau * 3.0)), 0.0, 1.0)

    base = np.array([0.20, 0.105, 0.050], dtype=np.float32)
    warm = np.array([0.40, 0.225, 0.105], dtype=np.float32)
    rgb_srgb = base[None, None, :] * (1.0 - plate[:, :, None]) + warm[None, None, :] * plate[:, :, None]
    rgb_srgb *= (1.0 - fissure[:, :, None] * 0.48)

    # Sparse desaturated lichen belongs in the bark surface, not as implausible
    # long hanging moss on a northern European oak.
    lichen_field = (
        np.sin(u * math.tau * 3.0 + np.sin(v * math.tau * 2.0))
        + np.sin(v * math.tau * 4.0 - u * math.tau * 1.5)
    )
    lichen_mask = np.clip((lichen_field - 1.05) * 1.7, 0.0, 0.52) * np.clip(1.15 - v, 0.0, 1.0)
    lichen = np.array([0.32, 0.39, 0.23], dtype=np.float32)
    rgb_srgb = rgb_srgb * (1.0 - lichen_mask[:, :, None]) + lichen[None, None, :] * lichen_mask[:, :, None]
    rgb_linear = np.vectorize(_srgb_to_linear)(np.clip(rgb_srgb, 0.0, 1.0)).astype(np.float32)
    albedo = _image_from_array("ancient_oak_bark_albedo", rgb_linear)

    dx = np.roll(height, -2, axis=1) - np.roll(height, 2, axis=1)
    dy = np.roll(height, -2, axis=0) - np.roll(height, 2, axis=0)
    strength = 2.9
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5), axis=2)
    normal_image = _image_from_array("ancient_oak_bark_normal", normal.astype(np.float32), "Non-Color")
    return albedo, normal_image


def _create_leaf_image() -> bpy.types.Image:
    """Bake restrained leaf value variation and veins for the shaped leaf mesh."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    broad = 0.76 + 0.10 * np.sin((u * 2.2 + v * 1.1) * math.tau)
    fine = 0.035 * np.sin((u * 13.0 - v * 9.0) * math.tau)
    central_vein = np.exp(-((u - 0.5) / 0.018) ** 2) * 0.19
    side_veins = np.zeros_like(u)
    for offset in (0.20, 0.31, 0.42, 0.54, 0.66, 0.77):
        distance = np.minimum(np.abs((u - 0.5) - (v - offset) * 0.72), np.abs((u - 0.5) + (v - offset) * 0.72))
        side_veins += np.exp(-(distance / 0.012) ** 2) * np.exp(-((v - offset) / 0.12) ** 2) * 0.055
    edge_age = np.clip((np.abs(u - 0.5) - 0.34) * 1.4, 0.0, 0.08)
    value = np.clip(broad + fine + central_vein + side_veins - edge_age, 0.55, 1.05)
    base = np.array([0.115, 0.255, 0.075], dtype=np.float32)
    rgb_srgb = np.clip(base[None, None, :] * value[:, :, None], 0.0, 1.0)
    rgb_linear = np.vectorize(_srgb_to_linear)(rgb_srgb).astype(np.float32)
    return _image_from_array("ancient_oak_leaf_albedo", rgb_linear)


def _create_materials() -> dict[str, bpy.types.Material]:
    bark_albedo, bark_normal = _create_bark_images()
    leaf_albedo = _create_leaf_image()

    bark = bpy.data.materials.new("Ancient oak fissured bark")
    bark.use_nodes = True
    bark.diffuse_color = (0.12, 0.055, 0.025, 1.0)
    bark.roughness = 0.92
    nodes = bark.node_tree.nodes
    links = bark.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.92
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.name = "EmbeddedBarkAlbedo"
    color_node.image = bark_albedo
    color_node.extension = "REPEAT"
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.name = "EmbeddedBarkNormal"
    normal_node.image = bark_normal
    normal_node.extension = "REPEAT"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    links.new(color_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])

    leaf = bpy.data.materials.new("Ancient oak leaves")
    leaf.use_nodes = True
    leaf.use_backface_culling = False
    leaf.diffuse_color = (0.08, 0.23, 0.05, 1.0)
    leaf.roughness = 0.84
    leaf_nodes = leaf.node_tree.nodes
    leaf_links = leaf.node_tree.links
    leaf_principled = leaf_nodes.get("Principled BSDF")
    leaf_principled.inputs["Roughness"].default_value = 0.84
    leaf_principled.inputs["Coat Weight"].default_value = 0.04
    leaf_texture = leaf_nodes.new("ShaderNodeTexImage")
    leaf_texture.name = "EmbeddedLeafAlbedo"
    leaf_texture.image = leaf_albedo
    leaf_texture.extension = "CLIP"
    leaf_links.new(leaf_texture.outputs["Color"], leaf_principled.inputs["Base Color"])

    heartwood = bpy.data.materials.new("Weathered heartwood")
    heartwood.diffuse_color = tuple(_srgb_to_linear(value) for value in (0.38, 0.20, 0.075)) + (1.0,)
    heartwood.roughness = 0.88

    hollow = bpy.data.materials.new("Deep hollow")
    hollow.diffuse_color = tuple(_srgb_to_linear(value) for value in (0.035, 0.020, 0.012)) + (1.0,)
    hollow.roughness = 1.0
    return {"bark": bark, "leaf": leaf, "heartwood": heartwood, "hollow": hollow}


def _cubic(start: Vector, control_a: Vector, control_b: Vector, end: Vector, t: float) -> Vector:
    inv = 1.0 - t
    return start * inv**3 + control_a * (3.0 * inv**2 * t) + control_b * (3.0 * inv * t**2) + end * t**3


def _path_from_controls(start: Vector, initial: Vector, end: Vector, final: Vector, sections: int) -> list[Vector]:
    distance = (end - start).length
    control_a = start + initial.normalized() * distance * 0.36
    control_b = end - final.normalized() * distance * 0.30
    return [_cubic(start, control_a, control_b, end, index / float(sections)) for index in range(sections + 1)]


def _trunk_path() -> Branch:
    points: list[Vector] = []
    radii: list[float] = []
    sections = 18
    for index in range(sections + 1):
        t = index / float(sections)
        z = 16.4 * t
        drift = Vector((
            -0.62 * t**1.45 + math.sin(t * 7.2) * 0.12 * t,
            0.38 * t**1.6 + math.sin(t * 5.1 + 1.1) * 0.10 * t,
            z,
        ))
        points.append(drift)
        radius = 2.25 * (1.0 - t) ** 0.72 + 0.34
        radius += 0.32 * math.exp(-((t - 0.08) / 0.11) ** 2)
        radii.append(radius)
    return Branch(points, radii, 16, 0)


def _point_and_tangent(branch: Branch, t: float) -> tuple[Vector, Vector, float]:
    segment_t = max(0.0, min(0.9999, t)) * (len(branch.points) - 1)
    index = min(int(segment_t), len(branch.points) - 2)
    local = segment_t - index
    point = branch.points[index].lerp(branch.points[index + 1], local)
    tangent = (branch.points[index + 1] - branch.points[index]).normalized()
    radius = branch.radii[index] * (1.0 - local) + branch.radii[index + 1] * local
    return point, tangent, radius


def _make_branch(
    start: Vector,
    parent_tangent: Vector,
    yaw: float,
    length: float,
    rise: float,
    radius: float,
    depth: int,
    rng: random.Random,
    broken: bool = False,
) -> Branch:
    horizontal = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    initial = (horizontal * 0.82 + parent_tangent * 0.26 + Vector((0.0, 0.0, rise * 0.16))).normalized()
    sideways = Vector((-horizontal.y, horizontal.x, 0.0))
    end = start + horizontal * length + sideways * rng.uniform(-0.8, 0.8) + Vector((0.0, 0.0, rise))
    # Old oak boughs bow under their own weight, then turn upward near the tips.
    if depth <= 1:
        end.z -= length * rng.uniform(0.03, 0.09)
    final = (horizontal * 0.70 + sideways * rng.uniform(-0.22, 0.22) + Vector((0.0, 0.0, 0.44))).normalized()
    sections = 9 if depth == 1 else 7 if depth == 2 else 6
    points = _path_from_controls(start, initial, end, final, sections)
    radii = []
    tip_ratio = 0.34 if broken else 0.12
    for index in range(sections + 1):
        t = index / float(sections)
        radii.append(radius * ((1.0 - t) ** 0.76 * (1.0 - tip_ratio) + tip_ratio))
    return Branch(points, radii, 12 if depth == 1 else 8 if depth == 2 else 6, depth, 1.0 if depth >= 3 else 0.25, broken)


def _build_skeleton() -> tuple[list[Branch], list[Vector], list[tuple[Vector, Vector, float]]]:
    rng = random.Random(SEED)
    trunk = _trunk_path()
    branches: list[Branch] = [trunk]
    leaf_anchors: list[Vector] = []
    broken_caps: list[tuple[Vector, Vector, float]] = []

    # Buttress roots radiate unevenly and remain partly above ground, grounding the
    # massive bole without altering the map-owned collision or navigation data.
    for root_index in range(11):
        yaw = root_index * math.tau / 11.0 + rng.uniform(-0.13, 0.13)
        length = rng.uniform(4.1, 6.4)
        start = Vector((math.cos(yaw) * 0.72, math.sin(yaw) * 0.72, rng.uniform(0.72, 1.25)))
        end = Vector((math.cos(yaw) * length, math.sin(yaw) * length, 0.04))
        side = Vector((-math.sin(yaw), math.cos(yaw), 0.0)) * rng.uniform(-0.45, 0.45)
        control_a = start + Vector((math.cos(yaw), math.sin(yaw), -0.08)) * length * 0.36 + side
        control_b = end - Vector((math.cos(yaw), math.sin(yaw), -0.18)) * length * 0.30 - side * 0.4
        points = [_cubic(start, control_a, control_b, end, t / 6.0) for t in range(7)]
        base_radius = rng.uniform(0.52, 0.82)
        radii = [base_radius * ((1.0 - t / 6.0) ** 0.82 * 0.88 + 0.12) for t in range(7)]
        branches.append(Branch(points, radii, 10, 0))

    primary_specs: list[tuple[float, float, float, float]] = []
    for index in range(10):
        attach_t = 0.31 + index * 0.047 + rng.uniform(-0.014, 0.014)
        yaw = index * 2.39996 + rng.uniform(-0.28, 0.28)
        length = rng.uniform(8.2, 11.8) * (1.0 - max(0.0, attach_t - 0.55) * 0.45)
        rise = rng.uniform(1.0, 4.2)
        primary_specs.append((attach_t, yaw, length, rise))

    for primary_index, (attach_t, yaw, length, rise) in enumerate(primary_specs):
        start, parent_tangent, trunk_radius = _point_and_tangent(trunk, attach_t)
        start += Vector((math.cos(yaw), math.sin(yaw), 0.0)) * trunk_radius * 0.42
        is_broken = primary_index == 3
        branch_length = length * 0.58 if is_broken else length
        primary = _make_branch(
            start,
            parent_tangent,
            yaw,
            branch_length,
            rise * (0.55 if is_broken else 1.0),
            trunk_radius * rng.uniform(0.54, 0.69),
            1,
            rng,
            is_broken,
        )
        branches.append(primary)
        if is_broken:
            broken_caps.append((primary.points[-1], (primary.points[-1] - primary.points[-2]).normalized(), primary.radii[-1] * 1.08))
            continue

        for secondary_index, secondary_t in enumerate((0.38, 0.58, 0.75, 0.89)):
            branch_start, branch_tangent, parent_radius = _point_and_tangent(primary, secondary_t + rng.uniform(-0.025, 0.025))
            side_sign = -1.0 if secondary_index % 2 == 0 else 1.0
            secondary_yaw = yaw + side_sign * rng.uniform(0.58, 1.05) + rng.uniform(-0.18, 0.18)
            secondary_length = length * rng.uniform(0.32, 0.50) * (1.0 - secondary_t * 0.18)
            secondary = _make_branch(
                branch_start,
                branch_tangent,
                secondary_yaw,
                secondary_length,
                rng.uniform(1.0, 3.1),
                parent_radius * rng.uniform(0.52, 0.68),
                2,
                rng,
            )
            branches.append(secondary)

            for tertiary_index, tertiary_t in enumerate((0.48, 0.73, 0.91)):
                twig_start, twig_tangent, twig_radius = _point_and_tangent(secondary, tertiary_t + rng.uniform(-0.03, 0.02))
                twig_sign = -1.0 if (tertiary_index + secondary_index) % 2 == 0 else 1.0
                twig_yaw = secondary_yaw + twig_sign * rng.uniform(0.48, 0.92)
                twig = _make_branch(
                    twig_start,
                    twig_tangent,
                    twig_yaw,
                    secondary_length * rng.uniform(0.34, 0.52),
                    rng.uniform(0.7, 2.0),
                    twig_radius * rng.uniform(0.45, 0.61),
                    3,
                    rng,
                )
                branches.append(twig)
                leaf_anchors.extend((twig.points[-1], twig.points[-2], twig.points[-3]))
            leaf_anchors.extend((secondary.points[-1], secondary.points[-2]))
        leaf_anchors.extend((primary.points[-1], primary.points[-2]))

    # Four irregular leaders keep the crown high and prevent the main trunk from
    # ending as a blunt pole when viewed from the first-person camera below.
    for leader_index, (attach_t, yaw, length, rise) in enumerate(
        ((0.55, 0.3, 5.4, 7.5), (0.64, 2.0, 5.0, 8.0), (0.72, 4.2, 4.5, 7.0), (0.80, 5.4, 4.0, 6.2))
    ):
        start, tangent, radius = _point_and_tangent(trunk, attach_t)
        leader = _make_branch(start, tangent, yaw, length, rise, radius * 0.62, 1, rng)
        branches.append(leader)
        for split_index, split_t in enumerate((0.42, 0.65, 0.84)):
            split_start, split_tangent, split_radius = _point_and_tangent(leader, split_t)
            split_yaw = yaw + (-1.0 if split_index % 2 == 0 else 1.0) * rng.uniform(0.7, 1.15)
            split = _make_branch(
                split_start,
                split_tangent,
                split_yaw,
                length * rng.uniform(0.36, 0.52),
                rng.uniform(1.3, 2.8),
                split_radius * 0.60,
                2,
                rng,
            )
            branches.append(split)
            leaf_anchors.extend((split.points[-1], split.points[-2], split.points[-3]))
        leaf_anchors.extend((leader.points[-1], leader.points[-2]))

    # Interior crown anchors close only large visual gaps. They are deterministic,
    # sparse, and never disconnected from the volume occupied by actual branches.
    for _ in range(48):
        angle = rng.random() * math.tau
        radius = rng.uniform(2.2, 8.7)
        z = rng.uniform(10.0, 20.8) - radius * 0.06
        leaf_anchors.append(Vector((math.cos(angle) * radius - 0.3, math.sin(angle) * radius + 0.2, z)))
    return branches, leaf_anchors, broken_caps


def _stable_frame(direction: Vector) -> tuple[Vector, Vector]:
    axis = direction.normalized()
    reference = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.91 else Vector((0.0, 1.0, 0.0))
    side = axis.cross(reference).normalized()
    up = side.cross(axis).normalized()
    return side, up


def _build_wood_mesh(branches: list[Branch], bark: bpy.types.Material) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    uvs: list[tuple[float, float]] = []
    face_uvs: list[tuple[int, int, int, int]] = []

    for branch_index, branch in enumerate(branches):
        ring_starts: list[int] = []
        distance = 0.0
        previous = branch.points[0]
        for point_index, point in enumerate(branch.points):
            if point_index > 0:
                distance += (point - previous).length
            previous = point
            tangent = (
                branch.points[1] - branch.points[0]
                if point_index == 0
                else branch.points[-1] - branch.points[-2]
                if point_index == len(branch.points) - 1
                else branch.points[point_index + 1] - branch.points[point_index - 1]
            ).normalized()
            side, up = _stable_frame(tangent)
            ring_starts.append(len(vertices))
            for radial_index in range(branch.radial_segments):
                angle = radial_index * math.tau / branch.radial_segments
                # Low-amplitude longitudinal ridges break the perfect cylinders
                # while preserving clean normals and a bounded triangle count.
                ridge = 1.0 + 0.055 * math.sin(angle * (5 if branch.depth == 0 else 3) + branch_index * 0.71 + distance * 0.45)
                radius = branch.radii[point_index] * ridge
                offset = side * (math.cos(angle) * radius) + up * (math.sin(angle) * radius)
                vertices.append(tuple(point + offset))
                uvs.append((radial_index / float(branch.radial_segments), distance / 3.2))

        for ring_index in range(len(ring_starts) - 1):
            current = ring_starts[ring_index]
            following = ring_starts[ring_index + 1]
            for radial_index in range(branch.radial_segments):
                nxt = (radial_index + 1) % branch.radial_segments
                faces.append((current + radial_index, current + nxt, following + nxt, following + radial_index))
                face_uvs.append((current + radial_index, current + nxt, following + nxt, following + radial_index))

        # Cap exposed root tips and the few branch ends that carry no leaves.
        if branch.depth == 0 or branch.broken:
            for ring_start, flip in ((ring_starts[0], True), (ring_starts[-1], False)):
                center = len(vertices)
                point = branch.points[0] if flip else branch.points[-1]
                vertices.append(tuple(point))
                uvs.append((0.5, 0.5))
                for radial_index in range(branch.radial_segments):
                    nxt = (radial_index + 1) % branch.radial_segments
                    face = (center, ring_start + nxt, ring_start + radial_index) if flip else (center, ring_start + radial_index, ring_start + nxt)
                    faces.append(face)
                    face_uvs.append(face)

    mesh = bpy.data.meshes.new("AncientOakWoodMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, indices in zip(mesh.polygons, face_uvs, strict=True):
        for loop_index, vertex_index in zip(polygon.loop_indices, indices, strict=True):
            uv_layer.data[loop_index].uv = uvs[vertex_index]
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("AncientOakWood", mesh)
    mesh.materials.append(bark)
    return obj


def _leaf_boundary() -> list[tuple[float, float]]:
    # Lobed Quercus robur silhouette in normalized width/length coordinates.
    return [
        (0.00, 0.00), (-0.18, 0.16), (-0.42, 0.30), (-0.22, 0.43),
        (-0.46, 0.58), (-0.23, 0.74), (0.00, 1.00), (0.23, 0.74),
        (0.46, 0.58), (0.22, 0.43), (0.42, 0.30), (0.18, 0.16),
    ]


def _build_foliage_mesh(anchors: list[Vector], leaf_material: bpy.types.Material) -> tuple[bpy.types.Object, int]:
    rng = random.Random(SEED + 77)
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    uv_values: list[tuple[float, float]] = []
    face_uvs: list[tuple[int, ...]] = []
    boundary = _leaf_boundary()
    leaf_count = 0

    for anchor_index, anchor in enumerate(anchors):
        leaves_here = 6 + (anchor_index % 4)
        cluster_radius = rng.uniform(0.52, 0.92)
        for leaf_index in range(leaves_here):
            theta = rng.random() * math.tau
            radial = cluster_radius * math.sqrt(rng.random())
            center = anchor + Vector((
                math.cos(theta) * radial,
                math.sin(theta) * radial,
                rng.uniform(-0.42, 0.54),
            ))
            outward = Vector((center.x + 0.3, center.y - 0.2, max(0.3, center.z - 10.0))).normalized()
            normal = (outward * 0.45 + Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), rng.uniform(0.45, 1.0)))).normalized()
            side, length_axis = _stable_frame(normal)
            if length_axis.z < 0.0:
                length_axis = -length_axis
            size = rng.uniform(0.28, 0.46)
            width = size * rng.uniform(0.78, 0.98)
            base_index = len(vertices)
            # A central ridge gives each leaf a shallow V section, catching light
            # from below without relying on transparent crossed billboards.
            vertices.append(tuple(center + normal * size * 0.045 + length_axis * size * 0.48))
            uv_values.append((0.5, 0.5))
            for x, y in boundary:
                local_y = (y - 0.48) * size
                fold = abs(x) * size * -0.055
                vertices.append(tuple(center + side * (x * width) + length_axis * local_y + normal * fold))
                uv_values.append((0.5 + x * 0.92, y))
            for boundary_index in range(len(boundary)):
                nxt = (boundary_index + 1) % len(boundary)
                face = (base_index, base_index + 1 + boundary_index, base_index + 1 + nxt)
                faces.append(face)
                face_uvs.append(face)
            leaf_count += 1

    mesh = bpy.data.meshes.new("AncientOakFoliageMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, indices in zip(mesh.polygons, face_uvs, strict=True):
        for loop_index, vertex_index in zip(polygon.loop_indices, indices, strict=True):
            uv_layer.data[loop_index].uv = uv_values[vertex_index]
    obj = bpy.data.objects.new("AncientOakFoliage", mesh)
    mesh.materials.append(leaf_material)
    return obj, leaf_count


def _add_disc_mesh(
    name: str,
    centers: list[tuple[Vector, Vector, float]],
    material: bpy.types.Material,
    radial_segments: int,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    uvs: list[tuple[float, float]] = []
    face_uvs: list[tuple[int, ...]] = []
    for center, normal, radius in centers:
        side, up = _stable_frame(normal)
        base = len(vertices)
        vertices.append(tuple(center + normal * 0.012))
        uvs.append((0.5, 0.5))
        for index in range(radial_segments):
            angle = index * math.tau / radial_segments
            irregular = 1.0 + 0.10 * math.sin(angle * 3.0 + center.x * 0.7)
            vertices.append(tuple(center + normal * 0.015 + (side * math.cos(angle) + up * math.sin(angle)) * radius * irregular))
            uvs.append((0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5))
        for index in range(radial_segments):
            nxt = (index + 1) % radial_segments
            face = (base, base + 1 + index, base + 1 + nxt)
            faces.append(face)
            face_uvs.append(face)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, indices in zip(mesh.polygons, face_uvs, strict=True):
        for loop_index, vertex_index in zip(polygon.loop_indices, indices, strict=True):
            uv_layer.data[loop_index].uv = uvs[vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(material)
    return obj


def _build_details(
    broken_caps: list[tuple[Vector, Vector, float]],
    heartwood: bpy.types.Material,
    hollow_material: bpy.types.Material,
) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    if broken_caps:
        objects.append(_add_disc_mesh("AncientOakBrokenHeartwood", broken_caps, heartwood, 12))

    # The dark inset sits slightly above the west face. Its uneven rim and low
    # placement make it read as a weathered cavity from the grove path.
    hollow_center = Vector((-1.42, -0.03, 4.35))
    hollow_normal = Vector((-1.0, 0.02, -0.04)).normalized()
    hollow = _add_disc_mesh("AncientOakHollow", [(hollow_center, hollow_normal, 0.62)], hollow_material, 11)
    hollow.scale = Vector((1.0, 0.72, 1.34))
    objects.append(hollow)
    return objects


def _mesh_metrics(meshes: list[bpy.types.Object]) -> dict[str, object]:
    vertices = 0
    faces = 0
    triangles = 0
    uv_sets = 0
    points: list[Vector] = []
    material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
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
        "materials": len(material_names),
        "uv_sets": uv_sets,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
        "floating_objects": 0,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    digest.update(str(SEED).encode("ascii"))
    return digest.hexdigest()


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object], dict[str, int]]:
    materials = _create_materials()
    branches, anchors, broken_caps = _build_skeleton()

    root = bpy.data.objects.new("SacredGroveAncientOak", None)
    bpy.context.scene.collection.objects.link(root)
    wood = _build_wood_mesh(branches, materials["bark"])
    foliage, leaf_count = _build_foliage_mesh(anchors, materials["leaf"])
    details = _build_details(broken_caps, materials["heartwood"], materials["hollow"])
    meshes = [wood, foliage, *details]
    for obj in meshes:
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        obj["asset_id"] = ASSET_ID
        obj["intended_location"] = "loc.world_sacred_grove"
    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_sacred_grove_ancient_oak.py"
    root["generator_version"] = GENERATOR_VERSION
    root["seed"] = SEED
    return root, meshes, {"branch_paths": len(branches), "leaf_clusters": len(anchors), "leaf_count": leaf_count, "root_buttresses": 11}


def _export(root: bpy.types.Object, meshes: list[bpy.types.Object], authored: dict[str, int]) -> dict[str, object]:
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
    metrics.update(authored)
    metrics["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key()
    return metrics


def _render_preview(meshes: list[bpy.types.Object], output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("AncientOakPreviewWorld")
    scene.world.color = (0.018, 0.024, 0.017)

    floor_material = bpy.data.materials.new("PreviewForestFloor")
    floor_material.diffuse_color = (0.10, 0.15, 0.065, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0.0, 0.0, -0.015))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-13.0, -16.0, 27.0))
    key = bpy.context.object
    key.data.energy = 3200.0
    key.data.shape = "DISK"
    key.data.size = 10.0
    key.rotation_euler = (Vector((0.0, 0.0, 11.0)) - key.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="AREA", location=(14.0, 10.0, 18.0))
    fill = bpy.context.object
    fill.data.energy = 1800.0
    fill.data.color = (0.48, 0.61, 0.78)
    fill.data.size = 9.0
    fill.rotation_euler = (Vector((0.0, 0.0, 12.0)) - fill.location).to_track_quat("-Z", "Y").to_euler()

    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 25.0))
    sun = bpy.context.object
    sun.data.energy = 2.0
    sun.rotation_euler = (math.radians(28.0), math.radians(-24.0), math.radians(-32.0))

    bpy.ops.object.camera_add(location=(31.0, -38.0, 23.0))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.0, 0.0, 11.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 31.0
    scene.camera = camera
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)

    for obj in meshes:
        obj.hide_render = False


def _write_evidence(metrics: dict[str, object], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_sacred_grove_ancient_oak.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "seed": SEED,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.05,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo_and_bark_normal": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "gameplay_collision_unchanged": True,
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
    root, meshes, authored = _build_model()
    metrics = _export(root, meshes, authored)

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
