# R-835 P4-020b North Quarter elevation parser gate

**Task:** R-835 / P4-020b
**Parent:** R-245 / P4-020
**Verification date:** 2026-09-01
**Base revision:** `2db612a415951ecc4794b4c1bdf8494d7709f2de` (`docs: record Godot teardown test guidance`)
**Godot:** `4.7.1.stable.official.a13da4feb`
**Decision:** **BLOCKED - clean-HEAD elevation parser gate is not available**

## Scope and decision boundary

This is a verification-only closeout for the North Quarter elevation parser gate. It does not change RRMap parser/compiler code, map authoring, runtime activation, transition registries, parity fixtures, or unrelated validation baselines.

The shared worktree already contains an uncommitted elevation handoff in:

- [`map_rrmap_parser_statements.gd`](../../scripts/map/rrmap/map_rrmap_parser_statements.gd)
- [`test_map_rrmap_parser.gd`](../../tests/godot/test_map_rrmap_parser.gd)
- [`test_north_quarter_prototype_map.gd`](../../tests/godot/test_north_quarter_prototype_map.gd)

Those files are modified by another handoff and are not owned or committed by R-835. The clean-HEAD result is therefore the acceptance result for this task.

## Verification matrix

| Check | Result | Evidence and interpretation |
|---|---|---|
| Clean detached focused Godot checkout | **BLOCKED** | `/tmp/rebel-reval-r835-clean` was based on `HEAD=2db612a4`. `test_map_rrmap_parser.gd`, `test_north_quarter_prototype_map.gd`, and `test_transition_spawn_clearance.gd` reported **3 files, 29 tests, 25 failures, 111 errors**. The first authored-map diagnostics are `unknown command 'elevation_ramp'` / `unknown command 'elevation_area'`. |
| Clean North Quarter elevation load | **BLOCKED** | `content/maps/north_quarter.rrmap:12-15` emits two `elevation_ramp` and two `elevation_area` unknown-command errors. The resulting invalid `MapDefinition` causes dependent spawn/route/property failures; these are parser-cascade diagnostics, not independent North Quarter geometry findings. |
| Dirty-worktree handoff regression | **PASS, not acceptance evidence** | The same focused area with the existing uncommitted handoff reports **3 files, 32 tests, 0 failures, 0 errors**: parser 16/16, North Quarter 10/10, transition clearance 6/6. This proves the pending handoff removes the cascade, but it cannot certify clean HEAD or establish R-835 ownership. |
| North Quarter activation ledger verifier | **PASS** | `python3 tools/verify_north_quarter_activation.py` passes with activation still fail-closed. The catalog entry remains prototype/inactive and the activation decision remains blocked. |
| Full blueprint validator in current shared checkout | **BLOCKED by independent baseline** | `tools/validate_map_blueprints.gd` exits 1 with **30 registered, 2 errors, 646 warnings**. Both errors are for `toompea_small_castle`: `MAP_REGISTRY_FACTORY_INVALID` and invalid uppercase stable IDs such as `SC-forecourt`. This is not attributed to R-835 and was not repaired here. |

## Exact verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

# Clean-HEAD focused evidence was captured in /tmp/rebel-reval-godot-logs/r835-clean-tests.log
# The prepared dirty-worktree handoff evidence is in /tmp/rebel-reval-godot-logs/r835-worktree.log

python3 tools/verify_north_quarter_activation.py
"$GODOT_BIN" --headless --path . --script tools/validate_map_blueprints.gd
```

The focused clean log records the first North Quarter failure at `north_quarter_definition.gd:14` while loading the authored elevation statements. The dirty handoff log records the complete 32-test green summary, followed only by the repository's known Godot teardown ObjectDB/resource-leak diagnostics.

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
