# P0-102i Exceptional Renderer Boundary Reverification

**Task:** R-363 / P0-102i
**Parent:** R-110 / P0-102
**Related implementation:** R-353 / P0-102e
**Date:** 2026-08-02
**Snapshot:** `28a6bbc1` (`main`)
**Status:** **BLOCKED - R-353 implementation and focused regression are not ready for acceptance**

## Scope and decision

This is an independent QA re-verification of the ordinary-versus-exceptional renderer boundary. It checks both a clean detached baseline and the current dirty R-353 worktree without claiming or modifying R-353's implementation. The boundary must keep churches, civic and guild buildings, institutions, and gatehouses out of the ordinary house renderer while preserving the existing fortification and gate-landmark paths.

The clean baseline is reproducible for the mesh regression and still has one Karja Gate contract failure. The current dirty R-353 worktree has the same gate failure plus an exceptional-house assertion mismatch and a mesh-test fixture parse failure. These findings remain with R-353; this QA task does not weaken assertions or add compatibility helpers to make the suite pass.

## Verification matrix

| Check | Result | Evidence |
|---|---|---|
| Clean HEAD import | **PASS** | Detached worktree `/tmp/rebel-reval-r363-clean-20260802` at `28a6bbc1`; `Godot --headless --editor --import` completed successfully. `git worktree add` emitted the repository's existing two non-pointer MP3 warnings, but the import command completed with status 0. |
| Clean mesh regression | **PASS** | `test_map_view_3d_mesh`: **18/18**, 0 failures, 0 errors. |
| Clean exceptional/fortification suite | **BLOCKED** | `test_map_view_3d_fortification`: **7/8 test methods pass, 1 failure, 2 errors**. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails because `Landmark_karja_gate_arch` has no `GateDoor0`; the follow-up lookup produces the null `material_override` diagnostics at `tests/godot/test_map_view_3d_fortification.gd:135-137`. |
| Clean ordinary-house regression | **PASS** | `test_houses_get_facade_doors_and_windows` passes in the same clean fortification suite. The clean baseline therefore does not fail on the ordinary-house assertions. |
| Current R-353 fortification suite | **BLOCKED** | Live dirty worktree: **6/8 test methods pass**, with `st_catherines_church` incorrectly entering house-only door/window/roof assertions and the unchanged `karja_gate_arch/GateDoor0` failure. The run reports 11 assertion failures and 4 engine/script diagnostics. |
| Current R-353 mesh suite | **BLOCKED - parse error** | Live dirty worktree cannot load `tests/godot/test_map_view_3d_mesh.gd`: `MarketCivicQuarter` is undeclared and `_building_by_id()` is missing at lines 567-569, with cascading type-inference diagnostics. The runner reports 0 tests and 5 load/parse errors. |
| View-only and stable-ID scope | **NOT ACCEPTED** | No collision/navigation, map source, runtime, or asset changes were made by this QA task. Stable-ID and route-opening acceptance must be rerun after R-353 fixes the gate contract and focused fixture. |

## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-r363-clean-20260802

git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
"$GODOT_BIN" --headless --path "$WT" --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh

# Run the same focused checks in the live worktree to expose R-353 WIP findings.
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
```

Captured current logs:

- `/tmp/r363-clean-fortification-current.log` - clean 7 pass, 1 failure, 2 errors.
- `/tmp/r363-clean-mesh-current.log` - clean 18/18 pass.
- `/tmp/r363-fortification-current.log` - dirty 6 pass, 11 assertion failures, 4 diagnostics.
- `/tmp/r363-mesh-current.log` - dirty 0 tests, 5 parse/load errors.

## Handoff and close decision

1. **R-353 / P0-102e:** add or expose the expected open metal `GateDoor0` node, or update the focused test and renderer contract together, then rerun the clean fortification suite.
2. **R-353 / P0-102e:** make the new mesh boundary fixture self-contained by importing its intended market-civic fixture and defining the building lookup helper, or replace them with existing fixtures; rerun `test_map_view_3d_mesh` after the script loads.
3. **R-353 / P0-102e:** update ordinary-house assertions to skip records accepted by the exceptional registry, or provide a separate exceptional assertion path. Do not route landmarks through the ordinary house kit to satisfy the test.
4. **R-364 / P0-102l:** consume this report together with the other P0-102 evidence. Do not close P0-102 while this owned prerequisite remains blocked.

**Decision:** keep R-363 in `in_review`. The clean baseline and current-WIP findings are independently reproducible, but the exceptional renderer boundary is not ready to accept.
