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

## R-862 reconciliation addendum

**Checked:** `2026-09-24T02:00:00+03:00`
**Task:** `R-862 / P0-040-N01`
**Parent:** `R-653 / P0-040`
**Verdict:** **BLOCKED for declared minimum-hardware acceptance; supplementary non-headless instrumentation reconciled**

### Packet provenance

| Field | Value |
|---|---|
| Tracked report | [`docs/reports/p0_154_n01_minimum_hardware_crowd_evidence_2026-08-18.md`](p0_154_n01_minimum_hardware_crowd_evidence_2026-08-18.md) |
| Manifest | [`docs/reports/data/r575_minimum_hardware_crowd_evidence_manifest.json`](data/r575_minimum_hardware_crowd_evidence_manifest.json) |
| Raw JSON path | `build/benchmarks/performance-minimum-hardware.json` (local only; not committed) |
| Raw JSON SHA-256 | `3c89f3f7586dc9c43bc8dfc135409278e8beb0c0418093e822c866eedf6f2633` |
| Capture revision | `cc1030c901f6ab73984e73e9ee895f37e236523b` |
| Recorded UTC | `2026-08-18T07:32:43Z` |

### Reconciliation checks

| Check | Result |
|---|---|
| Declared target profile | **PASS** - embedded `target_hardware` matches [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json): Intel Core i5-8250U / Intel UHD Graphics 620 / x86_64 / 8 GiB / `1920x1080` |
| Target vs measurement host separation | **PASS** - `target_hardware` and `measurement_host` are both present and distinct in the raw JSON |
| Non-headless renderer | **PASS as supplementary instrumentation** - `measurement_host.headless=false` |
| Project renderer / resolution contract | **PASS as supplementary instrumentation** - declared target display is `1920x1080`; the run used the production performance harness with `BENCHMARK_HEADLESS=0` |
| Crowd frame-time distribution | **PASS as supplementary instrumentation** - `crowd_character_peak` reports 20 samples with median `1.935 ms`, p95 `4.922 ms`, p99 `8.283 ms`, and max `8.283 ms` |
| GPU memory instrumentation | **PASS as supplementary instrumentation** - `lower_town_scene` reports `texture_memory_bytes=409065066` and `render_video_memory_bytes=643271870` |
| Declared Intel UHD 620 target measured | **BLOCKED** - detected host is Apple M5 Pro / arm64, not the declared x86_64 Intel profile |
| Full minimum-hardware sample contract | **BLOCKED** - the retained run used `--quick`, so scene and crowd profiles used 20 frame samples instead of the 120-sample minimum-hardware contract |
| Minimum-hardware acceptance | **BLOCKED** - Apple measurements cannot certify Intel UHD 620 performance or close P0-040 |

### Exact blockers for R-863

1. Acquire or access a representative x86_64 host matching Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB.
2. Re-run the exact command without `--quick`, preserving `TARGET_HARDWARE=tools/benchmarks/minimum-hardware.json` and `BENCHMARK_HEADLESS=0`.
3. Confirm `measurement_host.processor_name` and `measurement_host.video_adapter` identify the declared Intel CPU/GPU and that `measurement_host.headless=false`.
4. Retain the raw JSON with SHA-256, revision, UTC timestamp, OS/driver/Godot metadata, 120-sample frame-time distribution, and non-zero or explicitly labeled GPU memory counters.

No duplicate physical-run task is created here. `R-575` remains the owner of the crowd benchmark capture; `R-863` owns the next declared-target run attempt.

### Current availability recheck

**Checked:** `2026-09-24T02:00:00+03:00`

The declared target remains unavailable on the current measurement host. The live host reports Darwin `26.3` on `arm64` with Apple M5 Pro and 48 GiB RAM. No compatible Intel UHD 620 machine or configured remote runner is available in this environment.

**Verdict:** **BLOCKED** - the required target command must not be run here and relabeled as target evidence. The existing Apple M5 Pro non-headless capture remains supplementary instrumentation only.

### Verification commands

```text
python3 -m unittest tests.python.test_r575_minimum_hardware_evidence -v
PASS - 5/5 tests

python3 -m json.tool tools/benchmarks/minimum-hardware.json
PASS - declared profile parses

python3 -m json.tool docs/reports/data/r575_minimum_hardware_crowd_evidence_manifest.json
PASS - manifest parses
```

Sources: [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json), [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md), [`tools/benchmarks/run_large_map_benchmark.sh`](../../tools/benchmarks/run_large_map_benchmark.sh).

## R-863 declared-target capture attempt

**Checked:** `2026-09-24T00:31:21Z`
**Task:** `R-863 / P0-040-N02`
**Parent:** `R-653 / P0-040`
**Verdict:** **BLOCKED - declared Intel UHD 620 hardware unavailable; no substitute run executed**

### Availability gate

| Field | Value |
|---|---|
| Repository revision | `32d7faeeaeaaf0e3632b289414d5178d20e7c974` |
| Live host | Apple MacBook Pro `Mac17,8`, Apple M5 Pro, `arm64`, 48 GiB RAM, macOS `26.3` |
| Declared target | Intel Core i5-8250U / Intel UHD Graphics 620 / `x86_64` / 8 GiB / `1920x1080` |
| Compatible target host present | **NO** |
| Declared-target command executed | **NO** - stopped before launch per task contract |

The required non-headless command remains:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
TARGET_HARDWARE=tools/benchmarks/minimum-hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh \
  build/benchmarks/performance-minimum-hardware.json
```

No Apple M-series, headless, emulated, or otherwise non-matching result was substituted. The retained `R-575` supplementary capture and the `R-653` renderer-comparison ledger remain supplementary instrumentation only.

### Handoff

| Owner | Responsibility |
|---|---|
| `R-864` | Publish and validate the GPU evidence ledger once a declared-target raw report exists |
| `R-563` | Acquire or access the physical Intel UHD 620 host for the next capture attempt |

### Verification commands

```text
python3 -m unittest tests.python.test_r575_minimum_hardware_evidence -v
PASS - 6/6 tests

python3 -m json.tool tools/benchmarks/minimum-hardware.json
PASS - declared profile parses

python3 -m json.tool docs/reports/data/r575_minimum_hardware_crowd_evidence_manifest.json
PASS - manifest parses; r863_audit.next_owner=R-864
```
