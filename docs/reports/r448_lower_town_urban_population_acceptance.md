# R-448 Lower Town urban-population acceptance gate

**Task:** R-448
**Verification date:** 2026-08-20
**Repository snapshot:** `493b1b17d893984b1c435084242d430bf90c5918`
**Worktree:** shared worktree contains unrelated modified and untracked WIP. This report is the only file created for R-448; no runtime, map, asset, or unrelated test source was changed.

## Decision

**PASS - Lower Town urban-population acceptance gate is green on the current checkout.**

The deterministic profiles, authored cluster binding, lifecycle replay, market-day transition bridge, renderer capacity, and runtime controller integration all passed their focused checks. The gate does not claim a separate GPU frame-time budget; that remains covered by the vertical-slice performance work.

## Verification matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Population profile verifier | **PASS** | `python3 tools/verify_lower_town_population_profiles.py`; 3 scenarios |
| Population profile Python tests | **PASS** | `python3 -m unittest tests.python.test_verify_lower_town_population_profiles -v`; 3/3 |
| Urban-population Godot gate | **PASS** | `./tools/run_godot_checked.sh --require-test-summary r448-urban-population-final -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_urban_population`; 4 files, 32/32, 0 failures, 0 errors |
| Market-day transition bridge | **PASS** | `./tools/run_godot_checked.sh --require-test-summary r448-market-day-final -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_population_market_day_focus`; 1 file, 4/4, 0 failures, 0 errors |
| Renderer capacity | **PASS** | R-419 manifest scenarios remain within 64 instances; largest market-day scenario uses 33 |
| Placement and authored-space safety | **PASS** | Runtime integration verifies deterministic replay, walkable placement, authored prop clearance, and inter-actor clearance |
| Documentation diff hygiene | **PASS** | `git diff --check` |

## Acceptance evidence

- Day, market-day, night, and crackdown profiles resolve deterministically from explicit phase/date/seed inputs.
- Market-day changes population density through the population bridge without mutating `GameState`.
- Save/replay inputs reproduce profile and actor-plan outputs.
- Authored Lower Town worker, merchant, and watch clusters provide stable, walkable anchors.
- Runtime placement maps every generated actor to authored walkable space while respecting prop and actor clearances.
- Named/interactable NPC space remains excluded from the generated crowd set.
- Published crowd scenarios remain below the renderer capacity of 64 instances.

## Runtime diagnostics

Godot emitted shutdown-only ObjectDB/resource leak diagnostics after the passing suite. These are the documented DEF-002 allowlisted diagnostics handled by `tools/run_godot_checked.sh`; there were no unexpected engine, parser, resource, or script errors, and the required clean test summaries were present.

## Sources

- [`scripts/world/urban_population_profile.gd`](../../scripts/world/urban_population_profile.gd)
- [`scripts/world/urban_population_map_binding.gd`](../../scripts/world/urban_population_map_binding.gd)
- [`scripts/world/urban_population_controller.gd`](../../scripts/world/urban_population_controller.gd)
- [`scripts/world/urban_population_placement.gd`](../../scripts/world/urban_population_placement.gd)
- [`tests/godot/test_urban_population_controller.gd`](../../tests/godot/test_urban_population_controller.gd)
- [`tests/godot/test_urban_population_lifecycle.gd`](../../tests/godot/test_urban_population_lifecycle.gd)
- [`tests/godot/test_urban_population_performance_cap.gd`](../../tests/godot/test_urban_population_performance_cap.gd)
- [`tests/godot/test_urban_population_runtime_integration.gd`](../../tests/godot/test_urban_population_runtime_integration.gd)
- [`tests/godot/test_population_market_day_focus.gd`](../../tests/godot/test_population_market_day_focus.gd)
- [`tools/verify_lower_town_population_profiles.py`](../../tools/verify_lower_town_population_profiles.py)
- [`docs/reports/population_clusters_r419.json`](population_clusters_r419.json)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
