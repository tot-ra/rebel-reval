# R-532 Lower Town ordinary-fabric verification

**Task:** R-532 / P0-101 ordinary-fabric verification  
**Parent:** R-108 / P0-101  
**Map:** `lower_town_slice` / Workers' District  
**Verification date:** 2026-08-17  
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. This report changes no runtime, asset, or map source.  
**Decision:** **SOURCE/CONTRACT PASS; GAMEPLAY-VISUAL ACCEPTANCE BLOCKED.**

## Decision boundary

The authored Lower Town source and focused contracts are ready for the ordinary-fabric handoff at the structural boundary. All 43 tiered houses are assigned to the closed R-003-derived tier set, the required source material and roof families are represented, authored weathering hooks are present, and the map/renderer boundary tests pass.

This does **not** close visual acceptance. No matched gameplay-scale day/night route capture set exists under `docs/reports/images/lower_town_p0_101/`. Existing whole-map orthographic and calibration images are supplementary only. They cannot prove gameplay-scale tier readability, route-scale facade repetition, roof/material readability, wear or repair readability, or landmark separation.

No numeric facade repetition threshold is defined in the available R-003/P0-101 evidence. This report therefore does not invent one or claim that an undefined threshold has been met. The repetition gate remains pending a gameplay-scale route review owned by the ordinary-frontage/capture handoff.

## 1. Evidence matrix

| Check | Result | Evidence and boundary |
|---|---|---|
| 43 tiered ordinary houses audited | **PASS** | `lower_town_p0_101_landmark_inventory.md` section 1.1 enumerates every stable ID; the tier contract test asserts the same 43-ID allowlist. |
| Closed tier assignment | **PASS** | `merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`; no unknown tier values. |
| Required wall families in authored source | **PASS at source level** | Tiered records resolve to `log=17`, `plaster=13`, `plank=7`, `limestone=5`; one `brick` record remains the documented rare accent. Source styles are in `content/maps/lower_town_slice.rrmap` lines 28-75 and house records in lines 171-224. |
| Required roof families in authored source | **PASS at source level** | Tiered records resolve to `shingle=29`, `thatch=8`, `tile=6`. The three R-003 roof bands are represented. |
| Material/roof precedence and fallback | **PASS at contract level** | `test_burgher_house_tiers` verifies deterministic tier fallbacks and that authored `wall_material` / `roof_material` override tier defaults. |
| Surface texture and weathering variation | **PASS at contract level** | The tier contract requires at least 3 wall textures, 3 roof textures, and 2 stable weathering variants; all assertions pass. |
| Localized authored wear hooks | **PASS at source/contract level** | Eleven view-only decals are authored at lines 290-300 of the map source, including `mud`, `wet_threshold`, `grime`, and `soot`. The map test proves decals do not alter the gameplay fingerprint. |
| Repaired-state readability | **BLOCKED** | No gameplay-scale capture or human review proves that wear/repair details read on the route. The contract's weathering variants are not visual acceptance evidence. Owner: R-487 with capture support from R-536. |
| Facade repetition threshold | **BLOCKED** | No documented numeric threshold is available, and no matched route capture exists for reviewing repeated runs. Do not waive or infer this gate. Owner: R-487/R-536. |
| Integrated map and route contracts | **PASS** | `test_lower_town_slice_map` passes 19/19, including parity, route endpoints, city-wall/Viru Gate openings, navigation, water exclusion, smithy approach, boundary transitions, and view-only gate-arch alignment. |
| Gameplay-scale visual acceptance | **BLOCKED** | R-491 capture matrix has all ordinary-fabric day/night rows pending; the required gameplay-scale packet directory is absent. |

## 2. Ordinary-fabric audit

The 43 records are divided into the three closed tiers from the typology contract:

| Tier | Count | Authored material resolution | Authored roof resolution | Contract interpretation |
|---|---:|---|---|---|
| `merchant_stone` | 14 | plaster 5, plank 5, limestone 4 | shingle 10, tile 4 | Mixed/affluent merchant frontage and selective tile bias are authored; gameplay silhouette and readability remain unverified. |
| `merchant_timber` | 14 | plaster 6, log 4, plank 2, brick 1, limestone 1 | shingle 11, tile 2, thatch 1 | Timber/plastered-timber direction and shingle bias are authored; the single brick record is a rare accent, not a new required family. Gameplay readability remains unverified. |
| `craft_boda` | 15 | log 13, plaster 2 | shingle 8, thatch 7 | Compact craft-edge material and roof bias are authored; no gameplay capture proves relative height, compactness, or absence of merchant-scale treatment. |

The complete ID audit is retained in [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), section 1.1, and in the executable `EXPECTED_TIERS` table in [`test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd). The source rows are `pikk_corner_house` through `south_apron_far_roofs` in `content/maps/lower_town_slice.rrmap` lines 171-224.

The R-003 decisions used for this review are:

- gable to street with ridge perpendicular to the lane;
- merchant houses generally 2-3 storeys and `craft_boda` 1-2 storeys;
- stone/tile bias for affluent merchant masses;
- timber/plaster with shingle bias for ordinary merchant and craft frontage;
- log/thatch or shingle bias at the craft edge;
- no universal tiling, no late-Gothic tourist facade default, and no merchant hoist treatment on `craft_boda`.

These are authoring and review criteria, not claims that a source contract test can establish gameplay-scale visual quality.

## 3. Reproducible verification

Both commands were run from the project root with Godot 4.7.1 and the checked runner. The filter belongs after the standalone `--` so the test harness receives it.

```bash
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

./tools/run_godot_checked.sh --require-test-summary \
  r532_lower_town_slice_map -- \
  "$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map

./tools/run_godot_checked.sh --require-test-summary \
  r532_burgher_house_tiers -- \
  "$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
```

Observed results:

```text
test_lower_town_slice_map       1 file, 19 tests, 0 failures, 0 errors
 test_burgher_house_tiers       1 file, 5 tests, 0 failures, 0 errors
```

The checked runner accepted only the documented DEF-002 shutdown-only resource-leak diagnostics. No engine, parser, script, or resource failure was observed in either focused run.

### What the map suite proves

`test_lower_town_slice_map` covers the authored map validation and canonical parity fixture, view-only wear decal fingerprint isolation, terrain proportions, reachable route endpoints, smithy facade/yard placement, city-wall blocking with the Viru Gate causeway open, the southern district seam, navigation generation and player clearance, water exclusion, registered boundary transitions, and Viru Gate arch span over its collision jambs.

### What the tier suite proves

`test_burgher_house_tiers` covers all 43 stable IDs and their three tier assignments, keeps St. Catherine's and named special buildings outside ordinary tiers, verifies deterministic tier fallback and authored material precedence, builds walls/roofs with surface textures, and requires at least three wall textures, three roof textures, and two stable weathering variants. It also verifies that the exceptional registry wins for St. Catherine's and that wall records remain on the fortification path.

Neither suite performs a gameplay-scale camera capture or human visual review.

## 4. Remaining blockers and ownership

1. **Matched day/night gameplay route captures:** R-536 must provide the dedicated packet with stable third-person route/approach cameras, map revision, renderer, viewport, and non-blank verification. See [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), sections `Capture contract` and `Required ordinary-fabric coverage`.
2. **Ordinary frontage variation and wear review:** R-487 must review the captured repeated runs for facade/material repetition, tier separation, roof readability, and localized wear/repair readability. No undocumented repetition threshold may be inferred.
3. **Visual closeout:** R-532 can be moved from structural verification to final acceptance only after the matched plates exist and the observations are recorded against the R-003 decisions. The current final gate remains blocked as stated by [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md).
4. **Historical/art boundary:** [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) is a conditional art-direction pass, not final gameplay sign-off. Human review must still confirm the production route captures.

## Linked evidence

- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) - 91-record source inventory and ordinary-fabric ID list.
- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) - P0-101 clause matrix and current blocked closeout.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - required matched gameplay-scale day/night packet.
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) - closed tier, roof, massing, and rejection contract.
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - conditional art-direction decision and missing final capture evidence.
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md) - route/runtime boundary and unrelated final runtime blockers.
- [`burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - R-003 Spring 1343 source dossier and decisions.
- [`lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap) - authored source records, styles, transitions, and decals.
