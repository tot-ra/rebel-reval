# Sky/weather state contract

`SkyWeatherState` is the shared, scene-tree-free handoff object for exterior map presenters. It is the persistence boundary for the unified sky/weather system introduced by R-713.

## Ownership

- `SkyWeatherState` owns deterministic simulation inputs and accumulators.
- `SkyWeather3D` owns renderer resources and exposes `snapshot_state()` / `apply_state()` adapters.
- The shared day clock owner supplies `cycle_progress` and `elapsed_days` when taking a snapshot.
- Map transitions must transfer one state object, not construct a second weather timeline.

## Stable fields

The version 1 payload contains:

- `weather`, `transition_from_weather`, transition timing, and `auto_weather`;
- `calendar_date`, wrapped `cycle_progress`, and completed `elapsed_days`;
- `time_scale` and `rain_suppressed` presentation flags;
- cloud drift, retained puddle wetness, gust, lightning, and strike timers;
- deterministic weather/lightning RNG state;
- current and transition profile dictionaries.

Renderer-only objects such as `Environment`, `Sky`, `Camera3D`, particles, audio players, and scene nodes are intentionally excluded. This keeps save/load and map transitions independent from renderer lifetime.

## Validation and migration

`schema_version` is required to be `1`. Unknown future versions are rejected by `SkyWeather3D.apply_state()` rather than silently downgraded. Missing fields use deterministic defaults so older payloads can be migrated by `SkyWeatherState.from_dict()` without changing the active renderer. Numeric ranges are normalized at the boundary: time scale is capped at `20.0`, progress is wrapped, wetness and flash values are clamped, and zero lightning vectors receive a safe eastward fallback.

Any schema change must increment `CURRENT_VERSION`, add an explicit migration in `from_dict()`, and extend `tests/godot/test_sky_weather_state.gd` before the new state is used by save/load or map-transition code.
