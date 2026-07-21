# Reval fortifications and tower interiors - 1343 baseline

Recorded: 2026-07-21  
Snapshot: Reval in spring 1343  
Runtime registry: `scripts/map/reval_fortification_registry.gd`

## Decision

The game must model the fortifications that can be defended for **1343**, not copy the best-known fifteenth/sixteenth-century Tallinn circuit. The reviewed material does not provide a day-exact 1343 tower inventory. It does establish these bounds:

- work begun in 1310 continued through the 1340s;
- the southern, south-eastern, and northern extensions were still being incorporated;
- the full Lower Town perimeter closed around 1355;
- the 1355 town book records eleven people responsible for individual towers, but that is a later terminus and not evidence for eleven completed towers in 1343;
- the first-quarter-fourteenth-century reconstruction names Nun's Tower and Golden Leg Tower;
- the mid-fourteenth-century reconstruction adds Rent Tower and several gates/positions;
- archaeology supports an initial Great Coastal Gate tower in approximately 1311-1340.

Therefore the conservative game baseline is **four completed Lower Town defensive towers/gate towers**:

| Historical identity | Authored map | Stable building ID | 1343 treatment |
|---|---|---|---|
| Nunnatorn / Nun's Tower | `monastery_quarter` | `monastery_wall_tower_northwest` | Completed tower with an inward-facing door |
| Kuldjala / Golden Leg Tower | `monastery_quarter` | `monastery_wall_tower_west_mid` | Completed tower with an inward-facing door |
| Rentenitorn / Rent Tower | `north_quarter` | `merchant_wall_tower_northwest` | Completed tower with an inward-facing door |
| Great Coastal Gate tower | `north_quarter` | `coast_gate_west_tower` | One conservative gate tower, no Fat Margaret or paired later barbican silhouette |

Stable technical IDs are deliberately retained. They are already referenced by map parity and tests; historical names and dated evidence live in `RevalFortificationRegistry` instead of being inferred from filenames or coordinates.

## Construction-state policy

The mid-fourteenth-century reconstruction places Sand Gate, Viru Gate, Hinke Tower, Cattle/Karja Gate, and Harju Gate on or near the developing circuit. Their exact state on the game's spring 1343 date is not established. These are registered as **construction candidates**, not completed towers.

A future map pass may show a reversible construction state at those stable positions:

1. masonry foundations or a low unfinished shell;
2. timber scaffolding, ramps, cranes, lime, stone, and work sheds;
3. incomplete wall-walk connections and temporary hoarding;
4. no finished conical tower roof, later cannon embrasures, or mature barbican mass;
5. a dated source note and historical-review approval before the mockup becomes canonical.

The wall must remain visually and collision-continuous where a construction site sits on the perimeter. Construction art is presentation, not permission to introduce a passable breach.

## Explicit post-1343 exclusions

The completed 1343 skyline must not include:

- Saunatorn, Nunnadetagune, Loewenschede, Köismäe, Epping, Neitsitorn, or the other third-quarter-fourteenth-century additions;
- Viru foregate/barbican towers as mature masonry works;
- Kiek in de Kök;
- Fat Margaret;
- later gate foreworks, cannon towers, or sixteenth-century wall profiles.

The registry records major exclusions and their earliest reviewed state so later art cannot silently leak into the 1343 map.

## Wall-gap contract

Fortification geometry follows these rules on every city map:

- adjacent curtain and tower footprints overlap or meet; short seal blocks close stepped offsets;
- 3D curtain meshes overhang their authored footprint slightly to hide sub-cell seams;
- every apparent opening is either an authored gate landmark/transition or an inter-district seam;
- gate arches remain walkable at the center and collision-sealed at both jambs;
- every completed tower has exactly one authored inward-facing ground-level door;
- `tower=false` is an explicit dated-state override: the stable position remains wall masonry and must not be inferred as a finished round tower from its footprint.

## Tower mini-dungeon plan

Each completed tower eventually receives a dedicated enterable interior map. A tower package is not complete until it contains:

1. a stable scene/map ID and reciprocal exterior/interior transitions attached to the existing tower door;
2. a compact multi-floor route with stairs/ladders, wall-walk exit, and safe arrival cells;
3. one named boss encounter plus a non-lethal or alternate resolution where the story supports it;
4. authored enemy, loot/evidence, lighting, audio, and day/night state;
5. persistent boss/door/loot state through `GameState` and save compatibility;
6. navigation, collision, transition, camera, combat-outcome, retry, and packaged-build tests;
7. historical dressing appropriate to that tower's 1343 form, without importing later rebuilds.

Construction-candidate towers do **not** receive full mini-dungeons until their completed date is reached by the campaign or an explicitly alternate-history state. Before then, they may receive a construction-site encounter map or remain exterior-only.

## Sources and confidence

- [Tallinn city defensive walls](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-city-defensive-walls/) - synthesis and R. Zobel reconstructions for the first quarter, mid-fourteenth century, and ca. 1373 states.
- Monika Reppo and Villu Kadakas, [Excavations at the Great Coastal Gate of Tallinn](../../history/AVE2019_15_Reppo-Kadakas.pdf) - low curtain/gate by mid-century, probable 1311-1340 initial gate tower, and later Coastal Gate sequence.
- Tallinn Old Town management plan, reconstruction references to R. Zobel - useful for later-state comparison, not a 1343 tower count.
- [`docs/HISTORICAL_AUDIT.md`](../HISTORICAL_AUDIT.md), source H08-H11 - project-wide evidence labels and exclusions.

Confidence is **bounded reconstruction**. Four is a conservative implemented floor supported by named early positions, not a claim that archival evidence proves exactly four defensive works stood on one particular day in 1343. New evidence may add or reclassify a position through an explicit registry, map, documentation, and test update.
