"""Blank body library for the citizens of Reval (docs/SYSTEMS/CITIZENS.md).

The census gives every resident a sex, age, height and a build phrase. Building
4,247 bespoke bodies is not possible and not wanted yet (each resident gets a
painted face later), so residents are matched to a small set of blank,
period-plain Tier 2 bodies that differ in the things a viewer reads at once:
sex, life stage, weight, belly, bust and shoulders. Height is a uniform runtime
scale of the body (`scripts/city/citizen_body.gd`), head size a runtime bone scale.

Pure data, importable without Blender. The key set is mirrored by
`tools/city/build_citizen_runtime.py` (build phrase -> body id) and checked by
`tests/python/test_citizen_bodies.py`.
"""

import json
from pathlib import Path

# MakeHuman macro age: 0 -> 1 y, 0.1875 -> 11 y, 0.5 -> 25 y, 1.0 -> 90 y.
_AGE_KNOTS = [(1, 0.0), (11, 0.1875), (25, 0.5), (90, 1.0)]


def mh_age(years):
    for (y0, a0), (y1, a1) in zip(_AGE_KNOTS, _AGE_KNOTS[1:]):
        if years <= y1:
            return a0 + (max(years, y0) - y0) * (a1 - a0) / (y1 - y0)
    return 1.0


# Plain undyed cloth: colour comes later with the per-resident textures.
CLOTH = (0.46, 0.42, 0.35)
LINEN = (0.72, 0.67, 0.56)
DARK = (0.24, 0.20, 0.16)

# build class -> (weight, muscle, extra MakeHuman targets) per sex.
# weight 0.5 is average; the census build phrases fold into these four.
_BUILDS = {
    "m": {
        "thin": (0.26, 0.40, {"torso-scale-horiz-decr": 0.15}),
        "average": (0.50, 0.50, {}),
        "sturdy": (0.62, 0.72, {"torso-vshape-incr": 0.35, "measure-shoulder-dist-incr": 0.35,
                                "neck-scale-horiz-incr": 0.25}),
        "heavy": (0.88, 0.42, {"stomach-pregnant-incr": 0.75, "torso-scale-horiz-incr": 0.2,
                               "neck-scale-horiz-incr": 0.2, "cheek-volume-incr": 0.3}),
    },
    "f": {
        "thin": (0.28, 0.35, {}),
        "average": (0.50, 0.40, {}),
        "sturdy": (0.62, 0.55, {"measure-shoulder-dist-incr": 0.2}),
        "heavy": (0.88, 0.35, {"stomach-pregnant-incr": 0.45, "cheek-volume-incr": 0.3}),
    },
}
_CUP = {"thin": 0.25, "average": 0.5, "sturdy": 0.6, "heavy": 0.9}

# (sex, stage) -> (age in years, reference height in metres of the body).
_STAGES = {
    ("m", "adult"): (32, 1.68), ("f", "adult"): (32, 1.57),
    ("m", "elder"): (66, 1.64), ("f", "elder"): (66, 1.52),
    ("m", "child"): (8, 1.28), ("f", "child"): (8, 1.27),
}
# Builds modelled per life stage (the rest fold into the nearest).
STAGE_BUILDS = {"adult": ("thin", "average", "sturdy", "heavy"),
                "elder": ("thin", "heavy"), "child": ("average",)}

SKIN = {("m", "child"): "young_caucasian_male", ("f", "child"): "young_caucasian_female",
        ("m", "adult"): "middleage_caucasian_male", ("f", "adult"): "middleage_caucasian_female",
        ("m", "elder"): "old_caucasian_male", ("f", "elder"): "old_caucasian_female"}


# Adults come in two outfits: "a" the short work tunic / work gown, "b" the long
# tunic (men) / gown with apron (women) worn by the better-off. Dyes are runtime.
# Women have two more (WD-3, docs/SYSTEMS/CITIZEN_WARDROBE.md): "c" the fitted,
# buttoned kirtle under a sideless surcoat of patrician and noble women (1340s),
# "d" the Estonian linen shift, wool wrap skirt and solg brooch.
# Men (EQ-21, R-2023): "a" the short tunic, "b" the calf-length tunic of the better-off,
# "c" the buttoned cotehardie of rich young men (1340s fashion). Elders wear the long tunic.
OUTFITS = ("a", "b", "c")
FEMALE_OUTFITS = ("a", "b", "c", "d")


def outfits_of(sex, stage):
    """Base outfits modelled for one life stage (children and elders wear "a")."""
    if stage != "adult":
        return ("a",)
    return FEMALE_OUTFITS if sex == "f" else OUTFITS


def outfit_of(body):
    """Outfit letter of a body id (`citizen_f_adult_thin_c` -> "c")."""
    tail = body.rsplit("_", 1)[-1]
    return tail if tail in FEMALE_OUTFITS[1:] else "a"


# Layers fitted to each body and exported apart from it (build_human.py writes
# assets/characters/realistic/shapes/<layer_body>/layers/<layer>.glb, see
# layer_body); the census wardrobe
# rules in tools/city/build_citizen_runtime.py pick which ones a resident wears
# (docs/SYSTEMS/CITIZEN_WARDROBE.md). Order matters: aprons and accessories fit
# over the baked base, the armour kit stacks aketon -> mail -> mail coif -> surcoat.
LAYERS = {
    ("m", "adult"): ("hood", "coif", "wool_cap", "smith_apron", "waist_apron", "keys", "paternoster",
                     "satchel", "back_sack", "gambeson", "mail_haubergeon", "coat_of_plates", "mail_coif",
                     "aventail", "surcoat", "order_mantle", "kettle_hat", "bascinet", "great_helm",
                     "mail_chausses", "gauntlets"),
    ("m", "elder"): ("hood", "coif", "wool_cap", "waist_apron", "keys", "paternoster", "satchel"),
    ("m", "child"): ("hood", "coif", "wool_cap"),
    # Women's head follows marriage (WD-3): maidens wear their braids (the hair is a
    # layer, so it can come off), wives the headscarf or the Estonian head cloth.
    ("f", "adult"): ("braids", "headscarf", "head_cloth", "wimple", "barbette", "veil_over", "waist_apron",
                     "keys", "paternoster", "satchel"),
    ("f", "elder"): ("headscarf", "wimple", "barbette", "veil_over", "keys", "paternoster"),
    ("f", "child"): (),
}
# Layers a woman's base outfit rules out: the long gown bakes its apron; the
# patrician surcoat takes neither apron nor scrip; the head cloth is the Estonian
# wife's and the white burgher veil is not worn over it. Wimple and barbette are German
# burgher dress: the Estonian wrap-skirt body (d) wears neither.
_NOT_WITH = {"b": {"waist_apron", "head_cloth"}, "c": {"waist_apron", "satchel", "head_cloth"},
             "a": {"head_cloth"}, "d": {"veil_over", "wimple", "barbette"}}
# A young man of fashion in his cotehardie does not work in an apron or carry a sack.
_MEN_NOT_WITH = {"c": {"smith_apron", "waist_apron", "back_sack"}}
# Extra ease (m) for torso layers so they clear the baked tunic, its blousing and belt.
LAYER_EASE = 0.022


def layers_of(sex, stage, outfit="a"):
    """Layer ids fitted to one body (see _NOT_WITH and _MEN_NOT_WITH for what an outfit rules out)."""
    skip = (_NOT_WITH if sex == "f" else _MEN_NOT_WITH).get(outfit, set())
    return tuple(g for g in LAYERS[(sex, stage)] if g not in skip)


def body_id(sex, stage, build, outfit="a"):
    return f"citizen_{sex}_{stage}_{build}" + ("" if outfit == "a" else f"_{outfit}")


# Variants of one body shape (sex, stage, build) share one MPFB body, so a layer that
# does not sit over the baked outfit comes out identical for all of them. The fit table
# maps shape -> layer -> outfit -> the outfit whose build ships the file (R-2212); the
# runtime (CitizenWardrobe.layer_body) reads the same file. It is measured from the
# built GLBs by `share_layers.py --measure` (outfits merge where their vertex
# positions are equal).
LAYER_FIT_PATH = Path(__file__).resolve().parents[3] / "assets/characters/realistic/layer_fit.json"
SHAPES_DIR = "shapes"
_fit = {}


def layer_fit():
    if not _fit:
        _fit.update(json.loads(LAYER_FIT_PATH.read_text()))
    return _fit


def layer_body(sex, stage, build, outfit, layer):
    """Body whose build writes `layer` for this body: the layer's folder under shapes/.

    A layer missing from the fit table stays with its own body."""
    shape = layer_fit().get(f"{sex}_{stage}_{build}", {})
    return body_id(sex, stage, build, shape.get(layer, {}).get(outfit, outfit))


def parse_body(body):
    """`citizen_f_adult_thin_c` -> (sex, stage, build, outfit), or None for other bodies."""
    parts = body.split("_")
    if parts[0] != "citizen" or len(parts) not in (4, 5):
        return None
    return parts[1], parts[2], parts[3], parts[4] if len(parts) == 5 else "a"


def layer_path(body, layer):
    """Repo-relative path of the GLB that body wears for `layer`."""
    parsed = parse_body(body)
    owner = layer_body(*parsed, layer) if parsed else body
    return f"assets/characters/realistic/{SHAPES_DIR}/{owner}/layers/{layer}.glb"


def reference_height_m(sex, stage):
    return _STAGES[(sex, stage)][1]


def _spec(person, sex, stage, build, outfit="a"):
    age, height = _STAGES[(sex, stage)]
    weight, muscle, extra = _BUILDS[sex][build]
    targets = dict(extra)
    if stage == "elder":
        targets.update({"head-age-incr": 0.6, "mouth-laugh-lines-in": 0.4})
        muscle = min(muscle, 0.35)
    if stage == "child":
        targets.update({"head-age-decr": 0.3})
    male = sex == "m"
    extra = {}
    if male and (outfit == "b" or stage == "elder"):
        # Calf length shows age and standing (clothing dossier, male dress by status tier).
        garments = ["long_tunic", "hose", "boots"]
        palette = {"long_tunic": CLOTH, "hose": DARK, "boots": DARK}
    elif male and outfit == "c":
        garments = ["cotehardie", "hose", "boots"]
        palette = {"cotehardie": CLOTH, "hose": DARK, "boots": DARK}
    elif male:
        garments = ["short_tunic", "hose", "boots"]
        palette = {"short_tunic": CLOTH, "hose": DARK, "boots": DARK}
    elif outfit == "b":
        garments = ["gown", "waist_apron", "boots"]
        palette = {"gown": CLOTH, "waist_apron": LINEN, "boots": DARK}
    elif outfit == "c":
        # Accessories hang outside the surcoat; the girdle shows through its side openings.
        garments = ["kirtle", "sideless_surcoat", "boots"]
        palette = {"kirtle": CLOTH, "sideless_surcoat": CLOTH, "boots": DARK}
        extra["apron_over"] = "sideless_surcoat"
    elif outfit == "d":
        garments = ["linen_shift", "wrap_skirt", "solg", "boots"]
        palette = {"linen_shift": LINEN, "wrap_skirt": CLOTH, "boots": DARK}
        extra["apron_over"] = "wrap_skirt"
        extra["apron_gap"] = 0.02
    else:
        garments = ["work_gown", "boots"]
        palette = {"work_gown": CLOTH, "boots": DARK}
    layers = list(layers_of(sex, stage, outfit))
    # Hair (WD-3): girls keep braids baked in (never covered); grown women carry
    # the braid as the `braids` layer, so a wife's headscarf hides it; elder women
    # are always covered and get none.
    if male:
        hair = "short01"
    elif stage == "elder":
        hair = None
    else:
        hair = "braid01"
    spec = person(
        age=age, sex=sex, muscle=muscle, weight=weight, height_m=height, skin=SKIN[(sex, stage)],
        eyes="grey", hair=hair, hair_color=(0.34, 0.27, 0.19),
        brows="eyebrow002" if male else "eyebrow006", lashes="eyelashes02" if male else "eyelashes03",
        targets=targets, complexion={"tan": 0.4, "flush": 0.4},
        garments=garments + layers, palette=palette, outfits={"daily": garments},
        extra={"apron_over": garments[0], "belted": True if male else "plain", "layers": layers,
               "layer_ease": LAYER_EASE, "sleeve_buttons": male, **extra}, tier=2)
    # `_person` converts age through the repo's 25-year scale; the citizen bodies
    # state MakeHuman's own macro so a child really is a child.
    spec["macros"]["age"] = mh_age(age)
    spec["macros"]["cupsize"] = 0.5 if male else _CUP[build]
    spec["citizen"] = {"sex": sex, "stage": stage, "build": build, "outfit": outfit}
    return spec


def citizen_specs(person):
    """name -> spec for every body of the library, built with specs._person."""
    out = {}
    for sex in ("m", "f"):
        for stage, builds in STAGE_BUILDS.items():
            for build in builds:
                for outfit in outfits_of(sex, stage):
                    out[body_id(sex, stage, build, outfit)] = _spec(person, sex, stage, build, outfit)
    return out
