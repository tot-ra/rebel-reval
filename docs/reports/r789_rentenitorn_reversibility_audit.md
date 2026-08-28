# R-789 Rentenitorn minimum-claim and reversibility audit

**Task:** R-789 / P4-027d decomposition
**Parent:** R-246 / P4-027d
**Audit date:** 2026-08-28
**Audited revision:** `1290c2d9` (`main`, shared worktree)
**Decision:** **BLOCKED**

## Scope and decision boundary

This is a review-only audit of the Rentenitorn historical minimum-claim and reversibility boundary. It does not change the interior report, RRMap, catalog, transition manifest, exterior map, registry, or encounter content. The current worktree contains unrelated edits in `content/maps/north_quarter.rrmap`; no Rentenitorn-specific line is part of that diff.

The implementation is structurally complete, but the package cannot be treated as historically/art accepted until the named human review and gameplay-scale day/night captures owned by **R-785** are recorded. No approval is inferred from automated tests or from the existing implementation report.

## Minimum-claim and reversibility matrix

| Criterion | Result | Source evidence and owner |
|---|---|---|
| Historical claim is limited to the attested presence and date boundary | **PASS** | `history/dossiers/topography/walls-gates-towers.md:131-150` records Rent Tower as present on the NW circuit before the mid-fourteenth century and separately labels typical forms as general early-period context. `docs/reports/reval_fortifications_1343.md:7-28` calls the four-tower baseline conservative and maps Rentenitorn to `merchant_wall_tower_northwest`. `docs/reports/rentenitorn_interior_review.md:9-18` explicitly states that no plan, height, wall thickness, room count, or named occupant is established. |
| Unsupported plan, height, and occupant details remain labelled rather than presented as facts | **PASS** | `docs/reports/rentenitorn_interior_review.md:20-40` labels the closed shell as a plausible composite, the strongroom/counting/deck/partitions as invented or plausible reconstruction, and explains that `rentenitorn_floor_roof` is a gameplay deck rather than a claimed masonry storey. `content/maps/rentenitorn_interior.rrmap:1-8,25-27,33-40,56-58` repeats the minimum-claim and reversible-authorship boundary in the authored source. |
| Stable IDs and the exterior registry footprint remain reversible | **PASS** | `scripts/map/reval_fortification_registry.gd:42-51` retains `rentenitorn`, `north_quarter`, `merchant_wall_tower_northwest`, `completed_1343`, and `door_side=south`. `content/maps/north_quarter.rrmap:87-91` retains the same tower ID and inward south door transition. The current `north_quarter.rrmap` diff contains unrelated elevation/property work and no Rentenitorn-specific diff lines. |
| Interior identity can be revised without changing save/transition identity | **PASS** | `docs/reports/rentenitorn_interior_review.md:42-52` states that stable IDs are owned by `CompletedTowerPackages`, the exterior footprint and sealed wall policy remain fixed, and uncertain interior elements are not identity-bearing. The contract IDs are listed in `scripts/map/definitions/prototypes/rentenitorn_interior_definition.gd:18-56`. |
| Encounter content remains draft/invented and does not claim an attested occupant or event | **PASS** | `content/examples/valid/encounter.rentenitorn_boss.json:7-12,24-39` sets `confidence` and `canon_status` to `invented`/`draft`, keeps approval `draft`, and describes the watcher, dues dispute, composition, and outcomes as authored content. `docs/reports/rentenitorn_interior_review.md:54-62` records the same boundary. |
| Developer-only state is preserved; no release activation is claimed | **PASS** | `content/maps/rentenitorn_interior.rrmap:9-13` declares `scope=prototype active=false`; `scripts/map/map_catalog.gd:31-36` declares the catalog entry `active=false`; and `scripts/tower/completed_tower_packages.gd:192-200,288` enforces developer-only and `release_active=false`. The transition manifest entry is intentionally `active=true, release=false` (`content/transitions/active_destinations.json:103-112`), which permits developer traversal while keeping release activation disabled. |
| Existing report links resolve | **PASS** | Relative links in `docs/reports/rentenitorn_interior_review.md:84-88` resolve to `history/dossiers/topography/walls-gates-towers.md`, `docs/reports/reval_fortifications_1343.md`, and `content/maps/rentenitorn_interior.rrmap`. A filesystem probe confirmed all three targets exist. |
| No later tower silhouette or activation claim has been introduced | **PASS** | `docs/reports/reval_fortifications_1343.md:44-54` explicitly excludes later additions, Fat Margaret, Kiek in de Kök, foreworks, and later wall profiles. `history/dossiers/topography/walls-gates-towers.md:165-176` dates the relevant later forms. The Rentenitorn RRMap contains no later-silhouette terms and remains inactive in its authored source. |
| Historical reviewer signs the conservative form | **BLOCKED** | `docs/reports/rentenitorn_interior_review.md:78-82` requires historical review before the report can become signed. No named historical approval is recorded. Owner: **R-785**, `P4-027d: sign off Rentenitorn interior with day/night captures`. |
| Art reviewer confirms gameplay-scale three-band and wall-walk readability | **BLOCKED** | The required gameplay-camera day/night captures and art review are not recorded. The existing structural evidence proves IDs and reachability only, not visual acceptance. Owner: **R-785**. |

## Automated verification

All focused commands below ran against the current checkout with Godot 4.7.1 at `/Applications/Godot.app/Contents/MacOS/Godot`.

```text
python3 -m unittest tests.python.test_rentenitorn_boss_content -v
# PASS: Ran 3 tests in 0.022s; OK

python3 tools/validate_content.py content/examples/valid content/examples/support
# PASS: exit 0

GODOT_LOG_DIR=/tmp/r789-rentenitorn tools/run_godot_checked.sh \
  --require-test-summary r789-test_rentenitorn_interior_map -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_interior_map
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r789-rentenitorn tools/run_godot_checked.sh \
  --require-test-summary r789-test_rentenitorn_boss_encounter -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_boss_encounter
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r789-rentenitorn tools/run_godot_checked.sh \
  --require-test-summary r789-test_rentenitorn_persistence -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_persistence
# PASS: 1 file, 4 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r789-rentenitorn tools/run_godot_checked.sh \
  --require-test-summary r789-test_completed_tower_packages -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_completed_tower_packages
# PASS: 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r789-rentenitorn tools/run_godot_checked.sh \
  --require-test-summary r789-test_map_tower_doors -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_tower_doors
# PASS: 1 file, 7 tests, 0 failures, 0 errors
```

The interior-map and tower-door runs emitted Godot ObjectDB/resource leak warnings during teardown, but their checked summaries were zero-failure/zero-error and their wrapper status was 0. These warnings do not alter the scoped audit result.

A separate source probe passed the following assertions:

- all five audited artifacts exist;
- the encounter JSON parses;
- the authored RRMap and MapCatalog remain `active=false`;
- the transition manifest entry is `active=true` with `release=false` for developer traversal;
- the Rentenitorn registry row retains the same historical ID, map, building ID, and south door;
- the portfolio remains globally `decision=blocked` and Rentenitorn remains `status=in_progress`;
- all three report links resolve;
- no later-silhouette term is present in the authored Rentenitorn RRMap.

## Final disposition

**BLOCKED.** The historical minimum-claim and reversibility boundary is structurally and content-wise PASS, and all focused automated checks are green. R-246 remains open because R-785 must provide named historical and art sign-off plus matched gameplay-scale day/night captures. Do not change `rentenitorn_interior_review.md` to signed, change the map/catalog/manifest to release-active, or infer approval from this audit.

## Sources

- [`docs/reports/rentenitorn_interior_review.md`](rentenitorn_interior_review.md)
- [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap)
- [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md)
- [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md)
- [`scripts/map/reval_fortification_registry.gd`](../../scripts/map/reval_fortification_registry.gd)
- [`content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`content/examples/valid/encounter.rentenitorn_boss.json`](../../content/examples/valid/encounter.rentenitorn_boss.json)
- [`docs/reports/r788_rentenitorn_map_transition_verification.md`](r788_rentenitorn_map_transition_verification.md)
- [`docs/reports/r790_rentenitorn_boss_persistence_verification.md`](r790_rentenitorn_boss_persistence_verification.md)
