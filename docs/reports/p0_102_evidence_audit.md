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

## R-571 decal ground-clearance closeout

The focused correction was implemented on 2026-08-18. Decals now use the sampled `MapViewMeshBuilder.ground_height()` value and apply a view-only floor at `0.0` before adding `GROUND_LIFT` (`0.015`). This keeps positive rolling relief intact while preventing a negative relief sample from placing the transparent quad below the shared visual ground datum. Terrain meshes, `MapTerrainGrid`, collision/navigation data, and gameplay fingerprints are unchanged.

The focused rerun passed:

```text
/tmp/rebel-reval-r571-fixed2
Godot headless tests: 1 file(s), 8 test(s), 0 failure(s), 0 error(s).
```

The complete P0-102 acceptance matrix was rerun in the current shared worktree under `/tmp/rebel-reval-r571-matrix`. Evidence verification passed 8/8 plates, asset lint and provenance passed, and all eight Godot suites passed: environment integration 5/5, weathering 6/6, map-view core 20/20, mesh 19/19, material resolution 7/7, decals 8/8, fortification 8/8, and Lower Town 19/19. Expected shutdown ObjectDB/resource leak diagnostics remain non-blocking. This closes the independently owned R-571 decal blocker; the broader P0-102 and P0-101 acceptance boundaries remain subject to their existing scope and review gates.

## Scope boundaries and decision

The following remain outside this audit's acceptance claim:

- P0-101 human visual sign-off and final gameplay-scale review.
- P2-063 through P2-067 ordinary-house GLBs, plot dressing, and tier handoff evidence.
- Any unrelated staged or untracked work already present in the live worktree.

**Original audit decision (2026-08-17):** the asset/provenance gates, eight visual plates, shared module integration, collision/navigation-facing map contracts, material/weathering, core/mesh, Lower Town, and fortification checks were green, while the generic decal ground-clearance assertion independently blocked the clean P0-102 acceptance. The R-571 addendum above records the subsequent fix and green rerun; it does not close the broader P0-102 or P0-101 scope.

## Current clean-snapshot recheck (2026-08-30)

This addendum refreshes the audit against the current repository revision after the earlier R-571 decal correction. It does not replace the historical results above or claim the broader P0-102 parent closeout.

**Snapshot:** `4f4f74f91a152152bfc37a56e97e38c2fab99807` (`HEAD`)
**Clean workspace:** detached checkout `/tmp/rebel-reval-r557-20260830`
**Live workspace:** shared worktree with unrelated staged, modified, and untracked WIP; not used as a clean acceptance result
**Godot:** 4.7.1.stable.official (`a13da4feb`)
**Decision:** **BLOCKED / PARTIAL - retain R-557 in review**

### Evidence and asset checks

The current tracked evidence packet and repository-wide checks were run independently in the clean detached checkout:

| Check | Result | Boundary |
|---|---|---|
| `verify_p0_102_environment_kit_evidence.py` | **PASS - 8/8** | All forge, street/well, brewery, and checkpoint day/night plates are present and valid. This proves packet integrity, not human visual sign-off. |
| `verify_asset_lint.py` | **PASS** | 8 style-lock textures, 13 character GLBs, 41 tier-classified character GLBs, and 0 portraits checked. |
| `validate_asset_sources.py` | **BLOCKED** | Ten active plot-dressing albedo paths are missing from `assets/SOURCES.csv`: the Iron, Oak, Rope, Shingle, Stone, StoneDark, Thatch, Timber, Wattle, and WoodLight sidecars. This is the existing R-212/R-641 provenance handoff, not an R-557 asset change. |
| Godot editor import | **PASS - process status 0** | Import completed on the clean snapshot. The focused checked suites below still expose parser and authored-contract failures. |

The live dirty worktree reports provenance PASS because its modified `assets/SOURCES.csv` contains active WIP rows. That result is not promoted into the clean acceptance decision.

### Focused clean Godot suites

Each suite was run in a separate process through `tools/run_godot_checked.sh --require-test-summary`, after importing the detached checkout. The exact logs are retained under `/tmp/rebel-reval-r557-clean-20260830/`.

| Suite | Result | Classification |
|---|---:|---|
| `test_environment_kit_integration` | 5 tests, 26 failures, 34 errors | **BLOCKED** by the clean RRMap parser cascade and missing authored map records. |
| `test_building_surface_weathering` | 6 tests, 1 failure, 4 errors | **BLOCKED**; the Lower Town map cannot expose the expected authored wall variants in this snapshot. |
| `test_map_view_3d_core` | 20 tests, 9 failures, 44 errors | **BLOCKED** by the same map/parser cascade and dependent residency assertions. |
| `test_map_view_3d_mesh` | 19 tests, 9 failures, 44 errors | **BLOCKED** by the same map/parser cascade and dependent geometry assertions. |
| `test_map_view_material_resolution` | 7/7 pass | **PASS** for the isolated authored material-resolution contract. |
| `test_map_view_decals` | 8 tests, 4 failures, 4 errors | **BLOCKED** by missing Lower Town authored decal records in the clean snapshot; `test_decals_placed_from_map_data` itself passes after R-571. |
| `test_map_view_3d_fortification` | 8 tests, 6 failures, 45 errors | **BLOCKED** by the same parser cascade and dependent landmark/wall-walk assertions. |
| `test_burgher_house_tiers` | 5 tests, 92 failures, 12 errors | **BLOCKED**; the clean snapshot lacks the authored house records expected by the current tier contract. |
| `test_lower_town_slice_map` | 19 tests, 26 failures, 93 errors | **BLOCKED** by the parser cascade and clean-snapshot authored map gap. |

The first recurring substantive diagnostics are:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
```

The original attempted `test_lower_town_slice` filter was not a valid current test filename. The clean rerun used the discovered current file filter `test_lower_town_slice_map`, so the 19-test result above is the authoritative map-contract result for this recheck.

### Visual acceptance boundary and ownership

The eight environment-kit plates remain valid packet evidence. The separate three-tier gameplay packet also exists under `docs/reports/images/p0_102_three_tier/`, but its manifest explicitly limits the claim to matched file/camera/metadata integrity and leaves gameplay-scale material readability and human historical/art review open. Neither packet is promoted to visual sign-off by this audit.

The clean recheck leaves the following ownership boundaries unchanged:

- **R-453 / R-455:** repair and accept `elevation_area` / `elevation_ramp` RRMap dispatch and rerun the focused runtime matrix from clean `HEAD`.
- **R-209 / R-210 / R-211 / R-212:** complete authored ordinary-house and plot-dressing production handoffs; R-210's prior delivery does not waive synchronized clean acceptance.
- **R-641:** reconcile the ten missing plot-dressing provenance rows after the owning asset bundle lands.
- **R-612 / R-613 / R-638 / R-108:** complete gameplay-scale ordinary/exceptional visual review and named human art/canon sign-off.
- **R-557:** retain this evidence audit in review; do not advance R-110/P0-102 from this mixed historical/current evidence set.

**Current conclusion:** packet integrity, asset lint, and isolated material resolution pass. Clean runtime integration, Lower Town/tier contracts, provenance, and human visual acceptance remain blocked. No new follow-up task was created because every current blocker is already assigned to an existing board owner.

### Reproduction commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export WT=/tmp/rebel-reval-r557-20260830
export GODOT_LOG_DIR=/tmp/rebel-reval-r557-clean-20260830

git worktree add --detach "$WT" 4f4f74f91a152152bfc37a56e97e38c2fab99807
"$GODOT_BIN" --headless --editor --import --path "$WT" --quit

python3 "$WT/tools/verify_p0_102_environment_kit_evidence.py"
python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"  # expected blocked by R-212/R-641 rows

# Run each filter in a separate checked process from "$WT":
# test_environment_kit_integration
# test_building_surface_weathering
# test_map_view_3d_core
# test_map_view_3d_mesh
# test_map_view_material_resolution
# test_map_view_decals
# test_map_view_3d_fortification
# test_burgher_house_tiers
# test_lower_town_slice_map
```

The detached checkout is temporary verification state and is not part of the commit.
