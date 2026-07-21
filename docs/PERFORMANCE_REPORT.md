# Repeatable performance report

Task: `P1-030`  
Performance scene: `res://tools/benchmarks/lower_town_scene_benchmark.tscn`  
Generated reports: `build/benchmarks/` (ignored; do not commit raw host-specific runs)

## Command

Run the full report from the repository root:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh
```

For a short instrumentation smoke:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh build/benchmarks/performance-smoke.json --quick
```

`GODOT_BIN` defaults to `godot`. `TARGET_HARDWARE` may point to another JSON profile with the same required fields as `tools/benchmarks/target_hardware.json`:

```bash
TARGET_HARDWARE=/absolute/path/to/minimum-hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/benchmarks/minimum-hardware.json
```

The command exits nonzero when the target profile is missing or invalid, either Godot phase fails, or the report cannot be written. It prints the output path and a one-line summary with target profile, frame-time p95, static memory, and actor count.

## What the report measures

The command has two phases so the performance scene runs with normal project autoloads and the complete production `_ready` chain:

1. `lower_town_scene_benchmark.tscn` instances the real `scenes/reval_east/reval_east.tscn` Lower Town scene and samples startup, frame intervals, memory, node/collision counts, and actors.
2. `large_map_benchmark.tscn` records the production map pipeline and synthetic scale profiles, merges the Lower Town scene sample, and writes one JSON report.

The top-level `headline` summarizes the production Lower Town profile:

- `frame_time_ms_p95` - wall-clock interval between `SceneTree.process_frame` signals;
- `memory_static_bytes` and `memory_delta_mib` - Godot `Performance.MEMORY_STATIC` observations;
- `actor_count` - `CharacterBody2D` / `CharacterBody3D` descendants of the production scene's authoritative `Actors` branch.

The raw `profiles` section retains per-run distributions, node/collision counts, startup and pipeline timings, semantic counts, and existing map-budget observations.

## Hardware identity and interpretation

`target_hardware` is the declared machine profile for which the run is intended. `measurement_host` is what Godot detects at runtime. They are intentionally separate so a report made on a fast developer machine cannot be mistaken for minimum-hardware proof.

The committed profile, `development-baseline-m5-pro`, records the current reproducible development baseline. Its status is `development_baseline_not_minimum`. It is not a supported-platform or minimum-hardware declaration. P3-011 owns selection of the actual minimum target and its release budgets.

Headless runs use the dummy renderer. They are valid for deterministic command smoke, CPU-side scene/pipeline timings, memory, actor/node/collision counts, and regression evidence, but not for target-GPU acceptance. Before using frame time for P0-038 or P3-011 acceptance, run the full command non-headlessly on the declared target and retain the generated JSON as release evidence outside source Git.
