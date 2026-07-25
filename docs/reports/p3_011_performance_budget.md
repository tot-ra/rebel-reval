# P3-011 vertical-slice performance budget

Task: **P3-011**  
Date: 2026-07-25  
Reviewer: maintainer (authorial acceptance per [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md))

## Declared minimum hardware

Profile: `minimum-hardware-intel-uhd-620` (`tools/benchmarks/minimum-hardware.json`)

| Field | Value |
| --- | --- |
| CPU | Intel Core i5-8250U, 4 cores / 8 threads |
| GPU | Intel UHD Graphics 620 |
| Memory | 8 GiB shared |
| Display | 1920x1080 |
| API | OpenGL 4.5 / Vulkan 1.0 |

This is the representative 2017-2018 budget-laptop target for the vertical-slice release. It is not the development baseline.

## Busiest shipped scene

`scenes/reval_east/reval_east.tscn` (`lower_town_scene` benchmark profile)

The Lower Town exterior is the densest player-facing scene in the slice: full 3D district view, patrol hosts, ambient birds, weather, and every active quest route.

## Authored headless budgets

Source of truth:

- `scripts/slice/vertical_slice_performance_model.gd`
- `docs/data/slice_performance_manifest.json`
- `tools/benchmarks/large_map_benchmark_config.json`

| Metric | Limit | 2026-07-25 dev capture | Headroom |
| --- | ---: | ---: | ---: |
| Frame time p95 (ms) | 16.67 | 8.261 | 50.4% |
| Memory delta (MiB) | 280.0 | 215.37 | 23.1% |
| Node count | 7500 | 6340 | 15.5% |
| Collision count | 900 | 148 | 83.6% |
| Bird audio peak | 3 | 1 | 66.7% |
| Bird flight peak | 4 | 1 | 75.0% |

Capture command:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh build/benchmarks/performance-smoke.json --quick
```

Verification:

```bash
python3 tools/report_slice_performance.py --check
python3 tools/report_slice_performance.py --check --report build/benchmarks/performance-smoke.json
python3 -m unittest tests.python.test_report_slice_performance -v
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_vertical_slice_performance
```

## Optimizations landed for this gate

1. `MapViewStaticBatcher` merges static architectural trim into one mesh per material.
2. `trim_small_shadow_casters` removes shadow casting from slim trim that does not read in gameplay.
3. Backdrop dressing strips particles, lights, and shadow casting from non-playable silhouettes.

GPU render probe on the development baseline (non-headless, gl_compatibility) improved the workers district from ~77.8 ms / 15 933 draw calls to ~25.3 ms / 1 789 draw calls after the batching and shadow-trim pass documented in `docs/PERFORMANCE_REPORT.md`.

## Acceptance split

| Layer | Evidence | Status |
| --- | --- | --- |
| Headless CI slice gates | `tools/run_map_pipeline_ci.sh benchmark-smoke` plus `report_slice_performance.py --check --report ...` | Pass on 2026-07-25 development baseline |
| GPU minimum-hardware proof | Non-headless `tools/run_performance_report.sh` with `BENCHMARK_HEADLESS=0` and `TARGET_HARDWARE=tools/benchmarks/minimum-hardware.json` | Required before P3-012 platform declaration; retain generated JSON outside source Git |

Headless runs use the dummy renderer. They are valid for deterministic CPU-side regression and memory/node/collision budgets, but not for Intel UHD 620 GPU frame-time acceptance.

## Result

**Pass (repository-side slice gate).** The busiest shipped scene sustains the recorded frame-time, memory, node, collision, and ambient-fauna budgets with headroom on the 2026-07-25 development-baseline capture. Minimum-hardware GPU proof remains an export/platform follow-up owned by **P3-012**.
