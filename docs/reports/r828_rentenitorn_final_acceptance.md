# R-828 Rentenitorn final acceptance verification

**Task:** R-828 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Verification date:** 2026-08-31
**Decision:** **BLOCKED for R-246 closeout; R-828 verification complete**

## Scope and decision rule

This is the independent closeout verification requested after the named art/gameplay and historical review tasks. It reconciles R-246 against R-826, R-827, R-788, R-789, R-790, R-791, and R-804, and checks the current Rentenitorn sources, evidence packet, encounter/persistence package, and repaired P4-027f verifier. No map, runtime, content, catalog, transition, portfolio, or activation implementation was changed by this verification.

Objective checks are not human approval. R-246 remains blocked because the current review report records both required reviewer rows as **BLOCKED** under AI reviewers, not named human approvals. This report preserves the fail-closed boundary and does not reinterpret either row as PASS.

## Dependency and evidence matrix

| Dependency / acceptance clause | Board state | Current evidence | Result | Owner / disposition |
|---|---|---|---|---|
| R-826 art/gameplay review | `done` | `docs/reports/rentenitorn_interior_review.md:132-145`; six files in `docs/reports/images/rentenitorn/`; `test_rentenitorn_presentation` | **BLOCKED for human sign-off**. The AI art review records no visual amendment, but cannot substitute for the required named human art approval. | R-785 must obtain and record the named human art verdict. |
| R-827 historical/source review | `done` | `docs/reports/rentenitorn_interior_review.md:132-145`; minimum-claim sources and RRMap | **BLOCKED for human sign-off**. The AI/source review confirms the bounded reversible reconstruction, but cannot substitute for the required named human historical approval. | R-785 must obtain and record the named human historical verdict. |
| R-788 map structure and reciprocal transitions | `in_review` | `docs/reports/r788_rentenitorn_map_transition_verification.md` | **PASS for scoped technical verification**. Closed shell, three traversal bands, wall-walk, reciprocal IDs, and developer-only wiring are covered. | No implementation change or activation authorized here. |
| R-789 minimum-claim reversibility | `done` | `docs/reports/r789_rentenitorn_reversibility_audit.md` | **PASS for structural/content boundary; BLOCKED for final acceptance**. Unsupported fabric remains labelled plausible/invented and reversible. | Human historical/art verdicts remain owned by R-785. |
| R-790 boss, persistence, migration, and retry | `done` | `docs/reports/r790_rentenitorn_boss_persistence_verification.md`; focused boss/persistence suites | **PASS**. Distinct kill/bypass outcomes, strongroom gating, one-shot rewards, migration, immutable outcome, and node-free retry state are green. | No Rentenitorn implementation defect found. |
| R-791 prior independent acceptance | `done` | `docs/reports/r791_rentenitorn_final_acceptance_verification.md` | **Historical BLOCKED snapshot**. Later packet materialization and verifier repair are reconciled by R-804; its no-human-approval rule remains correct. | Do not overwrite historical evidence. |
| R-804 dependency reconciliation | `done` | `docs/reports/r804_rentenitorn_reconciliation.md` | **PASS for reconciliation; parent remains BLOCKED**. R-804 confirms the six-plate packet, objective package checks, and missing human approvals. | Current closeout decision remains fail-closed. |
| RRMap and enterable-tower contract | `-` | `content/maps/rentenitorn_interior.rrmap`; `test_rentenitorn_interior_map`; `test_enterable_tower_contract`; `test_completed_tower_packages` | **PASS**. Canonical map, all required bands/wall-walk, stable IDs, package identity, and contract constraints pass. | Interior remains `active=false`. |
| Boss content and content corpus | `-` | `content/examples/valid/encounter.rentenitorn_boss.json`; Python content tests; corpus validator | **PASS**. Encounter remains `confidence: invented`, `canon_status: draft`, and `approval.status: draft`; corpus validation exits 0. | No approval inferred from schema validity. |
| Presentation packet integrity | `-` | `docs/reports/images/rentenitorn/capture_manifest.json`; six referenced PNGs | **PASS for machine integrity**. Six outputs resolve and are non-empty, with three matched day/night framing pairs at 1280x720 gameplay scale. | Packet still requires human art readability verdict. |
| P4-027f portfolio gate | `in_review` | `docs/data/p4_027f_tower_portfolio.json`; `tools/verify_p4_027f_tower_portfolio.py` | **PASS as fail-closed verification; portfolio approval BLOCKED**. Verifier is structurally valid and returns `BLOCKED` for declared blockers including R-246. | R-246 is not ready for portfolio approval. |

## Active/release boundary

The current source and manifest preserve both boundaries:

- `content/maps/rentenitorn_interior.rrmap:10` declares `active=false`.
- The capture manifest records `rentenitorn_interior.active=false` and `north_quarter.active=false`.
- `content/transitions/active_destinations.json:104-112` has one `rentenitorn_interior` row with `active=false`, `release=false`, and spawn `rentenitorn_interior_entry`.
- The portfolio ledger keeps the Rentenitorn row `status=in_progress`, `acceptance_ref=null`, and overall `decision=blocked`.

Therefore this verification makes no activation claim. Keep the interior `active=false` and the transition `active=false` / `release=false`; do not mark the map or portfolio active.

## Exact verification commands and results

All seven Godot suites were run with Godot 4.7.1, the checked runner, and separate `GODOT_LOG_DIR=/tmp/r828-*` directories:

```text
GODOT_LOG_DIR=/tmp/r828-test_rentenitorn_interior_map ./tools/run_godot_checked.sh --require-test-summary r828-test_rentenitorn_interior_map -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_interior_map
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r828-test_map_tower_doors ./tools/run_godot_checked.sh --require-test-summary r828-test_map_tower_doors -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_tower_doors
# PASS: 1 file, 7 tests, 0 failures, 0 errors; known shutdown ObjectDB/resource leak warnings only

GODOT_LOG_DIR=/tmp/r828-test_rentenitorn_boss_encounter ./tools/run_godot_checked.sh --require-test-summary r828-test_rentenitorn_boss_encounter -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_boss_encounter
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r828-test_rentenitorn_persistence ./tools/run_godot_checked.sh --require-test-summary r828-test_rentenitorn_persistence -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_persistence
# PASS: 1 file, 4 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r828-test_rentenitorn_presentation ./tools/run_godot_checked.sh --require-test-summary r828-test_rentenitorn_presentation -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_presentation
# PASS: 1 file, 2 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r828-test_completed_tower_packages ./tools/run_godot_checked.sh --require-test-summary r828-test_completed_tower_packages -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_completed_tower_packages
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r828-test_enterable_tower_contract ./tools/run_godot_checked.sh --require-test-summary r828-test_enterable_tower_contract -- /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_enterable_tower_contract
# PASS: 1 file, 3 tests, 0 failures, 0 errors
```

The seven checked suites total **25 Godot tests, 0 failures, 0 errors**. The first two emitted known shutdown-only leak diagnostics accepted by the checked runner.

```text
python3 -m unittest tests.python.test_rentenitorn_boss_content.py -v
# INVOCATION ERROR: exit 1; unittest interprets the .py suffix as an attribute and reports:
# AttributeError: module 'tests.python.test_rentenitorn_boss_content' has no attribute 'py'

python3 -m unittest tests.python.test_rentenitorn_boss_content -v
# PASS: Ran 3 tests; OK

python3 -m unittest tests.python.test_verify_p4_027f_tower_portfolio.py -v
# INVOCATION ERROR: exit 1; unittest interprets the .py suffix as an attribute and reports:
# AttributeError: module 'tests.python.test_verify_p4_027f_tower_portfolio' has no attribute 'py'

python3 -m unittest tests.python.test_verify_p4_027f_tower_portfolio -v
# PASS: Ran 4 tests; OK

python3 tools/validate_content.py content/examples/valid content/examples/support
# PASS: exit 0

python3 tools/verify_p4_027f_tower_portfolio.py
# PASS as fail-closed gate: structurally valid, decision BLOCKED

python3 -m py_compile tools/verify_p4_027f_tower_portfolio.py tests/python/test_verify_p4_027f_tower_portfolio.py tests/python/test_rentenitorn_boss_content.py
# PASS: exit 0

# Manifest/file audit
# PASS: 6/6 manifest outputs present and non-empty; 9/9 referenced source artifacts present;
#       transition row is unique and exactly active=false/release=false

git diff --check -- docs/reports/rentenitorn_interior_review.md docs/reports/r788_rentenitorn_map_transition_verification.md docs/reports/r789_rentenitorn_reversibility_audit.md docs/reports/r790_rentenitorn_boss_persistence_verification.md docs/reports/r791_rentenitorn_final_acceptance_verification.md docs/reports/r804_rentenitorn_reconciliation.md docs/reports/r805_rentenitorn_final_acceptance.md docs/reports/r806_rentenitorn_transition_boundary.md docs/reports/images/rentenitorn/capture_manifest.json content/maps/rentenitorn_interior.rrmap content/maps/north_quarter.rrmap content/transitions/active_destinations.json tools/verify_p4_027f_tower_portfolio.py tests/python/test_verify_p4_027f_tower_portfolio.py
# PASS: exit 0
```

## Final disposition

**BLOCKED for R-246.** All objective Rentenitorn checks required by this task are green after correcting the two `unittest` module invocations. The required human gate is not green: R-826 and R-827 have recorded AI reviews with **BLOCKED** verdicts, not named human art and historical approvals. The owner is **R-785**. The fail-closed P4-027f verifier correctly keeps the portfolio blocked, including R-246.

R-246 is **not ready** for the P4-027f portfolio gate. Keep `R-246` in `in_review`, keep the Rentenitorn interior and transition `active=false`, keep `release=false`, and do not activate or promote the map in a later step until R-785 records both required named human verdicts and a subsequent independent acceptance rerun passes.

## Sources

- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
- [`docs/reports/r788_rentenitorn_map_transition_verification.md`](r788_rentenitorn_map_transition_verification.md)
- [`docs/reports/r789_rentenitorn_reversibility_audit.md`](r789_rentenitorn_reversibility_audit.md)
- [`docs/reports/r790_rentenitorn_boss_persistence_verification.md`](r790_rentenitorn_boss_persistence_verification.md)
- [`docs/reports/r791_rentenitorn_final_acceptance_verification.md`](r791_rentenitorn_final_acceptance_verification.md)
- [`docs/reports/r804_rentenitorn_reconciliation.md`](r804_rentenitorn_reconciliation.md)
- [`docs/reports/r805_rentenitorn_final_acceptance.md`](r805_rentenitorn_final_acceptance.md)
- [`docs/reports/r806_rentenitorn_transition_boundary.md`](r806_rentenitorn_transition_boundary.md)
- [`docs/reports/images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`content/examples/valid/encounter.rentenitorn_boss.json`](../../content/examples/valid/encounter.rentenitorn_boss.json)
- [`docs/data/p4_027f_tower_portfolio.json`](../data/p4_027f_tower_portfolio.json)
- [`scripts/tower/enterable_tower_contract.gd`](../../scripts/tower/enterable_tower_contract.gd)
- [`scripts/tower/completed_tower_packages.gd`](../../scripts/tower/completed_tower_packages.gd)
- [`scripts/combat/rentenitorn_boss_encounter.gd`](../../scripts/combat/rentenitorn_boss_encounter.gd)
- [`scripts/combat/rentenitorn_state_model.gd`](../../scripts/combat/rentenitorn_state_model.gd)
- [`tests/godot/test_rentenitorn_interior_map.gd`](../../tests/godot/test_rentenitorn_interior_map.gd)
- [`tests/godot/test_map_tower_doors.gd`](../../tests/godot/test_map_tower_doors.gd)
- [`tests/godot/test_rentenitorn_boss_encounter.gd`](../../tests/godot/test_rentenitorn_boss_encounter.gd)
- [`tests/godot/test_rentenitorn_persistence.gd`](../../tests/godot/test_rentenitorn_persistence.gd)
- [`tests/godot/test_rentenitorn_presentation.gd`](../../tests/godot/test_rentenitorn_presentation.gd)
- [`tests/godot/test_completed_tower_packages.gd`](../../tests/godot/test_completed_tower_packages.gd)
- [`tests/godot/test_enterable_tower_contract.gd`](../../tests/godot/test_enterable_tower_contract.gd)
- [`tests/python/test_rentenitorn_boss_content.py`](../../tests/python/test_rentenitorn_boss_content.py)
- [`tests/python/test_verify_p4_027f_tower_portfolio.py`](../../tests/python/test_verify_p4_027f_tower_portfolio.py)
- [`tools/verify_p4_027f_tower_portfolio.py`](../../tools/verify_p4_027f_tower_portfolio.py)
