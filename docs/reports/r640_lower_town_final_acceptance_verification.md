# R-640 Lower Town P0-101 final independent acceptance verification

**Task:** R-640 / P0-101 decomposition closeout
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Checkout:** current shared worktree at `8097cd74770c6f88f05eea126f6b1f4913aad1d`
**Scope:** verification-only; no runtime, map, asset, threshold, fixture, canon, or art decision was changed
**Decision:** **BLOCKED - R-108 / P0-101 must remain open.**

## Decision rule

R-108 may move to `done` only when every one of its seven acceptance clauses has independent evidence, the P0-100/P2-067/A-009 upstream boundary is resolved, and no packet-integrity, source-only, headless-only, supplementary, development-host, or conditional evidence is promoted to final acceptance. A blocked clause remains blocked even when a related structural contract is green.

This report consumes the completed verification ledgers R-637 and R-639, the in-review historical/art ledger R-638, the current source inventory, and a fresh scoped rerun of the Lower Town acceptance contracts. It preserves the distinction between package integrity, authored source, runtime contracts, gameplay-scale visual acceptance, human review, clean product load, and hardware evidence.

## Upstream and handoff reconciliation

| Dependency or owner | Board state / evidence | R-108 impact |
|---|---|---|
| R-109 / P0-100 | `in_progress`; base layout/terrain-density handoff is not closed | **BLOCKED upstream prerequisite** |
| R-213 / P2-067 | `done`; tier keys and authored assignments are structurally present | **PASS for wiring only**, not visual or parity acceptance |
| R-6 / A-009 | `in_review`; conditional art-direction pass, final gameplay sign-off blocked | **BLOCKED upstream art boundary** |
| R-487 / P0-101b | `in_progress`; ordinary frontage, wear and variation owner | Ordinary-fabric clause remains open |
| R-488 / P0-101c | `in_progress`; exceptional landmark implementation owner | Landmark clause remains open |
| R-489 / P0-101d | `in_progress`; playable-route art integration owner | Route and visual handoff remains open |
| R-490 / P0-101e | `in_review`; runtime QA has a blocked result | Runtime/performance clause remains open |
| R-491 / P0-101f | `in_review`; packet exists but surface review is incomplete | Visual packet is not acceptance |
| R-492 / P0-101g | `in_review`; no named human canon/art approval | Historical/art clause remains blocked |
| R-532 / R-533 / R-534 | `in_review` / `done` / `in_review`; structural checks do not clear visual gaps | Downstream evidence remains partial |
| R-535 / R-536 / R-537 | `done`, each with blocked acceptance boundaries | No clause is promoted by completion status alone |
| R-637 | `done`; stable-ID gameplay evidence remains blocked | Stable-ID visual coverage is absent |
| R-638 | `in_review`; 58 ordinary/non-ordinary review rows are blocked | Human historical/art clause is not proven |
| R-639 | `done`; runtime/performance recheck is explicitly blocked | Clean load, camera, resident cost and hardware remain open |
| R-618 / R-538 | `in_progress` / `in_review` | Existing final-closeout owners remain open; this report does not supersede them |

## Seven-clause R-108 acceptance matrix

| # | R-108 clause | Verdict | Independent evidence and exact blocker | Owner / next action |
|---:|---|---|---|---|
| 1 | Ordinary fabric: all three tiers, material/roof/wear variety, and no unexplained repeated facade/material run | **BLOCKED** | Current source has 51 tiered houses: `merchant_stone=14`, `merchant_timber=14`, `craft_boda=23`; the tier contract passes 5/5. This proves authored assignment and renderer precedence only. No accepted gameplay observation proves log/plank/plaster/limestone, tile/shingle/thatch, localized wear/repairs, or repetition thresholds. A-009 remains conditional. | R-487 / R-532. Produce stable-ID-linked matched route evidence and named ordinary-fabric review. |
| 2 | Exceptional landmarks, including St. Catherine's and the 1343 Viru Gate state, are distinct from ordinary houses | **BLOCKED** | Source and structural boundaries are present: 99 unique records, including 48 required non-ordinary records; fortification contract passes 8/8 and environment contract passes 5/5. R-638 records no stable-ID visual observation or human approval for any non-ordinary row. The foregate/incomplete-1343 boundary also remains historically unresolved. | R-488 / R-492, with R-489 for route integration. Resolve the dated boundary, capture each required landmark, and obtain named review. |
| 3 | Matched gameplay-scale day/night evidence covers the required ordinary fabric and landmark approaches | **BLOCKED for acceptance; PASS for packet integrity only** | Fresh packet audit: 10 existing PNGs, 5 day/night pairs, `1280x720`, 5 matching framing keys, 0 file errors. `test_capture_lower_town_p0_101` passes 5/5. Manifest metadata contains route anchors and interaction targets, but no visible stable-ID, material, roof, wear, or reviewer annotations; generic route candidates are not promoted. | R-491 / R-536 / R-637. Extend or replace the packet only with direct stable-ID observations and preserve the current integrity result separately. |
| 4 | Stable-ID coverage proves every required tier, special building, fortification, gate arch, wall and rear-workshop observation | **BLOCKED** | Source extraction reports `99` records and `99` unique IDs; all eight R-547 rear-workshop IDs are reconciled in the inventory. The manifest contains no stable-ID metadata keys and R-637/R-638 record no visible stable-ID observations for the 51 tiered houses, 10 untiered houses, 36 wall records or 2 gate arches. Structural IDs are ownership evidence, not visual proof. | R-637 / R-638 handoff to R-487, R-488, R-489 and R-492. Annotate each required visible ID in matched day/night evidence; do not infer visibility from route coverage. |
| 5 | Playable route, patrols, transitions, collision, navigation, occlusion/chunk metadata and parity remain valid | **BLOCKED** | Fresh `test_lower_town_slice_map` result is 18/19: routes, collision, navigation and gate-span checks pass, but canonical Lower Town parity fails on the authored gameplay fingerprint. R-639 also records the current parity drift; no fixture was regenerated. Terrain/streaming focused contracts pass in the linked recheck, but that does not waive the parity mismatch. | R-547 / map-content owner and R-489 / R-534. Review the authored delta and regenerate the canonical fixture only after owner approval, then rerun route and chunk checks. |
| 6 | Clean product load, camera/runtime behavior, and resident budgets pass | **BLOCKED** | Clean-checkout gate reaches detached checkout and import, then stops during clean import on missing tracked-HEAD preloads `eye_material.gdshader` and `hair_material.gdshader`; MapView3D load is not reached. Earlier clean-load evidence records `elevation_area`/`elevation_ramp` parser errors as the next blocker after shaders. R-639 records 6/11 camera assertions failing and declared resident cost of 22,346 nodes / 552.163 MiB against 7,500 / 280 MiB. | R-122 / R-124 for shader assets; R-453 / R-455 / R-604 for the next parser/load boundary; R-577 for camera; R-578 / P3-011 for resident cost. Rerun from a clean imported checkout after each upstream fix. |
| 7 | Performance and declared minimum-hardware evidence pass without silent budget waivers | **BLOCKED** | `python3 tools/report_slice_performance.py --check` passes the manifest/schema contract, but R-639's production profile fails node and memory caps. CPU-side development-host metrics are supplementary. The declared `minimum-hardware-intel-uhd-620` non-headless measurement is unavailable; Apple M5 Pro and headless dummy-renderer results cannot certify it. | R-563 / P3-011 for a real declared-target run or explicit named maintainer decision; R-578 / P3-011 for resident-cost overage. Do not raise caps silently. |

## Fresh verification record

Commands were run with `/Applications/Godot.app/Contents/MacOS/Godot` where applicable. The clean-checkout command was allowed to fail so its first reproducible blocker could be retained.

| Check | Result | Acceptance classification |
|---|---|---|
| `tools/verify_clean_checkout_load.sh` | **BLOCKED during clean import** by missing eye/hair shader preloads | Product clean-load failure, not a PATH limitation; map parser stage was not reached |
| `test_capture_lower_town_p0_101` | **5 tests, 0 failures, 0 errors** | Packet contract PASS only |
| `test_burgher_house_tiers` | **5 tests, 0 failures, 0 errors** | Authored tier contract PASS only |
| `test_lower_town_slice_map` | **19 tests, 1 failure, 0 errors** | Current parity blocker; no fixture change made |
| `test_map_view_3d_fortification` | **8 tests, 0 failures, 0 errors** | Structural fortification PASS only |
| `test_environment_kit_integration` | **5 tests, 0 failures, 0 errors** | Structural environment PASS only |
| `tests.python.test_verify_clean_checkout_load` | **7 tests, 6 passed, 1 expected skip** | Gate implementation contract PASS; product load remains blocked |
| `python3 tools/report_slice_performance.py --check` | **PASS** | Schema/manifest contract only, not hardware or aggregate budget acceptance |
| Dedicated PNG/manifest audit | **10 plates, 5 day, 5 night, 5 framing pairs, 0 errors** | Package integrity PASS; stable-ID visual acceptance remains blocked |
| Source inventory audit | **99 records, 99 unique IDs; tiers 14/14/23** | Authored source PASS; visual acceptance remains blocked |

Known shutdown-only Godot ObjectDB/resource leak lines were not used to waive substantive failures. R-638 additionally records 9 plot-dressing geometry failures in `test_map_view_3d_mesh`; those are pre-existing runtime/asset evidence and are not repaired by this verification-only task.

## Final decision and handoff

**R-640 is complete as a reproducible BLOCKED verification artifact. R-108 / P0-101 may not move to `done`.**

The exact blockers that downstream closeout owners must consume are:

1. no stable-ID-linked gameplay observations for ordinary tiers, rear workshops, special buildings, walls or gate arches;
2. no named human canon or art approval, with R-638's 58 review rows still blocked;
3. current Lower Town parity drift;
4. clean import blocked by missing shader preloads, with the RRMap parser blocker still pending as the next stage;
5. six camera assertion failures and resident over-budget measurements;
6. no declared Intel UHD 620 measurement; and
7. unresolved P0-100 and conditional A-009 upstream status.

No new follow-up task is created. Existing owners cover each blocker: R-109, R-6, R-487-R-492, R-547, R-577, R-578/P3-011, R-122/R-124, R-453/R-455/R-604, R-563, and the R-618/R-538 closeout boundary.

## Sources

- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md)
- [`r638_lower_town_historical_art_signoff_reconciliation.md`](r638_lower_town_historical_art_signoff_reconciliation.md)
- [`r639_lower_town_runtime_performance_reverification.md`](r639_lower_town_runtime_performance_reverification.md)
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md)
- [`p0_101_gpu_budget_evidence.md`](p0_101_gpu_budget_evidence.md)
- [`p0_101_runtime_performance_gate_ledger.md`](p0_101_runtime_performance_gate_ledger.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`tools/verify_clean_checkout_load.sh`](../../tools/verify_clean_checkout_load.sh)
- [`tools/report_slice_performance.py`](../../tools/report_slice_performance.py)
