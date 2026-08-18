# R-538 Lower Town P0-101 Closeout Verification

**Task:** R-538 - Verify and close Lower Town P0-101 acceptance (small)
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Worktree:** shared worktree with unrelated implementation WIP; only the scoped commands, authored map inspection, capture packet, and board statuses below are used as evidence.
**Decision:** **BLOCKED - R-538 verification is complete, but R-108 / P0-101 must remain open.** Move R-538 to `in_review`, not `done`.

## Scope

This is a verification-only closeout. It does not regenerate parity or chunk fixtures, edit runtime code, change map content, modify budgets or thresholds, promote supplementary images to gameplay acceptance, or assign human historical/art approval.

The seven R-108 clauses are evaluated separately so that green contracts are not mistaken for visual sign-off, clean product load, or target-hardware evidence.

## Current board reconciliation

| Ref | Status | Acceptance interpretation |
|---|---|---|
| R-487 | `in_progress` | Ordinary frontage, wear, and visual variation handoff remains open. |
| R-488 | `in_progress` | Exceptional landmark implementation handoff remains open. |
| R-489 | `in_progress` | Playable-route art integration handoff remains open. |
| R-490 | `in_review` | Runtime report is complete but retains resident-cost, camera, clean-load, and hardware blockers. |
| R-491 | `in_review` | Capture packet exists, but stable-ID surface coverage is not accepted. |
| R-492 | `in_review` | Landmark silhouette review has no named canon/art approval. |
| R-532 | `in_review` | Source/contract evidence exists; gameplay-scale ordinary-fabric acceptance remains blocked. |
| R-533 | `done` | Landmark boundary verification is structurally complete; final visual/history acceptance remains separate and blocked. |
| R-534 | `in_review` | Route/parity contracts exist; independent visual integration review remains open. |
| R-535 | `done` | Runtime/performance verification is complete with a blocked result. |
| R-536 | `done` | Capture packet-integrity audit is complete; surface-level visual rows remain blocked. |
| R-537 | `done` | Historical/art evidence audit is complete; no human approval was issued. |
| R-559 | `done` | Dependency preflight is complete with a blocked readiness result. |
| R-560 | `in_progress` | Capture capability exists, but the handoff remains open. |
| R-561 | `in_review` | Packet audit retains blocked stable-ID visual rows. |
| R-562 | `done` | Clean-load gate contract passes; clean product load remains blocked by RRMap parser diagnostics. |
| R-563 | `in_review` | Non-headless development-host evidence exists; declared Intel UHD 620 evidence is unavailable. |
| R-564 | `in_review` | Decomposition ledger is complete as blocked readiness, not an overall pass. |
| R-108 / P0-101 | `todo` | Parent must remain open. |

Upstream P0-100 / R-109 and P0-102 / R-110 remain `todo`; A-009 / R-6 remains conditional `in_review`. Existing owners cover the blockers, so no duplicate follow-up task is needed.

## Authored source and packet integrity

A scoped inspection of `content/maps/lower_town_slice.rrmap` reports:

- `99` building/landmark records and `99` unique stable IDs; no duplicate IDs.
- `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`.
- `st_catherines_church`, `viru_gate_arch`, and `viru_foregate_arch` are present.

The capture manifest at `docs/reports/images/lower_town_p0_101/capture_manifest.json` is structurally sound:

- `plates=10`, `presets=5`, `errors=0`.
- All 10 output files exist and have valid PNG signatures.
- All plates are `1280x720`; `day=5`, `night=5`; all 5 presets have a matched day/night pair.
- The manifest records map revision, renderer, camera intent, route anchors, time of day, and source task metadata.

This proves package integrity only. It does not prove that every required tier, material, roof, wear state, special building, fortification, or landmark has stable-ID-linked gameplay-scale acceptance observations.

## Focused verification rerun

Commands used the installed Godot 4.7.1 binary through `tools/run_godot_checked.sh --require-test-summary`, with `GODOT_BIN` exported before invocation.

| Focused suite/check | Result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19 tests, 1 failure** | Canonical parity fixture differs; failure reports authored footprint/door-side data. Do not regenerate the fixture in R-538. |
| `test_burgher_house_tiers` | **5/5** | Tier and material-precedence contract passes; visual readability is not proven. |
| `test_capture_lower_town_p0_101` | **5/5** | Capture contract and metadata requirements pass. |
| `test_kalev_smithy_map` | **16/16** | Smithy route and collision contract passes. |
| `test_map_terrain_chunks` | **6/6** | Terrain residency contract passes. |
| `test_large_map_chunk_prototype` | **8/8** | Chunk coordinate and ownership contract passes. |
| `test_map_object_chunk_streaming` | **7 tests, 1 failure** | Reviewed boundary inventory differs because current authored output includes additional rear/workshop records; do not accept or rebaseline here. |
| `test_vertical_slice_performance` | **4/4** | Authored metric and target-profile contract passes, not a hardware measurement. |
| `test_performance_benchmark` | **5/5** | Benchmark schema/target contract passes, not final budget acceptance. |
| `test_urban_population_performance_cap` | **2/2** | Population-cap contract passes. |
| `test_map_camera_modes` | **11 tests, 6 failures, 2 errors** | Building pull-out, eye-height, and follow-boom restoration remain red. The run also reports a shader tokenizer error caused by GDScript lint comments embedded in shader source. |
| `python3 tools/report_slice_performance.py --check` | **PASS** | Manifest and slice-gate schema are valid; this is not target-hardware evidence. |
| `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` | **7 passed, 1 expected skip** | Clean-checkout gate implementation contract passes. It does not prove product load. |

Existing R-490/R-535/R-562 evidence remains authoritative for the additional clean product-load and resource-budget boundary: `elevation_area` / `elevation_ramp` parser diagnostics, resident-node and resident-memory overages, and missing Intel UHD 620 measurement remain unresolved.

## Seven-clause verdict

1. **Ordinary repetition, materials, and landmark classification: BLOCKED.** Stable IDs and tier assignments are coherent, but parity/object-boundary fixtures are red and no signed gameplay-route repetition or stable-ID visual review exists.
2. **Three tiers, wall/roof families, and localized wear: BLOCKED.** Tier contract and packet integrity pass, but no stable-ID-linked gameplay-scale observation proves all required material, roof, and repair/wear reads.
3. **Exceptional landmarks and 1343 silhouettes: BLOCKED.** St. Catherine's and both Viru Gate view landmarks are authored, but R-492 has no named canon/art reviewers and no final silhouette approval.
4. **Matched gameplay-scale day/night evidence: BLOCKED for acceptance, PASS for package integrity.** The packet is 10 valid PNGs in 5 matched pairs, but surface-by-surface acceptance coverage is incomplete.
5. **Named historical/art review: BLOCKED.** No named human canon reviewer or human art reviewer has approved every required row.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** Smithy, terrain, large-chunk, tier, benchmark, and population-cap contracts pass, while Lower Town parity, object-boundary inventory, camera behavior, clean product load, resident budgets, and minimum-hardware evidence remain unresolved.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-487-R-489 and R-560 remain open; R-490-R-492 retain blocked/in-review outcomes; R-109/R-110 remain `todo`; A-009 remains conditional.

## Closeout

R-538 is complete as a deterministic blocked verification ledger. Keep R-108 / P0-101 `todo` and move R-538 to `in_review`. Do not create duplicate follow-up tasks: existing owners already cover ordinary frontage, exceptional landmarks, route integration, runtime/camera/parser budgets, capture coverage, human sign-off, decomposition, and minimum-hardware evidence.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`docs/reports/lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`docs/reports/r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`docs/reports/r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md)
- [`docs/reports/r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md)
- [`docs/reports/r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh)
