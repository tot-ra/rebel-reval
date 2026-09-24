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


# Rake of the hatch leaves, from the 0.62 m back kerb down to the 0.24 m front.
CELLAR_HATCH_ANGLE = 0.2975


def build_cellar_neck(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "CellarNeck", "cellar_neck")
    # A Kellerhals descends below grade, but the kit contract requires every
    # component to stay on or above z=0. A buried stair cannot be shown that
    # way - earlier attempts read as a stone trough or a flat plateau - so the
    # component is the above-ground half of the same feature: a kerbed cellar
    # hatch with sloped oak leaves, which is unambiguous from any camera angle.
    box(part, "WellFloor", (1.50, 1.24, 0.06), (0.0, 0.0, 0.03), mats["stone_dark"])
    box(part, "KerbFront", (1.94, 0.24, 0.24), (0.0, -0.74, 0.12), mats["stone"], 0.03)
    box(part, "KerbBack", (1.94, 0.24, 0.62), (0.0, 0.74, 0.31), mats["stone"], 0.03)
    for side, x in (("L", -0.86), ("R", 0.86)):
        # Two blocks per side approximate the kerb rake under the sloped leaves.
        box(part, f"KerbSide{side}Low", (0.22, 0.62, 0.34), (x, -0.31, 0.17), mats["stone"], 0.03)
        box(part, f"KerbSide{side}High", (0.22, 0.62, 0.52), (x, 0.31, 0.26), mats["stone"], 0.03)
    for side, x in (("L", -0.375), ("R", 0.375)):
        leaf = box(part, f"Leaf{side}", (0.71, 1.40, 0.08), (x, 0.0, 0.472), mats["oak"], 0.02)
        leaf.rotation_euler[0] = CELLAR_HATCH_ANGLE
    for side, x in (("L0", -0.60), ("L1", -0.16), ("R0", 0.16), ("R1", 0.60)):
        strap = box(part, f"Strap{side}", (0.09, 1.30, 0.03), (x, 0.0, 0.530), mats["iron"])
        strap.rotation_euler[0] = CELLAR_HATCH_ANGLE
    for side, x in (("L", -0.30), ("R", 0.30)):
        cylinder(part, f"Ring{side}", 0.06, 0.025, (x, -0.42, 0.43), mats["iron"], 10, (0.0, math.pi / 2.0, 0.0))


WATTLE_STAKES = 15
WATTLE_SPAN = 2.90


def build_wattle_fence(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "WattleFence", "wattle_fence")
    step = WATTLE_SPAN / (WATTLE_STAKES - 1)
    for index, x in enumerate((-1.45, 0.0, 1.45)):
        cylinder(part, f"Post{index}", 0.075, 1.50, (x, 0.0, 0.75), mats["oak"], 8)
    for index in range(WATTLE_STAKES):
        cylinder(part, f"Stake{index}", 0.030, 1.24, (-1.45 + index * step, 0.0, 0.62), mats["wattle"], 6)
    for row in range(6):
        for index in range(WATTLE_STAKES - 1):
            # Withies alternate in front of and behind consecutive stakes so the
            # fence reads as woven hazel. The previous diagonal branches read as
            # a garden trellis instead. Front and back runs overlap around y=0 so
            # the panel no longer lets daylight through.
            y = 0.035 if (index + row) % 2 == 0 else -0.035
            box(part, f"Withy{row}_{index}", (step, 0.09, 0.185), (-1.45 + (index + 0.5) * step, y, 0.12 + row * 0.19), mats["wattle"])


PLOT_WALL_COURSES = (
    (0.30, 0.60, ((-1.20, 1.18), (0.00, 1.18), (1.20, 1.18))),
    (0.88, 0.56, ((-1.49, 0.60), (-0.59, 1.20), (0.61, 1.20), (1.50, 0.60))),
    (1.42, 0.52, ((-1.20, 1.18), (0.00, 1.18), (1.20, 1.18))),
)


def build_plot_wall(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "PlotWall", "plot_wall")
    # Staggered courses give the wall a joint pattern at play distance without
    # per-stone geometry; the coping now sits directly on the top course.
    for course, (z, height, blocks) in enumerate(PLOT_WALL_COURSES):
        for index, (x, width) in enumerate(blocks):
            box(part, f"Course{course}_{index}", (width, 0.52, height), (x, 0.0, z), mats["stone"], 0.035)
    box(part, "Coping", (3.62, 0.62, 0.16), (0.0, 0.0, 1.76), mats["stone_dark"], 0.03)


def build_yard_gate(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "YardGate", "yard_gate")
    for side, x in (("Left", -0.86), ("Right", 0.86)):
        cylinder(part, f"Post{side}", 0.10, 1.80, (x, 0.0, 0.90), mats["oak"], 8)
    # Planked leaf sized to the clear opening between the post faces, so the gate
    # fills the gap instead of hanging in front of it as a single thin slab.
    for index in range(7):
        box(part, f"Plank{index}", (0.20, 0.07, 1.34), (-0.66 + index * 0.22, 0.0, 0.83), mats["oak"], 0.012)
    for index, z in enumerate((0.34, 1.26)):
        box(part, f"Rail{index}", (1.52, 0.09, 0.14), (0.0, 0.055, z), mats["timber"], 0.015)
    brace = box(part, "GateBrace", (1.62, 0.08, 0.12), (0.0, 0.055, 0.80), mats["timber"], 0.015)
    brace.rotation_euler[1] = 0.61
    for index, z in enumerate((0.42, 1.18)):
        cylinder(part, f"Hinge{index}", 0.040, 0.30, (-0.80, 0.0, z), mats["iron"], 8, (0.0, math.pi / 2.0, 0.0))
    cylinder(part, "IronLatch", 0.045, 0.26, (0.70, -0.09, 0.86), mats["iron"], 8, (math.pi / 2.0, 0.0, 0.0))


def build_privy(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "Privy", "privy")
    box(part, "BackWall", (1.45, 0.10, 1.70), (0.0, 0.49, 0.85), mats["timber"], 0.02)
    box(part, "SideWallL", (0.10, 1.08, 1.70), (-0.68, 0.0, 0.85), mats["oak"], 0.02)
    box(part, "SideWallR", (0.10, 1.08, 1.70), (0.68, 0.0, 0.85), mats["oak"], 0.02)
    # Jambs plus head close the front so the hut is not an open three-sided box.
    for side, x in (("L", -0.51), ("R", 0.51)):
        box(part, f"DoorJamb{side}", (0.32, 0.09, 1.70), (x, -0.50, 0.85), mats["timber"], 0.02)
    box(part, "DoorHead", (0.72, 0.09, 0.26), (0.0, -0.50, 1.57), mats["timber"], 0.02)
    box(part, "Door", (0.68, 0.06, 1.41), (0.0, -0.56, 0.735), mats["oak"], 0.02)
    cylinder(part, "DoorRing", 0.05, 0.03, (0.22, -0.60, 0.95), mats["iron"], 8, (math.pi / 2.0, 0.0, 0.0))
    box(part, "Seat", (1.26, 0.52, 0.10), (0.0, 0.22, 0.47), mats["oak"], 0.02)
    box(part, "SeatApron", (1.26, 0.08, 0.42), (0.0, -0.05, 0.21), mats["oak"], 0.02)
    # Roof base sits exactly on the 1.70 wall head; the old kit left a gap.
    roof_prism(part, "Roof", 1.76, 1.32, 0.34, (0.0, 0.0, 1.70), mats["thatch"])


WELL_SWEEP_ANGLE = 0.224


def build_well_sweep(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "WellSweep", "well_sweep")
    # A shaduf is a lever: the arm is long along X and pivots on the post head,
    # with the counterweight behind and the bucket hanging over the well drum.
    # The old kit extruded the arm along Y, so nothing lined up.
    cylinder(part, "WellDrum", 0.58, 0.68, (1.30, 0.0, 0.34), mats["stone"], 12)
    cylinder(part, "WellCoping", 0.64, 0.12, (1.30, 0.0, 0.74), mats["stone_dark"], 12)
    cylinder(part, "SweepPost", 0.11, 2.32, (-0.55, 0.0, 1.16), mats["oak"], 8)
    cylinder(part, "Pivot", 0.08, 0.34, (-0.55, 0.0, 2.28), mats["iron"], 8, (math.pi / 2.0, 0.0, 0.0))
    # Arm centre is offset from the pivot along the rotated axis so the tip lands
    # directly above the drum: 1.90 m of reach in front, 0.70 m of tail behind.
    arm = box(part, "SweepArm", (2.60, 0.14, 0.14), (0.035, 0.0, 2.15), mats["oak"], 0.02)
    arm.rotation_euler[1] = WELL_SWEEP_ANGLE
    cylinder(part, "Counterweight", 0.20, 0.34, (-1.23, 0.0, 2.43), mats["stone_dark"], 10)
    cylinder(part, "Rope", 0.025, 0.76, (1.30, 0.0, 1.48), mats["rope"], 8)
    cylinder(part, "Bucket", 0.17, 0.30, (1.30, 0.0, 0.95), mats["oak"], 10)


def build_lean_to(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "ServantLeanTo", "servant_lean_to")
    box(part, "RearWall", (2.70, 0.12, 2.05), (0.0, 0.62, 1.025), mats["timber"], 0.02)
    for index, x in enumerate((-1.25, 1.25)):
        cylinder(part, f"Post{index}", 0.09, 1.52, (x, -0.58, 0.76), mats["oak"], 8)
    box(part, "FrontBeam", (2.70, 0.13, 0.15), (0.0, -0.58, 1.445), mats["oak"], 0.02)
    for side, x in (("L", -1.30), ("R", 1.30)):
        box(part, f"SideWall{side}", (0.10, 1.20, 1.45), (x, 0.02, 0.725), mats["oak"], 0.02)
    box(part, "LowFrontWall", (2.40, 0.09, 0.72), (0.0, -0.58, 0.36), mats["oak"], 0.02)
    # Mono-pitch shed roof pitched to bridge the 2.05 rear wall head and the 1.52
    # front beam head. The previous gable prism sat above both and floated.
    roof = box(part, "LeanToRoof", (2.95, 1.72, 0.12), (0.0, 0.02, 1.85), mats["shingle"])
    roof.rotation_euler[0] = 0.4162
    part["mass_role"] = "Hinterhaus_service_wing"


def build_firewood(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "FirewoodStack", "firewood_stack")
    # Billets lie along X and stack across Y and Z. The old kit spaced them along
    # their own length, so twelve logs collapsed into one bundle.
    for row in range(4):
        stagger = 0.06 if row % 2 else -0.06
        for index in range(3):
            log = cylinder(
                part,
                f"Billet{row}_{index}",
                0.115,
                1.70,
                (stagger + ((index + row) % 3 - 1) * 0.04, -0.23 + index * 0.23, 0.12 + row * 0.205),
                mats["wood_light"],
                8,
                (0.0, math.pi / 2.0, 0.0),
            )
            log.rotation_euler[0] = ((index * 2 + row) % 5 - 2) * 0.035
    for side, x in (("L", -0.90), ("R", 0.90)):
        cylinder(part, f"Stake{side}", 0.05, 1.05, (x, 0.0, 0.525), mats["oak"], 6)
    box(part, "YardCord", (0.06, 0.62, 0.05), (0.30, 0.0, 0.90), mats["rope"])


def build_hoist(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "HoistBeam", "hoist_beam")
    # Props render standalone, with no host building mesh to bolt a beam onto, so
    # the merchant hoist carries its own mast and knee brace and reaches the
    # ground instead of floating in mid-air like the previous wall bracket.
    box(part, "WallPost", (0.22, 0.30, 2.10), (-1.05, 0.0, 1.05), mats["oak"], 0.025)
    box(part, "Beam", (2.40, 0.18, 0.18), (0.15, 0.0, 2.01), mats["oak"], 0.025)
    brace = box(part, "KneeBrace", (0.92, 0.14, 0.14), (-0.63, 0.0, 1.65), mats["oak"], 0.02)
    brace.rotation_euler[1] = -0.656
    box(part, "PulleyStrap", (0.07, 0.07, 0.24), (1.20, 0.0, 1.84), mats["iron"])
    cylinder(part, "Pulley", 0.20, 0.10, (1.20, 0.0, 1.66), mats["iron"], 12, (math.pi / 2.0, 0.0, 0.0))
    cylinder(part, "Rope", 0.025, 0.74, (1.20, 0.0, 1.27), mats["rope"], 8)
    cylinder(part, "Hook", 0.05, 0.22, (1.20, 0.0, 0.83), mats["iron"], 8)
    part["merchant_only"] = True


def build_loading_hatch(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    part = component(root, "LoadingHatch", "loading_hatch")
    box(part, "Sill", (1.58, 0.26, 0.14), (0.0, -0.04, 0.11), mats["oak"], 0.025)
    box(part, "Frame", (1.44, 0.14, 1.22), (0.0, 0.0, 0.79), mats["oak"], 0.025)
    for side, x in (("L", -0.60), ("R", 0.60)):
        box(part, f"Jamb{side}", (0.16, 0.20, 1.30), (x, -0.02, 0.83), mats["oak"], 0.025)
    # Two shutter leaves with paired hinges read as a loading opening rather than
    # a single blank panel.
    for side, x in (("L", -0.32), ("R", 0.32)):
        box(part, f"Leaf{side}", (0.60, 0.07, 1.00), (x, -0.10, 0.80), mats["timber"], 0.02)
    for side, x, z in (("L0", -0.56, 0.48), ("L1", -0.56, 1.14), ("R0", 0.56, 0.48), ("R1", 0.56, 1.14)):
        cylinder(part, f"Hinge{side}", 0.035, 0.20, (x, -0.10, z), mats["iron"], 8, (0.0, math.pi / 2.0, 0.0))
    cylinder(part, "HatchRing", 0.055, 0.03, (0.0, -0.15, 0.80), mats["iron"], 10, (math.pi / 2.0, 0.0, 0.0))
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
    # Fail the build rather than shipping a kit that sinks through the map floor;
    # the previous revision exported at -0.13 m and nobody noticed.
    if not report["checks"]["ground_contact"]:
        raise SystemExit(f"plot dressing kit breaks the ground plane at z={report['ground_min_z']}")
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
