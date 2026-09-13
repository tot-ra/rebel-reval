# Sky and weather realism — P0-211

The existing weather presenter now renders cloud depth through a finite slab,
with height-shaped density, internal billows, sunward extinction, high wisps and
closed stratiform decks. Atmospheric path length blends distant clouds into the
horizon. This is an original, bounded approximation for GL Compatibility, not a
full physical atmosphere or a claim of Witcher 3 rendering parity.

Sun and moon use approximately half-degree apparent diameters. Cloud drift is
slower, transitions take twelve seconds with eased starts/stops, and rain follows
the same world-space wind as the moving cloud banks. Overcast retains diffuse
fill while reducing direct sunlight and hard shadows. Rain adds distance haze,
slightly compresses contrast, and uses finer, less opaque streaks. Existing wet
ground, shelter, astronomy, lightning scheduling and reflection consumers remain
on the shared weather state.

No maps, content IDs, save schema, controls, or gameplay systems changed. Older
linear transition snapshots resume from their saved visible profile, avoiding a
zero-time jump when applying the new easing/lighting targets. The art-bible note
records the maintainer's requested atmospheric direction.

## Verification

Godot **4.7.1**, project-default **GL Compatibility**, Apple **M5 Pro**, 1280×720.

- Checked focused suite: **87 tests, zero failures/errors** across weather,
  astronomy, save envelope/service, continuity, mud and five new regression cases.
- New cases cover old-save transition continuity, interrupted easing, rain haze
  lifecycle and shelter, diffuse overcast lighting, and shared rain/wind direction.
- GDScript lint passes for all five changed/new scripts.
- `git diff --check` passes. Active-doc validation remains blocked by nine
  existing broken links in the concurrently modified root `README.md` and a
  stale aggregate report. None are in the new weather documentation.
- Independent agent review confirms correctness, simplicity and scope after
  correcting legacy easing continuity, cloud velocity sign, a capture-camera
  reset, and a concurrent task-ID collision.
- The broader lighting/water run is **not green**: the church window fixture
  reports missing panes/emissive windows, and `test_r715_water_weather_sync.gd`
  calls an absent `MapViewWaterMaterials.apply_weather_presentation()` method.
  Those tests and the water implementation were unchanged by this work. This
  refinement does not close the larger R-713/R-715 acceptance gates.

Run the focused checks:

```bash
tools/run_godot_checked.sh --require-test-summary weather-realism \
  /Applications/Godot.app/Contents/MacOS/Godot --headless \
  --script tools/run_godot_tests.gd -- \
  --filter=test_weather_realism,test_sky_weather_3d,test_sky_weather_state,test_sky_astronomy,test_r713_sky_weather_continuity,test_save_service,test_save_envelope,test_mud_weather
```

## Visual evidence

The capture tool uses the production shader, presenter, and lighting. A neutral
ground and four markers at increasing distances expose lighting and extinction.
The eight conditions are clear, cloudy, overcast, rain, isolated storm, dusk,
night and minimum quality. Original baseline plates were saved before edits;
the night camera was subsequently corrected, so use that plate as a qualitative
reference rather than an exact registered comparison. Day plates remain matched.

| Condition | Original | Revised |
|---|---|---|
| Cloudy | [before](images/weather_realism/before/cloudy.png) | [after](images/weather_realism/after/cloudy.png) |
| Clear | [before](images/weather_realism/before/clear.png) | [after](images/weather_realism/after/clear.png) |
| Overcast | [before](images/weather_realism/before/overcast.png) | [after](images/weather_realism/after/overcast.png) |
| Rain | [before](images/weather_realism/before/rain.png) | [after](images/weather_realism/after/rain.png) |
| Storm | [before](images/weather_realism/before/storm.png) | [after](images/weather_realism/after/storm.png) |
| Dusk | [before](images/weather_realism/before/dusk.png) | [after](images/weather_realism/after/dusk.png) |
| Night | [before](images/weather_realism/before/night.png) | [after](images/weather_realism/after/night.png) |
| Minimum | [before](images/weather_realism/before/minimum.png) | [after](images/weather_realism/after/minimum.png) |

Production Lower Town rooftop views: [clear](images/weather_realism/after/town_clear.png)
and [rain](images/weather_realism/after/town_rain.png). These use the existing
compiled map without changing authored or generated map content.

Reproduce revised plates and an existing Lower Town view:

```bash
tools/run_godot_checked.sh weather-plates \
  /Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script tools/capture_weather_realism.gd
tools/run_godot_checked.sh weather-town \
  /Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script tools/capture_weather_realism.gd -- --town
```

## Rendering cost and limits

The cloud calculation uses four depth samples at minimum and eight at recommended
quality. Worst-case cloud texture reads are approximately 34/66 per sky ray;
including rain, moon and lightning stays within the existing 80/140 texture-read
budgets. Texture sizes and particle caps are unchanged. This is more cloud work
than the previous flat layer.

The capture records 60 uncapped frame samples after warm-up, with live cloud
uniform updates, in [revised timings](images/weather_realism/after/timings.json).
[Baseline shader timings](images/weather_realism/baseline_shader/timings.json)
swap only the pre-change shader into the same current scene/resources to isolate
the shader comparison as far as this small viewport permits. These are whole
viewport CPU/frame observations, not isolated GPU timings or a representative
full-game benchmark. Other project tasks were active on the same host.

Observed whole-frame medians (old shader → revised) were 1.459 → 2.141 ms
for cloudy, 2.229 → 3.854 ms for rain and 1.861 → 2.710 ms for minimum.
The added cloud depth therefore has a measurable cost on this host; these short
runs are diagnostic comparisons, not release performance acceptance.

Godot's GPU timers return zero on this GL path; the packet records those results
as `null` (unavailable). The timing API and its scope are documented in the
[RenderingServer reference](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu).
Minimum-hardware GPU-budget qualification remains open; CPU/frame numbers do not
certify the R-713 1.5/2.5 ms weather GPU budgets.

To refresh the shader-only comparison while the pre-change shader is still HEAD:

```bash
git show HEAD:scripts/map/view3d/sky_weather_3d.gdshader > build/weather_baseline.gdshader
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --script tools/capture_weather_realism.gd -- --baseline-shader
```
