# P0-100 decomposition verification

**Task:** R-603 / P0-100 decomposition and review readiness
**Parent:** R-109 / P0-100
**Verification date:** 2026-08-19
**Repository snapshot:** `2f9aa13b` (`Capture Lower Town matched day/night evidence`)
**Worktree:** shared worktree contains unrelated staged, modified, deleted, and untracked WIP. This task changed only this report; no map, runtime, test, threshold, fixture, asset, or generated evidence file was changed.
**Decision:** **BLOCKED**

## Scope and decision rule

This is the evidence-only completion check for the low-complexity P0-100 decomposition. It reconciles R-109 against the eight listed dependencies, their board status, their reports, and focused commands. A green structural subtest does not close the parent when a required gate is red, a dependency is not `done`, or visual evidence is only packet integrity. No acceptance threshold is weakened, no parity/chunk fixture is regenerated, and no parent status is changed.

R-109 must remain open. It must not be described as complete or promoted to review-ready from this report.

## Dependency and board status snapshot

Statuses queried on 2026-08-19:

| Dependency | Board status | Evidence and effect on R-109 |
|---|---|---|
| R-596 ownership contract | `done` | `docs/data/lower_town_authoring_contract.json` and the focused authoring contract are present. This closes only the ownership-contract handoff; it does not clear later map/parity/runtime gates. |
| R-597 frontage rhythm and tiers | `in_review` | Its report records the source frontage report and authoring checks as green, but the map suite has parity drift owned by the later fixture reconciliation boundary. Not a completed dependency. |
| R-598 surfaces/elevation | `in_review` | `r598_lower_town_surface_elevation_verification.md` records elevation access as passing but surface acceptance as blocked/advisory at its verification snapshot, with R-607 and parity work still open. Not a completed dependency. |
| R-599 service yards/drainage | `done` | `test_lower_town_service_yards` passed 3/3 in its completion evidence. This closes the focused service-yard handoff only. |
| R-600 composition gate | `in_review` | Enforcement implementation is present, but its acceptance inputs are red: current Lower Town density/style/empty-region violations and an unrelated enforced monastery violation. Not a completed dependency. |
| R-601 routes/collision/transitions/streaming | `in_progress` | Current runtime and chunk checks still fail. This is an explicit open prerequisite. |
| R-602 matched day/night evidence | `done` | The packet is valid: five matched pairs, ten decoded 1280x720 PNGs, and capture contract 5/5. Its report explicitly keeps visual acceptance conditional because R-601 and surface/art review remain open. Packet integrity is not parent acceptance. |
| R-553 final integration closeout | `in_progress` | Its report decision is `BLOCKED`; it explicitly prohibits closing R-109/P0-100. |

Because R-597, R-598, R-600, R-601, and R-553 are not `done`, the decomposition cannot be `READY FOR REVIEW`.

## Verification matrix

| R-109 requirement | Result | Evidence, reproduction, and blocker |
|---|---|---|
| Historically grounded layout, authored sectors, and intentional open space | **BLOCKED** | The source contract defines `market_reserve`, `merchant_frontage_strip`, `craft_strip`, `craft_backlots`, `service_yards`, `institutional_landmark_edge`, and `transition_edges`, plus explicit open regions with exclusion reasons. The current authoring contract filter passed 2/2. However, R-548 is not a listed completed handoff in this decomposition, R-553 records an earlier unresolved-reference blocker, and the enforced empty-region metric is still red. Structural ownership is present but final parent acceptance is not established. |
| Dense property footprints, 7-11 m frontage rhythm, and all three tiers | **BLOCKED** | The contract records default frontage `7..11 m`, median `9`, and named artisan/institutional/edge/harbourward exceptions. R-597 reports its deterministic width and tier checks as green at its snapshot. The current `test_lower_town_slice_map` suite is 19 tests with one parity failure, and no report upgrades source records into gameplay-scale visual acceptance. R-602's capture matrix leaves tier coexistence and repeated-frontage readability pending. |
| Service yards, rear workshops, drainage, and non-blocking dressing | **PASS for scoped handoff; BLOCKED for parent** | R-599 completion evidence reports `test_lower_town_service_yards`: 1 file, 3 tests, 0 failures, 0 errors. The current authoring contract includes `brewery_rear_store`, `smithy_rear_shed`, `carriers_barn`, yard props, and wet/mud/grime decals. The parent remains blocked by independent parity, chunk, route, and composition gates. |
| Surface shares, cobblestone cap, and accessible elevation | **BLOCKED** | R-607 reports the post-change surface substrate as within bands: stone `26.6815536608472%`, earth `45.8722425226688%`, grass `27.446203816484%`, cobblestone `4.52023277845446%`; elevation range remains `1.48229014535609`. The same report records built density `21.9622960342187%`, max style share `47.5409836065574%`, and largest empty region `14778`, which remain outside R-600 limits. The current enforced composition audit reproduces these three Lower Town violations. |
| Enforced composition audit and required landmark ownership | **BLOCKED** | `docs/data/map_composition_thresholds.json` and `content/map_audit_manifest.json` explicitly enforce Lower Town, link the ownership contract, preserve H04-H05/H09-H10 refs, and require `st_catherines_church`. Python schema tests pass 5/5. The executable audit fails with `MAP_COMPOSITION_DENSITY`, `MAP_COMPOSITION_REPEATED_STYLE`, and `MAP_COMPOSITION_EMPTY_REGION` for `lower_town_slice`; it also reports the separate enforced `monastery_quarter` empty-region baseline. Godot composition tests fail 2/10 for the same four violations. |
| Smithy, brewery, cistern/checkpoints, quest anchors, and patrol routes | **BLOCKED** | Authoring contract resolution passes 2/2 and `test_transition_manifest` passes 3/3. The current runtime acceptance filter reaches 4 tests but has two failures: `iron_convoy` patrol points at cells `(24, 28)` and `(24, 42)` are blocked. Therefore route/patrol acceptance is not green even though stable anchors and transition manifest checks pass. |
| Collision, navigation, conversion parity, and chunk streaming | **BLOCKED** | `test_lower_town_slice_map` is 19 tests with 1 failure in canonical parity; current gameplay `walkability_sha256` is `0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944`, while the fixture expects `57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f`. `verify_map_conversion_parity.py` records Lower Town anchor accounting 11/11 and Kalev Smithy 3/3, but exits 1 because the Lower Town filter fails. `test_map_object_chunk_streaming` is 7 tests with 1 failure: the reviewed fixture omits current production records including `coopers_rear_workshop`, `rope_makers_rear_store`, and `smithy_rear_shed`, and ordering differs. Existing owners R-606/R-608 cover these fixture reconciliations; R-603 does not regenerate them. |
| Matched day/night gameplay readability and interaction visibility | **BLOCKED for acceptance; PASS for packet integrity only** | R-602's packet has five presets, five day/night pairs, ten RGBA 1280x720 non-blank PNGs, and `test_capture_lower_town_p0_101` 5/5. Its report explicitly marks player/entrance readability conditional because R-601 remains open, and leaves tier/material/roof/wear/landmark visual review pending. Valid images cannot substitute for route acceptance, gameplay traversal, or human canon/art sign-off. |

## Exact reproduction commands and outputs

All commands were run from the project root on the shared dirty worktree. Godot was `/Applications/Godot.app/Contents/MacOS/Godot`. The known shutdown ObjectDB/resource leak messages are not used to waive test failures.

### Evidence guard and Python contracts

```text
python3 tools/verify_r553_lower_town_closeout.py
# exit 0
# R-553 Lower Town closeout verification passed

python3 -m unittest tests.python.test_verify_map_composition -v
# exit 0
# Ran 5 tests in 0.003s - OK

python3 tools/verify_map_composition.py
# exit 1
# 4 errors:
# lower_town_slice: density 21.9622960342187 outside 45.0-60.0
# lower_town_slice: repeated style 47.5409836065574 above 35.0
# lower_town_slice: largest empty region 14778 above 1200
# monastery_quarter: largest empty region 25774 above 22000

python3 tools/verify_map_conversion_parity.py
# exit 1
# lower_town_slice: anchor accounting 11/11
# kalev_smithy: anchor accounting 3/3
# Godot filter failed: test_lower_town_slice_map
```

The existing R-553 unit-test guard has one independent regression in the current checkout:

```text
python3 -m unittest tests.python.test_verify_r553_lower_town_closeout -v
# exit 1; 6 tests, 1 failure
# test_advisory_composition_rejects_false_pass_decision failed because its seeded
# advisory-card mutation no longer reaches the validator's advisory branch after
# the repository card became enforced. The repository report itself still passes
# verify_r553_lower_town_closeout.py.
```

This is a test/guard maintenance issue, not evidence that R-109 passes. It is recorded for a follow-up rather than changed in this evidence-only task.

### Focused Godot checks

```text
GODOT_LOG_DIR=/tmp/r603-authoring tools/run_godot_checked.sh --require-test-summary r603-authoring -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_authoring_contract
# exit 0; 1 file, 2 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r603-composition-godot tools/run_godot_checked.sh --require-test-summary r603-composition-godot -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_composition_audit
# exit 1; 1 file, 10 tests, 2 failures, 0 errors
# Lower Town: density/style/empty-region violations
# monastery_quarter: empty-region violation

GODOT_LOG_DIR=/tmp/r603-map tools/run_godot_checked.sh --require-test-summary r603-map -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
# exit 1; 1 file, 19 tests, 1 failure, 0 errors
# failure: canonical parity walkability_sha256 differs from fixture

GODOT_LOG_DIR=/tmp/r603-chunk tools/run_godot_checked.sh --require-test-summary r603-chunk -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_map_object_chunk_streaming
# exit 1; 1 file, 7 tests, 1 failure, 0 errors
# failure: reviewed Lower Town boundary inventory differs; current rear-service
# records include cooper/rope/smithy rear buildings absent from the fixture

GODOT_LOG_DIR=/tmp/r603-runtime tools/run_godot_checked.sh --require-test-summary r603-runtime -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_r552_lower_town_runtime_acceptance
# exit 1; 1 file, 4 tests, 2 failures, 0 errors
# failures: iron_convoy point 1 at (24,28) blocked; point 2 at (24,42) blocked

GODOT_LOG_DIR=/tmp/r603-transition tools/run_godot_checked.sh --require-test-summary r603-transition -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_transition_manifest
# exit 0; 1 file, 3 tests, 0 failures, 0 errors

GODOT_LOG_DIR=/tmp/r603-capture tools/run_godot_checked.sh --require-test-summary r603-capture -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_capture_lower_town_p0_101
# exit 0; 1 file, 5 tests, 0 failures, 0 errors
```

## Remaining blockers and ownership

No duplicate implementation task is created for the existing map/runtime blockers:

- **R-600/R-607:** Lower Town composition density, repeated-style, empty-region, and explicit threshold reconciliation.
- **R-606:** canonical Lower Town parity fixture after reviewed semantic map changes.
- **R-608:** reviewed object-chunk readiness fixture after R-547 rear/service layout additions.
- **R-601:** route/collision/patrol/transition/streaming acceptance, including the two blocked `iron_convoy` cells.
- **R-553:** final integration closeout remains open and already records the parent-level blocked decision.
- **R-602/R-551 and downstream art/canon owners:** packet is valid but visual readability and human review remain conditional.

The stale `test_verify_r553_lower_town_closeout.py` seeded regression has no clearly assigned owner in the R-603 dependency set. A small QA follow-up should update that test to seed an advisory threshold fixture instead of mutating the now-enforced repository card, without weakening the enforced-card validation.

## Final decision

**BLOCKED.** The P0-100 decomposition is substantially documented and several focused contracts pass, but it is not complete and R-109 is not ready for review. Open dependency statuses, red composition/parity/chunk/runtime gates, and conditional visual evidence are sufficient blockers. Do not close R-603 as a parent acceptance, do not promote R-109, and do not treat the valid R-602 PNG packet or green structural subtests as a full Lower Town pass.

## Sources

- [`R-109 P0-100 task contract`](../../TODO.md)
- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`Map audit manifest`](../../content/map_audit_manifest.json)
- [`R-553 integration verification`](r553_lower_town_integration_verification.md)
- [`R-598 surface/elevation verification`](r598_lower_town_surface_elevation_verification.md)
- [`R-602 matched capture evidence`](r602_lower_town_matched_capture_evidence.md)
- [`R-607 surface reconciliation`](r607_lower_town_surface_reconciliation.md)
- [`R-597 frontage and tier handoff`](../../TODO.md)
- [`R-599 service-yard handoff`](../../TODO.md)
- [`R-600 composition enforcement task evidence`](../../TODO.md)
- [`R-601 route/runtime task contract`](../../TODO.md)
- [`R-608 chunk-readiness task contract`](../../TODO.md)
- [`tools/verify_r553_lower_town_closeout.py`](../../tools/verify_r553_lower_town_closeout.py)
- [`tools/verify_map_composition.py`](../../tools/verify_map_composition.py)
- [`tools/verify_map_conversion_parity.py`](../../tools/verify_map_conversion_parity.py)
- [`tests/godot/test_lower_town_authoring_contract.gd`](../../tests/godot/test_lower_town_authoring_contract.gd)
- [`tests/godot/test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd)
- [`tests/godot/test_map_composition_audit.gd`](../../tests/godot/test_map_composition_audit.gd)
- [`tests/godot/test_map_object_chunk_streaming.gd`](../../tests/godot/test_map_object_chunk_streaming.gd)
- [`tests/godot/test_r552_lower_town_runtime_acceptance.gd`](../../tests/godot/test_r552_lower_town_runtime_acceptance.gd)
- [`tests/godot/test_transition_manifest.gd`](../../tests/godot/test_transition_manifest.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`tests/python/test_verify_r553_lower_town_closeout.py`](../../tests/python/test_verify_r553_lower_town_closeout.py)
