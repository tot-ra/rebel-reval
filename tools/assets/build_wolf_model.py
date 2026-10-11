"""Build a game-ready Eurasian wolf GLB with closed anatomy and a fur coat.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_wolf_model.py

WHY: the catalog wolf is a six-segment ellipsoid loaf. At foreland range it
reads as a toy, not a wild canid. This pass authors a lean digitigrade body,
long muzzle, erect ears, neck ruff, and a low bushy tail, then fuses them into
one skinned surface with an agouti coat, guard-hair normals, and the shared
quadruped idle/walk contract.
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
OUTPUT = RUNTIME / "medieval_wolf.glb"

# Y-up contract: length, height, width. A large Baltic male: long body, ear
# tips under a metre, chest narrower than a bear.
DIMENSIONS_M = (1.72, 0.98, 0.40)

SURFACE_PROFILE = {
    "noise_scale": 118.0,
    "noise_detail": 6.0,
    "bump_strength": 0.50,
    "rough_min": 0.84,
    "rough_max": 0.97,
    "normal_strength": 1.05,
}


def create_wolf_mesh() -> bpy.types.Object:
    """Closed canid volumes. Head points along -X and the paws sit on Z=0."""
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

    # Deep ribcage, tucked loin, rounded haunch. The waist rise is the canid cue
    # that separates a wolf from the catalog loaf.
    sphere("WolfRibcage", (-0.10, 0.0, 0.46), (0.28, 0.125, 0.155), 26, 14)
    sphere("WolfShoulder", (-0.30, 0.0, 0.50), (0.15, 0.120, 0.145), 22, 12)
    sphere("WolfLoin", (0.12, 0.0, 0.50), (0.16, 0.085, 0.105), 20, 12)
    sphere("WolfHaunch", (0.32, 0.0, 0.50), (0.16, 0.115, 0.140), 22, 12)
    sphere("WolfBelly", (0.00, 0.0, 0.36), (0.24, 0.100, 0.080), 18, 10)
    sphere("WolfWithers", (-0.18, 0.0, 0.58), (0.18, 0.090, 0.070), 16, 10)

    segment("WolfNeck", (-0.32, 0.0, 0.54), (-0.50, 0.0, 0.64), 0.105, 0.075)
    sphere("WolfRuff", (-0.38, 0.0, 0.52), (0.10, 0.11, 0.09), 16, 10)
    sphere("WolfThroat", (-0.48, 0.0, 0.48), (0.08, 0.07, 0.06), 14, 8)

    sphere("WolfSkull", (-0.56, 0.0, 0.64), (0.11, 0.072, 0.080), 22, 12)
    sphere("WolfBrow", (-0.60, 0.0, 0.70), (0.06, 0.065, 0.035), 16, 8)
    sphere("WolfCheekLeft", (-0.58, 0.050, 0.60), (0.05, 0.030, 0.040), 12, 8)
    sphere("WolfCheekRight", (-0.58, -0.050, 0.60), (0.05, 0.030, 0.040), 12, 8)
    # Long narrow muzzle. A short dog snout is the main catalog failure.
    segment("WolfMuzzle", (-0.62, 0.0, 0.60), (-0.82, 0.0, 0.54), 0.050, 0.028, 12)
    sphere("WolfMuzzleStop", (-0.78, 0.0, 0.555), (0.045, 0.032, 0.028), 14, 8)
    sphere("WolfNoseLeather", (-0.84, 0.0, 0.535), (0.028, 0.022, 0.016), 12, 8)
    sphere("WolfJaw", (-0.70, 0.0, 0.530), (0.09, 0.034, 0.022), 16, 8)
    # Short triangular ears. Tall cones became the height extreme and normalized
    # into rabbit poles.
    for side, y in (("Left", 0.048), ("Right", -0.048)):
        segment(
            f"WolfEar{side}",
            (-0.54, y, 0.68),
            (-0.52, y * 1.15, 0.80),
            0.036,
            0.012,
            10,
        )

    for side, y in (("Left", 0.078), ("Right", -0.078)):
        segment(f"WolfFront{side}Upper", (-0.28, y, 0.46), (-0.34, y, 0.26), 0.042, 0.030)
        segment(f"WolfFront{side}Lower", (-0.34, y, 0.26), (-0.30, y, 0.06), 0.028, 0.020)
        sphere(f"WolfFront{side}Paw", (-0.36, y, 0.028), (0.075, 0.032, 0.024), 14, 8)
    for side, y in (("Left", 0.082), ("Right", -0.082)):
        sphere(f"WolfBack{side}Thigh", (0.26, y, 0.40), (0.10, 0.048, 0.12), 16, 10)
        segment(f"WolfBack{side}Gaskin", (0.20, y, 0.28), (0.32, y, 0.12), 0.034, 0.022)
        segment(f"WolfBack{side}Hock", (0.32, y, 0.12), (0.28, y, 0.045), 0.020, 0.016)
        sphere(f"WolfBack{side}Paw", (0.26, y, 0.026), (0.062, 0.030, 0.022), 14, 8)

    # One overlapping plume. Detached tail locks remeshed into a floating ball.
    segment("WolfTailBase", (0.42, 0.0, 0.52), (0.60, 0.0, 0.40), 0.060, 0.048)
    segment("WolfTailMid", (0.54, 0.0, 0.44), (0.76, 0.0, 0.32), 0.050, 0.034)
    segment("WolfTailTip", (0.70, 0.0, 0.36), (0.96, 0.0, 0.22), 0.036, 0.016)

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
    return obj


def apply_wolf_fur_displacement(obj: bpy.types.Object, *, strength: float = 0.016) -> None:
    """Break the remeshed hull into guard hair without wooling the muzzle or paws."""
    fur_group = obj.vertex_groups.new(name="WolfFurDisplace")
    fur_indices = []
    for vertex in obj.data.vertices:
        point = vertex.co
        muzzle = point.x < -0.70 and point.z > 0.42
        paw = point.z < 0.08
        if not muzzle and not paw:
            fur_indices.append(vertex.index)
    if fur_indices:
        fur_group.add(fur_indices, 1.0, "REPLACE")
    texture = bpy.data.textures.new("WolfFurNoise", type="CLOUDS")
    texture.noise_scale = 0.09
    texture.noise_depth = 5
    texture.nabla = 0.02
    displace = obj.modifiers.new("WolfFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = strength
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)
    fine = bpy.data.textures.new("WolfFurFine", type="CLOUDS")
    fine.noise_scale = 0.035
    fine.noise_depth = 3
    fine_displace = obj.modifiers.new("WolfFurFineDisplace", "DISPLACE")
    fine_displace.texture = fine
    fine_displace.texture_coords = "LOCAL"
    fine_displace.vertex_group = fur_group.name
    fine_displace.strength = strength * 0.45
    fine_displace.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier=fine_displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("WolfWeightedNormals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    bpy.ops.object.shade_smooth()


def _coat_tick(color: tuple[float, float, float], point: Vector) -> tuple[float, float, float]:
    """Agouti ticking: short light/dark bands along the guard-hair direction."""
    band = 0.5 + 0.5 * np.sin(point.x * 46.0 + point.z * 28.0 + point.y * 18.0)
    grain = 0.5 + 0.5 * np.sin(point.x * 91.0 - point.y * 73.0 + point.z * 37.0)
    mix = 0.82 + 0.10 * band + 0.08 * (grain - 0.5)
    return tuple(float(np.clip(channel * mix, 0.0, 1.0)) for channel in color)


def paint_wolf_coat(obj: bpy.types.Object) -> None:
    """Grey saddle, charcoal dorsal stripe, cream throat and muzzle, dark paws."""
    color_layer = obj.data.color_attributes.new(name="wolf_regions", type="BYTE_COLOR", domain="POINT")
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    max_y = max(abs(point.y) for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    length = max(max_x - min_x, 1e-6)
    height = max(max_z - min_z, 1e-6)
    for index, vertex in enumerate(obj.data.vertices):
        point = vertex.co
        nose_to_rump = (point.x - min_x) / length
        height_ratio = (point.z - min_z) / height
        side_ratio = abs(point.y) / max(max_y, 1e-6)
        if height_ratio < 0.08:
            color = (0.05, 0.045, 0.04)
        elif nose_to_rump < 0.045 and 0.40 < height_ratio < 0.58:
            color = (0.03, 0.022, 0.018)
        elif nose_to_rump < 0.09 and 0.42 < height_ratio < 0.64:
            color = _coat_tick((0.62, 0.56, 0.46), point)
        elif 0.12 < nose_to_rump < 0.26 and height_ratio > 0.58 and side_ratio > 0.22:
            color = _coat_tick((0.12, 0.11, 0.10), point)
        elif nose_to_rump > 0.88 and side_ratio < 0.55:
            color = (0.06, 0.055, 0.05)
        elif side_ratio < 0.20 and height_ratio > 0.55 and 0.12 < nose_to_rump < 0.82:
            color = _coat_tick((0.10, 0.09, 0.08), point)
        elif side_ratio < 0.42 and height_ratio < 0.40 and nose_to_rump < 0.58:
            color = _coat_tick((0.58, 0.52, 0.42), point)
        elif height_ratio > 0.84 and nose_to_rump < 0.42:
            color = (0.08, 0.07, 0.06)
        elif height_ratio > 0.46:
            color = _coat_tick((0.24, 0.22, 0.20), point)
        else:
            color = _coat_tick((0.36, 0.32, 0.28), point)
        color_layer.data[index].color = (*color, 1.0)


def create_wolf_rig(obj: bpy.types.Object):
    """Fit eyes, ears, and a wet nose onto the normalized wolf."""
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

    # Side of the skull, not the muzzle tip. The first snap landed on the nose.
    eye_left = snap_point_to_mesh_surface(
        obj, Vector((ax(0.24), max_y * 0.55, az(0.68))), outward=-0.008
    )
    eye_right = snap_point_to_mesh_surface(
        obj, Vector((ax(0.24), -max_y * 0.55, az(0.68))), outward=-0.008
    )
    nose = snap_point_to_mesh_surface(obj, Vector((ax(0.015), 0.0, az(0.50))), outward=0.004)
    armature, details = create_quadruped_rig(
        obj,
        "WolfRig",
        (ax(0.38), 0.0, az(0.50)),
        (ax(0.62), 0.0, az(0.54)),
        {
            "Neck": ((ax(0.34), 0.0, az(0.56)), (ax(0.16), 0.0, az(0.68))),
            "Tail": ((ax(0.70), 0.0, az(0.46)), (ax(0.92), 0.0, az(0.30))),
            "FrontLeftLeg": ((ax(0.32), max_y * 0.42, az(0.46)), (ax(0.32), max_y * 0.42, 0.02)),
            "FrontRightLeg": ((ax(0.32), -max_y * 0.42, az(0.46)), (ax(0.32), -max_y * 0.42, 0.02)),
            "BackLeftLeg": ((ax(0.64), max_y * 0.45, az(0.48)), (ax(0.60), max_y * 0.45, 0.02)),
            "BackRightLeg": ((ax(0.64), -max_y * 0.45, az(0.48)), (ax(0.60), -max_y * 0.45, 0.02)),
            "EyeLeft": (tuple(eye_left), (eye_left.x, eye_left.y, eye_left.z + 0.05)),
            "EyeRight": (tuple(eye_right), (eye_right.x, eye_right.y, eye_right.z + 0.05)),
        },
        {
            "neck_x": ax(0.30),
            "neck_z": az(0.48),
            "tail_x": ax(0.68),
            "tail_z": az(0.26),
            "tail_y": max_y * 0.70,
            "leg_z": az(0.38),
            "front_leg_x": ax(0.44),
            "back_leg_x": ax(0.54),
            "eye_x": abs(float(eye_left.x)),
            "eye_scale": (0.020, 0.011, 0.018),
            "pupil_scale": (0.009, 0.005, 0.010),
            "pupil_offset": 0.006,
            "tail_tuft_scale": (0.02, 0.02, 0.02),
        },
        eye_specs=[
            ("Left", float(eye_left.y), float(eye_left.z), "EyeLeft"),
            ("Right", float(eye_right.y), float(eye_right.z), "EyeRight"),
        ],
        tail_specs=None,
    )
    nose_material = create_flat_material("wolfrig_nose", (0.025, 0.018, 0.014, 1.0))
    nose_shader = nose_material.node_tree.nodes.get("Principled BSDF")
    nose_shader.inputs["Roughness"].default_value = 0.18
    nose_obj = add_uv_sphere("NoseTip", tuple(nose), (0.022, 0.018, 0.014), nose_material)
    parent_to_bone(nose_obj, armature, "Neck")
    details.append(nose_obj)

    for detail in details:
        if not detail.name.startswith("Eye") and not detail.name.startswith("Pupil"):
            continue
        shader = detail.data.materials[0].node_tree.nodes.get("Principled BSDF")
        if detail.name.startswith("Eye"):
            shader.inputs["Base Color"].default_value = (0.62, 0.34, 0.06, 1.0)
            shader.inputs["Roughness"].default_value = 0.14
        else:
            shader.inputs["Roughness"].default_value = 0.35
    armature["procedural_wolf"] = True
    return armature, details


def render_preview() -> None:
    scene = bpy.context.scene
    engine_items = scene.render.bl_rna.properties["engine"].enum_items
    engine_ids = {item.identifier for item in engine_items}
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engine_ids else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("WolfPreviewWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.42, 0.46, 0.43, 1.0)
    background.inputs["Strength"].default_value = 0.85
    sun = bpy.data.lights.new("WolfKey", "SUN")
    sun.energy = 3.2
    sun_object = bpy.data.objects.new("WolfKey", sun)
    scene.collection.objects.link(sun_object)
    sun_object.rotation_euler = (0.85, 0.15, 0.9)
    camera_data = bpy.data.cameras.new("WolfCam")
    camera_data.lens = 55
    camera = bpy.data.objects.new("WolfCam", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (-1.55, -1.85, 0.72)
    aim = Vector((-0.05, 0.0, 0.42)) - camera.location
    camera.rotation_euler = aim.to_track_quat("-Z", "Y").to_euler()
    preview = REPORTS / "wolf_preview.png"
    scene.render.filepath = str(preview)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    pipeline.TEXTURES = TEXTURES
    pipeline.clear_scene()
    obj = create_wolf_mesh()
    raw = pipeline.topology(obj)
    # Light smoothing keeps the muzzle and ear bases. The bear lesson was that
    # heavy smooth passes melt the species read back into a loaf.
    pipeline.rebuild_surface(
        obj,
        108.0,
        14_000,
        smooth_factor=0.26,
        smooth_iterations=3,
    )
    apply_wolf_fur_displacement(obj, strength=0.014)
    pipeline.normalize_dimensions(obj, DIMENSIONS_M)
    pipeline.make_uv(obj)
    normal = pipeline.bake_normal_map(obj, "wolf", SURFACE_PROFILE)
    roughness = pipeline.bake_roughness_map(obj, "wolf", SURFACE_PROFILE)
    paint_wolf_coat(obj)
    albedo = pipeline.new_image("wolf_albedo", (0.40, 0.38, 0.34, 1.0))
    albedo.filepath_raw = str(TEXTURES / "wolf_albedo.png")
    albedo.file_format = "PNG"
    albedo.save()
    pipeline.assign_pbr_material(obj, "wolf", albedo, normal, roughness, SURFACE_PROFILE)
    coat = obj.data.materials[0]
    coat_shader = coat.node_tree.nodes.get("Principled BSDF")
    specular = coat_shader.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.18
    production = pipeline.topology(obj)
    armature, details = create_wolf_rig(obj)
    render_preview()
    pipeline.export_glb(obj, OUTPUT, armature, details)
    report = {
        "asset_id": "creature.wolf",
        "route": "authored_closed_anatomy_blender_pbr",
        "source_license": "project-authored",
        "anatomy_decision": "remeshed_digitigrade_wolf_long_muzzle_ruff_bushy_tail",
        "scale_basis": "1.72 m nose-to-tail; 0.98 m ear height; 0.40 m chest width",
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "metric_dimensions_m_y_up": list(DIMENSIONS_M),
        "animations": ["Idle-loop", "Walk-loop"],
    }
    (REPORTS / "wolf_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("ASSET_METRICS=" + json.dumps({"triangles": production["triangles"], "sha256": report["output_sha256"]}))


if __name__ == "__main__":
    main()
