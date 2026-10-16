"""Turn one belt-gear part into a runtime GLB (task R-2033, docs/SYSTEMS/EQUIPMENT_VARIANTS.md).

Run by build_belt_gear.py with one manifest entry as JSON. Two sources:

- `meshy`: a raw Meshy image-to-3D scan (one textured mesh in a ~1.9 unit box).
  Scaled uniformly so its `size_axis` is `size_m` metres, optionally flattened to
  `depth_max_m` (Meshy guesses depth from a flat photo), decimated to `tris`,
  textures capped at `tex` px with a roughness floor.
- `procedural`: the key bunch and the paternoster, built here from primitives
  (Meshy funds ran out for them; their reference images are in the manifest so a
  scan can replace them file for file).

Runtime frame (scripts/city/belt_gear.gd mounts every part the same way):
glTF +X along the belt (toward the wearer's left on the front), +Y up, +Z out from
the body; the back of the part at z = 0, so it rests on the belt's outer face.
Origin by `origin`: "centre" (x, y bounding-box centre: buckles, mounts) or "top"
(the topmost point lowered by `hang_m`: where a hanging part meets the belt line).

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/equipment/belt_gear/normalize_belt_gear.py -- '<json>'
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[4]
## Leather and silk keep a soft sheen at most; Meshy leaves both glossy.
ROUGH_FLOOR = 0.4


def _spec() -> dict:
    return json.loads(sys.argv[sys.argv.index("--") + 1])


def _co(obj: bpy.types.Object) -> np.ndarray:
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _tris(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _import(src: Path) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(src))
    # Blender's importer can add a phantom Icosphere (art playbook); keep real meshes only.
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


def _scan(spec: dict) -> bpy.types.Object:
    obj = _import(ROOT / spec["raw"])
    co = _co(obj)
    # Blender axes: X along the belt, Z up, -Y toward the viewer (glTF +Z, out from the body).
    axis = {"x": 0, "y": 2}[spec["size_axis"]]
    scale = float(spec["size_m"]) / float(np.ptp(co[:, axis]))
    obj.data.transform(Matrix.Scale(scale, 4))
    depth_max = float(spec.get("depth_max_m", 0.0))
    if depth_max:
        depth = float(np.ptp(_co(obj)[:, 1]))
        if depth > depth_max:
            obj.data.transform(Matrix.Diagonal((1.0, depth_max / depth, 1.0, 1.0)))
    if _tris(obj) > int(spec["tris"]):
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = int(spec["tris"]) / _tris(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    tex = int(spec.get("tex", 512))
    for img in bpy.data.images:
        if img.size[0] > tex:
            img.scale(tex, tex * img.size[1] // img.size[0])
        if img.name == "Image_1" and img.size[0] > 0:
            # glTF metallic-roughness: roughness is G; lift it toward matte.
            px = np.empty(len(img.pixels), dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(-1, 4)
            px[:, 1] = ROUGH_FLOOR + (1.0 - ROUGH_FLOOR) * px[:, 1]
            img.pixels.foreach_set(px.ravel())
            img.update()
    return obj


def _material(name: str, colour: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def _torus(bm: bmesh.types.BMesh, centre: Vector, major: float, minor: float, segments: int = 16,
           sides: int = 6) -> None:
    """Ring in the X-Z plane (Blender: facing -Y, the viewer) at `centre`."""
    rings = []
    for i in range(segments):
        a = i / segments * 2 * math.pi
        radial = Vector((math.cos(a), 0.0, math.sin(a)))
        rings.append([
            bm.verts.new(centre + radial * (major + minor * math.cos(2 * math.pi * j / sides))
                         + Vector((0, minor * math.sin(2 * math.pi * j / sides), 0)))
            for j in range(sides)
        ])
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for j in range(sides):
            bm.faces.new((a[j], b[j], b[(j + 1) % sides], a[(j + 1) % sides]))


def _box(bm: bmesh.types.BMesh, centre: Vector, size: tuple, turn: float = 0.0) -> None:
    m = Matrix.Translation(centre) @ Matrix.Rotation(turn, 4, "Y") @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def _keys(spec: dict) -> bpy.types.Object:
    """Three hand-forged keys on one iron ring, hanging: the housewife's or gatekeeper's bunch.

    Proportions from the reference image (manifest `image`): ring 4 cm, keys 9, 7.5
    and 6 cm with oval bows, round shanks and notched flat bits, fanned slightly."""
    bm = bmesh.new()
    ring_r, wire = 0.019, 0.0024
    _torus(bm, Vector((0, 0, -ring_r)), ring_r, wire, 20, 6)
    bottom = Vector((0, 0, -2 * ring_r))
    for length, fan in ((0.09, -0.22), (0.075, 0.0), (0.06, 0.24)):
        down = Vector((math.sin(fan), 0, -math.cos(fan)))
        side = Vector((math.cos(fan), 0, math.sin(fan)))
        # The bow hangs on the ring's lowest point, the shank below it, the bit at the end.
        bow_r = 0.008
        bow_c = bottom + down * (bow_r - 0.002)
        m = bmesh.new()
        _torus(m, Vector((0, 0, 0)), bow_r, 0.0019, 14, 5)
        bmesh.ops.scale(m, vec=Vector((0.75, 1.0, 1.0)), verts=m.verts)
        bmesh.ops.rotate(m, verts=m.verts, cent=Vector(), matrix=Matrix.Rotation(-fan, 3, "Y"))
        bmesh.ops.translate(m, verts=m.verts, vec=bow_c)
        mesh = bpy.data.meshes.new("tmp")
        m.to_mesh(mesh)
        m.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        shank_len = length - 2 * bow_r
        shank_c = bow_c + down * (bow_r + shank_len / 2)
        _box(bm, shank_c, (0.0042, 0.0042, shank_len), -fan)
        tip = bow_c + down * (bow_r + shank_len)
        # Flat bit off one side of the shank's end, with a notch cut by two teeth.
        _box(bm, tip - down * 0.008 + side * 0.0065, (0.009, 0.0035, 0.011), -fan)
        _box(bm, tip - down * 0.0035 + side * 0.0125, (0.003, 0.0035, 0.004), -fan)
        _box(bm, tip - down * 0.0125 + side * 0.0125, (0.003, 0.0035, 0.004), -fan)
    mesh = bpy.data.meshes.new(spec["id"])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(spec["id"], mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.materials.append(_material("belt_gear_keys_iron", (0.24, 0.23, 0.22), 0.7, 0.62))
    return obj


def _paternoster(spec: dict) -> bpy.types.Object:
    """A string of pale bone beads in a hanging U, knotted at the top, a linen tassel below.

    Thirty 8 mm beads with a 12 mm gaud every tenth (manifest `image`): the U's ends are
    7 cm apart at the knot and it hangs 18 cm. The bead material is pale so the runtime
    can tint it to boxwood, amber or coral (belt_gear.gd); bone stays as built."""
    bm = bmesh.new()
    count, half_w, depth = 30, 0.035, 0.17
    centres = []
    for i in range(count):
        s = (i + 0.5) / count
        # A catenary-like U: the sides fall steeply, the bottom rounds.
        x = -half_w * math.cos(math.pi * s)
        z = -depth * math.sin(math.pi * s) ** 0.8
        centres.append(Vector((x, 0, z)))
    for i, c in enumerate(centres):
        r = 0.006 if i % 10 == 4 else 0.004
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=r, matrix=Matrix.Translation(c))
    beads = bpy.data.meshes.new(spec["id"])
    bm.to_mesh(beads)
    bm.free()
    obj = bpy.data.objects.new(spec["id"], beads)
    bpy.context.scene.collection.objects.link(obj)
    bone = _material("belt_gear_paternoster_beads", (0.80, 0.74, 0.60), 0.0, 0.45)
    obj.data.materials.append(bone)
    # Knot and tassel: undyed linen thread, their own surface (never tinted).
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=0.0035,
                              matrix=Matrix.Translation(Vector((0, 0, 0.0))))
    for c in (centres[0], centres[-1]):
        mid = (c + Vector((0, 0, 0))) * 0.5
        _box(bm, mid, (0.0012, 0.0012, (c - Vector()).length), math.atan2(-c.x, -c.z))
    low = Vector((0, 0, -depth - 0.006))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.0065, radius2=0.0015, depth=0.04,
                          matrix=Matrix.Translation(low - Vector((0, 0, 0.02))))
    thread = bpy.data.meshes.new("thread")
    bm.to_mesh(thread)
    bm.free()
    tassel = bpy.data.objects.new("thread", thread)
    bpy.context.scene.collection.objects.link(tassel)
    tassel.data.materials.append(_material("belt_gear_paternoster_thread", (0.62, 0.56, 0.44), 0.0, 0.9))
    bpy.ops.object.select_all(action="DESELECT")
    tassel.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def _place(obj: bpy.types.Object, spec: dict) -> None:
    """Origin and back face by the runtime frame (module docstring)."""
    co = _co(obj)
    lo, hi = co.min(axis=0), co.max(axis=0)
    x = (lo[0] + hi[0]) * 0.5
    if spec["origin"] == "top":
        z = hi[2] - float(spec.get("hang_m", 0.0))
    else:
        z = (lo[2] + hi[2]) * 0.5
    # Blender +Y is glTF -Z (into the body): the back is the largest Y.
    obj.data.transform(Matrix.Translation((-x, -hi[1], -z)))
    obj.data.update()


def main() -> None:
    spec = _spec()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if spec["source"] == "meshy":
        obj = _scan(spec)
    else:
        obj = {"keys": _keys, "paternoster": _paternoster}[spec["family"]](spec)
    _place(obj, spec)
    obj.name = obj.data.name = Path(spec["out"]).stem
    out = ROOT / spec["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_yup=True,
        export_apply=True,
    )
    co = _co(obj)
    size = co.max(axis=0) - co.min(axis=0)
    print("BELT_GEAR " + json.dumps({
        "id": spec["id"],
        "tris": _tris(obj),
        # Godot (x, y, z) = Blender (x, z, -y).
        "size_xyz_m": [round(float(size[0]), 4), round(float(size[2]), 4), round(float(size[1]), 4)],
    }))


main()
