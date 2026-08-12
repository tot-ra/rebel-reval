# Lower Town P0-101 Runtime, Route, Occlusion and Budget QA

**Task:** R-490 / P0-101e
**Parent:** R-108 / P0-101
**Maps:** `lower_town_slice` (Workers' District) and `kalev_smithy`
**Verification date:** 2026-08-12
**Engine:** Godot 4.7.1.stable.official (a13da4fe)
**Measurement host:** macOS, Apple M5 Pro, 18 logical cores, headless (`development-baseline-m5-pro`, `development_baseline_not_minimum`)
**Worktree:** shared worktree contains unrelated concurrent WIP. Every failure in this report was re-checked against a clean `git worktree` checkout of `HEAD` before being attributed.
**Decision:** **BLOCKED - clause 6 of P0-101 does not pass.** Routes, collision, navigation, chunk ownership and frame-time budgets are green; resident node/memory budgets fail, camera occlusion behaviour fails, and the 3D runtime does not load at all from a clean checkout of `HEAD`.

## Scope and method

R-490 is the runtime gate for P0-101 clause 6: routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures and performance budgets. It does not author art, does not judge silhouettes and does not produce acceptance captures; those stay with R-487/R-488/R-489 (implementation) and R-491/R-492 (visual and human review).

Because the shared worktree is dirty, every red result was reproduced in `/tmp/r490_clean`, a detached worktree at `HEAD` with a full `--import` pass. Failures that reproduce there are real repository state; failures that only appear in the dirty worktree would be concurrent WIP and are not attributed to this gate. No such WIP-only failure was found.

All Godot commands ran through `tools/run_godot_checked.sh --require-test-summary`, which fails on any engine, script, parser or resource error outside the documented DEF-002 shutdown allowlist.

## Result matrix

| Area | Result | Evidence |
|---|---|---|
| Routes, transitions, collision, navigation, water exclusion, parity fixture | **PASS** | `test_lower_town_slice_map`, `test_kalev_smithy_map`, `test_burgher_house_tiers`: 3 files, **39/39**, 0 errors |
| Terrain chunk residency and reload | **PASS** | `test_map_terrain_chunks` 6/6, `test_large_map_chunk_prototype` 8/8 |
| Object chunk ownership / streaming occlusion metadata | **PASS after reviewed re-baseline** | `test_map_object_chunk_streaming` 7/7 after regenerating the stale P0-067c baseline; see [Finding 3](#finding-3-stale-reviewed-chunk-ownership-baseline-resolved) |
| Budget model and slice gate consistency | **PASS** | `test_vertical_slice_performance`, `test_performance_benchmark`, `test_urban_population_performance_cap`: 3 files, **9/9**; `python3 tools/report_slice_performance.py` valid |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py`: 8 style-lock textures, 9 character GLBs, 29 tier-classified GLBs |
| Measured frame time, collision count, ambient-audio peaks | **PASS** | `lower_town_scene` p95 7.326 ms (limit 16.67), collisions 172 (limit 900), bird audio 1/3, bird flight 1/4 |
| Measured resident node count and resident memory | **FAIL** | `lower_town_scene` node count 8472 (limit 7500), memory delta 446.2 MiB (limit 280); see [Finding 1](#finding-1-lower-town-production-scene-exceeds-resident-node-and-memory-budgets) |
| Camera occlusion, building pull-out and follow boom | **FAIL** | `test_map_camera_modes` 6 failing assertions, reproduced at clean `HEAD`; see [Finding 2](#finding-2-camera-occlusion-and-follow-boom-regressions) |
| Runtime loads from a clean checkout | **FAIL at `HEAD`** | `MapView3D` cannot load; the whole 3D map runtime is dead at `HEAD`; see [Finding 4](#finding-4-release-blocking-runtime-load-breakage-at-head-fixed-here) |

## Findings

### Finding 1: Lower Town production scene exceeds resident node and memory budgets

`tools/run_performance_report.sh` measured the production `scenes/reval_east/reval_east.tscn` profile (`lower_town_scene`):

| Metric | Observed | Budget | Result |
|---|---|---|---|
| `frame_time_ms_p95` | 7.326 ms | 16.67 ms | pass |
| `collision_count` | 172 | 900 | pass |
| `bird_audio_peak` / `bird_flight_peak` | 1 / 1 | 3 / 4 | pass |
| `node_count` | **8472** | 7500 | **fail (113 %)** |
| `memory_delta_mib` | **446.2** | 280 | **fail (159 %)** |

The map-pipeline profile of the same district stays inside every budget (`node_count` 2246, `memory_delta_mib` 15.3, `navigation_bake_ms` 17.8), so the overage comes from the assembled production scene - actors, rigs, dressing and their materials - and not from the map compiler or the chunk streamer.

This is a hard blocker for P0-101 clause 6 and it will get worse, not better, as R-487/R-488/R-489 add ordinary-frontage variation and exceptional landmark meshes. The budget owner (P3-011) must either reduce resident cost or re-authorize the limits before the art pass lands; the limits must not be raised silently to absorb new art.

Both numbers were measured headless on a development baseline, not on the declared minimum target (`minimum-hardware-intel-uhd-620`). Headless measurement also cannot see GPU cost, so draw calls remain unmeasured here; `tools/benchmarks/lower_town_render_probe.tscn` is the non-headless instrument for that and was not run in this gate.

The synthetic `navigation_bake_ms` failures at 128 and 256 cells (66.5 ms and 3258.9 ms against a 25 ms limit) are scale-profile results for the large-map prototype, not Lower Town, and are outside this gate.

### Finding 2: Camera occlusion and follow-boom regressions

`test_map_camera_modes` fails 6 assertions across 4 of its 11 tests. The identical 6 failures reproduce on a clean `HEAD` checkout (with only the Finding 4 syntax repair applied, so the file can parse at all), so they are repository state, not local WIP:

- `test_building_collision_pulls_camera_out` - camera is not pulled out of a building AABB after follow;
- `test_c_cycles_third_person_first_person_and_top_down` - first-person camera does not sit at eye height;
- `test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character` - third-person pitch does not keep the follow boom distance;
- `test_third_person_scroll_zoom_clamps_and_enters_first_person` - restored boom does not reach max or min follow distance, and zoom-entered first-person does not sit at eye height.

The other 7 tests pass in the `r490-camera` run below, including every occlusion assertion: `test_enclosed_interior_third_person_does_not_enable_occlusion_ghost`, `test_top_down_occlusion_allows_ghost_not_reset`, `test_smithy_start_third_person_camera_avoids_walls`, `test_ground_clamp_prevents_underground_camera`, `test_interior_shell_follows_close_and_top_down_camera_modes`. Occlusion culling and interior ghosting are therefore healthy; the defect is confined to camera placement.

The failing set is exactly the follow-boom and eye-height contract. `scripts/map/view3d/map_view_runtime_camera.gd` is being actively edited by a concurrent session, so this gate reports the regression and does not change camera behaviour. It must be closed before P0-101 clause 6 can pass, because P0-101 route captures depend on the gameplay camera being correct.

### Finding 3: Stale reviewed chunk-ownership baseline (resolved)

`test_map_object_chunk_streaming::test_playable_slice_boundary_warnings_have_reviewed_production_ownership` failed for both playable slices on clean `HEAD`. The guard exists to force a human review of any change to chunk-boundary ownership, so this gate performed that review rather than only reporting it.

Reviewed drift in `tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`:

- `lower_town_slice`: 22 of 71 records changed, all `cell_rect` width only. They are precisely the plots narrowed by commit `0fc855b5` ("Separate overlapping Workers' District building footprints", 2026-07-27), which shrank the western/northern plot of each overlapping pair so roof overhangs stopped interpenetrating. That commit regenerated `lower_town_slice.parity.json` but not this baseline.
- `kalev_smithy`: `excluded.000` became `excluded.001` with an identical rect, because commit `cecc94a7` ("Keep smithy wake spawn outside bed") inserted `exclude blocked.bed` ahead of `exclude blocked.fore`.

No `owner_chunk`, `consumer_chunks`, `residency` or `kind` value changed, and no record was added or removed. Chunk ownership and streaming residency are therefore unaffected; only the recorded geometry was stale. The substantive assertions in the same test - owner is the lexicographically smallest consumer, every subject appears exactly once per consumer chunk, transitions stay persistent, exclusions stay baked into blocked navigation - passed both before and after.

The baseline was regenerated from the clean `HEAD` worktree, not from the dirty shared worktree, so concurrent WIP in the compiler and rrmap parser could not contaminate it. Verified green afterwards in both the clean worktree and the shared worktree.

### Finding 4: Release-blocking runtime load breakage at `HEAD` (fixed here)

From a clean checkout of `HEAD`, the entire 3D map runtime fails to load. Two files were left syntactically or semantically broken by commit `c1da164b` ("Fix GDScript gdlint across scripts and align lint config.", 2026-08-11), a 342-file reformat that deleted real code alongside formatting:

1. `scripts/map/view3d/map_view_runtime_camera.gd` - the `get:` body of `var first_person: bool:` was deleted, leaving a property with no block. The file does not parse, so `MapViewRuntimeCamera` cannot be resolved, `map_view_runtime.gd` fails to compile, and nothing that touches `MapView3D` can run.
2. `scripts/map/view3d/map_view_monastic_models.gd` - the `var long_face` and `var run` declarations were deleted from `add_oratory_details()` while their uses remained. The file does not parse, `MapViewMonasticModels.is_oratory` becomes unresolvable, and a single test run emitted 2128 `Nonexistent function 'is_oratory'` script errors. This is the oratory and monastic render path, which covers `st_catherines_church` and `monastery_cloister` - the two landmarks P0-101 must present.

Both declarations are restored verbatim to their pre-`c1da164b` form (4 lines total, no behaviour change). The same 4 lines were already present as uncommitted edits in the shared worktree from a concurrent session; this gate reproduced them independently in the clean worktree, confirmed byte equality with the pre-`c1da164b` source, and commits them because `HEAD` must not stay unloadable. Verified: at clean `HEAD` plus these four lines plus the Finding 3 baseline, `test_map_object_chunk_streaming` and `test_lower_town_slice_map` run **26/26 green with zero script errors**, where the same command at unmodified `HEAD` cannot load the runtime at all.

CI did not catch this because gdlint checks style, not compilation, and no gate runs a parse or load check over every script from a clean checkout.

## Commands

```bash
export GODOT_LOG_DIR=/tmp/r490_qa
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# Routes, collision, navigation, parity, tier wiring
tools/run_godot_checked.sh --require-test-summary r490-map-contracts -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map,test_kalev_smithy_map,test_burgher_house_tiers
# Godot headless tests: 3 file(s), 39 test(s), 0 failure(s), 0 error(s).

# Chunk ownership, terrain residency, chunk prototype
tools/run_godot_checked.sh --require-test-summary r490-chunk-refix -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_object_chunk_streaming,test_map_terrain_chunks,test_large_map_chunk_prototype
# Godot headless tests: 3 file(s), 21 test(s), 0 failure(s), 0 error(s).

# Budget model and slice gates
tools/run_godot_checked.sh --require-test-summary r490-perf -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_vertical_slice_performance,test_performance_benchmark,test_urban_population_performance_cap
# Godot headless tests: 3 file(s), 9 test(s), 0 failure(s), 0 error(s).

python3 tools/report_slice_performance.py   # manifest and slice gates are valid
python3 tools/verify_asset_lint.py          # asset lint passed

# Measured Lower Town budgets (report is host-specific, not committed)
GODOT_BIN="$GODOT" tools/run_performance_report.sh build/benchmarks/r490-lower-town.json
# frame p95: 7.326 ms; static memory: 599291229 bytes; actor count: 6

# Camera occlusion and follow boom (blocking)
tools/run_godot_checked.sh --require-test-summary r490-camera -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes
# Godot headless tests: 1 file(s), 11 test(s), 6 failure(s).
```

Consolidated re-run of every in-scope suite after the Finding 3 and Finding 4 repairs:

```text
--filter=test_lower_town_slice_map,test_kalev_smithy_map,test_burgher_house_tiers,
         test_map_object_chunk_streaming,test_map_terrain_chunks,test_large_map_chunk_prototype,
         test_vertical_slice_performance,test_performance_benchmark,test_urban_population_performance_cap
Godot headless tests: 9 file(s), 69 test(s), 0 failure(s), 0 error(s).
```

Clean-`HEAD` attribution used a detached worktree plus a full import pass, because a fresh worktree has no global script class cache and would otherwise report false parse errors:

```bash
git worktree add /tmp/r490_clean HEAD
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp/r490_clean --import
```

## Closeout and handoff

R-490 delivers the gate result; the gate itself is **BLOCKED**. Fixed in this task: the stale chunk-ownership baseline (Finding 3) and the runtime load breakage (Finding 4). Remaining owners:

1. **P3-011 / performance owner** - resolve the `lower_town_scene` resident node count (8472/7500) and resident memory (446.2/280 MiB) overage, or re-authorize the budgets with evidence. Blocks P0-101 clause 6.
2. **Camera owner** - fix the six `test_map_camera_modes` follow-boom, building-pull-out and eye-height assertions. Blocks P0-101 clause 6 and any route capture work in R-491.
3. **CI owner** - add a clean-checkout parse/load gate so a formatting pass can never again delete executable code without a red build.
4. **R-491 / R-492** - unchanged; matched captures and human silhouette review remain their blockers.
5. **R-108** - parent stays open.

Not measured by this gate and still open for whoever needs GPU evidence: non-headless draw-call attribution through `tools/benchmarks/lower_town_render_probe.tscn`, and any run on the declared minimum hardware profile.

## Sources

- [`tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`](../../tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json)
- [`tests/godot/test_map_object_chunk_streaming.gd`](../../tests/godot/test_map_object_chunk_streaming.gd)
- [`tests/godot/test_map_camera_modes.gd`](../../tests/godot/test_map_camera_modes.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json) - budget limits
- [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md) - repeatable benchmark contract
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) - R-493 parent acceptance gate
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - R-491 capture contract
