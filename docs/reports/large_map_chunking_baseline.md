# Large-map chunking baseline

Recorded: 2026-07-17  
Decision: [ADR 0010](../adr/0010-large-map-runtime-chunking.md)  
Raw run: `/tmp/large-map-baseline-final.json` (generated artifact, not committed)  
Repository HEAD at measurement: `b4c12238885e35da96e6aaad10bc05d80178e791`, with the working-tree prototype from ADR 0010

## Environment and method

| Field | Value |
|---|---|
| OS | macOS, darwin arm64 |
| Godot | 4.7.1.stable.official.a13da4feb |
| Renderer | Headless / dummy rendering server |
| Warmup / measured runs | 1 / 3 |
| Frame samples | 120 per measured pipeline run; 120 for the full scene run |
| Memory | `Performance.MEMORY_STATIC` delta, MiB |
| CPU timings | `Time.get_ticks_usec()` wall-clock around synchronous current-pipeline calls |
| Frame timing | Wall-clock interval between `SceneTree.process_frame` signals |

The command was:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/benchmarks/run_large_map_benchmark.sh /tmp/large-map-baseline-final.json
```

The Lower Town pipeline profile times compact blueprint compilation, `MapBuilder.build`, `MapAssembler.assemble`, and `MapNavBuilder.create_navigation_region` separately. The scene profile opens the real `reval_east.tscn` in a normal project scene process so autoloads and the complete 3D view are present. Synthetic profiles use the current monolithic `MapSceneBootstrap`; navigation is timed again in isolation for comparability and the duplicate isolated bake is excluded from pipeline CPU.

## Lower Town production baseline

Lower Town semantic input: 88x56 = 4,928 cells, 36 terrain zones, 89 buildings, 14 props, 6 transitions, and 9 anchors.

| Metric | Pipeline only, median (p95) | Full production scene |
|---|---:|---:|
| Blueprint compile CPU | 11.22 ms (11.51) | included in startup |
| Terrain grid build CPU | 3.30 ms (3.34) | included in startup |
| 2D visual assembly CPU | 3.04 ms (3.09) | included in startup |
| Navigation bake CPU | 2.74 ms (2.80) | included in startup |
| Instrumented pipeline / startup CPU | 20.26 ms (20.63) | 2,926.97 ms |
| Node count | 1,863 | 5,223 |
| Collision shape count | 89 | 481 |
| Static memory delta | 6.32 MiB (6.47) | 49.41 MiB |
| Frame time p95 | 8.38 ms (run p95 8.54) | 7.94 ms |
| Frame time p99 | 8.50 ms (run p95 8.61) | 8.34 ms |

Interpretation:

- Compact compilation and the current 2D pipeline are below the proposed one-chunk activation CPU ceiling on this machine.
- The complete production scene already exceeds the 5,000-node resident budget by 223 nodes. This makes visual LOD/batching a first-class requirement rather than an optional optimization.
- The 2D-only collision count is 89, while the full scene reaches 481 after world bounds, per-water-cell blocks, gameplay areas, player/NPC shapes, and view/runtime content are installed.
- Full startup is dominated by production 3D view construction under the headless dummy renderer. This is not an estimate of shipping GPU frame cost, but it establishes the current synchronous startup baseline.

## Synthetic monolithic scaling

The generator places one-cell-wide water lanes every 16 cells, 3x3 buildings at an 8-cell stride, and four props per proposed 32x32 chunk. It is intentionally non-production and deterministic. Its purpose is to stress current asymptotic behavior, not represent final city density.

| Size | Cells | Buildings / props | Pipeline CPU median | Nav bake median | Nodes | Collisions | Memory delta | Frame p95 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 32x32 | 1,024 | 16 / 4 | 2.34 ms | 0.50 ms | 503 | 84 | 1.67 MiB | 7.99 ms |
| 64x64 | 4,096 | 64 / 16 | 9.37 ms | 2.90 ms | 1,971 | 324 | 6.65 MiB | 8.05 ms |
| 128x128 | 16,384 | 256 / 64 | 85.79 ms | 59.51 ms | 7,839 | 1,284 | 26.27 MiB | 8.05 ms |
| 256x256 | 65,536 | 1,024 / 256 | 3,269.52 ms | 3,173.65 ms | 31,251 | 5,124 | 104.81 MiB | 8.13 ms |

Validated conclusions:

1. A synthetic 32x32 unit is comfortably within the proposed 50 ms activation and 25 ms navigation-bake p95 budgets on the reference machine.
2. The current monolithic 128x128 map exceeds activation, navigation, node, and collision budgets.
3. Navigation bake is the sharpest scaling limit: 0.50 ms at 32x32, 59.51 ms at 128x128, and 3.17 seconds at 256x256.
4. Nodes and collisions scale approximately with authored cells/content and exceed resident budgets before memory does.
5. Idle headless frame time stays low after construction. This does not validate camera-visible draw calls, GPU memory, LOD transition quality, active AI, or streaming-frame spikes.

## Known measurement limitations

- Headless Godot uses the dummy rendering server and emits existing `material is null` warnings from some 3D material/shader queries. Use a non-headless target-GPU capture before accepting visual LOD.
- `MEMORY_STATIC` is process static memory, not an allocation attribution profiler. Deltas are useful for comparison but can retain engine caches between runs.
- The full scene profile has one measured process startup; stage profiles and synthetic profiles have three timed runs.
- Frame samples are idle residency measurements. No moving camera, dynamic NPC population, disk I/O, or chunk churn exists in this prototype.
- Synthetic navigation is baked twice to isolate bake cost. The second bake is not included in `pipeline_cpu_ms`.

## Regression use

Commit raw reports only when intentionally refreshing the reference baseline. CI should run functional prototype tests, JSON validation, and a quick smoke benchmark, but should not fail on machine-sensitive timing. Reference-machine or scheduled runs should retain raw JSON and compare:

- Lower Town semantic and structural counts for accidental amplification.
- Synthetic 32x32 p95 against per-chunk activation and nav budgets.
- Synthetic 128x128 and 256x256 as expected-limit demonstrations.
- Full scene node/collision count and startup against this baseline until production chunking milestones replace it.
