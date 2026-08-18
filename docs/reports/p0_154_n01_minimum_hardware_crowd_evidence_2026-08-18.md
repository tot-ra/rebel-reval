# P0-154-N01 minimum-hardware crowd evidence

- **Task:** R-575 / P0-154-N01
- **Run date:** 2026-08-18
- **Decision:** **BLOCKED for declared minimum-hardware acceptance; crowd budget checks PASS on a non-target development host.**

## Procedure

The task command was executed from the repository root with the declared Intel UHD 620 profile and a real renderer:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-p0154
TARGET_HARDWARE=tools/benchmarks/minimum-hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh \
  build/benchmarks/performance-minimum-hardware.json --quick
```

The raw report is retained locally at `build/benchmarks/performance-minimum-hardware.json`. It is ignored by Git because host-specific benchmark JSON must not be committed as source evidence.

## Hardware boundary

| Evidence field | Declared target | Measured host |
| --- | --- | --- |
| Profile | `minimum-hardware-intel-uhd-620` | `development-baseline-m5-pro` equivalent host |
| CPU/GPU | Intel Core i5-8250U / Intel UHD Graphics 620 | Apple M5 Pro, MacBook Pro `Mac17,8` |
| Memory / platform | 8 GiB, Linux or Windows | 48 GiB, macOS |
| Renderer | Real non-headless device required | Godot 4.7.1, OpenGL 4.1 Metal Compatibility |

The `TARGET_HARDWARE` field correctly records the Intel UHD 620 declaration, but it does not emulate that device. This run is real renderer evidence only and cannot close the physical minimum-hardware requirement.

## Crowd benchmark result

| Metric | Observed | Budget | Result |
| --- | ---: | ---: | --- |
| Active characters | 200 / 200 target | 200 cap | PASS |
| Frame time p95 | 4.922 ms | 16.67 ms | PASS |
| Peak draw calls | 1 | 3 | PASS |
| Delta memory | 3.67417144775391 MiB | 96 MiB | PASS |
| `within_budget` | `true` | - | PASS |

The isolated `crowd_character_peak` profile therefore has non-zero draw-call evidence and passes all authored crowd frame, draw-call, and memory checks.

## Non-crowd observations

The same report also contains the production Lower Town and synthetic pipeline phases. On this M5 host, the production Lower Town phase reports 194.119 ms frame-time p95 and 9008 nodes, both over their general authored budgets. Synthetic navigation profiles also report existing budget failures. These observations are recorded for reproducibility but are not reclassified as crowd benchmark failures and do not prove Intel UHD 620 acceptance.

The run emitted a warning for `Patrol_viru_watch` without a rig scene and Compatibility shutdown leak diagnostics. The command nevertheless completed, wrote the report, and produced the crowd profile above.

## Follow-up

Run the same command on an actual Intel UHD 620-class Linux or Windows host. Replace this blocked evidence with the target measurement only after `measurement_host` identifies the declared GPU and the crowd frame, draw-call, and memory checks remain green.

Sources: [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json), [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md), [`tools/benchmarks/run_large_map_benchmark.sh`](../../tools/benchmarks/run_large_map_benchmark.sh).
