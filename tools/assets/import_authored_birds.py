#!/usr/bin/env python3
"""Rig and animate authored bird sculpts instead of rebuilding them from primitives.

The procedural storybook birds were visually rejected. This importer keeps a
licensed authored surface (its topology, UVs and PBR maps) and only adds the
runtime contract the game needs: the nine-bone ``Body/Head/Tail/Wing/Leg``
skeleton and the eight named clips.

Unlike ``storybook_birds.py`` the source rest pose has *folded* wings, so the
flight clips unfold the wing chain outward instead of folding a spread rest
pose. Ground clips therefore keep the authored silhouette untouched.

Run with Blender 5.2:
    blender -b --python tools/assets/import_authored_birds.py -- --only hen --publish
"""
from __future__ import annotations

import argparse
import hashlib
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/bird_redo"
sys.path.insert(0, str(Path(__file__).parent))
from mammal_limb_anatomy import foot_path  # noqa: E402  (generic planted-gait curve)

# ``height`` is the real standing height in metres including comb/crest. Anchor
# fractions are measured against the source bounding box so a replacement sculpt
# of the same species does not need new hand-tuned numbers.
CONFIG = {
    "hen": dict(
        source="assets/animals/hendrik_reyneke/chicken.glb",
        source_sha256="657adc065eda83691c5447f69145dbc3ada95b1bf99156369e85a74efe1873dc",
        author="hendrikReyneke (https://sketchfab.com/hendrikReyneke)",
        url="https://sketchfab.com/3d-models/chicken-ce17aabc51ba47bfbc7342a963b095e9",
        license="CC-BY-4.0",
        height=0.44,
        # Fractions of height/length; the source faces -Y in Blender (head) and
        # +Y (tail), matching the existing runtime facing correction.
        body=(0.00, 0.02, 0.50),
        # Neck root sits at the shoulders, inside the breast, so folding it
        # swings the skull down and forward instead of retracting it.
        neck=(0.00, -0.08, 0.60),
        # The head bone spans skull base to bill tip so comb and bill stay rigid
        # while the neck bends.
        head=(0.00, -0.30, 0.86),
        head_tip=(0.00, -0.95, 0.84),
        tail=(0.00, 0.34, 0.64),
        tail_tip=(0.00, 0.62, 0.74),
        shoulder=(0.28, -0.14, 0.62),
        wrist=(0.34, 0.10, 0.55),
        wing_tip=(0.30, 0.34, 0.48),
        # Bird leg chain: short femur forward, long tibiotarsus back, scaly
        # tarsometatarsus forward again, then toes. The visible backward joint
        # is the intertarsal (ankle), not a knee.
        hip=(0.24, 0.10, 0.52),
        knee=(0.24, -0.09, 0.39),
        ankle=(0.24, 0.20, 0.24),
        ball=(0.24, 0.00, 0.028),
        toe=(0.24, -0.26, 0.012),
        # Walk stride as a fraction of standing height.
        stride=0.30,
        clearance=0.075,
    ),
}


# Distal-to-proximal chain names; ``Leg.<side>`` keeps the existing runtime
# skeleton contract while the extra joints give the leg a real bird articulation.
LEG_BONES = ("Leg", "Shin", "Ankle", "Foot")


def solve_knee(hip: Vector, ankle: Vector, femur: float, tibia: float) -> Vector:
    """Sagittal two-bone solve with the knee carried forward, as in birds."""
    delta = Vector((0.0, ankle.y - hip.y, ankle.z - hip.z))
    distance = delta.length
    distance = min(max(distance, abs(femur - tibia) + 1e-5), femur + tibia - 1e-5)
    along = (femur * femur - tibia * tibia + distance * distance) / (2 * distance)
    across = math.sqrt(max(0.0, femur * femur - along * along))
    unit = Vector((0.0, delta.y, delta.z)).normalized()
    # Rotate the unit vector a quarter turn so the offset points toward the nose.
    forward = Vector((0.0, unit.z, -unit.y))
    if forward.y > 0.0:
        forward = -forward
    return hip + unit * along + forward * across


def clear() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds(meshes) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return low, high


def load_surface(species: str):
    cfg = CONFIG[species]
    path = ROOT / cfg["source"]
    if not path.exists():
        raise FileNotFoundError(f"Missing authored source: {path}")
    bpy.ops.import_scene.gltf(filepath=str(path), guess_original_bind_pose=False, disable_bone_shape=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {path}")

    # Bake the import hierarchy into the vertices so the exported GLB has
    # identity mesh-node transforms and the armature modifier is the only
    # deformer. Authored topology and UVs are preserved.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        world = obj.matrix_world.copy()
        mesh = bpy.data.meshes.new_from_object(
            obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph
        )
        obj.parent = None
        obj.animation_data_clear()
        obj.modifiers.clear()
        obj.data = mesh
        obj.data.transform(world)
        obj.matrix_world = Matrix.Identity(4)
        obj.vertex_groups.clear()
    for obj in list(bpy.context.scene.objects):
        if obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)

    low, high = bounds(meshes)
    scale = cfg["height"] / (high.z - low.z)
    anchor = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for index, obj in enumerate(meshes):
        for vertex in obj.data.vertices:
            vertex.co = (vertex.co - anchor) * scale
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        obj.name = f"{species}_surface" if index == 0 else f"{species}_surface{index + 1}"

    for image in bpy.data.images:
        if image.type == "IMAGE" and max(image.size) > 1024:
            factor = 1024 / max(image.size)
            image.scale(round(image.size[0] * factor), round(image.size[1] * factor))

    for material in bpy.data.materials:
        if not material.use_nodes:
            material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is None:
            continue
        principled.inputs["Metallic"].default_value = 0.0
        for link in list(principled.inputs["Metallic"].links):
            material.node_tree.links.remove(link)
        principled.inputs["Emission Strength"].default_value = 0.0
        # Feather cards rely on alpha cutout; keep the authored mask threshold.
        material.name = "Bird plumage"

    # The runtime plumage shader multiplies vertex pigment with the albedo map.
    # Authored sculpts carry their colour in the map, so ship neutral pigment
    # rather than tinting the source texture twice.
    for obj in meshes:
        for attribute in list(obj.data.color_attributes):
            obj.data.color_attributes.remove(attribute)
        layer = obj.data.color_attributes.new(name="Plumage", type="FLOAT_COLOR", domain="POINT")
        for index in range(len(obj.data.vertices)):
            layer.data[index].color = (1.0, 1.0, 1.0, 1.0)
    return meshes


def _anchor(cfg: dict, key: str, size: Vector) -> Vector:
    x, y, z = cfg[key]
    return Vector((x * size.x / 2.0, y * size.y / 2.0, z * cfg["height"]))


def create_rig(meshes, species: str):
    cfg = CONFIG[species]
    low, high = bounds(meshes)
    size = high - low
    centre = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, 0.0))

    def point(key: str, mirror: float = 1.0) -> Vector:
        anchor = _anchor(cfg, key, size)
        return Vector((centre.x + anchor.x * mirror, centre.y + anchor.y, anchor.z))

    armature = bpy.data.armatures.new("AuthoredBirdRig")
    rig = bpy.data.objects.new("AuthoredBirdRig", armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name: str, start: Vector, end: Vector, parent: str | None = None):
        edit = armature.edit_bones.new(name)
        edit.head = start
        edit.tail = end
        # Wing bones rest folded along the body, so their local roll decides
        # which axis unfolds them. Align roll to world up: pose rotation Z then
        # swings the wing out laterally and X beats it up and down.
        edit.align_roll(Vector((0.0, 0.0, 1.0)))
        if parent:
            edit.parent = armature.edit_bones[parent]
        return edit

    body_root = point("body")
    bone("Body", body_root, point("neck"))
    # A separate neck lets the bird reach the ground to feed instead of craning
    # the skull off a rigid torso.
    bone("Neck", point("neck"), point("head"), "Body")
    bone("Head", point("head"), point("head_tip"), "Neck")
    bone("Tail", point("tail"), point("tail_tip"), "Body")
    legs = {}
    for side, mirror in (("L", 1.0), ("R", -1.0)):
        bone(f"Wing.{side}", point("shoulder", mirror), point("wrist", mirror), "Body")
        bone(f"WingTip.{side}", point("wrist", mirror), point("wing_tip", mirror), f"Wing.{side}")
        chain = [point(key, mirror) for key in ("hip", "knee", "ankle", "ball", "toe")]
        legs[side] = chain
        parent = "Body"
        for name, start, end in zip(LEG_BONES, chain, chain[1:]):
            bone(f"{name}.{side}", start, end, parent)
            parent = f"{name}.{side}"
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["species"] = species

    skin(meshes, rig, cfg)
    return rig, body_root, legs


def skin(meshes, rig, cfg: dict) -> None:
    """Weight the authored surface with explicit anatomical falloffs.

    Heat diffusion leaks across a bird's folded wing/flank contact, which makes
    the wing drag the body during flight. Gaussian falloff to each bone segment,
    gated by side and height, keeps those regions separate and is reproducible.
    """
    height = cfg["height"]
    radius = {
        "Body": 0.40 * height,
        "Neck": 0.11 * height,
        "Head": 0.10 * height,
        "Tail": 0.16 * height,
        "Wing": 0.15 * height,
        "WingTip": 0.13 * height,
        # The femur is buried in the flank, so keep its pull short; the scaly
        # shank and toes are thin and must not drag body feathers.
        "Leg": 0.07 * height,
        "Shin": 0.06 * height,
        "Ankle": 0.05 * height,
        "Foot": 0.05 * height,
    }
    segments = {
        bone.name: (bone.head_local.copy(), bone.tail_local.copy()) for bone in rig.data.bones
    }

    def distance(name: str, point: Vector) -> float:
        start, end = segments[name]
        delta = end - start
        t = max(0.0, min(1.0, (point - start).dot(delta) / max(delta.length_squared, 1e-9)))
        return (point - (start + delta * t)).length

    leg_top = max(segments["Leg.L"][0].z, segments["Leg.R"][0].z)
    for obj in meshes:
        obj.vertex_groups.clear()
        groups = {name: obj.vertex_groups.new(name=name) for name in segments}
        for vertex in obj.data.vertices:
            point = vertex.co
            side = "L" if point.x >= 0.0 else "R"
            candidates = ["Body", "Neck", "Head", "Tail", f"Wing.{side}", f"WingTip.{side}"]
            candidates += [f"{name}.{side}" for name in LEG_BONES]
            weights = {}
            for name in candidates:
                key = name.split(".")[0]
                falloff = radius[key]
                if key in LEG_BONES:
                    # Body feathers must not follow the shank; fade the leg
                    # influence out above the hip joint.
                    if point.z > leg_top + 0.06 * height:
                        continue
                value = math.exp(-((distance(name, point) / falloff) ** 2))
                if value > 1e-4:
                    weights[name] = value
            if not weights:
                weights["Body"] = 1.0
            ordered = sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]
            total = sum(value for _, value in ordered)
            for name, value in ordered:
                groups[name].add([vertex.index], value / total, "REPLACE")
        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = rig
        obj.parent = rig


def pose_leg(rig, side: str, chain, travel: float, lift: float, drop: float, tuck: float) -> None:
    """Drive one leg chain so the toes follow a planted gait path.

    ``travel``/``lift`` come from the shared gait curve, ``drop`` is the body
    bob, and ``tuck`` folds the whole leg back under the tail for flight.
    """
    hip, knee_rest, ankle_rest, ball_rest, toe_rest = chain
    hip = Vector((hip.x, hip.y, hip.z + drop))
    femur = (knee_rest - chain[0]).length
    tibia = (ankle_rest - knee_rest).length

    if tuck > 0.0:
        # Folded flight posture: the toes ride up behind the vent.
        target = ankle_rest.lerp(Vector((ankle_rest.x, hip.y + 0.55 * tibia, hip.z - 0.20 * tibia)), tuck)
    else:
        target = Vector((ankle_rest.x, ankle_rest.y + travel, ankle_rest.z + lift))
    knee = solve_knee(hip, target, femur, tibia)
    offset = target - ankle_rest
    points = [hip, knee, target, ball_rest + offset, toe_rest + offset]

    poses = {"Body": rig.data.bones["Body"].matrix_local @ rig.pose.bones["Body"].matrix_basis}
    for index, name in enumerate(LEG_BONES):
        pose_bone = rig.pose.bones[f"{name}.{side}"]
        rest = pose_bone.bone.matrix_local
        start, end = points[index], points[index + 1]
        rotation = (pose_bone.bone.tail_local - pose_bone.bone.head_local).rotation_difference(end - start)
        desired = Matrix.Translation(start) @ rotation.to_matrix().to_4x4() @ rest.to_3x3().to_4x4()
        parent = pose_bone.parent
        pose_bone.matrix_basis = (
            rest.inverted() @ parent.bone.matrix_local @ poses[parent.name].inverted() @ desired
        )
        poses[pose_bone.name] = desired


def animate(rig, species: str, legs: dict) -> None:
    """Author the eight runtime clips against a folded-wing rest pose."""
    cfg = CONFIG[species]
    height = cfg["height"]
    stride = cfg["stride"] * height
    clearance = cfg["clearance"] * height
    rig.animation_data_create()
    # Walk cycle covers two strides per second at 48 fps over 48 frames.
    rig["walk_reference_speed"] = stride * 2.0
    rig["run_reference_speed"] = stride * 3.2

    clips = ["Idle", "Walk", "Hop", "Fly", "Peck", "TakeOff", "Glide", "Land"]
    for clip in clips:
        action = bpy.data.actions.new(clip)
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame in range(49):
            phase = frame / 48.0
            t = phase * math.tau
            for pose_bone in rig.pose.bones:
                pose_bone.rotation_mode = "XYZ"
                pose_bone.matrix_basis.identity()

            body = rig.pose.bones["Body"]
            neck = rig.pose.bones["Neck"]
            head = rig.pose.bones["Head"]
            tail = rig.pose.bones["Tail"]

            # ``extension`` unfolds the wing chain from the authored folded rest
            # pose; 0 keeps the sculpted silhouette exactly as authored.
            extension = 0.0
            lift = 0.0
            # Idle -> TakeOff -> Fly -> Glide -> Land -> Idle must chain without
            # a pose jump, so airborne clips hold the lift TakeOff ends on.
            if clip in ("Fly", "Glide"):
                extension = 1.0
                lift = 1.0
            elif clip == "TakeOff":
                extension = phase * phase * (3 - 2 * phase)
                lift = extension
            elif clip == "Land":
                reverse = 1.0 - phase
                extension = reverse * reverse * (3 - 2 * reverse)
                lift = extension

            drop = 0.0
            gait = None
            flap = 0.0
            if clip == "Idle":
                drop = 0.008 * height * math.sin(t)
                # Only whole-cycle harmonics: the clips must close on themselves.
                neck.rotation_euler = Euler((0.05 * math.sin(t), 0.0, 0.08 * math.sin(t)))
                head.rotation_euler.z = 0.10 * math.sin(t)
                tail.rotation_euler.x = 0.05 * math.sin(t)
            elif clip == "Peck":
                dip = (1 - math.cos(t)) * 0.5
                # Fold the neck down and level the skull so the bill reaches
                # the ground instead of the torso pivoting nose-up.
                neck.rotation_euler.x = -0.80 * dip
                head.rotation_euler.x = -0.30 * dip
                body.rotation_euler.x = -0.45 * dip
                tail.rotation_euler.x = 0.30 * dip
            elif clip in ("Walk", "Hop"):
                hop = clip == "Hop"
                bob = abs(math.sin(t if hop else t * 2))
                drop = (0.050 if hop else 0.012) * height * bob
                body.rotation_euler.x = (-0.10 if hop else -0.03) * bob
                # A walking hen pumps its head forward once per step.
                neck.rotation_euler.x = (0.10 if hop else 0.20) * math.sin(t * (1 if hop else 2) + 1.2)
                tail.rotation_euler.x = 0.10 * bob
                gait = {"L": 0.0, "R": 0.0 if hop else 0.5}
                if hop:
                    for side in ("L", "R"):
                        rig.pose.bones[f"Wing.{side}"].rotation_euler.z = 0.35 * bob
            elif clip in ("Fly", "TakeOff", "Glide", "Land"):
                if clip == "Fly":
                    flap = math.sin(t)
                elif clip == "Glide":
                    flap = 0.08 * math.sin(t)
                else:
                    flap = math.sin(t * 2) * extension
                drop = 0.34 * height * lift
                body.rotation_euler.x = -0.22 * extension
                neck.rotation_euler.x = 0.18 * extension
                tail.rotation_euler.x = 0.20 * extension
                for side, sign in (("L", 1.0), ("R", -1.0)):
                    wing = rig.pose.bones[f"Wing.{side}"]
                    tip = rig.pose.bones[f"WingTip.{side}"]
                    # Unfold laterally, then beat around the shoulder.
                    wing.rotation_euler.z = sign * (-1.15 * extension)
                    wing.rotation_euler.x = 0.75 * flap * extension
                    tip.rotation_euler.z = sign * (-0.55 * extension)
                    tip.rotation_euler.x = 0.45 * flap * extension

            # Convert the world-space body bob into the Body bone's local space.
            rest = rig.data.bones["Body"].matrix_local.to_3x3()
            body.location = rest.inverted() @ Vector((0.0, 0.0, drop))

            for side, chain in legs.items():
                travel = foot_lift = 0.0
                if gait is not None:
                    travel, foot_lift, _ = foot_path(phase - gait[side], stride, clearance)
                pose_leg(rig, side, chain, travel, foot_lift, drop, extension)

            for pose_bone in rig.pose.bones:
                pose_bone.keyframe_insert("rotation_euler", frame=frame, group=pose_bone.name)
                pose_bone.keyframe_insert("location", frame=frame, group=pose_bone.name)
                pose_bone.keyframe_insert("scale", frame=frame, group=pose_bone.name)
        rig.animation_data.action = None
    bpy.context.scene.render.fps = 48
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis.identity()


def build(species: str, out: Path) -> None:
    cfg = CONFIG[species]
    digest = hashlib.sha256((ROOT / cfg["source"]).read_bytes()).hexdigest()
    if digest != cfg["source_sha256"]:
        raise ValueError(f"{species}: source checksum mismatch ({digest})")
    clear()
    meshes = load_surface(species)
    rig, _body_root, legs = create_rig(meshes, species)
    animate(rig, species, legs)
    rig["source_author"] = cfg["author"]
    rig["source_url"] = cfg["url"]
    rig["license"] = cfg["license"]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    out.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / ".gdignore").touch()
    bpy.ops.export_scene.gltf(
        filepath=str(out / f"{species}.glb"),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_extras=True,
        export_yup=True,
        export_vertex_color="NAME",
        export_vertex_color_name="Plumage",
        export_all_vertex_colors=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(BUILD / f"{species}.blend"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=list(CONFIG))
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    out = ROOT / "assets/storybook" if args.publish else BUILD / "candidates"
    for species in [args.only] if args.only else list(CONFIG):
        build(species, out)


if __name__ == "__main__":
    main()
