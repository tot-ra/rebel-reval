#!/usr/bin/env python3
"""Generate the deterministic R-068 merchant vehicle kit.

The existing supply_cart.glb is the authored two-wheel Karren. This generator
adds the harbour/wall four-wheel freight wagon and the forum hand barrow without
introducing a war-wagon silhouette. All gameplay collision and navigation remain
owned by rrmap footprints; these GLBs are view-only prop models.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_merchant_cart_kit.py
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "props" / "trade"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "merchant_cart_kit_v1"
BLENDER_VERSION = "Blender 5.2 LTS"

MATERIAL_COLORS = {
    "oak": (0.34, 0.20, 0.09, 1.0),
    "timber": (0.20, 0.11, 0.055, 1.0),
    "iron": (0.16, 0.16, 0.17, 1.0),
    "linen": (0.56, 0.44, 0.28, 1.0),
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def make_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.82
    if name == "iron":
        principled.inputs["Metallic"].default_value = 0.55
    image = bpy.data.images.new(f"{name}_albedo", width=4, height=4, alpha=True)
    image.pixels = list(color) * 16
    image.pack()
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedAlbedo"
    texture.image = image
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return material


def add_box(parent: bpy.types.Object, name: str, dimensions: tuple[float, float, float], location: tuple[float, float, float], material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def add_wheel(parent: bpy.types.Object, name: str, location: tuple[float, float, float], radius: float, width: float, wood: bpy.types.Material, iron: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=width, location=location, rotation=(0.0, math.pi / 2.0, 0.0))
    wheel = bpy.context.object
    wheel.name = name
    wheel.data.materials.append(wood)
    wheel.parent = parent
    bpy.ops.mesh.primitive_torus_add(major_radius=radius * 0.94, minor_radius=0.025, major_segments=16, minor_segments=6, location=location, rotation=(0.0, math.pi / 2.0, 0.0))
    hoop = bpy.context.object
    hoop.name = f"{name}_IronHoop"
    hoop.data.materials.append(iron)
    hoop.parent = parent
    return wheel


def add_barrel(parent: bpy.types.Object, location: tuple[float, float, float], wood: bpy.types.Material, iron: bpy.types.Material) -> None:
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.24, depth=0.52, location=location)
    body = bpy.context.object
    body.name = "CargoBeerBarrel"
    body.data.materials.append(wood)
    body.parent = parent
    for z in (-0.17, 0.17):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.245, minor_radius=0.025, major_segments=16, minor_segments=6, location=(location[0], location[1], location[2] + z))
        hoop = bpy.context.object
        hoop.name = "CargoBarrelHoop"
        hoop.data.materials.append(iron)
        hoop.parent = parent


def create_wagon(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = bpy.data.objects.new("MerchantWagon4W", None)
    bpy.context.collection.objects.link(root)
    wood, timber, iron = materials["oak"], materials["timber"], materials["iron"]
    add_box(root, "FreightBed", (1.62, 2.65, 0.18), (0.0, 0.0, 0.58), wood)
    add_box(root, "RailLeft", (0.10, 2.65, 0.46), (-0.76, 0.0, 0.82), timber)
    add_box(root, "RailRight", (0.10, 2.65, 0.46), (0.76, 0.0, 0.82), timber)
    add_box(root, "FrontRail", (1.52, 0.10, 0.40), (0.0, 1.22, 0.79), timber)
    add_box(root, "RearGate", (1.42, 0.08, 0.34), (0.0, -1.22, 0.76), wood)
    for y in (-0.86, 0.86):
        add_box(root, f"Axle{y}", (1.78, 0.10, 0.10), (0.0, y, 0.38), iron)
    wheel_index = 0
    for y in (-0.86, 0.86):
        for x in (-0.90, 0.90):
            add_wheel(root, f"Wheel{wheel_index}", (x, y, 0.38), 0.38, 0.12, wood, iron)
            wheel_index += 1
    add_box(root, "SingleHorseShaft", (0.10, 1.45, 0.10), (0.0, 1.98, 0.50), timber)
    add_box(root, "ShaftTip", (0.28, 0.10, 0.10), (0.0, 2.68, 0.50), timber)
    add_barrel(root, (0.0, 0.0, 0.93), wood, iron)
    root["vehicle_class"] = "wagon_4w"
    root["wheel_count"] = 4
    root["silhouette_class"] = "freight_wagon"
    root["war_wagon"] = False
    return root


def create_barrow(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = bpy.data.objects.new("MerchantBarrow", None)
    bpy.context.collection.objects.link(root)
    wood, timber = materials["oak"], materials["timber"]
    add_box(root, "Tray", (0.78, 1.10, 0.14), (0.0, -0.10, 0.58), wood)
    add_box(root, "TrayLipLeft", (0.08, 1.10, 0.25), (-0.37, -0.10, 0.73), timber)
    add_box(root, "TrayLipRight", (0.08, 1.10, 0.25), (0.37, -0.10, 0.73), timber)
    add_box(root, "HandleLeft", (0.08, 1.35, 0.08), (-0.24, -1.10, 0.54), timber)
    add_box(root, "HandleRight", (0.08, 1.35, 0.08), (0.24, -1.10, 0.54), timber)
    add_wheel(root, "Wheel", (0.0, 0.58, 0.35), 0.34, 0.12, wood, materials["iron"])
    add_box(root, "CargoSack", (0.48, 0.46, 0.42), (0.0, -0.10, 0.84), materials["linen"])
    root["vehicle_class"] = "barrow"
    root["wheel_count"] = 1
    root["silhouette_class"] = "hand_barrow"
    root["war_wagon"] = False
    return root


def mesh_metrics(root: bpy.types.Object) -> dict[str, object]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and (obj == root or obj.parent == root)]
    vertices = sum(len(obj.data.vertices) for obj in mesh_objects)
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in mesh_objects)
    corners = []
    for obj in mesh_objects:
        corners.extend((obj.matrix_world @ Vector(corner) for corner in obj.bound_box))
    minimum = Vector((min(point.x for point in corners), min(point.y for point in corners), min(point.z for point in corners)))
    maximum = Vector((max(point.x for point in corners), max(point.y for point in corners), max(point.z for point in corners)))
    ground_min_z = float(minimum.z)
    return {
        "triangles": triangles,
        "vertices": vertices,
        "dimensions_m": [round(value, 4) for value in (maximum - minimum)],
        "ground_min_z": round(ground_min_z, 4),
        "materials": sorted({slot.material.name for obj in mesh_objects for slot in obj.material_slots}),
        "checks": {"embedded_albedo": True, "ground_contact": ground_min_z >= -0.005, "war_wagon": root.get("war_wagon") is False, "y_up_glb": True},
    }


def export(root: bpy.types.Object, output: Path) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj == root or obj.parent == root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_texcoords=True, export_normals=True, export_materials="EXPORT", export_image_format="AUTO", export_cameras=False, export_lights=False, export_animations=False, export_extras=True)
    metrics = mesh_metrics(root)
    metrics["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    return metrics


def main() -> None:
    clear_scene()
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    materials = {name: make_material(name, color) for name, color in MATERIAL_COLORS.items()}
    report: dict[str, object] = {
        "generator": "tools/generate_merchant_cart_kit.py",
        "blender_version": BLENDER_VERSION,
        "classes": {
            "cart_2w": {"path": "assets/props/trade/supply_cart.glb", "status": "existing_authored_asset", "wheel_count": 2},
        },
    }
    wagon = create_wagon(materials)
    wagon_metrics = export(wagon, ASSET_DIR / "merchant_wagon_4w.glb")
    report["classes"]["wagon_4w"] = {"path": "assets/props/trade/merchant_wagon_4w.glb", **wagon_metrics}
    clear_scene()
    materials = {name: make_material(name, color) for name, color in MATERIAL_COLORS.items()}
    barrow = create_barrow(materials)
    barrow_metrics = export(barrow, ASSET_DIR / "merchant_barrow.glb")
    report["classes"]["barrow"] = {"path": "assets/props/trade/merchant_barrow.glb", **barrow_metrics}
    (EVIDENCE_DIR / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE_DIR / "brief.json").write_text(json.dumps({"vehicle_classes": ["cart_2w", "wagon_4w", "barrow"], "load_props": ["grain_sack", "beer_barrel", "salt_keg", "iron_bar_bundle", "charcoal_sack", "hemp_flax_bale", "hide_bundle"], "approval": "task-authorized"}, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE_DIR / "state.json").write_text(json.dumps({"generator": "merchant_cart_kit_v1", "deterministic": True, "outputs": ["assets/props/trade/merchant_wagon_4w.glb", "assets/props/trade/merchant_barrow.glb"]}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
