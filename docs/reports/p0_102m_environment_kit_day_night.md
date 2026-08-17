# P0-102m Environment Kit Day/Night Reconciliation

**Task:** R-543
**Parent:** R-110 / P0-102
**Recorded:** 2026-08-17
**Source snapshot:** `72563b7d` (`Document P0-040 lighting and material style lock`); shared worktree remains dirty
**Decision:** **BLOCKED / PARTIAL - evidence packet reconciled, parent closeout not approved**

## Scope and decision

This is the narrow R-543 reconciliation of the dedicated P0-102 environment-kit evidence. The acceptance surface is four target spaces - forge, street/well, brewery, and checkpoint - with one matched gameplay-camera day/night pair per space. The task wording mentions six combinations, but the canonical P0-102 verifier and acceptance contract require eight plates (four spaces x two lighting states); this report follows the canonical eight-plate contract.

The dedicated environment-kit packet is valid for file integrity, matched framing, route/interactable context, and the four shared module crops. It does **not** prove the separate P0-101 ordinary-fabric visual gate: no accepted gameplay-camera pair shows `merchant_stone`, `merchant_timber`, and `craft_boda` together with tier-specific material, roof, wear, silhouette, and repetition review. Documentation-only burgher-house reference plates are not promoted to gameplay evidence.

## Matched evidence matrix

| Space / module | Day plate | Night plate | Map | Matched framing | Visible module, route, and interactable coverage | Result |
|---|---|---|---|---|---|---|
| Forge (`forge_interior` / `forge_yard`) | [`forge_day.png`](images/p0_102_environment_kit/forge_day.png) | [`forge_night.png`](images/p0_102_environment_kit/forge_night.png) | `kalev_smithy` | 1280x720; orthographic size 13.5; focus cell `(17.5, 7.0)`; focus height `0.8` | Furnace/anvil work area, player approach, courtyard door, and local forge wear context | **VALID PAIR** |
| Street/well (`street_well`) | [`street_well_day.png`](images/p0_102_environment_kit/street_well_day.png) | [`street_well_night.png`](images/p0_102_environment_kit/street_well_night.png) | `lower_town_slice` | 1280x720; orthographic size 17.5; focus cell `(104.0, 60.5)`; focus height `0.8` | Cistern, wash tub, wet threshold, surrounding street surface, and approach toward `street_start`; the separate `monastery_well` is outside this crop | **VALID PAIR** |
| Brewery (`brewery`) | [`brewery_day.png`](images/p0_102_environment_kit/brewery_day.png) | [`brewery_night.png`](images/p0_102_environment_kit/brewery_night.png) | `lower_town_slice` | 1280x720; orthographic size 17.5; focus cell `(80.5, 68.5)`; focus height `0.8` | `foaming_mug_brewery`, `brewery_door`, keg stack, malt sacks, evidence barrels, and player approach lane | **VALID PAIR** |
| Checkpoint (`checkpoint`) | [`checkpoint_day.png`](images/p0_102_environment_kit/checkpoint_day.png) | [`checkpoint_night.png`](images/p0_102_environment_kit/checkpoint_night.png) | `lower_town_slice` | 1280x720; orthographic size 17.5; focus cell `(117.5, 55.5)`; focus height `0.8` | `viru_gate_arch`, both Viru towers, `gate_cart`, approach lane, and `viru_foregate_arch` context | **VALID PAIR** |

The paired rows use identical camera/framing metadata within each space. Day and night differ by the authored lighting state, not by a camera or map substitution. The night plates retain readable geometry and lighting variation rather than becoming blank or flat.

## Coverage interpretation

| Acceptance dimension | Reconciled result | Boundary |
|---|---|---|
| Dedicated space/time files | **PASS - 8/8** | All eight expected files exist and are linked exactly once from the parent acceptance report. |
| Image integrity | **PASS** | Every plate decodes as an RGB PNG at 1280x720 with non-flat luminance; each day/night pair has different image bytes. |
| Shared module and route context | **PASS for evidence context** | The matrix identifies the four target modules and preserves the authored approach/door/interactable context described by the capture rows. This is not a substitute for the clean runtime matrix. |
| Material and wear readability | **PARTIAL - reviewable evidence, not human sign-off** | The crops include the authored wall/roof/ground and local wear contexts for each module. The file verifier cannot certify historical silhouette quality, fine material hierarchy, or repetition limits. |
| Ordinary tier coexistence | **BLOCKED - evidence missing** | `merchant_stone`, `merchant_timber`, and `craft_boda` source counts and contract tests are not gameplay-camera visual proof. The required tier-annotated day/night rows remain pending in the P0-101 capture matrix. |
| Exceptional landmark acceptance | **BLOCKED - separate owner** | Checkpoint plates preserve gate/tower context, but do not close the P0-101 historical/art sign-off or the independent fortification review. |
| Clean parent/runtime acceptance | **BLOCKED - separate baseline** | R-540 records the clean `elevation_area` / `elevation_ramp` parser cascade. This evidence-only task does not repair or waive that blocker. |

## Missing and invalid evidence treatment

No P0-102 environment-kit plate is missing or invalid in the dedicated set. The following items remain explicitly **not accepted** as substitutes:

- `docs/reports/images/burgher_houses/reference_*.png` - documentation/reference studies, not gameplay-camera acceptance plates.
- `docs/reports/images/lower_town_p0_101/` tier rows - no accepted plate currently demonstrates all three ordinary tiers together with matched day/night framing and visual interpretation.
- Existing whole-map `view3d` and ADR-0018 calibration images - supplementary renderer/calibration context without the required stable-ID tier/landmark review matrix.
- Source tier counts (`merchant_stone=14`, `merchant_timber=14`, `craft_boda=15`) and contract-test passes - implementation/source evidence only, not visual acceptance.

Because the four environment-kit pairs are valid but the downstream tier and human visual gates are missing, the correct closeout state is **BLOCKED / PARTIAL**, not `PASS` and not a regenerated capture request.

## Verification

Run from the repository root:

```bash
python3 tools/verify_p0_102_environment_kit_evidence.py
# P0-102 environment-kit evidence verification passed (8/8 plates)

git diff --check -- \
  docs/reports/p0_102_environment_kit_acceptance.md \
  docs/reports/p0_102m_environment_kit_day_night.md
```

The verifier checks the eight linked files, 1280x720 RGB dimensions, non-flat luminance, differing day/night bytes, identical pair framing metadata, map identity, lighting labels, camera metadata, and required acceptance-report terms. Runtime, art generation, and unrelated map/renderer findings remain outside R-543.

## Handoff

- Keep P0-102 open until the clean parser/runtime baseline is repaired and rerun.
- Keep the P0-101 ordinary-fabric and exceptional-landmark gates open until the dedicated tier/landmark gameplay packet and named human review are complete.
- Do not regenerate the eight valid environment-kit plates or promote reference images to fill the missing tier evidence.

The R-543 deliverable is complete as an evidence reconciliation with the blockers above recorded for the owning tasks.
