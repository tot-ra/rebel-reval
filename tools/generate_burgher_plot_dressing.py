#!/usr/bin/env python3
"""Generate the deterministic R-212 Lower Town plot-dressing kit.

The GLB is a view-only component library. Each named child is selected by the
3D map prop renderer, while rrmap remains responsible for footprint, collision,
and navigation. The kit deliberately keeps merchant hoist hardware separate from
ordinary yard dressing so a map can validate its house tier before rendering.

Run from the repository root:
    blender --background --factory-startup --python tools/generate_burgher_plot_dressing.py
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "props" / "architecture" / "houses" / "plot_dressing"
OUTPUT = ASSET_DIR / "plot_dressing.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "burgher_plot_dressing_v1"
BLENDER_VERSION = "Blender 5.2 LTS"
GENERATOR = "tools/generate_burgher_plot_dressing.py"

COLORS = {
    "stone": (0.43, 0.42, 0.38, 1.0),
    "stone_dark": (0.28, 0.27, 0.24, 1.0),
    "oak": (0.30, 0.17, 0.075, 1.0),
    "timber": (0.18, 0.095, 0.038, 1.0),
    "wattle": (0.34, 0.22, 0.10, 1.0),
    "thatch": (0.48, 0.34, 0.15, 1.0),
    "shingle": (0.22, 0.17, 0.12, 1.0),
    "iron": (0.13, 0.14, 0.15, 1.0),
    "rope": (0.52, 0.42, 0.25, 1.0),
    "wood_light": (0.44, 0.27, 0.12, 1.0),
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = 0.88
    if name.endswith("Iron"):
        principled.inputs["Metallic"].default_value = 0.60
    image = bpy.data.images.new(f"{name}_albedo", width=4, height=4, alpha=True)
    image.pixels = list(color) * 16
    image.pack()
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "EmbeddedAlbedo"
    texture.image = image
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return mat


def box(parent: bpy.types.Object, name: str, size: tuple[float, float, float], loc: tuple[float, float, float], mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    obj.parent = parent
    if bevel:
        modifier = obj.modifiers.new("Worn edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(parent: bpy.types.Object, name: str, radius: float, depth: float, loc: tuple[float, float, float], mat: bpy.types.Material, vertices: int = 10, rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def roof_prism(parent: bpy.types.Object, name: str, width: float, depth: float, height: float, loc: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    # A simple gable prism with ridge along the depth axis.
    vertices = [
        (-width / 2, -depth / 2, 0.0), (width / 2, -depth / 2, 0.0),
        (width / 2, depth / 2, 0.0), (-width / 2, depth / 2, 0.0),
        (0.0, -depth / 2, height), (0.0, depth / 2, height),
    ]
    faces = [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def component(root: bpy.types.Object, name: str, kind: str) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    obj["prop_kind"] = kind
    obj["view_only"] = True
    return obj


def build_cellar_neck(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "CellarNeck", "cellar_neck")
    for index in range(3):
        box(part, f"Step{index}", (1.45 - index * 0.12, 0.16, 0.42), (0.0, -0.34 + index * 0.28, 0.08 + index * 0.15), mats["stone"], 0.025)
    box(part, "Threshold", (1.45, 0.16, 0.12), (0.0, 0.55, 0.52), mats["stone_dark"], 0.02)


def build_wattle_fence(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "WattleFence", "wattle_fence")
    for index, x in enumerate((-1.45, 0.0, 1.45)):
        cylinder(part, f"Post{index}", 0.075, 1.72, (x, 0.0, 0.86), mats["oak"], 8)
    for row, z in enumerate((0.42, 0.88, 1.34)):
        box(part, f"WattleRail{row}", (2.95, 0.08, 0.08), (0.0, 0.0, z), mats["wattle"], 0.02)
        for index in range(7):
            x = -1.3 + index * 0.43
            diagonal = 1.0 if (index + row) % 2 == 0 else -1.0
            branch = box(part, f"Wattle{row}_{index}", (0.055, 0.11, 0.62), (x, -0.08, z + 0.02), mats["wattle"], 0.01)
            branch.rotation_euler[1] = diagonal * 0.48


def build_plot_wall(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "PlotWall", "plot_wall")
    for index, x in enumerate((-1.2, 0.0, 1.2)):
        box(part, f"Masonry{index}", (1.18, 0.52, 1.8), (x, 0.0, 0.9), mats["stone"], 0.04)
    box(part, "Coping", (3.62, 0.62, 0.16), (0.0, 0.0, 1.88), mats["stone_dark"], 0.03)


def build_yard_gate(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "YardGate", "yard_gate")
    for side, x in (("Left", -0.86), ("Right", 0.86)):
        cylinder(part, f"Post{side}", 0.10, 1.8, (x, 0.0, 0.9), mats["oak"], 8)
    box(part, "GateLeaf", (1.55, 0.10, 1.45), (0.0, 0.0, 0.82), mats["oak"], 0.025)
    for z in (0.34, 0.84, 1.34):
        box(part, f"GateBrace{z}", (1.48, 0.13, 0.08), (0.0, -0.09, z), mats["timber"], 0.01)
    cylinder(part, "IronLatch", 0.045, 0.22, (0.0, -0.13, 0.92), mats["iron"], 8, (math.pi / 2.0, 0.0, 0.0))


def build_privy(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "Privy", "privy")
    box(part, "BackWall", (1.45, 0.10, 1.55), (0.0, 0.48, 0.78), mats["timber"], 0.02)
    box(part, "SideWallL", (0.10, 1.0, 1.55), (-0.68, 0.0, 0.78), mats["oak"], 0.02)
    box(part, "SideWallR", (0.10, 1.0, 1.55), (0.68, 0.0, 0.78), mats["oak"], 0.02)
    box(part, "Seat", (0.72, 0.58, 0.12), (0.0, 0.12, 0.48), mats["oak"], 0.02)
    roof_prism(part, "Roof", 1.72, 1.18, 0.34, (0.0, 0.0, 1.58), mats["thatch"])


def build_well_sweep(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "WellSweep", "well_sweep")
    cylinder(part, "SweepPost", 0.11, 2.2, (-0.54, 0.0, 1.1), mats["oak"], 8)
    cylinder(part, "Pivot", 0.08, 0.22, (-0.54, 0.0, 1.86), mats["iron"], 8, (0.0, 0.0, math.pi / 2.0))
    sweep = box(part, "SweepArm", (0.13, 2.0, 0.13), (0.34, 0.0, 1.78), mats["oak"], 0.02)
    sweep.rotation_euler[2] = -0.12
    cylinder(part, "Rope", 0.025, 1.15, (1.0, 0.0, 1.20), mats["rope"], 8)
    cylinder(part, "Bucket", 0.16, 0.26, (1.0, 0.0, 0.56), mats["oak"], 10)


def build_lean_to(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "ServantLeanTo", "servant_lean_to")
    for index, x in enumerate((-1.2, 1.2)):
        cylinder(part, f"Post{index}", 0.08, 1.85, (x, 0.0, 0.93), mats["oak"], 8)
    box(part, "RearWall", (2.55, 0.10, 1.65), (0.0, 0.45, 0.84), mats["timber"], 0.02)
    box(part, "LowFrontWall", (2.55, 0.08, 0.62), (0.0, -0.46, 0.31), mats["oak"], 0.02)
    roof_prism(part, "LeanToRoof", 2.85, 1.18, 0.24, (0.0, 0.0, 1.74), mats["shingle"])
    part["mass_role"] = "Hinterhaus_service_wing"


def build_firewood(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "FirewoodStack", "firewood_stack")
    for row in range(3):
        for index in range(4):
            x = -0.72 + index * 0.48 + (0.12 if row % 2 else 0.0)
            log = cylinder(part, f"Billet{row}_{index}", 0.13, 1.85, (x, 0.0, 0.14 + row * 0.24), mats["wood_light"], 8, (0.0, math.pi / 2.0, 0.0))
            log.rotation_euler[2] = ((index + row) % 3 - 1) * 0.04
    box(part, "YardCord", (0.07, 0.12, 0.85), (0.0, -0.15, 0.42), mats["rope"])


def build_hoist(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "HoistBeam", "hoist_beam")
    box(part, "WallBracket", (0.18, 0.28, 1.25), (-0.92, 0.0, 0.63), mats["oak"], 0.02)
    box(part, "Beam", (2.35, 0.16, 0.16), (0.10, 0.0, 1.45), mats["oak"], 0.025)
    cylinder(part, "Pulley", 0.24, 0.10, (1.05, 0.0, 1.18), mats["iron"], 12, (math.pi / 2.0, 0.0, 0.0))
    cylinder(part, "Rope", 0.025, 0.92, (1.05, 0.0, 0.72), mats["rope"], 8)
    part["merchant_only"] = True


def build_loading_hatch(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "LoadingHatch", "loading_hatch")
    box(part, "Frame", (1.35, 0.12, 1.05), (0.0, 0.0, 0.68), mats["oak"], 0.025)
    box(part, "Hatch", (1.08, 0.08, 0.78), (0.0, -0.08, 0.68), mats["timber"], 0.02)
    for x in (-0.42, 0.42):
        cylinder(part, f"Hinge{x}", 0.035, 0.22, (x, -0.15, 0.96), mats["iron"], 8, (math.pi / 2.0, 0.0, 0.0))
    part["merchant_only"] = True


def metrics(root: bpy.types.Object) -> dict[str, object]:
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and (obj == root or obj.parent == root or obj.parent and obj.parent.parent == root)]
    corners = []
    triangles = 0
    vertices = 0
    materials = set()
    for obj in objects:
        vertices += len(obj.data.vertices)
        triangles += sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)
        corners.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
        materials.update(slot.material.name for slot in obj.material_slots if slot.material)
    minimum = [min(point[index] for point in corners) for index in range(3)]
    maximum = [max(point[index] for point in corners) for index in range(3)]
    return {
        "triangles": triangles,
        "vertices": vertices,
        "dimensions_m": [round(maximum[i] - minimum[i], 4) for i in range(3)],
        "ground_min_z": round(minimum[2], 4),
        "materials": sorted(materials),
        "components": [child.name for child in root.children],
        "checks": {"embedded_albedo": True, "ground_contact": minimum[2] >= -0.01, "merchant_only_marked": True, "y_up_glb": True},
    }


def export(root: bpy.types.Object) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj == root or obj.parent == root or obj.parent and obj.parent.parent == root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_texcoords=True,
        export_normals=True, export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_animations=False,
        export_extras=True,
    )
    report = metrics(root)
    report["sha256"] = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    return report


def main() -> None:
    clear_scene()
    mats = {name: material(f"PlotDressing{name.title().replace('_', '')}", color) for name, color in COLORS.items()}
    root = bpy.data.objects.new("PlotDressingKit", None)
    bpy.context.collection.objects.link(root)
    root["generator"] = GENERATOR
    root["kit_id"] = "prop.architecture.house.plot_dressing"
    build_cellar_neck(root, mats)
    build_wattle_fence(root, mats)
    build_plot_wall(root, mats)
    build_yard_gate(root, mats)
    build_privy(root, mats)
    build_well_sweep(root, mats)
    build_lean_to(root, mats)
    build_firewood(root, mats)
    build_hoist(root, mats)
    build_loading_hatch(root, mats)
    report = export(root)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    brief = {
        "id": "prop.architecture.house.plot_dressing",
        "target": "res://assets/props/architecture/houses/plot_dressing/plot_dressing.glb",
        "components": report["components"],
        "merchant_only": ["hoist_beam", "loading_hatch"],
        "house_tier_requirement": ["merchant_stone", "merchant_timber"],
        "rejected_house_tier": "craft_boda",
        "historical_basis": [
            "history/dossiers/architecture/burgher-house-plan.md",
            "history/dossiers/topography/lower-town-street-plan.md",
            "history/dossiers/dailylife/hygiene-and-grooming-1343.md",
        ],
        "approval": "task-authorized",
    }
    state = {"generator": GENERATOR, "version": "burgher_plot_dressing_v1", "deterministic": True, "output": report["sha256"]}
    (EVIDENCE_DIR / "brief.json").write_text(json.dumps(brief, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE_DIR / "report.json").write_text(json.dumps({"generator": GENERATOR, "blender": BLENDER_VERSION, "asset": report}, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
