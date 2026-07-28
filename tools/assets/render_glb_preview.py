"""Render compact front/side/three-quarter previews of a GLB for visual QA.

Run from the repository root:
    blender -b --python tools/assets/render_glb_preview.py -- <input.glb> <out_dir> [frame] [animation]

Previews are evidence only; nothing is written into runtime asset paths.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def scene_bounds() -> tuple[Vector, Vector]:
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            low = Vector(map(min, low, world))
            high = Vector(map(max, high, world))
    return low, high


def add_camera(name: str, location: Vector, target: Vector) -> bpy.types.Object:
    camera_data = bpy.data.cameras.new(name)
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new(name, camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    direction = target - location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return camera


def render(view: str, camera: bpy.types.Object, ortho_scale: float, out_dir: Path, frame: int) -> None:
    camera.data.ortho_scale = ortho_scale
    bpy.context.scene.camera = camera
    bpy.context.scene.frame_set(frame)
    bpy.context.scene.render.filepath = str(out_dir / f"preview_{view}_f{frame}.png")
    bpy.ops.render.render(write_still=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :]
    source = Path(args[0]).resolve()
    out_dir = Path(args[1]).resolve()
    frame = int(args[2]) if len(args) > 2 else 1
    animation = args[3] if len(args) > 3 else ""
    out_dir.mkdir(parents=True, exist_ok=True)

    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))

    if animation:
        for obj in bpy.context.scene.objects:
            if obj.type != "ARMATURE" or obj.animation_data is None:
                continue
            for action in bpy.data.actions:
                if action.name.lower().startswith(animation.lower()):
                    obj.animation_data.action = action

    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
    bpy.context.scene.display.shading.light = "STUDIO"
    bpy.context.scene.display.shading.color_type = "TEXTURE"
    bpy.context.scene.render.resolution_x = 640
    bpy.context.scene.render.resolution_y = 480
    bpy.context.scene.render.image_settings.file_format = "PNG"

    low, high = scene_bounds()
    center = (low + high) * 0.5
    size = high - low
    span = max(size.x, size.y, size.z)
    distance = span * 3.0
    ortho_scale = span * 1.25

    views = {
        "front": Vector((center.x + distance, center.y, center.z)),
        "side": Vector((center.x, center.y - distance, center.z)),
        "three_quarter": Vector((center.x + distance * 0.7, center.y - distance * 0.7, center.z + distance * 0.35)),
    }
    for name, location in views.items():
        camera = add_camera(f"Preview_{name}", location, center)
        render(name, camera, ortho_scale, out_dir, frame)

    print(f"PREVIEWS_WRITTEN={out_dir} bounds=({tuple(round(v, 3) for v in low)},{tuple(round(v, 3) for v in high)})")


if __name__ == "__main__":
    main()
