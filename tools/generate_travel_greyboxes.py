#!/usr/bin/env python3
"""Generate the debug travel greyboxes for every charted Estonia location.

WHY: the maintainer wants the whole map reachable for debugging, including places
that belong to later acts. Each node is a tiny rrmap greybox (same format as
world_poide.rrmap) plus a world_travel scene; the later game hides them with its
own logic. Run from the repo root; it rewrites the generated files in place:

  content/maps/world_<id>.rrmap and scenes/world_travel/world_<id>.tscn.
Manifest, catalog and registry entries are merged by hand (see docs/SYSTEMS/HUD_AND_MENUS.md).
Prints a JSON report of spawns, anchors and transitions per node.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H = 54, 30

# slot -> (x, y, spawn_offset_px) on the 54x30 grid; doors are 4x4 cells.
SLOTS = [
    (0, 24, "128,0"),
    (50, 24, "-128,0"),
    (23, 26, "0,-128"),
    (23, 0, "0,128"),
    (0, 14, "128,0"),
    (50, 14, "-128,0"),
]

# archetype -> (terrain lines, building/prop lines, anchors)
ARCH: dict[str, tuple[list[str], list[str], list[str]]] = {
    "castle": (
        ["terrain moat mud 8 4 38 20 order=1",
         "terrain castle_yard castle_paving 11 6 32 16 order=2",
         "terrain approach_road dirt 0 24 54 4 order=3"],
        ["building curtain_north wall 11 6 32 1 primitive=wall wall_height=56",
         "building curtain_west wall 11 6 1 17 primitive=wall wall_height=56",
         "building curtain_east wall 42 6 1 17 primitive=wall wall_height=56",
         "building gatehouse_west house 22 22 2 3 primitive=gatehouse wall_height=76",
         "building gatehouse_east house 28 22 2 3 primitive=gatehouse wall_height=76",
         "building keep house 22 9 10 8 primitive=stone_keep wall_height=92",
         "building storehouse house 34 15 6 4 primitive=storehouse wall_height=54",
         "prop yard_well well 17 17 primitive=well",
         "prop supply_cart cart 15 20 primitive=cart"],
        ["anchor landmark_gatehouse 26 25 kind=gatehouse",
         "anchor landmark_central_keep 27 18 kind=stone_keep",
         "anchor landmark_yard_well 17 18 kind=camp"],
    ),
    "town": (
        ["terrain town_road dirt 3 12 48 6 order=1",
         "terrain market_common mud 14 18 26 5 order=2",
         "terrain yards straw 6 5 12 5 order=3"],
        ["building west_house house 6 6 10 5 primitive=work_shed wall_height=40",
         "building east_house house 36 6 10 5 primitive=work_shed wall_height=40",
         "building hall house 21 6 12 5 primitive=stone_hall wall_height=68",
         "building warehouse house 20 19 8 4 primitive=storehouse wall_height=54",
         "prop market_well well 27 15 primitive=well",
         "prop supply_cart cart 33 22 primitive=cart"],
        ["anchor landmark_market_square 27 15 kind=camp",
         "anchor landmark_town_hall 27 11 kind=stone_keep",
         "anchor landmark_warehouse_row 24 24 kind=camp"],
    ),
    "wild": (
        ["terrain forest_floor meadow 0 0 54 30 order=1",
         "terrain track dirt 0 13 54 4 order=2",
         "terrain clearing ash 18 18 18 8 order=3"],
        ["building watch_hut house 36 6 8 4 primitive=work_shed wall_height=40",
         "building store_hut house 10 6 8 4 primitive=storehouse wall_height=44",
         "prop signal_fire barrels 27 20 primitive=signal_fire",
         "prop broken_cart cart 20 10 primitive=cart"],
        ["anchor landmark_crossing 27 14 kind=camp",
         "anchor landmark_clearing_fire 27 21 kind=camp",
         "anchor landmark_watch_hut 40 12 kind=camp"],
    ),
    "marsh": (
        ["terrain flood_water bog 0 0 54 12 order=1",
         "terrain shallows mud 0 12 54 5 order=2",
         "terrain causeway dirt 2 17 50 4 order=3",
         "terrain dry_bank meadow 0 21 54 9 order=4"],
        ["building pile_hut house 34 22 8 4 primitive=work_shed wall_height=36",
         "building boat_shed house 10 22 8 4 primitive=storehouse wall_height=40",
         "prop signal_fire barrels 27 19 primitive=signal_fire",
         "prop field_standard banner 40 18 primitive=standard"],
        ["anchor landmark_causeway 27 19 kind=bog_causeway",
         "anchor landmark_pile_hut 38 28 kind=camp",
         "anchor landmark_boat_shed 14 28 kind=camp"],
    ),
    "cliff": (
        ["terrain sea_edge mud 0 0 54 5 order=1",
         "terrain cliff_ledge stone 0 5 54 6 order=2",
         "terrain coast_road dirt 0 13 54 4 order=3",
         "terrain upland meadow 0 17 54 13 order=4"],
        ["building lime_kiln house 34 19 8 5 primitive=storehouse wall_height=60",
         "building quarry_shed house 10 19 8 4 primitive=work_shed wall_height=40",
         "prop signal_fire barrels 27 14 primitive=signal_fire",
         "prop quarry_cart cart 22 22 primitive=cart"],
        ["anchor landmark_cliff_edge 27 7 kind=fieldworks",
         "anchor landmark_lime_kiln 38 25 kind=camp",
         "anchor landmark_quarry 14 25 kind=camp"],
    ),
}

# id: (display, archetype, reval direction, reval gate scene, doc, blurb, pos, neighbours)
NODES: dict[str, dict] = {
    "rakvere": dict(name="Rakvere Castle", arch="castle", dir="east", doc="rakvere_wesenberg", pos=(0.608, 0.226), nb=["narva", "poltsamaa"]),
    "haapsalu": dict(name="Haapsalu Castle", arch="castle", dir="west", doc="haapsalu_laanemaa", pos=(0.332, 0.376), nb=["lihula", "klint"]),
    "lihula": dict(name="Lihula Castle", arch="castle", dir="west", doc="haapsalu_laanemaa", pos=(0.365, 0.471), nb=["haapsalu", "maasilinna", "soomaa"]),
    "tartu": dict(name="Dorpat Castle", arch="town", dir="south", doc="tartu_dorpat", pos=(0.651, 0.581), nb=["poltsamaa", "viljandi", "frontier_ugandi"]),
    "viljandi": dict(name="Viljandi Castle", arch="castle", dir="south", doc="viljandi_fellin", pos=(0.538, 0.588), nb=["tartu", "poltsamaa", "karksi", "soomaa"]),
    "poltsamaa": dict(name="Põltsamaa Castle", arch="castle", dir="south", doc="paide_castle", pos=(0.575, 0.482), nb=["rakvere", "tartu", "viljandi"]),
    "narva": dict(name="Narva Castle", arch="castle", dir="east", doc="narva_peipus_east", pos=(0.796, 0.217), nb=["rakvere"]),
    "karksi": dict(name="Karksi-Nuia", arch="castle", dir="south", doc="viljandi_fellin", pos=(0.516, 0.638), nb=["viljandi", "helme", "soomaa"]),
    "helme": dict(name="Helme Castle", arch="castle", dir="south", doc="otepaa_vastseliina_frontier", pos=(0.573, 0.676), nb=["karksi", "frontier_ugandi"]),
    "maasilinna": dict(name="Maasilinna Castle", arch="castle", dir="harbor", doc="saaremaa", pos=(0.238, 0.493), nb=["lihula", "karja"]),
    "karja": dict(name="Karja Fortress", arch="castle", dir="harbor", doc="saaremaa", pos=(0.195, 0.483), nb=["maasilinna"]),
    "klint": dict(name="Baltic Klint Coast", arch="cliff", dir="west", doc="baltic_klint_coast", pos=(0.415, 0.232), nb=["haapsalu"]),
    "soomaa": dict(name="Soomaa Flood Refuge", arch="marsh", dir="south", doc="soomaa_flood_refuge", pos=(0.480, 0.568), nb=["viljandi", "karksi", "lihula"]),
    "frontier_ugandi": dict(name="Otepää - Vastseliina Frontier", arch="wild", dir="south", doc="otepaa_vastseliina_frontier", pos=(0.620, 0.655), nb=["tartu", "helme"]),
}
GATES = {
    "east": ("viru_gate_foreland", "from_reval_east"),
    "west": ("reval_toompea", "from_reval_west"),
    "harbor": ("reval_harbor_north", "from_reval_harbor"),
    "south": ("reval_south", "from_reval_south"),
}
# Reval city spawn each direction lands on (manifest ids; legacy gate scenes are retired).
CITY_SPAWN = {"east": "gate.viru.outside", "west": "road.toompea_west",
              "harbor": "poi.fish_landing", "south": "gate.harju.outside"}
BLURBS = {
    "rakvere": "Danish crown fortress in Virumaa",
    "haapsalu": "Bishop of Ösel-Wiek seat, western siege front",
    "lihula": "Leal, bishopric stronghold on the western coast",
    "tartu": "Bishopric of Dorpat, brick town above the river",
    "viljandi": "Fellin, Order castle and the rye-sack tale",
    "poltsamaa": "Order castle on the Põltsamaa river",
    "narva": "Danish river castle on the eastern frontier",
    "karksi": "Order stronghold near the southern border",
    "helme": "Order castle in the southern hills",
    "maasilinna": "Soneburg, Order castle on the Muhu strait",
    "karja": "Saaremaa hillfort",
    "klint": "Limestone cliffs, waterfalls and quarries on the north coast",
    "soomaa": "Spring flood refuge among dugout boats",
    "frontier_ugandi": "Hillfort and new border castle towards Pskov",
}


def sid(n: str) -> str:
    return f"world_{n}"


def rrmap(n: str, seed: int) -> tuple[str, list[str], list[str]]:
    d = NODES[n]
    terrain, objs, anchors = ARCH[d["arch"]]
    gate, arrival = GATES[d["dir"]]
    lines = [
        f"# Debug travel greybox for {d['name']}: reachable from the global map in every act.",
        "rrmap 1",
        f"map world.{n} loc.world_{n} {W} {H} mud scope=prototype active=false "
        f"palette=clean_painted_outdoor seed={seed} cell_size=32",
        f'source "scenes/world_travel/world_{n}.tscn"',
        f'source "docs/LOCATIONS/{d["doc"]}.md"',
        'source "docs/LOCATIONS/README.md"',
        *terrain, *objs, *anchors,
        "spawn prototype_inspection 4 26",
        "patrol prototype_inspection_route 4,26|15,26|27,26|39,26|50,26",
    ]
    spawns = []
    for slot, m in zip(SLOTS, d["nb"]):
        x, y, off = slot
        lines.append(
            f"transition road_to_{m} {x} {y} 4 4 to=world_{m} destination_spawn=from_world_{n} "
            f"spawn=from_world_{m} spawn_offset_px={off} highlight_area=true "
            "transition_visual=ground alignment=travel"
        )
        spawns.append(f"from_world_{m}")
    # The Reval door: its spawn is the arrival point for travel from the hub (a
    # rrmap may declare only one plain spawn, so arrivals come from transitions).
    x, y, off = SLOTS[len(d["nb"])]
    lines.append(
        f"transition road_to_reval {x} {y} 4 4 to=reval_city destination_spawn={CITY_SPAWN[d['dir']]} "
        f"spawn={arrival} spawn_offset_px={off} highlight_area=true "
        "transition_visual=ground alignment=travel"
    )
    spawns.insert(0, arrival)
    anchor_ids = [re.match(r"anchor (\S+)", a).group(1) for a in anchors]
    return "\n".join(lines) + "\n", spawns, anchor_ids


def tscn(n: str) -> str:
    cls = "".join(p.capitalize() for p in n.split("_"))
    src = (ROOT / "scenes/world_travel/world_poide.tscn").read_text()
    return src.replace("WorldPoide", f"World{cls}").replace("world_poide", f"world_{n}")


def main() -> None:
    # symmetry guard: every new-new edge must exist in both directions
    for n, d in NODES.items():
        assert len(d["nb"]) <= len(SLOTS), n
        for m in d["nb"]:
            assert n in NODES[m]["nb"], f"{n}<->{m} not reciprocal"
    report: dict[str, dict] = {}
    for i, n in enumerate(NODES):
        text, spawns, anchors = rrmap(n, 1360 + i)
        (ROOT / f"content/maps/world_{n}.rrmap").write_text(text)
        (ROOT / f"scenes/world_travel/world_{n}.tscn").write_text(tscn(n))
        report[n] = {"spawns": spawns, "anchors": anchors,
                     "transitions": [f"road_to_{m}" for m in NODES[n]["nb"]] + ["road_to_reval"]}
    json.dump({"nodes": NODES, "gates": GATES, "blurbs": BLURBS, "report": report},
              sys.stdout, indent=1, default=list)


if __name__ == "__main__":
    main()
