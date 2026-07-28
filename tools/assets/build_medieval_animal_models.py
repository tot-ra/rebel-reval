"""Build game-ready medieval animal models from approved Hunyuan3D candidates.

Run from the repository root:
    blender -t 1 -b --python tools/assets/build_medieval_animal_models.py
    blender -t 1 -b --python tools/assets/build_medieval_animal_models.py -- cattle

Raw image-to-3D meshes stay under generated/comfyui and are never copied into
runtime paths. This pass keeps their approved silhouettes but rebuilds topology,
sets explicit metric dimensions, creates portable UV/PBR materials, and emits
compact reports next to the staging inputs. Each approved livestock mesh receives
a purpose-built low-cost rig, visible eyes, and looping idle/walk animation.
"""

from __future__ import annotations

import bmesh
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from mathutils import Matrix, Vector

# This script is also loaded by one-off Blender rebuild scripts via importlib.
# Keep its sibling module importable in both direct and importlib execution.
ASSET_TOOL_DIR = Path(__file__).resolve().parent
if str(ASSET_TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(ASSET_TOOL_DIR))

from medieval_animal_rigs import RIG_BUILDERS, create_cattle_rig


ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "generated/comfyui/medieval_animals_v1"
RUNTIME = ROOT / "assets/animals/medieval"
REPORTS = STAGING / "production/reports"
TEXTURES = STAGING / "production/textures"
TEXTURE_SIZE = 512

# Dimensions use the game contract's Y-up order: length, height, width.
SPECS = {
    "cattle": {
        "source": STAGING / "cattle_candidate.glb",
        "output": RUNTIME / "medieval_cattle.glb",
        "dimensions_m": (2.20, 1.45, 1.02),
        "triangles": 8_000,
        "voxel_divisor": 72.0,
        "base_color": (0.30, 0.115, 0.055),
        "accent_color": (0.48, 0.235, 0.095),
        "seed": 208744131,
        "animated": True,
    },
    "pig": {
        "source": STAGING / "pig_hendrik_reyneke_cc_by_source.glb",
        "output": RUNTIME / "medieval_pig.glb",
        "dimensions_m": (1.35, 0.75, 0.48),
        "triangles": 7_000,
        "voxel_divisor": 72.0,
        "base_color": (0.19, 0.105, 0.055),
        "accent_color": (0.40, 0.205, 0.095),
        "seed": 208744134,
        "animated": True,
        # WHY: this licensed source already has four clean, articulated legs and
        # cloven feet. Voxel remeshing would erase anatomy instead of repairing it.
        "preserve_topology": True,
        "source_long_axis": "y",
        "route": "licensed_existing_mesh_to_blender_cleanup",
        "source_license": "CC BY 4.0 - hendrikReyneke",
        "anatomy_decision": "approved_four_separate_weight_bearing_legs",
        "scale_basis": "1.35 m nose-to-rump length; 0.75 m standing height",
    },
    "sheep": {
        "source": STAGING / "sheep_candidate.glb",
        "output": RUNTIME / "medieval_sheep.glb",
        "dimensions_m": (1.25, 0.90, 0.55),
        "triangles": 6_000,
        "voxel_divisor": 72.0,
        "base_color": (0.58, 0.51, 0.38),
        "accent_color": (0.78, 0.72, 0.59),
        "seed": 208744132,
        "animated": True,
    },
    "pack_horse": {
        "source": STAGING / "pack_horse_candidate.glb",
        "output": RUNTIME / "medieval_pack_horse.glb",
        "dimensions_m": (2.35, 1.65, 0.78),
        "triangles": 10_000,
        "voxel_divisor": 20.0,
        "base_color": (0.27, 0.17, 0.085),
        "accent_color": (0.49, 0.34, 0.16),
        "seed": 208744133,
        "animated": True,
    },
}


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def topology(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    unseen = set(bm.verts)
    component_sizes: list[int] = []
    while unseen:
        stack = [unseen.pop()]
        count = 0
        while stack:
            vertex = stack.pop()
            count += 1
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in unseen:
                    unseen.remove(other)
                    stack.append(other)
        component_sizes.append(count)
    component_sizes.sort(reverse=True)
    result = {
        "vertices": len(mesh.vertices),
        "polygons": len(mesh.polygons),
        "triangles": sum(max(0, len(face.vertices) - 2) for face in mesh.polygons),
        "components": len(component_sizes),
        "component_vertices": component_sizes,
        "boundary_edges": sum(1 for edge in bm.edges if edge.is_boundary),
        "non_manifold_edges": sum(1 for edge in bm.edges if not edge.is_manifold),
        "loose_vertices": sum(1 for vertex in bm.verts if not vertex.link_edges),
    }
    bm.free()
    return result


def flatten_imported_hierarchy() -> bpy.types.Object:
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("Candidate contains no mesh")
    for obj in meshes:
        # WHY: glTF roots can carry axis-conversion transforms. Baking world space
        # first gives PCA, ground contact, and metric normalization stable inputs.
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        obj.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    return obj


def remove_tiny_islands(obj: bpy.types.Object, fraction: float) -> int:
    """Remove only detached scan noise, retaining substantial tack/fleece parts."""
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
    discarded = [island for island in islands if len(island) < max(12, largest * fraction)]
    if discarded:
        bmesh.ops.delete(bm, geom=[vertex for island in discarded for vertex in island], context="VERTS")
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    return len(discarded)


def align_long_axis(obj: bpy.types.Object) -> None:
    points = np.array([(vertex.co.x, vertex.co.y) for vertex in obj.data.vertices], dtype=np.float64)
    centered = points - points.mean(axis=0)
    covariance = np.cov(centered, rowvar=False)
    values, vectors = np.linalg.eigh(covariance)
    axis = vectors[:, int(np.argmax(values))]
    angle = math.atan2(float(axis[1]), float(axis[0]))
    obj.rotation_euler.z = -angle
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def rebuild_surface(obj: bpy.types.Object, divisor: float, target_triangles: int) -> None:
    max_dimension = max(obj.dimensions)
    obj.data.remesh_voxel_size = max_dimension / divisor
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.voxel_remesh()
    remove_tiny_islands(obj, 0.006)

    smooth = obj.modifiers.new("OrganicSurfaceCleanup", "SMOOTH")
    smooth.factor = 0.42
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    current_triangles = topology(obj)["triangles"]
    if current_triangles > target_triangles:
        decimate = obj.modifiers.new("ProductionTriangleBudget", "DECIMATE")
        decimate.ratio = target_triangles / current_triangles
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def normalize_dimensions(obj: bpy.types.Object, dimensions_y_up: tuple[float, float, float]) -> None:
    target_length, target_height, target_width = dimensions_y_up
    # WHY: imported glTF roots can leave stale bound boxes on obj.dimensions even
    # after baking matrix_world into mesh data. Vertex extents keep metric scaling
    # stable for preserve_topology livestock such as the licensed pig source.
    points = [vertex.co for vertex in obj.data.vertices]
    min_x = min(point.x for point in points)
    max_x = max(point.x for point in points)
    min_y = min(point.y for point in points)
    max_y = max(point.y for point in points)
    min_z = min(point.z for point in points)
    max_z = max(point.z for point in points)
    current = Vector((max_x - min_x, max_y - min_y, max_z - min_z))
    obj.scale = (
        target_length / max(current.x, 1e-6),
        target_width / max(current.y, 1e-6),
        target_height / max(current.z, 1e-6),
    )
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    points = [vertex.co for vertex in obj.data.vertices]
    min_z = min(point.z for point in points)
    center_x = (min(point.x for point in points) + max(point.x for point in points)) * 0.5
    center_y = (min(point.y for point in points) + max(point.y for point in points)) * 0.5
    for vertex in obj.data.vertices:
        vertex.co.x -= center_x
        vertex.co.y -= center_y
        vertex.co.z -= min_z
    obj.data.update()


def make_uv(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.05, island_margin=0.025, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def create_albedo(name: str, spec: dict) -> bpy.types.Image:
    """Create deterministic restrained coat variation as a portable texture."""
    rng = np.random.default_rng(spec["seed"])
    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size]
    broad = (
        np.sin(xx / 29.0 + spec["seed"] * 0.001)
        + np.sin(yy / 41.0)
        + np.sin((xx + yy) / 67.0)
    ) / 6.0 + 0.5
    grain = rng.random((size, size))
    mix = np.clip(broad * 0.78 + grain * 0.22, 0.0, 1.0)[..., None]
    base = np.array(spec["base_color"], dtype=np.float32)
    accent = np.array(spec["accent_color"], dtype=np.float32)
    rgb = base + (accent - base) * mix
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=2)

    image = bpy.data.images.new(f"{name}_albedo", size, size, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(rgba.astype(np.float32).ravel().tolist())
    image.filepath_raw = str(TEXTURES / f"{name}_albedo.png")
    image.file_format = "PNG"
    image.save()
    return image


def assign_material(obj: bpy.types.Object, name: str, image: bpy.types.Image) -> None:
    material = bpy.data.materials.new(f"medieval_{name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.84
    shader.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(material)


def export_glb(
    obj: bpy.types.Object,
    output: Path,
    armature: bpy.types.Object | None = None,
    details: list[bpy.types.Object] | None = None,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    export_objects = [obj]
    if armature is not None:
        export_objects.append(armature)
        export_objects.extend(details or [])
    for export_object in export_objects:
        export_object.select_set(True)
    bpy.context.view_layer.objects.active = armature or obj
    animated = armature is not None
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        # Applying transforms during export can destroy skin bind matrices.
        export_apply=not animated,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_skins=animated,
        export_animations=animated,
        export_animation_mode="ACTIONS" if animated else "ACTIVE_ACTIONS",
        export_force_sampling=animated,
        export_def_bones=True,
    )


def build(name: str, spec: dict) -> dict:
    source: Path = spec["source"]
    if not source.exists():
        raise FileNotFoundError(f"Missing approved candidate: {source}")
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    obj = flatten_imported_hierarchy()
    raw = topology(obj)
    discarded_before = remove_tiny_islands(obj, 0.0015)
    if spec.get("source_long_axis") == "y":
        # Keep authored head/tail orientation stable: source -Y becomes runtime -X.
        obj.rotation_euler.z = -math.pi * 0.5
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    else:
        align_long_axis(obj)
    if not spec.get("preserve_topology", False):
        rebuild_surface(obj, spec["voxel_divisor"], spec["triangles"])
    else:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    # Pack-horse scans retain tack islands; discard more aggressively before rigging.
    if name == "pack_horse":
        remove_tiny_islands(obj, 0.0025)
    normalize_dimensions(obj, spec["dimensions_m"])
    make_uv(obj)
    albedo = create_albedo(name, spec)
    assign_material(obj, name, albedo)
    production = topology(obj)
    armature: bpy.types.Object | None = None
    details: list[bpy.types.Object] = []
    if spec.get("animated", False):
        rig_builder = RIG_BUILDERS.get(name, create_cattle_rig)
        armature, details = rig_builder(obj)
    output: Path = spec["output"]
    export_glb(obj, output, armature, details)

    report = {
        "asset_id": f"creature.{name}",
        "route": spec.get("route", "leonardo_reference_to_hunyuan3d_to_blender_cleanup"),
        "source_license": spec.get("source_license", "project-authored AI generation"),
        "anatomy_decision": spec.get("anatomy_decision", "approved_reference_silhouette"),
        "scale_basis": spec.get("scale_basis", "brief metric dimensions"),
        "source": str(source.relative_to(ROOT)),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output": str(output.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "raw": raw,
        "production": production,
        "discarded_raw_noise_components": discarded_before,
        "metric_dimensions_m_y_up": list(spec["dimensions_m"]),
        "ground_min_y": 0.0,
        "uv_sets": len(obj.data.uv_layers),
        "materials": len(obj.data.materials),
        "texture_size": TEXTURE_SIZE,
        "static_prop": True,
        "rigged": armature is not None,
        "animations": ["Idle-loop", "Walk-loop"] if armature is not None else [],
        "animated_parts": ["legs", "neck", "tail", "eyes"] if armature is not None else [],
    }
    report_path = REPORTS / f"{name}_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(
        "ASSET_METRICS="
        + json.dumps(
            {
                "asset": name,
                "triangles": production["triangles"],
                "components": production["components"],
                "dimensions_m": spec["dimensions_m"],
                "sha256": report["output_sha256"],
            },
            separators=(",", ":"),
        )
    )
    return report


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)
    TEXTURES.mkdir(parents=True, exist_ok=True)
    selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    names = selected or list(SPECS)
    unknown = sorted(set(names) - set(SPECS))
    if unknown:
        raise ValueError(f"Unknown animal specs: {unknown}")
    for name in names:
        build(name, SPECS[name])


if __name__ == "__main__":
    main()
