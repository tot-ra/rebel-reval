# R-559 Lower Town P0-101 dependency and handoff readiness

**Task:** R-559 / P0-101 dependency and handoff readiness preflight
**Parent:** R-108 / P0-101
**Map:** `lower_town_slice` / Workers' District
**Verification date:** 2026-08-18
**Worktree:** shared worktree contains unrelated modified and untracked WIP; this report uses only the scoped board queries, reports, stable-ID inventory, capture manifest, and focused tests.
**Decision:** **BLOCKED - the P0-101 handoff set is not ready for final closeout.**

## Scope and decision boundary

This preflight reconciles the P0-101 upstream contract and R-487-R-492 handoffs before R-538 consumes them. It does not alter runtime, art, map content, budgets, thresholds, camera behavior, human-review outcomes, or historical claims. A `PASS` below means only that the named structural or evidence artifact is internally present; it does not promote a source contract, capture packet, or review pre-read into final P0-101 acceptance.

The readiness result is **BLOCKED** because R-487, R-488, and R-489 are not resolved, R-490-R-492 are not `done`, upstream P0-100 and A-009 are not resolved, and the visual/historical rows remain explicitly blocked. Existing reports also contain stale statements that the dedicated capture directory is absent; the current checkout now contains that packet, but the packet still does not close the pending visual rows.

## Board reconciliation

Exact task-board statuses queried on 2026-08-18:

| Contract or handoff | Board ref | Status | Linked artifact or evidence | Readiness result |
|---|---|---|---|---|
| P0-100 Lower Town layout and terrain-density upstream | R-109 | `todo` | No resolved upstream handoff is recorded in the scoped board state | **BLOCKED** - upstream parent remains open |
| P2-067 Lower Town tier wiring | R-213 | `done` | `tests/godot/test_lower_town_slice_map.gd`, `tests/godot/test_burgher_house_tiers.gd`; source inventory in `docs/reports/lower_town_p0_101_landmark_inventory.md` | **PASS as structural prerequisite only**; not a substitute for authored production or visual acceptance |
| A-009 ordinary-house art sign-off | R-6 | `in_review` | `docs/reports/burgher_house_art_signoff.md` | **BLOCKED** - conditional reference-art review is not final gameplay-scale sign-off |
| Ordinary frontage variation and worn-material gaps | R-487 | `in_progress` | `docs/reports/r532_lower_town_ordinary_fabric_verification.md` | **BLOCKED** - source/contract boundary passes, gameplay-visual acceptance remains blocked |
| Exceptional Lower Town landmarks | R-488 | `in_progress` | `docs/reports/r533_lower_town_landmark_boundary_acceptance.md` | **BLOCKED** - final landmark art/history evidence is not closed |
| Playable-route art integration | R-489 | `in_progress` | `docs/reports/r534_lower_town_route_integration_verification.md` | **BLOCKED** - contract parity is reported, independent final handoff and visual occlusion proof are absent |
| Runtime, route, occlusion, and budget QA | R-490 | `in_review` | `docs/reports/lower_town_p0_101_runtime_qa.md` | **BLOCKED** - resident node/memory, camera, clean-load, and GPU/minimum-hardware findings remain |
| Matched day/night capture packet | R-491 | `in_review` | `docs/reports/lower_town_p0_101_capture_matrix.md`, `docs/reports/images/lower_town_p0_101/capture_manifest.json` | **BLOCKED for acceptance** - packet capability is complete, surface-by-surface review rows remain pending/blocked |
| 1343 landmark silhouette review | R-492 | `in_review` | `docs/reports/r492_lower_town_1343_landmark_silhouette_review.md` | **BLOCKED** - no named canon or art reviewer is assigned and all required rows remain blocked |

The board state therefore does not satisfy the R-559 requirement that every R-487-R-492 handoff have a resolved status and explicit final `PASS`/`BLOCKED` result. The handoffs do have linked reports and explicit blockers, but three are still `in_progress` and three are still `in_review`.

## Stable-ID and source contract reconciliation

The linked inventory and source checks agree on the following boundaries:

- `content/maps/lower_town_slice.rrmap` contains 91 authored `building`/`landmark` records with unique stable IDs: 53 houses, 36 walls, and 2 view-only gate arches.
- The ordinary tiered set contains 43 records: 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda`.
- The required non-ordinary acceptance set contains 48 stable IDs, including special/use-site buildings, Viru inner-gate and foregate records, sealed wall joins, wall bends, and smithy-yard fence walls.
- `st_catherines_church` is the exceptional `church` house boundary. Viru tower/jamb records remain collision-bearing `building wall` records, while `viru_gate_arch` and `viru_foregate_arch` remain view-only `gate_arch` landmarks.
- The focused source contracts pass: `test_lower_town_slice_map` is 19/19 and `test_burgher_house_tiers` is 5/5, with zero test failures and zero test errors. Godot emits known shutdown leak diagnostics after the green summaries; those diagnostics do not change the scoped test result.

These facts establish stable-ID ownership, tier assignment, and renderer boundaries. They do not establish production-complete landmark meshes, gameplay-scale material/wear readability, route-scale repetition limits, or named human approval.

## Capture packet reconciliation

The current checkout contains the dedicated R-491 packet, contrary to stale wording in older reports:

- `docs/reports/images/lower_town_p0_101/capture_manifest.json` exists and declares `map_id=lower_town_slice`, `renderer=gl_compatibility`, viewport `1280x720`, orthographic size `33.75`, and day/night times.
- The manifest lists eight output plates: four route presets, each with a day and night frame. Every output exists, decodes as `1280x720`, and has a non-zero pixel payload.
- Each day/night pair has the same `framing_key`, focus world, camera pitch/yaw, and route anchors. This is valid packet and reproducibility evidence.
- The current matrix still marks representative tiers, repeated frontage, material families, roof covers, wear/repaired states, special buildings, landmark approaches, and route-scale special-building proof as `pending` / **BLOCKED**. The packet is therefore a completed capture-capability handoff, not visual acceptance.

Stale wording that must not be used as current evidence:

| Artifact | Stale statement | Current reconciliation |
|---|---|---|
| `docs/reports/lower_town_p0_101_acceptance.md` | Says `docs/reports/images/lower_town_p0_101/` is absent | The directory and manifest now exist. R-538's final decision remains BLOCKED for independent reasons, so this is a report-integrity discrepancy, not a visual PASS. |
| `docs/reports/r532_lower_town_ordinary_fabric_verification.md` | Says no matched gameplay-scale packet exists | The packet exists, but its ordinary-fabric rows remain blocked because the images are not per-surface human review evidence. |
| `docs/reports/r492_lower_town_1343_landmark_silhouette_review.md` | Says R-491 has no dedicated route/landmark packet | The packet exists, but R-492 still correctly remains blocked because landmark rows are pending and human reviewers are unassigned. |
| `docs/reports/lower_town_p0_101_capture_matrix.md` | Contains a literal supplementary-image placeholder path `docs/reports/images/view3d/{kalev_smithy,lower_town_slice}_{day,night}.png` | This is not a real path and should not be counted as a missing acceptance artifact or as a link to a concrete image. The dedicated packet paths above are the actual evidence paths. |

These discrepancies should be reconciled by the existing acceptance-package task R-573 or the owner of the corresponding report. R-559 does not rewrite historical reports.

## Handoff blockers for R-538

1. **R-487 ordinary fabric:** remains `in_progress`; `r532` records structural PASS only and gameplay-visual BLOCKED. No final ordinary-fabric repetition, material, roof, or wear disposition is available.
2. **R-488 exceptional landmarks:** remains `in_progress`; `r533` keeps all non-ordinary final art/history rows blocked. Stable IDs are present, but implementation and visual acceptance are not closed.
3. **R-489 route integration:** remains `in_progress`; `r534` reports authored/contract parity but lacks the independent final handoff and surface-level gameplay occlusion review.
4. **R-490 runtime QA:** remains `in_review` with a blocked result. The linked report records 8472/7500 resident nodes, 446.2/280 MiB resident memory, failing camera assertions, missing clean-checkout load protection, and unmeasured non-headless GPU/minimum-hardware evidence.
5. **R-491 captures:** remains `in_review`. The packet is now present and structurally valid, but its acceptance matrix intentionally leaves the visual rows blocked pending review.
6. **R-492 human review:** remains `in_review` and explicitly records `Human canon reviewer: Not assigned` and `Human art reviewer: Not assigned`. No silhouette may be approved from the current pre-review.
7. **Upstream contract:** R-109/P0-100 is `todo`; R-6/A-009 is `in_review` with conditional reference-art approval. R-213/P2-067 is `done`, but only its structural tier-wiring contribution is ready.

## Deterministic readiness decision

**R-559 result: BLOCKED.** The required handoffs are linked and their blockers are explicit, but the dependency set is not resolved and R-538 cannot consume this preflight as a final P0-101 PASS. Keep R-108 open.

No new duplicate follow-up task is created: the implementation, capture, runtime, human-review, and package-integrity owners already exist as R-487-R-492, R-490, R-491, R-492, R-573, and the upstream rows R-109/R-6. The next consumer should use this report as the readiness ledger and preserve the exact owners above.

## Reproduction record

```text
Focused map contract:
Godot headless tests: 1 file(s), 19 test(s), 0 failure(s), 0 error(s).

Focused house-tier contract:
Godot headless tests: 1 file(s), 5 test(s), 0 failure(s), 0 error(s).

Capture packet audit:
8 plates; each 1280x720; all non-blank; four matching day/night framing keys.
```

Commands used:

```bash
tools/run_godot_checked.sh --require-test-summary r559-lower-town-map \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map

tools/run_godot_checked.sh --require-test-summary r559-house-tiers \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
```

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/reports/lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md)
- [`docs/reports/lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`docs/reports/lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`docs/reports/lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md)
- [`docs/reports/r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md)
- [`docs/reports/r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`docs/reports/r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`docs/reports/r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`docs/reports/burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
