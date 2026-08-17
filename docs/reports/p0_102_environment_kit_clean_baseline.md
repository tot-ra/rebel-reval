# P0-102 Environment-Kit Clean Baseline

**Task:** R-540 / P0-102 acceptance: reproduce clean regression baseline
**Parent:** R-110 / P0-102
**Date:** 2026-08-17
**Snapshot:** `356c9721d548689ee59f5e12b80f649780d0fa7f` (`Document P0-102 focused regression blockers`)
**Verification worktree:** `/tmp/rebel-reval-r540-20260817` (detached clean snapshot)
**Decision:** **BLOCKED / PARTIAL - do not accept or close P0-102**

## Scope and method

This report reproduces the P0-102 focused regression from a detached clean snapshot. The live project worktree was not used for acceptance because it contains unrelated tracked and untracked WIP across RRMap editor/runtime files, maps, assets, history, tests, generated imports, and provenance data. No runtime, map, asset, test, or acceptance-threshold change was made for R-540.

The clean snapshot imported successfully with Godot 4.7.1. Each focused suite ran independently in its own Godot process through `tools/run_godot_checked.sh --require-test-summary`, so one failing suite could not hide the remaining results. The retained logs and status table are under `/tmp/r540_checked/`.

## Exact verification commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export WT=/tmp/rebel-reval-r540-20260817
export GODOT_LOG_DIR=/tmp/r540_checked

# Detached clean snapshot
# Snapshot: 356c9721d548689ee59f5e12b80f649780d0fa7f
git worktree add --detach "$WT" 356c9721d548689ee59f5e12b80f649780d0fa7f
"$GODOT_BIN" --headless --editor --import --path "$WT"
# Result: IMPORT_STATUS=0; import log: /tmp/r540_checked/import.log

for filter in \
  test_environment_kit_integration \
  test_building_surface_weathering \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_material_resolution \
  test_map_view_decals \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "r540-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
python3 "$WT/tools/verify_p0_102_environment_kit_evidence.py"
```

The per-suite exit statuses are preserved in `/tmp/r540_checked/suite_status.tsv`. The focused commands returned status 1 for every suite with substantive failures and status 0 for `test_map_view_material_resolution`.

## Focused-suite results

| Suite | Test methods | Failures | Engine/script errors | Exit | Result | Retained log |
|---|---:|---:|---:|---:|---|---|
| `test_environment_kit_integration` | 5 | 26 | 27 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-environment_kit_integration.log` |
| `test_building_surface_weathering` | 6 | 1 | 4 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-building_surface_weathering.log` |
| `test_map_view_3d_core` | 20 | 9 | 46 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-map_view_3d_core.log` |
| `test_map_view_3d_mesh` | 19 | 9 | 46 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-map_view_3d_mesh.log` |
| `test_map_view_material_resolution` | 7 | 0 | 0 | 0 | **PASS** | `/tmp/r540_checked/r540-map_view_material_resolution.log` |
| `test_map_view_decals` | 8 | 5 | 6 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-map_view_decals.log` |
| `test_map_view_3d_fortification` | 8 | 6 | 46 | 1 | **BLOCKED** | `/tmp/r540_checked/r540-map_view_3d_fortification.log` |
| **Total** | **73** | **56** | **175** | - | **BLOCKED** | `/tmp/r540_checked/` |

`test_map_view_material_resolution` is the only fully green suite. Its seven deterministic material tests pass with zero failures and zero errors. The weathering suite's generic surface-family and deterministic-variant tests pass, but Lower Town wall-texture acceptance is interrupted by the map parser failure.

## Asset and evidence checks

| Check | Result | Output |
|---|---|---|
| Godot editor import | **PASS** | `IMPORT_STATUS=0`; `/tmp/r540_checked/import.log` |
| Asset lint | **PASS** | `asset lint passed (8 style-lock textures, 9 character glbs, 29 tier-classified character glb(s), 0 portrait(s) checked)`; `/tmp/r540_checked/asset-lint.log` |
| Asset provenance | **PASS** | `assets/SOURCES.csv schema ok; 1143 rows; 990 inventory paths covered; 984 active runtime assets covered`; `/tmp/r540_checked/asset-provenance.log` |
| P0-102 evidence audit | **PASS** | `P0-102 environment-kit evidence verification passed (8/8 plates)`; `/tmp/r540_checked/evidence.log` |

These passes do not override the focused runtime/map blockers. The evidence audit validates the eight existing forge, street/well, brewery, and checkpoint day/night plates; it does not prove ordinary-house tier coexistence in one gameplay capture or provide human visual sign-off.

## Acceptance boundary and classification

| P0-102 requirement | Current result | Classification |
|---|---|---|
| Four target spaces share a deterministic view-only environment-kit contract | **BLOCKED** | A clean snapshot reproduces the failure. The integration suite cannot complete its authored shell, dressing, clearance, anchor, route, patrol, fingerprint, or view-only assertions. This is a P0-102 acceptance blocker, not a dirty-worktree-only failure. |
| Stable map, route, patrol, and interaction contracts | **BLOCKED** | The first parser diagnostic prevents authored Lower Town maps from compiling. Invalid map definitions and missing buildings, props, anchors, transitions, and patrols are downstream diagnostics, not independent acceptance passes. |
| Collision/navigation and resident authored map-view contracts | **BLOCKED** | Core and mesh suites cannot complete cleanly while the authored map fails to parse. Their missing-node, frontage, terrain, and neighbor-preview assertions remain unaccepted. |
| Shared material families and deterministic weathering | **PARTIAL** | Material resolution is green at 7/7. Generic weathering checks pass, but Lower Town weathered-wall acceptance remains blocked by the parser cascade. |
| Authored decals and local wear | **BLOCKED** | The decals suite reports Lower Town wear failures and parser diagnostics. R-540 does not weaken or reclassify those assertions; rerun after the parser baseline is repaired. |
| Exceptional fortification boundary | **BLOCKED** | The fortification suite is not a valid clean acceptance pass while the same map/parser cascade and dependent view diagnostics remain present. |
| Asset lint and provenance | **PASS** | Both validators pass on the same clean snapshot; no asset or manifest blocker was reproduced. |
| Existing day/night environment evidence | **PASS for file integrity only** | The evidence verifier passes 8/8 plates. Gameplay-scale tier coexistence and human visual sign-off remain outside this report and unresolved. |

### Primary clean-baseline blocker: RRMap elevation command dispatch

The first repeated substantive diagnostic in the clean logs is:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

This is a reproducible clean-baseline/parser finding associated with the active elevation parser and acceptance work owned by R-453/R-455. R-540 does not edit that implementation. The subsequent `Invalid map definition` messages and missing map/view records are treated as cascade diagnostics until the parser dispatch is repaired and the matrix is rerun.

### Dirty-worktree versus clean-baseline distinction

The live worktree's unrelated edits were excluded by using `/tmp/rebel-reval-r540-20260817`. Because the same `unknown_command` diagnostics reproduce from clean `HEAD`, they are not caused by the dirty worktree and must remain visible as baseline blockers. Conversely, no dirty-only asset/provenance failure was promoted into this report: both asset validators pass on the clean snapshot. Existing unrelated dirty WIP remains untouched and is not absorbed into the R-540 report.

Shutdown-only ObjectDB/resource/RID leak messages in failed Godot processes are not the acceptance decision. The substantive parser, assertion, and engine/script diagnostics are the reason the affected suites returned non-zero.

## Decision and handoff

R-540 is complete as a blocked reproducibility note. The current clean snapshot is importable, asset-clean, provenance-clean, and has valid eight-plate evidence, but it does not reproduce a passing P0-102 focused runtime baseline. Keep P0-102 blocked and rerun the complete matrix after the elevation parser/acceptance path is repaired, then reassess any remaining independent shader, decal, map-view, and fortification findings from fresh clean logs.

No runtime, map, asset, test, or acceptance-threshold source was changed by R-540.

## Source evidence

- `/tmp/r540_checked/import.log`
- `/tmp/r540_checked/suite_status.tsv`
- `/tmp/r540_checked/r540-*.log`
- `/tmp/r540_checked/asset-lint.log`
- `/tmp/r540_checked/asset-provenance.log`
- `/tmp/r540_checked/evidence.log`
- `docs/reports/p0_102l_environment_kit_closeout.md`
- `R-453`, `R-455`, and `R-540`
