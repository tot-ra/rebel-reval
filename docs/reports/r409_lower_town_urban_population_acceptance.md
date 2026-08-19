# R-409 Lower Town urban-population acceptance

**Task:** R-409
**Verification date:** 2026-08-19
**Repository snapshot:** `174df91c12043c49fe626e05aeb08562355053b5`
**Worktree:** shared worktree contains unrelated staged, modified, deleted, and untracked WIP. This report is the only scoped artifact created by R-409; no runtime, map, asset, or test source was changed.
**Decision:** **BLOCKED - population runtime integration cannot complete on the current checkout.**

## Scope and decision boundary

This gate verifies the deterministic Lower Town population profiles, authored cluster binding, lifecycle replay, market-day transitions, renderer capacity, and the controller's runtime bridge. A green profile or controller contract does not waive a renderer or engine diagnostic. The acceptance result describes the current shared checkout and keeps unrelated runtime WIP outside this QA change.

## Verification matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Population profile verifier | **PASS** | `python3 tools/verify_lower_town_population_profiles.py`; 3 scenarios |
| Population profile Python tests | **PASS** | `python3 -m unittest tests.python.test_verify_lower_town_population_profiles -v`; 3/3 |
| Market-day, lifecycle, and renderer-cap suites | **PASS** | `test_population_market_day_focus`, `test_urban_population_lifecycle`, and `test_urban_population_performance_cap`; 3 files, 10/10 |
| Controller and authored-map binding suite | **PASS** | `test_urban_population_controller`; 1 file, 22/22 |
| Runtime integration | **BLOCKED** | `test_urban_population_runtime_integration`; 3 tests, 2 pass, 1 engine/script error |

## Blocking reproduction

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r409-population-runtime-checked-2
./tools/run_godot_checked.sh --require-test-summary r409-population-runtime-2 -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_urban_population_runtime_integration
```

The first blocking diagnostic is:

```text
SHADER ERROR: Tokenizer: Unknown character #35: '#'
ERROR: Shader compilation failed.
```

The stack reaches `MapView3D.create()` from `test_controller_registers_full_day_profile_in_crowd_renderer`. The embedded `WATER_SHADER_CODE` contains GDScript-only `# gdlint: ignore=max-line-length` lines at `scripts/map/view3d/map_view_material_shaders.gd:167` and `:169`; the dummy renderer parses those lines as GLSL and fails before the population renderer assertion can complete. This is a renderer/shader defect, not a population-profile assertion failure.

## Passing evidence boundary

The passing checks establish that:

- day, market-day, night, and crackdown profiles resolve deterministically;
- market-day changes population density without mutating `GameState`;
- lifecycle save/replay preserves profile and actor-plan inputs;
- authored Lower Town clusters and anchors are walkable and stable;
- published scenarios remain within the renderer capacity of 64 instances;
- the controller resolves the expected profiles and passes 22 focused contract tests.

They do not establish successful 3D renderer integration while the water shader cannot compile. No visual sign-off or final Lower Town acceptance is inferred from this report.

## Follow-up ownership

`R-593` owns removal or relocation of the embedded shader lint directives and a focused regression rerun. R-409 does not modify `scripts/map/view3d/map_view_material_shaders.gd` because that file is outside this QA gate's scoped evidence-only change.

After R-593 lands, rerun the blocked command above and require a clean non-empty Godot summary with zero failures and zero errors before closing R-409.

## Sources

- [`scripts/world/urban_population_profile.gd`](../../scripts/world/urban_population_profile.gd)
- [`scripts/world/urban_population_map_binding.gd`](../../scripts/world/urban_population_map_binding.gd)
- [`scripts/world/urban_population_controller.gd`](../../scripts/world/urban_population_controller.gd)
- [`tests/godot/test_urban_population_controller.gd`](../../tests/godot/test_urban_population_controller.gd)
- [`tests/godot/test_urban_population_lifecycle.gd`](../../tests/godot/test_urban_population_lifecycle.gd)
- [`tests/godot/test_urban_population_performance_cap.gd`](../../tests/godot/test_urban_population_performance_cap.gd)
- [`tests/godot/test_urban_population_runtime_integration.gd`](../../tests/godot/test_urban_population_runtime_integration.gd)
- [`tools/verify_lower_town_population_profiles.py`](../../tools/verify_lower_town_population_profiles.py)
- [`docs/reports/population_clusters_r419.json`](population_clusters_r419.json)
- [`scripts/map/view3d/map_view_material_shaders.gd`](../../scripts/map/view3d/map_view_material_shaders.gd)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
