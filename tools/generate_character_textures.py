#!/usr/bin/env python3
"""Generate and audit the shared character-surface PBR texture families.

The runtime generator lives in :mod:`hero_body_textures` because Blender must
pack the images into the character GLB.  This CLI is the explicit contract for
that generator: it can list the available zones without Blender, and in
Blender it can export the source maps plus a deterministic provenance manifest.

The maps are intentionally palette-neutral.  ``generate_hero_body.py``
multiplies each albedo by the selected character spec's sRGB palette entry,
then exports the result as glTF ``baseColorTexture`` + ``baseColorFactor``.
That keeps one seamless family usable by every character and LOD.

Examples::

    python3 tools/generate_character_textures.py --list
    blender --background --python tools/generate_character_textures.py -- \
        --character=hero --output=/tmp/character-textures
    blender --background --python tools/generate_character_textures.py -- \
        --verify --character=hero --output=/tmp/character-textures
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from character_specs import CHARACTERS, spec  # noqa: E402

FAMILIES = ("skin", "cloth", "leather", "metal", "hair")
MAPS = ("albedo", "normal", "roughness", "ao")
MATERIALS_BY_FAMILY = {
    "skin": ("skin",),
    "cloth": ("tunic", "sleeves", "sleeve_band", "pants", "trim", "outerwear", "cape", "hat"),
    "leather": ("boots", "sole", "belt", "leather"),
    "metal": ("armor", "mail"),
    "hair": ("hair", "beard"),
}

# These are design prompts, not claims of external image provenance.  They
# preserve the art direction that the seeded procedural builders implement and
# make a future replacement generator auditable without changing the runtime
# material contract.
PROMPTS = {
    "skin": "Seamless tileable skin surface, subtle warm blotch, fine pores, sparse freckles, no lighting, no face or baked shadows",
    "cloth": "Seamless tileable plain medieval wool, restrained warp and weft weave, soft fibers, no lighting, no garment silhouette",
    "leather": "Seamless tileable vegetable-tanned leather, broad grain, fine pores and restrained crease relief, no lighting",
    "metal": "Seamless tileable brushed steel, fine directional streaks, sparse hammered dents, neutral value, no lighting",
    "hair": "Seamless tileable hair strands, narrow directional streaks with natural clump variation, no lighting, no head silhouette",
}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--character",
        default="hero",
        choices=sorted(CHARACTERS),
        help="character spec whose palette is recorded in the manifest (default: hero)",
    )
    parser.add_argument(
        "--family",
        action="append",
        choices=FAMILIES,
        dest="families",
        help="family to export; repeat for a subset (default: all five)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("generated/comfyui/character_textures_v1"),
        help="directory for source PNGs and manifest (default: generated/comfyui/character_textures_v1)",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        help="manifest path; defaults to <output>/manifest.json",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="check an existing output and manifest without regenerating files",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="print families, material-zone mapping, and known character specs; no Blender required",
    )
    return parser


def _script_args() -> list[str]:
    """Return arguments after Blender's optional ``--`` separator."""
    argv = sys.argv[1:]
    if "--" in argv:
        return argv[argv.index("--") + 1 :]
    return argv


def _rooted(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def _manifest(character: str, families: Iterable[str], output: Path) -> dict:
    selected = spec(character)
    selected_families = list(families)
    zones = {}
    for family in selected_families:
        zones[family] = {
            "materials": list(MATERIALS_BY_FAMILY[family]),
            "prompt": PROMPTS[family],
            "maps": {
                map_name: _relative(output / f"hero_tex_{family}_{map_name}.png")
                for map_name in MAPS
            },
            "seeded_builder": f"hero_body_textures._{family}_maps",
        }
    return {
        "schema": "rebel.character_textures.v1",
        "generator": {
            "tool": "tools/generate_character_textures.py",
            "implementation": "tools/hero_body_textures.py",
            "mode": "deterministic seeded procedural maps; no external image is shipped",
            "resolution": 512,
            "seamless": True,
            "maps": list(MAPS),
        },
        "character": {
            "name": character,
            "output_glb": selected["output"],
            "palette_srgb_overrides": {
                key: list(value) for key, value in selected["palette"].items()
            },
        },
        "runtime_contract": {
            "palette_application": "detail albedo multiplied by the character palette in generate_hero_body._material",
            "normal_space": "OpenGL tangent-space",
            "roughness_ao_export": "roughness is packed into glTF metallicRoughnessTexture; AO uses occlusionTexture",
        },
        "zones": zones,
        "provenance": {
            "author": "project maintainer",
            "source": "in-repository procedural implementation informed by the prompts above",
            "external_generation_ids": [],
            "regenerate": "blender --background --python tools/generate_character_textures.py -- --character=<spec>",
        },
    }


def _print_listing() -> None:
    print("families:")
    for family in FAMILIES:
        print(f"  {family}: {', '.join(MATERIALS_BY_FAMILY[family])}")
    print("maps: " + ", ".join(MAPS))
    print("characters: " + ", ".join(sorted(CHARACTERS)))


def _save_image(image: object, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Blender's Image.save writes packed images as PNG when file_format is set;
    # save_copy avoids changing the packed image's source path in the build.
    image.file_format = "PNG"
    image.save(filepath=str(path), save_copy=True)


def _write_maps(families: Iterable[str], output: Path) -> None:
    # Import Blender-only modules after --list/help have been handled, keeping
    # discovery and CI contract checks runnable with the repository Python.
    from hero_body_textures import family_images  # noqa: E402

    for family in families:
        images = family_images(family)
        for map_name, image in zip(MAPS, images):
            _save_image(image, output / f"hero_tex_{family}_{map_name}.png")


def _verify(
    output: Path,
    manifest_path: Path,
    expected_manifest: dict,
    required_families: Iterable[str],
) -> int:
    missing = []
    manifest = expected_manifest
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"invalid character texture manifest: {manifest_path}: {exc}")
            return 1
    if manifest.get("schema") != "rebel.character_textures.v1":
        print(f"invalid character texture manifest schema: {manifest.get('schema')!r}")
        return 1
    zones = manifest.get("zones", {})
    expected_families = set(required_families)
    if set(zones) != expected_families:
        print(
            "manifest must contain the selected families: "
            f"expected {sorted(expected_families)}, got {sorted(zones)}"
        )
        return 1
    for family, zone in zones.items():
        if tuple(zone.get("maps", {})) != MAPS:
            print(f"manifest map contract failed for {family}: {zone.get('maps', {})}")
            return 1
        for map_name, relative in zone["maps"].items():
            path = Path(relative)
            if not path.is_absolute():
                path = ROOT / relative
            if not path.is_file():
                missing.append(str(path))
    if not manifest_path.is_file():
        missing.append(str(manifest_path))
    if missing:
        print("missing character texture outputs:")
        print("\n".join(f"  {path}" for path in missing))
        return 1
    print(
        f"character texture outputs verified: {len(zones)} families, "
        f"{len(zones) * len(MAPS)} maps"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(_script_args() if argv is None else argv)
    if args.list:
        _print_listing()
        return 0

    families = tuple(dict.fromkeys(args.families or FAMILIES))
    output = _rooted(args.output)
    manifest_path = _rooted(args.manifest) if args.manifest else output / "manifest.json"
    manifest = _manifest(args.character, families, output)

    if args.verify:
        return _verify(output, manifest_path, manifest, families)

    _write_maps(families, output)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(
        f"wrote character texture source set: {len(families)} families, "
        f"{len(families) * len(MAPS)} maps, manifest={manifest_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
