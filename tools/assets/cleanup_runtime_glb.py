#!/usr/bin/env python3
"""In-place cleanup for reviewed runtime fauna/livestock GLBs.

Removes authoring preview helpers (Icosphere/Cube/Camera/Light), drops orphan
non-mesh scene nodes, and snaps the combined mesh bounds to Blender Z=0 so the
exported Y-up GLB keeps feet on the ground. Preserves armatures, skin weights,
and animation actions.

Run from the repository root:
    blender --background --factory-startup --python tools/assets/cleanup_runtime_glb.py -- \\
        assets/animals/medieval/medieval_dog.glb assets/birds/herring_gull/gliding_00.glb

Pass a manifest file with one repo-relative path per line instead of paths:
    blender --background --factory-startup --python tools/assets/cleanup_runtime_glb.py -- \\
        --manifest /tmp/fauna_cleanup_paths.txt
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = ROOT / "build" / "fauna_cleanup"
GROUND_EPS = 0.002
HELPER_NAMES = frozenset({"icosphere", "cube", "camera", "light", "plane"})


def _arguments() -> tuple[list[Path], Path | None]:
    if "--" not in sys.argv:
        raise SystemExit("Pass paths after --")
    tokens = sys.argv[sys.argv.index("--") + 1 :]
    manifest: Path | None = None
    paths: list[Path] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "--manifest":
            manifest = Path(tokens[index + 1])
            index += 2
            continue
        paths.append(ROOT / token)
        index += 1
    if manifest is not None:
        for line in manifest.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            rel = line.removeprefix("res://")
            paths.append(ROOT / rel)
    if not paths:
        raise SystemExit("No GLB paths provided")
    return paths, manifest


def _is_helper_mesh(obj: bpy.types.Object) -> bool:
    if obj.type != "MESH":
        return False
    name = obj.name.lower()
    return name in HELPER_NAMES or name.startswith("cube")


def _world_bounds() -> tuple[Vector, Vector]:
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    started = False
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            if not started:
                low = point.copy()
                high = point.copy()
                started = True
            else:
                low.x = min(low.x, point.x)
                low.y = min(low.y, point.y)
                low.z = min(low.z, point.z)
                high.x = max(high.x, point.x)
                high.y = max(high.y, point.y)
                high.z = max(high.z, point.z)
    if not started:
        return Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 0.0))
    return low, high


def _translate_scene(delta: Vector) -> None:
    for obj in bpy.context.scene.objects:
        if obj.type not in {"MESH", "ARMATURE"}:
            continue
        obj.location += delta


def _remove_orphans() -> list[str]:
    removed: list[str] = []
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"MESH", "ARMATURE"}:
            continue
        removed.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def cleanup_glb(path: Path) -> dict[str, object]:
    if not path.is_file():
        return {"path": str(path.relative_to(ROOT)), "updated": False, "error": "missing"}

    before_sha = hashlib.sha256(path.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))

    helpers = [obj.name for obj in list(bpy.context.scene.objects) if _is_helper_mesh(obj)]
    for obj in list(bpy.context.scene.objects):
        if _is_helper_mesh(obj):
            bpy.data.objects.remove(obj, do_unlink=True)

    orphans = _remove_orphans()
    low_before, _ = _world_bounds()
    delta_z = 0.0
    if low_before.z < -GROUND_EPS or low_before.z > GROUND_EPS:
        delta_z = -low_before.z
        _translate_scene(Vector((0.0, 0.0, delta_z)))

    low_after, high_after = _world_bounds()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not meshes:
        return {
            "path": str(path.relative_to(ROOT)),
            "updated": False,
            "error": "no meshes remain after cleanup",
        }

    animated = bool(armatures)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes + armatures:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armatures[0] if armatures else meshes[0]

    temp_path = path.with_suffix(".cleanup.glb")
    bpy.ops.export_scene.gltf(
        filepath=str(temp_path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=not animated,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_skins=animated,
        export_animations=animated,
        export_animation_mode="ACTIONS" if animated else "ACTIVE_ACTIONS",
        export_force_sampling=animated,
        export_def_bones=True,
    )
    after_sha = hashlib.sha256(temp_path.read_bytes()).hexdigest()
    changed = after_sha != before_sha
    if changed:
        temp_path.replace(path)
    else:
        temp_path.unlink(missing_ok=True)

    return {
        "path": str(path.relative_to(ROOT)),
        "updated": changed,
        "before_sha256": before_sha,
        "after_sha256": after_sha if changed else before_sha,
        "removed_helpers": helpers,
        "removed_orphans": orphans,
        "ground_delta_z": round(delta_z, 6),
        "min_z_after": round(low_after.z, 6),
        "max_z_after": round(high_after.z, 6),
        "mesh_count": len(meshes),
        "armature_count": len(armatures),
    }


def main() -> int:
    paths, _manifest = _arguments()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    reports: list[dict[str, object]] = []
    updated = 0
    for path in paths:
        report = cleanup_glb(path)
        reports.append(report)
        if report.get("updated"):
            updated += 1
        print(json.dumps(report, separators=(",", ":")))

    summary_path = REPORT_DIR / "cleanup_report.json"
    summary_path.write_text(
        json.dumps({"processed": len(reports), "updated": updated, "reports": reports}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    print(f"cleanup complete: {updated}/{len(reports)} updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
