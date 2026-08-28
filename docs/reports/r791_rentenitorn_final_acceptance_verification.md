# R-791 Rentenitorn final independent acceptance verification

**Task:** R-791 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Verification date:** 2026-08-28
**Audited revision:** `3220059b47632ef1cd693e1cd6fcb558b7294003` (`main`, shared dirty worktree)
**Decision:** **BLOCKED**

## Scope and decision rule

This is the final independent acceptance check for the Rentenitorn package. It reconciles the R-246 clauses against the R-785/R-788/R-789/R-790 dependency state, source reports, focused automated evidence, and release boundary. This verification did not modify Rentenitorn implementation, assets, map data, activation manifests, or existing evidence. The only changes in this session are this report, the shared development playbook lesson, and follow-up task R-792 for an unrelated malformed portfolio verifier.

`BLOCKED` is required because R-785 has not recorded both named historical and art sign-offs with matched gameplay-scale day/night captures. No automated or structural PASS is treated as human approval. Rentenitorn remains developer-only and release-inactive.

## Dependency and acceptance matrix

| Dependency / R-246 clause | Board status | Evidence | Result | Owner / blocker |
|---|---|---|---|---|
| R-785 historical form review and art sign-off with day/night captures | `todo` | `docs/reports/rentenitorn_interior_review.md:1-5,78-82`; no Rentenitorn capture directory or signed review is present | **BLOCKED** | R-785. Required named historical approval, named art approval, and matched gameplay-camera day/night plates are absent. |
| R-788 structure and reciprocal transitions | `in_review` | `docs/reports/r788_rentenitorn_map_transition_verification.md:25-70` | **PASS for scoped verification** | R-788 report records map/door/contract/catalog/north-quarter checks and reciprocal probe green; release activation is not claimed. |
| R-789 minimum-claim and reversibility audit | `in_review` | `docs/reports/r789_rentenitorn_reversibility_audit.md:15-28,30-87` | **BLOCKED for final acceptance** | R-789 records structural/content criteria PASS but explicitly blocks historical and art review pending R-785. |
| R-790 boss outcomes, persistence, migration, and retry | `done` | `docs/reports/r790_rentenitorn_boss_persistence_verification.md:13-28,30-52` | **PASS for scoped verification** | R-790 records distinct kill/bypass outcomes, one-shot rewards, save/load migration, node-free retry restoration, and no implementation defect. |
| Conservative pre-mid-fourteenth-century form | Source and automated checks | `content/maps/rentenitorn_interior.rrmap:1-8,25-40`; `docs/reports/rentenitorn_interior_review.md:7-40`; `tests/godot/test_rentenitorn_interior_map.gd` | **PASS as labelled reconstruction; blocked as human acceptance** | R-785 must provide historical sign-off. The package correctly labels unsupported plan/height/occupant details as plausible/invented rather than facts. |
| Unknown fabric remains labelled and reversible | Source and content checks | `docs/reports/rentenitorn_interior_review.md:15-18,20-52`; `tests/python/test_rentenitorn_boss_content.py::test_unknown_fabric_stays_reversible_and_labelled` | **PASS** | No blocker found in scoped evidence. |
| Reciprocal exterior door and return route | Focused Godot and R-788 evidence | `content/maps/north_quarter.rrmap:87-91`; `content/maps/rentenitorn_interior.rrmap:65`; R-788 report | **PASS** | Both directions and stable IDs are covered; no release activation implied. |
| All traversal bands and wall-walk | Focused Godot and R-788 evidence | `tests/godot/test_rentenitorn_interior_map.gd:26-50`; R-788 report | **PASS** | 3/3 Rentenitorn interior tests passed, including reachability and closed-shell checks. Gameplay-scale readability still belongs to R-785. |
| Distinct boss outcomes | Focused Godot/Python and R-790 evidence | `tests/godot/test_rentenitorn_boss_encounter.gd`; `content/examples/valid/encounter.rentenitorn_boss.json`; R-790 report | **PASS** | Kill and bypass remain distinct; unsupported outcome fails closed. |
| Save/load persistence and retry safety | Focused Godot and R-790 evidence | `tests/godot/test_rentenitorn_persistence.gd`; R-790 report | **PASS** | 4/4 persistence tests passed, including migration, immutable outcome, sealed strongroom, one-shot markers, and node-free retry payload. |
| Map activation boundary | Source and focused Godot evidence | `content/maps/rentenitorn_interior.rrmap:10`; `scripts/map/map_catalog.gd`; `scripts/tower/completed_tower_packages.gd`; `content/transitions/active_destinations.json:104-112` | **PASS / preserved** | Authored map/catalog remain `active=false`; developer transition remains `release=false`. This task did not activate the map. |
| Existing Rentenitorn report links | Filesystem probe | `docs/reports/rentenitorn_interior_review.md:84-88` and report link probe | **PASS** | All 3 links in the source review resolve. All 4 Rentenitorn reports inspected have resolving local links. |

## Exact verification commands and results

All Godot checks used Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot`, the repository checked runner, and separate `/tmp/r791-*` log directories.

```text
GODOT_LOG_DIR=/tmp/r791-test_rentenitorn_interior_map tools/run_godot_checked.sh \
  --require-test-summary r791-test_rentenitorn_interior_map -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_interior_map
# PASS: 1 file, 3 tests, 0 failures, 0 errors; teardown emitted known ObjectDB/resource leak warnings

GODOT_LOG_DIR=/tmp/r791-test_rentenitorn_boss_encounter tools/run_godot_checked.sh \
  --require-test-summary r791-test_rentenitorn_boss_encounter -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_boss_encounter
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r791-test_rentenitorn_persistence tools/run_godot_checked.sh \
  --require-test-summary r791-test_rentenitorn_persistence -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_persistence
# PASS: 1 file, 4 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r791-test_completed_tower_packages tools/run_godot_checked.sh \
  --require-test-summary r791-test_completed_tower_packages -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_completed_tower_packages
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r791-test_enterable_tower_contract tools/run_godot_checked.sh \
  --require-test-summary r791-test_enterable_tower_contract -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_enterable_tower_contract
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r791-test_map_tower_doors tools/run_godot_checked.sh \
  --require-test-summary r791-test_map_tower_doors -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_tower_doors
# PASS: 1 file, 7 tests, 0 failures, 0 errors; teardown emitted known ObjectDB/resource leak warnings

python3 -m unittest tests.python.test_rentenitorn_boss_content -v
# PASS: Ran 3 tests; OK

python3 tools/validate_content.py content/examples/valid content/examples/support
# PASS: exit 0

git diff --check -- <scoped Rentenitorn/report files>
# PASS: exit 0
```

The focused summaries total 23 Godot tests across 6 files, with 23 passes, 0 failures, and 0 errors, plus 3 focused Python tests. The full repository `git diff --check` was not used as acceptance evidence because the worktree contains unrelated concurrent WIP; the scoped diff check passed.

## Required checks that are blocked or not clean

```text
python3 tools/verify_p4_027f_tower_portfolio.py
# BLOCKED: tools/verify_p4_027f_tower_portfolio.py:233
# IndentationError: expected an indented block

python3 -m unittest tests.python.test_verify_p4_027f_tower_portfolio -v
# BLOCKED by the same portfolio verifier IndentationError at line 233

python3 tools/generate_active_docs_report.py --check
# BLOCKED: active_markdown_report.md is not up to date in the shared dirty worktree
```

The malformed verifier is outside this verification-only task's allowed implementation scope. Follow-up **R-792** was created at priority p0 to repair it. The stale generated active-doc report is a shared-worktree baseline issue and is not regenerated here because that would absorb unrelated documentation changes.

The R-261 portfolio ledger is currently `decision: blocked`; it lists R-246 among required blockers and `requires_signed_day_night_captures: true`. Its current Rentenitorn row remains `status: in_progress` with no `acceptance_ref`, which is consistent with this result. The existing portfolio verifier is therefore not allowed to convert this package into approval, even if repaired.

## Final disposition

**BLOCKED.**

Rentenitorn's structural, encounter, persistence, migration, retry, and developer-only boundaries are independently green. The package is not ready for final acceptance because R-785 has not recorded the required named historical and art sign-offs plus matched gameplay-scale day/night captures, and the independent R-789 audit remains blocked on that same evidence. The unrelated R-261 verifier parse defect and stale active-doc report are recorded as verification limitations with explicit ownership, not silently waived. Keep `active=false` and `release=false`; do not infer approval or activate the map.

## Sources

- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
- [`docs/reports/r788_rentenitorn_map_transition_verification.md`](r788_rentenitorn_map_transition_verification.md)
- [`docs/reports/r789_rentenitorn_reversibility_audit.md`](r789_rentenitorn_reversibility_audit.md)
- [`docs/reports/r790_rentenitorn_boss_persistence_verification.md`](r790_rentenitorn_boss_persistence_verification.md)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`docs/data/p4_027f_tower_portfolio.json`](../data/p4_027f_tower_portfolio.json)
- [`docs/reports/p4_027f_completed_tower_portfolio.md`](p4_027f_completed_tower_portfolio.md)
- [`scripts/tower/completed_tower_packages.gd`](../../scripts/tower/completed_tower_packages.gd)
- [`tests/godot/test_rentenitorn_interior_map.gd`](../../tests/godot/test_rentenitorn_interior_map.gd)
- [`tests/godot/test_rentenitorn_boss_encounter.gd`](../../tests/godot/test_rentenitorn_boss_encounter.gd)
- [`tests/godot/test_rentenitorn_persistence.gd`](../../tests/godot/test_rentenitorn_persistence.gd)
- [`tests/python/test_rentenitorn_boss_content.py`](../../tests/python/test_rentenitorn_boss_content.py)
