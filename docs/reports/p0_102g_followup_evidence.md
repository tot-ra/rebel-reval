# P0-102g Follow-up Acceptance Evidence

**Task:** R-369 / P0-102g
**Parent:** R-110 / P0-102
**Date:** 2026-08-02
**Snapshot:** `4b461b035998a228985c95f81d548101a0f6d5e3` (`main`, working tree ahead of `origin/main`)
**Status:** **PASS - all scoped environment-kit acceptance checks are green**

## Scope and method

This is an evidence-only refresh after the R-360 courtyard-soot and R-366 forge-yard-grime fixes. The task changed no runtime, map, asset, landmark, or test source. The only deliverable is this report.

The checks were run from a detached worktree at `/tmp/rebel-reval-r369-clean`, created from the exact snapshot above. Godot 4.7.1 editor import completed before testing. Each focused suite was run in a separate Godot process through `tools/run_godot_checked.sh --require-test-summary`, so every result has an independent non-empty final summary. The live project worktree contains unrelated modified and untracked files; those files were not used as acceptance evidence.

Godot import created generated sidecars in the detached worktree. No tracked source files were changed in that worktree after the snapshot was created.

## Acceptance matrix

| Check | Result | Evidence |
|---|---|---|
| Snapshot and Godot editor import | **PASS** | `git worktree add --detach /tmp/rebel-reval-r369-clean HEAD`; snapshot `4b461b035998a228985c95f81d548101a0f6d5e3`. `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path /tmp/rebel-reval-r369-clean` completed successfully. |
| Environment-kit integration | **PASS** | `test_environment_kit_integration`: **5/5 tests**, 0 failures, 0 errors. |
| Decal and local-wear regression | **PASS** | `test_map_view_decals`: **8/8 tests**, 0 failures, 0 errors. This includes the Lower Town and smithy-courtyard wear assertions. |
| Building surface weathering | **PASS** | `test_building_surface_weathering`: **6/6 tests**, 0 failures, 0 errors. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: **4/4 tests**, 0 failures, 0 errors. |
| Core 3D map-view regression | **PASS** | `test_map_view_3d_core`: **17/17 tests**, 0 failures, 0 errors. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: **18/18 tests**, 0 failures, 0 errors. |
| **Scoped focused-test total** | **PASS** | **58/58 tests**, 0 failures, 0 errors across six files. Every checked runner invocation returned status 0. |

## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
WT=/tmp/rebel-reval-r369-clean

git worktree add --detach "$WT" HEAD
"$GODOT_BIN" --headless --editor --import --path "$WT"

export GODOT_LOG_DIR=/tmp/r369_checked
mkdir -p "$GODOT_LOG_DIR"

for filter in \
  test_environment_kit_integration \
  test_map_view_decals \
  test_building_surface_weathering \
  test_map_view_material_resolution \
  test_map_view_3d_core \
  test_map_view_3d_mesh; do
  tools/run_godot_checked.sh --require-test-summary "r369-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done
```

The checked logs were written under `/tmp/r369_checked/`:

- `test_environment_kit_integration.console.log`
- `test_map_view_decals.console.log`
- `test_building_surface_weathering.console.log`
- `test_map_view_material_resolution.console.log`
- `test_map_view_3d_core.console.log`
- `test_map_view_3d_mesh.console.log`

## Shutdown diagnostics

The raw Godot logs contain only the repository's known shutdown-only DEF-002 diagnostics after successful summaries:

- `8 resources still in use at exit` for environment integration, decals, building weathering, core 3D, and mesh suites.
- `1 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit` for the core 3D and mesh suites.

`tools/run_godot_checked.sh` explicitly allowlists these shutdown diagnostics. No other engine error, script error, parse error, resource-load failure, or checked-runner failure occurred. These diagnostics do not reduce the scoped acceptance result.

## Historical fix confirmation

- **R-360 courtyard soot:** no longer open. `test_map_view_decals` passes 8/8, including the relevant local-wear assertions.
- **R-366 forge-yard grime:** no longer open. `test_environment_kit_integration` passes 5/5 and `test_map_view_decals` passes 8/8, including the smithy-courtyard grime coverage.

Neither historical finding is reported as an active failure in the current snapshot.

## Explicitly outside this task

This refresh does not run, alter, or accept the following unrelated boundaries:

- **R-353 / P0-102e fortification findings**, including the Karja Gate renderer contract.
- Unrelated asset-lint and asset-provenance baselines.
- P0-101 and P2-063 through P2-067 downstream ordinary-house, plot-dressing, tier-wiring, landmark, and gameplay-scale visual handoffs.
- Any modified or untracked files already present in the live project worktree.

Those findings remain owned by their existing tasks and are not environment-kit acceptance failures.

## Decision

The shared P0-102 environment-kit acceptance evidence is current and green for the six required focused checks. R-360 and R-366 are proven fixed in snapshot `4b461b03`. No follow-up task is required for this scoped evidence refresh.
