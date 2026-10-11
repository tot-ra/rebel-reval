#!/usr/bin/env python3
"""Backfill missing roughness maps on authored bird GLBs (P0-160).

Bird imports from the P2-033 pipeline often ship albedo + normal only.
This script preserves those maps and embeds a deterministic feather roughness
map so fauna GLBs meet the forge-cat / medieval-livestock PBR bar.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
BIRDS_DIR = ROOT / "assets" / "birds"
TEXTURE_SIZE = 512

# Soft feather barb micro-relief; tuned to read under GL Compatibility sun.
FEATHER_PROFILE = {
    "noise_scale": 18.0,
    "noise_detail": 6.0,
    "rough_min": 0.72,
    "rough_max": 0.90,
}


def _new_image(name: str, fill: tuple[float, float, float, float], *, non_color: bool) -> bpy.types.Image:
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    pixels = list(fill) * (TEXTURE_SIZE * TEXTURE_SIZE)
    image.pixels.foreach_set(pixels)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    image.file_format = "PNG"
    image.pack()
    return image


def _create_roughness_image(image_name: str) -> bpy.types.Image:
    """Procedural feather roughness without disturbing the imported body material."""
    import numpy as np

    size = TEXTURE_SIZE
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / float(size)
    v = yy / float(size)
    noise = (
        np.sin(u * FEATHER_PROFILE["noise_scale"] + v * 2.1)
        + np.sin(v * FEATHER_PROFILE["noise_scale"] * 0.72 - u * 1.4)
        + np.sin((u + v) * FEATHER_PROFILE["noise_scale"] * 0.35)
    ) / 3.0
    mix = np.clip(noise * 0.5 + 0.5, 0.0, 1.0)
    roughness = FEATHER_PROFILE["rough_min"] + mix * (
        FEATHER_PROFILE["rough_max"] - FEATHER_PROFILE["rough_min"]
    )
    rgb = np.repeat(roughness[:, :, None], 3, axis=2)
    alpha = np.ones((size, size, 1), dtype=np.float32)
    pixels = np.concatenate((rgb, alpha), axis=2).ravel()
    image = _new_image(image_name, (0.84, 0.84, 0.84, 1.0), non_color=True)
    image.pixels.foreach_set(pixels.tolist())
    image.pack()
    return image


def _body_material(obj: bpy.types.Object) -> bpy.types.Material | None:
    for slot in obj.material_slots:
        if slot.material is None:
            continue
        name = slot.material.name.lower()
        if any(part in name for part in ("eye", "pupil", "cornea")):
            continue
        return slot.material
    return obj.material_slots[0].material if obj.material_slots else None


def _material_has_roughness_map(material: bpy.types.Material) -> bool:
    if not material.use_nodes:
        return False
    for node in material.node_tree.nodes:
        if node.type != "BSDF_PRINCIPLED":
            continue
        rough_input = node.inputs.get("Roughness")
        if rough_input is None:
            return False
        for link in rough_input.links:
            if link.from_node.type == "TEX_IMAGE":
                return True
    return False


def _attach_roughness(material: bpy.types.Material, roughness: bpy.types.Image) -> None:
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    if shader is None:
        return
    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.name = "EmbeddedRoughness"
    roughness_node.image = roughness
    roughness_node.interpolation = "Linear"
    links.new(roughness_node.outputs["Color"], shader.inputs["Roughness"])
    shader.inputs["Metallic"].default_value = 0.0


def _import_mesh(path: Path) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"{path}: import produced no mesh objects")
    return max(meshes, key=lambda obj: len(obj.data.polygons))


def backfill_glb(path: Path) -> dict[str, object]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = _import_mesh(path)
    material = _body_material(obj)
    if material is None:
        raise RuntimeError(f"{path}: no body material found")
    if _material_has_roughness_map(material):
        return {"path": str(path), "updated": False, "reason": "roughness already present"}

    image_name = f"{path.stem}_roughness"
    roughness = _create_roughness_image(image_name)
    material = _body_material(obj)
    if material is None:
        raise RuntimeError(f"{path}: no body material found")
    _attach_roughness(material, roughness)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_skins=False,
        export_animations=False,
    )
    return {"path": str(path), "updated": True, "roughness_image": image_name}


def main() -> int:
    selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    targets = [Path(arg) for arg in selected] if selected else sorted(BIRDS_DIR.rglob("*.glb"))
    reports = []
    for path in targets:
        if not path.is_file():
            print(f"skip missing {path}", file=sys.stderr)
            continue
        report = backfill_glb(path)
        reports.append(report)
        print(json.dumps(report))
    updated = sum(1 for report in reports if report.get("updated"))
    print(f"backfill complete: {updated}/{len(reports)} updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
