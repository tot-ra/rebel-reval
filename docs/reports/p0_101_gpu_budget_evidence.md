# P0-101 GPU and Minimum-Hardware Budget Evidence

**Task:** R-563 / P0-101 GPU and minimum-hardware evidence
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Decision:** **BLOCKED - the declared Intel UHD 620 minimum-hardware profile was not available on the measurement host.** The non-headless probe ran successfully on the Apple M5 Pro development machine and records supplementary renderer evidence. No authored budget was raised or waived.

## Evidence boundary

This report keeps three identities separate:

1. **Declared target:** `minimum-hardware-intel-uhd-620` from [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json). This is the required acceptance profile: Intel Core i5-8250U, Intel UHD Graphics 620, 8 GiB RAM, 1920x1080.
2. **Non-headless measurement host:** Apple M5 Pro, macOS, 18 logical cores, 48 GiB RAM. This host is not the declared minimum and cannot emulate its GPU. Its render-probe values are supplementary renderer evidence only.
3. **Headless development baseline:** the existing CPU/resident run on the same M5 Pro host. Dummy-renderer video/texture memory values are not GPU evidence.

The probe and report changes only improve instrumentation and evidence. They do not change camera behavior, map data, authored caps, resident budgets, collision budgets, or hardware declarations.

## Authored caps and target configuration

Caps are read from [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json) and remain unchanged:

| Metric | Authored cap | Source / interpretation |
|---|---:|---|
| Resident node count | 7,500 | `budgets.resident_node_count` |
| Resident collision count | 900 | `budgets.resident_collision_count` |
| Resident memory delta | 280 MiB | `budgets.resident_memory_delta_mib` |
| Steady frame-time p95 | 16.67 ms | `budgets.steady_frame_time_ms_p95` |
| Ambient bird audio peak | 3 | `budgets.bird_audio_peak` |
| Ambient bird-flight peak | 4 | `budgets.bird_flight_peak` |
| Urban fauna peak | 8 | `MapViewUrbanFauna.MAX_CONCURRENT_FAUNA` |
| Penned fauna peak | 10 | `MapViewPennedFauna.MAX_CONCURRENT_FAUNA` |
| Draw calls / primitives | Not authored | Measurement and attribution only; no silent cap introduced |
| GPU video memory | Not authored | Measurement only; no silent cap introduced |

The intended target resolution is **1920x1080**, matching the declared minimum profile and the project viewport configuration. The non-headless invocation used Godot 4.7.1 with the GL Compatibility renderer and `--rendering-driver opengl3`.

## Measurements

### Non-headless render probe - Apple M5 Pro supplementary evidence

Command:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  res://tools/benchmarks/lower_town_render_probe.tscn \
  -- --output=/tmp/r563-render-probe-after.json
```

Godot reported `OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M5 Pro`. The probe used the integrated `LowerTown` scene and sampled 120 steady frames after a warm-up.

| Metric | Observed on M5 Pro | Cap | Result on declared minimum target |
|---|---:|---:|---|
| Peak draw calls | 2,518 | Not authored | **BLOCKED** - target GPU unavailable; informational measurement |
| Peak primitives | 2,932,008 | Not authored | **BLOCKED** - target GPU unavailable; informational measurement |
| Frame-time median | 49.872 ms | Not authored separately | **BLOCKED** - target GPU unavailable |
| Frame-time p95 | 60.930 ms | 16.67 ms | **BLOCKED** - supplementary host is over cap and is not target hardware |
| Video memory | 610.892 MiB | Not authored | **BLOCKED** - target GPU unavailable; informational measurement |
| Resident node count | 8,491 | 7,500 | **BLOCKED** - over cap; confirms R-490 blocker remains |
| Resident memory delta | 137.649 MiB | 280 MiB | **PASS on M5 only / BLOCKED for minimum target** |
| Collision count | 172 | 900 | **PASS on M5 only / BLOCKED for minimum target** |
| Ambient bird audio peak | 2 | 3 | **PASS on M5 only / BLOCKED for minimum target** |
| Ambient bird-flight peak | 1 | 4 | **PASS on M5 only / BLOCKED for minimum target** |
| Urban fauna peak | 8 | 8 | **PASS on M5 only / BLOCKED for minimum target** |
| Penned fauna peak | 5 | 10 | **PASS on M5 only / BLOCKED for minimum target** |

The probe completed with exit status 0 and wrote all listed fields. Godot emitted the known `Patrol_viru_watch` missing-rig warning and shutdown ObjectDB/resource-leak diagnostics; these did not prevent the probe from writing the report and are not reclassified as budget results.

### Headless CPU/resident baseline - kept separate

Command:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_BIN="$GODOT_BIN" tools/run_performance_report.sh \
  build/benchmarks/r563-baseline.json --quick
```

The report target label was `development-baseline-m5-pro` with status `development_baseline_not_minimum`; the process used the dummy renderer. The production `lower_town_scene` profile recorded:

| Metric | Headless M5 observed | Cap | Result |
|---|---:|---:|---|
| Frame-time p95 | 9.174 ms | 16.67 ms | **PASS - CPU-side only** |
| Resident node count | 8,489 | 7,500 | **BLOCKED** |
| Resident memory delta | 439.303 MiB | 280 MiB | **BLOCKED** |
| Collision count | 172 | 900 | **PASS - CPU-side only** |
| Ambient bird audio peak | 1 | 3 | **PASS - CPU-side only** |
| Ambient bird-flight peak | 1 | 4 | **PASS - CPU-side only** |
| Urban fauna peak | 8 | 8 | **PASS - CPU-side only** |
| Penned fauna peak | 5 | 10 | **PASS - CPU-side only** |
| Video / texture memory | 0 bytes reported by dummy renderer | Not authored | **BLOCKED** - not GPU evidence |

The headless run is valid regression evidence for CPU-side timing and resident accounting. It is not a minimum-hardware GPU measurement and is not merged with the non-headless values.

## R-490 reconciliation

R-490's resident-cost and camera findings remain open:

- The current scoped run still exceeds the resident node cap: 8,489 headless nodes and 8,491 non-headless-probe nodes against 7,500. The non-headless probe confirms the overage; it does not fix or re-authorize it.
- Headless resident memory remains over the cap at 439.303 MiB against 280 MiB. The non-headless probe's M5 process delta is a separate renderer-host observation and must not be substituted for the headless resident-budget value.
- R-490's six `test_map_camera_modes` follow-boom, building pull-out, and first-person eye-height failures were not exercised or changed by this GPU probe. Camera acceptance remains **BLOCKED**.
- No minimum-hardware Intel UHD 620 run was possible on this host. The M5 renderer result cannot be promoted to target acceptance.

## Verification record

| Check | Result |
|---|---|
| Non-headless render probe | **PASS as instrumentation** - exit 0; full JSON written |
| Quick performance report | **PASS as report generation** - target, host, headline and budget summary written |
| Lower Town map contract | **PASS** - `test_lower_town_slice_map`: 19/19, 0 failures, 0 errors |
| Authored caps unchanged | **PASS** - no budget/config cap changes in this task |
| Minimum-hardware acceptance | **BLOCKED** - Intel UHD 620 was not available; M5 is not an emulation or substitute |
| Overall R-563 result | **BLOCKED** - named hardware evidence is still required |

The generated JSON files under `build/benchmarks/` and `/tmp` are host-specific run artifacts and are not committed. This Markdown report is the retained evidence ledger.

## Follow-up ownership

1. **P3-011 / performance owner:** obtain a non-headless run on the declared `minimum-hardware-intel-uhd-620` profile, or record a named maintainer decision that explicitly accepts the blocker without changing caps.
2. **Resident-cost owner:** reduce the production scene's resident node/memory overages or obtain an explicit evidence-backed budget decision. Do not raise the 7,500-node or 280-MiB caps silently.
3. **Camera/runtime owner:** close the R-490 follow-boom, building pull-out, and eye-height failures independently.
4. **R-108 / P0-101:** remains open; this report must not be read as final performance acceptance.

## Sources

- [`tools/benchmarks/lower_town_render_probe.tscn`](../../tools/benchmarks/lower_town_render_probe.tscn)
- [`tools/benchmarks/lower_town_render_probe.gd`](../../tools/benchmarks/lower_town_render_probe.gd)
- [`tools/run_performance_report.sh`](../../tools/run_performance_report.sh)
- [`tools/benchmarks/run_large_map_benchmark.gd`](../../tools/benchmarks/run_large_map_benchmark.gd)
- [`tools/benchmarks/large_map_benchmark_config.json`](../../tools/benchmarks/large_map_benchmark_config.json)
- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`docs/reports/r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
