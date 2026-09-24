# WS-10 — Physical sky dome from a sky-view LUT that follows the sun

Part of the [water and sky task pack](README.md). Source technique: Tidewater `skyViewLUT` 192×108
(`skyViewKernel`, `skyViewRadiance`), `SkyParams` (`sunDiskIntensity`, `moonDir`,
`starIntensity`), from Hillaire EGSR 2020 §5.3.

## Player-facing goal

The sky over Reval looks like a real northern sky. The zenith is deep blue and the horizon is pale
and hazy. At sunrise and sunset the sun turns orange-red, a warm glow spreads along the horizon on
the sun's side, and a pink band with blue-grey Earth shadow below it rises in the opposite sky.
Twilight fades through deep blue into the existing star field. Stars, moon, clouds, rain shafts and
lightning keep working as today.

## Why

`sky_weather_3d.gdshader` builds the sky from hand-tuned gradient uniforms (`day_top_color`,
`day_horizon_color`, `night_*`, `sunset_color` + `sunset_factor`). They can't produce the Earth
shadow, the colour shift of the sun disk, or the right sky brightness distribution around the sun.

## Allowed files

- `scripts/map/view3d/sky_atmosphere_lut.gd` (new, `class_name SkyAtmosphereLut`: owns the LUT
  `SubViewport`)
- `scripts/map/view3d/sky_view_lut.gdshader` (new, `canvas_item`: computes the LUT)
- `scripts/map/view3d/sky_weather_3d.gdshader`
- `scripts/map/view3d/sky_weather_3d.gd` (create and update the LUT node, add quality-tier rows,
  pass textures)
- `scripts/map/view3d/atmosphere_common.gdshaderinc` (only fixes found while integrating)
- `tests/godot/test_sky_atmosphere_lut.gd` (new), `tests/godot/test_sky_weather_3d.gd`
- `docs/reports/images/ws10_*.png`, and the re-captured R-713 continuity images if the verifier
  requires them
- `TODO.md`

## Dependencies

- TODO: **WS-09** (the LUT assets and `atmosphere_common.gdshaderinc`).
- Unlocks WS-11 (water, fog and lighting driven by the same atmosphere).
- Stable IDs: none. Weather state and save snapshots (`snapshot_state` / `apply_state`) must not
  change format.

## Constraints and non-goals

- **The day cycle is compressed** (`DayNightCycle`: one solar day ≈ 60 s real time), so the sun moves
  about 6°/s. The LUT must re-render **every frame** on `recommended`. On `minimum`, use every
  second frame at half resolution. Never cache across big sun changes.
- No CPU readback in this task (WS-11 adds one event-driven readback).
- Keep the stars (Hipparcos map, observer transform), the moon (phase, albedo map, earthshine),
  clouds, storm cells, rain shafts, lightning and the quality tiers exactly as they behave now.
  Only the **background sky radiance and the sun disk** change.
- **Art direction wins.** Keep `sky_exposure`, `sky_tint` and `sunset_boost` uniforms so the art
  bible look can be matched ([`docs/ART_BIBLE.md`](../../ART_BIBLE.md)). The first calibration goal
  is: noon horizon luminance within ±15% of today's `day_horizon_color`.

## Deliverable

1. **`SkyAtmosphereLut`** (a `Node`, created by `SkyWeather3D.configure`):
   - It holds a `SubViewport` (192×108 on `recommended`, 96×54 on `minimum`,
     `render_target_update_mode = UPDATE_ALWAYS` or `UPDATE_ONCE` driven by hand for the
     every-other-frame path). Inside is a full-rect `ColorRect` with `sky_view_lut.gdshader`.
   - **HDR storage:** check whether `SubViewport.use_hdr_2d = true` gives a float render target on
     GL Compatibility in Godot 4.7. Write a test render and read back one texel in a *non-headless*
     capture run. If it does, store the radiance directly. If it doesn't, encode **RGBM** (range 8)
     in RGBA8 and decode in the sky shader:
     `rgb = rgba.rgb · rgba.a · 8`. Document which path was chosen and why in the script header.
   - `update(sun_dir: Vector3, frame: int)` sets shader params. `sky_view_texture()` returns the
     `ViewportTexture`.
2. **`sky_view_lut.gdshader`** (Hillaire §5.3, includes `atmosphere_common.gdshaderinc`):
   - Map UV to a view direction relative to the sun's azimuth, with **non-linear latitude** so
     texels concentrate at the horizon (port exactly):
     ```text
     v_horizon = sqrt(r² − R_ground²);  β = acos(v_horizon / r);  zh = π − β
     uv.y < 0.5: c = 1 − (1 − 2·uv.y)²;       cos_view_zenith = cos(zh · c)
     else:       c = (2·uv.y − 1)²;            cos_view_zenith = cos(zh + β · c)
     cos_light_view = −(uv.x² · 2 − 1)
     ```
   - The camera height is the ground (`r = R_ground + 0.002 km`, as Tidewater's `viewHeight 6360.002`).
   - Ray-march up to 30 steps to the top of the atmosphere or the ground. Per step, compute the
     medium, sun transmittance from the transmittance LUT, the Earth shadow (`ray_sphere` with the
     ground), and scattering
     `σ_R·phase_R + σ_M·phase_M` from the sun, plus `Ψ_ms·σ_s` from the multi-scattering LUT.
     Integrate energy-conserving per step: `(S − S·T_step)/σ_t`.
   - Output `radiance · sun_illuminance` with `sun_illuminance = 11` as a uniform (Tidewater default).
3. **Sky shader integration** (`sky_weather_3d.gdshader`):
   - Look up the LUT with the inverse mapping from `EYEDIR` and the sun azimuth. Result:
     `day_sky = lut · sky_exposure · sky_tint`.
   - **Sun disk:** use the existing disk shape and halo, but colour it with
     `sun_illuminance · T(ground, μ_sun)` from the transmittance LUT, with limb darkening
     `1 − 0.6·(1 − sqrt(1 − (d/r)²))`. The disk goes orange-red at the horizon by itself.
   - **Night:** below civil twilight the physical sun sky goes to ~0. Keep the existing
     `night_top_color`/`night_horizon_color` gradient as a moonlit and airglow floor, blended in by
     `1 − day_blend`, and add the stars as today. Don't run a second LUT for the moon.
   - **Twilight tint:** `sunset_color`/`sunset_factor` stay as a small art-controlled boost on top
     (`sunset_boost`, default 0.25), not as the main sunset source.
   - **Clouds:** light them with the physical sun colour at cloud height
     (`T(R_ground + 1.5 km, μ_sun)` from the transmittance LUT) and an ambient term from the LUT
     averaged over the zenith and horizon (two LUT samples). This replaces the constant
     `sun_color` / day colour mix inside the cloud lighting only. The cloud shapes stay untouched.
   - Weather: `cloud_darken`, overcast and storm continue to multiply the result as today, applied
     after the LUT.
4. **Quality tiers:** add `sky_lut_size` and `sky_lut_every_n_frames` to
   `SkyWeather3D.QUALITY_TIERS`. If the WS-09 assets are missing, `cloud_fallback`-style
   fail-closed rules apply: fall back to the old gradient.

## Verification

1. The headless Godot suite passes. `test_sky_atmosphere_lut.gd` checks:
   - the node creates its viewport at the tier size
   - `update()` throttling follows `sky_lut_every_n_frames`
   - missing assets fall back to the gradient
   - the shader source contains the non-linear latitude mapping and includes
     `atmosphere_common.gdshaderinc`
   `test_sky_weather_3d.gd` still passes unchanged (snapshots and quality behaviour).
2. Captures (Metal and Compatibility), `reval_harbor_north`, with the sun set through
   `apply_sky_state` at elevations of **60°, 20°, 5°, 0°, −4° and −10°**, in `clear` weather.
   Required observations:
   - The zenith is darker blue than the horizon at 60°.
   - At 5° and 0° the sun disk is orange-red, the horizon glow is warm on the sun's side, and the
     opposite side shows a pink band over a blue-grey shadow band.
   - At −4° there is a deep-blue twilight and the first stars.
   - At −10° the night looks like today.
   - `overcast` and `storm` at 20° look like today (dim and grey).
   Place them side by side with the pre-change captures in the report.
3. `tools/capture_r713_sky_weather_continuity.gd` and
   `python3 tools/verify_r713_sky_weather_acceptance.py` /
   `python3 tools/verify_r713_sky_weather_evidence.py` still pass. If they compare images,
   re-capture following their documented procedure and note the reason ("WS-10 physical sky").
4. Performance: the LUT pass is 192×108 × 30 steps per frame. Report its GPU cost from
   `tools/run_performance_report.sh --quick`. The sky pass itself should get *cheaper*, because one
   LUT fetch replaces the gradient maths.
5. Record a 60 s clip of one full compressed day. There must be no flicker, no banding in the
   twilight gradient, and no pop when the LUT updates.

## Documentation updates

- The script header in `sky_atmosphere_lut.gd`, recording the HDR vs RGBM decision.
- [`docs/SKY_WEATHER_STATE_CONTRACT.md`](../../SKY_WEATHER_STATE_CONTRACT.md): a short note that the
  sky radiance comes from the atmosphere LUT and that the state contract is unchanged. Add that file
  to the allowed files when you do this.
- `TODO.md` row:
  ```text
  - [ ] WS-10 | deps: WS-09 | deliverable: per-frame Hillaire sky-view LUT in a SubViewport (HDR or RGBM) driving the sky dome background, transmittance-coloured limb-darkened sun disk and physically lit clouds, with art-direction exposure/tint/sunset-boost and gradient fallback | allowed files: `scripts/map/view3d/sky_atmosphere_lut.gd`, `scripts/map/view3d/sky_view_lut.gdshader`, `scripts/map/view3d/sky_weather_3d.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_sky_atmosphere_lut.gd`, `tests/godot/test_sky_weather_3d.gd`, `docs/SKY_WEATHER_STATE_CONTRACT.md`, `docs/reports/images/ws10_*.png`, `TODO.md` | verify: LUT node/throttle/fallback tests; six-elevation clear captures show blue zenith, red low sun, Earth-shadow band, twilight into stars; R-713 continuity verifiers pass; 60 s day clip without flicker or banding
  ```
