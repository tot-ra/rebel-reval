"""Render three EEVEE plates of the production elk for visual review."""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "assets/animals/medieval/medieval_elk.glb"
OUT = ROOT / "docs/reports/images/elk_realism"
ENGINE = "BLENDER_EEVEE"


def clear() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    world = bpy.data.worlds.new("ElkPreviewWorld")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.42, 0.48, 0.38, 1.0)
        background.inputs["Strength"].default_value = 0.85
    bpy.context.scene.world = world


def import_elk() -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(GLB.resolve()))
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name.startswith("AnimalMesh"))
    return mesh


def frame_camera(camera: bpy.types.Object, target: Vector, offset: Vector) -> None:
    camera.location = target + offset
    direction = target - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_plate(name: str, camera: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = ENGINE
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.filepath = str(OUT / f"{name}.png")
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    clear()
    mesh = import_elk()
    points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
    center = sum(points, Vector()) / len(points)
    center.z = max(point.z for point in points) * 0.45

    key = bpy.data.lights.new("Key", "SUN")
    key.energy = 3.2
    key_obj = bpy.data.objects.new("Key", key)
    key_obj.rotation_euler = (0.85, 0.15, 0.70)
    bpy.context.scene.collection.objects.link(key_obj)

    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 1.1
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.rotation_euler = (1.20, -0.40, -2.20)
    bpy.context.scene.collection.objects.link(fill_obj)

    camera_data = bpy.data.cameras.new("ElkCam")
    camera_data.lens = 50
    camera = bpy.data.objects.new("ElkCam", camera_data)
    bpy.context.scene.collection.objects.link(camera)

    frame_camera(camera, center, Vector((-3.4, -4.2, 1.4)))
    render_plate("elk_three_quarter", camera)
    frame_camera(camera, center, Vector((0.0, -5.6, 1.2)))
    render_plate("elk_side", camera)
    frame_camera(camera, center, Vector((-5.4, 0.0, 1.2)))
    render_plate("elk_front", camera)
    print("ELK_PREVIEW=" + str(OUT))


if __name__ == "__main__":
    main()
