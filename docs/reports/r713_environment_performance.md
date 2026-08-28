# R-778 sky-weather environment performance

- Task: `R-778`
- Parent: `R-737` / `R-713`
- Recorded UTC: 2026-08-28
- Status: **BLOCKED - tier budgets are defined, but target-specific sky/weather measurements are not available**
- Runtime contract: [`SkyWeather3D`](../../scripts/map/view3d/sky_weather_3d.gd)

## Decision and evidence boundary

The minimum and recommended rows below are acceptance budgets for the weather presentation layer, not claims about the complete Lower Town frame. The values are the explicit renderer-cost budgets used by `SkyWeather3D.QUALITY_TIERS`; weather identity, transition state, cloud offsets, and seeded scheduling remain deterministic across tiers.

A performance row is accepted only when the recorded run identifies both the declared `target_hardware` and the actual `measurement_host`. A headless dummy-renderer run can verify the command and the deterministic contract, but cannot certify GPU cost. A run on Apple M5 Pro cannot certify the declared Intel UHD 620 minimum target.

## Sky/weather tier budgets

| Budget | `minimum` | `recommended` | Measurement meaning |
|---|---:|---:|---|
| Cloud noise resolution | 128 | 256 | Generated cloud-noise texture width and height |
| Cloud shape resolution | 256 | 512 | Generated cloud-shape texture width and height |
| Cloud shadow samples | 2 | 4 | Shader shadow integration samples |
| Rain shaft samples | 3 | 6 | Shader rain-column samples |
| Rain particles | 700 | 2,200 | Maximum `GPUParticles3D.amount` for rain |
| Lightning density | 0.65 | 1.0 | Rendered flash intensity multiplier; strike timing remains deterministic |
| Fog quality | 0.65 | 1.0 | Presentation quality multiplier |
| Shader sample budget | 80 | 140 | Combined weather shader sample allowance |
| Frame-time budget | 1.50 ms | 2.50 ms | Weather presentation allocation, not the whole-frame budget |
| Memory budget | 8 MiB | 24 MiB | Weather resources/allocation, not total process memory |
| Missing-resource fallback | `gradient_only_if_resource_missing` | `gradient_only_if_resource_missing` | Fail-soft visual fallback |

The source of truth for these values is `SkyWeather3D.QUALITY_TIERS`. The resource-resolution and rain-particle limits are also defined in [`sky_weather_resources.gd`](../../scripts/map/view3d/sky_weather_resources.gd). The focused contract test checks tier selection, clamping, and deterministic state equivalence in [`test_sky_weather_3d.gd`](../../tests/godot/test_sky_weather_3d.gd).

## Target and measurement-host identity

| Tier | Declared target hardware | Measurement host | Status | Clearing condition |
|---|---|---|---|---|
| `minimum` | `minimum-hardware-intel-uhd-620`: Intel Core i5-8250U, Intel UHD Graphics 620, x86_64, 8 GiB, 1920x1080; [`minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json) | **Unavailable**. The retained R-653 run used Apple M5 Pro arm64/macOS, not the declared target; see [`r653_minimum_hardware_gpu_evidence_manifest.json`](data/r653_minimum_hardware_gpu_evidence_manifest.json) | **BLOCKED** | Run the documented non-headless measurement on the declared Intel UHD 620-class target and record the weather-tier metrics with 120 or more frame samples |
| `recommended` | `development-baseline-m5-pro`: Apple M5 Pro, arm64, 48 GiB, macOS, 3456x2234; [`target_hardware.json`](../../tools/benchmarks/target_hardware.json) | Apple M5 Pro is available as a development host, but no retained run isolates the R-713 weather presenter at this tier. Existing generic reports are supplementary only | **BLOCKED** | Run the same protocol with the recommended tier selected and retain per-tier frame, memory, particle, and shader/resource observations |

The `development-baseline-m5-pro` profile is a reproducible development baseline, not a minimum-supported-hardware declaration. The target and host fields must remain separate even when they describe the same development machine.

## Existing supplementary observations

These observations help establish that the repository benchmark path is repeatable, but they do not close either row above because they are whole-scene or generic renderer measurements rather than isolated sky/weather tier measurements:

| Evidence | Host/renderer | Observed values | Interpretation |
|---|---|---|---|
| [`p038_comparison_evidence.json`](data/p038_comparison_evidence.json) | Apple M5 Pro arm64, headless dummy renderer | Whole-scene frame-time p95 `7.346 ms`; memory delta `261.475 MiB`; weather tier not isolated | Supplementary CPU/scene baseline; no GPU or sky-tier acceptance |
| [`r653_minimum_hardware_gpu_evidence_manifest.json`](data/r653_minimum_hardware_gpu_evidence_manifest.json) | Apple M5 Pro arm64, non-headless OpenGL renderer | 120 samples; frame-time p95 `68.674 ms`; texture memory `442,222,135 bytes`; video memory `671,481,419 bytes` | Supplementary renderer instrumentation; target mismatch means minimum-hardware result is blocked |

The generic whole-scene memory values must not be compared directly with the 8/24 MiB weather-resource allocations. They measure different scopes.

## Repeatable measurement protocol

Validate the declared profiles and the deterministic tier contract first:

```bash
python3 -m json.tool tools/benchmarks/minimum-hardware.json >/dev/null
python3 -m json.tool tools/benchmarks/target_hardware.json >/dev/null
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_sky_weather_3d
```

Run the host benchmark without relabeling its result. The command records the general scene baseline and host identity; a tier-specific instrumentation run must additionally record the selected tier and the weather-only metrics listed in the template below:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
TARGET_HARDWARE=tools/benchmarks/minimum-hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/benchmarks/r778-minimum-hardware.json

TARGET_HARDWARE=tools/benchmarks/target_hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/benchmarks/r778-recommended-development.json
```

Do not mark a row accepted from the headless command or from the generic report alone. The acceptance run must retain the raw JSON, repository revision, UTC timestamp, Godot version, renderer/driver, target profile, measurement-host profile, selected quality tier, frame sample count, and any unavailable metric as `BLOCKED` rather than omitting it.

## Retained measurement template

| Tier | Target profile | Measurement host | Renderer / headless | Samples | Weather frame p95 (ms) | Weather memory (MiB) | Rain particles | Shader samples | Result |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| `minimum` | `minimum-hardware-intel-uhd-620` | **not measured** | **not measured** | - | **BLOCKED** / budget `<= 1.50` | **BLOCKED** / budget `<= 8` | **BLOCKED** / cap `700` | **BLOCKED** / cap `80` | **BLOCKED** |
| `recommended` | `development-baseline-m5-pro` | **not measured for isolated weather tier** | **not measured for isolated weather tier** | - | **BLOCKED** / budget `<= 2.50` | **BLOCKED** / budget `<= 24` | **BLOCKED** / cap `2,200` | **BLOCKED** / cap `140` | **BLOCKED** |

## Ownership and next steps

- `R-778` provides the budget contract and fail-closed report template.
- `R-653` owns acquisition of the declared minimum-hardware GPU run. Its Apple M5 measurement remains supplementary.
- `R-737` owns tier integration and final budget acceptance.
- The R-713 acceptance ledger must keep these rows blocked until the target/host-separated evidence is retained; no generic whole-scene result should be relabeled as sky/weather proof.

## Sources

- [`SkyWeather3D.QUALITY_TIERS`](../../scripts/map/view3d/sky_weather_3d.gd)
- [`SkyWeatherResources`](../../scripts/map/view3d/sky_weather_resources.gd)
- [`test_sky_weather_3d.gd`](../../tests/godot/test_sky_weather_3d.gd)
- [`target_hardware.json`](../../tools/benchmarks/target_hardware.json)
- [`minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)
- [`R-713 acceptance ledger`](r713_sky_weather_acceptance.md)
