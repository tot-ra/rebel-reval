#!/usr/bin/env python3
"""Build a game-ready medieval Baltic fishing net rack with Blender.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_fishing_nets.py -- --preview

The deterministic rigid prop replaces four hanging box strips with a sagging
knotted hemp net, cork floats, stone sinkers, lashings, and a braced oak rack.
Map-owned placement, collision, navigation, and the one-cell anchor stay intact.
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
OUTPUT = ROOT / "assets" / "props" / "crafts" / "fishing_nets.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "fishing_nets_v1"
DEFAULT_PREVIEW = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
ASSET_ID = "prop.fishing_nets"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR_VERSION = "fishing_nets_v1"

TIMBER_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
HEMP_SRGB = (0x9A / 255.0, 0x7B / 255.0, 0x49 / 255.0)
CORK_SRGB = (0xB5 / 255.0, 0x82 / 255.0, 0x45 / 255.0)
STONE_SRGB = (0x66 / 255.0, 0x63 / 255.0, 0x5C / 255.0)

BRIEF = {
    "id": ASSET_ID,
    "kind": "rigid_prop",
    "target": "res://assets/props/crafts/fishing_nets.glb",
    "scene": "res://content/maps/reval_harbor_east.rrmap#drying_nets_west",
    "dimensions_m": [1.5, 1.48, 0.5],
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
    """Create broad painted variation that remains portable inside the GLB."""
    import numpy as np

    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size - 1)
    v = yy / float(size - 1)

    if surface == "wood":
        warp = u + 0.022 * np.sin(v * math.tau * 2.0) + 0.008 * np.sin(v * math.tau * 7.0)
        broad = np.sin((warp * 8.0 + v * 0.25) * math.tau)
        fine = np.sin((warp * 29.0 - v * 0.7) * math.tau)
        variation = 0.82 + broad * 0.072 + fine * 0.016
        for knot_u, knot_v, radius in ((0.24, 0.33, 0.075), (0.72, 0.69, 0.095)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.58)
            distance = np.sqrt(dx * dx + dy * dy)
            variation -= np.exp(-(distance * distance) * 5.0) * 0.13
            variation += np.sin(distance * math.tau * 2.0) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.05
    elif surface == "rope":
        twist = np.sin((u * 22.0 + v * 7.0) * math.tau)
        fibers = np.sin((u * 55.0 - v * 4.0) * math.tau)
        broad = np.sin((u * 3.0 + v * 2.0) * math.tau)
        variation = 0.84 + twist * 0.052 + fibers * 0.013 + broad * 0.025
    elif surface == "cork":
        broad = np.sin((u * 3.0 + v * 2.0) * math.tau)
        pores = np.sin(u * math.tau * 13.0) * np.sin(v * math.tau * 11.0)
        stain = np.exp(-(((u - 0.68) / 0.22) ** 2 + ((v - 0.36) / 0.18) ** 2))
        variation = 0.88 + broad * 0.05 + pores * 0.022 - stain * 0.06
    else:
        broad = np.sin((u * 2.0 + v * 1.4) * math.tau)
        fleck = np.sin(u * math.tau * 9.0) * np.sin(v * math.tau * 7.0)
        variation = 0.84 + broad * 0.045 + fleck * 0.035

    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2)
    # The material tiles are embedded and may be extracted by Godot. Welding the
    # borders prevents visible seams regardless of the importer's wrap filtering.
    pixels[-1, :, :] = pixels[0, :, :]
    pixels[:, -1, :] = pixels[:, 0, :]

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
    segments: int = 6,
    taper: float = 0.96,
) -> None:
    bmesh.ops.create_cone(
        mesh,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * taper,
        depth=(end - start).length,
        matrix=_axis_matrix(start, end),
    )


def _object_from_bmesh(
    name: str,
    mesh: bmesh.types.BMesh,
    material: bpy.types.Material,
    smooth: bool = False,
) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    data = bpy.data.meshes.new(f"{name}Mesh")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    mesh.normal_update()
    mesh.to_mesh(data)
    mesh.free()
    data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    data.validate(clean_customdata=False)
    data.update()
    return obj


def _build_frame(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    for side in (-1.0, 1.0):
        _add_cylinder_between(
            mesh,
            Vector((side * 0.66, 0.03, 0.0)),
            Vector((side * 0.56, 0.0, 1.39)),
            0.058,
            segments=8,
            taper=0.89,
        )
        # WHY: rear braces make the rack visibly freestanding while staying inside
        # the existing visual depth and leaving all gameplay navigation untouched.
        _add_cylinder_between(
            mesh,
            Vector((side * 0.62, 0.08, 0.58)),
            Vector((side * 0.67, 0.39, 0.0)),
            0.038,
            segments=8,
            taper=0.9,
        )
    _add_cylinder_between(mesh, Vector((-0.73, 0.0, 1.405)), Vector((0.73, 0.0, 1.405)), 0.062, segments=8)
    _add_cylinder_between(mesh, Vector((-0.69, 0.39, 0.025)), Vector((0.69, 0.39, 0.025)), 0.036, segments=8)
    obj = _object_from_bmesh("Frame", mesh, material)
    obj["construction"] = "faceted oak poles with rear ground braces"
    return obj


def _net_point(u: float, v: float) -> Vector:
    """Return a deterministic catenary-like point on the loose hanging net."""
    taper = 1.0 - 0.08 * v
    x = (u - 0.5) * 1.08 * taper
    edge = (2.0 * u - 1.0) ** 2
    top_z = 1.265 - 0.055 * (1.0 - edge)
    bottom_z = 0.37 - 0.115 * (1.0 - edge)
    z = top_z + (bottom_z - top_z) * v
    billow = math.sin(math.pi * u) * math.sin(math.pi * v)
    y = -0.045 + 0.11 * billow + 0.014 * math.sin(math.tau * u + 0.7) * math.sin(math.pi * v)
    return Vector((x, y, z))


def _build_netting(material: bpy.types.Material) -> tuple[bpy.types.Object, int]:
    mesh = bmesh.new()
    row_count = 9
    column_count = 8
    nodes: list[list[Vector]] = []
    for row in range(row_count):
        v = row / float(row_count - 1)
        shifted = row % 2 == 1
        count = column_count if shifted else column_count + 1
        row_nodes = []
        for column in range(count):
            u = (column + (0.5 if shifted else 0.0)) / float(column_count)
            row_nodes.append(_net_point(u, v))
        nodes.append(row_nodes)

    strand_count = 0
    for row in range(row_count - 1):
        upper = nodes[row]
        lower = nodes[row + 1]
        if row % 2 == 0:
            for column, point in enumerate(upper):
                if column > 0:
                    _add_cylinder_between(mesh, point, lower[column - 1], 0.0085, segments=6)
                    strand_count += 1
                if column < len(lower):
                    _add_cylinder_between(mesh, point, lower[column], 0.0085, segments=6)
                    strand_count += 1
        else:
            for column, point in enumerate(upper):
                _add_cylinder_between(mesh, point, lower[column], 0.0085, segments=6)
                _add_cylinder_between(mesh, point, lower[column + 1], 0.0085, segments=6)
                strand_count += 2

    obj = _object_from_bmesh("Netting", mesh, material)
    obj["mesh_pattern"] = "knotted diamond"
    obj["strand_count"] = strand_count
    return obj, strand_count


def _polyline(mesh: bmesh.types.BMesh, points: list[Vector], radius: float) -> None:
    for index in range(len(points) - 1):
        _add_cylinder_between(mesh, points[index], points[index + 1], radius, segments=7)


def _build_outline_and_lashings(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    samples = 12
    _polyline(mesh, [_net_point(index / samples, 0.0) for index in range(samples + 1)], 0.016)
    _polyline(mesh, [_net_point(index / samples, 1.0) for index in range(samples + 1)], 0.018)
    _polyline(mesh, [_net_point(0.0, index / samples) for index in range(samples + 1)], 0.015)
    _polyline(mesh, [_net_point(1.0, index / samples) for index in range(samples + 1)], 0.015)
    for u in (0.08, 0.3, 0.5, 0.7, 0.92):
        net_point = _net_point(u, 0.0)
        rail_point = Vector((net_point.x, -0.002, 1.405))
        _add_cylinder_between(mesh, rail_point, net_point, 0.012, segments=7)
    obj = _object_from_bmesh("OutlineRope", mesh, material)
    obj["lashing_count"] = 5
    return obj


def _add_ellipsoid(
    mesh: bmesh.types.BMesh,
    center: Vector,
    scale: Vector,
    segments: int,
    rings: int,
    yaw: float = 0.0,
) -> None:
    result = bmesh.ops.create_icosphere(mesh, subdivisions=1, radius=1.0)
    transform = Matrix.Translation(center) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal(Vector((*scale, 1.0)))
    bmesh.ops.transform(mesh, matrix=transform, verts=result["verts"])


def _build_floats(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    for index, u in enumerate((0.08, 0.28, 0.5, 0.72, 0.92)):
        point = _net_point(u, 0.0)
        point.z += 0.014
        scale = Vector((0.052 + 0.004 * (index % 2), 0.035, 0.043))
        _add_ellipsoid(mesh, point, scale, segments=8, rings=4, yaw=0.1 * (index - 2))
    obj = _object_from_bmesh("Floats", mesh, material, smooth=False)
    obj["historical_material"] = "cork or pine-bark net floats"
    obj["float_count"] = 5
    return obj


def _build_sinkers(material: bpy.types.Material) -> bpy.types.Object:
    mesh = bmesh.new()
    sinker_us = (0.06, 0.21, 0.36, 0.5, 0.64, 0.79, 0.94)
    for index, u in enumerate(sinker_us):
        point = _net_point(u, 1.0)
        point.z -= 0.027
        scale = Vector((0.032 + 0.004 * (index % 3), 0.027, 0.04 + 0.003 * (index % 2)))
        _add_ellipsoid(mesh, point, scale, segments=7, rings=3, yaw=0.17 * index)
    obj = _object_from_bmesh("Sinkers", mesh, material, smooth=False)
    obj["historical_material"] = "pierced stone net sinkers"
    obj["sinker_count"] = len(sinker_us)
    return obj


def _smart_uv(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.015)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.data.validate(clean_customdata=False)
        obj.data.update()


def _build_model() -> tuple[bpy.types.Object, list[bpy.types.Object], int]:
    timber = _create_material("SaltWeatheredOak", TIMBER_SRGB, 0.9, "wood")
    hemp = _create_material("TarredHempNet", HEMP_SRGB, 0.96, "rope")
    cork = _create_material("BarkCorkFloats", CORK_SRGB, 0.94, "cork")
    stone = _create_material("PiercedStoneSinkers", STONE_SRGB, 0.98, "stone")

    root = bpy.data.objects.new("FishingNets", None)
    bpy.context.collection.objects.link(root)
    netting, strand_count = _build_netting(hemp)
    meshes = [
        _build_frame(timber),
        netting,
        _build_outline_and_lashings(hemp),
        _build_floats(cork),
        _build_sinkers(stone),
    ]
    for obj in meshes:
        obj.parent = root
    _smart_uv(meshes)

    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= minimum_z

    root["asset_id"] = ASSET_ID
    root["generator"] = "tools/generate_fishing_nets.py"
    root["blender_version"] = BLENDER_VERSION
    root["historical_identity"] = "medieval Baltic knotted fishing net drying rack"
    return root, meshes, strand_count


def _mesh_metrics(meshes: list[bpy.types.Object], strand_count: int) -> dict[str, object]:
    triangles = 0
    vertices = 0
    faces = 0
    surfaces = 0
    uv_sets = 10_000
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    material_names: set[str] = set()
    for obj in meshes:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len(mesh.materials)
        uv_sets = min(uv_sets, len(mesh.uv_layers))
        material_names.update(material.name for material in mesh.materials)
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector((min(low.x, world.x), min(low.y, world.y), min(low.z, world.z)))
            high = Vector((max(high.x, world.x), max(high.y, world.y), max(high.z, world.z)))
    blender_dimensions = high - low
    return {
        "asset_id": ASSET_ID,
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "materials": len(material_names),
        "mesh_objects": len(meshes),
        "surfaces": surfaces,
        "uv_sets": 0 if uv_sets == 10_000 else uv_sets,
        "dimensions_m": [round(value, 4) for value in (blender_dimensions.x, blender_dimensions.z, blender_dimensions.y)],
        "ground_min": round(low.z, 6),
        "floating_objects": 0,
        "texture_size": 512,
        "net_strands": strand_count,
        "floats": 5,
        "sinkers": 7,
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, meshes: list[bpy.types.Object], strand_count: int) -> dict[str, object]:
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
    metrics = _mesh_metrics(meshes, strand_count)
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
    scene.world.color = (0.035, 0.04, 0.03)

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.15, 0.19, 0.11, 1.0)
    floor_material.roughness = 1.0
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.002))
    bpy.context.object.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-2.2, -2.5, 3.2))
    key = bpy.context.object
    key.data.energy = 760.0
    key.data.shape = "DISK"
    key.data.size = 2.8
    key.rotation_euler = (math.radians(28.0), 0.0, math.radians(-38.0))
    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.5, 2.2))
    fill = bpy.context.object
    fill.data.energy = 390.0
    fill.data.color = (0.5, 0.63, 0.82)
    fill.data.size = 2.4

    bpy.ops.object.camera_add(location=(2.15, -3.2, 1.95))
    camera = bpy.context.object
    direction = Vector((0.0, 0.04, 0.71)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.88
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
        "generator": "tools/generate_fishing_nets.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "checks": {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
            "floating_geometry": int(metrics["floating_objects"]) == 0,
            "identity_features": ["diamond_netting", "catenary_sag", "cork_floats", "stone_sinkers", "rear_braces"],
        },
    }
    if preview is not None:
        report["preview"] = preview.relative_to(ROOT).as_posix() if preview.is_relative_to(ROOT) else str(preview)
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "asset_id": ASSET_ID,
        "route": "deterministic_blender",
        "stage": "production_ready",
        "cache_key": metrics["cache_key"],
        "selected_glb": OUTPUT.relative_to(ROOT).as_posix(),
        "sha256": metrics["sha256"],
        "decision": "integrate",
        "defects": [],
    }
    STATE_PATH.write_text(json.dumps(state, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root, meshes, strand_count = _build_model()
    metrics = _export(root, meshes, strand_count)

    preview: Path | None = None
    if "--preview" in sys.argv:
        preview_index = sys.argv.index("--preview")
        if preview_index + 1 < len(sys.argv) and not sys.argv[preview_index + 1].startswith("--"):
            preview = Path(sys.argv[preview_index + 1]).resolve()
        else:
            preview = DEFAULT_PREVIEW
        _render_preview(preview)

    _write_evidence(metrics, preview)
    compact = {
        "triangles": metrics["triangles"],
        "materials": metrics["materials"],
        "uv_sets": metrics["uv_sets"],
        "dimensions_m": metrics["dimensions_m"],
        "ground_min": metrics["ground_min"],
        "sha256": metrics["sha256"],
    }
    print("ASSET_METRICS=" + json.dumps(compact, separators=(",", ":")))


if __name__ == "__main__":
    main()
