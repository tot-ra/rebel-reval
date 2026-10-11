"""Build the game-ready medieval street dog GLB with authored closed anatomy.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_medieval_dog.py

WHY: the P2-024 Lower Town street dog used the shared procedural silhouette
(six-segment tubes, no muzzle, no paws), which reads as a toy at street range.
This pass authors a closed hound mesh - deep chest, tucked waist, angled hocks,
pricked spitz ears, sickle tail - and reuses the livestock PBR bake pipeline and
quadruped rig so the dog matches the shipped cattle/pig/sheep/horse quality bar.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ASSET_TOOL_DIR = Path(__file__).resolve().parent
if str(ASSET_TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOL_DIR))

import build_medieval_animal_models as pipeline
from medieval_animal_rigs import create_dog_rig

ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "generated/comfyui/medieval_animals_v1"
RUNTIME = ROOT / "assets/animals/medieval"
REPORTS = STAGING / "production/reports"
TEXTURES = STAGING / "production/textures"

OUTPUT = RUNTIME / "medieval_dog.glb"

# Game contract Y-up order: length, height, width. A medium spitz-type hound:
# 1.02 m nose-to-tail, 0.64 m to the pricked ear tips, 0.30 m chest width.
DIMENSIONS_M = (1.02, 0.64, 0.30)

# Short coarse tawny coat; a finer noise grain than cattle hide.
SURFACE_PROFILE = {
    "noise_scale": 48.0,
    "noise_detail": 3.5,
    "bump_strength": 0.24,
    "rough_min": 0.80,
    "rough_max": 0.92,
    "normal_strength": 0.70,
}

SPEC = {
    "base_color": (0.34, 0.24, 0.13),
    "accent_color": (0.52, 0.40, 0.24),
    "seed": 208744136,
}


def create_dog_mesh() -> bpy.types.Object:
    """Build a coherent low-poly hound from closed anatomical volumes.

    Head points along -X and feet rest on Z=0, matching the shared quadruped
    rig convention. Distinct ribcage, tucked loin, and haunch masses avoid the
    single-blob silhouette; separate muzzle, jaw, ears, and paws keep the face
    and stance legible at the ambient-fauna camera distance.
    """
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ) -> bpy.types.Object:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
        part = bpy.context.object
        part.name = part_name
        part.rotation_euler = rotation
        part.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
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

    # Deep ribcage over the shoulders, a tucked loin, and a rounded haunch: the
    # waist rise toward the rear is the strongest hound silhouette cue.
    sphere("DogRibcage", (-0.16, 0.0, 0.40), (0.20, 0.115, 0.145))
    sphere("DogShoulder", (-0.28, 0.0, 0.42), (0.13, 0.110, 0.130))
    sphere("DogLoin", (0.08, 0.0, 0.425), (0.16, 0.095, 0.115))
    sphere("DogHaunch", (0.26, 0.0, 0.425), (0.125, 0.100, 0.120))

    # The neck rises into a long skull with a separate muzzle and jaw.
    segment("DogNeck", (-0.30, 0.0, 0.46), (-0.44, 0.0, 0.575), 0.095, 0.070)
    sphere("DogSkull", (-0.50, 0.0, 0.585), (0.095, 0.072, 0.080))
    segment("DogMuzzle", (-0.545, 0.0, 0.565), (-0.675, 0.0, 0.525), 0.046, 0.026)
    sphere("DogJaw", (-0.565, 0.0, 0.522), (0.065, 0.048, 0.026))

    # Pricked spitz ears stay separate volumes so they read in profile.
    for side, y in (("Left", 0.055), ("Right", -0.055)):
        tilt = 0.023 if y > 0.0 else -0.023
        segment(
            "DogEar%s" % side,
            (-0.450, y, 0.640),
            (-0.465, y + tilt, 0.735),
            0.036,
            0.006,
            10,
        )

    # Front legs column straight under the shoulder; rear legs carry the hound
    # angulation (thigh forward, hock back) with explicit thigh muscle volume.
    for side, y in (("Left", 0.078), ("Right", -0.078)):
        segment("DogFront%sUpper" % side, (-0.26, y, 0.40), (-0.27, y, 0.22), 0.045, 0.035)
        segment("DogFront%sLower" % side, (-0.27, y, 0.22), (-0.275, y, 0.05), 0.032, 0.026)
        sphere("DogFront%sPaw" % side, (-0.285, y, 0.035), (0.055, 0.042, 0.032))
    for side, y in (("Left", 0.085), ("Right", -0.085)):
        sphere("DogBack%sThigh" % side, (0.225, y, 0.335), (0.115, 0.052, 0.120))
        segment("DogBack%sGaskin" % side, (0.17, y, 0.24), (0.25, y, 0.10), 0.035, 0.026)
        segment("DogBack%sHock" % side, (0.25, y, 0.10), (0.24, y, 0.04), 0.024, 0.020)
        sphere("DogBack%sPaw" % side, (0.225, y, 0.032), (0.052, 0.040, 0.030))

    # A three-bend sickle tail carried above the back line.
    segment("DogTailBase", (0.36, 0.0, 0.47), (0.44, 0.0, 0.55), 0.035, 0.028)
    segment("DogTailMid", (0.44, 0.0, 0.55), (0.50, 0.0, 0.63), 0.028, 0.020)
    segment("DogTailTip", (0.50, 0.0, 0.63), (0.52, 0.0, 0.70), 0.020, 0.010)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    # The active ribcage keeps its old object origin after joining. Reset it
    # before metric normalization so the exported skin inherits no offset.
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)

    pipeline.clear_scene()
    obj = create_dog_mesh()
    raw = pipeline.topology(obj)
    # Measure the raw span before metric normalization so the rig can map its
    # authored anchors (eyes, nose, bones, group cut planes) into final space.
    raw_points = [vertex.co for vertex in obj.data.vertices]
    raw_span = Vector(
        (
            max(p.x for p in raw_points) - min(p.x for p in raw_points),
            max(p.y for p in raw_points) - min(p.y for p in raw_points),
            max(p.z for p in raw_points) - min(p.z for p in raw_points),
        )
    )
    pipeline.normalize_dimensions(obj, DIMENSIONS_M)
    coord_scale = Vector(
        (
            DIMENSIONS_M[0] / max(raw_span.x, 1e-6),
            DIMENSIONS_M[2] / max(raw_span.y, 1e-6),
            DIMENSIONS_M[1] / max(raw_span.z, 1e-6),
        )
    )
    pipeline.make_uv(obj)
    albedo = pipeline.create_albedo("dog", SPEC)
    normal = pipeline.bake_normal_map(obj, "dog", SURFACE_PROFILE)
    roughness = pipeline.bake_roughness_map(obj, "dog", SURFACE_PROFILE)
    pipeline.assign_pbr_material(obj, "dog", albedo, normal, roughness, SURFACE_PROFILE)
    production = pipeline.topology(obj)
    armature, details = create_dog_rig(obj, coord_scale)
    pipeline.export_glb(obj, OUTPUT, armature, details)

    report = {
        "asset_id": "creature.dog",
        "route": "authored_closed_anatomy_blender_pbr",
        "source_license": "project-authored",
        "anatomy_decision": "authored_closed_four_leg_hound_body_no_external_source",
        "scale_basis": "1.02 m nose-to-tail length; 0.64 m standing height at ear tips",
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "metric_dimensions_m_y_up": list(DIMENSIONS_M),
        "ground_min_y": 0.0,
        "uv_sets": len(obj.data.uv_layers),
        "materials": len(obj.data.materials),
        "texture_size": pipeline.TEXTURE_SIZE,
        "textures": [
            "dog_albedo.png",
            "dog_normal.png",
            "dog_roughness.png",
        ],
        "static_prop": True,
        "rigged": True,
        "animations": ["Idle-loop", "Walk-loop", "Trot-loop", "Sniff-loop"],
        "animated_parts": ["legs", "body", "neck", "tail", "eyes"],
    }
    report_path = REPORTS / "dog_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(
        "ASSET_METRICS="
        + json.dumps(
            {
                "asset": "dog",
                "triangles": production["triangles"],
                "components": production["components"],
                "dimensions_m": DIMENSIONS_M,
                "sha256": report["output_sha256"],
            },
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
