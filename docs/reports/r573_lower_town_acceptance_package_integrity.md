# R-573 P0-101 acceptance package integrity verification

**Task:** R-573 - P0-101 post-closeout acceptance package integrity check
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Worktree:** shared worktree contains unrelated modified and untracked WIP; this report changes no runtime, art, map content, budgets, thresholds, or human-review records.
**Decision:** **PACKAGE INTEGRITY PASS; FINAL P0-101 ACCEPTANCE BLOCKED.**

## Scope and decision boundary

This is a deterministic package-integrity check for R-538's seven-clause closeout. It verifies the acceptance and capture reports, their scoped local links, the dedicated R-491 manifest and plate outputs, stable-ID references, supplementary-evidence boundaries, and the current board statuses. It does not replace visual review, historical/art sign-off, runtime acceptance, clean-checkout acceptance, or minimum-hardware measurement.

A package-level `PASS` below means that the named artifact is present and internally coherent. It does not promote any `pending`, `BLOCKED`, or supplementary-only evidence to acceptance.

## Verification summary

| Check | Result | Evidence |
|---|---|---|
| R-538 seven-clause matrix | **PASS as structure** | `lower_town_p0_101_acceptance.md` contains seven numbered clause rows, each with an explicit `BLOCKED` or `PARTIAL - final acceptance BLOCKED` result. |
| Scoped report links | **PASS** | Six scoped reports were checked; 66 local Markdown links resolved with zero missing targets. Intentional placeholder paths containing `{...}` were excluded from filesystem resolution because the matrix labels them supplementary and non-concrete. |
| Capture manifest | **PASS** | `capture_manifest.json` parses as schema `r-560-lower-town-p0-101-capture-v1`, map `lower_town_slice`, renderer `gl_compatibility`, viewport `1280x720`, and eight plates. |
| Manifest outputs | **PASS** | All eight manifest outputs exist, have valid PNG signatures, decode successfully, and declare `1280x720` images with non-empty compressed pixel data. |
| Day/night parity | **PASS** | Four presets each have exactly one `day` and one `night` output; every pair matches on framing key, focus cell/world, camera pitch/yaw, and orthographic size. |
| Stable-ID reconciliation | **PASS** | The authored source contains 91 unique `building`/`landmark` records. R-492 contains 48 unique non-ordinary silhouette verdict rows; every R-492 ID is present in the R-486 inventory. |
| Supplementary-only boundary | **PASS** | R-491 explicitly keeps whole-map, calibration, debug, and conversion images supplementary; the dedicated packet is not treated as per-surface visual sign-off. |
| Acceptance outcome | **BLOCKED** | Visual rows remain pending/blocked, human reviewers are unassigned, R-487-R-489 remain open, and R-490/R-492 retain blocking findings. |

## Seven-clause reconciliation

R-538's exact final decision is preserved: **BLOCKED - do not close R-108 or promote P0-101 to accepted.** The current package check does not rewrite that decision.

| R-538 clause | Package-integrity result | Final acceptance state and owner |
|---|---|---|
| 1. Ordinary repetition and landmark classification | **PASS as linked source evidence only** | **BLOCKED** for route-scale visual repetition and presentation. R-487/R-532 own ordinary-fabric evidence; R-488/R-533 own exceptional boundaries. |
| 2. Three tiers, material families, roofs, wear/repairs | **PASS as matrix contract only** | **BLOCKED** because the matrix keeps all representative tier/material/roof/wear rows pending. R-487/R-532, with capture/review support from R-536/R-561. |
| 3. Exceptional landmark silhouettes | **PASS as stable-ID linkage only** | **BLOCKED**. R-492 has 48 explicit blocked verdict rows; no human approval is inferred. R-488/R-492 own the unresolved implementation and review. |
| 4. Matched gameplay-scale day/night captures | **PASS for packet integrity** | **BLOCKED for surface acceptance**. The eight-plate packet is valid and reproducible, but it does not cover every required surface row. R-491/R-536/R-561 remain open. |
| 5. Human historical/art review | **PASS as explicit blocker recording** | **BLOCKED**. R-492 records no assigned canon or art reviewer; R-537 remains the owner. |
| 6. Runtime, route, collision, navigation, occlusion, parity, and budgets | **PASS as linked report integrity** | **PARTIAL - final acceptance BLOCKED**. R-490/R-535 retains resident node/memory, camera, clean-load, and GPU/minimum-hardware findings; R-563 owns the unmeasured minimum-hardware evidence. |
| 7. Upstream blockers and P0-102 boundary | **PASS as explicit status ledger** | **BLOCKED**. Open upstream and decomposition owners remain recorded; R-559 is complete as a blocked readiness ledger, while R-564 remains open. |

## Capture packet audit

Manifest outputs, in manifest order:

- `street_start_to_smithy_door_day.png` and `_night.png`
- `smithy_door_to_brewery_door_day.png` and `_night.png`
- `brewery_door_to_checkpoint_west_day.png` and `_night.png`
- `checkpoint_west_to_checkpoint_east_day.png` and `_night.png`

The packet has the expected reproducibility metadata: `lower_town_slice`, `gl_compatibility`, `1280x720`, gameplay orthographic size `33.75`, camera pitch `-30.0`, yaw `45.0`, focus cells/world positions, route anchors, and the map fingerprint recorded by the manifest. The focused Godot contract passed:

```text
Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s).
```

The checked runner accepted only the documented shutdown DEF-002 resource-leak diagnostics. No packet output is missing or undecodable.

This is packet evidence, not visual approval. The capture matrix still marks these rows `pending` / **BLOCKED**: all three ordinary tiers as visual families, repeated frontage, log/plank/plaster/limestone, tile/shingle/thatch, localized wear/repairs, nine special/use-site buildings, St. Catherine's, inner Viru Gate, foregate, fortification continuity, and route-scale proof that special buildings are not enlarged ordinary houses.

## Current status reconciliation

The exact task-board statuses consumed by this report are:

| Ref | Status | Integrity/acceptance interpretation |
|---|---|---|
| R-487 | `in_progress` | Ordinary frontage/wear handoff open; no final visual acceptance. |
| R-488 | `in_progress` | Exceptional landmark implementation handoff open. |
| R-489 | `in_progress` | Route art integration handoff open; contract parity does not equal visual sign-off. |
| R-490 | `in_review` | Runtime QA report is blocked by recorded budget/camera/load/GPU findings. |
| R-491 | `in_review` | Capture packet is structurally complete; surface review remains blocked. |
| R-492 | `in_review` | 48 silhouette rows remain blocked; named human reviewers are absent. |
| R-532 | `in_review` | Ordinary-fabric verification is blocked at gameplay-visual acceptance. |
| R-533 | `done` | Boundary verification is complete, but does not close the final art gate. |
| R-534 | `in_review` | Route integration contract evidence is present; independent visual handoff remains blocked. |
| R-535 | `done` | Runtime verification is complete with a blocked gate result. |
| R-536 | `todo` | Dedicated packet acceptance audit remains open. |
| R-537 | `todo` | Historical/art sign-off verification remains open. |
| R-559 | `done` | Dependency preflight is complete with a deterministic BLOCKED result. |
| R-560 | `in_progress` | Capture capability task remains open on the board despite the generated packet being present. |
| R-561 | `todo` | Decomposition capture-packet audit remains open. |
| R-562 | `done` | Clean-checkout gate exists, but its report records the upstream parser/load blocker. |
| R-563 | `todo` | Minimum-hardware/GPU evidence remains unmeasured. |
| R-564 | `todo` | Decomposition-gap reconciliation remains open. |

The board state and reports therefore agree on the outcome: package integrity is green, but final P0-101 acceptance is not.

## Stale or contradictory evidence retained

R-538 and older linked reports still state that the dedicated capture directory is absent. That statement is stale against the current checkout: the directory, manifest, and eight PNG outputs exist and pass this audit. The contradiction is recorded here rather than rewriting the historical R-538 closeout or changing its overall result.

The stale absence claim does not erase the valid blocker. R-538 clause 4 remains blocked because the matrix does not claim that the packet covers every required acceptance surface, and clauses 2, 3, 5, 6, and 7 retain independent blockers. Supplementary `view3d`, ADR-0018 calibration, debug, and conversion images remain supplementary only.

## Deterministic closeout

**R-573 result: PACKAGE INTEGRITY PASS; FINAL P0-101 ACCEPTANCE BLOCKED.**

Keep R-108 open. Preserve R-538's exact blocker and owner boundaries. Do not promote the eight valid plates to full visual acceptance, do not treat source IDs as art approval, and do not treat R-559/R-562 completion as resolution of their recorded blocked runtime or visual gates.

No new follow-up task is created: existing owners R-487-R-492, R-532/R-534/R-536/R-537, R-561/R-563/R-564, and the runtime/parser owners already cover every unresolved item.

## Sources and verification commands

- [`lower_town_p0_101_acceptance.md`](lower_town_p0_101_acceptance.md) - R-538 seven-clause closeout and historical decision.
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md) - R-491 capture contract and pending visual rows.
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) - R-486 stable-ID inventory.
- [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md) - 48 blocked silhouette verdict rows and missing human review.
- [`r559_lower_town_dependency_handoff_readiness.md`](r559_lower_town_dependency_handoff_readiness.md) - R-559 dependency reconciliation.
- [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md) - R-490 runtime blockers.
- [`p0_101_clean_checkout_load_gate.md`](p0_101_clean_checkout_load_gate.md) - R-562 clean-checkout gate and parser blocker.
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) - dedicated packet metadata and outputs.
- [`../tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd) - focused packet contract.
- [`../tools/run_godot_checked.sh`](../../tools/run_godot_checked.sh) - checked runner and DEF-002 policy.

Focused command:

```bash
GODOT_BIN=/Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot \
  tools/run_godot_checked.sh --require-test-summary r573-capture-contract -- \
  /Users/artjomkurapov/.local/share/mise/installs/godot/4.7.1-stable/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101
```
