# P0-101 decomposition coverage audit

**Task:** R-649 / P0-101 decomposition coverage and dependency graph
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-21
**Scope:** verification-only; no map, runtime, asset, threshold, capture, or stable-ID changes
**Current RRMap SHA-256:** `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`
**Decision:** **BLOCKED - decomposition coverage is complete, but R-108 acceptance is not ready to close.**

## Decision rule

This audit maps each R-108 acceptance clause to an implementation owner, a verification owner where one exists, and a concrete artifact. Source and contract evidence are kept separate from gameplay-scale visual acceptance, human review, clean-checkout loading, and declared-hardware evidence. A child task being `done` does not promote a blocked acceptance clause to PASS.

## Current source revision

The current `content/maps/lower_town_slice.rrmap` was parsed independently with the following result:

```text
records=99
unique_ids=99
house=61
wall=36
gate_arch=2
tiered_houses=51
merchant_stone=14
merchant_timber=14
craft_boda=23
rear_workshops_present=8/8
```

The eight R-547 rear-workshop IDs are all present in the current map and in `docs/data/lower_town_authoring_contract.json`:

- `saddlers_rear_workshop`
- `coopers_rear_workshop`
- `sauna_rear_boda`
- `rope_makers_rear_store`
- `karja_rear_boda`
- `brewery_rear_store`
- `smithy_rear_shed`
- `carriers_barn`

This agrees with the current inventory report [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), which records 99 records, 51 tiered houses, and the eight-record R-547 delta. The inventory is source evidence only: it explicitly leaves the eight rear workshops visually blocked.

The current capture manifest [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) contains 10 plates, 5 day/night pairs, 5 framing keys, and no stable-ID fields. Its `map_fingerprint` is `13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba`, which does not match the current RRMap SHA-256 above. The manifest therefore remains packet-integrity evidence from an older source revision, not stable-ID visual acceptance for the current 99-record map.

## Upstream dependency graph

The parent prose labels resolve to registered board refs as follows:

| Parent label | Board ref | Current status | Readiness interpretation |
|---|---|---|---|
| `P0-100` | R-109 | `in_progress` | Base layout/terrain/decomposition remains an open upstream prerequisite. |
| `P2-067` | R-213 | `done` | Tier wiring is structurally complete; this is not visual or final parity acceptance. |
| `A-009` | R-6 | `in_review` | Conditional art-direction handoff; final gameplay sign-off remains blocked. |

The decomposition refs named by R-649 are registered and have no self-dependency in the queried board state: R-612/R-613/R-614/R-615/R-618 are the verification owners, paired with R-487/R-488/R-489/R-490/R-493 implementation or prior-gate owners. The parent has no uncovered acceptance clause or unregistered dependency label. R-617 is also registered and covers the historical/art verification surface that is required by the parent acceptance wording.

## Clause-by-clause coverage matrix

| # | R-108 acceptance clause | Implementation owner | Verification owner | Artifact and current board status | Coverage result and blocker |
|---:|---|---|---|---|---|
| 1 | No unexplained repeated ordinary facade/material run; every required visible landmark is classified and present exactly once. | R-487 `in_progress` | R-612 `in_progress` | [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md), [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md) | **STRUCTURAL COVERAGE PASS; ACCEPTANCE BLOCKED.** Current IDs and tier counts are reconciled, but no stable-ID gameplay review proves repetition/material limits or route-scale landmark presentation. Next action: R-487/R-612 provide annotated matched route evidence and preserve the visual blocker if absent. |
| 2 | Gameplay-scale captures distinguish `merchant_stone`, `merchant_timber`, and `craft_boda`, plus log/plank/plaster/limestone, tile/shingle/thatch, and localized wear/repair. | R-487 `in_progress` | R-612 `in_progress` with R-616 `done` as packet verifier | [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md) (R-616 board handoff), and [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) | **PACKET INTEGRITY PASS; VISUAL ACCEPTANCE BLOCKED.** The 10-plate packet has matched framing metadata but no stable-ID, material, roof, or wear observations. The eight rear workshops are current source records without visual coverage. |
| 3 | St. Catherine's, the 1343 Viru Gate state, and every required special building have reviewed exceptional silhouettes and are not scaled-up ordinary houses. | R-488 `in_progress` | R-613 `in_progress` with R-533 `done` as structural boundary verification | [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md), [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md), [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md) | **STRUCTURAL COVERAGE PASS; ACCEPTANCE BLOCKED.** Exceptional/wall/view-only boundaries are represented, but stable-ID gameplay plates and named historical/art approval are missing. Next action: R-488/R-613/R-617 preserve per-ID blockers until both evidence classes exist. |
| 4 | Matched gameplay-scale day/night captures exist for ordinary fabric and each required landmark, with camera and map-revision metadata. | R-489 `in_progress` | R-614 `in_progress`, with R-616 `done` and R-536 `done` for packet audits | [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md), [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md), [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json) | **PACKET CONTRACT PASS; ACCEPTANCE BLOCKED.** Route/camera metadata exists, but the manifest fingerprint predates the current RRMap and contains no stable-ID annotations. Generic route coverage cannot prove every required surface. Next action: R-489/R-614 reconcile the packet to the current source revision and annotate direct stable-ID observations. |
| 5 | Human historical/art review signs every required 1343 silhouette, or records a blocking amendment with an owner. | R-488 `in_progress` and R-492 `in_review` | R-617 `in_progress` | [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md), [`r492_lower_town_1343_landmark_silhouette_review.md`](r492_lower_town_1343_landmark_silhouette_review.md) | **BLOCKED.** The evidence audit records no named human canon reviewer and no named human art reviewer. No silhouette row may be promoted from source/structural evidence. Next action: R-617/R-492 obtain named review or retain owner-specific amendments. |
| 6 | Routes, patrols, transitions, collision, navigation, occlusion/chunk metadata, deterministic parity fixtures, and performance budgets pass with hardware limitations stated. | R-490 `in_review` | R-615 `in_progress` | [`lower_town_p0_101_runtime_qa.md`](lower_town_p0_101_runtime_qa.md), [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md), [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md) | **PARTIAL; FINAL ACCEPTANCE BLOCKED.** Linked reports retain camera failures, resident node/memory overages, clean-load/parser blockers, and missing declared minimum-hardware measurement. Route/chunk contracts are not a substitute for the full clause. Next action: R-615/R-490 consume the named camera, budget, clean-load, and hardware owners without changing caps silently. |
| 7 | All upstream blockers and child handoffs are resolved or explicitly recorded; no incomplete P0-102 handoff is treated as complete. | R-493 `in_review` | R-618 `in_progress` | [`r493_lower_town_architecture_acceptance.md`](r493_lower_town_architecture_acceptance.md), [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md), [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md) | **COVERAGE PASS; ACCEPTANCE BLOCKED.** The dependency and final-acceptance ledgers explicitly preserve the blockers, but R-109 is still open, R-6 is conditional, implementation owners remain open, and R-108 remains `todo`. Next action: R-618/R-493 rerun final acceptance only after the named child gates change status. |

## Stale, contradictory, and missing evidence

All 16 scoped repository paths checked for this audit exist. No linked path is missing, and no queried decomposition ref is unregistered. The following evidence boundaries must remain explicit:

1. **Source revision mismatch:** the current RRMap is 99 records with SHA-256 `6ae0b82a...`, while the capture manifest fingerprint is `13525325b3...`. The packet must not be treated as coverage of the current R-547 rear-workshop revision.
2. **Historical count mismatch:** older reports such as [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md) retain an earlier 91-record / 43-tier snapshot and an older 8-plate packet description. Use them as historical verification records only; the current inventory, capture matrix, R-616, and R-640 evidence supersede those counts for present-state reconciliation.
3. **Composition contract contradiction:** the live [`docs/data/map_composition_thresholds.json`](../data/map_composition_thresholds.json) marks `lower_town_slice` as `enforce=true` and `enforcement_state=enforced`; [`docs/data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json) agrees. The inventory report's older statement that this card has `enforce=false` is stale and must not be used as a PASS or skip. Owner for reconciliation: the P0-100 composition handoff, currently R-550.
4. **Visual evidence gap:** packet metadata has route anchors and matched day/night framing, but no stable-ID fields or reviewer annotations. Source counts, route candidates, non-blank PNGs, headless contracts, and development-host metrics remain structural or supplementary evidence only.
5. **No duplicate ownership gap:** the parent clauses map to ordinary, exceptional, route, runtime, historical/art, and final-acceptance owners. Existing open blockers have owners; no duplicate follow-up task is required from this audit.

## Reproduction record

Run from the project root:

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib, re
p = Path("content/maps/lower_town_slice.rrmap")
text = p.read_text()
records = re.findall(r"^(?:building|landmark)\s+(\S+)\s+(\S+)", text, re.M)
tiers = re.findall(r"^building\s+\S+\s+house\b[^\n]*\bhouse_tier=(\S+)", text, re.M)
rear = {
    "saddlers_rear_workshop", "coopers_rear_workshop", "sauna_rear_boda",
    "rope_makers_rear_store", "karja_rear_boda", "brewery_rear_store",
    "smithy_rear_shed", "carriers_barn",
}
ids = {record_id for record_id, _kind in records}
print(len(records), len(ids), len(tiers), {tier: tiers.count(tier) for tier in sorted(set(tiers))})
print("rear_workshops_present", rear <= ids)
print("map_sha256", hashlib.sha256(p.read_bytes()).hexdigest())
PY
```

Expected source result: `99 99 51 {'craft_boda': 23, 'merchant_stone': 14, 'merchant_timber': 14}`, `rear_workshops_present True`, and the current SHA-256 recorded at the top of this report.

The board refs and artifact paths were checked separately with exact `tasks.get` and filesystem checks. The focused results consumed by this audit are the existing reports' checked summaries; this coordination task does not rerun or alter production tests, captures, parity fixtures, thresholds, or map data.

## Final disposition

**R-649 is complete as a deterministic BLOCKED decomposition audit.** Coverage is present for all seven R-108 clauses, but the parent must remain open. Do not promote the current 99-record source inventory, the 10-plate packet, structural route tests, or conditional art review into final P0-101 acceptance. Existing owners R-487/R-612, R-488/R-613/R-617, R-489/R-614, R-490/R-615, and R-493/R-618 must resolve or explicitly retain their blockers before a future final acceptance rerun.

No new follow-up task is created because every blocker identified here already has a board owner, including the stale composition-contract reconciliation under R-550.

## Sources

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json)
- [`docs/data/map_composition_thresholds.json`](../data/map_composition_thresholds.json)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`r532_lower_town_ordinary_fabric_verification.md`](r532_lower_town_ordinary_fabric_verification.md)
- [`r533_lower_town_landmark_boundary_acceptance.md`](r533_lower_town_landmark_boundary_acceptance.md)
- [`r534_lower_town_route_integration_verification.md`](r534_lower_town_route_integration_verification.md)
- [`r535_lower_town_runtime_performance_verification.md`](r535_lower_town_runtime_performance_verification.md)
- [`r537_lower_town_historical_art_signoff.md`](r537_lower_town_historical_art_signoff.md)
- [`r493_lower_town_architecture_acceptance.md`](r493_lower_town_architecture_acceptance.md)
- [`r640_lower_town_final_acceptance_verification.md`](r640_lower_town_final_acceptance_verification.md)
- [`r611_p0_101_upstream_readiness.md`](r611_p0_101_upstream_readiness.md)
