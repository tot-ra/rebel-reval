# R-806 Rentenitorn transition boundary reconciliation

**Task:** R-806
**Parent:** R-246 / P4-027d
**Reconciliation date:** 2026-08-30
**Decision:** **PASS for transition boundary; parent acceptance remains BLOCKED**

## Scope and decision boundary

R-806 reconciles the Rentenitorn developer transition with the inactive authored map and catalog. The transition manifest now keeps `rentenitorn_interior` fail-closed with the exact pair `active=false` and `release=false`. The reciprocal transition and return spawn IDs remain unchanged. No Rentenitorn map geometry, catalog entry, runtime activation, or portfolio decision was changed.

The parent `R-246` remains `in_review`. R-785 still lacks named historical and art verdicts, and automated checks do not substitute for those human approvals. This report does not activate the map or promote the tower package.

## Reconciled manifest record

`content/transitions/active_destinations.json` contains exactly one `rentenitorn_interior` record:

```json
{
  "id": "rentenitorn_interior",
  "path": "res://scenes/reval_north/rentenitorn_interior.tscn",
  "active": false,
  "release": false,
  "spawns": [
    {"id": "rentenitorn_interior_entry"}
  ]
}
```

The source map remains `scope=prototype active=false`, and its catalog entry remains inactive. The north-quarter authored transition still points to `rentenitorn_interior` and `rentenitorn_interior_entry`; only the manifest activation flag changed.

## Validation change

The semantic transition validator now retains inactive destination records for authored reciprocal wiring and spawn validation. It still rejects an active map pointing to an inactive destination. This distinction allows inactive-to-inactive prototype seams to remain structurally verifiable without making them runtime-accessible.

Regression coverage includes:

- exact manifest flags and stable `rentenitorn_interior_entry` spawn;
- inactive source to inactive destination wiring remains valid;
- active source to inactive destination remains rejected with `MAP_TRANSITION_DESTINATION_UNKNOWN`.

## Acceptance matrix

| Check | Result | Evidence |
|---|---|---|
| Exact transition manifest row | **PASS** | JSON parse, unique scene IDs, exact `active=false` / `release=false` pair, and unchanged `rentenitorn_interior_entry` spawn. |
| Transition manifest suite | **PASS: 1 file, 6 tests, 0 failures, 0 errors** | `test_transition_manifest` |
| Semantic transition validation suite | **PASS: 1 file, 10 tests, 0 failures, 0 errors** | `test_map_blueprint_semantic_validation` |
| Tower door suite | **PASS: 1 file, 7 tests, 0 failures, 0 errors** | `test_map_tower_doors` |
| Rentenitorn map suite | **PASS: 1 file, 3 tests, 0 failures, 0 errors** | `test_rentenitorn_interior_map` |
| Enterable tower contract | **PASS: 1 file, 3 tests, 0 failures, 0 errors** | `test_enterable_tower_contract` |
| Completed tower package | **PASS: 1 file, 3 tests, 0 failures, 0 errors** | `test_completed_tower_packages` |
| Boss encounter | **PASS: 1 file, 3 tests, 0 failures, 0 errors** | `test_rentenitorn_boss_encounter` |
| Persistence and retry | **PASS: 1 file, 4 tests, 0 failures, 0 errors** | `test_rentenitorn_persistence` |
| Presentation packet | **PASS: 1 file, 2 tests, 0 failures, 0 errors** | `test_rentenitorn_presentation` |
| Rentenitorn content tests | **PASS: 3 tests, OK** | `python3 -m unittest tests/python/test_rentenitorn_boss_content.py -v` |
| Tower portfolio tests | **PASS: 4 tests, OK** | `python3 -m unittest tests/python/test_verify_p4_027f_tower_portfolio.py -v` |
| Content corpus validation | **PASS: exit 0** | `python3 tools/validate_content.py content/examples/valid content/examples/support` |
| Map activation guard | **PASS** | `python3 tools/verify_map_activation.py` |
| Changed GDScript lint | **PASS** | `python3 -m gdtoolkit.linter scripts/map/map_blueprint_semantic_validator.gd tests/godot/test_r806_transition_boundary.gd` |
| Scoped whitespace check | **PASS** | `git diff --check -- content/transitions/active_destinations.json scripts/map/map_blueprint_semantic_validator.gd tests/godot/test_transition_manifest.gd tests/godot/test_map_blueprint_semantic_validation.gd` |

The focused tower-door suite previously exposed the intended inactive-destination boundary as `MAP_TRANSITION_DESTINATION_UNKNOWN`. After the validator reconciliation it passes all 7 tests. The suite still emits known shutdown resource-leak diagnostics after its zero-failure summary; these are permitted by the checked runner and are unrelated to the transition result.

## Final disposition

**R-806 is complete.** Rentenitorn is now inactive and non-release in the transition manifest, while reciprocal IDs and return spawn wiring remain intact. The map and catalog remain inactive, and no release activation is claimed.

Keep `R-246` in `in_review` until R-785 records named historical and art verdicts. The old R-805 report remains a historical record of the pre-reconciliation blocker; this addendum is the current transition-boundary result.

## Sources

- [`content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`scripts/map/map_blueprint_semantic_validator.gd`](../../scripts/map/map_blueprint_semantic_validator.gd)
- [`tests/godot/test_transition_manifest.gd`](../../tests/godot/test_transition_manifest.gd)
- [`tests/godot/test_map_blueprint_semantic_validation.gd`](../../tests/godot/test_map_blueprint_semantic_validation.gd)
- [`docs/reports/r805_rentenitorn_final_acceptance.md`](r805_rentenitorn_final_acceptance.md)
- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
