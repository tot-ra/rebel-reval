"""Turn a raw Meshy image-to-3D GLB into a runtime furniture prop.

Skill: agents/rebel-art/skills/meshy-prop/SKILL.md. Meshy returns one textured
mesh normalised to a ~1.9 unit box, centred on the origin, with 2048 px PBR
maps. A catalog prop needs real size, its feet on the floor, the origin at the
footprint centre, the long side along X and the usable front facing glTF +Z
(Blender -Y), which is what HouseholdLayout's "front": 1 expects.

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/meshy_prop/normalize_meshy_prop.py -- \\
        --in build/beds_meshy/bed_box_master.glb --probe
    $B -b --factory-startup --python tools/assets/meshy_prop/normalize_meshy_prop.py -- \\
        --in build/beds_meshy/bed_box_master.glb \\
        --out assets/props/furniture/beds/bed_box_master/bed_box_master.glb \\
        --size 2.05,1.15,1.30 --yaw 90 --tris 14000 --tex 1024

--size is the target x (length), y (height), z (depth) in metres after --yaw
(degrees about the vertical, applied first). Scale is per axis so a short
Meshy bed can be stretched to sleep two adults; keep the stretch modest
(under ~25 %) or the texture visibly smears.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector


def _args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--out", default="")
    p.add_argument("--probe", action="store_true")
    p.add_argument("--size", default="")
    p.add_argument("--yaw", type=float, default=0.0)
    p.add_argument("--tris", type=int, default=0)
    p.add_argument("--tex", type=int, default=1024)
    p.add_argument("--name", default="")
    return p.parse_args(argv)


def _import(src: str) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    # Blender's importer can fabricate a phantom Icosphere (blender gotchas memory).
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("Icosphere")]
    for o in list(bpy.data.objects):
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def _tris(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _top_height(obj: bpy.types.Object, lo: Vector, hi: Vector) -> float:
    """Highest surface over the middle of the footprint, below a canopy.

    The catalog's lie_h / seat_h: where a sleeper's back or a sitter rests.
    Only vertices in the central quarter of the footprint and under 1.0 m
    count, so a tester canopy or a headboard does not win.
    """
    c = (lo + hi) * 0.5
    ex = (hi - lo) * 0.25
    zs = [
        v.co.z
        for v in obj.data.vertices
        if abs(v.co.x - c.x) < ex.x and abs(v.co.y - c.y) < ex.y and v.co.z < 1.0
    ]
    return round(max(zs), 3) if zs else 0.0


## Meshy bakes studio light into pure-white linen and leaves cloth glossy
## (roughness ~0.6), so lit bedding blows out indoors. Soft-cap the base
## colour above WHITE_KNEE and lift roughness towards matte.
WHITE_KNEE = 0.7
WHITE_SLOPE = 0.45
ROUGH_FLOOR = 0.35


def _tame(img: bpy.types.Image) -> None:
    if img.size[0] == 0 or img.name not in ("Image_0", "Image_1"):
        return
    px = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    if img.name == "Image_0":  # base colour: soft knee on RGB
        rgb = px[:, :3]
        over = rgb > WHITE_KNEE
        rgb[over] = WHITE_KNEE + (rgb[over] - WHITE_KNEE) * WHITE_SLOPE
    else:  # glTF metallic-roughness: roughness is G
        px[:, 1] = ROUGH_FLOOR + (1.0 - ROUGH_FLOOR) * px[:, 1]
    img.pixels.foreach_set(px.ravel())
    img.update()


def _images() -> list[tuple[str, int, int]]:
    return [(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.size[0] > 0]


def main() -> None:
    a = _args()
    obj = _import(a.src)
    lo, hi = _bounds(obj)
    info = {
        "src": a.src,
        "tris": _tris(obj),
        # Blender axes: x right, y back (glTF -Z), z up.
        "blender_size_xyz": [round(v, 3) for v in (hi - lo)],
        "images": _images(),
    }
    if a.probe:
        print("PROBE " + json.dumps(info))
        return
    if a.yaw:
        obj.data.transform(Matrix.Rotation(math.radians(a.yaw), 4, "Z"))
    lo, hi = _bounds(obj)
    centre = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    obj.data.transform(Matrix.Translation(-centre))
    if a.size:
        # Godot (x, y, z) = Blender (x, z, -y): length, height, depth.
        gx, gy, gz = (float(s) for s in a.size.split(","))
        ext = hi - lo
        obj.data.transform(Matrix.Diagonal((gx / ext.x, gz / ext.y, gy / ext.z, 1.0)))
    if a.tris and _tris(obj) > a.tris:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = a.tris / _tris(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for img in bpy.data.images:
        if img.size[0] > a.tex:
            img.scale(a.tex, a.tex * img.size[1] // img.size[0])
        _tame(img)
    obj.data.update()
    obj.name = a.name or Path(a.out).stem
    obj.data.name = obj.name
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_yup=True,
        export_apply=True,
    )
    lo, hi = _bounds(obj)
    info.update(
        out=str(out),
        out_tris=_tris(obj),
        godot_size_xyz=[round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
        out_images=_images(),
        top_h=_top_height(obj, lo, hi),
    )
    print("NORMALIZED " + json.dumps(info))


main()
