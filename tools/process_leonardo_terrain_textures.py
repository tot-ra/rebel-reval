#!/usr/bin/env python3
"""Prepare selected Leonardo terrain albedos for the Godot runtime.

The generator output is treated as an authored candidate, not as a drop-in
runtime texture: it is resized with Lanczos and moved to a half-tile phase so
large AI marks do not sit on the wrap seam. The final border pixels are welded
for deterministic repeatability.

Two tiers:

- Legacy families (timber, cobble, hay, ...) keep their 512 px albedo-only
  output. Runtime terrain resizes these to its 128 px texture-array tier.
- CO-01 ground families (coast_sand, sand, shore_shingle, mud, grass) ship a
  2048 px albedo plus a normal and a roughness map derived from the same plate.
  Leonardo cannot bake matching normal/roughness plates, so both are computed
  from a wrap-aware height estimate of the selected albedo (see
  `_derive_height`). The blend shader samples these per fragment.

Usage:
    python3 tools/process_leonardo_terrain_textures.py            # every family
    python3 tools/process_leonardo_terrain_textures.py --only sand mud
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "generated" / "leonardo"
PBR = ROOT / "assets" / "materials" / "pbr"
OUTPUTS = {
    "limestone_rubble": (
        GENERATED / "city_wall_limestone_v1" / "candidate_1.jpg",
        PBR / "limestone_rubble/limestone_rubble_albedo.png",
    ),
    "timber": (
        GENERATED / "timber_beam_v2" / "candidate_2.jpg",
        PBR / "timber/timber_albedo.png",
    ),
    "timber_floor": (
        GENERATED / "timber_floor_v2" / "candidate_1.jpg",
        PBR / "timber_floor/timber_floor_albedo.png",
    ),
    "cobble": (
        GENERATED / "cobble_street_v3" / "candidate_2.jpg",
        PBR / "cobble/cobble_albedo.png",
    ),
    "smithy_floor": (
        GENERATED / "smithy_flagstone_v3" / "candidate_2.jpg",
        PBR / "smithy_floor/smithy_floor_albedo.png",
    ),
    "hay": (
        GENERATED / "hay_thatch_v2" / "candidate_2.jpg",
        PBR / "hay/hay_albedo.png",
    ),
}
TARGET_SIZE = 512

## CO-01 (R-948) ground families. Every entry ships a GROUND_TARGET_SIZE albedo
## plus normal and roughness at GROUND_DERIVED_SIZE. The Leonardo realism model
## tops out at 1536 px, so the albedo is upscaled once with Lanczos. Derived maps
## stay at 1024: a 2048 normal of a noisy natural plate is 10-11 MiB as PNG, over
## the standard-Git limit in docs/ASSET_STORAGE_POLICY.md, and it would only
## resolve JPEG noise of the 1536 source (decision recorded in
## docs/reports/co01_coastal_ground_materials.md).
GROUND_TARGET_SIZE = 2048
GROUND_DERIVED_SIZE = 1024
GROUND_OUTPUTS = {
    "coast_sand": GENERATED / "coast_sand_foreshore_v1" / "candidate_2.jpg",
    "sand": GENERATED / "sand_upper_beach_v1" / "candidate_2.jpg",
    "shore_shingle": GENERATED / "shore_shingle_v1" / "candidate_2.jpg",
    "mud": GENERATED / "mud_tidal_yard_v3" / "candidate_2.jpg",
    "grass": GENERATED / "grass_meadow_v4" / "candidate_1.jpg",
}
## Per-family derivation constants.
## - normal_strength: slope gain of the height field (higher = deeper relief).
## - roughness: (dry base, damp base). Dark pixels read as damp hollows and move
##   toward the damp value; overcast Baltic ground stays mostly matte.
## - invert_height: shingle and grass read bright-on-top (pebble crowns, blades);
##   sand ripples and mud prints read dark in the trough, so height = luminance.
GROUND_DERIVATION = {
    "coast_sand": {"normal_strength": 5.0, "roughness": (0.90, 0.62), "blur": 1.0},
    "sand": {"normal_strength": 4.0, "roughness": (0.97, 0.88), "blur": 1.0},
    "shore_shingle": {"normal_strength": 7.0, "roughness": (0.82, 0.58), "blur": 1.5},
    # The selected mud plate carries baked wet-film glints; the shader adds its own
    # wet sheen (mud_wetness), so they are pulled back to the surrounding colour.
    "mud": {"normal_strength": 6.0, "roughness": (0.78, 0.40), "blur": 1.2, "despecular": True},
    "grass": {"normal_strength": 3.5, "roughness": (0.96, 0.84), "blur": 0.8},
}
# Directional or coursed plates must keep their authored phase. A half-tile
# shift moves the original wrap seam into the middle of a wall face or board.
KEEP_SOURCE_PHASE = {
    "limestone_rubble",
    "timber",
    "timber_floor",
    "cobble",
    "smithy_floor",
}


def _weld_edges(image: Image.Image, *, phase_shift: bool) -> Image.Image:
    """Make both wrap edges equal. Optionally move the original seam off the border."""
    size = image.width
    if phase_shift:
        image = ImageChops.offset(image, size // 2, size // 2)
    pixels = image.load()
    for y in range(size):
        edge = tuple((pixels[0, y][channel] + pixels[size - 1, y][channel]) // 2 for channel in range(3))
        pixels[0, y] = edge
        pixels[size - 1, y] = edge
    for x in range(size):
        edge = tuple((pixels[x, 0][channel] + pixels[x, size - 1][channel]) // 2 for channel in range(3))
        pixels[x, 0] = edge
        pixels[x, size - 1] = edge
    return image


def _wrap_blur(values: np.ndarray, radius: float) -> np.ndarray:
    """Separable Gaussian with wrap-around so derived maps stay tileable."""
    if radius <= 0.0:
        return values
    half = max(1, int(radius * 3.0))
    offsets = np.arange(-half, half + 1)
    weights = np.exp(-(offsets.astype(np.float64) ** 2) / (2.0 * radius * radius))
    weights /= weights.sum()
    out = np.zeros_like(values)
    for offset, weight in zip(offsets, weights):
        out += np.roll(values, int(offset), axis=1) * weight
    result = np.zeros_like(values)
    for offset, weight in zip(offsets, weights):
        result += np.roll(out, int(offset), axis=0) * weight
    return result


def _remove_baked_glints(albedo: np.ndarray) -> np.ndarray:
    """Replace the brightest specular sparkles with their blurred surroundings."""
    luminance = albedo[..., 0] * 0.2126 + albedo[..., 1] * 0.7152 + albedo[..., 2] * 0.0722
    # Glints are bright and desaturated; lit mud crowns are bright but stay ochre.
    saturation = albedo.max(axis=-1) - albedo.min(axis=-1)
    whiteness = luminance - saturation * 1.5
    lo, hi = np.percentile(whiteness, [90.0, 98.5])
    mask = np.clip((whiteness - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    mask = np.clip(_wrap_blur(mask, 2.5) * 1.8, 0.0, 1.0)[..., None]
    # Normalised convolution: fill from unmasked neighbours only, so the glints do
    # not bleed into their own replacement as pale blobs.
    keep = 1.0 - mask[..., 0]
    coverage = np.maximum(_wrap_blur(keep, 8.0), 1e-4)
    surround = np.stack([_wrap_blur(albedo[..., c] * keep, 8.0) / coverage for c in range(3)], axis=-1)
    return albedo * (1.0 - mask) + surround * mask


def _derive_height(albedo: np.ndarray, blur: float) -> np.ndarray:
    """Wrap-aware 0..1 height estimate from luminance.

    Low frequencies (lighting drift across the plate) are removed so the
    normal map carries grain and relief rather than one large tilt.
    """
    luminance = albedo[..., 0] * 0.2126 + albedo[..., 1] * 0.7152 + albedo[..., 2] * 0.0722
    detail = _wrap_blur(luminance, blur)
    broad = _wrap_blur(luminance, albedo.shape[0] / 64.0)
    height = detail - broad
    spread = max(float(np.percentile(np.abs(height), 99.0)), 1e-4)
    return np.clip(height / (2.0 * spread) + 0.5, 0.0, 1.0)


def _derive_normal(height: np.ndarray, strength: float) -> np.ndarray:
    """OpenGL-convention (+Y up) tangent-space normal, wrap-around central differences."""
    size = height.shape[0]
    scale = strength * size / 512.0
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * scale
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * scale
    normal = np.stack([-dx, dy, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def _derive_roughness(albedo: np.ndarray, height: np.ndarray, dry: float, damp: float) -> np.ndarray:
    luminance = albedo[..., 0] * 0.2126 + albedo[..., 1] * 0.7152 + albedo[..., 2] * 0.0722
    lo, hi = np.percentile(luminance, [5.0, 95.0])
    dryness = np.clip((luminance - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    # Crowns (high height) dry first; hollows hold moisture.
    dryness = np.clip(dryness * 0.7 + height * 0.3, 0.0, 1.0)
    return damp + (dry - damp) * dryness


def _to_image(values: np.ndarray, mode: str) -> Image.Image:
    image = Image.fromarray(np.clip(np.round(values * 255.0), 0, 255).astype(np.uint8))
    return image if image.mode == mode else image.convert(mode)


def process_legacy(family: str) -> bool:
    source, destination = OUTPUTS[family]
    if not source.is_file():
        print(f"skip {family}: missing {source.relative_to(ROOT)}")
        return False
    image = Image.open(source).convert("RGB")
    image = image.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
    image = _weld_edges(image, phase_shift=family not in KEEP_SOURCE_PHASE)
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "PNG", optimize=True)
    print(f"prepared {family}: {destination.relative_to(ROOT)}")
    return True


def process_ground(family: str) -> bool:
    source = GROUND_OUTPUTS[family]
    if not source.is_file():
        print(f"skip {family}: missing {source.relative_to(ROOT)}")
        return False
    params = GROUND_DERIVATION[family]
    image = Image.open(source).convert("RGB")
    image = image.resize((GROUND_TARGET_SIZE, GROUND_TARGET_SIZE), Image.Resampling.LANCZOS)
    image = _weld_edges(image, phase_shift=True)
    if params.get("despecular"):
        cleaned = _remove_baked_glints(np.asarray(image, dtype=np.float64) / 255.0)
        image = _to_image(cleaned, "RGB")
    derived_source = image.resize((GROUND_DERIVED_SIZE, GROUND_DERIVED_SIZE), Image.Resampling.LANCZOS)
    albedo = np.asarray(derived_source, dtype=np.float64) / 255.0
    height = _derive_height(albedo, float(params["blur"]))
    normal = _derive_normal(height, float(params["normal_strength"]))
    dry, damp = params["roughness"]
    roughness = _derive_roughness(albedo, height, float(dry), float(damp))

    out_dir = PBR / family
    out_dir.mkdir(parents=True, exist_ok=True)
    image.save(out_dir / f"{family}_albedo.png", "PNG", optimize=True)
    _to_image(normal, "RGB").save(out_dir / f"{family}_normal.png", "PNG", optimize=True)
    _to_image(roughness, "L").save(out_dir / f"{family}_roughness.png", "PNG", optimize=True)
    print(f"prepared {family}: {out_dir.relative_to(ROOT)} (albedo, normal, roughness)")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="*", default=[], help="family names to process")
    args = parser.parse_args()
    wanted = set(args.only)
    prepared = 0
    for family in OUTPUTS:
        if not wanted or family in wanted:
            prepared += int(process_legacy(family))
    for family in GROUND_OUTPUTS:
        if not wanted or family in wanted:
            prepared += int(process_ground(family))
    if prepared == 0:
        raise FileNotFoundError("no Leonardo terrain sources were available")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
