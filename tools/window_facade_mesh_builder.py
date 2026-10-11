"""Mesh construction for the modular window facade Blender generator.

This module owns the facade-specific BMesh primitives and variant assemblies.
Keeping it separate from ``generate_window_facades.py`` leaves that script focused
on materials, export, preview rendering, and production evidence.
"""

from __future__ import annotations

import math

import bmesh
from mathutils import Matrix, Vector

def _mark_new_faces(mesh: bmesh.types.BMesh, previous: set[bmesh.types.BMFace], material_index: int) -> None:
    for face in mesh.faces:
        if face not in previous:
            face.material_index = material_index


def _add_box_matrix(
    mesh: bmesh.types.BMesh,
    transform: Matrix,
    size: tuple[float, float, float],
    material_index: int,
) -> None:
    previous = set(mesh.faces)
    result = bmesh.ops.create_cube(mesh, size=1.0)
    scale = Matrix.Diagonal(Vector((*size, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform @ scale, verts=result["verts"])
    _mark_new_faces(mesh, previous, material_index)


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    *,
    rotation_z_degrees: float = 0.0,
    rotation_y_degrees: float = 0.0,
    parent: Matrix | None = None,
) -> None:
    transform = Matrix.Translation(Vector(center))
    transform @= Matrix.Rotation(math.radians(rotation_z_degrees), 4, "Z")
    transform @= Matrix.Rotation(math.radians(rotation_y_degrees), 4, "Y")
    if parent is not None:
        transform = parent @ transform
    _add_box_matrix(mesh, transform, size, material_index)


def _add_cylinder(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float,
    depth: float,
    material_index: int,
    *,
    segments: int = 8,
) -> None:
    previous = set(mesh.faces)
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=depth,
        matrix=Matrix.Translation(Vector(center)),
    )
    _mark_new_faces(mesh, previous, material_index)


def _add_extruded_polygon(
    mesh: bmesh.types.BMesh,
    points_xz: list[tuple[float, float]],
    depth: float,
    material_index: int,
    *,
    y_center: float = 0.0,
    transform: Matrix | None = None,
) -> None:
    """Add a watertight prism from a simple facade-plane polygon."""
    if len(points_xz) < 3:
        raise ValueError("an extruded polygon needs at least three points")
    matrix = transform if transform is not None else Matrix.Identity(4)
    front: list[bmesh.types.BMVert] = []
    back: list[bmesh.types.BMVert] = []
    for x, z in points_xz:
        front.append(mesh.verts.new(matrix @ Vector((x, y_center - depth * 0.5, z))))
        back.append(mesh.verts.new(matrix @ Vector((x, y_center + depth * 0.5, z))))

    front_face = mesh.faces.new(tuple(reversed(front)))
    front_face.material_index = material_index
    back_face = mesh.faces.new(tuple(back))
    back_face.material_index = material_index
    for index in range(len(points_xz)):
        next_index = (index + 1) % len(points_xz)
        side = mesh.faces.new((front[index], front[next_index], back[next_index], back[index]))
        side.material_index = material_index


def _leaf_transform(hinge_x: float, hinge_y: float, angle_degrees: float) -> Matrix:
    return Matrix.Translation(Vector((hinge_x, hinge_y, 0.0))) @ Matrix.Rotation(
        math.radians(angle_degrees), 4, "Z"
    )


def _add_rectangular_shutter(
    mesh: bmesh.types.BMesh,
    *,
    hinge_x: float,
    side: int,
    angle_degrees: float,
    closed: bool,
) -> None:
    """Build one period boarded leaf; side is +1 for left, -1 for right."""
    width = 0.30
    height = 0.75
    bottom = 0.10
    thickness = 0.045
    gap = 0.006
    transform = _leaf_transform(hinge_x, -0.078, angle_degrees)
    plank_width = (width - gap * 2.0) / 3.0

    for index in range(3):
        distance = plank_width * (index + 0.5) + gap * index
        _add_box(
            mesh,
            (side * distance, 0.0, bottom + height * 0.5),
            (plank_width, thickness, height),
            1,
            parent=transform,
        )

    # Open leaves expose their interior battens; closed leaves expose iron straps.
    for z in (bottom + 0.19, bottom + 0.56):
        _add_box(
            mesh,
            (side * width * 0.5, thickness * 0.72, z),
            (width * 0.88, 0.026, 0.052),
            0,
            parent=transform,
        )
        _add_box(
            mesh,
            (side * width * 0.48, -thickness * 0.74, z),
            (width * 0.78, 0.016, 0.026),
            3,
            parent=transform,
        )

    # Two hinge barrels bridge the leaf and frame. They remain separate readable
    # forms rather than painted lines at the game's architectural camera scale.
    for z in (bottom + 0.19, bottom + 0.56):
        _add_cylinder(mesh, (hinge_x, -0.112, z), 0.018, 0.105, 3, segments=8)

    if closed:
        latch_x = -0.028 if side == 1 else 0.028
        _add_box(mesh, (latch_x, -0.116, bottom + 0.41), (0.085, 0.018, 0.035), 3)


def _add_timber_frame(mesh: bmesh.types.BMesh) -> None:
    outer_width = 0.78
    outer_height = 0.95
    rail = 0.09
    depth = 0.12
    opening_width = 0.60
    opening_height = 0.75
    opening_bottom = 0.10

    _add_box(mesh, (-outer_width * 0.5 + rail * 0.5, -0.060, outer_height * 0.5), (rail, depth, outer_height), 0)
    _add_box(mesh, (outer_width * 0.5 - rail * 0.5, -0.060, outer_height * 0.5), (rail, depth, outer_height), 0)
    _add_box(mesh, (0.0, -0.060, rail * 0.5), (outer_width, depth, rail), 0)
    _add_box(mesh, (0.0, -0.060, outer_height - rail * 0.5), (outer_width, depth, rail), 0)

    # A projecting sill and restrained lintel create a facade-readable silhouette
    # without copying later Gothic display decoration.
    _add_box(mesh, (0.0, -0.095, 0.045), (0.88, 0.19, 0.09), 0)
    _add_box(mesh, (0.0, -0.075, outer_height - 0.045), (0.86, 0.15, 0.10), 0)

    _add_box(
        mesh,
        (0.0, -0.006, opening_bottom + opening_height * 0.5),
        (opening_width - 0.012, 0.014, opening_height - 0.012),
        4,
    )
    _add_box(mesh, (0.0, -0.090, opening_bottom + opening_height * 0.5), (0.045, 0.078, opening_height), 0)
    _add_box(mesh, (0.0, -0.090, opening_bottom + opening_height * 0.5), (opening_width, 0.078, 0.045), 0)


def _build_timber_variant(mesh: bmesh.types.BMesh, closed: bool) -> None:
    _add_timber_frame(mesh)
    if closed:
        _add_rectangular_shutter(mesh, hinge_x=-0.30, side=1, angle_degrees=0.0, closed=True)
        _add_rectangular_shutter(mesh, hinge_x=0.30, side=-1, angle_degrees=0.0, closed=True)
        # The central hasp communicates a securable night state at a glance.
        _add_box(mesh, (0.0, -0.126, 0.50), (0.16, 0.020, 0.042), 3)
        _add_cylinder(mesh, (0.0, -0.142, 0.50), 0.022, 0.022, 3, segments=8)
    else:
        _add_rectangular_shutter(mesh, hinge_x=-0.30, side=1, angle_degrees=168.0, closed=False)
        _add_rectangular_shutter(mesh, hinge_x=0.30, side=-1, angle_degrees=-168.0, closed=False)


def _pointed_opening_points() -> list[tuple[float, float]]:
    width = 0.64
    radius = width
    half = width * 0.5
    spring = 0.72
    bottom = 0.12
    points: list[tuple[float, float]] = [(-half, bottom), (half, bottom), (half, spring)]
    for index in range(1, 7):
        theta = (math.pi / 3.0) * index / 6.0
        points.append((-half + radius * math.cos(theta), spring + radius * math.sin(theta)))
    for index in range(1, 7):
        theta = math.pi * 2.0 / 3.0 + (math.pi / 3.0) * index / 6.0
        points.append((half + radius * math.cos(theta), spring + radius * math.sin(theta)))
    return points


def _add_arch_ring(mesh: bmesh.types.BMesh) -> None:
    width = 0.64
    half = width * 0.5
    spring = 0.72
    inner = width
    outer = width + 0.14
    depth = 0.20
    segments = 7

    _add_box(mesh, (-0.41, -0.10, 0.41), (0.18, depth, 0.82), 2)
    _add_box(mesh, (0.41, -0.10, 0.41), (0.18, depth, 0.82), 2)
    _add_box(mesh, (0.0, -0.125, 0.06), (1.00, 0.25, 0.12), 2)

    arcs = (
        ((half, spring), math.pi, math.pi * 2.0 / 3.0),
        ((-half, spring), 0.0, math.pi / 3.0),
    )
    for (center_x, center_z), theta_start, theta_end in arcs:
        for index in range(segments):
            t0 = theta_start + (theta_end - theta_start) * index / segments
            t1 = theta_start + (theta_end - theta_start) * (index + 1) / segments
            points = [
                (center_x + inner * math.cos(t0), center_z + inner * math.sin(t0)),
                (center_x + outer * math.cos(t0), center_z + outer * math.sin(t0)),
                (center_x + outer * math.cos(t1), center_z + outer * math.sin(t1)),
                (center_x + inner * math.cos(t1), center_z + inner * math.sin(t1)),
            ]
            _add_extruded_polygon(mesh, points, depth, 2, y_center=-0.10)

    apex = spring + math.sin(math.pi / 3.0) * inner
    outer_apex = spring + math.sin(math.pi / 3.0) * outer
    _add_extruded_polygon(
        mesh,
        [(-0.075, apex - 0.012), (0.075, apex - 0.012), (0.0, outer_apex + 0.018)],
        depth + 0.018,
        2,
        y_center=-0.109,
    )


def _add_pointed_shutter(
    mesh: bmesh.types.BMesh,
    *,
    left: bool,
) -> None:
    width = 0.64
    half = width * 0.5
    radius = width
    spring = 0.72
    bottom = 0.12
    apex = spring + math.sin(math.pi / 3.0) * radius
    side = 1.0 if left else -1.0
    hinge_x = -half if left else half
    angle = 168.0 if left else -168.0

    points: list[tuple[float, float]] = [(0.0, bottom), (side * half, bottom), (side * half, apex)]
    if left:
        for index in range(1, 7):
            theta = math.pi * 2.0 / 3.0 + (math.pi / 3.0) * index / 6.0
            global_x = half + radius * math.cos(theta)
            points.append((global_x + half, spring + radius * math.sin(theta)))
    else:
        for index in range(1, 7):
            theta = math.pi / 3.0 - (math.pi / 3.0) * index / 6.0
            global_x = -half + radius * math.cos(theta)
            points.append((global_x - half, spring + radius * math.sin(theta)))

    transform = _leaf_transform(hinge_x, -0.072, angle)
    _add_extruded_polygon(mesh, points, 0.048, 1, transform=transform)

    for z in (bottom + 0.22, bottom + 0.52):
        _add_box(
            mesh,
            (side * half * 0.52, 0.038, z),
            (half * 0.82, 0.028, 0.052),
            0,
            parent=transform,
        )
        _add_box(
            mesh,
            (side * half * 0.49, -0.038, z),
            (half * 0.76, 0.016, 0.026),
            3,
            parent=transform,
        )
        _add_cylinder(mesh, (hinge_x, -0.112, z), 0.018, 0.11, 3, segments=8)


def _build_stone_pointed_variant(mesh: bmesh.types.BMesh) -> None:
    opening = _pointed_opening_points()
    _add_extruded_polygon(mesh, opening, 0.016, 4, y_center=-0.004)
    _add_arch_ring(mesh)
    _add_pointed_shutter(mesh, left=True)
    _add_pointed_shutter(mesh, left=False)


def build_variant(mesh: bmesh.types.BMesh, variant: str) -> None:
    """Populate ``mesh`` with the requested stable facade variant."""
    if variant == "timber_open":
        _build_timber_variant(mesh, closed=False)
    elif variant == "timber_closed":
        _build_timber_variant(mesh, closed=True)
    elif variant == "stone_pointed_open":
        _build_stone_pointed_variant(mesh)
    else:
        raise ValueError(f"unknown facade variant: {variant}")
