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
2. **Three tiers, wall/roof families, and localized wear: BLOCKED.** The tier/map contracts pass, and the packet has five matched route pairs, but no plate is stable-ID annotated for `merchant_stone`, `merchant_timber`, `craft_boda`, each required material/roof family, or readable wear/repair. Owners: R-487/R-532/R-561.
3. **Exceptional landmarks and 1343 silhouettes: BLOCKED.** The 48 non-ordinary IDs and renderer/view-only boundaries are structurally present, but R-492/R-537 retain blocked per-row verdicts and R-488/R-489 are not closed. Owners: R-488/R-492/R-533/R-537.
4. **Matched gameplay-scale day/night evidence: BLOCKED for acceptance, PASS for packet integrity.** Manifest audit: 10 PNG plates, 5 presets, 5 matched pairs, `1280x720`, valid PNG signatures, non-blank payloads, `errors=0`; focused capture contract: 5/5. The packet does not cover every required stable-ID surface. Owners: R-491/R-536/R-561.
5. **Named human historical/art review: BLOCKED.** R-492 and R-537 record no assigned human canon reviewer or human art reviewer and issue no silhouette approval. Owner: R-537/R-492.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** Green scoped suites: map 19/19, tiers 5/5, smithy 16/16, terrain 6/6, large chunks 8/8, object streaming 7/7, vertical performance 4/4, benchmark 3/3, population cap 2/2; performance manifest check passes. Camera suite: 11 tests, 6 assertion failures, 0 test errors. Clean-load gate: exit 1 after clean checkout/LFS/import, first product diagnostics are `elevation_area` / `elevation_ramp` unknown commands, then 41 failures and 193 errors. R-490/R-535 also retain resident-node and resident-memory overages; R-563 lacks Intel UHD 620 evidence. Owners: camera/runtime owner, R-453/R-455, P3-011/R-563.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-109 remains `todo`; R-6 remains conditional `in_review`; R-487-R-489 and R-560 remain open; R-561/R-564 retain blocked readiness; no P0-102 or reference-art evidence is promoted.

### Validator and package evidence

| Check | Current result | Classification |
|---|---|---|
| `python3 tools/validate_asset_sources.py` | PASS - 1155 rows, 999 inventory paths, 993 active runtime assets | Relevant package/provenance validation is green. |
| Manifest/link audit | PASS - `plates=10`, `presets=5`, `errors=0`; 19 concrete links in this report, 0 missing | Relevant acceptance package integrity is green. |
| `python3 tools/report_slice_performance.py --check` | PASS - manifest and slice gates valid | Contract/schema evidence only; not a hardware measurement. |
| `python3 tools/verify_map_audit.py` | FAIL - missing scene coverage, target mismatch, missing strict TODO tasks, and P2-012/P2-021 dependency drift | Baseline repository inventory/TODO drift; not repaired or counted as a P0-101 acceptance PASS. |
| `python3 tools/verify_map_conversion_plan.py` | FAIL - same baseline scene/TODO/target/dependency drift | Baseline repository inventory/TODO drift; not repaired or counted as a P0-101 acceptance PASS. |
| `python3 tools/generate_active_docs_report.py --check` | FAIL - `docs/reports/active_markdown_report.md` is stale | Documentation baseline drift; not repaired in this verification-only task. |
| `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` | PASS - 7 tests, 1 expected skip | Gate implementation contract is green; live clean load remains blocked as above. |

The current dedicated packet is valid package evidence, superseding only the older absence statement in the historical R-538 text. It does not supersede R-538's blocked outcome or the surface-level blockers recorded by R-536/R-561/R-537. Supplementary whole-map, calibration, debug, and conversion images remain non-acceptance evidence.

### Closeout

**R-574 result: verification complete as a deterministic BLOCKED ledger; R-108 / P0-101 cannot move to `done`.** Do not close the parent until the named owners provide stable-ID-linked day/night visual observations, human canon/art sign-off, green clean-checkout load, camera/runtime and resident-budget resolution, declared minimum-hardware evidence, and resolved upstream/handoff statuses. No duplicate follow-up task is created because existing board owners cover each blocker.

**Sources:** [`r573_lower_town_acceptance_package_integrity.md`](r573_lower_town_acceptance_package_integrity.md), [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md), [`r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md), [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md), [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md), [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md), [`p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md), [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md), [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json).

---

## R-538 current verification addendum (2026-08-18)

**Verification checkout:** `e3f499275e90144cbb8a9820a50f2e9c4dfc44c9` in the shared worktree. The worktree contains unrelated implementation WIP; only the scoped report, current authored-map inspection, board states, and commands below are used for this closeout.

**Decision:** **R-538 verification complete as BLOCKED; keep R-108 / P0-101 open.** The acceptance gate is not promoted by partial contract results, generic capture metadata, or development-host measurements.

### Current board reconciliation

| Ref | Current status | Closeout interpretation |
|---|---|---|
| R-487 / P0-101b | `in_progress` | Ordinary frontage, wear, and visual variation handoff remains open. |
| R-488 / P0-101c | `in_progress` | Exceptional landmark implementation handoff remains open. |
| R-489 / P0-101d | `in_progress` | Playable-route art integration handoff remains open. |
| R-490 / P0-101e | `in_review` | Runtime report is complete but its gate result is BLOCKED. |
| R-491 / P0-101f | `in_review` | Capture packet exists, but stable-ID surface coverage is not accepted. |
| R-492 / P0-101g | `in_review` | Silhouette review has no named canon/art approval. |
| R-532 | `in_review` | Structural/source evidence is available; gameplay-scale ordinary-fabric acceptance remains blocked. |
| R-533 | `done` | Landmark boundary verification is structurally complete; visual/history acceptance remains blocked. |
| R-534 | `in_review` | Contract parity is available; independent visual route handoff remains open. |
| R-535 | `done` | Verification artifact is complete with a blocked runtime/performance result. |
| R-536 | `done` | Packet-integrity audit is complete; per-surface visual rows remain blocked. |
| R-537 | `done` | Evidence audit is complete; no human historical/art approval was issued. |
| R-559 | `done` | Dependency preflight is complete with a blocked readiness result. |
| R-560 | `in_progress` | Capture capability exists, but its board handoff is open. |
| R-561 | `in_review` | Packet audit retains blocked stable-ID visual rows. |
| R-562 | `done` | Gate implementation contract passes; clean product load remains blocked. |
| R-563 | `in_review` | Development-host renderer evidence is supplementary; declared minimum hardware is not measured. |
| R-564 | `in_review` | Decomposition ledger is complete as BLOCKED, not an overall PASS. |
| R-538 | `in_progress` at verification start | This addendum completes the verification deliverable; the task should move to `in_review`, not `done`. |
| R-108 / P0-101 | `todo` | Parent must remain open. |

Upstream reconciliation remains incomplete: R-109 / P0-100 and R-110 / P0-102 remain `todo`; R-213 / P2-067 is structurally resolved; R-6 / A-009 remains conditional `in_review`. Existing handoff and decomposition owners cover the blockers, so no duplicate follow-up task is created.

### Current authored source and capture evidence

A scoped source inspection of `content/maps/lower_town_slice.rrmap` reports `97` building records and `2` view-landmark records, with `99` unique stable IDs. Current authored tier counts are `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=23`; these counts differ from the earlier 43-house inventory because the current shared worktree contains additional rear/service craft records. This is source evidence only, not gameplay-scale readability evidence.

The dedicated packet manifest is present and structurally valid at `docs/reports/images/lower_town_p0_101/capture_manifest.json`: `10` PNG plates, `5` presets, `0` manifest errors. The packet remains blocked for final acceptance because its route metadata does not provide stable-ID-linked observations for every tier, material/roof/wear family, special building, fortification, and landmark review row. It supersedes older packet-count statements only for the current package-integrity count.

### Focused verification rerun

The commands were run with the installed Godot binary after exporting `GODOT_BIN` in a separate shell assignment. Results:

| Focused suite | Result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19 tests, 1 failure** | Authored gameplay/parity fixture differs; do not regenerate the canonical fixture in this verification task. |
| `test_burgher_house_tiers` | **5 tests, 0 failures** | Tier/material precedence contract passes; visual acceptance is still absent. |
| `test_kalev_smithy_map` | **16 tests, 0 failures** | Smithy route contract passes. |
| `test_map_terrain_chunks` | **6 tests, 0 failures** | Terrain residency contract passes. |
| `test_large_map_chunk_prototype` | **8 tests, 0 failures** | Large-chunk contract passes. |
| `test_map_object_chunk_streaming` | **7 tests, 1 failure** | Boundary inventory/production-ownership fixture differs; current route/chunk acceptance is blocked. |
| `test_vertical_slice_performance` | **4 tests, 0 failures** | Authored metric contract passes, not a target-hardware measurement. |
| `test_performance_benchmark` | **5 tests, 0 failures** | Benchmark schema/target contract passes, not final budget acceptance. |
| `test_urban_population_performance_cap` | **2 tests, 0 failures** | Population-cap contract passes. |
| `test_map_camera_modes` | **11 tests, 6 failures, 2 errors** | Camera collision/eye-height/boom restoration remains a blocking runtime issue; the checked log also records a shader tokenizer diagnostic. |

Additional scoped checks: `python3 tools/report_slice_performance.py --check` passes; `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` passes `7` tests with `1` expected skip. `python3 tools/validate_asset_sources.py` fails on a large pre-existing inventory/provenance drift outside this report's allowlist. Repository-wide map-audit and active-doc checks also report baseline inventory/TODO drift and are not counted as P0-101 passes.

The clean-checkout gate implementation is green as a contract, but its product load remains blocked at the first authored parser diagnostics: `unknown_command` for `elevation_area` and `elevation_ramp`, followed by an invalid Lower Town definition. R-453/R-455 own that parser boundary.

### Seven-clause current verdict

1. **Ordinary repetition, materials, and landmark classification: BLOCKED.** Current source IDs are unique, but parity and object-boundary fixtures are red and no route-scale repetition threshold or stable-ID visual review is signed.
2. **Three tiers, log/plank/plaster/limestone, roofs, wear: BLOCKED.** The tier contract is green and the packet is intact, but the packet has no per-surface stable-ID annotations or signed gameplay-scale observations.
3. **Exceptional landmarks and 1343 silhouettes: BLOCKED.** Structural landmark boundaries are available, while R-492/R-537 retain all rows blocked and no named canon/art reviewers are assigned.
4. **Matched gameplay-scale day/night evidence: BLOCKED for acceptance, PASS for package integrity.** Current manifest integrity is `10` plates / `5` presets / `0` errors; the required surface-by-surface acceptance matrix is incomplete.
5. **Named historical/art review: BLOCKED.** No named human canon reviewer or human art reviewer has approved the required rows.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** Several focused contracts pass, but Lower Town parity and object-boundary checks fail, camera tests are red, clean product load is blocked by elevation parser diagnostics, the runtime report retains resident-node/memory overages, and Intel UHD 620 evidence is unavailable.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-487-R-489 and R-560 remain open, R-490-R-492 retain blocked/in-review evidence, R-109/R-110 remain todo, and R-6/A-009 is conditional.

### Closeout

**R-538 is complete as a deterministic BLOCKED verification ledger.** Move R-538 to `in_review`; keep R-108 / P0-101 `todo`. No new follow-up tasks are needed because the exact owners already exist: R-487/R-532, R-488/R-492/R-533/R-537, R-489/R-534, R-490/R-535, R-491/R-536/R-561, R-453/R-455, P3-011/R-563, and R-560/R-564.

---

## R-538 focused rerun addendum (2026-08-18)

**Scope:** independent rerun of the narrow contracts required to consume the current Lower Town acceptance package. This addendum records current command output only; it does not regenerate parity fixtures, alter map content, change budgets, or promote partial evidence to acceptance.

### Reproduction record

The checks used the installed Godot 4.7.1 binary and the checked runner:

```text
r538-lower-town-map: 19 tests, 1 failure, 0 errors
  FAIL test_lower_town_slice_matches_canonical_parity_fixture
  reason: authored gameplay data differs from the canonical fixture; the failure reports a footprint/door-side diff

r538-house-tiers: 5 tests, 0 failures, 0 errors
r538-capture: 5 tests, 0 failures, 0 errors

capture packet audit: plates=10, presets=5, errors=0
python3 tools/report_slice_performance.py --check: PASS
```

The tier and capture contracts remain green, and all manifest outputs remain present, matched, and non-blank. The Lower Town parity mismatch is a current acceptance blocker; this verification task does not rewrite the canonical fixture because the authored change requires owner review.

### Current disposition

The seven-clause result remains unchanged: clauses 1-5 and 7 are **BLOCKED**, while clause 6 is **PARTIAL - final acceptance BLOCKED**. Existing blockers remain the stable-ID visual review gaps, unassigned canon/art reviewers, the parity/object-boundary mismatch, camera failures, clean-checkout `elevation_area` / `elevation_ramp` parser diagnostics, production resident-cost overages, and unavailable Intel UHD 620 evidence. Existing owners cover these findings; no duplicate follow-up task is created.

**R-538 verification is complete as a deterministic BLOCKED ledger.** Keep R-538 in `in_review` and keep R-108 / P0-101 `todo` until the named owners resolve every blocker.

---

## R-538 independent rerun addendum (2026-08-22)

**Scope:** fresh verification-only rerun in the shared worktree. No runtime, art, map content, acceptance threshold, parity fixture, or performance budget was changed. The existing working-tree changes to this report were preserved; this addendum records only the current verification boundary.

**Decision:** **BLOCKED - R-538 verification is complete; keep R-108 / P0-101 open.** Green structural contracts and packet integrity do not substitute for stable-ID visual acceptance, named human review, clean product load, camera behavior, resident budgets, or declared minimum-hardware evidence.

### Current source and packet audit

- The current `content/maps/lower_town_slice.rrmap` inventory reports `99` building/landmark records and `99` unique stable IDs, with no duplicate IDs. The authoritative inventory and tier contract report `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=23`; the source also contains `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch`.
- `docs/reports/images/lower_town_p0_101/capture_manifest.json` is present with `10` plates, `5` presets, `0` manifest errors, `1280x720` output, and matched day/night framing. The matrix still has no stable-ID-linked visual observations for every tier, material, roof, wear, special-building, fortification, and landmark row, so this remains package-integrity evidence only.
- `python3 tools/report_slice_performance.py --check` passes the manifest and slice-gate schema. `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` reports `6` passed and `1` expected skip; this validates the gate contract, not a successful clean product load.
- `python3 tools/verify_map_activation.py` passes. `python3 tools/verify_map_composition.py` is blocked by the baseline registry error for missing threshold card `nunnatorn_interior`; this is not counted as Lower Town acceptance evidence.

### Fresh focused rerun

All Godot runs used `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh`; known shutdown-only ObjectDB/resource leak diagnostics were not treated as substantive failures.

| Focused check | Current result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19/19** | Current authored map contract passes; this does not prove final visual acceptance. |
| `test_burgher_house_tiers` | **5/5** | Tier and material-precedence contract passes; gameplay-scale readability remains unproven. |
| `test_capture_lower_town_p0_101` | **5/5** | Capture packet contract passes; stable-ID visual rows remain blocked. |
| `test_kalev_smithy_map` | **16/16** | Smithy route and collision contract passes. |
| `test_map_terrain_chunks` | **6/6** | Terrain residency contract passes. |
| `test_large_map_chunk_prototype` | **8/8** | Chunk ownership and route prototype contract passes. |
| `test_map_object_chunk_streaming` | **7/7** | Streaming ownership and lifecycle contract passes. |
| `test_environment_kit_integration` | **5/5** | Shared environment-kit structural contract passes. |
| `test_map_view_3d_fortification` | **8/8** | Fortification renderer boundary passes; no human silhouette sign-off is implied. |
| `test_map_camera_modes` | **11 tests, 2 failures, 0 errors** | Building collision pull-out and third-person pitch follow-boom distance remain blocking runtime failures. |
| `test_vertical_slice_performance` | **4/4** | Authored budget and target-profile contract passes; no target-hardware measurement. |
| `test_performance_benchmark` | **5/5** | Benchmark schema and target contract passes; no final aggregate budget acceptance. |

### Seven-clause current verdict

1. **Ordinary repetition, materials, and landmark classification: BLOCKED.** Source IDs and tier counts are coherent, and structural contracts pass, but no stable-ID-linked gameplay-scale review proves material, wear, or repetition readability.
2. **Three tiers, roof families, and localized wear: BLOCKED.** Tier contract and packet integrity pass; the capture matrix still has no accepted per-surface day/night observations.
3. **Exceptional landmarks and 1343 silhouettes: BLOCKED.** St. Catherine's and both Viru gate arches are present and fortification contracts pass, but named canon/art review remains unresolved.
4. **Matched gameplay-scale day/night evidence: BLOCKED for acceptance, PASS for packet integrity.** The ten-plate packet is present and valid, but its stable-ID surface matrix remains pending.
5. **Named historical/art review: BLOCKED.** No named human canon and art approvals are recorded for the required rows; conditional A-009 evidence is not final gameplay sign-off.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** The focused route, chunk, fortification, environment, and contract suites pass, but camera behavior remains red; resident-cost and declared-target hardware blockers from R-490/R-535 remain unresolved, and the clean product-load boundary is not proven by the Python gate contract.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-108 remains `todo`; R-109 remains `in_progress`; R-6/A-009 remains conditional `in_review`; R-487-R-489 remain `in_progress`; and R-490-R-492 retain open blocked acceptance boundaries. R-559 is `done` as a blocked readiness ledger and R-564 remains `in_review` with blocked decomposition readiness.

### Closeout

R-538 is complete as a reproducible **BLOCKED** verification ledger. Keep `R-538` in `in_review` and `R-108 / P0-101` in `todo` until all seven clauses have independent acceptance evidence and the upstream, human-review, clean-load, camera, resident-budget, and minimum-hardware blockers are resolved. No follow-up task was created because existing owners already cover each blocker.

**Sources:** [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md), [`r559_lower_town_dependency_handoff_readiness.md`](r559_lower_town_dependency_handoff_readiness.md), [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md), and the focused commands listed above.

---

## R-538 fresh verification addendum (2026-08-23)

**Scope:** independent verification-only rerun in the shared worktree. No runtime, art, map content, parity fixture, acceptance threshold, budget, or human-review outcome was changed. The current report and existing staged work were preserved; this addendum records only fresh command results and board reconciliation.

**Decision:** **BLOCKED - R-538 is complete as a verification artifact; keep R-538 in `in_review` and R-108 / P0-101 open.** Structural contracts and packet integrity do not clear the remaining visual, human-review, clean-import, camera, resident-budget, composition, or minimum-hardware gates.

### Current source, packet, and board audit

- `content/maps/lower_town_slice.rrmap` has SHA-256 `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`; the source audit reports `99` records and `99` unique IDs, with `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`, `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch` present.
- `docs/reports/images/lower_town_p0_101/capture_manifest.json` contains `10` plates in `5` matched day/night presets at `1280x720`, but its `map_fingerprint` is `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`, which is stale against the current source. The manifest has route anchors and interaction targets, not stable-ID visual observations, so it remains package-integrity evidence only.
- Board reconciliation: R-109/P0-100 is `in_progress`; R-213/P2-067 is `done` for structural tier wiring only; R-6/A-009 is conditional `in_review`; R-487-R-489 remain `in_progress`; R-490-R-492 remain open (`in_review`); R-559 is `done` as a blocked readiness ledger; R-564 is `in_review` with blocked decomposition readiness. Existing owners cover every actionable blocker, so no follow-up task was created.

### Fresh focused verification

All Godot checks used Godot 4.7.1 through `tools/run_godot_checked.sh`; known shutdown-only ObjectDB/resource/RID leak lines were not used to waive substantive failures.

| Focused check | Current result | Acceptance classification |
|---|---|---|
| `test_lower_town_slice_map` | **19/19** | Map, route, collision, navigation, gate-span, and parity contracts pass in the current worktree. |
| `test_burgher_house_tiers` | **5/5** | Tier/material precedence contract passes; visual readability remains unproven. |
| `test_capture_lower_town_p0_101` | **5/5** | Packet contract passes; stale fingerprint and missing stable-ID observations remain blockers. |
| `test_kalev_smithy_map` | **16/16** | Smithy route and collision contract passes. |
| `test_map_object_chunk_streaming` | **7/7** | Object ownership and lifecycle contract passes. |
| `test_large_map_chunk_prototype` | **8/8** | Chunk ownership and route prototype contract passes. |
| `test_environment_kit_integration` | **5/5** | Shared environment-kit structural contract passes. |
| `test_map_view_3d_fortification` | **8/8** | Fortification renderer boundary passes; no human silhouette approval is implied. |
| `test_urban_population_performance_cap` | **2/2** | Population-cap contract passes. |
| `test_vertical_slice_performance` | **4/4** | Authored budget/target-profile contract passes; no target-hardware measurement. |
| `test_performance_benchmark` | **5/5** | Benchmark schema and target contract pass; no aggregate resident-budget acceptance. |
| `test_map_camera_modes` | **11 tests, 2 failures, 0 errors** | `test_building_collision_pulls_camera_out` and `test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character` remain blocking camera failures. |

Supporting checks: `python3 -m unittest tests.python.test_lower_town_p0_101_baseline -v` passes `4/4`; `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` passes `6` with `1` expected skip; `python3 tools/report_slice_performance.py --check` passes; and `python3 tools/verify_map_activation.py` passes. `python3 tools/verify_map_composition.py` remains blocked by unrelated missing threshold cards `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`.

### Clean-checkout and acceptance verdict

`tools/verify_clean_checkout_load.sh` reached detached clean checkout creation, LFS restoration, and Godot import, then failed during clean import. The checked log reports missing tracked-HEAD preloads `res://scripts/characters/eye_material.gdshader` and `res://scripts/characters/hair_material.gdshader`, followed by the shared-rig parse cascade and `GameState` living-city constant errors. This is a clean-import blocker owned by R-122/R-124 and the related runtime handoff; the older `elevation_area` / `elevation_ramp` parser boundary remains a later historical blocker and was not reclassified as a fresh observation here.

The seven-clause result remains:

1. **BLOCKED:** no stable-ID gameplay review proves ordinary repetition, materials, wear, or landmark classification.
2. **BLOCKED:** the three tier contract passes, but matched day/night surface observations for tiers, roofs, materials, and repairs are absent.
3. **BLOCKED:** St. Catherine's and both Viru gate arches are structurally present, but exceptional silhouettes lack named canon/art approval.
4. **BLOCKED for acceptance, PASS for packet integrity:** ten valid plates exist, but the packet is stale for the current RRMap and has no stable-ID visual matrix.
5. **BLOCKED:** no named human canon or art reviewers have signed the required rows; A-009 remains conditional.
6. **PARTIAL - final acceptance BLOCKED:** route/chunk/fortification contracts pass, while camera behavior and clean product import fail; resident-cost and declared minimum-hardware blockers remain open in R-490/R-535.
7. **BLOCKED:** P0-100, ordinary/landmark/route/runtime/capture/sign-off handoffs are not all resolved, and R-564 remains blocked.

**Closeout:** R-538 is complete as a deterministic **BLOCKED** ledger. Keep R-538 in `in_review`, keep R-108/P0-101 open, and do not create duplicate follow-up tasks while the existing owners remain active.

**Sources:** [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`r639_lower_town_runtime_performance_reverification.md`](r639_lower_town_runtime_performance_reverification.md), [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md), [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md), [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), and the focused commands listed above.

---

## R-538 independent rerun addendum (2026-08-23)

**Scope:** fresh verification-only rerun in the shared checkout at HEAD `bda5326ace979de572740b723bb18339abd5d66c`. No runtime, art, map, fixture, budget, threshold, or human-review files were changed. The current `content/maps/lower_town_slice.rrmap` SHA-256 is `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`.

**Decision:** **BLOCKED - keep R-538 in `in_review` and R-108 / P0-101 open.** Existing owners cover the actionable blockers; no duplicate follow-up task was created.

### Fresh focused results

All Godot suites used `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh --require-test-summary`. Known shutdown-only resource/RID leak diagnostics were not treated as substantive failures.

| Focused check | Fresh result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19/19** | Current Lower Town map, route, collision, navigation, and parity assertions pass in this checkout. |
| `test_burgher_house_tiers` | **5/5** | Tier/material-precedence contract passes; visual readability remains unproven. |
| `test_capture_lower_town_p0_101` | **5/5** | Capture packet contract passes; stable-ID visual acceptance remains blocked. |
| `test_kalev_smithy_map` | **16/16** | Smithy route and collision contract passes. |
| `test_map_object_chunk_streaming` | **7/7** | Object ownership and lifecycle contract passes. |
| `test_large_map_chunk_prototype` | **8/8** | Chunk ownership and route prototype contract passes. |
| `test_environment_kit_integration` | **5/5** | Shared environment-kit structural contract passes. |
| `test_urban_population_performance_cap` | **2/2** | Population-cap contract passes. |
| `test_vertical_slice_performance` | **4/4** | Authored budget/target-profile contract passes; this is not target-hardware evidence. |
| `test_performance_benchmark` | **5/5** | Benchmark schema/target contract passes; aggregate resident-budget acceptance remains open. |
| `test_map_view_3d_fortification` | **9 tests, 1 failure, 40 errors** | The run is blocked by the existing Lower Town neighbor/boundary fixture (`north edge needs its authored neighbor`) and related map diagnostics; it is not evidence of a new R-538 edit. |
| `test_map_camera_modes` | **11 tests, 2 failures, 266 errors** | `test_building_collision_pulls_camera_out` and `test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character` fail; global map diagnostics interrupt the remaining camera checks. |

Supporting checks: `python3 -m unittest tests.python.test_lower_town_p0_101_baseline -v` passes **4/4**; `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` passes **7** with **1 expected skip**; `python3 tools/report_slice_performance.py --check` passes; and `python3 tools/verify_map_activation.py` passes. `python3 tools/verify_map_composition.py` remains blocked by missing threshold cards `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`.

### Capture and clean-checkout boundary

`docs/reports/images/lower_town_p0_101/capture_manifest.json` contains **10** plates and **5** presets at `1280x720` with `gl_compatibility`, but its `map_fingerprint` remains `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`, which is stale against the current map SHA above. Plate records have no `stable_ids` field. The packet therefore remains package-integrity evidence only and cannot prove current-revision tier, material, roof, wear, special-building, fortification, or landmark acceptance.

The clean-load Python suite validates the gate implementation, not a successful product import. The current acceptance evidence continues to record the clean import blocker on tracked-HEAD shader preloads `res://scripts/characters/eye_material.gdshader` and `res://scripts/characters/hair_material.gdshader`, with the dependent shared-rig/GameState parse cascade owned by R-122/R-124. The older `elevation_area` / `elevation_ramp` parser blocker remains a later rerun boundary, not a new result of this addendum.

### Seven-clause disposition

1. **BLOCKED:** no stable-ID gameplay review proves ordinary repetition, materials, wear, or landmark classification.
2. **BLOCKED:** tier contracts pass, but matched day/night surface observations remain absent.
3. **BLOCKED:** exceptional structures are present structurally, but named canon/art silhouette approval is absent.
4. **BLOCKED for acceptance, PASS for packet integrity:** ten plates exist, but the packet is stale and lacks stable-ID observations.
5. **BLOCKED:** no named human canon/art reviewers have signed the required rows; A-009 remains conditional.
6. **PARTIAL - final acceptance BLOCKED:** most scoped contracts pass, while camera behavior, fortification boundary diagnostics, clean product import, resident-cost, and declared minimum-hardware evidence remain unresolved.
7. **BLOCKED:** required handoffs and upstream acceptance gates are not all resolved; existing task owners remain responsible.

**Closeout:** R-538 is complete as a deterministic blocked verification ledger. Keep R-538 in `in_review`, keep R-108 / P0-101 open, and do not promote any partial contract result to final acceptance.

---

## R-538 fresh verification addendum (2026-08-31)

**Scope:** independent verification-only rerun in the shared worktree. No runtime, art, map content, parity fixture, acceptance threshold, budget, or human-review outcome was changed. Existing unrelated WIP was preserved.

**Decision:** **BLOCKED - R-538 is complete as a verification artifact; keep R-538 in `in_review` and keep R-108 / P0-101 open.** The current owners already cover the unresolved blockers, so no duplicate follow-up task was created.

### Fresh source and packet audit

- `content/maps/lower_town_slice.rrmap` contains `99` building/landmark records with `99` unique stable IDs. Authored tier counts are `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=23`; `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch` are present.
- The current source SHA-256 is `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`, matching the manifest's `map_source_sha256`. The manifest's separate `map_fingerprint` remains `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`, so the packet is not current-revision acceptance evidence.
- `docs/reports/images/lower_town_p0_101/capture_manifest.json` contains `10` plates, `5` presets, `5` matched day/night pairs, `0` manifest errors, and all referenced outputs are present. Plate records do not contain `stable_ids` observations. The packet therefore passes package integrity only and does not prove tier, material, roof, wear, special-building, fortification, or landmark acceptance.
- `python3 tools/validate_asset_sources.py` passes with `2229` rows, `2016` inventory paths, and `2006` active runtime assets covered. `python3 tools/report_slice_performance.py --check` and `python3 tools/verify_map_activation.py` pass. `python3 tools/verify_map_composition.py` remains blocked by the baseline missing threshold card `toompea_small_castle`.

### Fresh focused verification

All Godot checks used `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh --require-test-summary`. Known shutdown-only ObjectDB/resource/RID leak lines were not treated as substantive failures.

| Focused check | Fresh result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19/19** | Current Lower Town map, route, collision, navigation, and parity contracts pass in the live checkout. |
| `test_burgher_house_tiers` | **6/6** | Tier/material-precedence contract passes; visual readability remains unproven. |
| `test_capture_lower_town_p0_101` | **9/9** | Capture packet contract passes; stable-ID visual acceptance remains blocked. |
| `test_kalev_smithy_map` | **16/16** | Smithy route and collision contract passes. |
| `test_map_terrain_chunks` | **6/6** | Terrain residency contract passes. |
| `test_large_map_chunk_prototype` | **8/8** | Large-map chunk and route prototype contract passes. |
| `test_map_object_chunk_streaming` | **7/7** | Object ownership and lifecycle contract passes. |
| `test_environment_kit_integration` | **5/5** | Shared environment-kit structural contract passes. |
| `test_map_view_3d_fortification` | **9/9** | Fortification renderer boundary contract passes; no human silhouette approval is implied. |
| `test_map_camera_modes` | **11/11** | Camera contract passes in this live checkout; this does not clear the historical clean-load or resident-budget blockers. |
| `test_vertical_slice_performance` | **4/4** | Authored budget/target-profile contract passes; this is not target-hardware evidence. |
| `test_performance_benchmark` | **5/5** | Benchmark schema/target contract passes; aggregate resident-budget acceptance remains open. |
| `test_urban_population_performance_cap` | **2/2** | Population-cap contract passes. |

The live focused batch totals **13 files, 107 tests, 0 failures, and 0 errors**. These are structural/runtime contract results only and do not promote the overall acceptance gate.

### Clean-checkout and remaining acceptance boundary

`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/verify_clean_checkout_load.sh` created the detached checkout, restored runtime LFS assets, and completed the import stage. The bounded clean load then failed with `4 files, 69 tests, 44 failures, and 191 errors`. The first actionable product diagnostics are `unknown_command` for `elevation_area` at lines 14, 20, and 22 and `elevation_ramp` at line 17 in `content/maps/lower_town_slice.rrmap`, followed by an invalid map definition. The checked runner rejected the command for those substantive diagnostics; shutdown-only leak messages were allowlisted. This is a clean product-load blocker, not a missing Godot binary or a report-only issue.

The final seven-clause disposition remains:

1. **BLOCKED:** no stable-ID-linked gameplay review proves ordinary repetition, materials, wear, or landmark classification.
2. **BLOCKED:** tier contracts pass, but matched day/night surface observations for all required tier, roof, material, and repair reads remain absent.
3. **BLOCKED:** exceptional structures are structurally present, but named canon/art silhouette approval is absent.
4. **BLOCKED for acceptance, PASS for packet integrity:** ten valid plates exist, but the packet fingerprint is stale and plate records lack stable-ID observations.
5. **BLOCKED:** no named human canon or art reviewers have signed the required rows; A-009 remains conditional.
6. **PARTIAL - final acceptance BLOCKED:** all current live focused suites pass, but clean product load, resident-node/memory caps, and minimum-hardware evidence remain unresolved; composition audit also has baseline registry drift.
7. **BLOCKED:** upstream and handoff owners remain open or conditional, including P0-100, R-487-R-489, R-490-R-492, R-564, and A-009.

**Closeout:** R-538 is complete as a deterministic **BLOCKED** ledger. Keep R-538 in `in_review`, keep R-108 / P0-101 open, and do not create duplicate follow-up tasks while R-578/P3-011, R-122/R-124, R-453/R-455/R-604, R-563, R-577, R-487-R-492, and the existing decomposition owners remain responsible.

**Sources:** [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json), [`r639_lower_town_runtime_performance_reverification.md`](r639_lower_town_runtime_performance_reverification.md), [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md), [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh), and the focused commands listed above.

## R-538 current verification addendum (2026-09-01)

**Scope:** independent verification-only rerun at source revision `2ab9dc1c864e4365bfaf95a0e7b0018d3fcbe4ab` in the shared worktree. This addendum changes acceptance evidence only. No runtime, art, map geometry, parity fixture, acceptance threshold, budget, or human-review outcome was changed; unrelated staged and untracked work was preserved. This section supersedes only the current verification boundary below. Earlier addenda remain historical records of their own snapshots.

**Decision:** **BLOCKED - keep R-538 in `in_review` and keep R-108 / P0-101 open.** The current revision does not provide an acceptance-grade clean load, current capture packet, or named human visual sign-off. Existing owners cover the blockers; no duplicate follow-up task was created.

### Current source and packet audit

- `git rev-parse HEAD` returned `2ab9dc1c864e4365bfaf95a0e7b0018d3fcbe4ab`.
- `sha256sum content/maps/lower_town_slice.rrmap` returned `67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e`.
- Parsing the current RRMap `building` and `landmark` records gives `91` records and `91` unique IDs: `53` houses, `36` walls, and `2` gate arches. The authored tier counts are `merchant_stone=14`, `merchant_timber=14`, and `craft_boda=15`. The source text contains `st_catherines_church`, `viru_gate_arch`, `viru_foregate_arch`, `viru_house_west`, and `viru_house_mid`.
- The preceding 2026-08-31 addendum recorded a different snapshot: `99` records, `craft_boda=23`, and source SHA `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`. That evidence is stale against this `HEAD` and must not be merged with the current counts.
- `docs/reports/images/lower_town_p0_101/capture_manifest.json` still contains `10` plates, `5` presets, `5` matched day/night pairs, `1280x720`, and `gl_compatibility`. Its `map_source_sha256` is the stale `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`, not the current source SHA. Its `map_fingerprint` remains `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`.
- All referenced packet outputs are present, but plate records contain no `stable_ids`; the five day/night observation entries are all `status=not_reviewed` with empty stable-ID arrays. The packet therefore passes file/package integrity only and cannot prove current-revision tier, material, roof, wear, repair, special-building, fortification, or landmark acceptance.

### Reproduction commands and results

The following Python checks were run from the repository root:

```bash
python3 -m unittest tests.python.test_lower_town_p0_101_baseline -v
# Ran 7 tests in 0.004s
# FAILED (failures=3): source SHA/record-count drift, tier/rear-workshop drift, and manifest/source drift

python3 tools/report_slice_performance.py --check
# PASS

python3 tools/verify_map_activation.py
# PASS

python3 tools/verify_map_composition.py
# FAIL: Composition audit: 3 enforced map(s), 3 error(s).
# The first Lower Town diagnostics are unknown_command for elevation_area/elevation_ramp;
# dependent invalid-map diagnostics also occur in the other enforced maps.

python3 -m unittest tests.python.test_verify_clean_checkout_load -v
# 7 tests passed with 1 expected skip; this validates the gate contract, not a successful product load
```

Each Godot focused check used the same checked invocation, with the listed filter substituted exactly:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_LOG_DIR=/tmp/r538-<filter> \
  tools/run_godot_checked.sh --require-test-summary r538-<filter> -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=<filter>
```

| Filter | Fresh checked result | Interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **1 file, 19 tests, 26 failures, 93 errors** | Current map load is blocked by the RRMap parser cascade; no route/parity assertion is promoted to acceptance. |
| `test_burgher_house_tiers` | **1 file, 5 tests, 92 failures, 12 errors** | The suite reports dependent missing-authored-ID/ordinary-tier assertions after map creation fails; the source-text inventory above is the authoritative current source audit. |
| `test_capture_lower_town_p0_101` | **1 file, 9 tests, 13 failures, 8 errors** | Capture runtime contract is blocked by the same map load failure; the existing packet remains package-integrity evidence only. |
| `test_kalev_smithy_map` | **1 file, 16 tests, 0 failures, 0 errors** | Structural smithy route/collision contract passes in isolation. |
| `test_map_terrain_chunks` | **1 file, 6 tests, 0 failures, 0 errors** | Terrain residency contract passes in isolation. |
| `test_large_map_chunk_prototype` | **1 file, 8 tests, 0 failures, 0 errors** | Large-map chunk and route prototype contract passes in isolation. |
| `test_map_object_chunk_streaming` | **1 file, 7 tests, 1 failure, 12 errors** | One boundary-ownership assertion and dependent map/parser diagnostics remain unresolved. |
| `test_environment_kit_integration` | **1 file, 5 tests, 26 failures, 34 errors** | Shared environment-kit checks are interrupted by the authored map parser cascade. |
| `test_map_view_3d_fortification` | **1 file, 8 tests, 6 failures, 45 errors** | Fortification checks cannot be accepted while the Lower Town fixture and Viru arch load fail. |
| `test_map_camera_modes` | **1 file, 11 tests, 0 failures, 35 errors** | No assertion failure was isolated, but parser/resource errors prevent a clean camera result. |
| `test_vertical_slice_performance` | **1 file, 4 tests, 0 failures, 0 errors** | Authored budget/target-profile contract passes; this is not target-hardware evidence. |
| `test_performance_benchmark` | **1 file, 3 tests, 0 failures, 0 errors** | Benchmark schema/target contract passes; resident-budget acceptance remains open. |
| `test_urban_population_performance_cap` | **1 file, 2 tests, 0 failures, 0 errors** | Population-cap contract passes. |

Known shutdown-only ObjectDB/resource/RID leak lines were not treated as substantive failures. Green structural contracts do not override the red current-source, parser, packet, visual, or human-review gates.

### Clean-checkout parser boundary

The clean product-load command was:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/verify_clean_checkout_load.sh
# detached checkout creation, runtime LFS restoration, and editor import completed
# load stage failed: 4 files, 70 tests, 49 failures, 196 errors
```

The first actionable diagnostics in the clean checkout are:

- `content/maps/lower_town_slice.rrmap:14:1`: `unknown_command` for `elevation_area`;
- `content/maps/lower_town_slice.rrmap:17:1`: `unknown_command` for `elevation_ramp`;
- `content/maps/lower_town_slice.rrmap:20:1`: `unknown_command` for `elevation_area`;
- `content/maps/lower_town_slice.rrmap:22:1`: `unknown_command` for `elevation_area`;
- subsequent `Invalid map definition` diagnostics report missing/invalid `map_id`, `size_cells`, `player_spawn`, `location`, `scope`, `palette`, and `fingerprint` fields because map creation did not complete.

The checked runner rejected the load-stage command for these substantive parser/resource diagnostics. This is a clean product-load blocker, not a missing Godot binary, a shutdown-only leak, or a report-only issue. R-453/R-455/R-604 own the RRMap elevation parser/compiler and clean-load boundary.

### Seven-clause current disposition

1. **BLOCKED:** no current stable-ID-linked gameplay review proves ordinary repetition limits, material variation, wear/repair readability, or landmark classification.
2. **BLOCKED:** authored tier counts are present in source, but current matched day/night surface observations remain absent and the focused tier/capture suites cannot complete cleanly.
3. **BLOCKED:** exceptional source records and gate-arch records exist, but reviewed 1343 silhouettes and named canon/art approval are absent.
4. **BLOCKED for acceptance, PASS for packet integrity:** ten 1280x720 plates and five day/night presets exist, but the packet source SHA is stale and all stable-ID observations are unreviewed/empty.
5. **BLOCKED:** no named human canon or art reviewers have signed the required rows; A-009 remains conditional.
6. **PARTIAL - final acceptance BLOCKED:** smithy, terrain, large-chunk, and authored performance contracts pass in isolation, while map loading, object streaming, environment/fortification integration, camera clean completion, resident-node/memory caps, and declared minimum-hardware evidence remain unresolved.
7. **BLOCKED:** upstream and handoff work remains open, so R-108 cannot move to `done`.

### Active blocker owners and closeout

- **RRMap parser and clean product load:** R-453/R-455/R-604.
- **Ordinary frontage, tier, wear, and gameplay-scale proof:** R-487/R-532, with R-491 capture support.
- **Exceptional landmark implementation and 1343 silhouette review:** R-488/R-492.
- **Playable-route art integration and route/runtime handoff:** R-489/R-534, with R-547/R-552/R-614 for map/parity/route verification.
- **Camera, resident cost, and minimum-hardware evidence:** R-577, R-578/P3-011, and R-563.
- **Readiness reconciliation:** R-564; parent R-108/P0-101 remains open.

**Closeout:** R-538 is complete as a deterministic **BLOCKED** verification ledger for this revision. Move R-538 to `in_review`, keep R-108 / P0-101 open, preserve all unrelated worktree changes, and do not create duplicate follow-up tasks while the owners above remain active.

**Sources:** [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap), [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json), [`tests/python/test_lower_town_p0_101_baseline.py`](../../tests/python/test_lower_town_p0_101_baseline.py), [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh), [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh), and the focused commands listed above.
