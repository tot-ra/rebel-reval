# R-692 P0-100 final independent verification

**Task:** R-692 / P0-100 decomposition closeout
**Parent:** R-109 / P0-100
**Verification date:** 2026-08-24
**Current branch:** `main`
**Current HEAD:** `bf523b378b56c13c42ad81991ddf4af6b92b22b8`
**Worktree:** shared dirty worktree with unrelated staged, modified, deleted, and untracked WIP. This report is the only R-692 acceptance artifact changed by this verification. No map, runtime, asset, threshold, parity fixture, or capture file was changed.
**Decision:** **BLOCKED**

## Decision rule

`READY FOR REVIEW` is reserved for a complete, reproducible proof of all eight R-109 acceptance clauses, resolved board dependencies, current-source identity, route/runtime parity, composition metrics, and human-readable day/night evidence. Packet integrity, source-only checks, headless-only checks, conditional rows, development-host captures, and green sub-suites do not substitute for missing gameplay or review evidence.

R-109 remains open. This report does not change any task status implicitly and does not rely on the earlier R-603 report. No follow-up task is created because every actionable blocker has an existing registered owner.

## Board snapshot

The required refs and current blockers were queried directly on 2026-08-24:

| Ref | Status | Effect on R-109 |
|---|---|---|
| R-109 | `in_progress` | Parent remains open. |
| R-553 | `in_progress` | Final Lower Town integration closeout remains open. |
| R-690 | `done` | Current-source capture packet is delivered, but its report keeps visual/runtime acceptance blocked. |
| R-691 | `in_review` | Latest post-remediation gate is blocked and does not promote R-109. |
| R-546 | `in_review` | Yard/fence/drainage handoff is not complete. |
| R-547 | `in_progress` | Property footprint/layout owner remains open. |
| R-548 | `in_progress` | Authoring contract owner remains open. |
| R-549 | `in_progress` | Surface/elevation implementation owner remains open. |
| R-552 | `in_progress` | Route/navigation/runtime handoff remains open. |
| R-598 | `in_progress` | Surface/elevation verification remains open. |
| R-600 | `in_review` | Composition enforcement exists, but acceptance metrics remain red. |
| R-601 | `in_progress` | Patrol/runtime acceptance remains open. |
| R-607 | `in_review` | Surface bands are reconciled, but density/style/empty-region metrics remain red. |

The required R-692 dependencies are therefore not all complete: R-553 is open and R-691 is only in review. R-690 being done proves packet delivery, not parent acceptance.

## Source identity and scope isolation

The current authored source matches the capture packet, but the shared worktree is not a clean snapshot:

```text
current content/maps/lower_town_slice.rrmap SHA-256:
6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50

capture manifest map_source_sha256:
6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50

capture manifest map_fingerprint:
13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba
```

The source hash matches the manifest. This proves packet identity only. No unrelated worktree result is promoted to R-692 evidence unless its path and ownership are explicit.

## Eight-clause reconciliation

| Clause | Result | Evidence and remaining boundary |
|---|---|---|
| 1. Historically grounded layout, authored sectors, and intentional empty ownership | **PASS for deterministic source contract; BLOCKED for R-109** | Current `test_lower_town_authoring_contract` passes `2/2`. The contract names `market_reserve`, `merchant_frontage_strip`, `craft_strip`, `craft_backlots`, `service_yards`, `institutional_landmark_edge`, `transition_edges`, and explicit open-region exclusions. R-547/R-548 remain open, and the enforced composition gate still reports the largest empty-region violation (`14778` cells vs `1200` limit). |
| 2. Dense property footprints, 7-11 m frontage rhythm, and all three ordinary tiers | **PASS for deterministic source/headless checks; BLOCKED for visual acceptance** | Current authoring contract output lists `merchant_stone`, `merchant_timber`, and `craft_boda`; public outliers `kaik_house_mid=12m` and `viru_house_mid=14m` are covered by `merchant_irregular_frontage_m`, while rear/service rows are explicitly excluded. `test_lower_town_authoring_contract` is `2/2`; `test_burgher_house_tiers` is `5/5`. No gameplay-scale human observation proves the three tiers together: all five day/night observation rows remain `not_reviewed` with empty stable-ID lists. R-547 remains open. |
| 3. Service yards, drainage, fences, and non-blocking dressing | **PASS for focused contract; BLOCKED for parent** | `test_lower_town_service_yards` passes `3/3` and covers service ownership, rear sheds/workshops, yard gates/fences, fuel/hay/greenery, and wet/mud/grime dressing. R-546 is only in review, and this source/headless result cannot clear composition, runtime, or visual gates. |
| 4. Surface shares, cobblestone cap, and accessible elevation | **PASS for Lower Town surface/map invariants; BLOCKED for full clause** | Current measured values remain stone `26.6815536608472%`, earth `45.8722425226688%`, grass `27.446203816484%`, cobblestone `4.52023277845446%`, elevation range `1.48229014535609`; the Lower Town surface bands pass. `test_lower_town_slice_map` passes `19/19`; the scoped R-503 gameplay invariants pass. The combined elevation matrix is blocked by an inactive `kuldjala_interior` destination and out-of-scope `north_quarter`/`south_quarter` profiles. R-549/R-598 remain open. |
| 5. Enforced composition metrics and required landmark ownership | **BLOCKED** | `python3 tools/verify_map_composition.py` exits `1` because registry threshold cards are missing for `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`. The Python contract suite is `4/5`, with only threshold-card coverage failing. Current Godot composition suite is `10 tests, 4 failures, 42 errors`; Lower Town violations are `MAP_COMPOSITION_DENSITY` built density `21.9622960342187%` vs `45..60%`, `MAP_COMPOSITION_REPEATED_STYLE` `47.5409836065574%` vs max `35%`, and `MAP_COMPOSITION_EMPTY_REGION` `14778` vs max `1200`. R-600/R-607 own the Lower Town metrics; other-map registry/compile errors remain separate blockers. |
| 6. Required smithy, brewery, cistern/checkpoints, quest anchors, transitions, and stable IDs | **PARTIAL / BLOCKED** | Current authoring contract `2/2`, map suite `19/19`, and transition manifest `6/6` pass. Required source IDs and manifest transitions resolve. Runtime acceptance still fails two patrol cells, so source anchors are not promoted to gameplay acceptance. R-552/R-601 remain open. |
| 7. Routes, patrols, transitions, collision, navigation, chunk streaming, and conversion parity | **PARTIAL / BLOCKED** | Map `19/19`, chunk suite `7/7`, transitions `6/6`, and `python3 tools/verify_map_conversion_parity.py` exit `0` with Lower Town anchor accounting `11/11` and Kalev Smithy `3/3`. However, `test_r552_lower_town_runtime_acceptance` is `4 tests, 2 failures`: `iron_convoy` point 1 at `(24,28)` and point 2 at `(24,42)` are blocked. The full R-109 route/patrol gate remains red. R-552/R-601 own this blocker. |
| 8. Matched current-source day/night gameplay-scale evidence | **PACKET VALID; VISUAL ACCEPTANCE BLOCKED** | `test_capture_lower_town_p0_101` passes `6/6`. The manifest has ten plates across five matched day/night presets, viewport `1280x720`, current-source SHA, and all ten PNGs decode as `1280x720` non-blank files. Each of the five observation rows remains `not_reviewed` with `stable_ids: []`; player/entrance readability, tier/material/roof/wear/landmark visibility, and human art/canon review are unproven. R-690/R-602 explicitly preserve this boundary. |

## Exact verification command/output summary

All current-worktree Godot checks used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh --require-test-summary <log-name> --`. Shutdown ObjectDB/resource-leak messages were retained as teardown diagnostics and not used to waive test failures.

```text
python3 tools/verify_map_composition.py
# exit 1
# registry maps missing threshold cards: kuldjala_interior, nunnatorn_interior, toompea_small_castle

python3 -m unittest tests.python.test_verify_map_composition -v
# exit 1; 5 tests, 1 failure
# test_threshold_cards_cover_registry fails on the same missing cards

python3 tools/verify_map_conversion_parity.py
# exit 0
# lower_town_slice anchor accounting 11/11
# kalev_smithy anchor accounting 3/3
# Godot filters green: test_kalev_smithy_map and test_lower_town_slice_map

python3 tools/verify_r553_lower_town_closeout.py
# exit 0; R-553 Lower Town closeout verification passed

python3 -m unittest tests.python.test_verify_r553_lower_town_closeout -v
# exit 0; 6 tests, 0 failures

python3 tools/verify_map_activation.py
# exit 0; Map activation guard passed

python3 tools/verify_map_audit.py
# exit 1; existing scene inventory/plan/TODO coverage drift, missing definition audit entries,
# and world_padise target mismatch

python3 tools/verify_map_conversion_plan.py
# exit 1; same existing scene inventory/plan/TODO coverage drift

... --filter=test_lower_town_authoring_contract
# exit 0; 1 file, 2 tests, 0 failures, 0 errors

... --filter=test_lower_town_slice_map
# exit 0; 1 file, 19 tests, 0 failures, 0 errors

... --filter=test_lower_town_service_yards
# exit 0; 1 file, 3 tests, 0 failures, 0 errors

... --filter=test_burgher_house_tiers
# exit 0; 1 file, 5 tests, 0 failures, 0 errors

... --filter=test_map_object_chunk_streaming
# exit 0; 1 file, 7 tests, 0 failures, 0 errors

... --filter=test_transition_manifest
# exit 0; 1 file, 6 tests, 0 failures, 0 errors

... --filter=test_capture_lower_town_p0_101
# exit 0; 1 file, 6 tests, 0 failures, 0 errors

... --filter=test_r552_lower_town_runtime_acceptance
# exit 1; 1 file, 4 tests, 2 failures, 0 errors
# iron_convoy point 1 (24,28) and point 2 (24,42) blocked

... --filter=test_map_composition_audit
# exit 1; 1 file, 10 tests, 4 failures, 42 errors
# Lower Town density/style/empty-region violations plus north_quarter and monastery registry/compile errors

... --filter=test_r454_city_elevation_readability,test_r454_elevation_scope,test_r503_elevation_gameplay_invariants
# exit 1; 2 files, 6 tests, 4 failures, 0 errors
# inactive monastery destination and two urban profiles outside the R-454 matrix

git diff --check -- docs/reports/r692_p0_100_final_independent_verification.md
# exit 0
```

## Clean-snapshot reproducibility

A clean snapshot was built without changing the shared worktree:

```bash
rm -rf /tmp/r692-clean && mkdir -p /tmp/r692-clean
git archive HEAD | tar -x -C /tmp/r692-clean
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp/r692-clean --import --quit-after 3
```

Import completed successfully. The clean snapshot's map hash is the committed `HEAD` source, not the current packet source. Clean checks are not acceptance evidence for the dirty current-source packet:

```text
cd /tmp/r692-clean && python3 tools/verify_map_composition.py
# exit 1; registry threshold coverage is missing for nunnatorn_interior

cd /tmp/r692-clean && python3 tools/verify_map_conversion_parity.py
# exit 1; test_lower_town_slice_map fails in the clean committed source

cd /tmp/r692-clean && ... --filter=test_lower_town_authoring_contract
# exit 1; clean-HEAD source lacks the current elevation_area/elevation_ramp commands
# and current authored anchor/landmark dependencies, producing a parser/contract cascade
```

This establishes the required boundary: the current packet is bound to dirty authored source, while clean `HEAD` does not contain all dependencies needed to reproduce that packet as a clean checkout. Clean-snapshot results are therefore not promoted to acceptance and are assigned to the existing map/elevation/runtime owners.

## Remaining owners and disposition

1. **R-600 / R-607:** Lower Town enforced composition remains outside density, repeated-style, and largest-empty-region limits.
2. **R-601 / R-552:** `iron_convoy` patrol cells `(24,28)` and `(24,42)` remain blocked.
3. **R-550 and registry owners:** global composition verification lacks threshold cards for `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`.
4. **R-549 / R-598 and existing elevation owners:** inactive monastery destination and out-of-matrix urban elevation profiles remain unresolved.
5. **R-548 / R-547 / R-549 / R-546 / R-598 / R-553 / R-691:** required board dependencies are not all `done`.
6. **R-690 / R-602 and visual/art/canon owners:** packet integrity passes, but all stable-ID observation rows are `not_reviewed` and no gameplay-scale visual sign-off is present.
7. **Shared worktree:** repository-wide map-audit and conversion-plan failures include unrelated inventory/TODO drift; those results are not waived as R-692 acceptance.

No follow-up task is created: all actionable blockers already have registered board owners. Do not weaken thresholds, regenerate parity fixtures, repair unrelated runtime/registry files, or change parent/dependency statuses from this evidence-only review.

## Final decision

**BLOCKED.** The current source has strong deterministic evidence for authoring, tiers, service yards, Lower Town map invariants, chunks, transitions, conversion accounting, and packet integrity. The enforced composition violations, blocked patrol cells, unresolved dependency statuses, clean-snapshot mismatch, incomplete elevation matrix, and unreviewed visual observations prevent all eight R-109 clauses from being independently proven.

Keep R-692, R-691, R-553, and R-109 open for their existing owners. Do not state `READY FOR REVIEW`; that exact status is not earned by the current evidence.

## Sources

- [`R-109 parent task`](../../TODO.md)
- [`R-692 task contract`](../../TODO.md)
- [`R-691 post-remediation gate`](r691_p0_100_post_remediation_gate.md)
- [`R-690 current-source capture reconciliation`](r602_lower_town_matched_capture_evidence.md)
- [`R-553 integration verification`](r553_lower_town_integration_verification.md)
- [`R-598 surface/elevation verification`](r598_lower_town_surface_elevation_verification.md)
- [`R-607 surface reconciliation`](r607_lower_town_surface_reconciliation.md)
- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`Map audit manifest`](../../content/map_audit_manifest.json)
- [`Current-source capture manifest`](images/lower_town_p0_101/capture_manifest.json)
- [`Map composition verifier`](../../tools/verify_map_composition.py)
- [`Map conversion parity verifier`](../../tools/verify_map_conversion_parity.py)
- [`Map audit verifier`](../../tools/verify_map_audit.py)
- [`Map conversion-plan verifier`](../../tools/verify_map_conversion_plan.py)
- [`Map activation verifier`](../../tools/verify_map_activation.py)
- [`Godot checked runner`](../../tools/run_godot_checked.sh)
- [`Godot test harness`](../../tools/run_godot_tests.gd)
