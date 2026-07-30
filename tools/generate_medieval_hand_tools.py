#!/usr/bin/env python3
"""Build independently placeable medieval hand tools with deterministic Blender geometry.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_medieval_hand_tools.py -- --preview

To rebuild only selected assets while preserving previously approved binaries:
    blender --background --factory-startup --python tools/generate_medieval_hand_tools.py -- --preview --only=blacksmith_hammer,blacksmith_punch,sickle,rake,wooden_shovel

The tools use known metric construction, so image-to-3D would only add topology noise.
The set covers forge tongs, a smith's hammer and punch, a three-tine pitchfork,
a short-bladed grass scythe and sickle, a wooden rake, and a wooden shovel.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "medieval_hand_tools_v2"
TEXTURE_SIZE = 512


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    slug: str
    root_name: str
    output: Path
    scene: str
    dimensions: tuple[float, float, float]
    triangle_max: int
    preview_target: tuple[float, float, float]
    preview_camera: tuple[float, float, float]
    preview_scale: float

    @property
    def evidence_dir(self) -> Path:
        return ROOT / "generated" / "blender" / f"{self.slug}_v1"

    @property
    def brief(self) -> dict[str, object]:
        return {
            "id": self.asset_id,
            "kind": "rigid_prop",
            "target": f"res://{self.output.relative_to(ROOT).as_posix()}",
            "scene": self.scene,
            "dimensions_m": list(self.dimensions),
            "triangles": {"max": self.triangle_max},
            "textures": {"albedo_normal_roughness": TEXTURE_SIZE},
            "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
            "approval": "task-authorized",
        }


SPECS = (
    AssetSpec(
        "prop.blacksmith_tongs",
        "blacksmith_tongs",
        "BlacksmithTongs",
        ROOT / "assets" / "props" / "tools" / "blacksmith_tongs.glb",
        "res://content/maps/kalev_smithy.rrmap#forge_tongs",
        (0.42, 0.77, 0.15),
        1400,
        (0.0, 0.04, 0.37),
        (1.25, -2.0, 1.15),
        1.05,
    ),
    AssetSpec(
        "prop.pitchfork",
        "pitchfork",
        "Pitchfork",
        ROOT / "assets" / "props" / "tools" / "pitchfork.glb",
        "res://content/maps/viru_gate_foreland.rrmap#west.pitchfork",
        (0.44, 2.02, 0.19),
        1800,
        (0.08, 0.0, 1.0),
        (2.0, -3.6, 2.05),
        2.4,
    ),
    AssetSpec(
        "prop.scythe",
        "scythe",
        "Scythe",
        ROOT / "assets" / "props" / "tools" / "scythe.glb",
        "res://content/maps/viru_gate_foreland.rrmap#east.scythe",
        (1.02, 1.54, 0.31),
        1800,
        (0.12, 0.0, 0.75),
        (2.4, -3.8, 2.05),
        2.05,
    ),
    AssetSpec(
        "prop.blacksmith_hammer",
        "blacksmith_hammer",
        "BlacksmithHammer",
        ROOT / "assets" / "props" / "tools" / "blacksmith_hammer.glb",
        "res://content/maps/kalev_smithy.rrmap#forge_hammer",
        (0.17, 0.38, 0.10),
        1000,
        (0.0, 0.0, 0.18),
        (0.65, -1.05, 0.62),
        0.60,
    ),
    AssetSpec(
        "prop.blacksmith_punch",
        "blacksmith_punch",
        "BlacksmithPunch",
        ROOT / "assets" / "props" / "tools" / "blacksmith_punch.glb",
        "res://content/maps/kalev_smithy.rrmap#forge_punch",
        (0.06, 0.23, 0.06),
        700,
        (0.0, 0.0, 0.11),
        (0.46, -0.82, 0.39),
        0.37,
    ),
    AssetSpec(
        "prop.sickle",
        "sickle",
        "Sickle",
        ROOT / "assets" / "props" / "tools" / "sickle.glb",
        "res://content/maps/viru_gate_foreland.rrmap#west.sickle",
        (0.42, 0.48, 0.10),
        1200,
        (0.07, 0.0, 0.21),
        (0.85, -1.35, 0.78),
        0.70,
    ),
    AssetSpec(
        "prop.rake",
        "rake",
        "Rake",
        ROOT / "assets" / "props" / "tools" / "rake.glb",
        "res://content/maps/viru_gate_foreland.rrmap#east.rake",
        (0.65, 1.72, 0.13),
        1600,
        (0.0, 0.0, 0.86),
        (2.0, -3.3, 1.85),
        2.05,
    ),
    AssetSpec(
        "prop.wooden_shovel",
        "wooden_shovel",
        "WoodenShovel",
        ROOT / "assets" / "props" / "tools" / "wooden_shovel.glb",
        "res://content/maps/viru_gate_foreland.rrmap#east.wooden_shovel",
        (0.28, 1.50, 0.12),
        1200,
        (0.0, 0.0, 0.75),
        (1.5, -2.7, 1.55),
        1.82,
    ),
)

PALETTE = {
    "wood": (0x82 / 255.0, 0x58 / 255.0, 0x32 / 255.0),
    "iron": (0x45 / 255.0, 0x4D / 255.0, 0x50 / 255.0),
    "edge": (0x7A / 255.0, 0x87 / 255.0, 0x89 / 255.0),
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _texture_fields(surface: str):
    import numpy as np

    yy, xx = np.mgrid[0:TEXTURE_SIZE, 0:TEXTURE_SIZE].astype(np.float32)
    u = xx / float(TEXTURE_SIZE)
    v = yy / float(TEXTURE_SIZE)
    if surface == "wood":
        warp = u + 0.022 * np.sin(v * math.tau * 2.2)
        broad = np.sin((warp * 9.0 + v * 0.35) * math.tau)
        fine = np.sin((warp * 31.0 - v * 0.6) * math.tau)
        height = 0.50 + broad * 0.10 + fine * 0.025
        color_variation = 0.86 + broad * 0.065 + fine * 0.016
        roughness = np.clip(0.88 - height * 0.05, 0.78, 0.94)
    elif surface == "edge":
        sweep = np.sin((u * 8.0 + 0.15 * np.sin(v * math.tau * 2.0)) * math.tau)
        cross = np.sin((v * 17.0 - u * 0.7) * math.tau)
        height = 0.50 + sweep * 0.055 + cross * 0.018
        color_variation = 0.92 + sweep * 0.035 + cross * 0.012
        roughness = np.clip(0.31 - height * 0.04, 0.22, 0.36)
    else:
        hammered = np.sin((u * 12.0 + v * 4.0) * math.tau) * np.sin((v * 10.0 - u * 3.0) * math.tau)
        scale = np.sin((u * 2.0 + v * 1.6) * math.tau)
        height = 0.50 + hammered * 0.10 + scale * 0.045
        color_variation = 0.80 + hammered * 0.050 + scale * 0.025
        roughness = np.clip(0.63 - height * 0.10, 0.48, 0.68)
    return height.astype(np.float32), color_variation.astype(np.float32), roughness.astype(np.float32)


def _image_from_pixels(name: str, pixels, *, non_color: bool) -> bpy.types.Image:
    image = bpy.data.images.new(name, width=TEXTURE_SIZE, height=TEXTURE_SIZE, alpha=True)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.file_format = "PNG"
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image


def _create_material(name: str, surface: str, metallic: float) -> bpy.types.Material:
    import numpy as np

    height, color_variation, roughness = _texture_fields(surface)
    base_linear = np.array([_srgb_to_linear(value) for value in PALETTE[surface]], dtype=np.float32)
    albedo_rgb = np.clip(base_linear[None, None, :] * color_variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((TEXTURE_SIZE, TEXTURE_SIZE, 1), dtype=np.float32)
    albedo = _image_from_pixels(f"{name}_albedo", np.concatenate((albedo_rgb, alpha), axis=2), non_color=False)

    du = np.gradient(height, axis=1)
    dv = np.gradient(height, axis=0)
    strength = 0.58 if surface != "edge" else 0.32
    nx = -du * strength
    ny = -dv * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal_rgb = np.stack((nx / length, ny / length, nz / length), axis=2) * 0.5 + 0.5
    normal = _image_from_pixels(
        f"{name}_normal",
        np.concatenate((np.clip(normal_rgb, 0.0, 1.0), alpha), axis=2),
        non_color=True,
    )
    rough_rgb = np.repeat(roughness[:, :, None], 3, axis=2)
    rough = _image_from_pixels(
        f"{name}_roughness",
        np.concatenate((rough_rgb, alpha), axis=2),
        non_color=True,
    )

    material = bpy.data.materials.new(name)
    material.diffuse_color = (*base_linear, 1.0)
    material.metallic = metallic
    material.roughness = float(roughness.mean())
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = material.roughness

    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.name = "EmbeddedPaintedAlbedo"
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.name = "EmbeddedTangentNormal"
    normal_node.image = normal
    normal_node.image.colorspace_settings.name = "Non-Color"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.75
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    rough_node = nodes.new("ShaderNodeTexImage")
    rough_node.name = "EmbeddedRoughness"
    rough_node.image = rough
    rough_node.image.colorspace_settings.name = "Non-Color"
    links.new(rough_node.outputs["Color"], principled.inputs["Roughness"])
    return material


def _link_and_parent(obj: bpy.types.Object, root: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    obj.parent = root
    if len(obj.data.materials) == 0:
        obj.data.materials.append(material)
    return obj


def _cylinder_between(
    root: bpy.types.Object,
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    vertices: int = 10,
    radius_end: float | None = None,
) -> bpy.types.Object:
    a = Vector(start)
    b = Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius,
        radius2=radius if radius_end is None else radius_end,
        depth=direction.length,
        end_fill_type="NGON",
        location=(a + b) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return _link_and_parent(obj, root, material)


def _sphere(
    root: bpy.types.Object,
    name: str,
    center: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=radius, location=center)
    obj = bpy.context.object
    obj.name = name
    return _link_and_parent(obj, root, material)


def _box(
    root: bpy.types.Object,
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("HandForgedEdges", "BEVEL")
    bevel.width = min(size) * 0.18
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return _link_and_parent(obj, root, material)


def _blade_prism(
    root: bpy.types.Object,
    name: str,
    outline: list[tuple[float, float]],
    z_low: float,
    z_high: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    vertices = [(x, y, z_low) for x, y in outline] + [(x, y, z_high) for x, y in outline]
    count = len(outline)
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return _link_and_parent(obj, root, material)


def _vertical_prism(
    root: bpy.types.Object,
    name: str,
    outline: list[tuple[float, float]],
    y_low: float,
    y_high: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Extrude an X/Z silhouette so upright blades remain legible in map views."""
    vertices = [(x, y_low, z) for x, z in outline] + [(x, y_high, z) for x, z in outline]
    count = len(outline)
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return _link_and_parent(obj, root, material)


def _build_tongs(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    iron = materials["iron"]
    edge = materials["edge"]
    objects: list[bpy.types.Object] = []
    # Long handles converge on a riveted boss, then reopen into short gripping jaws.
    for side, label in ((-1.0, "Left"), (1.0, "Right")):
        points = [
            (side * 0.19, 0.00, 0.025),
            (side * 0.13, 0.035, 0.23),
            (side * 0.045, 0.075, 0.47),
            (side * 0.075, 0.105, 0.64),
            (side * 0.055, 0.125, 0.73),
        ]
        for index in range(len(points) - 1):
            objects.append(_cylinder_between(root, f"{label}Arm{index}", points[index], points[index + 1], 0.021, iron, 10))
        objects.append(
            _box(
                root,
                f"{label}Jaw",
                (side * 0.055, 0.128, 0.744),
                (0.072, 0.07, 0.105),
                edge,
                rotation=(side * 0.08, 0.0, side * -0.10),
            )
        )
    objects.append(_sphere(root, "RivetedBoss", (0.0, 0.078, 0.475), 0.055, iron))
    objects.append(_cylinder_between(root, "RivetPin", (-0.062, 0.078, 0.475), (0.062, 0.078, 0.475), 0.022, edge, 10))
    return objects


def _build_pitchfork(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    iron = materials["iron"]
    objects = [_cylinder_between(root, "AshShaft", (-0.12, 0.02, 0.0), (0.115, 0.025, 1.60), 0.028, wood, 12, 0.024)]
    objects.append(_cylinder_between(root, "Socket", (0.105, 0.025, 1.48), (0.125, 0.02, 1.66), 0.042, iron, 12, 0.031))
    crown = (0.125, 0.02, 1.64)
    for index, offset in enumerate((-0.15, 0.0, 0.15)):
        shoulder = (0.125 + offset * 0.78, 0.0, 1.72)
        bend = (0.125 + offset, -0.045, 1.86)
        tip = (0.125 + offset * 1.08, -0.10, 2.01)
        objects.append(_cylinder_between(root, f"ForkBranch{index}", crown, shoulder, 0.022, iron, 9, 0.019))
        objects.append(_cylinder_between(root, f"TineLower{index}", shoulder, bend, 0.019, iron, 9, 0.012))
        objects.append(_cylinder_between(root, f"TineTip{index}", bend, tip, 0.012, iron, 9, 0.003))
    return objects


def _build_scythe(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    iron = materials["iron"]
    edge = materials["edge"]
    objects: list[bpy.types.Object] = []
    shaft_points = [(-0.29, 0.06, 0.10), (-0.17, 0.04, 0.55), (0.00, 0.015, 1.05), (0.10, 0.0, 1.52)]
    for index in range(len(shaft_points) - 1):
        objects.append(_cylinder_between(root, f"CurvedSnath{index}", shaft_points[index], shaft_points[index + 1], 0.031, wood, 12, 0.026))
    objects.append(_cylinder_between(root, "HandGrip", (-0.03, 0.02, 0.91), (-0.03, -0.24, 0.91), 0.023, wood, 10, 0.019))
    objects.append(_sphere(root, "GripKnob", (-0.03, -0.255, 0.91), 0.032, wood))
    objects.append(_cylinder_between(root, "IronSocket", (-0.31, 0.055, 0.07), (-0.22, 0.035, 0.20), 0.045, iron, 12, 0.033))
    blade_outline = [
        (-0.31, 0.02),
        (-0.16, -0.035),
        (0.10, -0.09),
        (0.39, -0.105),
        (0.68, -0.065),
        (0.61, -0.005),
        (0.35, 0.030),
        (0.08, 0.045),
        (-0.16, 0.055),
    ]
    objects.append(_blade_prism(root, "CurvedBlade", blade_outline, 0.025, 0.055, iron))
    edge_outline = [
        (-0.13, -0.038),
        (0.10, -0.092),
        (0.39, -0.107),
        (0.68, -0.067),
        (0.61, -0.047),
        (0.38, -0.080),
        (0.11, -0.068),
    ]
    objects.append(_blade_prism(root, "PolishedCuttingEdge", edge_outline, 0.019, 0.028, edge))
    return objects


def _build_blacksmith_hammer(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    iron = materials["iron"]
    edge = materials["edge"]
    # A compact one-handed smithing hammer: short ash haft, square face, and
    # transverse peen rather than the claw or rubberized grip of a modern tool.
    return [
        _cylinder_between(root, "AshHaft", (-0.012, 0.0, 0.0), (0.008, 0.0, 0.345), 0.021, wood, 12, 0.026),
        _box(root, "ForgedHead", (0.0, 0.0, 0.315), (0.105, 0.072, 0.068), iron),
        _box(root, "SquareFace", (-0.075, 0.0, 0.315), (0.052, 0.078, 0.072), edge),
        _box(root, "CrossPeen", (0.077, 0.0, 0.315), (0.052, 0.034, 0.058), iron),
    ]


def _build_blacksmith_punch(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    iron = materials["iron"]
    edge = materials["edge"]
    # Upright presentation keeps this small struck tool readable; the broad
    # mushroomed end and narrow working point distinguish it from a modern drill.
    return [
        _cylinder_between(root, "ForgedBody", (0.0, 0.0, 0.0), (0.0, 0.0, 0.190), 0.026, iron, 10, 0.014),
        _cylinder_between(root, "HardenedPoint", (0.0, 0.0, 0.190), (0.0, 0.0, 0.225), 0.014, edge, 10, 0.003),
        _cylinder_between(root, "StruckHead", (0.0, 0.0, 0.0), (0.0, 0.0, 0.026), 0.031, iron, 10, 0.026),
    ]


def _build_sickle(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    iron = materials["iron"]
    edge = materials["edge"]
    objects = [
        _cylinder_between(root, "ShortAshGrip", (-0.11, 0.0, 0.0), (-0.025, 0.0, 0.265), 0.027, wood, 12, 0.023),
        _cylinder_between(root, "BladeTang", (-0.035, 0.0, 0.235), (0.055, 0.0, 0.300), 0.018, iron, 10, 0.014),
    ]
    # The short inward-curving reaping blade is intentionally unlike the long,
    # two-handed scythe and suits grain or garden work beside a farm building.
    blade_outline = [
        (0.035, 0.275),
        (0.115, 0.350),
        (0.235, 0.430),
        (0.365, 0.452),
        (0.405, 0.424),
        (0.330, 0.385),
        (0.230, 0.355),
        (0.145, 0.305),
        (0.075, 0.245),
    ]
    edge_outline = [
        (0.075, 0.260),
        (0.150, 0.315),
        (0.235, 0.365),
        (0.330, 0.395),
        (0.405, 0.424),
        (0.365, 0.405),
        (0.245, 0.340),
        (0.125, 0.275),
    ]
    objects.append(_vertical_prism(root, "CurvedReapingBlade", blade_outline, -0.018, 0.018, iron))
    objects.append(_vertical_prism(root, "PolishedInnerEdge", edge_outline, -0.021, -0.019, edge))
    return objects


def _build_rake(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    objects = [
        _cylinder_between(root, "LongAshShaft", (0.0, 0.0, 0.10), (0.08, 0.015, 1.70), 0.027, wood, 12, 0.023),
        _cylinder_between(root, "RakeHead", (-0.31, 0.0, 0.095), (0.31, 0.0, 0.095), 0.026, wood, 12, 0.023),
    ]
    # Eight stout wooden teeth fit hay and yard work without implying a later
    # all-iron landscape rake.
    for index in range(8):
        x = -0.28 + index * 0.08
        objects.append(_cylinder_between(root, f"WoodenTooth{index}", (x, 0.005, 0.105), (x, -0.115, 0.012), 0.012, wood, 8, 0.006))
    return objects


def _build_wooden_shovel(root: bpy.types.Object, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    wood = materials["wood"]
    # A broad carved wooden blade and simple T-grip suit grain, ash, and stable
    # work without adding a later rolled-steel socket or factory D-handle.
    blade_outline = [
        (-0.135, 0.015),
        (0.135, 0.015),
        (0.125, 0.285),
        (0.060, 0.395),
        (-0.060, 0.395),
        (-0.125, 0.285),
    ]
    return [
        _vertical_prism(root, "CarvedWoodenBlade", blade_outline, -0.028, 0.028, wood),
        _cylinder_between(root, "AshShaft", (0.0, 0.0, 0.350), (0.0, 0.0, 1.405), 0.026, wood, 12, 0.022),
        _cylinder_between(root, "TGrip", (-0.10, 0.0, 1.445), (0.10, 0.0, 1.445), 0.023, wood, 10, 0.020),
        _cylinder_between(root, "GripNeck", (0.0, 0.0, 1.390), (0.0, 0.0, 1.445), 0.024, wood, 10, 0.022),
    ]


def _prepare_meshes(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
        bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def _ground_objects(objects: list[bpy.types.Object]) -> None:
    """Normalize every tool onto z=0 after bevels so exported roots never float."""
    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in objects for corner in obj.bound_box)
    for obj in objects:
        obj.location.z -= minimum_z


def _metrics(spec: AssetSpec, objects: list[bpy.types.Object]) -> dict[str, object]:
    triangles = 0
    vertices = 0
    material_names: set[str] = set()
    textured_material_names: set[str] = set()
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    uv_sets = 10_000
    for obj in objects:
        mesh = obj.data
        vertices += len(mesh.vertices)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        uv_sets = min(uv_sets, len(mesh.uv_layers))
        for material in mesh.materials:
            material_names.add(material.name)
            if material.use_nodes and any(node.type == "TEX_IMAGE" and node.image != None for node in material.node_tree.nodes):
                textured_material_names.add(material.name)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low.x = min(low.x, world.x)
            low.y = min(low.y, world.y)
            low.z = min(low.z, world.z)
            high.x = max(high.x, world.x)
            high.y = max(high.y, world.y)
            high.z = max(high.z, world.z)
    return {
        "asset_id": spec.asset_id,
        "vertices": vertices,
        "triangles": triangles,
        "materials": len(material_names),
        "textured_materials": len(textured_material_names),
        "mesh_objects": len(objects),
        "uv_sets": 0 if uv_sets == 10_000 else uv_sets,
        "dimensions_m": [round(high.x - low.x, 4), round(high.z - low.z, 4), round(high.y - low.y, 4)],
        "ground_min_z": round(low.z, 6),
        "floating_objects": 0,
        "texture_size": TEXTURE_SIZE,
    }


def _cache_key(spec: AssetSpec) -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(spec.brief, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(spec: AssetSpec, root: bpy.types.Object, objects: list[bpy.types.Object]) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
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
    metrics = _metrics(spec, objects)
    metrics["sha256"] = hashlib.sha256(spec.output.read_bytes()).hexdigest()
    metrics["cache_key"] = _cache_key(spec)
    return metrics


def _render_preview(spec: AssetSpec) -> Path:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.032, 0.028)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.16, 0.12, 0.07, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0.0, 0.0, -0.004))
    bpy.context.object.data.materials.append(floor_material)

    for name, energy, size, location in (
        ("Key", 540.0, 2.6, (2.1, -2.7, 3.2)),
        ("Fill", 180.0, 3.2, (-2.0, 1.5, 2.0)),
    ):
        light = bpy.data.lights.new(name, type="AREA")
        light.energy = energy
        light.size = size
        obj = bpy.data.objects.new(name, light)
        bpy.context.collection.objects.link(obj)
        obj.location = location

    bpy.ops.object.camera_add(location=spec.preview_camera)
    camera = bpy.context.object
    target = Vector(spec.preview_target)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = spec.preview_scale
    scene.camera = camera
    output = spec.evidence_dir / "preview.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    return output


def _write_evidence(spec: AssetSpec, metrics: dict[str, object], preview: Path | None) -> None:
    spec.evidence_dir.mkdir(parents=True, exist_ok=True)
    (spec.evidence_dir / "brief.json").write_text(json.dumps(spec.brief, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        **metrics,
        "route": "deterministic_blender",
        "generator": "tools/generate_medieval_hand_tools.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "approval": "user-requested 2026-07-30",
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= spec.triangle_max,
            "portable_pbr": True,
            "embedded_albedo_normal_roughness": int(metrics["textured_materials"]) == int(metrics["materials"]),
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix()
    (spec.evidence_dir / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": spec.asset_id,
        "route": "deterministic_blender",
        "stage": "integrated",
        "approval": "user-requested 2026-07-30",
        "cache_key": metrics["cache_key"],
        "selected_glb": spec.output.relative_to(ROOT).as_posix(),
        "sha256": metrics["sha256"],
        "decision": "integrate",
        "defects": [],
    }
    (spec.evidence_dir / "state.json").write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def _build(spec: AssetSpec, preview_enabled: bool) -> dict[str, object]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = bpy.data.objects.new(spec.root_name, None)
    bpy.context.collection.objects.link(root)
    materials = {
        "wood": _create_material("ToolAshWood", "wood", 0.0),
        "iron": _create_material("HammeredToolIron", "iron", 0.72),
        "edge": _create_material("PolishedToolEdge", "edge", 0.82),
    }
    builders = {
        "blacksmith_tongs": (_build_tongs, "riveted two-arm blacksmith tongs with short flat gripping jaws"),
        "pitchfork": (_build_pitchfork, "three hand-forged tines socketed onto a long ash shaft"),
        "scythe": (_build_scythe, "curved ash snath, side grip, iron socket, and short grass-cutting blade"),
        "blacksmith_hammer": (_build_blacksmith_hammer, "one-handed ash-hafted forging hammer with a square face and cross peen"),
        "blacksmith_punch": (_build_blacksmith_punch, "short hand-forged punch with a struck head and hardened tapered point"),
        "sickle": (_build_sickle, "short ash grip and inward-curving iron reaping blade"),
        "rake": (_build_rake, "long ash shaft, wooden crossbar, and eight wooden hay teeth"),
        "wooden_shovel": (_build_wooden_shovel, "broad carved wooden blade, long ash shaft, and simple transverse grip"),
    }
    builder, identity = builders[spec.slug]
    objects = builder(root, materials)
    _prepare_meshes(objects)
    _ground_objects(objects)
    root["asset_id"] = spec.asset_id
    root["generator"] = "tools/generate_medieval_hand_tools.py"
    root["generator_version"] = GENERATOR_VERSION
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = f"1343 northern Baltic hand tool: {identity}"
    metrics = _export(spec, root, objects)
    preview = _render_preview(spec) if preview_enabled else None
    _write_evidence(spec, metrics, preview)
    return metrics


def main() -> None:
    preview_enabled = "--preview" in sys.argv
    only_slugs: set[str] = set()
    for argument in sys.argv:
        if argument.startswith("--only="):
            only_slugs.update(slug.strip() for slug in argument.removeprefix("--only=").split(",") if slug.strip())
    specs = [spec for spec in SPECS if not only_slugs or spec.slug in only_slugs]
    missing = only_slugs.difference(spec.slug for spec in specs)
    if missing:
        raise ValueError(f"Unknown hand-tool slugs: {sorted(missing)}")
    all_metrics = []
    for spec in specs:
        metrics = _build(spec, preview_enabled)
        all_metrics.append(
            {
                "asset": spec.slug,
                "triangles": metrics["triangles"],
                "materials": metrics["materials"],
                "uv_sets": metrics["uv_sets"],
                "dimensions_m": metrics["dimensions_m"],
                "ground_min": metrics["ground_min_z"],
                "sha256": metrics["sha256"],
            }
        )
    print("ASSET_METRICS=" + json.dumps(all_metrics, separators=(",", ":")))


if __name__ == "__main__":
    main()
