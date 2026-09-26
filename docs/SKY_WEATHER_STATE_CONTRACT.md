# Sky/weather state contract

`SkyWeatherState` is the shared, scene-tree-free handoff object for exterior map presenters. It is the persistence boundary for the unified sky/weather system introduced by R-713.

## Ownership

- `SkyWeatherState` owns deterministic simulation inputs and accumulators.
- `SkyWeather3D` owns renderer resources and exposes `snapshot_state()` / `apply_state()` adapters.
- The shared day clock owner supplies `cycle_progress` and `elapsed_days` when taking a snapshot.
- Map transitions must transfer one state object, not construct a second weather timeline.

## Persisted payload

`SkyWeatherState.to_dict()` emits exactly the following version 1 keys. `Vector2` values are stored as two-number arrays, RNG states are stored as decimal strings, and profile dictionaries use string keys so the payload survives JSON encoding.

| Key | Purpose and ownership |
|---|---|
| `schema_version` | Payload version validated by `SkyWeatherState`. |
| `weather` | Active weather mode. |
| `transition_from_weather` | Weather mode at the start of the active transition. |
| `transition_progress` | Blend progress from the source profile to the active profile. |
| `time_in_state` | Simulated seconds spent in the active weather mode. |
| `state_duration` | Simulated duration before automatic weather selection advances. |
| `auto_weather` | Whether the weather state machine selects the next mode automatically. |
| `time_scale` | Simulation speed multiplier, including pause at zero. |
| `rain_suppressed` | Presentation flag for hiding falling rain under a roof. |
| `calendar_date` | Campaign date used by astronomy and seasonal presentation. |
| `cycle_progress` | Wrapped shared day-clock progress supplied to `snapshot_state()`. |
| `elapsed_days` | Completed shared day-clock days supplied to `snapshot_state()`. |
| `cloud_offset` | Primary cloud-bank UV drift accumulator. |
| `cloud_detail_offset` | Detail-cloud UV drift accumulator. |
| `puddle_wetness` | Retained wet-ground intensity. |
| `seconds_since_rain` | Simulated time since rain last reached the ground. |
| `gust` | Transient rain-front gust intensity. |
| `gust_time` | Elapsed time within the transient gust envelope. |
| `lightning` | Current lightning flash intensity. |
| `lightning_direction` | Normalized 2D bearing of the current lightning cell. |
| `lightning_time` | Elapsed time within the current lightning flash. |
| `time_to_strike` | Countdown to the next deterministic lightning strike. |
| `weather_rng_state` | Deterministic weather-sequence RNG state. |
| `lightning_rng_state` | Separate deterministic lightning RNG state. |
| `current_profile` | Active weather presentation profile, including coverage, darken, sun/ambient energy, gray, rain, wind, chaos, storm, locality, and thunder. |
| `transition_from_profile` | Source presentation profile retained while a transition is in progress. |

`SkyWeather3D.snapshot_state()` fills all 26 keys above. `SkyWeather3D.apply_state()` restores every presenter-owned field: weather transition data, weather flags, calendar date, cloud and wetness accumulators, gust/lightning timers, RNG streams, and both profiles. `cycle_progress` and `elapsed_days` are intentionally snapshot inputs owned by the shared day clock, so `apply_state()` does not overwrite that clock. `quality_tier`, renderer resources, and derived presentation values are not persisted.

Since WS-10 the clear-sky background radiance and the sun disk colour come from the physical atmosphere: `SkyAtmosphereLut` renders a Hillaire sky-view LUT from the sun direction that `apply_sky_state()` already receives, and falls back to the old gradient when the WS-09 LUT assets are missing. The LUT is derived presentation state, rebuilt from the sun direction every (other) frame, so the state contract above is unchanged: no key was added and `snapshot_state()` / `apply_state()` keep their format.

Renderer-only objects such as `Environment`, `Sky`, `SkyAtmosphereLut`, `Camera3D`, particles, audio players, and scene nodes are intentionally excluded. This keeps save/load and map transitions independent from renderer lifetime.

## Validation and migration

`schema_version` is required to be `1`. Unknown future versions are rejected by `SkyWeather3D.apply_state()` rather than silently downgraded. Missing fields use deterministic defaults so older payloads can be migrated by `SkyWeatherState.from_dict()` without changing the active renderer. Numeric ranges are normalized at the boundary: time scale is capped at `20.0`, progress is wrapped, wetness and flash values are clamped, and zero lightning vectors receive a safe eastward fallback.

Any schema change must increment `CURRENT_VERSION`, add an explicit migration in `from_dict()`, and extend `tests/godot/test_sky_weather_state.gd` before the new state is used by save/load or map-transition code.

## Beaufort ladder (R-955 / CO-08)

`SkyWeather3D.wind_direction_xz()` is a pure function of weather, the shared day clock, and the live gust envelope. It is not `CLOUD_DRIFT_PER_SECOND.normalized()`. CLEAR at noon (progress 0.25) still matches that historical harbour bearing so existing plates stay valid. Other presets use a fixed heading offset; the clock adds a ±22 deg veer that is zero at noon; a rain-front gust adds up to ±18 deg. Cloud drift, the sky `wind_dir` uniform, water, ripples, boats, rain particles, and chimney smoke all read the same accessor.

Hs is not re-derived from the FFT bake. `MapViewWaterMaterials.BEAUFORT_LADDER` documents the WS-04 capture knots plus the missing force-3 row:

| Weather | `sea_state` | Beaufort | Wind m/s | Hs m | Whitecaps |
|---|---:|---:|---:|---:|---|
| clear | 0.20 | 2 | 2.5 | 0.16 | off |
| breeze | 0.35 | 3 | 5.5 | 0.60 | off |
| cloudy | 0.52 | 4 | 8.0 | 1.36 | onset |
| overcast | 0.58 | 5 | 9.5 | 1.67 | on |
| storm | 0.79 | 6 | 12.5 | 3.01 | on |
| rain | 1.32 | 7 | 15.5 | 3.48 | on |

`sea_state` is still `wind + 0.4 x rain`. Whitecap onset is force 4. Fetch/shelter reuses the WS-08 signed shore field: land upwind or a tight basin scales FFT amplitude and foam toward 0.38. Gerstner hull motion reads `hull_motion_scale()` from the same Hs band (0.55..1.45). No new persisted key: restore reconstructs heading from the existing weather snapshot plus `cycle_progress`.
