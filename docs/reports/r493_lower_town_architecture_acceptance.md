# R-493 Lower Town architecture and landmark acceptance verification

**Task:** R-493 / P0-101h
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-19
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. This report uses only the scoped acceptance artifacts, task-board statuses, and focused commands below.
**Decision:** **PACKAGE AND CONTRACT EVIDENCE PASS; COMPLETE P0-101 ACCEPTANCE BLOCKED.**

## Scope and decision boundary

This is a verification-only closeout. It does not modify map content, runtime behavior, parity fixtures, budgets, captures, or human review assignments. A green source or packet contract is recorded separately from gameplay-scale visual acceptance, historical/art sign-off, clean product load, and target-hardware evidence.

R-493 is therefore complete as a deterministic acceptance ledger, but it must remain `in_review` while the parent R-108 / P0-101 gate is blocked.

## Current board reconciliation

| Ref | Status | Acceptance interpretation |
|---|---|---|
| R-487 | `in_progress` | Ordinary frontage, material variation, and wear handoff remains open. |
| R-488 | `in_progress` | Exceptional landmark implementation handoff remains open. |
| R-489 | `in_progress` | Playable-route art integration handoff remains open. |
| R-490 | `in_review` | Runtime QA retains camera, resident-cost, clean-load, and minimum-hardware blockers. |
| R-491 | `in_review` | Matched packet exists, but stable-ID surface observations are not accepted. |
| R-492 | `in_review` | Landmark silhouette review has no named canon/art approval. |
| R-532 | `in_review` | Structural ordinary-fabric evidence exists; gameplay-scale readability remains blocked. |
| R-534 | `in_review` | Route/parity contracts exist; independent visual integration review remains open. |
| R-560 | `in_progress` | Capture capability is reproducible, but the handoff remains open. |
| R-561 | `in_review` | Packet audit passes integrity but retains blocked visual rows. |
| R-564 | `in_review` | Decomposition readiness is a blocked ledger, not an overall pass. |
| R-108 / P0-101 | `todo` | Parent must remain open. |

Existing owners cover every unresolved finding. No duplicate follow-up task is created.

## Scoped verification record

| Check | Current result | Acceptance interpretation |
|---|---|---|
| `test_lower_town_slice_map` | **19 tests, 1 failure, 0 errors** | Route and authored contracts run, but canonical parity differs at the footprint/door-side fixture. Do not regenerate the fixture in R-493. |
| `test_burgher_house_tiers` | **5 tests, 0 failures, 0 errors** | Tier, material precedence, roof variation, and exceptional-registry contract passes; this is not visual sign-off. |
| `test_capture_lower_town_p0_101` | **5 tests, 0 failures, 0 errors** | Capture metadata, production map target, matched-pair contract, and output checks pass. |
| Capture manifest audit | **10 plates, 5 presets, 0 errors** | All outputs exist, decode as valid `1280x720` PNGs, and provide five day/night pairs. This proves packet integrity only. |
| `test_verify_clean_checkout_load` | **7 passed, 1 expected skip** | Clean-load gate implementation contract passes; it does not prove that the product loads from a clean checkout. |
| Existing runtime/performance evidence | **BLOCKED** | R-490/R-535 retain camera failures, resident-node/memory overages, parser/load boundary, and missing declared Intel UHD 620 measurement. |
| Historical/art evidence | **BLOCKED** | R-492/R-537 record no named human canon or art reviewer and no per-row silhouette approval. |

The Godot focused suites were run with `/Applications/Godot.app/Contents/MacOS/Godot` on the current shared checkout. The map failure was:

```text
FAIL test_lower_town_slice_matches_canonical_parity_fixture
lower_town_slice gameplay data changed; regenerate only after reviewing the canonical diff
expected: "footprint"
actual:   "door_side": "north"
```

The tier and capture suites completed with exit status 0. Godot emitted only the known shutdown ObjectDB/resource-leak diagnostics after the green runs; those diagnostics do not change the scoped test summaries.

## Seven-clause acceptance verdict

1. **Ordinary repetition, material runs, and landmark classification: BLOCKED.** Source IDs and tier contracts are coherent, but the parity fixture is red and no signed route-scale repetition/material review exists. Owners: R-487, R-532, R-534.
2. **Three tiers, wall/roof families, and localized wear: BLOCKED.** The tier contract and packet integrity pass, but no stable-ID-linked gameplay observation proves that all required surfaces and repaired states read at gameplay scale. Owners: R-487, R-532, R-561.
3. **Exceptional landmarks and Spring 1343 silhouettes: BLOCKED.** St. Catherine's, inner Viru Gate, foregate, walls, and special-use records are structurally present, but R-492/R-537 issue no human approval. Owners: R-488, R-489, R-492.
4. **Matched gameplay-scale day/night evidence: PASS for packet integrity, BLOCKED for acceptance.** The current manifest has ten valid PNG plates in five matched pairs, but the rows do not provide stable-ID-linked observations for every required surface. Owners: R-491, R-536, R-561.
5. **Named historical/art review: BLOCKED.** No named canon or art reviewer has signed the required rows. Owner: R-492/R-537.
6. **Routes, collision, navigation, occlusion, parity, and performance: PARTIAL - final acceptance BLOCKED.** Tier and capture contracts pass, but Lower Town parity remains red and R-490 retains camera, resident-cost, clean-load, and minimum-hardware blockers. Owners: R-490, R-535, R-563, R-453/R-455.
7. **Upstream blockers and handoff boundary: BLOCKED.** R-487-R-489 and R-560 remain open; R-490-R-492, R-532, R-534, R-561, and R-564 retain unresolved acceptance boundaries; R-108 remains `todo`.

## Closeout

R-493 is complete as a reproducible **BLOCKED** verification ledger. Keep R-493 in `in_review` and keep R-108 / P0-101 open. Do not promote source contracts, generic route crops, packet integrity, headless measurements, or development-host evidence to final historical/art or minimum-hardware acceptance.

The next action is to resolve the existing owner-backed findings, then rerun this ledger against the current map revision. No new task is needed because the board already contains owners for ordinary frontage, exceptional landmarks, route integration, capture review, runtime budgets, parser/load, and human sign-off.

## Sources

- [`docs/reports/lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`docs/reports/r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`docs/reports/r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`docs/reports/r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`docs/reports/r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md)
- [`docs/reports/r561_lower_town_gameplay_evidence_audit.md`](r561_lower_town_gameplay_evidence_audit.md)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tests/python/test_verify_clean_checkout_load.py`](../../tests/python/test_verify_clean_checkout_load.py)
