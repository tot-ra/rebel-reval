# WB-07b worker-thread terrain and surroundings assembly - 2026-09-27

Board row: **R-1005**, follow-up of R-979 ([WB-07 report](async_assembly_2026-09-26.md)). Status: **accepted** (R-1012, 2026-09-27). The terrain and height-field goal is met. Surroundings is split into units, but a set of single neighbor-preview building and prop builds still cost more than 4 ms each. Those builds are the heavy-single-object class that R-1006 owns (see [Residual gaps](#residual-gaps)).

## What changed

| Part | Where | Behaviour |
|------|-------|-----------|
| Worker jobs | `scripts/map/view3d/map_view_worker_job.gd` (new) | Wraps one `WorkerThreadPool` task or group task. Each task writes only its own result slot. `wait()` is idempotent, because the pool must be waited exactly once per task. Group tasks use at most 4 threads (see [Thread scaling](#thread-scaling)). |
| Await units | `scripts/map/view3d/map_view_assembly.gd` | New `await_job()` unit kind. In staged assembly, an unfinished job gives the rest of the frame back instead of blocking. The synchronous path blocks on it. `cancel()` and a view freed mid-assembly join every queued job. `drain()` runs builder units outside a view. |
| Height field | `map_view_mesh_builder_terrain.gd` | `ensure_height_field()` is now `compute_height_field()` (pure, worker-safe) plus `publish_height_field()` (main thread, first publisher wins). |
| Terrain | `map_view_mesh_builder_terrain_staged.gd` (new), `map_view_mesh_builder_terrain.gd`, `map_view_mesh_builder_terrain_water.gd`, `map_view_pier_crib_builder.gd` | One `terrain_start` unit starts every bake at once: blended-ground splat bands (25 on `lower_town_slice`, 16 vertex rows each), one job per water family, the shore field plus swash sheet, the seabed apron and the pier cribs. Main-thread units then publish them in the old child order: ground, water surfaces, swash, apron, cribs. The shore field is split into an `Image` bake (worker) and `ImageTexture` creation (main). |
| Surroundings | `map_view_mesh_builder_surroundings.gd` | Every neighbor definition, its terrain grid and its preview quad arrays bake on a worker, all neighbors at once. On the main thread each preview then becomes units: preview root, one unit per building, one per prop, the strip, one per merge. The tree band placement is also a worker job. |
| Wiring | `map_view_mesh_builder.gd`, `map_view_3d.gd` | Facade entry points `height_field_units()`, `terrain_units()`, `surroundings_units()`. The three view stages return their follow-up units. `map_view_3d.gd` is net 0 lines, so it stays at the 1200-line lint cap. `build_terrain()` and `build_surroundings()` drain the same units, so every caller gets the same tree. |
| Trace | `tools/benchmarks/async_assembly_trace.gd` | New `cold_staged` section. A staged build runs before anything caches the map, so the cold height-field bake appears as units. |

**Thread rule.** Workers read the map definition, the terrain grid and the published field. They write only job-local data. While any job of one build is running, the main thread writes nothing the jobs read. The one field write (the WS-08 shore-field cache) comes after every job of that build has been joined. Nodes, meshes, materials, textures and every static cache are created on the main thread.

Files outside the row's allowed list, each needed for the split: `map_view_assembly.gd` (the await-unit kind), `map_view_pier_crib_builder.gd` (the crib arrays were a 9 ms main-thread unit), and the two new modules.

## Verification

| Check | Result |
|-------|--------|
| `--filter=test_async_location_assembly` (12 tests, 2 new) | pass |
| New: cold reseeded `reval_harbor_east` bakes its field on a worker, the published field is used, and the staged tree plus every terrain surface array equals the synchronous build | pass |
| New: cancelling with the height-field job in flight joins it, publishes nothing, leaks no nodes, and a later build still bakes | pass |
| Byte-level parity against the pre-change code (HEAD worktree plus the same concurrent working-tree edits). Every `ArrayMesh` surface's `surface_get_arrays()` hash and format, every `MultiMesh` buffer and every `Node3D` transform under `Terrain` and `Surroundings`, on `lower_town_slice`, `reval_harbor_east` and `kalev_smithy` | 1756 of 1756 entries identical |
| 17 related suites (terrain chunks, shore field, WS-13b/13d, harbour, neighbor previews, fortification, R-715 water, ...) | 167 pass, identical to baseline |
| Full `run_godot_tests.gd` | 2186 pass. The failing set is a subset of the baseline worktree's (no new failures) |
| `gdlint` on every touched script | clean |

### Visual parity plates

`tools/capture_wb07_assembly_parity.gd`, over-tolerance pixels (8/255) out of 921,600. Masks: `docs/reports/images/wb07b/*_diff.png`.

| Map | GL staged | GL control | Metal staged | Metal control |
|-----|-----------|------------|--------------|---------------|
| `lower_town_slice` | 439 | 536 | 339 | 339 |
| `kalev_smithy` | 828 | 812 | 756 | 895 |
| `reval_harbor_east` | 112 | 98 | 119 | 98 |

Every staged count is within about 20 pixels of its control, as in the R-979 run (121 vs 111 on the harbour). The harbour over-tolerance pixels fall on the same six 64-px tiles in the staged and control masks (emitters). The byte-level check above shows the geometry is identical.

## Numbers

Host: Apple M5 Pro, Godot 4.7.1, headless dummy renderer, 4 ms budget, warm caches. Reproduce: `godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd -- --output=res://build/benchmarks/async_assembly.json`.

Main-thread milliseconds per stage in `assemble_async()` (before -> after):

| Stage | lower_town_slice | reval_harbor_east | kalev_smithy |
|-------|------------------|-------------------|--------------|
| `height_field` (cold) | about 1126 in one unit -> 0.3 | about 593 -> 0.1 | 0.0 -> 0.1 |
| `terrain_mesh` | 2894.3 -> 7.7 | 3690.3 -> 8.8 | 48.9 -> 0.3 |
| `surroundings` | 1419.2 -> 729.2 | 194.5 -> 48.3 | 0 -> 0.1 |

Staged frames:

| Map | Max frame | p90 frame | Wall time |
|-----|-----------|-----------|-----------|
| `lower_town_slice` | 2894.3 -> 71.1 ms | 17.4 -> 6.9 ms | 5116 -> 4686 ms |
| `reval_harbor_east` | 3690.4 -> 14.7 ms | 13.6 -> 0.07 ms | 4133 -> 3721 ms |
| `kalev_smithy` | 49.0 -> 18.7 ms | 14.3 -> 11.8 ms | 293 -> 318 ms |

What still sets the max frame: `lower_town_slice` 71 ms is a neighbor-preview building build (below). `reval_harbor_east` 14.7 ms and `kalev_smithy` 18.7 ms are `buildings_props`, `scatter` and `sky_weather` units, which R-1006 owns.

Units over budget in the three target stages (warm):

| Map | Before | After |
|-----|--------|-------|
| `lower_town_slice` | `terrain_mesh` 2764 ms, `surroundings` 1374 ms | `ground_publish` 5.3 ms, plus 44 neighbor-preview object builds at 4.1-71 ms |
| `reval_harbor_east` | `terrain_mesh` 3770 ms, `surroundings` 204 ms | 4 neighbor-preview prop builds at 4.5-7.4 ms |
| `kalev_smithy` | `terrain_mesh` 47 ms | none |

The synchronous `create()` drains the same units, so it gets the worker bakes as well. `terrain_mesh` drops from 2764 to 1752-2236 ms on `lower_town_slice` and from 3624 to 2621-3197 ms on `reval_harbor_east` (two runs; host load varied).

### Thread scaling

GDScript bands share refcounted objects: the grid, the field dictionary and constant string keys. The atomic contention caps the gain. The `lower_town_slice` ground bake takes 2519 ms on one thread, 2227 ms on 2, 1735 ms on 4, 1670 ms on 8 and 2201 ms on all 18. Group tasks therefore use 4 threads, which leaves the pool free for threaded loads and navigation bakes while a neighbor assembles.

## Residual gaps

| Gap | Cost | Owner |
|-----|------|-------|
| Neighbor-preview single-object builds: `build_building()` / `build_prop()` for one neighbor structure. Top: `east_throat_north_east` 71 ms, `guild_storehouse` 64 ms, `dunkri_corner_house` 64 ms, `pasture.sheep_a` 30 ms. The cost is repeatable and is the build itself (`_simplify_neighbor_building` is under 0.5 ms). | 4-71 ms each | R-1006 (heavy single building/prefab builds; the builders are its files). A backdrop-only build that skips the dressing `_simplify_neighbor_building` throws away would also help. |
| `ground_publish`: `ArrayMesh.add_surface_from_arrays()` for 176k ground vertices plus the instance | 3.2-5.3 ms headless | R-1006 GPU-backed trace decides whether it needs a split (more surfaces would change the mesh layout). |
| Cold material and texture generation on the main thread: `MapViewMaterials.blended_ground(seed)` 2961 ms on first `lower_town_slice` use, per-neighbor-seed terrain materials 0.9-1.1 s per neighbor, cold fortification and wall builds up to 1.1 s | cold only | New follow-up (see board). These are image and texture-array generation, not mesh arrays. |

Concurrency note: `MapView3D.shore_distance_at()` (active view) can call `bake_shore_field()` for a field. If the same map were ever staged while it is also the active view, that write could overlap a staged build's worker reads of the same field. R-980 must not stage the active map. Different maps use different field dictionaries.

## Second-reviewer sign-off (R-1012, 2026-09-27)

Independent review of commit `85943242` against current `origin/main` (`8d90ce91`, after R-1010 / R-1027 layering). Checks ran in an isolated HEAD worktree (`/tmp/r1012-review`) because a Godot `--editor` process owns the shared checkout. Reviewer: Cursor agent (R-1012). Decision: **accept**. No amend.

1. **Thread rule holds.** Worker callables (`compute_height_field`, `ground_band` / `ground_arrays`, `water_surface_arrays`, `compute_shore_field` + `swash_sheet_arrays`, `seabed_apron_arrays`, `crib_arrays`, `_neighbor_preview_data` / `_preview_data_for`, `_tree_band_data`, `_water_continuation_rest_ys`) read the definition, grid or published field and write job-local packed arrays, dictionaries or `SurfaceTool.commit_to_arrays()` output. `ImageTexture`, `ArrayMesh`, nodes and static caches (`publish_height_field`, `finish_shore_field`, `ground_mesh_from_arrays`, crib `add_*_mesh`, neighbor preview publish) stay on the main thread. Neighbor and water-rest workers call `compute_height_field` and do not publish the height-field cache.
2. **Shore-field write is after joins.** `_start()` queues `await_job` for shore, apron and cribs before `_publish_shore`, which is the only `field["shore_field"]` write. `cancel()` and `MapViewAssembly` PREDELETE join every queued job; `MapViewWorkerJob` PREDELETE also waits a dropped task. The active-view `shore_distance_at()` overlap stays a documented R-980 constraint, not an R-1005 defect.
3. **Parity and budget.** `--filter=test_async_location_assembly` is 18/18 (the original 12 plus later R-1010 / R-1027 cases). Fresh-process trace (`tools/benchmarks/async_assembly_trace.gd`, Apple M5 Pro, headless Compatibility): no `height_field` or `terrain_mesh` unit over 4 ms on `lower_town_slice`, `reval_harbor_east` or `kalev_smithy` (cold or warm). `ground_publish` is now under budget after R-1010 moved the material bake. Residual over-budget units are neighbor-preview `build_building` / `build_prop` (up to 185 ms cold on Lower Town), `buildings_props` and `scatter` - already owned by R-1006.
4. **Scope.** `map_view_assembly.gd` (`await_job`), `map_view_pier_crib_builder.gd` (worker arrays) and the two new modules (`map_view_worker_job.gd`, `map_view_mesh_builder_terrain_staged.gd`) are required for the split. Justified.
