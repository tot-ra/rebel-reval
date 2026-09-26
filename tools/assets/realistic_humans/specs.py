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

def _person(age, sex, muscle, weight, height_m, skin, eyes, hair, hair_color, brows, targets,
            complexion, garments, palette, outfits, beard=None, stubble=None, lashes="eyelashes02",
            extra=None, tier=1):
    """Compact spec for a named character (see the Kalev entry for every key)."""
    spec = {
        "tier": tier, "height_m": height_m,
        "macros": {"gender": 1.0 if sex == "m" else 0.0, "age": age_years(age), "muscle": muscle,
                   "weight": weight, "proportions": 0.7, "height": 0.5, "cupsize": 0.5, "firmness": 0.5,
                   "race": {"caucasian": 1.0, "asian": 0.0, "african": 0.0}},
        "targets": targets, "skin": skin, "eyes": eyes, "eyebrows": brows, "eyelashes": lashes,
        "hair": hair, "hair_color": hair_color, "complexion": complexion,
        "garments": garments, "palette": palette, "outfits": outfits,
    }
    if beard:
        spec["beard"] = dict({"style": "full_short"}, **beard)
    if stubble:
        spec["stubble"] = stubble
    spec.update(extra or {})
    return spec


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
        # Hero polish: original generated portrait (P0-214 reference, project
        # owned) projected onto the front of the face for photo-grade skin.
        "face_photo": {"path": "assets/characters/kalev_fresh/reference/face.png",
                       "landmarks": {"eye_l": [636, 548], "eye_r": [378, 548],
                                     "nose_tip": [512, 690], "mouth": [512, 850]}},
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

    # --- Named cast -------------------------------------------------------
    # Mart: Kalev's apprentice (docs/CHARACTERS/mart.md). Dossier: oversized
    # hand-me-down tunic, bare head, no belt knife, smaller than Kalev.
    "mart": _person(
        age=16, sex="m", muscle=0.5, weight=0.42, height_m=1.66, skin="young_caucasian_male",
        eyes="lightblue", hair="short01", hair_color=(0.44, 0.34, 0.24), brows="eyebrow002",
        targets={"head-age-decr": 0.35, "nose-scale-vert-decr": 0.2, "chin-prominent-decr": 0.2,
                 "cheek-volume-incr": 0.2, "neck-scale-horiz-decr": 0.2},
        complexion={"tan": 0.45, "flush": 0.4, "soot_forearms": 0.3},
        garments=["short_tunic", "hose", "boots"],
        palette={"short_tunic": (0.52, 0.42, 0.30), "hose": (0.30, 0.27, 0.22)},
        extra={"tunic_ease": 0.022, "belted": False},
        outfits={"work": ["short_tunic", "hose", "boots"]}),
    # Captain Henning of the Viru Watch (docs/CHARACTERS/henning.md): armed
    # authority; padded aketon, mail and iron hat over street dress.
    "henning": _person(
        age=48, sex="m", muscle=0.75, weight=0.62, height_m=1.78, skin="middleage_caucasian_male",
        eyes="grey", hair="short01", hair_color=(0.36, 0.33, 0.29), brows="eyebrow004",
        targets={"head-square": 0.5, "chin-width-incr": 0.4, "nose-hump-incr": 0.5,
                 "eyebrows-trans-down": 0.35, "mouth-angles-down": 0.3, "head-age-incr": 0.4},
        beard={"length": 0.006, "color": (0.34, 0.31, 0.27), "grey": 0.55, "coverage": 0.82, "shells": 6},
        complexion={"tan": 0.5, "flush": 0.5},
        garments=["wool_tunic", "gambeson", "mail_haubergeon", "kettle_hat", "hose", "boots"],
        palette={"gambeson": (0.36, 0.40, 0.46), "wool_tunic": (0.24, 0.26, 0.30), "hose": (0.18, 0.18, 0.20)},
        outfits={"armed": ["gambeson", "mail_haubergeon", "kettle_hat", "hose", "boots"],
                 "street": ["wool_tunic", "hose", "boots"]}),
    # Juergen Witte, Hanseatic amber merchant (docs/CHARACTERS/jurgen.md):
    # mid-calf fine wool in madder, parti-coloured hose, hood, purse.
    "jurgen": _person(
        age=52, sex="m", muscle=0.35, weight=0.8, height_m=1.74, skin="middleage_caucasian_male",
        eyes="blue", hair="short03", hair_color=(0.50, 0.45, 0.37), brows="eyebrow001",
        targets={"head-round": 0.3, "head-fat-incr": 0.4, "neck-double-incr": 0.5, "nose-volume-incr": 0.3,
                 "mouth-scale-horiz-decr": 0.15, "head-age-incr": 0.4},
        stubble={"color": (0.45, 0.40, 0.34), "amount": 0.25},
        complexion={"tan": 0.2, "flush": 0.55},
        garments=["long_tunic", "hose", "boots", "hood"],
        palette={"long_tunic": MADDER_RED, "hose": WOAD_BLUE, "hose_right": MADDER_RED,
                 "hood": (0.18, 0.20, 0.26), "boots": (0.14, 0.09, 0.06)},
        outfits={"street": ["long_tunic", "hose", "boots", "hood"]}),
    # Kaja, bilingual courier (docs/CHARACTERS/kaja.md): working gown and
    # headscarf of an Estonian townswoman who travels.
    "kaja": _person(
        age=26, sex="f", muscle=0.5, weight=0.42, height_m=1.64, skin="young_caucasian_female",
        eyes="bluegreen", hair="braid01", hair_color=(0.42, 0.33, 0.22), brows="eyebrow006",
        lashes="eyelashes03",
        targets={"cheek-bones-incr": 0.3, "chin-prominent-incr": 0.15, "nose-scale-horiz-decr": 0.15},
        complexion={"tan": 0.4, "flush": 0.35},
        garments=["work_gown", "headscarf", "boots"],
        palette={"work_gown": WOAD_BLUE, "headscarf": (0.72, 0.67, 0.56)},
        outfits={"travel": ["work_gown", "headscarf", "boots"]}),
    # Aita, alewife and healer (docs/CHARACTERS/aita.md): gown, apron, headscarf.
    "aita": _person(
        age=42, sex="f", muscle=0.45, weight=0.62, height_m=1.62, skin="middleage_caucasian_female",
        eyes="brown", hair="bob01", hair_color=(0.30, 0.22, 0.16), brows="eyebrow006", lashes="eyelashes03",
        targets={"head-round": 0.2, "cheek-volume-incr": 0.3, "head-age-incr": 0.2},
        complexion={"tan": 0.35, "flush": 0.55},
        garments=["work_gown", "waist_apron", "headscarf", "boots"],
        palette={"work_gown": RUSSET, "headscarf": (0.78, 0.74, 0.64)},
        extra={"apron_over": "work_gown"},
        outfits={"work": ["work_gown", "waist_apron", "headscarf", "boots"]}),
    # Ellen Luik, midwife and keeper of old songs (docs/CHARACTERS/ellen.md).
    "ellen": _person(
        age=63, sex="f", muscle=0.3, weight=0.48, height_m=1.58, skin="old_caucasian_female",
        eyes="grey", hair="long01", hair_color=(0.62, 0.60, 0.56), brows="eyebrow006", lashes="eyelashes01",
        targets={"head-age-incr": 0.8, "cheek-bones-incr": 0.3, "nose-hump-incr": 0.2,
                 "mouth-laugh-lines-in": 0.6},
        complexion={"tan": 0.4, "flush": 0.3},
        garments=["gown", "headscarf", "boots"],
        palette={"gown": (0.22, 0.20, 0.18), "headscarf": (0.30, 0.28, 0.25)},
        outfits={"daily": ["gown", "headscarf", "boots"]}),
    # Burgher wife (female base): long gown, linen coif and veil, keys belt.
    "townswoman": _person(
        age=34, sex="f", muscle=0.4, weight=0.5, height_m=1.63, skin="young_caucasian_female2",
        eyes="blue", hair="bob01", hair_color=(0.38, 0.30, 0.20), brows="eyebrow006", lashes="eyelashes03",
        targets={"nose-scale-horiz-decr": 0.1, "chin-prominent-decr": 0.1},
        complexion={"tan": 0.15, "flush": 0.35},
        garments=["gown", "veil", "boots"],
        palette={"gown": WOAD_BLUE},
        outfits={"church": ["gown", "veil", "boots"]}),
    # Lower Town watch militia: padded jack and iron cap over the tunic.
    "watchman": _person(
        age=30, sex="m", muscle=0.5, weight=0.5, height_m=1.74, skin="young_caucasian_male",
        eyes="brown", hair="short01", hair_color=(0.30, 0.23, 0.16), brows="eyebrow002",
        targets={"nose-point-width-incr": 0.3, "chin-width-incr": 0.2},
        beard={"length": 0.007, "color": (0.30, 0.23, 0.16), "grey": 0.0, "coverage": 0.7, "shells": 6},
        complexion={"tan": 0.5, "flush": 0.4},
        garments=["short_tunic", "gambeson", "kettle_hat", "hose", "boots"],
        palette={"gambeson": (0.60, 0.54, 0.42), "short_tunic": UNDYED_GREY_BROWN},
        outfits={"duty": ["gambeson", "kettle_hat", "hose", "boots"]}),
    "sergeant": _person(
        age=40, sex="m", muscle=0.85, weight=0.66, height_m=1.76, skin="middleage_caucasian_male",
        eyes="green", hair="short01", hair_color=(0.28, 0.20, 0.13), brows="eyebrow004",
        targets={"head-square": 0.4, "nose-hump-incr": 0.3, "eyebrows-trans-down": 0.3,
                 "measure-shoulder-dist-incr": 0.6, "torso-vshape-incr": 0.4},
        beard={"length": 0.009, "color": (0.30, 0.21, 0.13), "grey": 0.2, "coverage": 0.8, "shells": 6},
        complexion={"tan": 0.55, "flush": 0.45},
        garments=["gambeson", "mail_haubergeon", "kettle_hat", "hose", "boots"],
        palette={"gambeson": (0.44, 0.28, 0.20)},
        outfits={"duty": ["gambeson", "mail_haubergeon", "kettle_hat", "hose", "boots"]}),
    # Danish crown man-at-arms (Toompea garrison): mail under a red surcoat.
    "danish_warrior": _person(
        age=35, sex="m", muscle=0.82, weight=0.6, height_m=1.79, skin="middleage_caucasian_male",
        eyes="lightblue", hair="short04", hair_color=(0.55, 0.45, 0.30), brows="eyebrow002",
        targets={"head-square": 0.3, "chin-prominent-incr": 0.3, "cheek-bones-incr": 0.3},
        beard={"length": 0.012, "color": (0.52, 0.40, 0.26), "grey": 0.05, "coverage": 0.85, "shells": 7},
        complexion={"tan": 0.45, "flush": 0.5},
        garments=["gambeson", "mail_haubergeon", "surcoat", "kettle_hat", "hose", "boots"],
        palette={"surcoat": (0.52, 0.10, 0.08)},
        outfits={"armed": ["gambeson", "mail_haubergeon", "surcoat", "kettle_hat", "hose", "boots"]}),
    # Harju rebel / brigand outside the walls: coarse homespun, hood.
    "bandit": _person(
        age=28, sex="m", muscle=0.6, weight=0.38, height_m=1.72, skin="young_caucasian_male2",
        eyes="grey", hair="short03", hair_color=(0.34, 0.27, 0.18), brows="eyebrow004",
        targets={"cheek-inner-incr": 0.3, "nose-hump-incr": 0.35, "eyebrows-trans-down": 0.3},
        beard={"length": 0.01, "color": (0.34, 0.27, 0.18), "grey": 0.0, "coverage": 0.65, "shells": 6},
        complexion={"tan": 0.7, "flush": 0.35, "soot_forearms": 0.2},
        garments=["short_tunic", "hood", "hose", "boots"],
        palette={"short_tunic": (0.30, 0.27, 0.22), "hood": (0.26, 0.20, 0.14), "hose": (0.25, 0.22, 0.18)},
        outfits={"field": ["short_tunic", "hood", "hose", "boots"]}),
    # Innkeeper: heavy, clean-shaven, linen apron over a russet tunic.
    "innkeeper": _person(
        age=50, sex="m", muscle=0.4, weight=0.86, height_m=1.70, skin="middleage_caucasian_male",
        eyes="brown", hair="short01", hair_color=(0.40, 0.36, 0.31), brows="eyebrow001",
        targets={"head-fat-incr": 0.5, "neck-double-incr": 0.6, "head-round": 0.4, "nose-volume-incr": 0.4},
        stubble={"color": (0.38, 0.33, 0.28), "amount": 0.35},
        complexion={"tan": 0.3, "flush": 0.65},
        garments=["wool_tunic", "waist_apron", "hose", "boots"],
        palette={"wool_tunic": RUSSET},
        outfits={"work": ["wool_tunic", "waist_apron", "hose", "boots"]}),
}

for _name, _spec in SPECS.items():
    _spec.setdefault("fit", _name)
    _spec.setdefault("stable_id", f"char.{_name}")
