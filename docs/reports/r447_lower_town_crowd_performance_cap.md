# R-447 Lower Town crowd performance-cap measurement

**Task:** R-447
**Verification date:** 2026-08-18
**Engine:** Godot 4.7.1.stable.official
**Host:** macOS arm64, Apple M5 Pro development machine

## Scope

This report measures the deterministic crowd-renderer cap used by the Lower Town population workload and the isolated Tier-2 MultiMesh crowd path. It does not replace the minimum-hardware GPU acceptance owned by the vertical-slice performance gate.

## Results

### Authored Lower Town population workload

The published R-419 scenarios remain below the Lower Town renderer capacity of 64 instances:

| Scenario | Active actors | Capacity | Headroom |
| --- | ---: | ---: | ---: |
| Ordinary day | 21 | 64 | 43 |
| Market day | 33 | 64 | 31 |
| Night checkpoint | 12 | 64 | 52 |

The largest authored Lower Town scenario therefore uses 33 of 64 registered instances. The profile-cap and renderer-cap assertions passed for every scenario.

### Isolated Tier-2 crowd measurement

The production `MapViewCrowdRenderer` was exercised with the authored benchmark target of 200 characters and a hard cap of 200. The benchmark used 30 warm-up frames and 120 sampled frames with seed 154 and 1.35 m formation spacing.

| Metric | Observed | Budget / contract | Result |
| --- | ---: | ---: | --- |
| Active characters | 200 | 200 target | PASS |
| Renderer capacity | 200 | 200 cap | PASS |
| Frame-time median | 6.899 ms | informational | recorded |
| Frame-time p95 | 8.115 ms | 16.67 ms | PASS (headless CPU evidence) |
| Frame-time p99 | 8.445 ms | 25.00 ms | PASS (headless CPU evidence) |
| Frame-time max | 8.605 ms | informational | recorded |
| Static memory delta | 6.380 MiB | 96 MiB | PASS |
| Draw calls | 0 | 3 peak | not measured by headless dummy renderer |

The measured density was `0.548696844993141` characters per square metre. The raw benchmark output is host-specific and was kept under `/tmp/rebel-reval-r447/crowd.json` rather than committed.

## Verification commands

Focused Lower Town capacity contract:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r447
tools/run_godot_checked.sh --require-test-summary r447-capacity -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_urban_population_performance_cap
# 1 file, 2 tests, 0 failures, 0 errors
```

Focused performance contract:

```sh
tools/run_godot_checked.sh r447-performance -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_performance_benchmark
# 1 file, 5 tests, 0 failures, 0 errors
```

Isolated production crowd benchmark:

```sh
tools/run_godot_checked.sh r447-crowd-benchmark -- \
  "$GODOT_BIN" --headless --path . \
  --script res://tools/benchmarks/battle_scene_baseline.gd -- \
  --output=/tmp/rebel-reval-r447/crowd.json
# target 200/200; p95 8.115 ms; memory delta 6.380 MiB
```

The checked runner reported only the documented shutdown resource-leak diagnostic from the performance-contract process. No parser, script, resource-loading, or unexpected engine error occurred.

## Decision and evidence boundary

**PASS for the deterministic Lower Town crowd-cap contract and isolated CPU-side measurement.** The authored population scenarios fit the 64-instance Lower Town capacity, and the Tier-2 renderer reaches its 200-character benchmark target without exceeding the authored CPU or memory budgets.

The headless renderer reports zero draw calls because no GPU frame is submitted by the dummy renderer. That value is not GPU acceptance evidence. Minimum-hardware GPU frame time and draw-call evidence remain outside this task and must be supplied by the existing vertical-slice performance owner before release acceptance.

## Sources

- [`r419_lower_town_population_clusters.md`](r419_lower_town_population_clusters.md) - authored scenario and capture contract
- [`r420_urban_population_performance_cap.md`](r420_urban_population_performance_cap.md) - profile and 64-instance capacity assertions
- [`population_clusters_r419.json`](population_clusters_r419.json) - machine-readable scenario inputs
- [`../../tests/godot/test_urban_population_performance_cap.gd`](../../tests/godot/test_urban_population_performance_cap.gd)
- [`../../tests/godot/test_performance_benchmark.gd`](../../tests/godot/test_performance_benchmark.gd)
- [`../../tools/benchmarks/battle_scene_baseline.gd`](../../tools/benchmarks/battle_scene_baseline.gd)
- [`../../tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)
