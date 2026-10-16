#!/usr/bin/env python3
"""Pack the CC0 ambientCG ice and snow scans into the lake-ice texture set.

ADR 0045 winter ice (docs/SYSTEMS/SEASONS.md). Sources (CC0 1.0, ambientCG):
Ice003 (clear black lake ice), Ice004 (milky plate ice), Snow014 (wind crust),
1K-JPG downloads. Packing keeps the ice shader at four samplers:

- lake_ice_clear_albedo_rough.png  RGB Ice003 colour, A Ice003 roughness
- lake_ice_milky_albedo_rough.png  RGB Ice004 colour, A Ice004 roughness
- lake_ice_normals.png             RG Ice003 normal (GL), BA Ice004 normal (GL)
- snow_crust_normal.png            RG Snow014 normal (GL), B Snow014 displacement

Prints the mean sRGB colour of each ice albedo: ice_surface.gdshaderinc divides
it out (ICE_*_PHOTO_MEAN) so the scans keep their detail but take the game tone.

Usage: python3 tools/assets/pack_lake_ice_textures.py <download_dir> [--out DIR]
where <download_dir> holds the unzipped Ice003/, Ice004/ and Snow014/ folders.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

OUT_DEFAULT = Path("assets/materials/pbr/lake_ice")


def _map(root: Path, asset: str, kind: str) -> Image.Image:
    return Image.open(root / asset / f"{asset}_1K-JPG_{kind}.jpg")


def _albedo_rough(root: Path, asset: str) -> tuple[Image.Image, tuple[float, ...]]:
    colour = _map(root, asset, "Color").convert("RGB")
    rough = _map(root, asset, "Roughness").convert("L").resize(colour.size)
    r, g, b = colour.split()
    pixels = list(colour.getdata())
    mean = tuple(sum(p[i] for p in pixels) / (len(pixels) * 255.0) for i in range(3))
    return Image.merge("RGBA", (r, g, b, rough)), mean


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("download_dir", type=Path)
    parser.add_argument("--out", type=Path, default=OUT_DEFAULT)
    args = parser.parse_args()
    root: Path = args.download_dir
    out: Path = args.out
    out.mkdir(parents=True, exist_ok=True)

    clear, clear_mean = _albedo_rough(root, "Ice003")
    clear.save(out / "lake_ice_clear_albedo_rough.png")
    milky, milky_mean = _albedo_rough(root, "Ice004")
    milky.save(out / "lake_ice_milky_albedo_rough.png")

    n_clear = _map(root, "Ice003", "NormalGL").convert("RGB").resize(clear.size)
    n_milky = _map(root, "Ice004", "NormalGL").convert("RGB").resize(clear.size)
    cr, cg, _ = n_clear.split()
    mr, mg, _ = n_milky.split()
    Image.merge("RGBA", (cr, cg, mr, mg)).save(out / "lake_ice_normals.png")

    n_snow = _map(root, "Snow014", "NormalGL").convert("RGB")
    height = _map(root, "Snow014", "Displacement").convert("L").resize(n_snow.size)
    sr, sg, _ = n_snow.split()
    Image.merge("RGB", (sr, sg, height)).save(out / "snow_crust_normal.png")

    fmt = "vec3({:.3f}, {:.3f}, {:.3f})"
    print("ICE_CLEAR_PHOTO_MEAN =", fmt.format(*clear_mean))
    print("ICE_MILKY_PHOTO_MEAN =", fmt.format(*milky_mean))


if __name__ == "__main__":
    main()
