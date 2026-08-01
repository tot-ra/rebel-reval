# P0-102k Clean Acceptance Baseline

**Task:** R-361 / P0-102k
**Parent:** R-110 / P0-102
**Date:** 2026-08-01
**Snapshot:** `1df84ccbdf8599fe149609e54a32a41654ca6415` (`Add historically bounded Viru Gate landmark asset`)
**Status:** **PARTIAL - clean baseline reproduced; P0-102 remains blocked by scoped and external findings**

## Scope and method

This report reproduces the P0-102 acceptance boundary from a detached clean worktree at the snapshot above. The live project worktree contained unrelated character, fauna, environment, and generated-import changes; none were included in the reproduction or this report.

The clean worktree was created at `/tmp/rebel-reval-p0-102k`, followed by Godot editor import. Focused suites were run one process per suite through `tools/run_godot_checked.sh --require-test-summary`. Asset lint and provenance were run from the same clean snapshot. The report records failures without changing runtime, map, character, fauna, landmark, or provenance data outside this task's QA allowlist.

## Acceptance matrix

| Check | Result | Evidence / reproduction |
|---|---|---|
| Clean snapshot and Godot editor import | **PASS** | `git worktree add --detach /tmp/rebel-reval-p0-102k HEAD`; snapshot `1df84ccbdf8599fe149609e54a32a41654ca6415`. `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --import --path /tmp/rebel-reval-p0-102k` completed successfully. Godot emitted only the existing nested `project.godot` skip warning for generated verification content. |
| Environment-kit integration | **BLOCKED - scoped P0-102** | `test_environment_kit_integration`: **4/5 pass, 1 failure**. `test_forge_and_street_well_keep_clearance_and_local_wear_contract` fails `forge yard needs local grime wear`. This is an authored environment-kit wear contract finding and remains within P0-102 ownership. |
| Building surface weathering | **PASS** | `test_building_surface_weathering`: **6/6 pass**. |
| Core 3D map view regression | **PASS** | `test_map_view_3d_core`: **17/17 pass**. |
| Mesh-builder regression | **PASS** | `test_map_view_3d_mesh`: **18/18 pass**. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: **4/4 pass**. |
| Decal contract | **PASS** | `test_map_view_decals`: **8/8 pass**. The earlier R-360 courtyard soot failure is fixed in ancestor commit `725a46c4`, which is included in the clean snapshot. |
| Exceptional fortification renderer boundary | **BLOCKED - external R-353** | `test_map_view_3d_fortification`: **6/8 pass, 1 failure, 2 errors**. `test_town_wall_gets_battlements_and_gate_arch_clears_character` fails `Karja Gate needs open metal doors`; the attempted `GateDoor0` lookup then produces `Node not found` and null `material_override` diagnostics at `tests/godot/test_map_view_3d_fortification.gd:135-137`. This belongs to the active `R-353 / P0-102e` exceptional-landmark boundary task, not this baseline reproduction. |
| **Focused Godot total** | **PARTIAL** | **64/66 tests passed**. Two failures: the scoped forge-yard grime contract and the external Karja Gate contract. The fortification suite also reports two related engine/script diagnostics caused by the missing gate node. |
| Asset lint | **BLOCKED - external character baseline** | `python3 tools/verify_asset_lint.py` fails only with `assets/characters/shared/sergeant.glb: tier 1 (named_npc) triangle budget exceeded (57168>56000)`. This is outside P0-102 ownership and is not fixed here. |
| Asset provenance | **BLOCKED - external Viru Gate import baseline** | `python3 tools/validate_asset_sources.py` reports eight inventory/active-runtime paths missing from `assets/SOURCES.csv`: `viru_gate_ViruIron_albedo.png`, `viru_gate_ViruLimestone_albedo.png`, `viru_gate_ViruLimestoneLight_albedo.png`, `viru_gate_ViruLimestoneShadow_albedo.png`, `viru_gate_ViruOak_albedo.png`, `viru_gate_ViruOakCut_albedo.png`, `viru_gate_ViruOakTar_albedo.png`, and `viru_gate_ViruRoofTile_albedo.png` under `assets/props/architecture/gates/`. These are generated sidecars from the Viru Gate asset snapshot and are outside this QA task's allowlist. |

## Exact commands

Run from the repository root or replace `.` with the clean worktree path:

```sh
git worktree add --detach /tmp/rebel-reval-p0-102k HEAD
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --import --path /tmp/rebel-reval-p0-102k

for filter in \
  test_environment_kit_integration \
  test_building_surface_weathering \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_material_resolution \
  test_map_view_decals \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "p0-102k-${filter}" -- \
    "$GODOT_BIN" --headless --path /tmp/rebel-reval-p0-102k \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 tools/verify_asset_lint.py
python3 tools/validate_asset_sources.py
```

Captured logs are under `/tmp/p0_102k_logs/` in the reproducing session:

- `p0-102k-test_environment_kit_integration.log`
- `p0-102k-test_building_surface_weathering.log`
- `p0-102k-test_map_view_3d_core.log`
- `p0-102k-test_map_view_3d_mesh.log`
- `p0-102k-test_map_view_material_resolution.log`
- `p0-102k-test_map_view_decals.log`
- `p0-102k-test_map_view_3d_fortification.log`
- `/tmp/p0_102k_asset_lint.log`
- `/tmp/p0_102k_asset_sources.log`

## Handoffs and decision

1. **P0-102 owner / environment kit:** address the missing local grime wear asserted by `test_forge_and_street_well_keep_clearance_and_local_wear_contract`, then rerun the integration suite and this clean baseline.
2. **R-353 / P0-102e:** own the missing `Karja Gate` `GateDoor0` renderer contract and its focused fortification diagnostics. This report does not modify landmark/runtime code.
3. **Character owner:** resolve or explicitly accept the `sergeant.glb` tier-1 triangle budget baseline.
4. **Viru Gate asset owner:** register the eight generated albedo sidecars in `assets/SOURCES.csv` in the Viru Gate asset change, or document an approved exclusion if they are intentionally non-runtime.

**Decision:** keep R-361 in `in_review`. The clean baseline is reproducible and documented, but P0-102 is not ready to close: one scoped environment-kit contract fails, while fortification, asset lint, and provenance have separately owned external findings.
