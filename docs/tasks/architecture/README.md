# Architecture realism task pack (custom buildings for 1343 Reval)

Status: proposed task pack, 2026-09-26, raised by the maintainer after reviewing the built fabric in
play: "current buildings are too simplistic", the game "looks too generic", and the target is
Witcher 3 / Kingdom Come: Deliverance quality. High priority. Board rows **R-959**..**R-971**.
`AR-NN` ids below are local names only, like `CO-NN` in [`../coast/README.md`](../coast/README.md)
and `WS-NN` in [`../water_sky/README.md`](../water_sky/README.md).

This is the building-fabric sibling of the coast pack. CO-01..CO-10 fix what the sea meets; AR-01..AR-13
fix what the street is made of.

## Measured baseline (2026-09-26)

Counted directly over the 29 authored sources in `content/maps/*.rrmap` and the asset tree.

| Measure | Value |
|---|---|
| `building ... house` records, all maps | **362** |
| `building ... wall` records | **182** |
| `building ... interior_wall` / `interior_block` | 10 / 6 |
| house records that resolve to authored geometry (`house_tier=`) | **43**, all in `lower_town_slice` |
| house records rendered as a procedural box plus gable | **319 (88%)** |
| authored house GLBs in the whole project | **6** (`merchant_stone`, `merchant_stone_rendered`, `merchant_timber`, `merchant_timber_log`, `craft_boda`, `craft_boda_pentice`) |
| authored service-building GLBs | **4** (brewhouse, log_barn, public_bath, stone_storehouse) |
| authored gate GLBs | 4 (viru_gate, oak_double_gate, ironbound_double_gate, raised_portcullis) |
| authored GLBs for churches, monastic ranges, town hall, cathedral, keeps, towers | **0** |
| GLBs in `assets/buildings/facades` referenced by any runtime script | **0 of 3** (orphaned) |

House records per map, largest first: `north_quarter` 96, `lower_town_slice` 53,
`market_civic_quarter` 52, `monastery_quarter` 29, `south_quarter` 28, `toompea_quarter` 15,
`world_padise` 14, `world_sacred_grove` 11, `world_saaremaa` 11, `reval_harbor_north` 10,
`reval_harbor_east` 8, then single digits.

## Root causes found in the code

1. **A "style" is not a building, it is a tint.** In `content/maps/lower_town_slice.rrmap` all 49
   house styles differ only by `door_side` (4 values), `wall_height` (6 values), `wall_material`
   (limestone / plank / log / plaster / brick), `roof_material` (shingle / thatch / tile) and two hex
   colours. The style names even encode it: `house.south.h120.09`, `house.east.h104.41`. There is no
   bay rhythm, no storey line, no gable form, no opening schedule and no plinth in the data model.
2. **Wall and roof surfaces have no albedo texture and no roughness map.**
   `scripts/map/view3d/map_view_building_materials.gd` builds every wall and roof from
   `_weathered_albedo(color, weathering)` - a single `Color` - with
   `vertex_color_use_as_albedo = true`, a **procedurally generated pattern normal map**, and a
   hard-coded `material.roughness = 1.0`. A limestone wall, a plastered wall and a plank wall differ
   only in tint and bump pattern. Nothing has varying specular response, so nothing reads as stone,
   lime, tar or wet timber under the same sun.
3. **The good texture library reaches 12% of the buildings.**
   `assets/materials/pbr/building_variants/` does ship a proper albedo + normal set with three stems
   per family (tile, shingle, thatch, rubble, render, limewash, log - 21 pairs). Its only consumer is
   `MapViewBurgherHouseSurfaceVariety`, which only serves the 43 tiered houses. The other 319 houses
   never see it. Even there, **no family ships a roughness map**.
4. **Three GLBs per authored street.** `MERCHANT_TIMBER_VARIANTS` and its siblings hold two meshes per
   tier for three tiers. 43 buildings are drawn from 6 meshes, differentiated at runtime by a tint, a
   UV offset and a non-uniform scale fit. The loader comment says so outright: "The kit only ships two
   meshes per tier, so a street of similar plots would otherwise clone one albedo set."
5. **Landmarks are GDScript, not geometry.** `map_view_mesh_builder_churches.gd` (11k),
   `map_view_monastic_models.gd` (18k) and `map_view_mesh_builder_building_fortification.gd` (25k)
   contain **zero** `res://assets` references. St Olaf, St Catherine's, the cathedral, St Michael's
   convent, the town hall, the keeps and every wall tower are assembled from boxes, cylinders and
   extruded outlines at runtime. That is why a monastery precinct reads as a set of blocks.
6. **Only 31 authored primitives exist for 362 houses**, and most of them are props, not buildings:
   `wall_walk_platform` 13, `tree_line` 11, `work_shed` 6, `cart` 6, `hay_stack` 5, `signal_fire` 6.
   The genuinely architectural ones are single-use: `town_hall_1343`, `holy_spirit_chapel_1343`,
   `st_michaels_precinct_1343`, `st_michaels_chapel_1343`, `st_michaels_service_wing_1343`,
   `st_marys_construction_1343`, `timber_oratory_1343`, `barn_dwelling_1343`.
7. **The research is already done; the art is not.** `docs/HISTORICAL_AUDIT.md` section
   "P0-072: 1343 Reval environment target dossier" already holds per-map target cards for
   `monastery_quarter`, `south_quarter`, `toompea_quarter`, `world.padise` and the rest, with roof-cover
   shares, density bands, confidence labels and evidence rows H01-H24. `content/maps/world_padise.rrmap`
   already carries a careful Kadakas-based 1343 phasing comment. What is missing is geometry that
   honours it.

## Scope assumption (needs maintainer confirmation)

This pack assumes a **hybrid pipeline**, and AR-02 is the ADR that makes that binding:

- **Ordinary fabric** (the 319 untiered houses) comes from an extended version of the project's own
  modular Blender kit (`tools/burgher_house_kit_common.py`), because variability and deterministic
  reuse matter more there than bespoke silhouettes.
- **Landmarks** (St Olaf, St Michael's convent, Padise, the cathedral, the Small Castle, the town hall,
  the wall towers) are **bespoke** models kit-bashed against measured plans and archaeology, with
  licensed detail sources allowed for ornament (capitals, tracery, tile, ironwork).

**Known risk that shapes this choice: P0-209b.** The procedural Blender mammals passed every technical
test and were then visually rejected by the maintainer, and the replacement task explicitly says
"replace failed geometry instead of polishing primitive unions". Buildings occupy more screen than
animals, so the same failure mode is more expensive here. Every AR production task therefore carries a
**visual acceptance line that automated tests cannot satisfy**, and AR-02 must state the provenance
rule before any mesh is authored.

If the maintainer prefers pure in-house procedural generation, or prefers buying a licensed medieval
architecture kit as the base for ordinary fabric too, AR-02 records that instead and AR-04..AR-12 are
re-scoped from it. **Do not start AR-04 before AR-02 is decided.**

## Task list and order

| # | File | Summary | Depends on | Board |
|---|------|---------|------------|-------|
| AR-01 | [AR-01_building_typology_dossier.md](AR-01_building_typology_dossier.md) | Sourced 1343 typology dossier: bays, storeys, gables, openings, pitches, coursing per family | none | **R-959** |
| AR-02 | [AR-02_adr_architecture_pipeline.md](AR-02_adr_architecture_pipeline.md) | ADR 0022: kit vs bespoke, provenance, triangle/texture budgets, LOD contract, scope trade | AR-01 | **R-960** |
| AR-03 | [AR-03_building_surface_pbr.md](AR-03_building_surface_pbr.md) | Full albedo+normal+roughness+AO and anti-tiling for every wall and roof family, available to all 362 houses | none | **R-961** |
| AR-04 | [AR-04_modular_architecture_kit.md](AR-04_modular_architecture_kit.md) | Shared part library: plinths, bays, storey bands, gables, roof planes, eaves, flues, doors, pentices, stairs, galleries | AR-01, AR-02 | **R-962** |
| AR-05 | [AR-05_ordinary_house_assembler.md](AR-05_ordinary_house_assembler.md) | Deterministic kit assembly replaces box+gable for all 319 untiered houses | AR-03, AR-04 | **R-963** |
| AR-06 | [AR-06_burgher_tier_expansion.md](AR-06_burgher_tier_expansion.md) | Burgher tiers grow from 6 meshes to a real street population; the 3 orphaned window facades go live | AR-03, AR-04 | **R-964** |
| AR-07 | [AR-07_monastery_district_set.md](AR-07_monastery_district_set.md) | St Michael's Cistercian convent set plus St Olaf 1343 - multiple models, one theme | AR-04 | **R-965** |
| AR-08 | [AR-08_padise_estate_set.md](AR-08_padise_estate_set.md) | Padise 1343 pre-quadrangle estate: stone hall with undercroft, arched-niche building, timber ranges, mill, ford | AR-04 | **R-966** |
| AR-09 | [AR-09_toompea_set.md](AR-09_toompea_set.md) | St Mary's construction phase, Small Castle, curiae, Long/Short Leg gate works | AR-04 | **R-967** |
| AR-10 | [AR-10_civic_guild_set.md](AR-10_civic_guild_set.md) | Town hall 1343, Holy Spirit chapel and hospital, guild frontage, warehouse with hoist, weighhouse | AR-04 | **R-968** |
| AR-11 | [AR-11_fortification_set.md](AR-11_fortification_set.md) | Coursed wall sections, the Tallinn drum tower, Viru towers, Kuldjala/Nunnatorn/Rentenitorn, wall-walk | AR-04 | **R-969** |
| AR-12 | [AR-12_rural_harbour_set.md](AR-12_rural_harbour_set.md) | Smoke cottage, barn dwelling, threshing barn, boat shed, fish sheds, watermill, windmill, camp fabric | AR-04 | **R-970** |
| AR-13 | [AR-13_repetition_audit_gate.md](AR-13_repetition_audit_gate.md) | Repetition and silhouette verifier plus the district visual-gate rows that close the pack | AR-05..AR-12 | **R-971** |

Recommended order. **AR-01 and AR-03 start now and run in parallel** - AR-03 touches only materials and
needs no dossier. AR-02 follows AR-01 and needs a maintainer decision. Then AR-04 alone, because every
production task consumes its part library. Then AR-05, AR-06, AR-07, AR-08 in parallel, since they
touch disjoint maps and loaders. Then AR-09, AR-10, AR-11, AR-12. AR-13 closes.

The monastery work the maintainer named explicitly is **AR-07** (Monastery District, St Michael's) and
**AR-08** (Padise). Both are deliberately "multiple models in one theme", not one huge mesh, exactly as
requested.

## Seam with the world-building pack (R-972, WB-01..WB-14)

[`../world/README.md`](../world/README.md) was raised the same day, against the same complaint, and its
WB-13 and WB-14 rows touch the same district. The two packs are complementary, and the seam must stay
where it is written here or both will fight over `lower_town_slice`:

| Concern | Owner |
|---|---|
| Where a building sits, how plots, yards, service ranges and plot walls are laid out | **WB-13** (blueprint prefab family) |
| Prop density, wear, wealth and age tiers, landscape bedding, re-authored map data | **WB-14** |
| Terrain relief and the heightfield buildings stand on | **WB-02**, **WB-04** |
| What one building is made of - parts, bays, gables, roofs, openings, surfaces | **AR-03**..**AR-12** |
| Landmark geometry (convent, Padise, cathedral, town hall, towers) | **AR-07**..**AR-11** |

Concretely: WB edits `content/maps/*.rrmap` and `MapBlueprint` prefabs; **AR never does**. AR-04 kit parts
are view-layer output and are deliberately *not* registered as blueprint prefabs, so WB-13's prefab family
and AR-04's part library do not collide - WB-13 places a plot, AR-05 decides what the house on it looks
like.

Two ordering notes:

- **AR-06 and WB-14 both target `lower_town_slice`.** AR-06 requires an empty
  `git diff --stat content/maps/`, and WB-14 re-authors that map. Run them in either order, but not
  concurrently, and whichever runs second re-captures its before/after plates against the new state.
- **AR-05 consumes WB-04's relief if it lands first.** A building assembled on a slope needs a plinth
  that meets the ground. If WB-04 has not landed, AR-05 assumes the current near-flat ground and records
  that assumption.

## Rules for every task in this pack

The [water and sky pack rules](../water_sky/README.md#rules-for-every-task) apply unchanged: read
`AGENTS.md`, `docs/ART_BIBLE.md` and [ADR 0018](../../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
first; art direction wins over physical accuracy but must stay behind an explicit override; touch only
the **Allowed files**; both `minimum` and `recommended` quality tiers must work; no per-frame CPU
readback; baked and authored assets follow [`docs/ASSET_STORAGE_POLICY.md`](../../ASSET_STORAGE_POLICY.md)
and get `assets/SOURCES.csv` rows.

Additional rules specific to this pack:

1. **Asset freeze (P0-040).** AR-03, AR-04 and AR-06..AR-12 all add production art, so each names its
   exact files. Do not widen those lists in passing.
2. **Stable IDs are absolute.** Map, transition, spawn, anchor, patrol, prop, structure, landmark,
   prefab instance and prefab-local IDs survive every task here. New geometry may change what a
   building *looks* like; it may never rename an ID, move an authored cell, or change collision or
   navigation footprints. `docs/MAP_AUTHORING.md` owns that contract.
3. **Geometry is view-layer only.** Gameplay collision and navigation stay authored on the 2D map
   plane, exactly as `MapViewBurgherHouseModels` already documents. A prettier building must not become
   a different obstacle.
4. **Every dimension traces to AR-01.** If the dossier lacks a number, extend AR-01 first. Do not
   invent a storey height in a mesh. Named historical claims need a confidence label in
   `docs/CANON.md` per `AGENTS.md`.
5. **Historical exclusions hold.** The `docs/HISTORICAL_AUDIT.md` cross-map exclusions stay in force:
   no 15th-century St Olaf chancel or giant spire, no Great Guild Hall (1407-10), no Brotherhood or
   Blackheads frontage, no Padise quadrangle / abbey church / gun towers, no later Karja barbican.
6. **Visual acceptance is a separate line from tests.** Per P0-209b, no AR production task closes on
   green tests. Each needs a named human review of real in-game captures at the gameplay camera.
7. **Godot binary** is `/Applications/Godot.app/Contents/MacOS/Godot`, never on PATH. Headless for
   tests, `tools/godot_render.sh` for anything that renders.
8. Another agent may be committing at the same time. Stage files by explicit path only.
