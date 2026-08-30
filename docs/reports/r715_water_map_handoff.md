# R-815 water map-presenter handoff

- Task: R-815
- Parent: R-715, realistic reflective water rollout
- Recorded: 2026-08-30
- Status: **STRUCTURAL PASS - real-renderer visual and target-hardware performance acceptance remain BLOCKED**

## Scope and evidence boundary

This report covers the live map-presenter handoff boundary that is not covered by R-752's isolated per-map rollout or R-754's shared snapshot checks. The focused test keeps `reval_harbor_north` and `reval_harbor_east` in one `SceneTree`, binds the source and destination through the existing `SessionState` environment-runtime API, and does not reload a scene between presenters.

The source fixture uses a non-default rain/night state with elapsed days and retained wetness inputs. Before binding the destination, the test records source weather presentation and shared water uniforms. The destination binding must restore the same state, deactivate the source, leave one active environment owner, and preserve the authored map parity signatures for both grids.

This is verification/evidence only. It does not change map runtime, water materials, `SkyWeather3D`, transition logic, map sources, stable IDs, or R-713 implementation. Structural equality of presentation inputs and uniforms proves deterministic continuity only; it does not prove that the result looks correct in a real renderer.

## Required evidence

| Evidence | Result | Detail |
|---|---|---|
| Adjacent source map | PASS | `reval_harbor_north`; authored transition `to_harbor_east` is retained. |
| Adjacent destination map | PASS | `reval_harbor_east`; authored reciprocal transition `to_harbor_north` is retained. |
| Source/destination in one scene tree | PASS | Both `MapViewRuntime` presenters are alive during the handoff; no scene reload is used. |
| SessionState environment API | PASS | `bind_environment_runtime`, `active_environment_runtime`, snapshot capture, and destination restore are exercised. |
| Before/after uniform keys | PASS | The test records and compares `wave_height`, `wave_chaos`, `wave_speed`, `foam_intensity`, `breaker_intensity`, `tide_level`, `day_blend`, `sun_direction`, `moon_direction`, `star_visibility`, and `sidereal_angle` for all four shared water profiles. |
| Weather front and rain | PASS | Weather mode and `rain_intensity` remain equal after destination binding. |
| Wind-driven waves | PASS | `wind_strength`, `wind_direction`, wave height/chaos/speed, foam, and breaker uniforms remain equal. |
| Tide | PASS | `tide_level` remains equal in the destination presentation and every water uniform profile. |
| Day/night and celestial reflection | PASS | `day_blend`, sun/moon directions, `star_visibility`, and `sidereal_angle` remain equal. |
| Wetness | PASS | `puddle_wetness` remains equal, proving the fixture did not pass by restoring only a weather enum. |
| Old presenter deactivated | PASS | Source `environment_binding_active()` is false and its `WorldEnvironment.environment` is detached. |
| Single environment owner | PASS | Owner count is `1` before the handoff and `1` after it; the destination remains attached. |
| Terrain fingerprint parity | PASS | Source and destination `terrain_fingerprint` and `terrain_grid_fingerprint` are unchanged before/after handoff. |
| Walkability parity | PASS | Source and destination `walkability_sha256` values are unchanged before/after handoff. |
| Real-renderer visual acceptance | **BLOCKED** | This is a headless structural test and does not claim gameplay-camera visual continuity; matched capture remains owned by R-756. |
| Target-hardware performance acceptance | **BLOCKED** | No GPU frame-time or memory measurement is performed here; performance evidence remains owned by the parent rollout. |

## Focused verification

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_map_handoff
```

Expected summary for the new file:

```text
Godot headless tests: 1 file(s), 2 test(s), 0 failure(s), 0 error(s).
```

The test emits the source/destination map IDs, before/after presentation inputs, before/after water uniform dictionaries, owner counts, and parity signatures. Its report contract rejects this document if the required map IDs, uniform keys, owner evidence, parity fields, handoff artifact, or explicit renderer/performance blockers disappear.

## Recorded evidence shape

The focused run records these fields for both maps and both handoff sides:

- Map IDs: `reval_harbor_north` and `reval_harbor_east`.
- Presentation inputs: weather, rain, wind strength/direction, puddle wetness, day/night blend, tide, sun direction, moon direction, stars, sidereal angle, cloud offsets, and rain suppression.
- Water uniform keys: `wave_height`, `wave_chaos`, `wave_speed`, `foam_intensity`, `breaker_intensity`, `tide_level`, `day_blend`, `sun_direction`, `moon_direction`, `star_visibility`, and `sidereal_angle`.
- Owner counts: active environment owner count before and after handoff, plus source deactivation and destination attachment.
- Parity signatures: `terrain_fingerprint`, `terrain_grid_fingerprint`, `walkability_sha256`, and canonical `parity_sha256` for each authored grid.

The test compares typed vectors with approximate equality and scalar uniforms with approximate equality, while requiring identical key sets. It therefore checks actual renderer inputs rather than inferring visual continuity from map structure alone.

## Handoff

R-757 may consume this artifact for the R-715 map-transition continuity clause. R-815 does not duplicate R-752's isolated map rollout, R-754's save/snapshot contract, or R-757's full parent closeout. The structural handoff result is ready for downstream review only; real-renderer visual and target-hardware performance criteria remain explicitly blocked.

Artifact: [`test_r715_water_map_handoff.gd`](../../tests/godot/test_r715_water_map_handoff.gd)
