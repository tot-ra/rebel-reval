# R-788 Rentenitorn map and reciprocal-transition verification

**Task:** R-788 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Verification date:** 2026-08-28
**Repository:** `main`, shared dirty worktree with unrelated WIP
**Decision:** **PASS for the scoped R-788 verification**

## Scope and boundary

This note verifies the authored Rentenitorn interior structure, its prototype/factory and shared enterable-tower contract, the north-quarter exterior wiring, and the developer-only boundary. No map, runtime, asset, or activation change was made. `Rentenitorn` remains `active=false` and still requires historical/art human sign-off before release activation.

## Source assertions

| Requirement | Current source evidence |
|---|---|
| Developer-only 18x18 map | `content/maps/rentenitorn_interior.rrmap:10` declares `scope=prototype active=false`, `size_cells=18x18`; `tests/godot/test_rentenitorn_interior_map.gd:33-37,84-96` asserts those values and the inactive catalog entry. |
| Conservative closed shell | `content/maps/rentenitorn_interior.rrmap:25-32` authors west, north, east, and split south shell walls; `tests/godot/test_rentenitorn_interior_map.gd:56-75` requires all shell/partition wall groups and exact west/north/east segment counts. |
| Two authored doors | The west wall has one opening and the south wall is split around the inward door (`content/maps/rentenitorn_interior.rrmap:28-32`); the closed-shell test asserts west count `2`, north count `1`, and east count `1` (`tests/godot/test_rentenitorn_interior_map.gd:70-75`). |
| Three traversal bands and wall-walk | Ground, counting, and deck terrain bands are authored at `content/maps/rentenitorn_interior.rrmap:19-24`; the three floor anchors and wall-walk anchors are at lines `52-60`; `test_rentenitorn_map_reaches_every_band_and_the_wall_walk` routes from the player spawn to every required anchor (`tests/godot/test_rentenitorn_interior_map.gd:26-50`). |
| Shared contract identity | `scripts/map/definitions/prototypes/rentenitorn_interior_definition.gd:18-57` declares the north-quarter building, return spawn, interior entry spawn, reciprocal transition fields, three floor IDs, wall-walk ID, outcomes, loot/evidence, and persistence IDs. The interior map test validates this package and requires three floors (`tests/godot/test_rentenitorn_interior_map.gd:76-81`). |
| Exterior inward door and entry | `content/maps/north_quarter.rrmap:87-91` declares `merchant_wall_tower_northwest tower=true door_side=south` and `rentenitorn_enter` targeting `rentenitorn_interior_entry`, with `spawn=merchant_wall_tower_northwest_return`, `spawn_offset_px=0,96`, and the matching building ID. |
| Blueprint registry | `scripts/map/map_blueprint_registry.gd:159-174` registers the Rentenitorn source, factory, and all ten required anchors. `scripts/map/definitions/prototypes/rentenitorn_interior_rrmap_factory.gd:9-15` returns the parsed blueprint. |

## Exact verification results

All Godot test commands used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot` and `tools/run_godot_checked.sh --require-test-summary`.

```text
GODOT_LOG_DIR=/tmp/r788-rentenitorn-map tools/run_godot_checked.sh --require-test-summary r788-rentenitorn-map -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_interior_map
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r788-tower-doors tools/run_godot_checked.sh --require-test-summary r788-tower-doors -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_tower_doors
# PASS: 1 file, 7 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r788-contract tools/run_godot_checked.sh --require-test-summary r788-contract -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_enterable_tower_contract
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r788-catalog tools/run_godot_checked.sh --require-test-summary r788-catalog -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_completed_tower_packages
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r788-north-quarter tools/run_godot_checked.sh --require-test-summary r788-north-quarter -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_north_quarter_prototype_map
# PASS: 1 file, 10 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r788-transition-manifest tools/run_godot_checked.sh --require-test-summary r788-transition-manifest -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_nunnatorn_transitions
# PASS: 1 file, 1 test, 0 failures, 0 errors
```

The last command is the existing reciprocal-transition smoke for the shared transition pattern. Because no existing test directly loads both Rentenitorn maps for this pair, the exact Rentenitorn pair was also checked with a bounded temporary SceneTree probe:

```text
GODOT_LOG_DIR=/tmp/r788-reciprocal-probe-final tools/run_godot_checked.sh r788-reciprocal-probe-final -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script /tmp/r788_rentenitorn_reciprocal_probe.gd
# PASS: R-788 Rentenitorn reciprocal probe
# exit 0; probe confirmed both destination_scene_id/destination_spawn_id links,
# building_id, and the authored +96/-64 spawn offsets
```

## Blueprint-validator boundary

The repository-wide validator was run as requested:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/validate_map_blueprints.gd
# exit 1: 30 registered, 3 errors, 645 warnings
# Rentenitorn itself emitted warnings only (4 MAP_CHUNK_BOUNDARY_AMBIGUOUS records)
# unrelated errors:
#   Kuldjala factory returned an invalid blueprint
#   duplicated Toompea Small Castle registry entries returned invalid blueprints
```

Those errors are outside the R-788 allowlist and are owned by the existing Kuldjala/Toompea work. They do not invalidate the focused Rentenitorn parser, route, shell, contract, catalog, exterior-door, or reciprocal-probe results. The warnings are the known future chunk-boundary advisory for the authored 18x18 tower shell and do not fail the focused acceptance suite.

## Final status

R-788's scoped structural and transition verification is complete. The implementation remains deliberately inactive: no release activation or historical/art approval is claimed by this note.
