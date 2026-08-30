# R-814 water save-envelope continuity

- Task: R-814
- Parent: R-715, realistic reflective water rollout
- Recorded: 2026-08-30
- Status: **STRUCTURAL PASS - renderer and performance acceptance remain BLOCKED**

## Scope and evidence boundary

This verification covers only the persistence boundary that was missing from the water rollout decomposition. It seeds a non-default storm/night `SkyWeather3D` state, stores the JSON-safe snapshot through `GameState.save_payload()`, performs an explicit `JSON.stringify` / `JSON.parse_string` round-trip, and hydrates it with `GameStatePersistence.load_payload()`. The restored snapshot is then applied through the shared `MapViewWaterMaterials.apply_weather_presentation()` adapter.

The test does not modify or accept the save schema, weather runtime, water shader, map data, target renderer, or performance budget. Equality of typed presentation inputs and shader uniform values proves deterministic handoff only. It does not prove that those values look correct in a real renderer.

## Required evidence

| Evidence | Result | Detail |
|---|---|---|
| `GameState.save_payload()` includes `environment` | PASS | Non-default storm/night snapshot is present in the saved game-state dictionary. |
| Explicit JSON round-trip | PASS | `JSON.stringify` followed by `JSON.parse_string` returns a dictionary accepted by the persistence loader. |
| `GameStatePersistence.load_payload()` | PASS | Restored environment is accepted with no load errors. |
| Source/restored snapshot | PASS | `MapParitySnapshot.serialize_value` is equal before and after JSON decoding. |
| Source/restored weather presentation | PASS | Rain, wind, wetness, night blend, tide, moon/sun, stars, and sidereal inputs match. |
| Source/restored water uniforms | PASS | Wave height/chaos/speed, foam/breakers, lighting, tide, and celestial uniforms match for `water`, `river_water`, `shallow_water`, and `deep_water`. |
| Missing environment payload | PASS | Legacy payload loads and resolves to an empty optional environment state. Gameplay sentinel fields remain unchanged. |
| Invalid environment payload | PASS | Loader reports an environment error, discards the payload, and leaves gameplay sentinel fields unchanged. |
| Real-renderer visual acceptance | **BLOCKED** | Not claimed by this headless structural test; see R-756 water capture packet. |
| Target-hardware performance acceptance | **BLOCKED** | Not measured or claimed; owned by the parent rollout performance evidence. |

## Focused verification

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_save_envelope
```

Expected summary:

```text
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

The test emits source/restored presentation dictionaries and source/restored uniform dictionaries in the command log. The `test_report_records_required_evidence_boundary` contract keeps this report fail-closed if those evidence categories or the renderer/performance blockers are removed.

## Recorded uniform comparison

Values below are the source values followed by the restored values from the same focused run. Every pair compared equal; `sun_visibility` and `sun_reflection_visibility` are both `0.0` for the selected night fixture.

| Profile | `wave_height` | `wave_chaos` | `wave_speed` | `foam_intensity` | `breaker_intensity` | `tide_level` |
|---|---:|---:|---:|---:|---:|---:|
| `water` | `0.05773047 / 0.05773047` | `1.46713248 / 1.46713248` | `1.40346 / 1.40346` | `0.17982 / 0.17982` | `0.34840498 / 0.34840498` | `0.55665458305992 / 0.55665458305992` |
| `river_water` | `0.046184376 / 0.046184376` | `1.10034936 / 1.10034936` | `1.40346 / 1.40346` | `0.11988 / 0.11988` | `0.12669272 / 0.12669272` | `0.55665458305992 / 0.55665458305992` |
| `shallow_water` | `0.050033074 / 0.050033074` | `1.19204514 / 1.19204514` | `1.40346 / 1.40346` | `0.23976 / 0.23976` | `0.82350268 / 0.82350268` | `0.55665458305992 / 0.55665458305992` |
| `deep_water` | `0.084671356 / 0.084671356` | `1.80335034 / 1.80335034` | `1.40346 / 1.40346` | `0.11988 / 0.11988` | `0.1583659 / 0.1583659` | `0.55665458305992 / 0.55665458305992` |

The shared celestial inputs also compared equal: `sun_direction=(0.464892, -0.204173, -0.861504)`, `moon_direction=(0.805969, -0.07108, -0.587675)`, `star_visibility=0.6`, `day_blend=0.0`, and `sidereal_angle=4.31425933794721`.

## Handoff

R-757 may consume this artifact for the R-715 save/load continuity clause. This report is independent of R-754's direct `SkyWeatherState` snapshot tests and does not duplicate R-757's full parent closeout. The structural result is ready for that handoff only; visual and performance criteria remain explicitly blocked.

Artifact: [`test_r715_water_save_envelope.gd`](../../tests/godot/test_r715_water_save_envelope.gd)
