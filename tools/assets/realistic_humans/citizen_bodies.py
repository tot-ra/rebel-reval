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
OUTFITS = ("a", "b")


def body_id(sex, stage, build, outfit="a"):
    return f"citizen_{sex}_{stage}_{build}" + ("_b" if outfit == "b" else "")


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
    if male and outfit == "b":
        garments = ["wool_tunic", "hose", "boots"]
        palette = {"wool_tunic": CLOTH, "hose": DARK, "boots": DARK}
    elif male:
        garments = ["short_tunic", "hose", "boots"]
        palette = {"short_tunic": CLOTH, "hose": DARK, "boots": DARK}
    elif outfit == "b":
        garments = ["gown", "waist_apron", "headscarf", "boots"]
        palette = {"gown": CLOTH, "waist_apron": LINEN, "headscarf": LINEN, "boots": DARK}
    else:
        garments = ["work_gown", "headscarf", "boots"]
        palette = {"work_gown": CLOTH, "headscarf": LINEN, "boots": DARK}
    spec = person(
        age=age, sex=sex, muscle=muscle, weight=weight, height_m=height, skin=SKIN[(sex, stage)],
        eyes="grey", hair="short01" if (male or stage == "child") else "bob01", hair_color=(0.34, 0.27, 0.19),
        brows="eyebrow002" if male else "eyebrow006", lashes="eyelashes02" if male else "eyelashes03",
        targets=targets, complexion={"tan": 0.4, "flush": 0.4},
        garments=garments, palette=palette, outfits={"daily": garments},
        extra={"apron_over": garments[0], "belted": True if male else "plain"}, tier=2)
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
                for outfit in (OUTFITS if stage == "adult" else ("a",)):
                    out[body_id(sex, stage, build, outfit)] = _spec(person, sex, stage, build, outfit)
    return out
