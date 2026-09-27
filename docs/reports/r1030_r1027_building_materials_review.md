# R-1030 second-reviewer sign-off of R-1027 WB-07e building-material worker bakes

**Review date:** 2026-09-27
**Task:** R-1030 / independent review of commit `ba11dec6`
**Parent:** R-1027 (WB-07e, follow-up of R-1010)
**Reviewer:** independent Cursor Agent CLI pass against the four R-1030 checks
**Status:** **ACCEPT** - close R-1027. No new leftover row.

## Decision

Door and beam plates keep the pre-change cache keys because the synchronous
getters now call `door_wood_bake_request` / `beam_wood_bake_request` and then
`bake_image`. Workers paint only job-local `Image`s. `ImageTexture` creation,
`StandardMaterial3D` caches, and limestone `Texture2D.get_image()` stay on the
main thread. A fresh-process harbor-east staged build keeps every crib publish
unit under the 4 ms budget.

This is a contract, test, and headless-trace review. The committed GL hash pair
in the R-1027 report is accepted as evidence. That tool was not re-run here:
the shared worktree already had Godot `--editor`.

## Contract checks

| Check | Evidence | Result |
|---|---|---|
| 1. Door/beam bake requests keep the old cache keys and `bake_image()` is byte-identical to the synchronous paint (rotate_90 and bump strength) | `_door_wood` / `_beam_wood` build the request, then `publish_baked(request, bake_image(request))`. `bake_image` paints, optionally `rotate_90(CLOCKWISE)`, then `bump_map_to_normal_map` at 1.35 (door) or 1.9 (beam). `test_crib_wood_and_masonry_bake_on_workers` and `test_worker_pattern_bakes_are_byte_identical_to_main_thread` (now including `hewn_timber_bake_requests()`) compare published texels to a main-thread `bake_image`. | **PASS** |
| 2. Workers only paint job-local Images; textures, materials and nodes stay on the main thread. Limestone `get_image()` is not moved off-thread | `pattern_bake_units` runs `bake_image` through `MapViewWorkerJob.run_group`. `missing_bakes` skips `PATTERN_LIMESTONE` and `PATTERN_ROOF_TILE`. `publish_baked` and `publish_hewn_timber_materials` / `fortification_masonry` run in main-thread units. `fortification_masonry_resource_paths` only lists library paths for `ResourceLoader` prefetch. | **PASS** |
| 3. Fresh-process `async_assembly_trace.gd --map=reval_harbor_east` shows pier_cribs and pier_cribs_logs / pier_cribs_piles under 4 ms | Isolated worktree at `origin/main` (`a6a3dd76`). Cold `crib_units_ms`: `pier_cribs` 0.005, `pier_cribs_logs` 0.595, `pier_cribs_piles` 0.077, `cribs_building_materials` 0.160. None appear in `units_over_budget`. | **PASS** |
| 4. `--filter=test_async_location_assembly` stays green. GL `material_texture_hashes` vs the parent commit | Same worktree: 1 file, 18 tests, 0 failures. GL 2079/2079 vs `48696ba7` remains the R-1027 recorded pair; not re-run while `--editor` held the shared tree. | **PASS** |

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Door/beam getters invent a second cache key | **No rejection.** Getters call the bake-request helpers. |
| Worker writes `_cache`, textures, or materials | **No rejection.** Door/beam `bake_image` returns a local `Image`. `_cache` writes are `publish_baked` / getters on the main thread. |
| Limestone `get_image()` moves onto a worker | **No rejection.** `missing_bakes` skips limestone. Prefetch is `ResourceLoader` only. |
| Cold `pier_cribs*` still over 4 ms | **No rejection.** Fresh-process harbor units are all under 0.6 ms. |

## Verification

Commands run from an isolated worktree at `origin/main` (`a6a3dd76`) on 2026-09-27
because the shared checkout had Godot `--editor`. Cache came from an `rsync` of
the imported `.godot/` directory, not from `--editor --quit`.

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
git worktree add /tmp/rr-r1030-review origin/main
rsync -a --delete .godot/ /tmp/rr-r1030-review/.godot/
cd /tmp/rr-r1030-review
"$GODOT_BIN" --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/r1030_harbor_east.json --map=reval_harbor_east
./tools/run_godot_checked.sh --require-test-summary r1030-review -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_async_location_assembly
# Godot 4.7.1: 1 file(s), 18 test(s), 0 failure(s), 0 error(s).
```

Checked runner accepted the known DEF-002 exit leak (`8 resources still in use`).

## Handoff

- R-1030: move to done.
- R-1027: move to done. Second-reviewer acceptance is this report.
- Remaining over-budget neighbor `build_building` / `build_prop` units stay with **R-1006**. This review does not open a duplicate.
