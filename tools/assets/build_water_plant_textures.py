#!/usr/bin/env python3
"""Build the water-plant textures for the moat and stream (CityMoatPlants).

Input: Leonardo photos in generated/leonardo/water_plants_v1/ (gitignored raw
sources; generation IDs in generations.csv next to them):
  lily_pad.jpg     Nymphaea alba leaf from above, on white
  lily_flower.jpg  Nymphaea alba bloom from above, on black
  duckweed.jpg     Lemna minor patch from above, on white
  blade.jpg        macro of a Typha leaf surface, veins vertical, full frame

Output in assets/vegetation/water/:
  lily_pad.png            512 px RGBA, notch toward +U (mesh +X)
  lily_flower.png         256 px RGBA
  duckweed_patch.png      512 px RGBA, ragged patch
  reed_blade_detail.png   128x512 grey vein detail, opaque, tiles in V

WHY the blade is grey and the floaters keep their colour: reed and cattail
tones come from vertex colours and the seasonal albedo tint (green -> straw),
so the blade texture carries only the vein luminance (median 0.8 linear) and the
multiply keeps the tint. Pads, blooms and duckweed are tinted only by a mild
season multiplier, so their photo colour is the look. RGB is dilated into the
transparent margin so mipmaps do not pull a white or black fringe into the
alpha-scissored edge.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "generated" / "leonardo" / "water_plants_v1"
OUTPUT_DIR = ROOT / "assets" / "vegetation" / "water"
TARGET_MEDIAN_LINEAR = 0.8


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1.0 / 2.4) - 0.055)


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def key_alpha(rgb: np.ndarray, on_black: bool) -> np.ndarray:
    """Alpha from a flat background. On white, plants are low in at least one
    channel; on black (white petals), they are high in at least one."""
    if on_black:
        alpha = np.clip((rgb.max(axis=2) - 0.08) / 0.14, 0.0, 1.0)
    else:
        alpha = np.clip((0.93 - rgb.min(axis=2)) / 0.18, 0.0, 1.0)
    mask = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
    return np.asarray(mask, dtype=np.float32) / 255.0


def dilate_rgb(rgba: np.ndarray, passes: int = 32) -> np.ndarray:
    """Push opaque RGB outward into transparent pixels (mip-safe edges)."""
    rgb = rgba[..., :3].astype(np.float32)
    known = rgba[..., 3] > 128
    solid = known.copy()
    for _ in range(passes):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), axis=(0, 1))
            acc += np.roll(rgb, (dy, dx), axis=(0, 1)) * k[..., None]
            cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    rgb[~known] = rgb[solid].mean(axis=0)
    out = rgba.copy()
    out[..., :3] = rgb.round().astype(np.uint8)
    return out


def cutout(path: Path, size: int, on_black: bool, fill: float, rotate: float = 0.0) -> Image.Image:
    """Square RGBA: the plant cropped to its bounds, centred, longer side at
    `fill` of the frame (rest is mip padding)."""
    rgb = load(path)
    alpha = key_alpha(rgb, on_black)
    ys, xs = np.nonzero(alpha > 0.5)
    if xs.size == 0:
        raise SystemExit(f"nothing found in {path}")
    rgba = np.dstack([rgb, alpha])[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    img = Image.fromarray((rgba * 255).round().astype(np.uint8))
    if rotate:
        img = img.rotate(rotate, resample=Image.BICUBIC, expand=True)
    scale = fill * size / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    frame.paste(img, ((size - img.width) // 2, (size - img.height) // 2))
    return Image.fromarray(dilate_rgb(np.asarray(frame)))


def blade_detail(path: Path) -> Image.Image:
    """Grey vein strip from the centre of the macro, made to tile along V by
    cross-fading the bottom quarter into the top."""
    rgb = load(path)
    h, w = rgb.shape[:2]
    strip = rgb[:, w // 2 - w // 8: w // 2 + w // 8]
    lum = srgb_to_linear(strip) @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    lum = lum * (TARGET_MEDIAN_LINEAR / max(float(np.median(lum)), 1e-3))
    blend = h // 4
    body = lum[: h - blend].copy()
    ramp = np.linspace(0.0, 1.0, blend, dtype=np.float32)[:, None]
    body[:blend] = lum[h - blend:] * (1.0 - ramp) + body[:blend] * ramp
    grey = (linear_to_srgb(body) * 255).round().astype(np.uint8)
    return Image.fromarray(grey).convert("RGB").resize((128, 512), Image.LANCZOS)


def build(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    # The photo's notch points down (-V); the pad mesh notch faces +X (+U), so
    # turn the leaf 90 degrees counter-clockwise.
    results = {
        "lily_pad.png": cutout(source / "lily_pad.jpg", 512, False, 0.98, rotate=90.0),
        "lily_flower.png": cutout(source / "lily_flower.jpg", 256, True, 0.96),
        "duckweed_patch.png": cutout(source / "duckweed.jpg", 512, False, 0.96),
        "reed_blade_detail.png": blade_detail(source / "blade.jpg"),
    }
    for name, img in results.items():
        img.save(output / name, optimize=True)
        print(f"wrote {(output / name).relative_to(ROOT)}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=SOURCE_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args(argv)
    build(args.source, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
