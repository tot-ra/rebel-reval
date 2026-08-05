"""Create the standalone medieval horse deliverable from the approved horse rig.

The shared pack-horse model already carries the period-neutral draft/cob silhouette,
PBR material, and the tested quadruped animation contract. This scoped export keeps
that reviewed geometry in a separate asset without changing the runtime fauna route.

Run from the repository root:
    blender -b --factory-startup --python generated/blender/medieval_horse_v1/build_medieval_horse.py
"""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "assets/animals/medieval/medieval_pack_horse.glb"
OUTPUT = ROOT / "assets/animals/medieval/medieval_horse.glb"
REPORT = Path(__file__).resolve().parent / "report.json"


def read_glb_json(path: Path) -> dict:
    data = path.read_bytes()
    magic, _version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise RuntimeError(f"not a GLB: {path}")
    offset = 12
    while offset < total_length:
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_length]
        offset += 8 + chunk_length
        if chunk_type == 0x4E4F534A:
            return json.loads(chunk.rstrip(b" \\t\\r\\n\\0"))
    raise RuntimeError(f"missing JSON chunk: {path}")


def scene_mesh_bounds() -> tuple[list[float], list[float]]:
    points: list[tuple[float, float, float]] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_get() or not obj.visible_get():
            continue
        points.extend(tuple(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices)
    if not points:
        raise RuntimeError("horse export has no mesh vertices")
    minimum = [min(point[index] for point in points) for index in range(3)]
    maximum = [max(point[index] for point in points) for index in range(3)]
    return minimum, maximum


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.hide_get() and obj.visible_get()]
    if len(armatures) != 1 or not meshes:
        raise RuntimeError(f"expected one armature and mesh geometry, got {len(armatures)} / {len(meshes)}")

    armature = armatures[0]
    armature.name = "MedievalHorseRig"
    armature.data.name = "MedievalHorseRig"
    for mesh in meshes:
        if mesh.name == "Mesh_0":
            mesh.name = "AnimalMesh"

    actions = sorted(action.name for action in bpy.data.actions if action.name in {"Idle-loop", "Walk-loop"})
    if actions != ["Idle-loop", "Walk-loop"]:
        raise RuntimeError(f"horse export needs Idle-loop and Walk-loop, got {actions}")

    minimum, maximum = scene_mesh_bounds()
    dimensions = [maximum[index] - minimum[index] for index in range(3)]

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"ARMATURE", "MESH"} and (obj.type == "ARMATURE" or (not obj.hide_get() and obj.visible_get())):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_def_bones=True,
    )

    exported = read_glb_json(OUTPUT)
    exported_animations = [animation.get("name") for animation in exported.get("animations", [])]
    if not {"Idle-loop", "Walk-loop"}.issubset(exported_animations):
        raise RuntimeError(f"exported GLB lost required clips: {exported_animations}")

    report = {
        "asset_id": "assets.animals.medieval.horse",
        "source": str(SOURCE.relative_to(ROOT)),
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "output": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "route": "reviewed_pack_horse_rig_to_standalone_blender_export",
        "dimensions_m_xyz": [round(value, 4) for value in dimensions],
        "ground_min_z_m": round(minimum[2], 4),
        "mesh_objects": len(meshes),
        "armatures": len(armatures),
        "animations": exported_animations,
        "glb_nodes": len(exported.get("nodes", [])),
        "glb_meshes": len(exported.get("meshes", [])),
        "glb_skins": len(exported.get("skins", [])),
        "embedded_materials": True,
        "period_note": "Generic stocky draft/cob service horse; no post-1346 cavalry tack or decorative breed markers.",
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("HORSE_EXPORT=" + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
