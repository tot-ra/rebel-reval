#!/usr/bin/env python3
"""Build rigged ambient gait GLBs for the three domestic fowl species.

The standing meshes are already reviewed production assets. This pass deliberately
keeps their geometry and materials intact, adding only a compact body/leg armature
and deterministic Idle/Walk actions so ambient actors can use the same skeletal
animation contract as the other livestock.

Run from the repository root:
    blender --background --factory-startup --python tools/assets/build_bird_gaits.py
    blender --background --factory-startup --python tools/assets/build_bird_gaits.py -- chicken
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = ROOT / "generated" / "bird_gaits_v1" / "reports"

# Godot turns ambient actors with `look_at`, so a walking animal travels along
# its own -Z. glTF -Z is Blender +Y, which makes "head toward Blender +Y, feet at
# Z=0" the orientation contract every gait asset must satisfy. None of the
# reviewed source meshes meet it as authored: both fowl face Blender -Y (they
# would walk backwards), and the greylag goose is stored upside down with its
# feet at the top of the model. `orient_axis` bakes the corrective 180-degree
# rotation into the mesh before rigging, so the runtime needs no per-species
# transform and the leg bones are authored in the same corrected space.
#
# `leg_materials` names the authored leg/foot material slots. When present the
# rig weights exactly those vertices, which is far more reliable than guessing a
# capsule around a hand-placed segment. The hen has a single merged material, so
# it keeps the segment heuristic and its hand-tuned bone coordinates (already
# expressed in the corrected space).
SPECS = {
    "chicken": {
        "source": ROOT / "assets" / "animals" / "hendrik_reyneke" / "chicken.glb",
        "output": ROOT / "assets" / "birds" / "chicken" / "walking.glb",
        "orient_axis": "Z",
        "leg_materials": (),
        "leg_hips": ((0.055, -0.030, 0.115), (-0.055, -0.030, 0.115)),
        "leg_feet": ((0.055, -0.010, 0.010), (-0.055, -0.010, 0.010)),
        "leg_cut": 0.145,
        "leg_radius": 0.070,
        "body_center_y": 0.0,
        "body_top": 0.30,
        "walk_angle": 0.36,
        "body_bob": 0.006,
    },
    "mallard": {
        "source": ROOT / "assets" / "birds" / "mallard" / "standing.glb",
        "output": ROOT / "assets" / "birds" / "mallard" / "walking.glb",
        "orient_axis": "Z",
        "leg_materials": ("mallard_feet",),
        "body_center_y": 0.04,
        "body_top": 0.33,
        "walk_angle": 0.32,
        "body_bob": 0.008,
    },
    "greylag_goose": {
        "source": ROOT / "assets" / "birds" / "greylag_goose" / "standing.glb",
        "output": ROOT / "assets" / "birds" / "greylag_goose" / "walking.glb",
        # The source goose is upside down; a 180-degree turn about X rights it
        # and turns it to face +Y in the same step.
        "orient_axis": "X",
        "leg_materials": ("greylag_goose_leg", "greylag_goose_foot"),
        "body_center_y": 0.09,
        "body_top": 1.05,
        "walk_angle": 0.28,
        "body_bob": 0.012,
    },
}

# The runtime and livestock tests use these canonical four-leg names. A bird has
# two real legs, so front/back bones on each side share the same weights and pose.
LEG_NAMES = ("FrontLeftLeg", "FrontRightLeg", "BackLeftLeg", "BackRightLeg")


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import_mesh(source: Path) -> bpy.types.Object:
    if not source.exists():
        raise FileNotFoundError(source)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"{source}: imported scene contains no mesh")
    # The reviewed GLBs also carry a tiny authoring cube for source previews. Use
    # the largest mesh only so helper geometry cannot alter production scale,
    # silhouette, or ground contact. Preserve all authored material slots.
    mesh = max(meshes, key=lambda candidate: len(candidate.data.vertices))
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world.identity()
    mesh.parent = None
    mesh.name = "AnimalMesh"
    # Remove source-preview helpers (cube, camera, light) before adding the rig.
    # A clean scene is required because glTF selection can otherwise retain an
    # importer helper and export it as an unskinned second mesh.
    for obj in list(bpy.context.scene.objects):
        if obj != mesh:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.objects.active = None
    mesh.select_set(False)
    return mesh


def _distance_to_segment(point: Vector, start: Vector, end: Vector) -> float:
    segment = end - start
    length_sq = segment.length_squared
    if length_sq <= 1e-10:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(segment) / length_sq))
    return (point - (start + segment * t)).length


def _orient_mesh(mesh: bpy.types.Object, spec: dict) -> None:
    """Rotate the source mesh into the runtime orientation contract.

    See SPECS: the result must stand on Z=0 and face Blender +Y, which exports as
    glTF -Z, the direction Godot walks an ambient actor toward.
    """
    axis = spec["orient_axis"]
    # The glTF importer leaves objects in QUATERNION rotation mode, where writing
    # rotation_euler is silently ignored. Switch modes before posing the object.
    mesh.rotation_mode = "XYZ"
    mesh.rotation_euler = tuple(
        math.pi if letter == axis else 0.0 for letter in ("X", "Y", "Z")
    )
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    # transform_apply also rotates the imported custom split normals, which a raw
    # mesh.data.transform() call would leave pointing the old way.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    mesh.select_set(False)
    bpy.context.view_layer.objects.active = None


def _leg_side_vertices(mesh: bpy.types.Object, spec: dict) -> dict:
    """Vertex indices of the real legs, split into Left (+X) and Right (-X)."""
    material_names = set(spec.get("leg_materials", ()))
    sides: dict = {"Left": [], "Right": []}
    if material_names:
        slots = {
            index
            for index, material in enumerate(mesh.data.materials)
            if material is not None and material.name in material_names
        }
        if not slots:
            raise RuntimeError(
                f"{spec['name']}: leg materials {sorted(material_names)} are missing"
            )
        selected: set = set()
        for polygon in mesh.data.polygons:
            if polygon.material_index in slots:
                selected.update(polygon.vertices)
        for index in sorted(selected):
            sides["Left" if mesh.data.vertices[index].co.x > 0.0 else "Right"].append(index)
        return sides

    # Single-material sources have no leg slot to select, so weight vertices that
    # sit below the belly and close to the authored leg line instead. This keeps
    # the body silhouette rigid while lower legs and feet follow a step.
    segments = (
        ("Left", Vector(spec["leg_hips"][0]), Vector(spec["leg_feet"][0])),
        ("Right", Vector(spec["leg_hips"][1]), Vector(spec["leg_feet"][1])),
    )
    for vertex in mesh.data.vertices:
        point = vertex.co
        if point.z > spec["leg_cut"]:
            continue
        closest_side = ""
        closest_distance = float("inf")
        for side, start, end in segments:
            distance = _distance_to_segment(point, start, end)
            if distance < closest_distance:
                closest_side = side
                closest_distance = distance
        if closest_side and closest_distance <= spec["leg_radius"]:
            sides[closest_side].append(vertex.index)
    return sides


def _leg_anchors(mesh: bpy.types.Object, spec: dict, sides: dict) -> dict:
    """Hip (upper) and foot (lower) bone anchor per side, in corrected space."""
    if not spec.get("leg_materials"):
        return {
            "Left": (Vector(spec["leg_hips"][0]), Vector(spec["leg_feet"][0])),
            "Right": (Vector(spec["leg_hips"][1]), Vector(spec["leg_feet"][1])),
        }
    anchors: dict = {}
    for side, indices in sides.items():
        points = [mesh.data.vertices[index].co for index in indices]
        if not points:
            raise RuntimeError(f"{spec['name']}: no {side} leg vertices")
        mean_x = sum(point.x for point in points) / len(points)
        mean_y = sum(point.y for point in points) / len(points)
        top = max(point.z for point in points)
        bottom = min(point.z for point in points)
        if top - bottom < 0.01:
            raise RuntimeError(f"{spec['name']}: {side} leg is too flat to rig")
        anchors[side] = (
            Vector((mean_x, mean_y, top)),
            Vector((mean_x, mean_y, bottom)),
        )
    return anchors


def _snap_mesh_to_ground(mesh: bpy.types.Object) -> None:
    vertices = mesh.data.vertices
    if not vertices:
        return
    min_z = min(vertex.co.z for vertex in vertices)
    if abs(min_z) <= 1e-6:
        return
    for vertex in vertices:
        vertex.co.z -= min_z
    mesh.data.update()


def _build_armature(
    mesh: bpy.types.Object, spec: dict, sides: dict, anchors: dict
) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = "BirdRig"
    armature.data.name = "BirdSkeleton"
    armature.show_in_front = False

    edit_bones = armature.data.edit_bones
    root = edit_bones[0]
    root.name = "Root"
    root.head = (0.0, 0.0, 0.0)
    root.tail = (0.0, 0.0, 0.05)
    body = edit_bones.new("Body")
    body.head = (0.0, spec["body_center_y"], 0.05)
    body.tail = (0.0, spec["body_center_y"], spec["body_top"])
    body.parent = root
    body.use_connect = False

    for name in LEG_NAMES:
        bone = edit_bones.new(name)
        hip, foot = anchors["Left" if "Left" in name else "Right"]
        bone.head = hip
        bone.tail = foot
        bone.parent = root
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")

    body_group = mesh.vertex_groups.new(name="Body")
    body_indices = [vertex.index for vertex in mesh.data.vertices]
    body_group.add(body_indices, 1.0, "REPLACE")
    leg_groups = {name: mesh.vertex_groups.new(name=name) for name in LEG_NAMES}
    counts = {name: 0 for name in LEG_NAMES}

    # Each side drives the two compatible bone names the runtime expects.
    for side, vertex_indices in sides.items():
        if not vertex_indices:
            continue
        body_group.remove(vertex_indices)
        side_names = (
            ("FrontLeftLeg", "BackLeftLeg")
            if side == "Left"
            else ("FrontRightLeg", "BackRightLeg")
        )
        for name in side_names:
            leg_groups[name].add(vertex_indices, 1.0, "REPLACE")
            counts[name] = len(vertex_indices)

    modifier = mesh.modifiers.new("BirdRigArmature", "ARMATURE")
    modifier.object = armature
    mesh.parent = armature
    armature["gait_species"] = str(spec["name"])
    armature["gait_leg_vertex_counts"] = json.dumps(counts, sort_keys=True)
    for name, count in counts.items():
        if count < 8:
            raise RuntimeError(f"{spec['name']}: {name} received only {count} vertices")
    return armature


def _set_cyclic(action: bpy.types.Action) -> None:
    # Blender 5.x stores keyframe f-curves in layered action channel bags.
    # Iterate the bags rather than the removed Action.fcurves collection.
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for fcurve in channelbag.fcurves:
                    for keyframe in fcurve.keyframe_points:
                        keyframe.interpolation = "BEZIER"
                    fcurve.modifiers.new("CYCLES")


def _create_actions(armature: bpy.types.Object, spec: dict) -> None:
    pose_bones = armature.pose.bones
    animated = ["Body", *LEG_NAMES]
    for name in animated:
        pose_bones[name].rotation_mode = "XYZ"

    def new_action(name: str) -> bpy.types.Action:
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        armature.animation_data_create()
        armature.animation_data.action = action
        return action

    def key_pose(
        frame: int,
        leg_a: float,
        leg_b: float,
        body_z: float,
        body_pitch: float = 0.0,
    ) -> None:
        rotations = {
            "FrontLeftLeg": (leg_a, 0.0, 0.0),
            "BackLeftLeg": (leg_a, 0.0, 0.0),
            "FrontRightLeg": (leg_b, 0.0, 0.0),
            "BackRightLeg": (leg_b, 0.0, 0.0),
            "Body": (body_pitch, 0.0, 0.0),
        }
        for name in animated:
            pose_bones[name].rotation_euler = rotations[name]
            pose_bones[name].keyframe_insert("rotation_euler", frame=frame, group=name)
        pose_bones["Body"].location = (0.0, 0.0, body_z)
        pose_bones["Body"].keyframe_insert("location", frame=frame, group="Body")

    idle = new_action("Idle")
    idle_poses = (
        (1, 0.0, 0.0, 0.0, 0.0),
        (12, 0.025, -0.025, spec["body_bob"], 0.008),
        (24, -0.025, 0.025, 0.0, -0.008),
        (36, 0.0, 0.0, 0.0, 0.0),
    )
    for pose in idle_poses:
        key_pose(*pose)
    _set_cyclic(idle)

    walk = new_action("Walk")
    angle = float(spec["walk_angle"])
    bob = float(spec["body_bob"])
    walk_poses = (
        (1, angle, -angle, 0.0, -0.012),
        (7, angle * 0.35, -angle * 0.35, bob, 0.0),
        (13, 0.0, 0.0, bob * 1.35, 0.012),
        (19, -angle * 0.35, angle * 0.35, bob, 0.0),
        (25, -angle, angle, 0.0, -0.012),
        (31, -angle * 0.35, angle * 0.35, bob, 0.0),
        (37, 0.0, 0.0, bob * 1.35, 0.012),
        (43, angle * 0.35, -angle * 0.35, bob, 0.0),
        (49, angle, -angle, 0.0, -0.012),
    )
    for pose in walk_poses:
        key_pose(*pose)
    _set_cyclic(walk)
    armature.animation_data.action = idle


def _export(name: str, mesh: bpy.types.Object, armature: bpy.types.Object, spec: dict) -> dict:
    output: Path = spec["output"]
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=False,
        export_force_sampling=True,
        export_apply=False,
        export_materials="EXPORT",
    )
    report = {
        "species": name,
        "source": str(spec["source"].relative_to(ROOT)),
        "output": str(output.relative_to(ROOT)),
        "skeleton": ["Root", "Body", *LEG_NAMES],
        "animations": ["Idle", "Walk"],
        "animated_parts": ["legs", "body"],
        "leg_vertex_counts": json.loads(armature["gait_leg_vertex_counts"]),
        "ground_z": 0.0,
        "orient_axis": spec["orient_axis"],
        "faces_gltf_minus_z": True,
        "deterministic": True,
    }
    return report


def build(name: str) -> dict:
    spec = dict(SPECS[name])
    spec["name"] = name
    _reset_scene()
    mesh = _import_mesh(spec["source"])
    _orient_mesh(mesh, spec)
    _snap_mesh_to_ground(mesh)
    sides = _leg_side_vertices(mesh, spec)
    anchors = _leg_anchors(mesh, spec, sides)
    armature = _build_armature(mesh, spec, sides, anchors)
    _create_actions(armature, spec)
    report = _export(name, mesh, armature, spec)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / f"{name}.json").write_text(json.dumps(report, indent=2) + "\n")
    print("BIRD_GAIT=" + json.dumps(report, separators=(",", ":")))
    return report


def main() -> None:
    selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    names = selected or list(SPECS)
    unknown = sorted(set(names) - set(SPECS))
    if unknown:
        raise ValueError(f"Unknown bird specs: {unknown}")
    for name in names:
        build(name)


if __name__ == "__main__":
    main()
