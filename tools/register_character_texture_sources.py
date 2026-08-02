#!/usr/bin/env python3
"""Register Godot-extracted character texture sidecars in assets/SOURCES.csv.

Every generated character GLB embeds the shared procedural detail maps from
tools/hero_body_textures.py (P0-144/P0-145). On import Godot extracts them as
``assets/characters/shared/<body>_hero_tex_<family>_<map>.png`` files; packed
roughness/AO is extracted as
``<body>_hero_tex_<family>_ao-hero_tex_<family>_roughness.png`` because glTF
stores the channels together. ``tools/validate_asset_sources.py`` requires a
provenance row per extracted sidecar.

Usage:
    python3 tools/register_character_texture_sources.py
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "assets" / "characters" / "shared"
SOURCES = ROOT / "assets" / "SOURCES.csv"

FAMILY_BLURB = {
    "cloth": "plain wool weave",
    "leather": "tanned leather grain and pores",
    "skin": "skin blotch, pores and freckles",
    "hair": "hair strand streaks",
    "metal": "brushed metal streaks and dents",
}


def _sidecar_metadata(stem: str) -> tuple[str, str]:
    """Return (material family, map label) for Godot's imported sidecar name.

    Blender's glTF exporter packs AO and roughness into one ORM image. Godot
    therefore extracts it as ``<family>_ao-<family>_roughness.png`` rather than
    preserving two separate source names.
    """
    prefix, _, suffix = stem.partition("_hero_tex_")
    if not suffix:
        raise ValueError(f"not a character texture sidecar: {stem}")
    if suffix.endswith("_albedo"):
        return suffix[: -len("_albedo")], "albedo"
    if suffix.endswith("_normal"):
        return suffix[: -len("_normal")], "normal"
    marker = "_ao-hero_tex_"
    if marker in suffix and suffix.endswith("_roughness"):
        family, _, packed_family = suffix.partition(marker)
        if packed_family[: -len("_roughness")] != family:
            raise ValueError(f"ORM family mismatch in sidecar: {stem}")
        return family, "ao_roughness_orm"
    raise ValueError(f"unknown character texture sidecar suffix: {stem}")


def main() -> int:
    sidecars = sorted(SHARED.glob("*_hero_tex_*_*.png"))
    if not sidecars:
        print("no character texture sidecars found; run Godot --import first")
        return 1

    with SOURCES.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    header, body = rows[0], rows[1:]
    existing = {row[0] for row in body if row}

    added_rows: list[list[str]] = []
    for path in sidecars:
        rel = path.relative_to(ROOT).as_posix()
        stem = path.stem
        try:
            family, map_type = _sidecar_metadata(stem)
        except ValueError as exc:
            print(f"warning: {exc}", file=sys.stderr)
            continue
        asset_id = f"assets.characters.shared.{stem}"
        if asset_id in existing:
            continue
        body_name = stem.split("_hero_tex_")[0]
        added_rows.append(
            [
                asset_id,
                rel,
                "project maintainer",
                "tools/hero_body_textures.py (numpy) + tools/generate_hero_body.py with Blender 5.2 headless",
                f"Embedded {family} {map_type} extracted from {body_name}.glb by Godot import",
                "not applicable",
                "AGPL-3.0-or-later (project author)",
                f"Deterministic 512 px procedural {FAMILY_BLURB.get(family, family)}; regenerate by rebuilding the character body.",
                f"approved - derived from {body_name}.glb",
            ]
        )

    if added_rows:
        # Append-only: rewriting the whole file with csv.writer can silently
        # drop quoting on existing fields that contain commas.
        with SOURCES.open("a", newline="", encoding="utf-8") as handle:
            csv.writer(handle).writerows(added_rows)
    print(f"added {len(added_rows)} SOURCES.csv rows ({len(sidecars)} sidecars scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
