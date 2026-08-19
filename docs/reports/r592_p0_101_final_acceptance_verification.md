# R-592 P0-101 final independent acceptance verification

**Task:** R-592 / P0-101 decomposition: final independent acceptance verification
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-19
**Map:** `lower_town_slice` / Workers' District
**Checkout:** shared worktree with unrelated staged, modified, deleted, and untracked WIP
**Decision:** **BLOCKED - do not close R-108 or promote P0-101 to PASS.**

## Decision rule

R-108 may be recommended for closure only when every decomposition dependency is `done` with a PASS result, every acceptance clause is independently evidenced, and no supplementary, orthographic, headless-only, development-host-only, silent-budget, or ordinary-house-substitution evidence is promoted. A package-integrity PASS is not a visual or runtime acceptance PASS.

All six decomposition dependencies were queried with `tasks.get`:

| Ref | Board status | Result consumed by R-592 |
|---|---:|---|
| R-590 | `done` | **BLOCKED** ordinary-fabric handoff; `merchant_stone`, `craft_boda`, and plot dressing production evidence is missing; `merchant_timber` lacks clean tracked delivery and stable-ID gameplay proof. |
| R-589 | `done` | **BLOCKED** final 1343 silhouette acceptance; all 48 required non-ordinary records are structurally reconciled, but route-scale stable-ID observations and named human canon/art review are absent. |
| R-587 | `done` | **BLOCKED** route handoff; structural route checks are mostly green, but current parity and reviewed object-chunk ownership drift remain. |
| R-588 | `done` | **BLOCKED** visual acceptance; packet integrity is green at 10 plates / 5 matched pairs, but no visible stable-ID observations or reviewer sign-off exist. |
| R-591 | `done` | **BLOCKED** runtime/performance gates; clean load, camera, resident budgets, aggregate caps, shutdown diagnostics, and declared minimum-hardware measurement are not all green. |
| R-487 | `in_progress` | Parent ordinary-frontage/wear owner is still open. |
| R-488 | `in_progress` | Parent exceptional-landmark owner is still open. |
| R-489 | `in_progress` | Parent playable-route integration owner is still open. |

The parent R-108 remains `todo`. No follow-up task is created: every actionable blocker already has an existing owner.

## Independent rerun record

The smallest applicable checks were rerun against the current checkout without changing map data, fixtures, runtime code, camera behavior, budgets, assets, or review records:

| Check | Result | Interpretation |
|---|---|---|
| `python3 tools/report_slice_performance.py --check` | **PASS** | Manifest and authored slice-gate schema are valid. This is not a production resident-budget or hardware PASS. |
| `python3 -m unittest tests.python.test_verify_clean_checkout_load -v` | **PASS: 7 tests, 1 expected skip** | The clean-checkout gate contract is tested. The product clean-load stage is separately blocked below. |
| `test_capture_lower_town_p0_101` | **PASS: 5/5** | Capture contract, route metadata, deterministic presets, and existing output presence pass. |
| `test_burgher_house_tiers` | **PASS: 5/5** | Authored tier assignment and ordinary/exceptional routing contracts pass. This is not visual production-kit evidence. |
| `test_lower_town_slice_map` | **BLOCKED: 18/19** | Route/collision/navigation checks pass, but canonical parity fails because authored data has `door_side` where the fixture expects `footprint`. The fixture was not changed. |
| `python3 tools/verify_map_conversion_parity.py` | **FAIL** | Lower Town parity filter reproduces the same `test_lower_town_slice_map` failure; anchor accounting remains 11/11 and Kalev Smithy remains green. |
| Dedicated packet audit | **PASS for integrity only** | Current manifest has 10 plates, 5 presets, 5 matched day/night pairs, `1280x720`, `gl_compatibility`, and 0 packet errors. Stable-ID visual coverage remains absent. |
| `tools/verify_clean_checkout_load.sh` | **BLOCKED** | Detached checkout creation, 38 LFS object restore, and clean import pass. Load fails first on unknown RRMap commands `elevation_area` (lines 14, 20, 22) and `elevation_ramp` (line 17), followed by dependent MapView3D failures. |

Known Godot shutdown ObjectDB/resource-leak diagnostics are recorded but not used to waive the parity, parser, visual, or runtime blockers.

## R-108 acceptance matrix

| R-108 clause | Verdict | Evidence and first unresolved owner/action |
|---|---|---|
| Ordinary three-tier fabric, no unexplained repetition/material runs, worn or repaired variation | **BLOCKED** | R-590 proves source tier counts and focused contract only. `merchant_stone` and `craft_boda` kits plus plot dressing are absent; `merchant_timber` is not cleanly handed off. No stable-ID gameplay-scale observation proves tier/material/roof/wear readability. Owners: R-487, R-209, R-211, R-212. |
| Required exceptional buildings and 1343 silhouettes, including St. Catherine's and Viru Gate | **BLOCKED** | R-589 reconciles all 48 required non-ordinary IDs and proves walls, jambs, towers, and view-only arches do not count as ordinary houses. It records no stable-ID route-scale observations and no named human canon/art review. Owners: R-488, R-492. |
| Playable-route integration, routes, transitions, collision, navigation, occlusion, and chunk ownership | **BLOCKED** | R-587 records green endpoint/transition/collision/navigation subchecks, but current Lower Town parity is 18/19 and reviewed object-chunk ownership is 6/7. The rerun reproduces the parity failure. Owners: R-489 and the current map/content handoff owner; R-534 remains the integration boundary. |
| Matched day/night gameplay-scale evidence for every required tier, material, roof, wear state, special building, and landmark | **BLOCKED for acceptance; PASS for packet integrity only** | R-588 and the rerun establish 10 valid non-blank `1280x720` PNGs in 5 matched pairs and `test_capture_lower_town_p0_101` 5/5. Manifest rows contain route anchors but no visible stable-ID observations and no reviewer sign-off. Owner: R-489/R-491/R-588 handoff, with R-487/R-488 surface coverage. |
| Historical/art sign-off for all required 1343 silhouettes and explicit no-substitution boundary | **BLOCKED** | R-589 explicitly records no assigned human canon reviewer and no assigned human art reviewer. Structural renderer boundaries pass, but no silhouette approval exists. Owners: R-488 and R-492. |
| Clean-checkout load, runtime camera, occlusion/streaming, resident/performance budgets, and declared minimum hardware | **BLOCKED** | R-591 records camera failures, clean-load parser errors, current parity/chunk drift, 12,370 nodes / 478.987 MiB against 7,500 / 280 caps, aggregate performance-cap failure, non-shutdown diagnostics, and no real Intel UHD 620 measurement. Owners: R-453/R-455, R-577, R-578/P3-011, R-563, and R-490 boundary. |
| Upstream handoffs and closure readiness | **BLOCKED** | Parent owners R-487/R-488/R-489 remain `in_progress`; all decomposition ledgers are not PASS; R-108 remains `todo`. Do not promote P0-102, conditional reference-art review, packet integrity, or development-host metrics to P0-101 acceptance. Owners: existing handoff owners and R-108 closeout. |

## Final disposition

**R-592 result: BLOCKED.** The independent verification task is complete as a deterministic decision, but R-108 / P0-101 must remain open. The first closure blockers are:

1. land and verify the missing ordinary production kits and plot dressing, then link visible stable IDs to matched day/night route evidence;
2. obtain named historical/art review for every exceptional and fortification row without ordinary-house substitution;
3. reconcile current parity and reviewed chunk ownership before claiming route integration;
4. resolve clean-checkout elevation-command loading, camera/runtime errors, resident caps, and declared Intel UHD 620 measurement.

No task-board follow-up was added because these actions are already owned by R-209, R-211, R-212, R-487, R-488, R-489, R-490, R-492, R-453/R-455, R-563, and R-578/P3-011.

## Sources

- [`R-590 ordinary-fabric handoff`](r590_lower_town_ordinary_fabric_handoff.md)
- [`R-589 exceptional-boundary reconciliation`](r589_lower_town_exceptional_boundary_reconciliation.md)
- [`R-587 route integration verification`](r587_lower_town_route_integration_verification.md)
- [`R-588 gameplay packet audit`](r588_lower_town_gameplay_packet_audit.md)
- [`R-591 runtime/performance gate ledger`](p0_101_runtime_performance_gate_ledger.md)
- [`R-108 historical acceptance ledger`](lower_town_p0_101_acceptance.md)
- [`P0-101 capture matrix`](lower_town_p0_101_capture_matrix.md)
- [`capture manifest`](images/lower_town_p0_101/capture_manifest.json)
- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town parity fixture`](../../tests/fixtures/maps/lower_town_slice.parity.json)
- [`test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`report_slice_performance.py`](../../tools/report_slice_performance.py)
- [`verify_map_conversion_parity.py`](../../tools/verify_map_conversion_parity.py)
- [`verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
