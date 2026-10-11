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
import json
import struct
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

    # Snapshot the evaluated world matrix before detaching the meshes. Assigning
    # matrix_world while a mesh still has Sketchfab's scaled parent hierarchy can
    # reintroduce the inverse parent scale when that parent is removed later.
    # Detach first, then bake the saved matrix and explicitly reset every object
    # transform so the exported GLB has identity mesh-node transforms.
    for obj in meshes:
        world_matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.data = obj.data.copy()
        obj.data.transform(world_matrix)
        obj.matrix_world = Matrix.Identity(4)
        obj.location = Vector((0.0, 0.0, 0.0))
        obj.rotation_euler = Vector((0.0, 0.0, 0.0))
        obj.scale = Vector((1.0, 1.0, 1.0))

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
    _verify_export(args.output, args.largest_axis_m)
    print(f"Exported {args.title}: {args.output} (largest axis {args.largest_axis_m:.3f} m)")


def _verify_export(path: Path, expected_largest_axis_m: float) -> None:
    """Reject GLBs whose node transforms would scale metric vertices again."""
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise RuntimeError(f"Export is not a GLB: {path}")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    document = json.loads(payload[20 : 20 + json_length])

    for node in document.get("nodes", []):
        if "mesh" not in node:
            continue
        scale = node.get("scale", [1.0, 1.0, 1.0])
        translation = node.get("translation", [0.0, 0.0, 0.0])
        if any(abs(float(value) - 1.0) > 1e-5 for value in scale):
            raise RuntimeError(f"{path}: mesh node retains non-unit scale {scale}")
        if any(abs(float(value)) > 1e-5 for value in translation):
            raise RuntimeError(f"{path}: mesh node retains translation {translation}")

    largest_axis = 0.0
    for accessor in document.get("accessors", []):
        if accessor.get("type") != "VEC3" or "min" not in accessor or "max" not in accessor:
            continue
        largest_axis = max(
            largest_axis,
            max(float(high) - float(low) for low, high in zip(accessor["min"], accessor["max"])),
        )
    if abs(largest_axis - expected_largest_axis_m) > 1e-4:
        raise RuntimeError(
            f"{path}: exported largest axis {largest_axis:.6f} m, expected {expected_largest_axis_m:.6f} m"
        )


if __name__ == "__main__":
    main()
