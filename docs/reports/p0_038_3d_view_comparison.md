# P0-038 3D view layer comparison report

Recorded: 2026-07-23T16:04:27+00:00
Task: `P0-038`
Git commit: `a87b6002917fdfdc7afdb3fbf2fd8b1c030207d0`

## Verdict

**Pass (development baseline).** Headless frame time is inside budget, slice navigation remains green, animation reuse and NPC-variant timings meet ADR 0007 budgets. GPU texture memory and minimum-hardware frame time still require a non-headless capture before P0-040.

This report compares the programmatic 3D isometric candidate on the P0-053 slice surface kit. It is development-baseline evidence for P0-040 and does not replace the human blind-readability gate in P0-039 or the minimum-hardware declaration in P3-011.

## Repeatable procedure

Run from the repository root:

```bash
python3 tools/generate_p038_comparison_report.py --measure
python3 tools/generate_p038_comparison_report.py --write
python3 tools/generate_p038_comparison_report.py --check
```

Performance capture:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh build/benchmarks/p038-evidence.json --quick
```

Clean import baseline (CI uses this exact command):

```bash
tools/run_godot_checked.sh clean-import godot --headless --editor --quit
```

Non-headless GPU capture before frame-time acceptance:

```bash
TARGET_HARDWARE=tools/benchmarks/target_hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/benchmarks/p038-gpu-evidence.json
```

## Hardware

| Field | Declared target | Measurement host |
|---|---|---|
| Profile | `development-baseline-m5-pro` | detected at runtime |
| Status | `development_baseline_not_minimum` | `development_baseline_headless_only` |
| Platform | macOS 26.3 | macOS |
| CPU | Apple M5 Pro, 18 logical cores | Apple M5 Pro |
| GPU | Apple M5 Pro, 20 cores | headless dummy |
| Memory | 48 GiB declared | n/a |
| Headless | n/a | `True` |

## Raw measurements

| Category | Metric | Value | Budget or note |
|---|---|---:|---|
| Import | editor import smoke | 2.423 s (warm editor import smoke on existing `.godot/` cache) | clean clone uses CI import step |
| Frame time | Lower Town scene p95 | 7.346 ms | 16.67 ms steady-state target |
| Frame time | pipeline CPU p95 | 113.610 ms | CPU-side map build only |
| Memory | static bytes | 327126995 | development observation |
| Memory | scene delta MiB | 261.475 | chunk budget reference 256 MiB |
| Texture | `RENDER_TEXTURE_MEM_USED` | 0 bytes | 0 in headless dummy renderer |
| Texture | `RENDER_VIDEO_MEM_USED` | 0 bytes | rerun non-headless for GPU truth |
| Navigation | slice bake p95 | 16.971 ms | production Lower Town pipeline |
| Navigation | synthetic 128 bake p95 | 63.689 ms | monolithic stress only |
| Animation reuse | canonical clips on shared skeleton | 76 | no per-direction meshes |
| NPC variant | Innkeeper rebuild | 16.83 s | under one working day |
| NPC variant | pickup integration | 21 s | under one hour |

## Results

### Import time

Warm editor import smoke measured **2.423 s (warm editor import smoke on existing `.godot/` cache)**. CI still owns the authoritative clean-clone import gate through `tools/run_godot_checked.sh clean-import`.

### Frame time

Headless Lower Town scene frame-time p95 is **7.346 ms**, below the 16.67 ms steady-state reference on the development baseline. Treat this as CPU/dummy-renderer evidence only until a non-headless capture is recorded on the declared minimum-hardware profile.

### Texture memory

Texture memory monitors report **0 bytes** in headless mode because the dummy renderer does not allocate GPU texture pools. Re-run the benchmark with `BENCHMARK_HEADLESS=0` and retain the JSON outside Git for GPU acceptance.

### Navigation defects

Slice navigation bake p95 is **16.971 ms** on the production Lower Town pipeline. Route, patrol, collision, and transition suites remain green. Synthetic 128x128 monolithic navigation bake p95 is **63.689 ms** and is documented as chunk-streaming stress, not a slice defect.

### Animation reuse

The shared rig exposes **76** retargeted clips on one skeleton with **no per-direction assets** (`docs/reports/character_rig_production_p0_037.md`). Focused verification: `--filter=test_character_rig` (16/16).

### NPC-variant production time

Innkeeper variant rebuild measured **16.83 s** and canonical `pickup` integration measured **21 s**, both inside the ADR 0007 speed budgets documented in `docs/reports/character_rig_production_p0_037.md`.

### Renderer-setting escalation

Run tools/run_performance_report.sh with BENCHMARK_HEADLESS=0 on the declared minimum-hardware profile before using frame time or texture memory as P0-040 or P3-011 acceptance evidence.

## Embedded evidence

```json
{
  "animation_reuse": {
    "canonical_clip_count": 76,
    "focused_test_count": 16,
    "focused_test_filter": "test_character_rig",
    "per_direction_assets": false,
    "shared_skeleton": true,
    "source_report": "docs/reports/character_rig_production_p0_037.md"
  },
  "benchmark_report_path": "build/benchmarks/p038-evidence.json",
  "git_commit": "a87b6002917fdfdc7afdb3fbf2fd8b1c030207d0",
  "import_procedure": "tools/run_godot_checked.sh clean-import godot --headless --editor --quit",
  "import_time_seconds": 2.423,
  "measurement_host": {
    "distribution": "macOS",
    "headless": true,
    "os": "macOS",
    "processor_count": 18,
    "processor_name": "Apple M5 Pro",
    "video_adapter": ""
  },
  "navigation": {
    "note": "Slice map route, patrol, collision, and transition suites remain green on HEAD. Synthetic monolithic profiles expose navigation bake scaling that chunk streaming must not replicate in production.",
    "slice_navigation_bake_ms": 16.971,
    "slice_navigation_polygon_count": 0,
    "slice_route_tests": "green",
    "synthetic_128_navigation_bake_ms": 63.689,
    "synthetic_128_navigation_polygon_count": 818
  },
  "npc_variant_production": {
    "animation_budget_seconds": 3600,
    "innkeeper_rebuild_seconds": 16.83,
    "pickup_integration_seconds": 21.0,
    "source_report": "docs/reports/character_rig_production_p0_037.md",
    "variant_budget_working_day_seconds": 86400
  },
  "performance": {
    "actor_count": 3,
    "frame_time_budget_ms": 16.67,
    "frame_time_ms_p95": 7.346,
    "memory_delta_mib": 261.474585533142,
    "memory_static_bytes": 327126995,
    "pipeline_cpu_ms_p95": 113.61,
    "render_video_memory_bytes": 0,
    "renderer_mode": "headless_dummy",
    "scene_startup_ms": 16644.162,
    "texture_memory_bytes": 0
  },
  "recorded_utc": "2026-07-23T16:04:27+00:00",
  "renderer_escalation": {
    "current_status": "development_baseline_headless_only",
    "next_step": "Run tools/run_performance_report.sh with BENCHMARK_HEADLESS=0 on the declared minimum-hardware profile before using frame time or texture memory as P0-040 or P3-011 acceptance evidence.",
    "required_before_gpu_acceptance": true
  },
  "schema_version": 1,
  "target_hardware": {
    "architecture": "arm64",
    "cpu": "Apple M5 Pro, 18 logical cores",
    "display": "3456x2234 built-in display",
    "gpu": "Apple M5 Pro, 20 cores",
    "memory_gib": 48,
    "notes": "This reproducible development target is not a minimum supported-hardware declaration. P3-011 owns the minimum target and release budget. Run a non-headless capture on that profile before using GPU frame time as acceptance evidence.",
    "platform": "macOS 26.3",
    "profile_id": "development-baseline-m5-pro",
    "schema_version": 1,
    "status": "development_baseline_not_minimum"
  },
  "verdict": "pass_headless_development_baseline_pending_gpu_confirmation"
}
```
