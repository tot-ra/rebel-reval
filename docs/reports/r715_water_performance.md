# R-795 water performance verification

- Task: `R-795`
- Parent: `R-715`, reflective water rollout across authored maps
- Upstream measurement owner: `R-755`
- Recorded UTC: `2026-08-29`
- Status: **BLOCKED - the evidence contract is valid, but R-755 water-specific measurements are unavailable**
- Recommendation: **BLOCKED**

## Decision boundary

This is an independent performance-evidence ledger. It does not change water shaders, materials, map data, weather state, benchmark settings, capture output, or the status of R-715. It distinguishes water-owned budgets from generic scene budgets and keeps the declared target hardware separate from the machine that performs a measurement.

A `BLOCKED` row is a valid fail-closed artifact state, not a performance pass. The normal verifier checks that this state is represented honestly. Strict acceptance mode rejects the current report until R-755 supplies host-identified, non-headless measurements for both tiers.

The existing R-756 packet remains a visual-capture boundary. Its 130-plate matrix does not provide performance measurements. R-529's Monastery east-ditch regression and R-713's sky/weather acceptance remain external blockers and are not duplicated here.

## Water-only tier budget contract

These thresholds are allocations for the water presentation layer, not limits for the complete scene. They cover only the cost levers owned by water: shader detail, reflection/refraction sampling, shoreline detail, frame time, draw/resource counts, and water allocation memory.

| Water budget | `minimum` | `recommended` | Scope |
|---|---:|---:|---|
| Procedural/detail layers | 1 | 2 | Water shader detail layers |
| Reflection samples | 1 | 2 | Water reflection sampling |
| Refraction samples | 1 | 2 | Water refraction/depth sampling |
| Foam/shore detail | 0.50 | 1.00 | Shoreline foam/detail multiplier |
| Water frame-time p95 | 1.50 ms | 2.50 ms | Incremental water presentation cost |
| Water draw calls peak | 2 | 4 | Water-owned draw-call allocation |
| Water resource count peak | 4 | 8 | Water-owned material/texture/resource allocation |
| Water memory delta | 8 MiB | 24 MiB | Water-owned allocation, not process memory |
| Compatibility fallback | `compatibility_water_surface` | `compatibility_water_surface` | Declared for every tier |

The `steady_frame_time_ms_p95`, `resident_memory_delta_mib`, `resident_node_count`, and other generic scene budgets from `large_map_benchmark_config.json` are not substitutes for these values. The generic config is retained only as a comparison reference.

## Target and measurement-host matrix

| Tier | Declared target hardware | Measurement host | Renderer | Samples | Observed water metrics | Result |
|---|---|---|---|---:|---|---|
| `minimum` | `minimum-hardware-intel-uhd-620`: Intel Core i5-8250U / Intel UHD Graphics 620 / x86_64 / 8 GiB; [`minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json) | **Not measured**. The available Apple M5 Pro host cannot certify Intel UHD 620 | **Not measured**; a headless run is not accepted | - | **BLOCKED**; frame, draw, resource, and memory observations are null | **BLOCKED**; owner `R-755` |
| `recommended` | `development-baseline-m5-pro`: Apple M5 Pro / arm64 / 48 GiB; [`target_hardware.json`](../../tools/benchmarks/target_hardware.json) | **Not measured for isolated water tier**. Generic/development observations are not water attribution | **Not measured** | - | **BLOCKED**; no isolated water observations retained | **BLOCKED**; owner `R-755` |

The minimum row is intentionally not relabeled from the supplementary Apple M5 Pro evidence in [`r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md`](r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md). A development host is not an emulator for the Intel target. The recommended row also remains blocked because a generic scene report does not isolate the water tier.

## Fallback contract

Both tiers declare `compatibility_water_surface`. When screen/depth inputs or real-renderer reflection resources are unavailable, the surface keeps a water-like base color, Fresnel response, bounded refraction UV, and animated/detail normal path. The fallback does not mutate terrain, collision, navigation, weather state, or saved gameplay state. A renderer fallback is an evidence field, not permission to silently claim the high-quality tier.

## Machine-readable evidence

The JSON block is the source consumed by [`verify_r715_water_performance.py`](../../tools/verify_r715_water_performance.py). It is deliberately complete for blocked rows: missing measurements are represented by `null`, not omitted. `--strict` is the acceptance check for a future R-755 fixture and must fail against this report until both host-identified rows are measured.

```json
{
  "schema_version": 1,
  "report_id": "r715-water-performance-v1",
  "owner_task": "R-795",
  "upstream_owner": "R-755",
  "budget_scope": "water_only",
  "recommendation": "BLOCKED",
  "source": {
    "owner_task": "R-755",
    "generic_scene_config": "tools/benchmarks/large_map_benchmark_config.json",
    "generic_scene_budget_use": "comparison_only",
    "expected_water_outputs": [
      {
        "tier": "minimum",
        "path": "build/benchmarks/r715-water-minimum.json",
        "status": "blocked",
        "blocker": "R-755"
      },
      {
        "tier": "recommended",
        "path": "build/benchmarks/r715-water-recommended.json",
        "status": "missing",
        "blocker": "R-755"
      }
    ]
  },
  "tiers": [
    {
      "id": "minimum",
      "status": "BLOCKED",
      "owner": "R-755",
      "budget_scope": "water_only",
      "target_hardware": {
        "profile_id": "minimum-hardware-intel-uhd-620",
        "architecture": "x86_64",
        "gpu": "Intel UHD Graphics 620 (24 EUs, ~300 GFLOPS)"
      },
      "measurement_host": {
        "status": "not_measured",
        "profile_id": "",
        "architecture": "",
        "gpu": ""
      },
      "renderer": {
        "status": "not_measured",
        "method": "",
        "driver": "",
        "headless": null
      },
      "thresholds": {
        "detail_layers": 1,
        "reflection_samples": 1,
        "refraction_samples": 1,
        "foam_shore_detail": 0.5,
        "frame_time_ms_p95": 1.5,
        "draw_calls_peak": 2,
        "resource_count_peak": 4,
        "memory_delta_mib": 8
      },
      "fallback": {
        "id": "compatibility_water_surface",
        "declared": true,
        "renderer_safe": true,
        "behavior": "Keep water-like base, Fresnel, bounded refraction, and detail normal when screen/depth inputs are unavailable."
      },
      "measurement": {
        "status": "unmeasured",
        "samples": null,
        "metrics": {
          "frame_time_ms_p95": null,
          "draw_calls_peak": null,
          "resource_count_peak": null,
          "memory_delta_mib": null
        }
      }
    },
    {
      "id": "recommended",
      "status": "BLOCKED",
      "owner": "R-755",
      "budget_scope": "water_only",
      "target_hardware": {
        "profile_id": "development-baseline-m5-pro",
        "architecture": "arm64",
        "gpu": "Apple M5 Pro, 20 cores"
      },
      "measurement_host": {
        "status": "not_measured",
        "profile_id": "",
        "architecture": "",
        "gpu": ""
      },
      "renderer": {
        "status": "not_measured",
        "method": "",
        "driver": "",
        "headless": null
      },
      "thresholds": {
        "detail_layers": 2,
        "reflection_samples": 2,
        "refraction_samples": 2,
        "foam_shore_detail": 1,
        "frame_time_ms_p95": 2.5,
        "draw_calls_peak": 4,
        "resource_count_peak": 8,
        "memory_delta_mib": 24
      },
      "fallback": {
        "id": "compatibility_water_surface",
        "declared": true,
        "renderer_safe": true,
        "behavior": "Keep water-like base, Fresnel, bounded refraction, and detail normal when screen/depth inputs are unavailable."
      },
      "measurement": {
        "status": "unmeasured",
        "samples": null,
        "metrics": {
          "frame_time_ms_p95": null,
          "draw_calls_peak": null,
          "resource_count_peak": null,
          "memory_delta_mib": null
        }
      }
    }
  ]
}
```

## Verification commands

Normal mode validates this fail-closed artifact and reports `BLOCKED` without treating that as a test failure:

```bash
python3 tools/verify_r715_water_performance.py
```

Strict mode is for a future R-755 evidence handoff. It must remain red against this report because the minimum target and isolated recommended tier have not been measured:

```bash
python3 tools/verify_r715_water_performance.py --strict
```

A valid future fixture must provide both `target_hardware` and `measurement_host`, `headless=false`, a real renderer/driver, at least 120 samples, all four observed water metrics, and a matching target/host identity for each tier. The verifier rejects a fixture with a missing tier, generic budget keys, a mismatched target host, an absent fallback, stale Markdown links, or an unmeasured minimum row in strict mode.

The Godot structural contract is:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_performance_verification
```

## Blockers and ownership

1. **R-755:** run the water-isolated benchmark on the declared Intel UHD 620 target and retain target/host identity, real renderer/driver, 120 or more samples, and water-only metrics.
2. **R-755:** run the same protocol for the recommended tier on the Apple M5 Pro development profile, without relabeling generic scene measurements as water evidence.
3. **R-756:** complete the separate real-renderer visual capture and human review packet; this ledger does not duplicate that work.
4. **R-529 / R-713:** preserve the existing Monastery east-ditch and sky/weather blockers in parent coordination; neither is repaired or reclassified here.

## Sources

- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/target_hardware.json`](../../tools/benchmarks/target_hardware.json)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)
- [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)
- [`r715_water_acceptance.md`](r715_water_acceptance.md)
- [`r715_water_rollout_inventory.md`](r715_water_rollout_inventory.md)
- [`r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md`](r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md)
