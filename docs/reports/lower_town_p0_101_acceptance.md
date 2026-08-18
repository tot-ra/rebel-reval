# Lower Town P0-101 Acceptance Gate

**Task:** R-538 - Verify and close Lower Town P0-101 acceptance
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-17
**Snapshot:** `54b7e163c021a6b3b6e46028e930fcbe46e79919`
**Worktree:** shared worktree contains unrelated modified and untracked WIP. This report uses only the scoped commands and existing named evidence; unrelated WIP is not acceptance evidence.
**Decision:** **BLOCKED - do not close R-108 or promote P0-101 to accepted.**

## Scope and method

This is the R-538 final closeout ledger. It reconciles the seven R-108 acceptance clauses with the current task board, authored Lower Town source, linked R-487-R-492 reports, the decomposition blockers R-560-R-564, and reproducible focused checks. It does not author art, change map geometry, change runtime behavior, change budgets, waive missing captures, or reinterpret supplementary images as gameplay acceptance.

The report separates source and contract evidence from gameplay-scale visual evidence, human review, clean-checkout load evidence, and hardware measurements. A passing headless contract test proves only the contract covered by that test.

## Task-board and handoff state

| Handoff | Current status | Acceptance impact |
|---|---|---|
| R-486 / P0-101a inventory | `done` | Stable source inventory and renderer-boundary evidence are available. |
| R-213 / P2-067 tier wiring | `done` | Authored three-tier mapping and deterministic tier tests are available. |
| R-487 / P0-101b ordinary frontage and wear | `in_progress` | Ordinary variation, roof/material readability, and wear evidence are not closed. |
| R-488 / P0-101c exceptional landmarks | `in_progress` | Exceptional implementation handoff is not closed. |
| R-489 / P0-101d route integration | `in_progress` | Playable-route art integration handoff is not closed. |
| R-490 / P0-101e runtime/route/occlusion/budget QA | `in_review` | Report is complete but blocked by camera, resident-budget, clean-load, and unmeasured GPU gates. |
| R-491 / P0-101f matched captures | `in_review` | Matrix remains blocked; no dedicated gameplay-scale packet exists. |
| R-492 / P0-101g landmark silhouette review | `in_review` | Review has no named canon/art sign-off and keeps all required silhouettes blocked. |
| R-532 / ordinary-fabric verification | `todo` | Required independent ordinary-fabric acceptance is not closed. |
| R-533 / landmark-boundary verification | `todo` | Required independent landmark acceptance is not closed. |
| R-534 / route-integration verification | `todo` | Required independent route/parity handoff is not closed. |
| R-535 / runtime and performance verification | `todo` | Required independent runtime/performance handoff is not closed. |
| R-536 / day/night capture verification | `todo` | Dedicated visual packet audit is not closed. |
| R-537 / historical and art sign-off verification | `todo` | Human review ledger is not closed. |
| R-559 / dependency and handoff preflight | `todo` | Upstream reconciliation is not closed. |
| R-564 / decomposition-gap verification | `todo` | R-560-R-563 are not resolved and no final readiness ledger exists. |
| R-538 / this closeout | `in_progress` at verification start | Deliverable is now a deterministic blocked ledger; it cannot be marked done. |
| R-108 / P0-101 parent | `todo` | Parent must remain open. |

Upstream context is also incomplete: R-109 / P0-100 is `todo`, R-110 / P0-102 is `todo`, and R-6 / A-009 is `in_review` with conditional reference-art approval rather than final gameplay sign-off.

The decomposition tasks are still unresolved: R-560 gameplay-scale capture capability, R-561 capture packet audit, R-562 clean-checkout parse/load gate, and R-563 GPU/minimum-hardware evidence are all `todo`. R-564 therefore remains a blocking readiness dependency rather than a completed reconciliation.

## Clause-by-clause acceptance matrix

| R-108 acceptance clause | Result | Current evidence and exact limitation | Owner / blocker |
|---|---|---|---|
| 1. No unexplained repeated ordinary facade/material run; every required visible landmark is classified and present exactly once | **BLOCKED** | The authored source currently contains 91 `building`/`landmark` records with 91 unique IDs: 53 houses, 36 walls, and 2 view-only gate arches. The authored tier counts are 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda`. This proves source uniqueness and tier assignment only. It does not prove route-scale visual repetition limits, material variation, or landmark presentation. | R-532 is `todo`; R-487 is `in_progress`; R-533/R-488 remain open for exceptional records. |
| 2. Gameplay-scale captures distinguish all three tiers, log/plank/plaster/limestone families, tile/shingle/thatch roofs, and localized wear/repaired details | **BLOCKED** | Current dirty-worktree contracts pass: `test_lower_town_slice_map` is 19/19 and `test_burgher_house_tiers` is 5/5. These tests confirm authored map, route, parity, tier, fallback, and material-precedence contracts, but are not visual evidence. `docs/reports/images/lower_town_p0_101/` is absent and R-491 still marks the required gameplay-scale rows pending/blocked. | R-536 is `todo`; R-491 is `in_review`; ordinary visual proof remains with R-532/R-487. |
| 3. St. Catherine's, the 1343 Viru Gate, and every required special building have reviewed exceptional silhouettes and are not scaled-up ordinary houses | **BLOCKED** | Source boundaries are present: `st_catherines_church`, Viru Gate tower/jamb records, foregate records, and separate view-only `viru_gate_arch` / `viru_foregate_arch` landmarks are authored. R-492 still records all 48 required non-ordinary visible rows as blocked, R-488 is not closed, and no dedicated landmark approach packet or human approval exists. | R-533 is `todo`; R-488/R-492 are open. |
| 4. Matched gameplay-scale day/night captures exist for ordinary fabric and each required landmark, with camera and map-revision metadata | **BLOCKED** | No dedicated R-491 packet directory exists. Existing `view3d` day/night PNGs and ADR-0018 calibration third-person PNGs are 1280x720 and non-blank, but they are supplementary whole-map/calibration evidence without the required route/approach metadata and stable pose matrix. They are not promoted to acceptance plates. | R-536 and R-560/R-561 are `todo`; R-491 is `in_review`. |
| 5. Human historical/art review signs every required 1343 silhouette or records a blocking amendment with an owner | **BLOCKED** | R-492 explicitly records `Human canon reviewer: Not assigned` and `Human art reviewer: Not assigned`; its final silhouette sign-off is blocked. R-6/A-009 is conditional reference-art review, not final gameplay sign-off. R-537 is still `todo`. | R-537/R-492 and the missing named canon/art reviewers. |
| 6. Routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures, and performance budgets pass with hardware limitations stated | **PARTIAL - final acceptance BLOCKED** | Current focused dirty-worktree suites pass: `test_kalev_smithy_map` 16/16, `test_map_terrain_chunks` 6/6, `test_large_map_chunk_prototype` 8/8, `test_map_object_chunk_streaming` 7/7, `test_vertical_slice_performance` 4/4, `test_performance_benchmark` 3/3, and `test_urban_population_performance_cap` 2/2. `python3 tools/report_slice_performance.py --check` also passes. The current `test_map_camera_modes` run is red: 11 tests, 6 assertion failures, and 14 engine/script diagnostics covering building pull-out, first-person eye height, and follow-boom distance/zoom restoration. R-490 additionally records 8472/7500 resident nodes, 446.2/280 MiB resident memory, and missing non-headless GPU/minimum-hardware measurements. A clean HEAD checkout reproduces RRMap parser errors for `elevation_area` / `elevation_ramp` and an invalid Lower Town definition; the clean-checkout load gate itself is not implemented. | R-535/R-562/R-563 are `todo`; R-490 is `in_review`; camera, budget, parser/load, and GPU owners remain open. |
| 7. All upstream blockers are resolved or explicitly recorded; no incomplete P0-102 handoff is treated as complete | **BLOCKED** | Blockers are now named and reproducible: R-487-R-489 are `in_progress`; R-490-R-492 are `in_review` with blocked results; R-532-R-537, R-559, and R-564 are `todo`; R-560-R-563 are `todo`; R-109/R-110 are `todo`; and R-6 is conditional `in_review`. No P0-102 or reference-art report is promoted to P0-101 acceptance. | R-559/R-564 and all listed upstream owners. |

## Verification record

### Authored source and focused contracts

The current source extraction reports:

```text
records=91 unique_records=91
merchant_stone=14
merchant_timber=14
craft_boda=15
st_catherines_church=True
viru_gate=True
```

The current dirty-worktree focused commands were run through `tools/run_godot_checked.sh --require-test-summary` with Godot 4.7.1:

```text
--filter=test_lower_town_slice_map       1 file, 19 tests, 0 failures, 0 errors
--filter=test_burgher_house_tiers        1 file, 5 tests, 0 failures, 0 errors
--filter=test_kalev_smithy_map           1 file, 16 tests, 0 failures, 0 errors
--filter=test_map_terrain_chunks         1 file, 6 tests, 0 failures, 0 errors
--filter=test_large_map_chunk_prototype  1 file, 8 tests, 0 failures, 0 errors
--filter=test_map_object_chunk_streaming 1 file, 7 tests, 0 failures, 0 errors
--filter=test_vertical_slice_performance 1 file, 4 tests, 0 failures, 0 errors
--filter=test_performance_benchmark      1 file, 3 tests, 0 failures, 0 errors
--filter=test_urban_population_performance_cap 1 file, 2 tests, 0 failures, 0 errors
--filter=test_map_camera_modes            1 file, 11 tests, 6 failures, 14 errors
```

The checked runner accepted the expected shutdown-only DEF-002 resource leak lines for the green suites. The camera diagnostics were not treated as shutdown-only noise because they interrupt test completion and accompany assertion failures.

### Clean-checkout boundary

A detached worktree at `HEAD` was imported before the scoped clean-checkout tests. The clean Lower Town run did not reach a valid map contract: `content/maps/lower_town_slice.rrmap` emitted `unknown_command` for `elevation_area` at lines 14, 20, and 22 and `elevation_ramp` at line 17, followed by an invalid map definition and dependent route/landmark failures. This is the first reproducible clean-checkout parser/resource blocker. It is recorded, not repaired, because R-538 is verification-only and R-562 owns the missing CI/load gate.

### Performance and hardware boundary

`python3 tools/report_slice_performance.py --check` validates the authored manifest and slice-gate schema. It does not provide a new minimum-hardware measurement. R-490's linked runtime report remains the current measured evidence: headless development-baseline frame/collision checks are green, but resident nodes and memory exceed authored caps, camera behavior is red, and the non-headless GPU/minimum-hardware probe was not run. The declared target remains `minimum-hardware-intel-uhd-620`; a target profile label is not a measurement of that hardware.

### Capture and review boundary

The required directory `docs/reports/images/lower_town_p0_101/` is absent. The existing 1280x720 `view3d` and ADR-0018 third-person day/night files are supplementary only. R-491's matrix still requires matched gameplay-scale poses, map revision, camera intent, renderer, source stable IDs, and reproducible commands. R-492 has no named human canon or art reviewer and does not approve any silhouette.

## Closeout decision and next actions

**R-538 is complete as a verification ledger but remains blocked.** Move R-538 to `in_review`, keep R-108 `todo`, and do not promote any clause to an overall PASS. No duplicate follow-up tasks are created because the board already has explicit owners.

Required next actions before a future closeout:

1. R-532 closes the ordinary-fabric source and gameplay-scale evidence audit.
2. R-533 closes the exceptional landmark and fortification-boundary evidence audit.
3. R-534 closes route integration and parity fingerprint reconciliation.
4. R-535 closes runtime, occlusion, streaming, and authored budget evidence.
5. R-536/R-560/R-561 produce and verify the dedicated matched day/night gameplay-scale packet.
6. R-537 obtains named canon/art review or records owner-specific amendments for every required row.
7. R-562 adds and proves the clean-checkout parse/load gate; the `elevation_area` / `elevation_ramp` parser blocker must be owned outside this acceptance report.
8. R-563 supplies non-headless GPU and declared minimum-hardware evidence without changing authored caps.
9. R-559 and R-564 reconcile all handoffs and decomposition gaps before R-538 is rerun.
10. R-108 remains open until every clause above is independently evidenced as PASS.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`p3_011_performance_budget.md`](p3_011_performance_budget.md)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
- [`tools/run_godot_tests.gd`](../../tools/run_godot_tests.gd)

---

## R-574 current verification addendum (2026-08-18)

**Scope:** final board-level verification after R-573 package-integrity and the R-532-R-537 / R-559-R-564 handoff reports. This addendum is append-only and does not rewrite historical snapshots, implementation, map content, assets, budgets, thresholds, or human-review decisions.

**Current decision:** **PACKAGE INTEGRITY PASS; P0-101 / R-108 ACCEPTANCE BLOCKED.** Keep R-108 `todo`. R-574 is complete as a verification deliverable and may be marked `done`; its blocked result does not close or waive the parent.

### Current board and artifact reconciliation

| Ref | Current board status | Current evidence / interpretation |
|---|---|---|
| R-487 | `in_progress` | Ordinary frontage, wear, and gameplay-visual handoff remains open; R-532 is structural/source PASS but gameplay-visual BLOCKED. |
| R-488 | `in_progress` | Exceptional landmark implementation handoff remains open; R-533 proves boundaries structurally, not final visual acceptance. |
| R-489 | `in_progress` | Playable-route art integration handoff remains open; R-534 retains visual/independent-baseline blockers. |
| R-490 | `in_review` | Runtime QA retains camera, resident-cost, clean-load, and minimum-hardware blockers. |
| R-491 | `in_review` | Dedicated packet is structurally present, but the capture matrix does not provide stable-ID visual coverage for every required surface. |
| R-492 | `in_review` | Required silhouette rows remain blocked; named human canon/art reviewers are not assigned. |
| R-532 | `in_review` | Source and contract evidence pass; tier/material/roof/wear gameplay readability and repetition review remain blocked. |
| R-533 | `done` | Structural landmark-boundary verification is complete; final visual and historical acceptance remains blocked by its report. |
| R-534 | `in_review` | Route/parity contracts pass; independent before/after and surface-level visual handoff remain open. |
| R-535 | `done` | Verification artifact is complete with a blocked runtime/performance result. |
| R-536 | `done` | Packet-integrity audit is complete; surface-by-surface visual acceptance remains blocked. |
| R-537 | `done` | Evidence audit is complete; no historical/art approval was issued and all required rows remain blocked. |
| R-559 | `done` | Dependency preflight is complete with a deterministic blocked readiness result. |
| R-560 | `in_progress` | Capture capability is reproducible, but the board handoff remains open. |
| R-561 | `in_review` | Packet audit confirms integrity, while all stable-ID visual rows remain blocked. |
| R-562 | `done` | Gate implementation and CI contract pass; clean-checkout MapView3D load is blocked by the RRMap parser boundary. |
| R-563 | `in_review` | M5 renderer evidence is supplementary; declared Intel UHD 620 minimum-hardware evidence is unavailable and resident-node overage remains. |
| R-564 | `in_review` | Decomposition readiness ledger is complete as BLOCKED, not an overall PASS. |
| R-573 | `done` | Package-integrity report passes package checks but explicitly preserves final P0-101 BLOCKED. |
| R-109 / P0-100 | `todo` | Upstream layout/terrain-density handoff is unresolved. |
| R-213 / P2-067 | `done` | Tier wiring dependency is resolved structurally; visual acceptance still belongs to P0-101. |
| R-6 / A-009 | `in_review` | Conditional art/reference review is not final gameplay sign-off. |
| R-108 / P0-101 | `todo` | Parent must remain open. |

### Seven-clause verdicts

1. **Ordinary repetition, material runs, and landmark classification: BLOCKED.** Source inventory and stable IDs are coherent, but gameplay-route repetition and presentation are not visually accepted. Owners: R-487/R-532 and R-488/R-533.
2. **Three tiers, wall/roof families, and localized wear: BLOCKED.** The tier/map contracts pass, and the packet has four matched route pairs, but no plate is stable-ID annotated for `merchant_stone`, `merchant_timber`, `craft_boda`, each required material/roof family, or readable wear/repair. Owners: R-487/R-532/R-561.
3. **Exceptional landmarks and 1343 silhouettes: BLOCKED.** The 48 non-ordinary IDs and renderer/view-only boundaries are structurally present, but R-492/R-537 retain blocked per-row verdicts and R-488/R-489 are not closed. Owners: R-488/R-492/R-533/R-537.
4. **Matched gameplay-scale day/night evidence: BLOCKED for acceptance, PASS for packet integrity.** Manifest audit: 8 PNG plates, 4 presets, 4 matched pairs, `1280x720`, valid PNG signatures, non-blank payloads, `errors=0`; focused capture contract: 4/4. The packet does not cover every required stable-ID surface. Owners: R-491/R-536/R-561.
5. **Named human historical/art review: BLOCKED.** R-492 and R-537 record no assigned human canon reviewer or human art reviewer and issue no silhouette approval. Owner: R-537/R-492.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** Green scoped suites: map 19/19, tiers 5/5, smithy 16/16, terrain 6/6, large chunks 8/8, object streaming 7/7, vertical performance 4/4, benchmark 3/3, population cap 2/2; performance manifest check passes. Camera suite: 11 tests, 6 assertion failures, 0 test errors. Clean-load gate: exit 1 after clean checkout/LFS/import, first product diagnostics are `elevation_area` / `elevation_ramp` unknown commands, then 41 failures and 193 errors. R-490/R-535 also retain resident-node and resident-memory overages; R-563 lacks Intel UHD 620 evidence. Owners: camera/runtime owner, R-453/R-455, P3-011/R-563.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-109 remains `todo`; R-6 remains conditional `in_review`; R-487-R-489 and R-560 remain open; R-561/R-564 retain blocked readiness; no P0-102 or reference-art evidence is promoted.

### Validator and package evidence

| Check | Current result | Classification |
|---|---|---|
| `python3 tools/validate_asset_sources.py` | PASS - 1155 rows, 999 inventory paths, 993 active runtime assets | Relevant package/provenance validation is green. |
| Manifest/link audit | PASS - `plates=8`, `presets=4`, `errors=0`; 19 concrete links in this report, 0 missing | Relevant acceptance package integrity is green. |
| `python3 tools/report_slice_performance.py --check` | PASS - manifest and slice gates valid | Contract/schema evidence only; not a hardware measurement. |
| `python3 tools/verify_map_audit.py` | FAIL - missing scene coverage, target mismatch, missing strict TODO tasks, and P2-012/P2-021 dependency drift | Baseline repository inventory/TODO drift; not repaired or counted as a P0-101 acceptance PASS. |
| `python3 tools/verify_map_conversion_plan.py` | FAIL - same baseline scene/TODO/target/dependency drift | Baseline repository inventory/TODO drift; not repaired or counted as a P0-101 acceptance PASS. |
| `python3 tools/generate_active_docs_report.py --check` | FAIL - `docs/reports/active_markdown_report.md` is stale | Documentation baseline drift; not repaired in this verification-only task. |
| `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` | PASS - 7 tests, 1 expected skip | Gate implementation contract is green; live clean load remains blocked as above. |

The current dedicated packet is valid package evidence, superseding only the older absence statement in the historical R-538 text. It does not supersede R-538's blocked outcome or the surface-level blockers recorded by R-536/R-561/R-537. Supplementary whole-map, calibration, debug, and conversion images remain non-acceptance evidence.

### Closeout

**R-574 result: verification complete as a deterministic BLOCKED ledger; R-108 / P0-101 cannot move to `done`.** Do not close the parent until the named owners provide stable-ID-linked day/night visual observations, human canon/art sign-off, green clean-checkout load, camera/runtime and resident-budget resolution, declared minimum-hardware evidence, and resolved upstream/handoff statuses. No duplicate follow-up task is created because existing board owners cover each blocker.

**Sources:** [`r573_lower_town_acceptance_package_integrity.md`](r573_lower_town_acceptance_package_integrity.md), [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md), [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md), [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md), [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md), [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md), [`p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md), [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md), [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json).
