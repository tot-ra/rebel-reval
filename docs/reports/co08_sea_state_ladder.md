# CO-08 / R-955 sea-state ladder

Implementation of `docs/tasks/coast/CO-08_sea_state_wind_coupling.md`.

## Decisions (2026-09-26)

1. **Heading is a pure function.** `wind_direction_at(weather, progress, gust, from, blend)` is the only source. CLEAR at noon equals `CLOUD_DRIFT_PER_SECOND.normalized()` so existing harbour plates stay valid. Other presets offset that bearing (cloudy +55, overcast +110, rain -70, storm +165 deg). Day veer is `sin(TAU * (progress - 0.25)) * 22 deg` (zero at noon). Gust veer is `gust / GUST_PEAK * 18 deg`.
2. **No new save key.** `snapshot_state()` and `apply_state()` both write the supplied `cycle_progress` onto the local heading clock so `wind_direction_xz()` and later `advance()` stay on that clock. The shared day clock stays the R-713 owner.
3. **Hs stays the WS-04 table.** `BEAUFORT_LADDER` lists the published knots plus a force-3 row at `sea_state` 0.35 / Hs 0.60 m. Weight interpolation gained that same 0.35 knot so clear-to-cloudy transitions no longer jump from 0.16 m to 1.36 m. Settled weather weights at 0.20 / 0.50 / 0.85 are unchanged.
4. **Whitecaps start at force 4.** `whitecap_onset` is 0 on the 0.20 and 0.35 knots and 1 from cloudy upward. The shader multiplies the baked mask by that gate. Calm residual foam from `foam_coverage` 0.2 no longer reads as whitecaps.
5. **Fetch/shelter reuses the WS-08 field.** Signed distance, positive in water. An 8-unit upwind probe plus a 1.5..12 unit basin term lerp amplitude and foam toward 0.38. No new texture.
6. **Hull motion quotes the ladder.** Gerstner boats use `hull_motion_scale()` (Hs 0.16..3.48 m mapped onto 0.55..1.45). FFT boats already share `apply_sea_weather()` amplitude and now multiply by the same shelter term.

## Verification

Focused Godot filter:

`test_sea_state_ladder,test_sky_weather_3d,test_weather_realism,test_r715_water_weather_sync,test_r713_sky_weather_continuity,test_ocean_fft_sampler`

GPU plates (`tools/capture_co08_sea_states.gd`) were not taken in this session: a Godot `--editor` process already held the shared worktree. Follow-up **R-994** records that capture.

## Follow-up

**R-994:** Harbour North calm / breeze / gale / storm, opposite-quarter, and sheltered-lee plates on Metal and Compatibility, plus `python3 tools/verify_r715_water_performance.py` on a free GPU.
