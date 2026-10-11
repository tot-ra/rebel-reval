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

- wall_moss_feather_albedo.png / _normal.png (R-1747): flat interwoven feather
  moss carpet (Hypnum, Brachythecium), the main bark species.
- wall_moss_grimmia_albedo.png / _normal.png (R-1747): small hoary Grimmia
  cushions of limestone and roofs.

Sources (OpenAI gpt-image-1, generated/openai/wall_growth_v1/; Leonardo
Nano Banana, generated/leonardo/wall_growth_v2/) are quilted seamless with the
CO-01 terrain helpers.

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
SOURCE_DIR_V2 = ROOT / "generated" / "leonardo" / "wall_growth_v2"
OUT_DIR = ROOT / "assets" / "materials" / "pbr" / "wall_growth"
SIZE = 512
LUMA = np.array([0.2126, 0.7152, 0.0722])


def _plate(name: str, source_dir: Path = SOURCE_DIR, crop: float = 1.0) -> np.ndarray:
    image = Image.open(source_dir / name).convert("RGB")
    if crop < 1.0:
        # Drop a frame border the generator filled with substrate (bark corner).
        side = int(min(image.size) * crop)
        left = (image.width - side) // 2
        top = (image.height - side) // 2
        image = image.crop((left, top, left + side, top + side))
    plate = _make_seamless(image)
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


def _cushion_height(luminance: np.ndarray, mix: tuple[float, float, float, float] = (0.4, 0.3, 0.3, 0.22)) -> np.ndarray:
    """Cushion height from plate luminance, several scales at once.

    R-1747: one blur radius made every cushion the same dome, and the photo's
    lit side made each dome a crescent; thresholded on a wall they read as
    rows of identical half-circle scales. Mixing a small, a medium and a broad
    radius plus shoot grain gives tufts of mixed size with fringed outlines.
    """
    small = _normalise(_wrap_blur(luminance, 2.5), 2.0, 98.0)
    medium = _normalise(_wrap_blur(luminance, 7.0), 2.0, 98.0)
    broad = _normalise(_wrap_blur(luminance, 18.0), 2.0, 98.0)
    grain = _normalise(luminance - _wrap_blur(luminance, 1.5), 1.0, 99.0) - 0.5
    w_small, w_medium, w_broad, w_grain = mix
    return np.clip(small * w_small + medium * w_medium + broad * w_broad + grain * w_grain, 0.0, 1.0)


def _moss_plate(
    albedo: np.ndarray,
    stem: str,
    normal_strength: float = 4.0,
    mix: tuple[float, float, float, float] = (0.4, 0.3, 0.3, 0.22),
    close: bool = False,
) -> None:
    luminance = (albedo * LUMA).sum(axis=-1)
    height = _cushion_height(luminance, mix)
    if close:
        # Hoary hair-points make cushion rims brighter than their centres; a
        # thresholded rim reads as an empty ring. Fill each cushion up to its rim.
        height = np.maximum(height, np.clip((_wrap_blur(height, 5.0) - 0.15) * 1.5, 0.0, 1.0))
    # The generator baked strong crown highlights; ease them so the scene light
    # does the shading, and the normal map carries the relief.
    flat = albedo / np.maximum(_wrap_blur(luminance, 12.0)[..., None] * 1.6, 0.35)
    flat = np.clip(flat * float(luminance.mean()) * 1.6, 0.0, 1.0)
    colour = albedo * 0.45 + flat * 0.55
    rgba = np.concatenate([colour, height[..., None]], axis=-1)
    _to_image(rgba, "RGBA").save(OUT_DIR / f"{stem}_albedo.png", optimize=True)
    normal = _derive_normal(_wrap_blur(height, 1.0), normal_strength)
    _to_image(normal, "RGB").save(OUT_DIR / f"{stem}_normal.png", optimize=True)
    print(f"wrote {stem}_albedo.png + {stem}_normal.png")


def moss() -> None:
    _moss_plate(_plate("moss_candidate_1.png"), "wall_moss")


def moss_species() -> None:
    # A carpet, not cushions: the height follows broad mat thickness, so a low
    # cover leaves ragged mat patches instead of a glitter of lit frond tips.
    _moss_plate(
        _plate("feather_candidate_1.jpg", SOURCE_DIR_V2, crop=0.86), "wall_moss_feather", 3.0, (0.12, 0.3, 0.58, 0.1)
    )
    _moss_plate(_plate("grimmia_candidate_1.jpg", SOURCE_DIR_V2), "wall_moss_grimmia", 4.0, (0.15, 0.45, 0.4, 0.06), close=True)


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
    moss_species()
    lichen()


if __name__ == "__main__":
    main()
