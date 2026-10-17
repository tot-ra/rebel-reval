#!/usr/bin/env python3
"""Generate the vegetation texture set procedurally (R-1329, VEGR-1).

Replaces the image-generator leaf-card atlas (Leonardo leaf_cards_v1 plus the
OpenAI needle plates) with textures drawn in code from parametric species data,
so the canopy pipeline carries no external image-generator rights risk.

Every output is a pure function of the parameters below and SEED: numpy PCG64
streams, FFT-filtered noise and a fixed PNG encoder, no timestamps or metadata.
Two runs on the same machine give byte-identical files.

Outputs
- assets/materials/pbr/foliage_cards/leaf_card_atlas.png (4x2 tiles of 512 px,
  RGBA). Runtime contract unchanged from R-1194: tile order is
  MapViewLeafGeometry.CARD_TILES, image bottom is the petiole end (card UV.y = 0),
  RGB is relative detail around neutral 0.5 grey (the canopy shader multiplies
  albedo by 2 * texture and owns species tint, season and wetness), alpha is
  coverage, and transparent texels carry the nearby leaf colour so mipmaps do
  not halo.
- leaf_card_normal.png (OpenGL tangent space, +Y up) and leaf_card_surface.png
  (R roughness, G translucency, B baked occlusion), same layout. Produced for
  VEGR-6 (R-1324); the canopy shader does not sample them yet.
- assets/vegetation/bark/bark_<kind>_{albedo,normal}.png: seamless 512 px plates
  per bark family (birch, oak, grey, pine, spruce, cherry).
- assets/vegetation/ground/ground_<kind>_{albedo,normal}.png: seamless 512 px
  forest-floor plates (moss, leaf_litter, needle_litter).
- assets/vegetation/grain/grain_ear_atlas.png: 4x1 tiles of 256x512 RGBA ears
  (rye, barley, oat, flax), same relative-detail contract as the leaf atlas.

Usage:
  python3 tools/assets/generate_vegetation_atlases.py [--out-root DIR]
      [--compare-old OLD_ATLAS.png --sheets DIR]
--out-root writes the same relative tree elsewhere (tests use a temp dir).
--compare-old writes per-species before/after review sheets (near and
canopy-distance, tinted like the canopy shader) into --sheets.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

# Support both the documented script invocation and Python's module invocation.
if __package__:
    from .vegetation_atlases.species import (
        BARK_KINDS, EARS, EAR_TILE, GRID, GROUND_KINDS, LEAF_DIR, LEAVES,
        NEEDLES, PLATE, SEED, SS, TILE, TILES, VEG_DIR,
    )
    from .vegetation_atlases.foliage import build_leaf_atlas, tile_coverage, tune
    from .vegetation_atlases.grain import build_ear_atlas
    from .vegetation_atlases.raster import species_rng, to_u8
    from .vegetation_atlases.surfaces import bark_plate, ground_plate
else:
    from vegetation_atlases.species import (
        BARK_KINDS, EARS, EAR_TILE, GRID, GROUND_KINDS, LEAF_DIR, LEAVES,
        NEEDLES, PLATE, SEED, SS, TILE, TILES, VEG_DIR,
    )
    from vegetation_atlases.foliage import build_leaf_atlas, tile_coverage, tune
    from vegetation_atlases.grain import build_ear_atlas
    from vegetation_atlases.raster import species_rng, to_u8
    from vegetation_atlases.surfaces import bark_plate, ground_plate

ROOT = Path(__file__).resolve().parents[2]


def save_png(array: np.ndarray, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = "RGBA" if array.shape[2] == 4 else "RGB"
    # Fixed encoder settings and no metadata: identical bytes on every run.
    Image.fromarray(to_u8(array)).save(path, format="PNG", compress_level=9)
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(out_root: Path) -> dict[str, str]:
    """Write every output under out_root; returns relative path -> SHA-256."""
    digests: dict[str, str] = {}

    def write(array: np.ndarray, relative: Path) -> None:
        digests[relative.as_posix()] = save_png(array, out_root / relative)

    leaf = build_leaf_atlas()
    write(leaf["albedo"], LEAF_DIR / "leaf_card_atlas.png")
    write(leaf["normal"], LEAF_DIR / "leaf_card_normal.png")
    write(leaf["surface"], LEAF_DIR / "leaf_card_surface.png")
    for kind in BARK_KINDS:
        albedo, normal = bark_plate(kind, species_rng("bark", kind))
        write(albedo, VEG_DIR / "bark" / f"bark_{kind}_albedo.png")
        write(normal, VEG_DIR / "bark" / f"bark_{kind}_normal.png")
    for kind in GROUND_KINDS:
        albedo, normal = ground_plate(kind, species_rng("ground", kind))
        write(albedo, VEG_DIR / "ground" / f"ground_{kind}_albedo.png")
        write(normal, VEG_DIR / "ground" / f"ground_{kind}_normal.png")
    write(build_ear_atlas(), VEG_DIR / "grain" / "grain_ear_atlas.png")
    return digests


# Review sheets: old vs new tile, tinted like map_view_canopy.gdshader.

SHADER_TINT = {
    "birch": ((96, 118, 60), 0.74), "oak": ((96, 118, 60), 0.74),
    "maple": ((96, 118, 60), 0.74), "linden": ((96, 118, 60), 0.74),
    "apple": ((92, 128, 60), 0.74), "spruce": ((58, 84, 56), 0.84),
    "pine": ((72, 96, 52), 0.84),
}
SKY = np.array([0.62, 0.68, 0.72])


def tinted(tile: np.ndarray, species: str, far: bool) -> np.ndarray:
    colour, gain = SHADER_TINT[species]
    rgba = tile.astype(np.float64) / 255.0
    if far:
        # Canopy distance: what a 32 px mip level keeps of the card.
        image = Image.fromarray(tile).resize((32, 32), Image.Resampling.BOX)
        rgba = np.asarray(image.resize((256, 256), Image.Resampling.BILINEAR),
                          dtype=np.float64) / 255.0
    else:
        rgba = np.asarray(Image.fromarray(tile).resize((256, 256),
                          Image.Resampling.LANCZOS), dtype=np.float64) / 255.0
    rgb = np.array(colour) / 255.0 * 2.0 * rgba[..., :3] * gain
    keep = (rgba[..., 3] >= 0.5)[..., None]
    return np.where(keep, np.clip(rgb, 0, 1), SKY)


def review_sheets(old_atlas: Path, new_atlas: Path, out_dir: Path) -> list[Path]:
    old = np.asarray(Image.open(old_atlas).convert("RGBA"))
    new = np.asarray(Image.open(new_atlas).convert("RGBA"))
    written = []
    for index, species in enumerate(TILES):
        col, row = index % GRID[0], index // GRID[0]
        sl = (slice(row * TILE, (row + 1) * TILE), slice(col * TILE, (col + 1) * TILE))
        panels = [tinted(old[sl], species, False), tinted(new[sl], species, False),
                  tinted(old[sl], species, True), tinted(new[sl], species, True)]
        sheet = np.concatenate(panels, axis=1)
        path = out_dir / f"{species}_before_after.png"
        out_dir.mkdir(parents=True, exist_ok=True)
        Image.fromarray(to_u8(sheet)).save(path, format="PNG", compress_level=9)
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out-root", type=Path, default=ROOT)
    parser.add_argument("--tune", action="store_true",
                        help="print the size_scale per leaf species for its coverage target")
    parser.add_argument("--compare-old", type=Path)
    parser.add_argument("--sheets", type=Path, default=ROOT / "docs/reports/images/vegetation_atlases")
    args = parser.parse_args()
    if args.tune:
        for species in TILES:
            mult, coverage = tune(species)
            print(f"{species}: size_scale={mult} coverage={coverage:.3f}")
        return 0
    for relative, digest in generate(args.out_root).items():
        print(f"{relative} SHA-256 {digest}")
    if args.compare_old:
        for path in review_sheets(args.compare_old, args.out_root / LEAF_DIR / "leaf_card_atlas.png",
                                  args.sheets):
            print(f"review sheet {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
