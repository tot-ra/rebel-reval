# WS-11 — Water reflection, fog, sun and ambient colour come from the atmosphere

Part of the [water and sky task pack](README.md). Source technique: Tidewater's shared frame
lighting (`frame.skyIrradiance`, `frame.horizonColor`, `envIntensity`), its sky-irradiance readback
(`atmoIrr`), and `HazeParams`. Everything that is lit or reflected (the sun light, ambient, fog and
water reflection) samples **one** atmosphere, so they never disagree.

## Player-facing goal

At sunset the whole scene agrees. The sunlight on walls turns the same orange as the sun disk. The
sea reflects the actual sky above it: a warm horizon on the sun's side and the pink Earth-shadow band
on the other. Morning mist and rain haze take the colour of the sky's horizon. Shadows are filled
with bluish skylight at noon and dim violet light at dusk. None of it drifts out of sync during the
compressed day.

## Why

Today these colours come from separate hand-tuned constants:

- `map_view_lighting.gd`: `SUN_DAY_COLOR`, `SUNSET_LIGHT_COLOR`, `AMBIENT_DAY_COLOR`,
  `BACKGROUND_*`, the mist colour
- the water shader's `_sky_dome_gradient()`, which gets `day_top_color` and the rest through
  `apply_water_sky_reflection`

After WS-10, the sky dome is physical and these no longer match it.

## Allowed files

- `scripts/map/view3d/atmosphere_cpu.gd` (new, `class_name AtmosphereCpu`: CPU evaluation from the
  WS-09 LUT images)
- `scripts/map/view3d/map_view_lighting.gd`
- `scripts/map/view3d/map_view_water_materials.gd` (`apply_water_sky_reflection` signature)
- `scripts/map/view3d/map_view_materials.gd` (forwarding the sun colour it already passes)
- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/sky_weather_3d.gd` (expose the LUT texture and sun azimuth in
  `WeatherPresentation`)
- `scripts/map/view3d/atmosphere_common.gdshaderinc` (the shared sky-view lookup function)
- `tests/godot/test_atmosphere_cpu.gd` (new), `tests/godot/test_r715_water_weather_sync.gd`,
  `tests/godot/test_weather_realism.gd`
- `docs/reports/images/ws11_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-10** (the LUT texture exists and the sky uses it) and **WS-02** (the water `light()`
  path, so the sun colour lands on the glint correctly).
- Stable IDs: none. `WeatherPresentation` gets new fields. Nothing is serialised.

## Constraints and non-goals

- **No per-frame GPU readback.** Compute the CPU-side colours in GDScript from the *static* WS-09
  LUT images, loaded once with `Texture2D.get_image()`. That makes the path deterministic and
  testable headless.
- Update the CPU colours at most every 0.25 s of real time and smooth them with an exponential
  filter (τ ≈ 0.3 s) so the compressed day never steps visibly.
- Weather modifiers stay authoritative. Overcast, rain and lightning keep their current lerps on top
  of the physical base colours (`OVERCAST_LIGHT_COLOR`, `LIGHTNING_LIGHT_COLOR`, etc.).
- Keep every `*_COLOR` constant as an **art-direction tint** that multiplies the physical colour,
  initialised to white-equivalent so that the physical colour is the default. Name them
  `*_ART_TINT`. Don't delete the old constants until the review accepts the captures.
- Interiors are untouched (`enclosed_interior`, `interior_top_down` paths).

## Deliverable

1. **`AtmosphereCpu`** (static helpers + small cache):
   - `load()`: the transmittance and multi-scatter `Image`s (FORMAT_RGBAH), with bilinear sampling
     helpers that use the same UV mapping as `atmosphere_common.gdshaderinc`.
   - `sun_color(sun_dir) -> Color`: `sun_illuminance · T(ground, μ_sun)`, normalised to a
     displayable colour plus a separate `energy`. The colour comes from the ratio, and the energy
     from the luminance relative to noon.
   - `sky_irradiance(sun_dir) -> Color`: the cosine-weighted hemisphere irradiance on an upward
     surface. Evaluate single scattering + Ψ_ms with **16 fixed directions × 12 steps** in GDScript,
     reusing the WS-10 integration maths. It runs well under 1 ms. The test measures it.
   - `horizon_color(sun_dir, towards_dir) -> Color`: the sky radiance at 2° elevation, averaged
     over 8 azimuths (for fog), and also returned for the sun-facing azimuth (for sun-scatter fog).
2. **Lighting (`map_view_lighting.gd`):**
   - `sun.light_color` = `AtmosphereCpu.sun_color` × `SUN_ART_TINT`, then the existing overcast and
     lightning lerps. The twilight hand-off to the moon (`sun_light_weight`) stays as it is. Only
     the sun side of the blend becomes physical.
   - `sun.light_energy` stays `SUN_DAY_ENERGY`-based, multiplied by the relative physical energy
     (clamped 0.15–1).
   - `environment.ambient_light_color` = normalised `sky_irradiance` × `AMBIENT_ART_TINT` during
     the day, blended to today's night ambient by `1 − day_blend`. The ambient source stays
     `AMBIENT_SOURCE_COLOR`.
   - Mist, rain haze and fog: `environment.fog_light_color` = `horizon_color` averaged, and
     `environment.fog_sun_scatter` from Mie (about 0.2–0.35, stronger when hazy).
3. **Water reflection:** `apply_water_sky_reflection` passes the sky-view LUT texture, the sun
   azimuth, the exposure and tint, and the decode mode (HDR or RGBM from WS-10) instead of the
   gradient colours. In the water shader, replace `_sky_dome_gradient(reflected_sky_ray)` with
   `atmosphere_sky_view(reflected_sky_ray, …)` from the shared include. Use exactly the same
   night-gradient blend as the sky shader so reflections still work after dark. Clouds are *not* in
   the LUT. Keep the existing `cloud_darken` factor on the reflection.
4. **Consistency hook:** add `presentation.sky_lut`, `presentation.sun_azimuth` and
   `presentation.physical_sun_color` to `WeatherPresentation`, so the terrain and prop materials
   that already receive `sun_color` in `map_view_materials.gd` get the same value.

## Verification

1. The headless Godot suite passes. `test_atmosphere_cpu.gd` checks:
   - `sun_color` at the zenith is near-white, and at 2° elevation it is red > green > blue
   - `sky_irradiance` is blue-dominant at noon
   - the CPU zenith transmittance equals the WS-09 oracle (0.940, 0.868, 0.762) ± 0.01
   - output is deterministic for a given sun direction
   - one full evaluation (all three functions) takes under 1 ms, averaged over 100 runs
   `test_weather_realism.gd` and `test_r715_water_weather_sync.gd` pass. Update them where they
   assert the old constants, and assert the tint path instead.
2. Captures (Metal and Compatibility), `reval_harbor_north`, sun at 60°, 10°, 2° and −3°, weather
   `clear`, plus `rain/day` at 30° and a first-light plate with morning mist. Checks:
   - the lit walls, sun disk and sun glitter on the water share one hue at 2°
   - the sea reflects the Earth-shadow band opposite the sun
   - noon shadows are blue-filled
   - mist is horizon-coloured, not grey
   - rain still looks like today's rain
3. A 60 s full-day clip with no visible stepping in light colour.
4. `tools/run_performance_report.sh --quick`: CPU time of the lighting update, which runs at 4 Hz.

## Documentation updates

- Comments at the `*_ART_TINT` constants explaining that physics is the base and the tint is art
  direction.
- `TODO.md` row:
  ```text
  - [ ] WS-11 | deps: WS-10, WS-02 | deliverable: AtmosphereCpu (sun colour, sky irradiance, horizon colour from static LUT images, 4 Hz, smoothed) driving DirectionalLight colour/energy, ambient and fog, and water reflections sampling the shared sky-view LUT; old colour constants become art tints | allowed files: `scripts/map/view3d/atmosphere_cpu.gd`, `scripts/map/view3d/map_view_lighting.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_materials.gd`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_atmosphere_cpu.gd`, `tests/godot/test_r715_water_weather_sync.gd`, `tests/godot/test_weather_realism.gd`, `docs/reports/images/ws11_*.png`, `TODO.md` | verify: AtmosphereCpu oracle/perf tests; sunset captures show sun disk, lit walls and sea glitter in one hue and the Earth-shadow band reflected in the sea; 60 s day clip without colour stepping
  ```
