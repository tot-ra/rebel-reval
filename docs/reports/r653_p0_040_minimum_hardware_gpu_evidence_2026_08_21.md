# R-653 minimum-hardware GPU evidence ledger

**Recorded:** 2026-08-21
**Task:** `R-653 / P0-040`
**Parent:** `R-111 / P0-040`
**Decision:** **BLOCKED for declared minimum-hardware acceptance; supplementary non-headless instrumentation captured**

## Acceptance boundary

The declared acceptance target remains `minimum-hardware-intel-uhd-620` from [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json): Intel Core i5-8250U, Intel UHD Graphics 620, 8 GiB RAM, and 1920x1080. This checkout is running on an Apple M5 Pro development host, so the captured renderer values must not be promoted to Intel UHD 620 evidence or used to close P0-040.

The run is retained because it proves that the non-headless instrumentation can produce non-zero texture/video-memory values and a complete frame-time distribution. It does not emulate the declared target.

## Measurement provenance

| Field | Value |
|---|---|
| Repository revision | `847c9277320983c0398d25a5199e18f005b39d99` |
| Recorded UTC | `2026-08-21T13:05:45Z` to `2026-08-21T13:06:13Z` |
| OS | macOS `26.3` (`25D2125`) |
| Host architecture | `arm64` |
| Detected CPU/GPU | Apple M5 Pro; 18 logical cores; Apple M5 Pro GPU |
| Host memory/display | 48 GiB; host displays 5120x2880 and 3456x2234 |
| Godot | `4.7.1.stable.official.a13da4feb` |
| Renderer/driver | `gl_compatibility` / OpenGL 4.1 Metal compatibility (`opengl3`) |
| Display server | `macOS`; `headless=false` |
| Target profile | `minimum-hardware-intel-uhd-620` - declared target, not detected host |
| Raw JSON SHA-256 | `fddda43c820383c4c247d5b2b9e85a4dd3be0541f9a3f9adad30ddc771604e04` |

The raw JSON was written to `/tmp/r653-renderer-comparison.json` during the run. The external file is intentionally not committed as a host-specific artifact; the hash and complete measured fields below preserve its provenance.

## Exact command

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1920x1080 \
  res://tools/benchmarks/renderer_comparison_benchmark.tscn \
  -- --output=/tmp/r653-renderer-comparison.json \
  --renderer-requested=gl_compatibility
```

The benchmark used the production `LowerTown` scene and collected 120 steady-state frame samples after scene startup. The run exited with status 0 and wrote the raw JSON. Godot also emitted the pre-existing `Patrol_viru_watch` missing-rig warning and shutdown ObjectDB/resource-leak diagnostics; those diagnostics do not change the host identity or the measured fields, but they prevent this run from being treated as a clean release gate.

## Raw benchmark values

| Metric | Raw value | Interpretation |
|---|---:|---|
| `scene_startup_ms` | `20074.656` | Supplementary Apple M5 Pro startup measurement |
| Frame samples | `120` | Complete distribution present |
| Frame-time median | `9.737 ms` | Supplementary host only |
| Frame-time p95 | `68.674 ms` | Supplementary host only; includes observed long-frame outliers |
| Frame-time p99 | `187.460 ms` | Supplementary host only |
| Frame-time max | `2085.971 ms` | Supplementary host only; not a target acceptance result |
| `texture_memory_bytes` | `442222135` (`421.736 MiB`) | Non-zero real-renderer instrumentation; host-specific |
| `render_video_memory_bytes` | `671481419` (`640.375 MiB`) | Non-zero real-renderer instrumentation; host-specific |
| `memory_static_bytes` | `333988097` | Supplementary host observation |
| `memory_delta_mib` | `229.207` | Supplementary host observation |
| Rendering method | `gl_compatibility` | Matches current project renderer |
| Fidelity flags | shadows/glow enabled; SSAO/SSIL/SDFGI/SSR/volumetric fog unavailable | Renderer comparison metadata |

## Verification result

| Check | Result |
|---|---|
| Non-headless renderer run | **PASS as instrumentation** - exit 0, `headless=false`, raw JSON written |
| Non-zero GPU memory metrics | **PASS as instrumentation** - texture and video memory both available and non-zero |
| Declared Intel UHD 620 target measured | **BLOCKED** - detected host is Apple M5 Pro, not the declared target |
| Minimum-hardware frame-time acceptance | **BLOCKED** - Apple measurements cannot certify Intel UHD 620 performance |
| P0-038 generator check | **PASS** - `python3 tools/generate_p038_comparison_report.py --check` |
| P0-038 focused unit tests | **PASS** - `python3 -m unittest tests.python.test_generate_p038_comparison_report -v`, 5/5 |
| P0-040 approval | **PENDING/BLOCKED** - packet still requires a real Intel UHD 620 run and maintainer decision |

## Required next action

Run the same command on a representative x86_64 machine matching the declared Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB profile. Preserve the raw JSON, OS/driver/Godot metadata, 120-sample frame-time distribution, non-zero or explicitly instrumented GPU memory fields, exact command, and revision. Then replace the missing-target status in this ledger and link the accepted result from the P0-040 packet. Existing board task `R-563` owns that hardware acquisition/run; no duplicate follow-up task is created here.

## Sources

- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/renderer_comparison_benchmark.tscn`](../../tools/benchmarks/renderer_comparison_benchmark.tscn)
- [`tools/benchmarks/renderer_comparison.gd`](../../tools/benchmarks/renderer_comparison.gd)
- [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)
- [`docs/reports/p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md)
