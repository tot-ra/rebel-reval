# Coastal realism task pack (Kalamaja and the other water maps)

Status: proposed task pack, 2026-09-26, raised by the maintainer after reviewing Kalamaja
(`reval_harbor_east`) in play. High priority. Board epic **R-947**; rows **R-948**..**R-958**.
`CO-NN` ids below are local names only, like `WS-NN` in
[`../water_sky/README.md`](../water_sky/README.md).

This pack is the shore-side sequel to the water and sky pack. WS-01..WS-15 fixed the **sea surface,
sky and underwater optics**. Every complaint in this pack is about what the sea *meets*: the ground
materials, the shore silhouette, the depth profile, the vessels, and the fact that Kalev cannot enter
the water.

## Measured baseline (2026-09-26)

Measured with a throwaway `SceneTree` probe that compiled each blueprint through
`MapBlueprintCompiler`, built the grid with `MapBuilder`, and flood-filled
`MapVerification.is_walkable_cell`. 1 cell = **0.87 m** (`MapViewBuildingMaterials.METERS_PER_WORLD_UNIT`).

| Map | Size (cells / metres) | Water | Walkable | Largest walkable region | Elevation profiles |
|---|---|---|---|---|---|
| `reval_harbor_east` (Kalamaja) | 144x80 / 125x70 m | 41.7% | 37.8% (4354) | 4326 (99.4%) | 4, height span **0.00..0.05** |
| `reval_harbor_north` | 160x108 / 139x94 m | 49.5% | 36.9% (6382) | 6333 (99.2%) | 4, height span 0.00..0.60 |
| `world.saaremaa` | 104x60 / **90x52 m** | 28.5% | **41.8% (2610)** | 2606 (99.8%) | **0**, span 0.00..0.00 |

Terrain shares, same probe:

- `reval_harbor_east`: deep_water 30.0, forest_floor 13.7, dirt 12.4, mud 11.9, shallow_water 11.7,
  coast_sand 11.1, grass 8.1, timber_floor 1.0
- `world.saaremaa`: forest_floor 25.6, deep_water 17.9, grass 11.8, shallow_water 10.6, meadow 8.7,
  dirt 8.2, coast_sand 7.3, mud 4.2, ash 3.1, stone 1.8, timber_floor 0.7

## Root causes found in the code

1. **Ground materials.** `coast_sand` and `sand` have **no texture at all**: they are driven by
   `PATTERN_SPECKLE` in `scripts/map/view3d/map_view_terrain_materials.gd:65`. `grass`, `mud` and
   `limestone_rubble` ship **albedo only at 512x512** with no normal or roughness map, while
   `cobble`, `hay`, `stone` and `timber` do have the full three-channel set. That asymmetry is
   exactly what reads as "low-res or poor quality" on a beach that fills a third of the screen.
2. **No shore debris.** `assets/props/` has no rock, boulder, pebble, shingle, seaweed or wrack
   family. The shore is bare tinted ground plus vegetation.
3. **Straight shallow line.** `reval_harbor_east` authors `terrain water.shallow shallow_water
   0 24 144 10` - one ruler-straight 144x10 rect. `shore.headlands` / `shore.coves` add small
   rect notches on top, but the underlying band edge survives as a straight line.
4. **No sea room and no shore room.** At 144x80, Kalamaja spends 24 rows (21 m) on deep water,
   10 rows (8.7 m) on shallow, and 46 rows on everything landward. There is no room for a depth
   gradient, a berm, a dune line and a village terrace to read as separate levels.
5. **Flat ground.** Kalamaja's whole authored height span is **0.05 world units**. Saaremaa has zero
   elevation profiles. Nothing can read as a gradual level change because there are no levels.
6. **Vessels are primitives.** `map_view_fishing_boat_builder.gd` and
   `map_view_merchant_boat_builder.gd` assemble boxes, cylinders and spars with flat role materials.
   There are exactly **two** hull designs for the whole coast, the sail is a static `_sail_mesh()`,
   and the oars are fixed spars. Only the hull moves: `BoatFloat3D` heaves/pitches/rolls on the FFT
   field and heels into `SkyWeather3D` wind (`WIND_HEEL_RAD` 5.5 deg), but nothing in the rig or the
   oars responds to wind or wave.
7. **Water blocks the player.** `MapVerification.is_walkable_cell` rejects every
   `MapTypes.WATER_TERRAINS` cell. [ADR 0021](../../adr/0021-swimming-and-diving.md) is **Proposed**
   and its breath rule is explicitly **non-lethal**. The maintainer has now asked for drowning to be
   possible, so the ADR needs an amendment and an acceptance line before WS-14b can run.
8. **Saaremaa is too small to walk.** 2610 walkable cells inside 90x52 m, with forest_floor at 25.6%
   forming blocking bands on the south, west and east edges plus the Kaali crater slope mass in the
   middle. The island reads as a corridor, not a region.

## Scope assumption (needs maintainer confirmation)

CO-03, CO-04 and CO-09 assume the maps **may grow their cell footprint**. That shifts every authored
cell coordinate on the touched map and forces parity fixtures to be regenerated, so each of those
tasks carries its own ADR requirement under the `AGENTS.md` scope-change rule. If the maintainer
prefers to keep the current footprints, CO-03 and CO-09 must be renegotiated down to
"redistribute bands inside the existing grid" before any coding starts.

## Task list and order

| # | File | Summary | Depends on |
|---|------|---------|------------|
| CO-01 | [CO-01_coastal_ground_materials.md](CO-01_coastal_ground_materials.md) | Real sand/mud/grass/shingle PBR sets with normal+roughness and anti-tiling detail blend | none |
| CO-02 | [CO-02_shore_debris_props.md](CO-02_shore_debris_props.md) | Rock, boulder, pebble, shingle, seaweed and wrack prop family scattered on the tide margin | CO-01 |
| CO-03 | [CO-03_shore_silhouette_and_depth.md](CO-03_shore_silhouette_and_depth.md) | Wider sea, wider shore, irregular waterline, real shoaling depth gradient | CO-04 (ADR) |
| CO-04 | [CO-04_coastal_elevation_levels.md](CO-04_coastal_elevation_levels.md) | Gradual foreshore / berm / dune / terrace levels and a graded seabed | none |
| CO-05 | [CO-05_historical_vessel_research.md](CO-05_historical_vessel_research.md) | Sourced 1343 Baltic vessel dossier with hull and rig dimensions per type | none |
| CO-06 | [CO-06_vessel_asset_fleet.md](CO-06_vessel_asset_fleet.md) | Authored GLB fleet replacing the two primitive builders, with size and wear variants | CO-05 |
| CO-07 | [CO-07_rig_and_oar_dynamics.md](CO-07_rig_and_oar_dynamics.md) | Sails billow and luff with wind, oars and mooring lines answer the wave field | CO-06, CO-08 |
| CO-08 | [CO-08_sea_state_wind_coupling.md](CO-08_sea_state_wind_coupling.md) | Real varying wind direction plus a labelled Beaufort-to-wave-height ladder and a shelter term | none |
| CO-09 | [CO-09_saaremaa_traversability.md](CO-09_saaremaa_traversability.md) | Saaremaa becomes a walkable region instead of a corridor | CO-04 |
| CO-10 | [CO-10_swim_dive_drown.md](CO-10_swim_dive_drown.md) | ADR 0021 amended for drowning and accepted (R-957), then drowning shipped on WS-14b (R-958) | WS-13, WS-05, WS-14b |

Board rows: CO-01 **R-948**, CO-02 **R-949**, CO-03 **R-950**, CO-04 **R-951**, CO-05 **R-952**,
CO-06 **R-953**, CO-07 **R-954**, CO-08 **R-955**, CO-09 **R-956**, CO-10 **R-957** + **R-958**.

Recommended order: CO-01, CO-05, CO-08 and the CO-10 ADR amendment (R-957) can all start now and run
in parallel. Then CO-02 and CO-04, then CO-03, CO-06 and CO-09, then CO-07 and the CO-10
implementation (R-958).

Two entry points need a maintainer decision before their coding starts: the footprint growth ADR
(CO-03, CO-09) and the ADR 0021 acceptance plus scope trade (CO-10 R-957). Everything else is
unblocked.

## Rules for every task in this pack

The [water and sky pack rules](../water_sky/README.md#rules-for-every-task) apply unchanged: read
`AGENTS.md`, `docs/ART_BIBLE.md` and [ADR 0018](../../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
first; art direction wins over physical accuracy but must stay behind an explicit override uniform;
touch only the **Allowed files**; both `minimum` and `recommended` quality tiers must work; no
per-frame CPU readback; baked and authored assets follow
[`docs/ASSET_STORAGE_POLICY.md`](../../ASSET_STORAGE_POLICY.md) and get `assets/SOURCES.csv` rows.

Additional rules specific to this pack:

1. **Asset freeze (P0-040).** CO-01, CO-02 and CO-06 add new production art, so each names its exact
   files. Do not widen those lists in passing.
2. **Stable IDs.** Map, terrain, transition, spawn, anchor, prop and prefab IDs survive every
   re-authoring task. Growing a footprint may move a cell coordinate; it may never rename an ID.
3. **Godot binary** is `/Applications/Godot.app/Contents/MacOS/Godot`, never on PATH. Headless for
   tests, `tools/godot_render.sh` for anything that renders.
4. Another agent may be committing at the same time. Stage files by explicit path only.
