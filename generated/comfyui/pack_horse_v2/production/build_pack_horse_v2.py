"""One-off production rebuild for the clean pack-horse v2 candidate."""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[4]
BASE_SCRIPT = ROOT / "tools/assets/build_medieval_animal_models.py"
CANDIDATE = ROOT / "generated/comfyui/pack_horse_v2/pack_horse_candidate.glb"

module_spec = importlib.util.spec_from_file_location("animal_builder", BASE_SCRIPT)
builder = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(builder)


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    value = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return value * value * (3.0 - 2.0 * value)


def rebuild_surface(obj: bpy.types.Object, divisor: float, target_triangles: int) -> None:
    """Rebuild a watertight surface without repeating the destructive v1 blur."""
    max_dimension = max(obj.dimensions)
    obj.data.remesh_voxel_size = max_dimension / divisor
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.voxel_remesh()
    builder.remove_tiny_islands(obj, 0.002)

    # WHY: the original divisor of 20 erased the eyes, muzzle, ears, joints, and
    # hooves. A light pass at 128 samples preserves the clean candidate anatomy.
    smooth = obj.modifiers.new("OrganicSurfaceCleanup", "SMOOTH")
    smooth.factor = 0.12
    smooth.iterations = 2
    bpy.ops.object.modifier_apply(modifier=smooth.name)

    current_triangles = builder.topology(obj)["triangles"]
    if current_triangles > target_triangles:
        decimate = obj.modifiers.new("ProductionTriangleBudget", "DECIMATE")
        decimate.ratio = target_triangles / current_triangles
        decimate.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def add_coat_tint(obj: bpy.types.Object) -> str:
    """Add anatomical dark-bay markings without flattening them into clay brown."""
    # WHY: the Hunyuan candidate already carries generated color channels. They
    # must not survive beside the authored coat mask because glTF COLOR_n order
    # otherwise changes which tint Godot multiplies into the base color.
    for existing in list(obj.data.color_attributes):
        obj.data.color_attributes.remove(existing)
    attribute = obj.data.color_attributes.new(name="CoatTint", type="BYTE_COLOR", domain="CORNER")
    xs = [vertex.co.x for vertex in obj.data.vertices]
    zs = [vertex.co.z for vertex in obj.data.vertices]
    min_x, max_x = min(xs), max(xs)
    min_z, max_z = min(zs), max(zs)

    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index]
            x = (vertex.co.x - min_x) / max(max_x - min_x, 1e-6)
            z = (vertex.co.z - min_z) / max(max_z - min_z, 1e-6)

            lower_legs = 1.0 - smoothstep(0.20, 0.39, z)
            hooves = 1.0 - smoothstep(0.045, 0.115, z)
            mane = (1.0 - smoothstep(0.40, 0.57, x)) * smoothstep(0.70, 0.88, z)
            tail = smoothstep(0.82, 0.96, x)
            muzzle = (1.0 - smoothstep(0.03, 0.16, x)) * smoothstep(0.48, 0.73, z)
            dark = max(lower_legs * 0.78, hooves * 0.96, mane * 0.88, tail * 0.92, muzzle * 0.55)
            body = (1.0, 0.94, 0.88)
            black = (0.18, 0.16, 0.14)
            color = tuple(body[i] * (1.0 - dark) + black[i] * dark for i in range(3))
            data = attribute.data[loop_index]
            if hasattr(data, "color_srgb"):
                data.color_srgb = (*color, 1.0)
            else:
                data.color = (*color, 1.0)
    obj.data.color_attributes.active_color = attribute
    obj.data.color_attributes.render_color_index = obj.data.color_attributes.find(attribute.name)
    return attribute.name


def assign_material(obj: bpy.types.Object, name: str, image: bpy.types.Image) -> None:
    attribute_name = add_coat_tint(obj)
    material = bpy.data.materials.new(f"medieval_{name}")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    vertex_color = nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = attribute_name
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    links.new(texture.outputs["Color"], multiply.inputs["Color1"])
    links.new(vertex_color.outputs["Color"], multiply.inputs["Color2"])
    links.new(multiply.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.72
    shader.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(material)



def export_pack_horse_glb(
    obj: bpy.types.Object,
    output: Path,
    armature: bpy.types.Object | None = None,
    details: list[bpy.types.Object] | None = None,
) -> None:
    """Export only the authored coat mask as glTF COLOR_0.

    The raw Hunyuan mesh contains generated color channels. Exporting every
    channel makes the runtime tint depend on attribute order, so v2 deliberately
    forces the single active anatomical coat mask.
    """
    if armature is not None:
        raise ValueError("Pack horse v2 is a static prop and must not receive a rig")
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_animations=False,
    )


builder.export_glb = export_pack_horse_glb
builder.rebuild_surface = rebuild_surface
builder.assign_material = assign_material
builder.TEXTURE_SIZE = 1024
spec = dict(builder.SPECS["pack_horse"])
spec.update(
    source=CANDIDATE,
    triangles=12_000,
    voxel_divisor=128.0,
    base_color=(0.20, 0.065, 0.026),
    accent_color=(0.42, 0.19, 0.075),
    seed=208744234,
)
builder.build("pack_horse", spec)
