# Lower Town P0-101 Runtime, Route, Occlusion and Budget QA

**Task:** R-490 / P0-101e
**Parent:** R-108 / P0-101
**Maps:** `lower_town_slice` (Workers' District) and `kalev_smithy`
**Verification date:** 2026-08-12; current reconciliation 2026-09-01
**Engine:** Godot 4.7.1.stable.official (a13da4fe)
**Measurement host:** macOS, Apple M5 Pro, 18 logical cores, headless (`development-baseline-m5-pro`, `development_baseline_not_minimum`)
**Worktree:** shared worktree contains unrelated concurrent WIP. Every historical failure in this report was re-checked against a clean `git worktree` checkout of `HEAD` before being attributed.
**Decision:** **BLOCKED - clause 6 of P0-101 does not pass.** Routes, collision, navigation, chunk ownership and frame-time budgets are green; resident node/memory budgets fail, and the current clean-checkout runtime gate remains blocked by the RRMap elevation parser. The camera implementation has a current green assertion result in the live imported worktree, but the parser errors prevent independent camera certification.

## Scope and method

R-490 is the runtime gate for P0-101 clause 6: routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures and performance budgets. It does not author art, does not judge silhouettes and does not produce acceptance captures; those stay with R-487/R-488/R-489 (implementation) and R-491/R-492 (visual and human review).

Because the shared worktree is dirty, every red result was reproduced in `/tmp/r490_clean`, a detached worktree at `HEAD` with a full `--import` pass. Failures that reproduce there are real repository state; failures that only appear in the dirty worktree would be concurrent WIP and are not attributed to this gate. No such WIP-only failure was found.

All Godot commands ran through `tools/run_godot_checked.sh --require-test-summary`, which fails on any engine, script, parser or resource error outside the documented DEF-002 shutdown allowlist.

## Current status reconciliation (2026-09-01)

The original 2026-08-12 matrix below is retained as historical evidence. A current rerun from `HEAD=a317cfdd` changes the camera and clean-load attribution without changing the P0-101 decision:

- `test_map_camera_modes` was run in the imported live worktree with `tools/run_godot_checked.sh --require-test-summary r490-camera-current -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes`. The harness discovered 1 file and 11 tests, with **0 assertion failures and 35 engine/script errors**. The first errors are `unknown_command` for `elevation_area` at `lower_town_slice.rrmap` lines 14, 20, and 22 and `elevation_ramp` at line 17, followed by an invalid `MapDefinition`. Camera assertions are therefore not independently measurable in this run.
- `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/verify_clean_checkout_load.sh` completed detached checkout creation and Godot import, then failed in the bounded load stage with **4 files, 70 tests, 49 failures, and 196 errors**. The first substantive product diagnostics are the same four unsupported elevation commands; later landmark/null-node errors are dependent cascades. This reproduces the parser boundary from a clean checkout and is not a dirty-worktree artifact.
- The camera implementation and focused live-worktree result are owned by **R-577**; the clean-baseline parser dependency remains owned by **R-453/R-455**, with parser/load verification tracked by **R-604**. **R-562** already provides the CI/local clean-checkout gate, so this report does not add a duplicate gate.

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
| Camera occlusion, building pull-out and follow boom | **BLOCKED by parser baseline at current `HEAD`** | Historical 2026-08-12 run recorded 6 placement failures; after R-577, the 2026-09-01 run reaches 11 tests with 0 assertion failures but 35 engine/script errors from the shared `elevation_area` / `elevation_ramp` parser blocker; see [Current status reconciliation](#current-status-reconciliation-2026-09-01) and [Finding 2](#finding-2-camera-placement-evidence-is-blocked-by-the-current-parser-baseline) |
| Runtime loads from a clean checkout | **FAIL at current `HEAD`** | R-562 gate completes import, then fails bounded MapView3D load with 4 files, 70 tests, 49 failures, and 196 errors; first substantive diagnostic is unsupported `elevation_area` / `elevation_ramp`; see [Finding 4](#finding-4-release-blocking-runtime-load-breakage-at-head-superseded-by-the-parser-blocker) |

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

### Finding 2: Camera placement evidence is blocked by the current parser baseline

The historical 2026-08-12 run recorded 6 assertions failing across 4 of 11 camera tests. That result remains useful as the pre-R-577 baseline, but it is no longer the current camera result: R-577's implementation note reports the focused camera contract green in the imported live worktree.

The current 2026-09-01 checked run discovers all 11 camera tests and reports **0 assertion failures**, but it also reports **35 engine/script errors** before the map-backed camera setup can complete. The first diagnostics are the unsupported `elevation_area` and `elevation_ramp` commands in `content/maps/lower_town_slice.rrmap`, followed by invalid-map-definition errors. This run cannot certify the camera contract, and its parser errors must not be misreported as new camera regressions.

The camera implementation remains owned by **R-577**. Once **R-453/R-455** land the parser/compiler support and **R-604** re-runs the clean load gate, R-490 should rerun `test_map_camera_modes` and the companion camera suite from a clean imported checkout. No camera behavior or assertion was changed by this QA refresh.

### Finding 3: Stale reviewed chunk-ownership baseline (resolved)

`test_map_object_chunk_streaming::test_playable_slice_boundary_warnings_have_reviewed_production_ownership` failed for both playable slices on clean `HEAD`. The guard exists to force a human review of any change to chunk-boundary ownership, so this gate performed that review rather than only reporting it.

Reviewed drift in `tests/fixtures/maps/object_chunk_streaming_readiness_p0_067c.json`:

- `lower_town_slice`: 22 of 71 records changed, all `cell_rect` width only. They are precisely the plots narrowed by commit `0fc855b5` ("Separate overlapping Workers' District building footprints", 2026-07-27), which shrank the western/northern plot of each overlapping pair so roof overhangs stopped interpenetrating. That commit regenerated `lower_town_slice.parity.json` but not this baseline.
- `kalev_smithy`: `excluded.000` became `excluded.001` with an identical rect, because commit `cecc94a7` ("Keep smithy wake spawn outside bed") inserted `exclude blocked.bed` ahead of `exclude blocked.fore`.

No `owner_chunk`, `consumer_chunks`, `residency` or `kind` value changed, and no record was added or removed. Chunk ownership and streaming residency are therefore unaffected; only the recorded geometry was stale. The substantive assertions in the same test - owner is the lexicographically smallest consumer, every subject appears exactly once per consumer chunk, transitions stay persistent, exclusions stay baked into blocked navigation - passed both before and after.

The baseline was regenerated from the clean `HEAD` worktree, not from the dirty shared worktree, so concurrent WIP in the compiler and rrmap parser could not contaminate it. Verified green afterwards in both the clean worktree and the shared worktree.

### Finding 4: Release-blocking runtime load breakage at `HEAD` (superseded by the parser blocker)

The historical 2026-08-12 clean-checkout run found two files left syntactically or semantically broken by commit `c1da164b` (the 342-file reformat): `map_view_runtime_camera.gd` had a deleted `get:` body and `map_view_monastic_models.gd` had deleted local declarations. Those four lines were restored in the original R-490 closeout and are retained in history here.

The current `HEAD` includes those repairs and R-562's clean-checkout gate. On 2026-09-01 the gate completed detached checkout creation and the full Godot import, so the earlier reformat/import blocker is no longer the first failure. The bounded MapView3D smoke then failed with **4 files, 70 tests, 49 failures, and 196 errors**. The first substantive product diagnostics are the four unsupported `elevation_area` / `elevation_ramp` commands in `content/maps/lower_town_slice.rrmap` lines 14, 17, 20, and 22. The later invalid map-definition, landmark dictionary, and null-node errors are dependent cascades, not separate R-490 defects.

This remains a release blocker, but ownership is now explicit: **R-453/R-455** own elevation parser/compiler support, and **R-604** owns the clean-load rerun. R-562 already provides the CI/local gate that prevents this failure from being hidden by the shared dirty worktree. R-490 does not modify the parser or map source.

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

# Camera contract (historical baseline; current rerun is recorded above)
tools/run_godot_checked.sh --require-test-summary r490-camera -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_camera_modes
# Historical 2026-08-12 result: 1 file(s), 11 test(s), 6 failure(s).
# Current 2026-09-01 result: 1 file(s), 11 test(s), 0 assertion failures, 35 engine/script errors.
```

Consolidated historical re-run of every in-scope suite after the Finding 3 and Finding 4 repairs:

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

R-490 delivers the gate result; the gate itself is **BLOCKED**. Fixed or superseded since the original run: the stale chunk-ownership baseline (Finding 3), the reformat-induced runtime load breakage (historical Finding 4), and the six camera placement assertions (R-577). Remaining owners:

1. **P3-011 / performance owner** - resolve the `lower_town_scene` resident node count (8472/7500) and resident memory (446.2/280 MiB) overage, or re-authorize the budgets with evidence. Blocks P0-101 clause 6.
2. **R-453/R-455 elevation owners, with R-604 verification** - land parser/compiler support for `elevation_area` / `elevation_ramp`, then rerun the clean-checkout MapView3D load and camera suites. The current clean gate remains blocked by this first parser diagnostic.
3. **R-577 camera owner** - preserve the current camera fix and provide the post-parser clean imported rerun; the current live run has 0 assertion failures but cannot certify camera behavior while engine errors interrupt map-backed setup.
4. **R-562 / CI gate** - already resolved: the clean-checkout parse/load gate is present and referenced by CI; it correctly catches the current parser failure.
5. **R-491 / R-492** - unchanged; matched captures and human silhouette review remain their blockers.
6. **R-108** - parent stays open.

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
