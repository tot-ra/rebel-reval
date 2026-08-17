# P0-102g Environment Kit Acceptance

**Task:** R-359 / P0-102g
**Parent:** R-110 / P0-102
**Date:** 2026-08-01
**Status:** **PARTIAL - parent P0-102 is not ready for review**

## Scope and decision

This acceptance covers the four P0-102 target spaces: forge, street/well, brewery, and checkpoint. It evaluates the shared view-only assemblies and existing contracts; it does not author new art, runtime behavior, ordinary house-tier assets, or landmark art. P0-101 and P2-063-P2-067 remain separate ownership boundaries.

The implementation is accepted for the checks that pass below, but the parent task is not accepted as complete. The remaining findings are either an open prerequisite (`R-353`), an existing repository baseline defect, or the newly opened scoped follow-up `R-360`. The dedicated eight-plate evidence requirement is complete; this does not constitute the separate P0-101 human visual sign-off.

## R-543 day/night reconciliation (2026-08-17)

The dedicated four-space environment-kit packet has been reconciled in [`p0_102m_environment_kit_day_night.md`](p0_102m_environment_kit_day_night.md). The scoped verifier passes 8/8 matched forge, street/well, brewery, and checkpoint plates. The addendum keeps the parent acceptance **BLOCKED / PARTIAL** because the separate P0-101 gameplay-camera proof for `merchant_stone`, `merchant_timber`, and `craft_boda`, exceptional-landmark review, and clean runtime baseline are still unresolved. Existing burgher-house reference plates are explicitly not promoted to gameplay evidence.

## Verification matrix

| Check | Result | Evidence / reproduction |
|---|---|---|
| Four target spaces use shared builders, one cell scale, and deterministic view-only assembly | **PASS** | `test_environment_kit_integration`: 5/5. `test_four_target_spaces_share_one_deterministic_view_contract` and `test_forge_and_street_well_modules_are_deterministic_view_only_assemblies` pass. The modules are built by `MapViewEnvironmentKit` from authored `MapDefinition` records; no parallel map format or camera/coordinate exception is introduced. |
| Forge, street/well, brewery, and checkpoint routes, anchors, transitions, and patrol records remain valid | **PASS** | `test_environment_kit_integration`: all route/anchor/transition/patrol assertions pass, including `door_courtyard`, `brewery_door`, `viru_road_boundary`, `viru_watch`, and `iron_convoy`. |
| View construction does not create collision/navigation nodes or mutate fingerprints | **PASS** | `test_environment_kit_integration`: view-only node assertions and terrain/map/transition/patrol fingerprint checks pass. |
| Shared material families resolve | **PASS** | `test_building_surface_weathering`: 6/6. Log, plank, plaster, and limestone wall pattern identity passes; tile, shingle, and thatch roof identity passes. `test_map_view_material_resolution`: 4/4. |
| Deterministic worn/repaired material presentation exists | **PASS** | `test_weathering_variant_is_deterministic_per_building` and `test_all_weathering_variants_change_the_shared_pattern` pass. The implementation keeps wear as local view material/decal presentation keyed by stable IDs, as required by the contract. |
| Forge/street-well local wear and clearance | **PASS** | Integration tests pass local soot/grime checks, forge player-to-anvil approach, smithy-door clearance, courtyard firewood clearance, and well-module route checks. |
| Lower Town production decal contract | **BLOCKED - R-360** | Clean HEAD reproduction: `...Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_decals` gives 7/8, with `test_lower_town_slice_authors_wear_decals` failing `Courtyard anvil needs soot`. Follow-up `R-360 / P0-102h` owns adding the missing authored soot decal without weakening the assertion or changing gameplay fingerprints. |
| Ordinary versus exceptional renderer boundary | **PARTIAL - R-353 open** | The P0-102 integration fixture passes the checkpoint boundary check: Viru towers remain wall/fortification records, no ordinary `Roof` is emitted, and gate arches remain separate view landmarks. However, prerequisite `R-353 / P0-102e` is still `in_progress`. Its current dirty-worktree branch also causes `test_map_view_3d_fortification` diagnostics for `st_catherines_church`; acceptance does not claim or modify that work. |
| Focused map/view regression | **PARTIAL** | Clean HEAD: `test_map_view_3d_core` 17/17 PASS; `test_map_view_material_resolution` 4/4 PASS; `test_map_view_3d_mesh` 18/18 PASS; `test_building_surface_weathering` 6/6 PASS. `test_map_view_3d_fortification` is 7/8 with existing `Karja Gate needs open metal doors` failure and 2 engine diagnostics. `test_map_view_decals` is 7/8 due to R-360. The current dirty R-353 branch additionally prevents `test_map_view_3d_mesh.gd` from loading (`MarketCivicQuarter` and `_building_by_id()` are undeclared); this is not included in the acceptance change. |
| Asset lint | **BLOCKED by unrelated baseline** | Clean HEAD `python3 tools/verify_asset_lint.py` fails only on `assets/characters/shared/sergeant.glb: tier 1 (named_npc) triangle budget exceeded (57168>56000)`. This is owned by completed P2-005, is not an environment-kit asset, and is recorded without changing out-of-scope character art. |
| Asset provenance | **PASS on clean HEAD; dirty worktree has unrelated failure** | Clean HEAD `python3 tools/validate_asset_sources.py` passes: schema ok, 758 rows, 609 inventory paths covered, 603 active runtime assets covered. The live shared worktree additionally contains unregistered `assets/animals/medieval/medieval_horse_pack_horse_{albedo,normal,roughness}.png` from in-progress A-002/R-1; those files were excluded from this acceptance commit. |
| Import and checked focused acceptance runner | **PASS** | Clean HEAD Godot editor import passes. `tools/run_godot_checked.sh --require-test-summary p0-102g-environment-kit -- ... --filter=test_environment_kit_integration` passes with 5/5 and only allowlisted shutdown leak diagnostics. |
| Matched gameplay-scale day/night evidence for all four spaces | **PASS - 8/8 plates captured** | Dedicated forge, street/well, brewery, and checkpoint pairs are recorded below. All eight files are present, decode as non-blank RGB PNGs at 1280x720, and use matched day/night framing. This evidence does not replace P0-101 human visual sign-off. |
| P0-101 landmark and P2-063-P2-067 house-tier scope separation | **PASS** | No P0-101 landmark art or P2-063-P2-067 house-tier asset/deliverable is included in this report or the P0-102 module changes. The contract's ownership table remains authoritative. |

## P0-102m.1 forge evidence

The forge-only matched pair was captured from the authored `kalev_smithy` map with the shared `MapView3D` renderer. The evidence crop keeps the gameplay-scale orthographic framing and includes the furnace/anvil work area, the player approach, and the courtyard door. The capture helper's `--forge-evidence` mode changes only the evidence camera and output path; it does not alter map semantics, runtime behavior, collision/navigation, or tests.

| Plate | Path | Lighting | Framing metadata |
|---|---|---|---|
| Day | [`forge_day.png`](images/p0_102_environment_kit/forge_day.png) | `MapView3D.TIME_DAY` | 1280x720; orthographic size 13.5; focus logic cell (17.5, 7.0); focus height 0.8; map `kalev_smithy` |
| Night | [`forge_night.png`](images/p0_102_environment_kit/forge_night.png) | `MapView3D.TIME_NIGHT` | 1280x720; orthographic size 13.5; focus logic cell (17.5, 7.0); focus height 0.8; map `kalev_smithy` |

Both plates decode as non-empty RGB PNGs at 1280x720. They use one camera configuration and differ only by the authored day/night lighting state. The forge work area, courtyard door, and approach space remain in the same crop; the night plate is darker but retains visible lit geometry.

Reproduction:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . --rendering-driver metal --script tools/capture_kalev_smithy_domestic_life.gd -- --forge-evidence
```

The capture emitted existing non-fatal `world_harju.rrmap` audit diagnostics and renderer shutdown leak diagnostics, but exited successfully and wrote both PNGs. These limitations do not affect the saved evidence files and are not changed by this evidence-only task.

## P0-102m.2 street/well evidence

The street/well-only matched pair was captured from the authored `lower_town_slice` map with the shared `MapView3D` renderer. This evidence focuses on the cistern street node at logic cell (104, 60), its wash tub at (102, 61), the authored wet threshold, and the playable approach toward `street_start`. The separate `monastery_well` at (73, 11) is outside this close gameplay-scale crop and is not claimed by these two plates.

| Plate | Path | Lighting | Framing metadata |
|---|---|---|---|
| Day | [`street_well_day.png`](images/p0_102_environment_kit/street_well_day.png) | `MapView3D.TIME_DAY` | 1280x720; orthographic size 17.5; focus logic cell (104.0, 60.5); focus height 0.8; map `lower_town_slice` |
| Night | [`street_well_night.png`](images/p0_102_environment_kit/street_well_night.png) | `MapView3D.TIME_NIGHT` | 1280x720; orthographic size 17.5; focus logic cell (104.0, 60.5); focus height 0.8; map `lower_town_slice` |

Both plates decode as non-empty RGB PNGs at 1280x720. The pair uses one camera configuration and differs only by the authored day/night lighting state. The cistern, wash tub, wet threshold, surrounding street surface, and approach-side route remain in the same crop; the night plate is darker but still contains readable geometry and authored lighting variation.

Reproduction:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . --rendering-driver metal --script tools/capture_street_well_environment_kit.gd
```

The script is evidence-only: it does not alter map semantics, runtime behavior, collision/navigation, or tests.

## P0-102m.4 checkpoint evidence

**Task:** R-359 / P0-102g
**Parent:** R-110 / P0-102
**Date:** 2026-08-01
**Status:** **PARTIAL - parent P0-102 is not ready for review**

## Scope and decision

This acceptance covers the four P0-102 target spaces: forge, street/well, brewery, and checkpoint. It evaluates the shared view-only assemblies and existing contracts; it does not author new art, runtime behavior, ordinary house-tier assets, or landmark art. P0-101 and P2-063-P2-067 remain separate ownership boundaries.

The implementation is accepted for the checks that pass below, but the parent task is not accepted as complete. The remaining findings are either an open prerequisite (`R-353`), an existing repository baseline defect, or the newly opened scoped follow-up `R-360`. The dedicated eight-plate evidence requirement is complete; this does not constitute the separate P0-101 human visual sign-off.

## Verification matrix

| Check | Result | Evidence / reproduction |
|---|---|---|
| Four target spaces use shared builders, one cell scale, and deterministic view-only assembly | **PASS** | `test_environment_kit_integration`: 5/5. `test_four_target_spaces_share_one_deterministic_view_contract` and `test_forge_and_street_well_modules_are_deterministic_view_only_assemblies` pass. The modules are built by `MapViewEnvironmentKit` from authored `MapDefinition` records; no parallel map format or camera/coordinate exception is introduced. |
| Forge, street/well, brewery, and checkpoint routes, anchors, transitions, and patrol records remain valid | **PASS** | `test_environment_kit_integration`: all route/anchor/transition/patrol assertions pass, including `door_courtyard`, `brewery_door`, `viru_road_boundary`, `viru_watch`, and `iron_convoy`. |
| View construction does not create collision/navigation nodes or mutate fingerprints | **PASS** | `test_environment_kit_integration`: view-only node assertions and terrain/map/transition/patrol fingerprint checks pass. |
| Shared material families resolve | **PASS** | `test_building_surface_weathering`: 6/6. Log, plank, plaster, and limestone wall pattern identity passes; tile, shingle, and thatch roof identity passes. `test_map_view_material_resolution`: 4/4. |
| Deterministic worn/repaired material presentation exists | **PASS** | `test_weathering_variant_is_deterministic_per_building` and `test_all_weathering_variants_change_the_shared_pattern` pass. The implementation keeps wear as local view material/decal presentation keyed by stable IDs, as required by the contract. |
| Forge/street-well local wear and clearance | **PASS** | Integration tests pass local soot/grime checks, forge player-to-anvil approach, smithy-door clearance, courtyard firewood clearance, and well-module route checks. |
| Lower Town production decal contract | **BLOCKED - R-360** | Clean HEAD reproduction: `...Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_decals` gives 7/8, with `test_lower_town_slice_authors_wear_decals` failing `Courtyard anvil needs soot`. Follow-up `R-360 / P0-102h` owns adding the missing authored soot decal without weakening the assertion or changing gameplay fingerprints. |
| Ordinary versus exceptional renderer boundary | **PARTIAL - R-353 open** | The P0-102 integration fixture passes the checkpoint boundary check: Viru towers remain wall/fortification records, no ordinary `Roof` is emitted, and gate arches remain separate view landmarks. However, prerequisite `R-353 / P0-102e` is still `in_progress`. Its current dirty-worktree branch also causes `test_map_view_3d_fortification` diagnostics for `st_catherines_church`; acceptance does not claim or modify that work. |
| Focused map/view regression | **PARTIAL** | Clean HEAD: `test_map_view_3d_core` 17/17 PASS; `test_map_view_material_resolution` 4/4 PASS; `test_map_view_3d_mesh` 18/18 PASS; `test_building_surface_weathering` 6/6 PASS. `test_map_view_3d_fortification` is 7/8 with existing `Karja Gate needs open metal doors` failure and 2 engine diagnostics. `test_map_view_decals` is 7/8 due to R-360. The current dirty R-353 branch additionally prevents `test_map_view_3d_mesh.gd` from loading (`MarketCivicQuarter` and `_building_by_id()` are undeclared); this is not included in the acceptance change. |
| Asset lint | **BLOCKED by unrelated baseline** | Clean HEAD `python3 tools/verify_asset_lint.py` fails only on `assets/characters/shared/sergeant.glb: tier 1 (named_npc) triangle budget exceeded (57168>56000)`. This is owned by completed P2-005, is not an environment-kit asset, and is recorded without changing out-of-scope character art. |
| Asset provenance | **PASS on clean HEAD; dirty worktree has unrelated failure** | Clean HEAD `python3 tools/validate_asset_sources.py` passes: schema ok, 758 rows, 609 inventory paths covered, 603 active runtime assets covered. The live shared worktree additionally contains unregistered `assets/animals/medieval/medieval_horse_pack_horse_{albedo,normal,roughness}.png` from in-progress A-002/R-1; those files were excluded from this acceptance commit. |
| Import and checked focused acceptance runner | **PASS** | Clean HEAD Godot editor import passes. `tools/run_godot_checked.sh --require-test-summary p0-102g-environment-kit -- ... --filter=test_environment_kit_integration` passes with 5/5 and only allowlisted shutdown leak diagnostics. |
| Matched gameplay-scale day/night evidence for all four spaces | **PASS - 8/8 plates captured** | Dedicated forge, street/well, brewery, and checkpoint pairs are recorded below. All eight files are present, decode as non-blank RGB PNGs at 1280x720, and use matched day/night framing. This evidence does not replace P0-101 human visual sign-off. |
| P0-101 landmark and P2-063-P2-067 house-tier scope separation | **PASS** | No P0-101 landmark art or P2-063-P2-067 house-tier asset/deliverable is included in this report or the P0-102 module changes. The contract's ownership table remains authoritative. |

## P0-102m.4 checkpoint evidence

The checkpoint-only matched pair was captured from the authored `lower_town_slice` map with the shared `MapView3D` renderer. The crop keeps the gameplay orthographic scale and frames the `viru_gate_arch` gate throat, both Viru gate towers, `gate_cart`, the player approach lane, and the incomplete `viru_foregate_arch` context together.

| Plate | Path | Lighting | Framing metadata |
|---|---|---|---|
| Day | [`checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png) | `MapView3D.TIME_DAY` | 1280x720; orthographic size 17.5; focus logic cell (117.5, 55.5); focus height 0.8; map `lower_town_slice` |
| Night | [`checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png) | `MapView3D.TIME_NIGHT` | 1280x720; orthographic size 17.5; focus logic cell (117.5, 55.5); focus height 0.8; map `lower_town_slice` |

Both plates decode as non-empty RGB PNGs at 1280x720. The pair uses one camera configuration and differs only by the authored day/night lighting state.

Reproduction:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . --rendering-driver metal --script tools/capture_checkpoint_environment_kit.gd
```

The script is evidence-only: it does not alter map semantics, runtime behavior, collision/navigation, or tests.

## P0-102m.3 brewery evidence

The brewery-only matched pair was captured from the authored `lower_town_slice` map with the shared `MapView3D` renderer. The crop keeps the gameplay orthographic scale and frames the `foaming_mug_brewery` roofed mass, `brewery_door` entrance, and the working yard props (`brewery_keg_stack`, `brewery_malt_sacks`, and `evidence_barrels`) together with the player approach lane.

| Plate | Path | Lighting | Framing metadata |
|---|---|---|---|
| Day | [`brewery_day.png`](images/p0_102_environment_kit/brewery_day.png) | `MapView3D.TIME_DAY` | 1280x720; orthographic size 17.5; focus logic cell (80.5, 68.5); focus height 0.8; map `lower_town_slice` |
| Night | [`brewery_night.png`](images/p0_102_environment_kit/brewery_night.png) | `MapView3D.TIME_NIGHT` | 1280x720; orthographic size 17.5; focus logic cell (80.5, 68.5); focus height 0.8; map `lower_town_slice` |

Both plates decode as non-empty RGB PNGs at 1280x720. The pair uses one camera configuration and differs only by the authored day/night lighting state.

Reproduction:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --path . --rendering-driver metal --script tools/capture_brewery_environment_kit.gd
```

The script is evidence-only: it does not alter map semantics, runtime behavior, collision/navigation, or tests.

## Exact commands

Run from the repository root:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --import --path .
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_building_surface_weathering
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_core
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_mesh
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_material_resolution
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_decals
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
python3 tools/verify_asset_lint.py
python3 tools/validate_asset_sources.py
```

For the acceptance-critical suite, the checked runner also passed:

```sh
tools/run_godot_checked.sh --require-test-summary p0-102g-environment-kit -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
```

## Handoffs and close decision

- **R-360 / P0-102h**: restore the missing Lower Town courtyard soot decal, then rerun the decal and map parity suites.
- **R-353 / P0-102e**: finish the exceptional renderer boundary and its focused fortification/landmark regression. P0-102g does not close or modify it.
- **P0-101 / R-108**: provide final landmark quality and matched gameplay-scale day/night sign-off.
- **P2-063-P2-067**: provide authored ordinary house-tier assets, plot dressing, and tier wiring; not claimed here.
- Existing unrelated baselines remain visible: `sergeant.glb` asset-lint budget and clean-HEAD Karja Gate test failure.

**Decision:** keep R-359 in `in_review`. Do not mark parent P0-102 done or ready for review until R-360, R-353, and the required handoff evidence/baseline gates are resolved or explicitly accepted by their owners.

## P0-102m.5 evidence audit

The dedicated evidence audit is reproducible with:

```sh
python3 tools/verify_p0_102_environment_kit_evidence.py
```

The audit checks exactly eight linked plates in `docs/reports/images/p0_102_environment_kit/`: forge, street/well, brewery, and checkpoint, each in `day` and `night`. Every plate is present, decodes as an RGB PNG at 1280x720, has non-flat luminance, and differs from its paired state. Each report row records the map identity, `MapView3D.TIME_DAY` or `MapView3D.TIME_NIGHT`, orthographic camera size, focus logic cell, and focus height. Day/night rows for each space must carry identical framing metadata.

The evidence set preserves readability of routes, doors, player approach areas, and interactables. The forge crop includes the furnace/anvil work area, courtyard door, and approach; street/well includes the cistern, wash tub, wet threshold, and `street_start` approach; brewery includes `foaming_mug_brewery`, `brewery_door`, yard props, and approach lane; checkpoint includes `viru_gate_arch`, both gate towers, `gate_cart`, approach lane, and `viru_foregate_arch`. Capture limitations are explicit: the plates are evidence-only camera captures, do not replace P0-101 human visual sign-off, and capture commands can emit non-fatal map-audit or renderer shutdown diagnostics without changing the saved images.

**Audit result:** PASS - 8/8 plates present, decodable, non-blank, paired, and linked exactly once. This verification does not close the outstanding P0-102 implementation prerequisites or unrelated baseline findings recorded above.

## R-542 current acceptance recheck (2026-08-17)

**Task:** R-542 / P0-102 acceptance: verify shared module contract and coverage
**Snapshot:** `89686cee` (`Document research task-board workflow limits`)
**Status:** **PARTIAL - scoped provenance and asset lint pass; clean integration completion is blocked by R-565**

This recheck is limited to the P0-102 shared environment kit. It does not author runtime scenes, generated map output, ordinary-house GLBs, tier assignments, or exceptional landmark art. The existing contract in [`p0_102_environment_kit_contract.md`](p0_102_environment_kit_contract.md) remains normative; this addendum records the current artifact and ownership state rather than rewriting historical results.

### Shared module coverage

| Contract family | Required reads / variants | Current artifact and stable interface | Acceptance status |
|---|---|---|---|
| Ordinary wall shell | Log, plank, plastered-timber, limestone; local worn/repaired variation | `MapViewMeshBuilderHouseStyles` and `MapViewMaterials.wall_surface_for_building()` resolve authored wall keys and deterministic building weather variants. Shared building nodes are exercised by the integration fixture. | **PASS - artifact and scoped test present** |
| Gable and roof | Gable-to-street massing; tile, shingle, and thatch covers | `MapViewMeshBuilderHouseStyles.roof_style()` and the shared roof material path resolve `tile`, `shingle`, and `thatch`; tier defaults remain downstream. | **PASS - artifact and material test present** |
| Door and threshold | Stable entrance, threshold, transition visual, and arrival clearance | `smithy_door`, `brewery_door`, `smithy_door_transition`, and `viru_road_boundary` remain authored interfaces. Transition and route checks are in `test_environment_kit_integration.gd`. | **PASS for authored contract; clean completion partial** |
| Boundary wall/fence | Limestone or timber/wattle boundary, gates, and open thresholds | Forge yard uses `smithy_yard_fence_north` and `smithy_yard_fence_east`; checkpoint uses the authored Viru wall/tower records and gate-landmark path. | **PASS - artifact and module coverage present** |
| Drainage and ground wear | Packed earth/mud, wet thresholds, local grime/soot, restrained cobble | `MapViewDecals` is view-only; authored examples include `decal.mud_smithy_door`, `decal.wet_smithy_door`, `decal.mud_brewery_door`, `decal.wet_cistern`, and `decal.mud_checkpoint_east`. | **PASS - authored evidence and decal audit present** |
| Forge/workshop dressing | Furnace, anvil, bellows, hand tools, quench, charcoal/scrap/fuel | Module `forge_interior` and `forge_yard` resolve the authored `kalev_smithy` / `kalev_smithy` yard records. Stable anchors include `anvil`, `ledger`, `bed_alcove`, `door_courtyard`, and `courtyard_quench`. | **PASS for scoped module; clean completion partial** |
| Well/street kit | Well body, wash vessel, apron, drainage cue, clear approach | Module `street_well` resolves `cistern`, `cistern_wash_tub`, and `monastery_well`; route anchors include `street_start`, `checkpoint_east`, and `monastery_gate`. | **PASS for scoped module; clean completion partial** |
| Brewery service yard | Kegs, malt sacks, trade storage, door apron, local wet/mud wear | Module `brewery` resolves `foaming_mug_brewery`, `brewery_door`, `brewery_keg_stack`, `brewery_malt_sacks`, and `evidence_barrels`. | **PASS for scoped module; clean completion partial** |
| Checkpoint / gate approach | Route throat, gate context, cart/stall/sign dressing, ground transition | Module `checkpoint` resolves `checkpoint_west`, `checkpoint_east`, `market_stall_gate`, `gate_cart`, `viru_gate_arch`, and `viru_foregate_arch`; patrols `viru_watch` and `iron_convoy` remain authored. | **BLOCKED only by R-565 diagnostics; no missing module** |
| Small trade and yard props | Barrels, carts, stalls, signs, firewood, vegetation, fences | Existing validated prop builders and provenance rows cover the scoped forge, brewery, street, and gate prop families. No new P0-102-specific imported asset is required by the current assembly. | **PASS - provenance covered** |
| Material and wear presentation | Deterministic per-ID weathering, repaired/worn local presentation | `MapViewMaterials.BUILDING_WEATHER_VARIANTS` contains `worn`, `fresh`, `damp`, and `repaired`; integration and weathering tests cover deterministic variation. | **PASS - scoped asset/lint and material evidence** |
| Exceptional landmark handoff | Churches, civic/guild structures, gatehouses, and Viru Gate stay outside ordinary kit | `viru_gate_north_tower` and `viru_gate_south_tower` remain wall/fortification records without an ordinary roof; gate arches remain separate view landmarks. | **PASS in boundary assertion; full suite completion partial** |

### Ordinary-house tier boundary

The required R-003 ordinary tiers are explicitly recorded, but are not P0-102-owned environment-kit modules:

- `merchant_stone`: owned by P2-063 / R-209.
- `merchant_timber`: owned by P2-064 / R-210.
- `craft_boda`: owned by P2-065 / R-211.
- Plot and threshold dressing, including cellar necks, yard gates, privies, lean-tos, and merchant-only hoists, is owned by P2-066 / R-212.
- Lower Town tier assignment, mesh selection, and route/parity wiring is owned by P2-067.

P0-102 may consume these outputs after their contracts are accepted, but it must not substitute generic environment modules for the tier assets or claim their gameplay-scale evidence. Their absence is therefore a downstream handoff blocker, not an unowned P0-102 module.

### Stable IDs and evidence audit

The current acceptance inventory covers the four required spaces and their stable interfaces:

- Forge: `kalev_smithy`, `smithy_door`, `smithy_door_transition`, `door_courtyard`, `anvil`, `ledger`, `bed_alcove`, `courtyard_quench`.
- Street/well: `cistern`, `cistern_wash_tub`, `monastery_well`, `street_start`, `checkpoint_east`, `monastery_gate`.
- Brewery: `foaming_mug_brewery`, `brewery_door`, `brewery_keg_stack`, `brewery_malt_sacks`, `evidence_barrels`.
- Checkpoint: `checkpoint_west`, `checkpoint_east`, `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_arch`, `viru_foregate_arch`, `viru_road_boundary`, `viru_watch`, `iron_convoy`.

The evidence verifier reports **8/8** valid paired plates in `docs/reports/images/p0_102_environment_kit/`. It verifies 1280x720 RGB output, non-flat luminance, distinct day/night bytes, matched framing metadata, and report links for forge, street/well, brewery, and checkpoint. Plate integrity does not replace the missing three-tier gameplay capture or human P0-101 visual sign-off.

### Verification run

Commands run from the live repository on 2026-08-17:

```sh
python3 tools/validate_asset_sources.py
# PASS: schema ok; 1155 rows; 999 inventory paths covered; 993 active runtime assets covered

python3 tools/verify_asset_lint.py
# PASS: 8 style-lock textures, 9 character GLBs, 29 tier-classified character GLBs, 0 portraits checked

python3 tools/verify_p0_102_environment_kit_evidence.py
# PASS: 8/8 plates

GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_environment_kit_integration
# 5 tests, 0 assertion failures, 6 engine diagnostics
```

The focused Godot run reaches all five integration tests and reports no failed assertions. It is not a clean acceptance pass because checkpoint construction emits six existing detached-node diagnostics from `_expose_authored_gate_leaf_contract()` at `scripts/map/view3d/map_view_mesh_builder_landmarks.gd:419`, caused by `reparent(root, true)` before the assembled module is inside the SceneTree. This is the exact scope of **R-565**, which owns the runtime fix and rerun. The diagnostics are not reclassified as missing environment-kit artifacts.

### Final ownership decision

No unowned P0-102 required module was found. Every shared family in the contract has a current builder, authored map-facing interface, existing asset/provenance coverage, or an explicit downstream ownership boundary. The P0-102 acceptance remains **partial** until R-565 removes the detached gate-leaf diagnostics and the downstream ordinary-house/tier handoff provides its separate evidence. No additional follow-up task is needed from R-542.
