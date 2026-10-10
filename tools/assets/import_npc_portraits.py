#!/usr/bin/env python3
"""Crop painted NPC reference art into square dialogue portraits (R-1566).

Every characters/**/img/<slug>.jpg becomes assets/characters/portraits/npc/<slug>.png,
a head-and-shoulders square (the dialogue frame is square) in sRGB, max 256 px.
Idempotent: output is a pure function of the source. Slugs must be unique across groups.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_GLOB = "characters/**/img/*.jpg"
OUT_DIR = ROOT / "assets/characters/portraits/npc"
MAX_SIDE = 256  # frame is 96 px; larger PNG photos bloat the repo (768 px = 45 MB)
# Reference sheets are full-body 2:3 figures with the head in the upper third;
# a square from the top edge keeps head and shoulders without the torso.
TOP_BIAS = 0.0


def crop_portrait(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    w, h = img.size
    side = min(w, h)
    top = int((h - side) * TOP_BIAS)
    left = (w - side) // 2
    out = img.crop((left, top, left + side, top + side))
    if side > MAX_SIDE:
        out = out.resize((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    return out


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    seen: dict[str, Path] = {}
    for src in sorted(ROOT.glob(SRC_GLOB)):
        slug = src.stem
        if slug in seen:
            print(f"duplicate slug {slug}: {src} vs {seen[slug]}", file=sys.stderr)
            return 1
        seen[slug] = src
        crop_portrait(Image.open(src)).save(OUT_DIR / f"{slug}.png", optimize=True)
    print(f"{len(seen)} portraits written to {OUT_DIR.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
