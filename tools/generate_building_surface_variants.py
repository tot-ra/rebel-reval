#!/usr/bin/env python3
"""Paint the tileable building wall/roof surface library.

Leonardo is unavailable in this session. Reuse the burgher-house kit painter so
new maps stay in the same 1343 limestone / limewash / tile / shingle / thatch
language. Host python stubs bpy only to import the numpy surfaces.

Every stem ships three maps (AR-03, board row R-961):
- ``<stem>_albedo.png`` - sRGB colour;
- ``<stem>_normal.png`` - OpenGL (+Y) tangent-space normal;
- ``<stem>_orm.png`` - packed R = ambient occlusion, G = roughness,
  B = metallic (always 0), the same ORM order glTF and
  ``tools/assets/prop_orm_baking.py`` use, so one file carries both channels.

``building_macro_variation.png`` is the shared low-frequency tone plate that
the Godot side samples at a second, non-commensurate world scale to break the
visible repeat of a long wall or roof (anti-tiling detail blend).

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
    # AR-03 families so every authored wall_material / roof_material value has
    # a real surface set instead of a tint over a procedural pattern.
    ("ashlar", "ashlar_pale", (1.06, 1.05, 1.0)),
    ("ashlar", "ashlar_buff", (1.04, 0.96, 0.82)),
    ("ashlar", "ashlar_grey", (0.88, 0.88, 0.86)),
    ("boards", "plank_vertical", (1.0, 1.0, 1.0)),
    ("boards_horizontal", "plank_horizontal", (1.0, 0.96, 0.9)),
    ("boards", "plank_tarred", (0.62, 0.54, 0.46)),
    ("daub", "daub_clay", (1.0, 1.0, 1.0)),
    ("wattle", "daub_wattle", (1.0, 0.98, 0.94)),
    ("daub", "daub_straw", (1.08, 1.02, 0.86)),
    ("brick", "brick_red", (1.0, 1.0, 1.0)),
    ("brick", "brick_dark", (0.8, 0.74, 0.7)),
    ("brick", "brick_salmon", (1.1, 0.96, 0.86)),
    ("straw", "straw_gold", (1.04, 1.0, 0.86)),
    ("straw", "straw_grey", (0.84, 0.84, 0.8)),
    ("straw", "straw_brown", (0.9, 0.8, 0.66)),
    ("soot", "soot_black", (0.9, 0.88, 0.86)),
    ("soot", "soot_brown", (1.0, 0.92, 0.82)),
    ("soot", "soot_grey", (1.02, 1.02, 1.0)),
    ("gable_board", "gable_board_silver", (1.0, 1.0, 1.0)),
    ("gable_board", "gable_board_oak", (1.08, 0.94, 0.78)),
    ("gable_board", "gable_board_tarred", (0.64, 0.56, 0.48)),
    ("log_course", "logwall_pine", (1.04, 0.92, 0.7)),
    ("log_course", "logwall_weathered", (0.92, 0.9, 0.86)),
    ("log_course", "logwall_tar", (0.7, 0.62, 0.52)),
)

# Roughness profile per painter kind: (base, relief range). Relief lowers
# roughness on proud faces (weather-polished stone, worn tile crowns) and
# raises it in joints and cavities, which is how the eye separates materials
# that share a hue. Values follow tools/assets/prop_orm_baking.py profiles.
ROUGHNESS_PROFILES: dict[str, tuple[float, float]] = {
    "tile": (0.66, 0.16),
    "shingle": (0.8, 0.12),
    "thatch": (0.94, 0.05),
    "straw": (0.95, 0.04),
    "rubble": (0.86, 0.12),
    "ashlar": (0.74, 0.12),
    "render": (0.9, 0.06),
    "limewash": (0.93, 0.05),
    "soot": (0.82, 0.08),
    "log": (0.8, 0.12),
    "log_course": (0.8, 0.14),
    "boards": (0.84, 0.1),
    "boards_horizontal": (0.84, 0.1),
    "gable_board": (0.86, 0.1),
    "daub": (0.95, 0.04),
    "wattle": (0.92, 0.06),
    "brick": (0.8, 0.14),
}
# Stem-specific finish: pine tar and tarred boards read glossier than bare
# weathered wood; everything else uses its kind profile unchanged.
STEM_ROUGHNESS_BIAS: dict[str, float] = {
    "log_tar": -0.22,
    "logwall_tar": -0.22,
    "plank_tarred": -0.2,
    "gable_board_tarred": -0.2,
    "log_weathered": 0.06,
    "logwall_weathered": 0.06,
    "tile_moss": 0.08,
    "shingle_moss": 0.06,
}
# Cavity occlusion depth per kind: deep joints (tile, brick, log seams) darken
# more than a lime coat.
AO_DEPTH: dict[str, float] = {
    "tile": 0.55,
    "shingle": 0.45,
    "brick": 0.5,
    "log_course": 0.5,
    "rubble": 0.45,
    "ashlar": 0.35,
    "boards": 0.3,
    "boards_horizontal": 0.3,
    "gable_board": 0.35,
}
MACRO_NAME = "building_macro_variation.png"
MACRO_SIZE = 256

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


def _box_blur(field: np.ndarray, radius: int) -> np.ndarray:
    """Wrap-around box blur so the derived maps stay tileable."""
    out = field.astype(np.float32)
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for offset in range(-radius, radius + 1):
            acc += np.roll(out, offset, axis=axis)
        out = acc / float(2 * radius + 1)
    return out


def orm_from_height(
    kit, kind: str, stem: str, height: np.ndarray, size: int
) -> np.ndarray:
    """Pack AO (R), roughness (G) and metallic (B = 0) from the relief height."""
    low, high = float(height.min()), float(height.max())
    norm = (height - low) / max(high - low, 1e-6)
    radius = max(2, size // 128)
    cavity = np.clip(_box_blur(norm, radius) - norm, 0.0, 1.0)
    ao = np.clip(1.0 - AO_DEPTH.get(kind, 0.25) * cavity * 4.0, 0.35, 1.0)
    base, relief = ROUGHNESS_PROFILES[kind]
    base += STEM_ROUGHNESS_BIAS.get(stem, 0.0)
    # Separate rng stream so adding ORM never changes the albedo/normal bytes.
    micro = kit._fbm(size, kit._np_rng(f"building_variant_orm:{stem}"), 32, octaves=3)
    roughness = base + relief * (0.5 - norm) + 0.06 * (micro - 0.5)
    roughness = np.clip(roughness, 0.18, 1.0)
    metallic = np.zeros_like(norm)
    return np.stack((ao, roughness, metallic), axis=-1)


def macro_variation(kit) -> np.ndarray:
    """Low-frequency tone plate for the anti-tiling detail blend.

    Values stay in [0.86, 1.0] so a multiply blend only shades; the Godot side
    lifts albedo by the plate mean so overall exposure is unchanged.
    """
    rng = kit._np_rng("building_macro_variation")
    broad = kit._fbm(MACRO_SIZE, rng, 3, octaves=4)
    blotch = kit._fbm(MACRO_SIZE, rng, 7, octaves=3)
    tone = 0.55 * broad + 0.45 * blotch
    tone = (tone - tone.min()) / max(float(tone.max() - tone.min()), 1e-6)
    value = 0.86 + 0.14 * tone
    return np.stack((value, value, value), axis=-1)


def generate(kit) -> list[Path]:
    written: list[Path] = []
    for kind, stem, tint in VARIANTS:
        rng = kit._np_rng(f"building_variant:{stem}")
        rgb, height = kit.surface_texture(kind, rng, SIZE)
        rgb = np.clip(rgb * np.array(tint, dtype=np.float32), 0.0, 1.0)
        normal = kit._normal_from_height(height, 6.0 if kind in {"tile", "shingle", "thatch", "straw"} else 5.0)
        orm = orm_from_height(kit, kind, stem, height, height.shape[0])
        albedo_path = OUT_DIR / f"{stem}_albedo.png"
        normal_path = OUT_DIR / f"{stem}_normal.png"
        orm_path = OUT_DIR / f"{stem}_orm.png"
        _write_png(albedo_path, _to_image(rgb))
        _write_png(normal_path, _to_image(normal))
        _write_png(orm_path, _to_image(orm))
        written.extend((albedo_path, normal_path, orm_path))
    macro_path = OUT_DIR / MACRO_NAME
    _write_png(macro_path, _to_image(macro_variation(kit)))
    written.append(macro_path)
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
        if path.name == MACRO_NAME:
            family, map_kind = "macro_variation", "detail"
        else:
            family, map_kind = stem.rsplit("_", 1)
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
                    "AR-03 building surface library: tileable 1343 wall/roof "
                    "map shared by every building material; reproducible from "
                    "tools/generate_building_surface_variants.py."
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
