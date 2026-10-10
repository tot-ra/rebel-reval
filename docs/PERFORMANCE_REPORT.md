# Repeatable performance report

## Daily Brute/Caesar optimization loop

The enabled daily developer loop applies one evidence-backed performance fix when a safe, clean write boundary exists. It evaluates low / mid / high graphics quality against `tools/benchmarks/minimum-hardware.json`, balancing rendered frame time (target strictly below 33.33 ms / above 30 FPS), frame-time tails, CPU, GPU, memory, loading and I/O while preserving world/gameplay features. The loop instructions and guardrails are `agents/rebel-dev/skills/performance-loop/SKILL.md`; team-loop overview is [`docs/AGENT_LOOPS.md`](./AGENT_LOOPS.md).

Headless measurements are instrumentation only, not rendered FPS or GPU certification. Compare before/after on the same host, renderer, scene, resolution and workload, test every measurable tier, and report limitations; see the minimum-hardware and acceptance cautions in [P3-011](./reports/p3_011_performance_budget.md). The loop does not create project tasks or silently trade away features.

Status: implemented (task **P1-030**; harness repaired for the continuous city in task **R-1536**)

Performance scenes: the continuous Reval city `res://scenes/world/reval_city/reval_city.tscn` (ADR 0031, headline) and Kalev's smithy `res://scenes/reval_east/forge/forge.tscn`, mounted by `res://tools/benchmarks/scene_benchmark.tscn`

Generated reports: `build/benchmarks/` (ignored; do not commit raw host-specific runs)

Out of scope: budgets and pass/fail gates for the city (P3-011), minimum-hardware acceptance runs (R-653), regional sites (ADR 0042).

## Command

Run the full report from the repository root:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh
```

For a short instrumentation smoke:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_performance_report.sh build/benchmarks/performance-smoke.json --quick
```

`GODOT_BIN` defaults to `godot`. `TARGET_HARDWARE` may point to another JSON profile with the same required fields as `tools/benchmarks/target_hardware.json`:

```bash
TARGET_HARDWARE=/absolute/path/to/minimum-hardware.json \
  BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/benchmarks/minimum-hardware.json
```

`BENCHMARK_RENDERING_METHOD=gl_compatibility|mobile|forward_plus` (with `BENCHMARK_HEADLESS=0`) overrides the renderer for every Godot phase without editing `project.godot` (Compatibility uses `opengl3`, the others `metal`). The report records the renderer that actually ran in `measurement_host.rendering_method` / `rendering_driver` and prints it in the summary line. Headless runs report the project setting, but they draw nothing (dummy renderer). Compare renderers on the same host with, for example:

```bash
BENCHMARK_HEADLESS=0 BENCHMARK_RENDERING_METHOD=mobile \
  tools/run_performance_report.sh build/benchmarks/perf-mobile.json --quick
```

With `BENCHMARK_HEADLESS=0` a fourth phase runs `tools/benchmarks/renderer_frame_time.gd` (1920x1080, vsync off) and merges it under `renderer_frame_time`. It records per-shot median and p95 wall frame time, draw calls and primitives for four fixed city shots (day and midnight) and the Kalev smithy forge bay, plus `frame_ms_median_of_shots`, `frame_ms_worst_shot` and `fps_median_of_shots`. `--quick` samples 30 frames per shot instead of 90. Earlier results: [`reports/hdr_output_spike_2026-10-09.md`](./reports/hdr_output_spike_2026-10-09.md).

The command exits nonzero when the target profile is missing or invalid, a Godot phase fails, or the report cannot be written. It prints the output path and a one-line summary with target profile, renderer, frame-time p95, static memory, and actor count. A headless `--quick` run takes about one minute.

**Fail fast (R-1536).** A benchmark whose scene or `preload()` target is gone never calls `quit()`, and the old harness left headless Godot processes idling forever. Two guards in [`tools/benchmarks/benchmark_guard.sh`](../tools/benchmarks/benchmark_guard.sh), shared by `run_performance_report.sh`, `run_large_map_benchmark.sh` and `run_renderer_comparison.sh`, prevent that:

- `benchmark_preflight` runs `tools/benchmarks/benchmark_preflight.py`. It follows `ext_resource` paths and `preload("res://...")` targets transitively from each entry point and measured scene, and exits 1 listing every missing file before Godot starts.
- `benchmark_run` kills any phase, and the Godot child of `tools/godot_render.sh`, that outlives `BENCHMARK_TIMEOUT_SEC` (default 900 s). The run then fails with exit code 124.

Measured scenes are never instanced as an `ext_resource` of a benchmark scene. The recorders mount them at run time with `--scene=res://...` through `tools/benchmarks/benchmark_target.gd`, so a retired scene exits with code 1 and a `Benchmark scene is missing or cannot load` error. Verify: `python3 -m unittest tests.python.test_benchmark_preflight -v`.

## What the report measures

The command runs ordinary scenes so each measured scene runs with normal project autoloads and the complete production `_ready` chain:

1. `scene_benchmark.tscn` (`scene_baseline.gd`) runs once per measured scene. It mounts the scene with `--scene=` and samples startup, frame intervals, memory, node/collision counts, actors and fauna peaks into a baseline tagged with `--profile-id=`. The scenes are listed in the `SCENES` array of `tools/benchmarks/run_large_map_benchmark.sh`: `reval_city_scene` (the continuous city, spawned at `poi.forum`) and `kalev_smithy_scene` (the forge).
2. `large_map_benchmark.tscn` records the `kalev_smithy_pipeline` profile (compile, terrain build, 2D assembly and navigation bake of the `kalev_smithy` MapDefinition) and the synthetic scale profiles. It merges every scene baseline (`--scene-baseline=` repeats) and writes one JSON report.

Report `schema_version` 3 (R-1536) replaced the retired Lower Town profiles (`lower_town_scene`, `lower_town_pipeline`) with `reval_city_scene`, `kalev_smithy_scene` and `kalev_smithy_pipeline`. Scene profiles carry `scene` and `size_cells` `[0, 0]`: the city has no single map grid. Reports and slice-performance manifests made before R-1536 name the old profiles and are not comparable.

The top-level `headline` summarizes the `reval_city_scene` profile:

- `frame_time_ms_p95` - wall-clock interval between `SceneTree.process_frame` signals;
- `memory_static_bytes` and `memory_delta_mib` - Godot `Performance.MEMORY_STATIC` observations;
- `actor_count` - `CharacterBody2D` / `CharacterBody3D` descendants of the production scene's authoritative `Actors` branch.

The raw `profiles` section retains per-run distributions, node/collision counts, startup and pipeline timings, semantic counts, and existing map-budget observations.

## Location assembly (WB-07)

A third phase runs `tools/benchmarks/async_assembly_trace.gd` and merges its output under `location_assembly` (`--quick` traces `kalev_smithy` only). It can also run on its own:

```bash
godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/async_assembly.json [--budget-ms=4.0] [--quick] [--map=smithy_courtyard]
```

Per map (`kalev_smithy`, `smithy_courtyard`: the MapDefinition locations the game still assembles; the continuous city is not a `MapView3D` location and is timed by the scene phase) it records:

- `synchronous.total_ms` and `synchronous.stages_ms` - one-call `MapView3D.create()` cost, keyed by the stable `STAGES` names in `scripts/map/view3d/map_view_assembly.gd` (`height_field`, `surroundings`, `terrain_mesh`, `interior_shell`, `decals`, `object_index`, `buildings_props`, `scatter`, `chunk_finalize`, `transition_visuals`, `anchors`, `lighting`, `sky_weather`, `view_effects`);
- `staged.frame_ms`, `max_frame_ms`, `frames_over_budget` - main-thread milliseconds per process frame while `assemble_async()` builds a detached view, plus `mount_add_child_ms` for the final `add_child`;
- `staged.units_over_budget` - every single work unit (stage plus chunk or stable object ID) whose cost alone exceeds the budget; a unit is atomic, so these units set the frame-time floor;
- `navigation.synchronous_ms` vs `navigation.threaded_main_thread_ms` - the `MapNavBuilder` bake on the calling thread against the main-thread cost of starting the WorkerThreadPool bake.
- `cold_staged` (WB-07b) - `frames`, `max_frame_ms`, `stages_ms` and `units_over_budget` of a staged build that runs before anything caches the map, so the cold height-field bake and first-use material costs show up.

The budget comes from the project setting `world_host/location_assembly_frame_budget_ms` (default `4.0`). Staged assembly and threaded navigation and scene loading stay behind `world_host/async_location_assembly_enabled` (default `false`). Headless numbers are CPU scene-construction cost under the dummy renderer. Use `BENCHMARK_HEADLESS=0` for a GPU-backed trace. Findings: [`docs/reports/async_assembly_2026-09-26.md`](./reports/async_assembly_2026-09-26.md). Worker-thread terrain, surroundings and height-field bakes (WB-07b, R-1005): [`docs/reports/async_assembly_2026-09-27.md`](./reports/async_assembly_2026-09-27.md). Cold material and texture generation on workers (WB-07d, R-1010): [`docs/reports/async_assembly_cold_materials_2026-09-27.md`](./reports/async_assembly_cold_materials_2026-09-27.md). Door/beam wood and fortification masonry on the same path (WB-07e, R-1027): [`docs/reports/async_assembly_building_materials_2026-09-27.md`](./reports/async_assembly_building_materials_2026-09-27.md). View-scoped GLB pins, building and learned scene prefetch, row-band scatter and backdrop neighbor houses (WB-07c, R-1006): [`docs/reports/async_assembly_heavy_objects_2026-09-28.md`](./reports/async_assembly_heavy_objects_2026-09-28.md). `tools/benchmarks/material_texture_hashes.gd` prints per-slot texture hashes for a two-checkout parity diff. A three-map trace in one process warms shared material caches; `--map=` is the fresh-process cold number for a later map.

## GPU render probe (draw-call attribution)

The report above runs headless by default, so it cannot see GPU-side cost. For that, run the
render probe non-headlessly against a production scene (`--scene=`, default the continuous
city; pass `--scene=res://scenes/reval_east/forge/forge.tscn` for the smithy). The wrapper
keeps the window minimized and unfocused; the root viewport still renders at full size (see
`docs/SETUP.md`, "Rendering captures without a visible window"):

```bash
tools/godot_render.sh \
  res://tools/benchmarks/render_probe.tscn \
  -- --output=user://probe.json --screenshot=/tmp/probe.png
```

It reports peak draw calls, primitives, frame time, and a census of the visual
node types that produce them (mesh instances, shadow casters, particle systems,
multimeshes), plus the heaviest subtrees by surface count.

Attribution switches disable one cost source per run so a suspect can be sized
before any code changes: `--no-shadows`, `--no-neighbors`, `--no-particles`,
`--hide-particles`, `--halve-particles`, `--splits2`, `--trim-shadows`.

Baseline measured on `development-baseline-m5-pro` (2026-07-25, gl_compatibility, on the since-retired Lower Town scene):

| Build | Frame time (median) | Draw calls | Mesh instances |
| --- | --- | --- | --- |
| Before draw-call work | 77.8 ms (13 FPS) | 15 933 | 18 228 |
| After | 25.3 ms (39 FPS) | 1 789 | 1 828 |

The three fixes, in order of contribution: merging static view geometry per
material (`MapViewStaticBatcher`), dropping shadow casting on architectural trim
too slim to read as a shadow, and stripping backdrop dressing plus culling
offscreen chimney plumes.

## Vegetation benchmark (R-1320)

Status: implemented (task **R-1320**, VEGR-0; moved to the continuous city in **R-1536**). Per-layer cost of vegetation over a fixed camera set; the measurement gate of the vegetation-realism epic (R-1319). Measurement only: it changes no look, density, placement or shader. A separate report: the default and `--quick` contracts above are unchanged.

```bash
tools/run_performance_report.sh build/perf_veg.json --vegetation
python3 tools/vegetation_performance.py budgets build/perf_veg.json \
  --baseline docs/reports/vegetation_benchmark_baseline.json
python3 tools/vegetation_performance.py compare run_a.json run_b.json   # determinism
```

The mode runs `tools/capture_vegetation_benchmark.gd` through `tools/godot_render.sh --resolution 1920x1080 --disable-vsync` (minimized window) and prints a per-camera table. It cannot run headless: the dummy renderer drops MultiMesh instance transforms and AABBs, so the tool exits with code 2 there. `VEGETATION_LAYER_TIMING=0` skips the per-layer timing pass (counts and frame totals only, about 2 minutes including the city build). A missing plan anchor, streaming that never settles, or a missing report fails the run with exit code 1. Single camera: `tools/godot_render.sh --disable-vsync --script res://tools/capture_vegetation_benchmark.gd -- --output=res://build/benchmarks/veg.json --camera=meadow_eye_level [--layer-timing] [--frames=40] [--size=1920x1080] [--screenshots=res://build/benchmarks/veg_shots/]`.

**Scene state.** One `CityWorld3D` of the default city plan (ADR 0031) with its own camera and `setup_lighting`, the calendar fixed at 15 June 1343 (`MapViewMaterials.apply_vegetation_season`, `CityFarmland.set_calendar_date`), noon (`apply_time(0.5)`, sky clock stopped so time of day and weather cannot drift during a run), default weather, rendered into a fixed 1920x1080 `SubViewport` (own world), so window size and display scale never change the result. Before each census the tool resets the streamers that keep content past their build radius (forb chunks, farmland features, near tree crowns), then drives grass, forb, farmland and tree-LOD streaming round the camera anchor, as the game streams round Kalev, until no chunk or feature inside a build radius is missing (at most 900 frames, else exit 1). A `--camera=` run therefore reports the same counts as the full set.

**Camera set.** Each camera stands on a plan anchor picked by stable plan ID, so the set follows plan edits. Offsets and heights are world units (1 unit = 1 m); `cell` and `look_cell` in the report are world XZ, and `anchor` names the plan record. Eye cameras are perspective with a 65 degree FOV; the gameplay camera reproduces the orthographic follow camera (pitch -30, yaw 45, boom 90, `CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE`). Camera names are unchanged from R-1320, but the scenes are not: reports made before R-1536 measured the retired `viru_gate_foreland` and `lower_town_slice` maps and are not comparable (re-baseline before using `budgets --baseline`).

| Name | Anchor (first by plan ID) | Eye, height | Aim offset, height |
|---|---|---|---|
| `meadow_eye_level` | first `meadow` pasture, vertex centroid | anchor, 1.65 | (15, -9), 0.6 |
| `meadow_gameplay` | same | focus on anchor | gameplay camera |
| `grain_field_eye_level` | first `wheat` field, vertex centroid | anchor, 1.65 | (-6, 16), 0.4 |
| `woodland_interior` | largest `woods` record (`at`) | anchor, 1.65 | (-26, 2), 2.0 |
| `woodland_distance` | same wood, `radius + 42` south of `at` | edge point, 6.0 | (0, -42), 3.0 |
| `lower_town_street` | street 2.5 units out of the `landmark.kalev_smithy` door | anchor, 1.65 | (-2, -3), 0.35 |

**Layers and attribution.** `grass_near`, `grass_mid`, `grain`, `trees_lod0`, `trees_lod1`, `trees_lod2`, `shrubs`, `flowers`, `litter`, `veg_misc` (vegetation outside the named tiers: reeds, cattails, floating plants), and `other` (every non-vegetation node, fences and hay ricks included). An explicit `veg_layer` metadata tag wins. Otherwise the owning city builder decides, by its class or by the fixed root name the builder gives:

- `CityGrass`: `NearBlades_*` chunks are `grass_near`; mid-chunk `Blades` and `FarGrass_*` are `grass_mid`; the yarrow accent plants of a mid chunk are `flowers`. `CityForbs` layers are `flowers`;
- `CityFarmland`: `Crop_*` batches and `FarFields` are `grain`;
- `CityTreeLod` (real-size near and macro crowns) is `trees_lod0`; `MapViewTreeMeshes.CITY_SHRUBS` species are `shrubs`;
- direct children of the `Vegetation` root (`CityVegetationBuilder`) go by the visibility range the builder sets: `WOOD_RANGE` trunks are `trees_lod0` (the only trunk mesh), `CROWN_RANGE` far card crowns are `trees_lod1`, `BUSH_RANGE` batches (bushes and shrub-species trees) are `shrubs`. The builder emits one batch per species and 96-unit chunk under the same name, and Godot renames the duplicates, so names cannot attribute them;
- `MoatPlants` batches are `veg_misc`. Their AABB spans the whole moat, so every camera submits them;
- `TreeLeafFall3D` descendants are `litter`. `trees_lod2` has no city producer and stays zero.

**Counting rule.** A geometry node counts when it is visible in the tree, its world AABB intersects the camera frustum, and its AABB centre is within its `visibility_range_end` (the per-node tests Godot's scene cull applies). A MultiMesh is culled as a whole, so all of its instances count. Triangles are mesh triangles times instances; draw calls are surfaces per submitted node (main pass); `shadow_draw_calls` counts the same surfaces again when the node casts shadows (once per node, not per cascade split).

**Timing.** Frame time is the median of synchronous frames: `RenderingServer.force_draw()` (the main loop skips drawing while the window is minimized) followed by a render-target readback that waits for the GPU. Layer cost (`--layer-timing`) is the median of paired frames with the layer shown and hidden. Small layers repeat within about 1 ms; the tree layer varies by tens of percent, so milliseconds are advisory and counts are the gate.

**Schema** (`rr.vegetation_benchmark.v1`): top level `schema`, `scene` (`reval_city`, R-1536), `godot`, `renderer`, `display_server`, `host {os, cpu, arch, gpu}`, `resolution`, `timed`, `layer_timing`, `frames`, `layers` (the ordered list above), `cameras[]`. Each camera: `name`, `map_id` (`reval_city`), `anchor` (plan ID, R-1536), `mode` (`eye` or `gameplay`), `projection`, `fov` or `size`, `cell`, `look_cell`, `position`, `layers {<layer>: {nodes, instances, triangles, draw_calls, shadow_draw_calls}}`, `totals {all, vegetation}`, `vegetation_share {triangles, draw_calls}`, `unattributed_top` (largest `other` nodes, for auditing attribution), `forbs {instances, triangles, draw_calls, models, chunk_build_ms, refill_ms, update_for_step_ms}` (R-1558, CityForbs only, with `forb_hotspot_*` cameras the tool places itself), `gpu {frame_ms_median, draw_calls_peak, primitives_peak, objects_peak}`, and with layer timing `layer_ms {<layer>: {frame_ms_saved, frame_ms_shown, draw_calls_saved}}`. Counts are integers. Vegetation layers reproduce exactly on the same build, across runs, between a `--camera=` run and the full set, and with or without `--layer-timing` (checked for R-1536 with `vegetation_performance.py compare`). The `other` layer also holds moving city content. Between a counts-only run and a longer timed run it can differ by a few nodes (seen at `lower_town_street`, about 0.5 % of its triangles), so compare runs made in the same mode. Adding a layer or camera bumps the schema version.

**Budgets.** `tools/vegetation_performance.py budgets` checks counts against the target budgets in its `BUDGETS` table (documented with their reasoning in [`VEGETATION_REALISM.md`](./SYSTEMS/VEGETATION_REALISM.md) section 8). With `--baseline`, each limit is `max(target, baseline)`: a layer already over target may not grow, a layer under target may grow up to it. Millisecond findings print as advisory warnings. Baseline run and findings: [`docs/reports/vegetation_benchmark_baseline.md`](./reports/vegetation_benchmark_baseline.md) (taken on the retired maps; superseded until a city re-baseline lands).

Verify: `python3 -m unittest tests.python.test_vegetation_performance -v`.

## Hardware identity and interpretation

`target_hardware` is the declared machine profile for which the run is intended. `measurement_host` is what Godot detects at runtime. They are intentionally separate so a report made on a fast developer machine cannot be mistaken for minimum-hardware proof.

The committed profile, `development-baseline-m5-pro`, records the current reproducible development baseline. Its status is `development_baseline_not_minimum`. It is not a supported-platform or minimum-hardware declaration. P3-011 owns selection of the actual minimum target and its release budgets.

Headless runs use the dummy renderer. They are valid for deterministic command smoke, CPU-side scene/pipeline timings, memory, actor/node/collision counts, and regression evidence, but not for target-GPU acceptance. Before using frame time for P0-038 or P3-011 acceptance, run the full command non-headlessly on the declared target and retain the generated JSON as release evidence outside source Git.

## R-653 minimum-hardware GPU run checklist

Use this checklist only for the declared target run owned by R-563. It does not authorize a benchmark run on a substitute host or change any performance budget.

1. **Select the declared target profile:** `minimum-hardware-intel-uhd-620` from [`tools/benchmarks/minimum-hardware.json`](../tools/benchmarks/minimum-hardware.json). Record its Intel Core i5-8250U / Intel UHD Graphics 620 / 8 GiB / `1920x1080` values before the run.
2. **Use a real display:** the acceptance run must be non-headless. Do not use `--headless`; require the raw report to record `headless=false` and the detected OS/display driver.
3. **Run the full 120-frame capture:** do not pass `--quick`, because that intentionally reduces the distribution to 20 samples.

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
tools/godot_render.sh \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1920x1080 \
  res://tools/benchmarks/renderer_comparison_benchmark.tscn \
  -- --output=/tmp/r653-renderer-comparison.json \
  --renderer-requested=gl_compatibility
```

4. **Retain provenance:** copy the raw JSON to the release-evidence location without rewriting it; record its SHA-256, repository revision, UTC timestamp, OS and driver, detected CPU/GPU, Godot version, renderer, and `frame_time_ms.samples=120`.
5. **Separate target from host:** compare the declared profile with Godot's detected `measurement_host`. An Apple host, another non-target GPU, or any headless result is supplementary instrumentation only and cannot certify `minimum-hardware-intel-uhd-620`.
6. **Run documentation checks without acquiring hardware:** validate the profile with `python3 -m json.tool tools/benchmarks/minimum-hardware.json`, run the relevant evidence/report checks, and finish with `git diff --check`. No acceptance decision is implied by these checks alone.

## R-713 sky-weather quality-tier budget handoff

The R-713 weather presenter has explicit `minimum` and `recommended` renderer-cost budgets for cloud resolution, shader samples, rain particles, fog quality, FFT cascade count, sky-view LUT size/cadence, ripple-sim resolution, frame time, and memory. The values and the retained measurement template live in [`r713_environment_performance.md`](reports/r713_environment_performance.md). Both isolated performance rows are currently **BLOCKED**: the declared Intel UHD 620 minimum target has not been measured (`R-653`), and the available Apple M5 / headless whole-scene reports do not isolate sky-weather tier cost (`R-822`). Keep `target_hardware` and `measurement_host` separate; do not promote a development-host or dummy-renderer observation to minimum-hardware acceptance.
