# P0-102 Asset and Visual Acceptance Evidence Audit

**Task:** R-557 / P0-102
**Date:** 2026-08-17
**Snapshot:** `a40d4f86d6508ff5379bbd93d09808568e21532e` (`HEAD`)
**Godot:** 4.7.1.stable.official (`a13da4feb`)
**Decision:** **BLOCKED / PARTIAL - do not close P0-102**

## Scope and method

This is an evidence-only audit of the P0-102 environment-kit acceptance boundary. It covers the four required spaces - forge, street/well, brewery, and checkpoint - and checks the dedicated day/night plates, asset provenance, asset lint, authored view-only wear, shared module integration, material/weathering behavior, map-view mesh construction, fortification separation, and Lower Town collision/navigation-facing contracts.

The live project worktree already contained unrelated staged, modified, and untracked WIP before this audit. The audit did not modify runtime code, maps, imported assets, shaders, tests, or binary evidence plates. Results below are from the current `HEAD` plus the existing worktree state used for the bounded verification; the pre-existing worktree state is not a clean acceptance snapshot.

Godot focused suites were run separately through `tools/run_godot_checked.sh --require-test-summary`. The expected ObjectDB/resource/RID shutdown diagnostics were present in some logs and are not the decision blocker. The decal suite returned non-zero because one assertion failed.

## Exact verification commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r557
mkdir -p "$GODOT_LOG_DIR"

python3 tools/verify_p0_102_environment_kit_evidence.py
python3 tools/verify_asset_lint.py
python3 tools/validate_asset_sources.py

# Each command was run in a separate Godot process.
tools/run_godot_checked.sh --require-test-summary r557-environment-kit -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_environment_kit_integration

tools/run_godot_checked.sh --require-test-summary r557-weathering -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_building_surface_weathering

tools/run_godot_checked.sh --require-test-summary r557-core -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_core

tools/run_godot_checked.sh --require-test-summary r557-mesh -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_mesh

tools/run_godot_checked.sh --require-test-summary r557-materials -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_material_resolution

tools/run_godot_checked.sh --require-test-summary r557-decal -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_decals

tools/run_godot_checked.sh --require-test-summary r557-fortification -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_fortification

tools/run_godot_checked.sh --require-test-summary r557-lower-town -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice
```

Retained logs: `/tmp/rebel-reval-r557/r557-*.log`.

## Acceptance matrix

| Gate | Result | Evidence |
|---|---|---|
| Dedicated P0-102 day/night evidence | **PASS** | `verify_p0_102_environment_kit_evidence.py`: 8/8 plates. All files decode as 1280x720 RGB PNGs, are non-flat, differ between day/night, use matching framing metadata, and are linked once in `p0_102_environment_kit_acceptance.md`. |
| Asset lint | **PASS** | `verify_asset_lint.py`: 8 style-lock textures, 9 character GLBs, 29 tier-classified character GLBs, and 0 portraits checked. |
| Asset provenance | **PASS** | `validate_asset_sources.py`: schema valid; 1,155 manifest rows; 999 inventory paths covered; 993 active runtime assets covered. |
| Pivot and shared scale contract | **PASS** | `test_environment_kit_integration` verifies every target space keeps `MapTypes.DEFAULT_CELL_SIZE`, maps building/prop logic positions through `MapViewBridge.logic_to_world()`, and preserves the shared cell-to-metre pivot convention. |
| Shared environment-kit integration | **PASS** | `test_environment_kit_integration`: 5/5. Four target spaces, shared view-only assembly, clearance, authored routes/anchors, local wear, deterministic fingerprints, and exceptional checkpoint boundary pass. |
| Weathering and shared surfaces | **PASS** | `test_building_surface_weathering`: 6/6. Distinct wall/roof families, deterministic per-building weathering, and Lower Town weathered materials pass. |
| Map-view core contracts | **PASS** | `test_map_view_3d_core`: 20/20. Terrain/elevation, actor sync, route-facing residency, rolling ground, water, occlusion, and view-only behavior pass. |
| Mesh construction | **PASS** | `test_map_view_3d_mesh`: 19/19. Shared house/roof geometry, props, interiors, doors, vegetation, exceptional-building boundary, and terrain detail pass. |
| Material resolution | **PASS** | `test_map_view_material_resolution`: 7/7. Authored stone, cobble, ground, rock, and timber-floor material contracts pass. |
| Fortification boundary | **PASS** | `test_map_view_3d_fortification`: 8/8. Gate/wall/round-tower geometry, wall walks, neighbor previews, and ordinary-versus-exceptional boundary pass. |
| Lower Town slice | **PASS** | `test_lower_town_slice`: 19/19. Map validation/parity, route endpoints, water navigation exclusion, prop/dressing contracts, decal gameplay fingerprint invariance, and Viru Gate seam pass. |
| Authored decal placement on sampled ground | **BLOCKED** | `test_map_view_decals`: 7/8. `test_decals_placed_from_map_data` fails `Decal Y must clear ground lift`; the other seven methods pass. Follow-up **R-571** owns the ground-clearance contract and rerun. |

The green focused matrix contains **91 passing methods**. One of the 92 audited methods is red, so the P0-102 acceptance gate remains blocked.

## Visual evidence set

The dedicated evidence directory is `docs/reports/images/p0_102_environment_kit/`:

| Space | Day plate | Night plate | Map identity |
|---|---|---|---|
| Forge | [`forge_day.png`](images/p0_102_environment_kit/forge_day.png) | [`forge_night.png`](images/p0_102_environment_kit/forge_night.png) | `kalev_smithy` |
| Street/well | [`street_well_day.png`](images/p0_102_environment_kit/street_well_day.png) | [`street_well_night.png`](images/p0_102_environment_kit/street_well_night.png) | `lower_town_slice` |
| Brewery | [`brewery_day.png`](images/p0_102_environment_kit/brewery_day.png) | [`brewery_night.png`](images/p0_102_environment_kit/brewery_night.png) | `lower_town_slice` |
| Checkpoint | [`checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png) | [`checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png) | `lower_town_slice` |

The source acceptance report records `MapView3D.TIME_DAY` / `MapView3D.TIME_NIGHT`, orthographic size, focus logic cell, and focus height for each pair. The set preserves the required routes, doors, player approach areas, and interactables: forge furnace/anvil and courtyard door; street/well cistern, wash tub, wet threshold, and `street_start`; brewery door, kegs, malt sacks, barrels, and approach lane; checkpoint gate arch, both towers, cart, foregate arch, and approach lane.

These are evidence-only camera captures. They do not replace P0-101 human visual sign-off, ordinary-house tier acceptance, or final gameplay-scale art review owned by P0-101 and P2-063 through P2-067.

## Decal blocker classification

The exact failing log is `/tmp/rebel-reval-r557/r557-decal.log`:

```text
RUN res://tests/godot/test_map_view_decals.gd (8 test(s))
...
FAIL res://tests/godot/test_map_view_decals.gd::test_decals_placed_from_map_data - Decal Y must clear ground lift
...
Godot headless tests: 1 file(s), 8 test(s), 1 failure(s), 0 error(s).
```

This is a substantive project assertion, not a runner or shutdown-only failure. `scripts/map/view3d/map_view_decals.gd` samples `MapViewMeshBuilder.ground_height()` and places the quad at `ground_y + GROUND_LIFT`. The `decal_test` fixture samples a negative rolling-ground height at the authored soot position `(16,16)`, so its final Y is below the test's minimum `GROUND_LIFT` threshold. The correct fix must preserve sampled terrain relief and the view-only/gameplay-fingerprint contract; weakening the assertion or removing terrain sampling would invalidate the acceptance boundary.

Follow-up **R-571 / P0-102: fix decal ground clearance on rolling terrain** is created as a P1 task. It must define the intended clearance contract, implement the narrow runtime/test correction, rerun `test_map_view_decals`, and then rerun this acceptance matrix from a clean snapshot.

## Scope boundaries and decision

The following remain outside this audit's acceptance claim:

- P0-101 human visual sign-off and final gameplay-scale review.
- P2-063 through P2-067 ordinary-house GLBs, plot dressing, and tier handoff evidence.
- Any unrelated staged or untracked work already present in the live worktree.

**Final decision:** the asset/provenance gates, eight visual plates, shared module integration, collision/navigation-facing map contracts, material/weathering, core/mesh, Lower Town, and fortification checks are currently green. The generic decal ground-clearance assertion is independently reproducible and blocks a clean P0-102 acceptance. Keep R-557 as a blocked evidence audit and do not close P0-102 until R-571 is fixed and the focused matrix is rerun.
