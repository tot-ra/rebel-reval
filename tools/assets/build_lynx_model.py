"""Build a game-ready Eurasian lynx for the mammal catalog.

The catalog silhouette is a low-poly ellipsoid loaf. This pass replaces it with
closed anatomical volumes, a spotted tawny coat, ear tufts, a cheek ruff, and
the shared quadruped clips so the animal reads at street range.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_lynx_model.py
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
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
OUTPUT = ROOT / "assets/animals/medieval/medieval_lynx.glb"
REPORT = ROOT / "generated/comfyui/medieval_animals_v1/production/reports/lynx_report.json"

# Nose-to-rump, standing height including ear tufts, body width.
DIMENSIONS_M = (1.18, 0.74, 0.36)
TRIANGLES = 14_000
VOXEL_DIVISOR = 150.0

SURFACE_PROFILE = {
    # Guard-hair breakup. The spots live in the coat colors; this only keeps
    # the remeshed hull from reading as clay or plastic.
    "noise_scale": 78.0,
    "noise_detail": 5.0,
    "bump_strength": 0.34,
    "rough_min": 0.84,
    "rough_max": 0.96,
    "normal_strength": 0.82,
}


def lynx_spot(point: Vector) -> bool:
    """Large broken rosettes. Cells are wide so neighboring vertices agree."""
    cell = 0.036
    ix = int(math.floor(point.x / cell))
    iy = int(math.floor(point.y / cell))
    iz = int(math.floor((point.z + point.x * 0.35) / cell))
    scramble = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
    scramble = (scramble ^ (scramble >> 13)) * 1274126177
    return (scramble & 255) < 52


def lynx_coat_color(point: Vector, bounds: dict[str, float]) -> tuple[float, float, float]:
    """Tawny Eurasian coat: cream belly and ruff, black ear backs, tail tip, spots."""
    length = max(bounds["max_x"] - bounds["min_x"], 1e-6)
    height = max(bounds["max_z"] - bounds["min_z"], 1e-6)
    nose_to_rump = (point.x - bounds["min_x"]) / length
    height_ratio = (point.z - bounds["min_z"]) / height
    side_ratio = abs(point.y) / max(bounds["max_y"], 1e-6)
    # Only the ear tips go black. Painting the whole ear reads as horns.
    if height_ratio > 0.93 and 0.08 < nose_to_rump < 0.40 and side_ratio > 0.25:
        return (0.04, 0.028, 0.02)
    # Bob-tail tip is black; the dock stays tawny so the tail still reads.
    if nose_to_rump > 0.90:
        return (0.03, 0.02, 0.015)
    if nose_to_rump > 0.82 and height_ratio > 0.42 and side_ratio < 0.35:
        return pipeline._coat_wobble((0.42, 0.28, 0.16), point, 0.04)
    # Dark stockings above pale toes.
    if height_ratio < 0.07:
        return (0.62, 0.48, 0.32)
    if height_ratio < 0.16 and (nose_to_rump < 0.46 or nose_to_rump > 0.55):
        return pipeline._coat_wobble((0.28, 0.16, 0.08), point, 0.04)
    # Nose leather stays on the tip. The muzzle itself is pale, not a brown bulb.
    if nose_to_rump < 0.045 and 0.55 < height_ratio < 0.72:
        return (0.16, 0.07, 0.05)
    if nose_to_rump < 0.14 and height_ratio < 0.58 and side_ratio < 0.45:
        return (0.84, 0.78, 0.68)
    # Cheek ruff is only a little lighter than the crown.
    if 0.10 < nose_to_rump < 0.32 and side_ratio > 0.62 and 0.45 < height_ratio < 0.75:
        return pipeline._coat_wobble((0.68, 0.50, 0.32), point, 0.04)
    # Cream belly and inner legs.
    if side_ratio < 0.28 and height_ratio < 0.40 and nose_to_rump < 0.78:
        return pipeline._coat_wobble((0.88, 0.82, 0.72), point, 0.04)
    if lynx_spot(point) and 0.10 < nose_to_rump < 0.86 and height_ratio > 0.18:
        return (0.08, 0.05, 0.03)
    return pipeline._coat_wobble((0.58, 0.40, 0.22), point, 0.07)


def create_lynx_mesh() -> bpy.types.Object:
    """Closed volumes for a long-legged felid with a ruff, tall ears, and a bob tail.

    WHY: voxel remesh fuses these masses into one hide. Thin ear tufts and the
    black tail pencil are added after remesh so the voxel size cannot eat them.
    """
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 18,
        ring_count: int = 10,
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
        vertices: int = 12,
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

    # Long torso, modest rump. A lynx reads as leggy, not as a heavy-haunched dog.
    sphere("LynxBarrel", (0.04, 0.0, 0.40), (0.30, 0.105, 0.11), 26, 14)
    sphere("LynxChest", (-0.16, 0.0, 0.39), (0.14, 0.12, 0.125), 20, 12)
    sphere("LynxRump", (0.26, 0.0, 0.43), (0.13, 0.11, 0.12), 20, 12)
    sphere("LynxBelly", (0.04, 0.0, 0.32), (0.22, 0.08, 0.06), 18, 10)
    sphere("LynxTopline", (0.02, 0.0, 0.50), (0.22, 0.06, 0.035), 16, 8)

    segment("LynxNeck", (-0.18, 0.0, 0.44), (-0.34, 0.0, 0.52), 0.11, 0.08)
    sphere("LynxSkull", (-0.44, 0.0, 0.55), (0.12, 0.11, 0.10), 22, 12)
    sphere("LynxForehead", (-0.44, 0.0, 0.62), (0.07, 0.08, 0.04), 14, 8)
    # Wide cheeks, not hanging cotton lobes.
    sphere("LynxCheekLeft", (-0.40, 0.09, 0.52), (0.05, 0.04, 0.045), 12, 8)
    sphere("LynxCheekRight", (-0.40, -0.09, 0.52), (0.05, 0.04, 0.045), 12, 8)
    sphere("LynxMuzzle", (-0.56, 0.0, 0.51), (0.055, 0.042, 0.035), 16, 10)
    sphere("LynxChin", (-0.50, 0.0, 0.47), (0.045, 0.04, 0.025), 12, 8)
    # Splayed triangular ears. Tall thin cones remesh into black horns.
    segment("LynxEarLeft", (-0.40, 0.05, 0.62), (-0.38, 0.11, 0.73), 0.048, 0.016, 10)
    segment("LynxEarRight", (-0.40, -0.05, 0.62), (-0.38, -0.11, 0.73), 0.048, 0.016, 10)
    segment("LynxTail", (0.36, 0.0, 0.46), (0.52, 0.02, 0.40), 0.042, 0.026, 10)

    for side, y in (("Left", 0.085), ("Right", -0.085)):
        sphere(f"LynxFront{side}Shoulder", (-0.16, y, 0.36), (0.07, 0.05, 0.08), 12, 8)
        segment(
            f"LynxFront{side}Upper",
            (-0.16, y, 0.38),
            (-0.17, y, 0.20),
            0.048,
            0.032,
        )
        segment(
            f"LynxFront{side}Lower",
            (-0.17, y, 0.22),
            (-0.19, y, 0.055),
            0.030,
            0.022,
            10,
        )
        # Snowshoe paw: wider than the cannon, planted flat.
        sphere(f"LynxFront{side}Paw", (-0.20, y, 0.038), (0.055, 0.04, 0.032), 14, 8)
        sphere(f"LynxBack{side}Hip", (0.22, y, 0.38), (0.08, 0.055, 0.09), 12, 8)
        segment(
            f"LynxBack{side}Thigh",
            (0.22, y, 0.40),
            (0.24, y, 0.20),
            0.052,
            0.034,
        )
        segment(
            f"LynxBack{side}Cannon",
            (0.24, y, 0.22),
            (0.22, y, 0.055),
            0.030,
            0.022,
            10,
        )
        sphere(f"LynxBack{side}Paw", (0.22, y, 0.038), (0.058, 0.042, 0.032), 14, 8)

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
    obj["species"] = "lynx"
    return obj


def apply_lynx_fur(obj: bpy.types.Object) -> None:
    """Light guard-hair relief on the torso only.

    WHY: displacing the ears, muzzle, or paws melts the silhouette that makes
    the animal a lynx. The normal map carries the finer hair.
    """
    fur_group = obj.vertex_groups.new(name="LynxFurDisplace")
    indices = [
        vertex.index
        for vertex in obj.data.vertices
        if vertex.co.z > 0.16 and vertex.co.x > -0.36 and vertex.co.x < 0.40 and vertex.co.z < 0.62
    ]
    if not indices:
        return
    fur_group.add(indices, 1.0, "REPLACE")
    texture = bpy.data.textures.new("LynxFurNoise", type="CLOUDS")
    texture.noise_scale = 0.09
    texture.noise_depth = 4
    displace = obj.modifiers.new("LynxFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = 0.012
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()


def _bounds(obj: bpy.types.Object) -> dict[str, float]:
    points = [vertex.co for vertex in obj.data.vertices]
    return {
        "min_x": min(point.x for point in points),
        "max_x": max(point.x for point in points),
        "max_y": max(abs(point.y) for point in points),
        "min_z": min(point.z for point in points),
        "max_z": max(point.z for point in points),
    }


def create_lynx_rig(obj: bpy.types.Object) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    """Quadruped rig fitted to the normalized lynx, plus tufts and a black tail tip."""
    bounds = _bounds(obj)
    length = bounds["max_x"] - bounds["min_x"]
    height = bounds["max_z"] - bounds["min_z"]
    half_width = bounds["max_y"]

    def at_fraction(along: float, side: float, up: float) -> Vector:
        return Vector(
            (
                bounds["min_x"] + length * along,
                half_width * side,
                bounds["min_z"] + height * up,
            )
        )

    eye_probe_left = snap_point_to_mesh_surface(obj, at_fraction(0.10, 0.28, 0.74), outward=0.004)
    eye_probe_right = snap_point_to_mesh_surface(obj, at_fraction(0.10, -0.28, 0.74), outward=0.004)
    nose_probe = snap_point_to_mesh_surface(obj, at_fraction(0.02, 0.0, 0.66), outward=0.004)
    ear_left = snap_point_to_mesh_surface(obj, at_fraction(0.16, 0.42, 0.96), outward=0.002)
    ear_right = snap_point_to_mesh_surface(obj, at_fraction(0.16, -0.42, 0.96), outward=0.002)
    tail_root = at_fraction(0.78, 0.0, 0.62)
    tail_tip = snap_point_to_mesh_surface(obj, at_fraction(0.98, 0.0, 0.52), outward=0.004)

    def tup(point: Vector) -> tuple[float, float, float]:
        return (point.x, point.y, point.z)

    armature, details = create_quadruped_rig(
        obj,
        "LynxRig",
        tup(at_fraction(0.42, 0.0, 0.48)),
        tup(at_fraction(0.70, 0.0, 0.58)),
        {
            "Neck": (tup(at_fraction(0.34, 0.0, 0.58)), tup(at_fraction(0.16, 0.0, 0.74))),
            "Tail": (tup(tail_root), tup(tail_tip)),
            "FrontLeftLeg": (tup(at_fraction(0.32, 0.42, 0.46)), tup(at_fraction(0.30, 0.42, 0.06))),
            "FrontRightLeg": (tup(at_fraction(0.32, -0.42, 0.46)), tup(at_fraction(0.30, -0.42, 0.06))),
            "BackLeftLeg": (tup(at_fraction(0.68, 0.46, 0.50)), tup(at_fraction(0.66, 0.46, 0.06))),
            "BackRightLeg": (tup(at_fraction(0.68, -0.46, 0.50)), tup(at_fraction(0.66, -0.46, 0.06))),
            "EyeLeft": (tup(eye_probe_left), (eye_probe_left.x, eye_probe_left.y, eye_probe_left.z + 0.04)),
            "EyeRight": (
                tup(eye_probe_right),
                (eye_probe_right.x, eye_probe_right.y, eye_probe_right.z + 0.04),
            ),
        },
        {
            "neck_x": at_fraction(0.30, 0.0, 0.0).x,
            "neck_z": at_fraction(0.0, 0.0, 0.52).z,
            "tail_x": at_fraction(0.80, 0.0, 0.0).x,
            "tail_z": at_fraction(0.0, 0.0, 0.40).z,
            "tail_y": half_width * 0.35,
            "leg_z": at_fraction(0.0, 0.0, 0.42).z,
            "front_leg_x": at_fraction(0.40, 0.0, 0.0).x,
            "back_leg_x": at_fraction(0.58, 0.0, 0.0).x,
            "eye_x": abs(eye_probe_left.x),
            "eye_scale": (0.020, 0.012, 0.018),
            "pupil_scale": (0.009, 0.005, 0.011),
            "pupil_offset": 0.006,
            "tail_tuft_scale": (0.02, 0.02, 0.02),
        },
        eye_specs=[
            ("Left", eye_probe_left.y, eye_probe_left.z, "EyeLeft"),
            ("Right", eye_probe_right.y, eye_probe_right.z, "EyeRight"),
        ],
        tail_specs=None,
    )
    # The shared eye white is livestock-brown. Lynx irises are amber and wet.
    eye_material = bpy.data.materials.get("lynxrig_eye_white")
    if eye_material is not None and eye_material.node_tree is not None:
        shader = eye_material.node_tree.nodes.get("Principled BSDF")
        amber = (0.72, 0.42, 0.08, 1.0)
        eye_material.diffuse_color = amber
        shader.inputs["Base Color"].default_value = amber
        shader.inputs["Roughness"].default_value = 0.18
    nose_material = create_flat_material("lynxrig_nose", (0.09, 0.035, 0.03, 1.0))
    nose = add_uv_sphere("NoseTip", tup(nose_probe), (0.012, 0.014, 0.009), nose_material)
    parent_to_bone(nose, armature, "Neck")
    details.append(nose)

    tuft_material = create_flat_material("lynxrig_tuft", (0.02, 0.015, 0.012, 1.0))
    for side, anchor in (("Left", ear_left), ("Right", ear_right)):
        tip = anchor + Vector((0.0, 0.0, 0.032))
        tuft = add_tapered_segment(f"EarTuft{side}", anchor, tip, 0.010, 0.002, tuft_material)
        parent_to_bone(tuft, armature, "Neck")
        details.append(tuft)
    tail_cap = add_uv_sphere("TailTip", tup(tail_tip), (0.028, 0.026, 0.024), tuft_material)
    parent_to_bone(tail_cap, armature, "Tail")
    details.append(tail_cap)
    armature["procedural_lynx"] = True
    return armature, details


def build() -> dict:
    pipeline.clear_scene()
    obj = create_lynx_mesh()
    raw = pipeline.topology(obj)
    pipeline.rebuild_surface(
        obj,
        VOXEL_DIVISOR,
        TRIANGLES,
        smooth_factor=0.22,
        smooth_iterations=2,
    )
    apply_lynx_fur(obj)
    pipeline.normalize_dimensions(obj, DIMENSIONS_M)
    pipeline.make_uv(obj)

    original_color = pipeline.livestock_region_color

    def routed_color(name: str, point: Vector, bounds: dict[str, float]):
        if name == "lynx":
            return lynx_coat_color(point, bounds)
        return original_color(name, point, bounds)

    pipeline.livestock_region_color = routed_color
    try:
        albedo = pipeline.bake_livestock_region_albedo(obj, "lynx")
    finally:
        pipeline.livestock_region_color = original_color
    normal = pipeline.bake_normal_map(obj, "lynx", SURFACE_PROFILE)
    roughness = pipeline.bake_roughness_map(obj, "lynx", SURFACE_PROFILE)
    pipeline.assign_pbr_material(obj, "lynx", albedo, normal, roughness, SURFACE_PROFILE)
    armature, details = create_lynx_rig(obj)
    pipeline.export_glb(obj, OUTPUT, armature, details)
    production = pipeline.topology(obj)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    report = {
        "asset_id": "creature.lynx",
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "AGPL-3.0-or-later (project author)",
        "anatomy_decision": "remeshed_eurasian_lynx_ruff_ear_tufts_bob_tail_spotted_coat",
        "scale_basis": "1.18 m nose-to-rump; 0.74 m ear-tuft height; 0.36 m body width",
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": digest,
        "raw": raw,
        "production": production,
        "metric_dimensions_m_y_up": list(DIMENSIONS_M),
        "animations": ["Idle-loop", "Walk-loop", "Trot-loop", "Graze-loop"],
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print("LYNX_SHA256=" + digest)
    print(
        "LYNX_TRIANGLES="
        + str(production["triangles"])
        + " COMPONENTS="
        + str(production["components"])
    )
    return report


if __name__ == "__main__":
    build()
