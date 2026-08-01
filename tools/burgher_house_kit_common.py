#!/usr/bin/env python3
"""Shared deterministic builders for the 1343 Reval burgher-house kits.

Historical basis: history/dossiers/architecture/burgher-house-plan.md (R-003).
Every builder follows the dossier Brief ship decisions: gable end to street,
ridge perpendicular to the lane, 1343-safe openings (no late-Gothic four-light
crosses or blind niches), loading hatches with hoist beam on merchant tiers,
tile/shingle/thatch roof bands by tier.

Consumed by the per-tier generators:
    tools/generate_burgher_house_merchant_stone.py
    tools/generate_burgher_house_merchant_timber.py
    tools/generate_burgher_house_craft_boda.py

Blender coordinates: X = facade width, Y = plot depth (facade plane at y=0,
front towards -Y), Z = up. glTF export with ``export_yup=True`` maps the
facade to Godot +Z.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

GENERATOR_VERSION = "burgher_house_kit_v1"
BLENDER_VERSION = "Blender 5.2 LTS"

# --- palette (sRGB) -------------------------------------------------------

LIMESTONE_SRGB = (0x8E / 255.0, 0x89 / 255.0, 0x7C / 255.0)
LIMESTONE_DARK_SRGB = (0x6E / 255.0, 0x6A / 255.0, 0x60 / 255.0)
LIMEWASH_SRGB = (0xE4 / 255.0, 0xDD / 255.0, 0xCB / 255.0)
OAK_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
OAK_AGED_SRGB = (0x5E / 255.0, 0x47 / 255.0, 0x33 / 255.0)
SHUTTER_SRGB = (0x4E / 255.0, 0x3B / 255.0, 0x2B / 255.0)
TILE_SRGB = (0x9C / 255.0, 0x4A / 255.0, 0x2E / 255.0)
SHINGLE_SRGB = (0x3D / 255.0, 0x33 / 255.0, 0x2B / 255.0)
THATCH_SRGB = (0x8A / 255.0, 0x6F / 255.0, 0x42 / 255.0)
IRON_SRGB = (0x3A / 255.0, 0x3E / 255.0, 0x42 / 255.0)
RECESS_SRGB = (0x1A / 255.0, 0x14 / 255.0, 0x10 / 255.0)
ROPE_SRGB = (0x9A / 255.0, 0x86 / 255.0, 0x60 / 255.0)

ROOF_PITCH_DEG = 48.0  # dossier: steep vernacular pitch (~45 deg analogy)


def srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


# --- procedural 512 px albedos (deterministic, packed into the GLB) -------


def create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if surface == "limestone":
        # Coursed ashlar: horizontal beds, per-row staggered vertical joints.
        row = np.floor(v * 9.0)
        bed = np.abs(np.sin(v * 9.0 * math.pi))
        joint_u = u * 5.0 + (row % 2.0) * 0.5
        joint = np.abs(np.sin(joint_u * math.pi))
        mortar = np.clip(1.0 - bed * 14.0, 0.0, 1.0) + np.clip(1.0 - joint * 22.0, 0.0, 1.0)
        grain = np.sin((u * 23.0 + v * 17.0) * math.tau) * np.sin((v * 29.0 - u * 7.0) * math.tau)
        variation = 0.86 + grain * 0.05 - np.clip(mortar, 0.0, 1.0) * 0.16
    elif surface == "limewash":
        mottle = np.sin((u * 6.0 + v * 4.0) * math.tau) * np.sin((v * 9.0 - u * 3.0) * math.tau)
        streak = np.sin((u * 41.0) * math.tau + np.sin(v * math.tau * 3.0))
        variation = 0.94 + mottle * 0.035 + streak * 0.012
    elif surface == "oak":
        warped = v + 0.018 * np.sin(u * math.tau * 3.0) + 0.007 * np.sin(u * math.tau * 11.0)
        broad = np.sin((warped * 9.0 + u * 0.45) * math.tau)
        fine = np.sin((warped * 31.0 - u * 0.8) * math.tau)
        boards = np.abs(np.sin(u * 6.0 * math.pi))
        variation = 0.82 + broad * 0.06 + fine * 0.02 - np.clip(1.0 - boards * 18.0, 0.0, 1.0) * 0.18
    elif surface == "shutter":
        warped = v + 0.012 * np.sin(u * math.tau * 5.0)
        grain = np.sin((warped * 17.0 + u * 0.6) * math.tau)
        boards = np.abs(np.sin(u * 4.0 * math.pi))
        weather = np.sin((u * 3.0 + v * 5.0) * math.tau)
        variation = 0.78 + grain * 0.05 + weather * 0.04 - np.clip(1.0 - boards * 16.0, 0.0, 1.0) * 0.16
    elif surface == "tile":
        row = np.floor(v * 14.0)
        tile_u = u * 12.0 + (row % 2.0) * 0.5
        bed = np.abs(np.sin(v * 14.0 * math.pi))
        joint = np.abs(np.sin(tile_u * math.pi))
        tone = np.sin((row * 0.7 + np.floor(tile_u) * 1.3) * 2.399)
        variation = 0.85 + tone * 0.09 - np.clip(1.0 - bed * 10.0, 0.0, 1.0) * 0.22 \
            - np.clip(1.0 - joint * 26.0, 0.0, 1.0) * 0.10
    elif surface == "shingle":
        row = np.floor(v * 11.0)
        shingle_u = u * 9.0 + (row % 2.0) * 0.5
        bed = np.abs(np.sin(v * 11.0 * math.pi))
        joint = np.abs(np.sin(shingle_u * math.pi))
        tone = np.sin((row * 1.1 + np.floor(shingle_u) * 2.1) * 1.7)
        variation = 0.80 + tone * 0.08 - np.clip(1.0 - bed * 8.0, 0.0, 1.0) * 0.20 \
            - np.clip(1.0 - joint * 20.0, 0.0, 1.0) * 0.12
    elif surface == "thatch":
        streaks = np.sin((u * 60.0 + np.sin(v * math.tau * 2.0) * 2.2) * math.tau)
        layers = np.sin(v * 7.0 * math.tau)
        variation = 0.84 + streaks * 0.05 + layers * 0.06
    elif surface == "iron":
        hammer = np.sin((u * 17.0 + v * 5.0) * math.tau) * np.sin((v * 13.0 - u * 4.0) * math.tau)
        variation = 0.74 + hammer * 0.05
    elif surface == "rope":
        twist = np.sin((u * 24.0 + v * 6.0) * math.tau)
        variation = 0.85 + twist * 0.08
    else:  # recess - deep shadow inside openings
        variation = np.full_like(u, 0.9)
    base_linear = np.array([srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    pixels = np.concatenate((rgb, np.ones((size, size, 1), dtype=np.float32)), axis=2)
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image


def create_material(
    name: str,
    srgb: tuple[float, float, float],
    surface: str,
    roughness: float = 0.9,
    metallic: float = 0.0,
    textured: bool = True,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*(srgb_to_linear(value) for value in srgb), 1.0)
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if textured:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = create_texture(f"{name}_albedo", srgb, surface)
        texture.interpolation = "Linear"
        material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def standard_materials(prefix: str) -> dict[str, bpy.types.Material]:
    """One shared material set per kit so variant GLBs stay visually consistent."""
    return {
        "limestone": create_material(f"{prefix}Limestone", LIMESTONE_SRGB, "limestone", 0.95),
        "limestone_dark": create_material(f"{prefix}LimestoneDark", LIMESTONE_DARK_SRGB, "limestone", 0.95),
        "limewash": create_material(f"{prefix}Limewash", LIMEWASH_SRGB, "limewash", 0.92),
        "oak": create_material(f"{prefix}Oak", OAK_SRGB, "oak", 0.85),
        "oak_aged": create_material(f"{prefix}OakAged", OAK_AGED_SRGB, "oak", 0.88),
        "shutter": create_material(f"{prefix}ShutterOak", SHUTTER_SRGB, "shutter", 0.9),
        "tile": create_material(f"{prefix}ClayTile", TILE_SRGB, "tile", 0.82),
        "shingle": create_material(f"{prefix}WoodShingle", SHINGLE_SRGB, "shingle", 0.9),
        "thatch": create_material(f"{prefix}Thatch", THATCH_SRGB, "thatch", 0.95),
        "iron": create_material(f"{prefix}WroughtIron", IRON_SRGB, "iron", 0.55, 0.65),
        "recess": create_material(f"{prefix}Recess", RECESS_SRGB, "recess", 1.0),
        "rope": create_material(f"{prefix}Rope", ROPE_SRGB, "rope", 0.95),
    }


# --- geometry helpers ------------------------------------------------------


def box(
    name: str,
    size: tuple[float, float, float],
    transform: Matrix,
    material: bpy.types.Material,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.matrix_world = transform
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft worn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def cylinder(
    name: str,
    radius: float,
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    obj = bpy.context.object
    obj.name = name
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


def at(x: float, y: float, z: float) -> Matrix:
    return Matrix.Translation((x, y, z))


def rot_y(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "Y")


def rot_x(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "X")


def rot_z(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "Z")


def _extrude_profile(
    name: str,
    outline: list[tuple[float, float]],
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Extrude a 2D XZ outline along Y by ``depth`` (front face at y=0)."""
    count = len(outline)
    verts: list[tuple[float, float, float]] = []
    for y in (0.0, -depth):
        for x, z in outline:
            verts.append((x, y, z))
    faces: list[tuple[int, ...]] = []
    faces.append(tuple(range(count - 1, -1, -1)))
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


def gable_infill(
    name: str,
    width: float,
    base_z: float,
    ridge_z: float,
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Triangular gable wall closing the roof void on the street/rear face."""
    half = width * 0.5
    outline = [(-half, base_z), (half, base_z), (0.0, ridge_z)]
    return _extrude_profile(name, outline, depth, transform, material)


def _pointed_arch_outline(
    width: float,
    spring_z: float,
    apex_z: float,
    segments: int = 7,
) -> list[tuple[float, float]]:
    """Pointed (Gothic) arch: two circular arcs meeting in a cusp at the apex."""
    half = width * 0.5
    rise = apex_z - spring_z
    # Arc centre sits on the spring line, outside the opening (cusp at apex).
    centre_x = (half * half - rise * rise) / (2.0 * half) if half > 0.0 else 0.0
    radius = math.hypot(half - centre_x, 0.0)
    apex_angle = math.atan2(rise, 0.0 - centre_x)
    right: list[tuple[float, float]] = []
    for index in range(segments + 1):
        t = float(index) / float(segments)
        angle = apex_angle * t
        right.append((centre_x + radius * math.cos(angle), spring_z + radius * math.sin(angle)))
    left = [(-x, z) for x, z in reversed(right[:-1])]
    return right + left


def pointed_arch_ring(
    name: str,
    width: float,
    spring_z: float,
    apex_z: float,
    frame: float,
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Flat arch ring (voussoir band) around a pointed-arch portal/window."""
    inner = _pointed_arch_outline(width, spring_z, apex_z)
    # Offset the outline outward along averaged 2D normals for the outer band.
    outer: list[tuple[float, float]] = []
    count = len(inner)
    for index, (x, z) in enumerate(inner):
        prev_p = inner[(index - 1) % count]
        next_p = inner[(index + 1) % count]
        dx = next_p[0] - prev_p[0]
        dz = next_p[1] - prev_p[1]
        length = math.hypot(dx, dz)
        if length < 1e-6:
            normal = (0.0, 1.0)
        else:
            # Arch outline runs counter-clockwise up the right side; outward
            # is to the right of travel on the way up and left on the way down,
            # so pick the normal pointing away from the opening centroid.
            candidate = (dz / length, -dx / length)
            centroid = (0.0, (spring_z + apex_z) * 0.5)
            to_point = (x - centroid[0], z - centroid[1])
            if candidate[0] * to_point[0] + candidate[1] * to_point[1] < 0.0:
                candidate = (-candidate[0], -candidate[1])
            normal = candidate
        outer.append((x + normal[0] * frame, z + normal[1] * frame))
    ring_outline = inner + list(reversed(outer))
    verts: list[tuple[float, float, float]] = []
    ring_count = len(ring_outline)
    for y in (0.0, -depth):
        for x, z in ring_outline:
            verts.append((x, y, z))
    faces: list[tuple[int, ...]] = []
    faces.append(tuple(range(ring_count - 1, -1, -1)))
    faces.append(tuple(range(ring_count, ring_count * 2)))
    for index in range(ring_count):
        nxt = (index + 1) % ring_count
        faces.append((index, nxt, ring_count + nxt, ring_count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


# --- architectural components ----------------------------------------------


def add_roof(
    objects: list[bpy.types.Object],
    width: float,
    depth: float,
    wall_h: float,
    ridge_h: float,
    material: bpy.types.Material,
    overhang: float = 0.45,
    thickness: float = 0.14,
) -> None:
    """Two sloped slabs, ridge along the plot depth (gable ends to the lane)."""
    run = width * 0.5 + overhang
    eave_z = wall_h - overhang * 0.35
    rise = ridge_h - eave_z
    slope_len = math.hypot(run, rise)
    angle = math.atan2(rise, run)
    slab_len = slope_len + 0.15
    for side, sign in (("L", 1.0), ("R", -1.0)):
        center_x = sign * run * 0.5
        center_z = (ridge_h + eave_z) * 0.5
        transform = at(center_x, depth * 0.5, center_z) @ rot_y(sign * angle)
        objects.append(box(f"RoofSlab{side}", (slab_len, depth + overhang * 2.0, thickness), transform, material))
    # Ridge cap: narrow inverted-V pair along the ridge line.
    cap_angle = math.radians(38.0)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        transform = at(sign * 0.10, depth * 0.5, ridge_h + 0.05) @ rot_y(sign * cap_angle)
        objects.append(box(f"RidgeCap{side}", (0.30, depth + overhang * 2.0, 0.07), transform, material))


def add_portal(
    objects: list[bpy.types.Object],
    x_center: float,
    door_w: float,
    door_h: float,
    stone: bpy.types.Material,
    door_material: bpy.types.Material,
    recess: bpy.types.Material,
    steps: int = 3,
) -> None:
    """Street portal: pointed arch ring, jambs, recessed plank door, steps."""
    spring_z = door_h * 0.68
    jamb_w = 0.22
    for side, sign in (("JambL", -1.0), ("JambR", 1.0)):
        objects.append(
            box(
                f"Portal{side}",
                (jamb_w, 0.30, spring_z),
                at(x_center + sign * (door_w * 0.5 + jamb_w * 0.5), -0.10, spring_z * 0.5),
                stone,
                0.02,
            )
        )
    objects.append(
        pointed_arch_ring(
            "PortalArch",
            door_w + jamb_w * 2.0,
            spring_z,
            door_h + 0.18,
            0.20,
            0.30,
            at(x_center, -0.10, 0.0),
            stone,
        )
    )
    # Dark reveal + plank door leaf just proud of the facade plane.
    objects.append(box("PortalRecess", (door_w, 0.10, door_h), at(x_center, 0.02, door_h * 0.5), recess))
    objects.append(
        box("PortalDoor", (door_w - 0.14, 0.07, door_h - 0.10), at(x_center, -0.06, (door_h - 0.10) * 0.5), door_material, 0.015)
    )
    # Cellar-neck steps down to the lane (dossier: raised threshold).
    step_h = 0.16
    for index in range(steps):
        tread = 0.34
        objects.append(
            box(
                f"PortalStep{index}",
                (door_w + 0.5, tread, step_h),
                at(x_center, -0.25 - index * (tread - 0.06), step_h * (steps - index) - step_h * 0.5),
                stone,
                0.015,
            )
        )


def add_window(
    objects: list[bpy.types.Object],
    name: str,
    x_center: float,
    z_center: float,
    width: float,
    height: float,
    frame_material: bpy.types.Material,
    shutter_material: bpy.types.Material,
    recess: bpy.types.Material,
    shutters: str = "closed",
    y_face: float = 0.0,
) -> None:
    """Recessed opening with frame and shutters; hatches are always closed."""
    objects.append(box(f"{name}Recess", (width, 0.09, height), at(x_center, y_face + 0.02, z_center), recess))
    frame_t = 0.10
    for side, sign, sx, sz in (
        ("L", -1.0, frame_t, height + frame_t * 2.0),
        ("R", 1.0, frame_t, height + frame_t * 2.0),
    ):
        objects.append(
            box(
                f"{name}Frame{side}",
                (sx, 0.14, sz),
                at(x_center + sign * (width * 0.5 + frame_t * 0.5), y_face - 0.05, z_center),
                frame_material,
                0.012,
            )
        )
    for side, sign, sy, sz in (
        ("T", 1.0, 0.14, frame_t),
        ("B", -1.0, 0.14, frame_t),
    ):
        objects.append(
            box(
                f"{name}Frame{side}",
                (width + frame_t * 2.0, sy, sz),
                at(x_center, y_face - 0.05, z_center + sign * (height * 0.5 + frame_t * 0.5)),
                frame_material,
                0.012,
            )
        )
    leaf_w = width * 0.5
    if shutters == "closed":
        for side, sign in (("L", -1.0), ("R", 1.0)):
            objects.append(
                box(
                    f"{name}Shutter{side}",
                    (leaf_w - 0.02, 0.05, height - 0.04),
                    at(x_center + sign * leaf_w * 0.5, y_face - 0.045, z_center),
                    shutter_material,
                    0.01,
                )
            )
    elif shutters == "open":
        for side, sign in (("L", -1.0), ("R", 1.0)):
            hinge_x = x_center + sign * (width * 0.5 + frame_t * 0.5)
            # Folded flat back against the facade beside the opening.
            objects.append(
                box(
                    f"{name}Shutter{side}",
                    (leaf_w - 0.02, 0.05, height - 0.04),
                    at(hinge_x + sign * leaf_w * 0.5, y_face - 0.10, z_center),
                    shutter_material,
                    0.01,
                )
            )


def add_loading_hatches(
    objects: list[bpy.types.Object],
    x_center: float,
    storeys_above_ground: int,
    storey_h: float,
    frame_material: bpy.types.Material,
    shutter_material: bpy.types.Material,
    recess: bpy.types.Material,
    iron: bpy.types.Material,
) -> None:
    """Stacked shuttered loading hatches on the storage floors (hatch rhythm)."""
    for level in range(storeys_above_ground):
        z_center = storey_h * (level + 1) + storey_h * 0.52
        name = f"Hatch{level + 1}"
        add_window(
            objects,
            name,
            x_center,
            z_center,
            0.95,
            1.15,
            frame_material,
            shutter_material,
            recess,
            shutters="closed",
        )
        # Wrought-iron hinge straps read as the dossier's hoist hardware.
        for side, sign in (("Top", 1.0), ("Bottom", -1.0)):
            objects.append(
                box(
                    f"{name}Hinge{side}",
                    (0.62, 0.03, 0.05),
                    at(x_center, -0.085, z_center + sign * 0.38),
                    iron,
                )
            )


def add_hoist_beam(
    objects: list[bpy.types.Object],
    x_center: float,
    z_base: float,
    beam_material: bpy.types.Material,
    iron: bpy.types.Material,
    rope: bpy.types.Material,
    protrude: float = 1.55,
) -> None:
    """Protruding wooden hoisting beam with brace, rope, and hook."""
    embed = 0.45
    beam_len = protrude + embed
    objects.append(
        box(
            "HoistBeam",
            (0.18, beam_len, 0.22),
            at(x_center, protrude - beam_len * 0.5, z_base + 0.11),
            beam_material,
            0.02,
        )
    )
    # Diagonal brace from facade to beam tip.
    brace_run = protrude - 0.25
    brace_rise = 0.95
    brace_len = math.hypot(brace_run, brace_rise)
    angle = math.atan2(brace_rise, brace_run)
    transform = at(x_center, -(brace_run * 0.5) - 0.05, z_base - brace_rise * 0.5 + 0.05) @ rot_x(angle)
    objects.append(box("HoistBrace", (0.12, brace_len, 0.12), transform, beam_material, 0.015))
    # Rope and iron hook below the beam tip.
    tip_y = -protrude + 0.12
    objects.append(
        cylinder("HoistRope", 0.022, 1.35, at(x_center, tip_y, z_base - 0.62), rope, 6)
    )
    objects.append(
        box("HoistHook", (0.07, 0.07, 0.22), at(x_center, tip_y, z_base - 1.38), iron, 0.02)
    )


def add_chimney(
    objects: list[bpy.types.Object],
    y_pos: float,
    ridge_h: float,
    stone: bpy.types.Material,
) -> None:
    objects.append(
        box("Chimney", (0.55, 0.55, 1.5), at(0.0, y_pos, ridge_h + 0.45), stone, 0.02)
    )
    objects.append(
        box("ChimneyCap", (0.78, 0.78, 0.12), at(0.0, y_pos, ridge_h + 1.24), stone, 0.015)
    )


def add_weathervane(objects: list[bpy.types.Object], ridge_h: float, iron: bpy.types.Material) -> None:
    """Simple rod + arrow + pennant at the street gable apex."""
    objects.append(cylinder("VaneRod", 0.02, 1.0, at(0.0, 0.12, ridge_h + 0.55), iron, 6))
    objects.append(box("VaneArrow", (0.06, 0.55, 0.05), at(0.0, 0.0, ridge_h + 0.86), iron, 0.008))
    fin = _extrude_profile(
        "VaneFin",
        [(0.0, 0.0), (0.30, 0.10), (0.0, 0.20)],
        0.02,
        at(0.0, 0.28, ridge_h + 0.76) @ rot_x(math.radians(90.0)),
        iron,
    )
    objects.append(fin)
    pennant = _extrude_profile(
        "VanePennant",
        [(0.0, 0.0), (0.42, 0.05), (0.0, 0.12)],
        0.015,
        at(0.03, 0.12, ridge_h + 0.95) @ rot_y(math.radians(-90.0)),
        iron,
    )
    objects.append(pennant)


def add_anchor_plates(
    objects: list[bpy.types.Object],
    width: float,
    storey_h: float,
    count: int,
    iron: bpy.types.Material,
) -> None:
    """Crossed wall-tie anchor plates (X irons) on the street facade."""
    for index in range(count):
        x = -width * 0.5 + (index + 1.0) * width / (count + 1.0)
        z = storey_h * 0.92
        for arm, sign in (("A", 1.0), ("B", -1.0)):
            plate = box(
                f"Anchor{index}{arm}",
                (0.30, 0.03, 0.055),
                at(x, -0.045, z),
                iron,
            )
            plate.rotation_euler.y = sign * math.radians(38.0)
            objects.append(plate)


def add_quoins(
    objects: list[bpy.types.Object],
    width: float,
    wall_h: float,
    depth: float,
    stone: bpy.types.Material,
) -> None:
    """Alternating limestone quoin blocks on the front corners."""
    course_h = 0.42
    courses = int(wall_h / course_h)
    for level in range(courses):
        z = course_h * (level + 0.5)
        long = 0.42 if level % 2 == 0 else 0.30
        for side, sign in (("L", -1.0), ("R", 1.0)):
            objects.append(
                box(
                    f"Quoin{level}{side}",
                    (long, 0.34, course_h - 0.05),
                    at(sign * (width * 0.5 - long * 0.5 + 0.04), -0.05, z),
                    stone,
                    0.015,
                )
            )


def add_timber_frame(
    objects: list[bpy.types.Object],
    width: float,
    wall_h: float,
    storey_h: float,
    timber: bpy.types.Material,
    spacing: float = 1.35,
) -> None:
    """Structural posts and floor beams on a timber facade (1343-safe: no
    decorative late-medieval Fachwerk patterns, just frame rhythm)."""
    post_count = max(2, int(width / spacing))
    for index in range(post_count + 1):
        x = -width * 0.5 + index * (width / post_count)
        objects.append(
            box(
                f"Post{index}",
                (0.14, 0.16, wall_h),
                at(x, -0.045, wall_h * 0.5),
                timber,
                0.012,
            )
        )
    levels = int(round(wall_h / storey_h))
    for level in range(1, levels + 1):
        objects.append(
            box(
                f"Beam{level}",
                (width + 0.06, 0.15, 0.16),
                at(0.0, -0.05, storey_h * level),
                timber,
                0.012,
            )
        )


def add_terrace(
    objects: list[bpy.types.Object],
    x_center: float,
    width: float,
    stone: bpy.types.Material,
    height: float = 0.48,
) -> None:
    """Raised cellar-neck terrace before the portal with front steps."""
    objects.append(
        box("Terrace", (width, 1.5, height), at(x_center, -0.85, height * 0.5), stone, 0.02)
    )
    steps = 3
    step_h = height / steps
    for index in range(steps):
        objects.append(
            box(
                f"TerraceStep{index}",
                (min(width, 1.6), 0.30, step_h),
                at(x_center, -1.75 - index * 0.24, step_h * (steps - index) - step_h * 0.5),
                stone,
                0.012,
            )
        )


# --- house assembly ---------------------------------------------------------


def build_house(spec: dict[str, object], materials: dict[str, bpy.types.Material]) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Assemble one deterministic burgher house from a tier spec.

    Required spec keys: name, width, depth, storeys. Optional flags select the
    wall/roof materials and the R-003 feature set (portal, hatches, hoist,
    terrace, quoins, anchors, timber frame, weathervane, chimney).
    """
    name = str(spec["name"])
    width = float(spec["width"])
    depth = float(spec["depth"])
    storeys = int(spec["storeys"])
    storey_h = float(spec.get("storey_h", 3.0))
    wall_h = storey_h * storeys
    ridge_h = wall_h + (width * 0.5) * math.tan(math.radians(ROOF_PITCH_DEG))

    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    objects: list[bpy.types.Object] = []

    wall_material = materials[str(spec.get("wall", "limestone"))]
    trim_material = materials[str(spec.get("trim", "limestone_dark"))]
    roof_material = materials[str(spec.get("roof", "tile"))]
    door_material = materials[str(spec.get("door", "oak_aged"))]
    recess = materials["recess"]

    stone_base_h = float(spec.get("stone_base_h", 0.0))
    if stone_base_h > 0.0:
        # Stone cellar ground floor under a timber front (dossier: mixed plots).
        objects.append(
            box("StoneBase", (width, depth, stone_base_h), at(0.0, depth * 0.5, stone_base_h * 0.5), materials["limestone"], 0.03)
        )
        objects.append(
            box(
                "Walls",
                (width, depth, wall_h - stone_base_h),
                at(0.0, depth * 0.5, stone_base_h + (wall_h - stone_base_h) * 0.5),
                wall_material,
                0.025,
            )
        )
    else:
        objects.append(box("Walls", (width, depth, wall_h), at(0.0, depth * 0.5, wall_h * 0.5), wall_material, 0.03))

    # Gable infills close the roof void on street and rear faces.
    gable_wall = materials[str(spec.get("gable_wall", spec.get("wall", "limestone")))]
    objects.append(gable_infill("GableFront", width, wall_h, ridge_h, 0.32, at(0.0, 0.02, 0.0), gable_wall))
    objects.append(gable_infill("GableRear", width, wall_h, ridge_h, 0.32, at(0.0, depth - 0.02, 0.0), gable_wall))
    add_roof(objects, width, depth, wall_h, ridge_h, roof_material, overhang=float(spec.get("overhang", 0.45)))

    portal_x = float(spec.get("portal_x", -width * 0.22))
    door_h = float(spec.get("door_h", 2.3))
    if spec.get("terrace", False):
        add_terrace(objects, portal_x, min(width * 0.62, 3.4), trim_material)
    add_portal(
        objects,
        portal_x,
        float(spec.get("door_w", 1.25)),
        door_h,
        trim_material,
        door_material,
        recess,
        steps=int(spec.get("portal_steps", 3)),
    )

    if spec.get("ground_window", True):
        # Large rectangular diele opening beside the portal (affluent fronts).
        add_window(
            objects,
            "GroundWindow",
            float(spec.get("ground_window_x", width * 0.24)),
            door_h * 0.52,
            float(spec.get("ground_window_w", 1.35)),
            float(spec.get("ground_window_h", 1.30)),
            trim_material,
            materials["shutter"],
            recess,
            shutters=str(spec.get("ground_window_shutters", "open")),
        )

    hatch_storeys = int(spec.get("hatch_storeys", storeys - 1))
    if hatch_storeys > 0:
        add_loading_hatches(
            objects,
            float(spec.get("hatch_x", 0.0)),
            hatch_storeys,
            storey_h,
            trim_material,
            materials["shutter"],
            recess,
            materials["iron"],
        )

    if spec.get("upper_window", False):
        # Plain small shuttered upper opening (craft tier; not a loading hatch).
        add_window(
            objects,
            "UpperWindow",
            float(spec.get("upper_window_x", 0.0)),
            storey_h * 1.55,
            0.70,
            0.80,
            trim_material,
            materials["shutter"],
            recess,
            shutters="closed",
        )

    if spec.get("hoist", False):
        add_hoist_beam(
            objects,
            float(spec.get("hatch_x", 0.0)),
            wall_h + (ridge_h - wall_h) * 0.30,
            materials["oak_aged"],
            materials["iron"],
            materials["rope"],
        )

    if spec.get("gable_vent", True):
        # Small shuttered vent high in the gable (attic bulk-storage airflow).
        vent_z = wall_h + (ridge_h - wall_h) * 0.62
        add_window(
            objects,
            "GableVent",
            float(spec.get("vent_x", width * 0.20)),
            vent_z,
            0.42,
            0.5,
            trim_material,
            materials["shutter"],
            recess,
            shutters="closed",
        )

    if spec.get("quoins", False):
        add_quoins(objects, width, wall_h, depth, trim_material)
    if spec.get("anchor_plates", False):
        add_anchor_plates(objects, width, storey_h, int(spec.get("anchor_count", 3)), materials["iron"])
    if spec.get("timber_frame", False):
        add_timber_frame(objects, width, wall_h, storey_h, materials["oak"])
    if spec.get("chimney", True):
        add_chimney(objects, depth * 0.68, ridge_h, materials[str(spec.get("chimney_mat", "limestone_dark"))])
    if spec.get("weathervane", False):
        add_weathervane(objects, ridge_h, materials["iron"])

    for obj in objects:
        obj.parent = root
    return root, objects


# --- export, metrics, evidence ----------------------------------------------


def mesh_metrics(objects: list[bpy.types.Object], asset_id: str) -> dict[str, object]:
    triangles = 0
    surfaces = 0
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        surfaces += len(mesh.materials)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_v = Vector(map(min, min_v, world))
            max_v = Vector(map(max, max_v, world))
    dims = max_v - min_v
    return {
        "asset_id": asset_id,
        "triangles": triangles,
        "surfaces": surfaces,
        "dimensions_m": [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)],
        "checks": {
            "triangles_in_budget": 400 <= triangles <= 9000,
            "non_empty": triangles > 0 and dims.x > 0.0 and dims.z > 0.0,
            "grounded": min_v.z > -0.05,
        },
    }


def export_glb(root: bpy.types.Object, objects: list[bpy.types.Object], output: Path, asset_id: str) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
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
    metrics = mesh_metrics(objects, asset_id)
    metrics["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    return metrics


def write_evidence(evidence_dir: Path, brief: dict[str, object], reports: dict[str, object]) -> None:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / "brief.json").write_text(json.dumps(brief, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report = {
        "generator": GENERATOR_VERSION,
        "blender": BLENDER_VERSION,
        "historical_basis": "history/dossiers/architecture/burgher-house-plan.md",
        "assets": reports,
    }
    (evidence_dir / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (evidence_dir / "state.json").write_text(
        json.dumps(
            {
                "outputs": {asset_id: reports[asset_id]["sha256"] for asset_id in reports},
                "complete": all(all(metrics["checks"].values()) for metrics in reports.values()),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


# --- reference plates (A-008 evidence, non-runtime) --------------------------


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def render_plate(
    spec: dict[str, object],
    materials: dict[str, bpy.types.Material],
    output: Path,
    view: str,
) -> None:
    """Render one EEVEE evidence plate for a variant (street gable or rear)."""
    _clear_scene()
    root, objects = build_house(spec, materials)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PlateWorld") if scene.world is None else scene.world
    scene.world.color = (0.05, 0.055, 0.065)

    depth = float(spec["depth"])
    width = float(spec["width"])
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0.0, depth * 0.5, -0.02))
    floor = bpy.context.object
    floor_mat = bpy.data.materials.new("PlateFloor")
    floor_mat.diffuse_color = (0.16, 0.14, 0.12, 1.0)
    floor.data.materials.append(floor_mat)

    bpy.ops.object.light_add(type="SUN", location=(-6.0, -8.0, 12.0))
    sun = bpy.context.object
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(38.0), 0.0, math.radians(-32.0))
    bpy.ops.object.light_add(type="AREA", location=(7.0, -2.0, 6.0))
    fill = bpy.context.object
    fill.data.energy = 700.0
    fill.data.color = (0.55, 0.65, 0.85)
    fill.data.size = 5.0

    if view == "street":
        cam_pos = (width * 1.15, -depth * 1.05, 6.2)
        target = Vector((0.0, depth * 0.30, 4.2))
    else:  # rear three-quarter
        cam_pos = (-width * 1.2, depth * 1.85, 6.8)
        target = Vector((0.0, depth * 0.55, 3.6))
    bpy.ops.object.camera_add(location=cam_pos)
    camera = bpy.context.object
    direction = target - Vector(cam_pos)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    # Plates only document geometry; remove plate-only scene objects so the
    # next variant starts clean (materials/textures are shared and kept).
    bpy.data.objects.remove(root)
    for obj in objects:
        try:
            bpy.data.objects.remove(obj)
        except Exception:
            pass
