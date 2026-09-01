# R-835 P4-020b North Quarter elevation parser gate

**Task:** R-835 / P4-020b
**Parent:** R-245 / P4-020
**Verification date:** 2026-09-01
**Base revision:** `1424bf620074214c6787ce73886676d074bcda2f` (`HEAD` at verification)
**Godot:** `4.7.1.stable.official.a13da4feb`
**Decision:** **BLOCKED - clean-HEAD elevation parser gate is not available**

## Scope and decision boundary

This is a verification-only closeout for the North Quarter elevation parser gate. It does not change RRMap parser/compiler code, map authoring, runtime activation, transition registries, parity fixtures, or unrelated validation baselines.

The shared worktree already contains an uncommitted elevation handoff in:

- [`map_rrmap_parser_statements.gd`](../../scripts/map/rrmap/map_rrmap_parser_statements.gd)
- [`test_map_rrmap_parser.gd`](../../tests/godot/test_map_rrmap_parser.gd)
- [`test_north_quarter_prototype_map.gd`](../../tests/godot/test_north_quarter_prototype_map.gd)

Those files are modified by another handoff and are not owned or committed by R-835. The clean-HEAD result is therefore the acceptance result for this task.

## Historical verification matrix (superseded by the current clean-HEAD rerun)

| Check | Result | Evidence and interpretation |
|---|---|---|
| Clean detached focused Godot checkout | **BLOCKED** | `/tmp/rebel-reval-r835-clean` was based on `HEAD=2db612a4`. `test_map_rrmap_parser.gd`, `test_north_quarter_prototype_map.gd`, and `test_transition_spawn_clearance.gd` reported **3 files, 29 tests, 25 failures, 111 errors**. The first authored-map diagnostics are `unknown command 'elevation_ramp'` / `unknown command 'elevation_area'`. |
| Clean North Quarter elevation load | **BLOCKED** | `content/maps/north_quarter.rrmap:12-15` emits two `elevation_ramp` and two `elevation_area` unknown-command errors. The resulting invalid `MapDefinition` causes dependent spawn/route/property failures; these are parser-cascade diagnostics, not independent North Quarter geometry findings. |
| Dirty-worktree handoff regression | **PASS, not acceptance evidence** | The same focused area with the existing uncommitted handoff reports **3 files, 32 tests, 0 failures, 0 errors**: parser 16/16, North Quarter 10/10, transition clearance 6/6. This proves the pending handoff removes the cascade, but it cannot certify clean HEAD or establish R-835 ownership. |
| North Quarter activation ledger verifier | **PASS** | `python3 tools/verify_north_quarter_activation.py` passes with activation still fail-closed. The catalog entry remains prototype/inactive and the activation decision remains blocked. |
| Full blueprint validator in current shared checkout | **BLOCKED by independent baseline** | `tools/validate_map_blueprints.gd` exits 1 with **30 registered, 2 errors, 646 warnings**. Both errors are for `toompea_small_castle`: `MAP_REGISTRY_FACTORY_INVALID` and invalid uppercase stable IDs such as `SC-forecourt`. This is not attributed to R-835 and was not repaired here. |


## Current clean-HEAD rerun

A fresh detached worktree was created from `HEAD=1424bf620074214c6787ce73886676d074bcda2f`, imported with Godot before running the checks, and removed after capture. This rerun excludes the shared dirty-worktree parser handoff and is the current acceptance evidence for R-835.

| Check | Result | Current evidence |
|---|---|---|
| `test_map_rrmap_parser.gd` | **PASS** | **1 file, 14 tests, 0 failures, 0 errors**. This covers the parser unit boundary only; it does not prove that authored elevation commands are dispatched by the clean production loader. |
| `test_north_quarter_prototype_map.gd` | **BLOCKED** | **1 file, 9 tests, 19 failures, 44 errors**. `content/maps/north_quarter.rrmap:12-15` reports `unknown_command` for two `elevation_ramp` and two `elevation_area` statements. Dependent failures include invalid bounds/dressing data and missing `to_reval_harbor` data. |
| `test_transition_spawn_clearance.gd` | **BLOCKED** | **1 file, 6 tests, 6 failures, 67 errors**. The same clean authored-map parser cascade appears in Lower Town, Market Civic, and Monastery maps; spawn-offset and transition assertions are downstream diagnostics. |
| `tools/validate_map_blueprints.gd` | **BLOCKED** | **28 registered, 9 errors, 145 warnings**. The 9 errors are `MAP_REGISTRY_FACTORY_INVALID` for authored RRMap factories after their elevation parse failures. They are not an independent R-835 defect. |
| `tools/verify_transitions.gd` | **BLOCKED by parser cascade** | **48 errors** in the clean snapshot, including invalid map definitions and missing registered spawns. This is downstream of the same authored RRMap parse failure and is not separately attributed to R-835. |
| `tools/verify_north_quarter_activation.py` | **PASS** | `P4-020 North Quarter activation readiness guard passed.` Activation remains fail-closed. |
| `tools/verify_map_activation.py` | **PASS** | `Map activation guard passed.` No activation/runtime registry change is authorized by this report. |

The clean rerun confirms that R-835 remains **BLOCKED** until R-604 lands its RRMap `elevation_ramp` / `elevation_area` parser/compiler support and the focused production-load checks pass from a fresh clean snapshot. The standalone 14-test parser unit result must not be promoted to map acceptance while the authored production loader still emits `unknown_command`.

Evidence logs:

- `/tmp/rebel-reval-r835-clean-current-logs/parser.log`
- `/tmp/rebel-reval-r835-clean-current-logs/north_quarter.log`
- `/tmp/rebel-reval-r835-clean-current-logs/transition_clearance.log`
- `/tmp/rebel-reval-r835-clean-current-logs/validate_map_blueprints.log`
- `/tmp/rebel-reval-r835-clean-final-logs/verify_transitions.log`
- `/tmp/rebel-reval-r835-clean-final-logs/verify_north_quarter_activation.log`
- `/tmp/rebel-reval-r835-clean-final-logs/verify_map_activation.log`

## Exact verification commands

The current clean-HEAD rerun used the following commands from the repository root. The detached worktree was imported before the checks and removed after the logs were captured:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
CLEAN=/tmp/rebel-reval-r835-clean-current

"$GODOT_BIN" --headless --editor --import --path "$CLEAN"
"$GODOT_BIN" --headless --path "$CLEAN" --script tools/run_godot_tests.gd -- "--filter=test_map_rrmap_parser"
"$GODOT_BIN" --headless --path "$CLEAN" --script tools/run_godot_tests.gd -- "--filter=test_north_quarter_prototype_map"
"$GODOT_BIN" --headless --path "$CLEAN" --script tools/run_godot_tests.gd -- "--filter=test_transition_spawn_clearance"
"$GODOT_BIN" --headless --path "$CLEAN" --script tools/validate_map_blueprints.gd
"$GODOT_BIN" --headless --path "$CLEAN" --script tools/verify_transitions.gd
python3 "$CLEAN/tools/verify_north_quarter_activation.py"
python3 "$CLEAN/tools/verify_map_activation.py"
```

The focused clean logs record the first North Quarter failure at `north_quarter.rrmap:12-15` while loading the authored elevation statements. The current addendum above records the per-suite summaries and distinguishes parser-cascade diagnostics from the independent activation guards. Historical handoff logs remain listed below for provenance; they are not clean-HEAD acceptance evidence.

## Dependency and handoff

**R-604 / Restore RRMap elevation command support on clean HEAD** is still `in_progress` on the task board. Its acceptance text explicitly owns the `elevation_ramp` / `elevation_area` parser/compiler boundary and requires verification from an imported clean checkout. The uncommitted three-file handoff currently present in the shared worktree is the implementation evidence for that dependency, not a completed R-835 deliverable.

R-835 must remain open until R-604 lands and the following checks are rerun from a fresh clean snapshot:

1. RRMap parser/compiler focused tests, including elevation parse, compile, and canonical round-trip coverage.
2. `test_north_quarter_prototype_map` with authored elevation data loaded without parser errors.
3. `test_transition_spawn_clearance` and the adjacent transition/collision checks.
4. `tools/validate_map_blueprints.gd`, with the independent `toompea_small_castle` baseline either resolved by its owner or explicitly separated from the North Quarter result.

No activation/runtime registry change is authorized by this report. No duplicate dependency task is created because R-604 already owns the parser boundary.

## Evidence files

- `/tmp/rebel-reval-godot-logs/r835-clean-tests.log`
- `/tmp/rebel-reval-godot-logs/r835-worktree.log`
- `/tmp/rebel-reval-godot-logs/r835-clean-import.log`
- `/tmp/rebel-reval-godot-logs/p4-020-blueprints-final.log`
- [`p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`r834_p4_020a_upstream_dependency_reconciliation.md`](r834_p4_020a_upstream_dependency_reconciliation.md)

**Final status:** **BLOCKED - keep R-835 in review and rerun clean-HEAD acceptance after R-604 is completed.**
