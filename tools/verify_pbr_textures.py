#!/usr/bin/env python3
"""Verify P0-130 PBR texture set presence, dimensions, and provenance.

Checks that every material family under ``assets/materials/pbr/`` ships the
required albedo/normal/roughness triplet at 512x512 PNG and carries a
provenance row in ``assets/SOURCES.csv``.

Usage:
    python3 tools/verify_pbr_textures.py
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBR_DIR = ROOT / "assets" / "materials" / "pbr"
SOURCES = ROOT / "assets" / "SOURCES.csv"
SOURCE_ID_PREFIX = "assets.materials.pbr."

REQUIRED_FAMILIES = (
    "stone",
    "plaster",
    "timber",
    "hay",
    "roof_tile",
    "cobble",
)

MAP_TYPES = ("albedo", "normal", "roughness")
TEXTURE_SIZE = 512


def png_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.relative_to(ROOT)} is not a PNG")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return width, height


def _read_pbr_sources() -> set[str]:
    """Return set of asset_id values that match the PBR prefix."""
    if not SOURCES.is_file():
        return set()
    ids: set[str] = set()
    with SOURCES.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            aid = row.get("asset_id", "")
            if aid.startswith(SOURCE_ID_PREFIX):
                ids.add(aid)
    return ids


def validate() -> list[str]:
    errors: list[str] = []
    source_ids = _read_pbr_sources()

    for family in REQUIRED_FAMILIES:
        family_dir = PBR_DIR / family
        if not family_dir.is_dir():
            errors.append(f"missing PBR family directory: assets/materials/pbr/{family}/")
            continue

        for map_type in MAP_TYPES:
            rel_path = f"assets/materials/pbr/{family}/{family}_{map_type}.png"
            abs_path = ROOT / rel_path

            if not abs_path.is_file():
                errors.append(f"missing PBR texture: {rel_path}")
                continue

            try:
                width, height = png_dimensions(abs_path)
            except ValueError as exc:
                errors.append(str(exc))
                continue

            if width != TEXTURE_SIZE or height != TEXTURE_SIZE:
                errors.append(
                    f"{rel_path}: expected {TEXTURE_SIZE}x{TEXTURE_SIZE}, got {width}x{height}"
                )

            asset_id = f"{SOURCE_ID_PREFIX}{family}.{map_type}"
            if asset_id not in source_ids:
                errors.append(f"missing SOURCES.csv provenance row for {asset_id}")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("PBR texture verification failed:")
        for e in errors:
            print(f"  - {e}")
        return 1

    count = len(REQUIRED_FAMILIES) * len(MAP_TYPES)
    print(
        f"PBR texture verification passed "
        f"({count} textures across {len(REQUIRED_FAMILIES)} families; provenance ok)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
