# P0-102n Exceptional Boundary Reconciliation

**Task:** R-383 / P0-102n
**Parent:** R-359 / P0-102g / P0-102
**Date:** 2026-08-02
**Snapshot:** `08577f501b0a40fbf026cc637e0c6f5e435013a3`
**Worktree:** current shared worktree with active R-353 / P0-102e renderer-boundary changes
**Status:** **RECONCILED - BLOCKED for acceptance**

## Scope and decision

This is a maintainer-facing evidence reconciliation for the ordinary-versus-exceptional renderer boundary after the current R-353 implementation and R-380 fixture repair work. It does not author landmark art, change map/runtime ownership, weaken assertions, or claim ordinary-house production handoffs.

The current boundary is structurally explicit:

- `MapViewMeshBuilderBuildings.build_building()` checks `MapViewMeshBuilderBuildingRegistry` before entering the ordinary building path.
- Recognized exceptional house records are handed to `build_exceptional_building()`, which sets `renderer_boundary=exceptional` and `exceptional_category` metadata.
- Ordinary house records retain `renderer_boundary=ordinary` and the shared roof/facade/chimney path.
- Viru Gate tower records are authored as `kind=wall`; the registry intentionally ignores non-house records so they remain on the fortification renderer rather than being converted into ordinary houses.

**Decision:** the implementation inventory and checkpoint preservation are reconciled, but this report does not mark P0-102 or R-359 ready. The current WIP still has reproducible St. Catherine regression diagnostics, the independent Karja Gate `GateDoor0` blocker, and an unrelated 17-path provenance baseline. Existing owners must resolve or explicitly accept those findings.

## 1. Exceptional inventory and routing

### 1.1 Registry inventory

The current `MapViewMeshBuilderBuildingRegistry` contains the following explicit boundary records:

| Inventory | Current entries | Routing evidence |
|---|---|---|
| Stable exceptional IDs | `town_hall_mass`, `church_silhouette`, `holy_spirit_hospital`, `guild_frontage`, `st_catherines_church`, `st_olaf_silhouette`, `cathedral_silhouette`, `viru_gate_north_tower`, `viru_gate_south_tower` | ID lookup returns the corresponding `civic`, `church`, `institutional`, `guild`, or `gatehouse` category. |
| Exceptional styles | `house.town_hall`, `house.church`, `house.cathedral`, `house.guild`, `house.gatehouse`, `house.hospital` | Style lookup is applied only to `kind=house` records. |
| Exceptional primitives | `town_hall_1343`, `holy_spirit_chapel_1343`, `stone_church`, `stone_hall`, `monastic_range`, `gatehouse` | Primitive lookup is applied only to `kind=house` records. |
| Viru Gate tower handoff | `viru_gate_north_tower`, `viru_gate_south_tower` | These records are `kind=wall` in `lower_town_slice.rrmap`; the registry returns no exceptional-house category for non-house records, so the fortification path owns their drums, roofs, wall-walk access, and tower state. |

The current source inventory confirms the following authored records:

- `market_civic_quarter.rrmap`: `town_hall_mass`, `church_silhouette`, `holy_spirit_hospital`, and `guild_frontage` use the registered exceptional styles.
- `monastery_quarter.rrmap`: `convent_chapel` and `st_olaf_silhouette` use church-style exceptional records.
- `toompea_quarter.rrmap`: `cathedral_silhouette` uses `house.cathedral`; hill-gate records use `house.gatehouse`.
- `reval_harbor_north.rrmap`: `great_coast_gate` and `great_coast_gate_east` use `house.gatehouse`.
- `lower_town_slice.rrmap`: `st_catherines_church` retains its stable house record ID, while both Viru Gate towers remain wall records.
- `world_padise.rrmap`, `world_paide.rrmap`, and `world_poide.rrmap` use exceptional primitive records such as `stone_hall` and `gatehouse` where the outdoor prototype renderer owns those records.

### 1.2 Boundary behavior

The current R-353 code path provides the required separation for known exceptional house records:

1. `MapViewMeshBuilder.build_building()` delegates registry-positive records to `build_exceptional_building()`.
2. The exceptional builder creates the landmark mass and category-specific dressing without the ordinary `Roof`, ordinary `Chimney`, or ordinary facade helper path.
3. Ordinary records continue through the shared house wall, roof, chimney, facade, historic-detail, and window-light helpers.
4. `test_exceptional_buildings_cross_landmark_boundary_without_house_kit` passes for the market/civic fixture and confirms both exceptional metadata and an ordinary-house control record.

This satisfies the architectural boundary in the P0-102 contract. It does not by itself prove that every historical landmark silhouette is production-complete; that remains P0-101 and the relevant landmark owners' work.

## 2. Viru Gate handoff

The Viru Gate source and tests preserve the approved 1343 boundary state:

- Stable tower IDs remain `viru_gate_north_tower` and `viru_gate_south_tower`.
- Both towers remain round `wall` records with `round_tower=true`, `tower=false`, and `wall_walk_axis=z`.
- The gate arch IDs remain `viru_gate_arch` and `viru_foregate_arch`.
- The source retains `gate_variant=ironbound` plus `grille_variant=portcullis` for the inner arch and a simpler oak gate for the incomplete outer works.
- The checkpoint integration fixture confirms the towers have a shared wall mass, no ordinary-house `Roof`, and remain separate from the gate-arch landmarks.
- `test_lower_town_slice_map` passes all 19 tests, including the Viru arch/collision-jamb span and required route checks.

The current implementation therefore does not route the Viru Gate towers through ordinary-house assembly. The fortification acceptance is not fully green because the same focused suite still reports the separate Karja Gate `GateDoor0` failure. That failure is not a Viru Gate handoff failure and remains with R-353 / P0-102e.

## 3. St. Catherine's handoff

`st_catherines_church` is a stable Lower Town building ID and is present in the registry as an exceptional `church` ID. The historical audit describes St. Catherine's as retaining a late-13th-century church/east-wing core while omitting later enlargement; the renderer boundary therefore correctly prevents it from being treated as an ordinary house.

The current WIP does not yet reconcile the old ordinary-house assertions with that boundary. The exact current failures are:

- `test_map_view_3d_mesh`: `st_catherines_church: every house keeps a chimney stack`, followed by the null `Chimney` lookup diagnostic at `tests/godot/test_map_view_3d_mesh.gd:375-376`.
- `test_map_view_3d_fortification`: the legacy `test_houses_get_facade_doors_and_windows` loop reports missing ordinary door, door hardware, windows, ridge board, and plinth nodes for `st_catherines_church`, because the record is now intentionally exceptional.

These are not grounds to route St. Catherine's back through the ordinary house kit. R-353 / P0-102e owns the boundary fixture and must either update the ordinary-house assertions to exclude registry-accepted exceptional records or add a dedicated exceptional assertion path, while preserving the church's stable ID and landmark review requirements. P0-101 / R-108 remains the owner of final church silhouette and gameplay-scale art acceptance.

## 4. Ordinary-module contract

The approved ordinary families remain separate from the boundary implementation:

| Family / contract | Current evidence | Decision |
|---|---|---|
| Shared ordinary renderer | Ordinary control record passes `renderer_boundary=ordinary` and retains `Roof`; the shared builder remains the common wall/roof/facade/chimney path. | **Preserved.** No bespoke camera, world-coordinate, or landmark exception was added by this audit. |
| Material and roof interfaces | `test_environment_kit_integration` passes its shared deterministic view contract; `test_burgher_house_typology_contract` passes all 3 tests for the closed `merchant_stone`, `merchant_timber`, and `craft_boda` allowlist and round-trip/rejection behavior. | **Preserved.** The typology contract is not production handoff evidence. |
| Collision/navigation ownership | Environment integration asserts view-only nodes and unchanged grid/map/transition/patrol snapshots. | **Preserved.** No collision or navigation node is authored by this report or the boundary registry. |
| Ordinary house tier assignment | `lower_town_slice.rrmap` currently has no `house_tier=` assignment and no `merchant_stone`, `merchant_timber`, or `craft_boda` tokens. | **Deferred.** P2-067 / R-213 owns Lower Town tier wiring after P2-063-P2-066. |
| Merchant/timber/boda assets | No completed production handoff is accepted here. | **Deferred.** P2-063-P2-065 and P0-101 remain separate owners. |
| Plot dressing and hoist/loading details | Not authored or claimed by this audit. | **Deferred.** P2-066 remains the owner. |

The shared camera, scale, material, collision, and occlusion interfaces therefore remain the correct contract for ordinary modules, but the current repository does not yet prove the final ordinary-tier assets or their playable-route visual acceptance.

## 5. Preserved IDs, openings, and routes

The following checkpoint and Lower Town interfaces were checked against the current source and focused tests:

- Anchors: `checkpoint_west`, `checkpoint_east`, `street_start`, `smithy_door`, and `brewery_door` remain present.
- Transitions: `viru_road_boundary` and the existing smithy transition remain present and retain arrival-clearance checks.
- Patrols: `viru_watch` and `iron_convoy` remain present, with authored patrol points inside map bounds.
- Gate landmarks: `viru_gate_arch` and `viru_foregate_arch` remain separate view landmarks.
- Stable buildings: `viru_gate_north_tower`, `viru_gate_south_tower`, and `st_catherines_church` retain their IDs.
- Required through-route: `test_lower_town_slice_map` passes `test_lower_town_required_route_endpoints_reachable`, `test_city_wall_blocks_except_viru_gate`, `test_viru_gate_arch_matches_collision_jamb_span`, and the remaining 16 map-contract methods.
- Environment-kit integration: `test_environment_kit_integration` passes 5/5, including the checkpoint exceptional-context test and the view-only fingerprint/route/anchor checks.

No source or runtime route record was changed by this reconciliation.

## 6. Verification matrix

| Check | Result | Exact evidence |
|---|---|---|
| Environment-kit boundary and route contract | **PASS** | `test_environment_kit_integration`: 5/5 tests, 0 failures, 0 errors. |
| Lower Town IDs, route openings, Viru collision span, parity | **PASS** | `test_lower_town_slice_map`: 19/19 tests, 0 failures, 0 errors. |
| Exceptional/ordinary mesh boundary | **PARTIAL** | `test_map_view_3d_mesh`: 19 tests, 1 failure, 2 engine/script errors. Boundary-specific test passes; St. Catherine chimney assertion fails. |
| Fortification and landmark regression | **BLOCKED** | `test_map_view_3d_fortification`: 8 tests, 11 failures, 4 errors. St. Catherine legacy ordinary-house assertions fail; Karja `GateDoor0` is missing and causes the null `material_override` diagnostic at `tests/godot/test_map_view_3d_fortification.gd:137`. |
| Ordinary house typology contract | **PASS** | `test_burgher_house_typology_contract`: 3/3 tests, 0 failures, 0 errors. This proves the closed allowlist only, not production assets or Lower Town wiring. |
| Asset lint | **PASS** | `python3 tools/verify_asset_lint.py`: asset lint passed, including 8 style-lock textures, 8 character GLBs, 26 tier-classified character GLBs, and 0 portraits. |
| Asset provenance | **BLOCKED - unrelated active owners** | `python3 tools/validate_asset_sources.py` reports 17 missing inventory/active-runtime paths: 3 horse sidecars from A-002/R-1, 8 Viru Gate generated albedo paths, and 6 supply-cart generated albedo paths. |

The raw focused commands were run from the repository root with Godot 4.7.1:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_burgher_house_typology_contract
python3 tools/verify_asset_lint.py
python3 tools/validate_asset_sources.py
```

The first, second, fifth, and lint commands completed successfully. The mesh, fortification, and provenance commands reproduced the failures recorded above. Godot shutdown ObjectDB/resource/RID leak diagnostics were also emitted by the headless renderer; they are the existing shutdown noise and are not used as acceptance failures here unless accompanied by the explicit test failures above.

## 7. Ownership and next actions

No new follow-up task is required because every remaining finding maps to an existing owner:

1. **R-353 / P0-102e, currently in progress:** reconcile St. Catherine's exceptional record with ordinary-house regression loops without weakening the boundary; repair the Karja Gate `GateDoor0` contract and rerun the focused fortification suite.
2. **R-380 / P0-102e fixture repair, currently in review:** consume this reconciliation when reviewing the boundary fixture and keep exceptional records out of ordinary-house assertions.
3. **R-1 / A-002:** register or otherwise resolve the 3 medieval horse sidecar paths in the provenance manifest.
4. **P2-068 / cart asset owners:** register or explicitly exclude the 6 supply-cart albedo paths.
5. **A-003 / Viru Gate asset owner:** register or explicitly exclude the 8 Viru Gate albedo paths.
6. **P2-063-P2-067 and P0-101:** complete the ordinary house families, plot dressing, Lower Town tier wiring, exceptional landmark art, and final gameplay-scale acceptance before claiming the broader P0-102 deliverable.

**Final decision:** **BLOCKED for acceptance, but boundary reconciliation complete.** The current code proves the intended ordinary-versus-exceptional routing and preserves Viru Gate/Lower Town route interfaces. It is not acceptable to close R-383 as evidence that the parent P0-102 is ready while the named R-353/St. Catherine/Karja and provenance findings remain open.

## R-397 clean recheck addendum (2026-08-02)

A fresh detached worktree at `/tmp/rebel-reval-r397-20260802` from `HEAD=94ea0de5980af5b66c68c2b4ca051c228484c840` was imported with Godot 4.7.1 before the focused test. The live shared worktree was excluded from acceptance because it contains unrelated WIP.

`tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260802 --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification` returned status 1. Saved log: `/tmp/r397_checked/p0-102-r397-boundary.log`.

The clean result is **8 test methods, 2 failures, and 6 engine/script errors**. The pre-existing exceptional landmark blocker remains: `Landmark_karja_gate_arch/GateDoor0` is absent and the null `material_override` access follows at `tests/godot/test_map_view_3d_fortification.gd:137`. A second independent baseline blocker is `MAP_ID_DUPLICATE` for `outer_wall_road` at `content/maps/monastery_quarter.rrmap:162`, which prevents the north neighbor preview from being built and causes the `Surroundings/Neighbor_north/Buildings` assertion to fail. R-413 owns that map-source defect. The other six fortification methods pass, including the ordinary-house regression and wall-walk checks.

This recheck changed documentation only. It does not weaken boundary assertions or route either landmark through the ordinary-house renderer. Keep the boundary acceptance **BLOCKED** until R-353 resolves `GateDoor0` and R-413 resolves the monastery stable-ID collision.

## R-397 current-HEAD recheck addendum (2026-08-29)

A fresh detached checkout at `/tmp/rebel-reval-r397-20260829` from `HEAD=d2bb1d24da4fe00d2efa6b0c92d4f846e9cbf814` (`Add static harbour prototype contract verifier`) was used for this recheck. The live worktree was not used because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully with status 0.

Exact verification command:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r397_checked_20260829
/tmp/rebel-reval-r397-20260829/tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260829 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
```

Result: **BLOCKED**. The checked command returned exit status 1. The saved log `/tmp/r397_checked_20260829/p0-102-r397-boundary.log` reports 8 tests, 6 failures, and 45 engine/script errors.

- The first repeated diagnostics are `unknown command 'elevation_area'` and `unknown command 'elevation_ramp'` while loading the authored elevation statements in `lower_town_slice.rrmap` and related map definitions. The resulting invalid definitions produce dependent missing-fixture, null-builder, and assertion diagnostics, including `MapViewMeshBuilder` dictionary access and null `has_node` calls.
- The prior R-353 `GateDoor0` and R-413 `outer_wall_road` findings were not emitted before the elevation/parser cascade interrupted the suite. Board records show R-353 and R-413 as `done`, but this run does not independently certify either owner; a clean rerun is required after R-453/R-455 land the elevation parser/authoring handoff.
- No runtime, map, landmark, test, or asset source was changed by R-397. The exceptional renderer boundary remains **not accepted** because the required focused suite did not complete cleanly.

The current ownership boundary is therefore R-453/R-455 for the clean-HEAD elevation/parser blocker, followed by a fresh `test_map_view_3d_fortification` run to verify the exceptional renderer contract itself.

## R-397 latest clean-HEAD recheck addendum (2026-09-01)

A fresh detached checkout at `/tmp/rebel-reval-r397-20260901` from `HEAD=15634e77559e1c5a1af3de9233baea56989a0abc` (`test: cover Harju blocked activation contract`) was used for the latest recheck. The live worktree was not used because it contains unrelated modified and untracked WIP. Godot 4.7.1 editor import completed successfully with status 0 before the focused run.

Exact verification command:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/r397_checked_20260901
/tmp/rebel-reval-r397-20260901/tools/run_godot_checked.sh --require-test-summary p0-102-r397-boundary -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r397-20260901 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
```

Result: **BLOCKED**. The checked command returned exit status 1. The saved log `/tmp/r397_checked_20260901/p0-102-r397-boundary.log` reports 8 test methods, 6 failures, and 45 engine/script errors.

- The first repeated diagnostics are `unknown command 'elevation_area'` and `unknown command 'elevation_ramp'` while loading authored elevation statements, including `lower_town_slice.rrmap` lines 14, 17, 20, and 22 and related statements in `south_quarter.rrmap`. The clean snapshot's parser dispatch still does not register these commands, so invalid map definitions and dependent missing-fixture, null-builder, and assertion diagnostics prevent a clean exceptional-boundary result.
- The earlier R-353 `GateDoor0` and R-413 `outer_wall_road` findings were not reached or emitted in this run. They must not be reported as the current root cause. A fresh fortification rerun is required after the active R-453/R-455 elevation parser/authoring handoff lands.
- No runtime, map, landmark, test, or asset source was changed by R-397. The exceptional renderer boundary remains **not accepted** because the required focused suite did not complete cleanly.

The current ownership boundary is R-453/R-455 for the clean-HEAD elevation/parser blocker, followed by a fresh `test_map_view_3d_fortification` run to verify the exceptional renderer contract itself.
