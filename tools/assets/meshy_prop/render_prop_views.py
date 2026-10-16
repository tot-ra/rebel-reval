"""Render a prop GLB from four sides into one review sheet.

Skill: agents/rebel-art/skills/meshy-prop/SKILL.md. Views, left to right:
front (looking along glTF -Z, i.e. at the side HouseholdLayout turns to the
room), right (+X end), top (glTF -Z is down in the image), three-quarter.
A red stick marks +X and a blue stick glTF +Z (the front) at the origin, so a
raw Meshy scan shows which --yaw normalize_meshy_prop.py needs.

    $B -b --factory-startup --python tools/assets/meshy_prop/render_prop_views.py -- \\
        --glb build/beds_meshy/bed_box_master.glb --out build/beds_meshy/bed_box_master_views.png
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def _args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--px", type=int, default=480)
    return p.parse_args(argv)


def _stick(name: str, end: Vector, colour: tuple[float, float, float, float]) -> None:
    bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=end.length, location=end * 0.5)
    obj = bpy.context.active_object
    obj.rotation_euler = end.to_track_quat("Z", "Y").to_euler()
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = colour
    obj.data.materials.append(mat)


def main() -> None:
    a = _args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.2)
    _stick("plus_x", Vector((radius * 0.8, 0, 0)), (1, 0, 0, 1))
    _stick("front_z", Vector((0, -radius * 0.8, 0)), (0, 0.2, 1, 1))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = a.px
    scene.render.resolution_y = a.px
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = radius * 2.3
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    # (direction from the centre to the camera) per view; Blender -Y = glTF +Z.
    views = [Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((-1, -1, 0.8))]
    tiles = []
    for k, d in enumerate(views):
        d.normalize()
        cam.location = centre + d * radius * 4.0
        if k == 2:
            # Top view: an unrotated camera looks down with Blender +Y (glTF back) up.
            cam.rotation_euler = (0, 0, 0)
        else:
            # Explicit look-at basis keeps world Z up in the image (no roll).
            fwd = -d
            right = fwd.cross(Vector((0, 0, 1))).normalized()
            up = right.cross(fwd)
            cam.rotation_euler = Matrix((right, up, -fwd)).transposed().to_euler()
        tile = out.with_name(f"{out.stem}_{k}.png")
        scene.render.filepath = str(tile)
        bpy.ops.render.render(write_still=True)
        tiles.append(tile)

    sheet = bpy.data.images.new("sheet", a.px * len(tiles), a.px)
    px = [0.0] * (a.px * len(tiles) * a.px * 4)
    for k, tile in enumerate(tiles):
        img = bpy.data.images.load(str(tile))
        data = list(img.pixels)
        for row in range(a.px):
            src = row * a.px * 4
            dst = (row * a.px * len(tiles) + k * a.px) * 4
            px[dst : dst + a.px * 4] = data[src : src + a.px * 4]
        tile.unlink()
    sheet.pixels = px
    sheet.filepath_raw = str(out)
    sheet.file_format = "PNG"
    sheet.save()
    print(f"VIEWS {out} size_blender={[round(v, 3) for v in (hi - lo)]} radius={math.floor(radius * 100) / 100}")


main()
