# R-691 P0-100 post-remediation gate

**Task:** R-691 / P0-100 post-remediation gate
**Parent:** R-109 / P0-100
**Verification date:** 2026-08-24
**Decision:** **BLOCKED - do not close R-691 or promote R-109 to acceptance.**
**Current checkout:** `HEAD=6c456894ce96ff3529f8949635bf7ea6d0bd8224`, branch `main`
**Worktree:** dirty shared worktree with unrelated staged, modified, deleted, and untracked WIP. No production map, runtime, asset, threshold, parity fixture, or capture file was changed by this gate. This report and the QA playbook lesson are the only files changed by this session.

## Scope and decision rule

This is the reproducible eight-clause R-109 gate requested by R-691. Each clause records the exact board owner, command, current result, and blocker boundary. `PASS` is reserved for a complete scoped check. `PACKET VALID`, `SOURCE-ONLY`, and `HEADLESS-ONLY` evidence are not promoted to gameplay or visual acceptance. The parent remains blocked if any required clause, dependency, clean-snapshot condition, or visual review is unresolved.

The current authored Lower Town source is present in the dirty worktree, but it is not the same source as `HEAD`:

```text
worktree content/maps/lower_town_slice.rrmap SHA-256: 6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50
HEAD    content/maps/lower_town_slice.rrmap SHA-256: 67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9e
```

The matched capture manifest records the worktree source SHA `6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`, and a direct hash check matches it. This proves current-source packet identity, not clean-HEAD acceptance.

## Board dependency snapshot

Statuses were queried by exact board ref on 2026-08-24:

| Ref | Status | Gate effect |
|---|---|---|
| R-548 | `in_progress` | Authoring contract owner remains open. |
| R-547 | `in_progress` | Property footprint/layout owner remains open. |
| R-549 | `in_progress` | Surface/elevation implementation owner remains open. |
| R-546 | `in_review` | Yard/fence/drainage handoff is not a completed dependency. |
| R-550 | `in_progress` | Enforced composition owner remains open. |
| R-552 | `in_progress` | Route/navigation/runtime verification owner remains open. |
| R-598 | `in_progress` | Surface/elevation verification remains open despite scoped Lower Town invariants. |
| R-600 | `in_review` | Composition implementation exists, but acceptance inputs remain red. |
| R-601 | `in_progress` | Patrol/runtime gate remains open. |
| R-606 | `done` | Lower Town canonical parity fixture reconciliation is complete; current map parity test is green. |
| R-607 | `in_review` | Surface bands are reconciled, but separate composition metrics remain red. |
| R-608 | `done` | Reviewed object-chunk readiness fixture is reconciled; focused chunk suite is green. |
| R-609 | `done` | Stale R-553 advisory-card regression is fixed; Python closeout suite is green. |
| R-690 | `done` | Current-source capture packet is valid, but its report keeps visual/runtime acceptance blocked. |
| R-553 | `in_progress` | Integration closeout remains blocked and must not promote R-109. |

The dependency state alone prevents a PASS. The command matrix below records the actionable current evidence.

## Eight-clause gate matrix

| Clause | Board owner | Exact command / evidence | Result | Blocker or evidence boundary |
|---|---|---|---|---|
| 1. Authored sectors and intentional empty ownership | R-548, R-547 | `... --filter=test_lower_town_authoring_contract`; inspect `docs/data/lower_town_authoring_contract.json`; `python3 tools/verify_map_composition.py` | **PASS for source/headless contract; BLOCKED for gate** | The authoring contract resolves with `2/2` tests and declares `market_reserve`, `merchant_frontage_strip`, `craft_strip`, `craft_backlots`, `service_yards`, `institutional_landmark_edge`, `transition_edges`, and explicit open-region exclusions. `verify_map_composition.py` exits 1 before metrics because the registry lacks threshold cards for `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle`. R-548/R-547 remain open. |
| 2. 7-11 m frontage rhythm and three house tiers | R-597, R-547 | `... --filter=test_lower_town_authoring_contract`; `... --filter=test_burgher_house_tiers` | **PASS for deterministic source/headless checks; not visual acceptance** | Authoring `2/2` and tier suite `5/5` pass. The deterministic report lists `merchant_stone`, `merchant_timber`, and `craft_boda`; public widths use the `7..11 m` default, with `kaik_house_mid=12 m` and `viru_house_mid=14 m` covered by `merchant_irregular_frontage_m`; rear/service buildings are explicitly excluded. The capture manifest has no reviewed stable-ID observations, so gameplay-scale visual coexistence remains unproven. R-597 is `in_review`, R-547 is `in_progress`. |
| 3. Service yards, drainage, fences, and non-blocking dressing | R-546, R-599 | `... --filter=test_lower_town_service_yards` | **PASS for focused headless contract; BLOCKED for parent** | `3/3` pass: service ownership, rear sheds/workshops, yard gates/fences, fuel/hay/greenery, and wet/mud/grime decals are present and routes remain open. R-546 is `in_review`; this scoped PASS does not clear the parent composition/runtime gates. |
| 4. Surface shares, cobblestone cap, and accessible elevation | R-549, R-598, R-607 | `... --filter=test_lower_town_slice_map`; `... --filter=test_r454_city_elevation_readability,test_r454_elevation_scope,test_r503_elevation_gameplay_invariants`; `python3 tools/verify_map_composition.py` | **PASS for Lower Town surface/map invariants; BLOCKED for full clause** | Current Lower Town measurements from the reconciled source are stone `26.6815536608472%`, earth `45.8722425226688%`, grass `27.446203816484%`, cobblestone `4.52023277845446%`, elevation range `1.48229014535609`; these are within the documented bands. `test_lower_town_slice_map` is `19/19` and the R-503 finite/reciprocal methods pass. The combined elevation filter is `2/3` for R-454 plus `2/3` for R-503 because `monastery_quarter` cannot compile through inactive `kuldjala_interior`, and north/south profiles are outside the R-454 matrix. R-549/R-598 remain open. |
| 5. Enforced composition and failure metrics | R-550, R-600, R-607 | `python3 tools/verify_map_composition.py`; `python3 -m unittest tests.python.test_verify_map_composition -v`; `... --filter=test_map_composition_audit` | **BLOCKED** | Python verifier exits 1 on missing registry threshold cards: `kuldjala_interior`, `nunnatorn_interior`, `toompea_small_castle`. Python contract suite is `4/5` with only registry coverage failing. Godot composition suite is `10 tests, 4 failures, 42 errors`; Lower Town failures are `MAP_COMPOSITION_DENSITY` `21.9622960342187%` vs `45..60%`, `MAP_COMPOSITION_REPEATED_STYLE` `47.5409836065574%` vs max `35%`, and `MAP_COMPOSITION_EMPTY_REGION` `14778` vs max `1200`. Independent failures include `north_quarter` empty region `19079` vs `12000` and `monastery_quarter` compile/threshold coverage errors. R-600/R-607 own the Lower Town composition boundary; unrelated map owners own the other errors. |
| 6. Required landmarks, anchors, routes, and stable IDs | R-548, R-552, R-601 | `... --filter=test_lower_town_authoring_contract`; `... --filter=test_lower_town_slice_map`; `... --filter=test_transition_manifest`; `... --filter=test_r552_lower_town_runtime_acceptance` | **PARTIAL / BLOCKED** | Authoring `2/2`, map `19/19`, and transition manifest `6/6` pass. Required smithy/brewery/cistern/checkpoints, quest anchors, transition IDs, and landmark references resolve in source/runtime contracts. Runtime acceptance is `4 tests, 2 failures`: `iron_convoy` point 1 at cell `(24,28)` and point 2 at `(24,42)` are blocked. This is an actionable patrol blocker owned by R-601/R-552, not a source-only anchor PASS. |
| 7. Routes, patrols, transitions, collision, navigation, chunk, and parity | R-552, R-601, R-606, R-608 | `... --filter=test_lower_town_slice_map`; `... --filter=test_r552_lower_town_runtime_acceptance`; `... --filter=test_map_object_chunk_streaming`; `... --filter=test_transition_manifest`; `python3 tools/verify_map_conversion_parity.py` | **PASS for map/parity/chunk/transition; BLOCKED for runtime patrol gate** | `test_lower_town_slice_map` `19/19`, chunk suite `7/7`, transition suite `6/6`, and conversion parity exit `0` all pass. Conversion output records Lower Town anchor accounting `11/11`, Kalev Smithy `3/3`, and green map filters. Runtime route acceptance still fails the two named `iron_convoy` cells. Broad `verify_map_audit.py` and `verify_map_conversion_plan.py` also report existing repository-wide scene/TODO coverage drift, including missing strict legacy task labels and inactive scene/definition coverage; these are not waived by the scoped Lower Town passes. |
| 8. Matched current-source day/night evidence | R-690, R-601, R-602 and visual/art owners | `... --filter=test_capture_lower_town_p0_101`; direct manifest/hash/PNG audit; documented capture command in `r602_lower_town_matched_capture_evidence.md` | **PACKET VALID; VISUAL ACCEPTANCE BLOCKED** | Capture contract is `6/6`; manifest has five presets, ten matched day/night plates, `1280x720` viewport, current source SHA matching the RRMap, and non-blank PNG evidence. `stable_id_observation_coverage` has five rows, but every day/night row is `not_reviewed` with an empty `stable_ids` list. Player/entrance readability, tier/material/roof/wear/landmark visibility, and human art/canon review therefore remain conditional. R-601 is still `in_progress`; R-690 explicitly does not promote packet integrity to acceptance. |

## Exact command and output summary

All dirty-worktree Godot commands used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot` through `tools/run_godot_checked.sh --require-test-summary <basename> --`. Known shutdown ObjectDB/resource leak lines were retained as non-blocking wrapper-approved teardown diagnostics. Any non-zero test summary remains blocking.

```text
python3 tools/verify_map_composition.py
# exit 1
# registry maps missing threshold cards: kuldjala_interior, nunnatorn_interior, toompea_small_castle

python3 -m unittest tests.python.test_verify_map_composition -v
# exit 1; 5 tests, 1 failure
# test_threshold_cards_cover_registry fails on the same three missing cards

python3 tools/verify_map_conversion_parity.py
# exit 0
# lower_town_slice anchor accounting 11/11
# kalev_smithy anchor accounting 3/3
# Godot filter green: test_kalev_smithy_map
# map conversion parity verification passed

python3 tools/verify_r553_lower_town_closeout.py
# exit 0; R-553 Lower Town closeout verification passed

python3 -m unittest tests.python.test_verify_r553_lower_town_closeout -v
# exit 0; 6 tests, 0 failures

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
# Lower Town density/style/empty-region failures plus north_quarter and monastery baseline errors

... --filter=test_r454_city_elevation_readability,test_r454_elevation_scope,test_r503_elevation_gameplay_invariants
# exit 1; 2 files, 6 tests, 4 failures, 0 errors
# monastery inactive destination compile failure and two R-454 matrix outliers; finite and reciprocal Lower Town invariants pass

python3 tools/verify_map_activation.py
# exit 0; Map activation guard passed

python3 tools/verify_map_audit.py
# exit 1; existing scene inventory/plan/TODO coverage drift and missing definition audit entries

python3 tools/verify_map_conversion_plan.py
# exit 1; same existing scene inventory/plan/TODO coverage drift

git diff --check
# exit 2; unrelated dirty WIP: tools/benchmarks/lower_town_scene_benchmark.tscn:12 new blank line at EOF
```

The scoped candidate paths used by this report have no whitespace diagnostics:

```text
git diff --check -- agents/rebel-qa/playbook.md
# exit 0 for the appended lesson
```

## Clean-snapshot reproducibility

The clean check was constructed without changing the shared worktree:

```bash
rm -rf /tmp/r691-clean && mkdir -p /tmp/r691-clean
git archive HEAD | tar -x -C /tmp/r691-clean
git diff --binary -- \
  content/maps/lower_town_slice.rrmap \
  content/map_audit_manifest.json \
  docs/data/map_composition_thresholds.json > /tmp/r691-scoped.patch
git -C /tmp/r691-clean apply /tmp/r691-scoped.patch
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp/r691-clean --import --quit-after 3
```

Import exits `0`. The clean snapshot is not acceptance-ready, however:

- `python3 tools/verify_map_composition.py` exits `1` on missing `nunnatorn_interior` threshold coverage.
- `python3 tools/verify_map_conversion_parity.py` exits `1` because `test_lower_town_slice_map` cannot load cleanly.
- Focused clean Godot runs expose the first baseline parse cascade at `state_rule_evaluator.gd`: missing `GameState.LIVING_CITY_MIN`, `LIVING_CITY_MAX`, `LIVING_CITY_DELTA_MIN`, and `LIVING_CITY_DELTA_MAX`. Lower Town source parsing then reports unsupported `elevation_area` / `elevation_ramp` commands and missing current runtime/registry dependencies.
- The clean authoring/map/runtime results therefore cannot be promoted: they are clean-snapshot baseline/cascade evidence, not valid acceptance failures attributable to the three scoped map files.

The clean snapshot does confirm the required distinction: the current packet is bound to the dirty authored source, while `HEAD` does not contain all dependencies needed to reproduce that source as a clean checkout. R-693 owns the living-city baseline; R-623/R-251 own Nunnatorn; R-297 owns Toompea Small Castle; existing R-453/R-455 work owns the elevation matrix/command boundary.

## Current blockers and ownership

1. **R-600 / R-607:** Lower Town enforced composition still fails built density `21.9623%`, repeated style `47.541%`, and largest empty region `14778`.
2. **R-601 / R-552:** `iron_convoy` patrol cells `(24,28)` and `(24,42)` remain blocked.
3. **R-550 / registry owners:** global composition verification cannot reach a clean acceptance result while `kuldjala_interior`, `nunnatorn_interior`, and `toompea_small_castle` threshold cards are missing.
4. **R-623/R-251 and R-297:** inactive map/threshold/registry dependencies remain outside this Lower Town gate but fail the global composition and elevation harnesses.
5. **R-693:** clean `HEAD` startup has the missing Living City constants parse cascade.
6. **R-548/R-547/R-549/R-546/R-598/R-553:** board dependencies are not all `done`, so a green scoped sub-suite cannot close the parent.
7. **R-690/R-602 and visual owners:** ten PNGs and the manifest are valid current-source packet evidence, but all stable-ID visual observation rows are `not_reviewed`; no gameplay-scale visual or human art/canon acceptance is claimed.
8. **Shared worktree:** repository-wide `git diff --check`, map audit, and conversion-plan checks include unrelated WIP drift. The exact unrelated whitespace blocker is `tools/benchmarks/lower_town_scene_benchmark.tscn:12`.

No follow-up task was created: all actionable blockers above already have registered board owners. Do not weaken thresholds, regenerate fixtures, repair unrelated runtime/registry files, or change task statuses implicitly from this gate.

## Final decision

**BLOCKED.** The current-source Lower Town map, authoring contract, tiers, service yards, map parity, chunk streaming, transitions, and capture packet have strong scoped evidence. The enforced composition metrics, patrol accessibility, unresolved dependency statuses, clean-snapshot reproducibility, and unreviewed visual observations prevent the eight-clause R-109 gate from passing. Keep R-691, R-553, and R-109 open; do not treat packet integrity or source/headless-only checks as final gameplay or visual acceptance.

## Sources

- [`R-109 parent task`](../../TODO.md)
- [`R-691 task contract`](../../TODO.md)
- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`Map audit manifest`](../../content/map_audit_manifest.json)
- [`Current-source capture manifest`](images/lower_town_p0_101/capture_manifest.json)
- [`R-602 matched capture evidence`](r602_lower_town_matched_capture_evidence.md)
- [`R-607 surface reconciliation`](r607_lower_town_surface_reconciliation.md)
- [`R-598 surface/elevation verification`](r598_lower_town_surface_elevation_verification.md)
- [`R-553 integration verification`](r553_lower_town_integration_verification.md)
- [`R-596/R-597/R-599/R-600/R-601/R-608/R-609/R-690 board evidence`](../../TODO.md)
- [`Map composition verifier`](../../tools/verify_map_composition.py)
- [`Map conversion parity verifier`](../../tools/verify_map_conversion_parity.py)
- [`Map audit verifier`](../../tools/verify_map_audit.py)
- [`Map activation verifier`](../../tools/verify_map_activation.py)
- [`Map conversion-plan verifier`](../../tools/verify_map_conversion_plan.py)
- [`Godot checked runner`](../../tools/run_godot_checked.sh)
- [`Godot test harness`](../../tools/run_godot_tests.gd)
