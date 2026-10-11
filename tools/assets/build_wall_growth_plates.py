#!/usr/bin/env python3
"""Build the wall moss and lichen plates (R-1661 follow-up, LIVING_VEGETATION.md).

Procedural noise moss read as a flat green film over the masonry. The wall
shader now samples two photographic plates instead:

- wall_moss_albedo.png: cushion moss, RGB colour, A = cushion height. The
  shader thresholds A against its coverage mask, so the moss edge follows
  real cushion outlines and the stone shows in the gaps between cushions.
- wall_moss_normal.png: tangent normal from the same height (OpenGL, +Y up).
- wall_lichen.png: crustose rosettes, RGB colour, A = rosette mask cut out
  of the grey stone the generator painted them on.

Sources (OpenAI gpt-image-1, generated/openai/wall_growth_v1/) are quilted
seamless with the CO-01 terrain helpers.

Run from the repository root:
    python3 tools/assets/build_wall_growth_plates.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from process_leonardo_terrain_textures import (  # noqa: E402
    _derive_normal,
    _make_seamless,
    _resize_tileable,
    _to_image,
    _wrap_blur,
)

SOURCE_DIR = ROOT / "generated" / "openai" / "wall_growth_v1"
OUT_DIR = ROOT / "assets" / "materials" / "pbr" / "wall_growth"
SIZE = 512
LUMA = np.array([0.2126, 0.7152, 0.0722])


def _plate(name: str) -> np.ndarray:
    plate = _make_seamless(Image.open(SOURCE_DIR / name).convert("RGB"))
    return np.asarray(_resize_tileable(plate, SIZE), dtype=np.float64) / 255.0


def _normalise(values: np.ndarray, lo_pct: float, hi_pct: float) -> np.ndarray:
    lo, hi = np.percentile(values, [lo_pct, hi_pct])
    return np.clip((values - lo) / max(hi - lo, 1e-4), 0.0, 1.0)


def _bleed(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Fill uncovered texels from covered neighbours so mips do not pull in grey stone."""
    coverage = np.maximum(_wrap_blur(mask, 6.0), 1e-4)
    surround = np.stack([_wrap_blur(rgb[..., c] * mask, 6.0) / coverage for c in range(3)], axis=-1)
    weight = mask[..., None]
    return rgb * weight + surround * (1.0 - weight)


def moss() -> None:
    albedo = _plate("moss_candidate_1.png")
    luminance = (albedo * LUMA).sum(axis=-1)
    # Cushion height: the plate's own shading (lit crowns, dark gaps) at cushion
    # scale, plus a little shoot-level grain so the edge is fringed, not smooth.
    cushion = _normalise(_wrap_blur(luminance, 5.0), 2.0, 98.0)
    grain = _normalise(luminance - _wrap_blur(luminance, 2.0), 1.0, 99.0) - 0.5
    height = np.clip(cushion + grain * 0.18, 0.0, 1.0)
    # The generator baked strong crown highlights; ease them so the scene light
    # does the shading, and the normal map carries the relief.
    flat = albedo / np.maximum(_wrap_blur(luminance, 12.0)[..., None] * 1.6, 0.35)
    flat = np.clip(flat * float(luminance.mean()) * 1.6, 0.0, 1.0)
    colour = albedo * 0.45 + flat * 0.55
    rgba = np.concatenate([colour, height[..., None]], axis=-1)
    _to_image(rgba, "RGBA").save(OUT_DIR / "wall_moss_albedo.png", optimize=True)
    normal = _derive_normal(_wrap_blur(height, 1.0), 4.0)
    _to_image(normal, "RGB").save(OUT_DIR / "wall_moss_normal.png", optimize=True)
    print("wrote wall_moss_albedo.png + wall_moss_normal.png")


def lichen() -> None:
    albedo = _plate("lichen_candidate_1.png")
    luminance = (albedo * LUMA).sum(axis=-1)
    saturation = albedo.max(axis=-1) - albedo.min(axis=-1)
    # Rosettes are paler than the stone around them; Xanthoria spots are vivid.
    # The high-pass radius is wider than a rosette, so the crust's own mean does
    # not hollow its centre into a ring.
    pale = _normalise(luminance - _wrap_blur(luminance, 48.0), 62.0, 88.0)
    orange = np.clip((albedo[..., 0] - albedo[..., 2] - 0.2) * 5.0, 0.0, 1.0) * np.clip(saturation * 4.0, 0.0, 1.0)
    mask = np.clip(np.maximum(_wrap_blur(pale, 1.2), orange), 0.0, 1.0)
    mask = np.clip((mask - 0.25) / 0.5, 0.0, 1.0)
    # Close the rosettes: their textured centres fall below the high-pass and
    # read as hollow rings (soap bubbles) on the wall.
    mask = np.maximum(mask, np.clip((_wrap_blur(mask, 3.0) - 0.3) * 2.5, 0.0, 1.0))
    rgba = np.concatenate([_bleed(albedo, mask), mask[..., None]], axis=-1)
    _to_image(rgba, "RGBA").save(OUT_DIR / "wall_lichen.png", optimize=True)
    print(f"wrote wall_lichen.png (coverage {mask.mean():.2f})")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    moss()
    lichen()


if __name__ == "__main__":
    main()
