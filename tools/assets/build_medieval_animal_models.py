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
        # Low bump: a small udder UV island magnifies high-frequency noise into speckle.
        "bump_strength": 0.08,
        "rough_min": 0.78,
        "rough_max": 0.90,
        "normal_strength": 0.28,
    },
    "goat": {
        "noise_scale": 62.0,
        "noise_detail": 4.0,
        "bump_strength": 0.30,
        "rough_min": 0.80,
        "rough_max": 0.92,
        "normal_strength": 0.78,
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
        # Short summer coat: fine hair grain and a soft sheen, not clay.
        "noise_scale": 148.0,
        "noise_detail": 6.0,
        "bump_strength": 0.16,
        "rough_min": 0.50,
        "rough_max": 0.72,
        "normal_strength": 0.48,
    },
    "brown_bear": {
        # High-frequency guard-hair breakup so the remeshed hull does not read as clay.
        "noise_scale": 92.0,
        "noise_detail": 5.2,
        "bump_strength": 0.42,
        "rough_min": 0.82,
        "rough_max": 0.96,
        "normal_strength": 0.92,
    },
    "elk": {
        # Long winter guard hair on a Baltic moose. Coarser than cattle hide so
        # the remeshed barrel does not read as a wet clay horse.
        "noise_scale": 78.0,
        "noise_detail": 4.8,
        "bump_strength": 0.36,
        "rough_min": 0.80,
        "rough_max": 0.94,
        "normal_strength": 0.86,
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
        # WHY: 2.20 x 1.45 m read as a stubby yard animal beside heroic characters,
        # and the sideways walk made the 1.02 m width look like body length. Grow
        # the metric envelope for gameplay readability while keeping cattle below
        # pack-horse withers.
        "dimensions_m": (2.65, 1.72, 1.18),
        "triangles": 9_000,
        "voxel_divisor": 78.0,
        "base_color": (0.24, 0.075, 0.028),
        "accent_color": (0.52, 0.205, 0.065),
        "seed": 208744131,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "remeshed_multi_volume_cattle_body_head_muzzle_horns_udder_four_legs_and_cloven_hooves",
        "scale_basis": "2.65 m nose-to-rump; 1.72 m standing height; 1.18 m body width",
    },
    "goat": {
        # WHY: replace the static licensed scan with reproducible authored anatomy
        # and the shared livestock animation contract requested for the live actor.
        "source": None,
        "output": RUNTIME / "medieval_goat.glb",
        "dimensions_m": (1.30, 1.05, 0.48),
        "triangles": 8_000,
        "voxel_divisor": 76.0,
        "base_color": (0.20, 0.105, 0.052),
        "accent_color": (0.48, 0.31, 0.16),
        "seed": 208744135,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "AGPL-3.0-or-later (project author)",
        "anatomy_decision": "remeshed_goat_barrel_wedge_head_swept_horns_beard_four_legs_and_cloven_hooves",
        "scale_basis": "1.30 m nose-to-rump; 1.05 m horn height; 0.48 m body width",
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
        # WHY: the Hunyuan candidate stayed a faceted open shell. Its mane and tail
        # tore under decimation, and a flat UV noise coat hid hooves and the crest.
        # Closed volumes remesh into one hide that can sit on the existing rig.
        "source": None,
        "output": RUNTIME / "medieval_pack_horse.glb",
        "dimensions_m": (2.35, 1.65, 0.78),
        "triangles": 22_000,
        "voxel_divisor": 132.0,
        "base_color": (0.42, 0.175, 0.062),
        "accent_color": (0.16, 0.07, 0.035),
        "seed": 208744133,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "lofted_draft_horse_deep_chest_tucked_belly_arched_crest_long_head_cannons_and_hooves",
        "scale_basis": "2.35 m nose-to-rump; 1.65 m standing height; 0.78 m width",
    },
    "brown_bear": {
        # WHY: the catalog bear is a 6-segment ellipsoid loaf. A Witcher-scale
        # Eurasian brown bear needs a scapular hump, dish face, plantigrade paws,
        # and a shaggy coat that reads at street range on the foreland margin.
        "source": None,
        "output": RUNTIME / "medieval_brown_bear.glb",
        "dimensions_m": (2.28, 1.52, 1.18),
        "triangles": 13_000,
        "voxel_divisor": 96.0,
        "base_color": (0.26, 0.15, 0.07),
        "accent_color": (0.44, 0.28, 0.14),
        "seed": 208744136,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "remeshed_ursine_barrel_scapular_hump_dish_face_plantigrade_paws_and_shaggy_coat",
        "scale_basis": "2.28 m nose-to-rump; 1.52 m standing height including hump; 1.18 m body width",
    },
    "elk": {
        # WHY: the catalog elk is a 1.55 m ellipsoid loaf with two cone posts.
        # A Witcher-scale Eurasian elk (Alces alces) needs long legs, a scapular
        # hump, a hanging roman muzzle, a throat bell, and palmate antlers.
        "source": None,
        "output": RUNTIME / "medieval_elk.glb",
        "dimensions_m": (2.55, 1.78, 0.80),
        "triangles": 11_000,
        "voxel_divisor": 88.0,
        "base_color": (0.16, 0.09, 0.05),
        "accent_color": (0.34, 0.24, 0.16),
        "seed": 208744137,
        "animated": True,
        "route": "deterministic_procedural_closed_anatomy_remesh",
        "source_license": "project-authored procedural geometry",
        "anatomy_decision": "remeshed_eurasian_elk_hump_hanging_muzzle_bell_palmate_antlers_long_legs_and_cloven_hooves",
        "scale_basis": "2.55 m nose-to-rump; 1.78 m shoulder height; 0.80 m body width; palmate antlers are Neck details",
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


def apply_bear_fur_displacement(obj: bpy.types.Object, *, strength: float = 0.038) -> None:
    """Push shaggy guard-hair undulation into the remeshed ursine hull.

    WHY: a smooth remesh reads as a clay toy. Low-frequency displace on the
    cape, ruff, and flanks keeps one manifold surface while breaking the
    silhouette the way a Witcher-scale brown bear coat should.
    """
    fur_group = obj.vertex_groups.new(name="BearFurDisplace")
    fur_indices = [
        vertex.index
        for vertex in obj.data.vertices
        if vertex.co.z > 0.14 and not (vertex.co.x < -0.92 and vertex.co.z > 0.62)
    ]
    if fur_indices:
        fur_group.add(fur_indices, 1.0, "REPLACE")

    texture = bpy.data.textures.new("BearFurNoise", type="CLOUDS")
    texture.noise_scale = 0.13
    texture.noise_depth = 5
    texture.nabla = 0.028
    displace = obj.modifiers.new("BearFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = strength
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)

    fine = bpy.data.textures.new("BearFurFine", type="CLOUDS")
    fine.noise_scale = 0.055
    fine.noise_depth = 4
    fine_displace = obj.modifiers.new("BearFurFineDisplace", "DISPLACE")
    fine_displace.texture = fine
    fine_displace.texture_coords = "LOCAL"
    fine_displace.vertex_group = fur_group.name
    fine_displace.strength = strength * 0.40
    fine_displace.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier=fine_displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("BearWeightedNormals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 50
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    bpy.ops.object.shade_smooth()


def apply_elk_fur_displacement(obj: bpy.types.Object, *, strength: float = 0.028) -> None:
    """Push winter guard-hair undulation into the remeshed elk hull.

    WHY: a smooth remesh reads as a clay horse. Low-frequency displace on the
    barrel and hump keeps one manifold surface, but antlers, hooves, and the
    hanging muzzle must stay keratin-hard or the species read collapses.
    """
    fur_group = obj.vertex_groups.new(name="ElkFurDisplace")
    fur_indices = []
    for vertex in obj.data.vertices:
        point = vertex.co
        hoof = point.z < 0.16
        muzzle = point.x < -1.20
        if not hoof and not muzzle:
            fur_indices.append(vertex.index)
    if fur_indices:
        fur_group.add(fur_indices, 1.0, "REPLACE")

    texture = bpy.data.textures.new("ElkFurNoise", type="CLOUDS")
    texture.noise_scale = 0.16
    texture.noise_depth = 4
    texture.nabla = 0.030
    displace = obj.modifiers.new("ElkFurDisplace", "DISPLACE")
    displace.texture = texture
    displace.texture_coords = "LOCAL"
    displace.vertex_group = fur_group.name
    displace.strength = strength
    displace.mid_level = 0.5
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=displace.name)

    fine = bpy.data.textures.new("ElkFurFine", type="CLOUDS")
    fine.noise_scale = 0.062
    fine.noise_depth = 3
    fine_displace = obj.modifiers.new("ElkFurFineDisplace", "DISPLACE")
    fine_displace.texture = fine
    fine_displace.texture_coords = "LOCAL"
    fine_displace.vertex_group = fur_group.name
    fine_displace.strength = strength * 0.38
    fine_displace.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier=fine_displace.name)
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    if min_z < 0.0:
        for vertex in obj.data.vertices:
            vertex.co.z -= min_z
        obj.data.update()
    weighted = obj.modifiers.new("ElkWeightedNormals", "WEIGHTED_NORMAL")
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


def _mesh_bounds(obj: bpy.types.Object) -> dict[str, float]:
    points = [vertex.co for vertex in obj.data.vertices]
    return {
        "min_x": min(point.x for point in points),
        "max_x": max(point.x for point in points),
        "max_y": max(abs(point.y) for point in points),
        "min_z": min(point.z for point in points),
        "max_z": max(point.z for point in points),
    }


def _coat_wobble(color: tuple[float, float, float], point: Vector, scale: float) -> tuple[float, float, float]:
    """Break a flat hide with object-space variation so UV islands cannot tile blocks."""
    wave = 0.5 + 0.5 * math.sin(point.x * 7.5 + point.z * 5.0 + point.y * 11.0)
    span = 1.0 - scale + (2.0 * scale * wave)
    return tuple(max(0.0, min(1.0, channel * span)) for channel in color)


def livestock_region_color(name: str, point: Vector, bounds: dict[str, float]) -> tuple[float, float, float]:
    """Pick hoof, horn, muzzle, mane, and belly colors from the normalized body."""
    length = max(bounds["max_x"] - bounds["min_x"], 1e-6)
    height = max(bounds["max_z"] - bounds["min_z"], 1e-6)
    # nx is 0 at the nose and 1 at the rump. Both species face -X.
    nose_to_rump = (point.x - bounds["min_x"]) / length
    height_ratio = (point.z - bounds["min_z"]) / height
    side_ratio = abs(point.y) / max(bounds["max_y"], 1e-6)
    if name == "brown_bear":
        # Dark Eurasian coat: black-brown stockings, tan muzzle, grizzled cape.
        if height_ratio < 0.080:
            return (0.035, 0.022, 0.014)
        if height_ratio < 0.34 and (nose_to_rump < 0.40 or nose_to_rump > 0.60):
            return _coat_wobble((0.07, 0.038, 0.018), point, 0.04)
        if nose_to_rump < 0.09 and height_ratio < 0.70:
            return (0.38, 0.28, 0.18)
        if nose_to_rump < 0.18 and 0.56 < height_ratio < 0.88 and side_ratio > 0.18:
            return (0.055, 0.032, 0.018)
        if side_ratio < 0.30 and height_ratio < 0.40 and nose_to_rump < 0.36:
            return _coat_wobble((0.22, 0.14, 0.07), point, 0.05)
        if height_ratio > 0.70 and 0.16 < nose_to_rump < 0.55:
            return _coat_wobble((0.30, 0.18, 0.08), point, 0.09)
        return _coat_wobble((0.14, 0.075, 0.035), point, 0.06)
    if name == "elk":
        # Eurasian moose: dark chocolate body, pale stockings, cream muzzle,
        # keratin antlers. Small UV islands stay in COLOR_0, not the atlas.
        if height_ratio < 0.055:
            return (0.055, 0.035, 0.022)
        if height_ratio > 0.78 and (side_ratio > 0.26 or nose_to_rump < 0.34):
            return _coat_wobble((0.20, 0.13, 0.08), point, 0.04)
        if nose_to_rump < 0.12 and height_ratio < 0.70:
            return (0.46, 0.38, 0.28)
        if height_ratio < 0.34 and (nose_to_rump < 0.42 or nose_to_rump > 0.60):
            return _coat_wobble((0.34, 0.24, 0.16), point, 0.05)
        if height_ratio > 0.60 and 0.20 < nose_to_rump < 0.52:
            return _coat_wobble((0.10, 0.055, 0.032), point, 0.06)
        return _coat_wobble((0.17, 0.095, 0.052), point, 0.07)
    if name == "cattle":
        if height_ratio < 0.055:
            return (0.07, 0.045, 0.03)
        if height_ratio > 0.88 and side_ratio > 0.48 and nose_to_rump < 0.34:
            return _coat_wobble((0.62, 0.48, 0.32), point, 0.04)
        if nose_to_rump < 0.09 and height_ratio < 0.64:
            return (0.15, 0.08, 0.065)
        if 0.50 < nose_to_rump < 0.74 and height_ratio < 0.34 and side_ratio < 0.42:
            return (0.58, 0.34, 0.30)
        if height_ratio < 0.30 and side_ratio < 0.32:
            return _coat_wobble((0.42, 0.22, 0.13), point, 0.05)
        return _coat_wobble((0.32, 0.12, 0.05), point, 0.07)
    if name == "pack_horse":
        return _bay_horse_color(point)
    if height_ratio < 0.055:
        return (0.05, 0.035, 0.028)
    if height_ratio < 0.26 and (nose_to_rump < 0.40 or nose_to_rump > 0.64):
        return _coat_wobble((0.09, 0.055, 0.035), point, 0.04)
    if nose_to_rump < 0.11 and height_ratio < 0.78:
        return (0.13, 0.07, 0.05)
    if side_ratio < 0.18 and height_ratio > 0.64 and nose_to_rump < 0.58:
        return (0.045, 0.03, 0.025)
    if nose_to_rump > 0.88 and side_ratio < 0.30:
        return (0.045, 0.03, 0.025)
    return _coat_wobble((0.36, 0.17, 0.07), point, 0.06)


def _mix_color(
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    weight: float,
) -> tuple[float, float, float]:
    blend = max(0.0, min(1.0, weight))
    return tuple(start[channel] * (1.0 - blend) + end[channel] * blend for channel in range(3))


def _bay_horse_color(point: Vector) -> tuple[float, float, float]:
    """Dark-bay coat with black points, the readable medieval draft colour.

    WHY: a single brown reads as clay at street distance. Black legs, mane,
    muzzle, and tail plus a lighter barrel are what make a horse read as a horse.
    """
    bay = (0.40, 0.16, 0.055)
    bay_light = (0.56, 0.26, 0.095)
    black = (0.04, 0.026, 0.02)
    dark = (0.11, 0.05, 0.03)
    sun = 0.5 + 0.5 * math.sin(point.x * 1.35 + point.z * 0.55)
    upper = max(0.0, min(1.0, (point.z - 0.95) / 0.40))
    color = _mix_color(bay, bay_light, 0.38 * sun * upper)
    color = _coat_wobble(color, point, 0.04)
    on_leg = (point.x < -0.32 or point.x > 0.38) and abs(point.y) > 0.06
    if on_leg:
        stocking = max(0.0, min(1.0, (0.48 - point.z) / 0.32))
        color = _mix_color(color, dark, stocking * 0.9)
    hoof = max(0.0, min(1.0, (0.09 - point.z) / 0.09))
    color = _mix_color(color, black, hoof)
    if -0.95 < point.x < 0.08:
        crest_y = max(0.0, 1.0 - abs(point.y) / 0.065)
        crest_z = max(0.0, min(1.0, (point.z - 1.16) / 0.28))
        color = _mix_color(color, black, crest_y * crest_z * 0.95)
    if point.z > 1.48 and point.x < -0.70:
        color = _mix_color(color, black, 0.8)
    if point.x < -0.98:
        muzzle = max(0.0, min(1.0, (-0.98 - point.x) / 0.18))
        color = _mix_color(color, (0.09, 0.05, 0.035), muzzle)
    if point.x > 0.78 and abs(point.y) < 0.16:
        dock = max(0.0, min(1.0, (point.x - 0.78) / 0.18))
        color = _mix_color(color, black, dock)
    if abs(point.y) < 0.16 and 0.70 < point.z < 0.98 and -0.15 < point.x < 0.45:
        color = _mix_color(color, (0.50, 0.25, 0.11), 0.28)
    if -0.78 < point.x < -0.42 and abs(point.y) < 0.08 and 0.95 < point.z < 1.22:
        color = _mix_color(color, dark, 0.4)
    return color


def _fill_coat_triangle(
    buffer: np.ndarray,
    cover: np.ndarray,
    uvs: list[tuple[float, float]],
    colors: list[np.ndarray],
) -> None:
    size = buffer.shape[0]
    points = np.array(uvs, dtype=np.float64)
    points[:, 0] *= size - 1
    points[:, 1] *= size - 1
    min_x = max(int(np.floor(points[:, 0].min())), 0)
    max_x = min(int(np.ceil(points[:, 0].max())), size - 1)
    min_y = max(int(np.floor(points[:, 1].min())), 0)
    max_y = min(int(np.ceil(points[:, 1].max())), size - 1)
    if min_x > max_x or min_y > max_y:
        return
    edge_u = points[1] - points[0]
    edge_v = points[2] - points[0]
    denom = edge_u[0] * edge_v[1] - edge_v[0] * edge_u[1]
    if abs(denom) < 1e-6:
        return
    xs = np.arange(min_x, max_x + 1)
    ys = np.arange(min_y, max_y + 1)
    grid_x, grid_y = np.meshgrid(xs, ys)
    offset_x = grid_x - points[0, 0]
    offset_y = grid_y - points[0, 1]
    weight_u = (offset_x * edge_v[1] - edge_v[0] * offset_y) / denom
    weight_v = (edge_u[0] * offset_y - offset_x * edge_u[1]) / denom
    weight_origin = 1.0 - weight_u - weight_v
    mask = (weight_origin >= -0.02) & (weight_u >= -0.02) & (weight_v >= -0.02)
    if not np.any(mask):
        return
    painted = (
        weight_origin[..., None] * colors[0]
        + weight_u[..., None] * colors[1]
        + weight_v[..., None] * colors[2]
    )
    target = buffer[min_y : max_y + 1, min_x : max_x + 1]
    target[mask] = painted[mask]
    cover[min_y : max_y + 1, min_x : max_x + 1][mask] = True


def _dilate_coat(buffer: np.ndarray, cover: np.ndarray, radius: int) -> None:
    """Bleed filled texels into empty UV padding so island seams do not flash black."""
    filled = buffer
    mask = cover
    for _step in range(radius):
        grown = mask.copy()
        color = filled.copy()
        for shift_y, shift_x in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shifted_mask = np.zeros_like(mask)
            shifted_color = np.zeros_like(filled)
            if shift_y == 1:
                shifted_mask[:-1, :] = mask[1:, :]
                shifted_color[:-1, :] = filled[1:, :]
            elif shift_y == -1:
                shifted_mask[1:, :] = mask[:-1, :]
                shifted_color[1:, :] = filled[:-1, :]
            elif shift_x == 1:
                shifted_mask[:, :-1] = mask[:, 1:]
                shifted_color[:, :-1] = filled[:, 1:]
            else:
                shifted_mask[:, 1:] = mask[:, :-1]
                shifted_color[:, 1:] = filled[:, :-1]
            take = (~grown) & shifted_mask
            color[take] = shifted_color[take]
            grown[take] = True
        filled = color
        mask = grown
    buffer[:] = filled
    cover[:] = mask


def _rasterize_region_colors(obj: bpy.types.Object, layer_name: str) -> np.ndarray:
    mesh = obj.data
    uv_data = mesh.uv_layers.active.data
    color_data = mesh.color_attributes[layer_name].data
    buffer = np.zeros((TEXTURE_SIZE, TEXTURE_SIZE, 3), dtype=np.float32)
    cover = np.zeros((TEXTURE_SIZE, TEXTURE_SIZE), dtype=bool)
    for polygon in mesh.polygons:
        loop_ids = polygon.loop_indices
        if len(loop_ids) < 3:
            continue
        for start in range(1, len(loop_ids) - 1):
            triangle = (loop_ids[0], loop_ids[start], loop_ids[start + 1])
            uvs: list[tuple[float, float]] = []
            colors: list[np.ndarray] = []
            for loop_index in triangle:
                uv = uv_data[loop_index].uv
                uvs.append((float(uv.x), float(uv.y)))
                vertex_index = mesh.loops[loop_index].vertex_index
                colors.append(np.array(color_data[vertex_index].color[:3], dtype=np.float64))
            _fill_coat_triangle(buffer, cover, uvs, colors)
    _dilate_coat(buffer, cover, 8)
    return buffer


def bake_livestock_region_albedo(obj: bpy.types.Object, name: str) -> bpy.types.Image:
    """Paint hoof, horn, muzzle, and mane colors straight into the UV atlas.

    WHY: a UV-space sine texture ignores anatomy, and a Cycles emit bake of the
    same vertex colors collapsed small islands into a dot grid on the udder.
    """
    bounds = _mesh_bounds(obj)
    layer_name = f"{name}_regions"
    color_layer = obj.data.color_attributes.new(name=layer_name, type="BYTE_COLOR", domain="POINT")
    for index, vertex in enumerate(obj.data.vertices):
        red, green, blue = livestock_region_color(name, vertex.co, bounds)
        color_layer.data[index].color = (red, green, blue, 1.0)

    rgb = np.clip(_rasterize_region_colors(obj, layer_name), 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((TEXTURE_SIZE, TEXTURE_SIZE, 1), dtype=np.float32)], axis=2)
    image = bpy.data.images.new(f"{name}_albedo", TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    image.colorspace_settings.name = "sRGB"
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
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

    region_name = f"{name}_regions"
    if obj.data.color_attributes.get(region_name) is not None:
        # Godot displays this attribute only after vertex_color_use_as_albedo is set.
        # A UV atlas of the same colors breaks horns and the udder into dots.
        attribute = nodes.new("ShaderNodeAttribute")
        attribute.attribute_name = region_name
        links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
    else:
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
    if name == "pack_horse":
        # A fully matte hide reads as clay. Short coat needs a soft highlight.
        if "Specular IOR Level" in shader.inputs:
            shader.inputs["Specular IOR Level"].default_value = 0.40
        if "Sheen Weight" in shader.inputs:
            shader.inputs["Sheen Weight"].default_value = 0.20
        if "Sheen Roughness" in shader.inputs:
            shader.inputs["Sheen Roughness"].default_value = 0.42
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
    # Lateral ears are flat paddles below the horn line. Thin cones remeshed into
    # extra horn nubs and made the poll unreadable.
    sphere("CattleEarLeft", (-0.98, 0.36, 1.14), (0.05, 0.18, 0.11), 14, 8)
    sphere("CattleEarRight", (-0.98, -0.36, 1.14), (0.05, 0.18, 0.11), 14, 8)
    for side, y_sign in (("Left", 1.0), ("Right", -1.0)):
        # Thick enough to survive the voxel size, curved out then forward so the
        # pair reads as horns instead of broken posts.
        # The tip starts inside the base so remesh fuses one curve, not a branch.
        segment(
            f"CattleHorn{side}Base",
            (-0.90, 0.08 * y_sign, 1.30),
            (-0.76, 0.24 * y_sign, 1.50),
            0.090,
            0.055,
            12,
        )
        segment(
            f"CattleHorn{side}Tip",
            (-0.82, 0.16 * y_sign, 1.42),
            (-0.96, 0.32 * y_sign, 1.62),
            0.060,
            0.026,
            10,
        )
    segment("CattleTailDock", (0.92, 0.0, 1.00), (1.12, 0.0, 0.72), 0.10, 0.035, 10)

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
    # One udder mass. Separate teats remesh into a speckled lump whose UV islands
    # sample padding instead of the pink coat.
    sphere("CattleUdder", (0.39, 0.0, 0.46), (0.22, 0.20, 0.14), 18, 10)

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
    obj["udder_teat_count"] = 0
    return obj


def create_goat_mesh() -> bpy.types.Object:
    """Build a compact horned goat from closed volumes for deterministic remesh."""
    parts: list[bpy.types.Object] = []

    def sphere(
        part_name: str,
        location: tuple[float, float, float],
        scale: tuple[float, float, float],
        segments: int = 20,
        ring_count: int = 11,
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

    # Lean barrel, high withers, sloped neck, and wedge-shaped face distinguish the
    # goat from the round fleece sheep at normal gameplay distance.
    sphere("GoatBarrel", (0.08, 0.0, 0.61), (0.47, 0.225, 0.255), 26, 14)
    sphere("GoatBelly", (0.08, 0.0, 0.48), (0.37, 0.19, 0.16))
    sphere("GoatShoulder", (-0.30, 0.0, 0.65), (0.24, 0.23, 0.27))
    sphere("GoatRump", (0.39, 0.0, 0.62), (0.24, 0.22, 0.245))
    sphere("GoatWithers", (-0.20, 0.0, 0.80), (0.22, 0.18, 0.12), 18, 10)
    segment("GoatNeck", (-0.29, 0.0, 0.66), (-0.51, 0.0, 0.84), 0.20, 0.135)
    sphere("GoatHead", (-0.58, 0.0, 0.86), (0.18, 0.135, 0.17))
    segment("GoatFace", (-0.59, 0.0, 0.85), (-0.76, 0.0, 0.76), 0.13, 0.085)
    sphere("GoatMuzzle", (-0.78, 0.0, 0.74), (0.105, 0.095, 0.075), 16, 9)
    sphere("GoatJaw", (-0.66, 0.0, 0.72), (0.13, 0.105, 0.075), 16, 9)
    segment("GoatEarLeft", (-0.57, 0.09, 0.94), (-0.52, 0.23, 0.96), 0.055, 0.014, 9)
    segment("GoatEarRight", (-0.57, -0.09, 0.94), (-0.52, -0.23, 0.96), 0.055, 0.014, 9)

    # Two backward-swept, slightly divergent horns and a hanging beard are the
    # strongest species cues. Thick bases keep them connected through voxel remesh.
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        segment(
            f"GoatHorn{side}Base",
            (-0.53, 0.07 * sign, 0.98),
            (-0.45, 0.11 * sign, 1.12),
            0.052,
            0.037,
            12,
        )
        segment(
            f"GoatHorn{side}Mid",
            (-0.45, 0.11 * sign, 1.12),
            (-0.32, 0.14 * sign, 1.18),
            0.038,
            0.023,
            10,
        )
        segment(
            f"GoatHorn{side}Tip",
            (-0.32, 0.14 * sign, 1.18),
            (-0.20, 0.15 * sign, 1.16),
            0.024,
            0.008,
            9,
        )
    segment("GoatBeard", (-0.69, 0.0, 0.70), (-0.65, 0.0, 0.53), 0.050, 0.012, 10)

    # Slender jointed legs finish in paired cloven toes at the ground plane.
    for side, y in (("Left", 0.145), ("Right", -0.145)):
        for end, x, knee_dx in (("Front", -0.29, -0.02), ("Back", 0.36, 0.035)):
            sphere(f"Goat{end}{side}Joint", (x, y, 0.48), (0.085, 0.075, 0.105), 14, 8)
            segment(
                f"Goat{end}{side}UpperLeg",
                (x, y, 0.50),
                (x + knee_dx, y, 0.25),
                0.068,
                0.050,
            )
            segment(
                f"Goat{end}{side}LowerLeg",
                (x + knee_dx, y, 0.26),
                (x - 0.01, y, 0.075),
                0.050,
                0.032,
            )
            sphere(
                f"Goat{end}{side}HoofOuter",
                (x - 0.025, y + 0.017, 0.030),
                (0.060, 0.027, 0.030),
                12,
                8,
            )
            sphere(
                f"Goat{end}{side}HoofInner",
                (x - 0.025, y - 0.017, 0.030),
                (0.060, 0.027, 0.030),
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
    obj["horn_count"] = 2
    obj["cloven_hoof_toes"] = 8
    obj["beard"] = True
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


def _loft_frame(tangent: Vector) -> tuple[Vector, Vector]:
    tangent = tangent.normalized()
    reference = Vector((0.0, 0.0, 1.0))
    if abs(tangent.dot(reference)) > 0.82:
        reference = Vector((0.0, 1.0, 0.0))
    side = tangent.cross(reference).normalized()
    up = side.cross(tangent).normalized()
    return side, up


def _append_loft(
    bm: bmesh.types.BMesh,
    stations: list[tuple[Vector, float, float]],
    sides: int,
) -> None:
    """Bridge elliptical rings into one closed solid. Voxel remesh unions overlaps."""
    rings: list[list] = []
    count = len(stations)
    for index, (center, radius_a, radius_b) in enumerate(stations):
        if index == 0:
            tangent = stations[1][0] - center
        elif index == count - 1:
            tangent = center - stations[index - 1][0]
        else:
            tangent = stations[index + 1][0] - stations[index - 1][0]
        if tangent.length < 1e-8:
            tangent = Vector((1.0, 0.0, 0.0))
        side, up = _loft_frame(tangent)
        ring = []
        for step in range(sides):
            angle = (step / sides) * math.tau
            ring.append(
                bm.verts.new(
                    center
                    + side * (math.cos(angle) * radius_a)
                    + up * (math.sin(angle) * radius_b)
                )
            )
        rings.append(ring)
    for ring_index in range(count - 1):
        current = rings[ring_index]
        nxt = rings[ring_index + 1]
        for step in range(sides):
            following = (step + 1) % sides
            bm.faces.new((current[step], current[following], nxt[following], nxt[step]))
    bm.faces.new(tuple(rings[0]))
    bm.faces.new(tuple(reversed(rings[-1])))


def _horse_leg_stations(
    x: float,
    y: float,
    profile: tuple[tuple[float, float, float], ...],
) -> list[tuple[Vector, float, float]]:
    stations = [
        (Vector((x + shift_x, y, z)), radius, radius) for z, radius, shift_x in profile
    ]
    # The last ring is the hoof: longer in the direction of travel than it is wide.
    center, radius_a, radius_b = stations[-1]
    stations[-1] = (center, radius_a * 1.35, radius_b * 1.08)
    return stations


def refine_horse_surface(obj: bpy.types.Object) -> None:
    """Push equine landmarks back after voxel smoothing.

    WHY: even a lofted remesh melts the crest, belly tuck, cannons, and hooves
    into one sausage. These displacements are a few centimetres, in the same
    grounded meter space as the pack-horse bones.
    """
    leg_axes = (
        Vector((-0.58, 0.22, 0.0)),
        Vector((-0.58, -0.22, 0.0)),
        Vector((0.64, 0.22, 0.0)),
        Vector((0.64, -0.22, 0.0)),
    )
    for vertex in obj.data.vertices:
        point = vertex.co
        if -0.05 < point.x < 0.38 and point.z < 1.02 and abs(point.y) < 0.24:
            target = 0.86 + 0.10 * abs(point.x - 0.12)
            if point.z < target:
                lift = (target - point.z) * 0.42 * (1.0 - abs(point.y) / 0.24)
                point.z += lift
                point.y *= 0.90
        ear = point.z > 1.48 and point.x < -0.75
        if not ear and -0.92 < point.x < -0.12 and abs(point.y) < 0.09 and point.z > 1.08:
            central = 1.0 - abs(point.y) / 0.09
            point.z += 0.028 * central
            point.y *= 1.0 - 0.08 * central
        if -0.32 < point.x < -0.08 and abs(point.y) < 0.10 and point.z > 1.12:
            point.z += 0.026 * (1.0 - abs(point.y) / 0.10)
        if -1.10 < point.x < -0.82 and abs(point.y) < 0.12 and 1.05 < point.z < 1.30:
            under = max(0.0, (1.28 - point.z) / 0.23)
            point.z -= 0.028 * under * (1.0 - abs(point.y) / 0.12)
        if point.x < -1.02:
            point.x -= 0.02
            point.y *= 0.92
        for sign in (1.0, -1.0):
            eye = Vector((-0.94, 0.135 * sign, 1.36))
            eye_distance = (point - eye).length
            if eye_distance < 0.055:
                point.y -= sign * 0.014 * (1.0 - eye_distance / 0.055)
            nostril = Vector((-1.10, 0.045 * sign, 1.20))
            nostril_distance = (point - nostril).length
            if nostril_distance < 0.04:
                point.x += 0.012 * (1.0 - nostril_distance / 0.04)
        if -0.50 < point.x < -0.22 and 0.85 < point.z < 1.22 and 0.10 < abs(point.y) < 0.32:
            point.y += math.copysign(0.016, point.y)
        if 0.32 < point.x < 0.72 and 0.90 < point.z < 1.28 and abs(point.y) > 0.08:
            point.y += math.copysign(0.018, point.y)
        nearest = min(leg_axes, key=lambda axis: math.hypot(point.x - axis.x, point.y - axis.y))
        radial = math.hypot(point.x - nearest.x, point.y - nearest.y)
        if radial < 0.15 and radial > 1e-5:
            scale = 1.0
            if 0.20 < point.z < 0.46:
                scale = 0.90
            elif 0.50 < point.z < 0.66:
                scale = 1.12
            elif 0.10 < point.z < 0.18:
                scale = 1.16
            elif point.z < 0.09:
                scale = 1.20
            if scale != 1.0:
                point.x = nearest.x + (point.x - nearest.x) * scale
                point.y = nearest.y + (point.y - nearest.y) * scale
            if point.z < 0.09:
                forward = (0.09 - point.z) / 0.09
                point.x += (-0.016 if nearest.x < 0.0 else 0.014) * forward
    min_z = min(vertex.co.z for vertex in obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co.z -= min_z
        if vertex.co.z < 0.0:
            vertex.co.z = 0.0
    obj.data.update()


def create_pack_horse_mesh() -> bpy.types.Object:
    """Loft a draft horse, then let voxel remesh fuse the overlapping sections.

    WHY: separate metaballs stayed a string of balls. Closed sections in the
    rig's meter space (eyes near (-0.94, ±0.14, 1.38), legs on the bones) remesh
    into one hide when they overlap.
    """
    parts: list[bpy.types.Object] = []

    def loft(
        part_name: str,
        stations: list[tuple[Vector, float, float]],
        sides: int = 16,
        stiffness: float = 1.45,
    ) -> None:
        del stiffness
        mesh = bpy.data.meshes.new(part_name)
        bm = bmesh.new()
        _append_loft(bm, stations, sides)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        part = bpy.data.objects.new(part_name, mesh)
        bpy.context.collection.objects.link(part)
        parts.append(part)

    # (center, half-width, half-height). Nose is -X so normalization cannot
    # swap the skull onto the dock.
    loft(
        "HorseBody",
        [
            (Vector((-1.14, 0.0, 1.20)), 0.036, 0.032),
            (Vector((-1.06, 0.0, 1.22)), 0.066, 0.058),
            (Vector((-1.00, 0.0, 1.26)), 0.084, 0.092),
            (Vector((-0.94, 0.0, 1.32)), 0.150, 0.130),
            (Vector((-0.86, 0.0, 1.40)), 0.124, 0.114),
            (Vector((-0.78, 0.0, 1.34)), 0.130, 0.155),
            (Vector((-0.64, 0.0, 1.24)), 0.240, 0.190),
            (Vector((-0.50, 0.0, 1.14)), 0.280, 0.220),
            (Vector((-0.34, 0.0, 1.04)), 0.250, 0.245),
            (Vector((-0.16, 0.0, 0.98)), 0.300, 0.275),
            (Vector((0.04, 0.0, 0.97)), 0.280, 0.255),
            (Vector((0.24, 0.0, 1.02)), 0.230, 0.210),
            (Vector((0.44, 0.0, 1.05)), 0.300, 0.260),
            (Vector((0.64, 0.0, 1.07)), 0.300, 0.220),
            (Vector((0.84, 0.0, 1.08)), 0.100, 0.105),
            (Vector((1.14, 0.0, 1.06)), 0.030, 0.032),
        ],
        18,
    )
    loft(
        "HorseJaw",
        [
            (Vector((-1.08, 0.0, 1.14)), 0.050, 0.040),
            (Vector((-0.98, 0.0, 1.16)), 0.088, 0.070),
            (Vector((-0.86, 0.0, 1.20)), 0.072, 0.058),
        ],
        12,
    )
    for side, y_sign in (("Left", 1.0), ("Right", -1.0)):
        loft(
            f"HorseEar{side}",
            [
                (Vector((-0.86, 0.06 * y_sign, 1.42)), 0.048, 0.055),
                (Vector((-0.84, 0.07 * y_sign, 1.54)), 0.036, 0.042),
                (Vector((-0.82, 0.08 * y_sign, 1.64)), 0.022, 0.026),
            ],
            8,
        )
        loft(
            f"HorseFront{side}",
            _horse_leg_stations(
                -0.58,
                0.22 * y_sign,
                (
                    (1.18, 0.11, 0.0),
                    (1.00, 0.09, 0.0),
                    (0.96, 0.095, 0.0),
                    (0.78, 0.072, 0.0),
                    (0.62, 0.086, 0.0),
                    (0.46, 0.050, 0.0),
                    (0.30, 0.044, 0.0),
                    (0.16, 0.060, 0.0),
                    (0.045, 0.070, -0.02),
                ),
            ),
            12,
        )
        loft(
            f"HorseHind{side}",
            _horse_leg_stations(
                0.64,
                0.22 * y_sign,
                (
                    (1.18, 0.12, 0.0),
                    (1.00, 0.10, 0.0),
                    (0.98, 0.105, 0.02),
                    (0.80, 0.078, 0.02),
                    (0.62, 0.092, 0.045),
                    (0.46, 0.050, 0.02),
                    (0.30, 0.044, 0.0),
                    (0.16, 0.058, 0.01),
                    (0.045, 0.068, 0.025),
                ),
            ),
            12,
        )

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "AnimalMesh"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    obj["procedural_anatomy"] = True
    return obj


def create_brown_bear_mesh() -> bpy.types.Object:
    """Build a heavy Eurasian brown bear from closed anatomical volumes.

    WHY: the catalog primitive is a loaf with a tube snout. Witcher-scale
    readability comes from a scapular hump, dish-faced short muzzle, thick
    ruff, plantigrade paws, and overlapping fur hulls that remesh into one coat.
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

    # A long rectangular barrel, not a sheep loaf. Front mass sits lower than
    # the scapular peak so the silhouette rises into a Witcher-style hump.
    sphere("BearBarrel", (0.18, 0.0, 0.64), (0.78, 0.40, 0.30), 28, 16)
    sphere("BearLoin", (0.08, 0.0, 0.70), (0.42, 0.36, 0.22), 22, 12)
    sphere("BearBelly", (0.12, 0.0, 0.44), (0.62, 0.38, 0.20), 24, 14)
    sphere("BearShoulders", (-0.48, 0.0, 0.78), (0.40, 0.48, 0.36), 24, 14)
    # Tall, narrow scapular peak. Soft remesh melted the first 12 cm bump.
    sphere("BearHump", (-0.36, 0.0, 1.34), (0.20, 0.16, 0.34), 20, 12)
    sphere("BearHumpFront", (-0.50, 0.0, 1.16), (0.18, 0.18, 0.22), 18, 10)
    sphere("BearHumpRidge", (-0.16, 0.0, 1.12), (0.26, 0.15, 0.18), 18, 10)
    sphere("BearFurCape", (-0.28, 0.0, 1.00), (0.36, 0.34, 0.16), 20, 11)
    sphere("BearRump", (0.68, 0.0, 0.74), (0.36, 0.40, 0.32), 22, 12)
    sphere("BearHaunchLeft", (0.62, 0.26, 0.62), (0.22, 0.18, 0.24), 16, 10)
    sphere("BearHaunchRight", (0.62, -0.26, 0.62), (0.22, 0.18, 0.24), 16, 10)
    sphere("BearFlankLeft", (0.10, 0.40, 0.60), (0.46, 0.12, 0.20), 16, 10)
    sphere("BearFlankRight", (0.10, -0.40, 0.60), (0.46, 0.12, 0.20), 16, 10)
    for index, (x, z, radius) in enumerate((
        (-0.42, 0.96, 0.16),
        (-0.22, 0.90, 0.15),
        (-0.04, 0.86, 0.14),
        (0.16, 0.82, 0.13),
        (-0.56, 0.78, 0.15),
        (0.40, 0.78, 0.13),
    )):
        sphere(f"BearGuardLock{index}", (x, 0.0, z), (radius, radius * 0.72, radius * 0.55), 14, 8)

    # A neck almost as thick as the skull, with a hanging winter ruff.
    segment("BearNeck", (-0.52, 0.0, 0.82), (-0.92, 0.0, 0.86), 0.38, 0.32)
    sphere("BearRuff", (-0.70, 0.0, 0.70), (0.32, 0.40, 0.32), 20, 12)
    sphere("BearThroatFur", (-0.78, 0.0, 0.52), (0.24, 0.24, 0.20), 16, 10)
    sphere("BearChestBlaze", (-0.54, 0.0, 0.50), (0.22, 0.26, 0.16), 16, 10)

    # Large wide skull, short boxy muzzle, ears on the sides not the crown.
    sphere("BearSkull", (-1.02, 0.0, 0.90), (0.28, 0.26, 0.24), 22, 12)
    sphere("BearForehead", (-1.10, 0.0, 0.96), (0.16, 0.20, 0.12), 18, 10)
    sphere("BearCheekLeft", (-1.04, 0.18, 0.82), (0.16, 0.12, 0.16), 16, 9)
    sphere("BearCheekRight", (-1.04, -0.18, 0.82), (0.16, 0.12, 0.16), 16, 9)
    sphere("BearMuzzle", (-1.26, 0.0, 0.76), (0.16, 0.15, 0.11), 20, 11)
    sphere("BearNose", (-1.38, 0.0, 0.74), (0.07, 0.08, 0.06), 14, 8)
    sphere("BearJaw", (-1.12, 0.0, 0.68), (0.18, 0.14, 0.10), 16, 9)
    sphere("BearEarLeft", (-0.96, 0.24, 1.02), (0.05, 0.09, 0.08), 12, 8)
    sphere("BearEarRight", (-0.96, -0.24, 1.02), (0.05, 0.09, 0.08), 12, 8)
    segment("BearTailDock", (0.98, 0.0, 0.70), (1.10, 0.0, 0.58), 0.07, 0.035, 10)

    # Forelegs stay thicker than the hinds. Plantigrade pads sit ahead of the
    # cannon so the animal walks on its soles, not on hoof-like nubs.
    for side, y in (("Left", 0.24), ("Right", -0.24)):
        for end, x, knee_dx, upper, lower in (
            ("Front", -0.46, -0.02, 0.175, 0.130),
            ("Back", 0.60, 0.03, 0.150, 0.110),
        ):
            sphere(f"Bear{end}{side}Shoulder", (x, y, 0.66), (0.18, 0.16, 0.22), 14, 8)
            segment(
                f"Bear{end}{side}UpperLeg",
                (x, y, 0.68),
                (x + knee_dx, y, 0.34),
                upper,
                lower,
            )
            segment(
                f"Bear{end}{side}LowerLeg",
                (x + knee_dx, y, 0.36),
                (x - 0.04, y, 0.12),
                lower,
                0.095,
            )
            sphere(
                f"Bear{end}{side}Paw",
                (x - 0.10, y, 0.055),
                (0.18, 0.11, 0.055),
                14,
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
    obj["plantigrade_paws"] = True
    obj["scapular_hump"] = True
    return obj


def create_elk_mesh() -> bpy.types.Object:
    """Build a Eurasian elk (Alces alces) from closed anatomical volumes.

    WHY: the catalog primitive is a loaf with two cone posts. Witcher-scale
    readability comes from long legs, a scapular hump, a hanging roman muzzle,
    a throat bell, and palmate antlers thick enough to survive voxel remesh.
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

    # Slim high barrel on long cannons. Antlers stay off this remesh: voxel
    # fusion turned the first palms into withers potatoes.
    sphere("ElkBarrel", (0.12, 0.0, 1.28), (0.62, 0.28, 0.26), 28, 16)
    sphere("ElkLoin", (0.08, 0.0, 1.36), (0.40, 0.22, 0.16), 20, 12)
    sphere("ElkBelly", (0.14, 0.0, 1.02), (0.48, 0.24, 0.18), 22, 12)
    sphere("ElkShoulders", (-0.40, 0.0, 1.38), (0.32, 0.32, 0.30), 22, 12)
    sphere("ElkHump", (-0.32, 0.0, 1.62), (0.22, 0.16, 0.18), 20, 11)
    sphere("ElkBrisket", (-0.50, 0.0, 1.10), (0.20, 0.24, 0.20), 18, 10)
    sphere("ElkRump", (0.62, 0.0, 1.32), (0.30, 0.28, 0.26), 22, 12)
    sphere("ElkHaunchLeft", (0.56, 0.22, 1.12), (0.16, 0.14, 0.20), 14, 8)
    sphere("ElkHaunchRight", (0.56, -0.22, 1.12), (0.16, 0.14, 0.20), 14, 8)

    # Neck stays clear of the chest so remesh cannot swallow the hanging head.
    segment("ElkNeck", (-0.46, 0.0, 1.36), (-0.92, 0.0, 1.18), 0.22, 0.16)
    sphere("ElkNeckMass", (-0.68, 0.0, 1.24), (0.16, 0.14, 0.14), 16, 9)
    sphere("ElkThroat", (-0.80, 0.0, 1.04), (0.12, 0.10, 0.10), 14, 8)
    sphere("ElkBell", (-0.78, 0.0, 0.86), (0.07, 0.06, 0.14), 14, 8)

    sphere("ElkSkull", (-1.05, 0.0, 1.16), (0.18, 0.16, 0.16), 20, 11)
    sphere("ElkForehead", (-1.14, 0.0, 1.22), (0.12, 0.13, 0.11), 16, 9)
    sphere("ElkCheekLeft", (-1.14, 0.12, 1.08), (0.12, 0.09, 0.11), 14, 8)
    sphere("ElkCheekRight", (-1.14, -0.12, 1.08), (0.12, 0.09, 0.11), 14, 8)
    sphere("ElkMuzzle", (-1.34, 0.0, 0.98), (0.20, 0.11, 0.10), 20, 11)
    sphere("ElkNose", (-1.52, 0.0, 0.92), (0.10, 0.10, 0.08), 16, 9)
    sphere("ElkLip", (-1.58, 0.0, 0.86), (0.07, 0.08, 0.06), 12, 7)
    sphere("ElkJaw", (-1.22, 0.0, 0.92), (0.14, 0.10, 0.08), 14, 8)
    segment("ElkTailDock", (0.88, 0.0, 1.28), (1.00, 0.0, 1.14), 0.06, 0.025, 8)

    # Long thin legs. The first pass used cattle cannons and read as a fat pony.
    for side, y in (("Left", 0.20), ("Right", -0.20)):
        sphere(f"ElkFront{side}Shoulder", (-0.42, y, 1.14), (0.13, 0.11, 0.16), 14, 8)
        sphere(f"ElkBack{side}Hip", (0.56, y, 1.16), (0.15, 0.12, 0.18), 14, 8)
        for end, x, knee_dx in (("Front", -0.42, -0.03), ("Back", 0.56, 0.05)):
            segment(
                f"Elk{end}{side}UpperLeg",
                (x, y, 1.16),
                (x + knee_dx, y, 0.62),
                0.090,
                0.055,
            )
            segment(
                f"Elk{end}{side}LowerLeg",
                (x + knee_dx, y, 0.64),
                (x, y, 0.14),
                0.055,
                0.038,
            )
            segment(
                f"Elk{end}{side}Pastern",
                (x, y, 0.15),
                (x - 0.02, y, 0.05),
                0.038,
                0.030,
                10,
            )
            sphere(
                f"Elk{end}{side}HoofOuter",
                (x - 0.03, y + 0.024, 0.038),
                (0.080, 0.040, 0.038),
                12,
                7,
            )
            sphere(
                f"Elk{end}{side}HoofInner",
                (x - 0.03, y - 0.024, 0.038),
                (0.080, 0.040, 0.038),
                12,
                7,
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
    obj["cloven_hoof_toes"] = 8
    obj["palmate_antlers"] = True
    obj["scapular_hump"] = True
    return obj


def build(name: str, spec: dict) -> dict:
    source: Path | None = spec.get("source")
    if source is not None and not source.exists():
        raise FileNotFoundError(f"Missing approved candidate: {source}")
    clear_scene()
    if name in {"cattle", "goat", "sheep", "pack_horse", "brown_bear", "elk"}:
        mesh_builders = {
            "cattle": create_cattle_mesh,
            "goat": create_goat_mesh,
            "sheep": create_sheep_mesh,
            "pack_horse": create_pack_horse_mesh,
            "brown_bear": create_brown_bear_mesh,
            "elk": create_elk_mesh,
        }
        obj = mesh_builders[name]()
        raw = topology(obj)
        # WHY: without remesh the joined anatomical volumes stay as separate
        # islands. Species-tuned smoothing fuses them into a coherent silhouette
        # while retaining cattle joints or sheep fleece relief. The horse uses
        # fewer smooth passes so the neck crest and cannons are not melted flat.
        horse_surface = name == "pack_horse"
        bear_surface = name == "brown_bear"
        elk_surface = name == "elk"
        rebuild_surface(
            obj,
            spec["voxel_divisor"],
            spec["triangles"],
            smooth_factor=(
                0.28
                if bear_surface
                else (
                    0.48
                    if elk_surface
                    else (
                        0.46
                        if horse_surface
                        else (0.50 if name == "cattle" else (0.58 if name == "goat" else 0.72))
                    )
                )
            ),
            smooth_iterations=(
                3
                if bear_surface
                else (
                    4
                    if elk_surface
                    else (5 if horse_surface else (5 if name == "cattle" else (7 if name == "goat" else 12)))
                )
            ),
        )
        if name == "pack_horse":
            # Voxel remesh keeps the leg-to-chest shelf. One subdivision pass
            # rounds it before the triangle budget is applied again.
            subsurf = obj.modifiers.new("RoundHide", "SUBSURF")
            subsurf.levels = 1
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=subsurf.name)
            current_triangles = topology(obj)["triangles"]
            if current_triangles > spec["triangles"]:
                decimate = obj.modifiers.new("ProductionTriangleBudget", "DECIMATE")
                decimate.ratio = spec["triangles"] / current_triangles
                decimate.use_collapse_triangulate = True
                bpy.ops.object.modifier_apply(modifier=decimate.name)
            bpy.ops.object.shade_smooth()
        if name == "sheep":
            apply_fleece_displacement(obj, strength=0.052)
        if name == "brown_bear":
            apply_bear_fur_displacement(obj, strength=0.072)
        if name == "elk":
            apply_elk_fur_displacement(obj, strength=0.040)
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
        # Drop unfused ear/crest nubs. The hide itself is the large island.
        remove_tiny_islands(obj, 0.012)
    if name == "pig":
        discarded_before = 0
    normalize_dimensions(obj, spec["dimensions_m"])
    if name == "pack_horse":
        # Landmark push runs after metric scale so crest and cannons match the rig.
        refine_horse_surface(obj)
    make_uv(obj)
    profile = SURFACE_PROFILES[name]
    if name in {"cattle", "pack_horse", "brown_bear", "elk"}:
        # Position bake replaces UV noise. create_albedo's sine field is what drew
        # rectangular patches across the cattle hide and the horse coat.
        albedo = bake_livestock_region_albedo(obj, name)
    else:
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
        if name == "pack_horse":
            # The hanging tail is a separate mesh parented to the tail bone. Give it
            # a dark hair material so it does not sample the bay body atlas.
            tail_material = bpy.data.materials.new("pack_horse_tail")
            tail_material.use_nodes = True
            tail_shader = tail_material.node_tree.nodes.get("Principled BSDF")
            tail_shader.inputs["Base Color"].default_value = (0.04, 0.028, 0.022, 1.0)
            tail_shader.inputs["Roughness"].default_value = 0.84
            for detail in details:
                if detail.name.startswith("Tail"):
                    detail.data.materials.clear()
                    detail.data.materials.append(tail_material)
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
