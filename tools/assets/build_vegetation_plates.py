#!/usr/bin/env python3
"""Build seamless grass-ground and bark plates from the OpenAI vegetation run.

Sources: generated/openai/vegetation_v1/{grass,bark,needles}/<name>/source.png
(raw 1024 px plates, ignored by git; prompt.json records prompt, generation id
and SHA-256, and assets/SOURCES.csv repeats them).

Why a processor at all:
- Image models do not tile. `make_seamless` cross-fades each plate with copies
  rolled by half its size (classic 4-way blend), so every edge meets the
  opposite edge exactly. The blend is variance preserving: averaging two
  textures halves their contrast, which would show as soft blurry bands.
- Twelve grass plates come out with different exposure and saturation. Side by
  side in the ground shader that reads as patchwork, so each plate's mean
  colour is pulled part of the way toward the shared meadow mean while its own
  detail is kept.
- Normals are derived from a high-passed luminance height (gaps between blades
  and bark furrows are dark), which is enough for the ground and trunk shading.

Outputs:
- assets/materials/pbr/grass_ground/grass_ground_albedo_array.jpg  (4x3 slices)
- assets/materials/pbr/grass_ground/grass_ground_normal_array.jpg  (4x3 slices)
- assets/materials/pbr/bark_<kind>/bark_<kind>_albedo.jpg, _normal.jpg
- the spruce and pine tiles of assets/materials/pbr/foliage_cards/leaf_card_atlas.png
  (rebuilt from the selected needle plates with build_leaf_card_atlas.build_tile and
  defringed per tile; do not run defringe_atlas.py on the whole atlas again)

Usage: python3 tools/assets/build_vegetation_plates.py [--only grass,bark,needles]
       [--preview build/vegetation_plates]   (writes 2x2 seam-check tilings)
Slice order must match CityTerrainBuilder.GRASS_VARIANTS.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "generated/openai/vegetation_v1"
GRASS_OUT = ROOT / "assets/materials/pbr/grass_ground"
SLICE = 1024
GRID = (4, 3)
# Slice order is a runtime contract (CityTerrainBuilder.GRASS_VARIANTS).
GRASS = [
    "g01_grazed_turf", "g02_lush_meadow", "g06_clover", "g07_hay_meadow",
    "g09_spring", "g10_yarrow_weeds", "g11_sedge_pasture", "g12_wildflowers",
    "g03_dry_summer", "g04_moss_shade", "g08_leaf_scatter", "g05_trodden",
]
# How far each plate's mean colour is pulled toward the shared meadow mean.
# Character plates (dry, moss, leaves, trodden) keep more of their own colour.
# Strong pulls: at distance only mean colour is left, and plates that differ
# in tone showed as blotches across every pasture.
GRASS_PULL = {"g03_dry_summer": 0.6, "g04_moss_shade": 0.65, "g08_leaf_scatter": 0.55,
              "g05_trodden": 0.3}
GRASS_DEFAULT_PULL = 0.85
# Bark kind -> (saturation multiplier, normal strength). Pine came out neon orange.
BARK = {"birch": (0.9, 2.0), "oak": (0.95, 3.2), "grey": (0.9, 2.6),
        "pine": (0.62, 3.0), "spruce": (0.85, 2.6), "cherry": (0.9, 1.8)}
NEEDLES = {"spruce": "spruce_1", "pine": "pine_2"}
# Backdrop deficit (0-255) where a texel starts to count as needle. Pine needles
# are paler grey-green than spruce, so they need a lower threshold.
NEEDLE_KEY = {"spruce": 75.0, "pine": 66.0}
LEAF_ATLAS = ROOT / "assets/materials/pbr/foliage_cards/leaf_card_atlas.png"
LEAF_TILE_INDEX = {"spruce": 5, "pine": 6}  # MapViewLeafGeometry.CARD_TILES


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make_seamless(img: np.ndarray, frac: float = 0.22) -> np.ndarray:
    """4-way half-roll blend; edges wrap exactly, contrast is preserved."""
    h, w = img.shape[:2]
    x = np.arange(w) / (w - 1)
    y = np.arange(h) / (h - 1)
    wx = smoothstep(0.0, frac, np.minimum(x, 1.0 - x))[None, :, None]
    wy = smoothstep(0.0, frac, np.minimum(y, 1.0 - y))[:, None, None]
    rx = np.roll(img, w // 2, axis=1)
    ry = np.roll(img, h // 2, axis=0)
    rxy = np.roll(rx, h // 2, axis=0)
    weights = [wx * wy, (1 - wx) * wy, wx * (1 - wy), (1 - wx) * (1 - wy)]
    mean = img.mean(axis=(0, 1), keepdims=True)
    acc = sum(wk * (ik - mean) for wk, ik in zip(weights, [img, rx, ry, rxy]))
    norm = np.sqrt(sum(wk * wk for wk in weights))
    return np.clip(mean + acc / norm, 0.0, 1.0)


def luminance(img: np.ndarray) -> np.ndarray:
    # Explicit weighted sum: float32 matmul through Accelerate emits spurious overflow warnings.
    return img[..., 0] * 0.2126 + img[..., 1] * 0.7152 + img[..., 2] * 0.0722


def normal_from(img: np.ndarray, strength: float) -> np.ndarray:
    """Tangent-space normal (OpenGL, +Y up) from high-passed luminance height.
    Gradients use wrapped differences so the normal map tiles like the albedo."""
    lum = luminance(img)
    blur = np.asarray(
        Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)),
        dtype=np.float32,
    ) / 255.0
    height = lum - blur
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    n = np.dstack([-dx * strength * 8.0, dy * strength * 8.0, np.ones_like(dx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def saturate(img: np.ndarray, amount: float) -> np.ndarray:
    lum = luminance(img)[..., None]
    return np.clip(lum + (img - lum) * amount, 0.0, 1.0)


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).round().astype(np.uint8))


def save_jpeg(arr: np.ndarray, path: Path, quality: int = 88) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    to_image(arr).save(path, quality=quality, subsampling=0)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{path.relative_to(ROOT)} {path.stat().st_size // 1024} KiB SHA-256 {digest}")


def preview_tiling(arr: np.ndarray, path: Path) -> None:
    """2x2 tiling at half size: a visible cross in the middle means a seam."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tiled = np.tile(arr, (2, 2, 1))
    to_image(tiled).resize((SLICE, SLICE), Image.Resampling.LANCZOS).save(path)


def build_grass(preview: Path | None) -> None:
    plates = {}
    for name in GRASS:
        img = load(SOURCE / "grass" / name / "source.png")
        if img.shape[:2] != (SLICE, SLICE):
            img = np.asarray(to_image(img).resize((SLICE, SLICE), Image.Resampling.LANCZOS),
                             dtype=np.float32) / 255.0
        plates[name] = make_seamless(img)
    greens = [n for n in GRASS if n not in GRASS_PULL]
    meadow = np.mean([plates[n].mean(axis=(0, 1)) for n in greens], axis=0)
    print("meadow mean sRGB", np.round(meadow * 255).astype(int).tolist())
    albedo = np.zeros((GRID[1] * SLICE, GRID[0] * SLICE, 3), dtype=np.float32)
    normal = np.zeros_like(albedo)
    for index, name in enumerate(GRASS):
        img = plates[name]
        own = img.mean(axis=(0, 1))
        pull = GRASS_PULL.get(name, GRASS_DEFAULT_PULL)
        target = own + (meadow - own) * pull
        # Scale (not shift) toward the target so dark gaps stay dark.
        img = np.clip(img * (target / np.maximum(own, 1e-3)), 0.0, 1.0)
        r, c = divmod(index, GRID[0])
        albedo[r * SLICE:(r + 1) * SLICE, c * SLICE:(c + 1) * SLICE] = img
        normal[r * SLICE:(r + 1) * SLICE, c * SLICE:(c + 1) * SLICE] = normal_from(img, 2.2)
        if preview:
            preview_tiling(img, preview / f"grass_{name}_2x2.jpg")
    save_jpeg(albedo, GRASS_OUT / "grass_ground_albedo_array.jpg")
    # Half-resolution normals: blade-level noise compresses badly (a full-size
    # JPEG is ~19 MiB, over the 10 MiB storage limit) and the ground shader only
    # needs the coarse relief from it.
    half = np.asarray(to_image(normal).resize((albedo.shape[1] // 2, albedo.shape[0] // 2),
                      Image.Resampling.BOX), dtype=np.float32) / 255.0
    save_jpeg(half, GRASS_OUT / "grass_ground_normal_array.jpg", quality=88)
    if preview:
        to_image(albedo).resize((2048, 1536), Image.Resampling.LANCZOS).save(
            preview / "grass_ground_albedo_array.jpg")


def build_bark(preview: Path | None) -> None:
    for kind, (sat, strength) in BARK.items():
        img = make_seamless(saturate(load(SOURCE / "bark" / kind / "source.png"), sat))
        out = ROOT / f"assets/materials/pbr/bark_{kind}"
        save_jpeg(img, out / f"bark_{kind}_albedo.jpg")
        save_jpeg(normal_from(img, strength), out / f"bark_{kind}_normal.jpg", quality=90)
        if preview:
            preview_tiling(img, preview / f"bark_{kind}_2x2.jpg")


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    """Separable box blur with edge clamping; three passes approximate a Gaussian."""
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        n = a.shape[axis]
        hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
        lo = np.take(c, np.arange(0, n), axis=axis)
        a = (hi - lo) / (2 * r + 1)
    return a


def fill_needle_rim(tile: np.ndarray) -> np.ndarray:
    """Repaint every texel below the scissor with nearby needle colour so linear
    mips never mix backdrop grey into the needle edges. defringe_atlas.py cannot
    be used: it trusts colour only deep inside solid shapes, and needles are a
    few texels wide (the result is a mosaic). Normalised Gaussian fill instead."""
    rgb = tile[..., :3].astype(np.float32)
    solid = (tile[..., 3] > 127).astype(np.float32)
    fill = rgb.copy()
    for radius in (2, 6, 18):
        def blur(a: np.ndarray, r: int = radius) -> np.ndarray:
            return box_blur(box_blur(box_blur(a, r), r), r)
        weight = blur(solid)
        colour = np.dstack([blur(rgb[..., c] * solid) for c in range(3)])
        colour /= np.maximum(weight, 1e-4)[..., None]
        empty = (solid < 0.5) & (weight > 1e-3)
        fill[empty] = colour[empty]
        solid = np.maximum(solid, (weight > 1e-3).astype(np.float32))
    out = np.dstack([np.clip(fill, 0, 255), tile[..., 3]])
    return out.round().astype(np.uint8)


def build_needles() -> None:
    sys.path.insert(0, str(ROOT / "tools/assets"))
    import build_leaf_card_atlas as leaf  # noqa: E402  (sibling tool, shared keying)

    # Needle plates have soft grey contact shadows between needles that the leaf
    # keying (threshold 22) keeps as opaque pale fill, which is exactly what made
    # spruce cards read as a flat sheet. Key needles much harder.
    base_key = leaf.key_alpha
    atlas = Image.open(LEAF_ATLAS).convert("RGBA")
    for species, candidate in NEEDLES.items():
        threshold = NEEDLE_KEY[species]

        def needle_key(rgb: np.ndarray, t: float = threshold) -> tuple[np.ndarray, np.ndarray]:
            border = np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3)])
            deficit = np.max(np.median(border, axis=0)[None, None, :] - rgb, axis=2)
            _alpha, pure = base_key(rgb)
            return np.clip((deficit - t) / 40.0, 0.0, 1.0), pure

        leaf.key_alpha = needle_key
        tile = np.asarray(leaf.build_tile(SOURCE / "needles" / candidate / "source.png"))
        tile = fill_needle_rim(tile)
        index = LEAF_TILE_INDEX[species]
        box = ((index % leaf.GRID[0]) * leaf.TILE, (index // leaf.GRID[0]) * leaf.TILE)
        atlas.paste(Image.fromarray(tile), box)
    leaf.key_alpha = base_key
    atlas.save(LEAF_ATLAS, optimize=True)
    digest = hashlib.sha256(LEAF_ATLAS.read_bytes()).hexdigest()
    print(f"{LEAF_ATLAS.relative_to(ROOT)} SHA-256 {digest} ")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", default="grass,bark,needles")
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    parts = set(args.only.split(","))
    if "grass" in parts:
        build_grass(args.preview)
    if "bark" in parts:
        build_bark(args.preview)
    if "needles" in parts:
        build_needles()
    manifest = {"grass_slices": GRASS, "grid": list(GRID), "bark": sorted(BARK),
                "needles": NEEDLES, "source_run": "generated/openai/vegetation_v1"}
    (GRASS_OUT / "prompt.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
