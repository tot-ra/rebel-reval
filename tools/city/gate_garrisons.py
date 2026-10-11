"""Who stands at which Reval gate (docs/SYSTEMS/GATE_GARRISONS.md).

Called from build_citizen_runtime.build(): it turns real census residents into the gate
watch, the town patrols and the Toompea wall patrol. Nobody is invented: gatekeepers,
watch sergeants and Danish men-at-arms come from the census trades of the same name, the
rest of the town watch is a burgher levy drawn from the households nearest each gate.

Deterministic: every pick is ordered by a stable hash of the resident id.
"""

from __future__ import annotations

import itertools
import math

# gate id -> staffing. `watch` is burghers per shift (levy), `crown` Danish men-at-arms per
# shift, `keepers` census gatekeepers who hold the gate by day.
GATES = {
    "gate.coastal": {"label": "Coastal Gate", "keepers": 1, "watch": 2, "crown": 0, "reason": "harbour traffic, the busiest gate"},
    "gate.sand": {"label": "Sand Gate", "keepers": 1, "watch": 1, "crown": 0, "reason": "small beach gate"},
    "gate.viru": {"label": "Viru Gate and barbican", "keepers": 2, "watch": 3, "crown": 0, "reason": "main land road, inner gate and foregate"},
    "gate.karja": {"label": "Cattle Gate", "keepers": 1, "watch": 2, "crown": 0, "reason": "herds and carts"},
    "gate.harju": {"label": "Smiths' Gate", "keepers": 1, "watch": 2, "crown": 0, "reason": "road south to Harju"},
    "gate.nuns": {"label": "Nuns' Gate", "keepers": 1, "watch": 1, "crown": 0, "reason": "quiet convent gate"},
    "gate.long_hill": {"label": "Long Hill Gate", "keepers": 1, "watch": 0, "crown": 3, "reason": "council gatekeeper with a Danish guard to the castle"},
    "gate.short_hill": {"label": "Short Hill Gate", "keepers": 0, "watch": 0, "crown": 3, "reason": "Danish castle watch only"},
}
# Town patrols: street name -> (burghers per shift, sergeant on the day shift, sergeant on the night shift)
PATROLS = {"Pikk": (1, True, True), "Lai": (1, False, False), "Vene": (1, False, False)}
WALL_PATROL_CROWN = 4  # Danish men-at-arms per shift on the Toompea wall walk

DAY_RANK, NIGHT_RANK = 8.5, 10.2  # metres inward of the passage; the two shifts never stand on one spot
LATERAL = [-2.8, 2.8, -4.6, 4.6, -6.4, 6.4]
KEEPER_SPOT = (7.0, 5.2)  # (inward, lateral): the toll table beside the passage
PATROL_SPEED = 0.9  # m/s, used by CitizenRoster
LEVY_MIN_AGE, LEVY_MAX_AGE = 22, 50
LEVY_STATUS = {"labourer", "journeyman", "master_craftsman", "free_commoner"}
# Traders, clerks, healers and the like do not stand at a gate with a spear.
LEVY_EXEMPT = {"innkeeper", "alewife", "healer", "midwife", "barber", "musician", "bathkeeper",
               "retailer", "merchant", "greengrocer", "pedlar", "saltmonger", "dairy",
               "novgorod_merchant", "moneylender", "falconer", "gardener", "gatekeeper", "child",
               "apprentice", "monk", "priest"}
LEVY_RADIUS = (140.0, 260.0, 520.0)
FORUM = (5.0, -10.0)
CASTLE = (-420.0, 150.0)
WALL_WALK_INSET = 3.0

PATTERN_NIGHT = [[5.5, "home"], [17.6, "work"]]


def _inward(gate):
    """Unit vector across the wall toward the town side: the forum for the town gates, the
    castle for the two hill gates (the Danes stand on their side, looking out at the town)."""
    a = gate["angle"]
    n = (-math.sin(a), math.cos(a))
    ref = CASTLE if gate["id"] in ("gate.long_hill", "gate.short_hill") else FORUM
    gx, gz = gate["at"]
    if (ref[0] - gx) * n[0] + (ref[1] - gz) * n[1] < 0:
        n = (-n[0], -n[1])
    return n


def _longest_street(plan, name):
    best = []
    for s in plan["streets"]:
        if s.get("name") == name and len(s["points"]) > len(best):
            best = s["points"]
    return [tuple(p) for p in best]


def _wall_walk(plan):
    """The Toompea wall as a walkable chain, set a little way inside the wall."""
    pts = [tuple(w["from"]) for w in plan["toompea_walls"]] + [tuple(plan["toompea_walls"][-1]["to"])]
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    out = []
    for x, z in pts:
        d = math.hypot(cx - x, cz - z) or 1.0
        out.append((round(x + (cx - x) / d * WALL_WALK_INSET, 2), round(z + (cz - z) / d * WALL_WALK_INSET, 2)))
    return out


def assign(plan, residents, hh_xy, place, hash01):
    """Mutates `residents` in place and returns (patrols, report).

    `hh_xy`: household id -> (x, z); `place(key, x, z, angle)` registers a standing place and
    returns its index. `patrols` is the list of walked routes ({"id", "points"}).
    """
    by_id = {r["id"]: r for r in residents}
    gates = {g["id"]: g for g in plan["gates"]}
    taken: set[str] = set()
    report: list[dict] = []
    patrols: list[dict] = []

    def hash_key(r, salt):
        return hash01(r["id"] + ":" + salt)

    def dist(r, xz):
        x, z = hh_xy[r["household"]]
        return math.hypot(x - xz[0], z - xz[1])

    def duty(r, post, role, shift, kit, label, **extra):
        r["duty"] = {"post": post, "role": role, "shift": shift, "kit": kit, "label": label, **extra}
        taken.add(r["id"])
        r["pattern"] = "watch_day" if shift == "day" else "watch_night"
        r["walk"] = min(r["walk"], 1.25)

    def census(trade, **filt):
        out = [r for r in residents if r["trade"] == trade and r["id"] not in taken]
        for k, v in filt.items():
            out = [r for r in out if r.get(k) == v]
        return out

    def gate_spot(g, inward, rank, lateral, key):
        n = _inward(g) if inward is None else inward
        gx, gz = g["at"]
        across = (-n[1], n[0])
        x = gx + n[0] * rank + across[0] * lateral
        z = gz + n[1] * rank + across[1] * lateral
        out = math.atan2(-n[1], -n[0])  # facing out of the town
        return place(key, x, z, out)

    # --- gatekeepers: the assignment with the shortest total walk to work ---------------------
    slots = [gid for gid, c in GATES.items() for _ in range(c["keepers"])]
    keepers = sorted(census("gatekeeper"), key=lambda r: r["id"])
    best = min(itertools.permutations(range(len(keepers)), len(slots)),
               key=lambda perm: sum(dist(keepers[k], gates[gid]["at"]) for k, gid in zip(perm, slots)))
    for k, gid in zip(best, slots):
        r = keepers[k]
        g = gates[gid]
        n = _inward(g)
        spot_in, spot_lat = KEEPER_SPOT
        nth = sum(1 for x in residents if x.get("duty", {}).get("post") == gid and x["duty"]["role"] == "gatekeeper")
        r["work"] = gate_spot(g, n, spot_in, spot_lat * (-1 if nth % 2 else 1), f"post:{gid}:keeper:{nth}")
        r["work_kind"] = "gate"
        duty(r, gid, "gatekeeper", "day", "keeper", GATES[gid]["label"], exact=True)

    # --- gate watch: burgher levy and Danish men-at-arms ------------------------------------
    def levy_pool(xz):
        for radius in LEVY_RADIUS:
            pool = [r for r in residents
                    if r["id"] not in taken and r["sex"] == "m"
                    and LEVY_MIN_AGE <= r["age"] <= LEVY_MAX_AGE
                    and r["status"] in LEVY_STATUS and r["household"].startswith("hh.lt.")
                    and r["trade"] not in LEVY_EXEMPT
                    and r["faction"] != "danish_crown" and r["pattern"] in ("craft", "market")
                    and dist(r, xz) <= radius]
            if len(pool) >= 12:
                return pool
        return pool

    def pick(pool, n, salt):
        return sorted(pool, key=lambda r: hash_key(r, salt))[:n]

    crown_pool = [r for r in residents if r["trade"] == "man_at_arms"]
    crown_pool.sort(key=lambda r: hash_key(r, "crown"))
    crown_iter = iter(crown_pool)

    for gid, cfg in GATES.items():
        g = gates[gid]
        for shift in ("day", "night"):
            rank = DAY_RANK if shift == "day" else NIGHT_RANK
            if cfg["watch"]:
                for k, r in enumerate(pick(levy_pool(g["at"]), cfg["watch"], f"watch:{gid}:{shift}")):
                    r["work"] = gate_spot(g, None, rank, LATERAL[k % len(LATERAL)], f"post:{gid}:{shift}:{k}")
                    r["work_kind"] = "gate"
                    duty(r, gid, "watchman", shift, "watch", cfg["label"], exact=True)
            for k in range(cfg["crown"]):
                r = next(crown_iter)
                r["work"] = gate_spot(g, None, rank, LATERAL[k % len(LATERAL)], f"post:{gid}:{shift}:c{k}")
                r["work_kind"] = "gate"
                duty(r, gid, "man_at_arms", shift, "crown", cfg["label"], exact=True)

    # --- town patrols: Pikk, Lai, Vene ------------------------------------------------------
    # Day sergeant: the burgher one; night sergeant: the crown one.
    sergeants = sorted(census("watch_sergeant"), key=lambda r: (r["faction"] == "danish_crown", r["id"]))
    sergeant_of = {"day": sergeants[0] if sergeants else None, "night": sergeants[1] if len(sergeants) > 1 else None}
    for street, (n_watch, sgt_day, sgt_night) in PATROLS.items():
        route = _longest_street(plan, street)
        if len(route) < 2:
            continue
        pid = f"patrol.{street.lower()}"
        patrols.append({"id": pid, "points": [list(p) for p in route]})
        index = len(patrols) - 1
        centre = route[len(route) // 2]
        for shift in ("day", "night"):
            crew = pick(levy_pool(centre), n_watch, f"patrol:{street}:{shift}")
            if (shift == "day" and sgt_day) or (shift == "night" and sgt_night):
                s = sergeant_of[shift]
                if s is not None and s["id"] not in taken:
                    crew.insert(0, s)
            for k, r in enumerate(crew):
                r["work"] = place(f"{pid}:start", route[0][0], route[0][1], None)
                r["work_kind"] = "patrol"
                role = "sergeant" if r["trade"] == "watch_sergeant" else "watchman"
                duty(r, pid, role, shift, "sergeant" if role == "sergeant" else "watch",
                     f"{street} street watch", route=index, offset=k * 5.0)

    # --- Toompea wall patrol (Danish) -------------------------------------------------------
    wall = _wall_walk(plan)
    patrols.append({"id": "patrol.toompea_wall", "points": [list(p) for p in wall]})
    index = len(patrols) - 1
    for shift in ("day", "night"):
        for k in range(WALL_PATROL_CROWN):
            r = next(crown_iter)
            r["work"] = place("patrol.toompea_wall:start", wall[0][0], wall[0][1], None)
            r["work_kind"] = "patrol"
            duty(r, "patrol.toompea_wall", "man_at_arms", shift, "crown", "Toompea wall walk",
                 route=index, offset=k * 40.0)

    # Danish dress: red tunic (the crown's colours) over their own hose.
    for r in residents:
        d = r.get("duty")
        if d and d["kit"] == "crown":
            r["cloth"] = [0.62, 0.1, 0.09]
        elif d and d["kit"] in ("watch", "sergeant"):
            r["cloth"] = [r["cloth"][0] * 0.8, r["cloth"][1] * 0.8, r["cloth"][2] * 0.8] if d["kit"] == "watch" else [0.18, 0.2, 0.3]

    for r in residents:
        if "duty" in r:
            report.append({k: r["duty"][k] for k in ("post", "role", "shift")} | {"id": r["id"]})
    return patrols, report
