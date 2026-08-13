# R-455 - City elevation and ditch readability

## Scope

Acceptance coverage for terrain elevation/grades, player-eye and top-down readability, recessed ditch/water visibility, terrain/object alignment, shoreline continuity, patrol routes, and camera bounds. Runtime evidence is separated from the remaining human historical/art review boundary.

## Evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Toompea base elevation | PASS | `definition.ground_elevation == 2.8`, guarded by `test_r455_toompea_ground_elevation_and_deterministic_height`. |
| Deterministic terrain height | PASS | The acceptance test calls `MapViewMeshBuilder.ground_height()` twice for the same cell and compares the result. |
| Elevation grades/profiles | PARTIAL | The R-454 urban RRMap matrix contains the authored profile IDs and scope suite passes. The legacy Monastery prototype fixture still exposes an empty `elevation_profiles` array, so that fixture remains an explicit compatibility boundary rather than evidence of a missing RRMap profile. |
| Monastery ditch/water presence | PASS | Built terrain contains water cells. |
| Harbor shoreline continuity | PASS | Harbor North contains water cells with non-water neighboring cells; this guards against an isolated or disconnected water region. |
| Recessed ditch/water runtime geometry | PASS | The focused test inspects generated water mesh vertices at `-WATER_RECESS + WATER_SURFACE_LIFT` and verifies the Harbor North ground bed at `-WATER_RECESS`. |
| Terrain/object alignment | PASS / visual evidence | The matched Harbor North Metal captures show the same authored terrain/object layout in player-eye and top-down framing. Exact pixel-level footprint alignment remains a human visual review concern, not a public runtime assertion. |
| Player-eye/top-down readability | PASS | Four non-headless Metal captures exist and load as RGB PNGs at 1600x900: `docs/reports/images/elevation/reval_harbor_north_player_eye_day.png`, `reval_harbor_north_player_eye_night.png`, `reval_harbor_north_top_down_day.png`, and `reval_harbor_north_top_down_night.png`. |
| Patrol routes | PASS | Toompea and Lower Town expose non-empty patrol arrays with at least one two-point segment. |
| Camera bounds | PASS | Toompea and Lower Town camera bounds are non-empty `Rect2` values. |

## Rendered evidence

Each plate was produced in a separate non-headless Godot 4.7.1 process with the Mobile renderer and Metal driver on Apple M5 Pro / Metal 4.0. The Harbor North authored spawn is `(3328, 2656)` logic pixels, rendered at world eye position `(104.0, 1.65, 83.0)` for player-eye captures. Day and night plates are separate runs, so the four files are attributable to fresh renderer state.

```text
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r524-logs

# One process per plate, non-headless Metal:
"$GODOT_BIN" --path . --rendering-method mobile --rendering-driver metal \
  --script tools/_tmp_capture_r455_elevation.gd -- --camera=player_eye --time=day
"$GODOT_BIN" --path . --rendering-method mobile --rendering-driver metal \
  --script tools/_tmp_capture_r455_elevation.gd -- --camera=player_eye --time=night
"$GODOT_BIN" --path . --rendering-method mobile --rendering-driver metal \
  --script tools/_tmp_capture_r455_elevation.gd -- --camera=top_down --time=day
"$GODOT_BIN" --path . --rendering-method mobile --rendering-driver metal \
  --script tools/_tmp_capture_r455_elevation.gd -- --camera=top_down --time=night
```

The checked logs report `Metal 4.0 - Forward Mobile - Using Device #0: Apple - Apple M5 Pro (Apple9)` and `R455_ELEVATION_CAPTURE_OK` for all four plates. The only exit diagnostics are the repository's known resource/RID shutdown leaks allowed by `tools/run_godot_checked.sh`; no script, parser, shader, or resource-loading errors occurred.

## Verification

Focused acceptance run:

```text
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r524-logs
tools/run_godot_checked.sh --require-test-summary r455-focused-after-captures -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r455_city_elevation_readability.gd
```

Result: 1 file, 5 tests, 0 failures, 0 errors. The fifth test verifies all four evidence files exist, load as RGB PNGs, and are exactly 1600x900. Related R-454 and R-503 elevation suites previously passed 3 tests each. Known unrelated baseline failures remain out of scope: monastery composition/empty-region checks, an extra transition marker, and the Karja Gate authored-leaf contract.

## Decision

R-455 is **accepted for the runtime and rendered-readability gate**: authored base elevation, deterministic relief sampling, recessed water/shore geometry, matched player-eye/top-down day/night evidence, terrain/object layout evidence, patrol, and camera contracts are covered. The legacy Monastery prototype's empty profile array remains explicitly partial, while the authored nine-map R-454 RRMap matrix is covered by its scope suite. Human historical and art sign-off is not claimed by this automated gate.
