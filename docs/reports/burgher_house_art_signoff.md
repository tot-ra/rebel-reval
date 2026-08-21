# A-009 Lower Town burgher-house art sign-off

**Review date:** 2026-08-02
**Historical target:** Spring 1343 Reval, Lower Town
**Task:** A-009 / R-6
**Inputs:** A-008 reference pack, R-003 `burgher-house-plan.md`, and P0-163 `house_tier` contract

## Decision

**CONDITIONAL ART-DIRECTION PASS; FINAL GAMEPLAY SIGN-OFF BLOCKED.**

The six A-008 synthetic reference plates establish a coherent visual target for the three closed ordinary-house tiers. They support the required Spring 1343 massing and material direction, and they reject late-Gothic tourist-facade defaults. They do **not** prove that production GLBs exist, that the tiers are wired into a playable route, or that the families remain readable under matched gameplay-scale day/night lighting.

A-009 must therefore remain open for final acceptance until the downstream authored kits and capture evidence are available. This report records the art decision boundary rather than treating documentation-only studies as runtime or archaeological evidence.

## Evidence inventory

| Evidence | Result | Review note |
|---|---|---|
| `reference_merchant_stone_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_stone_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_merchant_timber_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_merchant_timber_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| `reference_craft_boda_street_gable.png` | Present | 1200x800 synthetic Blender street-gable study |
| `reference_craft_boda_rear_yard.png` | Present | 1200x800 synthetic Blender rear-yard study |
| Production house GLBs for the three tiers | Missing | Owned by P2-063, P2-064, and P2-065, all currently open |
| `signoff_*.png` gameplay-scale day/night captures | Missing | No final day/night evidence exists for this A-009 review |
| Runtime registration in `assets/SOURCES.csv` | Correctly absent | A-008 plates remain documentation-only and are not runtime assets |

## Tier review

| Tier | Provisional art verdict | Required read | Boundary / amendment |
|---|---|---|---|
| `merchant_stone` | Pass as a reference target | Narrow 2-3 storey gable, strongest limestone or mixed-front read, cellar-neck/raised threshold, storage hatches, optional merchant hoist, selective tile | Hoist remains functional and optional. Do not add four-light crosses, blind niches, rich tracery, or universal stone frontage. |
| `merchant_timber` | Pass as a reference target | Timber or plastered-timber front, two typical storeys, smaller openings, restrained storage treatment, shingle bias, optional stone cellar | Do not make the hoist a default facade ornament. Do not copy a later stone Gothic skin or tile every roof. |
| `craft_boda` | Pass as a reference target | Compact one or two storeys, simple workshop-dwelling mass, modest openings, single-hearth implication, shared/minimal rear yard | Hoist, loading crane, granary treatment, hypocaust default, and landmark-scale massing remain rejected. |

## R-003 Brief ship-decision review

| # | Decision | A-009 reference verdict | Final-capture requirement |
|---:|---|---|---|
| 1 | Gable end faces the street and ridge runs perpendicular to the lane | **Pass in reference pack** | Confirm in gameplay camera for all three production families. |
| 2 | Merchant fronts default to 2-3 storeys; *boda* stays at 1-2 storeys | **Pass in tier separation** | Confirm relative height and silhouette separation in one shared route capture. |
| 3 | Street-to-yard sequence reads as cellar neck/threshold, diele, chimney-kitchen zone, dornse, and rear yard | **Partially evidenced** | Reference plates show exterior intent only; gameplay or cutaway evidence must confirm no oversized landmark-like volume. |
| 4 | Merchant upper levels read as storage/loading, with hatches rather than domestic window walls | **Pass for `merchant_stone`; restrained for `merchant_timber`** | Confirm authored hatch/hoist combinations and ensure `craft_boda` has none. |
| 5 | `merchant_stone` carries limestone or mixed frontage, portal, larger ground opening, cellar, and selective tile | **Pass as target** | Confirm material response at day and night; reject all-over clean stone or tourist ornament. |
| 6 | `merchant_timber` carries timber/plaster, small openings, and shingle/thatch bias | **Pass as target** | Confirm timber remains visually primary at gameplay distance and does not collapse into stone Gothic. |
| 7 | `craft_boda` remains a compact two-room workshop-dwelling | **Pass as target** | Confirm footprint and height stay below merchant tiers; no merchant crane or granary silhouette. |
| 8 | Roof covers vary by wealth and ward: selective tile, ordinary shingle/thatch | **Pass as material rule** | Matched day/night plates must retain roof-band separation without relying on hue alone. |
| 9 | Rear yards read as working service space, not empty garden plazas | **Pass in paired rear-yard studies** | Confirm gate/fence, water point, fuel, and modest outbuilding relationships in gameplay-scale views. |
| 10 | Ordinary houses must not become post-1400 tourist Gothic monuments or scaled-up landmarks | **Pass as explicit rejection rule** | Final review must include a negative check for four-light crosses, blind niches, rich tracery, monumental width, and landmark substitution. |

## Required closeout evidence

A-009 can move from conditional review to final art acceptance only when all of the following are attached under this report's allowed evidence boundary:

1. A production-ready `merchant_stone` GLB and gameplay-scale day/night capture.
2. A production-ready `merchant_timber` GLB and gameplay-scale day/night capture.
3. A production-ready `craft_boda` GLB and gameplay-scale day/night capture.
4. A shared gameplay route or comparison plate where all three tiers are visible at the same camera scale.
5. An annotation for each capture against the ten R-003 decisions above.
6. Confirmation that runtime assets, if later shipped, are owned and registered by P2-063 through P2-067 rather than by this documentation-only review.

## Open blockers and ownership

- **P2-063 / R-209:** author and verify `merchant_stone` production kit.
- **P2-064 / R-210:** author and verify `merchant_timber` production kit.
- **P2-065 / R-211:** author and verify `craft_boda` production kit.
- **P2-067 / R-213:** wire the tier families into Lower Town route composition.
- **P0-101 / R-108:** perform the final ordinary-fabric and landmark gameplay-scale day/night acceptance after the dependencies land.

No new follow-up task is created here because each blocker already has an owning board row. The six A-008 plates remain non-runtime documentation and must not be used to close those production or gameplay gates.

## Sources

- [`burgher_house_art_brief.md`](burgher_house_art_brief.md) - A-008 tier matrix, confidence labels, plate pack, and non-runtime boundary.
- [`burgher_house_typology_contract.md`](burgher_house_typology_contract.md) - P0-163 closed tier allowlist and rejection rules.
- [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - R-003 Brief ship decisions 1-10 and confidence notes.

## R-541 ordinary-versus-exceptional boundary verification (2026-08-17)

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

### Evidence boundary and required closeout

The eight `lower_town_p0_101` plates are valid capture artifacts, not sufficient R-541 tier acceptance. They cover four route poses in day/night pairs, but the capture matrix explicitly marks `merchant_stone`, `merchant_timber`, `craft_boda`, repeated frontage, roof readability, and localized wear rows as pending. The A-009 decision remains **CONDITIONAL ART-DIRECTION PASS; FINAL GAMEPLAY SIGN-OFF BLOCKED**.

R-541 therefore remains in review rather than being treated as a gameplay acceptance pass. Closeout requires a matched gameplay-scale route or comparison capture with all three tiers visible at the same camera scale, annotations against the R-003 decisions, and a human review of silhouette, repetition, roof/material hierarchy, localized wear, landmark separation, and occlusion. Existing route, parity, and navigation passes must be retained when that evidence is captured.

### Verification signature

- **Verification performed by:** Codex, implementation/QA verification
- **Verification date:** 2026-08-17
- **Signed result:** source and renderer boundary verified; final gameplay-scale acceptance **BLOCKED** pending the R-6/P0-101 ordinary-fabric evidence gate.

## R-541 verification recheck (2026-08-21)

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

The lower-town parity failure is an existing acceptance input problem, not a source-contract failure in R-541. The saved checked-runner log is `/tmp/rebel-reval-r541-20260821/r541-lower-town-map-20260821.log`; it reports no parser or test errors and identifies only the canonical walkability hash mismatch. R-213 is already `done` and R-353 is already `done`; the remaining R-541 closeout boundary is the missing human/gameplay visual packet owned by R-6/P0-101.

**Current closeout:** keep R-541 open/in progress until a gameplay-scale comparison capture shows all three tiers at one camera scale, with annotations for silhouette, facade/roof/material hierarchy, localized wear, landmark separation, repetition, and occlusion. Do not weaken thresholds or regenerate parity from this verification.

- **Rechecked by:** Codex, implementation/QA verification
- **Recheck date:** 2026-08-21
- **Signed result:** source and renderer boundary remains verified; final gameplay-scale acceptance remains **BLOCKED**.
