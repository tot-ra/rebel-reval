#!/usr/bin/env python3
"""Deterministic 1343 census of Reval derived from the city plan buildings.

Reads ``content/world/reval_city/plan.json`` (641 building footprints, districts,
streets) and writes ``docs/data/city_census.json``: every household and every
resident with age, sex, ethnicity, status, trade, faction affinity, and an
appearance seed (height, build, hair, eyes, marks). Cards in
``docs/CITIZENS/people/`` flesh out chosen residents; they must not contradict
the seed. Ledger pages in ``docs/CITIZENS/ledger/`` are generated from the same data.

  python3 tools/city/build_city_census.py           # rewrite census + ledger + stats
  python3 tools/city/build_city_census.py --check   # fail if committed output is stale

All randomness is seeded per building id, so the output is stable. The census is the
source of truth once cards exist: do not change the algorithm to "re-roll" people.
Confidence: every figure is a `plausible composite` bracket, see docs/CITIZENS/CENSUS.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "content/world/reval_city/plan.json"
OUT_JSON = ROOT / "docs/data/city_census.json"
LEDGER_DIR = ROOT / "docs/CITIZENS/ledger"
STATS_MD = ROOT / "docs/CITIZENS/census_tables.md"

SCHEMA = "rr.city_census.v1"

# --------------------------------------------------------------------------- names

GERMAN_M = ("Johannes Hinrik Dietrich Nicolaus Hermann Winand Rotcher Ricbod Heyno Gerhard Albert Conrad Bertold Werner "
            "Everhard Lambert Arnold Gottschalk Segebode Wolter Jakob Lutke Brun Eler Volmar Thomas Tideman Godeke "
            "Reynold Otto Ludolf Detlev Vicke Bernd Sander Marquard Evert Peter Wilke Hildebrand Meinhard Eylard "
            "Tilman Sivert Cord Frederik Hartwig Kersten Gerlach Hennike Lambrecht Ruthard Wessel Henneke Borchard "
            "Bartold Egbert Alke Johan Reimar Ghert Arend Helmich Rembert Tyde Claus Heine Ropert Berend").split()
GERMAN_F = ("Mechtild Sophia Walburgis Yda Greta Gertrud Elseke Adelheid Katharina Ermgard Hille Telseke Margarete "
            "Alheid Gesche Taleke Anneke Bela Lucia Ghese Drude Wobbeke Metteke Abele Jutte Berta Heilwig Cecilia Oda "
            "Kunigunde Lysbeth Fenne Gyse Hillegund Richardis Mette Wendele Gyla Ilsabe Beke Tibbeke Grete Ellen "
            "Hebele Sibbe Wibeke Geseke Dorothea Rixa Trude Lutgard Ermelin Gerburg").split()
GERMAN_BY_TOPO = ("van Lubeke van Bremen van Soest van Dortmund van Hamelen van Minden van Munster van Brunswik "
                  "van Stralesund van Rostok van Wismar van Gripeswold van Wesele van Kolne van Hildensem van Goslar "
                  "van Luneborch van Stade van Verden van Revele Westfal van Dulmen van Bocholt van Zwolle "
                  "van Deventer van Campen van Groninghe van Hervorde van Lemego van Paderborne").split(" van ")
# the split above leaves a leading empty element; handled in code
GERMAN_BY_OCC = {
    "smith": ["Smed", "Hammer", "Isenhard"], "goldsmith": ["Goltsmed", "Goldschmit"], "baker": ["Becker", "Brotman"],
    "brewer": ["Brawer", "Moltenbruer"], "butcher": ["Knokenhower", "Fleischer"], "cooper": ["Botcher", "Fatbinder"],
    "carpenter": ["Timmerman", "Zimmerman"], "mason": ["Murer", "Steenmetter"], "shoemaker": ["Schomaker", "Schuster"],
    "tanner": ["Lowergerver", "Gerwer"], "weaver": ["Wever", "Lakenmaker"], "tailor": ["Schroder", "Snider"],
    "furrier": ["Pelser", "Kurssener"], "saddler": ["Sadelmaker", "Sadeler"], "ropemaker": ["Repschleger", "Reper"],
    "carter": ["Voerman", "Karrenman"], "fisher": ["Visscher"], "miller": ["Moller"], "barber": ["Scherer", "Barbitonsor"],
    "chandler": ["Lichtmaker"], "potter": ["Putter", "Tapper"], "glover": ["Hanschemaker"], "wheelwright": ["Radmaker"],
}
GERMAN_BY_DESC = ("Langhe Corte Witte Swarte Rode Brune Grote Lutke Junge Olde Fromme Starke Snelle Wise Kleine "
                  "Hovesche Vrie Stolte Gude Blyde Hardekop Rotermund Lippe Kniphof Overdyk Stenhus Wulf Sasse").split()

ESTONIAN_M = ("Marten Hinrick Jüri Jaan Andres Tõnis Mattes Peeter Niklas Hendrik Laurents Kristjan Tõll Lembit Ain "
              "Kaur Leho Toomas Mihkel Madis Villem Joosep Ants Jakob Paul Taavet Olev Uku Rein Tõnu Karl Kaarel "
              "Priidik Jaak Hans Mats Evert Aadu Hindrek Jürgen Märt Oskar Tiit Orav Raivo "
              "Pärtel Siim Kaspar Mikk Taniel Eerik Gerdt Albert Henn Lauri Simon Kornel").split()
# a few of those are later forms; the pool is filtered below
_ESTONIAN_M_DROP = {"Oskar", "Raivo", "Orav", "Tiit", "Karl", "Märt", "Hans", "Aadu", "Jürgen", "Taavet", "Kaarel", "Mats"}
ESTONIAN_F = ("Liis Mari Anna Kadri Triin Made Eeva Ell Els Marga Katrin Ede Hele Lilli Mai Ilse Tiiu Reet Aino "
              "Sille Mall Ann Juta Leena Viive Ilmi Olli "
              "Agnes Barbara Gertrud Lutsia Magdalena Margareta Dorothea Kristiina Katarina Elsa Berta Elisabet Helena Sofia Ursula Veronika "
              "Susanna Judit Ruth Mett Tilda Wendla Gesa Alit").split()
_ESTONIAN_F_DROP = {"Aino", "Sille", "Mall", "Juta", "Leena", "Viive", "Ilmi", "Olli", "Lilli", "Mai", "Tiiu", "Reet", "Ilse"}
SWEDE_M = "Olof Erik Sven Nils Anders Lars Jöns Per Magnus Bengt Knut Gunnar Torgils Ragnvald Halvard Birger Ulf Folke".split()
SWEDE_F = "Kristina Ingeborg Birgitta Karin Ragnhild Margareta Helga Sigrid Anna Gunhild Elin Ulrika Cecilia".split()
FINN_M = "Matti Pekka Heikki Antti Olli Tuomas Lauri Jussi Eero Mikko Yrjö Paavo Eskil Olavi Juho Sakari Simo Lasse Tapani Pietari".split()
FINN_F = "Maria Helka Kaisa Aune Impi Liisa Anna Katri Saara Hilkka Ilona Marketta Valpuri Elina Tuulikki Sanna".split()
RUSSIAN_M = "Prokhor Ivan Ontsifor Stepan Mikula Yakov Fedor Semyon Gavril Grigori Lavrenty Dmitri Timofei Yeremei".split()
RUSSIAN_F = "Marfa Agafya Fevronia Ulyana Praskovya Irina Olena Domna".split()
DANISH_M = "Peder Jens Niels Ove Mogens Esger Tyge Abel Torben Henrik Ebbe Knud Absalon Kristoffer".split()
DANISH_F = "Ingeborg Kirsten Margrete Sidsel Bodil Gunhild Ragnhild Cecilie Elisabet".split()
DANISH_BY = "Skeel Lunge Galen Basse Thott Rosenkrantz Bille Brahe Hvide Krabbe Munk Gyldenstierne Ulfeldt".split()
DANISH_BY = ["Skjalm", "Lunge", "Galen", "Basse", "Bjelke", "Krag", "Bille", "Brok", "Hvide", "Krabbe", "Munk", "Rud", "Tuve", "Vendelbo"]
ESTONIAN_PATRO = ("Jaani Mardi Peetri Hindriku Tõnu Andrese Mattese Niklase Jüri Toomase Laurentsi Ainu Kauri Lembitu "
                  "Mihkli Madise Villemi Uku Olevi Reinu Jaagu Priidiku Jakobi Paulu Antsu Hannu Joosepi Kristjani Lehu Tiidu Sulevi Ardi Ennu Ulvi Taavi Evertsi Orgu").split()
SWEDE_BY = ["Olofsson", "Erikssen", "Svensson", "Nilsson", "Andersson", "Larsson", "Persson", "Bengtsson", "Knutsson"]
FINN_BY = ["Pekanpoika", "Matinpoika", "Heikinpoika", "Antinpoika", "Tuomaanpoika", "Mikonpoika"]


# neutral last-resort distinguishers (never describe the body, so they cannot contradict an appearance seed)
EPITHETS = ["of the Mill", "of the Gate", "by the Well", "at the Corner", "of the Lane", "by the Wall", "of the Bridge", "at the Linden",
            "of the Shore", "by the Chapel", "of the Yard", "at the Cross", "of the Hill", "by the Pond", "of the Stair", "at the Ford",
            "of the Row", "by the Elder Tree", "of the Market", "at the Sign of the Key"]


def _clean(pool, drop=()):
    return [x for x in pool if x not in drop]


# --------------------------------------------------------------------------- trades
# key: (label, low-German / local label, fertility of ethnicities handled elsewhere)

TRADES = {
    # long-distance and civic
    "merchant": "Fernhändler (long-distance merchant)", "factor": "Hanseatic factor", "clerk": "merchant's clerk",
    "retailer": "Krämer (retail trader)", "moneylender": "moneychanger", "councillor": "Ratsherr (councillor)",
    "burgomaster": "Bürgermeister", "stadtschreiber": "Stadtschreiber (town clerk)", "ratsdiener": "Ratsdiener (council servant)",
    "vogt_officer": "crown bailiff's man", "gatekeeper": "gatekeeper", "watch_sergeant": "watch sergeant",
    "town_herdsman": "city herdsman", "executioner": "Scharfrichter", "gravedigger": "gravedigger and bell-ringer",
    "scribe": "scribe", "schoolmaster": "parish schoolmaster", "weigher": "town weigher",
    # food and drink
    "baker": "Becker (baker)", "brewer": "Brawer (brewer)", "alewife": "alewife", "innkeeper": "tavern keeper",
    "butcher": "Fleischer (butcher)", "fishmonger": "fishmonger", "miller": "miller", "cook": "cook (household or cookshop)",
    "greengrocer": "greengrocer", "saltmonger": "salt and herring dealer",
    # metals and building
    "smith": "blacksmith", "goldsmith": "goldsmith", "armourer": "armourer", "nailsmith": "nail-smith", "cutler": "knife-smith",
    "cooper": "Böttcher (cooper)", "carpenter": "Zimmermann (carpenter)", "mason": "stonemason", "tiler": "roof-tiler and thatcher",
    "wheelwright": "wheelwright", "joiner": "joiner", "limeburner": "lime-burner", "brickmaker": "brickmaker", "glazier": "glazier",
    # cloth and leather
    "weaver": "cloth-weaver", "dyer": "dyer", "tailor": "tailor", "furrier": "furrier", "shoemaker": "Schuster (shoemaker)",
    "tanner": "Lohgerber (tanner)", "saddler": "saddler", "glover": "glover", "hatter": "cap-maker", "spinner": "spinner",
    "belt_maker": "belt and purse maker", "comb_maker": "comb and horn worker",
    # sea and haulage
    "fisher": "fisherman", "net_maker": "net-maker", "boatman": "lighter-man (boatman)", "shipwright": "boat-builder",
    "ropemaker": "ropemaker", "sailmaker": "sailmaker", "carter": "carter", "porter": "porter (dock carrier)", "drover": "drover",
    "sailor": "sailor", "skipper": "skipper", "pilot": "harbour pilot", "ballast_man": "ballast and stone hauler",
    # service and care
    "barber": "barber-surgeon", "midwife": "midwife", "bathkeeper": "bathkeeper", "apothecary": "spicer and apothecary",
    "healer": "herb-wife", "washerwoman": "washerwoman", "chandler": "candle-maker", "tallow": "tallow-boiler",
    "potter": "potter", "gardener": "market gardener", "dairy": "dairy-woman", "wet_nurse": "wet-nurse",
    "musician": "town piper and fiddler", "beggar": "beggar (licensed at the church door)", "pedlar": "pedlar",
    "labourer": "day labourer", "servant": "household servant", "maid": "maid", "apprentice": "apprentice", "journeyman": "journeyman",
    "stable_hand": "stable hand and ostler", "farmer": "gate-farm cultivator", "woodcutter": "woodcutter and charcoal-burner",
    "child": "child", "scholar": "scholar", "infant": "infant", "widow": "widow living on a pension", "retired": "retired craftsman",
    "prostitute": "bath-girl (licensed by the council's tolerance)", "pilgrim": "pilgrim", "monk": "friar", "nun": "nun",
    "priest": "priest", "chaplain": "chaplain", "sexton": "sexton", "canon": "canon", "lay_brother": "lay brother",
    "knight": "vassal knight", "squire": "squire", "man_at_arms": "castle man-at-arms", "crown_clerk": "crown clerk",
    "castle_servant": "castle servant", "castle_cook": "castle cook", "chamberlain": "chamberlain", "falconer": "falconer",
    "hospital_inmate": "hospital inmate", "lay_sister": "lay sister", "vicar": "vicar choral", "novgorod_merchant": "Novgorod merchant",
    "novgorod_clerk": "Novgorod merchant's clerk", "outlaw": "fugitive", "refugee": "refugee from Harju manors",
}

# zone weights per trade for heads: merchant, craft, harbour, fishing, suburb, toompea_house
HEAD_TRADES = {
    "merchant": (14, 1, 1, 0, 0, 0), "retailer": (8, 4, 2, 0, 1, 0), "moneylender": (1.2, 0.1, 0, 0, 0, 0),
    "baker": (3, 6, 1, 0, 2, 0), "brewer": (4, 4, 1, 0, 0, 0), "innkeeper": (2, 3, 6, 0, 2, 0), "alewife": (0.5, 2, 3, 0.5, 1, 0),
    "butcher": (1, 4, 1, 0, 3, 0), "fishmonger": (1, 2, 5, 3, 0, 0), "miller": (0, 0.3, 0, 0, 2, 0), "cook": (1, 2, 3, 0, 0, 0),
    "smith": (0.3, 6, 1, 0, 3, 0.3), "goldsmith": (2, 0.5, 0, 0, 0, 0), "armourer": (0.5, 1.5, 0, 0, 0, 1), "nailsmith": (0, 1.5, 0.5, 0, 1, 0),
    "cutler": (0.3, 1.2, 0, 0, 0, 0), "cooper": (1, 4, 4, 0, 2, 0), "carpenter": (0.5, 6, 3, 0.5, 4, 0.5), "mason": (0.5, 4, 1, 0, 1, 1),
    "tiler": (0, 1.5, 0.5, 0, 1, 0), "wheelwright": (0, 1.5, 0.5, 0, 2, 0), "joiner": (0.5, 2.5, 0.5, 0, 0, 0.5),
    "limeburner": (0, 0.5, 0, 0, 1.5, 0), "brickmaker": (0, 0.3, 0, 0, 1.5, 0), "glazier": (0.2, 0.4, 0, 0, 0, 0.2),
    "weaver": (1, 5, 1, 0, 3, 0), "dyer": (0.2, 1.5, 0.3, 0, 0, 0), "tailor": (2, 5, 1, 0, 0.5, 1), "furrier": (1.5, 2, 0, 0, 0, 0.5),
    "shoemaker": (0.7, 8, 2, 0, 1, 0), "tanner": (0, 1.7, 1, 0, 1.5, 0), "saddler": (0.3, 1.5, 0, 0, 1, 0.8),
    "glover": (0.5, 1, 0, 0, 0, 0), "hatter": (0.5, 0.8, 0, 0, 0, 0), "belt_maker": (0.3, 1, 0, 0, 0, 0), "comb_maker": (0, 0.6, 0, 0, 0.5, 0),
    "fisher": (0, 0.8, 18, 22, 1, 0), "net_maker": (0, 0.3, 1.5, 4, 0, 0), "boatman": (0, 0.3, 7, 4, 0, 0), "shipwright": (0, 0.3, 2.5, 2, 0, 0),
    "ropemaker": (0, 1, 3, 0.8, 0, 0), "sailmaker": (0, 0.5, 2, 0.5, 0, 0), "carter": (0.5, 3, 5, 0, 7, 0), "porter": (0, 3, 11, 0.8, 0, 0),
    "drover": (0, 0.5, 0.5, 0, 5, 0), "sailor": (0, 0.5, 4, 2, 0, 0), "skipper": (0.7, 0.3, 1.5, 0.5, 0, 0), "pilot": (0, 0, 0.8, 0.8, 0, 0),
    "ballast_man": (0, 0, 1.5, 0.5, 0, 0), "barber": (0.7, 1.5, 0.3, 0, 0, 0.3), "bathkeeper": (0, 0.5, 0.2, 0, 0, 0), "apothecary": (0.5, 0.1, 0, 0, 0, 0),
    "chandler": (0.4, 1.2, 0.2, 0, 0, 0), "tallow": (0, 1, 0.3, 0, 0.5, 0), "potter": (0, 1, 0.3, 0, 1, 0), "gardener": (0.2, 1, 0, 0, 3, 0.4),
    "musician": (0.2, 0.6, 0.3, 0, 0, 0.3), "pedlar": (0, 0.8, 0.8, 0.3, 0.5, 0), "labourer": (0, 9, 16, 6, 8, 0), "stable_hand": (0, 1, 0.5, 0, 2, 0.5),
    "farmer": (0, 0, 0, 0, 10, 0), "woodcutter": (0, 0.5, 0, 0, 3, 0), "saltmonger": (0.8, 1.3, 1.5, 0, 0, 0), "greengrocer": (0.3, 2, 0.8, 0, 1, 0),
    "scribe": (1.2, 0.3, 0, 0, 0, 0.5), "weigher": (0.1, 0.2, 0.3, 0, 0, 0), "pilgrim": (0, 0, 0, 0, 0, 0),
    "retired": (0.5, 1, 0.5, 0.5, 0.5, 0.2), "knight": (0, 0, 0, 0, 0, 5), "crown_clerk": (0, 0, 0, 0, 0, 2), "falconer": (0, 0, 0, 0, 0, 0.5),
    "chamberlain": (0, 0, 0, 0, 0, 0.5),
}
ZONE_INDEX = {"merchant": 0, "craft": 1, "harbour": 2, "fishing": 3, "suburb": 4, "toompea": 5}

# Ethnic mix for heads per zone: german, estonian, swede, finn, russian, danish
ETHNIC_BY_ZONE = {
    "merchant": (0.74, 0.12, 0.05, 0.02, 0.07, 0.0),
    "craft": (0.28, 0.53, 0.12, 0.05, 0.02, 0.0),
    "harbour": (0.14, 0.55, 0.17, 0.10, 0.04, 0.0),
    "fishing": (0.04, 0.58, 0.20, 0.17, 0.01, 0.0),
    "suburb": (0.08, 0.76, 0.08, 0.06, 0.02, 0.0),
    "toompea": (0.70, 0.05, 0.0, 0.0, 0.0, 0.25),
}
ETHNICITIES = ("german", "estonian", "swedish", "finnish", "russian", "danish")
# trades reserved for specific groups at a probability (cultural prior)
ETHNIC_TRADE_BIAS = {
    "shoemaker": {"swedish": 3.0}, "fisher": {"estonian": 1.5, "swedish": 1.5, "finnish": 1.5},
    "mason": {"estonian": 3.0}, "carter": {"estonian": 2.2}, "porter": {"estonian": 3.0, "swedish": 1.5}, "drover": {"estonian": 3.0},
    "labourer": {"estonian": 2.0}, "merchant": {"german": 3.0, "russian": 0.3}, "moneylender": {"german": 4.0}, "goldsmith": {"german": 4.0},
    "furrier": {"russian": 2.5}, "brewer": {"german": 1.8}, "tailor": {"german": 1.5}, "weaver": {"german": 1.4},
    "knight": {"german": 1.0, "danish": 0.8}, "innkeeper": {"estonian": 1.2}, "pedlar": {"finnish": 2.0, "estonian": 1.5},
}

PLAN_ZONE_STREETS = {
    "merchant": {"Pikk", "Lai", "Vana turg", "Raekoja", "Mündi", "Dunkri", "Vene", "Saiakang", "Kullassepa", "Rataskaevu", "Bremeni käik",
                 "Kinga"},
    "craft": {"Harju", "Suur-Karja", "Kuninga", "Voorimehe", "Pagari", "Kooli", "Sauna", "Tolli", "Aida", "Laboratooriumi", "Müürivahe",
              "Väike-Kloostri", "Suur-Kloostri", "Niguliste", "Rutu", "Vana-Posti", "Hobusepea", "Sulevimägi", "Meistrite hoov",
              "Pühavaimu", "Oleviste", "Olevimägi", "Katariina käik"},
}

# --------------------------------------------------------------------------- appearance pools

HAIR_COLORS = {
    "nordic": [("ash blond", 22), ("dark blond", 22), ("light brown", 26), ("brown", 14), ("straw blond", 8), ("reddish blond", 4),
               ("copper red", 2), ("dark brown", 2)],
    "german": [("brown", 30), ("dark blond", 20), ("light brown", 14), ("dark brown", 10), ("blond", 8), ("black-brown", 6),
               ("chestnut red", 6), ("sandy", 6)],
    "slavic": [("light brown", 30), ("brown", 25), ("dark blond", 20), ("black-brown", 10), ("red-brown", 10), ("ash blond", 5)],
}
EYE_COLORS = {
    "nordic": [("blue", 34), ("grey-blue", 22), ("grey", 20), ("green-grey", 8), ("hazel", 8), ("brown", 8)],
    "german": [("blue", 22), ("grey", 20), ("hazel", 18), ("brown", 26), ("green", 8), ("grey-green", 6)],
    "slavic": [("grey", 30), ("blue", 20), ("brown", 25), ("grey-green", 12), ("hazel", 13)],
}
COMPLEXIONS = ["fair, quick to flush", "fair with freckles", "pale and sallow", "ruddy", "weathered tan", "olive-fair", "wind-reddened",
               "sun-browned", "pale and even", "sallow with winter pallor", "rosy-cheeked", "sun-freckled and peeling"]
BUILDS = {  # label: weight, male mod, female mod (BMI-ish)
    "lean and wiry": 14, "slight": 9, "average": 26, "sturdy": 22, "stocky": 12, "heavy-set": 8, "gaunt": 5, "broad-shouldered": 7,
    "pear-shaped": 6, "round-bellied": 5, "long-limbed": 6,
}
MARKS_GENERAL = [
    "small crescent scar over the left eyebrow", "nose broken once and healed slightly crooked to the right",
    "gap where a front tooth is missing", "freckles across nose and cheeks", "cleft chin", "protruding ears",
    "a wart on the right cheek", "pale scar across the chin", "mole near the corner of the mouth", "a squint in the left eye",
    "deep laugh lines", "a limp from a badly healed shin", "tremor in the right hand when tired", "stoop from years of bending",
    "heavy-lidded eyes", "birthmark on the neck", "chilblain-scarred knuckles", "bitten-down nails and calloused thumbs",
    "a cold-sore scar on the upper lip", "sunken cheeks from lost back teeth", "a faint pock-scarred forehead",
    "one ear nicked at the rim", "unusually long fingers", "very thick, straight eyebrows meeting over the nose",
    "a high, narrow forehead", "uneven shoulders", "thin, early-receding hairline", "a rolling, wide-legged gait",
    "left-handed", "an old burn scar on the back of one hand",
]
MARKS_BY_TRADE = {
    "smith": ["burn scars speckling the forearms", "hearing dulled in the left ear", "thumb-thick calluses"],
    "armourer": ["burn scars speckling the forearms", "stained fingertips"],
    "goldsmith": ["pinched squint lines", "stained fingertips"],
    "fisher": ["salt-cracked hands", "weather-lined eyes narrowed against the glare", "a missing fingertip from a net winch"],
    "net_maker": ["rope-scarred palms", "knotted, arthritic fingers"],
    "boatman": ["salt-cracked hands", "rope-scarred palms"],
    "porter": ["a permanently bowed neck from sacks", "rope-scarred shoulders"],
    "ropemaker": ["rope-scarred palms", "a missing fingertip"],
    "mason": ["lime-burnt, cracked hands", "a dusty, limestone-grey cast to the hair"],
    "carpenter": ["a missing finger joint", "splinter-scarred forearms"],
    "tanner": ["tannin-stained hands", "hands bleached and cracked by lime"],
    "dyer": ["permanently blue-stained hands", "madder-red cuticles"],
    "butcher": ["knife scars on the left hand", "thick wrists"],
    "baker": ["flour-pale eyebrows", "burn marks inside the forearms"],
    "brewer": ["steam-reddened face", "beer-flushed nose"],
    "scribe": ["ink-stained right fingers", "eye-strain squint"],
    "clerk": ["ink-stained right fingers", "eye-strain squint"],
    "barber": ["steady, neat hands", "small nicks on the hands"],
    "weaver": ["stooped shoulders from the loom", "worn thumb pads"],
    "tailor": ["needle-pricked fingertips", "eye-strain squint"],
    "shoemaker": ["awl-pricked fingertips", "pitch-stained thumbs"],
    "labourer": ["a hernia truss visible under the shirt", "split, thick-callused palms"],
    "carter": ["wind-burnt face", "a horse-kicked crooked shin"],
    "sailor": ["tarred pigtail", "a rope-burn scar on the neck"],
    "knight": ["a sword-cut scar on the jaw", "a nose bent by a mace glancing off the helm"],
    "man_at_arms": ["a sword-cut scar on the forearm", "a healed arrow wound in the thigh"],
    "midwife": ["strong, very clean hands", "swollen knuckles"],
    "innkeeper": ["a ruddy, jowly face", "a bar-keeper's wiry strength"],
    "alewife": ["a ruddy, jowly face", "a wiry, scalded forearm"],
}
VOICES = ["low and unhurried", "gravelly", "clear and carrying", "soft, almost whispering", "nasal", "thin and reedy", "warm baritone",
          "high and quick", "hoarse from the harbour wind", "slow, with long pauses", "sing-song Estonian cadence under the German",
          "clipped and precise", "booming", "monotone", "husky", "a flat, tired murmur"]

FACTIONS = ["none", "hanseatic", "danish_crown", "livonian_order", "black_cloaks", "harju_kings", "cult_metsik", "pskov_novgorod",
            "vitalienbruder", "blackheads", "church"]


# --------------------------------------------------------------------------- helpers

def wchoice(rng: random.Random, pairs):
    total = sum(w for _, w in pairs)
    r = rng.random() * total
    acc = 0.0
    for v, w in pairs:
        acc += w
        if r <= acc:
            return v
    return pairs[-1][0]


def street_slug(name: str) -> str:
    return slugify(name) or "back_lane"


def hh_anchor(hid: str) -> str:
    return hid.replace(".", "-").replace("_", "-")


def ledger_rel(h: dict) -> str:
    """Path of the ledger page for a household, relative to docs/CITIZENS/."""
    return f"ledger/{DISTRICT_DIR[h['district']]}/{street_slug(h['street'])}.md"


def card_rel(p: dict, dcode: str) -> str:
    """Path of a person's card relative to docs/CITIZENS/."""
    return f"people/{DISTRICT_DIR[dcode]}/{p['slug']}.md"


def slugify(text: str) -> str:
    t = unicodedata.normalize("NFKD", text.lower().replace("ö", "o").replace("ä", "a").replace("ü", "u").replace("õ", "o"))
    t = "".join(c for c in t if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", t).strip("_")


def poly_area(f):
    s = 0.0
    for i in range(len(f)):
        x1, y1 = f[i]
        x2, y2 = f[(i + 1) % len(f)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def centroid(f):
    return sum(p[0] for p in f) / len(f), sum(p[1] for p in f) / len(f)


def inside(pt, poly):
    x, y = pt
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def seed_rng(*parts) -> random.Random:
    h = hashlib.sha256("|".join(map(str, parts)).encode()).hexdigest()
    return random.Random(int(h[:16], 16))


# --------------------------------------------------------------------------- name allocation

EST_GEN = {"Marten": "Marteni", "Hinrick": "Hinricku", "Jüri": "Jüri", "Jaan": "Jaani", "Andres": "Andrese", "Tõnis": "Tõnise",
           "Mattes": "Mattese", "Peeter": "Peetri", "Niklas": "Niklase", "Hendrik": "Hendriku", "Laurents": "Laurentsi", "Kristjan": "Kristjani",
           "Tõll": "Tõlli", "Lembit": "Lembitu", "Ain": "Aino", "Kaur": "Kauri", "Leho": "Leho", "Toomas": "Toomase", "Mihkel": "Mihkli",
           "Madis": "Madise", "Villem": "Villemi", "Joosep": "Joosepi", "Ants": "Antsu", "Jakob": "Jakobi", "Paul": "Pauli", "Olev": "Olevi",
           "Pärtel": "Pärtli", "Siim": "Siimu", "Kaspar": "Kaspari", "Mikk": "Mikku", "Taniel": "Tanieli", "Eerik": "Eerika", "Gerdt": "Gerdti",
           "Albert": "Alberti", "Henn": "Henni", "Lauri": "Lauri", "Simon": "Simoni", "Kornel": "Korneli", "Uku": "Uku", "Rein": "Reinu", "Tõnu": "Tõnu", "Priidik": "Priidiku", "Jaak": "Jaagu", "Evert": "Everti", "Hindrek": "Hindreku"}
RU_PATRO = {"Prokhor": "Prokhorov", "Ivan": "Ivanov", "Ontsifor": "Ontsiforov", "Stepan": "Stepanov", "Mikula": "Mikulin", "Yakov": "Yakovlev",
            "Fedor": "Fedorov", "Semyon": "Semyonov", "Gavril": "Gavrilov", "Grigori": "Grigoriev", "Lavrenty": "Lavrentyev", "Dmitri": "Dmitriev",
            "Timofei": "Timofeyev", "Yeremei": "Yeremeyev"}


def patronymic(eth, father_given, sex):
    m = sex == "m"
    if eth == "estonian":
        return f"{EST_GEN.get(father_given, father_given + 'i')} {'poeg' if m else 'tütar'}"
    if eth == "swedish":
        stem = father_given + ("son" if m else "dotter") if father_given.endswith("s") else father_given + ("sson" if m else "sdotter")
        return stem
    if eth == "finnish":
        stem = father_given[:-1] + "a" if father_given.endswith(("a", "i")) else father_given
        stem = stem + "n" if not stem.endswith("n") else stem
        return stem + ("poika" if m else "tytär")
    if eth == "russian":
        base = RU_PATRO.get(father_given, father_given + "ov")
        if base.endswith("in") and father_given == "Mikula":
            return "Mikulich" if m else "Mikulichna"
        stem = base[:-2] if base.endswith("ov") else base[:-2] if base.endswith("ev") else base
        if base.endswith("ev"):
            return base[:-2] + ("evich" if m else "evna")
        return base + ("ich" if m else "na")
    return ""


class NameBook:
    def __init__(self):
        self.used = Counter()

    def make(self, rng, eth, sex, trade, status, head=None, role=None, father=None):
        """Return (given, byname, display). Display must be unique city-wide."""
        for attempt in range(60):
            given, by = self._draw(rng, eth, sex, trade, status, attempt)
            if father is not None and role == "head" and father["ethnicity"] == eth:
                if eth in ("german", "danish"):
                    by = father["byname"]
                elif eth in ("estonian", "swedish", "finnish", "russian"):
                    by = patronymic(eth, father["given"], sex)
            if head is not None and role == "child" and head["sex"] == "m" and head["ethnicity"] == eth:
                if eth == "german" or eth == "danish":
                    by = head["byname"]
                elif eth in ("estonian", "swedish", "finnish", "russian"):
                    by = patronymic(eth, head["given"], sex)
            disp = f"{given} {by}".strip()
            if self.used[disp] == 0 or attempt >= 59:
                if self.used[disp]:
                    base = disp
                    for k in range(len(EPITHETS) * 3):
                        ep = EPITHETS[(self.used[base] * 7 + k + sum(map(ord, base))) % len(EPITHETS)]
                        cand = f"{given} {by} {ep}".replace("  ", " ").strip()
                        if self.used[cand] == 0:
                            break
                    by = f"{by} {ep}".strip()
                    disp = cand
                    self.used[base] += 1
                self.used[disp] += 1
                return given, by, disp
        raise RuntimeError("name pool exhausted")

    def _draw(self, rng, eth, sex, trade, status, attempt):
        m = sex == "m"
        if eth == "german":
            given = rng.choice(GERMAN_M if m else GERMAN_F)
            if status in ("patrician", "council") or trade in ("merchant", "factor", "moneylender", "councillor", "burgomaster", "skipper"):
                by = "van " + rng.choice([t for t in GERMAN_BY_TOPO if t.strip()]) if rng.random() < 0.7 else rng.choice(GERMAN_BY_DESC)
                by = by.replace("van van", "van")
            elif trade in GERMAN_BY_OCC and rng.random() < 0.6:
                by = rng.choice(GERMAN_BY_OCC[trade])
            elif rng.random() < 0.45:
                by = rng.choice(GERMAN_BY_DESC)
            else:
                by = "van " + rng.choice([t for t in GERMAN_BY_TOPO if t.strip()])
            if not m and attempt % 2 == 0 and rng.random() < 0.3:
                by = ""
            return given, by.strip()
        if eth == "estonian":
            given = rng.choice(_clean(ESTONIAN_M, _ESTONIAN_M_DROP) if m else _clean(ESTONIAN_F, _ESTONIAN_F_DROP))
            if given in ("Kalev", "Mart"):
                given = "Marten"
            by = patronymic("estonian", rng.choice(list(EST_GEN)), sex) if (rng.random() < 0.55 or attempt > 3) else ""
            return given, by
        if eth == "swedish":
            given = rng.choice(SWEDE_M if m else SWEDE_F)
            by = patronymic("swedish", rng.choice(SWEDE_M), sex)
            return given, by
        if eth == "finnish":
            given = rng.choice(FINN_M if m else FINN_F)
            by = patronymic("finnish", rng.choice(FINN_M), sex)
            return given, by
        if eth == "russian":
            given = rng.choice(RUSSIAN_M if m else RUSSIAN_F)
            by = patronymic("russian", rng.choice(RUSSIAN_M), sex)
            return given, by
        if eth == "danish":
            given = rng.choice(DANISH_M if m else DANISH_F)
            by = rng.choice(DANISH_BY) if m else rng.choice(DANISH_BY)
            return given, by
        raise ValueError(eth)


# --------------------------------------------------------------------------- building classification

def street_names(plan):
    out = {}
    road_names = {
        "road.viru": "Viru road", "road.karja": "Karja road", "road.harju": "Harju road", "road.tartu": "Tartu road",
        "road.coast_west": "Western coast road", "road.harbour": "Harbour road", "road.sand_beach": "Sand beach road",
        "road.toompea_west": "Western castle road", "road.toompea_south": "Southern castle road",
    }
    for s in plan["streets"]:
        out[s["id"]] = s.get("name", "") or road_names.get(s["id"], "")
    for k, v in road_names.items():
        out.setdefault(k, v)
    return out


DISTRICT_CODE = {
    "district.lower_town": "lt", "district.toompea": "tp", "district.kalarand": "kr", "district.viru": "vi", "district.karja": "ka",
    "district.harju": "ha", "district.toompea_foot": "tf", "none": "xx",
}
DISTRICT_DIR = {
    "lt": "lower_town", "tp": "toompea", "kr": "kalarand", "vi": "viru_road", "ka": "karja_road", "ha": "harju_road", "tf": "toompea_foot",
    "xx": "outside",
}
DISTRICT_NAME = {
    "lt": "Lower Town", "tp": "Toompea", "kr": "Fishing beach (Kalarand)", "vi": "Viru road suburb", "ka": "Cattle-road farmsteads",
    "ha": "Harju-road houses", "tf": "Vassal yards below the castle", "xx": "Outside the districts",
}
DISTRICT_ZONE = {"tp": "toompea", "kr": "fishing", "vi": "suburb", "ka": "suburb", "ha": "suburb", "tf": "toompea", "xx": "suburb"}


def classify(b, district, streets, plan_forum):
    area = poly_area(b["footprint"])
    cx, cy = centroid(b["footprint"])
    sname = streets.get(b["street_id"], "")
    if district == "lt":
        if sname in PLAN_ZONE_STREETS["merchant"]:
            zone = "merchant"
        elif sname in PLAN_ZONE_STREETS["craft"]:
            zone = "craft"
        else:
            zone = "craft"
        if cy < -330 and zone != "merchant":
            zone = "harbour"
        if zone == "merchant" and cy < -380:
            zone = "merchant"
    else:
        zone = DISTRICT_ZONE[district]
    # size class
    if area < 45:
        cls = "shed"
    elif area < 115:
        cls = "poor"
    elif area < 260:
        cls = "master"
    elif area < 460:
        cls = "merchant"
    else:
        cls = "great"
    if cls == "shed" and zone in ("fishing", "suburb") and area >= 22:
        cls = "poor"  # huts and farm cottages are dwellings, not outbuildings
    if zone == "merchant" and cls == "poor":
        cls = "master"
    if zone in ("harbour", "fishing", "suburb") and cls in ("merchant", "great"):
        cls = "master" if zone != "harbour" else "merchant"
    if zone == "toompea" and cls in ("great", "merchant"):
        cls = "master"
    return area, (cx, cy), sname, zone, cls


# --------------------------------------------------------------------------- household generation

SIZE_BY_CLASS = {  # (min, max, mean-ish) of persons; tuned so the plan totals ~4,000 residents
    "shed": (0, 2), "poor": (2, 5), "master": (4, 7), "merchant": (6, 10), "great": (8, 12),
}
AGE_STAFF = {"servant": (15, 45), "maid": (14, 38), "apprentice": (11, 17), "journeyman": (17, 28), "clerk": (16, 32)}


def draw_age_adult(rng, lo, hi, skew=0.0):
    a = rng.triangular(lo, hi, lo + (hi - lo) * (0.35 + skew))
    return int(round(a))


def draw_ethnicity(rng, zone, bias_trade=None):
    mix = list(ETHNIC_BY_ZONE[zone])
    if bias_trade and bias_trade in ETHNIC_TRADE_BIAS:
        for e, mult in ETHNIC_TRADE_BIAS[bias_trade].items():
            mix[ETHNICITIES.index(e)] *= mult
    return wchoice(rng, list(zip(ETHNICITIES, mix)))


def draw_head_trade(rng, zone, cls, eth_hint=None):
    zi = ZONE_INDEX[zone]
    pairs = []
    for t, wz in HEAD_TRADES.items():
        w = wz[zi]
        if w <= 0:
            continue
        low = t in ("labourer", "porter", "fisher", "farmer", "drover", "sailor", "ballast_man", "boatman", "woodcutter", "net_maker", "pedlar",
                    "stable_hand", "carter", "gardener", "pilot")
        if cls in ("great", "merchant") and low:
            w = 0
        elif cls == "master" and low:
            w *= 0.35
        if cls == "poor" and t in ("merchant", "moneylender", "goldsmith", "apothecary", "knight"):
            w *= 0.05
        if cls in ("great", "merchant") and t == "merchant":
            w *= 3.0
        if cls in ("master",) and t == "merchant":
            w *= 0.6
        if cls == "great":
            w *= 8 if t == "merchant" else 0.4
        if eth_hint and t in ETHNIC_TRADE_BIAS:
            w *= ETHNIC_TRADE_BIAS[t].get(eth_hint, 0.7)
        pairs.append((t, w))
    return wchoice(rng, pairs)


def person_stub(rng, eth, sex, age, trade, status, role):
    return {"eth": eth, "sex": sex, "age": age, "trade": trade, "status": status, "role": role}


def build_household(rng, zone, cls, district):
    """Return a list of person stubs for a household (before naming)."""
    if cls == "shed":
        n = wchoice(rng, [(0, 70), (1, 14), (2, 10), (3, 6)])
        if n == 0:
            return [], None
        eth = draw_ethnicity(rng, zone, "labourer")
        out = []
        for i in range(n):
            out.append(person_stub(rng, eth, "m" if i == 0 else rng.choice("mf"), 22 + rng.randint(0, 35), "labourer" if i == 0 else "servant", "labourer", "tenant"))
        return out, "shed"
    lo, hi = SIZE_BY_CLASS[cls]
    target = rng.randint(lo, hi)
    if zone == "fishing":
        target += 1
    if district in ("tp", "tf"):
        target = max(4, int(target * 0.9))
    head_trade = draw_head_trade(rng, zone, cls)
    eth = draw_ethnicity(rng, zone, head_trade)
    if head_trade == "knight":
        eth = wchoice(rng, [("german", 0.75), ("danish", 0.25)])
    widow = rng.random() < 0.13
    head_sex = "f" if widow else "m"
    head_age = draw_age_adult(rng, 24, 74, 0.0)
    if widow:
        head_age = max(head_age, 33)
    elite = head_trade in ("merchant", "moneylender", "knight", "crown_clerk", "goldsmith", "skipper") or cls == "great"
    status_head = {"great": "patrician", "merchant": "burgher_merchant"}.get(cls)
    if head_trade in ("knight",):
        status_head = "noble"
    if not status_head:
        status_head = "master_craftsman" if cls == "master" and head_trade not in ("labourer", "porter", "fisher", "farmer", "drover", "sailor") else (
            "free_commoner" if cls != "poor" else "labourer")
    if head_trade in ("fisher", "net_maker", "boatman", "farmer", "woodcutter", "drover", "labourer", "porter", "sailor", "ballast_man"):
        status_head = "labourer" if cls == "poor" else "free_commoner"
    members = []
    head_trade_final = ("widow_owner_of_" + head_trade) if widow else head_trade
    members.append(person_stub(rng, eth, head_sex, head_age, head_trade, status_head, "head"))
    members[0]["widow"] = widow
    # spouse
    if not widow and rng.random() < 0.88:
        wife_age = max(16, head_age - int(rng.gauss(3.5, 3.5)))
        spouse_eth = eth if rng.random() > 0.05 else rng.choice(["estonian", "german", "swedish"])
        wife_trade = wchoice(rng, [("spinner", 18), ("brewer", 6 if head_trade in ("brewer", "innkeeper") else 0.5), ("retailer", 6 if head_trade in ("merchant", "retailer") else 2),
                                   ("dairy", 3), ("washerwoman", 3), ("healer", 1.5), ("midwife", 0.6), ("alewife", 3 if head_trade in ("innkeeper", "brewer") else 0.6),
                                   ("cook", 2), ("spinner", 6)])
        if head_trade in ("fisher", "fishmonger", "net_maker"):
            wife_trade = rng.choice(["fishmonger", "net_maker", "spinner"])
        if head_trade in ("baker", "butcher", "innkeeper", "shoemaker", "tailor"):
            wife_trade = {"baker": "baker", "butcher": "butcher", "innkeeper": "innkeeper", "shoemaker": "shoemaker", "tailor": "tailor"}[head_trade] if rng.random() < 0.45 else wife_trade
        # trade labels are the key; a wife who "is" the baker's partner is recorded as working in the trade
        members.append(person_stub(rng, spouse_eth, "f", wife_age, wife_trade, status_head if status_head != "labourer" else "free_commoner", "spouse"))
    # children: mother age drives them
    mother_age = members[1]["age"] if len(members) > 1 else (head_age if widow else None)
    if mother_age:
        births = []
        a = rng.randint(18, 25)
        while a <= min(mother_age, 44):
            births.append(mother_age - a)  # child's current age
            a += rng.choice([1, 2, 2, 2, 3, 3, 4])
        for cage in births:
            if cage < 0:
                continue
            # survival to this age
            surv = 0.62 if cage < 12 else 0.58
            if cage < 1:
                surv = 0.85
            if rng.random() > surv:
                continue
            if cage >= 22 or (cage >= 15 and rng.random() < 0.65):
                continue  # left home as apprentice/servant/married
            sex = rng.choice("mf")
            trade = "infant" if cage < 2 else ("child" if cage < 8 else ("apprentice" if (11 <= cage <= 16 and sex == "m" and rng.random() < 0.55) else ("maid" if (cage >= 13 and sex == "f" and rng.random() < 0.4) else ("scholar" if (sex == "m" and cage < 15 and elite and rng.random() < 0.5) else "child" if cage < 14 else (head_trade if sex == "m" else "spinner")))))
            if cage >= 17 and trade == "apprentice":
                trade = head_trade
            members.append(person_stub(rng, eth, sex, cage, trade, status_head, "child"))
    # elderly parent
    if rng.random() < (0.30 if not widow else 0.42) and head_age < 62:
        pa = head_age + rng.randint(22, 30)
        if pa <= 82:
            members.append(person_stub(rng, eth, rng.choice(["m", "f", "f"]), pa, "retired", status_head, "elder"))
    # staff and lodgers up to the target
    staff_pool = []
    if cls in ("master", "merchant", "great"):
        staff_pool += ["apprentice", "journeyman", "maid", "maid", "servant"]
    if cls in ("merchant", "great"):
        staff_pool += ["clerk", "servant", "maid", "maid", "cook"]
    if cls == "great":
        staff_pool += ["clerk", "maid", "servant", "stable_hand"]
    if cls == "poor":
        staff_pool += ["lodger", "lodger", "servant"]
    guard = 0
    while len(members) < target and guard < 40:
        guard += 1
        kind = rng.choice(staff_pool) if staff_pool else "child"
        if kind == "lodger":
            sex = "m" if rng.random() < 0.5 else "f"
            lt = wchoice(rng, [("labourer", 6), ("porter", 3), ("sailor", 2), ("spinner", 2), ("washerwoman", 2), ("pedlar", 1)])
            members.append(person_stub(rng, draw_ethnicity(rng, "harbour", lt), sex, draw_age_adult(rng, 16, 55), lt, "labourer", "lodger"))
            continue
        if kind in ("journeyman", "clerk", "porter", "stable_hand"):
            sex = "m"
        elif kind in ("maid", "cook"):
            sex = "f"
        else:
            sex = "f" if rng.random() < 0.62 else "m"
        lo_a, hi_a = AGE_STAFF.get(kind, (16, 45))
        age = draw_age_adult(rng, lo_a, hi_a)
        if kind in ("journeyman",):
            trade = head_trade if head_trade not in ("merchant", "retailer", "moneylender") else "clerk"
            if head_trade in ("labourer", "porter", "fisher", "farmer"):
                trade = "labourer"
        elif kind == "apprentice":
            trade = "apprentice"
            if head_trade in ("merchant", "retailer", "moneylender"):
                trade = "apprentice"
            sex = "m"
        elif kind == "clerk":
            trade = "clerk"
        elif kind in ("servant", "maid", "cook", "porter", "stable_hand"):
            trade = kind if kind != "servant" else ("servant" if sex == "f" or rng.random() < 0.6 else "stable_hand")
        else:
            trade = kind
        seth = eth
        if cls in ("merchant", "great", "master") and eth == "german" and kind in ("servant", "maid", "porter", "stable_hand", "cook"):
            seth = wchoice(rng, [("estonian", 60), ("german", 22), ("swedish", 10), ("finnish", 8)])
        elif kind in ("apprentice", "journeyman", "clerk"):
            seth = eth if rng.random() < 0.7 else wchoice(rng, [("estonian", 50), ("german", 30), ("swedish", 20)])
        st = {"servant": "servant", "maid": "servant", "cook": "servant", "porter": "servant", "stable_hand": "servant", "apprentice": "apprentice",
              "journeyman": "journeyman", "clerk": "clerk"}.get(kind, "servant")
        members.append(person_stub(rng, seth, sex, age, trade, st, kind if kind in ("servant", "maid", "apprentice", "journeyman", "clerk", "cook", "porter", "stable_hand") else "servant"))
    return members, "house"


# --------------------------------------------------------------------------- appearance

def pace_group(eth):
    return {"german": "german", "danish": "german", "russian": "slavic"}.get(eth, "nordic")


def draw_appearance(rng, p):
    sex, age, eth = p["sex"], p["age"], p["eth"]
    grp = pace_group(eth)
    base = 169.0 if sex == "m" else 157.0
    if eth in ("swedish", "danish"):
        base += 2.0
    if eth == "finnish":
        base -= 1.0
    if age < 18:
        frac = {0: .31, 1: .42, 2: .48, 3: .53, 4: .58, 5: .62, 6: .65, 7: .69, 8: .72, 9: .75, 10: .78, 11: .81, 12: .84, 13: .88, 14: .92, 15: .95, 16: .97, 17: .99}
        h = base * frac.get(age, 0.97) + rng.gauss(0, 3.0)
    else:
        h = base + rng.gauss(0, 5.8)
        if age > 55:
            h -= 0.07 * (age - 55) * 2
    h = max(60, min(h, 192 if sex == "m" else 180))
    build = wchoice(rng, list(BUILDS.items()))
    if p["trade"] in ("smith", "armourer", "porter", "mason", "carter", "cooper", "labourer", "ballast_man", "boatman", "shipwright", "woodcutter", "man_at_arms", "knight"):
        if rng.random() < 0.6 and sex == "m":
            build = rng.choice(["broad-shouldered", "sturdy", "stocky", "heavy-set"])
    if p["trade"] in ("clerk", "scribe", "schoolmaster", "monk", "priest", "canon", "scholar"):
        if rng.random() < 0.55:
            build = rng.choice(["slight", "lean and wiry", "gaunt", "average"])
    if p["status"] in ("patrician",) and age > 40 and rng.random() < 0.5:
        build = rng.choice(["round-bellied", "heavy-set", "sturdy"])
    if age < 12:
        build = rng.choice(["small for the age", "slight", "wiry", "sturdy", "round-faced and solid", "all elbows and knees"])
    if age > 60 and rng.random() < 0.4:
        build = rng.choice(["gaunt", "stooped and thin", "shrunken", "lean and wiry"])
    hair = wchoice(rng, HAIR_COLORS[grp])
    grey = 0.0 if age < 30 else min(1.0, (age - 28) / 50 + rng.gauss(0, 0.12))
    grey = max(0.0, grey)
    if grey < 0.1:
        hair_desc = hair
    elif grey < 0.35:
        hair_desc = f"{hair} with grey at the temples"
    elif grey < 0.65:
        hair_desc = f"{hair}, streaked with grey"
    elif grey < 0.88:
        hair_desc = f"mostly grey over {hair}"
    else:
        hair_desc = "white" if rng.random() < 0.5 else "iron-grey"
    eye = wchoice(rng, EYE_COLORS[grp])
    comp = rng.choice(COMPLEXIONS)
    if p["trade"] in ("fisher", "boatman", "carter", "farmer", "drover", "shipwright", "sailor", "pilot", "ballast_man", "woodcutter"):
        comp = rng.choice(["weathered tan", "wind-reddened", "sun-browned", "weathered and lined"])
    if p["trade"] in ("clerk", "scribe", "moneylender", "canon", "priest", "scholar") or p["status"] == "patrician":
        comp = rng.choice(["pale and even", "sallow with winter pallor", "fair, quick to flush", "rosy-cheeked", "pale and sallow"])
    marks = []
    n_marks = wchoice(rng, [(0, 25), (1, 45), (2, 25), (3, 5)]) if age >= 12 else wchoice(rng, [(0, 55), (1, 40), (2, 5)])
    pool = list(MARKS_GENERAL)
    tm = MARKS_BY_TRADE.get(p["trade"], []) if age >= 14 else []
    for _ in range(n_marks):
        if tm and rng.random() < 0.5:
            m = rng.choice(tm)
        else:
            m = rng.choice(pool)
        if age < 14 and any(k in m for k in ("limp", "stoop", "receding", "laugh lines", "hernia", "sunken cheeks")):
            continue
        if m not in marks:
            marks.append(m)
    facial_hair = None
    if sex == "m" and age >= 16:
        if p["role"] in ("monk",) or p["trade"] in ("monk", "priest", "canon", "chaplain", "sexton", "vicar", "lay_brother"):
            facial_hair = "clean-shaven, tonsured" if p["trade"] != "lay_brother" else "full beard, no tonsure"
        elif eth == "german" or eth == "danish":
            facial_hair = wchoice(rng, [("clean-shaven", 42), ("close-trimmed beard", 24), ("moustache only", 8), ("forked beard", 8), ("stubble, shaved weekly", 14), ("full beard", 4)])
        elif eth == "russian":
            facial_hair = wchoice(rng, [("full beard, parted", 60), ("long moustache and beard", 25), ("clean-shaven", 15)])
        else:
            facial_hair = wchoice(rng, [("full beard", 36), ("short beard", 22), ("clean-shaven", 18), ("moustache and chin beard", 12), ("stubble", 12)])
        if age < 20 and facial_hair not in ("clean-shaven",) and rng.random() < 0.7:
            facial_hair = "sparse downy whiskers"
    left_hand = rng.random() < 0.1
    voice = rng.choice(VOICES)
    return {
        "height_cm": int(round(h)), "build": build, "hair": hair_desc, "eyes": eye, "complexion": comp,
        "marks": marks, "facial_hair": facial_hair, "left_handed": left_hand, "voice": voice,
    }


# --------------------------------------------------------------------------- faction

FACTION_LABELS = {
    "none": "no faction", "hanseatic": "Hanseatic guilds", "danish_crown": "Danish Crown", "livonian_order": "Livonian Order",
    "black_cloaks": "Black Cloaks", "harju_kings": "Harju Kings", "cult_metsik": "Cult of Metsik", "pskov_novgorod": "Pskov / Novgorod",
    "vitalienbruder": "Vitalienbrüder", "blackheads": "Brotherhood of Blackheads", "church": "Church (parish and orders)",
}


def draw_faction(rng, p, zone, district):
    eth, tr, age, st = p["eth"], p["trade"], p["age"], p["status"]
    if age < 14 or tr in ("infant", "child"):
        return "none", "none"
    w = {k: 0.0 for k in FACTIONS}
    w["none"] = 52
    if tr in ("priest", "chaplain", "monk", "nun", "canon", "lay_brother", "lay_sister", "sexton", "vicar"):
        return "church", "core"
    if district in ("tp", "tf"):
        w["danish_crown"] = 30
        w["livonian_order"] = 3
        w["hanseatic"] = 4
    if eth == "german":
        w["hanseatic"] += 28 if zone in ("merchant", "craft") else 12
        if tr in ("merchant", "factor", "clerk", "retailer", "moneylender", "skipper", "councillor"):
            w["hanseatic"] += 24
            w["none"] -= 14
        w["danish_crown"] += 4
        w["livonian_order"] += 2.0
        if tr in ("merchant", "clerk") and age < 36 and p["sex"] == "m":
            w["blackheads"] += 12
    elif eth == "danish":
        w["danish_crown"] += 40
        w["livonian_order"] += 2
    elif eth in ("estonian", "finnish"):
        w["black_cloaks"] += 7 if zone in ("craft", "harbour", "merchant") else 4
        w["harju_kings"] += 5 if zone in ("suburb", "fishing") else 2.5
        w["cult_metsik"] += 4.5
        w["hanseatic"] += 2
        if tr in ("smith", "armourer", "carpenter", "mason", "cooper", "porter", "shoemaker", "weaver", "tanner", "carter"):
            w["black_cloaks"] += 6
        if tr in ("fisher", "net_maker", "boatman", "ballast_man", "sailor"):
            w["vitalienbruder"] += 1.2
        if tr in ("healer", "midwife", "farmer", "drover", "woodcutter", "dairy", "washerwoman", "spinner"):
            w["cult_metsik"] += 5
    elif eth == "swedish":
        w["hanseatic"] += 10
        w["vitalienbruder"] += 1.5
        w["black_cloaks"] += 2
    elif eth == "russian":
        w["pskov_novgorod"] += 70
    if tr in ("sailor", "boatman", "porter", "ballast_man", "skipper") and zone in ("harbour", "fishing"):
        w["vitalienbruder"] += 1.8
    if tr == "knight":
        w["danish_crown"] += 25
        w["livonian_order"] += 3
    if tr in ("watch_sergeant", "gatekeeper", "ratsdiener", "stadtschreiber", "councillor", "burgomaster", "weigher"):
        w["hanseatic"] += 30
        w["none"] = 5
    if tr in ("man_at_arms", "crown_clerk", "castle_servant", "castle_cook", "chamberlain", "falconer", "squire"):
        w["danish_crown"] += 35
        w["none"] = 8
    if tr in ("novgorod_merchant", "novgorod_clerk"):
        w["pskov_novgorod"] += 80
        w["none"] = 5
    keys = [k for k in w if w[k] > 0]
    f = wchoice(rng, [(k, w[k]) for k in keys])
    if f == "none":
        return "none", "none"
    role = wchoice(rng, [("core", 12), ("active", 24), ("sympathiser", 46), ("coerced_or_dependent", 10), ("informer", 8)])
    if f in ("hanseatic",):
        role = wchoice(rng, [("core", 14), ("active", 36), ("sympathiser", 38), ("dependent", 12)])
    if f in ("harju_kings", "black_cloaks", "cult_metsik", "vitalienbruder") and rng.random() < 0.7:
        role = wchoice(rng, [("secret_sympathiser", 50), ("secret_cell_member", 25), ("courier", 12), ("informer", 13)])
    return f, role


# --------------------------------------------------------------------------- institutions & civic (fixed rosters)

def institution_rosters():
    """Households that are not plot houses. (id, district, name, building_hint, members(trade,count,eth,sex-balance))"""
    return [
        {"id": "inst.st_catherine_friary", "district": "lt", "name": "St Catherine's Dominican friary", "bldg": "bldg.osm.w26885940",
         "street": "Katariina käik", "zone": "craft", "roster": [("monk", 24, "german", "m"), ("lay_brother", 8, "estonian", "m"), ("servant", 5, "estonian", "m"),
                                                                 ("cook", 1, "estonian", "m")]},
        {"id": "inst.st_michael_nunnery", "district": "lt", "name": "St Michael's Cistercian nunnery", "bldg": "bldg.osm.w26889132",
         "street": "Väike-Kloostri", "zone": "craft", "roster": [("nun", 22, "german", "f"), ("lay_sister", 8, "estonian", "f"), ("servant", 6, "estonian", "f"),
                                                                 ("chaplain", 2, "german", "m"), ("gardener", 2, "estonian", "m")]},
        {"id": "inst.holy_spirit_house", "district": "lt", "name": "Holy Spirit hospital house", "bldg": "bldg.osm.w28131871",
         "street": "Pühavaimu", "zone": "craft", "roster": [("hospital_inmate", 14, "mixed", "m"), ("hospital_inmate", 6, "mixed", "f"), ("priest", 1, "german", "m"),
                                                            ("servant", 3, "estonian", "f")]},
        {"id": "inst.st_olaf_parish", "district": "lt", "name": "St Olaf's parish house", "bldg": "bldg.osm.w26889368",
         "street": "Oleviste", "zone": "harbour", "roster": [("priest", 1, "german", "m"), ("chaplain", 3, "german", "m"), ("sexton", 1, "estonian", "m"),
                                                          ("gravedigger", 1, "estonian", "m"), ("servant", 2, "estonian", "f")]},
        {"id": "inst.st_nicholas_parish", "district": "lt", "name": "St Nicholas' parish house", "bldg": "bldg.osm.w26889447",
         "street": "Niguliste", "zone": "merchant", "roster": [("priest", 1, "german", "m"), ("chaplain", 3, "german", "m"), ("sexton", 1, "estonian", "m"),
                                                             ("servant", 2, "estonian", "f")]},
        {"id": "inst.novgorod_court", "district": "lt", "name": "Novgorod merchants' church and court", "bldg": "bldg.osm.w26900845",
         "street": "Vene", "zone": "merchant", "roster": [("novgorod_merchant", 8, "russian", "m"), ("novgorod_clerk", 4, "russian", "m"),
                                                          ("priest", 1, "russian", "m"), ("servant", 4, "russian", "m")]},
        {"id": "inst.town_hall", "district": "lt", "name": "Town hall (council servants)", "bldg": "bldg.lm.town_hall",
         "street": "Raekoja", "zone": "merchant", "roster": [("stadtschreiber", 1, "german", "m"), ("scribe", 2, "german", "m"), ("ratsdiener", 4, "german", "m"),
                                                            ("weigher", 1, "german", "m"), ("watch_sergeant", 2, "german", "m"), ("servant", 3, "estonian", "m")]},
        {"id": "inst.st_mary_chapter", "district": "tp", "name": "Cathedral chapter of St Mary", "bldg": "bldg.osm.w26902813",
         "street": "Kiriku plats", "zone": "toompea", "roster": [("canon", 12, "german", "m"), ("vicar", 8, "german", "m"), ("sexton", 2, "estonian", "m"),
                                                                 ("scribe", 2, "german", "m"), ("servant", 10, "estonian", "m"), ("castle_cook", 3, "estonian", "f")]},
        {"id": "inst.castle_toompea", "district": "tp", "name": "Toompea castle (Danish crown)", "bldg": "", "street": "Lossi plats", "zone": "toompea",
         "roster": [("man_at_arms", 36, "mixed_dk", "m"), ("squire", 6, "danish", "m"), ("crown_clerk", 5, "danish", "m"), ("chamberlain", 1, "danish", "m"),
                    ("castle_cook", 4, "estonian", "m"), ("castle_servant", 18, "estonian", "f"), ("stable_hand", 6, "estonian", "m"), ("falconer", 1, "danish", "m"),
                    ("knight", 1, "danish", "m")]},
        {"id": "inst.harbour_transients", "district": "lt", "name": "Harbour inns and ships' berths (seasonal)", "bldg": "",
         "street": "Coastal Gate quay", "zone": "harbour", "roster": [("sailor", 90, "mixed_sea", "m"), ("skipper", 8, "german", "m"), ("pilgrim", 6, "mixed", "m"),
                                                                       ("pedlar", 8, "finnish", "m")]},
    ]


def inst_xy(inst, building_info):
    if inst["bldg"] and inst["bldg"] in building_info:
        return [round(building_info[inst["bldg"]][3]), round(building_info[inst["bldg"]][4])]
    return {"inst.castle_toompea": [-440, 170], "inst.harbour_transients": [220, -560]}.get(inst["id"], [0, 0])


def draw_inst_member(rng, trade, eth_spec, sex_spec, nb, inst):
    if eth_spec == "mixed":
        eth = wchoice(rng, [("estonian", 45), ("german", 35), ("swedish", 15), ("finnish", 5)])
    elif eth_spec == "mixed_dk":
        eth = wchoice(rng, [("danish", 52), ("german", 40), ("estonian", 8)])
    elif eth_spec == "mixed_sea":
        eth = wchoice(rng, [("german", 36), ("swedish", 24), ("finnish", 10), ("estonian", 14), ("danish", 8), ("russian", 8)])
    else:
        eth = eth_spec
    sex = sex_spec
    if trade in ("monk", "canon", "priest", "chaplain", "vicar"):
        age = int(rng.triangular(24, 70, 40))
    elif trade in ("nun", "lay_sister"):
        age = int(rng.triangular(18, 72, 38))
    elif trade in ("hospital_inmate",):
        age = int(rng.triangular(40, 86, 66))
    elif trade in ("sailor",):
        age = int(rng.triangular(16, 55, 26))
    elif trade in ("squire",):
        age = rng.randint(16, 22)
    elif trade in ("man_at_arms",):
        age = int(rng.triangular(19, 48, 28))
    else:
        age = int(rng.triangular(18, 62, 33))
    status = {"monk": "cleric", "canon": "cleric", "priest": "cleric", "chaplain": "cleric", "vicar": "cleric", "nun": "cleric", "lay_brother": "cleric",
              "lay_sister": "cleric", "sexton": "servant", "man_at_arms": "soldier", "squire": "noble", "knight": "noble", "crown_clerk": "clerk",
              "sailor": "labourer", "skipper": "burgher_merchant", "hospital_inmate": "dependent", "novgorod_merchant": "guest_merchant",
              "novgorod_clerk": "clerk", "stadtschreiber": "burgher", "watch_sergeant": "burgher"}.get(trade, "servant")
    return person_stub(rng, eth, sex, age, trade, status, "resident")


# --------------------------------------------------------------------------- main build

def build():
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    streets = street_names(plan)
    districts = plan["districts"]
    forum = plan["forum"]
    names = NameBook()
    households = []
    persons = []

    def district_of(pt):
        for d in districts:
            if inside(pt, d["polygon"]):
                return DISTRICT_CODE.get(d["id"], "xx")
        return "xx"

    building_info = {}
    for b in plan["buildings"]:
        c = centroid(b["footprint"])
        dcode = district_of(c)
        area, (cx, cy), sname, zone, cls = classify(b, dcode, streets, forum)
        building_info[b["id"]] = (b, dcode, area, cx, cy, sname, zone, cls)

    # per building households (only plain houses; churches/hall belong to institutions)
    for bid in sorted(building_info):
        b, dcode, area, cx, cy, sname, zone, cls = building_info[bid]
        if b["kind"] != "house":
            continue
        rng = seed_rng("household", bid)
        stubs, hkind = build_household(rng, zone, cls, dcode)
        short = bid.replace("bldg.", "").replace(".", "_")
        hid = f"hh.{dcode}.{short}"
        hh = {"id": hid, "kind": hkind or "empty", "building": bid, "district": dcode, "street": sname or "Back lane", "zone": zone, "class": cls,
              "area_m2": round(area), "door": b.get("door"), "xy": [round(cx), round(cy)], "members": []}
        recs = {}
        elder_i = next((i for i, st in enumerate(stubs) if st["role"] == "elder" and st["sex"] == "m" and not (stubs[0].get("widow"))), None)
        order = ([elder_i] if elder_i is not None else []) + [0 if i == 0 else None for i in [0]] + [i for i in range(1, len(stubs)) if i != elder_i]
        order = [i for i in order if i is not None] if stubs else []
        for i in order:
            prng = seed_rng("person", bid, i)
            pid = f"cit.{dcode}.{short}.{i + 1:02d}"
            recs[i] = _finish_person(prng, stubs[i], pid, hid, zone, dcode, names, sname,
                                     head=recs.get(0) if i != 0 else None, father=recs.get(elder_i) if (i == 0 and elder_i is not None) else None)
        for i in range(len(stubs)):
            persons.append(recs[i])
            hh["members"].append(recs[i]["id"])
        households.append(hh)

    # institutions
    for inst in institution_rosters():
        rng = seed_rng("institution", inst["id"])
        hh = {"id": "hh." + inst["id"].replace("inst.", "inst_"), "kind": "institution", "building": inst["bldg"], "district": inst["district"],
              "street": inst["street"], "zone": inst["zone"], "class": "institution", "area_m2": 0, "door": None, "xy": inst_xy(inst, building_info), "members": [], "name": inst["name"]}
        i = 0
        for trade, count, eth, sex in inst["roster"]:
            for _ in range(count):
                i += 1
                prng = seed_rng("person", inst["id"], i)
                s = draw_inst_member(prng, trade, eth, sex, i, inst)
                pid = f"cit.{inst['district']}.{inst['id'].replace('inst.', 'inst_')}.{i:03d}"
                persons.append(_finish_person(prng, s, pid, hh["id"], inst["zone"], inst["district"], names, inst["street"], inst=True))
                hh["members"].append(pid)
        households.append(hh)

    seen = Counter()
    for p in persons:
        base = slugify(p["name"])
        seen[base] += 1
        p["slug"] = base if seen[base] == 1 else f"{base}_{seen[base]}"
    return {"schema": SCHEMA, "households": households, "persons": persons, "plan_buildings": len(plan["buildings"])}


def _finish_person(rng, s, pid, hid, zone, dcode, names, street, inst=False, head=None, father=None):
    eth, sex, age, trade = s["eth"], s["sex"], s["age"], s["trade"]
    status = s["status"]
    given, by, disp = names.make(rng, eth, sex, trade, status, head=head, role=s["role"], father=father)
    app = draw_appearance(rng, s)
    f, frole = draw_faction(rng, s, zone, dcode)
    segment = segment_of(s)
    literacy = "none"
    if trade in ("merchant", "factor", "clerk", "moneylender", "stadtschreiber", "scribe", "crown_clerk", "schoolmaster", "priest", "canon", "chaplain", "vicar", "monk", "nun", "apothecary", "scholar", "councillor", "burgomaster", "skipper", "novgorod_merchant", "novgorod_clerk", "goldsmith"):
        literacy = "reads_writes"
    elif status in ("patrician", "burgher_merchant") or (eth in ("german", "danish") and status == "master_craftsman" and rng.random() < 0.45):
        literacy = "reads_numerals"
    elif rng.random() < 0.06:
        literacy = "numerals_only"
    langs = {"german": ["mlg"], "estonian": ["estonian"], "swedish": ["swedish"], "finnish": ["finnish"], "russian": ["russian"], "danish": ["danish"]}[eth]
    langs = list(langs)
    if eth in ("estonian", "swedish", "finnish") and (zone in ("merchant", "craft", "harbour") and rng.random() < 0.7 or status in ("servant", "apprentice", "journeyman", "clerk") and rng.random() < 0.8):
        langs.append("mlg")
    if eth == "german" and (status in ("servant", "labourer") or zone in ("harbour", "craft")) and rng.random() < 0.35:
        langs.append("estonian")
    if eth == "danish":
        langs.append("mlg")
    if eth == "russian":
        langs.append("mlg")
    if literacy == "reads_writes":
        langs.append("latin")
    return {
        "id": pid, "household": hid, "name": disp, "given": given, "byname": by, "sex": sex, "age": age, "ethnicity": eth, "segment": segment,
        "status": status, "trade": trade, "household_role": s["role"], "faction": f, "faction_role": frole, "literacy": literacy, "languages": langs,
        "widow": bool(s.get("widow")), "appearance": app,
    }


def segment_of(s):
    eth, tr, st = s["eth"], s["trade"], s["status"]
    if tr in ("priest", "chaplain", "monk", "nun", "canon", "lay_brother", "lay_sister", "sexton", "vicar"):
        return "cleric"
    if tr in ("sailor", "skipper", "pilgrim"):
        return "sailor"
    if tr == "refugee":
        return "refugee"
    if st in ("servant", "apprentice") or tr in ("servant", "maid", "apprentice"):
        return "servant"
    if eth == "german":
        return "german_burgher" if st in ("patrician", "burgher_merchant", "master_craftsman", "burgher", "clerk") else "german_resident"
    if eth == "danish":
        return "danish_crown_household"
    if eth == "estonian":
        return "estonian_townsman"
    if eth in ("swedish", "finnish"):
        return "swede_hauler" if tr in ("porter", "carter", "labourer", "fisher", "boatman", "net_maker") else "swede_finn_resident"
    if eth == "russian":
        return "russian_guest"
    return "other"


# --------------------------------------------------------------------------- civic role assignment (post pass)

def assign_civic_roles(data):
    """Mark council seats, watch posts and other fixed offices on existing residents (deterministic)."""
    persons = {p["id"]: p for p in data["persons"]}
    hh = {h["id"]: h for h in data["households"]}
    merch_heads = []
    for h in data["households"]:
        if h["kind"] != "house" or h["district"] != "lt":
            continue
        for pid in h["members"]:
            p = persons[pid]
            if p["household_role"] == "head" and p["sex"] == "m" and p["ethnicity"] == "german" and p["status"] in ("patrician", "burgher_merchant") and 36 <= p["age"] <= 66:
                merch_heads.append((h["area_m2"], pid))
    merch_heads.sort(reverse=True)
    council = [pid for _, pid in merch_heads[:20]]
    for i, pid in enumerate(council):
        p = persons[pid]
        p["office"] = "burgomaster" if i < 2 else "councillor"
        p["trade"] = "merchant" if p["trade"] in ("labourer",) else p["trade"]
        p["faction"] = "hanseatic"
        p["faction_role"] = "core"
        if i == 0:  # attested name (d. Dec 1345), person detail is a plausible composite; see names-address-and-oaths.md
            p.update({"name": "Dietrich Zierenberg", "given": "Dietrich", "byname": "Zierenberg", "slug": "dietrich_zierenberg",
                      "attested_name": True})
    # gate keepers: heads of poor/master households nearest to each gate, by street proximity is not tracked here; pick deterministic small-house German/Estonian men
    gates = ["Coastal Gate", "Sand Gate", "Viru Gate", "Cattle Gate", "Smiths' Gate", "Long Hill Gate", "Short Hill Gate", "Nunnery Gate"]
    rng = seed_rng("gatekeepers")
    cand = [pid for pid, p in persons.items() if p["household_role"] in ("head", "journeyman") and p["sex"] == "m" and 30 <= p["age"] <= 58
            and hh[p["household"]]["district"] == "lt" and hh[p["household"]]["class"] in ("poor", "master") and "office" not in p]
    rng.shuffle(cand)
    for g, pid in zip(gates, cand[:8]):
        p = persons[pid]
        p["office"] = f"gatekeeper:{g}"
        p["trade"] = "gatekeeper"
        p["faction"] = "hanseatic"
        p["faction_role"] = "dependent"
    # attested micro-roles (estonian-and-german-populations.md): one Estonian night-watch squad, an Estonian-speaking city herdsman
    est = [pid for pid, p in persons.items() if p["ethnicity"] == "estonian" and p["sex"] == "m" and 22 <= p["age"] <= 50
           and p["household_role"] in ("head", "journeyman", "lodger") and hh[p["household"]]["district"] == "lt" and "office" not in p
           and p["trade"] in ("labourer", "porter", "carter", "mason", "carpenter", "cooper")]
    seed_rng("estwatch").shuffle(est)
    for pid in est[:8]:
        persons[pid]["office"] = "estonian_night_watch"
        persons[pid]["faction"] = "hanseatic" if seed_rng("w", pid).random() < 0.6 else persons[pid]["faction"]
    herd = [pid for pid, p in persons.items() if hh[p["household"]]["district"] == "ka" and p["sex"] == "m" and 25 <= p["age"] <= 60
            and p["household_role"] == "head" and p["ethnicity"] == "estonian"]
    if herd:
        persons[sorted(herd)[0]]["office"] = "city_herdsman"
        persons[sorted(herd)[0]]["trade"] = "town_herdsman"
    hang = [pid for pid, p in persons.items() if hh[p["household"]]["district"] in ("ha", "vi") and p["sex"] == "m" and 28 <= p["age"] <= 55
            and p["household_role"] == "head" and "office" not in p]
    if hang:
        pid = sorted(hang)[-1]
        persons[pid]["office"] = "executioner"
        persons[pid]["trade"] = "executioner"
        persons[pid]["faction"] = "none"
        persons[pid]["faction_role"] = "none"
    return data


def pop_stats(data):
    persons = data["persons"]
    n = len(persons)
    st = {"total": n}
    st["by_district"] = Counter(hh["district"] for hh in data["households"] for _ in hh["members"])
    st["sex"] = Counter(p["sex"] for p in persons)
    st["eth"] = Counter(p["ethnicity"] for p in persons)
    st["faction"] = Counter(p["faction"] for p in persons)
    bands = [(0, 4), (5, 14), (15, 29), (30, 44), (45, 59), (60, 120)]
    st["age"] = Counter()
    for p in persons:
        for lo, hi in bands:
            if lo <= p["age"] <= hi:
                st["age"][f"{lo}-{hi if hi < 120 else '+'}"] += 1
    st["trade"] = Counter(p["trade"] for p in persons)
    st["segment"] = Counter(p["segment"] for p in persons)
    return st


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args(argv)
    data = build()
    assign_civic_roles(data)
    # normalise: list ordering is deterministic
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"), sort_keys=True) + "\n"
    if args.stats:
        st = pop_stats(data)
        for k, v in st.items():
            print(k, dict(v) if hasattr(v, "items") else v)
        return 0
    if args.check:
        if not OUT_JSON.exists() or OUT_JSON.read_text(encoding="utf-8") != text:
            print("city census is stale: run python3 tools/city/build_city_census.py", file=sys.stderr)
            return 1
        return 0
    OUT_JSON.write_text(text, encoding="utf-8")
    print(f"wrote {OUT_JSON.relative_to(ROOT)}: {len(data['households'])} households, {len(data['persons'])} persons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
