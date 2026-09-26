# Seamless startup baseline (WB-05 / R-977)

Measured: 2026-09-27 (local), recorded UTC 2026-09-26T23:34:04.
Repository HEAD: `85d909f1070299fb1c2697730f04a12b7361ed4b`.
Host: Apple M5 Pro, macOS arm64, 18 threads, Godot 4.7.1.stable.official.a13da4feb.
Renderer: headless dummy (no GPU). A Godot `--editor` process was also open on the
same worktree; treat the full-scene number as contended, not as minimum-hardware
evidence.

This report replaces the ADR 0019 pair of "about 20 ms compact pipeline" and
"about 2.93 s full production scene startup" from 2026-07-17
([`large_map_chunking_baseline.md`](large_map_chunking_baseline.md)).

## Named reproduce command

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/benchmarks/run_large_map_benchmark.sh \
  build/benchmarks/seamless-startup-baseline.json --quick
```

`--quick` is 0 warmup, 1 timed run, 20 idle frames. The 2026-07-17 run used
1 warmup, 3 timed runs, and 120 frames. Use the same wrapper without `--quick`
when comparing run-to-run noise. The order-of-magnitude shift below is not
run noise.

3D stage breakdown (Lower Town only):

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/wb05-async-assembly.json --quick
```

Raw JSON from this session: `build/benchmarks/wb05-pipeline.json` (wrapper
equivalent) and `build/benchmarks/wb05-async-assembly.json`. Those files are
generated artifacts and are not committed.

## Compact 2D pipeline (`lower_town_pipeline`)

`LowerTownSlice` definition factory, `MapBuilder.build`, `MapAssembler.assemble`,
and `MapNavBuilder.create_navigation_region`. No 3D view.

| Stage | 2026-07-17 median (ms) | 2026-09-27 (ms) |
|---|---:|---:|
| Blueprint compile / definition create | 11.22 | 79.04 |
| Terrain grid build | 3.30 | 43.19 |
| 2D visual assembly | 3.04 | 8.12 |
| Navigation bake | 2.74 | 18.53 |
| Instrumented pipeline CPU | 20.26 | 148.87 |
| Nodes | 1863 | 2573 |
| Collision shapes | 89 | 122 |
| Static memory delta (MiB) | 6.32 | 19.01 |
| Idle frame p95 (ms) | 8.38 | 7.80 |

The authored Lower Town grew from 88x56 (4928 cells) to 152x128 (19456 cells).
Compile and terrain cost scale with that. The 2D pipeline is still far below
the 3D view.

## Full production scene (`reval_east.tscn`)

Ordinary project autoloads and the complete `_ready` chain, including
`MapView3D`.

| Metric | 2026-07-17 | 2026-09-27 |
|---|---:|---:|
| Scene startup (ms) | 2926.97 | 17267.53 |
| Nodes | 5223 | 15088 |
| Collision shapes | 481 | 177 |
| Static memory delta (MiB) | 49.41 | 601.70 |
| Idle frame median / p95 (ms) | 7.94 / 7.94 | 9.64 / 17.53 |

The 20-frame p99 (465.58 ms) is the first process frames after `_ready`, not
steady residency. Budget against the median and p95.

The scene already exceeds ADR 0019 resident caps: 7500 nodes and 280 MiB
static delta. R-980 cannot flip streaming flags on until residency is inside
those caps, or a later measured ADR changes the caps.

## 3D view stages (`MapView3D.create`, warmed caches)

Synchronous Lower Town view after a prior build of the same map warmed shared
caches. `height_field` 0.15 ms is the warm path. A cold surroundings pass in
the same trace paid 7033 ms, dominated by neighbour previews.

| Stage | Warm sync (ms) |
|---|---:|
| `height_field` (warm) | 0.15 |
| `surroundings` | 1608.69 |
| `terrain_mesh` | 1958.93 |
| `interior_shell` | 0.01 |
| `decals` | 0.65 |
| `object_index` | 0.96 |
| `buildings_props` | 365.91 |
| `scatter` | 221.56 |
| `chunk_finalize` | 5.92 |
| `transition_visuals` | 0.80 |
| `anchors` | 0.03 |
| `lighting` | 0.03 |
| `sky_weather` | 8.65 |
| `view_effects` | 1.53 |
| **total** | **4176.95** |

Navigation: synchronous bake 19.28 ms; threaded bake main-thread publish
0.01 ms after 5 frames.

This matches the WB-07 finding: the 3D view, not the 2D pipeline, is the
startup cost. Water, sky, atmosphere, crowd, and the larger authored grid
landed after the 2.93 s figure. Streaming has to hide this 4.2 s warm view
(and a longer cold view) across frames, not shave a 20 ms 2D path.

Earlier WB-07 traces on the same host:
[`async_assembly_2026-09-26.md`](async_assembly_2026-09-26.md),
[`async_assembly_2026-09-27.md`](async_assembly_2026-09-27.md).

## What to budget against

| Work | Number to use |
|---|---|
| Compact compile + terrain + 2D + nav | 149 ms (this report) |
| Warm `MapView3D.create` | 4177 ms (this report) |
| Full `reval_east.tscn` startup | 17268 ms (this report, contended) |
| Per-frame assembly budget | 4.0 ms (`world_host/location_assembly_frame_budget_ms`) |
| Resident caps | ADR 0019 / `large_map_benchmark_config.json` |
