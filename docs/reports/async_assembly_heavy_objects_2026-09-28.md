# WB-07c heavy single objects and scatter chunks - 2026-09-28

Board row: **R-1006**, follow-up of R-979 ([WB-07](async_assembly_2026-09-26.md)) and R-1005 ([WB-07b](async_assembly_2026-09-27.md)). Status: **in review** (second reviewer pending). Follow-ups: R-1095 (whole-stage units), R-1096 (cold first assembly).

## Where the time went

Profiling the over-budget units from the R-1005 residual list showed that most of them were not geometry at all:

| Cost | Cause | Units it hit |
|------|-------|--------------|
| 40-60 ms | `load(path)` of an authored GLB. ResourceLoader caches a resource only while something references it. Builders did `load(path).instantiate()` and dropped the `PackedScene`, so every building or prop re-read its `.scn`. | `public_bathhouse`, `monastery_barn`, `foaming_mug_brewery`, `guild_storehouse`, every neighbor-preview kit house (`south.plot.*.front`, `dunkri_corner_house`, ...) |
| 5-11 ms | The same, for prop kits shared by many props | every smithy household-clutter, hearth, chest, table and yard plot-dressing prop |
| 2-3 ms per plate | `MapViewBurgherHouseSurfaceVariety` loads kit surface plates nothing held | 8-21 ms per kit house |
| ~40 ms | `_boat_rest_y()` rebuilt the whole playable grid (`MapBuilder.build`) per boat | the six Harbor East fishing boats |
| 6-15 ms | The per-cell pass of `build_scatter()` ran as one call per chunk | every `scatter` chunk |
| ~2-3 ms | Neighbor-preview houses built chimney, structure, facade and window-light dressing that `_simplify_neighbor_building` frees right after | every neighbor-preview house |

## What changed

| Part | Where | Behaviour |
|------|-------|-----------|
| View-scoped scene pins | `scripts/map/view3d/map_view_packed_scenes.gd` (new), `map_view_assembly.gd` | `MapViewPackedScenes.load_scene()` / `load_pinned()` return the same resource as `load()` and also store it in the pin set of the running assembly queue. `MapViewAssembly.run_next()` pushes the queue's set around each unit; `drain()` queues pin into the enclosing queue. The set lives as long as the view, so no GLB outlives every view that used it. Outside a unit it is a plain `load()`. |
| Load sites | 27 model builders in `scripts/map/view3d/` | `load(X) as PackedScene` became `MapViewPackedScenes.load_scene(X)`. Mechanical; `map_view_runtime_actors.gd` (player rig equip) is unchanged. |
| Building GLB prefetch | `map_view_mesh_builder_building_houses.gd`, `map_view_assembly.gd`, `map_view_mesh_builder_surroundings.gd` | `production_scene_paths()` lists every GLB of a building's tier (all variants, not only the fitted one); `production_resource_paths()` adds the kit surface plates. The plan starts threaded `ResourceLoader` requests for the map's buildings and awaits them after `height_field`, before the neighbor previews. Each neighbor preview prefetches its own buildings with its material bakes. |
| Learned prefetch | `map_view_packed_scenes.gd`, `map_view_assembly.gd` | Prop, landmark and animal kits have no path before their build. The last unit of an assembly remembers the pin set per map (`map_id:fingerprint`, path strings only); the next assembly of the same map prefetches it. A map's first assembly in a process still loads its prop kits inline. |
| Surface plates | `map_view_burgher_house_surface_variety.gd` | Plates load through `load_pinned()`; `kit_texture_paths()` lists the plates of the kit families for the prefetch. |
| Fishing boats | `map_view_mesh_builder_prop_models.gd` | `_boat_rest_field()` looks the published field up once per definition key. Same field, same rest Y. |
| Resumable scatter | `map_view_mesh_builder_scatter.gd`, `map_view_assembly.gd`, `map_view_3d.gd` | `build_scatter()` is now `begin_scatter()` + `collect_rows()` + `emit_layers()` + `emit_shore()`. Staged assembly runs a chunk as 4-row bands, a layer unit and a shore unit that hands the chunk to `_load_scatter_chunk(coordinates, built)`. Rows always run top to bottom into the same arrays, so any band split gives the same instances in the same order. `build_scatter()` still does all four in one call for streaming and tools. |
| Backdrop houses | `map_view_mesh_builder_buildings.gd`, `map_view_mesh_builder_surroundings.gd` | `build_building(..., backdrop = true)` skips the ordinary-house dressing (chimney, structure, facade, historic details, window lights) that `_simplify_neighbor_building` removes anyway. Walls, roof and the production model are built as before. |

**Thread rule (headless).** The dummy renderer's mesh `RID_Owner` is not thread-safe. A GLB whose meshes load on a loader thread while the main thread or another loader thread creates a mesh fails with `Attempting to initialize the wrong RID`. Under `DisplayServer` `headless` the prefetch therefore loads one GLB at a time, each started at its own await, so nothing else of the view creates a mesh meanwhile. On Compatibility and Metal the loads run in parallel and overlap the height-field bake. The GPU trace below ran with parallel loads and logged no RID errors.

`map_view_3d.gd` gains 4 lines (the optional `built` argument, freed if the chunk is already loaded). Files outside the row's allowed list: `map_view_assembly.gd`, the new `map_view_packed_scenes.gd`, `map_view_burgher_house_surface_variety.gd`, `map_view_mesh_builder_building_houses.gd`, and the 27 one-line load-site edits. Each is required by the change above.

## Parity

`build/r1006/tree_hash.gd`-style dump (throwaway, not committed): every node path, class, transform and visibility, every `ArrayMesh` surface's `surface_get_arrays()` hash, every `MultiMesh` buffer hash, and the stored properties of every material override and surface material. Three maps, synchronous and staged, against an `origin/main` worktree (`da3e7222`):

| Comparison | Result |
|------------|--------|
| HEAD synchronous vs this change, synchronous and staged, before the backdrop build | 17,168 of 17,168 lines identical (byte-identical files) |
| After the backdrop build | 17,167 identical; 1 differs (see decision) |

**Decision - backdrop build and the shared wall cache.** `MapViewBuildingMaterials._shared_library_surface()` keys its cache on `color.to_html()`, which quantizes to 8 bits. On `lower_town_slice`, a neighbor-preview house used to create the `wall_surface(&"plank", ...)` entry first, and `wall_side_house`'s `ThatchGableInfill` reused it. Now the neighbor dressing is not built, so `wall_side_house` creates the entry with its own exact colour. `albedo_color` differs by 0.0009 in G and B. The new value is the building's authored colour and no longer depends on which neighbors are built first. Accepted; no visual difference.

## Numbers

Host: Apple M5 Pro, Godot 4.7.1, 4 ms budget, warm caches (the trace builds each map once synchronously first). The host was shared with other agent sessions (load average 5-8), so single frames vary by about 1 ms between runs. Reproduce: `godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd -- --output=res://build/benchmarks/async_assembly.json` and `tools/godot_render.sh --script tools/benchmarks/async_assembly_trace.gd -- --output=...` for the GPU trace.

Staged assembly, headless (before -> after):

| Map | Max frame | p90 frame | Units over 4 ms | Neighbor units over 4 ms | Wall time |
|-----|-----------|-----------|-----------------|--------------------------|-----------|
| `lower_town_slice` | 63.8 -> 10.0 ms | 4.49 -> 4.02 ms | 66 -> 6 | 35 (max 63.8 ms) -> 2 (max 4.46 ms) | 6928 -> 4600 ms |
| `kalev_smithy` | 17.2 -> 7.2 ms | 8.65 -> 3.68 ms | 16 -> 3 | 0 -> 0 | 437 -> 285 ms |
| `reval_harbor_east` | 46.3 -> 10.3 ms | 0.67 -> 3.21 ms | 34 -> 6 | 3 -> 0 | 4320 -> 3279 ms |

Harbor East's p90 rises because the scatter chunks are now dozens of 1-3 ms bands instead of 12 chunks of 6-15 ms: more frames do real work, and none of them is heavy. The synchronous `create()` drains the same units and gets the same savings (Lower Town 4970 -> 3574 ms).

### GPU trace

Recommended tier (the M5 Pro above), Compatibility renderer on Metal-backed GL, minimized window through `tools/godot_render.sh`, parallel loader-thread prefetch. `origin/main` (`da3e7222`) -> this change:

| Map | Max frame | Units over 4 ms | Neighbor units over 4 ms | Staged wall time | Synchronous `create()` |
|-----|-----------|-----------------|--------------------------|------------------|------------------------|
| `lower_town_slice` | 71.1 -> 9.6 ms | 156 -> 29 | 84 (max 71.1 ms) -> 2 (max 5.6 ms) | 6343 -> 3892 ms | 5067 -> 3437 ms |
| `kalev_smithy` | 21.3 -> 9.6 ms | 26 -> 3 | 0 -> 0 | 443 -> 154 ms | 293 -> 99 ms |
| `reval_harbor_east` | 46.2 -> 10.6 ms | 32 -> 11 | 4 (max 7.8 ms) -> 0 | 3662 -> 3473 ms | 3253 -> 3014 ms |

The GPU p90 frame is under 0.1 ms on Lower Town and Harbor East (most frames only wait for worker jobs) and 3.7 ms on the smithy. The two remaining Lower Town neighbor units are `monastery_city_wall_east` (5.6 ms, a fortification wall, not a kit house) and `pskov_trade_banner` (4.4 ms, R-1096). The GPU run logged no RID errors with parallel GLB loads. Minimum tier: not measured, no hardware (R-727).

### Residual over-budget units

| Unit | Cost | Why it stays | Owner |
|------|------|--------------|-------|
| `neighbor_building_monastery_city_wall_east` | 5.6 ms GPU | fortification wall build (masonry and battlements), not a kit house | R-1096 |
| `sky_weather` | 4-9 ms | `_stage_sky_weather` builds the sky, clouds and weather in one call; not in this row's files | R-1095 |
| `chunk_finalize` | ~6 ms | terrain details, occluders, chimney smoke and window lights for every initial chunk in one call | R-1095 |
| `view_effects` | up to 8 ms on GPU | post-process and view effect setup | R-1095 |
| `ground_publish` | 4-5.5 ms | one `ArrayMesh.add_surface_from_arrays()` of 176k vertices. Splitting it changes the mesh layout and so the parity fingerprint; the GPU trace does not show it setting the max frame. Not split. | none |
| `neighbor_prop_pskov_trade_banner`, `..._novgorod_...` | ~4.5 ms | procedural heraldry mesh per faction | R-1096 |
| Harbor East `fisher_hut_*`, `fish_shed_mid`, `smoke_shed_west`; smithy `forge_furnace`, `domestic_hearth` | 4-7 ms | procedural single buildings and props whose build itself is the cost | R-1096 |
| Cold first assembly | ~200 ms max frame on Lower Town | cold material generation, first-ever GLB loads of prop kits (no learned set yet) | R-1096 (declared prop-kit paths); R-1010 follow-ups (materials) |

## Verification

| Check | Result |
|-------|--------|
| `--filter=test_async_location_assembly` (24 tests, 4 new) | pass, 0 errors |
| New: row-band scatter equals one-call `build_scatter()` on Lower Town and Harbor East | pass |
| New: a view pins its service-building GLB and kit plates; no pin set stays pushed | pass |
| New: the smithy clutter kit is learned and pinned by the next assembly | pass |
| New: fishing boats share the published height field | pass |
| Tree parity vs `origin/main` (three maps, both paths) | see [Parity](#parity) |
| Full `run_godot_tests.gd` | 2361 tests, 269 failures / 36 errors; the failing set equals the `origin/main` worktree's (2357 tests, 269 / 37). No new failures |
| GPU trace | see [GPU trace](#gpu-trace) |
