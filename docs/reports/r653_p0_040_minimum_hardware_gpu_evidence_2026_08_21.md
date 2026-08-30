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
| Raw JSON SHA-256 | [`fddda43c820383c4c247d5b2b9e85a4dd3be0541f9a3f9adad30ddc771604e04`](data/r653_minimum_hardware_gpu_evidence_manifest.json) |

The raw JSON was written to `/tmp/r653-renderer-comparison.json` during the run and is not committed as a host-specific artifact. Its SHA-256, complete measured fields, and R-709 audit result are preserved in [`docs/reports/data/r653_minimum_hardware_gpu_evidence_manifest.json`](data/r653_minimum_hardware_gpu_evidence_manifest.json). The manifest is a provenance record, not a substitute for rerunning the declared target.

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
| `scene_startup_ms` | `20074.656` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - Apple M5 Pro only |
| Frame samples | `120` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - complete distribution present |
| Frame-time median | `9.737 ms` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host only |
| Frame-time p95 | `68.674 ms` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host only; includes observed long-frame outliers |
| Frame-time p99 | `187.460 ms` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host only |
| Frame-time max | `2085.971 ms` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host only; not a target acceptance result |
| `texture_memory_bytes` | `442222135` (`421.736 MiB`) | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - non-zero real-renderer counter; host-specific |
| `render_video_memory_bytes` | `671481419` (`640.375 MiB`) | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - non-zero real-renderer counter; host-specific |
| `memory_static_bytes` | `333988097` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host observation |
| `memory_delta_mib` | `229.207` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - host observation |
| Rendering method | `gl_compatibility` | **PASS as supplementary instrumentation / BLOCKED for target acceptance** - matches current project renderer |
| Fidelity flags | shadows/glow enabled; SSAO/SSIL/SDFGI/SSR/volumetric fog unavailable | **PASS as metadata / BLOCKED for final visual acceptance** - renderer capability limitations are preserved |

## Verification result

| Check | Result |
|---|---|
| R-709 target identity audit | **BLOCKED** - the raw renderer JSON has no embedded `target_hardware` or `measurement_host` identity; the captured provenance records an Apple M5 Pro arm64 host, not Intel UHD 620 x86_64 |
| Target profile identity | **BLOCKED** - declared profile is Intel Core i5-8250U / Intel UHD Graphics 620 / x86_64 / 8 GiB / 1920x1080; no valid target run was executed |
| Non-headless renderer run | **PASS as supplementary instrumentation** - exit 0, `headless=false`, raw JSON written |
| Requested renderer and resolution | **PASS as supplementary instrumentation** - `gl_compatibility`, `opengl3`, 1920x1080 |
| Frame sample count and distribution | **PASS as supplementary instrumentation** - 120 samples with median/p95/p99/max present |
| GPU memory instrumentation | **PASS as supplementary instrumentation** - texture and video memory both available and non-zero; renderer fidelity limitations remain recorded |
| Declared Intel UHD 620 target measured | **BLOCKED** - detected host is Apple M5 Pro, not the declared target |
| Minimum-hardware frame-time acceptance | **BLOCKED** - Apple measurements cannot certify Intel UHD 620 performance |
| P0-038 generator check | **PASS** - `python3 tools/generate_p038_comparison_report.py --check` |
| P0-038 focused unit tests | **PASS** - `python3 -m unittest tests.python.test_generate_p038_comparison_report -v`, 5/5 |
| P0-040 approval | **PENDING/BLOCKED** - packet still requires a real Intel UHD 620 run and maintainer decision |

## Required next action

Run the same command on a representative x86_64 machine matching the declared Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB profile. Preserve the raw JSON, OS/driver/Godot metadata, 120-sample frame-time distribution, non-zero or explicitly instrumented GPU memory fields, exact command, and revision. Then replace the missing-target status in this ledger and link the accepted result from the P0-040 packet. Existing board task `R-563` owns that hardware acquisition/run; no duplicate follow-up task is created here.

## Current availability check

**Checked:** `2026-08-25T10:33:25Z`

The declared target is not available on the current measurement host. The host is an Apple MacBook Pro (Mac17,8) with Apple M5 Pro, arm64 architecture, 48 GiB RAM, and Metal 4 display hardware. It is not the required x86_64 Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB profile. No Intel UHD 620 machine or compatible remote runner is configured in this environment.

**Verdict:** **BLOCKED** - the R-709 audit confirms that no valid declared-target run was executed. The raw renderer JSON has no embedded target/host identity fields, and the captured provenance identifies the actual host as Apple M5 Pro arm64 rather than Intel Core i5-8250U / Intel UHD Graphics 620 x86_64. The required `BENCHMARK_HEADLESS=0` command must not be run here and relabeled as target evidence. The existing Apple M5 Pro non-headless capture remains supplementary only: it proves 120 samples, a complete median/p95/p99/max distribution, and non-zero GPU memory instrumentation, but it cannot certify the target or change any performance cap. R-563 remains the owner of target hardware acquisition/run.

## Independent R-711 verification addendum

**Checked:** `2026-08-25T12:02:34Z`
**Verification task:** `R-711`
**Verdict:** **BLOCKED** - `READY_FOR_PARENT_REVIEW` is not permitted because the declared Intel UHD 620 target was not measured.

### Board and dependency state

- `R-711`: `done` after recording this independent verification.
- `R-710`: `done`; its ledger reconciliation preserves the unavailable-target boundary.
- Readiness owners `R-652`, `R-654`, and `R-655`: `done`.
- `R-653`: `in_progress`; the target-capture owner remains open because no valid Intel UHD 620 run is available.
- `R-563`: `in_review`; it remains the owner of target hardware acquisition and the declared-target capture.

### Evidence checks

| Check | Result |
|---|---|
| Target profile identity | **BLOCKED** - `tools/benchmarks/minimum-hardware.json` still declares Intel Core i5-8250U / Intel UHD Graphics 620 / x86_64 / 8 GiB / 1920x1080; the detected host is Apple M5 Pro / arm64 / 48 GiB. |
| Raw report provenance | **PASS** - `/tmp/r653-renderer-comparison.json` exists and SHA-256 `fddda43c820383c4c247d5b2b9e85a4dd3be0541f9a3f9adad30ddc771604e04` matches the linked manifest. |
| Non-headless status | **PASS as supplementary instrumentation** - manifest records `headless=false`, `gl_compatibility`, `opengl3`, and 1920x1080; this does not repair the host mismatch. |
| Frame-time distribution | **PASS as supplementary instrumentation** - 120 samples with median `9.737 ms`, p95 `68.674 ms`, p99 `187.460 ms`, and max `2085.971 ms`. |
| GPU metrics/instrumentation | **PASS as supplementary instrumentation** - `texture_memory_bytes=442222135` and `render_video_memory_bytes=671481419`; fidelity limitations and shutdown diagnostics remain documented. |
| Approval packet link | **PASS** - [`p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md) links this ledger and the raw-evidence manifest, while retaining `PENDING` and no-acceptance boundaries. |
| Authored target/caps | **PASS** - no runtime, asset, map, budget, or performance-cap files were changed; the declared profile remains unchanged. |

### Exact verification commands and results

```text
python3 -m unittest tests.python.test_r653_minimum_hardware_evidence -v
PASS - 6/6 tests

python3 tools/generate_p038_comparison_report.py --check
PASS - P0-038 comparison report is up to date

python3 -m unittest tests.python.test_generate_p038_comparison_report -v
PASS - 5/5 tests

python3 -m json.tool tools/benchmarks/minimum-hardware.json
PASS - declared profile parses

git diff --check -- docs/reports/r653_p0_040_minimum_hardware_gpu_evidence_2026_08_21.md
PASS

python3 tools/generate_active_docs_report.py --check
BLOCKED by pre-existing repository-wide drift: active_markdown_report.md is not up to date
```

The active-document failure is outside this task's allowlist and does not alter the R-653 evidence result. The first actionable blocker remains the unavailable x86_64 Intel Core i5-8250U / Intel UHD Graphics 620 machine. The Apple M5 Pro capture is retained as supplementary non-headless instrumentation only; no target acceptance, maintainer approval, parent closure, or performance-cap change is inferred.

## Current availability recheck

**Checked:** `2026-08-30T03:32:49Z`

The declared target remains unavailable in this environment. The live host reports Darwin `25.3.0` on `arm64` (`Mac17,8`), Apple M5 Pro with 48 GiB RAM and Apple M5 Pro GPU / Metal 4. This does not match the required x86_64 Intel Core i5-8250U, Intel UHD Graphics 620, and 8 GiB profile. No compatible Intel UHD 620 machine or configured remote runner is available.

**Verdict:** **BLOCKED** - the required target command was not run, because this host cannot provide declared-target evidence. No Apple, headless, emulated, or otherwise non-matching result was substituted. The existing Apple M5 Pro non-headless capture remains supplementary instrumentation only; R-563 remains responsible for obtaining the real Intel UHD 620 run.

## Sources

- [`tools/benchmarks/minimum-hardware.json`](../../tools/benchmarks/minimum-hardware.json)
- [`tools/benchmarks/renderer_comparison_benchmark.tscn`](../../tools/benchmarks/renderer_comparison_benchmark.tscn)
- [`tools/benchmarks/renderer_comparison.gd`](../../tools/benchmarks/renderer_comparison.gd)
- [`docs/PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)
- [`docs/reports/data/r653_minimum_hardware_gpu_evidence_manifest.json`](data/r653_minimum_hardware_gpu_evidence_manifest.json)
- [`docs/reports/p0_040_maintainer_approval_packet.md`](p0_040_maintainer_approval_packet.md)
