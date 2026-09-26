# World-building task pack (relief, seamless traversal, authoring, historical density)

Status: proposed task pack, 2026-09-26, raised by the maintainer after reviewing the playable
districts. High priority. Task board epic **R-972**; rows **R-973**..**R-986**. `WB-NN` ids below are
local names only, like `CO-NN` in [`../coast/README.md`](../coast/README.md) and `WS-NN` in
[`../water_sky/README.md`](../water_sky/README.md).

The coastal pack (`CO-01`..`CO-09`) owns the Kalamaja shoreline. This pack owns the four complaints
that apply to **every** map: no loading screens between adjacent Reval locations, a map editor a
human can actually use, terrain that is not flat, and districts that read as a lived-in 1343 town
instead of a field of boxes.

Reference bar: Kingdom Come: Deliverance and The Witcher 3. Both are cited only as a target for
density, relief and material variety. Neither justifies new scope by itself; each row below still
carries its own gate.

## Measured baseline (2026-09-26)

Counted directly from `content/maps/*.rrmap` statement frequencies. 1 cell = **0.87 m**
(`MapViewBuildingMaterials.METERS_PER_WORLD_UNIT`).

| Map | Cells | Active | Buildings | Props | Styles | Decals | Elev. profiles | Props / 1000 cells |
|---|---|---|---|---|---|---|---|---|
| `kalev_smithy` (interior) | 364 | **Y** | 0 | 41 | 3 | 7 | 0 | **112.6** |
| `town_hall` (interior) | 960 | . | 3 | 17 | 5 | 0 | 0 | 17.7 |
| `lower_town_slice` | 19456 | **Y** | 89 | **39** | 63 | 11 | 4 | **2.0** |
| `market_civic_quarter` | 14592 | . | 52 | 19 | 18 | 0 | 4 | 1.3 |
| `monastery_quarter` | 29120 | . | 45 | 25 | 23 | 0 | 5 | 0.9 |
| `north_quarter` | 36400 | . | 118 | 26 | 16 | 0 | 4 | 0.7 |
| `south_quarter` | 32256 | . | 59 | 15 | 7 | 0 | 5 | **0.5** |
| `toompea_quarter` | 27648 | . | 44 | **9** | 14 | 0 | 4 | **0.3** |
| `viru_gate_foreland` | 20160 | . | 6 | 43 | 29 | 0 | 0 | 2.1 |

Four facts follow from that table and from the code.

**1. Outdoor districts are roughly fifty times emptier than an interior.** Kalev's forge carries
112.6 props per 1000 cells. The one active outdoor district carries 2.0, and Toompea carries 0.3 -
nine props across 27 648 cells (about 21 000 m²). Decals exist on three maps out of twenty-nine.
This, not the building meshes, is why the districts read as "boxes of buildings that are not real".

**2. Buildings are boxes with recoloured faces.** `lower_town_slice` has 89 `building` rows against
63 `style` rows. The styles are generated variant names (`house.east.h104.40`,
`house.east.h104.41`, ...) differing by roof/wall colour, material enum and wall height. There is no
authored notion of a plot, a rear service range, a yard, a plot wall, age, wealth, or upkeep.
`docs/HISTORICAL_AUDIT.md` H04/H05 already describe strip plots 7-11 m wide and up to 100 m deep
with a front house, rear service buildings and plot walls - the maps do not implement it.

**3. Elevation is a view-only decal.** `docs/MAP_AUTHORING.md` states it plainly: elevation "does
not change 2D collision, navigation, stable IDs, transition placement, or save identity".
`MapBlueprintCompiler` clamps `ground_elevation` to `0.0 .. 8.0`, so a **ditch cannot be authored at
all**. `MapNavBuilder` bakes a flat `NavigationRegion2D`. The view layer does own a height field
(`MapViewMeshBuilder.ensure_height_field`) and boats, penned fauna, urban fauna and scatter snap to
it - the player and navigation do not. Toompea, a limestone hill standing roughly 20-30 m over the
Lower Town, is authored as `elevation=2.8` world units, about **2.4 m**.

**4. Seamless traversal is designed but inert, and there is almost nothing to be seamless between.**
ADR 0019 is `Proposed`; `MapWorldLayout` and `MapAlignmentMath` are implemented; `WorldHost` exists
as a "Phase 2 additive-residency prototype" that "deliberately does not create players/cameras or
perform scene swaps" and is off behind `world_host/additive_residency_enabled`. `DoorNavigator`
still swaps scenes, `MapView3D._assemble()` still builds a whole location synchronously, and
`MapNavBuilder` still bakes the whole location on the calling thread. Separately, only
`lower_town_slice` and `kalev_smithy` are `active=true`; every adjacent district is an inactive
prototype.

**5. The editor edits placement, not content.** `addons/rrmap/` is 2258 lines of
`map_alignment_canvas` / `map_alignment_editor_model` / `map_alignment_workspace`. It positions maps
relative to each other. It cannot paint terrain, place a building or a prop, or sculpt relief.
A parser and a serializer both exist (`MapRrmapParser`, `MapRrmapSerializer`), so a round trip is
available - nothing drives it.

## Rows

| Row | Local id | Deps | Theme | Summary |
|---|---|---|---|---|
| R-973 | WB-01 | none | Relief | [ADR 0023](../../adr/0023-terrain-relief-as-gameplay.md): terrain relief becomes gameplay, with the removed scope named |
| R-974 | WB-02 | R-973 | Relief | Signed relief primitives and a compiled gameplay heightfield in `.rrmap` |
| R-975 | WB-03 | R-974 | Relief | Relief drives player/NPC height, slope limits, navigation and camera |
| R-976 | WB-04 | R-975 | Relief | Re-author Toompea, Lower Town and the Viru foreland with real relief |
| R-977 | WB-05 | none | Seamless | Accept ADR 0019, record phases 3-5 and the travel boundary |
| R-978 | WB-06 | R-977 | Seamless | `WorldHost` phase 3 owns player, camera, environment, HUD and navigation |
| R-979 | WB-07 | R-977 | Seamless | Budgeted async location assembly and threaded navigation bake |
| R-980 | WB-08 | R-978, R-979 | Seamless | Seam crossing with prefetch and eviction, no loading screen inside Reval |
| R-981 | WB-09 | R-982, R-974 | Authoring | `.rrmap` v2 semantic layer: plots, style presets, required descriptions |
| R-982 | WB-10 | none | Authoring | Machine-checkable authoring density and variety contract |
| R-983 | WB-11 | R-981 | Authoring | `.rrmap` content editor: paint, place, sculpt, live preview, round trip |
| R-984 | WB-12 | none | History | 1343 Reval domestic infrastructure dossier: water, food, fuel, sanitation |
| R-985 | WB-13 | R-984, R-981 | History | Burgher plot prefab family with rear service range, yard and plot wall |
| R-986 | WB-14 | R-985, R-976, R-982 | History | Density, wealth/age tiers and landscape bedding pass on `lower_town_slice` |

Ordering note: R-977, R-982 and R-984 have no dependencies and can start immediately. R-973 also has
none but is an ADR, so it gates the whole relief chain and should be first in that chain.

## Relationship to the architecture pack (AR-01..AR-13)

`docs/tasks/architecture/README.md` (board rows **R-959**..**R-971**) was raised the same day from
the same review session, against the same Witcher 3 / Kingdom Come bar. The two packs are siblings
and must not be merged, but the boundary has to stay sharp because both touch the Lower Town:

| Concern | Owner |
|---|---|
| What a building is **made of** - bays, storeys, gables, openings, pitches, coursing, PBR surfaces, the modular kit, per-family bespoke sets | **AR pack** |
| Building **appearance** repetition: distinct silhouettes, nearest identical neighbour, part reuse | **AR-13** |
| How buildings sit on a **plot**: frontage, depth, rear service range, yard, plot wall, gate | **WB-13** |
| Household **services**: water, food, fuel, heat, sanitation, waste | **WB-12** |
| **Dressing and ground** density: props, decals, vegetation, ground cover, footprint repetition | **WB-10** |
| **Terrain** relief and what stands on it | **WB-01**..**WB-04** |
| **Streaming** and loading screens | **WB-05**..**WB-08** |
| **Authoring surface**: `.rrmap` v2 and the editor | **WB-09**, **WB-11** |

Three specific interlocks:

- **ADR numbers.** AR-02 owns `docs/adr/0022-architectural-asset-pipeline.md`. This pack uses
  **0023** (relief as gameplay, WB-01) and **0024** (semantic authoring layer, WB-09). Whoever
  writes second must re-check the highest merged ADR number before creating a file.
- **WB-13 and AR-06.** AR-06 grows the burgher *meshes* from 6 to a real street population. WB-13
  composes the *plot* those meshes stand on. WB-13 must consume AR-06's tier names rather than
  invent a parallel tier vocabulary; if AR-06 lands first, WB-13 adopts its tiers verbatim.
- **WB-14 and AR-05/AR-06.** All three change how `lower_town_slice` looks. AR-05 and AR-06 change
  the renderer and the meshes; WB-14 changes the map file. They can land independently, but WB-14's
  authored wealth and age distribution must map onto the AR tier vocabulary, and the last of the
  three to land owns the combined before/after captures.

## Scope discipline

Three rows in this pack are scope changes under `AGENTS.md` and therefore ship an ADR before any
code: **R-973** (relief as gameplay), **R-977** (accepting ADR 0019 and enabling streaming), and
**R-981** (a second authoring surface in `.rrmap`). Each names the equivalent-cost scope it removes
inside its own task document. No row in this pack may begin implementation before its ADR is merged
or human-approved.

The asset freeze (**P0-040**) still applies. R-985 and R-986 add new production art and must name
exact files in their task rows, with `assets/SOURCES.csv` rows for anything new.
