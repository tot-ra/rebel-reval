#!/usr/bin/env python3
"""Normalize an authorized hendrikReyneke Sketchfab GLB for Rebel Reval.

Run with Blender 5.2 or newer:
    blender --background --python tools/assets/import_hendrik_reyneke_model.py -- \
        --source SOURCE.glb --output OUTPUT.glb --largest-axis-m 0.5 \
        --title Chicken --source-url https://sketchfab.com/...

The importer bakes Sketchfab's nested transforms into portable metric geometry,
centres the animal over the origin, puts its feet on the ground, preserves PBR
materials, and embeds the attribution metadata in the exported GLB.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--largest-axis-m", type=float, required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--source-url", required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def main() -> None:
    args = arguments()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(args.source))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects in {args.source}")

    # Bake the complete imported hierarchy so the runtime GLB does not depend on
    # Sketchfab's centimetre-scale wrapper transforms.
    for obj in meshes:
        obj.data = obj.data.copy()
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        obj.parent = None

    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    coordinates = [vertex.co for obj in meshes for vertex in obj.data.vertices]
    low = Vector((min(v.x for v in coordinates), min(v.y for v in coordinates), min(v.z for v in coordinates)))
    high = Vector((max(v.x for v in coordinates), max(v.y for v in coordinates), max(v.z for v in coordinates)))
    largest_axis = max(high.x - low.x, high.y - low.y, high.z - low.z)
    if largest_axis <= 0.0:
        raise RuntimeError(f"Degenerate bounds in {args.source}")
    scale = args.largest_axis_m / largest_axis
    anchor = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))

    for index, obj in enumerate(meshes):
        for vertex in obj.data.vertices:
            vertex.co = (vertex.co - anchor) * scale
        obj.name = "AnimalMesh" if index == 0 else f"AnimalMesh{index + 1}"
        obj["author"] = "hendrikReyneke (https://sketchfab.com/hendrikReyneke)"
        obj["license"] = "CC-BY-4.0 (https://creativecommons.org/licenses/by/4.0/)"
        obj["source"] = args.source_url
        obj["title"] = args.title

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_extras=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        use_selection=True,
    )
    print(f"Exported {args.title}: {args.output} (largest axis {args.largest_axis_m:.3f} m)")


if __name__ == "__main__":
    main()
