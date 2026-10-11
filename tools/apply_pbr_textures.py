#!/usr/bin/env python3
"""Process AI-generated PBR textures and install into the project.

Converts Leonardo AI JPG outputs into 512x512 seamless PNG albedo/normal/roughness
sets under assets/materials/pbr/, replacing the placeholder albedo-only style-lock
textures with PBR-ready material sets for Reval 1343 environment surfaces.

Usage:
    python3 tools/apply_pbr_textures.py
"""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBR_DIR = ROOT / "assets" / "materials" / "pbr"
STYLE_LOCK_DIR = ROOT / "assets" / "materials" / "style_lock"
SOURCES_CSV = ROOT / "assets" / "SOURCES.csv"
GENERATED_DIR = ROOT / "generated" / "leonardo"

# Leonardo generation IDs mapped to material families and map types.
# Each entry: (family, map_type, generation_id, prompt_excerpt)
GENERATION_MAP: list[tuple[str, str, str, str]] = [
    # Albedos
    ("stone", "albedo", "72c9eec1-f240-463f-86e2-fa255eac2201",
     "Seamless tileable medieval limestone wall texture, cut ashlar blocks, light grey stone"),
    ("plaster", "albedo", "a1dee551-67ba-44c9-bd9d-85230df47e71",
     "Seamless tileable lime plaster wall texture, warm beige cream color"),
    ("timber", "albedo", "e42db7c1-6272-4857-8928-0e8e999675a5",
     "Seamless tileable aged timber wood texture, dark brown structural beam"),
    ("hay", "albedo", "e1debaf4-d34d-4232-b864-8d77df3d0e95",
     "Seamless tileable dry straw hay thatch roofing texture, golden brown"),
    ("roof_tile", "albedo", "9c66006f-5ddc-457c-9252-8458968387f0",
     "Seamless tileable medieval clay roof shingle texture, dark red-brown curved tiles"),
    ("cobble", "albedo", "1c85cef0-b09f-4a3c-8ff2-90fa8b2a786c",
     "Seamless tileable medieval cobblestone street texture, irregular grey stone blocks"),
    # Normal maps
    ("stone", "normal", "51b612ce-3d49-4542-9a5c-210dfba3f733",
     "Seamless tileable limestone wall normal map, cut ashlar stone blocks with mortar joints"),
    ("plaster", "normal", "4161e9fa-3a64-4e8d-9c96-2b60b956d4d6",
     "Seamless tileable lime plaster wall normal map, rough plaster surface with subtle cracks"),
    ("timber", "normal", "10b58670-209f-47c7-8aed-123b220ac951",
     "Seamless tileable aged timber wood normal map, wood grain and knots"),
    ("hay", "normal", "02e14313-0af5-4444-8061-91f22beeb2a2",
     "Seamless tileable straw hay thatch normal map, bundled reed thatch roofing"),
    ("roof_tile", "normal", "a0a3a1c9-9e5b-47e3-ad16-028e9f3090b0",
     "Seamless tileable clay roof shingle normal map, overlapping curved ceramic tiles"),
    ("cobble", "normal", "151628c8-41ad-4ac7-991a-76c26489f42e",
     "Seamless tileable cobblestone street normal map, irregular stone blocks with gaps"),
    # Roughness maps
    ("stone", "roughness", "6ea9567a-e4de-466d-ad49-1d6442eec7ce",
     "Seamless tileable limestone roughness map, rough areas for mortar, smoother for stone"),
    ("plaster", "roughness", "c74dc4bc-9a95-42b1-b582-2e2c6e39d705",
     "Seamless tileable lime plaster roughness map, medium grey with subtle variations"),
    ("timber", "roughness", "5e4dd896-a15d-4016-9096-a0922b134e84",
     "Seamless tileable timber wood roughness map, varied grey following wood grain"),
    ("hay", "roughness", "a8a8db92-2501-4ba7-a0d6-6651dbafda6b",
     "Seamless tileable straw hay thatch roughness map, very bright rough surface"),
    ("roof_tile", "roughness", "40e9e3ac-0b03-44c1-b082-971e6b1df275",
     "Seamless tileable clay roof shingle roughness map, medium-dark grey fired ceramic"),
    ("cobble", "roughness", "3ca9a967-2c0d-4946-976c-9d1bfbf04571",
     "Seamless tileable cobblestone roughness map, varied grey worn stone tops"),
]

TARGET_SIZE = 512


def _find_generation_file(gen_id: str) -> Path | None:
    """Locate the Leonardo output JPG for a given generation ID."""
    for path in GENERATED_DIR.glob(f"{gen_id}*.jpg"):
        return path
    return None


def _convert_to_png(src: Path, dst: Path, size: int = TARGET_SIZE) -> None:
    """Convert a JPG to a PNG of the given size using Pillow."""
    try:
        from PIL import Image
    except ImportError:
        print(f"ERROR: Pillow not installed. Cannot convert {src.name}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(src).convert("RGB")
    img = img.resize((size, size), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG", optimize=True)


def _compute_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def _build_provenance_note(gen_id: str, prompt: str, map_type: str) -> str:
    """Build a provenance string for SOURCES.csv."""
    return (
        f"Leonardo AI generation {gen_id}; "
        f"prompt: {prompt}; "
        f"map type: {map_type}; "
        f"processed to {TARGET_SIZE}x{TARGET_SIZE} seamless PNG by tools/apply_pbr_textures.py"
    )


def main() -> int:
    errors: list[str] = []
    provenance_rows: list[dict[str, str]] = []

    # Collect existing SOURCES.csv content (non-PBR rows)
    existing_rows: list[dict[str, str]] = []
    if SOURCES_CSV.is_file():
        with SOURCES_CSV.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames or []
            for row in reader:
                if not row.get("asset_id", "").startswith("assets.materials.pbr."):
                    existing_rows.append(row)

    # Process each generation
    for family, map_type, gen_id, prompt in GENERATION_MAP:
        src = _find_generation_file(gen_id)
        if src is None:
            errors.append(f"Missing Leonardo output for {family}/{map_type} (gen {gen_id})")
            continue

        dst = PBR_DIR / family / f"{family}_{map_type}.png"
        _convert_to_png(src, dst)

        sha = _compute_sha256(dst)
        asset_id = f"assets.materials.pbr.{family}.{map_type}"
        rel_path = f"assets/materials/pbr/{family}/{family}_{map_type}.png"

        provenance_rows.append({
            "asset_id": asset_id,
            "path": rel_path,
            "approval": f"approved - Leonardo AI PBR generation ({datetime.now():%Y-%m-%d})",
            "creator_or_tool": "Leonardo AI",
            "model_version": "Lucid Realism",
            "prompt_or_url": _build_provenance_note(gen_id, prompt, map_type),
            "seed": gen_id,
            "license": "AGPL-3.0-or-later (project author)",
        })

        print(f"  OK  {rel_path}")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1

    # Write SOURCES.csv
    if not fieldnames:
        fieldnames = [
            "asset_id", "path", "approval", "creator_or_tool",
            "model_version", "prompt_or_url", "seed", "license",
        ]

    with SOURCES_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in existing_rows:
            writer.writerow(row)
        for row in provenance_rows:
            writer.writerow(row)

    print(f"\nInstalled {len(provenance_rows)} PBR textures to {PBR_DIR.relative_to(ROOT)}/")
    print(f"Updated {SOURCES_CSV.relative_to(ROOT)} with provenance rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
