# Vegetation benchmark baseline (R-1320, VEGR-0)

Status: recorded 2026-10-08. First run of the per-layer vegetation benchmark; the reference every later vegetation-realism phase (R-1319 epic) is measured against. Budgets derived from it are in [`VEGETATION_REALISM.md`](../SYSTEMS/VEGETATION_REALISM.md) section 8; the command, camera set and JSON schema are in [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md#vegetation-benchmark-r-1320).

Raw report: [`vegetation_benchmark_baseline.json`](./vegetation_benchmark_baseline.json) (schema `rr.vegetation_benchmark.v1`), used as `--baseline` by `tools/vegetation_performance.py budgets`.

## Run

| Field | Value |
|---|---|
| Date | 2026-10-08 |
| Machine | Apple M5 Pro (CPU and GPU), macOS, arm64 - the development reference in `tools/benchmarks/target_hardware.json`, not the declared minimum |
| Godot | 4.7.1-stable (official), GL Compatibility |
| Resolution | 1920x1080 render target (fixed SubViewport, independent of the window) |
| Maps | `viru_gate_foreland` (Pirita crossing: meadow, rye/barley/flax fields, mixed and spruce woodland bands), `lower_town_slice` |
| Calendar | 15 June 1343, noon (`apply_cycle_progress(0.5)`), default weather |
| Command | `tools/run_performance_report.sh build/perf_veg.json --vegetation` (paired layer timing, 40 pairs per layer) |
| Determinism | A second run on the same build reproduced every count (`vegetation_performance.py compare`: counts identical) |

## Counts per camera and layer

Cells are `instances / triangles / draw calls` submitted after visibility-range and frustum culling (main pass; shadow passes are counted separately in the JSON as `shadow_draw_calls`). `-` means the layer submits nothing from that camera.

| Camera | grass_near | grass_mid | grain | trees_lod0 | flowers | veg_misc | other |
|---|---|---|---|---|---|---|---|
| `meadow_eye_level` | 2,952 / 87,792 / 4 | 1,390 / 44,480 / 8 | - | 1,302 / 13,554,060 / 54 | 147 / 882 / 2 | 53 / 954 / 2 | 124 / 386,512 / 20 |
| `meadow_gameplay` | - | - | - | 1,385 / 14,583,844 / 98 | - | - | 567 / 519,910 / 68 |
| `grain_field_eye_level` | 2,597 / 77,260 / 4 | 701 / 22,432 / 8 | 398 / 38,208 / 6 | 1,117 / 9,549,706 / 115 | 280 / 35,310 / 4 | 39 / 702 / 2 | 82 / 438,014 / 70 |
| `woodland_interior` | 1,121 / 33,484 / 2 | 155 / 4,960 / 4 | 204 / 19,584 / 4 | 1,123 / 9,703,824 / 114 | 242 / 35,082 / 3 | 127 / 2,286 / 1 | 410 / 791,076 / 409 |
| `woodland_distance` | 2,619 / 77,808 / 4 | 722 / 23,104 / 10 | 398 / 38,208 / 6 | 1,153 / 9,849,910 / 139 | 275 / 35,280 / 4 | 40 / 720 / 2 | 53 / 435,212 / 22 |
| `lower_town_street` | 601 / 17,888 / 2 | 5 / 160 / 1 | - | - | 36 / 216 / 1 | 13 / 234 / 1 | 2,265 / 2,978,241 / 2,069 |

`trees_lod1`, `trees_lod2`, `shrubs` and `litter` are zero on every camera: no tree LOD chain exists outside the city (VEGR-7, R-1326), scattered shrubs are not on these maps, and there is no litter layer yet (VEGR-8, R-1327). The one authored hawthorn bush on Viru counts in `shrubs` only when its prop is in view.

## Frame time and share

Frame time is the median of synchronous frames (`force_draw` plus a render-target readback, so each sample waits for the GPU; the readback is a constant that cancels in layer differences). Layer saving is the median of paired shown/hidden frames. Two runs are shown as `run 1 / run 2`.

| Camera | Vegetation share (tris / draws) | Frame ms | GPU draw calls | GPU primitives | Layer saving, ms |
|---|---|---|---|---|---|
| `meadow_eye_level` | 97% / 78% | 67.1 / 66.7 | 357 | 63,753,576 | trees_lod0 58.7 / 51.4; every other layer within -0.4..0.4 |
| `meadow_gameplay` | 97% / 59% | 96.7 / 94.3 | 1,050 | 75,126,764 | trees_lod0 71.4 / 71.8 |
| `grain_field_eye_level` | 96% / 67% | 47.6 / 43.8 | 563 | 46,073,926 | trees_lod0 47.9 / 40.0; others within -0.2..0.2 |
| `woodland_interior` | 93% / 24% | 45.2 / 40.0 | 875 | 45,816,204 | trees_lod0 37.2 / 32.6; others within -0.4..0.9 |
| `woodland_distance` | 96% / 88% | 43.7 / 49.7 | 562 | 45,449,028 | trees_lod0 36.1 / 69.5; others within -0.2..0.5 |
| `lower_town_street` | 1% / 0% | 15.1 / 15.2 | 2,540 | 4,801,195 | all layers within -0.1..1.3 |

## Findings

1. **Tree crowns are the whole vegetation cost.** Every rural camera submits 9.5 to 14.6 million crown triangles (about 10,400 per tree, `MapViewTreeMeshes.geometry_stats`) and hiding the tree layer saves 33 to 72 ms. Grass, grain, flowers and herbs together stay under 0.2 million triangles and under 1 ms. Rural Viru runs at 44 to 97 ms per frame on the reference machine; the street runs at 15 ms.
2. **Shadows multiply the tree cost.** Census triangles are main-pass only; the GPU primitive count is 4.3 to 5.0 times higher on rural cameras because 50 to 134 tree MultiMeshes per camera cast directional shadows across the split cascades. The `shadow_draw_calls` column in the JSON names them.
3. **No distance reduction.** Every tree at every distance draws the LOD0 crown, and `woodland_distance` (forest 40 m away) costs as much as standing inside it. The LOD chain (VEGR-7) is the largest available win.
4. **Grass is cheap and distance-culled per chunk.** Scatter grass uses a 45 m visibility range measured to the centre of each chunk MultiMesh, so the orthographic gameplay camera (90 m boom) culls every grass and grain layer on Viru; first-person ground cover (`grass_near`) only exists in close-camera mode. Grass density therefore has headroom (VEGR-4) as long as it stays chunked.
5. **Share is not a useful budget on rural maps.** Vegetation is 93 to 97 percent of rural triangles because it is the scene. The spec's placeholder (at most 35 percent of a meadow) is replaced by absolute per-layer counts.
6. **Timing noise.** Layer savings for small layers repeat within about 1 ms; the tree layer varies by tens of percent between runs (36 vs 70 ms on `woodland_distance`). Counts are the gate; milliseconds are advisory.

## Limits

- Measured on the development reference only. The declared minimum (Intel UHD 620, 1080p, `tools/benchmarks/minimum-hardware.json`) has no run yet (R-653).
- Headless runs cannot produce counts: the dummy renderer drops MultiMesh instance data, so the benchmark always runs through `tools/godot_render.sh` (minimized window).
- The census applies Godot's per-node visibility-range and frustum tests; it does not model occlusion culling or alpha-scissor overdraw, which only the timing reflects.
