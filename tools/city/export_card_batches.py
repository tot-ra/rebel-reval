#!/usr/bin/env python3
"""Export writer batches for citizen cards (one JSON per batch, whole households together).

  python3 tools/city/export_card_batches.py --out DIR [--size 24]

Each batch lists, per card to write: the census seed, the appearance seed, the household with
every member (carded or not), relative links, and every planned social edge with its agreed fact,
so two writers never contradict each other about the same relationship. See
docs/CITIZENS/WRITING_CARDS.md for the writer brief.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_city_census as bc  # noqa: E402

ROOT = bc.ROOT
PLAN = ROOT / "docs/data/citizen_cards_plan.json"


def trade_label(t):
    return bc.TRADES.get(t, t.replace("_", " "))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, default=24)
    args = ap.parse_args(argv)
    census = json.loads(bc.OUT_JSON.read_text(encoding="utf-8"))
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    P = {p["id"]: p for p in census["persons"]}
    H = {h["id"]: h for h in census["households"]}
    cards = set(plan["cards"])
    card_link = {}
    for pid in cards:
        h = H[P[pid]["household"]]
        card_link[pid] = bc.card_rel(P[pid], h["district"])
    edges_by = defaultdict(list)
    for e in plan["edges"]:
        edges_by[e["a"]].append(e)
        edges_by[e["b"]].append(e)

    # whole households together, neighbours adjacent
    hh_ids = sorted({P[pid]["household"] for pid in cards}, key=lambda hid: (H[hid]["district"], H[hid]["street"], H[hid]["xy"], hid))
    batches, cur, n = [], [], 0
    for hid in hh_ids:
        k = sum(1 for m in H[hid]["members"] if m in cards)
        if cur and n + k > args.size:
            batches.append(cur)
            cur, n = [], 0
        cur.append(hid)
        n += k
    if cur:
        batches.append(cur)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for bi, hhs in enumerate(batches, 1):
        recs = []
        for hid in hhs:
            h = H[hid]
            members = []
            for m in h["members"]:
                q = P[m]
                members.append({"id": m, "name": q["name"], "age": q["age"], "sex": q["sex"], "household_role": q["household_role"],
                                "trade": trade_label(q["trade"]), "carded": m in cards,
                                "card": ("../../" + card_link[m]) if m in cards else None})
            near = []
            for oid, o in H.items():
                if oid == hid or o["kind"] == "institution" or o["district"] != h["district"] or not o["members"]:
                    continue
                d = math.hypot(o["xy"][0] - h["xy"][0], o["xy"][1] - h["xy"][1])
                if d < 90:
                    head = next((P[m] for m in o["members"] if P[m]["household_role"] == "head"), P[o["members"][0]])
                    near.append((d, oid, head))
            near.sort(key=lambda t: (t[0], t[1]))
            neighbours = [{"household": oid, "head": hd["name"], "head_age": hd["age"], "trade": trade_label(hd["trade"]), "street": H[oid]["street"],
                           "size": len(H[oid]["members"]), "ledger": f"../../{bc.ledger_rel(H[oid])}#{bc.hh_anchor(oid)}",
                           "head_card": ("../../" + card_link[hd["id"]]) if hd["id"] in cards else None, "metres": round(d)}
                          for d, oid, hd in near[:6]]
            for m in h["members"]:
                if m not in cards:
                    continue
                q = P[m]
                es = []
                for e in edges_by[m]:
                    other = e["b"] if e["a"] == m else e["a"]
                    o = P[other]
                    es.append({"other_id": other, "other_name": o["name"], "other_age": o["age"], "other_trade": trade_label(o["trade"]),
                               "other_street": H[o["household"]]["street"], "other_card": "../../" + card_link[other],
                               "kind": e["kind"], "agreed_fact": e["fact"]})
                office = q.get("office")
                recs.append({
                    "id": m, "name": q["name"], "slug": q["slug"], "write_to": f"docs/CITIZENS/{card_link[m]}",
                    "attested_name": bool(q.get("attested_name")),
                    "census": {"age": q["age"], "sex": q["sex"], "ethnicity": q["ethnicity"], "segment": q["segment"], "status": q["status"],
                               "trade_key": q["trade"], "trade_label": trade_label(q["trade"]), "household_role": q["household_role"],
                               "faction": q["faction"], "faction_label": bc.FACTION_LABELS[q["faction"]], "faction_role": q["faction_role"],
                               "office": office, "literacy": q["literacy"], "languages": q["languages"], "widow": q["widow"]},
                    "appearance_seed": q["appearance"],
                    "household": {"id": hid, "name": h.get("name"), "ledger": f"../../{bc.ledger_rel(h)}#{bc.hh_anchor(hid)}", "street": h["street"],
                                  "district": bc.DISTRICT_NAME[h["district"]], "zone": h["zone"], "class": h["class"], "plot_m2": h["area_m2"],
                                  "building": h["building"], "members": members},
                    "edges": es,
                    "nearby_households": neighbours,
                })
        (out / f"batch_{bi:02d}.json").write_text(json.dumps({"batch": bi, "cards": recs}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(batches)} batches, {len(cards)} cards -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
