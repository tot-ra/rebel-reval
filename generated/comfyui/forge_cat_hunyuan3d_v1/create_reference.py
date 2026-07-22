"""Create one clean forge-cat source image for single-image Hunyuan3D.

This is a staging/reference generator only. It intentionally does not export or
install its procedural geometry as a game asset: Hunyuan3D must generate the
candidate mesh that will be reviewed before any production work begins.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT_DIR = Path(__file__).resolve().parent
REFERENCE_PATH = OUTPUT_DIR / "forge_cat_reference.png"
BLEND_PATH = OUTPUT_DIR / "forge_cat_reference_source.blend"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.curves, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        # Orphaned blocks from the default scene make reruns harder to inspect.
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.7) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    return mat


def add_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_ear(
    name: str,
    location: tuple[float, float, float],
    rotation: tuple[float, float, float],
    mat: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=3,
        radius1=0.31,
        radius2=0.035,
        depth=0.62,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = (0.72, 0.86, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Soft ear edges", "BEVEL")
    bevel.width = 0.045
    bevel.segments = 3
    obj.data.materials.append(mat)
    return obj


def add_tail(mat: bpy.types.Material) -> bpy.types.Object:
    curve = bpy.data.curves.new("TailCurve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = 0.135
    curve.bevel_resolution = 5
    curve.resolution_u = 12

    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(4)
    points = (
        (1.16, 0.27, 1.83),
        (1.72, 0.34, 1.74),
        (2.18, 0.42, 1.88),
        (2.56, 0.43, 2.18),
        (2.64, 0.39, 2.55),
    )
    for bezier_point, coordinate in zip(spline.bezier_points, points):
        bezier_point.co = coordinate
        bezier_point.handle_left_type = "AUTO"
        bezier_point.handle_right_type = "AUTO"

    obj = bpy.data.objects.new("Tail", curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    add_sphere("TailTip", points[-1], (0.14, 0.14, 0.17), mat)
    return obj


def add_area_light(name: str, location: tuple[float, float, float], energy: float, size: float) -> None:
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    point_at(obj, Vector((0.0, 0.0, 1.45)))


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def build_cat() -> None:
    fur = material("Charcoal warm fur", (0.145, 0.115, 0.09, 1.0), roughness=0.82)
    muzzle = material("Muzzle", (0.25, 0.20, 0.16, 1.0), roughness=0.88)
    eye = material("Muted amber eyes", (0.42, 0.20, 0.055, 1.0), roughness=0.42)
    nose = material("Nose", (0.055, 0.033, 0.03, 1.0), roughness=0.72)

    # Broad, compact proportions suit a working smithy cat and remain readable
    # after voxel-based image-to-3D generation.
    add_sphere("Torso", (0.0, 0.0, 1.57), (1.28, 0.57, 0.60), fur, rotation=(0.0, -0.03, 0.0))
    add_sphere("Chest", (-0.88, -0.01, 1.62), (0.56, 0.54, 0.67), fur)
    add_sphere("Neck", (-1.05, -0.01, 1.93), (0.47, 0.44, 0.52), fur)
    add_sphere("Head", (-1.39, -0.02, 2.28), (0.57, 0.49, 0.52), fur)

    add_ear("NearEar", (-1.42, -0.30, 2.77), (0.02, -0.07, -0.05), fur)
    add_ear("FarEar", (-1.35, 0.30, 2.76), (-0.02, -0.03, 0.06), fur)

    # The staggered x positions keep all four limbs separately visible from the
    # front three-quarter camera instead of letting far limbs hide behind near ones.
    legs = (
        ("NearFront", (-0.92, -0.39, 0.78), (0.215, 0.205, 0.66), (-0.06, 0.0, 0.0)),
        ("FarFront", (-0.62, 0.39, 0.80), (0.205, 0.195, 0.65), (0.04, 0.0, 0.0)),
        ("NearRear", (0.80, -0.40, 0.77), (0.235, 0.215, 0.67), (0.045, 0.0, 0.0)),
        ("FarRear", (0.57, 0.40, 0.79), (0.22, 0.205, 0.65), (-0.035, 0.0, 0.0)),
    )
    for name, location, scale, rotation in legs:
        add_sphere(f"{name}Leg", location, scale, fur, rotation=rotation)
        add_sphere(f"{name}Paw", (location[0] - 0.055, location[1] - 0.02, 0.18), (0.29, 0.245, 0.16), fur)

    add_tail(fur)

    # Small, surface-attached facial forms improve feline readability without
    # thin whiskers or other details that could become floating geometry.
    add_sphere("NearMuzzle", (-1.82, -0.15, 2.13), (0.25, 0.22, 0.19), muzzle)
    add_sphere("FarMuzzle", (-1.80, 0.13, 2.13), (0.23, 0.20, 0.18), muzzle)
    add_sphere("Nose", (-1.995, -0.035, 2.20), (0.10, 0.10, 0.085), nose)
    add_sphere("NearEye", (-1.79, -0.285, 2.42), (0.085, 0.047, 0.09), eye, rotation=(0.0, 0.18, 0.0))
    add_sphere("FarEye", (-1.77, 0.245, 2.42), (0.078, 0.044, 0.085), eye, rotation=(0.0, 0.18, 0.0))


def configure_scene() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.render.filepath = str(REFERENCE_PATH)

    scene.world.color = (0.72, 0.72, 0.72)
    world_nodes = scene.world.node_tree.nodes if scene.world and scene.world.use_nodes else None
    if scene.world:
        scene.world.use_nodes = True
        world_nodes = scene.world.node_tree.nodes
        background = world_nodes.get("Background")
        background.inputs["Color"].default_value = (0.72, 0.72, 0.72, 1.0)
        background.inputs["Strength"].default_value = 0.7

    scene.view_settings.look = "AgX - Medium High Contrast"

    camera_data = bpy.data.cameras.new("ReferenceCamera")
    camera = bpy.data.objects.new("ReferenceCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (-6.5, -9.0, 4.0)
    point_at(camera, Vector((0.18, 0.0, 1.50)))
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 5.55
    camera_data.lens = 58
    scene.camera = camera

    add_area_light("Key", (-4.5, -5.5, 7.5), 1050.0, 5.0)
    add_area_light("Fill", (3.5, -3.0, 4.5), 720.0, 4.5)
    add_area_light("Rim", (2.0, 4.5, 6.0), 900.0, 3.5)


def main() -> None:
    clear_scene()
    build_cat()
    configure_scene()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)
    print(f"REFERENCE={REFERENCE_PATH}")
    print(f"SOURCE={BLEND_PATH}")


if __name__ == "__main__":
    main()
