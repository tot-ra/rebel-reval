"""Turn a raw Meshy image-to-3D scan into a game-ready equipment variant GLB.

Pipeline and conventions: docs/SYSTEMS/EQUIPMENT_VARIANTS.md (task R-2003).
Run through Blender, never repository python3 (it imports bpy); the host
driver build_equipment.py checks the raw SHA-256 and calls this:

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/equipment/cleanup_equipment.py -- \\
        --manifest tools/assets/equipment/items/spear_p1_w1.json

What it does, in order (each step is driven by the manifest):
1. import the scan, drop Blender's phantom Icosphere, join into one mesh;
2. turn the manifest's `align_axis` (the raw axis pointing at the item's top,
   e.g. the spear point) onto Blender +Z = glTF/Godot +Y, scale uniformly to
   `longest_m` real metres;
3. wearables: boolean-cut the head cavity Meshy caps solid (`cavity`) and give
   the new inner faces a liner material;
4. hafted weapons: build the shaft procedurally (`shaft`) under the scanned
   head, its top radius matched to the scanned socket - Meshy cannot resolve a
   2 m pole 2 cm thick, so only the iron is scanned;
5. tame the scan's PBR (roughness floor: wrought iron, no plate shine), bake
   ambient occlusion and repack occlusion/roughness/metal into one ORM image;
6. put the pivot at the grip (or the wearable's anchor), add socket empties;
7. decimate to the LOD0 budget, cap textures, export GLB; write LOD1 next to
   the build files (Godot also generates import LODs, so LOD1 is a budget check).

Prints one `EQUIPMENT {json}` line with sizes, tris and socket positions.
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

ROOT = Path(__file__).resolve().parents[3]
AXES = {
    "+X": Vector((1, 0, 0)), "-X": Vector((-1, 0, 0)),
    "+Y": Vector((0, 1, 0)), "-Y": Vector((0, -1, 0)),
    "+Z": Vector((0, 0, 1)), "-Z": Vector((0, 0, -1)),
}


def _args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--manifest", required=True)
    return p.parse_args(argv)


def _import(src: Path) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
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


def _co(obj: bpy.types.Object) -> np.ndarray:
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _tris(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _align_and_scale(obj: bpy.types.Object, axis: str, longest_m: float) -> None:
    rot = AXES[axis].rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
    obj.data.transform(rot)
    co = _co(obj)
    lo, hi = co.min(0), co.max(0)
    centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    obj.data.transform(Matrix.Translation(-centre))
    s = longest_m / float((hi - lo).max())
    obj.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
    obj.data.update()


def _image(mat: bpy.types.Material, name: str) -> bpy.types.Image | None:
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None and node.image.name.startswith(name):
            return node.image
    return None


def _pixels(img: bpy.types.Image) -> np.ndarray:
    px = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(img.size[1], img.size[0], 4)


def _cap(img: bpy.types.Image, tex: int) -> None:
    w, h = img.size
    if max(w, h) > tex:
        k = tex / max(w, h)
        img.scale(max(1, round(w * k)), max(1, round(h * k)))


def _gltf_output_group() -> bpy.types.NodeTree:
    """The exporter reads glTF occlusion from a group named 'glTF Material Output'."""
    group = bpy.data.node_groups.get("glTF Material Output")
    if group is None:
        group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return group


def _bake_ao(obj: bpy.types.Object, width: int, height: int) -> np.ndarray:
    """Cycles AO bake on the scan's own UVs; returns a (h, w) 0..1 array."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    img = bpy.data.images.new("ao_bake", width, height, float_buffer=False)
    nodes = []
    for slot in obj.material_slots:
        node = slot.material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        slot.material.node_tree.nodes.active = node
        nodes.append((slot.material, node))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="AO", margin=8)
    ao = _pixels(img)[..., 0].copy()
    for mat, node in nodes:
        mat.node_tree.nodes.remove(node)
    bpy.data.images.remove(img)
    return ao


def _scan_material(obj: bpy.types.Object, spec: dict, tex: int, name: str) -> None:
    """Rebuild the Meshy material as base colour + normal + one ORM image."""
    mat = obj.material_slots[0].material
    base, mr, normal = _image(mat, "Image_0"), _image(mat, "Image_1"), _image(mat, "normal")
    # Colour space first: changing it reloads the image and would undo the downscale.
    for img in (mr, normal):
        if img is not None:
            img.colorspace_settings.name = "Non-Color"
    for img in (base, mr, normal):
        if img is not None:
            _cap(img, tex)
    ao = _bake_ao(obj, *mr.size) if spec.get("ao", True) else None  # same size as the ORM it fills
    mrp = _pixels(mr)
    rough = mrp[..., 1]
    metal = mrp[..., 2]
    # Art bible: wrought iron reads grey-black and matte, never chrome.
    floor = float(spec.get("rough_floor", 0.0))
    rough = floor + (1.0 - floor) * rough
    metal = np.minimum(metal, float(spec.get("metal_cap", 1.0)))
    orm = np.ones_like(mrp)
    orm[..., 0] = 1.0 if ao is None else 0.35 + 0.65 * ao  # keep AO gentle on a scan with baked shading
    orm[..., 1] = rough
    orm[..., 2] = metal
    orm_img = bpy.data.images.new("orm", mr.size[0], mr.size[1])
    orm_img.pixels.foreach_set(orm.ravel())
    orm_img.update()
    # File-backed copy: editing a packed glTF image in place is lost on export (art playbook).
    orm_img.filepath_raw = str(ROOT / "build" / "equipment" / name / "orm.png")  # exporter names the image by file stem
    Path(orm_img.filepath_raw).parent.mkdir(parents=True, exist_ok=True)
    orm_img.file_format = "PNG"
    orm_img.save()

    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    t_base = nt.nodes.new("ShaderNodeTexImage")
    t_base.image = base
    nt.links.new(t_base.outputs["Color"], bsdf.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = orm_img
    t_orm.image.colorspace_settings.name = "Non-Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_orm.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    group = nt.nodes.new("ShaderNodeGroup")
    group.node_tree = _gltf_output_group()
    nt.links.new(sep.outputs["Red"], group.inputs["Occlusion"])
    if normal is not None:
        t_n = nt.nodes.new("ShaderNodeTexImage")
        t_n.image = normal
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t_n.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    mat.name = f"{name}_scan"


def _texture_material(name: str, spec: dict) -> bpy.types.Material:
    """Principled material from tileable albedo/normal/roughness plates (repo paths).

    Tint the plate itself (derive_tileable_pbr.py --tint): the glTF exporter
    drops colour-mix nodes, so a node tint would not reach Godot.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 0.0
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = bpy.data.images.load(str(ROOT / spec["albedo"]))
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    if spec.get("roughness"):
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = bpy.data.images.load(str(ROOT / spec["roughness"]))
        r.image.colorspace_settings.name = "Non-Color"
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    if spec.get("normal"):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(str(ROOT / spec["normal"]))
        n.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _socket_radius(obj: bpy.types.Object, band_m: float) -> float:
    """Mean radius of the scan's lowest `band_m` (the open socket mouth)."""
    co = _co(obj)
    low = co[co[:, 2] < co[:, 2].min() + band_m]
    return float(np.hypot(low[:, 0] - low[:, 0].mean(), low[:, 1] - low[:, 1].mean()).max())


def _build_shaft(head: bpy.types.Object, spec: dict, name: str) -> tuple[bpy.types.Object, float]:
    """Tapered round pole below the head; returns (shaft, head lift above the butt)."""
    insert = float(spec["insert_m"])
    top_r = _socket_radius(head, 0.01) * float(spec.get("socket_fill", 0.92))
    butt_r = float(spec["butt_radius_m"])
    length = float(spec["length_m"])
    seg = int(spec.get("segments", 12))
    rings = int(spec.get("rings", 6))
    uv_repeat = float(spec.get("uv_repeat_m", 0.5))
    verts, faces, uvs = [], [], []
    for r in range(rings + 1):
        t = r / rings
        z = t * length
        # Thickest a third of the way up, where the hands work; tapers to the socket.
        swell = 1.0 + 0.06 * math.sin(min(t / 0.66, 1.0) * math.pi)
        base = butt_r if t <= 0.33 else butt_r + (top_r - butt_r) * (t - 0.33) / 0.67
        radius = base * swell
        for s in range(seg):
            a = s / seg * math.tau
            verts.append((radius * math.cos(a), radius * math.sin(a), z))
    for r in range(rings):
        for s in range(seg):
            a, b = r * seg + s, r * seg + (s + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    butt = len(verts)
    verts.append((0.0, 0.0, -butt_r * 0.35))  # rounded butt end
    for s in range(seg):
        faces.append((butt, (s + 1) % seg, s))
    mesh = bpy.data.meshes.new(f"{name}_shaft")
    mesh.from_pydata(verts, [], faces)
    uv = mesh.uv_layers.new(name="UVMap")
    # Grain runs along the shaft: U wraps the circumference once, V follows height.
    for poly in mesh.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            x, y, z = verts[vi]
            u = (math.atan2(y, x) / math.tau) % 1.0
            if poly.loop_total == 4:
                # Seam: the last column wraps to u=1, not back to 0.
                cols = [(math.atan2(verts[v][1], verts[v][0]) / math.tau) % 1.0 for v in poly.vertices]
                if max(cols) - min(cols) > 0.5 and u < 0.5:
                    u += 1.0
            uv.data[li].uv = (u, z / uv_repeat)
    mesh.update()
    shaft = bpy.data.objects.new(f"{name}_shaft", mesh)
    bpy.context.scene.collection.objects.link(shaft)
    bpy.ops.object.select_all(action="DESELECT")
    shaft.select_set(True)
    bpy.context.view_layer.objects.active = shaft
    bpy.ops.object.shade_smooth()
    shaft.data.materials.append(_texture_material(f"{name}_shaft", spec))
    lift = length - insert
    head.data.transform(Matrix.Translation((0, 0, lift)))
    head.data.update()
    return shaft, lift


def _cut_cavity(obj: bpy.types.Object, spec: dict, name: str) -> None:
    """Boolean the head volume out of a wearable Meshy capped solid; inner faces get a liner."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=spec["centre"])
    cutter = bpy.context.active_object
    cutter.scale = spec["radii"]
    liner = bpy.data.materials.new(f"{name}_liner")
    liner.use_nodes = True
    bsdf = liner.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*spec.get("liner_rgb", (0.22, 0.15, 0.09)), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    cutter.data.materials.append(liner)
    mod = obj.modifiers.new("cavity", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    mod.material_mode = "TRANSFER"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def _decimate(obj: bpy.types.Object, budget: int) -> None:
    if budget and _tris(obj) > budget:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = budget / _tris(obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)


def _export(path: Path, objects: list[bpy.types.Object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_yup=True,
        export_apply=True,
    )


def main() -> None:
    m = json.loads(Path(_args().manifest).read_text())
    name = m["variant"]
    head = _import(ROOT / m["raw"])
    scan = m["scan"]
    _align_and_scale(head, scan["align_axis"], float(scan["longest_m"]))
    if m.get("cavity"):
        _cut_cavity(head, m["cavity"], name)
    _scan_material(head, scan, int(m.get("tex", 1024)), name)
    parts = [head]
    lift = 0.0
    if m.get("shaft"):
        shaft, lift = _build_shaft(head, m["shaft"], name)
        parts.append(shaft)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = name
    top = float(_co(obj)[:, 2].max())
    bottom = float(_co(obj)[:, 2].min())
    pivot = float(m.get("pivot_from_base_m", 0.0))
    obj.data.transform(Matrix.Translation((0, 0, -pivot)))
    obj.data.update()
    # Sockets in Godot metres relative to the pivot (Godot x, y, z = Blender x, z, -y).
    sockets = dict(m.get("sockets", {}))
    if m.get("shaft"):
        sockets.setdefault("socket_grip", [0.0, 0.0, 0.0])
        sockets.setdefault("socket_butt", [0.0, round(bottom - pivot, 3), 0.0])
        sockets.setdefault("socket_tip", [0.0, round(top - pivot, 3), 0.0])
    empties = []
    for sname, (gx, gy, gz) in sorted(sockets.items()):
        e = bpy.data.objects.new(sname, None)
        e.location = (gx, -gz, gy)
        bpy.context.scene.collection.objects.link(e)
        empties.append(e)
    _decimate(obj, int(m.get("tris", 0)))
    out = ROOT / m["out"]
    _export(out, [obj, *empties])
    lod0 = _tris(obj)
    lod1 = 0
    if m.get("lod1_tris"):
        _decimate(obj, int(m["lod1_tris"]))
        lod1 = _tris(obj)
        _export(ROOT / "build" / "equipment" / f"{name}_lod1.glb", [obj, *empties])
    co = _co(obj)
    lo, hi = co.min(0), co.max(0)
    print("EQUIPMENT " + json.dumps({
        "variant": name,
        "out": m["out"],
        "lod0_tris": lod0,
        "lod1_tris": lod1,
        "godot_size_xyz": [round(float(hi[0] - lo[0]), 3), round(float(hi[2] - lo[2]), 3), round(float(hi[1] - lo[1]), 3)],
        "head_lift_m": round(lift, 3),
        "sockets": sockets,
        "images": [(i.name, i.size[0]) for i in bpy.data.images if i.size[0] > 0 and i.users],
    }))


main()
