# Lower Town water-region merge benchmark

Recorded: 2026-07-17

Repository HEAD at measurement: `126cd76431e0172d2bacc433dea7cb9f7922cfb0`, with the working-tree water-region merge

Raw runs: `/tmp/water-merge-before.json` and `/tmp/water-merge-after.json` (generated artifacts, not committed)

## Environment and method

| Field | Value |
|---|---|
| OS | macOS, darwin arm64 |
| Godot | 4.7.1.stable.official.a13da4feb |
| Renderer | Headless / dummy rendering server |
| Warmup / measured runs | 1 / 3 for pipeline; 1 scene process |
| Command | `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/benchmarks/run_large_map_benchmark.sh <output>` |

Both measurements used the existing large-map benchmark without configuration changes. The complete production scene count includes gameplay, view/runtime, player, and NPC collision shapes. The pipeline navigation result isolates `MapNavBuilder.create_navigation_region`. Lower Town contains 380 water cells, which the deterministic merger represents with 17 exact rectangles.

## Results

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Lower Town production-scene collision shapes | 481 | 118 | -363 (-75.5%) |
| Lower Town navigation bake median | 3.543 ms | 3.667 ms | +0.124 ms (+3.5%) |
| Lower Town navigation bake p95 | 3.585 ms | 3.724 ms | +0.139 ms (+3.9%) |
| Lower Town production-scene startup | 2901.403 ms | 2860.103 ms | -41.300 ms (-1.4%) |

Raw Lower Town navigation bake samples were `2.520, 3.543, 3.585 ms` before and `2.578, 3.667, 3.724 ms` after. At this map size, the obstruction-count reduction did not produce a navigation-bake speedup beyond run-to-run noise. The primary measured Lower Town gain is collision-shape count.

The deterministic synthetic stress profiles show the intended scaling benefit more clearly:

| Synthetic size | Collision shapes before / after | Navigation bake before / after |
|---:|---:|---:|
| 32x32 | 84 / 22 | 0.685 / 1.369 ms |
| 64x64 | 324 / 72 | 4.454 / 4.125 ms |
| 128x128 | 1284 / 268 | 57.636 / 57.263 ms |
| 256x256 | 5124 / 1044 | 3477.465 / 3137.404 ms |

## Semantic verification

- The canonical Lower Town parity fixture still matches, preserving definition and terrain fingerprints.
- Merged collision rectangles cover every water cell exactly once and no non-water cell.
- Hole, one-cell causeway, diagonal-touch, map-boundary, and repeated deterministic-output tests pass.
- Viru and Karja remain connected both in exact grid-route verification and across the baked navigation polygons.
- Water-cell centers remain outside navigation polygons.

## Limitations

- Headless Godot uses the dummy renderer and emits the repository's existing null-material warnings during the complete 3D scene run.
- Millisecond-scale bake measurements are sensitive to process and system noise. More iterations or a dedicated microbenchmark are needed to claim small-map timing improvements.
- The full Godot suite currently reports 16 unrelated failures in prefab transform, rrmap loader, and headless evening-window material tests. All changed-path tests and all Lower Town map/navigation tests pass.
