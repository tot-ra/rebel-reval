# R-1029 second-reviewer sign-off of R-1010 WB-07d worker-thread material bakes

**Review date:** 2026-09-27
**Task:** R-1029 / independent review of commit `e330642d` on current `origin/main` (`be1b971e`)
**Parent:** R-1010 (WB-07d). Later same-path follow-ups R-1024, R-1025, R-1027, R-1028 are in that tip.
**Reviewer:** independent Cursor Agent CLI pass against the R-1029 contract
**Status:** **ACCEPT** - close R-1010. No new leftover row.

## Decision

Cold terrain, water, and backdrop textures still follow the R-1005 thread rule:
workers paint only job-local `Image`s (and pack the caustic pair). Every static
cache write, `ImageTexture` creation, and `Texture2D.get_image()` stays on the
main thread. Synchronous getters share the same bake-request keys as the staged
units. Neighbor material jobs start one pass before their preview units, and a
job dropped without `wait()` joins its pool task or threaded load in
`NOTIFICATION_PREDELETE`.

This is a contract, test, and headless-trace review. The committed GL hash pair
in `docs/reports/async_assembly_cold_materials_2026-09-27.md` is accepted as
evidence. That optional tool was not re-run here: the shared checkout already
had concurrent `.import` churn and another session's `map_view_3d.gd` WIP.

## Contract checks

| Check | Evidence | Result |
|---|---|---|
| 1. Workers only paint job-local Images / pack caustic tiles; cache, textures, and `get_image()` stay on the main thread | `missing_bakes` skips `PATTERN_LIMESTONE` and `PATTERN_ROOF_TILE`. `bake_image` returns a local `Image` with mipmaps. `publish_baked` writes `_cache` only when the key is empty. `caustic_tile_sources()` runs on the main thread; `pack_caustic_tiles` is the worker body. `_copied_texture_image()` / `_authored_plate_image()` duplicate before resize. | **PASS** |
| 2. Cache keys unchanged for `pattern:*`, `pattern_normal:*`, `cobble_surface:*`, `terrain:*`, `blended_ground:*`, `terrain_pattern_array:*` | Getters call the same `*_bake_request()` helpers, then `publish_baked(request, bake_image(request))`. Terrain keys remain `terrain:%s:%d`, `blended_ground:%d`, `terrain_pattern_array:%d`. `test_worker_pattern_bakes_are_byte_identical_to_main_thread` and `test_cold_ground_material_bakes_on_workers` compare published texels to the main-thread paint. | **PASS** |
| 3. Cancel safety: neighbor bakes start one pass before preview units; PREDELETE joins un-waited tasks and loads | Surroundings queues `await_job(neighbor data)`, then `neighbor_*_materials` (`_start_neighbor_materials` builds `terrain_material_units` / `water_material_units`), then later the preview units that consume `materials["units"]`. `MapViewWorkerJob._notification(PREDELETE)` waits the pool task or `load_threaded_get`. Tests: `test_dropped_worker_job_joins_its_task`, `test_cancel_with_worker_jobs_in_flight_joins_them`. | **PASS** |
| 4. `load_resources` is held until consumers run | `_prefetch` / water `prefetch` stay bound on the await unit and on each publish closure via `plates.value()` / `prefetch.value()`. | **PASS** |
| 5. R-1024 / R-1025 merge kept `_copied_texture_image()` and the backdrop `rest_job` | `map_view_terrain_materials.gd` still duplicates `get_image()`. Surroundings still uses `rest_job` plus `backdrops_rest` on relief maps, and `backdrops_water_warm` (R-1028) before `backdrops`. `test_terrain_plate_get_image` and `test_map_relief_water` stay green. | **PASS** |

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Worker writes `_cache`, `ImageTexture`, or materials | **No rejection.** `bake_image` returns a local `Image`. Cache writes are `publish_baked` / getters on the main thread. |
| Limestone or roof-tile `get_image()` moves onto a worker | **No rejection.** `missing_bakes` skips both families. |
| Cache key drift on the named getters | **No rejection.** Staged and sync paths share the request helpers. |
| `ground_publish`, neighbor material units, or `backdrops` over 4 ms except the first water shader parse | **No rejection.** Fresh-process `cold_staged` (below). |

## Verification

Focused suite and traces ran from an isolated worktree at `origin/main`
(`be1b971e`) on 2026-09-27 because the shared checkout had concurrent
`.import` sidecars, deleted `content/maps/*.rrmap.uid`, and a dirty
`map_view_3d.gd`. Cache came from an `rsync` of the imported `.godot/`
directory, not from `--editor --quit`.

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
git worktree add --detach /tmp/rr-r1029-review origin/main
rsync -a .godot/ /tmp/rr-r1029-review/.godot/
cd /tmp/rr-r1029-review
./tools/run_godot_checked.sh --require-test-summary r1029-review -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_async_location_assembly,test_terrain_plate_get_image,test_map_relief_water
# Godot 4.7.1: 3 file(s), 31 test(s), 0 failure(s), 0 error(s).
"$GODOT_BIN" --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/r1029_harbor_east.json --map=reval_harbor_east
"$GODOT_BIN" --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/r1029_lower_town.json --map=lower_town_slice
```

Checked runner accepted the known DEF-002 exit leak (`8 resources still in use`).

### cold_staged budget (4 ms)

Host: Apple M5 Pro, Godot 4.7.1, headless dummy renderer.

| Map | Contract material / backdrop units over 4 ms | Notes |
|---|---|---|
| `reval_harbor_east` | `surroundings/neighbor_reval_harbor_north_water_deep_water` 9.273 ms | Documented first water `ShaderMaterial` parse. No `ground_publish` or `backdrops` over budget. Cribs: `pier_cribs` 0.005, `pier_cribs_logs` 0.653, `pier_cribs_piles` 0.078. |
| `lower_town_slice` | `surroundings/neighbor_reval_south_water_water` 9.369 ms | Same first-parse exception. No `ground_publish` or `backdrops` over budget. |

Remaining over-budget units are neighbor `build_building` / `build_prop` and
`tree_band_publish`. Those stay with **R-1006**. This review does not open a
duplicate.

GL `material_texture_hashes.gd` vs `0876f4ed` was not re-run (optional in the
R-1029 verify line). The parent report's 2071/2079 identical slots plus the
documented BC1 JPEG readback pair remain the recorded evidence.

## Handoff

- R-1029: move to done.
- R-1010: move to done. Second-reviewer acceptance is this report.
- Remaining over-budget neighbor object builds stay with **R-1006**.
