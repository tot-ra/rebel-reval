# R-692 P0-100 final independent verification

**Task:** R-692 / P0-100 decomposition closeout
**Parent:** R-109 / P0-100
**Verification date:** 2026-08-24
**Current branch:** `main`
**Current HEAD:** `58568dde30d29736d6876c4ffd32d262c3a77aa7`
**Worktree:** shared dirty worktree with unrelated staged, modified, deleted, and untracked WIP. This report is the only R-692 acceptance artifact; no map, runtime, asset, threshold, parity fixture, or capture file was changed.
**Decision:** **BLOCKED**

## Decision rule

This is the final independent reconciliation requested by R-692. `READY FOR REVIEW` is reserved for a complete, reproducible proof of all eight R-109 acceptance clauses, resolved board dependencies, current-source identity, route/runtime parity, composition metrics, and human-readable day/night evidence. Packet integrity, source-only checks, headless-only checks, conditional rows, and development-host captures are not promoted to acceptance.

R-109 remains open. This report does not change any task status implicitly and does not rely on the earlier R-603 report.

## Board snapshot

The following refs were queried directly on 2026-08-24:

| Ref | Status | Effect on R-109 |
|---|---|---|
| R-109 | `in_progress` | Parent is open. |
| R-553 | `in_progress` | Final integration closeout remains blocked. |
| R-690 | `done` | Current-source capture packet is valid, but its own report keeps visual/runtime acceptance blocked. |
| R-691 | `in_review` | Latest post-remediation gate decision is BLOCKED. |
| R-546 | `in_review` | Yard/fence/drainage handoff is not a completed dependency. |
| R-547 | `in_progress` | Property footprint/layout owner remains open. |
| R-548 | `in_progress` | Authoring contract owner remains open. |
| R-549 | `in_progress` | Surface/elevation implementation owner remains open. |
| R-552 | `in_progress` | Route/navigation/runtime handoff remains open. |
| R-598 | `in_progress` | Surface/elevation verification remains open. |
| R-600 | `in_review` | Enforced composition implementation exists, but Lower Town metrics remain outside the acceptance bands. |
| R-601 | `in_progress` | Patrol/runtime acceptance remains open. |
| R-607 | `in_review` | Surface bands pass, but separate composition metrics remain red. |
| R-608 | `done` | Chunk-readiness fixture reconciliation is complete; focused chunk suite is green. |
| R-609 | `done` | R-553 closeout guard regression is repaired; Python closeout suite is green. |
| R-693 | `todo` | Clean-HEAD Living City constants parse cascade remains an external baseline blocker. |

The required R-692 dependencies are therefore not all complete: R-553 is open and R-691 is only in review. R-690 being done proves packet delivery, not parent acceptance.

## Source identity and scope isolation

The current authored source and capture packet are internally consistent, but they are not the same source as clean `HEAD`:

```text
current content/maps/lower_town_slice.rrmap SHA-256:
6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50

HEAD content/maps/lower_town_slice.rrmap SHA-256:
67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e

capture manifest map_source_sha256:
6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50

capture manifest map_fingerprint:
13525325b3d8be840c79d8c709c8aab12632bc6092a7123bc6d9275ba51d17ba
```

The current-source hash matches the manifest. That proves packet identity only. The shared worktree contains unrelated WIP, so no repository-wide result is treated as scoped R-692 evidence unless its path and ownership are explicit. The scoped `git diff --check` for this report and the linked Lower Town acceptance paths is clean; the full dirty-worktree check remains affected by unrelated changes recorded below.

## Eight-clause reconciliation

| Clause | Result | Evidence and remaining boundary |
|---|---|---|
| 1. Historically grounded layout, authored sectors, and intentional empty ownership | **PASS for deterministic source contract; BLOCKED for R-109** | `test_lower_town_authoring_contract`: `2/2`. The contract names `market_reserve`, `merchant_frontage_strip`, `craft_strip`, `craft_backlots`, `service_yards`, `institutional_landmark_edge`, `transition_edges`, and explicit open-region exclusions. The parent cannot accept this clause while R-548/R-547 remain open and the enforced composition gate reports an unowned empty-region violation of `14778` cells (limit `1200`). |
| 2. Dense property footprints, 7-11 m frontage rhythm, and all three ordinary tiers | **PASS for deterministic source/headless checks; BLOCKED for visual acceptance** | `test_burgher_house_tiers`: `5/5`; authoring contract: `2/2`. The deterministic frontage report includes `merchant_stone`, `merchant_timber`, and `craft_boda`; public rows use the `7..11 m` default with documented wider and rear/service exceptions. No gameplay-scale visual observation proves the three tiers together: all five manifest observation rows are `not_reviewed` with empty stable-ID lists. R-547 remains open. |
| 3. Service yards, drainage, fences, and non-blocking dressing | **PASS for focused contract; BLOCKED for parent** | `test_lower_town_service_yards`: `3/3`. Service ownership, rear sheds/workshops, gates/fences, fuel/hay/greenery, and wet/mud/grime dressing are covered. R-546 is only `in_review`, and this source/headless result cannot clear the parent composition/runtime or visual gates. |
| 4. Surface shares, cobblestone cap, and accessible elevation | **PASS for Lower Town surface/map invariants; BLOCKED for full clause** | Current measured values are stone `26.6815536608472%`, earth `45.8722425226688%`, grass `27.446203816484%`, cobblestone `4.52023277845446%`, elevation range `1.48229014535609`; the Lower Town bands pass. `test_lower_town_slice_map`: `19/19`; R-503 finite/reciprocal checks pass. The combined elevation matrix has `4` failures in `6` tests: inactive `kuldjala_interior` compile dependency plus `north_quarter` profile `r454.north.east_harbour_fall` and `south_quarter` profile `r454.south.karja_causeway` outside the matrix. R-549/R-598 remain open. |
| 5. Enforced composition metrics and required landmark ownership | **BLOCKED** | `python3 tools/verify_map_composition.py` exits `1` because registry threshold cards are missing for `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`. The Python contract suite is `4/5` with only threshold-card coverage failing. The Godot composition suite is `10 tests, 4 failures, 42 errors`; Lower Town violations are `MAP_COMPOSITION_DENSITY` built density `21.9622960342187%` vs `45..60%`, `MAP_COMPOSITION_REPEATED_STYLE` `47.5409836065574%` vs max `35%`, and `MAP_COMPOSITION_EMPTY_REGION` `14778` vs max `1200`. R-600/R-607 own the Lower Town composition boundary; registry/other-map errors remain separate blockers. |
| 6. Required smithy, brewery, cistern/checkpoints, quest anchors, transitions, and stable IDs | **PARTIAL / BLOCKED** | `test_lower_town_authoring_contract`: `2/2`, `test_lower_town_slice_map`: `19/19`, and `test_transition_manifest`: `6/6` pass. Required authored IDs and manifest transitions resolve in the current source. The runtime acceptance still fails two named patrol cells, so source anchors are not promoted to gameplay acceptance. R-552/R-601 remain open. |
| 7. Routes, patrols, transitions, collision, navigation, chunk streaming, and conversion parity | **PARTIAL / BLOCKED** | Map `19/19`, chunk suite `7/7`, transitions `6/6`, and `python3 tools/verify_map_conversion_parity.py` exit `0` (Lower Town anchor accounting `11/11`, Kalev Smithy `3/3`) pass their scoped structural boundaries. `test_r552_lower_town_runtime_acceptance` is `4 tests, 2 failures`: `iron_convoy` point 1 at `(24,28)` and point 2 at `(24,42)` are blocked. The full R-109 route/patrol gate therefore remains red despite map/chunk/parity subpasses. R-601/R-552 own this blocker. |
| 8. Matched current-source day/night gameplay-scale evidence | **PACKET VALID; VISUAL ACCEPTANCE BLOCKED** | `test_capture_lower_town_p0_101`: `6/6`. The manifest contains five presets, ten matched plates, `1280x720` viewport, current-source SHA, and all ten PNGs decode as RGBA `1280x720` non-blank files. Every one of the five day/night stable-ID rows is `not_reviewed` with `stable_ids: []`; player/entrance readability, tier/material/roof/wear/landmark visibility, and human art/canon review remain unproven. R-690/R-602 explicitly preserve this boundary; R-601 and visual owners remain open. |

## Exact verification command/output summary

All current-worktree Godot checks used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh`. Known ObjectDB/resource-leak messages appeared during teardown after successful green suites and were not used to waive any test failure.

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
# Godot filter green: test_kalev_smithy_map and test_lower_town_slice_map

python3 tools/verify_r553_lower_town_closeout.py
# exit 0; R-553 Lower Town closeout verification passed

python3 -m unittest tests.python.test_verify_r553_lower_town_closeout -v
# exit 0; 6 tests, 0 failures

python3 tools/verify_map_activation.py
# exit 0; Map activation guard passed

python3 tools/verify_map_audit.py
# exit 1; existing scene inventory/plan/TODO coverage drift,
# missing definition audit entries, and world_padise target mismatch

python3 tools/verify_map_conversion_plan.py
# exit 1; same existing scene inventory/plan/TODO coverage drift

GODOT_LOG_DIR=/tmp/r692-godot tools/run_godot_checked.sh --require-test-summary r692-authoring -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_authoring_contract
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
# Lower Town density/style/empty-region violations plus independent map/registry errors

... --filter=test_r454_city_elevation_readability,test_r454_elevation_scope,test_r503_elevation_gameplay_invariants
# exit 1; 2 files, 6 tests, 4 failures, 0 errors
# inactive monastery destination and two out-of-matrix urban profiles

git diff --check -- content/maps/lower_town_slice.rrmap content/map_audit_manifest.json \
  docs/data/map_composition_thresholds.json \
  docs/reports/images/lower_town_p0_101/capture_manifest.json \
  docs/reports/r602_lower_town_matched_capture_evidence.md \
  docs/reports/r691_p0_100_post_remediation_gate.md \
  docs/reports/p0_100_decomposition_verification.md
# exit 0; tracked linked acceptance paths are clean

git diff --no-index --check /dev/null docs/reports/r692_p0_100_final_independent_verification.md
# exit 1; expected valid new-file diff status, with no whitespace diagnostics


## Clean-snapshot reproducibility

A clean snapshot was built without changing the shared worktree:

```bash
rm -rf /tmp/r692-clean && mkdir -p /tmp/r692-clean
git archive HEAD | tar -x -C /tmp/r692-clean
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp/r692-clean --import --quit-after 3
```

Import exits `0`. The clean snapshot has source SHA `67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e`, not the packet SHA. Its focused checks are not acceptance evidence for the current source:

```text
cd /tmp/r692-clean && python3 tools/verify_map_composition.py
# exit 1; missing nunnatorn_interior threshold card

cd /tmp/r692-clean && python3 tools/verify_map_conversion_parity.py
# exit 1; Godot filter test_lower_town_slice_map failed

cd /tmp/r692-clean && GODOT_LOG_DIR=/tmp/r692-clean-godot \
  ./tools/run_godot_checked.sh --require-test-summary r692-clean-authoring -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_authoring_contract
# exit 1; clean-HEAD parse cascade for missing GameState living-city constants,
# then unknown authored elevation_area/elevation_ramp commands and unresolved IDs
```

This establishes the required distinction: the current packet is bound to dirty authored source, while clean `HEAD` does not contain all runtime/parser dependencies needed to reproduce that source. R-693 owns the Living City constants baseline; the elevation command/registry and cross-map threshold inputs have separate existing owners. These clean-snapshot failures are not reclassified as Lower Town implementation failures, but they prevent clean reproducibility from being promoted to acceptance.

## Remaining owners and disposition

1. **R-600 / R-607:** Lower Town enforced composition remains outside density, repeated-style, and largest-empty-region limits.
2. **R-601 / R-552:** `iron_convoy` patrol cells `(24,28)` and `(24,42)` remain blocked.
3. **R-550 and registry owners:** global composition verification lacks threshold cards for `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`.
4. **R-549 / R-598 and existing elevation owners:** cross-map elevation matrix and inactive monastery destination remain unresolved.
5. **R-693:** clean `HEAD` startup has the missing Living City constants parse cascade.
6. **R-548 / R-547 / R-549 / R-546 / R-598 / R-553 / R-691:** required board dependencies are not all in `done`.
7. **R-690 / R-602 and visual/art/canon owners:** packet is valid, but all stable-ID observation rows are `not_reviewed` and no gameplay-scale visual sign-off is present.
8. **Shared worktree:** repository-wide map audit, conversion-plan, and whitespace checks include unrelated baseline drift; no such result is waived as R-692 acceptance.

No follow-up task is created: each actionable blocker already has a registered owner. Do not weaken thresholds, regenerate parity fixtures, repair unrelated runtime/registry files, or change parent/dependency statuses from this evidence-only review.

## Final decision

**BLOCKED.** The current source has strong deterministic evidence for authoring, tiers, service yards, Lower Town map invariants, chunks, transitions, conversion accounting, and packet integrity. The enforced composition violations, blocked patrol cells, unresolved dependency statuses, clean-snapshot mismatch/parse boundary, incomplete elevation matrix, and unreviewed visual observations prevent all eight R-109 clauses from being independently proven.

Keep R-692, R-691, R-553, and R-109 open for their existing review/implementation owners. Do not state `READY FOR REVIEW`; that exact status is not earned by the current evidence.

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
