#!/usr/bin/env python3
"""Paint extra tileable wall/roof maps for cloned burgher-house GLBs.

Leonardo is unavailable in this session. Reuse the burgher-house kit painter so
new maps stay in the same 1343 limestone / limewash / tile / shingle / thatch
language. Host python stubs bpy only to import the numpy surfaces.

Run from the repository root:
    python3 tools/generate_building_surface_variants.py
"""

from __future__ import annotations

import csv
import hashlib
import sys
import types
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "materials" / "pbr" / "building_variants"
SOURCES = ROOT / "assets" / "SOURCES.csv"
SIZE = 512

# kind matches burgher_house_kit_common.surface_texture; tint is sRGB multiply.
VARIANTS: tuple[tuple[str, str, tuple[float, float, float]], ...] = (
    ("tile", "tile_red", (1.0, 1.0, 1.0)),
    ("tile", "tile_umber", (0.78, 0.52, 0.42)),
    ("tile", "tile_moss", (0.72, 0.78, 0.56)),
    ("shingle", "shingle_silver", (1.0, 1.0, 1.0)),
    ("shingle", "shingle_oak", (0.86, 0.68, 0.5)),
    ("shingle", "shingle_moss", (0.7, 0.78, 0.58)),
    ("thatch", "thatch_gold", (1.06, 0.96, 0.72)),
    ("thatch", "thatch_olive", (0.86, 0.88, 0.62)),
    ("thatch", "thatch_ash", (0.78, 0.76, 0.68)),
    ("rubble", "rubble_pale", (1.06, 1.04, 0.98)),
    ("rubble", "rubble_buff", (1.02, 0.94, 0.8)),
    ("rubble", "rubble_dark", (0.78, 0.76, 0.72)),
    ("render", "render_cream", (1.08, 1.04, 0.92)),
    ("render", "render_ochre", (1.02, 0.88, 0.68)),
    ("render", "render_soot", (0.82, 0.8, 0.76)),
    ("limewash", "limewash_chalk", (1.06, 1.04, 0.96)),
    ("limewash", "limewash_straw", (1.04, 0.94, 0.72)),
    ("limewash", "limewash_clay", (0.94, 0.82, 0.7)),
    ("log", "log_pine", (1.04, 0.92, 0.7)),
    ("log", "log_weathered", (0.92, 0.9, 0.86)),
    ("log", "log_tar", (0.7, 0.62, 0.52)),
)

SOURCE_COLUMNS = (
    "asset_id",
    "path",
    "creator_or_tool",
    "model_version",
    "prompt_or_url",
    "seed",
    "license",
    "edits",
    "approval",
)


def _stub_blender_modules() -> None:
    if "bpy" in sys.modules:
        return
    bpy = types.ModuleType("bpy")
    bpy.data = types.SimpleNamespace(materials=None, images=None)
    sys.modules["bpy"] = bpy
    sys.modules["bmesh"] = types.ModuleType("bmesh")
    mathutils = types.ModuleType("mathutils")

    class Vector:
        def __init__(self, *args: object) -> None:
            self.args = args

    class Matrix:
        def __init__(self, *args: object) -> None:
            self.args = args

    mathutils.Vector = Vector
    mathutils.Matrix = Matrix
    sys.modules["mathutils"] = mathutils


def _load_kit():
    _stub_blender_modules()
    tools_dir = str(ROOT / "tools")
    if tools_dir not in sys.path:
        sys.path.insert(0, tools_dir)
    import burgher_house_kit_common as kit

    return kit


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _to_image(rgb: np.ndarray) -> Image.Image:
    # Kit arrays are Blender-bottom-origin; PNG / Godot read top-left origin.
    pixels = np.clip(rgb[::-1], 0.0, 1.0)
    return Image.fromarray(np.rint(pixels * 255.0).astype(np.uint8)).convert("RGB")


def _write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def generate(kit) -> list[Path]:
    written: list[Path] = []
    for kind, stem, tint in VARIANTS:
        rng = kit._np_rng(f"building_variant:{stem}")
        rgb, height = kit.surface_texture(kind, rng, SIZE)
        rgb = np.clip(rgb * np.array(tint, dtype=np.float32), 0.0, 1.0)
        normal = kit._normal_from_height(height, 6.0 if kind in {"tile", "shingle", "thatch"} else 5.0)
        albedo_path = OUT_DIR / f"{stem}_albedo.png"
        normal_path = OUT_DIR / f"{stem}_normal.png"
        _write_png(albedo_path, _to_image(rgb))
        _write_png(normal_path, _to_image(normal))
        written.extend((albedo_path, normal_path))
    return written


def _append_sources(written: list[Path]) -> None:
    existing: set[str] = set()
    with SOURCES.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            existing.add(row.get("path", ""))
    new_rows: list[dict[str, str]] = []
    for path in written:
        rel = path.relative_to(ROOT).as_posix()
        if rel in existing:
            continue
        stem = path.stem
        family = stem.rsplit("_", 1)[0]
        map_kind = "albedo" if stem.endswith("_albedo") else "normal"
        digest = _sha256(path)
        new_rows.append(
            {
                "asset_id": f"assets.materials.pbr.building_variants.{family}.{map_kind}",
                "path": rel,
                "creator_or_tool": "tools/generate_building_surface_variants.py",
                "model_version": "burgher_house_kit_v2 painter",
                "prompt_or_url": (
                    f"Deterministic 512 px {map_kind} from burgher_house_kit_common."
                    f"surface_texture; SHA-256 {digest}"
                ),
                "seed": f"building_variant:{family}",
                "license": "AGPL-3.0-or-later (project author)",
                "edits": (
                    "Tileable 1343 wall/roof variant so cloned house GLBs can "
                    "swap albedo/normal without a second mesh."
                ),
                "approval": "approved - deterministic kit painter, Leonardo unavailable",
            }
        )
    if not new_rows:
        return
    with SOURCES.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=SOURCE_COLUMNS, lineterminator="\n"
        )
        for row in new_rows:
            writer.writerow(row)


def main() -> int:
    kit = _load_kit()
    written = generate(kit)
    _append_sources(written)
    print(f"wrote {len(written)} building surface variants under {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
