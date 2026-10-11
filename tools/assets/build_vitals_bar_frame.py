#!/usr/bin/env python3
"""Cut the painted bronze vitals bar frame out of its Leonardo plate (R-1798).

The raw plate is a bronze rope-twist frame on flat white (white outside and in
the opening). Usage:

    python3 tools/assets/build_vitals_bar_frame.py \
        generated/leonardo/vitals_bar_frame_v1/frame_candidate_1.jpg \
        assets/UI/vitals/vitals_bar_frame.png

WHY a flood fill instead of a luminance key: the bronze has pale highlights
that a plain "near white -> transparent" key would punch holes into. Only
white connected to the outside or to the opening becomes transparent; a thin
edge band gets soft alpha and is un-premultiplied from white so no white halo
survives on dark game scenes.
"""

from __future__ import annotations

import sys

import numpy as np
from PIL import Image

# Frame bounds measured on generation 1f1c5b87-dc5b-67c0-8299-3d0ec4af077f (candidate 1)
# (stud tips at x 48 / 1296, rims at y 300 / 480), plus a little padding.
CROP = (40, 292, 1305, 489)
OUT_HEIGHT = 80
BG_DISTANCE = 30  # max (255 - min channel) still counted as background white
EDGE_BAND = 2


def _flood(candidate: np.ndarray, seeds: list[tuple[int, int]]) -> np.ndarray:
    region = np.zeros_like(candidate)
    for y, x in seeds:
        region[y, x] = candidate[y, x]
    while True:
        grown = region.copy()
        grown[1:, :] |= region[:-1, :]
        grown[:-1, :] |= region[1:, :]
        grown[:, 1:] |= region[:, :-1]
        grown[:, :-1] |= region[:, 1:]
        grown &= candidate
        if (grown == region).all():
            return region
        region = grown


def _dilate(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def build(raw_path: str, out_path: str) -> None:
    rgb = np.asarray(Image.open(raw_path).convert("RGB").crop(CROP)).astype(np.float32)
    distance = 255.0 - rgb.min(axis=2)
    h, w = distance.shape
    background = _flood(distance < BG_DISTANCE, [(0, 0), (h - 1, w - 1), (h // 2, w // 2)])
    alpha = np.ones((h, w), np.float32)
    alpha[background] = 0.0
    band = _dilate(background, EDGE_BAND) & ~background
    alpha[band] = np.clip(distance[band] / 90.0, 0.0, 1.0)
    # Un-premultiply from white: observed = a * colour + (1 - a) * 255.
    safe = np.maximum(alpha, 1e-3)[..., None]
    colour = np.clip((rgb - 255.0 * (1.0 - alpha[..., None])) / safe, 0.0, 255.0)
    colour[alpha == 0.0] = 0.0
    rgba = np.dstack([colour, alpha * 255.0]).round().astype(np.uint8)
    image = Image.fromarray(rgba)
    width = round(image.width * OUT_HEIGHT / image.height)
    image.resize((width, OUT_HEIGHT), Image.LANCZOS).save(out_path, optimize=True)
    print(f"{out_path}: {width}x{OUT_HEIGHT}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2])
