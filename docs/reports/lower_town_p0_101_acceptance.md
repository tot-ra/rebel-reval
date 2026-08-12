# Lower Town P0-101 Acceptance Gate

**Task:** R-493 / P0-101h
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-12
**Snapshot:** `30161e0de2016ac228814620487a525a53c783ff`
**Worktree:** shared worktree contains unrelated modified and untracked WIP; this report does not treat those changes as evidence.
**Decision:** **BLOCKED - do not close R-108 or promote the Lower Town architecture and landmark pass to accepted.**

## Scope and method

This is the final P0-101 verification-only gate requested by R-493. It checks the acceptance clauses against the current authored source, task-board handoffs, focused map contracts, existing evidence reports, and the available capture/review records. It does not author new art, change map geometry, change runtime behavior, waive missing evidence, or reinterpret supplementary images as gameplay acceptance.

The report distinguishes source/contract evidence from visual and human-review evidence. A passing focused test proves the tested contract only; it does not prove gameplay-scale material readability, landmark silhouette quality, or historical/art approval.

## Task-board handoff state

| Handoff | Current status | Acceptance impact |
|---|---|---|
| R-486 / P0-101a inventory | `done` | Source inventory and renderer-boundary evidence are available. |
| R-213 / P2-067 tier wiring | `done` | Current map has authored `house_tier` values and focused tier coverage. |
| R-487 / P0-101b ordinary frontage and wear | `todo` | Ordinary variation, roof/material readability, and worn/repaired detail handoff is incomplete. |
| R-488 / P0-101c exceptional landmarks | `todo` | Required exceptional implementation handoff is incomplete. |
| R-489 / P0-101d route integration | `todo` | Playable-route art integration handoff is incomplete. |
| R-490 / P0-101e runtime/route/occlusion/budget QA | `in_progress` | Final runtime and budget gate is not closed. |
| R-491 / P0-101f matched captures | `in_review` | `lower_town_p0_101_capture_matrix.md` marks every required day/night row pending or blocked. |
| R-492 / P0-101g landmark silhouette review | `in_review` | Review explicitly records no human canon/art sign-off and all required silhouettes blocked. |
| R-108 / P0-101 parent | `todo` | Parent must remain open. |

Upstream context is also incomplete for this final gate: R-109 / P0-100 remains `todo`, R-110 / P0-102 remains `todo`, and R-6 / A-009 is only `in_review` with a conditional reference-art pass, not final gameplay sign-off. R-213 is complete and is therefore reported as a positive handoff, but its own gameplay capture requirement is not a substitute for R-491/R-492 evidence.

## Clause-by-clause acceptance matrix

| Acceptance clause | Result | Evidence and limitation | Source task / command / report | Reviewer or owner |
|---|---|---|---|---|
| 1. No unexplained repeated ordinary facade/material run; every required visible landmark is classified and present exactly once | **BLOCKED** | The authored source has 91 unique stable records: 53 houses, 36 walls, and 2 view-only gate arches. Static extraction found 91 records and 91 unique IDs. The tier counts are 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda`. This proves inventory uniqueness and tier assignment, but not visual repetition, material variation, or route-scale landmark presentation. R-487 and R-488 remain open. | R-486 `lower_town_p0_101_landmark_inventory.md`; R-487/R-488 board status; static check: `python3` record/ID/tier extraction from `content/maps/lower_town_slice.rrmap` | R-493 verification; ordinary review remains with R-487 and landmark review with R-488/R-492. |
| 2. Gameplay-scale captures distinguish all three tiers, log/plank/plaster/limestone families, tile/shingle/thatch roofs, and localized wear/repaired details | **BLOCKED** | `test_burgher_house_tiers` passes 3/3 and confirms the three authored tiers, untiered special IDs, fallback style mapping, and authored material precedence. `test_lower_town_slice_map` passes 19/19 and confirms map/parity/route/wall/water contracts. Neither suite is visual evidence. R-491 records every ordinary-fabric capture row as pending; the existing whole-map orthographic and calibration images are explicitly supplementary. | R-213; R-491; commands below: `r493-house-tiers`, `r493-lower-map`; `lower_town_p0_101_capture_matrix.md` sections 2-4 | R-493 verification; final visual evidence owned by R-491 and ordinary art review by R-6/R-108. |
| 3. St. Catherine's, 1343 Viru Gate, and every required special building have reviewed exceptional silhouettes and are not scaled-up ordinary houses | **BLOCKED** | R-486 confirms `st_catherines_church` is on the exceptional registry and gate arches are view-only, while wall/tower/jamb records remain fortification-capable. This is a routing/boundary result, not a production silhouette result. R-488 is `todo`; R-492 marks all 48 required non-ordinary visible rows `BLOCKED`. No dedicated landmark approach captures or human sign-off exists. | R-486 inventory sections 2-4; R-488/R-492 board and report; `r492_lower_town_1343_landmark_silhouette_review.md` sections 2-6 | R-493 verification; exceptional implementation R-488; historical/art decision R-492. |
| 4. Matched gameplay-scale day/night captures exist for ordinary fabric and each required landmark, with camera/map revision metadata | **BLOCKED** | No `docs/reports/images/lower_town_p0_101/` acceptance set exists. R-491's matrix marks representative tiers, special buildings, St. Catherine's, inner gate, foregate, walls, and route-scale proof as pending/blocked. Existing `view3d`, ADR-0018, audit, and conversion images do not meet the route-camera contract. | R-491; `lower_town_p0_101_capture_matrix.md` sections 2, 5, and 7; capture directory existence check | R-491 / production-art-canon capture owner. |
| 5. Human historical/art review signs every required 1343 silhouette or records a blocking amendment with an owner | **BLOCKED** | R-492 explicitly states: human canon reviewer not assigned, human art reviewer not assigned, and no silhouette may be approved from the current evidence. R-6/A-009 is a conditional art-direction pass for reference plates only and states that final gameplay sign-off is blocked. | R-492 report lines 3-18; R-6 `burgher_house_art_signoff.md` lines 8-14 and 53-72 | Canon/art reviewers are not assigned in the current evidence; R-492 remains the handoff owner. |
| 6. Routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures, and performance budgets pass; hardware limitations are stated | **PARTIAL - focused map contracts PASS, final acceptance BLOCKED** | `test_lower_town_slice_map`: **19/19**, including parity, required route endpoints, city-wall/gate collision semantics, navigation connectivity, water exclusion, smithy entrance attachment, and stable seam checks. `test_burgher_house_tiers`: **3/3**. The final occlusion/chunk/performance handoff is not complete because R-490 is `in_progress`; no current R-493 evidence closes the broader budget and route-art integration clauses. | R-490 status; commands below; `tests/godot/test_lower_town_slice_map.gd`; `tests/godot/test_burgher_house_tiers.gd`; R-491/R-492 reports | R-493 verification for focused contracts; R-489 integration and R-490 runtime/budget QA remain owners. |
| 7. All upstream blockers are resolved or explicitly recorded; no external/incomplete P0-102 handoff is treated as complete | **BLOCKED** | Blockers are explicitly recorded and remain owned: R-487/R-488/R-489 are `todo`, R-490 is `in_progress`, R-491/R-492 are `in_review`, R-109 and R-110 are `todo`, and R-6 is conditional. The report does not promote the shared P0-102 environment kit or reference-art sign-off into final P0-101 acceptance. | Task board state; `p0_102g_scope_boundary_recheck.md`; `burgher_house_art_signoff.md`; R-486/R-491/R-492 reports | R-493 verification; each named upstream owner retains its blocker. |

## Current positive evidence

### Authored-source inventory

The current `content/maps/lower_town_slice.rrmap` contains:

- 91 records with unique stable IDs;
- 53 house records, 36 wall records, and 2 `gate_arch` view landmarks;
- 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda` assignments;
- separate untiered special/exceptional records, including `st_catherines_church`;
- preserved Viru Gate tower/jamb records and separate view-only arch records.

These results agree with R-486's inventory and do not by themselves establish visual acceptance.

### Focused contract verification

The following current checks passed on 2026-08-12:

```text
export GODOT_LOG_DIR=/tmp/r493_checked

tools/run_godot_checked.sh --require-test-summary r493-lower-map -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

Result: Godot headless tests: 1 file(s), 19 test(s), 0 failure(s), 0 error(s).

# Expected shutdown-only ObjectDB/resource leak diagnostics were emitted and
# accepted by the checked runner's documented DEF-002 allowlist.

tools/run_godot_checked.sh --require-test-summary r493-house-tiers -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers

Result: Godot headless tests: 1 file(s), 3 test(s), 0 failure(s), 0 error(s).

# Same expected shutdown-only diagnostics were emitted.
```

The focused green results are contract evidence only. They do not close the blocked visual rows above.

## Non-acceptance evidence boundary

The following existing assets must not be promoted to this gate's gameplay-scale acceptance set:

- `docs/reports/images/view3d/lower_town_slice_day.png` and `lower_town_slice_night.png`: fixed whole-map orthographic smoke views;
- `docs/reports/images/adr0018_calibration/lower_town_slice_third_person_day.png` and `lower_town_slice_third_person_night.png`: calibration plates without the P0-101 inventory and route metadata;
- top-down/debug, map-audit, and map-conversion images listed in R-491's matrix.

They remain useful supplementary context only.

## Closeout decision and handoff

**R-493 / P0-101h remains in review with a BLOCKED acceptance result.** The report deliverable is complete, but the gate cannot be marked done because clauses 1-5 and 7 are not fully evidenced, while clause 6 is only partially covered by focused map contracts.

No new follow-up task is created. Existing board ownership is sufficient and a duplicate task would obscure the handoff:

1. R-487 must complete ordinary frontage variation and localized wear evidence.
2. R-488 must complete the exceptional landmark implementation and preserve non-ordinary renderer boundaries.
3. R-489 must integrate ordinary and exceptional art on playable routes without gameplay drift.
4. R-490 must close runtime, route, occlusion, navigation, and budget QA.
5. R-491 must produce matched gameplay-scale day/night route and approach plates with metadata.
6. R-492 must obtain named human canon and art review, or record owner-specific amendments.
7. R-108 remains the parent acceptance owner and must not close until all clauses are PASS.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) - R-486 inventory and renderer boundaries
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - R-491 capture contract and pending matrix
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md) - R-492 blocked human review
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) - R-6 conditional reference-art sign-off
- [`p0_102g_scope_boundary_recheck.md`](p0_102g_scope_boundary_recheck.md) - P0-102 downstream ownership boundary
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
