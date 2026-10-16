# WB-13: Burgher plot prefab family - front house, rear service range, yard, plot wall

## Retarget (ADR 0031)

Recorded by WB-13a (**R-1411**). This section is the contract for every later WB-13 subtask. The
original text below is kept for history.

Burgher plots are **plan records**, not a grid prefab. They live in
`content/world/reval_city/plan.json`, are built by `tools/city/build_reval_city_plan.py`, and are
rendered by the city scene (ADR 0031). The `lower_town_slice` grid is unreachable from the seamless
city, so deliverable 1 below (`burgher_plot_package.gd`, blueprint registry, prefab expander,
`tests/fixtures/maps/rrmap_burgher_plot_example.rrmap`) and its allowed files are **superseded**
unless the maintainer reverses this decision. Deliverables 2-5 (deterministic IDs, tier-driven
variation, new art only for yard objects, tests and docs) stay in force, retargeted to plan records.

Subtasks (board refs in parentheses):

| Sub | Ref | Scope |
|---|---|---|
| WB-13a | R-1411 | This contract and trace table (docs only) |
| WB-13b | R-1412 | Predecessor of WB-13c named by its `Depends on`; not on the board under that ref at WB-13a time, resolve before WB-13c starts |
| WB-13c | R-1413 | Strip plots behind street-fronting houses in the plan |
| WB-13d | R-1414 | Plot wall runs, one gate per yard, wall kind by tier |
| WB-13e | R-1415 | Rear service ranges in deep yards |
| WB-13f | R-1416 | Yard infrastructure items from the WB-12 table |
| WB-13g | R-1417 | Yard objects art batch 1: privy, plot gate, water butt |
| WB-13h | R-1418 | Yard objects art batch 2: midden, garden bed, drying line, coop, sweep well |
| WB-13i | R-1419 | Yard ground surfaces in the splat |
| WB-13j | R-1420 | Runtime: plot walls and gates, collision, open gate gap |
| WB-13k | R-1421 | Runtime: yard items and service ranges near the player |
| WB-13l | R-1422 | Reachability and roof-clearance gate |
| WB-13m | R-1423 | Performance cost of yards |
| WB-13n | R-1424 | Capture tool and plates |
| WB-13o | R-1425 | Independent verification and closeout of R-985 |

### WB-13c decisions (R-1413)

Recorded by the unattended complex loop on 2026-10-17; the maintainer may reverse them.

- **Yard shape.** `yard` is the rear part of the plot behind the house's back line, a convex quad
  (or `[]`), not "plot minus footprint". Walls, gates and items in WB-13d..f work on that quad; the
  side strips beside a house stay plot but not yard.
- **Party-wall overhang.** Neighbouring OSM rings overlap by slivers after simplification, so a plot
  is the free interval around the door and its house may overhang it at a party wall. Plots never
  overlap each other, a foreign building or a street corridor.
- **Wide houses.** A house wider than 11 m keeps its own frontage (no house is reshaped here). The
  H04 median is therefore asserted over houses up to 11 m wide (7.65 m); wider footprints are
  mostly merged modern blocks and splitting them belongs to AR-06 / UF-04.
- **No plot.** 98 of 517 eligible houses get none because neighbours or a street close round them;
  later WB-13 steps skip them.

### Evidence rule

Every row below cites a section of `docs/reports/reval_domestic_infrastructure_1343.md` (the WB-12
dossier, "dossier" below) and carries its evidence class: `A` attested, `B` bounded range inferred
from attested observations, `C` later survival for general form only, `D` gameplay assignment
inside A-C limits, `U` unknown. A number with no dossier citation is not allowed; where the dossier
says unknown, the plan records no number. Tier-to-element assignments are class `D` and say so.

### Trace table: plot element to dossier

| Plot element | Dossier row | Class | Per-plot rule | Tiers |
|---|---|---|---|---|
| Plot strip (7-11 m frontage, up to 100 m deep) | Section 5 intro; `docs/HISTORICAL_AUDIT.md` H04 | A/B | Frontage inside 7-11 m; depth stops at the first of another plot, building, street corridor, curtain or 100 m | all |
| Plot wall | Section 1 (gutters, yard fall) and Section 5; wall kinds are H04 plot walls | B (kind per tier is D) | One wall run closing the yard sides and rear; none across the street frontage | all; kind by tier |
| Gate | Section 5 (gated yard); chicken-coop row "Rear yard, gated" | D | Exactly one gate per yard onto the street or a close, with an open gap | all |
| Rear service range: store | Food: grain / beer store | A type, B contents | Only where the yard is deep enough after sheds | craft, merchant, great |
| Rear service range: workshop | Food: commercial bakery, fuel: forge and charcoal crib (hot trades) | D | Fire-separated rear or side; only on a plot whose house trade needs it | craft, some merchant |
| Rear service range: round-log auxiliary dwelling | H05 round-log evidence via Section 4 intro | A | Dirt floor, wattle; poorer tiers | poor, craft |
| Rear service range: kitchen shed | Food: household hearth kitchen | A/B | Rear-yard kitchen shed as an alternative to the living-bay hearth | merchant, great |
| Rear service range: byre or hay barn | Section 2 livestock, Section 5, reject list | reject | **None** on an inner-wall burgher plot | none |
| Yard surface: packed earth | Section 4 "Where refuse sat" (P0-072 ground) | A/B | Default trodden earth | all |
| Yard surface: wood chip | Section 4, H05 chip layers | A | Chip patches near the woodpile and workshop | craft, poor |
| Yard surface: manure layer | Section 4, H05 manure layers | A (extent U) | Small patch by the midden only; never a whole-yard stain | all with a midden |
| Firewood stack | Section 3 authoring table | A type, volume U | 1 on every plot with a dwelling hearth, clear of privy and well; no stack size from a foreign figure | all |
| Privy shed over pit or barrel | Section 4 authoring table | B, lining U | 1 per burgess plot with a rear yard, downslope of the well; labourer plots may share | all except shared poor |
| Midden / chip heap | Section 4 authoring table | A layers, size U | 1 small heap per rear yard, never at the forum or gate apron | all |
| Well (private 0-1 or shared) | Section 1 authoring table | B, construction U | 0-1 private on plots with a rear yard; poor plots may share; sweep or windlass with timber collar, no later stone monument | craft, merchant, great private; poor shared |
| Water butt | Section 1 authoring table (roof drain) | B, count U | 0-1 under a timber-roof eaves channel, against a rear or side wall | craft, merchant, great |
| Kitchen-garden bed | Section 2 authoring table | A/B/U | 0-1 where open ground remains after sheds; district share stays inside the P0-072 3-10% band | all with spare ground |
| Drying line | Section 2 authoring table | D | 0-1, rear yard only, never the frontage | poor, craft |
| Chicken coop | Section 2 authoring table | B/U | 0-1 wattle or basket coop, gated yard, never a street flock | poor, craft |

### Wealth and age tier ladder

Wealth tiers match the census classes in `content/world/reval_city/citizens.json`: `poor`, `craft`
(census `master`), `merchant`, `great`. Age tiers are `new`, `settled`, `old`. Upkeep is `kept` or
`worn`. All assignments are class `D` inside the dossier limits. Frontage is always inside the H04
7-11 m band (class `A/B`); the plan records no finer measured statistic.

| Tier | Frontage band | Wall kind | Service range | Yard surface | Item set |
|---|---|---|---|---|---|
| poor | low end of 7-11 m | wattle | round-log auxiliary dwelling or none | trodden earth, chip | firewood, shared privy, shared well access, midden, drying line, coop |
| craft | 7-11 m | wattle or plank | workshop or store | earth with chip | firewood, privy, 0-1 private well, midden, water butt, bed, line, coop |
| merchant | upper half of 7-11 m | plank or dry-stone / limestone | store, kitchen shed | earth, swept near the house | firewood, privy, private well, midden, water butt, bed |
| great | high end of 7-11 m | dry-stone or limestone | store, kitchen shed | earth, swept | as merchant; hypocaust is house form, owned by AR-01, not a yard item (Section 3, class C) |

Age and upkeep modulate, never add elements: `new` has fresh timber and a clean yard, `settled` is
the baseline, `old` shows weathering and a larger midden patch; `worn` upkeep adds gaps in the wall
and a sparser bed, `kept` the reverse. Neither changes the element set above.

### Yard reject list (copied from dossier Section 6)

- No byre, hay barn or cattle herd on an inner-wall yard; larger animals stay on the P0-072 `low`
  band, at most one tether or small pen where routes allow.
- No timber water pipes (later Viru pipes are not medieval household plumbing).
- No sewer grates and no citywide underground sewer.
- No brick chimney pots.
- No stone Tartu 1335 latrine dimensions copied as Reval measurements; privy lining stays unknown.
- No night soil in the street gutter; no named municipal dung-cart roster.
- No drinking from harbour, ditch or moat water.

---

Board row: **R-985**. Priority: high. Depends on: **R-984**, **R-981**.

## Player-facing goal

A Lower Town street stops being a row of detached boxes. Each house fronts the street on a narrow
strip plot; behind it a yard runs back with a service range, a privy, a woodpile, a water butt and
a small garden, closed off by a plot wall with a gate. The player can see into the yards through
the gates, and the block reads as somewhere people live.

## Why this is needed

`docs/HISTORICAL_AUDIT.md` H04 already describes the correct structure: irregular streets, strip
plots commonly **7-11 m wide and up to 100 m deep**, a front house with rear service buildings, and
plot walls. H05 adds the archaeology from the NUKU courtyard: a mid-14th-century round-log
auxiliary building with a dirt floor, wattle, wells, gutters, and manure and chip yard layers.

None of it is implemented. `lower_town_slice` has 89 free-standing `building` rectangles with no
plot relationship, no yard, no service range, no plot wall and no gate. There is one prefab package
in the entire project, `scripts/map/prefabs/urban_prefab_package.gd`. At 0.87 m per cell, a 7-11 m
frontage is 8-13 cells, so the geometry fits the existing grid without any change of scale.

## Deliverable

1. **A `burgher_plot` prefab package** in `scripts/map/prefabs/`, reviewed and registered
   explicitly in `scripts/map/map_blueprint_registry.gd`, parameterised by frontage, depth, street
   side, wealth tier, age tier and upkeep, expanding to:
   - a street-fronting house whose footprint, storeys and material follow the tier;
   - an optional rear service range - byre, store, workshop or auxiliary dwelling - on H05's
     round-log evidence for the poorer tiers;
   - a yard with authored ground surface, including the manure and chip layers H05 attests;
   - a plot wall with a gate onto the street or a close;
   - domestic infrastructure placed from the R-984 authoring table: privy, midden, water butt or
     shared well, woodpile sized to the R-984 winter figure, kitchen garden, drying line.
2. **Deterministic prefab-local IDs** derived from the plot ID, stable across recompiles,
   reordering and chunking, per ADR 0009.
3. **Tier-driven variation** rather than random noise: a poor plot on the same street as a rich one
   differs in footprint, storeys, material, roof, wall, yard surface and the presence of a service
   range, all from the tier, all deterministic from the map seed.
4. **New production art** only where an existing model cannot carry the meaning, named exactly in
   the task claim, with `assets/SOURCES.csv` rows. Candidates from the current prop census, which
   has no such models: privy, midden, water butt, plot gate, garden bed, drying line.
5. **Godot tests** and a documented authoring contract.

## Allowed files

`scripts/map/prefabs/burgher_plot_package.gd` and its `.uid`,
`scripts/map/prefabs/urban_prefab_package.gd`, `scripts/map/map_blueprint_registry.gd`,
`scripts/map/map_prefab_expander.gd`, `scripts/map/map_prefab_primitive_transformer.gd`,
`scripts/map/map_prop_style_variants.gd`,
`scripts/map/view3d/map_view_mesh_builder_prop_models.gd`,
`scripts/map/view3d/map_view_mesh_builder_district_life_props.gd`,
new `scripts/map/view3d/map_view_domestic_infrastructure_models.gd` and its `.uid`,
matching `.uid` sidecars, art files named in the task claim, `assets/SOURCES.csv`,
`tests/godot/test_burgher_plot_prefab.gd` and its `.uid`,
`tests/fixtures/maps/rrmap_burgher_plot_example.rrmap` and its `.uid`,
`docs/MAP_AUTHORING.md`, `docs/ART_BIBLE.md`, `docs/reports/images/burgher_plot/`,
`docs/tasks/world/WB-13_burgher_plot_prefab.md`, the project task board (`tasks` tool).

## Boundary against AR-06 (architecture pack)

AR-06 (`docs/tasks/architecture/AR-06_burgher_tier_expansion.md`, board row R-964) grows the burgher
**meshes** from the current 6 authored house GLBs to a real street population and brings the three
orphaned window facades in `assets/buildings/facades` into use. This row composes the **plot** those
meshes stand on.

So this row must not author house geometry or new house tiers. It consumes AR-06's tier vocabulary
verbatim; if AR-06 has not landed, use the existing `house_tier=` values (`merchant_stone`,
`merchant_stone_rendered`, `merchant_timber`, `merchant_timber_log`, `craft_boda`,
`craft_boda_pentice`) and add no others. New art in this row is limited to yard and service
objects - privy, midden, water butt, plot gate, garden bed, drying line - which AR-06 does not cover.

## Constraints and non-goals

Do not re-author any production map here - R-986 applies the prefab. Asset freeze **P0-040**
applies: no legacy isometric tiles, props or characters, no pixel-frame animation assets, and every
new file named explicitly in the task claim before work starts. Preserve every stable ID. Do not
add a new giant `MapDefinition` factory or a runtime dictionary authoring path. Roof overhang rules
from the `lower_town_slice` header still hold: only fortification seals and the smithy yard fence
may deliberately interpenetrate, so plot walls and neighbouring roofs must not z-fight.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd` on the fixture, zero errors,
  and an explicit written decision for any `MAP_GEOMETRY_OVERLAP` warning.
- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_burgher_plot_prefab.gd` asserting: prefab-local IDs are deterministic across two compiles
  and a reorder; frontage 8-13 cells maps to H04's 7-11 m; each wealth and age tier produces a
  distinguishable footprint, material and infrastructure set; the yard is enterable through the
  gate and the whole plot is navigable; no roof interpenetration.
- `python3 tools/validate_asset_sources.py`, `verify_asset_lint.py`, `verify_storage_hygiene.py`
- `python3 tools/verify_map_audit.py`, `verify_map_composition.py`,
  `generate_active_docs_report.py --check`
- Captures on GL Compatibility and Metal: a street elevation of four plots at four wealth tiers; a
  yard interior plate; a walk clip entering a yard through the gate.
- A second reviewer confirms every placed infrastructure element traces to a row in the R-984
  authoring table, and that nothing on the R-984 reject list appears.

## Doc updates

`docs/MAP_AUTHORING.md` documents the prefab parameters and the tier contract.
`docs/ART_BIBLE.md` records the wealth and age visual ladder.
