# P0-102 Acceptance Reconciliation

**Task:** R-668 / P0-102 decomposition: reconcile complete acceptance evidence
**Parent:** R-110 / P0-102
**Reconciliation date:** 2026-08-22
**Live revision:** `63e143498cd4756e0b4f37e377ce5a43f0523327` (`Add three-tier Lower Town gameplay evidence`)
**Live worktree:** shared dirty worktree; `git status --short` reports 275 path entries, including unrelated staged, unstaged, and untracked WIP
**Decision:** **BLOCKED - R-110 / P0-102 remains `todo`**

## Scope and decision rule

This report reconciles every requirement in the R-110 deliverable and verify text against the current evidence packet. It distinguishes four kinds of evidence:

1. **Source or structural evidence** proves IDs, wiring, renderer ownership, or a contract test.
2. **Scoped runtime evidence** proves the exact command result in the named snapshot and worktree.
3. **Gameplay evidence** proves that a route or surface was captured, but does not automatically prove visual quality.
4. **Human historical/art acceptance** requires named observations and cannot be inferred from metadata, source counts, or a green automated test.

The live worktree is not a clean acceptance checkout. Clean-baseline results below use the detached evidence recorded by R-666: base revision `981ecaa3c3ecbf1974255ef4ec3efd870dfe64be` plus the four-file elevation handoff patch `/tmp/r666-elevation.patch` (SHA-256 `51db7fd87da85836cfc9bb965141a89a1481d101aad21913b40270a3293adfef`). The R-667 gameplay capture was produced at source `HEAD=5236487ff56a7c92f440758e92b90b97c5123153` in a dirty shared worktree and is therefore evidence of the captured packet, not a synchronized clean-parent run.

The decision rule is fail-closed: a passing subordinate contract, valid PNG, or source inventory does not waive a failed clean gate, missing production handoff, missing route/parity result, or missing human review.

## Board and evidence snapshot

| Item | Current status / revision | Acceptance interpretation |
|---|---|---|
| R-110 / P0-102 | `todo` | Parent remains open; this report does not move its status. |
| R-539 shared module acceptance | `in_review` | Four-space contract evidence exists; current Lower Town parity result is 18/19, not a clean parity PASS. |
| R-541 ordinary/exceptional boundary | `in_review` | Source and renderer boundary pass; gameplay-scale visual acceptance remains blocked. |
| R-542 shared module contract and coverage | `in_progress` | Do not promote its partial work to a completed parent gate. |
| R-557 asset and visual acceptance audit | `in_review` | Scoped asset/evidence findings exist; its result is not a clean synchronized parent run. |
| R-666 clean regression after elevation handoff | `in_review` | Elevation parser test is green; checked clean import and full matrix remain blocked. |
| R-667 three-tier gameplay capture | `in_review` | Two matched plates and manifest are valid packet evidence; visual/art sign-off remains open. |
| R-668 this report | `in_progress` at start | Reconciled below as a deterministic BLOCKED report. |

## R-110 requirement matrix

| R-110 requirement | Current artifact and command result | Verdict | Owner for every gap |
|---|---|---|---|
| Four slice spaces use shared modules without bespoke camera, scale, or material exceptions | [`p0_102f_environment_kit_integration.md`](p0_102f_environment_kit_integration.md) records `test_environment_kit_integration` 5/5 and the shared modules `forge_interior`, `forge_yard`, `street_well`, `brewery`, and `checkpoint`. R-666 records the same isolated assertions at 5/5, but the checked runner exits 1 because the clean snapshot emits missing shared-character shader preloads. | **BLOCKED for parent acceptance; structural coverage present** | R-542 owns the shared-module coverage recheck. R-122 and R-124 own the missing clean-base eye/hair shader assets that make the checked import/runtime gate red. |
| Historically grounded ordinary families and R-003 tiers `merchant_stone`, `merchant_timber`, and `craft_boda` coexist on the route | R-667 manifest records all three labels, four stable ordinary IDs, limestone/plaster/log materials, and tile/shingle/thatch roofs. The two 1280x720 plates exist and share one framing key. `test_burgher_house_tiers` is recorded as 5/5. This is source/metadata plus packet evidence, not human visual interpretation or complete production-kit acceptance. | **BLOCKED for final ordinary-fabric acceptance** | R-209 and R-211 remain in progress for their production kits; R-210 is done but its downstream visual acceptance is not inferred here. R-212 owns plot dressing; R-612 owns independent ordinary-fabric verification; R-638 owns historical/art sign-off. |
| Varied footprints, heights, gables, doors, windows, chimneys, roofs, fences/gates, drainage, carts, barrels, crates, signs, workshops, yards, vegetation, and worn material variants are accepted | Shared renderer/material paths and `test_building_surface_weathering` / `test_map_view_material_resolution` provide implementation evidence. R-666 reports asset lint PASS and isolated environment/fortification assertions PASS, but clean checked import is blocked; no synchronized visual matrix proves every family. Plot-dressing provenance is also red. | **PARTIAL / BLOCKED** | R-542 owns shared-kit coverage; R-212 owns plot/threshold dressing; R-641 owns repository provenance reconciliation; R-612 and R-638 own downstream visual review. |
| Exceptional churches, guild halls, gates, and civic buildings remain outside the ordinary-house path | [`p0_102_exceptional_boundary_reconciliation.md`](p0_102_exceptional_boundary_reconciliation.md) and `test_burgher_house_tiers`/`test_environment_kit_integration` record structural separation, Viru towers as `kind=wall`, and separate gate-arch landmarks. R-666 reports `test_map_view_3d_fortification` 8/8 assertions but checked status 1 because of shader diagnostics. | **STRUCTURAL PASS; acceptance BLOCKED** | R-541 owns the ordinary/exceptional verification boundary; R-613 and R-638 own final landmark and historical/art acceptance. |
| Every module passes asset lint, provenance, pivot, scale, collision, navigation, route, and parity checks | R-666: asset lint PASS; `test_map_rrmap_parser` 16/16; environment assertions 5/5; fortification assertions 8/8; Lower Town 19 tests with one parity failure; provenance BLOCKED by ten plot-dressing albedo rows. The clean checked import remains red. R-539 independently records 18/19 Lower Town tests with the canonical parity mismatch. | **BLOCKED** | R-122/R-124 own clean import shader assets; R-547 owns authored layout; R-552 owns route/navigation/parity verification; R-641 owns provenance. |
| Day/night readability is proven, including the required three-tier gameplay capture | The dedicated environment packet passes 8/8 file-integrity checks through `verify_p0_102_environment_kit_evidence.py`. R-667 adds `three_tier_route_day.png`, `three_tier_route_night.png`, and `capture_manifest.json`; both plates are non-blank, matched, and 1280x720. R-667 explicitly states that wall/roof readability and human review remain open. | **BLOCKED for visual acceptance; packet integrity PASS** | R-667 owns capture packet integrity; R-612 and R-638 own ordinary and human visual acceptance; R-613 owns exceptional landmark review. |

## Detailed acceptance evidence

### 1. Shared four-space module assembly

The source and integration contract covers the required spaces and stable interfaces:

- Forge: `kalev_smithy`, `smithy_door`, `door_courtyard`, `anvil`, `ledger`, `bed_alcove`.
- Street/well: `cistern`, `cistern_wash_tub`, `monastery_well`, `street_start`, `checkpoint_east`.
- Brewery: `foaming_mug_brewery`, `brewery_door`, `brewery_keg_stack`, `brewery_malt_sacks`, `evidence_barrels`.
- Checkpoint: `checkpoint_west`, `checkpoint_east`, `viru_gate_north_tower`, `viru_gate_south_tower`, `viru_gate_arch`, `viru_foregate_arch`, `viru_road_boundary`, `viru_watch`, `iron_convoy`.

R-539's live scoped run records `test_environment_kit_integration` 5/5 and `test_kalev_smithy_map` 16/16. The same report records `test_lower_town_slice_map` 18/19 because the canonical parity fixture does not match the dirty authored map. R-666's detached post-elevation handoff reports 5/5 environment assertions, but the checked runner rejects the run due to missing `eye_material.gdshader` and `hair_material.gdshader` in the clean base. Therefore the module contract is structurally present but not a clean-parent acceptance PASS.

### 2. Materials, wear, props, and geometry safety

The shared contract and historical acceptance packet cover the intended families:

- Walls: log, plank, plaster/plastered timber, and limestone.
- Roofs: tile, shingle, and thatch.
- Local presentation: deterministic worn, fresh, damp, repaired, soot, grime, mud, and wet-threshold cues.
- Space dressing: workshop tools/fuel, wells/wash tubs, brewery storage, carts/stalls/signs, fences, drainage, and route-facing ground transitions.

`test_map_view_material_resolution` is recorded as 7/7 in R-666. `test_environment_kit_integration` and `test_building_surface_weathering` provide structural and deterministic material evidence. These checks do not prove that every material/wear family is visually legible at gameplay distance, and they do not prove the downstream plot-dressing kit. R-666's provenance run names ten missing active plot-dressing albedo rows owned by R-212/R-641. No new P0-102 asset or manifest fix is claimed here.

Pivot, scale, collision, and navigation are treated as separate contracts. The environment integration fixture asserts shared cell scale, view-only construction, unchanged fingerprints, route/anchor preservation, and no view-authored collision/navigation nodes. The clean checked runtime is still blocked by R-122/R-124 shader preloads, and Lower Town parity is red under R-547/R-552 ownership, so these assertions are not promoted to the complete R-110 gate.

### 3. Ordinary versus exceptional boundary

The current registry and builder routing provide the required implementation boundary:

- Registry-positive house records use the exceptional builder and carry `renderer_boundary=exceptional`.
- Ordinary records use the shared wall/roof/facade/chimney path and carry `renderer_boundary=ordinary`.
- Viru Gate towers remain `kind=wall` records and are not converted into ordinary houses.
- `viru_gate_arch` and `viru_foregate_arch` remain view-only gate landmarks rather than ordinary buildings.
- Ordinary tier metadata must not turn churches, civic buildings, guild halls, institutions, or gates into ordinary-kit coverage.

This is a structural PASS only. R-638 states that all required non-ordinary rows remain blocked because there is no named human canon/art reviewer and no stable-ID-linked visual observation for each required landmark. R-613/R-638 own that missing acceptance; R-541 owns the boundary verification and must not be broadened into landmark art approval.

### 4. Three-tier gameplay evidence boundary

R-667 is the current dedicated three-tier packet:

- Day: [`three_tier_route_day.png`](images/p0_102_three_tier/three_tier_route_day.png)
- Night: [`three_tier_route_night.png`](images/p0_102_three_tier/three_tier_route_night.png)
- Metadata: [`capture_manifest.json`](images/p0_102_three_tier/capture_manifest.json)

The packet records route `checkpoint_west -> brewery_door` on `merchant_craft_lane`, gameplay orthographic size `33.75`, pitch `-30`, yaw `45`, and stable IDs `kaik_house_west`, `viru_house_west`, `sauna_corner_house`, and `saddlers_rear_workshop`. It also records all three tier labels and separates `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch` from ordinary coverage.

The packet is valid evidence that the capture helper wrote the intended matched files and metadata. It does not independently prove that each tier is visually distinguishable, that materials/roofs/wear read at gameplay scale, or that the exceptional silhouettes pass human historical/art review. R-612 and R-638 explicitly require those observations, while R-667 records them as open.

The older four-space packet is also valid but is not a substitute:

- Forge: [`forge_day.png`](images/p0_102_environment_kit/forge_day.png), [`forge_night.png`](images/p0_102_environment_kit/forge_night.png)
- Street/well: [`street_well_day.png`](images/p0_102_environment_kit/street_well_day.png), [`street_well_night.png`](images/p0_102_environment_kit/street_well_night.png)
- Brewery: [`brewery_day.png`](images/p0_102_environment_kit/brewery_day.png), [`brewery_night.png`](images/p0_102_environment_kit/brewery_night.png)
- Checkpoint: [`checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png), [`checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png)

`verify_p0_102_environment_kit_evidence.py` reports 8/8 valid pairs, but those plates prove the four environment spaces, not the R-110 requirement for three ordinary tiers in one gameplay comparison.

### 5. Clean-baseline versus live-worktree comparison

| Evidence state | Revision / workspace | Result | What may be claimed |
|---|---|---|---|
| Live worktree | `63e1434`; 275 dirty path entries | Current source and board context only | Useful for locating current artifacts; not a clean runtime acceptance result. |
| R-666 detached base plus scoped elevation patch | Base `981ecaa`; `/tmp/r666-elevation.patch` | Parser 16/16; asset lint PASS; clean checked import BLOCKED by R-122/R-124; Lower Town 18/19 equivalent with one parity mismatch; provenance BLOCKED by ten plot-dressing rows | Elevation parser handoff is available in this evidence snapshot; parent runtime gate is not green. |
| R-667 capture source | `5236487`; dirty shared worktree | Two matched non-blank plates and manifest | Capture packet integrity and declared metadata only; no human visual sign-off. |

The clean and live results must not be merged into a synthetic all-green result. The live tree contains active WIP, while the detached R-666 snapshot is not the current full `HEAD` and intentionally applies only the scoped elevation handoff. A future parent closeout needs one synchronized clean checkout after the named owners land their fixes and handoffs.

## Verification commands and recorded results

The following commands are the authoritative reproductions from the prerequisite reports. They are listed with their result boundary rather than reclassified as a new run from the dirty worktree.

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

# R-666 clean import and parser/runtime checks
GODOT_LOG_DIR=/tmp/r666_checked \
  /tmp/rebel-reval-r666-20260822/tools/run_godot_checked.sh \
  --require-test-summary r666-clean-import-checked -- \
  "$GODOT_BIN" --headless --path /tmp/rebel-reval-r666-20260822 \
  --editor --import --quit
# BLOCKED: missing eye_material.gdshader and hair_material.gdshader; owners R-122/R-124

"$GODOT_BIN" --headless --path /tmp/rebel-reval-r666-20260822 \
  --script tools/run_godot_tests.gd -- --filter=test_map_rrmap_parser
# PASS: 16 tests, 0 failures, 0 errors

# R-666 scoped acceptance summaries
"$GODOT_BIN" --headless --path /tmp/rebel-reval-r666-20260822 \
  --script tools/run_godot_tests.gd -- --filter=test_environment_kit_integration
# Assertions: 5/5; checked status remains blocked by shader diagnostics

"$GODOT_BIN" --headless --path /tmp/rebel-reval-r666-20260822 \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
# BLOCKED: 19 tests, 1 parity failure, 0 test errors; owner R-547/R-552

"$GODOT_BIN" --headless --path /tmp/rebel-reval-r666-20260822 \
  --script tools/run_godot_tests.gd -- --filter=test_map_view_3d_fortification
# Assertions: 8/8; checked status remains blocked by shader diagnostics

python3 /tmp/rebel-reval-r666-20260822/tools/verify_asset_lint.py
# PASS

python3 /tmp/rebel-reval-r666-20260822/tools/validate_asset_sources.py
# BLOCKED: ten plot-dressing albedo sidecars without manifest rows; owners R-212/R-641

# Evidence packet checks
python3 tools/verify_p0_102_environment_kit_evidence.py
# PASS: 8/8 environment-kit plates
```

R-667 additionally records the non-headless capture command and verifies both three-tier PNGs as 1280x720, non-flat, and matched by `framing_key`. That result is retained as packet integrity evidence and not promoted to final visual acceptance.

## Ownership and no-unowned-blocker check

| Blocking finding | Owning board ref(s) | Required next action |
|---|---|---|
| Missing clean-base eye/hair shader preloads | R-122, R-124 | Land the shader assets and rerun checked clean import and the full P0-102 matrix. |
| Lower Town parity fixture mismatch | R-547, R-552 | Review the authored layout/canonical diff and reconcile the fixture under the owning map/parity contract; do not refresh it from this report. |
| Ten plot-dressing albedo sidecars absent from `assets/SOURCES.csv` | R-212, R-641 | Complete the plot-dressing handoff and provenance reconciliation, then rerun the provenance validator from clean `HEAD`. |
| Ordinary production-kit and plot-dressing acceptance | R-209, R-211, R-212; R-210 is done | Complete the remaining production/dressing handoffs and retain R-210's delivered result in the synchronized visual/provenance rerun. |
| Ordinary gameplay readability and repeated-material review | R-612, R-638 | Annotate visible stable IDs and R-003 rules in matched day/night gameplay frames; obtain named human art/canon observations. |
| Exceptional landmark gameplay/historical/art acceptance | R-613, R-638 | Review each required exceptional ID, including St. Catherine's and the Viru/foregate state, with named human approval or an owned amendment. |
| Shared module acceptance reconciliation | R-539, R-542, R-557 | Rerun the synchronized clean matrix after the current baseline and downstream handoffs are complete. |
| Parent closeout | R-544, R-669, R-110 | Keep R-110 `todo`; perform the final independent verification only after all parent rows are green. |

Every current blocker has an existing board owner. No duplicate follow-up task is created by R-668.

## Final decision

**BLOCKED. R-110 / P0-102 is not READY and remains `todo`.**

The following facts are accepted only at their stated boundary:

- Shared four-space module structure is present and has green isolated assertion summaries.
- The ordinary/exceptional renderer boundary is structurally present.
- The elevation parser handoff is green in the scoped 16-test parser suite.
- Asset lint and the dedicated eight-plate environment evidence pass in the R-666 snapshot.
- The R-667 three-tier packet is present, matched, non-blank, and metadata-valid.

The parent cannot advance because:

1. the clean checked import/runtime gate is blocked by missing R-122/R-124 shader assets;
2. Lower Town route/parity has an independent fixture mismatch owned by R-547/R-552;
3. provenance has ten active plot-dressing sidecars without manifest rows owned by R-212/R-641;
4. ordinary production handoffs and final ordinary-fabric review remain open under R-209/R-211/R-212 and R-612; R-210 is done but its delivered result still requires synchronized visual/provenance acceptance;
5. exceptional landmark historical/art review remains unproven under R-613/R-638; and
6. R-667 explicitly provides capture integrity, not the human visual sign-off required by R-110.

R-110 may be reconsidered only after the named owners land their work and one synchronized clean snapshot reruns import, parser, shared module integration, materials/wear, geometry safety, route/parity, asset lint, provenance, exceptional boundary, and both environment plus three-tier gameplay evidence gates. No downstream P0-101 result is claimed as P0-102 completion evidence.

## Source links

- [`p0_102_environment_kit_contract.md`](p0_102_environment_kit_contract.md)
- [`p0_102f_environment_kit_integration.md`](p0_102f_environment_kit_integration.md)
- [`p0_102_environment_kit_acceptance.md`](p0_102_environment_kit_acceptance.md)
- [`p0_102_scope_ledger.md`](p0_102_scope_ledger.md)
- [`p0_102_exceptional_boundary_reconciliation.md`](p0_102_exceptional_boundary_reconciliation.md)
- [`p0_102_clean_elevation_recheck.md`](p0_102_clean_elevation_recheck.md)
- [`p0_102_three_tier_gameplay_capture.md`](p0_102_three_tier_gameplay_capture.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md)
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`p0_102l_environment_kit_closeout.md`](p0_102l_environment_kit_closeout.md)
- [`p0_102m_environment_kit_day_night.md`](p0_102m_environment_kit_day_night.md)
- [`images/p0_102_three_tier/three_tier_route_day.png`](images/p0_102_three_tier/three_tier_route_day.png)
- [`images/p0_102_three_tier/three_tier_route_night.png`](images/p0_102_three_tier/three_tier_route_night.png)
- [`images/p0_102_three_tier/capture_manifest.json`](images/p0_102_three_tier/capture_manifest.json)
- [`images/p0_102_environment_kit/forge_day.png`](images/p0_102_environment_kit/forge_day.png)
- [`images/p0_102_environment_kit/forge_night.png`](images/p0_102_environment_kit/forge_night.png)
- [`images/p0_102_environment_kit/street_well_day.png`](images/p0_102_environment_kit/street_well_day.png)
- [`images/p0_102_environment_kit/street_well_night.png`](images/p0_102_environment_kit/street_well_night.png)
- [`images/p0_102_environment_kit/brewery_day.png`](images/p0_102_environment_kit/brewery_day.png)
- [`images/p0_102_environment_kit/brewery_night.png`](images/p0_102_environment_kit/brewery_night.png)
- [`images/p0_102_environment_kit/checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png)
- [`images/p0_102_environment_kit/checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png)

**Final status:** **BLOCKED - no unowned blocker; keep R-110 / P0-102 `todo`.**
