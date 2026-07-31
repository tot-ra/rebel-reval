"""Candidate-only Blender cleanup experiment for P2-034b.

Run from the repository root:
    blender -b --python generated/comfyui/bird_gull_v1/blender_cleanup_experiment.py

The script never reads from or writes to assets/birds. It preserves the three source
Hunyuan GLBs and writes experimental decimated/remeshed meshes plus eight static glide
frames below generated/comfyui/bird_gull_v1/candidates/cleanup/.
"""

from __future__ import annotations

import hashlib
import json
import math
import shutil
from collections import deque
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
CANDIDATE_ROOT = ROOT / "generated" / "comfyui" / "bird_gull_v1" / "candidates"
OUTPUT_ROOT = CANDIDATE_ROOT / "cleanup"
TARGET_TRIANGLES = 7800
FRAME_COUNT = 8

# Targets match the accepted Blender harbour-gull gliding_00 largest axes. Those
# production meshes were measured before this candidate-only run and are not opened
# or modified here. Their size is driven by the MapViewBirdSpecies catalog profiles.
SPECIES = {
    "herring_gull": {
        "source": "herring_gull_hunyuan_candidate.glb",
        "target_largest_axis_m": 1.551923,
        "scale_m": 0.60,
        "palette": {
            "body": (0.69, 0.68, 0.64, 1.0),
            "wing": (0.33, 0.37, 0.40, 1.0),
            "accent": (0.12, 0.14, 0.16, 1.0),
        },
    },
    "common_gull": {
        "source": "common_gull_hunyuan_candidate.glb",
        "target_largest_axis_m": 1.112211,
        "scale_m": 0.43,
        "palette": {
            "body": (0.73, 0.72, 0.68, 1.0),
            "wing": (0.43, 0.47, 0.49, 1.0),
            "accent": (0.16, 0.18, 0.19, 1.0),
        },
    },
    "common_tern": {
        "source": "common_tern_hunyuan_candidate.glb",
        "target_largest_axis_m": 1.133045,
        "scale_m": 0.35,
        "palette": {
            "body": (0.72, 0.73, 0.70, 1.0),
            "wing": (0.26, 0.29, 0.30, 1.0),
            "accent": (0.55, 0.12, 0.08, 1.0),
        },
    },
}


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_single_mesh(path: Path) -> bpy.types.Object:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj not in before and obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"expected one mesh in {path}, got {len(meshes)}")
    obj = meshes[0]
    obj.name = path.stem
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj


def duplicate_mesh(obj: bpy.types.Object, name: str) -> bpy.types.Object:
    result = obj.copy()
    result.data = obj.data.copy()
    result.name = name
    bpy.context.scene.collection.objects.link(result)
    return result


def activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def triangulate(obj: bpy.types.Object) -> None:
    activate(obj)
    modifier = obj.modifiers.new("Triangulate", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for vertex in obj.data.vertices:
        point = obj.matrix_world @ vertex.co
        low.x, low.y, low.z = min(low.x, point.x), min(low.y, point.y), min(low.z, point.z)
        high.x, high.y, high.z = max(high.x, point.x), max(high.y, point.y), max(high.z, point.z)
    return low, high


def topology_metrics(obj: bpy.types.Object) -> dict[str, int]:
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    boundary_edges = sum(1 for edge in mesh.edges if edge.is_boundary)
    non_manifold_edges = sum(1 for edge in mesh.edges if not edge.is_manifold)

    remaining = set(mesh.verts)
    components = 0
    while remaining:
        components += 1
        queue = deque([remaining.pop()])
        while queue:
            vertex = queue.popleft()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in remaining:
                    remaining.remove(other)
                    queue.append(other)
    mesh.free()
    return {
        "connected_components": components,
        "boundary_edges": boundary_edges,
        "non_manifold_edges": non_manifold_edges,
    }


def mesh_metrics(obj: bpy.types.Object) -> dict[str, object]:
    low, high = bounds(obj)
    dimensions = high - low
    metrics: dict[str, object] = {
        "triangles": triangle_count(obj),
        "vertices": len(obj.data.vertices),
        "dimensions_m": [round(dimensions.x, 6), round(dimensions.y, 6), round(dimensions.z, 6)],
        "largest_axis_m": round(max(dimensions), 6),
        "min_z_m": round(low.z, 6),
        "max_z_m": round(high.z, 6),
        "material_count": len(obj.data.materials),
        "materials": [material.name for material in obj.data.materials],
    }
    metrics.update(topology_metrics(obj))
    return metrics


def cleanup_base_mesh(obj: bpy.types.Object) -> None:
    activate(obj)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.remove_doubles(mesh, verts=mesh.verts, dist=0.00001)
    bmesh.ops.dissolve_degenerate(mesh, dist=0.000001, edges=mesh.edges)
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    triangulate(obj)


def decimate_to_budget(obj: bpy.types.Object, target: int = TARGET_TRIANGLES) -> None:
    current = triangle_count(obj)
    if current <= target:
        return
    activate(obj)
    modifier = obj.modifiers.new("CandidateDecimate", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = min(1.0, target / current)
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    triangulate(obj)
    # A second small correction handles modifier rounding while staying under budget.
    current = triangle_count(obj)
    if current > target:
        modifier = obj.modifiers.new("CandidateDecimateBudgetCorrection", "DECIMATE")
        modifier.ratio = target / current * 0.999
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        triangulate(obj)


def voxel_remesh(obj: bpy.types.Object, source_largest_axis: float) -> None:
    activate(obj)
    modifier = obj.modifiers.new("CandidateVoxelRemesh", "REMESH")
    modifier.mode = "VOXEL"
    modifier.voxel_size = source_largest_axis / 64.0
    modifier.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    triangulate(obj)


def remove_small_components(obj: bpy.types.Object, minimum_face_fraction: float = 0.0025) -> int:
    """Remove voxel-remesh specks while retaining meaningful connected forms."""
    activate(obj)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    remaining = set(mesh.verts)
    components: list[set] = []
    while remaining:
        component = {remaining.pop()}
        queue = deque(component)
        while queue:
            vertex = queue.popleft()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in remaining:
                    remaining.remove(other)
                    component.add(other)
                    queue.append(other)
        components.append(component)

    component_faces = []
    for component in components:
        faces = {face for vertex in component for face in vertex.link_faces}
        component_faces.append((component, faces))
    largest_face_count = max((len(faces) for _, faces in component_faces), default=0)
    threshold = max(4, math.ceil(largest_face_count * minimum_face_fraction))
    delete_verts = [
        vertex
        for component, faces in component_faces
        if len(faces) < threshold
        for vertex in component
    ]
    removed_components = sum(1 for _, faces in component_faces if len(faces) < threshold)
    if delete_verts:
        bmesh.ops.delete(mesh, geom=delete_verts, context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return removed_components


def normalize_scale_and_ground(obj: bpy.types.Object, target_largest_axis: float) -> dict[str, float]:
    low, high = bounds(obj)
    largest = max(high - low)
    factor = target_largest_axis / largest
    obj.scale *= factor
    bpy.context.view_layer.update()
    low, _ = bounds(obj)
    obj.location.z -= low.z
    bpy.context.view_layer.update()
    return {"uniform_scale_factor": factor, "ground_correction_m": -low.z}


def create_materials(obj: bpy.types.Object, species: str) -> None:
    obj.data.materials.clear()
    palette = SPECIES[species]["palette"]
    for role in ("body", "wing", "accent"):
        material = bpy.data.materials.new(f"{species}_{role}_diagnostic")
        material.diffuse_color = palette[role]
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = palette[role]
        principled.inputs["Roughness"].default_value = 0.72
        principled.inputs["Metallic"].default_value = 0.0
        obj.data.materials.append(material)

    low, high = bounds(obj)
    center = (low + high) * 0.5
    half_span = max((high.x - low.x) * 0.5, 1e-6)
    for polygon in obj.data.polygons:
        world_center = obj.matrix_world @ polygon.center
        wing_factor = abs(world_center.x - center.x) / half_span
        if wing_factor > 0.76:
            polygon.material_index = 2
        elif wing_factor > 0.34:
            polygon.material_index = 1
        else:
            polygon.material_index = 0


def surface_error(source: bpy.types.Object, candidate: bpy.types.Object) -> dict[str, float]:
    source_tree = BVHTree.FromObject(source, bpy.context.evaluated_depsgraph_get())
    candidate_tree = BVHTree.FromObject(candidate, bpy.context.evaluated_depsgraph_get())

    def distances(from_obj: bpy.types.Object, tree: BVHTree, maximum_samples: int = 5000) -> list[float]:
        stride = max(1, len(from_obj.data.vertices) // maximum_samples)
        values = []
        for vertex_index in range(0, len(from_obj.data.vertices), stride):
            vertex = from_obj.data.vertices[vertex_index]
            point = from_obj.matrix_world @ vertex.co
            nearest = tree.find_nearest(point)
            if nearest is not None:
                values.append((point - nearest[0]).length)
        return values

    forward = distances(source, candidate_tree)
    reverse = distances(candidate, source_tree)
    combined = forward + reverse
    return {
        "mean_surface_error_m": round(sum(combined) / len(combined), 6),
        "max_sampled_surface_error_m": round(max(combined), 6),
        "sample_count": len(combined),
    }


def export_glb(obj: bpy.types.Object, path: Path) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    activate(obj)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    result = mesh_metrics(obj)
    result["path"] = path.relative_to(ROOT).as_posix()
    result["bytes"] = path.stat().st_size
    result["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def deform_glide_frame(base: bpy.types.Object, frame_index: int) -> tuple[bpy.types.Object, dict[str, float]]:
    result = duplicate_mesh(base, f"{base.name}_gliding_{frame_index:02d}")
    low, high = bounds(result)
    center = (low + high) * 0.5
    half_span = max((high.x - low.x) * 0.5, 1e-6)
    phase = 2.0 * math.pi * frame_index / FRAME_COUNT
    phase_value = math.sin(phase)
    amplitude = float(SPECIES[result.get("species") or base.get("species")]["scale_m"]) * 0.22

    for vertex in result.data.vertices:
        world = result.matrix_world @ vertex.co
        wing_factor = abs(world.x - center.x) / half_span
        influence = max(0.0, min(1.0, (wing_factor - 0.30) / 0.70))
        influence = influence * influence * (3.0 - 2.0 * influence)
        # This spatial bend is deliberately diagnostic. The Hunyuan mesh has no wing
        # segmentation or armature, so the audit must judge deformation artifacts.
        vertex.co.z += phase_value * amplitude * influence
        vertex.co.y -= abs(phase_value) * amplitude * 0.10 * influence
    result.data.update()

    pre_ground_low, _ = bounds(result)
    result.location.z -= pre_ground_low.z
    bpy.context.view_layer.update()
    low, high = bounds(result)
    root_band = []
    tip_band = []
    for vertex in result.data.vertices:
        world = result.matrix_world @ vertex.co
        factor = abs(world.x - center.x) / half_span
        if factor < 0.25:
            root_band.append(world.z)
        elif factor > 0.78:
            tip_band.append(world.z)
    pose = {
        "frame": frame_index,
        "phase": round(phase_value, 6),
        "ground_min_z_m": round(low.z, 6),
        "wingtip_minus_root_mean_z_m": round(
            sum(tip_band) / len(tip_band) - sum(root_band) / len(root_band), 6
        ),
        "largest_axis_m": round(max(high - low), 6),
    }
    return result, pose


def process_species(species: str, config: dict[str, object]) -> dict[str, object]:
    reset_scene()
    source_path = CANDIDATE_ROOT / str(config["source"])
    source = import_single_mesh(source_path)
    source.hide_render = True
    source.hide_set(True)
    source_metrics = mesh_metrics(source)
    source_largest = float(source_metrics["largest_axis_m"])

    direct = duplicate_mesh(source, f"{species}_direct_decimated")
    cleanup_base_mesh(direct)
    decimate_to_budget(direct)
    direct_error = surface_error(source, direct)
    direct_transform = normalize_scale_and_ground(direct, float(config["target_largest_axis_m"]))
    create_materials(direct, species)
    direct["species"] = species

    remeshed = duplicate_mesh(source, f"{species}_voxel_remeshed")
    cleanup_base_mesh(remeshed)
    voxel_remesh(remeshed, source_largest)
    removed_components = remove_small_components(remeshed)
    decimate_to_budget(remeshed)
    remesh_error = surface_error(source, remeshed)
    remesh_transform = normalize_scale_and_ground(remeshed, float(config["target_largest_axis_m"]))
    create_materials(remeshed, species)
    remeshed["species"] = species

    species_root = OUTPUT_ROOT / species
    direct_metrics = mesh_metrics(direct)
    # Direct decimation is recorded but not exported when Blender cannot cross the
    # non-manifold split-vertex topology. Keeping hundreds of MB of failed evidence
    # would add no review value; the source and reproducible script remain available.
    direct_export: dict[str, object] = {
        **direct_metrics,
        "path": None,
        "bytes": None,
        "sha256": None,
        "exported": False,
    }
    remesh_export = export_glb(remeshed, species_root / "voxel_remeshed.glb")

    frames = []
    for frame_index in range(FRAME_COUNT):
        frame_obj, pose_metrics = deform_glide_frame(remeshed, frame_index)
        frame_obj["species"] = species
        exported = export_glb(frame_obj, species_root / f"gliding_{frame_index:02d}.glb")
        frames.append({**pose_metrics, **exported})
        bpy.data.objects.remove(frame_obj, do_unlink=True)

    return {
        "species": species,
        "source": {"path": source_path.relative_to(ROOT).as_posix(), **source_metrics},
        "catalog_scale_m": config["scale_m"],
        "target_largest_axis_m": config["target_largest_axis_m"],
        "direct_decimation": {
            **direct_export,
            **direct_error,
            **direct_transform,
            "budget_pass": int(direct_export["triangles"]) <= TARGET_TRIANGLES,
        },
        "voxel_remesh": {
            **remesh_export,
            **remesh_error,
            **remesh_transform,
            "small_components_removed": removed_components,
            "budget_pass": int(remesh_export["triangles"]) <= TARGET_TRIANGLES,
        },
        "material_reconstruction": {
            "status": "diagnostic_only",
            "material_count": 3,
            "uv_status": "absent",
            "assignment": "spatial body/wing/tip regions; not species-faithful plumage",
        },
        "glide_sequence": {
            "frame_count": len(frames),
            "method": "unrigged spatial outer-wing bend on cleaned voxel-remesh mesh",
            "frames": frames,
        },
    }


def main() -> None:
    if OUTPUT_ROOT.exists():
        shutil.rmtree(OUTPUT_ROOT)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    results = {
        "task": "P2-034b",
        "blender_version": bpy.app.version_string,
        "candidate_only": True,
        "production_assets_opened": False,
        "target_triangles": TARGET_TRIANGLES,
        "frame_count": FRAME_COUNT,
        "species": [process_species(name, config) for name, config in SPECIES.items()],
    }
    output_path = OUTPUT_ROOT / "experiment_results.json"
    output_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"P2_034B_RESULTS={output_path}")


if __name__ == "__main__":
    main()
