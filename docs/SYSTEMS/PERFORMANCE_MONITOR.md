# Performance monitor (F3)

Status: implemented (requested directly by the maintainer 2026-10-10; no board task yet). Scope: a developer overlay that shows where frame time goes, so a screenshot of a slow place is enough to diagnose it. Out of scope: a profiler for shipped builds, GPU captures (use Xcode / RenderDoc), frame-time budgets per system.

## Using it

| Input | Effect |
|-------|--------|
| **F3** | cycle off, compact, full |
| **F4** (full mode) | measure what each layer costs: switches every layer off in turn for about 24 frames and lists the milliseconds and share of the frame each one saves. Stand still while it runs |
| **Shift+F3** | write a JSON snapshot to `user://perf_snapshots/` (the path is printed) |
| **Alt+1 .. Alt+0** (full mode; Shift or Cmd also work, read by physical key so macOS Option works) | switch a render layer off or on: grass, fields, trees, buildings, sea/water, shore spray, god rays, cloud shadow + fog, people + fauna, sun shadows; F4 also measures the sky dome (no key) |
| `--perf-overlay` (game argument) | start with the full panel |

Closing the panel puts every layer back. Nothing else changes in gameplay: the overlay reads timers, it does not alter simulation.

## What the panel shows

- **Frame**: FPS, average, p95 and worst frame time over the last 240 frames, with a bar graph (the line is the 33.3 ms budget of 30 FPS).
- **Render CPU / GPU / script / physics** milliseconds, and a one-line verdict: GPU bound, CPU bound or balanced. GPU time is `n/a` where the driver or window reports none (a minimized window reports zero).
- **Where you are**: world position, nearest point of interest or wood, water depth, weather and time of day, the active quality row, resolution and render scale, renderer and GPU name. This makes a screenshot reproducible.
- **Layer cost** (after F4, with the triangles each layer holds): the frame time each render layer takes, biggest first. This is the answer to "is it the grass, the sea or the sky" on a GPU-bound frame, because Godot does not expose per-pass GPU times to scripts (its pass timestamps exist only while the editor profiler runs). The panel lists per-pass GPU time too if a driver ever reports it.
- **CPU systems**: a tree of probed systems (`view_runtime/actors/ground` is shown as `actors` under `view_runtime`), siblings slowest first, a parent's time includes its parts. "probed total" adds only the top-level nodes. It is script time we measured, not the frame: a frame much longer than the total is waiting (on the GPU) or running unprobed code. Counts such as "rigs, posed, skipped" follow the list. Milliseconds per frame (average / recent peak) of the probed systems: city update steps (grass, fields, doors, interiors, ground trail, smoke, shadow range and minimap, music zones), citizens, named NPCs, fauna, fish, ships, tree LOD, sea LOD, shore spray, sky and weather, map view, runtime, water simulations, chimney smoke, boats, leaf fall, and the physics steps of the actors.
- **Memory**: RAM, video memory (textures and buffers), draw calls, objects, triangles, nodes, orphan nodes, resources and pipeline compilations (a spike there is shader stutter).

## Telling grass from sea from sky

1. Read the verdict. A GPU bound frame answers "which layer": press F4, or press Alt+number for a suspect layer and watch the frame time. Whatever recovers the most is the cost.
2. A CPU bound frame answers "which system" from the CPU systems list.
3. Frame time that spikes without a steady cost shows up as a high worst / p95 with a low average. Check pipeline compilations and `shore_spray` / `tree_lod` peaks.
4. The snapshot (Shift+F3) adds the biggest MultiMeshes with their visible instance counts, visible lights, emitting particle systems and the most numerous node classes.

## How it is built

- `scripts/debug/perf_monitor.gd`: autoload `PerfMonitor` (CanvasLayer 100), all UI built in code.
- `scripts/debug/perf_probe.gd`: `start()` / `stop(&"scope", t)` accumulators. While the overlay is not in full mode `start()` returns 0 and `stop()` returns at once, so shipped builds pay one static read per scope. New systems add a scope the same way and appear in the list without any change to the overlay.
- Viewport render times come from `RenderingServer.viewport_set_measure_render_time`, enabled only while the overlay is open.
- `tools/benchmarks/player_view_frame_time.gd --panel` records the panel text for every benchmark shot (see [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)).

## Verify

`godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_perf_monitor`. GPU timings and the layer toggles need a real window; the unit tests cover mode cycling, the probe, every panel section and layer restore.

## Limits

- GPU pass names depend on the driver's timestamps; where none arrive the panel says so.
- Layer switches hide and pause the layer, they do not unload its memory. Layers need the city view (group `city_view`, set by `CityMapView.create_city`); other scenes show only the frame and memory sections.
- The "waiting on the GPU" verdict is inferred: when probed CPU work is much shorter than a slow frame, the CPU is idle. It is exact only when the driver reports GPU time.
- The panel is not shown in the main menu scenes' layouts beyond the top-left corner; it ignores the mouse.
