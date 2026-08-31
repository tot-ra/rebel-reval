# R-838 P4-020e North Quarter activation preflight

**Task:** R-838 / P4-020e
**Parent:** R-245 / P4-020 North Quarter activation
**Verification date:** 2026-09-01
**Repository HEAD at verification:** `97ec7a292352e72dbb4831e0a4f3a89df1e59d4d` (`docs: record North Quarter traversal gate evidence`)
**Godot:** `4.7.1.stable.official.a13da4feb`
**Decision:** **BLOCKED - controlled promotion was not authorized and no activation registry was changed**

## Scope and decision boundary

This is the controlled activation preflight for North Quarter. Promotion is atomic: the authored RRMap, map catalog, transition release state, approval ledger, and accepted day/night evidence must clear together. A dependency with board status `in_review` is not treated as accepted.

The preflight found unresolved dependencies and parser/validator blockers. It therefore preserves the fail-closed developer-only state. No partial activation, evidence substitution, or blocker removal was performed.

## Dependency matrix

Board statuses and linked evidence were checked on 2026-09-01:

| Dependency | Board ref | Board status | Activation interpretation |
|---|---|---|---|
| Art-bible and technical-freeze baseline | R-111 / P0-040 | `in_progress` | **BLOCKED** - maintainer approval is not closed |
| Converted-map visual/gameplay parity | R-214 / P2-021 | `in_review` | **BLOCKED** - review status is not an accepted parity verdict |
| Central District activation prerequisite | R-254 / P4-019 | `in_review` | **BLOCKED** - prerequisite remains open |
| North Quarter environment acceptance | R-280 / P4-023f | `in_review` | **BLOCKED** - signed historical/art and day/night acceptance remain unresolved |
| North Quarter elevation parser gate | R-835 | `in_review` | **BLOCKED** - clean HEAD does not parse `elevation_ramp` / `elevation_area`; R-604 remains the owner of that boundary |
| North Quarter day/night parity review | R-836 | `done` | **BLOCKED** - the committed review explicitly records `PENDING / BLOCKED`; available R-785 plates are not a signed P4-023f packet linked to the current revision |
| North Quarter traversal/collision gate | R-837 | `in_progress` | **BLOCKED** - prior scoped evidence is not an activation approval and the parent gate remains open |

R-834 is complete as a dependency reconciliation, but it confirms that the four ledger blockers above remain unresolved. R-839 is intentionally not claimable as a final verification task until R-838 and the direct dependencies are done.

## Activation-state matrix

The repository remains internally consistent and fail-closed:

| Registry | Current state | Required blocked-state interpretation | Result |
|---|---|---|---|
| `content/maps/north_quarter.rrmap` | `scope=prototype active=false` | Prototype and inactive | **PASS** |
| `scripts/map/map_catalog.gd` / `reval_north` | `scope=prototype`, `active=false` | Prototype and inactive | **PASS** |
| `content/transitions/active_destinations.json` / `reval_north` | `active=true`, `release=false` | Developer traversal available, release disabled | **PASS** |
| `docs/data/p4_020_north_quarter_activation.json` | `decision=blocked`; blockers `P0-040`, `P2-021`, `P4-019`, `P4-023f` | Ledger remains blocked with all named dependencies | **PASS** |
| `parity_review` | `status=pending`; `day_capture=null`; `night_capture=null` | No unaccepted evidence promoted | **PASS** |

No production registry is active, and no partial-activation condition is present.

## Verification matrix

| Check | Result | Evidence and interpretation |
|---|---|---|
| North Quarter activation guard | **PASS, fail-closed** | `python3 tools/verify_north_quarter_activation.py` returned `P4-020 North Quarter activation readiness guard passed.` |
| Activation-ledger Python suite | **PASS** | `python3 -m unittest tests.python.test_verify_north_quarter_activation -v`: **4 tests, OK** |
| Generic map activation guard | **PASS** | `python3 tools/verify_map_activation.py`: `Map activation guard passed.` |
| North Quarter prototype Godot suite | **BLOCKED** | `/tmp/rebel-reval-r838/r838-north-quarter-prototype.log`: **1 file, 9 tests, 19 failures, 44 errors**. The first authored-map failures are `unknown command 'elevation_ramp'` and `unknown command 'elevation_area'` at `content/maps/north_quarter.rrmap:12-15`; dependent `to_reval_harbor` access is a parser-cascade failure. |
| Transition spawn-clearance Godot suite | **BLOCKED** | `/tmp/rebel-reval-r838/r838-transition-spawn-clearance.log`: **1 file, 6 tests, 6 failures, 67 errors**. It repeats the elevation parser errors and then reports dependent `spawn_offset` dictionary access failures. |
| Transition manifest Godot suite | **PASS at assertion summary, not clean acceptance evidence** | `/tmp/rebel-reval-r838/r838-transition-manifest.log`: **1 file, 6 tests, 0 failures, 0 errors**, but the log also contains pre-existing missing preload diagnostics for `res://assets/characters/shared/hero_cape.glb` and `hero_hat.glb`; the checked clean acceptance boundary therefore remains unresolved. |
| Map blueprint validator | **BLOCKED** | `godot --headless --path . --script tools/validate_map_blueprints.gd` exits 1. North Quarter emits the same elevation parser errors and `MAP_REGISTRY_FACTORY_INVALID`; the same clean-HEAD parser/factory cascade also affects other elevation-authored maps. |
| Map conversion-plan validator | **BLOCKED by repository baseline** | `python3 tools/verify_map_conversion_plan.py` exits 1 on missing scene coverage, including `scenes/reval_north/rentenitorn_interior.tscn`, plus unrelated character/debug/benchmark scenes. This is not repaired by R-838. |
| Map audit validator | **BLOCKED by repository baseline** | `python3 tools/verify_map_audit.py` exits 1 on the same missing scene-coverage inventory. No map-audit baseline was waived. |
| Active-docs check | **BLOCKED by repository baseline** | `python3 tools/generate_active_docs_report.py --check` reports `active_markdown_report.md is not up to date`. No broad generated report was regenerated in this scoped activation task. |
| Aggregate transition verifier | **BLOCKED** | `tools/verify_transitions.gd` exits 1 with **48** registered-spawn diagnostics, including missing North Quarter IDs such as `from_monastery`, `to_reval_harbor`, and `outer_harbor_exit`, followed by known renderer teardown leak diagnostics. No aggregate pass is claimed. |

The failed checks are preserved as blockers or baseline findings. They were not “fixed” by changing unrelated map, runtime, or generated documentation files.

## Acceptance disposition

**R-838 cannot promote North Quarter.** The activation guard passes only because it correctly rejects promotion and confirms that all runtime state remains consistently inactive for release. The following conditions are still required before a truthful atomic activation:

1. P0-040, P2-021, P4-019, and P4-023f must each reach an accepted closeout, not merely `in_review`.
2. R-604 must restore and verify RRMap `elevation_ramp` / `elevation_area` parsing from a clean checkout, after which R-835 must be rerun.
3. R-836's pending parity boundary must be replaced by a signed P4-023f North Quarter packet tied to the current authored and compiled revision.
4. R-837 must close its traversal/collision evidence and the aggregate transition/parser diagnostics must be understood by their owners.
5. The required map validators and clean focused Godot suites must pass without relying on dirty-worktree WIP or parser-cascade suppression.
6. Only then may the RRMap, catalog, transition release flag, and approval ledger switch together, followed by independent R-839 verification.

**Final status:** **R-838 preflight complete; North Quarter activation remains BLOCKED and all registries remain unchanged.**

## Sources

- [`../data/p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`r834_p4_020a_upstream_dependency_reconciliation.md`](r834_p4_020a_upstream_dependency_reconciliation.md)
- [`r835_p4_020b_north_quarter_elevation_parser_gate.md`](r835_p4_020b_north_quarter_elevation_parser_gate.md)
- [`r836_p4_020c_north_quarter_day_night_parity_review.md`](r836_p4_020c_north_quarter_day_night_parity_review.md)
- [`r837_p4_020d_north_quarter_traversal_collision_gate.md`](r837_p4_020d_north_quarter_traversal_collision_gate.md)
- [`../../content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`../../scripts/map/map_catalog.gd`](../../scripts/map/map_catalog.gd)
- [`../../content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`../../tools/verify_north_quarter_activation.py`](../../tools/verify_north_quarter_activation.py)
- [`../../tests/python/test_verify_north_quarter_activation.py`](../../tests/python/test_verify_north_quarter_activation.py)
- [`../../tools/verify_map_activation.py`](../../tools/verify_map_activation.py)
- [`../../tools/verify_map_conversion_plan.py`](../../tools/verify_map_conversion_plan.py)
- [`../../tools/verify_map_audit.py`](../../tools/verify_map_audit.py)
- [`../../tools/validate_map_blueprints.gd`](../../tools/validate_map_blueprints.gd)
- [`../../tools/verify_transitions.gd`](../../tools/verify_transitions.gd)

**Evidence logs:** `/tmp/rebel-reval-r838/activation.log`, `/tmp/rebel-reval-r838/activation-unit.log`, `/tmp/rebel-reval-r838/map-activation.log`, `/tmp/rebel-reval-r838/conversion-plan.log`, `/tmp/rebel-reval-r838/map-audit.log`, `/tmp/rebel-reval-r838/active-docs.log`, `/tmp/rebel-reval-r838/blueprints.log`, `/tmp/rebel-reval-r838/r838-north-quarter-prototype.log`, `/tmp/rebel-reval-r838/r838-transition-spawn-clearance.log`, `/tmp/rebel-reval-r838/r838-transition-manifest.log`.
