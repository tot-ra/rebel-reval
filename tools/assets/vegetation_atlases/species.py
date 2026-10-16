"""Species parameters and stable texture layout contracts."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

SEED = 1343
TILE = 512
SS = 2  # supersampling factor for every drawn tile
GRID = (4, 2)
# Tile order is a runtime contract: MapViewLeafGeometry.CARD_TILES.
TILES = ["birch", "oak", "maple", "linden", "apple", "spruce", "pine"]
LEAF_DIR = Path("assets/materials/pbr/foliage_cards")
VEG_DIR = Path("assets/vegetation")
BARK_KINDS = ["birch", "oak", "grey", "pine", "spruce", "cherry"]
GROUND_KINDS = ["moss", "leaf_litter", "needle_litter"]
EARS = ["rye", "barley", "oat", "flax"]
PLATE = 512
EAR_TILE = (256, 512)


# --------------------------------------------------------------------------
# Species parameters. Colours are linear-ish sRGB 0..1 before normalisation;
# only their relative variation survives in the atlas, so they set hue shifts
# between leaves, veins, wear and twig, not the final crown colour.


@dataclass(frozen=True)
class LeafSpecies:
    shape: str
    length: float  # leaf blade length as a fraction of the cluster height
    width: float  # blade width / length
    colour: tuple[float, float, float]
    leaves: int
    layout: str
    petiole: float  # petiole length / blade length
    vein_pairs: int
    vein_slope: float  # how far a secondary vein runs tipward per unit across
    serrations: int
    serration_depth: float
    lobes: int = 0
    lobe_depth: float = 0.0
    roughness: float = 0.6
    translucency: float = 0.75
    wear: float = 0.15  # share of leaves with browned tips or margins
    coverage: float = 0.40  # alpha coverage the tile is tuned to (old tile's value)
    size_scale: float = 1.0  # foliage size multiplier found by --tune for `coverage`
    side_shoots: tuple[tuple[float, int, float, int], ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class NeedleSpecies:
    colour: tuple[float, float, float]
    tip_colour: tuple[float, float, float]
    needle_length: float
    needle_radius: float
    spacing: float
    fascicle: int  # needles per attachment point (1 spruce, 2 pine)
    spread: tuple[float, float]  # needle angle from the shoot, radians
    shoots: tuple[tuple[float, int, float], ...]  # (t on axis, side, length)
    curve: float
    roughness: float
    translucency: float
    coverage: float = 0.40
    size_scale: float = 1.0


LEAVES: dict[str, LeafSpecies] = {
    # Silver birch: small deltoid leaves, double-serrate, alternate on fine
    # branched twigs; several short side shoots carry the cluster.
    "birch": LeafSpecies(
        shape="deltoid", length=0.15, width=0.70, colour=(0.40, 0.56, 0.20), leaves=15,
        layout="alternate", petiole=0.35, vein_pairs=7, vein_slope=0.75, serrations=16,
        serration_depth=0.07, roughness=0.55, translucency=0.85, wear=0.10, coverage=0.34, size_scale=2.1,
        side_shoots=((0.22, 1, 0.50, 5), (0.34, -1, 0.60, 6), (0.52, 1, 0.55, 5),
                     (0.70, -1, 0.40, 4)),
    ),
    # Pedunculate oak: obovate, 5 rounded lobes a side, near-sessile, crowded
    # into rosettes at the shoot tip.
    "oak": LeafSpecies(
        shape="lobed", length=0.33, width=0.62, colour=(0.30, 0.43, 0.16), leaves=9,
        layout="rosette", petiole=0.05, vein_pairs=6, vein_slope=0.55, serrations=0,
        serration_depth=0.0, lobes=4, lobe_depth=0.42, roughness=0.62, translucency=0.62,
        wear=0.25, coverage=0.45, size_scale=2.6,
    ),
    # Norway maple: palmate, five pointed lobes, long petioles, opposite pairs.
    "maple": LeafSpecies(
        shape="palmate", length=0.36, width=1.0, colour=(0.34, 0.52, 0.18), leaves=5,
        layout="opposite", petiole=0.30, vein_pairs=5, vein_slope=0.0, serrations=0,
        serration_depth=0.0, lobes=5, lobe_depth=0.55, roughness=0.5, translucency=0.8,
        wear=0.12, coverage=0.41, size_scale=3.6,
    ),
    # Small-leaved linden: cordate, oblique base, fine serration, two-ranked.
    "linden": LeafSpecies(
        shape="cordate", length=0.24, width=0.92, colour=(0.33, 0.50, 0.19), leaves=12,
        layout="distichous", petiole=0.40, vein_pairs=6, vein_slope=0.6, serrations=24,
        serration_depth=0.035, roughness=0.5, translucency=0.82, wear=0.12, coverage=0.47, size_scale=1.9,
        side_shoots=((0.30, -1, 0.50, 4), (0.50, 1, 0.45, 4)),
    ),
    # Apple: elliptic, finely crenate, clustered on short spurs.
    "apple": LeafSpecies(
        shape="elliptic", length=0.21, width=0.55, colour=(0.31, 0.47, 0.18), leaves=12,
        layout="spurs", petiole=0.30, vein_pairs=8, vein_slope=0.7, serrations=30,
        serration_depth=0.025, roughness=0.58, translucency=0.7, wear=0.18, coverage=0.39, size_scale=3.0,
    ),
}

NEEDLES: dict[str, NeedleSpecies] = {
    # Norway spruce: short stiff single needles around every shoot, side shoots
    # alternate at a forward angle, pale new growth at the shoot tips.
    "spruce": NeedleSpecies(
        colour=(0.15, 0.27, 0.13), tip_colour=(0.21, 0.35, 0.15), needle_length=0.050,
        needle_radius=0.0042, spacing=0.0080, fascicle=1, spread=(0.80, 1.30),
        shoots=((0.12, -1, 0.46), (0.20, 1, 0.48), (0.30, -1, 0.44), (0.40, 1, 0.42),
                (0.50, -1, 0.36), (0.60, 1, 0.32), (0.70, -1, 0.25), (0.79, 1, 0.19),
                (0.87, -1, 0.12)),
        curve=0.05, roughness=0.45, translucency=0.35, coverage=0.39, size_scale=3.3,
    ),
    # Scots pine: long twisted needles in pairs, splaying forward from the
    # shoot, blue-green, a whorl of side shoots at the base.
    "pine": NeedleSpecies(
        colour=(0.25, 0.36, 0.24), tip_colour=(0.30, 0.42, 0.26), needle_length=0.21,
        needle_radius=0.0085, spacing=0.008, fascicle=2, spread=(0.30, 0.95),
        shoots=((0.14, -1, 0.58), (0.16, 1, 0.56), (0.20, -1, 0.42), (0.22, 1, 0.44),
                (0.40, -1, 0.34), (0.44, 1, 0.32)),
        curve=0.18, roughness=0.42, translucency=0.30, coverage=0.52, size_scale=1.8,
    ),
}

TWIG = (0.30, 0.22, 0.15)
