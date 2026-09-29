#!/usr/bin/env python3
"""Prepare selected Leonardo terrain albedos for the Godot runtime.

The generator output is treated as an authored candidate, not as a drop-in
runtime texture: it is resized with Lanczos and moved to a half-tile phase so
large AI marks do not sit on the wrap seam. The final border pixels are welded
for deterministic repeatability.

Two tiers:

- Legacy families (timber, cobble, hay, ...) keep their 512 px albedo-only
  output. Runtime terrain resizes these to its 128 px texture-array tier.
- CO-01 ground families (coast_sand, sand, shore_shingle, mud, grass) are quilted
  seamless (`SEAMLESS_FAMILIES`) instead of phase-shifted, then ship a
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


## Overlap-quilting for isotropic ground plates. A half-tile phase shift only moves
## the wrap seam of a non-tileable plate into the middle of the tile, where it
## repeats as a visible cross grid on large ground areas. Instead the tile is cut
## from the top-left of the plate and the unused strip past its right and bottom
## edge (a natural continuation of the last column/row) is stitched over the
## tile's first columns/rows along a minimum-error path. Column 0 then continues
## the last column, so the wrap is seamless and the stitch hides in the grain.
SEAMLESS_OVERLAP_FRACTION = 1.0 / 6.0
SEAMLESS_MARGIN = 12  # px kept out of the cut path so the wrap edge is pure overlap
SEAMLESS_FEATHER = 1.5  # px Gaussian softening of the cut
# Every CO-01 ground family is isotropic natural ground with no authored course or
# grain direction, so all of them quilt. Shingle and mud carried the worst phase
# seam (mid-tile discontinuity 11x and 5x the local grain) because their plates
# have the strongest large marks.
SEAMLESS_FAMILIES = set(GROUND_OUTPUTS)

## Leonardo lights every plate from one side, so each albedo carries a broad
## bright-to-dark drift (38-53% of mean luminance on shingle, mud and grass).
## A seamless tile still repeats that drift as a blotch grid once the ground
## covers dozens of cells, which reads as the same "obvious cell" artefact as a
## hard seam. The drift is shading, not material, so it is divided out in linear
## light before quilting; a residual fraction is kept so the ground is not flat.
DEDRIFT_STRENGTH = 0.8
DEDRIFT_RADIUS_FRACTION = 1.0 / 8.0


def _min_error_cut(cost: np.ndarray, margin: int, cyclic: bool) -> np.ndarray:
    """Top-to-bottom path through cost (rows x cols) moving at most one column per row.

    With cyclic=True the path must end in the column it started in, because the
    rows themselves wrap (the second pass runs on an already tileable axis).
    """
    rows, cols = cost.shape
    cost = cost.copy()
    cost[:, :margin] = np.inf
    cost[:, cols - margin :] = np.inf
    starts = np.arange(margin, cols - margin, 2) if cyclic else np.array([-1])
    count = len(starts)
    acc = np.full((count, cols), np.inf)
    if cyclic:
        acc[np.arange(count), starts] = cost[0, starts]
    else:
        acc[0] = cost[0]
    back = np.zeros((rows, count, cols), dtype=np.int8)
    for row in range(1, rows):
        left = np.concatenate([np.full((count, 1), np.inf), acc[:, :-1]], axis=1)
        right = np.concatenate([acc[:, 1:], np.full((count, 1), np.inf)], axis=1)
        stacked = np.stack([left, acc, right])
        choice = np.argmin(stacked, axis=0)
        acc = np.take_along_axis(stacked, choice[None], axis=0)[0] + cost[row]
        back[row] = choice.astype(np.int8) - 1
    if cyclic:
        finals = acc[np.arange(count), starts]
        best = int(np.argmin(finals))
        column = int(starts[best])
    else:
        best = 0
        column = int(np.argmin(acc[0]))
    path = np.zeros(rows, dtype=np.int64)
    for row in range(rows - 1, -1, -1):
        path[row] = column
        column += int(back[row, best, column])
    return path


def _stitch_columns(plate: np.ndarray, tile: int, overlap: int, cyclic: bool) -> np.ndarray:
    """Make columns wrap: plate[:, tile:tile+overlap] replaces the tile's first columns."""
    body = plate[:, :tile].copy()
    head = body[:, :overlap]
    tail = plate[:, tile : tile + overlap]
    diff = ((head - tail) ** 2).sum(axis=-1)
    # Light smoothing so the cut follows regions of similar structure, not single pixels.
    diff = _wrap_blur(diff, 1.5)
    path = _min_error_cut(diff, SEAMLESS_MARGIN, cyclic)
    use_tail = (np.arange(overlap)[None, :] < path[:, None]).astype(np.float64)
    # Feather only along the cut direction; rows are left untouched so the
    # cyclic path stays tileable.
    half = max(1, int(SEAMLESS_FEATHER * 3.0))
    offsets = np.arange(-half, half + 1)
    weights = np.exp(-(offsets.astype(np.float64) ** 2) / (2.0 * SEAMLESS_FEATHER**2))
    weights /= weights.sum()
    padded = np.pad(use_tail, ((0, 0), (half, half)), mode="edge")
    mask = sum(padded[:, half + o : half + o + overlap] * w for o, w in zip(offsets, weights))
    body[:, :overlap] = tail * mask[..., None] + head * (1.0 - mask[..., None])
    return body


def _broad_luminance(luminance: np.ndarray, radius: float) -> np.ndarray:
    """Very low-pass of the plate: box-downsample below the cutoff, bicubic back up.

    A direct Gaussian at this radius (hundreds of pixels) is far slower and would
    need wrap padding the plate does not have yet.
    """
    size = luminance.shape[0]
    coarse = max(4, int(round(size / max(radius, 1.0))))
    small = Image.fromarray(luminance.astype(np.float32)).resize((coarse, coarse), Image.Resampling.BOX)
    return np.asarray(small.resize((size, size), Image.Resampling.BICUBIC), dtype=np.float64)


def _srgb_to_linear(values: np.ndarray) -> np.ndarray:
    return np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)


def _linear_to_srgb(values: np.ndarray) -> np.ndarray:
    return np.where(values <= 0.0031308, values * 12.92, 1.055 * values ** (1.0 / 2.4) - 0.055)


def _flatten_lighting(image: Image.Image) -> Image.Image:
    """Divide out the generator's broad shading drift, keeping the fine grain."""
    srgb = np.asarray(image, dtype=np.float64) / 255.0
    linear = _srgb_to_linear(srgb)
    luminance = linear @ np.array([0.2126, 0.7152, 0.0722])
    broad = _broad_luminance(luminance, image.width * DEDRIFT_RADIUS_FRACTION)
    # Clamped so a near-black hollow cannot be pushed to a bright smear.
    gain = np.clip(float(luminance.mean()) / np.maximum(broad, 1e-4), 0.5, 2.0)
    gain = 1.0 + (gain - 1.0) * DEDRIFT_STRENGTH
    return _to_image(_linear_to_srgb(np.clip(linear * gain[..., None], 0.0, 1.0)), "RGB")


def _make_seamless(image: Image.Image) -> Image.Image:
    """Crop a tile from the plate and quilt its wrap edges from the leftover strips."""
    plate = np.asarray(image, dtype=np.float64) / 255.0
    size = min(plate.shape[0], plate.shape[1])
    overlap = int(size * SEAMLESS_OVERLAP_FRACTION)
    tile = size - overlap
    plate = plate[:size, :size]
    # Pass 1: horizontal wrap on the full height, so the bottom strip is also
    # x-tileable for pass 2.
    wide = _stitch_columns(plate, tile, overlap, cyclic=False)
    # Pass 2: vertical wrap on the transposed plate. Rows (former columns) now
    # wrap, so the cut must close on itself.
    tall = _stitch_columns(wide.transpose(1, 0, 2), tile, overlap, cyclic=True)
    return _to_image(tall.transpose(1, 0, 2), "RGB")


def _resize_tileable(image: Image.Image, size: int) -> Image.Image:
    """Lanczos resize that samples across the wrap instead of clamping the border."""
    pad = max(8, image.width // 32)
    padded = np.pad(np.asarray(image), ((pad, pad), (pad, pad), (0, 0)), mode="wrap")
    scale = size / image.width
    out_pad = int(round(pad * scale))
    big = Image.fromarray(padded).resize(
        (size + 2 * out_pad, size + 2 * out_pad), Image.Resampling.LANCZOS
    )
    return big.crop((out_pad, out_pad, out_pad + size, out_pad + size))


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
    if family in SEAMLESS_FAMILIES:
        image = _resize_tileable(_make_seamless(_flatten_lighting(image)), GROUND_TARGET_SIZE)
    else:
        image = image.resize((GROUND_TARGET_SIZE, GROUND_TARGET_SIZE), Image.Resampling.LANCZOS)
        image = _weld_edges(image, phase_shift=True)
    if params.get("despecular"):
        cleaned = _remove_baked_glints(np.asarray(image, dtype=np.float64) / 255.0)
        image = _to_image(cleaned, "RGB")
    if family in SEAMLESS_FAMILIES:
        derived_source = _resize_tileable(image, GROUND_DERIVED_SIZE)
    else:
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
