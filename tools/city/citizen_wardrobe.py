"""Wardrobe rules for the census residents of Reval (docs/SYSTEMS/CITIZEN_WARDROBE.md).

A resident is a blank body with one baked base outfit (tunic or gown, hose,
boots, belt with purse; for women also the kirtle with sideless surcoat or the
Estonian shift and wrap skirt) plus layers fitted to that body
(tools/assets/realistic_humans/citizen_bodies.LAYERS). These rules pick the
layers and their dyes from what the census knows: sex, age, status, trade,
household role, faction and duty. Every pick is a stable hash of the resident
id, so the same person always wears the same things.

The rules follow history/dossiers/dailylife/clothing-and-status-markers.md:
hems, fur and dyes by rank; married women covered (headscarf, or the Estonian
head cloth), maidens bareheaded with braids, burgher wives veiled and keyed; smiths in leather aprons; watch in aketon and kettle hat; crown men in
mail under red; no armour on burghers, no veil on labourers.

Pure Python, no Blender: imported by tools/city/build_citizen_runtime.py and
tests/python/test_citizen_wardrobe.py.
"""
from __future__ import annotations

import zlib

# --- dyes (linear RGB multipliers of the undyed layer) ----------------------
LINEN_WHITE = (0.88, 0.86, 0.80)
LINEN_NATURAL = (0.74, 0.70, 0.60)
LINEN_GREY = (0.62, 0.60, 0.55)
HABIT_BLACK = (0.12, 0.11, 0.10)
CROWN_RED = (0.58, 0.11, 0.09)  # Danish crown colours, no invented heraldry
ORDER_WHITE = (0.86, 0.85, 0.80)  # Livonian Order mantle white (the black cross is a separate patch)
LEATHER_DARK = (0.24, 0.14, 0.08)
LEATHER_TAN = (0.42, 0.28, 0.15)
AMBER = (0.70, 0.42, 0.12)
CORAL = (0.62, 0.16, 0.12)
BOXWOOD = (0.55, 0.40, 0.22)
IRON = (0.30, 0.29, 0.28)

# Hood and cap dyes by wealth (period dyes: woad, madder, weld, walnut, undyed).
HOOD_DYES = {
    "rich": [(0.42, 0.13, 0.10), (0.17, 0.24, 0.38), (0.20, 0.17, 0.15), (0.24, 0.30, 0.20),
             (0.30, 0.15, 0.30), (0.52, 0.12, 0.10)],
    "mid": [(0.27, 0.35, 0.46), (0.52, 0.25, 0.18), (0.35, 0.40, 0.28), (0.36, 0.28, 0.20),
            (0.60, 0.52, 0.28), (0.46, 0.44, 0.40)],
    "poor": [(0.46, 0.44, 0.40), (0.36, 0.28, 0.20), (0.30, 0.21, 0.14), (0.50, 0.35, 0.21),
             (0.40, 0.38, 0.33)],
}

WEALTH = {"patrician": "rich", "noble": "rich", "guest_merchant": "rich", "burgher_merchant": "rich",
          "master_craftsman": "mid", "clerk": "mid", "cleric": "mid", "free_commoner": "mid",
          "journeyman": "mid", "soldier": "mid", "burgher": "mid"}

# --- trades ------------------------------------------------------------------
MONASTIC = {"monk", "lay_brother"}
NUNS = {"nun", "lay_sister"}
SECULAR_CLERGY = {"canon", "chaplain", "priest", "vicar"}
CLERGY = MONASTIC | NUNS | SECULAR_CLERGY
# Leather apron (Schurz): fire, edge tools, hides and stone.
LEATHER_APRON = {"smith": 0.9, "nailsmith": 0.9, "armourer": 0.9, "cutler": 0.85, "shoemaker": 0.6,
                 "saddler": 0.6, "belt_maker": 0.6, "glover": 0.5, "tanner": 0.8, "cooper": 0.6,
                 "carpenter": 0.45, "joiner": 0.5, "mason": 0.55, "limeburner": 0.5, "shipwright": 0.4,
                 "potter": 0.5, "tiler": 0.4, "brickmaker": 0.5, "comb_maker": 0.5}
# Linen waist apron: food, drink, wash and dye trades (dyers' aprons are stained).
LINEN_APRON = {"baker": 0.9, "butcher": 0.9, "brewer": 0.7, "cook": 0.85, "castle_cook": 0.85,
               "innkeeper": 0.7, "alewife": 0.8, "fishmonger": 0.8, "chandler": 0.6, "tallow": 0.6,
               "dairy": 0.7, "maid": 0.35, "washerwoman": 0.8, "dyer": 0.8, "barber": 0.6, "healer": 0.3,
               "midwife": 0.5, "saltmonger": 0.5, "retailer": 0.25, "servant": 0.2, "castle_servant": 0.3,
               "spinner": 0.15, "weaver": 0.3, "tailor": 0.2, "gardener": 0.3}
DYER_APRON = (0.30, 0.38, 0.52)
SATCHEL = {"clerk": 0.5, "scribe": 0.8, "crown_clerk": 0.6, "novgorod_clerk": 0.6, "scholar": 0.7,
           "pilgrim": 1.0, "pedlar": 0.9, "healer": 0.6, "midwife": 0.6, "barber": 0.4, "ratsdiener": 0.7,
           "merchant": 0.25, "novgorod_merchant": 0.3, "retailer": 0.2, "weigher": 0.4, "musician": 0.4,
           "falconer": 0.5}
BACK_SACK = {"porter": 0.7, "carter": 0.4, "labourer": 0.25, "farmer": 0.4, "drover": 0.3, "stable_hand": 0.15,
             "sailor": 0.15, "gardener": 0.2, "boatman": 0.2, "saltmonger": 0.2}
# Household keys outside the housewife: offices that lock things.
KEY_TRADES = {"gatekeeper": 1.0, "chamberlain": 1.0, "sexton": 0.9, "innkeeper": 0.5, "alewife": 0.4,
              "weigher": 0.5, "ratsdiener": 0.4}
ARMED_TRADES = {"man_at_arms", "knight", "squire"}

# Duty kits (content/world/reval_city/citizens.json `duty.kit`, GATE_GARRISONS.md).
DUTY_KITS = {
    "watch": ("gambeson", "kettle_hat"),
    "crown": ("gambeson", "mail_haubergeon", "surcoat", "kettle_hat"),
    "sergeant": ("gambeson", "mail_haubergeon", "mail_coif", "kettle_hat"),
    "keeper": ("keys",),
}
HEADWEAR = ("hood", "coif", "wool_cap", "veil_over", "kettle_hat", "bascinet", "mail_coif", "aventail",
            "great_helm", "headscarf", "head_cloth", "braids")
# Heads that may stack: mail under an iron head piece (coif or aventail under bascinet, helm or hat).
ARMOUR_HEADS = {"mail_coif", "aventail", "bascinet", "great_helm", "kettle_hat"}
# Knightly harness (WD-4): only a knight of noble status wears it. Mail chausses also go to
# crown men-at-arms; nothing here is ever worn by a burgher, master, journeyman or labourer.
KNIGHT_ONLY = {"coat_of_plates", "great_helm", "aventail", "bascinet", "gauntlets", "order_mantle"}
ARMOUR = KNIGHT_ONLY | {"gambeson", "mail_haubergeon", "mail_coif", "surcoat", "kettle_hat", "mail_chausses"}
# A grown woman's head (WD-3): exactly one of these; the veil only ever goes over the headscarf.
WOMAN_HEAD = ("braids", "headscarf", "head_cloth")
# Working maids and alewives tie a kerchief over their braids at work (dossier: servant girl,
# alewife "headscarf always"); this share of the unmarried ones does.
KERCHIEF_TRADES = {"maid": 0.35, "servant": 0.3, "cook": 0.5, "castle_cook": 0.5, "alewife": 0.8,
                   "washerwoman": 0.5, "dairy": 0.4, "castle_servant": 0.3}
STRAPS = ("satchel", "back_sack")  # both cross the right shoulder: one at a time


def hash01(key: str) -> float:
    return (zlib.crc32(key.encode()) & 0xFFFFFF) / float(0x1000000)


def wealth_of(person: dict) -> str:
    return WEALTH.get(person["status"], "poor")


def stage_of(age: int) -> str:
    return "child" if age < 13 else "elder" if age >= 58 else "adult"


def _pick(table, key):
    return list(table[int(hash01(key) * len(table)) % len(table)])


def dress(person: dict, available: tuple) -> tuple[list[str], dict]:
    """(layers worn in order, {layer: dye}) for one resident.

    `available` is the layer set fitted to the resident's body
    (citizen_bodies.layers_of); a rule never adds a layer the body lacks."""
    key = person["id"]
    trade = person["trade"]
    status = person["status"]
    sex = person["sex"]
    stage = stage_of(person["age"])
    wealth = wealth_of(person)
    duty = (person.get("duty") or {}).get("kit", "")
    faction = person.get("faction", "none")
    estonian = person.get("ethnicity") in ("estonian", "finnish")
    wear: list[str] = []
    dye: dict = {}

    def roll(tag: str) -> float:
        return hash01(f"{key}:wd:{tag}")

    def put(layer: str, colour=None) -> None:
        if layer in available and layer not in wear:
            if layer in STRAPS and any(s in wear for s in STRAPS):
                return
            wear.append(layer)
            if colour is not None:
                dye[layer] = [round(c, 3) for c in colour]

    def head_free() -> bool:
        return not any(h in wear for h in HEADWEAR)

    # Armour: duty kits first, then soldiers and knights off the duty roster.
    for layer in DUTY_KITS.get(duty, ()):
        put(layer, CROWN_RED if layer == "surcoat" else None)
    if not duty and trade in ARMED_TRADES and stage == "adult":
        cover = (CROWN_RED if faction == "danish_crown" else ORDER_WHITE if faction == "livonian_order"
                 else _pick(HOOD_DYES["rich"], key + ":surcoat"))
        noble = status == "noble"
        if trade == "knight" and noble and faction == "livonian_order":
            # Order brother: mail under a white surcoat and the white mantle with the black cross.
            for layer in ("gambeson", "mail_haubergeon", "mail_chausses", "gauntlets"):
                put(layer)
            put("surcoat", ORDER_WHITE)
            put("order_mantle", ORDER_WHITE)
            if roll("helm") < 0.5:
                put("aventail")
                put("bascinet")
            else:
                put("mail_coif")
        elif trade == "knight" and noble and roll("armed") < 0.65:
            # Vassal knight: coat of plates or surcoat over mail, bascinet with aventail (the
            # great helm is for ceremony and the lists), mail chausses and gauntlets.
            put("gambeson")
            put("mail_haubergeon")
            if roll("plates") < 0.55:
                put("coat_of_plates", cover)
            else:
                put("surcoat", cover)
            head = roll("helm")
            if head < 0.2:
                put("mail_coif")
                put("great_helm")
            elif head < 0.8:
                put("aventail")
                put("bascinet")
            else:
                put("mail_coif")
            if roll("chausses") < 0.7:
                put("mail_chausses")
            if roll("gauntlets") < 0.6:
                put("gauntlets")
        elif trade == "squire" and roll("armed") < 0.5:
            put("gambeson")
            if roll("mail") < 0.5:
                put("mail_haubergeon")
            if roll("cap") < 0.4:
                put("kettle_hat")
        elif trade == "man_at_arms" and roll("armed") < 0.4:
            put("gambeson")
            if faction in ("danish_crown", "livonian_order") and roll("mail") < 0.6:
                # Crown and Order men wear their lord's colour over the mail.
                put("mail_haubergeon")
                put("surcoat", cover)
                if roll("chausses") < 0.3:
                    put("mail_chausses")
            if roll("cap") < 0.5:
                put("kettle_hat")

    # Aprons by trade (the long-cut female body bakes its own apron).
    if roll("leather_apron") < LEATHER_APRON.get(trade, 0.0) and "gambeson" not in wear:
        put("smith_apron", LEATHER_DARK if roll("apron_tone") < 0.6 else LEATHER_TAN)
    elif roll("linen_apron") < LINEN_APRON.get(trade, 0.0) and "gambeson" not in wear:
        put("waist_apron", DYER_APRON if trade == "dyer" else
            LINEN_WHITE if trade in ("baker", "cook", "castle_cook", "dairy") else
            LINEN_NATURAL if roll("apron_tone") < 0.6 else LINEN_GREY)

    # Head coverings. A woman's head follows marriage (WD-3): wives and widows are
    # covered, maidens go bareheaded with their braids; girls' braids are baked in.
    if sex == "f":
        if stage != "child":  # girls never cover their (baked) braids
            married = person.get("household_role") in ("spouse", "head", "elder") or stage == "elder"
            scarf = LINEN_WHITE if wealth == "rich" else LINEN_NATURAL if roll("scarf_tone") < 0.6 else LINEN_GREY
            if trade in NUNS:
                put("headscarf", LINEN_WHITE)  # the wimple under the black veil
                put("veil_over", HABIT_BLACK)
            elif married:
                # The Estonian wife's long white head cloth goes with her wrap skirt (outfit "d").
                if "head_cloth" in available and roll("head_cloth") < 0.75:
                    put("head_cloth", LINEN_WHITE if roll("cloth_tone") < 0.6 else LINEN_NATURAL)
                else:
                    put("headscarf", scarf)
                if "headscarf" in wear:
                    if wealth == "rich":
                        put("veil_over", LINEN_WHITE)
                    elif wealth == "mid" and roll("veil") < 0.55:
                        put("veil_over", LINEN_WHITE if roll("veil_tone") < 0.5 else LINEN_NATURAL)
                    elif stage == "elder" and roll("veil") < 0.35:
                        put("veil_over", LINEN_NATURAL)
            elif roll("kerchief") < KERCHIEF_TRADES.get(trade, 0.0):
                put("headscarf", scarf)
            if not any(h in wear for h in WOMAN_HEAD):
                put("braids")
            if not any(h in wear for h in WOMAN_HEAD) and "headscarf" in available:
                put("headscarf", scarf)  # a body without a braid (elders) is never bareheaded
    elif head_free():
        r = roll("head")
        if trade in MONASTIC:
            put("hood", HABIT_BLACK)
        elif trade in SECULAR_CLERGY:
            if r < 0.5:
                put("hood", _pick([(0.20, 0.17, 0.15), (0.26, 0.23, 0.20), (0.17, 0.20, 0.30)], key + ":hd"))
        elif stage == "child":
            if r < 0.25:
                put("hood", _pick(HOOD_DYES[wealth], key + ":hd"))
            elif r < 0.5:
                put("wool_cap", _pick(HOOD_DYES["poor"], key + ":cap"))
            elif r < 0.65:
                put("coif", LINEN_NATURAL)
        elif stage == "elder":
            if r < 0.5:
                put("hood", _pick(HOOD_DYES[wealth], key + ":hd"))
            elif r < 0.75:
                put("coif", LINEN_WHITE if wealth != "poor" else LINEN_NATURAL)
            elif r < 0.85:
                put("wool_cap", _pick(HOOD_DYES["poor"], key + ":cap"))
        elif wealth == "rich":
            if r < 0.55:
                put("hood", _pick(HOOD_DYES["rich"], key + ":hd"))
        elif wealth == "mid":
            if r < 0.3:
                put("hood", _pick(HOOD_DYES["mid"], key + ":hd"))
            elif r < 0.55:
                put("coif", LINEN_WHITE if roll("coif_tone") < 0.5 else LINEN_NATURAL)
            elif r < 0.7:
                put("wool_cap", _pick(HOOD_DYES["mid"], key + ":cap"))
        else:
            cap_share = 0.40 if estonian else 0.25
            if r < 0.30:
                put("coif", LINEN_NATURAL if roll("coif_tone") < 0.6 else LINEN_GREY)
            elif r < 0.30 + cap_share:
                put("wool_cap", _pick(HOOD_DYES["poor"], key + ":cap"))
            elif r < 0.30 + cap_share + 0.12:
                put("hood", _pick(HOOD_DYES["poor"], key + ":hd"))

    # Keys: the housewife's authority, and offices that lock things.
    if sex == "f" and person.get("household_role") in ("spouse", "head") and wealth != "poor":
        if roll("keys") < 0.8:
            put("keys", IRON)
    elif roll("keys") < KEY_TRADES.get(trade, 0.0):
        put("keys", IRON)

    # Prayer beads: clergy, the devout of the church faction, some rich women and elders.
    bead = AMBER if wealth == "rich" and roll("bead") < 0.5 else CORAL if wealth == "rich" else BOXWOOD
    if trade in CLERGY and roll("beads") < 0.9:
        put("paternoster", BOXWOOD)
    elif faction == "church" and roll("beads") < 0.5:
        put("paternoster", bead)
    elif sex == "f" and wealth == "rich" and roll("beads") < 0.35:
        put("paternoster", bead)
    elif stage == "elder" and roll("beads") < 0.25:
        put("paternoster", bead)

    # Carrying: scrips for clerks and travellers, sacks for porters.
    if roll("satchel") < SATCHEL.get(trade, 0.0):
        put("satchel", LEATHER_TAN if roll("satchel_tone") < 0.5 else LEATHER_DARK)
    if roll("sack") < BACK_SACK.get(trade, 0.0):
        put("back_sack")
    return wear, dye


def shield_of(person: dict, wear: list) -> str:
    """Shield kind carried on the left arm, or "" (WD-4): only the armed kits above carry one.

    `order` is white with the black cross, `crown` plain red (no invented heraldry), `field` the
    knight's own surcoat colour, `plain` bare lime-wood with an iron boss (men-at-arms off the
    roster). The town watch carries none (spear only, GATE_GARRISONS.md)."""
    if (person.get("duty") or {}).get("kit"):
        return ""
    if "order_mantle" in wear:
        return "order"
    if person["trade"] == "knight" and person["status"] == "noble" and "mail_haubergeon" in wear:
        return "crown" if person.get("faction") == "danish_crown" else "field"
    if person["trade"] == "man_at_arms" and "mail_haubergeon" in wear \
            and hash01(f"{person['id']}:wd:shield") < 0.5:
        return "crown" if person.get("faction") == "danish_crown" else "plain"
    return ""
