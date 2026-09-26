"""Realistic human character specs (ADR 0022).

Pure data, importable without Blender. Each spec drives
`build_human.py`: an MPFB/MakeHuman CC0 base body shaped by macro and
detail targets, bound to the shared 41-bone motion rig, then dressed in
separately fitted, historically grounded garments (see
history/dossiers/dailylife/clothing-and-status-markers.md).

Units are metres. MakeHuman macro `age` maps 0.5 -> 25 years and
1.0 -> 90 years; `age_years()` converts.
"""


def age_years(years: float) -> float:
    if years <= 25:
        return 0.1875 + (years - 1) * (0.5 - 0.1875) / 24.0
    return min(1.0, 0.5 + (years - 25) * 0.5 / 65.0)


# Garment colours are linear-ish sRGB triples for undyed and period-dyed
# cloth; see the materials table in the clothing dossier.
UNDYED_GREY_BROWN = (0.34, 0.29, 0.23)
WOAD_BLUE = (0.20, 0.27, 0.36)
MADDER_RED = (0.47, 0.17, 0.12)
RUSSET = (0.36, 0.20, 0.12)
LINEN_UNBLEACHED = (0.78, 0.73, 0.62)
LEATHER_DARK = (0.20, 0.12, 0.07)
LEATHER_TAN = (0.40, 0.25, 0.14)

SPECS = {
    # Mid-40s Estonian master smith: dossier "Art - Kalev (hero)".
    "kalev": {
        "stable_id": "char.kalev",
        "fit": "kalev",
        "tier": 0,
        "height_m": 1.80,
        "macros": {
            "gender": 1.0, "age": age_years(44), "muscle": 0.9, "weight": 0.64,
            "proportions": 0.85, "height": 0.55, "cupsize": 0.5, "firmness": 0.5,
            "race": {"caucasian": 1.0, "asian": 0.0, "african": 0.0},
        },
        "targets": {
            "head-square": 0.45, "head-age-incr": 0.5,
            "chin-prominent-incr": 0.35, "chin-width-incr": 0.35,
            "nose-hump-incr": 0.4, "nose-scale-horiz-incr": 0.25, "nose-point-width-incr": 0.3,
            "nose-trans-down": 0.15,
            "eyebrows-trans-down": 0.25, "eyebrows-angle-down": 0.25,
            "mouth-laugh-lines-in": 0.5, "mouth-scale-horiz-incr": 0.1,
            "neck-scale-horiz-incr": 0.45, "neck-scale-depth-incr": 0.35,
            "torso-muscle-dorsi-incr": 0.5, "torso-muscle-pectoral-incr": 0.35,
            "torso-scale-horiz-incr": 0.2, "torso-vshape-incr": 0.3, "measure-shoulder-dist-incr": 0.45,
            "measure-upperarm-circ-incr": 0.4, "l-lowerarm-muscle-incr": 0.8, "r-lowerarm-muscle-incr": 0.9,
            "l-upperarm-muscle-incr": 0.5, "r-upperarm-muscle-incr": 0.6, "measure-neck-circ-incr": 0.4,
            "measure-waist-circ-incr": 0.25,
        },
        "skin": "middleage_caucasian_male",
        "eyes": "brownlight",
        "eyebrows": "eyebrow004",
        "eyelashes": "eyelashes02",
        # Dark brown hair brushed back (reference brief). short02's crown
        # tufts render as dark flaps in Godot; short04 lies flat.
        "hair": "short04",
        "hair_color": (0.24, 0.18, 0.13),

        # Short grizzled beard (reference brief) as alpha-tested fur shells.
        "beard": {"style": "full_short", "length": 0.008, "color": (0.30, 0.22, 0.15), "grey": 0.28,
                  "coverage": 0.78, "shells": 7},
        # Complexion overlays baked into the skin albedo.
        "complexion": {"tan": 0.55, "flush": 0.45, "soot_forearms": 0.35, "stubble": 0.0},
        "garments": ["linen_shirt", "work_tunic", "wool_tunic", "hose", "boots", "smith_apron",
                     "hood", "gambeson", "mail_haubergeon", "kettle_hat"],
        # Named outfits (dossier: forge dress; street/travel; armed watch duty).
        "outfits": {
            "forge": ["work_tunic", "smith_apron", "hose", "boots"],
            "street": ["wool_tunic", "hose", "boots"],
            "travel": ["wool_tunic", "hood", "hose", "boots"],
            "armed": ["gambeson", "mail_haubergeon", "kettle_hat", "hose", "boots"],
            "undress": ["linen_shirt"],
        },
        "palette": {
            "wool_tunic": UNDYED_GREY_BROWN, "hose": (0.22, 0.20, 0.17),
            "hood": WOAD_BLUE, "gambeson": (0.62, 0.56, 0.44),
        },
    },
}
