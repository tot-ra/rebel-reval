# R-738 adjacent-map sky/weather continuity

- Task: R-738
- Parent: R-713
- Capture identity: `r713-sky-weather-continuity-v1`
- Verification date: 2026-08-26
- Status: **BLOCKED - renderer evidence pending**

## Evidence boundary

This is a fail-closed continuity packet. The structural contract and deterministic capture planning are implemented, but no PNG is accepted until the capture helper runs with Godot 4.7 and the Metal renderer on a real display-capable host. Headless output is deliberately rejected because SubViewport readback is not valid on the dummy renderer.

The representative handoff is `lower_town_slice` -> `monastery_quarter`, the authored Workers' District to northern Reval district edge. It is used because both maps are present in the map registry and the source maps carry a physical `alignment=edge` ground transition. `reval_harbor_east` is not used as the representative source because its `.rrmap` remains a prototype (`active=false`).

## Capture metadata

| Field | Value |
|---|---|
| Capture identity | `r713-sky-weather-continuity-v1` |
| Commit | Written into the manifest by the renderer run; current packet is `not captured` |
| Engine | Godot 4.7, project GL Compatibility renderer |
| Renderer | Metal required for SubViewport readback |
| Hardware host | Written by the renderer run; current packet is `not measured` |
| Viewport | 1280x720 PNG plates |
| Manifest checksums | SHA-256 written per captured plate and verified independently |


| Artifact | Contract |
|---|---|
| [`tools/capture_r713_sky_weather_continuity.gd`](../../tools/capture_r713_sky_weather_continuity.gd) | Deterministic renderer capture, source-to-target state handoff, one view per process phase, PNG dimensions, SHA-256 manifest metadata |
| [`tools/verify_r713_sky_weather_evidence.py`](../../tools/verify_r713_sky_weather_evidence.py) | Fail-closed manifest, report, image, checksum, identity, and owner verification |
| [`tests/godot/test_r713_sky_weather_continuity.gd`](../../tests/godot/test_r713_sky_weather_continuity.gd) | Headless structural tests for packet identities, scenario coverage, JSON-safe snapshot digest, and no scene-swap capture path |
| [`docs/reports/images/r713_sky_weather/capture_manifest.json`](images/r713_sky_weather/capture_manifest.json) | Planned 40-plate packet metadata; starts in `blocked` / `missing` state until a real capture completes |

## Expected visual invariants

The packet covers both `day/night` lighting states and these weather cases on both maps. Each captured plate records the shared presentation snapshot fields (`wind_direction`, `puddle_wetness`, rain intensity, overcast, exposure, and shelter flag):

- `clear`: a stable clear sky and low clear-air haze;
- `overcast`: continuous cloud cover, matching exposure, and overcast haze;
- `rain`: matched rain direction/intensity, wet-ground response, and rain curtain;
- `storm`: matched wind direction, cloud-front identity, lightning-capable storm presentation, and distant haze;
- `rain_shelter_pair`: sheltered interior/exterior pair where the weather simulation, fog/haze, lighting, wetness, and wind remain shared, while only visible rain emission is suppressed under a roof.

The handoff must prove:

1. source and target snapshots have the same state digest, including weather identity, transition progress, cloud offsets, wind/gust, rain, wetness, calendar, RNG state, and day-clock inputs;
2. the normalized `wind direction` is shared by clouds, world effects, and water-facing consumers;
3. fog/haze and exposure do not reset at the handoff;
4. `SessionState` remains the single canonical environment owner;
5. there is `no duplicate environment owner`, exactly one active `WorldEnvironment` per presentation side, and no `SceneTree.change_scene_to_packed()` capture path;
6. image pairs are non-flat, decode as PNG, match the fixed 1280x720 viewport, and match the recorded manifest checksums.

## Capture and verification commands

Run one full packet on a real renderer:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method mobile --rendering-driver metal \
  --script tools/capture_r713_sky_weather_continuity.gd
```

Run a smaller deterministic iteration when needed:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method mobile --rendering-driver metal \
  --script tools/capture_r713_sky_weather_continuity.gd -- \
  --scenario=rain --time=day --shelter=exterior
```

Verify the complete committed packet:

```bash
python3 tools/verify_r713_sky_weather_evidence.py
git diff --check
```

Run the headless structural suite with a required summary:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
tools/run_godot_checked.sh --require-test-summary r738-sky-weather-continuity -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_r713_sky_weather_continuity
```

## Current result and limitations

- **PASS - structural contract:** the new focused suite defines the fixed map pair, all five weather scenarios, both day/night states, exterior/sheltered modes, JSON-safe state hashing, one-owner requirement, and fail-closed Metal boundary.
- **BLOCKED - visual packet:** the manifest currently contains `40` planned identities with `status: missing`; no renderer capture has been promoted or human-reviewed in this checkout. A Metal 4.0 / Forward Mobile attempt on 2026-08-26 reached the Apple M5 Pro renderer, then stopped before PNG creation because the existing R-737 worktree state cannot parse `scripts/map/view3d/sky_weather_3d.gd` (`Could not parse global class "SkyWeather3D"`). R-738 does not modify that runtime file.
- **BLOCKED - dependency integration:** R-714 streaming, R-736 atmosphere/wet-surface synchronization, R-737 quality budgets, and R-726 fixed-setting capture acceptance remain open dependencies. This report does not alter those systems or waive their gates.
- **Not measured:** hardware host, real renderer output, PNG checksums, human visual review, transition hitch, and minimum-hardware performance. These remain explicit limitations rather than inferred evidence.
