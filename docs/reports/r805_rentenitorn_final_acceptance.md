# R-805 Rentenitorn final independent acceptance

**Task:** R-805 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Acceptance date:** 2026-08-30
**Decision:** **BLOCKED for parent closeout; independent acceptance complete**

## Scope and decision boundary

This is the final independent acceptance rerun after R-804. It rechecks the Rentenitorn package against the R-246 acceptance clauses, the current R-785 presentation packet, the shared enterable-tower contract, the fail-closed portfolio ledger, and the inactive/release boundary. No implementation, map geometry, catalog, transition, runtime activation, or portfolio files were changed by this acceptance.

Automated PASS results are not human historical or art approval. R-246 remains `in_review` because R-785 still has no named historical reviewer or named art reviewer, and because the developer transition currently has `active=true` even though it remains `release=false`. Follow-up R-806 owns reconciliation of that transition boundary.

## Independent acceptance matrix

| R-246 clause | Result | Evidence |
|---|---|---|
| RRMap parses and canonical fingerprint remains stable | **PASS** | `test_rentenitorn_interior_map`: 3/3, including parser success and canonical parse/print round-trip; `docs/reports/images/rentenitorn/capture_manifest.json` records interior fingerprint `037f7a6bc32050bb417ef317fa50a291f380a8113dfc6e0dc13f4531db57ef7d`. |
| Closed-shell traversal covers all three bands and wall-walk | **PASS** | `test_rentenitorn_interior_map`: all required entry, ground, watch, roof, wall-walk, encounter, reward, and evidence anchors are reachable; closed shell retains exactly the authored south and west openings. |
| Reciprocal exterior/interior door and return spawn | **PASS for reciprocal package wiring** | `test_map_tower_doors`: 7/7 and `test_enterable_tower_contract`: 3/3; `content/maps/rentenitorn_interior.rrmap:65` and `content/transitions/active_destinations.json:104-112` retain `rentenitorn_interior_entry` and the exterior return spawn IDs. Release activation is not approved. |
| Collision and camera/lighting presentation | **PASS for automated evidence** | `test_rentenitorn_interior_map` validates the closed-shell geometry contract; `test_rentenitorn_presentation`: 2/2 validates decoded non-blank 1280x720 gameplay-scale plates, orthographic size 33.75, pitch -30, yaw 45, and matched day/night framing. Human visual readability remains **BLOCKED** pending R-785 art review. |
| Boss kill and bypass outcomes are distinct and unsupported outcomes fail closed | **PASS** | `test_rentenitorn_boss_encounter`: 3/3; kill resolves `night_fought`, bypass resolves `night_bypassed`, and unsupported outcomes leave state unchanged. |
| Strongroom, loot, evidence, and outcome durability | **PASS** | `test_rentenitorn_persistence`: 4/4; strongroom remains sealed until resolution, loot/evidence are one-shot, and the outcome is immutable after persistence. |
| Save/load migration and failed-retry restoration without scene nodes | **PASS** | `test_rentenitorn_persistence`: legacy record migration, save round-trip, and failed retry restoration all pass; serialized retry payload contains no `Node` instances. |
| Shared enterable-tower contract | **PASS for Rentenitorn-scoped contract evidence** | `test_enterable_tower_contract`: 3/3; contract validation covers reciprocal destination identity, three reachable levels, wall-walk route, distinct loot/evidence, and alternate outcome requirements. |
| Content validation | **PASS** | `python3 -m unittest tests/python/test_rentenitorn_boss_content.py -v`: 3/3; `python3 tools/validate_content.py content/examples/valid content/examples/support`: exit 0. |
| Completed-tower portfolio verification | **PASS as fail-closed verification; approval remains blocked** | `test_completed_tower_packages`: 3/3; `python3 -m unittest tests/python/test_verify_p4_027f_tower_portfolio.py -v`: 4/4; `python3 tools/verify_p4_027f_tower_portfolio.py`: structurally valid, `BLOCKED` by `R-270`, `R-251`, `R-250`, `R-246`, `R-252`, and `R-629`. |
| Six matched gameplay-scale day/night plates are present, linked, and non-identical | **PASS for packet integrity** | `docs/reports/images/rentenitorn/capture_manifest.json` contains exactly six outputs in three day/night pairs. All files decode at 1280x720, are non-empty/non-blank, share framing keys within each pair, and have distinct SHA-256 values. Paths are listed in the evidence inventory below. |
| Historical human sign-off | **BLOCKED** | `docs/reports/rentenitorn_interior_review.md:132-145` still lists Historical reviewer as **Not assigned** / **BLOCKED**. Automated source review and tests do not substitute for a named historical verdict. Owner: R-785. |
| Art human sign-off | **BLOCKED** | `docs/reports/rentenitorn_interior_review.md:132-145` still lists Art reviewer as **Not assigned** / **BLOCKED**. Automated plate integrity does not certify gameplay readability. Owner: R-785. |
| Interior map inactive | **PASS** | `content/maps/rentenitorn_interior.rrmap:10` declares `active=false`; `scripts/map/map_catalog.gd` and `test_rentenitorn_interior_map` preserve the inactive catalog entry. |
| Developer transition inactive and release-inactive | **BLOCKED** | `content/transitions/active_destinations.json:104-107` currently declares `active=true`, `release=false`. The release boundary is closed, but the requested `active=false` developer transition boundary is not satisfied. No transition edit was permitted in this task. Owner: R-806. |

## Presentation evidence inventory

The manifest is `docs/reports/images/rentenitorn/capture_manifest.json`. It declares renderer `gl_compatibility`, driver `opengl3`, viewport `[1280, 720]`, orthographic gameplay size `33.75`, pitch `-30`, yaw `45`, and distance `90`.

| View | Day output | Night output | Framing key | Day SHA-256 | Night SHA-256 |
|---|---|---|---|---|---|
| Interior three-band route and wall-walk | [`rentenitorn_interior_day.png`](images/rentenitorn/rentenitorn_interior_day.png) | [`rentenitorn_interior_night.png`](images/rentenitorn/rentenitorn_interior_night.png) | `rentenitorn_interior\|4.750\|0.800\|6.750\|33.750` | `9b0f635c528a108f16eee7a31a14a9e1755e04faf664804da531246a76965ff7` | `c5e01c219117613be603038adef4893c50022f335160df5e0e12ad717f6b6888` |
| Exterior tower approach | [`north_quarter_merchant_wall_tower_northwest_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_day.png) | [`north_quarter_merchant_wall_tower_northwest_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_night.png) | `north_quarter_merchant_wall_tower_northwest\|11.000\|0.800\|13.500\|33.750` | `f4537b0532702d832cc49a5fe59522e1482d8dc9b8eac7ef8cc3dc47e2ef0231` | `ec8d0cc4dd6f69ba66ab4fae1b39b4441a53902bf0181ff2a77f1cf41144b562` |
| Exterior south door and return spawn | [`north_quarter_merchant_wall_tower_northwest_door_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_day.png) | [`north_quarter_merchant_wall_tower_northwest_door_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_night.png) | `north_quarter_merchant_wall_tower_northwest_door\|11.000\|0.800\|15.000\|33.750` | `d30fb212cc57f015423641a8ed640634f5d5b86fb3d25e61aa19bf11f6d1aee2` | `144309c46569a3963248df459f068429d8f035f9f8d6544207ac0f4bcab49c3e` |

The six outputs are all present, non-empty, and non-identical within each day/night pair. Their stable-ID coverage is recorded in the manifest and linked review report. This packet proves reproducibility and output integrity only; it does not provide the missing human art verdict.

## Verification commands

All seven Godot suites used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot`, `tools/run_godot_checked.sh --require-test-summary`, and separate `/tmp/r805-*` log directories.

```text
# PASS: 1 file, 3 tests, 0 failures, 0 errors
test_rentenitorn_interior_map

# PASS: 1 file, 3 tests, 0 failures, 0 errors
test_rentenitorn_boss_encounter

# PASS: 1 file, 4 tests, 0 failures, 0 errors
test_rentenitorn_persistence

# PASS: 1 file, 2 tests, 0 failures, 0 errors
test_rentenitorn_presentation

# PASS: 1 file, 7 tests, 0 failures, 0 errors
test_map_tower_doors

# PASS: 1 file, 3 tests, 0 failures, 0 errors
test_enterable_tower_contract

# PASS: 1 file, 3 tests, 0 failures, 0 errors
test_completed_tower_packages

# PASS: 3 tests, OK
python3 -m unittest tests/python/test_rentenitorn_boss_content.py -v

# PASS: exit 0
python3 tools/validate_content.py content/examples/valid content/examples/support

# PASS: 4 tests, OK
python3 -m unittest tests/python/test_verify_p4_027f_tower_portfolio.py -v

# PASS as a fail-closed gate: structurally valid, decision BLOCKED
python3 tools/verify_p4_027f_tower_portfolio.py

# BLOCKED by shared-worktree generated-report drift
python3 tools/generate_active_docs_report.py --check
# active_markdown_report.md is not up to date
```

The focused Godot suites total 25 tests, with 25 passes, 0 failures, and 0 errors. The first and fifth suites emitted known ObjectDB/resource teardown warnings; the checked runner permits only those shutdown diagnostics and returned status 0. The active-docs failure is a shared-worktree baseline issue and was not regenerated because the generated report is outside this task's allowlist.

## Final disposition

**BLOCKED.** The Rentenitorn implementation and automated acceptance evidence are green, and all six presentation outputs are present and machine-verified. Parent closeout is not authorized: R-785 still lacks named historical and art verdicts, the fail-closed portfolio correctly lists R-246 among unresolved blockers, and the developer transition does not yet satisfy the requested `active=false` / `release=false` pair.

Keep `R-246` in `in_review`. Keep `content/maps/rentenitorn_interior.rrmap` and its catalog entry `active=false`; keep the transition `release=false` and do not promote the package based on this report. R-806 must reconcile the transition flag, and R-785 must record both human verdicts before a later acceptance rerun can consider parent closeout.

## Sources

- [`docs/reports/r804_rentenitorn_reconciliation.md`](r804_rentenitorn_reconciliation.md)
- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
- [`docs/reports/r791_rentenitorn_final_acceptance_verification.md`](r791_rentenitorn_final_acceptance_verification.md)
- [`docs/reports/r789_rentenitorn_reversibility_audit.md`](r789_rentenitorn_reversibility_audit.md)
- [`docs/reports/r790_rentenitorn_boss_persistence_verification.md`](r790_rentenitorn_boss_persistence_verification.md)
- [`docs/reports/r788_rentenitorn_map_transition_verification.md`](r788_rentenitorn_map_transition_verification.md)
- [`docs/reports/images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`content/examples/valid/encounter.rentenitorn_boss.json`](../../content/examples/valid/encounter.rentenitorn_boss.json)
- [`docs/data/p4_027f_tower_portfolio.json`](../data/p4_027f_tower_portfolio.json)
- [`docs/reports/p4_027f_completed_tower_portfolio.md`](p4_027f_completed_tower_portfolio.md)
- [`scripts/tower/enterable_tower_contract.gd`](../../scripts/tower/enterable_tower_contract.gd)
- [`tools/verify_p4_027f_tower_portfolio.py`](../../tools/verify_p4_027f_tower_portfolio.py)
