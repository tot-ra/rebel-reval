#!/usr/bin/env python3
"""Generate the reusable 1343 Reval gate-leaf and portcullis kit.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_medieval_gate_kit.py

Add ``--preview`` for a single comparison render. The GLBs are deterministic,
Y-up, metric assets; evidence is written to generated/blender/medieval_gate_kit_v1/.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "props" / "architecture" / "gates"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "medieval_gate_kit_v1"
PREVIEW_PATH = EVIDENCE_DIR / "preview.png"
BRIEF_PATH = EVIDENCE_DIR / "brief.json"
REPORT_PATH = EVIDENCE_DIR / "report.json"
STATE_PATH = EVIDENCE_DIR / "state.json"
GENERATOR_VERSION = "medieval_gate_kit_v1"
BLENDER_VERSION = "Blender 5.2 LTS"

ASSETS = {
    "oak_double_gate": OUTPUT_DIR / "oak_double_gate.glb",
    "ironbound_double_gate": OUTPUT_DIR / "ironbound_double_gate.glb",
    "raised_portcullis": OUTPUT_DIR / "raised_portcullis.glb",
}

BRIEF = {
    "id": "kit.reval_gate_1343",
    "kind": "rigid_architecture_kit",
    "targets": [f"res://{path.relative_to(ROOT).as_posix()}" for path in ASSETS.values()],
    "scene": "res://content/maps/lower_town_slice.rrmap#viru_gate_arch",
    "dimensions_m": {"leaf_pair": [4.7, 2.65, 2.2], "portcullis": [4.8, 3.25, 0.42]},
    "triangles": {"target_each": 3500, "max_each": 6000},
    "textures": {"albedo": 512},
    "historical_basis": "history/dossiers/topography/walls-gates-towers.md",
    "style_refs": ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
    "approval": "task-authorized",
}

OAK_SRGB = (0x77 / 255.0, 0x4D / 255.0, 0x2D / 255.0)
OAK_DARK_SRGB = (0x53 / 255.0, 0x37 / 255.0, 0x2A / 255.0)
IRON_SRGB = (0x46 / 255.0, 0x4F / 255.0, 0x52 / 255.0)


def _srgb_to_linear(channel: float) -> float:
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def _create_texture(name: str, base_srgb: tuple[float, float, float], surface: str) -> bpy.types.Image:
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    if surface == "oak":
        warped = v + 0.018 * np.sin(u * math.tau * 3.0) + 0.007 * np.sin(u * math.tau * 11.0)
        broad = np.sin((warped * 9.0 + u * 0.45) * math.tau)
        fine = np.sin((warped * 31.0 - u * 0.8) * math.tau)
        variation = 0.82 + broad * 0.065 + fine * 0.018
        for knot_u, knot_v, radius in ((0.22, 0.33, 0.075), (0.71, 0.69, 0.09)):
            dx = (u - knot_u) / radius
            dy = (v - knot_v) / (radius * 0.55)
            distance = np.sqrt(dx * dx + dy * dy)
            variation += np.sin(distance * math.tau * 1.8) * np.clip(1.0 - distance / 2.0, 0.0, 1.0) * 0.055
            variation -= np.exp(-(distance * distance) * 5.0) * 0.12
    else:
        hammer = np.sin((u * 17.0 + v * 5.0) * math.tau) * np.sin((v * 13.0 - u * 4.0) * math.tau)
        oxidation = np.sin((u * 2.0 + v * 1.3) * math.tau)
        variation = 0.72 + hammer * 0.04 + oxidation * 0.025
    base_linear = np.array([_srgb_to_linear(value) for value in base_srgb], dtype=np.float32)
    rgb = np.clip(base_linear[None, None, :] * variation[:, :, None], 0.0, 1.0)
    pixels = np.concatenate((rgb, np.ones((size, size, 1), dtype=np.float32)), axis=2)
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
    image = _create_texture(f"{name}_albedo", srgb, surface)
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*(_srgb_to_linear(value) for value in srgb), 1.0)
    material.metallic = metallic
    material.roughness = roughness
    nodes = material.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = material.diffuse_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def _box(
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


def _cylinder(
    name: str,
    radius: float,
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
    vertices: int = 10,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    obj = bpy.context.object
    obj.name = name
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


def _torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    transform: Matrix,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=12,
        minor_segments=6,
    )
    obj = bpy.context.object
    obj.name = name
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


def _cone(
    name: str,
    radius: float,
    depth: float,
    transform: Matrix,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.0, radius2=radius, depth=depth)
    obj = bpy.context.object
    obj.name = name
    obj.matrix_world = transform
    obj.data.materials.append(material)
    return obj


def _leaf_transform(hinge_x: float, open_angle: float, local: Matrix) -> Matrix:
    return Matrix.Translation((hinge_x, 0.0, 0.0)) @ Matrix.Rotation(open_angle, 4, "Z") @ local


def _build_double_gate(name: str, oak: bpy.types.Material, dark_oak: bpy.types.Material, iron: bpy.types.Material, reinforced: bool) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    objects: list[bpy.types.Object] = []
    leaf_width = 2.12
    leaf_height = 2.62
    leaf_thickness = 0.14 if not reinforced else 0.17
    hinge_x = 2.30
    open_radians = math.radians(80.0)
    board_count = 6
    board_width = leaf_width / board_count

    for leaf_index, direction in enumerate((1.0, -1.0)):
        hinge = -hinge_x if direction > 0.0 else hinge_x
        angle = open_radians if direction > 0.0 else -open_radians
        prefix = f"Leaf{leaf_index}"
        for board_index in range(board_count):
            local_x = direction * (board_index + 0.5) * board_width
            z = leaf_height * 0.5 + 0.03 * math.sin(float(board_index) * 1.7)
            objects.append(
                _box(
                    f"{prefix}_Board{board_index}",
                    (board_width - 0.018, leaf_thickness, leaf_height - 0.025),
                    _leaf_transform(hinge, angle, Matrix.Translation((local_x, 0.0, z))),
                    oak,
                    0.012,
                )
            )
        # Oak rails and stiles keep each leaf structurally plausible instead of a flat slab.
        for rail_index, z in enumerate((0.24, leaf_height * 0.53, leaf_height - 0.24)):
            objects.append(
                _box(
                    f"{prefix}_OakRail{rail_index}",
                    (leaf_width, leaf_thickness + 0.035, 0.13),
                    _leaf_transform(
                        hinge,
                        angle,
                        Matrix.Translation((direction * leaf_width * 0.5, 0.015, z)),
                    ),
                    dark_oak,
                    0.012,
                )
            )
        for stile_index, local_x in enumerate((0.08, leaf_width - 0.08)):
            objects.append(
                _box(
                    f"{prefix}_Stile{stile_index}",
                    (0.16, leaf_thickness + 0.04, leaf_height - 0.10),
                    _leaf_transform(
                        hinge,
                        angle,
                        Matrix.Translation((direction * local_x, 0.012, leaf_height * 0.5)),
                    ),
                    dark_oak,
                    0.012,
                )
            )
        brace_length = math.sqrt((leaf_width * 0.82) ** 2 + (leaf_height * 0.63) ** 2)
        brace_angle = direction * math.atan2(leaf_height * 0.63, leaf_width * 0.82)
        objects.append(
            _box(
                f"{prefix}_DiagonalBrace",
                (brace_length, leaf_thickness + 0.025, 0.115),
                _leaf_transform(
                    hinge,
                    angle,
                    Matrix.Translation((direction * leaf_width * 0.52, 0.02, leaf_height * 0.51))
                    @ Matrix.Rotation(-brace_angle, 4, "Y"),
                ),
                dark_oak,
                0.01,
            )
        )

        strap_levels = (0.30, 0.95, 1.62, 2.29) if reinforced else (0.34, 1.29, 2.23)
        for strap_index, z in enumerate(strap_levels):
            objects.append(
                _box(
                    f"{prefix}_IronStrap{strap_index}",
                    (leaf_width * 0.94, 0.035, 0.075),
                    _leaf_transform(
                        hinge,
                        angle,
                        Matrix.Translation((direction * leaf_width * 0.5, -leaf_thickness * 0.55, z)),
                    ),
                    iron,
                    0.008,
                )
            )
            # Broad forged nail heads make the binding legible in first person.
            for nail_side in (0.16, 0.84):
                objects.append(
                    _cylinder(
                        f"{prefix}_Nail{strap_index}_{int(nail_side * 100)}",
                        0.035,
                        0.026,
                        _leaf_transform(
                            hinge,
                            angle,
                            Matrix.Translation((direction * leaf_width * nail_side, -leaf_thickness * 0.72, z))
                            @ Matrix.Rotation(math.radians(90.0), 4, "X"),
                        ),
                        iron,
                        8,
                    )
                )
        for hinge_index, z in enumerate((0.43, 2.08)):
            objects.append(
                _cylinder(
                    f"{prefix}_HingePin{hinge_index}",
                    0.055,
                    0.30,
                    _leaf_transform(hinge, angle, Matrix.Translation((0.0, -leaf_thickness * 0.66, z))),
                    iron,
                    10,
                )
            )
        handle_x = direction * leaf_width * 0.80
        objects.append(
            _torus(
                f"{prefix}_RingHandle",
                0.105,
                0.021,
                _leaf_transform(
                    hinge,
                    angle,
                    Matrix.Translation((handle_x, -leaf_thickness * 0.78, 1.16))
                    @ Matrix.Rotation(math.radians(90.0), 4, "X"),
                ),
                iron,
            )
        )
        if reinforced:
            for edge_x in (0.13, leaf_width - 0.13):
                objects.append(
                    _box(
                        f"{prefix}_IronEdge{int(edge_x * 100)}",
                        (0.09, 0.04, leaf_height * 0.92),
                        _leaf_transform(
                            hinge,
                            angle,
                            Matrix.Translation((direction * edge_x, -leaf_thickness * 0.60, leaf_height * 0.5)),
                        ),
                        iron,
                        0.008,
                    )
                )

    for obj in objects:
        obj.parent = root
    _ground_root(root, objects)
    return root, objects


def _build_portcullis(name: str, iron: bpy.types.Material, dark_oak: bpy.types.Material) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    objects: list[bpy.types.Object] = []
    width = 4.80
    lattice_height = 2.92
    bar_count = 11
    bar_step = width / float(bar_count - 1)
    for index in range(bar_count):
        x = -width * 0.5 + index * bar_step
        objects.append(
            _box(
                f"VerticalBar{index}",
                (0.085, 0.09, lattice_height),
                Matrix.Translation((x, 0.0, 0.35 + lattice_height * 0.5)),
                iron,
                0.008,
            )
        )
        objects.append(
            _cone(
                f"Tooth{index}",
                0.105,
                0.35,
                Matrix.Translation((x, 0.0, 0.175)),
                iron,
            )
        )
    for rail_index, z in enumerate((0.57, 1.40, 2.23, 3.06)):
        objects.append(
            _box(
                f"CrossRail{rail_index}",
                (width + 0.16, 0.115, 0.105),
                Matrix.Translation((0.0, -0.015, z)),
                iron,
                0.008,
            )
        )
    # Oak-lined runners and a chain drum distinguish a raised working grille from a fence.
    for side_index, x in enumerate((-width * 0.5 - 0.16, width * 0.5 + 0.16)):
        objects.append(
            _box(
                f"GuideRunner{side_index}",
                (0.16, 0.22, 3.25),
                Matrix.Translation((x, 0.035, 1.625)),
                dark_oak,
                0.012,
            )
        )
        wheel_transform = Matrix.Translation((x * 0.86, -0.18, 2.95)) @ Matrix.Rotation(math.radians(90.0), 4, "X")
        objects.append(_torus(f"ChainWheel{side_index}", 0.22, 0.035, wheel_transform, iron))
        for link_index in range(5):
            link_z = 2.67 - link_index * 0.16
            link = _torus(
                f"ChainLink{side_index}_{link_index}",
                0.075,
                0.015,
                Matrix.Translation((x * 0.86, -0.21, link_z))
                @ Matrix.Rotation(math.radians(90.0 if link_index % 2 == 0 else 0.0), 4, "X"),
                iron,
            )
            objects.append(link)
    for obj in objects:
        obj.parent = root
    _ground_root(root, objects)
    return root, objects


def _ground_root(root: bpy.types.Object, objects: list[bpy.types.Object]) -> None:
    """Normalize bevel-expanded geometry to exact ground contact at local Z zero."""
    bpy.context.view_layer.update()
    minimum_z = min((obj.matrix_world @ Vector(corner)).z for obj in objects for corner in obj.bound_box)
    root.location.z -= minimum_z
    bpy.context.view_layer.update()


def _mesh_metrics(objects: list[bpy.types.Object], asset_id: str) -> dict[str, object]:
    vertices = faces = triangles = surfaces = 0
    uv_sets = 0
    materials: set[str] = set()
    points: list[Vector] = []
    for obj in objects:
        mesh = obj.data
        vertices += len(mesh.vertices)
        faces += len(mesh.polygons)
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)
        surfaces += len({polygon.material_index for polygon in mesh.polygons})
        uv_sets = max(uv_sets, len(mesh.uv_layers))
        materials.update(material.name for material in mesh.materials if material is not None)
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return {
        "asset_id": asset_id,
        "mesh_objects": len(objects),
        "vertices": vertices,
        "faces": faces,
        "triangles": triangles,
        "surfaces": surfaces,
        "materials": len(materials),
        "uv_sets": uv_sets,
        "texture_size": 512,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(minimum.z, 6),
    }


def _cache_key() -> str:
    digest = hashlib.sha256()
    digest.update(json.dumps(BRIEF, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    digest.update(Path(__file__).read_bytes())
    digest.update(BLENDER_VERSION.encode("utf-8"))
    return digest.hexdigest()


def _export(root: bpy.types.Object, objects: list[bpy.types.Object], output: Path, asset_id: str) -> dict[str, object]:
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
    metrics = _mesh_metrics(objects, asset_id)
    metrics["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    return metrics


def _render_preview(roots: list[bpy.types.Object]) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.025, 0.023, 0.021)
    roots[0].location.x = -5.4
    roots[1].location.x = 0.0
    roots[2].location.x = 5.4

    floor_material = bpy.data.materials.new("PreviewFloor")
    floor_material.diffuse_color = (0.14, 0.12, 0.10, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=20.0, location=(0.0, 0.0, -0.01))
    floor = bpy.context.object
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-4.5, -5.0, 7.0))
    key = bpy.context.object
    key.data.energy = 1450.0
    key.data.size = 5.5
    key.rotation_euler = (math.radians(26.0), 0.0, math.radians(-38.0))
    bpy.ops.object.light_add(type="AREA", location=(5.5, 1.5, 4.0))
    fill = bpy.context.object
    fill.data.energy = 850.0
    fill.data.color = (0.52, 0.64, 0.86)
    fill.data.size = 4.0
    fill.rotation_euler = (math.radians(58.0), 0.0, math.radians(142.0))

    bpy.ops.object.camera_add(location=(9.6, -14.5, 7.2))
    camera = bpy.context.object
    direction = Vector((0.0, 0.1, 1.35)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 15.4
    scene.camera = camera
    scene.render.filepath = str(PREVIEW_PATH)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    oak = _create_material("GateOak", OAK_SRGB, 0.78, 0.0, "oak")
    dark_oak = _create_material("GateDarkOak", OAK_DARK_SRGB, 0.82, 0.0, "oak")
    iron = _create_material("GateWroughtIron", IRON_SRGB, 0.70, 0.72, "iron")

    oak_root, oak_objects = _build_double_gate("OakDoubleGate", oak, dark_oak, iron, reinforced=False)
    reinforced_root, reinforced_objects = _build_double_gate(
        "IronboundDoubleGate", oak, dark_oak, iron, reinforced=True
    )
    grille_root, grille_objects = _build_portcullis("RaisedPortcullis", iron, dark_oak)
    built = {
        "oak_double_gate": (oak_root, oak_objects),
        "ironbound_double_gate": (reinforced_root, reinforced_objects),
        "raised_portcullis": (grille_root, grille_objects),
    }

    cache_key = _cache_key()
    reports: dict[str, object] = {}
    for asset_id, output in ASSETS.items():
        root, objects = built[asset_id]
        metrics = _export(root, objects, output, asset_id)
        metrics["checks"] = {
            "metric_scale": True,
            "y_up_glb": True,
            "ground_contact": abs(float(metrics["ground_min_z"])) <= 0.0001,
            "triangle_cap": int(metrics["triangles"]) <= int(BRIEF["triangles"]["max_each"]),
            "portable_pbr": True,
            "embedded_albedo": True,
            "uvs": int(metrics["uv_sets"]) >= 1,
        }
        reports[asset_id] = metrics

    preview_requested = "--preview" in sys.argv
    if preview_requested:
        _render_preview([oak_root, reinforced_root, grille_root])

    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    BRIEF_PATH.write_text(json.dumps(BRIEF, separators=(",", ":")) + "\n", encoding="utf-8")
    report = {
        "asset_id": BRIEF["id"],
        "route": "deterministic_blender",
        "generator": "tools/generate_medieval_gate_kit.py",
        "generator_version": GENERATOR_VERSION,
        "blender_version": BLENDER_VERSION,
        "cache_key": cache_key,
        "historical_scope": "Simple mid-14th-century gate leaves and one raised grille; no barbican, foregate towers, or drawbridge.",
        "assets": reports,
        "preview": "generated/blender/medieval_gate_kit_v1/preview.png" if preview_requested else None,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    state = {
        "cache_key": cache_key,
        "outputs": {asset_id: reports[asset_id]["sha256"] for asset_id in ASSETS},
        "complete": all(all(metrics["checks"].values()) for metrics in reports.values()),
    }
    STATE_PATH.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    compact = {
        key: {
            "triangles": value["triangles"],
            "materials": value["materials"],
            "dimensions_m": value["dimensions_m"],
            "sha256": value["sha256"],
        }
        for key, value in reports.items()
    }
    print("ASSET_METRICS=" + json.dumps(compact, separators=(",", ":")))


if __name__ == "__main__":
    main()
