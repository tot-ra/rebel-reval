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

# Per-species hide/wool/hair micro-surface baked into portable normal and
# roughness maps. Sheep gets a coarser noise profile so fleece reads apart from
# cattle/pig hide without changing the shared rig or silhouette contract.
SURFACE_PROFILES: dict[str, dict] = {
    "cattle": {
        "noise_scale": 38.0,
        "noise_detail": 3.5,
        "bump_strength": 0.22,
        "rough_min": 0.78,
        "rough_max": 0.90,
        "normal_strength": 0.65,
    },
    "pig": {
        "noise_scale": 42.0,
        "noise_detail": 3.0,
        "bump_strength": 0.20,
        "rough_min": 0.76,
        "rough_max": 0.88,
        "normal_strength": 0.60,
    },
    "sheep": {
        "noise_scale": 85.0,
        "noise_detail": 4.5,
        "bump_strength": 0.35,
        "rough_min": 0.82,
        "rough_max": 0.94,
        "normal_strength": 0.85,
    },
    "pack_horse": {
        "noise_scale": 55.0,
        "noise_detail": 4.0,
        "bump_strength": 0.26,
        "rough_min": 0.74,
        "rough_max": 0.86,
        "normal_strength": 0.70,
    },
}

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
        "base_color": (0.23, 0.09, 0.055),
        "accent_color": (0.48, 0.22, 0.12),
        "seed": 208744134,
        "animated": True,
        # WHY: the licensed scan remains the anatomy/proportion reference, but
        # its open fragments are not suitable as the shipped body surface.
        "route": "licensed_reference_to_authored_closed_anatomy_rebuild",
        "source_license": "CC BY 4.0 - hendrikReyneke",
        "anatomy_decision": "authored_closed_four_leg_landrace_body_from_licensed_reference",
        "scale_basis": "1.35 m nose-to-rump length; 0.75 m standing height",
    },
    "sheep": {
        # WHY: the rejected image-to-3D candidate contains detached ground fragments
        # and cannot provide trustworthy facial anatomy. The runtime mesh is built
        # entirely from deterministic closed anatomical volumes below.
        "source": None,
        "output": RUNTIME / "medieval_sheep.glb",
        "dimensions_m": (1.25, 0.90, 0.55),
        "triangles": 8_000,
        "voxel_divisor": 72.0,
        "base_color": (0.64, 0.59, 0.47),
        "accent_color": (0.86, 0.82, 0.70),
        "seed": 208744132,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "closed_multi_volume_fleece_head_ears_muzzle_four_legs_and_cloven_hooves",
        "scale_basis": "1.25 m nose-to-rump; 0.90 m standing height; 0.55 m fleece width",
    },
    "pack_horse": {
        # WHY: rebuild only through pack_horse_v3/production/build_pack_horse_v3.py.
        # The shared voxel remesh collapses this open AI surface to a paper shell,
        # and older v1/v2 candidates still carry fused ground discs.
        "source": ROOT / "generated/comfyui/pack_horse_v3/pack_horse_candidate.glb",
        "output": RUNTIME / "medieval_pack_horse.glb",
        "dimensions_m": (2.35, 1.65, 0.78),
        "triangles": 10_000,
        "voxel_divisor": 110.0,
        "base_color": (0.27, 0.17, 0.085),
        "accent_color": (0.49, 0.34, 0.16),
        "seed": 208744133,
        "animated": True,
        "preserve_topology": True,
        "route": "leonardo_reference_to_floating_cleanup_to_hunyuan3d_to_blender_cleanup",
        "anatomy_decision": "use_generated/comfyui/pack_horse_v3/production/build_pack_horse_v3.py",
        "scale_basis": "2.35 m nose-to-rump; 1.65 m standing height; 0.78 m width",
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


def new_image(name: str, color: tuple[float, float, float, float], *, non_color: bool = False) -> bpy.types.Image:
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    image.generated_color = color
    return image


def _prepare_bake_scene() -> bpy.types.Scene:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.device = "CPU"
    scene.render.bake.margin = 8
    scene.render.bake.use_selected_to_active = False
    return scene


def bake_normal_map(obj: bpy.types.Object, name: str, profile: dict) -> bpy.types.Image:
    """Bake a tangent-space hide/wool normal from procedural micro-relief."""
    _prepare_bake_scene()
    normal = new_image(f"{name}_normal", (0.5, 0.5, 1.0, 1.0), non_color=True)
    material = bpy.data.materials.new(f"medieval_{name}_normal_bake")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = profile["noise_scale"]
    noise.inputs["Detail"].default_value = profile["noise_detail"]
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = profile["bump_strength"]
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(material)

    image_node = nodes.new("ShaderNodeTexImage")
    image_node.image = normal
    nodes.active = image_node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)

    normal.filepath_raw = str(TEXTURES / f"{name}_normal.png")
    normal.file_format = "PNG"
    normal.save()
    bpy.data.materials.remove(material)
    return normal


def bake_roughness_map(obj: bpy.types.Object, name: str, profile: dict) -> bpy.types.Image:
    """Bake a matte hide/wool roughness map with subtle value breakup."""
    scene = _prepare_bake_scene()
    scene.cycles.samples = 8
    roughness = new_image(f"{name}_roughness", (0.84, 0.84, 0.84, 1.0), non_color=True)
    material = bpy.data.materials.new(f"medieval_{name}_roughness_bake")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = profile["noise_scale"] * 0.55
    noise.inputs["Detail"].default_value = profile["noise_detail"]
    spread = nodes.new("ShaderNodeMapRange")
    spread.inputs["From Min"].default_value = 0.35
    spread.inputs["From Max"].default_value = 0.65
    spread.inputs["To Min"].default_value = profile["rough_min"]
    spread.inputs["To Max"].default_value = profile["rough_max"]
    spread.clamp = True
    links.new(noise.outputs["Fac"], spread.inputs["Value"])
    links.new(spread.outputs["Result"], shader.inputs["Base Color"])

    image_node = nodes.new("ShaderNodeTexImage")
    image_node.image = roughness
    nodes.active = image_node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)

    roughness.filepath_raw = str(TEXTURES / f"{name}_roughness.png")
    roughness.file_format = "PNG"
    roughness.save()
    bpy.data.materials.remove(material)
    return roughness


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


def assign_pbr_material(
    obj: bpy.types.Object,
    name: str,
    albedo: bpy.types.Image,
    normal: bpy.types.Image,
    roughness: bpy.types.Image,
    profile: dict,
) -> None:
    material = bpy.data.materials.new(f"medieval_{name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    output = nodes.get("Material Output")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    links.new(albedo_node.outputs["Color"], shader.inputs["Base Color"])

    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = profile["normal_strength"]
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])

    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    links.new(roughness_node.outputs["Color"], shader.inputs["Roughness"])
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


def create_sheep_mesh() -> bpy.types.Object:
    """Build a detailed sheep entirely from closed procedural volumes.

    WHY: the previous image-to-3D surface included detached ground debris, a split
    torso, and no dependable facial anatomy. Overlapping closed volumes provide a
    stable skinned surface while preserving readable fleece, face, ear, leg, and
    cloven-hoof landmarks at the map camera distance.
    """
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 16,
    ) -> bpy.types.Object:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, location=location)
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
        vertices: int = 10,
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

    # Interlocking fleece lobes break up the outline without loose cards or ground
    # helpers. Shoulder and rump sit slightly higher than the belly like a compact
    # northern short-tailed sheep under a full medieval fleece.
    sphere("SheepFleeceCore", (0.06, 0.0, 0.56), (0.46, 0.255, 0.29), 20)
    sphere("SheepFleeceShoulder", (-0.28, 0.0, 0.60), (0.28, 0.275, 0.30))
    sphere("SheepFleeceRump", (0.35, 0.0, 0.58), (0.29, 0.265, 0.29))
    sphere("SheepFleeceBack", (0.02, 0.0, 0.76), (0.35, 0.23, 0.14))
    for index, (x, y, z, radius) in enumerate(
        (
            (-0.18, 0.21, 0.68, 0.105),
            (0.08, 0.23, 0.65, 0.115),
            (0.31, 0.21, 0.67, 0.105),
            (-0.18, -0.21, 0.68, 0.105),
            (0.08, -0.23, 0.65, 0.115),
            (0.31, -0.21, 0.67, 0.105),
        )
    ):
        sphere(f"SheepFleeceCurl{index + 1:02d}", (x, y, z), (radius, radius, radius), 12)

    # A distinct bare face, jaw and nose eliminate the old paper-thin mask. The
    # narrow ears remain inside the 0.55 m body width, so eyes can sit on the skull
    # rather than floating beside it.
    segment("SheepNeck", (-0.30, 0.0, 0.61), (-0.48, 0.0, 0.72), 0.20, 0.145)
    sphere("SheepHead", (-0.51, 0.0, 0.73), (0.17, 0.145, 0.185))
    sphere("SheepMuzzle", (-0.61, 0.0, 0.65), (0.115, 0.115, 0.105))
    sphere("SheepJaw", (-0.55, 0.0, 0.61), (0.125, 0.105, 0.075))
    segment("SheepEarLeft", (-0.48, 0.10, 0.82), (-0.43, 0.235, 0.86), 0.060, 0.018, 8)
    segment("SheepEarRight", (-0.48, -0.10, 0.82), (-0.43, -0.235, 0.86), 0.060, 0.018, 8)

    # Two-segment legs read as weight-bearing anatomy instead of four sticks. Each
    # foot has two toe volumes with a small central cleft and rests exactly on Z=0.
    for side, y in (("Left", 0.155), ("Right", -0.155)):
        for end, x, knee_dx in (("Front", -0.29, -0.025), ("Back", 0.31, 0.035)):
            segment(f"Sheep{end}{side}UpperLeg", (x, y, 0.48), (x + knee_dx, y, 0.23), 0.070, 0.052)
            segment(f"Sheep{end}{side}LowerLeg", (x + knee_dx, y, 0.25), (x, y, 0.075), 0.052, 0.036)
            sphere(f"Sheep{end}{side}HoofOuter", (x - 0.018, y + 0.022, 0.035), (0.060, 0.030, 0.035), 12)
            sphere(f"Sheep{end}{side}HoofInner", (x - 0.018, y - 0.022, 0.035), (0.060, 0.030, 0.035), 12)

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
    obj["fleece_lobes"] = 10
    obj["cloven_hoof_toes"] = 8
    return obj


def create_pig_mesh() -> bpy.types.Object:
    """Build a coherent low-poly landrace pig from closed anatomical volumes.

    WHY: the licensed scan is useful as a proportion reference, but its 17 open
    surface islands read as detached fragments in runtime. These closed volumes
    keep the approved silhouette while making the body, snout, ears, legs, hooves,
    and curled tail intentionally readable at the ambient-fauna camera distance.
    """
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ) -> bpy.types.Object:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, location=location)
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

    # One low, deep torso with distinct shoulder and rump masses avoids the
    # inflated single-blob silhouette of the rejected image-to-3D candidate.
    sphere("PigBodyCore", (0.08, 0.0, 0.49), (0.50, 0.215, 0.225))
    sphere("PigBelly", (0.04, 0.0, 0.35), (0.40, 0.195, 0.145))
    sphere("PigShoulder", (-0.28, 0.0, 0.50), (0.23, 0.215, 0.22))
    sphere("PigRump", (0.42, 0.0, 0.50), (0.24, 0.205, 0.215))

    # The head slopes down from the neck into a broad, mobile muzzle.
    segment("PigNeck", (-0.30, 0.0, 0.54), (-0.50, 0.0, 0.66), 0.18, 0.14)
    sphere("PigHead", (-0.58, 0.0, 0.65), (0.235, 0.17, 0.17), (0.0, -0.12, 0.0))
    sphere("PigMuzzle", (-0.73, 0.0, 0.59), (0.145, 0.145, 0.105), (0.0, -0.12, 0.0))
    sphere("PigJaw", (-0.68, 0.0, 0.525), (0.14, 0.13, 0.07))

    # Short tapered ears are deliberately separate volumes so their silhouette
    # remains legible instead of disappearing into the head scan.
    segment("PigEarLeft", (-0.54, 0.12, 0.76), (-0.49, 0.18, 0.88), 0.075, 0.018, 8)
    segment("PigEarRight", (-0.54, -0.12, 0.76), (-0.49, -0.18, 0.88), 0.075, 0.018, 8)

    # Four short legs have a slight species-credible rake and terminate in
    # compact cloven-foot volumes. Their vertex regions are assigned to the
    # existing quadruped bones by create_pig_rig().
    for side, y in (("Left", 0.14), ("Right", -0.14)):
        segment("PigFront%sUpper" % side, (-0.28, y, 0.42), (-0.30, y, 0.18), 0.085, 0.068)
        segment("PigFront%sLower" % side, (-0.30, y, 0.20), (-0.32, y, 0.075), 0.068, 0.055)
        sphere("PigFront%sHoof" % side, (-0.32, y, 0.055), (0.085, 0.067, 0.045))
        segment("PigBack%sUpper" % side, (0.36, y, 0.43), (0.39, y, 0.19), 0.09, 0.07)
        segment("PigBack%sLower" % side, (0.39, y, 0.20), (0.36, y, 0.075), 0.07, 0.055)
        sphere("PigBack%sHoof" % side, (0.36, y, 0.055), (0.088, 0.068, 0.045))

    # A compact three-bend tail gives the rear silhouette a pig-specific cue.
    segment("PigTailBase", (0.58, 0.0, 0.58), (0.68, 0.0, 0.66), 0.055, 0.043)
    segment("PigTailMid", (0.68, 0.0, 0.66), (0.74, 0.0, 0.75), 0.043, 0.031)
    segment("PigTailCurl", (0.74, 0.0, 0.75), (0.67, 0.0, 0.83), 0.031, 0.015)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    # The active torso keeps its old object origin after joining. Reset it before
    # metric normalization so the exported skin does not inherit a hidden offset.
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

def build(name: str, spec: dict) -> dict:
    source: Path | None = spec.get("source")
    if source is not None and not source.exists():
        raise FileNotFoundError(f"Missing approved candidate: {source}")
    clear_scene()
    if name == "sheep":
        obj = create_sheep_mesh()
        raw = topology(obj)
        discarded_before = 0
    else:
        assert source is not None
        bpy.ops.import_scene.gltf(filepath=str(source))
        source_obj = flatten_imported_hierarchy()
        raw = topology(source_obj)
        if name == "pig":
            # Keep the licensed mesh as the measured reference, but do not ship its
            # open scan fragments. The authored body below is the production source.
            clear_scene()
            obj = create_pig_mesh()
        else:
            obj = source_obj
            discarded_before = remove_tiny_islands(obj, 0.0015)
            if spec.get("source_long_axis") == "y":
                # The licensed source's head points along +Y. Rotate +90 degrees so that
                # source +Y becomes runtime -X, matching the shared quadruped rig's head,
                # neck, eye, and locomotion conventions.
                obj.rotation_euler.z = math.pi * 0.5
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
    if name == "pig":
        discarded_before = 0
    normalize_dimensions(obj, spec["dimensions_m"])
    make_uv(obj)
    profile = SURFACE_PROFILES[name]
    albedo = create_albedo(name, spec)
    normal = bake_normal_map(obj, name, profile)
    roughness = bake_roughness_map(obj, name, profile)
    assign_pbr_material(obj, name, albedo, normal, roughness, profile)
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
        "source": str(source.relative_to(ROOT)) if source is not None else "procedural:create_sheep_mesh",
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest() if source is not None else None,
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
        "textures": [
            f"{name}_albedo.png",
            f"{name}_normal.png",
            f"{name}_roughness.png",
        ],
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
