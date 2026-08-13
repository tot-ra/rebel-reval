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


## R-363 live recheck addendum (2026-08-13)

A fresh live-worktree recheck was run from the current shared tree. The worktree contains unrelated active changes, so this addendum records only the scoped renderer-boundary evidence and does not claim those changes.

| Check | Result | Evidence |
|---|---|---|
| Focused mesh boundary suite | **PASS with existing teardown diagnostics** | `test_map_view_3d_mesh`: **19/19** assertions pass. The exceptional-building boundary test passes for civic/church/guild/institution records, St. Catherine's, and an ordinary-house control. The current dirty run still emits 8 existing dummy-renderer teardown diagnostics from authored gate-leaf exposure. |
| Ordinary-house fortification regression | **PASS** | `test_houses_get_facade_doors_and_windows` passes. The loop now skips registry-accepted exceptional records, so St. Catherine's is no longer incorrectly checked as an ordinary house. |
| Focused fortification suite | **BLOCKED by Karja Gate diagnostics** | The current run reaches all 8 test methods with **0 assertion failures**, but emits 6 engine/script diagnostics from the independent Karja Gate authored-leaf path. The district-boundary marker assertion now passes with the five authored IDs. |
| Current boundary interpretation | **PARTIAL** | The intended ordinary-versus-exceptional routing and five-marker district-boundary contract are green at assertion level. The remaining blocker is the Karja Gate authored-leaf/dummy-renderer diagnostic path, not grounds to route exceptional buildings back through the ordinary house kit. |
| Scope changes | **PASS** | This recheck changes only the focused regression coverage and this report. No map source, collision, navigation, runtime route, or asset file was modified. |

Exact commands from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
GODOT_LOG_DIR=/tmp/r363-live \
  tools/run_godot_checked.sh --require-test-summary r363-fortification -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_fortification
```

The checked fortification log is `/tmp/r363-live/r363-fortification.log`. Godot Compatibility shutdown leak diagnostics also appear after the test summary; they are existing renderer shutdown noise and are not the scoped assertions.

## R-508 transition-marker reconciliation (2026-08-13)

The district-boundary marker drift was caused by a stale count contract, not by an accidental renderer marker. `lower_town_slice.rrmap:297-301` authors five `highlight_area=true` destination transitions:

- `vana_turg_boundary`
- `vene_district_boundary`
- `viru_road_boundary`
- `workers_outer_wall_road`
- `to_reval_south`

`street_start_spawn` at line 302 is an authored spawn-only transition without `highlight_area`, so it correctly produces no marker. `MapView3D._assemble` intentionally creates one view-only marker for each highlighted transition and does not synthesize any others.

The regression in `tests/godot/test_map_view_3d_fortification.gd` now asserts the exact five-ID set, checks each `Marker_<id>` node, and explicitly rejects `Marker_street_start_spawn`. This documents the authored contract while protecting against both accidental marker removal and future marker inflation. The R-508 marker finding is resolved. The focused live fortification run still cannot report a clean file summary because the independent Karja Gate authored-leaf path emits the pre-existing dummy-renderer diagnostics; no marker assertion failure was observed. The focused mesh suite remains 19/19 assertion passes.

## Handoff and close decision

1. **R-353 / P0-102e:** add or expose the expected open metal `GateDoor0` node, or update the focused test and renderer contract together, then rerun the clean fortification suite.
2. **R-508:** **RESOLVED** - the district-boundary contract now matches the five authored highlighted transitions and has deterministic ID-level regression coverage.
3. **R-364 / P0-102l:** consume this report together with the remaining Karja Gate evidence. Do not close P0-102 while that owned prerequisite remains blocked.

**Decision:** keep the exceptional renderer boundary acceptance open only for the Karja Gate authored-leaf contract. The district transition-marker count drift is reconciled and no longer blocks acceptance.
