"""Generate decimated LOD1/LOD2 GLBs for shared-rig character bodies.

Follows the forge_cat production precedent: mesh-only distance LODs exported as
separate GLBs beside each runtime body. LOD meshes keep skin weights against the
same armature bone names so SharedCharacterRig can mount them on the live
skeleton without a second AnimationPlayer.

Run from the repository root:

    blender --background --python tools/generate_character_lods.py
    blender --background --python tools/generate_character_lods.py -- mart

Writes:
  assets/characters/shared/<body>_lod1.glb  (~50% of LOD0 triangles)
  assets/characters/shared/<body>_lod2.glb  (~20% of LOD0 triangles)
  assets/characters/shared/character_lod_manifest.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_specs import CHARACTERS  # noqa: E402

SHARED_DIR = ROOT / "assets/characters/shared"
MANIFEST_PATH = SHARED_DIR / "character_lod_manifest.json"

LOD_RATIOS = {
    1: 0.50,
    2: 0.20,
}

GARMENT_OUTPUTS = {
    "assets/characters/shared/hero_cape.glb",
    "assets/characters/shared/hero_hat.glb",
}


def _clear_scene() -> None:
    # WHY: soft select/delete in background Blender left orphan MESH objects
    # (often named Icosphere.*) between bodies. Those leftovers were then
    # decimated into later LOD GLBs with no materials and rendered as the
    # default-white distant character blobs.
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.actions,
        bpy.data.images,
    ):
        for item in list(block):
            block.remove(item)


def _mesh_triangle_count(mesh: bpy.types.Mesh) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)


def _mesh_has_authored_materials(obj: bpy.types.Object) -> bool:
    if obj.type != "MESH" or obj.data is None:
        return False
    materials = list(obj.data.materials)
    return bool(materials) and all(material is not None for material in materials)


def _scene_triangle_count(meshes: list[bpy.types.Object] | None = None) -> int:
    targets = meshes if meshes is not None else _source_meshes()
    return sum(_mesh_triangle_count(obj.data) for obj in targets)


def _body_glb_paths(selected: list[str] | None = None) -> list[Path]:
    paths: list[Path] = []
    seen: set[str] = set()
    for name, entry in CHARACTERS.items():
        if selected is not None and name not in selected:
            continue
        output = entry["output"]
        if output in seen or output in GARMENT_OUTPUTS:
            continue
        seen.add(output)
        path = ROOT / output
        if path.is_file():
            paths.append(path)
    return sorted(paths)


def _import_glb(path: Path) -> bpy.types.Object | None:
    bpy.ops.import_scene.gltf(filepath=str(path))
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if not armatures:
        print(f"SKIP {path.name}: no armature")
        return None
    return armatures[0]


def _source_meshes() -> list[bpy.types.Object]:
    meshes: list[bpy.types.Object] = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        # Helper leftovers and unnamed Icospheres carry no slot materials and
        # would import as Godot's default white StandardMaterial3D.
        if obj.name.startswith("Icosphere"):
            print(f"SKIP helper mesh {obj.name}: Icosphere leftovers are not body LOD sources")
            continue
        if not _mesh_has_authored_materials(obj):
            print(f"SKIP mesh {obj.name}: missing authored materials")
            continue
        meshes.append(obj)
    return meshes


def _decimate_copy(source: bpy.types.Object, ratio: float) -> bpy.types.Object:
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    bpy.context.collection.objects.link(duplicate)
    duplicate.parent = source.parent
    duplicate.matrix_parent_inverse = source.matrix_parent_inverse.copy()
    current = _mesh_triangle_count(duplicate.data)
    if current <= 0:
        return duplicate
    modifier = duplicate.modifiers.new("DecimateLOD", "DECIMATE")
    modifier.ratio = min(1.0, max(0.01, ratio))
    bpy.context.view_layer.objects.active = duplicate
    bpy.ops.object.select_all(action="DESELECT")
    duplicate.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return duplicate


def _export_lod(path: Path, armature: bpy.types.Object, meshes: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for mesh_obj in meshes:
        mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_materials="EXPORT",
    )


def _process_body(path: Path) -> dict:
    _clear_scene()
    armature = _import_glb(path)
    if armature is None:
        return {}
    sources = _source_meshes()
    if not sources:
        print(f"SKIP {path.name}: no authored body meshes")
        return {}
    lod0_tris = _scene_triangle_count(sources)
    entry = {
        "body": path.name,
        "lod0_triangles": lod0_tris,
        "levels": {},
    }
    for level, ratio in LOD_RATIOS.items():
        lod_meshes: list[bpy.types.Object] = []
        for source in sources:
            lod_meshes.append(_decimate_copy(source, ratio))
        lod_tris = sum(_mesh_triangle_count(mesh.data) for mesh in lod_meshes)
        out_path = path.with_name(f"{path.stem}_lod{level}{path.suffix}")
        _export_lod(out_path, armature, lod_meshes)
        for mesh_obj in lod_meshes:
            mesh_data = mesh_obj.data
            bpy.data.objects.remove(mesh_obj, do_unlink=True)
            if mesh_data is not None and mesh_data.users == 0:
                bpy.data.meshes.remove(mesh_data)
        fraction = round(lod_tris / lod0_tris, 4) if lod0_tris else 0.0
        entry["levels"][f"lod{level}"] = {
            "path": str(out_path.relative_to(ROOT)),
            "triangles": lod_tris,
            "fraction_of_lod0": fraction,
            "target_ratio": ratio,
        }
        print(
            f"Wrote {out_path.name}: {lod_tris} tris ({fraction:.1%} of LOD0 {lod0_tris})"
        )
    return entry


def _selected_names(argv: list[str]) -> list[str] | None:
    if "--" not in argv:
        return None
    names = [arg for arg in argv[argv.index("--") + 1 :] if not arg.startswith("-")]
    return names or None


def main() -> None:
    selected = _selected_names(sys.argv)
    manifest = {
        "lod_ratios": LOD_RATIOS,
        "bodies": [],
    }
    for path in _body_glb_paths(selected):
        report = _process_body(path)
        if report:
            manifest["bodies"].append(report)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback

        traceback.print_exc()
        sys.exit(1)
