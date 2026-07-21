"""Generate our own hero body mesh around the retargeted adult skeleton.

Runs inside Blender (build-time tool only, never at runtime):

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python tools/generate_hero_body.py [-- --character=<spec>]

Input:  the character's skeleton intermediate (see tools/character_specs.py)
        with adult proportions and all 76 CC0 animation clips, produced by
        tools/build_heroic_humanoid_glb.py. Its meshes are placeholders.
Output: the spec's runtime glb - same skeleton and clips, but every visible
        mesh is generated from bone-derived measurements by focused body-part
        builders, then shaped by the spec's `shape` and `palette` overrides.

Skinning is deterministic: each generated vertex is assigned weights at
creation time, so no automatic-weight heuristics are involved.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_specs import spec as character_spec  # noqa: E402
from hero_body_context import BodyContext  # noqa: E402
from hero_body_head_builder import build_head  # noqa: E402
from hero_body_limb_builder import build_limbs  # noqa: E402
from hero_body_mesh_builder import PartBuilder, find_armature  # noqa: E402
from hero_body_torso_builder import build_torso  # noqa: E402
from hero_garment_builder import build_garments  # noqa: E402

GARMENT_OUTPUTS = {
    "cape": ROOT / "assets/characters/shared/hero_cape.glb",
    "hat": ROOT / "assets/characters/shared/hero_hat.glb",
}

# Default palette aligned with the legacy Kalev pixel sprite
# (img/user__idle.gif). Character specs override selected colors.
PALETTE = {
    "skin": (0.80, 0.58, 0.42, 1.0),
    "tunic": (0.38, 0.24, 0.14, 1.0),
    "sleeves": (0.84, 0.83, 0.80, 1.0),
    "sleeve_band": (0.22, 0.42, 0.72, 1.0),
    "pants": (0.16, 0.12, 0.10, 1.0),
    "boots": (0.42, 0.28, 0.16, 1.0),
    "belt": (0.62, 0.46, 0.28, 1.0),
    "hair": (0.48, 0.32, 0.20, 1.0),
    "beard": (0.42, 0.28, 0.16, 1.0),
    "eyes": (0.06, 0.05, 0.05, 1.0),
    "armor": (0.45, 0.47, 0.50, 1.0),
    "cape": (0.42, 0.24, 0.14, 1.0),
    "hat": (0.32, 0.36, 0.28, 1.0),
}
_active_palette: dict = dict(PALETTE)


def _material(name: str) -> bpy.types.Material:
    existing = bpy.data.materials.get(f"hero_{name}")
    if existing is not None:
        return existing
    material = bpy.data.materials.new(f"hero_{name}")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    # The palette is authored in sRGB; base color factors are linear.
    srgb = _active_palette[name]
    linear = tuple(pow(channel, 2.2) for channel in srgb[:3]) + (srgb[3],)
    bsdf.inputs["Base Color"].default_value = linear
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.1
    return material


def generate(character: str) -> None:
    selected = character_spec(character)
    _active_palette.update(selected["palette"])
    source = ROOT / selected["skeleton_intermediate"]
    output = ROOT / selected["output"]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    armature = find_armature()
    context = BodyContext.from_armature(armature)
    parts: list[PartBuilder] = [
        build_torso(context, selected["shape"], selected["features"]),
        build_head(context, selected["shape"], selected["features"]),
    ]
    parts.extend(build_limbs(context, selected["shape"], selected["features"]))
    body_objects = [part.build(armature, _material) for part in parts]

    # Report stature so the rig scene can pin its uniform model scale.
    crown = (
        context.head_center
        + context.frame.up * 0.150 * context.scale * selected["shape"]["head_scale"]
    )
    print(f"BODY_STATURE={crown.dot(context.frame.up):.4f}")
    print(f"BODY_ACTIONS={len(bpy.data.actions)}")
    _export(output, animations=True)
    print(f"Wrote {output}")

    _export_selected_garments(context, selected["garments"], body_objects)


def _export_selected_garments(
    context: BodyContext,
    selected_garments: list[str],
    body_objects: list[bpy.types.Object],
) -> None:
    if not selected_garments:
        return
    for obj in body_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

    for name, builder in build_garments(context).items():
        if name not in selected_garments:
            continue
        garment_object = builder.build(context.armature, _material)
        _export(GARMENT_OUTPUTS[name], animations=False)
        print(f"Wrote {GARMENT_OUTPUTS[name]}")
        bpy.data.objects.remove(garment_object, do_unlink=True)


def _export(path: Path, animations: bool) -> None:
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_yup=True,
    )


def _character_argument() -> str:
    argv = sys.argv
    if "--" in argv:
        for argument in argv[argv.index("--") + 1 :]:
            if argument.startswith("--character="):
                return argument.split("=", 1)[1]
    return "hero"


if __name__ == "__main__":
    try:
        generate(_character_argument())
    except Exception:
        import traceback

        traceback.print_exc()
        sys.exit(1)
