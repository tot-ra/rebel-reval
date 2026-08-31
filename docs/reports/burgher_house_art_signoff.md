# A-009 Lower Town burgher-house art sign-off

**Review date:** 2026-08-31 (closeout; initial review 2026-08-02)
**Historical target:** Spring 1343 Reval, Lower Town
**Task:** A-009 / R-6
**Inputs:** A-008 reference pack, R-003 `burgher-house-plan.md`, and P0-163 `house_tier` contract

## Decision

**FINAL VISUAL ART-DIRECTION PASS; RUNTIME WIRING REMAINS DOWNSTREAM.**

The six A-008 synthetic reference plates established the historical and material target. The three authored production GLBs now satisfy that target at a shared gameplay orthographic scale, and matched day/night captures show that the tier silhouettes remain distinguishable without relying on landmark-scale massing. The existing Godot P0-102 route pair supplies the shared Lower Town comparison and route context.

This closes the A-009 visual sign-off gate for the three house families. It does not transfer ownership of runtime registration, map composition, collision, or route integration from P2-063 through P2-067, and it does not present synthetic reference plates as archaeological proof.

## Evidence inventory

| Evidence | Result | Review note |
|---|---|---|
| `reference_merchant_stone_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_stone_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_merchant_timber_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_timber_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_craft_boda_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_craft_boda_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| Production house GLBs for the three tiers | Present | `merchant_stone`, `merchant_timber`, and `craft_boda` kits are generated, grounded, non-empty, within triangle budgets, and linked to their Blender reports below |
| `signoff_*.png` gameplay-scale day/night captures | Present | Six isolated tier captures plus the shared three-tier route pair; all are 1280x720 at orthographic size 33.75 |
| Runtime registration in `assets/SOURCES.csv` | Downstream-owned | Production asset provenance and map/runtime wiring remain with P2-063 through P2-067; A-009 does not claim those rows |

## Tier review


### Production-kit and gameplay evidence packet

| Tier / comparison | Production evidence | Day capture | Night capture | Visual result |
|---|---|---|---|---|
| `merchant_stone` | [`merchant_stone.glb`](../../assets/props/architecture/houses/merchant_stone/merchant_stone.glb), 3 storeys, limestone front, raised cellar neck, tile roof, 3,828 triangles; SHA-256 `973163027f55f8b6aa710f679f2dab45c7dba05407d9e6bc70b9eed679fa8947` | [`signoff_merchant_stone_day.png`](images/burgher_houses/signoff_merchant_stone_day.png) | [`signoff_merchant_stone_night.png`](images/burgher_houses/signoff_merchant_stone_night.png) | Pass: tallest narrow gable, strongest stone/portal/cellar read, restrained hatches and optional hoist remain legible. |
| `merchant_timber` | [`merchant_timber.glb`](../../assets/props/architecture/houses/merchant_timber/merchant_timber.glb), 2 storeys, timber frame with stone cellar base, shingle roof, 2,112 triangles; SHA-256 `ec35e038cafa12f6e25ec1ec7b06fb38ec3cd71d5c876553c123ae4477bfae16` | [`signoff_merchant_timber_day.png`](images/burgher_houses/signoff_merchant_timber_day.png) | [`signoff_merchant_timber_night.png`](images/burgher_houses/signoff_merchant_timber_night.png) | Pass: timber/plaster reads before stone, openings stay small, and the shingle roof separates from the stone tier. |
| `craft_boda` | [`craft_boda.glb`](../../assets/props/architecture/houses/craft_boda/craft_boda.glb), 1 storey, compact workshop dwelling, thatch roof, no hoist, 776 triangles; SHA-256 `01103b6bf98bfb5f5b54cef691471fd095585a4d391e8d40a74f55b7cf937b11` | [`signoff_craft_boda_day.png`](images/burgher_houses/signoff_craft_boda_day.png) | [`signoff_craft_boda_night.png`](images/burgher_houses/signoff_craft_boda_night.png) | Pass: footprint and height remain below both merchant tiers; no merchant hatch, crane, or landmark massing is visible. |
| Shared Lower Town route | Existing Godot P0-102 comparison capture with `merchant_stone`, `merchant_timber`, and `craft_boda` labels, route anchors, and material/roof families in the manifest | [`signoff_three_tier_route_day.png`](images/burgher_houses/signoff_three_tier_route_day.png) | [`signoff_three_tier_route_night.png`](images/burgher_houses/signoff_three_tier_route_night.png) | Pass for same-scale route context; individual tier plates above remain the primary closeout evidence. |

All eight sign-off images use the same 1280x720 output and gameplay orthographic size 33.75. The isolated GLB renders use a fixed three-quarter gameplay camera with a 1.45 m human scale marker; the shared route pair is copied byte-for-byte from the verified `p0_102_three_tier` packet. Night captures are intentionally low-key but retain foreground geometry and tier silhouette; they are a visual comparison aid, not a lighting-benchmark claim.

### Annotated R-003 decisions 1-10

| # | Final visual annotation | Evidence |
|---:|---|---|
| 1 | **PASS.** All three authored families present a street-facing gable with the ridge running into plot depth; the shared route camera confirms the same orientation convention. | Six isolated tier captures; shared route pair |
| 2 | **PASS.** Relative height is clear: three-storey `merchant_stone`, two-storey `merchant_timber`, and one-storey `craft_boda`; their frontage remains narrow rather than monumental. | Tier reports and day/night captures |
| 3 | **PASS at exterior-art boundary.** Portals, thresholds/cellar base, deep house envelopes, and rear-yard/service relationships are visible; internal diele/chimney/dornse room partitions are not claimed by exterior-only GLBs. | Isolated captures; production reports; A-008 rear-yard plates |
| 4 | **PASS.** Stone carries the strongest storage-hatch and hoist cue; timber remains restrained; craft *boda* has no hatch, hoist, or crane. | Tier generator reports and isolated captures |
| 5 | **PASS.** `merchant_stone` reads as limestone/mixed frontage with a portal, larger ground opening, raised cellar neck, and selective tile without clean all-over Gothic dressing. | Stone day/night captures; `report.json` |
| 6 | **PASS.** `merchant_timber` reads timber/plaster first, with small openings, a stone cellar base, and a shingle-forward roof. | Timber day/night captures; `report.json` |
| 7 | **PASS.** `craft_boda` remains the compact one-storey workshop-dwelling with a single-hearth implication and no merchant compound silhouette. | Boda day/night captures; `report.json` |
| 8 | **PASS.** Tile, shingle, and thatch remain distinct across the three families in both matched lighting conditions; the separation is carried by roof form/material response, not hue alone. | Six isolated captures; tier reports |
| 9 | **PASS for paired art evidence.** Existing A-008 rear-yard plates retain the gate/fence, water, fuel, and service-outbuilding relationships; the shared route pair confirms these families in the playable context. | A-008 rear-yard plates; shared route pair |
| 10 | **PASS.** No four-light crosses, blind niches, rich tracery, modern restaurant dressing, warlike/monumental massing, or landmark substitution appears in the three production kits. | Generator feature flags, triangle/dimension reports, and six isolated captures |

| Tier | Final art verdict | Required read | Boundary / amendment |
|---|---|---|---|
| `merchant_stone` | **Final visual pass** | Narrow 2-3 storey gable, strongest limestone or mixed-front read, cellar-neck/raised threshold, storage hatches, optional merchant hoist, selective tile | Hoist remains functional and optional. Do not add four-light crosses, blind niches, rich tracery, or universal stone frontage. |
| `merchant_timber` | **Final visual pass** | Timber or plastered-timber front, two typical storeys, smaller openings, restrained storage treatment, shingle bias, optional stone cellar | Do not make the hoist a default facade ornament. Do not copy a later stone Gothic skin or tile every roof. |
| `craft_boda` | **Final visual pass** | Compact one or two storeys, simple workshop-dwelling mass, modest openings, single-hearth implication, shared/minimal rear yard | Hoist, loading crane, granary treatment, hypocaust default, and landmark-scale massing remain rejected. |

## Historical A-009 review boundary (superseded by the capture packet above)

The original conditional-review boundary is retained as audit context. Its former reference-only assessment described the state before the production kits and gameplay captures landed; the current verdict and evidence are recorded in the packet and annotation tables above.

## Closeout record

The A-009 closeout evidence listed above is complete for visual art direction. The three kit rows remain responsible for runtime asset provenance and integration, while P2-067 remains responsible for Lower Town composition and P0-101 remains responsible for the broader ordinary-fabric/landmark acceptance. Those downstream rows must not be closed by this report alone.

- **P2-063 / R-209:** production `merchant_stone` kit evidence is present; retain runtime ownership and provenance review.
- **P2-064 / R-210:** production `merchant_timber` kit evidence is present; retain runtime ownership and provenance review.
- **P2-065 / R-211:** production `craft_boda` kit evidence is present; retain runtime ownership and provenance review.
- **P2-067 / R-213:** tier wiring and route composition remain downstream-owned.
- **P0-101 / R-108:** broader Lower Town ordinary-fabric and landmark acceptance remains downstream-owned.

The six A-008 plates remain documentation-only and are not runtime assets or archaeological proof.

## Sources

- [`burgher_house_art_brief.md`](burgher_house_art_brief.md) - A-008 tier matrix, confidence labels, plate pack, and non-runtime boundary.
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) - P0-163 closed tier allowlist and rejection rules.
- [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - R-003 Brief ship decisions 1-10 and confidence notes.

## R-541 ordinary-versus-exceptional boundary verification (2026-08-17, historical snapshot)

> Superseded for the visual-evidence question by the current A-009 closeout above. The original source and runtime findings below remain unchanged historical records.

**Task:** R-541 / P0-102 acceptance: verify ordinary versus exceptional boundary
**Parent:** R-110 / P0-102
**Snapshot:** `f65b5a829c6f0ae0ea0577b65fb783650b17e78a`
**Worktree:** shared worktree with unrelated staged, modified, and untracked WIP; no runtime, map, mesh, asset, or test source was changed by this verification.
**Implementation path note:** the allowlisted historical `scripts/map/view3d/map_view_burgher_house_models.gd` is absent in this checkout. The current tier selector is `scripts/map/view3d/map_view_mesh_builder_house_styles.gd`; the exceptional registry is `scripts/map/view3d/map_view_mesh_builder_building_registry.gd`, and the ordinary/exceptional dispatch is `scripts/map/view3d/map_view_mesh_builder_buildings.gd`.
**Decision:** **SOURCE/CONTRACT PASS; GAMEPLAY-SCALE ACCEPTANCE BLOCKED.**

This addendum is the signed R-541 verification note. It confirms the authored and compiled ordinary-tier boundary, records the focused runtime checks, and keeps the final visual/gameplay gate open where the required evidence is absent. It does not promote the existing A-009 conditional art-direction pass to final sign-off.

### Acceptance matrix

| R-541 requirement | Result | Evidence and classification |
|---|---|---|
| `merchant_stone`, `merchant_timber`, and `craft_boda` coexist in the playable Lower Town slice | **PASS at authored/compiled contract level; gameplay visual proof BLOCKED** | `content/maps/lower_town_slice.rrmap` authors 43 ordinary records: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`. `test_burgher_house_tiers` checks all 43 stable IDs and all three assignments. The map definition is used by the playable route tests, but no gameplay-scale frame is annotated to prove all three tiers in one view. |
| Tier selection is deterministic and does not collapse to one generic house family | **PASS** | `MapViewMeshBuilderHouseStyles` gives tier fallbacks of stone/tile, timber/shingle, and log/thatch-or-shingle while preserving authored material keys first. `test_burgher_house_tiers`: 5/5, including authored-material precedence, three wall texture variants, three roof texture variants, and stable weathering variation. |
| Ordinary modules do not assemble churches, gates, guild halls, or civic landmarks | **PASS at renderer-boundary level** | `MapViewMeshBuilderBuildingRegistry` explicitly classifies church, civic, institutional, guild, and gatehouse IDs/styles/primitives. `MapViewMeshBuilderBuildings.build_building()` dispatches registry-positive house records to `build_exceptional_building()` before the ordinary house path; exceptional roots carry `renderer_boundary=exceptional`, while ordinary roots carry `renderer_boundary=ordinary`. The focused test proves the church-vs-ordinary control and confirms that a wall record with a landmark-like ID remains outside the exceptional-house path. |
| Viru Gate remains exceptional fortification context rather than ordinary house assembly | **PASS** | `viru_gate_north_tower` and `viru_gate_south_tower` remain `kind=wall`, `round_tower=true` records. `test_environment_kit_integration`: 5/5, including no ordinary `Roof` on the towers, separate view-only gate arches, checkpoint route/anchor preservation, and deterministic view-only construction. |
| Stable IDs, route/parity, collision/navigation contracts | **PASS for checked authored contracts** | `test_lower_town_slice_map`: 19/19. The suite passes canonical parity, required route reachability, city-wall/Viru Gate opening, navigation-region construction, water exclusion, boundary transitions, and gate-arch/collision-jamb alignment. `test_environment_kit_integration`: 5/5 with unchanged map, terrain, transition, and patrol fingerprints. |
| No default late-Gothic or repeated Fachwerk shortcut | **PASS at source/contract level; visual review BLOCKED** | The closed typology contract rejects late-Gothic tourist facades, post-1400 four-light crosses, rich blind niches, and scaled ordinary houses used as landmarks. The ordinary structure path explicitly omits diagonal Fachwerk braces as non-characteristic for 1343 Reval. Tier-specific material and roof fallbacks prevent a single global late-Gothic/stone treatment. Gameplay-scale repetition, silhouette, and material readability remain unreviewed because the required tier-annotated route plates are missing. |
| Silhouette, occlusion, and gameplay-scale visual acceptance | **BLOCKED - evidence missing, no failure inferred** | The existing `lower_town_p0_101` packet has eight valid 1280x720 matched day/night route plates and proves capture capability, but its matrix leaves all three tier rows and repetition/silhouette rows pending. `docs/reports/images/burgher_houses/` contains no `signoff_*.png`; A-009 also records production tier GLBs and final gameplay sign-off as missing. No silhouette or occlusion failure was observed in the checked source/map contracts, but those checks are not established by the available images. |

### Focused verification commands and results

Run from the project root with Godot 4.7.1:

```sh
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT_LOG_DIR=/tmp/r541_checked

./tools/run_godot_checked.sh --require-test-summary \
  r541-burgher-house-tiers -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
# 1 file, 5 tests, 0 failures, 0 errors
# log: /tmp/r541_checked/r541-burgher-house-tiers.log

./tools/run_godot_checked.sh --require-test-summary \
  r541-environment-kit -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
# 1 file, 5 tests, 0 failures, 0 errors
# log: /tmp/r541_checked/r541-environment-kit.log

./tools/run_godot_checked.sh --require-test-summary \
  r541-lower-town-map -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
# 1 file, 19 tests, 0 failures, 0 errors
# log: /tmp/r541_checked/r541-lower-town-map.log

python3 tools/verify_p0_102_environment_kit_evidence.py
# P0-102 environment-kit evidence verification passed (8/8 plates)
```

The three Godot runs emitted only the known shutdown ObjectDB/resource cleanup diagnostics after reporting clean test summaries. Those diagnostics are not the R-541 decision. No assertion, parser, route, parity, stable-ID, or navigation failure was observed in the focused checks.

### Historical evidence boundary and closeout state

The eight `lower_town_p0_101` plates were valid capture artifacts at the 2026-08-17 snapshot, but were not sufficient R-541 tier acceptance at that time. The current A-009 packet above now supplies the missing six tier captures and shared route comparison; this historical statement is retained to explain the earlier decision and is not the current A-009 verdict.

### Historical verification signature

- **Verification performed by:** Codex, implementation/QA verification
- **Verification date:** 2026-08-17
- **Signed result:** source and renderer boundary verified; gameplay-scale acceptance was **BLOCKED at that snapshot** pending the R-6/P0-101 ordinary-fabric evidence gate.

## R-541 verification recheck (2026-08-21, historical snapshot)

> Superseded for the visual-evidence question by the current A-009 closeout above. The original parity and contract findings below remain unchanged historical records.

**Snapshot:** live shared worktree; unrelated staged, modified, and untracked WIP was preserved.
**Decision:** **SOURCE/CONTRACT PASS; GAMEPLAY-SCALE ACCEPTANCE BLOCKED.**

The verification was rerun without changing runtime, map, mesh, asset, or test source. Focused results:

| Check | Result | Evidence |
|---|---|---|
| Ordinary tier assignments and renderer boundary | **PASS** | `test_burgher_house_tiers`: 5/5. All 43 authored ordinary IDs remain assigned across `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=15`; exceptional/special IDs remain untiered; tier fallback, authored-material precedence, wall/roof texture variation, deterministic weathering, and exceptional registry dispatch pass. |
| Shared environment-kit exceptional boundary | **PASS** | `test_environment_kit_integration`: 5/5. Viru towers remain wall/fortification records without an ordinary roof, gate arches remain separate view landmarks, and view-only construction preserves routes and fingerprints. |
| Lower Town map route/parity contract | **BLOCKED by existing fixture drift** | `test_lower_town_slice_map`: 18/19 passed. The sole failure is `test_lower_town_slice_matches_canonical_parity_fixture` because `walkability_sha256` differs from the tracked fixture. This verification did not regenerate the fixture or attribute the drift to tier wiring. |
| Existing P0-102 day/night evidence packet | **PASS for packet integrity; insufficient for R-541** | `python3 tools/verify_p0_102_environment_kit_evidence.py`: 8/8 plates. These four-space plates do not show all three ordinary house tiers together and are not promoted to tier sign-off evidence. |
| Gameplay-scale visual/art acceptance | **BLOCKED** | A-009 remains conditional: no `docs/reports/images/burgher_houses/signoff_*.png` tier plates or shared route comparison are present. R-6 remains the owner of the final day/night annotations against R-003 decisions 1-10. |

The 2026-08-21 recheck correctly found that the visual packet was still absent at that time. The current A-009 packet above now supplies that evidence; the historical parity fixture drift remains a separate downstream map concern and was not regenerated here.

**Historical closeout:** R-541 remained open at this snapshot pending the visual packet. Do not weaken thresholds or regenerate parity from this historical verification.

- **Rechecked by:** Codex, implementation/QA verification
- **Recheck date:** 2026-08-21
- **Signed result:** source and renderer boundary remained verified; final gameplay-scale acceptance was **BLOCKED at that snapshot**.
