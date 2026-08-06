# R-418 Lower Town urban-population acceptance gate

Task: **R-418**
Scope: final QA gate for the Lower Town urban-population profiles, map binding, renderer capacity, lifecycle replay, and market-day transition bridge.

## Decision

**BLOCKED - runtime population binding does not compile in the current shared worktree.**

The evidence and isolated profile/capacity suites pass, but the complete urban-population gate cannot be accepted while `res://scripts/world/urban_population_map_binding.gd` fails to preload. The binding file is currently modified WIP owned by the runtime population workstream; this QA task does not alter that shared implementation.

## Verification matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Population capture verifier | PASS | `python3 tools/verify_lower_town_population_profiles.py`; 3 scenarios |
| Population capture Python tests | PASS | `python3 -m unittest tests.python.test_verify_lower_town_population_profiles -v`; 3/3 |
| Market-day transition bridge | PASS | `test_population_market_day_focus`; 4/4 |
| Lifecycle replay and renderer disable | PASS | `test_urban_population_lifecycle`; 4/4 |
| Published renderer-capacity manifest | PASS | `test_urban_population_performance_cap`; 2/2 |
| Complete `test_urban_population` filter | BLOCKED | 2 files ran, 6 tests passed, 16 load/compile errors; controller and runtime-integration files could not load |

## Blocking reproduction

```sh
tools/run_godot_checked.sh r418-urban-population -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_urban_population
```

The first diagnostic is:

```text
Parse Error: Could not preload resource script "res://scripts/world/urban_population_map_binding.gd"
```

The dependent diagnostics are emitted from `tests/godot/test_urban_population_controller.gd` and `scripts/world/urban_population_controller.gd`, including unresolved `UrbanPopulationMapBinding` / `MapBindingScript` constants and type inference failures. These are cascade errors from the binding preload failure, not separate acceptance findings.

## Scope and ownership

- `R-441` owns binding of Lower Town population zones to the runtime lookup.
- `R-442` owns wiring the controller to the crowd renderer.
- `R-448` is the higher-level final Lower Town urban-population acceptance gate.
- This report is evidence-only. No runtime, map, asset, or test source was changed to suppress the failure.

## Follow-up

After the binding script compiles, rerun the complete filter and require zero load/compile errors before accepting R-418:

```sh
tools/run_godot_checked.sh r418-urban-population -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_urban_population
```

The independent passing checks above should be retained as the baseline for that rerun. No additional task is created because the blocker already has the R-441/R-442 owners.
