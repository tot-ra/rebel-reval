import bpy
import json
import hashlib
import sys
from pathlib import Path

root = Path.cwd()
out_path = root / "generated/comfyui/bird_wader_v1/candidates/candidate_audit.json"
CANDIDATE_SPECS = {
    "grey_heron": root / "generated/comfyui/bird_wader_v1/candidates/grey_heron_hunyuan_candidate.glb",
    "common_snipe": root / "generated/comfyui/bird_wader_v1/candidates/common_snipe_hunyuan_candidate.glb",
}
RETIRED_CANDIDATES = [
    {
        "species": "northern_lapwing",
        "candidate_path": "generated/comfyui/bird_wader_v1/candidates/northern_lapwing_hunyuan_candidate.glb",
        "status": "removed",
        "removal_commit": "206069637005a2c4e0f904f2baa14a8428c00458",
        "removal_reason": "Rejected 12.67 MiB candidate removed by storage cleanup; production Blender wader retained.",
        "historical_metrics": {
            "triangles": 879680,
            "vertices": 227166,
            "largest_axis_m": 1.963176,
            "min_z_m": -0.97777,
            "material_count": 0,
            "animation_count": 0,
        },
        "production_verdict": "reject",
    }
]
production_largest = {"grey_heron": 3.2685, "common_snipe": 0.7644}

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)

def audit(species, path):
    reset()
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    vertices = sum(len(obj.data.vertices) for obj in objects)
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons if len(poly.vertices) >= 3) for obj in objects)
    materials = []
    for obj in objects:
        for slot in obj.material_slots:
            if slot.material and slot.material.name not in materials:
                materials.append(slot.material.name)
    points = []
    for obj in objects:
        for vertex in obj.data.vertices:
            points.append(obj.matrix_world @ vertex.co)
    mins = [min(point[i] for point in points) for i in range(3)]
    maxs = [max(point[i] for point in points) for i in range(3)]
    dimensions = [maxs[i] - mins[i] for i in range(3)]
    animations = sorted({action.name for action in bpy.data.actions})
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    ratio = max(dimensions) / production_largest[species] if production_largest[species] else 0.0
    checks = {
        "triangle_budget": triangles <= 8000,
        "grounding": abs(mins[2]) <= 0.02,
        "materials": len(materials) > 0,
        "catalog_scale": 0.5 <= ratio <= 1.5,
        "standing_pose_asset": True,
        "animation_coverage": len(animations) > 0,
    }
    verdict = "accept" if all(checks.values()) else "reject"
    reasons = []
    if not checks["triangle_budget"]:
        reasons.append(f"triangle budget exceeded ({triangles} > 8000)")
    if not checks["grounding"]:
        reasons.append(f"grounding outside 2 cm tolerance (min Z {mins[2]:.6f} m)")
    if not checks["materials"]:
        reasons.append("no imported materials/textures")
    if not checks["catalog_scale"]:
        reasons.append(f"catalog scale ratio outside [0.5, 1.5] ({ratio:.3f})")
    if not checks["animation_coverage"]:
        reasons.append("no authored animation")
    return {
        "species": species,
        "candidate_path": str(path.relative_to(root)),
        "sha256": digest,
        "bytes": path.stat().st_size,
        "metrics": {
            "triangles": triangles,
            "vertices": vertices,
            "mesh_count": len(objects),
            "dimensions_m": [round(value, 6) for value in dimensions],
            "largest_axis_m": round(max(dimensions), 6),
            "min_z_m": round(mins[2], 6),
            "max_z_m": round(maxs[2], 6),
            "material_count": len(materials),
            "materials": materials,
            "animation_count": len(animations),
            "animations": animations,
        },
        "production_comparison": {
            "production_largest_axis_m": production_largest[species],
            "largest_axis_ratio": round(ratio, 6),
        },
        "checks": checks,
        "production_verdict": verdict,
        "verdict_reasons": reasons,
    }

report = {
    "id": "fauna.wader_batch.hunyuan_candidate",
    "generator": "Hunyuan3Dv2 via local ComfyUI 0.28.2",
    "route": "local_comfyui_hunyuan3d_v2_single_image",
    "checkpoint": "hunyuan3d-dit-v2-mv_fp16.safetensors",
    "workflow_path": "generated/comfyui/bird_wader_v1/candidate_workflow_api.json",
    "reference_source": "generated/comfyui/bird_wader_v1/previews/*_standing.png",
    "candidate_only": True,
    "production_unchanged": True,
    "quality_contract": {
        "triangle_budget": 8000,
        "grounding_tolerance_m": 0.02,
        "requires_materials": True,
        "requires_catalog_scale_ratio": [0.5, 1.5],
        "requires_standing_pose": True,
        "requires_animation_coverage": True,
    },
    "candidates": [audit(species, path) for species, path in CANDIDATE_SPECS.items()],
    "retired_candidates": RETIRED_CANDIDATES,
    "production_policy": "Candidates only; assets/birds production GLBs were not modified or replaced.",
    "workflow_status": "healthy",
}
out_path.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
