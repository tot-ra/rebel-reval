# Lower Town P0-101 matched capture matrix

**Task:** R-491 / P0-101f
**Role:** production / art / canon
**Map:** `lower_town_slice` / Workers' District
**Source snapshot:** current shared worktree, 2026-08-24; raw RRMap SHA-256 `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`; compiled runtime semantic fingerprint `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`
**Recorded:** 2026-08-24
**Status:** **CAPTURE PACKET REGENERATED FOR CURRENT RUNTIME - CURRENT-REVISION VISUAL ACCEPTANCE BLOCKED**

## Decision

This report is the evidence matrix for the P0-101 visual acceptance pass. It deliberately distinguishes **evidence** from **interpretation**. No existing image is promoted to a P0-101 acceptance plate unless it is a matched day/night, gameplay-scale view with a reproducible camera and map revision.

The dedicated capture capability is now available and has produced a reproducible packet for the current compiled runtime definition, but stable-ID visual acceptance is still **blocked**:

- `tools/capture_lower_town_p0_101.gd` uses production `LowerTownSlice.create()`, `MapBuilder.build()`, and `MapView3D.create()` with five authored sector route-segment midpoint presets.
- `docs/reports/images/lower_town_p0_101/capture_manifest.json` records map ID, source fingerprint, renderer, 1280x720 viewport, gameplay orthographic size `33.75`, focus cells/heights, camera pitch/yaw, intent, and matched day/night outputs.
- Ten dedicated PNGs exist under `docs/reports/images/lower_town_p0_101/`: five sector route poses times `day` and `night`. Each decodes as 1280x720 with a non-zero pixel payload; all five day/night pairs share the same framing key and focus world.
- `test_capture_lower_town_p0_101.gd` passes 5/5 with 0 failures and 0 errors. The non-headless capture command completed with status 0 and wrote all ten plates. Godot also emitted the known shutdown resource-leak diagnostics plus pre-existing `monastery_quarter` neighbor-preview diagnostics (`MAP_TRANSITION_DESTINATION_UNKNOWN` for `kuldjala_interior` and chunk-boundary warnings); those diagnostics are outside this Lower Town evidence task and do not invalidate the written packet.
- The current source inventory contains 51 tiered houses (`merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`), ten untiered special/exceptional houses, 36 collision-bearing wall records, and two view-only gate arches. The eight R-547 rear-workshop IDs are listed in the inventory delta and have no stable-ID visual observations in this packet.
- **Revision semantics:** the manifest's `map_fingerprint` is the compiled `MapDefinition` semantic fingerprint (`13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`), not a raw-file digest. The current raw RRMap SHA is separately recorded above (`6ae0b82a...`). A direct Godot probe on 2026-08-24 reproduced the manifest fingerprint and found 97 building records, two view landmarks, and all eight R-547 rear-workshop IDs in the compiled definition.
- **Visual-review warning:** the manifest plates still have no `stable_ids` field, so route proximity is not visual proof for any individual current record. The packet is therefore current-runtime capture evidence, but not stable-ID visual acceptance.

This is a completed capture-capability handoff, not current-revision visual acceptance or a waiver of the remaining review gates.

## Capture contract

Every acceptance plate must record all of the following in its filename or matrix row:

| Field | Required value |
|---|---|
| Map | `lower_town_slice` |
| Camera | gameplay-scale third-person route camera; no top-down/debug-only substitute |
| Time | one `day` plate and one `night` plate from the same camera pose and map revision |
| Renderer | `gl_compatibility` unless the capture owner records an approved renderer decision |
| Viewport | `1280x720` or the project-approved gameplay capture resolution |
| Map revision | commit or authored-map revision, including dirty-worktree note when applicable |
| Camera intent | route-scale, ordinary frontage, landmark approach, or gate opening |
| Evidence | PNG path, non-blank verification result, and exact command/script |
| Interpretation | observed result only; do not infer material/silhouette quality from source data |

The dedicated gameplay-scale packet is reproduced with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

The runner writes the ten dedicated plates and `capture_manifest.json` below `docs/reports/images/lower_town_p0_101/`. The whole-map command remains supplementary:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/capture_map_view_3d.gd
```

That script writes `docs/reports/images/view3d/{kalev_smithy,lower_town_slice}_{day,night}.png`; it is useful for renderer smoke evidence, but does **not** satisfy this matrix's gameplay-scale camera requirement.

## Evidence status summary

| Acceptance surface | Required day plate | Required night plate | Evidence status | Source / blocker |
|---|---|---|---|---|
| Representative `merchant_stone` frontage | pending | pending | **BLOCKED** | Inventory 1.1, `merchant_stone` rows; no gameplay-scale tier capture |
| Representative `merchant_timber` frontage | pending | pending | **BLOCKED** | Inventory 1.1, `merchant_timber` rows; no gameplay-scale tier capture |
| Representative `craft_boda` frontage, including eight current rear-workshop IDs | pending | pending | **BLOCKED** | Inventory 1.1/1.1a; source count is 23 but the packet has no stable-ID tier observation for any representative or rear-workshop record |
| Repeated frontage / variation audit | pending | pending | **BLOCKED** | Inventory 3, source inventory only; repetition cannot be judged from records |
| Log / plank / plaster / limestone wall families | pending | pending | **BLOCKED** | Inventory 1.1-1.3; no material-readable route frames |
| Tile / shingle / thatch roof covers | pending | pending | **BLOCKED** | Inventory 3; no gameplay-scale roof-readability frames |
| Localized wear and repaired states | pending | pending | **BLOCKED** | Inventory 3; no close or route-scale wear frames |
| Ten untiered special/use-site buildings | pending | pending | **BLOCKED** | Inventory 1.2; listed individually below |
| St. Catherine's church | pending | pending | **BLOCKED** | Inventory 1.2, `st_catherines_church`; no dated silhouette approach |
| Inner Viru Gate 1343 state | pending | pending | **BLOCKED** | Inventory 1.3-1.4; no gate approach/opening frame |
| Viru foregate 1343 state | pending | pending | **BLOCKED** | Inventory 1.3-1.4; no foregate approach/opening frame |
| Remaining fortification and precinct walls | pending | pending | **BLOCKED** | Inventory 1.3; no route-scale wall/landmark frame set |
| Route-scale proof that special buildings are not enlarged ordinary houses | pending | pending | **BLOCKED** | R-491 deliverable; no matched route frame |
| Existing playable route and landmark approach reproducibility | `market_primary_spine_day.png`, `merchant_craft_lane_day.png`, `service_yard_day.png`, `eastern_artisan_wet_margin_day.png`, `landmark_approaches_day.png` | matching `_night.png` plates | **CAPTURE PACKET COMPLETE** | `capture_manifest.json`; five authored sector route midpoint presets, matched framing keys, non-blank 1280x720 PNG verification |


## Current-revision R-108 coverage ledger

The parent acceptance contract has seven clauses. This ledger maps each clause to source IDs, existing evidence, the missing acceptance evidence, and the owner. **No packet row is promoted merely because its route preset passes near an authored record.**

| # | R-108 parent clause | Current source IDs / structural evidence | Existing evidence | Missing evidence | Owner |
|---:|---|---|---|---|---|
| 1 | No unexplained repeated facade/material run; every required visible landmark is classified exactly once | 51 tiered houses; 10 untiered houses; 36 wall IDs; 2 `gate_arch` IDs; all 99 IDs unique | [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), current-source audit | Stable-ID-linked gameplay review proving repetition limits, material variation, and one-time landmark classification | R-487 / R-612; exceptional boundary R-488 / R-613 |
| 2 | Gameplay captures distinguish three tiers plus log/plank/plaster/limestone, tile/shingle/thatch, and wear/repair | `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`; eight rear-workshop IDs are current `craft_boda` records | Source inventory and tier contract; no visual claim | Matched day/night plates annotated to representative IDs, all eight rear workshops, materials, roof covers, and wear states | R-487 / R-612; packet handoff R-616 |
| 3 | St. Catherine's, 1343 Viru Gate, and special buildings read as exceptional, not enlarged ordinary houses | `st_catherines_church`; special houses; Viru towers/jambs; foregate walls/towers/jambs; `viru_gate_arch`; `viru_foregate_arch` | Static registry and wall/view-landmark separation in inventory | Dated gameplay-scale approach/close plates plus historical/art decision per required ID | R-488 / R-613; review R-617 / R-492 |
| 4 | Matched gameplay-scale day/night captures exist for ordinary fabric and each landmark with map revision metadata | Five route presets, 10 current-runtime plates, raw source SHA `6ae0b82a...`, compiled semantic fingerprint `13525325...` | Packet integrity: 10 PNGs, 5 framing pairs, 1280x720; direct Godot probe reproduces the semantic fingerprint | Stable-ID observations for every required surface remain missing; the manifest fingerprint must not be compared directly with the raw RRMap digest | R-489 / R-614; capture R-560/R-491 |
| 5 | Human historical/art review signs every 1343 silhouette or records an owned blocking amendment | Required IDs are enumerated in inventory and this matrix | No named human approval in current packet | Named canon/art sign-off or per-ID blocking amendments | R-617 / R-492 |
| 6 | Routes, collision, navigation, occlusion/chunk metadata, parity, and performance budgets pass | Wall/gate IDs preserve collision/view split; authored route anchors and transitions remain source evidence | Existing focused reports and map contracts only | Current parity, camera/occlusion, clean-load, resident-budget, and declared-hardware gates | R-490 / R-615; map/parity R-547; runtime R-577/R-578 |
| 7 | All upstream blockers and child handoffs resolve without promoting incomplete P0-102 evidence | Current child ownership is explicit: R-487, R-488, R-489, R-490, R-491, R-492; P0-102 remains separate | Existing decomposition and acceptance ledgers preserve blocked statuses | Resolved child statuses and final parent rerun; no incomplete handoff may be promoted | R-493 / R-618; upstream R-109/R-110 and A-009 |

**Disposition:** source inventory and packet integrity are deterministic structural evidence, but the current-revision acceptance result remains **BLOCKED** because the packet has no stable-ID visual annotations or named canon/art sign-off. The direct Godot probe confirms that the manifest's compiled semantic fingerprint is reproducible; the raw RRMap SHA is a separate source-ledger value. The exact Python baseline audit remains useful for checking those two revision domains are not conflated.

Every row above requires one day and one night frame. `pending` is intentionally not a claim that a file exists.

## Required ordinary-fabric coverage

The source inventory establishes the required IDs, but not visual acceptance. At least one matched day/night gameplay-scale route frame must show each tier, and the final review must inspect repeated runs rather than a single isolated house.

| Tier | Required source IDs | Day plate | Night plate | Interpretation to record after capture |
|---|---|---|---|---|
| `merchant_stone` | `pikk_corner_house`, `vene_row_house`, `vene_corner_house`, `market_row_house`, `saiakang_house`, `vene_gate_house`, `apothecary_house`, `moneychangers_house`, `kaik_house_west`, `kaik_house_mid`, `kaik_house_east`, `glovers_house`, `viru_house_stone`, `merchants_house` | pending | pending | Stone/mixed frontage, tier silhouette, tile-forward roof bias, variation across adjacent rows |
| `merchant_timber` | `turg_house_north`, `vanaturu_kael_house`, `corner_house_muurivahe`, `viru_house_west`, `viru_house_mid`, `viru_house_east`, `weary_traveler_inn`, `saddlers_house`, `coopers_house`, `rope_makers_house`, `karja_corner_house`, `turg_south_house`, `west_lane_house`, `glassblowers_house` | pending | pending | Timber/plastered-timber frontage, shingle-forward roof bias, no accidental landmark treatment |
| `craft_boda` (23 current records, including R-547 rear workshops) | pending | pending | **BLOCKED** | Source IDs are reconciled in inventory section 1.1a, but no packet plate is stable-ID linked; do not infer visibility from `merchant_craft_lane` or `eastern_artisan_wet_margin` route coverage |

**Inventory link:** [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), sections 1.1 and 1.1a, current source lines 160-241 of `content/maps/lower_town_slice.rrmap`.

The eight current R-547 rear-workshop IDs are not silently folded into a route verdict. They are structural source records only and remain `BLOCKED` for both day and night until a future capture identifies each stable ID in-frame: `saddlers_rear_workshop`, `coopers_rear_workshop`, `sauna_rear_boda`, `rope_makers_rear_store`, `karja_rear_boda`, `brewery_rear_store`, `smithy_rear_shed`, and `carriers_barn`.

## Required special and landmark coverage

The following rows retain the stable IDs from the inventory so that each future plate can be linked to one authored record. A grouped row is used only where the inventory itself defines a wall surface family; the stable IDs remain explicit and must be checked individually during capture review.

| Surface / stable IDs | Day plate | Night plate | Required observation | Inventory link |
|---|---|---|---|---|
| `monastery_cloister`, `monastery_barn` | pending | pending | Special/use-site mass reads as a precinct/service structure, not a scaled ordinary house | Inventory 1.2 |
| `guild_storehouse`, `public_bathhouse` | pending | pending | Use-site identity and frontage remain distinct from ordinary tiers | Inventory 1.2 |
| `karja_gate_house`, `foaming_mug_brewery`, `kalev_smithy` | pending | pending | Gate/production landmarks retain readable approach and do not inherit a generic enlarged-house silhouette | Inventory 1.2 |
| `muurivahe_house_north`, `south_apron_wall_walk_hut` | pending | pending | Special/use-site boundary and wall relationship remain legible at route scale | Inventory 1.2 |
| `st_catherines_church` | pending | pending | Dated 1343 church silhouette, exceptional path, approach and night readability; no ordinary-house substitution | Inventory 1.2, exceptional registry |
| `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_north_jamb`, `viru_gate_south_jamb` | pending | pending | Collision-bearing inner gate throat, opening clearance, tower/jamb relationship and 1343 state | Inventory 1.3, Viru Gate subsection |
| `viru_gate_arch` | pending | pending | View-only ironbound arch and raised portcullis align visually with jambs; do not treat the arch as collision | Inventory 1.4 |
| `foregate_wall_north`, `foregate_wall_south`, `foregate_tower_north`, `foregate_tower_south`, `foregate_north_jamb`, `foregate_south_jamb` | pending | pending | Incomplete 1343 foregate state and oak leaves remain distinct from the inner gate | Inventory 1.3, Foregate subsection |
| `viru_foregate_arch` | pending | pending | View-only oak arch fits the foregate opening and preserves route readability | Inventory 1.4 |
| `city_wall_north`, `city_wall_gate_south`, `city_wall_south_continuation` | pending | pending | City-wall continuity and gate-side massing read as fortification surface, not ordinary houses | Inventory 1.3 |
| `wall_tower_northeast`, `wall_tower_north`, `hinke_tower`, `wall_tower_southeast`, `wall_tower_south`, `wall_tower_southwest` | pending | pending | Round-tower silhouettes and wall-walk continuity; no later or unowned tower invention | Inventory 1.3 |
| `wall_seal_viru_south_join`, `wall_seal_viru_south_west`, `wall_seal_viru_south_east`, `wall_seal_hinke_north`, `wall_seal_bend_a_east`, `wall_seal_bend_b_north`, `wall_seal_bend_c_west`, `wall_seal_bend_d_north` | pending | pending | Sealed wall joins remain closed and do not create accidental openings or ordinary frontage | Inventory 1.3 |
| `city_wall_bend_a`, `city_wall_bend_b`, `city_wall_bend_c`, `city_wall_bend_d` | pending | pending | Bends preserve fortification silhouette, occlusion and route clearance | Inventory 1.3 |
| `monastery_precinct_wall_west`, `monastery_precinct_wall_south_a`, `monastery_precinct_wall_south_b` | pending | pending | Precinct boundary reads separately from house rows and remains traversable only at authored routes | Inventory 1.3 |
| `smithy_yard_fence_north`, `smithy_yard_fence_east` | pending | pending | Yard boundary and production approach remain localized, not monumental | Inventory 1.3 |

**Note:** The complete tower set has ten IDs: `wall_tower_northeast`, `wall_tower_north`, `viru_gate_north_tower`, `viru_gate_south_tower`, `foregate_tower_north`, `foregate_tower_south`, `hinke_tower`, `wall_tower_southeast`, `wall_tower_south`, and `wall_tower_southwest`; the Viru and foregate tower IDs are covered in their dedicated rows above.

## Supplementary images that must not be promoted

These files exist, but they do not satisfy the P0-101 acceptance contract because their camera intent or scope is wrong:

| Existing file | Use | Why it is not P0-101 evidence |
|---|---|---|
| `docs/reports/images/view3d/lower_town_slice_day.png` | Whole-map renderer smoke context | Fixed orthographic camera; no route or landmark approach metadata |
| `docs/reports/images/view3d/lower_town_slice_night.png` | Whole-map renderer smoke context | Fixed orthographic camera; no matched gameplay-scale framing |
| `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_day.png` | ADR-0018 calibration context | Calibration plate, not a P0-101 route/landmark inventory capture |
| `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_night.png` | ADR-0018 calibration context | Calibration plate; it does not identify the required frontage/landmark IDs |
| `docs/reports/images/adr0018_calibration/lower_town_slice_top_down_day.png` | Debug/overview context | Top-down/debug view is explicitly disallowed as acceptance capture |
| `docs/reports/images/adr0018_calibration/lower_town_slice_top_down_night.png` | Debug/overview context | Top-down/debug view is explicitly disallowed as acceptance capture |
| `docs/reports/images/map_audit/lower_town_slice.png` | Map audit context | Audit image has no matched gameplay day/night camera contract |
| `docs/reports/images/map_conversion_lower_town_after_day.png` | Conversion context | Historical conversion evidence, not the final P0-101 integrated route set |
| `docs/reports/images/map_conversion_lower_town_after_night.png` | Conversion context | Historical conversion evidence, not the final P0-101 integrated route set |

## Blockers and ownership handoff

1. **Capture capability:** **COMPLETE for R-560.** The dedicated runner and ten-plate manifest are under `tools/capture_lower_town_p0_101.gd` and `docs/reports/images/lower_town_p0_101/`; the exact command is recorded above.
2. **Focused contracts:** `test_capture_lower_town_p0_101.gd` passes 5/5 with 0 failures and 0 errors. The remaining blocker is not packet generation; it is surface-by-surface visual review and upstream route/art handoff.
3. **Production dependencies:** the ordinary house kits, plot dressing, tier wiring and exceptional-landmark implementation must be complete before the captures can show the required authored visual surfaces. The existing board tasks R-487/R-488/R-489 own those upstream handoffs.
4. **Review:** The PNG set now exists and passes non-blank/dimension/parity checks. Send the matrix plus plates to the canon/art reviewer for R-492; review each required tier, material, wear, special-building, rear-workshop, and landmark row before changing any `pending`/`BLOCKED` status. Do not close R-108 from this matrix.

No new follow-up task is created here: each remaining blocker already has an owning board task or an existing runtime owner, and creating a duplicate would obscure ownership.

## Reproduction and verification checklist

The following commands are the minimum evidence record for the next capture attempt:

```bash
# Dedicated gameplay-scale route packet (non-headless; required evidence).
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd

# Focused packet contract (5/5, 0 failures, 0 errors).
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101

# Whole-map renderer smoke only; not sufficient for this matrix.
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/capture_map_view_3d.gd

# Existing focused contracts (current rerun: 19/19 and 3/3).
tools/run_godot_checked.sh --require-test-summary r491-lower-map \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r491-house-tiers \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

For each future plate, verify dimensions and non-blank output using the existing capture-stat helper or an equivalent project check. A successful command with no route-camera metadata still remains supplementary, not acceptance evidence.

## Source references

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), especially sections 1.1-1.4, 3-4, and 5-6.
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), current source lines 116-247, including the R-547 rear-workshop delta.
- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd), dedicated route packet runner and manifest schema.
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd), packet contract and generated-output checks.
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json), generated packet metadata and output list.
- [`tools/capture_map_view_3d.gd`](../../tools/capture_map_view_3d.gd), fixed `MAP_IDS`, `OUTPUT_DIR`, viewport, and supplementary orthographic view creation.
- [`tests/godot/test_capture_map_view_3d.gd`](../../tests/godot/test_capture_map_view_3d.gd), existing whole-map capture contract.
- [`tools/verify_adr0018_calibration_captures.py`](../../tools/verify_adr0018_calibration_captures.py), calibration-only image verification and camera modes.
- [`adr0018_visual_calibration.md`](adr0018_visual_calibration.md), calibration protocol and renderer context.
- [`docs/reports/renderer_evaluation.md`](renderer_evaluation.md), renderer choice and non-headless capture boundary.
