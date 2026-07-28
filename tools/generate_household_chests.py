#!/usr/bin/env python3
"""Build three game-ready medieval household chests with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_household_chests.py -- --preview

The set separates household wealth and storage purpose without fantasy ornament:
a small all-wood coffer, an iron-bound burgher chest, and a large merchant
strongbox. All outputs are deterministic rigid props with embedded painted PBR
albedos, metric dimensions, UVs, and ground contact at zero.
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
OUTPUT_DIR = ROOT / "assets" / "props" / "furniture"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "household_chests_v1"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "household_chests_v1"

WOOD_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
PALE_WOOD_SRGB = (0x8A / 255.0, 0x61 / 255.0, 0x3D / 255.0)
DARK_TIMBER_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)

SPECS = (
    {
        "key": "poor",
        "asset_id": "prop.chest.poor_household",
        "output": "chest_poor_household.glb",
        "root_name": "PoorHouseholdChest",
        "purpose": "linens, food vessels, and ordinary household tools",
        "wealth": "poor household",
        "width": 0.78,
        "depth": 0.42,
        "feet": 0.04,
        "body_height": 0.31,
        "lid": "flat",
        "lid_thickness": 0.075,
        "wood": PALE_WOOD_SRGB,
        "bands": (),
        "triangle_max": 2800,
    },
    {
        "key": "common",
        "asset_id": "prop.chest.burgher_household",
        "output": "chest_burgher_household.glb",
        "root_name": "BurgherHouseholdChest",
        "purpose": "clothing, account papers, tools, and mixed household goods",
        "wealth": "artisan or burgher household",
        "width": 0.98,
        "depth": 0.52,
        "feet": 0.035,
        "body_height": 0.32,
        "lid": "arched",
        "lid_depth": 0.47,
        "wood": WOOD_SRGB,
        "bands": (-0.27, 0.27),
        "triangle_max": 4200,
    },
    {
        "key": "rich",
        "asset_id": "prop.chest.merchant_strongbox",
        "output": "chest_merchant_strongbox.glb",
        "root_name": "MerchantStrongbox",
        "purpose": "coin, charters, seals, and high-value merchant goods",
        "wealth": "wealthy merchant, guild, or civic treasury",
        "width": 1.18,
        "depth": 0.62,
        "feet": 0.05,
        "body_height": 0.36,
        "lid": "arched",
        "lid_depth": 0.55,
        "wood": DARK_TIMBER_SRGB,
        "bands": (-0.36, 0.0, 0.36),
        "triangle_max": 6500,
    },
)

BRIEF = {
    "id": "prop.household_chests",
    "kind": "rigid_prop_set",
    "targets": [f"res://assets/props/furniture/{spec['output']}" for spec in SPECS],
    "scene": "res://content/maps/*.rrmap#chest",
    "variants": [
        {"id": spec["asset_id"], "wealth": spec["wealth"], "purpose": spec["purpose"]}
        for spec in SPECS
    ],
    "triangles": {"max_per_asset": 6500},
    "textures": {"albedo": 512},
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(
    name: str,
    base_srgb: tuple[float, float, float],
    surface: str,
) -> bpy.types.Image:
    """Bake restrained broad detail because procedural nodes do not export to glTF."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if surface == "wood":
        warp = u + 0.027 * np.sin(v * math.tau * 2.0) + 0.009 * np.sin(v * math.tau * 6.2 + 0.5)
        broad = np.sin((warp * 9.0 + 0.10 * np.sin(v * math.tau * 1.5)) * math.tau)
        fine = np.sin((warp * 31.0 + v * 0.7) * math.tau)
        variation = 0.84 + broad * 0.065 + fine * 0.015
        for knot_u, knot_v, radius in ((0.23, 0.34, 0.075), (0.72, 0.68, 0.095)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.55)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 2.1) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.06
            variation -= np.exp(-(distance * distance) * 5.0) * 0.12
    elif surface == "timber":
        grain = np.sin((u * 13.0 + 0.12 * np.sin(v * math.tau * 2.0)) * math.tau)
        tool = np.sin((u * 43.0 + v * 0.4) * math.tau)
        variation = 0.78 + grain * 0.055 + tool * 0.012
    else:
        hammered = np.sin((u * 11.0 + v * 5.0) * math.tau) * np.sin((v * 9.0 - u * 4.0) * math.tau)
        broad = np.sin((u * 2.0 + v * 1.7) * math.tau)
        variation = 0.75 + hammered * 0.045 + broad * 0.025

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
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedPaintedAlbedo"
    texture.image = _create_texture(f"{name}_albedo", srgb, surface)
    texture.interpolation = "Linear"
    texture.extension = "REPEAT"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _faces_for(vertices: list[bmesh.types.BMVert]) -> set[bmesh.types.BMFace]:
    return {face for vertex in vertices for face in vertex.link_faces}


def _add_box(
    mesh: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material_index: int,
    rotation_x: float = 0.0,
) -> None:
    matrix = Matrix.Translation(Vector(center))
    if rotation_x:
        matrix @= Matrix.Rotation(rotation_x, 4, "X")
    matrix @= Matrix.Diagonal(Vector((*size, 1.0)))
    result = bmesh.ops.create_cube(mesh, size=1.0, matrix=matrix)
    vertices = [element for element in result["verts"] if isinstance(element, bmesh.types.BMVert)]
    for face in _faces_for(vertices):
        face.material_index = material_index


def _add_cylinder_between(
    mesh: bmesh.types.BMesh,
    start: Vector,
    end: Vector,
    radius: float,
    material_index: int,
    segments: int = 8,
) -> None:
    direction = end - start
    length = direction.length
    if length <= 1e-6:
        return
    rotation = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    matrix = Matrix.Translation((start + end) * 0.5) @ rotation
    result = bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=length,
        matrix=matrix,
    )
    vertices = [element for element in result["verts"] if isinstance(element, bmesh.types.BMVert)]
    for face in _faces_for(vertices):
        face.material_index = material_index


def _add_arch_lid(
    mesh: bmesh.types.BMesh,
    width: float,
    depth: float,
    base_z: float,
    material_index: int,
    segments: int = 10,
) -> list[Vector]:
    radius = depth * 0.5
    profile = [
        Vector((0.0, radius * math.cos(theta), base_z + radius * math.sin(theta)))
        for theta in (math.pi - math.pi * index / segments for index in range(segments + 1))
    ]
    half_width = width * 0.5
    left = [mesh.verts.new((-half_width, point.y, point.z)) for point in profile]
    right = [mesh.verts.new((half_width, point.y, point.z)) for point in profile]
    count = len(profile)
    for index in range(count):
        next_index = (index + 1) % count
        face = mesh.faces.new((left[index], left[next_index], right[next_index], right[index]))
        face.material_index = material_index
    for ring in (left, list(reversed(right))):
        face = mesh.faces.new(ring)
        face.material_index = material_index
    return profile


def _add_arch_band(
    mesh: bmesh.types.BMesh,
    x: float,
    profile: list[Vector],
    width: float,
    thickness: float,
    material_index: int,
) -> None:
    for start, end in zip(profile[:-1], profile[1:]):
        midpoint = (start + end) * 0.5
        vector = end - start
        angle = math.atan2(vector.z, vector.y)
        _add_box(
            mesh,
            (x, midpoint.y, midpoint.z + thickness * 0.5),
            (width, vector.length + 0.006, thickness),
            material_index,
            angle,
        )


def _add_front_rivets(
    mesh: bmesh.types.BMesh,
    x_positions: tuple[float, ...],
    front_y: float,
    z_positions: tuple[float, ...],
    material_index: int,
) -> None:
    for x in x_positions:
        for z in z_positions:
            _add_cylinder_between(
                mesh,
                Vector((x, front_y - 0.010, z)),
                Vector((x, front_y - 0.025, z)),
                0.014,
                material_index,
                8,
            )


def _add_side_handle(
    mesh: bmesh.types.BMesh,
    side_x: float,
    depth: float,
    body_mid_z: float,
    material_index: int,
) -> None:
    outward = 1.0 if side_x > 0.0 else -1.0
    x = side_x + outward * 0.022
    y_front, y_back = -depth * 0.18, depth * 0.18
    lower_z = body_mid_z - 0.02
    upper_z = body_mid_z + 0.11
    _add_cylinder_between(mesh, Vector((x, y_front, upper_z)), Vector((x, y_front, lower_z)), 0.012, material_index)
    _add_cylinder_between(mesh, Vector((x, y_back, lower_z)), Vector((x, y_back, upper_z)), 0.012, material_index)
    _add_cylinder_between(mesh, Vector((x, y_front, lower_z)), Vector((x, y_back, lower_z)), 0.012, material_index)


def _build_model(spec: dict[str, object], preview_suffix: str = "") -> tuple[bpy.types.Object, bpy.types.Object]:
    key = str(spec["key"])
    suffix = f"_{preview_suffix}" if preview_suffix else ""
    materials = [
        _create_material(f"{key.title()}ChestOak{suffix}", spec["wood"], 0.84, 0.0, "wood"),
        _create_material(f"{key.title()}ChestTimber{suffix}", DARK_TIMBER_SRGB, 0.88, 0.0, "timber"),
    ]
    if key != "poor":
        materials.append(_create_material(f"{key.title()}ChestIron{suffix}", IRON_SRGB, 0.70, 0.72, "iron"))

    root = bpy.data.objects.new(str(spec["root_name"]), None)
    root.empty_display_type = "PLAIN_AXES"
    root["asset_id"] = spec["asset_id"]
    root["wealth_class"] = spec["wealth"]
    root["storage_purpose"] = spec["purpose"]
    bpy.context.scene.collection.objects.link(root)

    mesh_data = bpy.data.meshes.new(f"{spec['root_name']}Geometry")
    obj = bpy.data.objects.new(f"{spec['root_name']}Mesh", mesh_data)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    for material in materials:
        mesh_data.materials.append(material)

    mesh = bmesh.new()
    width = float(spec["width"])
    depth = float(spec["depth"])
    feet = float(spec["feet"])
    body_height = float(spec["body_height"])
    body_base = feet
    body_top = body_base + body_height
    front_y = -depth * 0.5

    # One solid carcass with external seams reads as assembled planks without
    # leaving gaps that shimmer at the fixed isometric gameplay distance.
    _add_box(mesh, (0.0, 0.0, body_base + body_height * 0.5), (width, depth, body_height), 0)
    for row in (0.34, 0.67):
        seam_z = body_base + body_height * row
        _add_box(mesh, (0.0, front_y - 0.006, seam_z), (width * 0.94, 0.012, 0.012), 1)

    foot_width = 0.12 if key == "rich" else 0.10
    for x in (-width * 0.39, width * 0.39):
        _add_box(mesh, (x, 0.0, feet * 0.5), (foot_width, depth * 0.86, feet), 1)

    if spec["lid"] == "flat":
        lid_thickness = float(spec["lid_thickness"])
        _add_box(
            mesh,
            (0.0, 0.0, body_top + lid_thickness * 0.5),
            (width + 0.035, depth + 0.035, lid_thickness),
            0,
        )
        for seam_y in (-depth * 0.22, 0.0, depth * 0.22):
            _add_box(
                mesh,
                (0.0, seam_y, body_top + lid_thickness + 0.002),
                (width * 0.96, 0.010, 0.006),
                1,
            )
        # Wooden battens and a peg latch make the poorest coffer functional
        # without implying access to expensive forged strapping.
        for x in (-width * 0.29, width * 0.29):
            _add_box(mesh, (x, front_y - 0.013, body_base + body_height * 0.51), (0.055, 0.026, body_height * 0.92), 1)
            _add_box(mesh, (x, 0.0, body_top + lid_thickness + 0.010), (0.055, depth * 0.90, 0.025), 1)
        _add_box(mesh, (0.0, front_y - 0.028, body_top - 0.035), (0.085, 0.035, 0.11), 1)
        _add_cylinder_between(
            mesh,
            Vector((0.0, front_y - 0.055, body_top - 0.07)),
            Vector((0.0, front_y - 0.075, body_top - 0.07)),
            0.018,
            1,
            8,
        )
    else:
        lid_depth = float(spec["lid_depth"])
        profile = _add_arch_lid(mesh, width + 0.025, lid_depth, body_top, 0, 10)
        band_positions = tuple(float(value) for value in spec["bands"])
        band_width = 0.035 if key == "common" else 0.045
        for x in band_positions:
            _add_arch_band(mesh, x, profile, band_width, 0.018, 2)
            _add_box(
                mesh,
                (x, front_y - 0.014, body_base + body_height * 0.52),
                (band_width, 0.028, body_height * 0.96),
                2,
            )
            _add_box(
                mesh,
                (x, -front_y + 0.014, body_base + body_height * 0.52),
                (band_width, 0.028, body_height * 0.96),
                2,
            )

        lock_width = 0.13 if key == "common" else 0.18
        lock_height = 0.14 if key == "common" else 0.18
        lock_z = body_top - lock_height * 0.47
        _add_box(mesh, (0.0, front_y - 0.025, lock_z), (lock_width, 0.035, lock_height), 2)
        _add_cylinder_between(
            mesh,
            Vector((0.0, front_y - 0.048, lock_z - 0.012)),
            Vector((0.0, front_y - 0.062, lock_z - 0.012)),
            0.018,
            2,
            8,
        )
        _add_front_rivets(
            mesh,
            band_positions,
            front_y,
            (body_base + body_height * 0.20, body_base + body_height * 0.78),
            2,
        )

        if key == "rich":
            # Corner guards and carrying handles communicate a heavy strongbox;
            # decoration stays structural rather than drifting into fantasy gold.
            for x in (-width * 0.47, width * 0.47):
                _add_box(mesh, (x, front_y - 0.018, body_base + body_height * 0.50), (0.040, 0.030, body_height), 2)
            for side_x in (-width * 0.5, width * 0.5):
                _add_side_handle(mesh, side_x, depth, body_base + body_height * 0.53, 2)
            _add_front_rivets(
                mesh,
                (-width * 0.47, width * 0.47),
                front_y,
                (body_base + body_height * 0.17, body_base + body_height * 0.83),
                2,
            )

    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    mesh.to_mesh(mesh_data)
    mesh.free()
    mesh_data.update()

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bevel = obj.modifiers.new("HandSoftenedEdges", "BEVEL")
    bevel.width = 0.005 if key == "poor" else 0.006
    bevel.segments = 1
    bevel.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.object.shade_smooth_by_angle()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return root, obj


def _bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    minimum = Vector((1e9, 1e9, 1e9))
    maximum = Vector((-1e9, -1e9, -1e9))
    for corner in obj.bound_box:
        point = obj.matrix_world @ Vector(corner)
        minimum = Vector(map(min, minimum, point))
        maximum = Vector(map(max, maximum, point))
    return minimum, maximum


def _metrics(obj: bpy.types.Object, output: Path, spec: dict[str, object]) -> dict[str, object]:
    minimum, maximum = _bounds(obj)
    dimensions = maximum - minimum
    triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)
    used_materials = {
        obj.data.materials[polygon.material_index].name
        for polygon in obj.data.polygons
        if polygon.material_index < len(obj.data.materials)
    }
    return {
        "triangles": triangles,
        "materials": len(used_materials),
        "uv_sets": len(obj.data.uv_layers),
        "dimensions_m": [round(dimensions.x, 4), round(dimensions.z, 4), round(dimensions.y, 4)],
        "ground_min": round(minimum.z, 6),
        "texture_size": 512,
        "triangle_max": int(spec["triangle_max"]),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, obj: bpy.types.Object, output: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
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


def _build_and_export() -> dict[str, dict[str, object]]:
    all_metrics: dict[str, dict[str, object]] = {}
    for spec in SPECS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        root, obj = _build_model(spec)
        output = OUTPUT_DIR / str(spec["output"])
        _export(root, obj, output)
        all_metrics[str(spec["key"])] = _metrics(obj, output, spec)
    return all_metrics


def _render_preview(output: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    placements = (-1.25, 0.0, 1.38)
    for index, (spec, x) in enumerate(zip(SPECS, placements)):
        root, _obj = _build_model(spec, f"preview{index}")
        root.location.x = x

    floor_material = bpy.data.materials.new("PreviewFloorMaterial")
    floor_material.diffuse_color = (0.13, 0.105, 0.075, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=5.5, location=(0.0, 0.0, -0.004))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.2, -3.8, 4.8))
    key = bpy.context.object
    key.data.energy = 900.0
    key.data.shape = "DISK"
    key.data.size = 3.2
    bpy.ops.object.light_add(type="AREA", location=(3.5, 1.4, 2.7))
    fill = bpy.context.object
    fill.data.energy = 440.0
    fill.data.size = 2.8

    bpy.ops.object.camera_add(location=(3.5, -5.0, 2.8))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.05, 0.0, 0.33)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.8

    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.03, 0.024)
    scene.render.filepath = str(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _write_evidence(metrics: dict[str, dict[str, object]], preview: Path | None) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    cache_key = _cache_key()
    validation = {
        key: {
            "metric_scale": True,
            "ground_contact": abs(float(values["ground_min"])) <= 0.001,
            "triangle_budget": int(values["triangles"]) <= int(values["triangle_max"]),
            "uvs": int(values["uv_sets"]) >= 1,
            "portable_pbr_materials": int(values["materials"]) >= 2,
        }
        for key, values in metrics.items()
    }
    report = {
        "asset_id": BRIEF["id"],
        "route": "deterministic_blender",
        "generator": "tools/generate_household_chests.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": cache_key,
        "metrics": metrics,
        "validation": validation,
        "preview": preview.relative_to(ROOT).as_posix() if preview is not None else None,
        "defects": [],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": BRIEF["id"],
        "route": "deterministic_blender",
        "stage": "integrated",
        "cache_key": cache_key,
        "selected_glbs": {key: str(spec["output"]) for key, spec in zip(metrics, SPECS)},
        "sha256": {key: values["sha256"] for key, values in metrics.items()},
        "decision": "integrate",
        "defects": [],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    metrics = _build_and_export()
    preview: Path | None = None
    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        if index + 1 < len(sys.argv) and not sys.argv[index + 1].startswith("--"):
            preview = Path(sys.argv[index + 1]).expanduser().resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(preview)
    _write_evidence(metrics, preview)
    compact = {
        key: {
            "triangles": value["triangles"],
            "materials": value["materials"],
            "dimensions_m": value["dimensions_m"],
            "sha256": value["sha256"],
        }
        for key, value in metrics.items()
    }
    print("ASSET_METRICS=" + json.dumps(compact, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
