# R-804 Rentenitorn reconciliation and dependency closure

**Task:** R-804 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Reconciliation date:** 2026-08-30
**Decision:** **BLOCKED for parent closeout; R-804 reconciliation complete**

## Scope and decision boundary

This note reconciles the current board dependencies, Rentenitorn evidence packet, source contracts, focused verification, and portfolio gate. It does not change Rentenitorn implementation, map geometry, catalog data, transition data, or activation state. Automated evidence is not treated as historical or art approval.

The current packet contains all six gameplay-scale PNGs required by R-785, in three matched day/night framing pairs. The remaining closeout blocker is human sign-off: the source review still records both the historical and art reviewers as **Not assigned** / **BLOCKED**. R-246 therefore remains `in_review` and the map remains developer-only.

## Dependency and evidence matrix

| Dependency | Board state | Current evidence | Reconciliation result | Remaining owner / boundary |
|---|---|---|---|---|
| R-270 / P4-027a shared enterable-tower contract | `in_review` | `scripts/tower/enterable_tower_contract.gd`; `test_enterable_tower_contract`; `test_completed_tower_packages` | **PASS for Rentenitorn-scoped contract evidence**: reciprocal identity, three-floor minimum, wall-walk, distinct outcomes, loot/evidence, persistence and retry fields are covered by the package and focused suites | Parent/shared tower portfolio gate remains open; do not infer portfolio approval from the Rentenitorn package |
| R-785 human presentation and sign-off packet | `in_review` | `docs/reports/rentenitorn_interior_review.md:78-145`; `docs/reports/images/rentenitorn/capture_manifest.json`; six PNGs under `docs/reports/images/rentenitorn/` | **BLOCKED for sign-off**: packet is present and machine-verified, but both named human reviewers are still unassigned and both verdicts remain BLOCKED | R-785: named historical reviewer and named art reviewer must inspect and record verdicts |
| R-788 map structure and reciprocal transitions | `in_review` | `docs/reports/r788_rentenitorn_map_transition_verification.md`; current map/door/contract suites | **PASS for scoped verification**: map structure, closed shell, traversal anchors, exterior door, reciprocal IDs and developer-only boundary are green | Release activation is outside R-804 and remains prohibited |
| R-789 minimum-claim reversibility audit | `done` | `docs/reports/r789_rentenitorn_reversibility_audit.md` | **PASS for structural/content criteria; BLOCKED for final acceptance**: unknown fabric is labelled reversible, encounter is invented/draft, stable IDs and footprint are preserved | R-785 owns the missing historical/art verdicts explicitly called out by R-789 |
| R-790 boss outcomes and durable state | `done` | `docs/reports/r790_rentenitorn_boss_persistence_verification.md`; boss/persistence suites | **PASS**: kill/bypass outcomes, fail-closed unsupported outcome, strongroom gating, one-shot loot/evidence, migration, immutable outcome, and node-free retry restoration are green | No Rentenitorn implementation defect identified |
| R-791 independent final acceptance | `done` | `docs/reports/r791_rentenitorn_final_acceptance_verification.md` plus current packet and rerun below | **Superseded BLOCKED snapshot**: its 2026-08-28 report correctly refused approval, but its claims that captures were absent and the portfolio verifier was malformed are stale after R-785 packet materialization and R-792 repair | This note is the current reconciliation; it does not rewrite historical R-791 evidence or waive its human-review rule |
| R-792 portfolio verifier repair | `done` | `tools/verify_p4_027f_tower_portfolio.py`; `tests/python/test_verify_p4_027f_tower_portfolio.py` | **PASS**: verifier parses and the fail-closed repository ledger returns `BLOCKED`; all four focused regression tests pass | Portfolio remains blocked by its declared dependencies, including R-246 |

## Current artifact reconciliation

### Presentation packet

The manifest records six outputs, all present and non-empty:

| View | Day | Night | Framing key | Stable-ID coverage |
|---|---|---|---|---|
| Interior three-band route and wall-walk | `rentenitorn_interior_day.png` | `rentenitorn_interior_night.png` | `rentenitorn_interior\|4.750\|0.800\|6.750\|33.750` | `rentenitorn_interior_entry`, `rentenitorn_floor_ground`, `rentenitorn_floor_watch`, `rentenitorn_floor_roof`, `rentenitorn_wall_walk` |
| Exterior tower approach | `north_quarter_merchant_wall_tower_northwest_day.png` | `north_quarter_merchant_wall_tower_northwest_night.png` | `north_quarter_merchant_wall_tower_northwest\|11.000\|0.800\|13.500\|33.750` | `merchant_wall_tower_northwest` |
| Exterior south door and return spawn | `north_quarter_merchant_wall_tower_northwest_door_day.png` | `north_quarter_merchant_wall_tower_northwest_door_night.png` | `north_quarter_merchant_wall_tower_northwest_door\|11.000\|0.800\|15.000\|33.750` | `merchant_wall_tower_northwest`, `rentenitorn_enter`, `merchant_wall_tower_northwest_return` |

The packet uses `1280x720`, orthographic gameplay scale `33.75`, pitch `-30`, yaw `45`, distance `90`, `gl_compatibility`, and `opengl3`. Day/night pairs share framing keys and differ by time-of-day metadata. The `test_rentenitorn_presentation` suite confirms decoded, non-blank gameplay-scale outputs and matched pairs.

### Historical and content boundary

The source review and RRMap retain the minimum-claim boundary: the dossier attests presence on the north-west circuit before the mid-fourteenth century, but does not establish plan, height, wall thickness, room count, or occupant. The closed rectangular shell, three traversal bands, timber deck, wall-walk, room uses, Rent Tower Watcher, dues dispute, and outcomes remain labelled plausible/invented reconstruction. The encounter fixture remains `confidence: invented`, `canon_status: draft`, and `approval.status: draft`.

The interior RRMap and catalog remain `active=false`. The transition manifest permits developer traversal with `active=true` but keeps `release=false`; this is not release activation. The portfolio ledger remains `decision: blocked` and the Rentenitorn row remains `status: in_progress` with no `acceptance_ref`.

## Fresh verification matrix

All checked Godot commands used `/Applications/Godot.app/Contents/MacOS/Godot` and `tools/run_godot_checked.sh --require-test-summary`.

| Check | Result |
|---|---|
| `test_rentenitorn_interior_map` | **PASS: 1 file, 3 tests, 0 failures, 0 errors** |
| `test_map_tower_doors` | **PASS: 1 file, 7 tests, 0 failures, 0 errors** |
| `test_rentenitorn_boss_encounter` | **PASS: 1 file, 3 tests, 0 failures, 0 errors** |
| `test_rentenitorn_persistence` | **PASS: 1 file, 4 tests, 0 failures, 0 errors** |
| `test_rentenitorn_presentation` | **PASS: 1 file, 2 tests, 0 failures, 0 errors** |
| `test_completed_tower_packages` | **PASS: 1 file, 3 tests, 0 failures, 0 errors** |
| `test_enterable_tower_contract` | **PASS: 1 file, 3 tests, 0 failures, 0 errors** |
| `python3 -m unittest tests.python.test_rentenitorn_boss_content -v` | **PASS: 3 tests, OK** |
| `python3 -m unittest tests.python.test_verify_p4_027f_tower_portfolio -v` | **PASS: 4 tests, OK** |
| `python3 tools/validate_content.py content/examples/valid content/examples/support` | **PASS: exit 0** |
| `python3 tools/verify_p4_027f_tower_portfolio.py` | **PASS as fail-closed gate: structurally valid, decision `BLOCKED`** |
| Manifest/file audit | **PASS: 6/6 outputs present and non-empty; 3 matched day/night framing keys; both maps marked inactive in manifest** |
| `python3 tools/generate_active_docs_report.py --check` | **BLOCKED by shared-worktree baseline: `active_markdown_report.md is not up to date`; no generated-report refresh claimed** |

The first two Rentenitorn map/door runs emitted known ObjectDB/resource teardown warnings, but the checked summaries were zero-failure/zero-error and wrapper status was zero. These warnings do not change the scoped results. The active-docs command was run separately and is blocked only by the pre-existing shared-worktree generated-report drift noted in the matrix.

## Final disposition

**R-804 is complete as a reconciliation task, with the parent closeout BLOCKED.** The implementation, map structure, transition contract, boss/persistence package, content corpus, repaired portfolio verifier, and six-file presentation packet are reconciled and objectively green. The parent cannot close because R-785 has not recorded a named historical verdict and a named art verdict. No automated test, source review, capture manifest, or portfolio verifier result substitutes for those human approvals.

Keep `R-246` in `in_review`, keep `rentenitorn_interior` `active=false`, and keep its transition `release=false`. The next acceptance action is for R-785 to obtain and record both human verdicts; after that, R-805 may rerun the independent acceptance matrix. No activation is authorized by this note.

## Sources

- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
- [`docs/reports/r788_rentenitorn_map_transition_verification.md`](r788_rentenitorn_map_transition_verification.md)
- [`docs/reports/r789_rentenitorn_reversibility_audit.md`](r789_rentenitorn_reversibility_audit.md)
- [`docs/reports/r790_rentenitorn_boss_persistence_verification.md`](r790_rentenitorn_boss_persistence_verification.md)
- [`docs/reports/r791_rentenitorn_final_acceptance_verification.md`](r791_rentenitorn_final_acceptance_verification.md)
- [`docs/reports/images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`content/examples/valid/encounter.rentenitorn_boss.json`](../../content/examples/valid/encounter.rentenitorn_boss.json)
- [`docs/data/p4_027f_tower_portfolio.json`](../data/p4_027f_tower_portfolio.json)
- [`docs/reports/p4_027f_completed_tower_portfolio.md`](p4_027f_completed_tower_portfolio.md)
- [`scripts/tower/enterable_tower_contract.gd`](../../scripts/tower/enterable_tower_contract.gd)
- [`tools/verify_p4_027f_tower_portfolio.py`](../../tools/verify_p4_027f_tower_portfolio.py)
- [`tests/python/test_verify_p4_027f_tower_portfolio.py`](../../tests/python/test_verify_p4_027f_tower_portfolio.py)
