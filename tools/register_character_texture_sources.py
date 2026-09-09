#!/usr/bin/env python3
"""Register shared character family textures in assets/SOURCES.csv.

Runtime humanoid GLBs URI-reference ``assets/characters/shared/textures/hero_tex_*.png``.
Per-body Godot extracts (``<body>_hero_tex_*.png``) are not provenance sources
and are removed from the manifest when this script runs.

Usage:
    python3 tools/register_character_texture_sources.py
"""

from __future__ import annotations

import csv
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "assets" / "characters" / "shared"
TEXTURE_DIR = SHARED / "textures"
SOURCES = ROOT / "assets" / "SOURCES.csv"

FAMILY_BLURB = {
    "cloth": "plain wool weave",
    "leather": "tanned leather grain and pores",
    "skin": "skin blotch, pores and freckles",
    "hair": "hair strand streaks",
    "metal": "brushed metal streaks and dents",
}


def _sidecar_metadata(stem: str) -> tuple[str, str]:
    """Return (material family, map label) for a shared or extracted sidecar name."""
    suffix = stem
    if "_hero_tex_" in stem:
        suffix = stem.split("_hero_tex_", 1)[1]
        suffix = f"hero_tex_{suffix}" if not suffix.startswith("hero_tex_") else suffix
    if not suffix.startswith("hero_tex_"):
        raise ValueError(f"not a character texture sidecar: {stem}")
    body = suffix[len("hero_tex_") :]
    if body.endswith("_albedo"):
        return body[: -len("_albedo")], "albedo"
    if body.endswith("_normal"):
        return body[: -len("_normal")], "normal"
    marker = "_ao-hero_tex_"
    if marker in body and body.endswith("_roughness"):
        family, _, packed_family = body.partition(marker)
        if packed_family[: -len("_roughness")] != family:
            raise ValueError(f"ORM family mismatch in sidecar: {stem}")
        return family, "ao_roughness_orm"
    raise ValueError(f"unknown character texture sidecar suffix: {stem}")


def _is_extracted_sidecar_row(line: str) -> bool:
    return (
        "assets/characters/shared/" in line
        and "_hero_tex_" in line
        and "assets/characters/shared/textures/" not in line
    )


def _shared_row(path: Path) -> list[str]:
    rel = path.relative_to(ROOT).as_posix()
    family, map_type = _sidecar_metadata(path.stem)
    return [
        f"assets.characters.shared.textures.{path.stem}",
        rel,
        "project maintainer",
        "tools/hero_body_textures.py (numpy) + tools/share_character_textures.py",
        f"Shared {family} {map_type} referenced by generated humanoid GLBs",
        "not applicable",
        "AGPL-3.0-or-later (project author)",
        f"Deterministic 512 px procedural {FAMILY_BLURB.get(family, family)}; regenerate by rebuilding any character body.",
        "approved - shared family map",
    ]


def main() -> int:
    textures = sorted(TEXTURE_DIR.glob("hero_tex_*.png"))
    if not textures:
        print("no shared character textures found; run tools/share_character_textures.py --apply first")
        return 1

    raw = SOURCES.read_bytes()
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    text = raw.decode("utf-8")
    lines = text.splitlines()
    kept: list[str] = []
    existing_ids: set[str] = set()
    for line in lines:
        if _is_extracted_sidecar_row(line):
            continue
        kept.append(line)
        if line and "," in line:
            existing_ids.add(line.split(",", 1)[0])

    added = 0
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    for path in textures:
        row = _shared_row(path)
        if row[0] in existing_ids:
            continue
        writer.writerow(row)
        added += 1
        existing_ids.add(row[0])
    extra = buf.getvalue().splitlines()
    kept.extend(extra)
    body = ("\n".join(kept) + "\n").encode("utf-8")
    if newline == b"\r\n":
        body = body.replace(b"\n", b"\r\n")
    SOURCES.write_bytes(body)
    print(
        f"shared texture provenance: {len(textures)} files, "
        f"added {added} SOURCES.csv rows, removed extracted sidecar rows"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
