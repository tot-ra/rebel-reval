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
        "noise_scale": 110.0,
        "noise_detail": 5.5,
        "bump_strength": 0.48,
        "rough_min": 0.84,
        "rough_max": 0.96,
        "normal_strength": 0.95,
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
        # WHY: the rejected image-to-3D candidate has a fused ground sheet, stretched
        # limbs, and an unreadable head. Match the sheep pipeline by generating closed
        # anatomical volumes and fusing them into one deterministic skinned surface.
        "source": None,
        "output": RUNTIME / "medieval_cattle.glb",
        "dimensions_m": (2.20, 1.45, 1.02),
        "triangles": 9_000,
        "voxel_divisor": 78.0,
        "base_color": (0.24, 0.075, 0.028),
        "accent_color": (0.52, 0.205, 0.065),
        "seed": 208744131,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "remeshed_multi_volume_cattle_body_head_muzzle_horns_udder_four_legs_and_cloven_hooves",
        "scale_basis": "2.20 m nose-to-rump; 1.45 m standing height; 1.02 m body width",
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
        # from dense closed volumes, then voxel-remeshed into one skinned surface so
        # the fleece reads as wool rather than a cloud of overlapping spheres.
        "source": None,
        "output": RUNTIME / "medieval_sheep.glb",
        "dimensions_m": (1.25, 0.90, 0.55),
        "triangles": 8_500,
        # Coarser voxels fuse overlapping fleece hulls into one body. Micro-wool
        # then comes from the baked normal/roughness maps, not from a sphere grid.
        "voxel_divisor": 68.0,
        "base_color": (0.64, 0.59, 0.47),
        "accent_color": (0.86, 0.82, 0.70),
        "seed": 208744132,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "remeshed_multi_volume_fleece_bare_face_ears_muzzle_four_legs_and_cloven_hooves",
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


def rebuild_surface(
    obj: bpy.types.Object,
    divisor: float,
    target_triangles: int,
    *,
    smooth_factor: float = 0.42,
    smooth_iterations: int = 3,
) -> None:
    max_dimension = max(obj.dimensions)
    obj.data.remesh_voxel_size = max_dimension / divisor
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.voxel_remesh()
    remove_tiny_islands(obj, 0.006)

    smooth = obj.modifiers.new("OrganicSurfaceCleanup", "SMOOTH")
    smooth.factor = smooth_factor
    smooth.iterations = smooth_iterations
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    current_triangles = topology(obj)["triangles"]
    if current_triangles > target_triangles:
        decimate = obj.modifiers.new("ProductionTriangleBudget", "DECIMATE")
        decimate.ratio = target_triangles / current_triangles
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    bpy.ops.object.shade_smooth()
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
    # Sheep needs stronger fleece mottling so the coat does not read as clay.
    grain_weight = 0.34 if name == "sheep" else 0.22
    mix = np.clip(broad * (1.0 - grain_weight) + grain * grain_weight, 0.0, 1.0)[..., None]
    base = np.array(spec["base_color"], dtype=np.float32)
    accent = np.array(spec["accent_color"], dtype=np.float32)
    rgb = base + (accent - base) * mix
    if name == "sheep":
        # Soft UV-space dirtying keeps the portable texture from looking painted flat.
        dirt = np.clip(
            0.55
            + 0.25 * np.sin(xx / 11.0)
            + 0.20 * np.sin(yy / 13.0 + xx / 17.0),
            0.0,
            1.0,
        )[..., None]
        face_tint = np.array((0.42, 0.32, 0.24), dtype=np.float32)
        rgb = rgb * (0.82 + 0.18 * dirt) + face_tint * (0.18 * (1.0 - dirt))
        rgb = np.clip(rgb, 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=2)

    image = bpy.data.images.new(f"{name}_albedo", size, size, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(rgba.astype(np.float32).ravel().tolist())
    image.filepath_raw = str(TEXTURES / f"{name}_albedo.png")
    image.file_format = "PNG"
    image.save()
    return image


def apply_fleece_displacement(obj: bpy.types.Object, *, strength: float = 0.030) -> None:
    """Push organic wool undulation into the remeshed hull.

    WHY: fused hulls alone read as clay. A low-frequency displace keeps one
    manifold surface while breaking the silhouette into lock-scale fleece.
    """
    # Keep the bare face and lower legs smooth so displace does not wool the muzzle.
    fleece_group = obj.vertex_groups.new(name="FleeceDisplace")
    fleece_indices = [
        vertex.index
        for vertex in obj.data.vertices
        if vertex.co.z > 0.11 and not (vertex.co.x < -0.48 and vertex.co.z > 0.54)
    ]
    if fleece_indices:
        fleece_group.add(fleece_indices, 1.0, "REPLACE")

    texture = bpy.data.textures.new("SheepFleeceNoise", type="CLOUDS")
    texture.noise_scale = 0.11
    texture.noise_depth = 5
    texture.nabla = 0.025
    displace = obj.modifiers.new("SheepFleeceDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fleece_group.name
    displace.strength = strength
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)
    # A second finer pass adds lock-scale breakup on top of the broad fleece swell.
    fine = bpy.data.textures.new("SheepFleeceFine", type="CLOUDS")
    fine.noise_scale = 0.05
    fine.noise_depth = 3
    fine_displace = obj.modifiers.new("SheepFleeceFineDisplace", "DISPLACE")
    fine_displace.texture = fine
    fine_displace.texture_coords = "LOCAL"
    fine_displace.vertex_group = fleece_group.name
    fine_displace.strength = strength * 0.35
    fine_displace.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier=fine_displace.name)
    # Lift any displaced hoof verts that sank below the authored ground plane.
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("SheepWeightedNormals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    bpy.ops.object.shade_smooth()


def paint_sheep_region_vertex_colors(obj: bpy.types.Object) -> None:
    """Mark bare face and hoof regions so albedo bake can darken them."""
    color_layer = obj.data.color_attributes.new(
        name="SheepRegions", type="BYTE_COLOR", domain="POINT"
    )
    wool = (0.78, 0.72, 0.58, 1.0)
    face = (0.36, 0.26, 0.18, 1.0)
    hoof = (0.16, 0.12, 0.09, 1.0)
    for index, vertex in enumerate(obj.data.vertices):
        point = vertex.co
        if point.z < 0.085:
            color_layer.data[index].color = hoof
        elif point.x < -0.46 and point.z > 0.52:
            color_layer.data[index].color = face
        else:
            color_layer.data[index].color = wool


def bake_sheep_region_albedo(obj: bpy.types.Object, base_albedo: bpy.types.Image) -> bpy.types.Image:
    """Multiply portable coat variation with bare-face / hoof region colors."""
    paint_sheep_region_vertex_colors(obj)
    _prepare_bake_scene()
    material = bpy.data.materials.new("medieval_sheep_region_bake")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    output = nodes.get("Material Output")
    emission = nodes.new("ShaderNodeEmission")
    attribute = nodes.new("ShaderNodeAttribute")
    attribute.attribute_name = "SheepRegions"
    base_node = nodes.new("ShaderNodeTexImage")
    base_node.image = base_albedo
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs["Fac"].default_value = 1.0
    links.new(base_node.outputs["Color"], mix.inputs["Color1"])
    links.new(attribute.outputs["Color"], mix.inputs["Color2"])
    links.new(mix.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    obj.data.materials.clear()
    obj.data.materials.append(material)

    image = new_image("sheep_region_albedo", (0.7, 0.65, 0.55, 1.0))
    image_node = nodes.new("ShaderNodeTexImage")
    image_node.image = image
    nodes.active = image_node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=8)
    image.filepath_raw = str(TEXTURES / "sheep_albedo.png")
    image.file_format = "PNG"
    image.save()
    bpy.data.materials.remove(material)
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




def create_cattle_mesh() -> bpy.types.Object:
    """Build a sturdy northern-European cow from closed anatomical volumes.

    WHY: the old image-to-3D mesh fused the animal to a ground sheet and distorted
    its limbs. Interlocking closed volumes follow the successful sheep pipeline:
    voxel remesh produces one clean hide surface while retaining a broad barrel,
    deep chest, level back, readable bovine head, horns, udder, and planted legs.
    """
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 22,
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

    # A long barrel with distinct shoulder and rump masses gives cattle their
    # load-bearing silhouette without reproducing the old tent-like dorsal ridge.
    sphere("CattleBarrel", (0.08, 0.0, 0.86), (0.72, 0.42, 0.40), 28, 16)
    sphere("CattleBelly", (0.10, 0.0, 0.67), (0.58, 0.37, 0.27), 24, 14)
    sphere("CattleShoulders", (-0.48, 0.0, 0.90), (0.40, 0.43, 0.43), 24, 14)
    sphere("CattleBrisket", (-0.55, 0.0, 0.70), (0.26, 0.35, 0.31), 20, 12)
    sphere("CattleRump", (0.58, 0.0, 0.88), (0.41, 0.41, 0.40), 24, 14)
    sphere("CattleTopline", (0.08, 0.0, 1.12), (0.60, 0.32, 0.16), 22, 12)

    # The neck slopes forward into a broad poll and a blunt, low muzzle. Cheeks,
    # ears, horn bases, dewlap, and nostril plane keep the face bovine in close view.
    segment("CattleNeck", (-0.48, 0.0, 0.92), (-0.86, 0.0, 1.13), 0.34, 0.23)
    sphere("CattlePoll", (-0.91, 0.0, 1.19), (0.25, 0.30, 0.25), 22, 12)
    sphere("CattleForehead", (-1.02, 0.0, 1.16), (0.25, 0.25, 0.25), 22, 12)
    sphere("CattleCheekLeft", (-1.03, 0.17, 1.04), (0.20, 0.15, 0.19), 18, 10)
    sphere("CattleCheekRight", (-1.03, -0.17, 1.04), (0.20, 0.15, 0.19), 18, 10)
    sphere("CattleMuzzle", (-1.25, 0.0, 0.96), (0.24, 0.25, 0.17), 22, 12)
    sphere("CattleNose", (-1.39, 0.0, 0.94), (0.13, 0.23, 0.13), 18, 10)
    sphere("CattleJaw", (-1.12, 0.0, 0.86), (0.21, 0.21, 0.14), 18, 10)
    sphere("CattleDewlap", (-0.71, 0.0, 0.69), (0.24, 0.20, 0.25), 18, 10)
    segment("CattleEarLeft", (-0.94, 0.19, 1.26), (-0.88, 0.43, 1.24), 0.095, 0.025, 10)
    segment("CattleEarRight", (-0.94, -0.19, 1.26), (-0.88, -0.43, 1.24), 0.095, 0.025, 10)
    for side, y_sign in (("Left", 1.0), ("Right", -1.0)):
        # Short outward-upward horns suit practical medieval cows and survive the
        # remesh better than thin crescents.
        segment(
            f"CattleHorn{side}Base",
            (-0.88, 0.18 * y_sign, 1.34),
            (-0.83, 0.34 * y_sign, 1.44),
            0.075,
            0.045,
            12,
        )
        segment(
            f"CattleHorn{side}Tip",
            (-0.83, 0.34 * y_sign, 1.44),
            (-0.90, 0.43 * y_sign, 1.53),
            0.046,
            0.014,
            10,
        )

    # Hip/shoulder caps and articulated-looking limb volumes prevent the remesh
    # from creating spindly poles. Every cloven toe ends at Z=0 before normalization.
    for side, y in (("Left", 0.29), ("Right", -0.29)):
        sphere(f"CattleFront{side}Shoulder", (-0.52, y, 0.74), (0.16, 0.14, 0.22), 16, 9)
        sphere(f"CattleBack{side}Hip", (0.58, y, 0.76), (0.18, 0.15, 0.23), 16, 9)
        for end, x, knee_dx in (("Front", -0.52, -0.02), ("Back", 0.58, 0.05)):
            segment(
                f"Cattle{end}{side}UpperLeg",
                (x, y, 0.76),
                (x + knee_dx, y, 0.40),
                0.125,
                0.090,
            )
            segment(
                f"Cattle{end}{side}LowerLeg",
                (x + knee_dx, y, 0.42),
                (x, y, 0.13),
                0.090,
                0.057,
            )
            segment(
                f"Cattle{end}{side}Pastern",
                (x, y, 0.15),
                (x - 0.02, y, 0.055),
                0.058,
                0.045,
                10,
            )
            sphere(
                f"Cattle{end}{side}HoofOuter",
                (x - 0.035, y + 0.032, 0.045),
                (0.095, 0.050, 0.045),
                14,
                8,
            )
            sphere(
                f"Cattle{end}{side}HoofInner",
                (x - 0.035, y - 0.032, 0.045),
                (0.095, 0.050, 0.045),
                14,
                8,
            )

    # A restrained udder identifies the animal as a cow without becoming a comic
    # focal point. Four short teats remain connected through remesh.
    sphere("CattleUdder", (0.39, 0.0, 0.49), (0.24, 0.24, 0.16), 18, 10)
    for index, (x, y) in enumerate(((0.31, 0.10), (0.31, -0.10), (0.47, 0.10), (0.47, -0.10))):
        segment(f"CattleTeat{index}", (x, y, 0.48), (x, y, 0.36), 0.040, 0.026, 10)

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
    obj["cloven_hoof_toes"] = 8
    obj["horn_count"] = 2
    obj["udder_teat_count"] = 4
    return obj
def create_sheep_mesh() -> bpy.types.Object:
    """Build a detailed sheep from dense closed volumes for later remesh.

    WHY: a plain object.join of spheres reads as a bubble cloud under the map
    camera. These interlocking fleece, face, and leg volumes are authored denser
    than the final budget so voxel remesh can fuse them into one woolly body while
    keeping a bare face, ears, and cloven hooves readable.
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

    # Heavily overlapping fleece hulls only. A regular lock grid survives remesh as
    # toy-like sphere rows; soft overlapping volumes fuse into one wool body while
    # the baked normal map supplies the micro-curl reading.
    sphere("SheepFleeceCore", (0.04, 0.0, 0.52), (0.47, 0.255, 0.285), 24, 14)
    sphere("SheepFleeceBelly", (0.02, 0.0, 0.38), (0.37, 0.210, 0.150), 20, 12)
    sphere("SheepFleeceShoulder", (-0.26, 0.0, 0.55), (0.30, 0.270, 0.290), 22, 12)
    sphere("SheepFleeceChest", (-0.34, 0.0, 0.46), (0.18, 0.210, 0.185), 18, 10)
    sphere("SheepFleeceRump", (0.33, 0.0, 0.53), (0.30, 0.260, 0.280), 22, 12)
    sphere("SheepFleeceBack", (0.02, 0.0, 0.70), (0.36, 0.230, 0.140), 20, 11)
    sphere("SheepFleeceWithers", (-0.12, 0.0, 0.68), (0.22, 0.210, 0.120), 18, 10)
    sphere("SheepFleecePoll", (-0.38, 0.0, 0.74), (0.13, 0.145, 0.110), 16, 9)
    sphere("SheepFleeceFlankLeft", (0.06, 0.20, 0.52), (0.28, 0.120, 0.200), 18, 10)
    sphere("SheepFleeceFlankRight", (0.06, -0.20, 0.52), (0.28, 0.120, 0.200), 18, 10)
    sphere("SheepFleeceBritchLeft", (0.30, 0.16, 0.48), (0.16, 0.120, 0.180), 16, 9)
    sphere("SheepFleeceBritchRight", (0.30, -0.16, 0.48), (0.16, 0.120, 0.180), 16, 9)
    fleece_locks = 12

    # Bare face volumes stay denser than fleece so remesh preserves a readable
    # skull, muzzle plane, and ear tips inside the 0.55 m body width.
    segment("SheepNeck", (-0.32, 0.0, 0.58), (-0.50, 0.0, 0.70), 0.18, 0.125)
    sphere("SheepHead", (-0.54, 0.0, 0.72), (0.155, 0.125, 0.165), 18, 10)
    sphere("SheepForehead", (-0.50, 0.0, 0.80), (0.10, 0.11, 0.08), 14, 8)
    sphere("SheepCheekLeft", (-0.56, 0.08, 0.68), (0.08, 0.07, 0.08), 12, 8)
    sphere("SheepCheekRight", (-0.56, -0.08, 0.68), (0.08, 0.07, 0.08), 12, 8)
    sphere("SheepMuzzle", (-0.66, 0.0, 0.64), (0.105, 0.085, 0.085), 16, 9)
    sphere("SheepNoseBridge", (-0.62, 0.0, 0.69), (0.07, 0.05, 0.05), 12, 8)
    sphere("SheepJaw", (-0.58, 0.0, 0.58), (0.11, 0.09, 0.07), 14, 8)
    segment("SheepEarLeft", (-0.50, 0.09, 0.80), (-0.46, 0.22, 0.84), 0.055, 0.016, 8)
    segment("SheepEarRight", (-0.50, -0.09, 0.80), (-0.46, -0.22, 0.84), 0.055, 0.016, 8)

    # Thigh/shoulder caps plus three-segment legs prevent remesh from turning limbs
    # into thin stilts. Cloven toes rest on Z=0 so normalize keeps ground contact.
    for side, y in (("Left", 0.155), ("Right", -0.155)):
        sphere(f"SheepFront{side}Shoulder", (-0.30, y, 0.48), (0.10, 0.09, 0.11), 12, 8)
        sphere(f"SheepBack{side}Hip", (0.32, y, 0.48), (0.11, 0.095, 0.12), 12, 8)
        for end, x, knee_dx in (("Front", -0.30, -0.02), ("Back", 0.32, 0.03)):
            segment(
                f"Sheep{end}{side}UpperLeg",
                (x, y, 0.46),
                (x + knee_dx, y, 0.24),
                0.075,
                0.055,
            )
            segment(
                f"Sheep{end}{side}LowerLeg",
                (x + knee_dx, y, 0.25),
                (x, y, 0.09),
                0.055,
                0.038,
            )
            segment(
                f"Sheep{end}{side}Pastern",
                (x, y, 0.095),
                (x - 0.01, y, 0.04),
                0.038,
                0.030,
                8,
            )
            sphere(
                f"Sheep{end}{side}HoofOuter",
                (x - 0.012, y + 0.018, 0.030),
                (0.055, 0.028, 0.030),
                12,
                8,
            )
            sphere(
                f"Sheep{end}{side}HoofInner",
                (x - 0.012, y - 0.018, 0.030),
                (0.055, 0.028, 0.030),
                12,
                8,
            )

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
    obj["fleece_lobes"] = fleece_locks
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
    if name in {"cattle", "sheep"}:
        obj = create_cattle_mesh() if name == "cattle" else create_sheep_mesh()
        raw = topology(obj)
        # WHY: without remesh the joined anatomical volumes stay as separate
        # islands. Species-tuned smoothing fuses them into a coherent silhouette
        # while retaining cattle joints or sheep fleece relief.
        rebuild_surface(
            obj,
            spec["voxel_divisor"],
            spec["triangles"],
            smooth_factor=0.58 if name == "cattle" else 0.72,
            smooth_iterations=7 if name == "cattle" else 12,
        )
        if name == "sheep":
            apply_fleece_displacement(obj, strength=0.052)
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
    if name == "sheep":
        # WHY: a single flat coat makes the remeshed body read as clay. Region bake
        # keeps one production surface while darkening the bare face and hooves.
        albedo = bake_sheep_region_albedo(obj, albedo)
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
        "source": (
            str(source.relative_to(ROOT))
            if source is not None
            else f"procedural:create_{name}_mesh"
        ),
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
        "animations": ["Idle-loop", "Walk-loop", "Trot-loop", "Graze-loop"] if armature is not None else [],
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
