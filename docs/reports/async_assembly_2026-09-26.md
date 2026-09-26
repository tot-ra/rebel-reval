# WB-07 budgeted location assembly - 2026-09-26

Board row: **R-979** ([contract](../tasks/world/WB-07_async_location_assembly.md)). Status: **partial**. The scheduler, threaded navigation, threaded scene loading, cancellation and instrumentation work and are tested. The frame-budget gate is **not met**: two builder calls outside this row's allowed files are still single multi-second units (see [Open gap](#open-gap-units-over-budget)).

## What changed

| Part | Where | Behaviour |
|------|-------|-----------|
| Staged assembly | `scripts/map/view3d/map_view_3d.gd`, `map_view_assembly.gd` (new; extracted to keep `map_view_3d.gd` under the 1200-line lint cap) | `_assemble()` is now an ordered queue of work units under 14 stable stage names (`STAGES` in the new `scripts/map/view3d/map_view_assembly.gd`, which owns the queue, budget loop and timings). `create()` drains the queue in one call, as before. `create_staged()` + `step_assembly(budget_usec)` / `assemble_async()` drain it across frames. Chunk units expand into one unit per streamed object. `cancel_assembly()` stops it. Per-stage, per-unit and per-frame timings are recorded on both paths. |
| Per-object chunk loading | `scripts/map/map_object_chunk_streamer.gd` | `load_chunk()` is split into `begin_chunk_load()` + `load_record()`. Same order and same instances. `load_chunk()` behaviour is unchanged. |
| Threaded navigation bake | `scripts/map/map_nav_builder.gd` | `bake_navigation_polygon()` is the shared pure bake. `start_bake()` runs it on the WorkerThreadPool. `create_navigation_region_threaded()` returns a region whose `NavBakePublisher` child assigns the finished polygon in one step. Freeing the region early joins the worker and drops the result. |
| Threaded scene loading | `scripts/global/door_navigator.gd` | `_get_scene_resource()` uses `ResourceLoader.load_threaded_request()` / `load_threaded_get()` instead of `load()`, with the LRU cache unchanged. `request_scene_preload()` / `is_scene_resource_ready()` start and poll a background load. With the flag on, `go_to_scene()` waits for the threaded load across frames instead of blocking. |
| Flags | `project.godot` `[world_host]` | `async_location_assembly_enabled=false` (ADR 0019: streaming ships flag-off until its gates pass). `location_assembly_frame_budget_ms=4.0` (a quarter of a 60 Hz frame). With the flag on, `MapSceneBootstrap` uses the threaded navigation region. |
| Instrumentation | `tools/benchmarks/async_assembly_trace.gd`, `tools/run_performance_report.sh` | Per-stage and frame trace merged into the performance report as `location_assembly`. See [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md#location-assembly-wb-07). |

**Usage contract for R-980:** assemble a neighbour **detached** (`create_staged()` then `await assemble_async()`), then mount it with one `add_child`. Nothing simulates or renders before the mount, so a half-built location is never visible, and the mounted result is the synchronous result. Measured mount cost: 0.9-6.2 ms.

**Not wired into the active-scene path.** `MapViewRuntimeBootstrap.install()` still uses `create()`. The active scene needs its camera, sky and player rig in the same frame, and it already runs behind the scene-swap transition. The staged path exists for off-screen neighbour mounts, which are R-980 scope.

## Verification

| Check | Result |
|-------|--------|
| `--filter=test_async_location_assembly` (10 tests) | pass |
| Staged tree equals synchronous tree (path, class, transform, visibility, mesh AABB, multimesh count, stable ID) for `lower_town_slice`, `kalev_smithy`, `reval_harbor_east` | pass |
| Threaded nav polygon byte-identical to synchronous, 10 runs x 3 maps | pass |
| Cancel mid-`buildings_props`: no unreleased orphan nodes, no duplicate stable handles, never completes | pass |
| Freeing a threaded region before publish joins the worker and leaks nothing | pass |
| Scheduler never starts a unit after the budget is spent | pass |
| Related suites `test_door_navigator_cache`, `test_map_scene_bootstrap` | pass |
| `test_world_host` | 4 failures, **identical on a clean HEAD worktree** (the stubbed duplicate-handle path WB-06 owns). Not caused by this row. |

Orphan note: `StaticBatcher.merge` detaches merged source meshes and `queue_free()`s them. Those frees complete at the end of a frame, so a synchronous test sees about 2,420 pending nodes after freeing a `lower_town_slice` view built by **either** path. The cancel test therefore excludes nodes that are `is_queued_for_deletion()`. The rest must be zero, and they are.

### Visual parity plates

`tools/godot_render.sh [--rendering-method mobile --rendering-driver metal] --script tools/capture_wb07_assembly_parity.gd [-- --control]`. Both views mount in the same frame into their own worlds, with weather time frozen. They are compared pixel by pixel at 1280x720. The tolerance is 8/255 on the largest channel. `--control` compares two synchronous builds, which gives the renderer's own noise floor.

| Map | GL Compatibility staged (exact / over tol.) | GL control | Metal (mobile) staged | Metal control |
|-----|---------------------------------------------|------------|------------------------|---------------|
| `lower_town_slice` | 1831 / 460 | 1206 / 516 | 1164 / 382 | 1054 / 348 |
| `kalev_smithy` | 10582 / 752 | 12429 / 751 | 1413 / 866 | 1326 / 873 |
| `reval_harbor_east` | 190 / 121 | 223 / 111 | 178 / 101 | 186 / 92 |

Every staged difference is within the control noise floor. The masks (`docs/reports/images/wb07/*_diff.png`, red = over tolerance) put all over-tolerance pixels on the forge fire, candle flames, window lights and chimney-smoke particles. Those are emitters with per-instance random phase, and they differ just as much between two synchronous builds. Staged plates on Metal: `docs/reports/images/wb07/*_mobile_staged.png`.

A first run mounted the staged view **while** it assembled. That produced about 400k 1-LSB differences on `lower_town_slice`, because the sky and weather had simulated for a few extra frames. It is the reason behind the detached-assembly usage contract above.

## Startup baseline and per-stage breakdown

Host: Apple M5 Pro, macOS arm64, Godot 4.7.1, headless dummy renderer. Shared static caches (materials, prefab templates, height field) were warmed by one prior build of the same map, so both paths do the same work. Reproduce: `godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd -- --output=res://build/benchmarks/async_assembly.json`.

Synchronous `MapView3D.create()` in milliseconds:

| Stage | lower_town_slice | kalev_smithy | reval_harbor_east |
|-------|------------------|--------------|-------------------|
| `height_field` (warm) | 0.1 | 0.0 | 0.1 |
| `surroundings` | 1374.1 | 0.0 | 204.1 |
| `terrain_mesh` | 2764.7 | 47.4 | 3769.7 |
| `interior_shell` | 0.0 | 0.1 | 0.0 |
| `decals` | 0.6 | 0.1 | 0.0 |
| `object_index` | 0.9 | 0.3 | 0.3 |
| `buildings_props` | 327.0 | 199.5 | 63.4 |
| `scatter` | 218.0 | 0.0 | 144.0 |
| `chunk_finalize` | 4.9 | 0.1 | 0.3 |
| `transition_visuals` | 0.7 | 0.3 | 0.4 |
| `anchors` | 0.0 | 0.0 | 0.0 |
| `lighting` | 0.0 | 0.0 | 0.0 |
| `sky_weather` | 6.7 | 5.5 | 5.3 |
| `view_effects` | 1.5 | 0.1 | 0.9 |
| **total** | **4700.6** | **254.4** | **4189.9** |

A cold `height_field` on `lower_town_slice` costs about 1,126 ms on the same host. It lands in whichever view builds the map first. Inside `terrain_mesh` for `lower_town_slice`, the blended ground mesh is about 2,550 ms and the WS-08 shore swash is about 610 ms (one-off probe).

This supersedes ADR 0019's "about 2.93 s full production scene startup" as the number to budget against. The 3D view alone now costs 4.2-4.7 s on the two outdoor maps, after the water, sky and density work landed. WB-05 (R-977) still owns the published whole-scene baseline.

Staged `assemble_async()` at a 4 ms budget:

| Map | Units | Frames | Median frame | p90 frame | Max frame | Mount `add_child` | Nav sync | Nav threaded, main thread |
|-----|-------|--------|--------------|-----------|-----------|-------------------|----------|---------------------------|
| `lower_town_slice` | 239 | 66 | 6.1 ms | 14.1 ms | 2764.5 ms | 6.2 ms | 19.3 ms | 0.02 ms (ready after 6 frames) |
| `kalev_smithy` | 71 | 27 | 6.4 ms | 14.7 ms | 48.3 ms | 0.9 ms | 0.5 ms | 0.02 ms (1 frame) |
| `reval_harbor_east` | 115 | 29 | 7.0 ms | 14.9 ms | 3686.9 ms | 1.4 ms | 9.9 ms | 0.01 ms (4 frames) |

Frame-time trace: `staged.frame_ms` in the JSON has one value per frame. Before WB-07, every map is one frame at the synchronous total above.

## Open gap: units over budget

A unit is atomic, so any unit that alone costs more than the budget sets the frame floor:

| Unit | Cost | Why it is still one unit | Owner |
|------|------|--------------------------|-------|
| `terrain_mesh` | 47-3770 ms | `MapViewMeshBuilderTerrain.build_terrain()` builds the ground mesh, water quads, shore swash and seabed apron in one call. Splitting it or moving its array work to a worker needs `map_view_mesh_builder_terrain*.gd`, which is outside WB-07's allowed files (and was being edited by a concurrent session). | R-1005 (WB-07b) |
| `surroundings` | 0-1374 ms | Same: one `build_surroundings()` call in `map_view_mesh_builder_surroundings.gd`. | R-1005 (WB-07b) |
| `height_field` (cold) | about 1126 ms | Pure data, but it writes a static cache that the main thread reads for actor sync. It needs a compute-on-worker, publish-on-main change in the terrain builder. | R-1005 (WB-07b) |
| Heavy single objects (`public_bathhouse` 51 ms, `monastery_barn` 48 ms, `forge_furnace` 18 ms, ...) | 5-51 ms | Each is one prefab or building build. They need per-object LOD-first or split builders. | R-1006 (WB-07c) |
| `scatter` chunks | 12-15 ms | `build_scatter()` is one call per chunk in `map_view_mesh_builder_scatter*.gd`. | R-1006 (WB-07c) |

**Main-thread-only stages in GL Compatibility:** `lighting`, `sky_weather` and `view_effects` create nodes and RenderingServer resources (environment, sky material, ripple viewport) and stay on the main thread. They cost 0-7 ms. Node creation in every stage stays on the main thread, because the scene tree is not thread-safe. Only pure array or polygon computation can move to workers, and today that means the navigation bake.

## Minimum-tier evidence

Not captured. The declared minimum tier (Intel UHD 620, x86_64) is not available on this host, and R-727 already tracks target-hardware evidence. `tools/run_performance_report.sh` now carries the `location_assembly` section, so the minimum-tier run will include it.
