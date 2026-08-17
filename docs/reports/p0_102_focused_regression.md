# P0-102 Focused Environment-Kit Regression

**Task:** R-555 / P0-102 focused regression
**Date:** 2026-08-17
**Snapshot:** `266b3eeaba87c1f49b17059105f4c8261c3f7d68` (`Record scoped runtime commit lesson`)
**Verification worktree:** `/tmp/rebel-reval-r555-20260817` (detached, created from the snapshot)
**Decision:** **BLOCKED / PARTIAL - do not accept or close P0-102**

## Scope and method

This was a bounded evidence-only regression run for the shared P0-102 environment kit. It exercised the four target spaces (forge, street/well, brewery, and checkpoint), their shared view-only assembly, authored map/route/patrol identity, collision/navigation-facing map-view contracts, deterministic materials, weathering, decals, core 3D rendering, mesh construction, and the exceptional fortification boundary.

The live project worktree was not used for acceptance. It contains unrelated modified and untracked WIP across RRMap editor/runtime files, maps, assets, history, tests, and generated imports. The detached verification worktree had no tracked diff at the start of the run. Godot editor import generated only these temporary untracked UID sidecars in that worktree:

- `tests/godot/test_r454_elevation_scope.gd.uid`
- `tests/godot/test_r503_elevation_gameplay_invariants.gd.uid`
- `tests/godot/test_saaremaa_map.gd.uid`

No runtime, map, asset, shader, test, or provenance source was changed by R-555.

Godot 4.7.1 (`a13da4feb`) editor import completed with `IMPORT_STATUS=0`. Each focused suite ran in its own Godot process through the checked runner. Retained logs are under `/tmp/r555_checked/`.

## Exact verification commands

The commands below reproduce the bounded run from the repository root. The snapshot hash is pinned so unrelated live-worktree changes cannot enter the evidence.

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export WT=/tmp/rebel-reval-r555-20260817
export LOG_DIR=/tmp/r555_checked

# Detached snapshot and Godot import
# Snapshot: 266b3eeaba87c1f49b17059105f4c8261c3f7d68
git worktree add --detach "$WT" 266b3eeaba87c1f49b17059105f4c8261c3f7d68
"$GODOT_BIN" --headless --editor --import --path "$WT"
# Result: IMPORT_STATUS=0

mkdir -p "$LOG_DIR"
export GODOT_LOG_DIR="$LOG_DIR"

for filter in \
  test_environment_kit_integration \
  test_building_surface_weathering \
  test_map_view_3d_core \
  test_map_view_3d_mesh \
  test_map_view_material_resolution \
  test_map_view_decals \
  test_map_view_3d_fortification; do
  tools/run_godot_checked.sh --require-test-summary "r555-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done
```

The exact Godot invocations recorded by the checked runner use the form:

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp/rebel-reval-r555-20260817 --script tools/run_godot_tests.gd -- --filter=<suite>
```

## Focused-suite results

| Suite | Test methods | Failures | Engine/script errors | Result | Retained log |
|---|---:|---:|---:|---|---|
| `test_environment_kit_integration` | 5 | 26 | 27 | **BLOCKED** | `/tmp/r555_checked/r555-environment_kit_integration.runner.log` |
| `test_building_surface_weathering` | 6 | 1 | 4 | **BLOCKED** | `/tmp/r555_checked/r555-building_surface_weathering.runner.log` |
| `test_map_view_3d_core` | 20 | 9 | 46 | **BLOCKED** | `/tmp/r555_checked/r555-map_view_3d_core.runner.log` |
| `test_map_view_3d_mesh` | 19 | 9 | 46 | **BLOCKED** | `/tmp/r555_checked/r555-map_view_3d_mesh.runner.log` |
| `test_map_view_material_resolution` | 7 | 0 | 0 | **PASS** | `/tmp/r555_checked/r555-map_view_material_resolution.runner.log` |
| `test_map_view_decals` | 8 | 5 | 6 | **BLOCKED** | `/tmp/r555_checked/r555-map_view_decals.runner.log` |
| `test_map_view_3d_fortification` | 8 | 6 | 46 | **BLOCKED** | `/tmp/r555_checked/r555-map_view_3d_fortification.runner.log` |
| **Total** | **73** | **56** | **175** | **BLOCKED** | `/tmp/r555_checked/` |

The material-resolution suite is the only fully green suite: all seven deterministic material tests passed. The weathering suite's generic surface-family and deterministic-variant methods passed, but its Lower Town assembly method was interrupted by the map parser failure and then failed its authored-wall-texture assertion.

## Acceptance boundary

| P0-102 contract | Current result | Evidence and classification |
|---|---|---|
| Four target spaces share one deterministic view-only environment-kit contract | **NOT ACCEPTED** | `test_environment_kit_integration` returned 26 failures and 27 errors. The run did not cleanly confirm authored shells, dressing, clearance, anchors, stable map fingerprints, or view-only assembly for forge, street/well, brewery, and checkpoint. Representative failures include missing brewery shell/dressing, missing forge/street-well families, missing checkpoint geometry, and missing route/interaction/patrol records. |
| Stable map, route, patrol, and interaction fingerprints | **BLOCKED** | The first parser failure prevents several authored maps from compiling. Follow-on failures report invalid map definitions and missing anchors, transitions, patrols, buildings, and props. These are not valid fingerprint acceptance evidence until the parser baseline is repaired. |
| Collision/navigation and resident authored map-view contracts | **BLOCKED** | `test_map_view_3d_core` and `test_map_view_3d_mesh` both fail before clean completion. The logs include missing route anchor `smithy_door`, missing terrain/ground nodes, frontage residency failures, and missing neighbor previews. No collision/navigation contract is declared green from this run. |
| Deterministic material resolution | **PASS** | `test_map_view_material_resolution`: 7/7, 0 failures, 0 errors. |
| Building weathering and shared surface families | **PARTIAL** | Five weathering methods pass. The Lower Town method reports 1 assertion failure and 4 parser diagnostics, so Lower Town wall-texture acceptance remains blocked. |
| Authored decals and local wear | **BLOCKED** | The generic placement test fails `Decal Y must clear ground lift`. The suite also reports an independent water shader tokenizer failure and Lower Town wear assertions for threshold/yard, soot, mud, and wet wear. The Lower Town-specific availability failures are not separated from the parser cascade by this run. |
| Core 3D terrain and mesh construction | **BLOCKED** | The core and mesh suites report parser cascades plus separate assertions for terrain, river smoothing, smoke variation, puddles, transition-door geometry, and exceptional-building boundaries. They cannot be accepted as clean regressions. |
| Exceptional fortification boundary | **BLOCKED** | `test_map_view_3d_fortification` reports missing Viru Gate arch context, wall-walk connectivity/count failures, and the missing west neighbor preview. This run does not repair or accept the fortification boundary. |

## Diagnostic classification

### Primary clean-baseline blocker: RRMap elevation command dispatch

The first repeated substantive diagnostic is:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

The same parser-dispatch gap also appears for authored elevation commands in `south_quarter.rrmap` and `market_civic_quarter.rrmap`. The resulting `Invalid map definition` messages and missing map fields/nodes are downstream failures. The owning elevation work remains **R-453** and **R-455**, both still `in_progress`. R-555 does not edit their parser or map-authoring implementation.

### Separate findings retained without reclassification

The report does not collapse every failure into the elevation cascade. The following findings remain separately recorded and are not claimed fixed by this evidence-only run:

- **Water shader:** `SHADER ERROR: Tokenizer: Unknown character #35: '#'` at inline shader line 131, followed by `Shader compilation failed` through `map_view_water_materials.gd:42`. This independently interrupts decal, mesh, and fortification setup paths.
- **Generic decal placement:** `test_decals_placed_from_map_data` fails `Decal Y must clear ground lift`.
- **Neighbor previews:** map-view tests report missing `Surroundings/Neighbor_west` and `Surroundings/Neighbor_west/Buildings`, followed by null child access and `west edge needs a neighbor preview`.
- **Fortification assertions:** Viru Gate arch context is absent in the fixture, and the workers-district wall walk reports zero/incorrect round-tower connectivity. These findings remain unaccepted; R-555 makes no ownership or implementation claim for them.
- **Mesh/view assertions:** smoke variation, puddle preparation, transition-door framing, terrain node presence, and exceptional-building boundary assertions remain red in the retained logs. Their final ownership must be resolved after the parser and independent shader/fixture blockers are rerun in a clean baseline.

### Shutdown-only diagnostics

Failed Godot processes also emit ObjectDB/resource/RID leak messages while shutting down, for example `ObjectDB instances were leaked`, `resources still in use`, and dummy-renderer RID allocations. These are the documented DEF-002 shutdown diagnostics and are not the acceptance decision. The blocking result comes from the substantive parser, shader, script, and assertion failures above. The checked runner correctly returned non-zero for every suite with substantive failures.

## Decision and handoff

R-555 is complete as a blocked regression report only. The run confirms that the current clean snapshot is importable and that deterministic material resolution is green, but it does not confirm the four-space environment-kit contract, stable map/route/patrol fingerprints, collision/navigation assertions, or the full 3D environment regression.

Keep P0-102 blocked and rerun the complete matrix after:

1. **R-453 / R-455** register and validate `elevation_area` and `elevation_ramp` in the RRMap parser/acceptance path.
2. The independent `water_surface` shader tokenizer failure and generic decal ground-lift failure have an owning fix and focused rerun.
3. Neighbor-preview, fortification, terrain, mesh, and transition-door findings are assigned to their owning work and rerun from a clean snapshot.

No test was weakened and no runtime, map, asset, shader, or test source was changed by this report.

## Source evidence

- `/tmp/r555_checked/import.log`
- `/tmp/r555_checked/*.runner.log`
- `docs/reports/p0_102_final_verification.md`
- `docs/reports/p0_102l_environment_kit_closeout.md`
- `R-453`, `R-455`, and `R-555`
