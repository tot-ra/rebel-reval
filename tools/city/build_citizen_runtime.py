#!/usr/bin/env python3
"""Compile the city census into the runtime citizen file (docs/SYSTEMS/CITIZENS.md).

  python3 tools/city/build_citizen_runtime.py            # write content/world/reval_city/citizens.json
  python3 tools/city/build_citizen_runtime.py --check    # fail when the committed file is stale

Inputs: docs/data/city_census.json (who lives where), content/world/reval_city/plan.json
(streets, doors, points of interest) and the deep cards under docs/CITIZENS/people
(one-line blurb). Output, deterministic and ID-stable:

- `graph`: the walkable street network (street vertices, crossings, T-junctions and the
  projection of every door and point of interest onto the nearest street).
- `places`: every position a resident can be at ([x, z, graph node, outward angle]).
- `patterns`: daily timetables (hour of departure, destination key).
- `residents`: one record per resident aged 3 or more, with the blank body that
  matches their sex, age and build, a height scale, their home and workplace, and the
  facts the information panel shows. Infants stay indoors and are not compiled.

Body ids mirror tools/assets/realistic_humans/citizen_bodies.py.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets/realistic_humans"))
import citizen_bodies  # noqa: E402

CENSUS = ROOT / "docs/data/city_census.json"
PLAN = ROOT / "content/world/reval_city/plan.json"
PEOPLE = ROOT / "docs/CITIZENS/people"
OUT = ROOT / "content/world/reval_city/citizens.json"

SCHEMA = "rr.city_citizens.v1"
MIN_AGE = 3
DOOR_STAND = 2.5  # metres out from the door, same as CityTravel
NODE_MERGE = 1.5
SNAP_MAX = 60.0

# --- build phrase -> body build class ------------------------------------

BUILD_CLASS = {
    "slight": "thin", "lean and wiry": "thin", "wiry": "thin", "gaunt": "thin",
    "all elbows and knees": "thin", "small for the age": "thin", "long-limbed": "thin",
    "average": "average",
    "sturdy": "sturdy", "stocky": "sturdy", "broad-shouldered": "sturdy",
    "heavy-set": "heavy", "round-faced and solid": "heavy", "pear-shaped": "heavy",
}
HEAD_BUILD = {"round-faced and solid": 0.06, "small for the age": -0.04, "gaunt": -0.03,
              "all elbows and knees": 0.03}

# --- trade -> pattern, workplace -----------------------------------------
# work kinds: door (own door), forum, landing, granary, hall, church, post, castle, well,
# mill, gate, none.

PATTERN_OF = {}
WORK_OF = {}


def _trades(pattern, work, *names):
    for name in names:
        PATTERN_OF[name] = pattern
        WORK_OF[name] = work


_trades("craft", "door", "smith", "nailsmith", "carpenter", "joiner", "cooper", "shoemaker", "tailor",
        "weaver", "tanner", "furrier", "glover", "saddler", "hatter", "cutler", "armourer", "brewer",
        "baker", "butcher", "dyer", "potter", "tiler", "mason", "glazier", "chandler", "ropemaker",
        "sailmaker", "net_maker", "comb_maker", "belt_maker", "tallow", "wheelwright", "barber",
        "healer", "midwife", "innkeeper", "alewife", "brickmaker", "limeburner", "bathkeeper",
        "musician", "gardener", "farmer", "woodcutter", "falconer", "apprentice", "stable_hand")
_trades("market", "forum", "retailer", "merchant", "greengrocer", "pedlar", "saltmonger", "dairy",
        "novgorod_merchant", "moneylender")
_trades("market", "landing", "fishmonger", "fisher")
_trades("market", "granary", "sailor", "boatman", "porter", "carter", "pilot", "skipper", "shipwright",
        "labourer", "drover")
_trades("admin", "hall", "clerk", "scribe", "stadtschreiber", "ratsdiener", "scholar", "weigher",
        "chamberlain", "novgorod_clerk")
_trades("admin", "castle", "crown_clerk")
_trades("cleric", "church", "monk", "lay_brother", "nun", "lay_sister", "chaplain", "priest", "vicar",
        "canon", "sexton", "gravedigger")
_trades("military", "post", "man_at_arms", "knight", "squire", "watch_sergeant", "executioner")
_trades("military", "gate", "gatekeeper")
_trades("market", "mill", "miller")
_trades("domestic", "door", "spinner", "maid", "servant", "cook", "castle_cook", "castle_servant")
_trades("well", "well", "washerwoman")
_trades("leisure", "none", "retired", "pilgrim", "hospital_inmate", "town_herdsman")
_trades("child", "none", "child")

# Where people take a walk; and who counts as clergy (always at church).
STROLLS = ["poi.forum", "poi.fish_landing", "poi.well.dominican", "poi.well.yard.viru",
           "poi.well.yard.pikk_north", "poi.guard.viru", "poi.guard.coastal", "poi.bath.nunne",
           "poi.well.bishop_garden"]
CLERGY = {"monk", "lay_brother", "nun", "lay_sister", "canon", "chaplain", "priest", "vicar",
          "sexton", "gravedigger"}

# What a trade fetches in the middle of the working day.
SUPPLY_OF = {}
for _kind, _trade_names in {
    "iron": ("smith", "nailsmith", "armourer", "cutler", "saddler", "wheelwright", "belt_maker"),
    "grain": ("baker", "brewer", "miller", "alewife", "innkeeper", "cook", "dairy"),
    "fish": ("fisher", "net_maker", "fishmonger"),
    "water": ("dyer", "tanner", "washerwoman", "glover", "furrier"),
    "wood": ("carpenter", "joiner", "cooper", "shipwright", "ropemaker", "tiler", "potter",
             "limeburner", "brickmaker", "mason"),
}.items():
    for _t in _trade_names:
        SUPPLY_OF[_t] = _kind
SUPPLY_POI = {"iron": "poi.smithy.harju", "grain": "poi.granary.pikk", "fish": "poi.fish_landing",
              "water": "poi.well.yard.lai", "wood": "poi.mill.karja", "market": "poi.forum"}

# Timetables: (hour to set out, destination key). The resident is wherever the
# previous destination was, and the first entry follows the last one overnight.
PATTERNS = {
    "home": [[0.0, "home"]],
    # Children of the better-off go to the parish school, the rest fetch and carry.
    "school": [[7.4, "school"], [11.8, "home"], [13.0, "school"], [15.4, "door"], [17.0, "home"]],
    "child": [[6.6, "water"], [7.0, "home"], [8.0, "door"], [9.5, "food"], [10.0, "door"], [11.5, "home"],
              [13.0, "fuel"], [13.5, "door"], [15.5, "stroll"], [17.5, "home"]],
    # Housework: slops, water, bread, firewood, with long spells indoors.
    "domestic": [[5.6, "water"], [6.0, "home"], [6.4, "latrine"], [6.6, "home"], [7.3, "food"],
                 [8.2, "home"], [10.2, "fuel"], [10.7, "home"], [14.3, "water"], [14.7, "home"],
                 [16.0, "church"], [17.0, "stroll"], [17.8, "home"]],
    # Workshops: in and out of the doorway, fetching what the trade needs.
    "craft": [[5.8, "water"], [6.2, "latrine"], [6.4, "door"], [8.4, "home"], [8.8, "supply"],
              [9.5, "door"], [11.6, "home"], [12.8, "door"], [15.0, "supply"], [15.6, "door"],
              [17.2, "church"], [18.0, "stroll"], [19.0, "home"]],
    "market": [[5.5, "work"], [9.4, "food"], [10.0, "work"], [12.0, "home"], [13.0, "work"],
               [16.4, "water"], [17.0, "work"], [18.0, "home"]],
    "admin": [[7.0, "work"], [10.0, "food"], [10.5, "work"], [12.0, "home"], [13.5, "work"],
              [16.0, "stroll"], [17.0, "church"], [17.8, "home"]],
    "cleric": [[4.5, "work"], [7.0, "water"], [7.4, "work"], [9.0, "home"], [10.0, "work"],
               [12.0, "home"], [14.0, "work"], [18.0, "home"]],
    "military": [[6.0, "work"], [12.0, "food"], [12.5, "work"], [18.0, "door"], [19.5, "home"]],
    "well": [[6.0, "work"], [11.0, "home"], [11.6, "food"], [12.2, "home"], [13.2, "work"], [16.5, "home"]],
    "leisure": [[7.0, "church"], [8.0, "water"], [8.4, "door"], [9.8, "home"], [10.5, "stroll"],
                [12.0, "home"], [14.0, "door"], [15.0, "stroll"], [16.2, "water"], [16.6, "home"]],
}

SPREAD_SLOTS = 12  # distinct standing spots round a point of interest
CHILD_PLAY_AGE = 6  # younger children stay in the house with their mother


# --- geometry -------------------------------------------------------------

def seg_closest(p, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    ll = dx * dx + dz * dz
    t = 0.0 if ll == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / ll))
    return t, (ax + dx * t, az + dz * t)


def seg_intersect(a, b, c, d):
    """Intersection point of segments ab and cd, or None."""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < 1e-9:
        return None
    qp = (c[0] - a[0], c[1] - a[1])
    t = (qp[0] * s[1] - qp[1] * s[0]) / den
    u = (qp[0] * r[1] - qp[1] * r[0]) / den
    if 0.0 < t < 1.0 and 0.0 < u < 1.0:
        return (a[0] + r[0] * t, a[1] + r[1] * t)
    return None


class Graph:
    """Street network with node dedupe and edge splitting."""

    def __init__(self, streets):
        self.nodes: list[tuple[float, float]] = []
        self.edges: set[tuple[int, int]] = set()
        chains = []
        for pts in streets:
            chain = [self.node(tuple(p)) for p in pts]
            chains.append(chain)
        # Crossings between different streets.
        segments = []
        for ci, chain in enumerate(chains):
            for k in range(len(chain) - 1):
                if chain[k] != chain[k + 1]:
                    segments.append((ci, chain[k], chain[k + 1]))
        splits: dict[tuple[int, int], list[int]] = {}
        for i, (ci, a, b) in enumerate(segments):
            for cj, c, d in segments[i + 1:]:
                if ci == cj or len({a, b, c, d}) < 4:
                    continue
                hit = seg_intersect(self.nodes[a], self.nodes[b], self.nodes[c], self.nodes[d])
                if hit is not None:
                    n = self.node(hit)
                    splits.setdefault((a, b), []).append(n)
                    splits.setdefault((c, d), []).append(n)
        for ci, a, b in segments:
            self._add_chain(a, b, splits.get((a, b), []))
        # T-junctions: a street end that lands near another street.
        self._snap_endpoints(chains)

    def node(self, p):
        for i, q in enumerate(self.nodes):
            if abs(q[0] - p[0]) <= NODE_MERGE and abs(q[1] - p[1]) <= NODE_MERGE and \
                    math.hypot(q[0] - p[0], q[1] - p[1]) <= NODE_MERGE:
                return i
        self.nodes.append((round(p[0], 2), round(p[1], 2)))
        return len(self.nodes) - 1

    def _add_chain(self, a, b, mids):
        ax, az = self.nodes[a]
        order = sorted(set(mids), key=lambda n: math.hypot(self.nodes[n][0] - ax, self.nodes[n][1] - az))
        chain = [a] + [n for n in order if n not in (a, b)] + [b]
        for u, v in zip(chain, chain[1:]):
            if u != v:
                self.edges.add((min(u, v), max(u, v)))

    def _snap_endpoints(self, chains):
        for chain in chains:
            for end in (chain[0], chain[-1]):
                if self.degree(end) <= 1:
                    self.snap(self.nodes[end], exclude=end, limit=8.0, link=end)

    def degree(self, n):
        return sum(1 for e in self.edges if n in e)

    def nearest_edge(self, p, exclude=None):
        best = (1e18, None, None, None)
        for u, v in self.edges:
            if exclude in (u, v):
                continue
            t, q = seg_closest(p, self.nodes[u], self.nodes[v])
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            if d < best[0]:
                best = (d, (u, v), t, q)
        return best

    def snap(self, p, exclude=None, limit=SNAP_MAX, link=None):
        """Project p onto the network, splitting the edge; return (node, distance)."""
        d, edge, t, q = self.nearest_edge(p, exclude)
        if edge is None or d > limit:
            return None, d
        u, v = edge
        for end in (u, v):
            if math.hypot(self.nodes[end][0] - q[0], self.nodes[end][1] - q[1]) <= NODE_MERGE:
                node = end
                break
        else:
            node = len(self.nodes)
            self.nodes.append((round(q[0], 2), round(q[1], 2)))
            self.edges.discard((u, v))
            self.edges.add((min(u, node), max(u, node)))
            self.edges.add((min(v, node), max(v, node)))
        if link is not None and link != node:
            self.edges.add((min(link, node), max(link, node)))
        return node, d


# --- data -------------------------------------------------------------------

def hash01(key: str) -> float:
    return (zlib.crc32(key.encode()) & 0xFFFFFF) / float(0x1000000)


def read_cards():
    """Census id -> (card slug, relative path, blurb)."""
    cards = {}
    for path in sorted(PEOPLE.rglob("*.md")):
        if path.name == "README.md":
            continue
        text = path.read_text()
        m = re.search(r"\| Census ID \| `([^`]+)` \|", text)
        if not m:
            continue
        blurb = re.search(r"^> (.+)$", text, re.M)
        cards[m.group(1)] = (path.stem, str(path.relative_to(ROOT)),
                             blurb.group(1).strip() if blurb else "")
    return cards


# Period dyes (specs.py _CROWD_DYES) by wealth; the body glTF carries one undyed
# palette and the runtime multiplies each resident's garments with these.
DYES = {
    "poor": [(0.46, 0.44, 0.40), (0.36, 0.28, 0.20), (0.36, 0.20, 0.12), (0.72, 0.67, 0.56),
             (0.30, 0.21, 0.14), (0.50, 0.35, 0.21)],
    "mid": [(0.27, 0.35, 0.46), (0.52, 0.25, 0.18), (0.60, 0.52, 0.28), (0.35, 0.40, 0.28),
            (0.36, 0.28, 0.20), (0.46, 0.44, 0.40), (0.30, 0.21, 0.14), (0.27, 0.35, 0.46)],
    "rich": [(0.17, 0.24, 0.38), (0.42, 0.13, 0.10), (0.20, 0.17, 0.15), (0.84, 0.82, 0.76),
             (0.24, 0.30, 0.20), (0.30, 0.15, 0.30)],
}
UNDER = [(0.22, 0.20, 0.17), (0.30, 0.21, 0.14), (0.27, 0.35, 0.46), (0.46, 0.44, 0.40), (0.72, 0.67, 0.56)]
HABIT = [(0.20, 0.17, 0.15), (0.26, 0.23, 0.20)]
WEALTH = {"patrician": "rich", "noble": "rich", "guest_merchant": "rich", "burgher_merchant": "rich",
          "master_craftsman": "mid", "clerk": "mid", "cleric": "mid", "free_commoner": "mid",
          "journeyman": "mid", "soldier": "mid"}
HABIT_TRADES = {"monk", "lay_brother", "nun", "lay_sister", "canon", "chaplain"}
LONG_SHARE = {"rich": 1.0, "mid": 0.45, "poor": 0.15}


def clothing(person, stage):
    """(outfit, main dye, under dye) for a resident, deterministic from the id."""
    key = person["id"]
    wealth = WEALTH.get(person["status"], "poor")
    pick = hash01(key + ":dye")
    if person["trade"] in HABIT_TRADES:
        main = HABIT[int(pick * len(HABIT))]
        wealth = "mid"
    else:
        table = DYES[wealth]
        main = table[int(pick * len(table))]
    under = UNDER[int(hash01(key + ":under") * len(UNDER))]
    long_cut = stage == "adult" and (
        person["trade"] in HABIT_TRADES or hash01(key + ":cut") < LONG_SHARE[wealth])
    return ("b" if long_cut else "a"), list(main), list(under)


def body_for(person):
    sex = person["sex"]
    age = person["age"]
    stage = "child" if age < 13 else "elder" if age >= 58 else "adult"
    build = BUILD_CLASS.get(person["appearance"]["build"], "average")
    if stage == "child":
        build = "average"
    elif stage == "elder":
        build = "thin" if build in ("thin", "average") else "heavy"
    outfit, main, under = clothing(person, stage)
    return citizen_bodies.body_id(sex, stage, build, outfit), stage, main, under


def build():
    census = json.loads(CENSUS.read_text())
    plan = json.loads(PLAN.read_text())
    cards = read_cards()

    graph = Graph([s["points"] for s in plan["streets"]])
    places: list[list] = []
    place_index: dict[str, int] = {}

    def place(key, x, z, angle=None):
        if key in place_index:
            return place_index[key]
        node, _ = graph.snap((x, z))
        places.append([round(x, 2), round(z, 2), -1 if node is None else node,
                       None if angle is None else round(angle, 3)])
        place_index[key] = len(places) - 1
        return place_index[key]

    pois = {p["id"]: p for p in plan["points_of_interest"]}
    wells = [p for p in pois.values() if p["kind"] == "well"]
    posts = [p for p in pois.values() if p["kind"] in ("guard_post", "barracks")]
    churches = []
    for b in plan["buildings"]:
        if b.get("kind") in ("church", "chapel") and b.get("door"):
            churches.append(b)

    def poi_place(pid, spread_key=None):
        p = pois[pid]
        x, z = p["at"]
        if spread_key is not None:
            slot = int(hash01(spread_key) * SPREAD_SLOTS)
            a = (slot + 0.37) / SPREAD_SLOTS * math.tau
            r = 3.0 + (slot * 7 % SPREAD_SLOTS) / SPREAD_SLOTS * 6.0
            return place(f"{pid}:{slot}", x + math.cos(a) * r, z + math.sin(a) * r)
        return place(pid, x, z)

    gutter_points = [tuple(pt) for g in plan["gutters"] for pt in g["points"]]

    def nearest_gutter(x, z):
        gx, gz = min(gutter_points, key=lambda q: math.hypot(q[0] - x, q[1] - z))
        return (round(gx, 1), round(gz, 1))

    def church_place(church, key):
        """A standing spot in front of a church door (6 spots per church)."""
        cx, cz, ca = church["door"]
        slot = int(hash01(key + ":s") * 6)
        side = (slot - 2.5) * 0.9
        out = (math.cos(ca), math.sin(ca))
        return place(f"church:{church['id']}:{slot}", cx + out[0] * 3.5 - out[1] * side,
                     cz + out[1] * 3.5 + out[0] * side)

    def nearest(items, x, z, pos=lambda i: i["at"]):
        return min(items, key=lambda i: math.hypot(pos(i)[0] - x, pos(i)[1] - z))

    # Households: door places (institutions take their building's door).
    building_door = {b["id"]: b["door"] for b in plan["buildings"] if b.get("door")}
    hh_by_id = {h["id"]: h for h in census["households"]}
    hh_door: dict[str, int] = {}
    for h in census["households"]:
        if not h["members"]:
            continue
        x, z, ang = h["door"] or building_door.get(h["building"]) or [h["xy"][0], h["xy"][1], 0.0]
        out = (math.cos(ang), math.sin(ang))
        hh_door[h["id"]] = place("door:" + h["id"], x + out[0] * DOOR_STAND, z + out[1] * DOOR_STAND, ang)

    # Head of household trade (apprentices and journeymen work where the master does).
    head_trade = {}
    for p in census["persons"]:
        if p["household_role"] == "head":
            head_trade[p["household"]] = p["trade"]

    residents = []
    for p in census["persons"]:
        if p["age"] < MIN_AGE or p["household"] not in hh_door:
            continue
        hh = hh_by_id[p["household"]]
        door = places[hh_door[p["household"]]]
        trade = p["trade"]
        pattern = PATTERN_OF.get(trade, "domestic")
        work_kind = WORK_OF.get(trade, "door")
        if p["age"] < CHILD_PLAY_AGE:
            pattern, work_kind = "home", "none"
        elif p["age"] < 15 and trade == "child":
            pattern, work_kind = "child", "none"
            wealth = WEALTH.get(p["status"], "poor")
            if p["age"] >= 7 and (wealth == "rich" or (wealth == "mid" and p["sex"] == "m")):
                pattern = "school"
        if trade == "apprentice" and head_trade.get(p["household"]) in PATTERN_OF:
            pattern = PATTERN_OF[head_trade[p["household"]]]
            work_kind = WORK_OF[head_trade[p["household"]]]
        key = p["id"]
        x, z = door[0], door[1]
        work = hh_door[p["household"]]
        if work_kind == "forum":
            work = poi_place("poi.forum", key)
        elif work_kind == "landing":
            work = poi_place("poi.fish_landing", key)
        elif work_kind == "granary":
            work = poi_place("poi.granary.pikk" if hash01(key + ":g") < 0.5 else "poi.fish_landing", key)
        elif work_kind == "mill":
            work = poi_place("poi.mill.karja", key)
        elif work_kind == "hall":
            work = poi_place("poi.watch.town_hall", key)
        elif work_kind == "castle":
            work = poi_place("poi.barracks.castle", key)
        elif work_kind in ("post", "gate"):
            post = nearest(posts, x, z)
            work = poi_place(post["id"], key)
        elif work_kind == "well":
            w = nearest(wells, x, z)
            work = poi_place(w["id"], key)
        elif work_kind == "church" and churches:
            c = nearest(churches, x, z, lambda b: b["door"])
            cx, cz, ca = c["door"]
            work = church_place(c, key)
        # Errands: market for traders, otherwise the nearest well; evenings at the nearest church or the forum.
        wnear = nearest(wells, x, z)
        errand_kind = "market" if hash01(key + ":m") < 0.4 else "well"
        errand = poi_place("poi.forum", key + ":e") if errand_kind == "market" else poi_place(wnear["id"], key + ":e")
        if churches and hash01(key + ":c") < 0.45:
            c = nearest(churches, x, z, lambda b: b["door"])
            cx, cz, ca = c["door"]
            errand2 = church_place(c, key)
            errand2_kind = "church"
        else:
            errand2_kind = "market" if hash01(key + ":n") < 0.5 else "well"
            errand2 = (poi_place("poi.forum", key + ":e2") if errand2_kind == "market"
                       else poi_place(wnear["id"], key + ":e2"))

        gate = nearest(plan["gates"], x, z)
        gx, gz = gate["at"]
        ga = math.atan2(z - gz, x - gx)
        fuel = place(f"fuel:{gate['id']}:{int(hash01(key + ':f') * 6)}",
                     gx + math.cos(ga) * (12.0 + int(hash01(key + ':f') * 6) * 1.6),
                     gz + math.sin(ga) * (12.0 + int(hash01(key + ':f') * 6) * 1.6))
        water = poi_place(wnear["id"], key + ":wa")
        latrine = place("latrine:" + ":".join(map(str, nearest_gutter(x, z))), *nearest_gutter(x, z))
        food_roll = hash01(key + ":food")
        food_kind = "market" if food_roll < 0.55 else "bakery" if food_roll < 0.85 else "butcher"
        food = poi_place({"market": "poi.forum", "bakery": "poi.bakery.lai",
                          "butcher": "poi.slaughter.karja"}[food_kind], key + ":fo")
        supply_kind = SUPPLY_OF.get(trade, "market")
        supply = poi_place(SUPPLY_POI[supply_kind], key + ":su")
        school = (church_place(nearest(churches, x, z, lambda b: b["door"]), key)
                  if pattern == "school" and churches else hh_door[p["household"]])
        church_spot = (church_place(nearest(churches, x, z, lambda b: b["door"]), key)
                       if churches else hh_door[p["household"]])
        stroll_poi = STROLLS[int(hash01(key + ":stroll") * len(STROLLS))]
        stroll = poi_place(stroll_poi, key + ":st")
        body, stage, cloth, under = body_for(p)
        ap = p["appearance"]
        head = 1.0 + HEAD_BUILD.get(ap["build"], 0.0) + (hash01(key + ":h") - 0.5) * 0.10
        if p["age"] < 10:
            head += 0.10
        card = cards.get(key)
        rec = {
            "id": key,
            "name": p["name"],
            "sex": p["sex"],
            "age": p["age"],
            "ethnicity": p["ethnicity"],
            "trade": trade,
            "status": p["status"],
            "faction": p["faction"],
            "faction_role": p["faction_role"],
            "household": p["household"],
            "household_role": p["household_role"],
            "street": hh["street"],
            "literacy": p["literacy"],
            "languages": p["languages"],
            "appearance": {
                "height_cm": ap["height_cm"], "build": ap["build"], "hair": ap["hair"],
                "eyes": ap["eyes"], "complexion": ap["complexion"], "facial_hair": ap["facial_hair"],
                "marks": ap["marks"], "voice": ap["voice"],
            },
            "body": body,
            "cloth": cloth,
            "under": under,
            "height_scale": round(max(0.55, min(1.3, ap["height_cm"] / 100.0 /
                                                 citizen_bodies.reference_height_m(p["sex"], stage))), 3),
            "head_scale": round(max(0.88, min(1.2, head)), 3),
            "pattern": pattern,
            "jitter": round((hash01(key + ":j") - 0.5) * 1.2, 2),
            "walk": round(1.0 + hash01(key + ":w") * 0.45 - (0.15 if p["age"] > 60 else 0.0), 2),
            "home": hh_door[p["household"]],
            "work": work,
            "errand": errand,
            "errand2": errand2,
            "work_kind": work_kind,
            "water": water,
            "food": food,
            "food_kind": food_kind,
            "fuel": fuel,
            "latrine": latrine,
            "supply": supply,
            "supply_kind": supply_kind,
            "school": school,
            "church": church_spot,
            "stroll": stroll,
            "devout": trade in CLERGY or hash01(key + ":devout") < 0.75,
            "strolls": hash01(key + ":walks") < 0.6,
            "errand_kind": errand_kind,
            "errand2_kind": errand2_kind,
            "card": card[1] if card else "",
            "blurb": card[2] if card else "",
        }
        residents.append(rec)

    return {
        "schema": SCHEMA,
        "source": "docs/data/city_census.json + content/world/reval_city/plan.json",
        "patterns": PATTERNS,
        "graph": {"nodes": [[x, z] for x, z in graph.nodes],
                  "edges": [list(e) for e in sorted(graph.edges)]},
        "places": places,
        "residents": residents,
    }


def dump(data) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"), sort_keys=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = dump(build())
    if args.check:
        if not OUT.is_file() or OUT.read_text() != text:
            print(f"{OUT.relative_to(ROOT)} is stale; run tools/city/build_citizen_runtime.py")
            return 1
        print("citizens.json up to date")
        return 0
    OUT.write_text(text)
    data = json.loads(text)
    print(f"wrote {OUT.relative_to(ROOT)}: {len(data['residents'])} residents, "
          f"{len(data['places'])} places, {len(data['graph']['nodes'])} nodes, {len(text) // 1024} KiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
