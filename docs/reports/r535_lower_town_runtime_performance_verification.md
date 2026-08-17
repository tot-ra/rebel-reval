# R-535 Lower Town Runtime and Performance Gate

**Task:** R-535 / P0-101 runtime and performance verification
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Snapshot:** `0b9401f6aec0137961a059df44a51f8943988477`
**Engine:** Godot 4.7.1.stable.official
**Measurement host:** macOS, Apple M5 Pro, 18 logical cores; headless for the CPU/memory report and non-headless for the GPU probe
**Declared target profile:** `development-baseline-m5-pro`, status `development_baseline_not_minimum`
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. No runtime, map, fixture, budget, or test source was changed for this verification.
**Decision:** **BLOCKED - P0-101 clause 6 is not green.** The focused authored contracts and CPU frame-time gate pass, but the clean-checkout MapView3D load is blocked by RRMap parser errors, camera placement tests fail, resident node and memory budgets are over limit, and the GPU probe is not minimum-hardware evidence.

## Scope and evidence boundary

R-535 is verification-only. It reruns the R-490 runtime/performance evidence without changing camera or runtime code, map parser behavior, fixtures, budget limits, or hardware declarations. A headless pass proves only deterministic CPU-side contracts and instrumentation; it does not prove target-GPU performance. A non-headless run on the development Mac is supplementary renderer evidence and cannot satisfy minimum-hardware acceptance.

The report keeps the clean-checkout result separate from the current shared worktree. The clean gate restored runtime LFS inputs and completed import before the MapView3D load stage. The generated JSON under `build/benchmarks/` is host-specific and ignored; its values are transcribed here as evidence, not committed as a release baseline.

## Result matrix

| Area | Result | Evidence |
|---|---|---|
| Lower Town and Kalev Smithy map contracts | **PASS** | Focused map-contract suite: **40/40** tests, 0 failures, 0 errors |
| Chunk residency, streaming and ownership | **PASS** | Focused chunk/streaming suite: **21/21** tests, 0 failures, 0 errors |
| Authored performance contracts | **PASS** | Focused performance suite: **9/9** tests, 0 failures, 0 errors |
| Slice performance report | **PASS** | `python3 tools/report_slice_performance.py` |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py` |
| Clean checkout, LFS restore and import | **PARTIAL** | 37 LFS objects restored; clean import completed |
| Clean-checkout MapView3D load | **BLOCKED** | `elevation_area` / `elevation_ramp` parser errors; bounded run reports **41 failures / 193 errors** |
| Camera placement and follow boom | **FAIL** | `test_map_camera_modes`: **11 tests, 6 failures** |
| Lower Town production scene frame time | **PASS** | p95 **7.607 ms** against **16.67 ms** limit |
| Lower Town production scene resident node count | **FAIL** | **8,489** against **7,500** limit |
| Lower Town production scene resident memory | **FAIL** | **439.3 MiB** against **280 MiB** limit |
| Collision and ambient bird peaks | **PASS** | 172 collisions, bird audio peak 1, bird flight peak 1; limits 900, 3 and 4 |
| Non-headless GPU probe | **SUPPLEMENTARY / NOT ACCEPTANCE** | 2,518 draw calls, 2,932,008 primitives, 18 FPS; development hardware only |

## Verification commands and results

All Godot checks used the checked runner with `--require-test-summary`; the runner rejects parser, script, resource and unexpected engine errors outside the documented shutdown-only allowlist.

### Focused authored suites

```bash
tools/run_godot_checked.sh --require-test-summary r535-map-contracts -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map,test_kalev_smithy_map,test_burgher_house_tiers
# 40/40 tests, 0 failures, 0 errors

tools/run_godot_checked.sh --require-test-summary r535-chunk-streaming -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_object_chunk_streaming,test_map_terrain_chunks,test_large_map_chunk_prototype
# 21/21 tests, 0 failures, 0 errors

tools/run_godot_checked.sh --require-test-summary r535-performance -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_vertical_slice_performance,test_performance_benchmark,test_urban_population_performance_cap
# 9/9 tests, 0 failures, 0 errors

python3 tools/report_slice_performance.py
# valid report and slice gates

python3 tools/verify_asset_lint.py
# asset lint passed
```

The map and streaming suites are green within their authored contracts. They do not waive the runtime load, camera, resident-cost, or minimum-hardware blockers below.

### Camera suite

```bash
tools/run_godot_checked.sh --require-test-summary r535-camera -- \
  "$GODOT" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_camera_modes
# 11 tests, 6 failures
```

The failing assertions remain in the known follow-boom and eye-height family:

- `test_building_collision_pulls_camera_out` - follow camera is not pulled out of a building AABB;
- `test_c_cycles_third_person_first_person_and_top_down` - first-person camera does not reach eye height;
- `test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character` - third-person pitch does not preserve follow-boom distance;
- `test_third_person_scroll_zoom_clamps_and_enters_first_person` - restored boom distance and zoom-entered first-person eye height do not satisfy the contract.

These failures are repository-state regressions, not changes introduced by R-535. Camera/runtime owners must repair them; this verification does not modify camera code.

### Clean-checkout load gate

```bash
GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot \
  tools/verify_clean_checkout_load.sh
# detached checkout: pass
# runtime LFS restore: pass, 37 objects
# clean import: pass
# MapView3D load: blocked
```

The first product diagnostics are the existing RRMap parser failures:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

The dependent bounded MapView3D run reports 41 failures and 193 errors. Those downstream map/view diagnostics are not reclassified as independent R-535 defects. The parser/elevation owners are R-453 / R-455.

### CPU and resident-cost report

```bash
GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh build/benchmarks/r535-lower-town.json
```

The report was recorded at `2026-08-17T21:35:51Z` from commit `0b9401f6aec0137961a059df44a51f8943988477`. Its `lower_town_scene` production profile measured:

| Metric | Observed | Budget | Result |
|---|---:|---:|---|
| `frame_time_ms_p95` | 7.607 ms | 16.67 ms | **PASS** |
| `node_count` | 8,489 | 7,500 | **FAIL** |
| `memory_delta_mib` | 439.3 MiB | 280 MiB | **FAIL** |
| `collision_count` | 172 | 900 | **PASS** |
| `bird_audio_peak` | 1 | 3 | **PASS** |
| `bird_flight_peak` | 1 | 4 | **PASS** |

The `lower_town_pipeline` profile remains inside the CPU-side limits, including 2,246 nodes, 15.3 MiB memory delta, and 7.975 ms frame-time p95. The overage is in the assembled production scene and must not be hidden by raising the authored budgets.

The report is headless on the development baseline. It is valid for CPU-side timings and resident accounting, but it is not target-GPU acceptance evidence.

### Non-headless GPU probe

The render probe was run through `tools/benchmarks/lower_town_render_probe.tscn` on the Apple M5 Pro development machine. It recorded:

| Metric | Observed | Interpretation |
|---|---:|---|
| Peak draw calls | 2,518 | renderer evidence only |
| Peak primitives | 2,932,008 | renderer evidence only |
| Median frame time | 54.647 ms | approximately 18 FPS on this run |
| p95 frame time | 59.865 ms | not a minimum-target result |
| Video memory | 610.9 MiB | development-host measurement |

The committed target profile explicitly says `development_baseline_not_minimum`. The probe therefore demonstrates a renderer cost signal, but it does not establish support or acceptance on the declared minimum hardware. R-563 remains the follow-up for minimum-hardware GPU evidence.

## Blockers and ownership

1. **R-453 / R-455** - register and validate `elevation_area` and `elevation_ramp` in the RRMap parser and elevation acceptance path, then rerun the clean-checkout MapView3D load gate.
2. **Camera/runtime owner** - repair the six `test_map_camera_modes` follow-boom, building pull-out and first-person eye-height failures.
3. **P3-011 / performance owner** - reduce the production scene's 8,489 resident nodes and 439.3 MiB memory delta to the existing 7,500-node and 280-MiB limits, or obtain an explicit evidence-backed budget decision. Do not raise limits silently.
4. **R-563** - run the renderer probe on the actual minimum hardware profile. The Apple M5 Pro run cannot close this requirement.

R-535 remains **BLOCKED** and must not be marked as a P0-101 clause-6 pass. The green authored contracts are useful regression evidence, but they cannot override the clean-load, camera, resident-cost, and hardware boundaries.

## Sources

- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md) - R-490 baseline and historical blocker attribution
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md) - R-562 clean-checkout procedure and parser evidence
- [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
- [`tools/run_performance_report.sh`](../../tools/run_performance_report.sh)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json) - authored budgets
- [`tools/benchmarks/lower_town_render_probe.tscn`](../../tools/benchmarks/lower_town_render_probe.tscn)
- [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md) - performance and GPU-probe contract
- [`tools/benchmarks/target_hardware.json`](../../tools/benchmarks/target_hardware.json) - development target declaration
