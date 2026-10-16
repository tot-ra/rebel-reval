#!/usr/bin/env python3
"""Tileable PBR plate (albedo, normal, roughness) from one generated texture photo.

Pipeline: docs/SYSTEMS/EQUIPMENT_VARIANTS.md (task R-2003), prompts in
tools/assets/equipment/prompts.md. Use it for cloth, quilting, mail and
leather swatches for the fitted garments (garments.py), and for wood on
procedurally built parts (the ash spear shaft). The source comes from
Leonardo (Nano Banana, 1184x864 or 1248x832; square sizes are rejected) or
ComfyUI (tools/assets/equipment/comfyui_tileable_textile.json).

    python3 tools/assets/equipment/derive_tileable_pbr.py \\
        --src build/equipment_pilot/plates/ash_shaft_used_leonardo.jpg \\
        --out-dir assets/materials/equipment/ash_shaft_used --stem ash_shaft_used \\
        --size 512 --tint 0.86,0.74,0.58 --gain 0.82 --strength 2.0 --rough 0.78,0.12 \\
        --preview docs/reports/images/equipment/ash_shaft_used_plate.png

Steps: divide out the generator's broad lighting, quilt the wrap edges
seamless (the terrain-plate helpers in tools/process_leonardo_terrain_textures.py,
same code as tools/assets/derive_plate_normals.py), resize wrap-aware, tint
(generators drift pale and grey; the art bible wants undyed, woad, madder,
weathered ash), derive a wrap-around height from luminance, then the
OpenGL (+Y) normal and a roughness where hollows read rougher than crowns.
The preview is the plate tiled 2x2 next to its normal and roughness, so a
seam or a repeat blotch shows before the plate is wired.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from process_leonardo_terrain_textures import (  # noqa: E402
    _derive_height,
    _derive_normal,
    _flatten_lighting,
    _make_seamless,
    _resize_tileable,
)


def _floats(text: str) -> list[float]:
    return [float(v) for v in text.split(",")]


def derive(
    src: Path, size: int, tint: list[float], gain: float, strength: float, rough: list[float], blur: float
) -> tuple[Image.Image, Image.Image, Image.Image]:
    plate = Image.open(src).convert("RGB")
    # The terrain helpers work on a square plate; generators only give landscape sizes.
    side = min(plate.size)
    left, top = (plate.width - side) // 2, (plate.height - side) // 2
    plate = plate.crop((left, top, left + side, top + side))
    plate = _resize_tileable(_make_seamless(_flatten_lighting(plate)), size)
    albedo = np.asarray(plate, dtype=np.float64) / 255.0
    albedo = np.clip(albedo * np.array(tint) * gain, 0.0, 1.0)
    height = _derive_height(albedo, blur)
    normal = _derive_normal(height, strength)
    base, spread = rough
    # Hollows (low height) hold grime and fibre ends: rougher than worn crowns.
    roughness = np.clip(base + spread * (0.5 - height) * 2.0, 0.0, 1.0)
    to8 = lambda a: Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8))  # noqa: E731
    return to8(albedo), to8(normal), to8(roughness)


def preview(albedo: Image.Image, normal: Image.Image, roughness: Image.Image) -> Image.Image:
    s = albedo.width
    sheet = Image.new("RGB", (s * 4, s * 2))
    for dx in (0, 1):
        for dy in (0, 1):
            sheet.paste(albedo, (dx * s, dy * s))
    sheet.paste(normal.resize((s, s)), (s * 2, 0))
    sheet.paste(roughness.convert("RGB"), (s * 3, 0))
    sheet.paste(albedo, (s * 2, s))
    return sheet


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--stem", required=True)
    p.add_argument("--size", type=int, default=1024)
    p.add_argument("--tint", default="1,1,1", help="per-channel multiply r,g,b")
    p.add_argument("--gain", type=float, default=1.0, help="overall albedo multiply")
    p.add_argument("--strength", type=float, default=2.0, help="normal strength")
    p.add_argument("--rough", default="0.85,0.08", help="roughness base,spread")
    p.add_argument("--blur", type=float, default=1.0, help="height detail blur px")
    p.add_argument("--preview", default="")
    a = p.parse_args()
    albedo, normal, roughness = derive(
        Path(a.src), a.size, _floats(a.tint), a.gain, a.strength, _floats(a.rough), a.blur
    )
    out = ROOT / a.out_dir
    out.mkdir(parents=True, exist_ok=True)
    albedo.save(out / f"{a.stem}_albedo.png")
    normal.save(out / f"{a.stem}_normal.png")
    roughness.convert("L").save(out / f"{a.stem}_roughness.png")
    if a.preview:
        (ROOT / a.preview).parent.mkdir(parents=True, exist_ok=True)
        preview(albedo, normal, roughness).save(ROOT / a.preview)
    mean = np.asarray(albedo, dtype=np.float64).reshape(-1, 3).mean(0) / 255.0
    print(f"PLATE {a.stem} {a.size}px albedo_mean_srgb={[round(v, 3) for v in mean]} -> {a.out_dir}")


main()
