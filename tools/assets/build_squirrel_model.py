"""Build a game-ready Eurasian red squirrel GLB with closed anatomy and a fur coat.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_squirrel_model.py

WHY: the catalog squirrel is a six-segment ellipsoid loaf with a stick tail. At
garden range it reads as a toy, not Sciurus vulgaris. This pass authors a compact
arched rodent, tufted ears, a short muzzle, and a fused bushy plume, then skins
one surface with a rust/cream agouti coat and the shared quadruped idle/walk
contract. Witcher 3 is the fidelity reference only; no game assets are copied.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ASSET_TOOL_DIR = Path(__file__).resolve().parent
if str(ASSET_TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOL_DIR))

import build_medieval_animal_models as pipeline
from medieval_animal_rigs import (
    add_tapered_segment,
    add_uv_sphere,
    create_flat_material,
    create_quadruped_rig,
    parent_to_bone,
    snap_point_to_mesh_surface,
)

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "assets/animals/medieval"
REPORTS = ROOT / "generated/comfyui/medieval_animals_v1/production/reports"
TEXTURES = ROOT / "generated/comfyui/medieval_animals_v1/production/textures"
OUTPUT = RUNTIME / "medieval_squirrel.glb"

# Y-up contract: length, height, width. Slightly heroic so the plume reads at
# street range without becoming a cat-sized rodent.
DIMENSIONS_M = (0.48, 0.22, 0.11)

SURFACE_PROFILE = {
    "noise_scale": 132.0,
    "noise_detail": 6.0,
    "bump_strength": 0.56,
    "rough_min": 0.86,
    "rough_max": 0.98,
    "normal_strength": 1.12,
}


def create_squirrel_mesh() -> bpy.types.Object:
    """Closed rodent volumes. Head points along -X and the paws sit on Z=0."""
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 20,
        ring_count: int = 12,
    ) -> bpy.types.Object:
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=segments, ring_count=ring_count, location=location
        )
        part = bpy.context.object
        part.name = part_name
        part.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        parts.append(part)
        return part

    def segment(
        part_name: str,
        start: tuple[float, float, float],
        end: tuple[float, float, float],
        start_radius: float,
        end_radius: float,
        vertices: int = 14,
    ) -> bpy.types.Object:
        start_v = Vector(start)
        end_v = Vector(end)
        direction = end_v - start_v
        bpy.ops.mesh.primitive_cone_add(
            vertices=vertices,
            radius1=end_radius,
            radius2=start_radius,
            depth=direction.length,
            location=(start_v + end_v) * 0.5,
        )
        part = bpy.context.object
        part.name = part_name
        part.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        parts.append(part)
        return part

    # Compact hunched torso. A deep chest, tucked waist, and huge haunch are the
    # rodent cue that separates a squirrel from the catalog loaf.
    sphere("SquirrelRibcage", (-0.08, 0.0, 0.19), (0.12, 0.070, 0.080), 24, 14)
    sphere("SquirrelShoulder", (-0.18, 0.0, 0.21), (0.07, 0.065, 0.075), 20, 12)
    sphere("SquirrelLoin", (0.02, 0.0, 0.22), (0.06, 0.050, 0.060), 18, 10)
    sphere("SquirrelHaunch", (0.13, 0.0, 0.24), (0.10, 0.080, 0.095), 22, 12)
    sphere("SquirrelBelly", (-0.04, 0.0, 0.135), (0.10, 0.050, 0.036), 18, 10)
    sphere("SquirrelTopline", (-0.05, 0.0, 0.265), (0.09, 0.036, 0.028), 16, 8)

    segment("SquirrelNeck", (-0.20, 0.0, 0.23), (-0.28, 0.0, 0.29), 0.050, 0.042)
    # Large rounded skull. A tiny head on a fat body reads as a weasel.
    sphere("SquirrelSkull", (-0.35, 0.0, 0.31), (0.075, 0.060, 0.060), 22, 12)
    sphere("SquirrelBrow", (-0.36, 0.0, 0.355), (0.040, 0.042, 0.024), 14, 8)
    sphere("SquirrelCheekLeft", (-0.33, 0.042, 0.29), (0.032, 0.024, 0.030), 12, 8)
    sphere("SquirrelCheekRight", (-0.33, -0.042, 0.29), (0.032, 0.024, 0.030), 12, 8)
    # Short pointed muzzle. A long canid snout is the main catalog failure.
    segment("SquirrelMuzzle", (-0.40, 0.0, 0.29), (-0.47, 0.0, 0.275), 0.028, 0.014, 12)
    sphere("SquirrelMuzzleStop", (-0.45, 0.0, 0.28), (0.022, 0.016, 0.014), 12, 8)
    sphere("SquirrelNoseLeather", (-0.48, 0.0, 0.268), (0.012, 0.010, 0.008), 10, 8)
    sphere("SquirrelJaw", (-0.39, 0.0, 0.265), (0.042, 0.022, 0.015), 14, 8)
    # Short wide ears. Tall cones remesh into rabbit poles, the lynx/wolf lesson.
    for side, y in (("Left", 0.036), ("Right", -0.036)):
        sphere(f"SquirrelEar{side}", (-0.32, y, 0.37), (0.022, 0.020, 0.028), 12, 8)
        sphere(f"SquirrelEarTip{side}", (-0.315, y * 1.15, 0.395), (0.014, 0.012, 0.016), 10, 8)

    for side, y in (("Left", 0.046), ("Right", -0.046)):
        segment(f"SquirrelFront{side}Upper", (-0.16, y, 0.17), (-0.17, y, 0.08), 0.020, 0.014)
        segment(f"SquirrelFront{side}Lower", (-0.17, y, 0.08), (-0.16, y, 0.024), 0.013, 0.010)
        sphere(f"SquirrelFront{side}Paw", (-0.175, y, 0.015), (0.028, 0.016, 0.013), 12, 8)
    for side, y in (("Left", 0.054), ("Right", -0.054)):
        sphere(f"SquirrelBack{side}Thigh", (0.11, y, 0.18), (0.058, 0.032, 0.068), 16, 10)
        segment(f"SquirrelBack{side}Gaskin", (0.09, y, 0.13), (0.15, y, 0.055), 0.020, 0.013)
        segment(f"SquirrelBack{side}Hock", (0.15, y, 0.055), (0.12, y, 0.020), 0.012, 0.009)
        sphere(f"SquirrelBack{side}Paw", (0.10, y, 0.013), (0.026, 0.015, 0.011), 12, 8)

    # Continuous spine plus overlapping locks. Sparse spheres remeshed into a
    # bead necklace; the spine keeps one hide and the locks keep the lumps.
    segment("SquirrelTailSpine", (0.16, 0.0, 0.24), (0.56, 0.0, 0.40), 0.046, 0.026)
    plume = (
        (0.18, 0.00, 0.25, 0.050),
        (0.22, 0.00, 0.30, 0.056),
        (0.26, 0.02, 0.35, 0.052),
        (0.26, -0.02, 0.35, 0.052),
        (0.30, 0.00, 0.41, 0.060),
        (0.34, 0.025, 0.46, 0.054),
        (0.34, -0.025, 0.46, 0.054),
        (0.38, 0.00, 0.49, 0.058),
        (0.43, 0.022, 0.49, 0.050),
        (0.43, -0.022, 0.49, 0.050),
        (0.47, 0.00, 0.47, 0.048),
        (0.51, 0.016, 0.43, 0.038),
        (0.51, -0.016, 0.43, 0.038),
        (0.54, 0.00, 0.38, 0.030),
    )
    for index, (px, py, pz, radius) in enumerate(plume):
        sphere(f"SquirrelPlume{index}", (px, py, pz), (radius, radius * 0.82, radius * 0.88), 14, 8)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj["procedural_anatomy"] = True
    obj["digitigrade_paws"] = True
    obj["species"] = "squirrel"
    return obj


def apply_squirrel_fur_displacement(obj: bpy.types.Object, *, strength: float = 0.012) -> None:
    """Break the remeshed hull into guard hair without wooling the muzzle or paws."""
    fur_group = obj.vertex_groups.new(name="SquirrelFurDisplace")
    fur_indices = []
    for vertex in obj.data.vertices:
        point = vertex.co
        muzzle = point.x < -0.42 and point.z < 0.34
        paw = point.z < 0.04
        ear_tip = point.z > 0.38 and point.x < -0.22
        if not muzzle and not paw and not ear_tip:
            fur_indices.append(vertex.index)
    if fur_indices:
        fur_group.add(fur_indices, 1.0, "REPLACE")
    texture = bpy.data.textures.new("SquirrelFurNoise", type="CLOUDS")
    texture.noise_scale = 0.07
    texture.noise_depth = 5
    texture.nabla = 0.02
    displace = obj.modifiers.new("SquirrelFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = strength
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)
    fine = bpy.data.textures.new("SquirrelFurFine", type="CLOUDS")
    fine.noise_scale = 0.028
    fine.noise_depth = 3
    fine_displace = obj.modifiers.new("SquirrelFurFineDisplace", "DISPLACE")
    fine_displace.texture = fine
    fine_displace.texture_coords = "LOCAL"
    fine_displace.vertex_group = fur_group.name
    fine_displace.strength = strength * 0.50
    fine_displace.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier=fine_displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("SquirrelWeightedNormals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    bpy.ops.object.shade_smooth()


def _coat_tick(color: tuple[float, float, float], point: Vector) -> tuple[float, float, float]:
    """Agouti ticking: short light/dark bands along the guard-hair direction."""
    band = 0.5 + 0.5 * np.sin(point.x * 58.0 + point.z * 34.0 + point.y * 22.0)
    grain = 0.5 + 0.5 * np.sin(point.x * 110.0 - point.y * 84.0 + point.z * 46.0)
    mix = 0.80 + 0.12 * band + 0.08 * (grain - 0.5)
    return tuple(float(np.clip(channel * mix, 0.0, 1.0)) for channel in color)


def paint_squirrel_coat(obj: bpy.types.Object) -> None:
    """Rust dorsal, cream belly, darker ear backs and tail tip, dark paws."""
    color_layer = obj.data.color_attributes.new(
        name="squirrel_regions", type="BYTE_COLOR", domain="POINT"
    )
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    length = max(max_x - min_x, 1e-6)
    height = max(max_z - min_z, 1e-6)
    # Tail fluff is wider than the ribcage. Measuring side_ratio from the whole
    # AABB painted the torso as belly cream.
    body_width = max(
        (abs(point.y) for point in points if (point.x - min_x) / length < 0.58),
        default=1e-6,
    )
    rust = (0.72, 0.24, 0.07)
    dark_rust = (0.28, 0.09, 0.04)
    cream = (0.93, 0.86, 0.72)
    for index, vertex in enumerate(obj.data.vertices):
        point = vertex.co
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        side_ratio = abs(point.y) / max(body_width, 1e-6)
        if height_ratio < 0.09:
            color = (0.14, 0.08, 0.04)
        elif nose_to_rump < 0.035 and 0.36 < height_ratio < 0.54:
            color = (0.08, 0.04, 0.03)
        elif nose_to_rump < 0.14 and height_ratio < 0.56 and side_ratio < 0.55:
            color = _coat_tick((0.82, 0.58, 0.38), point)
        elif height_ratio > 0.78 and nose_to_rump < 0.34 and side_ratio > 0.22:
            color = _coat_tick(dark_rust, point)
        elif nose_to_rump > 0.88:
            color = _coat_tick(dark_rust, point)
        elif height_ratio < 0.30 and side_ratio < 0.55 and nose_to_rump < 0.56:
            color = _coat_tick(cream, point)
        elif nose_to_rump > 0.60:
            color = _coat_tick((0.62, 0.20, 0.07), point)
        elif height_ratio > 0.42:
            color = _coat_tick(rust, point)
        else:
            color = _coat_tick((0.78, 0.36, 0.14), point)
        color_layer.data[index].color = (*color, 1.0)


def create_squirrel_rig(obj: bpy.types.Object):
    """Fit dark eyes, a wet nose, and winter ear tufts onto the normalized squirrel."""
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    max_y = max(abs(point.y) for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)

    def ax(fraction: float) -> float:
        return min_x + fraction * (max_x - min_x)

    def az(fraction: float) -> float:
        return min_z + fraction * (max_z - min_z)

    # Side of the skull, not the muzzle tip. The first snap on wolf landed on the nose.
    eye_left = snap_point_to_mesh_surface(
        obj, Vector((ax(0.16), max_y * 0.42, az(0.58))), outward=-0.002
    )
    eye_right = snap_point_to_mesh_surface(
        obj, Vector((ax(0.16), -max_y * 0.42, az(0.58))), outward=-0.002
    )
    nose = snap_point_to_mesh_surface(obj, Vector((ax(0.02), 0.0, az(0.46))), outward=0.001)
    ear_left = snap_point_to_mesh_surface(obj, Vector((ax(0.22), max_y * 0.48, az(0.92))), outward=0.001)
    ear_right = snap_point_to_mesh_surface(
        obj, Vector((ax(0.22), -max_y * 0.48, az(0.92))), outward=0.001
    )
    armature, details = create_quadruped_rig(
        obj,
        "SquirrelRig",
        (ax(0.36), 0.0, az(0.42)),
        (ax(0.58), 0.0, az(0.48)),
        {
            "Neck": ((ax(0.30), 0.0, az(0.50)), (ax(0.14), 0.0, az(0.62))),
            "Tail": ((ax(0.64), 0.0, az(0.48)), (ax(0.90), 0.0, az(0.62))),
            "FrontLeftLeg": ((ax(0.28), max_y * 0.40, az(0.38)), (ax(0.26), max_y * 0.40, 0.01)),
            "FrontRightLeg": ((ax(0.28), -max_y * 0.40, az(0.38)), (ax(0.26), -max_y * 0.40, 0.01)),
            "BackLeftLeg": ((ax(0.56), max_y * 0.44, az(0.40)), (ax(0.52), max_y * 0.44, 0.01)),
            "BackRightLeg": ((ax(0.56), -max_y * 0.44, az(0.40)), (ax(0.52), -max_y * 0.44, 0.01)),
            "EyeLeft": (tuple(eye_left), (eye_left.x, eye_left.y, eye_left.z + 0.012)),
            "EyeRight": (tuple(eye_right), (eye_right.x, eye_right.y, eye_right.z + 0.012)),
        },
        {
            "neck_x": ax(0.28),
            "neck_z": az(0.40),
            "tail_x": ax(0.62),
            "tail_z": az(0.30),
            "tail_y": max_y * 0.85,
            "leg_z": az(0.32),
            "front_leg_x": ax(0.40),
            "back_leg_x": ax(0.50),
            "eye_x": abs(float(eye_left.x)),
            "eye_scale": (0.007, 0.004, 0.006),
            "pupil_scale": (0.003, 0.002, 0.003),
            "pupil_offset": 0.002,
            "tail_tuft_scale": (0.008, 0.008, 0.008),
        },
        eye_specs=None,
        tail_specs=None,
    )

    # Shared eye helper places pupils 1.5 cm in front of the socket. That offset
    # is livestock-sized and would float off a 5 cm squirrel skull, so eyes are
    # authored here at species scale.
    eye_material = create_flat_material("squirrelrig_eye", (0.10, 0.05, 0.03, 1.0))
    eye_shader = eye_material.node_tree.nodes.get("Principled BSDF")
    eye_shader.inputs["Roughness"].default_value = 0.12
    pupil_material = create_flat_material("squirrelrig_pupil", (0.012, 0.008, 0.005, 1.0))
    for side, anchor, bone_name in (
        ("Left", eye_left, "EyeLeft"),
        ("Right", eye_right, "EyeRight"),
    ):
        eye = add_uv_sphere(
            f"Eye{side}",
            tuple(anchor),
            (0.0090, 0.0060, 0.0078),
            eye_material,
        )
        outward = Vector((-0.0030, 0.0016 if anchor.y > 0.0 else -0.0016, 0.0))
        pupil = add_uv_sphere(
            f"Pupil{side}",
            tuple(anchor + outward),
            (0.0040, 0.0026, 0.0036),
            pupil_material,
        )
        parent_to_bone(eye, armature, bone_name)
        parent_to_bone(pupil, armature, bone_name)
        details.extend([eye, pupil])

    nose_material = create_flat_material("squirrelrig_nose", (0.08, 0.04, 0.03, 1.0))
    nose_shader = nose_material.node_tree.nodes.get("Principled BSDF")
    nose_shader.inputs["Roughness"].default_value = 0.20
    nose_obj = add_uv_sphere("NoseTip", tuple(nose), (0.0045, 0.0038, 0.0032), nose_material)
    parent_to_bone(nose_obj, armature, "Neck")
    details.append(nose_obj)

    tuft_material = create_flat_material("squirrelrig_tuft", (0.42, 0.14, 0.06, 1.0))
    for side, anchor in (("Left", ear_left), ("Right", ear_right)):
        tip = anchor + Vector((0.0, 0.0, 0.007))
        tuft = add_tapered_segment(f"EarTuft{side}", anchor, tip, 0.0032, 0.0010, tuft_material)
        bpy.context.view_layer.objects.active = tuft
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
        bpy.ops.object.mode_set(mode="OBJECT")
        parent_to_bone(tuft, armature, "Neck")
        details.append(tuft)

    armature["procedural_squirrel"] = True
    return armature, details


def render_preview() -> None:
    scene = bpy.context.scene
    engine_items = scene.render.bl_rna.properties["engine"].enum_items
    engine_ids = {item.identifier for item in engine_items}
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engine_ids else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("SquirrelPreviewWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.40, 0.44, 0.36, 1.0)
    background.inputs["Strength"].default_value = 0.85
    sun = bpy.data.lights.new("SquirrelKey", "SUN")
    sun.energy = 3.4
    sun_object = bpy.data.objects.new("SquirrelKey", sun)
    scene.collection.objects.link(sun_object)
    sun_object.rotation_euler = (0.85, 0.15, 0.9)
    camera_data = bpy.data.cameras.new("SquirrelCam")
    camera_data.lens = 60
    camera = bpy.data.objects.new("SquirrelCam", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (-0.38, -0.52, 0.18)
    aim = Vector((0.04, 0.0, 0.11)) - camera.location
    camera.rotation_euler = aim.to_track_quat("-Z", "Y").to_euler()
    preview = REPORTS / "squirrel_preview.png"
    scene.render.filepath = str(preview)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    pipeline.TEXTURES = TEXTURES
    pipeline.clear_scene()
    obj = create_squirrel_mesh()
    raw = pipeline.topology(obj)
    # Light smoothing keeps the muzzle, ear bases, and plume. Heavy smooth
    # passes melt the species read back into a loaf.
    pipeline.rebuild_surface(
        obj,
        128.0,
        12_000,
        smooth_factor=0.16,
        smooth_iterations=2,
    )
    apply_squirrel_fur_displacement(obj, strength=0.016)
    pipeline.normalize_dimensions(obj, DIMENSIONS_M)
    pipeline.make_uv(obj)
    normal = pipeline.bake_normal_map(obj, "squirrel", SURFACE_PROFILE)
    roughness = pipeline.bake_roughness_map(obj, "squirrel", SURFACE_PROFILE)
    paint_squirrel_coat(obj)
    albedo = pipeline.new_image("squirrel_albedo", (0.58, 0.28, 0.12, 1.0))
    albedo.filepath_raw = str(TEXTURES / "squirrel_albedo.png")
    albedo.file_format = "PNG"
    albedo.save()
    pipeline.assign_pbr_material(obj, "squirrel", albedo, normal, roughness, SURFACE_PROFILE)
    coat = obj.data.materials[0]
    coat_shader = coat.node_tree.nodes.get("Principled BSDF")
    specular = coat_shader.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.16
    sheen = coat_shader.inputs.get("Sheen Weight")
    if sheen is not None:
        sheen.default_value = 0.22
    production = pipeline.topology(obj)
    armature, details = create_squirrel_rig(obj)
    render_preview()
    pipeline.export_glb(obj, OUTPUT, armature, details)
    report = {
        "asset_id": "creature.squirrel",
        "route": "authored_closed_anatomy_blender_pbr",
        "source_license": "project-authored",
        "anatomy_decision": "remeshed_red_squirrel_tufted_ears_bushy_plume_cream_belly",
        "scale_basis": "0.48 m nose-to-tail; 0.22 m plume/ear height; 0.11 m chest width",
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "metric_dimensions_m_y_up": list(DIMENSIONS_M),
        "animations": ["Idle-loop", "Walk-loop"],
    }
    (REPORTS / "squirrel_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        "ASSET_METRICS="
        + json.dumps({"triangles": production["triangles"], "sha256": report["output_sha256"]})
    )


if __name__ == "__main__":
    main()
