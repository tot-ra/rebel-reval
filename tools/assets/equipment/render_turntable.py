"""Turntable review sheet for an equipment GLB: eight yaw views plus the underside.

Pipeline: docs/SYSTEMS/EQUIPMENT_VARIANTS.md (task R-2003). Run through Blender:

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/equipment/render_turntable.py -- \\
        --glb assets/props/weapons/spear/variants/spear_p1_w1.glb \\
        --out docs/reports/images/equipment/spear_p1_w1_turntable.png [--frame-y 1.1,1.45]

Tiles left to right: yaw 0..315 deg in 45 deg steps around Godot +Y (tile 0
looks along glTF -Z at the front), then a view from straight below - a
Meshy wearable comes capped solid underneath, so the underside tile is the
acceptance check for the head cavity. `--frame-y lo,hi` crops to a height band
in Godot metres (e.g. the spearhead) instead of the whole item. EEVEE with a
neutral grey world and a key light, so roughness/metal read as in game, not
Workbench flat colour.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def _args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--tile", default="220x640", help="tile WxH in px")
    p.add_argument("--frame-y", default="", help="lo,hi Godot metres to frame")
    p.add_argument("--samples", type=int, default=32)
    return p.parse_args(argv)


def _look(cam: bpy.types.Object, target: Vector, direction: Vector, dist: float, up: Vector) -> None:
    d = direction.normalized()
    cam.location = target + d * dist
    fwd = -d
    right = fwd.cross(up).normalized()
    true_up = right.cross(fwd)
    cam.rotation_euler = Matrix((right, true_up, -fwd)).transposed().to_euler()


def main() -> None:
    a = _args()
    tw, th = (int(v) for v in a.tile.split("x"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    if a.frame_y:
        zlo, zhi = (float(v) for v in a.frame_y.split(","))
    else:
        zlo, zhi = lo.z, hi.z
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (zlo + zhi) / 2))
    span_h = (zhi - zlo) * 1.08
    span_w = max(hi.x - lo.x, hi.y - lo.y) * 1.25

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = a.samples
    scene.render.resolution_x = tw
    scene.render.resolution_y = th
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    dist = max(span_h, span_w) * 4.0 + 1.0
    cam_data.clip_end = dist * 3.0

    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    tiles: list[np.ndarray] = []
    views = [("yaw", k * 45.0) for k in range(8)] + [("under", 0.0)]
    for kind, yaw in views:
        if kind == "yaw":
            r = math.radians(yaw)
            # Blender -Y is glTF +Z (the item's front); yaw turns the camera about +Z.
            d = Vector((math.sin(r), -math.cos(r), 0.0))
            _look(cam, centre, d, dist, Vector((0, 0, 1)))
            cam_data.ortho_scale = max(span_h, span_w * th / tw)
        else:
            # Straight up from below; for a tall item frame its whole footprint bottom.
            under = Vector((centre.x, centre.y, lo.z))
            _look(cam, under, Vector((0, 0, -1)), dist, Vector((0, 1, 0)))
            cam_data.ortho_scale = max(hi.x - lo.x, hi.y - lo.y) * 1.4 * max(1.0, th / tw)
        tile = out.with_name(f"{out.stem}_{kind}_{int(yaw)}.png")
        scene.render.filepath = str(tile)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(tile))
        px = np.empty(tw * th * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        tiles.append(px.reshape(th, tw, 4))
        bpy.data.images.remove(img)
        tile.unlink()
    sheet = np.concatenate(tiles, axis=1)
    img = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0])
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = str(out)
    img.file_format = "PNG"
    img.save()
    print(f"TURNTABLE {out} {sheet.shape[1]}x{sheet.shape[0]} size_blender={[round(v, 3) for v in (hi - lo)]}")


main()
