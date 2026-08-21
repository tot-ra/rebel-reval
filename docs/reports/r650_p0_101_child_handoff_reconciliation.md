# R-650 P0-101 child handoff reconciliation

**Task:** R-650 / P0-101: reconcile child handoffs before acceptance
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Checkout:** `0623bffc5f7bc7714de4156c18aaa59b7ccf0b0c` (`main`)
**Worktree:** shared checkout with unrelated staged, modified, and untracked WIP; this report is the only scoped production artifact
**Scope:** verification-only; no map, runtime, asset, capture, parity fixture, threshold, canon, or art-review decision was changed
**Decision:** **RECONCILED; BLOCKED FOR P0-101 ACCEPTANCE.**

## Decision rule

R-650 is complete when every P0-101 child handoff has a current board status, a concrete artifact or an explicit missing-artifact result, an acceptance boundary, and a named next owner. A child task status of `done` is not promoted to acceptance when its report records a blocked result. Structural contracts, source counts, packet integrity, and conditional reference-art review remain separate from gameplay-scale visual acceptance, human sign-off, clean product load, parity, resident budgets, and declared-hardware evidence.

This reconciliation closes the coordination gap for the child handoffs. It does not close R-108, and it does not move any child task to `done`.

## Board and source snapshot

The current board query and source audit establish the following state:

| Item | Current result | Acceptance meaning |
|---|---|---|
| R-108 / P0-101 | `todo` | Parent remains open. |
| R-109 / P0-100 | `in_progress` | Base layout, terrain, composition, and upstream handoff are unresolved. |
| R-213 / P2-067 | `done` | Tier assignment and wiring are structurally ready only. |
| R-6 / A-009 | `in_review` | Conditional reference-art direction; final gameplay sign-off is blocked. |
| Current RRMap | 99 records, 99 unique IDs; 51 tiered houses | Source inventory only. Counts do not prove visual coverage. |
| Current tier counts | `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23` | Structural tier coverage only. |
| Current map SHA-256 | `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50` | Identifies the current source revision. |
| Capture manifest | 10 plates, 5 day/night pairs, `1280x720`, 5 matching framing keys | Packet integrity only; manifest fingerprint predates the current RRMap revision. |

The eight current rear-workshop IDs are present in the source and remain visually unproven: `saddlers_rear_workshop`, `coopers_rear_workshop`, `sauna_rear_boda`, `rope_makers_rear_store`, `karja_rear_boda`, `brewery_rear_store`, `smithy_rear_shed`, and `carriers_barn`.

## Child handoff ledger

| Child gate | Board status | Concrete evidence | Current result | Acceptance blocker and next owner |
|---|---|---|---|---|
| R-612 ordinary-fabric acceptance | `in_progress` | [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md), [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md), [`p0_101_decomposition_coverage_audit.md`](p0_101_decomposition_coverage_audit.md) | Structural source/tier contract is available; visual acceptance is blocked. | No stable-ID-linked gameplay observation proves all three tiers, repeated frontage, wall/roof families, or wear/repair readability. Owner: R-487/R-532, with matched capture and review support. |
| R-613 exceptional-landmark acceptance | `in_progress` | [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md), [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md) | Exceptional routing and stable-ID boundary are structurally green; final art/history acceptance is blocked. | St. Catherine's, Viru Gate/foregate, walls, precinct boundaries, and special buildings lack stable-ID-linked day/night observations and named review. Owners: R-488/R-492/R-617. |
| R-614 playable-route integration | `in_progress` | [`r587_lower_town_route_integration_verification.md`](r587_lower_town_route_integration_verification.md), [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md), [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md) | Route endpoint, collision, and navigation checks are mostly green; final route acceptance is blocked. | Fresh `test_lower_town_slice_map` is 18/19 because canonical `walkability_sha256` differs: expected `57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f`, actual `0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944`. Owner: R-547/map-content owner, then R-489/R-534 rerun route and visual integration. |
| R-615 runtime and performance gates | `in_progress` | [`r639_lower_town_runtime_performance_reverification.md`](r639_lower_town_runtime_performance_reverification.md), [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md), [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md) | Focused contracts provide supporting evidence; product acceptance is blocked. | Clean import is blocked by missing tracked-HEAD eye/hair shaders; six camera assertions fail; production resident cost is over budget; Intel UHD 620 evidence is unavailable. Owners: R-122/R-124, R-577, R-578/P3-011, and R-563. |
| R-616 gameplay-scale day/night evidence | `done` | [`r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md), [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) | **Packet integrity PASS; visual acceptance BLOCKED.** | 10 outputs and 5 matched pairs are valid, but metadata contains route anchors rather than visible stable-ID observations, reviewer sign-off, or current-source coverage for the rear-workshop additions. Owners: R-560/R-561/R-487/R-488/R-492. |
| R-617 historical and art sign-off | `in_progress` | [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md), [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md), [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) | All 58 reviewed rows remain blocked. | No named human canon reviewer or human art reviewer is assigned; A-009 remains conditional. Owners: R-492/R-537, with R-488 and R-6 supplying reviewable production evidence. |
| R-618 final independent acceptance | `in_progress` | [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md), [`p0_101_decomposition_coverage_audit.md`](p0_101_decomposition_coverage_audit.md), [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md) | Coverage is reconciled; parent closeout is blocked. | R-109 remains open, R-6 remains conditional, implementation/runtime owners remain open, and child gates above are not all accepted. Owner: R-493/R-618 after upstream and child blockers change state. |

## Fresh scoped verification

The following checks were run against the current shared checkout with Godot 4.7.1. Known shutdown-only ObjectDB/resource-leak diagnostics followed the green summaries and were not used to waive substantive findings.

| Check | Result | Classification |
|---|---|---|
| `test_capture_lower_town_p0_101` | 1 file, 5 tests, 0 failures, 0 errors | Packet contract PASS only. |
| `test_burgher_house_tiers` | 1 file, 5 tests, 0 failures, 0 errors | Tier/source contract PASS only. |
| `test_map_view_3d_fortification` | 1 file, 8 tests, 0 failures, 0 errors | Fortification boundary PASS only. |
| `test_environment_kit_integration` | 1 file, 5 tests, 0 failures, 0 errors | Environment structural contract PASS only. |
| `test_lower_town_slice_map` | 1 file, 19 tests, 1 failure, 0 errors | **BLOCKED by canonical parity drift**, not by parser/runtime errors. 18 assertions pass. |
| Manifest and PNG audit | 10 files, 5 day, 5 night, 5 matching framing keys, no invalid outputs | Packet integrity PASS; no visual acceptance inferred. |
| Source audit | 99 records, 99 unique IDs, tier counts 14/14/23 | Source inventory PASS; no visual acceptance inferred. |

### Reproduction commands

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

bash tools/run_godot_checked.sh --require-test-summary r650-capture -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101

bash tools/run_godot_checked.sh --require-test-summary r650-tiers -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers

bash tools/run_godot_checked.sh --require-test-summary r650-fortification -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_3d_fortification

bash tools/run_godot_checked.sh --require-test-summary r650-environment -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_environment_kit_integration

bash tools/run_godot_checked.sh --require-test-summary r650-map -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_lower_town_slice_map
```

The map command's checked log records the single canonical parity failure and a zero-error summary. No parity fixture was regenerated because the authored map delta requires owner review first.

## Reconciliation outcome

**R-650 is complete as a deterministic child-handoff reconciliation, with a BLOCKED parent acceptance result.** The child set has no unowned acceptance surface:

1. R-612 owns ordinary-fabric visual proof.
2. R-613 owns exceptional landmark acceptance.
3. R-614 owns playable-route integration and parity handoff.
4. R-615 owns runtime, clean-load, camera, resident-budget, and hardware gates.
5. R-616 is complete for packet integrity but not visual acceptance.
6. R-617 owns named historical/art review.
7. R-618 owns final independent closeout after the preceding gates and upstream dependencies resolve.

No follow-up task is created. Existing owners already cover the parity, visual, historical/art, clean-load, camera, resident-budget, and minimum-hardware blockers. Keep R-108 open and do not promote any structural or packet-only PASS to final acceptance.

## Sources

- [`p0_101_decomposition_coverage_audit.md`](p0_101_decomposition_coverage_audit.md)
- [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md)
- [`r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md)
- [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md)
- [`r639_lower_town_runtime_performance_reverification.md`](r639_lower_town_runtime_performance_reverification.md)
- [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`r587_lower_town_route_integration_verification.md`](r587_lower_town_route_integration_verification.md)
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tests/godot/test_map_view_3d_fortification.gd`](../../tests/godot/test_map_view_3d_fortification.gd)
- [`tests/godot/test_environment_kit_integration.gd`](../../tests/godot/test_environment_kit_integration.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)

**Final status:** **RECONCILED; BLOCKED.**
