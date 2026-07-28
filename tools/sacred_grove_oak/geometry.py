"""Procedural branch, wood, foliage, and detail meshes for the ancient oak."""

from __future__ import annotations

import math
import random
from dataclasses import dataclass

import bpy
from mathutils import Vector

@dataclass
class Branch:
    points: list[Vector]
    radii: list[float]
    radial_segments: int
    depth: int
    leaf_density: float = 0.0
    broken: bool = False

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


def build_skeleton(seed: int) -> tuple[list[Branch], list[Vector], list[tuple[Vector, Vector, float]]]:
    rng = random.Random(seed)
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


def build_wood_mesh(branches: list[Branch], bark: bpy.types.Material) -> bpy.types.Object:
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


def build_foliage_mesh(
    anchors: list[Vector], leaf_material: bpy.types.Material, seed: int
) -> tuple[bpy.types.Object, int]:
    rng = random.Random(seed + 77)
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


def build_details(
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
