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

import json
import struct
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_specs import population_spec, spec as character_spec  # noqa: E402
from hero_body_anatomy_builder import (  # noqa: E402
    build_anatomical_limbs,
    build_anatomical_torso,
)
from hero_body_context import BodyContext  # noqa: E402
from hero_body_head_builder import build_head  # noqa: E402
from hero_body_limb_builder import build_limbs  # noqa: E402
from hero_body_mesh_builder import PartBuilder, find_armature  # noqa: E402
from hero_body_textures import apply_texture  # noqa: E402
from hero_body_torso_builder import build_torso  # noqa: E402
from hero_garment_builder import build_garments  # noqa: E402

GARMENT_OUTPUTS = {
    "cape": ROOT / "assets/characters/shared/hero_cape.glb",
    "hat": ROOT / "assets/characters/shared/hero_hat.glb",
}

# Default palette aligned with the legacy Kalev pixel sprite
# (character/inspiration/user__idle.gif). Character specs override selected colors.
PALETTE = {
    "skin": (0.80, 0.58, 0.42, 1.0),
    "tunic": (0.38, 0.24, 0.14, 1.0),
    "sleeves": (0.84, 0.83, 0.80, 1.0),
    "sleeve_band": (0.22, 0.42, 0.72, 1.0),
    "pants": (0.16, 0.12, 0.10, 1.0),
    "boots": (0.42, 0.28, 0.16, 1.0),
    # Soles and heel counters: darker, waxed leather that separates the built-up
    # parts of the shoe from its upper at gameplay distance.
    "sole": (0.17, 0.13, 0.11, 1.0),
    "belt": (0.62, 0.46, 0.28, 1.0),
    "hair": (0.48, 0.32, 0.20, 1.0),
    "beard": (0.42, 0.28, 0.16, 1.0),
    # Iris. Kept at a readable mid value on purpose: paired with the near-black
    # pupil and limbal ring below, a lighter iris is what makes an eye read as
    # an eye instead of a dark hole (see docs/reports/face_realism_research.md).
    "eyes": (0.34, 0.38, 0.38, 1.0),
    # Sclera. Never paper white: a real sclera sits in the shadow of the lids
    # and is closer to a warm light grey, which is why bright white eyeballs
    # are the classic giveaway of a game character.
    "eye_white": (0.70, 0.68, 0.62, 1.0),
    # Pupil and limbal ring share this material: the darkest value on the face.
    "pupil": (0.04, 0.04, 0.05, 1.0),
    # Cornea: the transparent bulge over the iris that carries the wet
    # highlight. Alpha comes from TRANSPARENT_ALPHA below.
    "cornea": (0.92, 0.95, 0.97, 1.0),
    # Lips read as slightly redder, slightly darker skin. Anything more
    # saturated turns into lipstick at portrait distance.
    "lips": (0.52, 0.31, 0.26, 1.0),
    # Vermillion seam where the lips meet - much darker than the lips, and the
    # cue that reads as a closed mouth at dialogue distance.
    "lip_seam": (0.20, 0.09, 0.08, 1.0),
    "armor": (0.45, 0.47, 0.50, 1.0),
    "mail": (0.40, 0.43, 0.45, 1.0),
    "outerwear": (0.28, 0.20, 0.14, 1.0),
    # Work-apron leather. Kept separate from "outerwear" because aprons read
    # as tanned hide while vests and surcoats stay wool cloth.
    "leather": (0.24, 0.16, 0.10, 1.0),
    "trim": (0.55, 0.40, 0.24, 1.0),
    "cape": (0.42, 0.24, 0.14, 1.0),
    "hat": (0.32, 0.36, 0.28, 1.0),
}
_active_palette: dict = dict(PALETTE)

# Materials exported with glTF alpha blending, and their opacity. Only the
# cornea qualifies: everything else stays opaque so the GL Compatibility
# renderer keeps a single sorted transparent surface per character.
TRANSPARENT_ALPHA = {"cornea": 0.16}


def _material(name: str) -> bpy.types.Material:
    existing = bpy.data.materials.get(f"hero_{name}")
    if existing is not None:
        return existing
    material = bpy.data.materials.new(f"hero_{name}")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    # The palette is authored in sRGB; base color factors are linear.
    srgb = _active_palette.get(name)
    if srgb is None:
        # Late-added material names (for example apron "leather") fall back to
        # the spec's outerwear tone instead of failing the whole build.
        srgb = _active_palette.get("outerwear", PALETTE["outerwear"])
    linear = tuple(pow(channel, 2.2) for channel in srgb[:3]) + (srgb[3],)
    bsdf.inputs["Base Color"].default_value = linear
    # Material response is part of the model, not a global flat-plastic tint.
    # Wool stays matte, leather has a restrained broad highlight, skin keeps a
    # softer response and metal remains the only genuinely reflective surface.
    roughness = {
        "skin": 0.72,
        "hair": 0.78,
        "beard": 0.82,
        "eyes": 0.32,
        "eye_white": 0.50,
        # The cornea is the glossiest surface on the body; its highlight is the
        # single strongest "alive" cue we can afford without an eye shader.
        "cornea": 0.05,
        "pupil": 0.22,
        "lips": 0.58,
        "lip_seam": 0.62,
        "boots": 0.66,
        "sole": 0.80,
        "belt": 0.64,
        "outerwear": 0.76,
        "armor": 0.38,
        "mail": 0.47,
    }.get(name, 0.88)
    specular = {
        "skin": 0.28,
        "eyes": 0.55,
        "eye_white": 0.34,
        "cornea": 0.90,
        "pupil": 0.50,
        "lips": 0.36,
        "lip_seam": 0.30,
        "boots": 0.24,
        "sole": 0.14,
        "belt": 0.24,
        "armor": 0.62,
        "mail": 0.48,
    }.get(name, 0.16)
    bsdf.inputs["Roughness"].default_value = roughness
    alpha = TRANSPARENT_ALPHA.get(name)
    if alpha is not None:
        # glTF takes baseColorFactor alpha from the Alpha socket, and alphaMode
        # BLEND from the material's blend setting. Blender 4.2+ replaced
        # `blend_method` with `surface_render_method`, so set whichever exists
        # rather than pinning the tool to one Blender generation.
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "BLENDED"
        if hasattr(material, "blend_method"):
            material.blend_method = "BLEND"
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.72 if name in ("armor", "mail") else 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    # Procedural albedo/normal detail maps (P0-144/P0-145): the flat tint stays
    # as the multiplicative factor, so spec palettes keep working unchanged.
    apply_texture(material, name)
    return material


def generate(
    character: str,
    *,
    population_seed: int | None = None,
    fidelity_tier: int = 2,
    manifest_path: Path | None = None,
) -> None:
    selected = (
        population_spec(population_seed, archetype=character, fidelity_tier=fidelity_tier)
        if population_seed is not None
        else character_spec(character)
    )
    _active_palette.clear()
    _active_palette.update(PALETTE)
    _active_palette.update(selected["palette"])
    source = ROOT / selected["skeleton_intermediate"]
    output = ROOT / selected["output"]
    output.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    armature = find_armature()
    if population_seed is not None:
        # Uniform root scale changes stature without changing bone-relative
        # animation motion or skinning. Build variation remains mesh-local.
        armature.scale = (selected["height_scale"],) * 3
        armature["population_seed"] = population_seed
        armature["population_height_scale"] = selected["height_scale"]
        armature["population_archetype"] = selected["population_archetype"]
    context = BodyContext.from_armature(armature)
    body_parts: list[PartBuilder]
    if selected["features"]["anatomical_layers"]:
        # Opt-in prototypes keep the proven skeleton/clip contract but author
        # skin below independent clothing, with muscle landmarks in the body
        # profile. Existing characters remain byte-for-byte rebuild compatible.
        body_parts = [
            build_anatomical_torso(context, selected["shape"]),
            build_torso(context, selected["shape"], selected["features"]),
            build_head(context, selected["shape"], selected["face"], selected["features"]),
        ]
        body_parts.extend(
            build_anatomical_limbs(context, selected["shape"], selected["features"])
        )
    else:
        body_parts = [
            build_torso(context, selected["shape"], selected["features"]),
            build_head(context, selected["shape"], selected["face"], selected["features"]),
        ]
        body_parts.extend(build_limbs(context, selected["shape"], selected["features"]))
    body_objects = [part.build(armature, _material) for part in body_parts]

    # Report stature so the rig scene can pin its uniform model scale.
    crown = (
        context.head_center
        + context.frame.up * 0.150 * context.scale * selected["shape"]["head_scale"]
    )
    print(f"BODY_STATURE={crown.dot(context.frame.up):.4f}")
    print(f"BODY_ACTIONS={len(bpy.data.actions)}")
    _export(output, animations=True)
    print(f"Wrote {output}")
    if population_seed is not None:
        manifest = {
            "schema": "rebel.population_variant.v1",
            "generator": "tools/generate_hero_body.py",
            "seed": population_seed,
            "archetype": selected["population_archetype"],
            "fidelity_tier": selected["fidelity_tier"],
            "output": selected["output"],
            "variation": selected["variation"],
            "pbr_texture_families": ["skin", "cloth", "leather", "metal", "hair"],
            "palette_srgb": {key: list(value) for key, value in selected["palette"].items()},
        }
        resolved_manifest = manifest_path or output.with_suffix(".variation.json")
        resolved_manifest.parent.mkdir(parents=True, exist_ok=True)
        resolved_manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        print(f"Wrote {resolved_manifest}")

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
        # Keep the default 'MATERIAL' + all-colour-sets behaviour: it is the
        # only combination that writes the head's tint attribute to every
        # primitive. _promote_vertex_colors then moves it into COLOR_0.
        export_vertex_color="MATERIAL",
        export_all_vertex_colors=True,
    )
    _promote_vertex_colors(path)


def _promote_vertex_colors(path: Path) -> None:
    """Move the real vertex-colour set into COLOR_0 and drop the placeholder.

    Blender 5.2's glTF exporter carries a mesh's colour attribute into the
    first primitive only when selecting a single set, so we export all sets;
    that writes a flat white COLOR_0 (the material-driven slot) ahead of the
    real data in COLOR_1. Godot reads COLOR_0 and nothing else, so without this
    step the complexion and hair tints are exported but never render.

    The rewrite is index-level only: the surviving buffer views are copied
    verbatim into a fresh binary chunk, and accessor/buffer-view references are
    remapped. No vertex data is recomputed.
    """
    blob = path.read_bytes()
    json_length = struct.unpack_from("<I", blob, 12)[0]
    document = json.loads(blob[20 : 20 + json_length])
    binary = blob[20 + json_length + 8 :]

    dropped: set[int] = set()
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            attributes = primitive["attributes"]
            extra = sorted(
                name for name in attributes if name.startswith("COLOR_") and name != "COLOR_0"
            )
            if not extra:
                continue
            dropped.add(attributes["COLOR_0"])
            attributes["COLOR_0"] = attributes.pop(extra[0])
            for name in extra[1:]:
                dropped.add(attributes.pop(name))
    if not dropped:
        return

    kept_accessors = [i for i in range(len(document["accessors"])) if i not in dropped]
    accessor_map = {old: new for new, old in enumerate(kept_accessors)}
    kept_views = sorted(
        {
            document["accessors"][i].get("bufferView")
            for i in kept_accessors
            if document["accessors"][i].get("bufferView") is not None
        }
        | {
            image["bufferView"]
            for image in document.get("images", [])
            if "bufferView" in image
        }
    )
    view_map = {old: new for new, old in enumerate(kept_views)}

    chunks: list[bytes] = []
    offset = 0
    views: list[dict] = []
    for old_index in kept_views:
        view = dict(document["bufferViews"][old_index])
        start = view.get("byteOffset", 0)
        data = binary[start : start + view["byteLength"]]
        padding = (-len(data)) % 4
        view["byteOffset"] = offset
        views.append(view)
        chunks.append(data + b"\x00" * padding)
        offset += len(data) + padding

    document["bufferViews"] = views
    document["accessors"] = [
        {
            **document["accessors"][i],
            **(
                {"bufferView": view_map[document["accessors"][i]["bufferView"]]}
                if document["accessors"][i].get("bufferView") is not None
                else {}
            ),
        }
        for i in kept_accessors
    ]
    for image in document.get("images", []):
        if "bufferView" in image:
            image["bufferView"] = view_map[image["bufferView"]]
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive["attributes"] = {
                name: accessor_map[index]
                for name, index in primitive["attributes"].items()
            }
            if "indices" in primitive:
                primitive["indices"] = accessor_map[primitive["indices"]]
            for target in primitive.get("targets", []):
                for name, index in list(target.items()):
                    target[name] = accessor_map[index]
    for skin in document.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = accessor_map[skin["inverseBindMatrices"]]
    for animation in document.get("animations", []):
        for sampler in animation.get("samplers", []):
            sampler["input"] = accessor_map[sampler["input"]]
            sampler["output"] = accessor_map[sampler["output"]]

    payload = b"".join(chunks)
    document["buffers"] = [{"byteLength": len(payload)}]
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((-len(encoded)) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(payload)
    path.write_bytes(
        b"glTF"
        + struct.pack("<II", 2, total)
        + struct.pack("<I", len(encoded))
        + b"JSON"
        + encoded
        + struct.pack("<I", len(payload))
        + b"BIN\x00"
        + payload
    )


def _arguments() -> tuple[str, int | None, int, Path | None]:
    character = "hero"
    population_seed: int | None = None
    fidelity_tier = 2
    manifest_path: Path | None = None
    argv = sys.argv
    if "--" in argv:
        for argument in argv[argv.index("--") + 1 :]:
            if argument.startswith("--character="):
                character = argument.split("=", 1)[1]
            elif argument.startswith("--population-seed="):
                population_seed = int(argument.split("=", 1)[1])
            elif argument.startswith("--tier="):
                fidelity_tier = int(argument.split("=", 1)[1])
            elif argument.startswith("--manifest="):
                manifest_path = Path(argument.split("=", 1)[1])
    return character, population_seed, fidelity_tier, manifest_path


if __name__ == "__main__":
    try:
        selected_character, selected_seed, selected_tier, selected_manifest = _arguments()
        generate(
            selected_character,
            population_seed=selected_seed,
            fidelity_tier=selected_tier,
            manifest_path=selected_manifest,
        )
    except Exception:
        import traceback

        traceback.print_exc()
        sys.exit(1)
