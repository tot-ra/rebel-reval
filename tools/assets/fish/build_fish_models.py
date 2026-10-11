"""Build the herring and perch glTF models from prepare_fish_textures.py output.

Stage 2 of the fish model pipeline. Run through Blender, not host python3:

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
        --python tools/assets/fish/build_fish_models.py

Each model (<species>.gltf + .bin, texture by URI) is one mesh, one material, in the CityFish mesh-space contract
(Godot axes: +X forward, nose at x 0.5, tail tip no further back than x -0.78,
every vertex inside y -0.24..0.29 and z +-0.24):

- a lofted body following the fin-free outline from the profile, with a
  laterally compressed teardrop section (herring keeled, perch rounder);
- a flat midplane fin card (z = 0) covering the silhouette cells, so the
  painted caudal, dorsal, anal and pelvic fins show their exact outline through
  alpha clipping; inside the body it is hidden.

UV0 projects the side illustration onto both flanks (the drawing is a lateral
view, so a side projection is exact on the silhouette). UV1.y is the part id
the runtime shader reads: 0 body, 1 fin (fins get backlight and no metal).
Blender is Z-up; the glTF exporter maps Blender (x, y, z) to Godot (x, z, -y),
so the build works in Blender coords with height on Z and thickness on Y.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[3]
PROFILES = ROOT / "build/fish"
OUT = ROOT / "assets/animals/fish"
RING_SIDES = 20
BODY_RINGS = 40
# Half-thickness as a share of half-depth, and how much the belly narrows.
SECTION = {"herring": (0.42, 0.45), "perch": (0.4, 0.15)}


def _uv(rect: list[float], x: float, y: float) -> tuple[float, float]:
    left, top, right, bottom = rect
    # Blender UV v runs up; the exporter flips it back to glTF's top-left origin.
    return (x - left) / (right - left), 1.0 - (top - y) / (top - bottom)


def _resample(body: list[list[float]], count: int) -> list[tuple[float, float, float]]:
    # Rings denser at the head, where the outline curves fastest.
    xs = [b[0] for b in body]
    out = []
    for k in range(count):
        t = (k / (count - 1)) ** 1.25
        x = xs[-1] + (xs[0] - xs[-1]) * t
        i = max(j for j in range(len(xs)) if xs[j] <= x) if x > xs[0] else 0
        i = min(i, len(xs) - 2)
        f = (x - xs[i]) / max(xs[i + 1] - xs[i], 1e-9)
        top = body[i][1] + (body[i + 1][1] - body[i][1]) * f
        bottom = body[i][2] + (body[i + 1][2] - body[i][2]) * f
        out.append((x, top, bottom))
    return out


def build(species: str) -> Path:
    profile = json.loads((PROFILES / f"{species}_profile.json").read_text())
    rect = profile["uv_rect"]
    thick, keel = SECTION[species]
    bm = bmesh.new()
    uv0 = bm.loops.layers.uv.new("UVMap")
    uv1 = bm.loops.layers.uv.new("Part")

    rings = []
    samples = _resample(profile["body"], BODY_RINGS)
    for i, (x, top, bottom) in enumerate(samples):
        half = 0.5 * (top - bottom)
        mid = 0.5 * (top + bottom)
        # Snout ring collapses to a point; the caudal-stalk ring stays open
        # (the fin card continues through it).
        if i == 0:
            half *= 0.0
        ring = []
        for j in range(RING_SIDES):
            a = 2.0 * math.pi * j / RING_SIDES
            up = math.sin(a)
            width = half * thick * math.cos(a)
            width *= 1.0 - 0.25 * max(up, 0.0)
            width *= 1.0 - keel * max(-up, 0.0) ** 2
            ring.append(bm.verts.new((x, width, mid + up * half)))
        rings.append(ring)

    def face(verts, part: float) -> None:
        f = bm.faces.new(verts)
        for loop in f.loops:
            co = loop.vert.co
            loop[uv0].uv = _uv(rect, co.x, co.z)
            loop[uv1].uv = (0.0, part)

    for i in range(len(rings) - 1):
        for j in range(RING_SIDES):
            k = (j + 1) % RING_SIDES
            a, b = rings[i], rings[i + 1]
            if i == 0:
                face([a[j], b[k], b[j]], 0.0)
            else:
                face([a[j], a[k], b[k], b[j]], 0.0)
    # Fin card: one quad per silhouette cell, double-sided in the shader.
    fin_verts: dict[tuple[float, float], bmesh.types.BMVert] = {}

    def fin_vert(x: float, y: float):
        key = (round(x, 6), round(y, 6))
        if key not in fin_verts:
            fin_verts[key] = bm.verts.new((x, 0.0, y))
        return fin_verts[key]

    for x0, y0, x1, y1 in profile["fin_cells"]:
        face([fin_vert(x0, y1), fin_vert(x1, y1), fin_vert(x1, y0), fin_vert(x0, y0)], 1.0)

    mesh = bpy.data.meshes.new(species)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(species, mesh)
    bpy.context.scene.collection.objects.link(obj)

    material = bpy.data.materials.new(f"{species}_skin")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(OUT / species / profile["texture"]))
    links = material.node_tree.links
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.4
    material.use_backface_culling = False
    mesh.materials.append(material)

    # Assert the contract in Blender coords (glTF y = Blender z, z = -y).
    xs = [v.co.x for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    assert max(xs) <= 0.5 + 1e-4 and min(xs) >= -0.78 - 1e-4, (min(xs), max(xs))
    assert max(zs) <= 0.29 + 1e-4 and min(zs) >= -0.24 - 1e-4, (min(zs), max(zs))
    assert max(abs(y) for y in ys) <= 0.24, max(ys)
    for o in list(bpy.context.scene.objects):
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    target = OUT / species / f"{species}.gltf"
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        # Separate glTF: the image stays a URI to <species>_albedo.png, so the
        # runtime shader and the model share one texture file (no embedded copy).
        export_format="GLTF_SEPARATE",
        export_keep_originals=True,
        use_selection=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_yup=True,
    )
    print(f"{species}: {len(mesh.vertices)} verts, {len(mesh.polygons)} faces -> {target}")
    return target


def main() -> None:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for species in ("herring", "perch"):
        build(species)


main()
