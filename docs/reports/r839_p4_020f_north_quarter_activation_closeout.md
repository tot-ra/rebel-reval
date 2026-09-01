# R-839 P4-020f North Quarter activation closeout

**Task:** R-839 / P4-020f
**Parent:** R-245 / P4-020 North Quarter activation
**Verification date:** 2026-09-01
**Audited revision:** `18a4070644235b125733b193b2a42547712c6d2c` (`docs: record malformed workdir diagnostic lesson`)
**Godot:** `4.7.1.stable.official.a13da4feb`
**Verification checkout:** detached disposable checkout at `/private/tmp/rebel-reval-r839-final`; repository status was empty before and after the clean-pass command set
**Decision:** **FAIL / BLOCKED - North Quarter was not promoted and remains fail-closed**

## Scope and decision boundary

This is the independent final verification for the North Quarter activation chain. It audits the authored RRMap, compiled/catalog state, transition manifest, activation ledger, upstream dependency statuses, parser/elevation behavior, traversal and collision gates, map validators, active documentation, and available day/night evidence.

The main worktree was not used as clean evidence because it contains unrelated staged and untracked WIP. The checks below were run from the disposable clean checkout at the audited revision. No runtime code, map content, activation manifest, ledger, capture, or generated documentation was changed for this verification. The only repository deliverable from R-839 is this report.

The decision is fail-closed. A passing readiness guard means that the repository correctly refuses promotion; it does not mean that release acceptance passed.

## Dependency matrix

Board statuses and linked evidence were checked on 2026-09-01. `in_review` is not treated as done.

| Dependency | Board ref | Board status | Closeout interpretation |
|---|---|---|---|
| Art-bible and technical-freeze baseline | R-111 / P0-040 | `in_progress` | **BLOCKED** - maintainer approval is not closed |
| Converted-map visual/gameplay parity | R-214 / P2-021 | `in_review` | **BLOCKED** - review is not an accepted parity verdict |
| Central District activation prerequisite | R-254 / P4-019 | `in_review` | **BLOCKED** - prerequisite and its fail-closed ledger remain open |
| North Quarter environment acceptance | R-280 / P4-023f | `in_review` | **BLOCKED** - signed historical/art review and accepted day/night/gameplay packet remain unresolved |
| North Quarter elevation parser gate | R-835 | `in_review` | **BLOCKED** - clean HEAD rejects `elevation_ramp` / `elevation_area`; parser ownership remains with R-604 |
| North Quarter day/night parity review | R-836 | `done` | **BLOCKED for activation** - its committed decision remains `PENDING / BLOCKED`; R-785 plates are not a signed P4-023f packet tied to this revision |
| North Quarter traversal/collision gate | R-837 | `in_progress` | **BLOCKED** - the parent gate remains open and prior scoped evidence is not activation approval |
| Controlled activation preflight | R-838 | `in_progress` | **BLOCKED** - no controlled promotion was authorized |

R-834 is complete as dependency reconciliation, but it confirms that the four ledger blockers remain unresolved. R-604 is already the owner of the elevation parser boundary; no duplicate remediation task is created here.

## Activation-state matrix

The clean checkout remains internally consistent and fail-closed:

| Registry | Observed state | Required blocked-state interpretation | Result |
|---|---|---|---|
| `content/maps/north_quarter.rrmap` | `scope=prototype active=false` | Prototype and inactive | **PASS** |
| `scripts/map/map_catalog.gd` / `reval_north` | `scope=prototype`, `active=false` | Not a production scene | **PASS** |
| `content/transitions/active_destinations.json` / `reval_north` | `active=true`, `release=false` | Developer traversal only; release disabled | **PASS** |
| `docs/data/p4_020_north_quarter_activation.json` | `decision=blocked`; blockers `P0-040`, `P2-021`, `P4-019`, `P4-023f` | All named activation blockers preserved | **PASS** |
| `parity_review` | `status=pending`; `day_capture=null`; `night_capture=null` | No unaccepted evidence promoted | **PASS** |

No production registry is active and no partial activation was detected. The activation-state passes are safety checks, not release approval.

## Verification matrix

All results below are from the clean detached checkout at the audited revision. Exit status is included for every command.

| Check | Exit | Result | Clean evidence and interpretation |
|---|---:|---|---|
| North Quarter activation guard | 0 | **PASS, fail-closed** | `P4-020 North Quarter activation readiness guard passed.` The guard confirms the blocked ledger and rejects production promotion. |
| Activation-ledger Python suite | 0 | **PASS** | `4 tests, OK`; all blocked-state, partial-activation, approval/parity, and repository-consistency assertions passed. |
| Map blueprint validator | 1 | **BLOCKED** | `validate_map_blueprints.gd` reports `unknown command 'elevation_ramp'` / `unknown command 'elevation_area'` in North Quarter and other elevation-authored maps, followed by `MAP_REGISTRY_FACTORY_INVALID`. |
| Focused Godot matrix | 1 | **BLOCKED** | `5 file(s), 55 test(s), 107 failure(s), 338 error(s)`. The parser and transition-manifest files contain passing assertions, but authored-map loading is interrupted by the elevation parser errors; North Quarter and spawn-clearance failures include dependent invalid-definition, missing-transition, `spawn_offset`, and route/property diagnostics. |
| Aggregate transition verifier | 1 | **BLOCKED** | `P0-022 transition verification failed: 48 error(s)`. The clean run reports missing registered spawn IDs, including North Quarter `from_monastery`, `from_monastery_outer`, `to_reval_harbor`, `outer_harbor_exit`, and `merchant_wall_tower_northwest_return`, plus renderer teardown diagnostics. |
| Map audit validator | 1 | **BLOCKED by repository baseline** | Reports missing scene coverage, target mismatch for `scenes/world_travel/world_padise.tscn`, missing strict TODO rows, missing audit entries for `nunnatorn_interior.tscn` and prototype definition packages, and the P2-012/P2-021 dependency mismatch. |
| Generic map activation guard | 0 | **PASS** | `Map activation guard passed.` This validates the inactive/blocked state; it does not authorize promotion. |
| Map conversion-plan validator | 1 | **BLOCKED by repository baseline** | Reports missing scene coverage including `scenes/reval_north/rentenitorn_interior.tscn`, unrelated character/debug/benchmark scenes, target mismatch, missing strict TODO rows, and the P2-012/P2-021 dependency mismatch. |
| Active Markdown report check | 1 | **BLOCKED by repository baseline** | `active_markdown_report.md is not up to date`. No generated report was regenerated in this verification-only task. |
| `git diff --check` | 0 | **PASS** | No whitespace errors in the clean verification checkout. |

The primary authored-map blocker is the unsupported `elevation_ramp` / `elevation_area` parser boundary owned by R-604. Subsequent invalid `MapDefinition`, missing transition, spawn, route, and view-property diagnostics are recorded as parser-cascade effects unless independently established otherwise. The map-audit, conversion-plan, and active-doc failures are preserved as repository baseline findings and were not waived.

## Visual day/night evidence review

Available image files were checked in the clean checkout for existence, decode, dimensions, non-blank payload, and SHA-256. They are not accepted promotion evidence because the activation ledger has no accepted captures and the required signed P4-023f packet is absent.

| Pair | Dimensions | Stable scope and disposition |
|---|---|---|
| `north_quarter_merchant_wall_tower_northwest_day.png` / `_night.png` | `RGBA 1280x720` | Manifest-backed R-785 / P4-027d tower approach pair; valid and distinct, but isolated tower coverage and not a signed P4-023f packet |
| `north_quarter_merchant_wall_tower_northwest_door_day.png` / `_night.png` | `RGBA 1280x720` | Manifest-backed R-785 / P4-027d door/return pair; valid and distinct, but not district-wide acceptance evidence |
| `reval_harbor_north_player_eye_day.png` / `_night.png` | `RGB 1600x900` | Supplementary `reval_harbor_north` pair without an acceptance manifest; wrong map scope for North Quarter promotion |
| `reval_harbor_north_top_down_day.png` / `_night.png` | `RGB 1600x900` | Supplementary/debug-scale pair without an acceptance manifest; not a gameplay-scale North Quarter acceptance substitute |

The R-785 manifest identifies task `R-785 / P4-027d`, renderer `gl_compatibility`, OpenGL 3 driver `opengl3`, viewport `1280x720`, orthographic size `33.75`, pitch `-30`, yaw `45`, and distance `90`. Its North Quarter entry remains `active=false` and carries fingerprint `da6bfe9e553638388fd0bc578eca68f236574ad91528f1cf68602f942174211f`. It does not provide P4-023f sign-off or current-revision acceptance.

The required replacement is one signed P4-023f packet tied to the current authored and compiled revision, covering Coastal Gate, harbourward relief/runoff, Pikk and district routes, merchant court/material variety, population/activity, reciprocal seams, gameplay interactions, and named historical/art review. Until then, `parity_review` must remain pending.

## Acceptance disposition

**R-839 FAIL/BLOCKED. North Quarter activation is not release-consistent and must not be promoted.** The repository passes the safety boundary only because activation remains correctly disabled. Release acceptance is blocked by all of the following:

1. Named activation dependencies P0-040, P2-021, P4-019, and P4-023f are not all done.
2. R-604's elevation parser support is not present on clean HEAD, so R-835 cannot close its clean parser gate.
3. The focused Godot matrix and aggregate transition verifier do not complete cleanly.
4. Map audit, conversion-plan, and active-doc checks fail on existing repository coverage/baseline drift.
5. No signed, current-revision P4-023f day/night and gameplay acceptance packet is linked to the ledger.

Keep R-245/P4-020, R-838/P4-020e, and R-837/P4-020d open. Do not change `content/maps/north_quarter.rrmap`, `scripts/map/map_catalog.gd`, `content/transitions/active_destinations.json`, `docs/data/p4_020_north_quarter_activation.json`, or any evidence files as a result of this report. R-604, R-835, and R-280 remain with their existing owners; no duplicate remediation task is created.

## Exact verification commands

These are the exact commands required by R-839 and executed from the disposable clean checkout:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot

python3 tools/verify_north_quarter_activation.py
python3 -m unittest tests.python.test_verify_north_quarter_activation -v
godot --headless --path . --script tools/validate_map_blueprints.gd

tools/run_godot_checked.sh --require-test-summary p4-020-final -- "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_rrmap_parser,test_north_quarter_prototype_map,test_market_prototype_maps,test_transition_spawn_clearance,test_transition_manifest

godot --headless --path . --script tools/verify_transitions.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

The clean-pass logs are retained outside the repository at `/private/tmp/rebel-reval-r839-final-logs/`:

- `activation-clean-pass.log` - exit 0
- `activation-unit-clean-pass.log` - exit 0
- `blueprints-clean-pass.log` - exit 1
- `focused-clean-pass.log` - exit 1
- `transitions-clean-pass.log` - exit 1
- `map-audit-clean-pass.log` - exit 1
- `map-activation-clean-pass.log` - exit 0
- `conversion-plan-clean-pass.log` - exit 1
- `active-docs-clean-pass.log` - exit 1
- `diff-check-clean-pass.log` - exit 0

## Sources

- [`../data/p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`../adr/0008-three-act-campaign-and-faction-scope.md`](../adr/0008-three-act-campaign-and-faction-scope.md)
- [`r834_p4_020a_upstream_dependency_reconciliation.md`](r834_p4_020a_upstream_dependency_reconciliation.md)
- [`r835_p4_020b_north_quarter_elevation_parser_gate.md`](r835_p4_020b_north_quarter_elevation_parser_gate.md)
- [`r836_p4_020c_north_quarter_day_night_parity_review.md`](r836_p4_020c_north_quarter_day_night_parity_review.md)
- [`r837_p4_020d_north_quarter_traversal_collision_gate.md`](r837_p4_020d_north_quarter_traversal_collision_gate.md)
- [`r838_p4_020e_north_quarter_activation_preflight.md`](r838_p4_020e_north_quarter_activation_preflight.md)
- [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md)
- [`images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)
- [`images/rentenitorn/`](images/rentenitorn/)
- [`images/elevation/`](images/elevation/)
- [`../../content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`../../scripts/map/map_catalog.gd`](../../scripts/map/map_catalog.gd)
- [`../../content/transitions/active_destinations.json`](../../content/transitions/active_destinations.json)
- [`../../tools/verify_north_quarter_activation.py`](../../tools/verify_north_quarter_activation.py)
- [`../../tests/python/test_verify_north_quarter_activation.py`](../../tests/python/test_verify_north_quarter_activation.py)
- [`../../tools/validate_map_blueprints.gd`](../../tools/validate_map_blueprints.gd)
- [`../../tools/verify_transitions.gd`](../../tools/verify_transitions.gd)
- [`../../tools/verify_map_audit.py`](../../tools/verify_map_audit.py)
- [`../../tools/verify_map_activation.py`](../../tools/verify_map_activation.py)
- [`../../tools/verify_map_conversion_plan.py`](../../tools/verify_map_conversion_plan.py)
- [`../../tools/generate_active_docs_report.py`](../../tools/generate_active_docs_report.py)

**Final status:** **R-839 verification complete; North Quarter activation remains FAIL/BLOCKED and all production registries remain unchanged.**
