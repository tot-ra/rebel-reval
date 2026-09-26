# CO-08: Wind direction and a labelled wind-to-wave-height continuum

Board row: **R-955**. Priority: high. Depends on: none.

## Player-facing goal

The sea obeys the weather the player can see. In a calm the water is almost flat; in a fresh breeze
there is a short chop running in one direction; in a gale the wave trains lengthen, steepen and start
throwing whitecaps; in a storm the sea is high and streaked. The wind blows from a **direction that
changes** between weather states and over a long day, and everything that reads wind - waves, foam
streaks, boat heel, rigs, vegetation gusts, chimney smoke - turns together. Behind a headland or a
quay wall the sea is noticeably calmer than out in the open.

## Why this is needed

Two different problems, measured 2026-09-26.

**The good part already exists.** `MapViewWaterMaterials.OCEAN_FFT_SEA_STATES` plus
`fft_sea_state_scalar(wind, rain)` already map weather onto significant wave height: clear Hs 0.16 m,
cloudy 1.36 m, overcast 1.67 m, storm 3.01 m, rain/storm 3.48 m against the WS-03 reference of
1.26 m. `BoatFloat3D` scales hull motion by `lerpf(0.55, 1.45, wind) * lerpf(1.0, 1.4, rain)`. So wave
height *does* already follow wind strength, and the task must not re-derive it.

**The broken part.** `SkyWeather3D.wind_direction_xz()` (`sky_weather_3d.gd:1004`) returns

```gdscript
return CLOUD_DRIFT_PER_SECOND.normalized()   # const Vector2(0.0011, 0.00044)
```

a **compile-time constant**, roughly (0.93, 0.37), for the entire game. Every consumer inherits it:
`boat_float_3d.gd:121,171`, `map_view_3d.gd:220,226` (water and ripples), `sky_weather_3d.gd:1175,1200`
(cloud drift and the sky shader `wind_dir`), `chimney_smoke_3d.gd:180`. The wind therefore blows from
the same quarter in every scene, in every weather, forever - which is why the sea reads as a texture
that gets rougher rather than as a sea being driven by weather. There is also no shelter model: the
open sea and the lee of a quay get the same sea state.

## Deliverable

1. **Real wind direction** in `SkyWeather3D`: a deterministic direction per weather state plus a slow
   continuous veer over the day cycle and a short-lived gust shift, exposed through the existing
   `wind_direction_xz()` so no consumer needs changing. `CLOUD_DRIFT_PER_SECOND` becomes a
   base/reference, not the answer. Cloud drift and the sky shader `wind_dir` follow the same value, so
   clouds and waves cannot disagree.
2. Direction is part of the weather snapshot (`sky_weather_3d.gd:808` already stores
   `snapshot.wind_direction`), so it **survives save/load and map transitions** with no visible jump.
   The R-713/R-854 weather-continuity fixtures must cover it.
3. A **documented Beaufort ladder** in `docs/SKY_WEATHER_STATE_CONTRACT.md`: for each weather preset,
   the Beaufort force, the mean wind speed in m/s, the resulting Hs in metres, the existing
   `sea_state` scalar and the whitecap onset. Derive it from the numbers already in
   `OCEAN_FFT_SEA_STATES`; adjust only where the ladder shows a gap (for example, the jump from clear
   0.16 m to cloudy 1.36 m skips the whole fresh-breeze range, so an intermediate row is expected).
4. **Whitecap onset tied to the ladder**: the WS-06 foam threshold keys off Beaufort force rather than
   a hand-tuned constant, so foam appears when the ladder says it should (roughly force 4 and above).
5. **Fetch and shelter**: a cheap per-cell shelter term from distance to upwind land, so the lee of a
   headland, a quay or a pier carries reduced wave amplitude and foam. Reuse the WS-08 shore distance
   field; do not add a new field.
6. `BoatFloat3D`'s `lerpf(0.55, 1.45, wind)` motion scale is replaced by a read of the shared ladder
   so hull motion, surface displacement and the CO-07 rig all quote the same sea state.

## Allowed files

- `scripts/map/view3d/sky_weather_3d.gd`
- `scripts/map/view3d/map_view_water_materials.gd`
- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_3d.gd` (shelter term wiring only)
- `scripts/map/view3d/boat_float_3d.gd` (sea-state read only)
- `scripts/map/view3d/ocean_fft_sampler.gd` (shared sea-state mapping only)
- `docs/SKY_WEATHER_STATE_CONTRACT.md`
- `tests/godot/test_sky_weather_3d.gd`, `tests/godot/test_weather_realism.gd`,
  `tests/godot/test_r715_water_weather_sync.gd`, `tests/godot/test_r713_sky_weather_continuity.gd`,
  `tests/godot/test_ocean_fft_sampler.gd`, `tests/godot/test_sea_state_ladder.gd` (new)
- `tools/capture_co08_sea_states.gd` (new)
- `docs/reports/co08_sea_state_ladder.md`, `docs/reports/images/co08_*.png`, `TODO.md`

## Constraints and non-goals

- Do not re-bake the FFT cascades. WS-03's bake and its Hs 1.26 m reference stay as they are; this
  task changes the **mapping and the direction**, not the baked field.
- Do not change the water surface look in calm weather beyond what the ladder requires. Existing WS-02,
  WS-06, WS-07 and WS-11 plates must stay valid or be re-recorded with a reason.
- Wind direction must be **deterministic** from the weather/clock state, never `randf()`. Two clients
  with the same save show the same sea.
- No new fields, no new render targets, no per-frame readback. The shelter term is derived from an
  existing field.
- Do not touch vegetation or smoke behaviour beyond them receiving the now-varying direction. If a
  consumer looks wrong with a rotating wind, record it as a follow-up rather than special-casing it.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sea_state_ladder,test_sky_weather_3d,test_weather_realism,test_r715_water_weather_sync,test_r713_sky_weather_continuity,test_ocean_fft_sampler
python3 tools/generate_active_docs_report.py --check
python3 tools/verify_r715_water_performance.py
```

- `test_sea_state_ladder.gd` asserts: `wind_direction_xz()` is no longer constant across weather
  states and varies over the day cycle; direction is deterministic for a fixed clock+weather seed;
  cloud drift, sky `wind_dir`, water, ripples, boats and smoke all report the same direction within
  tolerance; Hs is monotonically non-decreasing in Beaufort force across the documented ladder;
  whitecap onset sits at the documented force; the sheltered lee of a quay has lower amplitude and
  foam than open water at the same weather.
- Continuity: save in a gale, load, cross a transition - wind direction and sea state match with no
  step (extend the R-713/R-854 fixtures).
- `tools/capture_co08_sea_states.gd` through `tools/godot_render.sh`: Harbor North plates at calm,
  fresh breeze, gale, storm, and two plates at the same weather with wind from opposite quarters
  showing the wave trains and foam streaks turning, plus a sheltered-lee plate. Before and after,
  Compatibility and Metal.

## Doc updates

`docs/SKY_WEATHER_STATE_CONTRACT.md` Beaufort ladder, `docs/reports/co08_sea_state_ladder.md`,
`TODO.md`.

## TODO.md line

```
- [ ] R-955 | deps: none | deliverable: real deterministic wind direction in SkyWeather3D replacing the constant CLOUD_DRIFT_PER_SECOND.normalized(), a documented Beaufort force / wind speed / Hs / sea_state ladder shared by water, sampler, boats and rigs, Beaufort-keyed whitecap onset, and a fetch/shelter term off the WS-08 shore field | allowed files: per docs/tasks/coast/CO-08_sea_state_wind_coupling.md | verify: `--filter=test_sea_state_ladder,test_sky_weather_3d,test_weather_realism,test_r715_water_weather_sync,test_r713_sky_weather_continuity,test_ocean_fft_sampler` incl. non-constant deterministic direction, all consumers agreeing, Hs monotonic in force, documented whitecap onset and sheltered lee < open water; save/load and transition continuity; water performance verifier; calm/breeze/gale/storm, opposite-quarter and sheltered-lee plates on Compatibility and Metal
```
