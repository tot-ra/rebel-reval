# P0-142 renderer evaluation report

Recorded: 2026-07-29T10:06:01Z
Task: `P0-142`
Git commit: `3433dfeb5b6be02a279fef0028c083f3e40ac7d4`

## Verdict

**Recommendation: stay on `gl_compatibility`.**
Compatibility keeps the shipped macOS preset and web path viable while P0-141 post-grade already delivers glow; Forward+ gains are deferred until minimum-hardware GPU capture and P0-157 decal path land.

This spike compares Godot 4.7 rendering methods on the playable Lower Town slice.
It does not switch the shipped renderer or export preset.

## Repeatable procedure

Run from the repository root:

```bash
tools/benchmarks/run_renderer_comparison.sh build/benchmarks --quick
python3 tools/generate_renderer_evaluation_report.py --write
python3 tools/generate_renderer_evaluation_report.py --check
```

Full sample count (120 frames per renderer):

```bash
tools/benchmarks/run_renderer_comparison.sh build/benchmarks
```

Non-headless GPU capture (optional, for texture memory truth):

```bash
BENCHMARK_HEADLESS=0 tools/benchmarks/run_renderer_comparison.sh build/benchmarks --quick
```

## Hardware

| Field | Declared target | Measurement host |
|---|---|---|
| Profile | `development-baseline-m5-pro` | detected at runtime |
| Status | `development_baseline_not_minimum` | headless spike |
| Platform | macOS 26.3 | macOS |
| CPU | Apple M5 Pro, 18 logical cores | n/a |
| GPU | Apple M5 Pro, 20 cores | n/a |
| Memory | 48 GiB declared | n/a |
| Headless | n/a | `False` |

## Per-renderer measurements

| Renderer | Frame time | Static memory | Texture memory | Startup |
|---|---|---|---|---|
| `gl_compatibility` | 48.488 ms median, p95 190.299 ms | 200.90 MiB | 198.02 MiB | 19362.8 ms |
| `mobile` | 16.667 ms median, p95 30.404 ms | 240.28 MiB | 254.78 MiB | 28655.5 ms |
| `forward_plus` | 16.583 ms median, p95 21.810 ms | 243.81 MiB | 283.92 MiB | 27770.1 ms |

## Fidelity feature probe

| Renderer | Glow | Tonemap | Fog | Dir. shadow | SSAO path | SSIL | SDFGI |
|---|:---:|:---:|:---:|:---:|---|:---:|:---:|
| `gl_compatibility` | yes | 4 | no | yes | no | no | no |
| `mobile` | yes | 4 | no | yes | yes | no | no |
| `forward_plus` | yes | 4 | no | yes | yes | yes | yes |

## Side-by-side captures

- `gl_compatibility`: `docs/reports/images/renderer_evaluation/gl_compatibility_lower_town_day.png`
- `mobile`: `docs/reports/images/renderer_evaluation/mobile_lower_town_day.png`
- `forward_plus`: `docs/reports/images/renderer_evaluation/forward_plus_lower_town_day.png`

## Export compatibility

| Target | Renderer | Status | Note |
|---|---|---|---|
| forward_plus_desktop | `forward_plus` | requires_new_preset | no Forward+ export preset exists yet; spike only |
| macos_rr_preset | `gl_compatibility` | supported | export_presets.cfg rr preset ships today on universal macOS |
| web_html5 | `gl_compatibility` | supported_with_caveats | Godot 4 web export targets Compatibility GL; Forward+ is not a browser export path |

## Recommendation

- **Stay on:** `gl_compatibility`
- **Follow-up:** `P0-157` (decal path depends on renderer spike outcome)
- **Rationale:** Compatibility keeps the shipped macOS preset and web path viable while P0-141 post-grade already delivers glow; Forward+ gains are deferred until minimum-hardware GPU capture and P0-157 decal path land.
