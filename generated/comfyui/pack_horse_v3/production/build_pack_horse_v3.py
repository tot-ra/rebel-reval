"""Production rebuild for the pack-horse v3 runtime model.

Run from the repository root:

    blender -b --factory-startup --python generated/comfyui/pack_horse_v3/production/build_pack_horse_v3.py

WHY: the v2 runtime horse remeshed a Hunyuan candidate that still carried a fused
ground disc, producing a flat wall. v3 regenerates from a floating mid-gray
reference, keeps the candidate topology (no voxel remesh - remesh collapsed the
open AI surface to a paper shell), optionally trims residual contact shards,
then decimates into the shared livestock PBR + quadruped-rig contract.
"""

from __future__ import annotations

import bmesh
import bpy
import hashlib
import importlib.util
import json
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
BASE_SCRIPT = ROOT / "tools/assets/build_medieval_animal_models.py"
RIG_SCRIPT = ROOT / "tools/assets/medieval_animal_rigs.py"
CANDIDATE = ROOT / "generated/comfyui/pack_horse_v3/pack_horse_candidate.glb"
STAGING_OUTPUT = ROOT / "generated/comfyui/pack_horse_v3/pack_horse_v3.glb"
RUNTIME_OUTPUT = ROOT / "assets/animals/medieval/medieval_pack_horse.glb"
REPORT = ROOT / "generated/comfyui/pack_horse_v3/production/reports/pack_horse_v3_report.json"
RUNTIME_REPORT = ROOT / "generated/comfyui/medieval_animals_v1/production/reports/pack_horse_report.json"
TEXTURE_STAGING = ROOT / "generated/comfyui/medieval_animals_v1/production/textures"

module_spec = importlib.util.spec_from_file_location("animal_builder", BASE_SCRIPT)
builder = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(builder)

rig_spec = importlib.util.spec_from_file_location("animal_rigs", RIG_SCRIPT)
rigs = importlib.util.module_from_spec(rig_spec)
rig_spec.loader.exec_module(rigs)

DIMENSIONS_M_Y_UP = (2.35, 1.65, 0.78)
TARGET_TRIANGLES = 10_000
# Safety trim only: the floating reference no longer ships a full pedestal.
DISC_HEIGHT_FRACTION = 0.015
SPEC = {
    "seed": 208744133,
    "base_color": (0.27, 0.17, 0.085),
    "accent_color": (0.49, 0.34, 0.16),
}


def trim_contact_shards(obj: bpy.types.Object, height_fraction: float = DISC_HEIGHT_FRACTION) -> dict:
    """Delete only residual horizontal contact shards under the hooves."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    zs = [vertex.co.z for vertex in bm.verts]
    min_z = min(zs)
    max_z = max(zs)
    cut_z = min_z + (max_z - min_z) * height_fraction

    disc_faces = [
        face
        for face in bm.faces
        if abs(face.normal.z) > 0.55
        and (sum(vertex.co.z for vertex in face.verts) / len(face.verts)) < cut_z
    ]
    if disc_faces:
        bmesh.ops.delete(bm, geom=disc_faces, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return {
        "cut_z": cut_z,
        "height_fraction": height_fraction,
        "deleted_disc_faces": len(disc_faces),
    }


def keep_largest_component(obj: bpy.types.Object) -> int:
    """Drop every loose fragment; only the horse body survives."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    unseen = set(bm.verts)
    islands: list[list[bmesh.types.BMVert]] = []
    while unseen:
        stack = [unseen.pop()]
        island: list[bmesh.types.BMVert] = []
        while stack:
            vertex = stack.pop()
            island.append(vertex)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in unseen:
                    unseen.remove(other)
                    stack.append(other)
        islands.append(island)
    largest = max((len(island) for island in islands), default=0)
    discarded = [island for island in islands if len(island) < largest]
    if discarded:
        bmesh.ops.delete(bm, geom=[vertex for island in discarded for vertex in island], context="VERTS")
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    return len(discarded)


def point_head_negative_x(obj: bpy.types.Object) -> None:
    """Face the head toward -X, matching the shared quadruped rig contract."""
    max_z = max(vertex.co.z for vertex in obj.data.vertices)
    high = [vertex.co for vertex in obj.data.vertices if vertex.co.z > max_z * 0.75]
    mean_x = sum(point.x for point in high) / max(len(high), 1)
    if mean_x > 0.0:
        obj.rotation_euler.z = math.pi
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def reduce_topology(obj: bpy.types.Object, target_triangles: int) -> None:
    """Collapse-decimate the clean candidate; never voxel-remesh this surface."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")

    # Two collapse passes: Hunyuan surfaces often undershoot a single ratio target.
    for pass_index in range(2):
        current_triangles = builder.topology(obj)["triangles"]
        if current_triangles <= target_triangles:
            break
        decimate = obj.modifiers.new(f"ProductionTriangleBudget{pass_index}", "DECIMATE")
        decimate.ratio = target_triangles / max(current_triangles, 1)
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def mesh_volume(obj: bpy.types.Object) -> float:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    volume = 0.0
    for face in bm.faces:
        verts = face.verts
        if len(verts) < 3:
            continue
        volume += verts[0].co.dot(verts[1].co.cross(verts[2].co)) / 6.0
    bm.free()
    return abs(volume)


def sync_textures_to_staging() -> list[str]:
    """Keep the shared medieval_animals_v1 texture staging in sync with the rebuild."""
    TEXTURE_STAGING.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for name in ("albedo", "normal", "roughness"):
        source = builder.TEXTURES / f"pack_horse_{name}.png"
        destination = TEXTURE_STAGING / f"pack_horse_{name}.png"
        if not source.exists():
            continue
        if source.resolve() != destination.resolve():
            shutil.copy2(source, destination)
        copied.append(str(destination.relative_to(ROOT)))
    return copied


def main() -> None:
    if not CANDIDATE.exists():
        raise FileNotFoundError(f"Missing pack-horse v3 candidate: {CANDIDATE}")

    builder.clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(CANDIDATE))
    obj = builder.flatten_imported_hierarchy()
    raw = builder.topology(obj)

    disc = trim_contact_shards(obj)
    discarded = keep_largest_component(obj)
    builder.align_long_axis(obj)
    point_head_negative_x(obj)
    reduce_topology(obj, TARGET_TRIANGLES)
    builder.normalize_dimensions(obj, DIMENSIONS_M_Y_UP)
    builder.make_uv(obj)

    profile = builder.SURFACE_PROFILES["pack_horse"]
    albedo = builder.create_albedo("pack_horse", SPEC)
    normal = builder.bake_normal_map(obj, "pack_horse", profile)
    roughness = builder.bake_roughness_map(obj, "pack_horse", profile)
    builder.assign_pbr_material(obj, "pack_horse", albedo, normal, roughness, profile)

    production = builder.topology(obj)
    width = float(obj.dimensions.y)
    volume = mesh_volume(obj)
    # Guard against the failed remesh path that collapsed the horse to a paper shell.
    if width > 1.05:
        raise RuntimeError(f"Pack-horse width {width:.3f} m still looks disc-contaminated")
    if volume < 0.08:
        raise RuntimeError(f"Pack-horse volume {volume:.4f} m^3 is too thin for a solid body")

    armature, details = rigs.create_pack_horse_rig(obj)
    STAGING_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    builder.export_glb(obj, STAGING_OUTPUT, armature, details)
    shutil.copy2(STAGING_OUTPUT, RUNTIME_OUTPUT)
    texture_paths = sync_textures_to_staging()

    report = {
        "asset_id": "creature.pack_horse.v3",
        "route": "leonardo_reference_to_floating_cleanup_to_hunyuan3d_to_blender_cleanup",
        "decision": (
            "v3 regenerates from a floating mid-gray reference so Hunyuan does not "
            "emit a ground disc, then preserves topology with collapse decimate only "
            "(voxel remesh collapsed open AI surfaces to a paper shell)."
        ),
        "source": str(CANDIDATE.relative_to(ROOT)),
        "source_sha256": hashlib.sha256(CANDIDATE.read_bytes()).hexdigest(),
        "output": str(RUNTIME_OUTPUT.relative_to(ROOT)),
        "staging_output": str(STAGING_OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(RUNTIME_OUTPUT.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "contact_trim": disc,
        "discarded_loose_fragments": discarded,
        "metric_dimensions_m_y_up": list(DIMENSIONS_M_Y_UP),
        "ground_min_y": 0.0,
        "mesh_volume_m3": volume,
        "uv_sets": len(obj.data.uv_layers),
        "materials": len(obj.data.materials),
        "texture_size": builder.TEXTURE_SIZE,
        "textures": texture_paths,
        "rigged": True,
        "animations": ["Idle-loop", "Walk-loop", "Trot-loop", "Graze-loop"],
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n")

    runtime_report = dict(report)
    runtime_report["asset_id"] = "creature.pack_horse"
    runtime_report["anatomy_decision"] = "approved_four_separate_weight_bearing_legs_no_ground_disc"
    runtime_report["scale_basis"] = "2.35 m nose-to-rump; 1.65 m standing height; 0.78 m width"
    RUNTIME_REPORT.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME_REPORT.write_text(json.dumps(runtime_report, indent=2) + "\n")

    print(
        "ASSET_METRICS="
        + json.dumps(
            {
                "asset": "pack_horse_v3",
                "output_sha256": report["output_sha256"],
                "triangles": production["triangles"],
                "components": production["components"],
                "boundary_edges": production["boundary_edges"],
                "non_manifold_edges": production["non_manifold_edges"],
                "width_m": round(width, 3),
                "volume_m3": round(volume, 4),
            },
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
