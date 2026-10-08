#!/usr/bin/env python3
"""Rebuild the leaf-cluster card atlas (R-1194 slot, procedural since R-1329).

The atlas used to be keyed from Leonardo leaf plates (leaf_cards_v1) plus OpenAI
needle plates. R-1329 replaced both with tools/assets/generate_vegetation_atlases.py,
which draws every species from parametric outlines; no image-generator source is
read any more. This entry point is kept so existing docs and habits keep working:
it regenerates the whole vegetation set (the leaf atlas and its normal/surface
companions included) through the generator.

Usage: python3 tools/assets/build_leaf_card_atlas.py
Tile order must match MapViewLeafGeometry.CARD_TILES (generator TILES).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_vegetation_atlases  # noqa: E402

TILES = generate_vegetation_atlases.TILES
GRID = generate_vegetation_atlases.GRID
TILE = generate_vegetation_atlases.TILE

if __name__ == "__main__":
    sys.argv = sys.argv[:1]
    raise SystemExit(generate_vegetation_atlases.main())
