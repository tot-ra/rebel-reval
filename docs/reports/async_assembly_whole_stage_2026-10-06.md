# WB-07f whole-stage assembly units - 2026-10-06

Board row: **R-1095**, follow-up of R-1006 ([WB-07c](async_assembly_heavy_objects_2026-09-28.md)). Status: **in review**.

## What changed

`sky_weather`, `chunk_finalize` and `view_effects` were single units owned by `MapView3D` (4-11 ms). Each stage now returns follow-up units, which `MapViewAssembly.run_next()` already runs ahead of the queue, so the synchronous and staged paths still drain one plan.

| Stage | Units | Where |
|-------|-------|-------|
| `sky_weather` | `SkyWeather3D.configure_steps()`: setup, cloud noise, cloud shape, quality resources, moon, star-image alloc, star bake in 1000-star slices, star texture, sky dome, rain emitter, roof audio; then the rain gate | `sky_weather_3d.gd`, `sky_weather_resources.gd` (`new_star_image`, `bake_stars`) |
| `chunk_finalize` | terrain details, occluder reset, occluder bounds in 24-child slices of `Buildings` and `Landmarks`, chimney smoke, window lights | `MapViewAssembly.finalize_units()`, `MapView3D._append_occluder_slice()` |
| `view_effects` | water ripple sim, underwater pass, cloud shadow pass, mud footprints, fog of war | `MapViewAssembly.view_effects_units()` |

`configure()` still exists and runs every step in order, so other callers are unchanged. The sky node stops processing in the first step and resumes in the last: `advance()` reads the material, which is not built until the middle steps. Stars combine with `max()`, so slicing the bake does not change the star image. Occluder slices walk the same children with the same accumulated transform in the same order as the old whole-container walk.

## Numbers

Apple M5 Pro, Godot 4.7.1, headless, shared host. `async_assembly_trace.gd`, before (HEAD) -> after:

| Unit | Before | After |
|------|--------|-------|
| `sky_weather` (Kalev smithy / Lower Town / Harbor East) | 7.3 / 8.1 / 10.0 ms | none over 4 ms (largest step about 3 ms: rain emitter 2.3 ms, star slice 1 ms) |
| `chunk_finalize` (Lower Town) | 7.3 ms | under 1 ms in total |
| `view_effects` | under 4 ms headless; 7.8 ms on GPU in R-1006 | under 1 ms per effect |

Remaining over-budget units belong to other rows: neighbor props and walls (R-1096), `ground_publish` (no owner, see the R-1006 report) and `water_deep_water` (terrain).

## Verification

- `--filter=test_async_location_assembly,test_sky_weather_3d,test_sky_weather_state,test_r713_sky_weather_continuity,test_map_view_3d_runtime,test_world_host_streaming,test_r715_water_map_handoff,test_map_view_3d_mesh`: all pass.
- `test_map_view_3d_core` (2 water-optics checks) and `test_map_view_3d_lighting` (St. Catherine's window lights, 2 checks) fail identically on clean HEAD. Not caused by this change.
- Not measured: GPU trace through `tools/godot_render.sh` (not run in this session).
