# WS-04 — Water shader samples the baked FFT cascades

Part of the [water and sky task pack](README.md). Source technique: Tidewater `oceanDisplacement`,
`oceanDerivatives` and `oceanLOD` (cascade sampling, choppy normal from derivatives, and a distance
fade for small cascades).

## Player-facing goal

Open Baltic water in the harbour and coastal maps moves like a real sea. Long swells carry shorter
wind waves on top of them. Crests are sharp, troughs are broad, and wave groups build and fade.
The wave pattern follows the weather's wind heading. The sea visibly flattens in calm weather and
gets steep and confused in a storm. There is no visible repeating four-wave pattern.

## Allowed files

- `scripts/map/view3d/map_view_water.gdshader`
- `scripts/map/view3d/map_view_water_materials.gd`
- `scripts/map/view3d/map_view_runtime_environment.gd` (drives the `ocean_time` global)
- `scripts/map/view3d/sky_weather_3d.gd` (only to add `ocean_fft_cascades` to `QUALITY_TIERS`)
- `project.godot` (the `shader_globals` entry for `ocean_time`, nothing else)
- `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_r715_water_weather_sync.gd`,
  `tests/godot/test_ocean_fft_material.gd` (new)
- `docs/reports/images/ws04_*.png`
- `TODO.md`

## Dependencies

- TODO: **WS-03** (the baked atlases and `ocean_fft_profile.json` exist).
- Must ship together with **WS-05** (boat parity) or stay disabled by default until WS-05 lands. See
  step 8.
- Stable IDs: none. The water terrain IDs are unchanged.

## Constraints and non-goals

- Keep the existing Gerstner path (`_water_field`) as the **fallback**. Rivers
  (`flow_strength > 0`) and puddles keep Gerstner. Select the path with `uniform bool use_fft`.
- Harbour basins must **stay on the FFT path**, because that's where players look at the water most.
  `TERRAIN_WATER` has `standing: 0.42`, `TERRAIN_SHALLOW_WATER` has 0.18 and `TERRAIN_DEEP_WATER`
  has 0.08 (`WATER_WAVE_BASE`). FFT waves only travel, so emulate standing waves as in step 6a.
- Keep the shore fade and shoaling (`displacement_fade`, `shoaling`) and the tide terms unchanged.
- Don't do foam styling here (that's WS-06). The FFT path only needs a working placeholder foam from
  the baked alpha channel.
- No per-frame GDScript work beyond setting one global float.

## Deliverable

1. **One ocean clock.** Register `global uniform float ocean_time` in `project.godot`
   (`[shader_globals]`). `MapViewRuntimeEnvironment.advance_cycle(scaled_delta, …)` is already
   called every frame from `MapViewRuntime._process`. Accumulate `scaled_delta` there, so the time
   controls pause and scale the sea together with the weather, and publish it with
   `RenderingServer.global_shader_parameter_set("ocean_time", t)`. Expose `ocean_time()` for the
   CPU side. Keep `t` wrapped to `fmod(t, 25.6 · 64)` so float precision never degrades. The shader uses `ocean_time`
   instead of `TIME` on the FFT path. WS-05 reads the same value on the CPU, which fixes today's
   drift between `TIME` in the shader and `Time.get_ticks_msec()` in `BoatFloat3D`.
2. **Uniforms** (set by `map_view_water_materials.gd` from `ocean_fft_profile.json`, loaded once
   and cached in a static):
   ```glsl
   uniform bool use_fft = false;
   uniform sampler2DArray fft_c0_disp  : filter_linear, repeat_enable;
   uniform sampler2DArray fft_c0_deriv : filter_linear_mipmap, repeat_enable;
   uniform sampler2DArray fft_c1_disp  : filter_linear, repeat_enable;
   uniform sampler2DArray fft_c1_deriv : filter_linear_mipmap, repeat_enable;
   uniform sampler2DArray fft_c2_deriv : filter_linear_mipmap, repeat_enable;
   // per cascade: x = patch size in world units (patch_m / 0.87), y = loop period s, z = frames, w = weight
   uniform vec4 fft_cascade[3];
   uniform vec4 fft_disp_scale[2];   // Dx, Dy, Dz scale; w unused
   uniform vec4 fft_deriv_scale[3];  // dDy/dx, dDy/dz, dDx/dx, dDz/dz
   uniform float ocean_amplitude = 1.0;   // 1 = baked reference sea state
   uniform int fft_cascade_count = 3;     // quality tier
   ```
3. **Wind rotation.** The bake has the wind along +X. Rotate the sample position by the wind angle
   before the lookup, `p' = R(−angle(wind_direction))·xz`. Rotate the resulting horizontal
   displacement and slopes back by `R(+angle)`. `wind_direction` already exists and is driven by
   SkyWeather.
4. **Frame blend** helper, used for every cascade and texture:
   ```glsl
   vec4 _fft_sample(sampler2DArray tex, vec2 uv, vec4 c, float lod) {
       float f = fract(ocean_time / c.y) * c.z;
       float i0 = floor(f);
       float i1 = mod(i0 + 1.0, c.z);
       vec4 a = textureLod(tex, vec3(uv, i0), lod);
       vec4 b = textureLod(tex, vec3(uv, i1), lod);
       return mix(a, b, f - i0);
   }
   ```
   `uv = p' / c.x` (world units ÷ patch world size). Decode each channel as `(v − 0.5)·2·scale`.
   The disp textures use `lod = 0`. The deriv textures in `fragment()` compute a LOD by hand from
   `fwidth(uv)·N`, because sampler arrays with explicit layers don't pick mip levels automatically in
   every GL driver.
5. **Vertex stage (FFT path):**
   `D = Σ_{c<2} w_c·decode(c_disp)`. Scale horizontal by `choppiness`. Convert metres to world units
   (`/ 0.87`) and multiply by `ocean_amplitude`. Apply the existing `displacement_fade` and
   `shoaling`. **Replace** `wave_height` on this path. `wave_height` stays the Gerstner amplitude
   only.
6. **Fragment stage (FFT path):** sum the slopes and Jacobian derivatives of all active cascades at
   the *undisplaced* `wave_sample_xz` (same reasoning as today's comment about the swimming normal):
   ```glsl
   vec2 S = Σ w_c·(dDy/dx, dDy/dz);           // world-units-consistent
   vec2 J = Σ w_c·(dDx/dx, dDz/dz) * choppiness;
   vec3 n = normalize(vec3(-S.x / (1.0 + J.x), 1.0, -S.y / (1.0 + J.y)));
   ```
   Fade C2, then C1, towards zero weight with camera distance (Tidewater `oceanLOD`). Start about
   40 world units for C2 and about 160 for C1, and tune on the capture. Let the existing detail
   normal take over what the fade removes. Replace the Gerstner `normal_terms.y` crest term used by
   the crest SSS glow with `crest = clamp(1.0 − (1.0 + J.x)·(1.0 + J.y), 0.0, 1.0)`.
6a. **Standing waves on the FFT path.** Two equal wave trains travelling in opposite directions
   add up to a standing wave. Sample every cascade a second time with the wind angle turned by π
   (i.e. `−p'`, with the displacement and slopes negated back), and blend:
   `F = mix(F(p'), 0.5·(F(p') + F_opposite), standing_wave_ratio)`. This doubles the samples only
   where `standing_wave_ratio > 0.01`. Branch on the uniform so open sea pays nothing. Reduce
   choppiness by `(1 − standing·0.65)` as the Gerstner path does today.
7. **Weather mapping** in `apply_sea_weather`. It currently maps wind and storm to Gerstner
   `wave_height`, `choppiness` and `wave_chaos`. Add cascade weights (`fft_cascade[i].w`) and
   `ocean_amplitude` from the same inputs. Starting table (tune on captures and record the final
   table in the code comment):

   | Sea state | C0 w | C1 w | C2 w | choppiness | ocean_amplitude |
   |---|---|---|---|---|---|
   | calm (wind ≈ 0.2) | 0.15 | 0.45 | 0.8 | 0.6 | 0.5 |
   | reference (wind ≈ 0.5) | 1.0 | 1.0 | 1.0 | 0.9 | 1.0 |
   | storm (storm chop 1) | 1.8 | 1.4 | 1.2 | 1.15 | 1.6 |

   Interpolate smoothly, with no jump when the weather changes. Weather transitions already blend
   over `SkyWeather3D.TRANSITION_SECONDS`.
8. **Enablement.** `water_surface()` sets `use_fft = true` only for open sea and coastal terrains
   (look at `MapTypes.WATER_TERRAINS` and `OPTICAL_DEPTH_BY_TERRAIN` for the IDs) **and** only when
   `BoatFloat3D` reports FFT support (a constant WS-05 adds). Until WS-05 lands that constant is
   false, so this task can merge safely with the FFT path covered by tests and turned on only for
   captures.
9. **Quality tiers.** Add `ocean_fft_cascades` to both rows of `SkyWeather3D.QUALITY_TIERS`:
   `recommended = 3` and `minimum = 2` (C2 off, detail normal only). The water material reads it
   when the material is built. Changing the tier needs a material rebuild, and that's acceptable.

## Verification

1. The headless Godot suite passes. New `test_ocean_fft_material.gd`:
   - the profile JSON loads, and the cascade uniforms equal `patch_m/0.87`, the period and the frame
     count
   - sea terrains get `use_fft` (with a test hook that forces the WS-05 support flag) and rivers
     don't
   - the weather table is monotonic from calm to storm
   - the `minimum` tier sets `fft_cascade_count = 2`
2. `test_r715_water_weather_sync.gd` is extended so a weather change moves the cascade weights and
   `wind_direction` together.
3. Captures (Metal and Compatibility, FFT forced on), on the harbour map `reval_harbor_north`:
   `clear/day`, `overcast/day` and `storm/day`, plus a 10-second clip at `clear/day`. Checks:
   - there is no visible tiling at the gameplay zoom, including when zoomed fully out
   - no seam or pop when the 25.6 s loop wraps (watch a fixed spot across the wrap)
   - storm waves are visibly steeper and more confused than calm ones
   - changing the wind heading turns the wave trains
4. Performance: `tools/run_performance_report.sh --quick` and
   `python3 tools/verify_r715_water_performance.py`. The FFT path costs about 4 array samples per
   vertex and about 6 per fragment. Report the frame-time change on the harbour benchmark. It must
   stay inside the existing water budget, or the task must document the new budget.
5. `python3 tools/generate_active_docs_report.py --check`, `git diff --check`.

## Documentation updates

- The code comment above the weather table (the final tuned values).
- `TODO.md` row:
  ```text
  - [ ] WS-04 | deps: WS-03 | deliverable: water shader FFT path sampling baked C0/C1 displacement and C0-C2 derivatives with frame blending, wind rotation, distance LOD, ocean_time global clock and weather-driven cascade weights; Gerstner kept for rivers/standing basins/fallback | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_runtime_environment.gd`, `scripts/map/view3d/sky_weather_3d.gd`, `project.godot`, `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_r715_water_weather_sync.gd`, `tests/godot/test_ocean_fft_material.gd`, `docs/reports/images/ws04_*.png`, `TODO.md` | verify: headless suite incl. new FFT material test; harbor clear/overcast/storm captures show no tiling, no loop seam, wind-steered trains; performance report within water budget
  ```
