#!/usr/bin/env python3
"""Choose which residents get a deep card and wire a symmetric social network between them.

Input : docs/data/city_census.json (tools/city/build_city_census.py)
Output: docs/data/citizen_cards_plan.json  { "cards": [person ids], "edges": [ {a, b, kind, hint} ] }

Selection is stratified: every office holder, every economically necessary trade, every faction
(quota per faction), every street with at least four households, plus a dense "focus street"
sample so that neighbours really are neighbours. Households chosen are carded whole (children
under five stay in the ledger only); institutions contribute a few representatives.

  python3 tools/city/plan_citizen_cards.py           # rewrite plan
  python3 tools/city/plan_citizen_cards.py --check   # fail if stale
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENSUS = ROOT / "docs/data/city_census.json"
OUT = ROOT / "docs/data/citizen_cards_plan.json"

FOCUS_STREETS = ["Pikk", "Lai", "Vene", "Müürivahe", "Harju road", "Viru road", "Sauna", "Suur-Karja", "Vana turg", "Western coast road"]
FOCUS_SHARE = 0.10
HOUSEHOLD_CAP = 6
FACTION_QUOTA = {"harju_kings": 14, "vitalienbruder": 6, "blackheads": 8, "pskov_novgorod": 12, "cult_metsik": 14, "livonian_order": 10,
                 "black_cloaks": 22, "danish_crown": 26, "hanseatic": 40, "church": 20}
MUST_TRADES = (
    "merchant retailer moneylender baker brewer alewife innkeeper butcher fishmonger miller cook smith goldsmith armourer nailsmith cooper "
    "carpenter mason tiler wheelwright joiner glazier weaver dyer tailor furrier shoemaker tanner saddler glover hatter fisher net_maker "
    "boatman shipwright ropemaker sailmaker carter porter drover sailor skipper pilot barber midwife bathkeeper apothecary chandler tallow "
    "potter gardener musician pedlar labourer farmer healer washerwoman dairy scribe clerk weigher stable_hand knight crown_clerk "
    "town_herdsman executioner gatekeeper canon monk nun priest hospital_inmate novgorod_merchant man_at_arms sexton gravedigger "
    "spinner retired widow apprentice journeyman maid servant"
).split()
TARGET_CARDS = 600
FORCE_CARDS: tuple[str, ...] = ()  # census ids that must have a card (promotions after the first wave)
COMPLEMENT = {  # trade -> trades it naturally deals with
    "baker": ["miller", "butcher", "brewer"], "brewer": ["cooper", "miller", "innkeeper", "alewife"], "innkeeper": ["brewer", "butcher", "fishmonger", "porter"],
    "smith": ["carpenter", "wheelwright", "armourer", "carter", "cooper"], "cooper": ["brewer", "merchant", "fishmonger", "saltmonger"],
    "merchant": ["porter", "clerk", "skipper", "carter", "cooper", "moneylender"], "fisher": ["fishmonger", "net_maker", "boatman"],
    "tanner": ["shoemaker", "saddler", "glover", "butcher"], "weaver": ["dyer", "tailor", "merchant"], "tailor": ["weaver", "furrier"],
    "carpenter": ["mason", "tiler", "joiner", "shipwright"], "mason": ["limeburner", "carpenter", "labourer"], "carter": ["porter", "drover", "merchant"],
    "porter": ["merchant", "carter", "sailor", "innkeeper"], "ropemaker": ["shipwright", "sailmaker", "skipper"], "shipwright": ["carpenter", "ropemaker", "sailmaker"],
    "midwife": ["healer", "barber", "priest"], "barber": ["healer", "midwife", "bathkeeper"], "scribe": ["merchant", "clerk", "priest"],
    "goldsmith": ["merchant", "armourer", "moneylender"], "armourer": ["smith", "goldsmith", "man_at_arms"],
}


def seed(*parts):
    return random.Random(int(hashlib.sha256("|".join(map(str, parts)).encode()).hexdigest()[:16], 16))


def plan():
    d = json.loads(CENSUS.read_text(encoding="utf-8"))
    P = {p["id"]: p for p in d["persons"]}
    H = {h["id"]: h for h in d["households"]}
    chosen_hh = []
    chosen_p = set()
    forced = {pid for pid, p in P.items() if p.get("office")}

    def card_household(hid):
        if hid in chosen_hh or H[hid]["kind"] == "institution":
            return False
        chosen_hh.append(hid)
        order = {"head": 0, "spouse": 1, "elder": 2, "journeyman": 3, "clerk": 3, "apprentice": 4, "maid": 5, "servant": 5, "lodger": 6, "child": 7}
        mem = sorted((P[m] for m in H[hid]["members"] if P[m]["age"] >= 5), key=lambda q: (order.get(q["household_role"], 8), -q["age"], q["id"]))
        kids = 0
        taken = 0
        for q in mem:
            if q["age"] < 14:
                if kids >= 2:
                    continue
                kids += 1
            if taken >= HOUSEHOLD_CAP and q["id"] not in forced:
                continue
            chosen_p.add(q["id"])
            taken += 1
        return True

    def card_person(pid):
        chosen_p.add(pid)

    for pid in FORCE_CARDS:
        card_person(pid)
    # 1. office holders
    for pid, p in sorted(P.items()):
        if p.get("office"):
            if H[p["household"]]["kind"] == "institution":
                card_person(pid)
            else:
                card_household(p["household"])
    # 2. institution representatives (oldest = senior)
    for h in d["households"]:
        if h["kind"] != "institution":
            continue
        mem = [P[m] for m in h["members"]]
        by = defaultdict(list)
        for p in mem:
            by[p["trade"]].append(p)
        for trade, lst in sorted(by.items()):
            lst.sort(key=lambda p: (-p["age"], p["id"]))
            take = {"monk": 3, "nun": 3, "lay_brother": 1, "lay_sister": 1, "canon": 2, "vicar": 1, "priest": 1, "chaplain": 1, "sexton": 1, "hospital_inmate": 3,
                    "man_at_arms": 4, "squire": 1, "crown_clerk": 1, "chamberlain": 1, "knight": 1, "castle_cook": 1, "castle_servant": 2, "falconer": 1,
                    "sailor": 6, "skipper": 3, "pilgrim": 2, "pedlar": 2, "novgorod_merchant": 3, "novgorod_clerk": 1, "stadtschreiber": 1, "ratsdiener": 2,
                    "watch_sergeant": 1, "scribe": 1, "weigher": 1, "gravedigger": 1, "stable_hand": 1, "gardener": 1}.get(trade, 0)
            for p in lst[:take]:
                card_person(p["id"])
    # 3. street coverage and focus streets
    street_hh = defaultdict(list)
    for h in d["households"]:
        if h["kind"] == "house" and h["members"]:
            street_hh[(h["district"], h["street"])].append(h["id"])
    for (dist, street), lst in sorted(street_hh.items()):
        lst.sort()
        r = seed("street", dist, street)
        if street in FOCUS_STREETS and dist == "lt" or street in FOCUS_STREETS and street.endswith("road"):
            k = max(2, round(len(lst) * FOCUS_SHARE))
        elif len(lst) >= 5:
            k = 1
        else:
            k = 0
        for hid in r.sample(lst, min(k, len(lst))):
            card_household(hid)
    # 4. trade coverage
    trade_hh = defaultdict(list)
    for pid, p in P.items():
        h = H[p["household"]]
        if h["kind"] == "house":
            trade_hh[p["trade"]].append(pid)
    for trade in MUST_TRADES:
        have = any(P[pid]["trade"] == trade for pid in chosen_p)
        if have:
            continue
        cands = sorted(trade_hh.get(trade, []))
        if not cands:
            continue
        # prefer small households of an unrepresented street
        r = seed("trade", trade)
        r.shuffle(cands)
        cands.sort(key=lambda pid: (len(H[P[pid]["household"]]["members"]) + (3 if (H[P[pid]["household"]]["district"], H[P[pid]["household"]]["street"]) in {(H[x]["district"], H[x]["street"]) for x in chosen_hh} else 0)))
        card_household(P[cands[0]]["household"])
    # 5. faction quotas (add persons via their households, smallest first)
    for fac, quota in FACTION_QUOTA.items():
        have = sum(1 for pid in chosen_p if P[pid]["faction"] == fac)
        pool = sorted(pid for pid, p in P.items() if p["faction"] == fac and pid not in chosen_p and H[p["household"]]["kind"] == "house" and p["age"] >= 14)
        seed("faction", fac).shuffle(pool)
        pool.sort(key=lambda pid: len(H[P[pid]["household"]]["members"]))
        for pid in pool:
            if have >= quota:
                break
            if card_household(P[pid]["household"]):
                have = sum(1 for q in chosen_p if P[q]["faction"] == fac)
    # institution members in a faction count already via church; fill the remainder randomly
    rest = sorted(h["id"] for h in d["households"] if h["kind"] == "house" and h["members"] and h["id"] not in chosen_hh)
    seed("fill").shuffle(rest)
    for hid in rest:
        if len(chosen_p) >= TARGET_CARDS:
            break
        card_household(hid)
    return d, P, H, sorted(chosen_p), chosen_hh


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def edges(d, P, H, cards):
    cardset = set(cards)
    deg = Counter()
    seen = set()
    out = []

    pair_count = Counter()

    def add(a, b, kind, hint):
        if a == b or P[a]["household"] == P[b]["household"]:
            return False
        key = tuple(sorted((a, b)))
        hpair = tuple(sorted((P[a]["household"], P[b]["household"])))
        if key in seen or deg[a] >= 7 or deg[b] >= 7 or pair_count[hpair] >= (1 if kind == "neighbour" else 2):
            return False
        pair_count[hpair] += 1
        seen.add(key)
        deg[a] += 1
        deg[b] += 1
        out.append({"a": key[0], "b": key[1], "kind": kind, "hint": hint})
        return True

    adults = [pid for pid in cards if P[pid]["age"] >= 14]
    by_street = defaultdict(list)
    by_trade = defaultdict(list)
    by_fac = defaultdict(list)
    for pid in adults:
        h = H[P[pid]["household"]]
        by_street[(h["district"], h["street"])].append(pid)
        by_trade[P[pid]["trade"]].append(pid)
        if P[pid]["faction"] != "none":
            by_fac[P[pid]["faction"]].append(pid)
    for pid in adults:
        r = seed("edge", pid)
        h = H[P[pid]["household"]]
        # neighbours
        near = [q for q in adults if P[q]["household"] != P[pid]["household"] and H[P[q]["household"]]["district"] == h["district"]
                and dist(h["xy"], H[P[q]["household"]]["xy"]) < 75]
        near.sort(key=lambda q: (dist(h["xy"], H[P[q]["household"]]["xy"]), q))
        for q in near[:2]:
            add(pid, q, "neighbour", "share a lane, a well, or a party wall")
        # trade partner / fellow
        tr = P[pid]["trade"]
        same = [q for q in by_trade.get(tr, []) if q != pid]
        r.shuffle(same)
        same.sort(key=lambda q: dist(h["xy"], H[P[q]["household"]]["xy"]))
        if same and tr not in ("labourer", "spinner", "servant", "maid", "retired", "widow", "child"):
            add(pid, same[0], "trade_fellow", "same trade: rivalry, shared tools, or guild brotherhood")
        for comp in COMPLEMENT.get(tr, []):
            cs = [q for q in by_trade.get(comp, []) if q != pid]
            if cs:
                cs.sort(key=lambda q: dist(h["xy"], H[P[q]["household"]]["xy"]))
                if add(pid, cs[0], "trade_partner", f"{tr} and {comp} depend on each other (supply, credit, or favours)"):
                    break
        # faction cell
        f = P[pid]["faction"]
        if f != "none" and f != "church":
            cell = [q for q in by_fac[f] if q != pid]
            r.shuffle(cell)
            for q in cell[:2]:
                add(pid, q, "faction_cell", f"both lean {f}: they know it about each other, or one suspects")
        # credit / patronage across classes
        if P[pid]["status"] in ("patrician", "burgher_merchant") and P[pid]["household_role"] == "head":
            poor = [q for q in adults if P[q]["status"] in ("master_craftsman", "free_commoner", "labourer") and P[q]["household_role"] == "head" and dist(h["xy"], H[P[q]["household"]]["xy"]) < 220]
            r.shuffle(poor)
            for q in poor[:2]:
                add(pid, q, "creditor_debtor", "one lent the other money, grain, or a bond; the debt colours every greeting")
        # parish
        if P[pid]["trade"] in ("priest", "chaplain"):
            flock = [q for q in adults if P[q]["trade"] not in ("priest", "chaplain") and dist(h["xy"], H[P[q]["household"]]["xy"]) < 250]
            r.shuffle(flock)
            for q in flock[:3]:
                add(pid, q, "confessor", "confessor and penitent; what is said under the seal vs what is guessed")
    # make sure every adult has at least two external links
    for pid in adults:
        r = seed("edge2", pid)
        guard = 0
        hp = H[P[pid]["household"]]
        close = sorted((q for q in adults if q != pid and P[q]["household"] != P[pid]["household"] and H[P[q]["household"]]["district"] == hp["district"]),
                       key=lambda q: (dist(hp["xy"], H[P[q]["household"]]["xy"]), q))[:14]
        while deg[pid] < 2 and guard < 30 and close:
            guard += 1
            q = r.choice(close)
            add(pid, q, "acquaintance", "know each other from the market, the church door, or a shared hardship")
    out.sort(key=lambda e: (e["a"], e["b"]))
    return out


FACTS = {
    "neighbour": [
        "{A} and {B} share a party wall; {A}'s chimney smokes into {B}'s loft, a grievance two winters old that neither has taken to the Vogt.",
        "{A} and {B} draw from one back-yard well on an unwritten rota that both resent and both keep.",
        "Their children play together in the lane despite the parents' coolness; {A} lets it pass, {B} pretends not to see.",
        "{A} keeps an eye on {B}'s house when {B} is away on business, and is repaid in fish, bread, or small repairs.",
        "A boundary stake between their yards was moved by {A}'s late father; {B}'s household has noticed and says nothing yet.",
        "{B} sleeps badly and has twice seen {A} leave by the back lane after curfew; {B} has told no one.",
        "They sit near each other at church and trade gossip at the door after mass; each treats the other as an early-warning system.",
        "{A}'s hens keep getting into {B}'s yard; it is always settled with a jug of beer, and always happens again.",
        "{A} once helped carry {B}'s sick child to the herb-wife in the night; neither mentions it, both remember.",
        "{B} rents a shed from {A} for tools and firewood at a rate neither considers fair to themselves.",
    ],
    "trade_fellow": [
        "{A} and {B} compete for the same customers; each privately counts the other's apprentices and lamp-oil.",
        "{A} and {B} belong to the same Amt fraternity and stand together at the feast masses, though they dislike each other's methods.",
        "{A} trained under the master who later trained {B}; {B} owes {A} an old, unspoken courtesy.",
        "{A} and {B} share one rare tool, lent back and forth, and each keeps a mental ledger of how long the other has held it.",
        "They once split a bulk delivery of raw material to beat the price; the arrangement quietly lapsed after a quarrel over weights.",
        "{B} is the better craftsman and {A} the better businessperson; each believes the other has the easier life.",
        "{A} suspects {B} of undercutting the going price using stolen or smuggled stock; no proof, so far.",
    ],
    "trade_partner": [
        "{A} regularly supplies {B}, usually on credit settled at quarter-days; the arrangement is the backbone of both households' week.",
        "{B} regularly supplies {A} and has twice held back stock to press an old point; {A} has not forgotten.",
        "They split the cost of a cart-hire and a day's labour at the harbour each week, and quarrel about it every week.",
        "{A} recommended {B} to a third party and has since heard complaints that rebound on their own name.",
        "They trade favours in kind: {A} supplies what {B} lacks, and {B} returns work {A} cannot do; the books are never even.",
    ],
    "faction_cell": [
        "{A} knows {B} shares their sympathies; they meet briefly after mass and say nothing that could be repeated.",
        "{A} suspects but cannot prove that {B} leans the same way; each watches the other for a sign.",
        "Neither knows the other's allegiance, but each has noticed the other's silence at the right moments.",
        "{A} recruited {B} a year ago with a small kindness; {B} resents being treated as a debtor.",
        "{B} is {A}'s superior in the circle, though neither would put it that way; they never speak in the same room as others.",
        "They were at the same funeral and the same whisper, and know it; a cell of two, with a third unnamed.",
    ],
    "creditor_debtor": [
        "{A} lent {B} {sum} marks in the autumn of 1342 for a new roof; the bond falls due at Michaelmas and {B} has paid about half.",
        "{A} advanced {B} {sum} marks' worth of grain on credit after a failed harvest; interest is unspoken and heavy.",
        "{B} owes {A} {sum} marks for a share in a boat voyage that went badly; {A} has been patient so far.",
        "{A} stood surety for {B}'s fine of {sum} marks last year; {B} has not repaid, and {A} has started to notice who notices.",
        "{B} borrowed {sum} marks from {A} to pay a dowry; the marriage went ahead and the debt remains.",
        "{A} holds {B}'s tools as pledge for {sum} marks; {B} pays what they can, in labour, every week.",
    ],
    "confessor": [
        "{A} hears {B}'s confession; {B} confessed something at Lent and has avoided {A}'s eye since.",
        "{A} baptised {B}'s child and officiated at a funeral for {B}'s kin; the bond is warm but formal.",
        "{B} comes to {A} for advice more often than the sacrament requires; {A} suspects {B} is lonely or afraid.",
        "{A} once refused {B} absolution until a restitution was made; {B} made it, and has respected and resented {A} ever since.",
    ],
    "acquaintance": [
        "{A} and {B} know each other from the market; they greet by name and trade the day's prices.",
        "{A} and {B} met at the church door the week of Easter and fell into the habit of walking home together.",
        "{A} and {B} survived the same bad winter in the same lane; hardship is a quiet bond.",
        "{A} once did {B} a small favour at the gate; the memory is slightly different on each side.",
        "{A} and {B} share a distant kinship through marriage that neither can trace exactly.",
        "{B} sells {A} small things at a fair price, and {A} tells others to buy from {B}.",
    ],
}


def add_facts(d, P, ed):
    names = {p["id"]: p["name"] for p in d["persons"]}
    for e in ed:
        r = seed("fact", e["a"], e["b"], e["kind"])
        tmpl = r.choice(FACTS[e["kind"]])
        a, b = (e["a"], e["b"]) if r.random() < 0.5 else (e["b"], e["a"])
        e["fact"] = tmpl.format(A=names[a], B=names[b], sum=r.choice([3, 4, 5, 6, 8, 9, 12, 15, 18, 24, 30, 45]))
    return ed


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--stats", action="store_true")
    args = ap.parse_args(argv)
    d, P, H, cards, hh = plan()
    ed = add_facts(d, P, edges(d, P, H, cards))
    obj = {"schema": "rr.citizen_cards_plan.v1", "cards": cards, "households_carded": sorted(hh), "edges": ed}
    text = json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"
    if args.stats:
        print(len(cards), "cards;", len(hh), "households;", len(ed), "edges")
        print(Counter(P[c]["faction"] for c in cards))
        print(Counter(H[P[c]["household"]]["street"] for c in cards).most_common(14))
        print(Counter(P[c]["trade"] for c in cards).most_common(30))
        print("age", Counter(min(P[c]["age"] // 15, 5) for c in cards))
        return 0
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("citizen card plan is stale: run python3 tools/city/plan_citizen_cards.py", file=sys.stderr)
            return 1
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(cards)} cards, {len(ed)} edges")
    return 0


if __name__ == "__main__":
    sys.exit(main())
