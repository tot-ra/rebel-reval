# R-604 RRMap elevation command verification

**Task:** R-604 / restore `elevation_area` and `elevation_ramp` on clean HEAD
**Date:** 2026-09-24
**Snapshot:** `0bae8e3e` (`Reorganize Kalev fresh assets into per-model folders.`)
**Decision:** **PASS - parser and blueprint validation accept authored elevation commands; North Quarter and transition clearance suites green**

## Scope

R-604 tracked clean-checkout failures where `content/maps/*.rrmap` files already authored `elevation_area` / `elevation_ramp` but older parser builds reported `unknown_command` and cascaded into empty `MapDefinition` errors. This closeout re-verifies the current tree without changing map source or compiler behavior.

## Commands run

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_rrmap_parser
"$GODOT_BIN" --headless --path . --script tools/validate_map_blueprints.gd
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_north_quarter_prototype_map,test_transition_spawn_clearance
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
python3 -m unittest tests.python.test_verify_clean_checkout_load -v
```

## Results

| Check | Result | Notes |
|-------|--------|-------|
| `test_map_rrmap_parser` | PASS | 15/15 including `test_elevation_profiles_parse_compile_and_round_trip` |
| `tools/validate_map_blueprints.gd` | PASS | 28 registered, 0 errors (warnings only) |
| `test_north_quarter_prototype_map` | PASS | 9/9 |
| `test_transition_spawn_clearance` | PASS | 6/6 |
| `test_lower_town_slice_map` | PARTIAL | 18/19; one parity-fixture drift unrelated to elevation (`door_side` vs `footprint`) |
| `tests.python.test_verify_clean_checkout_load` | PASS | 7/7 contract tests |

`tools/verify_transitions.gd` still reports four inactive-scene manifest errors (`rentenitorn_interior` and related). Those are transition activation gaps, not RRMap elevation parsing, and remain outside R-604.

## Handoff

- **R-245 / P4-020:** elevation parsing is no longer a North Quarter activation blocker on this HEAD.
- **R-108 / P0-101:** clean-checkout elevation `unknown_command` diagnostics from August 2026 reports are obsolete on this HEAD; remaining P0-101 blockers stay owned by acceptance and parity tasks (for example R-538 ledger, parity fixture refresh).
