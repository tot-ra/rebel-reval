# R-738 adjacent-map sky/weather continuity

- Task: R-738
- Parent: R-713
- Capture identity: `r713-sky-weather-continuity-v1`
- Verification date: 2026-08-28
- Status: **PACKET VALID - human visual review pending**

## Evidence boundary

This is a fail-closed continuity packet. The structural contract and deterministic Metal capture packet are implemented and independently verified. The packet remains pending acceptance until named human visual review records the visual result. Headless output is deliberately rejected because SubViewport readback is not valid on the dummy renderer.

The representative handoff is `lower_town_slice` -> `monastery_quarter`, the authored Workers' District to northern Reval district edge. It is used because both maps are present in the map registry and the source maps carry a physical `alignment=edge` ground transition. `reval_harbor_east` is not used as the representative source because its `.rrmap` remains a prototype (`active=false`).

## Capture metadata

| Field | Value |
|---|---|
| Capture identity | `r713-sky-weather-continuity-v1` |
| Capture commit | `37686843313d3710d748c9002827900f0609dce3` |
| Engine | Godot 4.7.1-stable (official) |
| Renderer expected | Metal |
| Renderer observed | macOS |
| Hardware host | macOS/arm64 |
| Viewport | 1280x720 PNG plates |
| Captured plates | 40/40 |
| Captured handoffs | 20/20 |
| Manifest checksums | SHA-256 recorded per plate and verified independently |

| Artifact | Contract |
|---|---|
| [`tools/capture_r713_sky_weather_continuity.gd`](../../tools/capture_r713_sky_weather_continuity.gd) | Deterministic renderer capture, source-to-target state handoff, one view per process phase, PNG dimensions, SHA-256 manifest metadata |
| [`tools/verify_r713_sky_weather_evidence.py`](../../tools/verify_r713_sky_weather_evidence.py) | Fail-closed manifest, report, image, checksum, identity, and owner verification |
| [`tests/godot/test_r713_sky_weather_continuity.gd`](../../tests/godot/test_r713_sky_weather_continuity.gd) | Headless structural tests for packet identities, scenario coverage, JSON-safe snapshot digest, and no scene-swap capture path |
| [`docs/reports/images/r713_sky_weather/capture_manifest.json`](images/r713_sky_weather/capture_manifest.json) | Captured 40-plate packet metadata with 20 captured handoffs; visual review remains pending |

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
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . \
  --rendering-method mobile --rendering-driver metal \
  --script tools/capture_r713_sky_weather_continuity.gd
```

Run a smaller deterministic iteration when needed:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . \
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
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_LOG_DIR=/tmp/rebel-reval-r779 \
tools/run_godot_checked.sh --require-test-summary r738-sky-weather-continuity -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_r713_sky_weather_continuity
```

## Current result and limitations

- **PASS - structural contract:** the focused suite passes `4/4` and defines the fixed map pair, all five weather scenarios, both day/night states, exterior/sheltered modes, JSON-safe state hashing, one-owner requirement, and fail-closed Metal boundary.
- **PASS - packet integrity:** the committed manifest contains `40/40` captured PNG plates at `1280x720`, `20/20` captured handoffs, matching source/target state hashes, one environment owner per side, and verified SHA-256 checksums. `python3 tools/verify_r713_sky_weather_evidence.py` returns `R713_SKY_WEATHER_CONTINUITY_PASS`.
- **BLOCKED - acceptance review:** `capture_status` remains `captured_pending_review`; named human visual review is required before acceptance. The verifier deliberately cannot self-approve visual continuity.
- **BLOCKED - dependency integration:** R-714 streaming, R-736 atmosphere/wet-surface synchronization, R-737 quality budgets, and R-726 fixed-setting capture acceptance remain open dependencies. This report does not alter those systems or waive their gates.
- **Not measured:** named human visual review, transition hitch, and minimum-hardware performance. These remain explicit limitations rather than inferred evidence.
