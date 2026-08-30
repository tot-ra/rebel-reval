# R-748 / R-751 / R-752 water rollout inventory

Recorded: 2026-08-27
Parent: R-715, reflective water rollout across authored maps
Scope: inventory, shared view rollout contract, and water surface/shoreline geometry contract

## Decision boundary

This report freezes the existing water rollout surface so downstream tasks can work from one explicit inventory. It does **not** change map geometry, water shaders, weather state, navigation, visual quality, or performance budgets. It is not visual or performance acceptance.

The inventory is fail-closed: a new water terrain family or water-bearing map definition must update the focused contract test and this report before it can be treated as part of the rollout. Text such as `surroundings ... water` is not counted as a water terrain; only compiled terrain cells whose ID belongs to `MapTypes.WATER_TERRAINS` are counted.

R-731 (`R-715a` shared water material coverage audit) is complete and remains the upstream material baseline. R-715 remains open because rollout, synchronization, budgets, captures, and independent closeout are not accepted.

## Closed terrain vocabulary

`MapTypes.WATER_TERRAINS` currently contains exactly these four stable IDs:

| Terrain ID | Meaning in the current contract | Primary treatment |
|---|---|---|
| `water` | enclosed water, ditches, ponds, and small basins | shared still-water profile; no coastal tide response |
| `river_water` | authored flowing river/current | shared water shader with Pirita flow direction and stronger detail normal |
| `shallow_water` | coastal or shore-adjacent shallow layer | low absorption, shoreline retreat, foam/breaker response |
| `deep_water` | open/deeper coastal water and lakes | higher absorption and deep-bed response |

The list is owned by [`scripts/map/map_types.gd`](../../scripts/map/map_types.gd). The rendering facade mirrors it in [`scripts/map/view3d/map_view_materials.gd`](../../scripts/map/view3d/map_view_materials.gd); the focused test asserts that the two remain a closed four-ID vocabulary.

## Water-bearing map definitions

The focused test builds every definition returned by [`MapAuditRegistry.all()`](../../scripts/map/map_audit_registry.gd), ignores only invalid empty definitions returned after an already-failed parser dependency, and records every compiled definition containing one or more closed water IDs. The complete result is 14 definitions: 13 rollout rows plus the explicitly excluded `monastery_quarter` row owned by R-529.

| Compiled map ID | Authored definition/source | Water terrain IDs |
|---|---|---|
| `smithy_courtyard` | [`scripts/map/smithy_courtyard_definition.gd`](../../scripts/map/smithy_courtyard_definition.gd) | `water` |
| `lower_town_slice` | [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) | `water` |
| `monastery_quarter` | [`content/maps/monastery_quarter.rrmap`](../../content/maps/monastery_quarter.rrmap) | `water` |
| `south_quarter` | [`content/maps/south_quarter.rrmap`](../../content/maps/south_quarter.rrmap) | `water` |
| `viru_gate_foreland` | [`content/maps/viru_gate_foreland.rrmap`](../../content/maps/viru_gate_foreland.rrmap) | `river_water` |
| `reval_harbor_north` | [`content/maps/reval_harbor_north.rrmap`](../../content/maps/reval_harbor_north.rrmap) | `shallow_water`, `deep_water` |
| `reval_harbor_east` | [`content/maps/reval_harbor_east.rrmap`](../../content/maps/reval_harbor_east.rrmap) | `shallow_water`, `deep_water` |
| `prototype.paldiski_coastal_outpost` | [`scripts/map/definitions/outdoor/coast_harbor_definitions.gd`](../../scripts/map/definitions/outdoor/coast_harbor_definitions.gd) | `shallow_water`, `deep_water` |
| `prototype.sacred_grove` | [`scripts/map/definitions/outdoor/wilderness_event_definitions.gd`](../../scripts/map/definitions/outdoor/wilderness_event_definitions.gd) | `shallow_water` |
| `prototype.saaremaa` | [`scripts/map/definitions/outdoor/wilderness_event_definitions.gd`](../../scripts/map/definitions/outdoor/wilderness_event_definitions.gd) | `shallow_water`, `deep_water` |
| `prototype.swedish_arrival` | [`scripts/map/definitions/outdoor/wilderness_event_definitions.gd`](../../scripts/map/definitions/outdoor/wilderness_event_definitions.gd) | `shallow_water`, `deep_water` |
| `world.sacred_grove` | [`content/maps/world_sacred_grove.rrmap`](../../content/maps/world_sacred_grove.rrmap) via [`DistantLocationDefinitions`](../../scripts/map/definitions/outdoor/distant_location_definitions.gd) | `shallow_water` |
| `world.padise` | [`content/maps/world_padise.rrmap`](../../content/maps/world_padise.rrmap) via [`DistantLocationDefinitions`](../../scripts/map/definitions/outdoor/distant_location_definitions.gd) | `water`, `river_water`, `shallow_water` |
| `world.saaremaa` | [`content/maps/world_saaremaa.rrmap`](../../content/maps/world_saaremaa.rrmap) via [`DistantLocationDefinitions`](../../scripts/map/definitions/outdoor/distant_location_definitions.gd) | `shallow_water`, `deep_water` |

`monastery_quarter` is inventoried because its authored `outer_wall.ditch` contains `water`, but it is excluded from the 13-row rollout matrix pending the R-529 east-ditch regression. This is an explicit external blocker, not an omitted water-bearing definition.

The two sacred-grove and two Saaremaa rows are intentionally separate: `prototype.*` definitions are event/prototype packages, while `world.*` definitions are the developer-traversable RRMap layer. Stable map IDs are not merged or renamed.

## R-752 shared view rollout matrix

The rollout uses the existing `MapView3D.create` path for every row below. `MapViewMeshBuilderTerrain` discovers each water ID from the compiled grid, builds one `Terrain_<terrain_id>` surface, and assigns `MapViewMaterials.water_surface(terrain_id)`. No authored `.rrmap` or prototype activation flag is changed by this rollout.

The focused exception and handoff audit is [`tests/godot/test_r715_water_exceptions.gd`](../../tests/godot/test_r715_water_exceptions.gd), with its fail-closed matrix and external-owner status recorded in [`r715_water_exceptions.md`](r715_water_exceptions.md). It covers the 13 rollout rows while making enclosed, river, shallow/deep coastal, harbour, shoreline, and intentionally excluded Monastery cases explicit.

| Map ID | Water IDs | Shared view path | Gameplay topology |
|---|---|---|---|
| `smithy_courtyard` | `water` | `Terrain/Terrain_water` | unchanged; enclosed-water exception retained |
| `lower_town_slice` | `water` | `Terrain/Terrain_water` | unchanged; stable terrain and transition IDs retained |
| `south_quarter` | `water` | `Terrain/Terrain_water` | unchanged; ditch gameplay remains map-owned |
| `viru_gate_foreland` | `river_water` | `Terrain/Terrain_river_water` | unchanged; river flow remains presentation-only |
| `reval_harbor_north` | `shallow_water`, `deep_water` | `Terrain/Terrain_shallow_water` + `Terrain/Terrain_deep_water` | unchanged; landing and navigation remain map-owned |
| `reval_harbor_east` | `shallow_water`, `deep_water` | `Terrain/Terrain_shallow_water` + `Terrain/Terrain_deep_water` | unchanged; landing and navigation remain map-owned |
| `prototype.paldiski_coastal_outpost` | `shallow_water`, `deep_water` | shared water terrain loop | inactive prototype preserved |
| `prototype.sacred_grove` | `shallow_water` | `Terrain/Terrain_shallow_water` | inactive prototype preserved |
| `prototype.saaremaa` | `shallow_water`, `deep_water` | shared water terrain loop | inactive prototype preserved |
| `prototype.swedish_arrival` | `shallow_water`, `deep_water` | shared water terrain loop | inactive prototype preserved |
| `world.sacred_grove` | `shallow_water` | `Terrain/Terrain_shallow_water` | world-travel layer unchanged |
| `world.padise` | `water`, `river_water`, `shallow_water` | three shared terrain surfaces | world-travel layer unchanged |
| `world.saaremaa` | `shallow_water`, `deep_water` | two shared terrain surfaces | world-travel layer unchanged |

Focused coverage is [`tests/godot/test_r715_water_map_rollout.gd`](../../tests/godot/test_r715_water_map_rollout.gd). It enumerates the registry rather than hard-coding view construction per map, verifies the shared material for each generated surface, asserts exactly one `ViewEnvironment` and one `SkyWeather3D`, and compares terrain fingerprints plus walkability signatures before and after view construction.

R-529 handoff: the pre-existing Monastery east-ditch regression remains owned by its existing task and is not folded into this rollout. Re-run that map-specific regression before final R-715 closeout.

R-713 handoff: unified sky/weather acceptance and water-facing synchronization evidence remain blocked upstream. This rollout consumes the existing shared presenter; it does not create a second weather/environment controller or claim the missing visual acceptance.

## Existing ownership boundaries

| Concern | Current owner | Boundary |
|---|---|---|
| Public material API and profile catalog | [`map_view_materials.gd`](../../scripts/map/view3d/map_view_materials.gd) | Keeps `water_surface`, `WATER_TERRAINS`, weather, lighting, tide, and sky-reflection calls stable for consumers. |
| Cached water materials and uniforms | [`map_view_water_materials.gd`](../../scripts/map/view3d/map_view_water_materials.gd) | Owns water-only shader material cache plus `water_surface`, `apply_sea_weather`, `apply_water_lighting`, `apply_coastal_tide`, and `apply_water_sky_reflection`. |
| Water shader family | [`map_view_material_shaders.gd`](../../scripts/map/view3d/map_view_material_shaders.gd) | Owns the shared animated water shader, depth/bed layers, current advection, Fresnel/celestial response, and safe defaults. R-748 does not alter it. |
| Water surface geometry | [`map_view_mesh_builder_terrain_water.gd`](../../scripts/map/view3d/map_view_mesh_builder_terrain_water.gd) | Owns smoothed contours, coverage sampling, clipped water triangles, and recessed view-only surface vertices. |
| Coastal shoreline detail | [`map_view_shoreline_3d.gd`](../../scripts/map/view3d/map_view_shoreline_3d.gd) | Owns deterministic view-only coastal rock scatter on water-facing coast-sand cells; it does not add collision or navigation. |
| Terrain compilation and water metadata clearing | [`map_builder.gd`](../../scripts/map/map_builder.gd) | Applies authored zones and clears inherited vegetation metadata when a water overlay wins. |
| Wind/rain and presentation snapshot | [`sky_weather_3d.gd`](../../scripts/map/view3d/sky_weather_3d.gd) | Owns the runtime weather values consumed by the view; the current checkout has a known parse cascade before this can be reverified. |
| Astronomical tide calculation | [`sky_astronomy.gd`](../../scripts/map/view3d/sky_astronomy.gd) | Owns the deterministic tide calculation; `MapViewLighting` forwards the presentation tide level to the material facade. |
| Weather/tide fan-out | [`map_view_lighting.gd`](../../scripts/map/view3d/map_view_lighting.gd) | Applies the shared celestial/weather presentation to water lighting, coastal tide, and sky reflection. |

## Child-task handoff boundaries

Existing board rows own the next bounded steps; R-748 does not duplicate them:

| Task | Handoff from this inventory |
|---|---|
| R-750 | Lock the shared reflective material contract and preserve distinct shallow/deep/river optical and flow/tide profiles. Depends on this inventory. |
| R-751 | Stabilize water surface and shoreline geometry using the existing mesh and shoreline owners. |
| R-752 | Roll the shared water presentation across the 13 inventoried rollout definitions without changing stable map IDs or navigation semantics. |
| R-754 | Synchronize water uniforms with the shared sky/weather state rather than creating a second weather store. |
| R-755 | Measure rendering budgets and fallbacks on declared hardware; do not infer target-hardware acceptance from headless runs. |
| R-756 | Produce matched visual evidence; this inventory supplies the map/terrain matrix but does not sign captures. |
| R-757 | Independently rerun the complete rollout, map, weather, performance, capture, and report gates. |

External blockers recorded for downstream coordination are **R-529** (pre-existing Monastery east-ditch water regression) and **R-713** (unified sky/weather acceptance still blocked, including water-facing synchronization evidence). They are not repaired or reclassified by this audit.

The inventory contract itself is [`tests/godot/test_r715_water_rollout_inventory.gd`](../../tests/godot/test_r715_water_rollout_inventory.gd); its report marker check keeps this document and the 14-row full inventory synchronized.

## R-751 water surface and shoreline geometry contract

Focused coverage: [`tests/godot/test_r715_water_surface_geometry.gd`](../../tests/godot/test_r715_water_surface_geometry.gd)

```text
treat empty or sub-threshold water contours as dry instead of indexing missing samples
build deterministic recessed water surfaces without mutating gameplay terrain fingerprints
clip water triangles against smoothed contour coverage and expose shoreline vertex colors for foam
place coastal rock scatter only on coast-sand cells with adjacent closed water IDs
verify authored rock origins through collect_rock_instances before multimesh commit
```

Expected command:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r715_water_surface_geometry
```

Headless Godot 4.7.1 returns identity transforms from `MultiMesh.get_instance_transform()` under the dummy renderer, so shoreline placement assertions read the authored transform list from `MapViewShoreline3D.collect_rock_instances()` and only compare the committed instance count on the node. Visual acceptance remains owned by R-756; gameplay collision and navigation remain unchanged.

## Verification contract

Focused rollout test: [`tests/godot/test_r715_water_map_rollout.gd`](../../tests/godot/test_r715_water_map_rollout.gd)

```text
automatically enumerate water-bearing MapAuditRegistry definitions
automatically build each definition through MapView3D.create
audit one shared water material and surface per compiled water terrain
assert one ViewEnvironment and one SkyWeather3D presenter per view
compare terrain fingerprints and walkability signatures before and after view build
```

Expected command:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r715_water_map_rollout
```

The new rollout contract is lint-clean. The current dirty checkout cannot provide a clean executable result because the existing `SkyWeather3D` parse cascade and unrelated RRMap validation errors occur while loading the shared map registry. This is a baseline verification blocker, not a reason to weaken the rollout contract or alter authored maps. R-752 therefore claims shared view registration and focused coverage, but not visual/performance acceptance.

A scoped Markdown link check must resolve every relative link in this report. `git diff --check` must remain clean for this report and the Roadmap coordination note.
