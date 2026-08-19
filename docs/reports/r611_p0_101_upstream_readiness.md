# R-611 P0-101 upstream readiness reconciliation

**Task:** R-611 / P0-101 decomposition: reconcile upstream readiness
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-20
**Repository snapshot:** `0c58dd56` (`main`)
**Worktree:** shared worktree contains unrelated staged, modified, and untracked WIP. This report is the only scoped artifact; no map, runtime, art, budget, threshold, fixture, or test source was changed.
**Decision:** **BLOCKED - upstream prerequisites are not resolved; downstream acceptance gates must not start from a PASS assumption.**

## Scope and decision rule

This is the verification-only preflight named by R-611. It reconciles the three parent dependencies declared by R-108 against the task board, linked reports, and focused commands. It records the exact evidence each downstream decomposition gate (R-612 through R-618) must consume. A green structural subtest or a completed implementation handoff does not promote a blocked upstream parent to PASS, and no blocked dependency is treated as complete.

R-108 / P0-101 must remain open. This report does not close R-611 as an overall acceptance PASS.

## Upstream dependency ledger

Board statuses queried on 2026-08-20:

| Parent dependency | Board ref | Status | Linked evidence | Readiness for P0-101 |
|---|---|---|---|---|
| Lower Town base layout, terrain, routes, and decomposition | R-109 / P0-100 | `in_progress` | [`p0_100_decomposition_verification.md`](p0_100_decomposition_verification.md), [`r553_lower_town_integration_verification.md`](r553_lower_town_integration_verification.md) | **BLOCKED** - R-603 records a blocked decomposition; R-553 explicitly forbids closing R-109. R-597, R-598, R-600, and R-601 are not `done`. |
| R-003 house-tier wiring on the playable route | R-213 / P2-067 | `done` | [`test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd), [`test_lower_town_slice_map.gd`](../../tests/godot/test_lower_town_slice_map.gd), [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md) | **PASS as structural prerequisite only** - tier keys and authored assignments are present and the focused tier contract is green. This does not clear parity drift, composition enforcement, runtime acceptance, or visual sign-off. |
| Conditional ordinary-house art/reference handoff | R-6 / A-009 | `in_review` | [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md) | **BLOCKED** - decision remains `CONDITIONAL ART-DIRECTION PASS; FINAL GAMEPLAY SIGN-OFF BLOCKED`. P2-063 and P2-065 are still open (`R-209`, `R-211`); only P2-064 is `done`. |

Because R-109 and R-6 are not `done`, the upstream contract is not ready for final P0-101 closeout. R-213 is complete only as tier wiring, not as a substitute for the blocked base and art gates.

## Focused reproduction record

Commands run from the project root on the shared dirty worktree. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`. Shutdown ObjectDB/resource leak diagnostics after green summaries are not treated as test failures.

### Tier wiring contract (R-213 evidence)

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_burgher_house_tiers
# Godot headless tests: 1 file(s), 5 test(s), 0 failure(s), 0 error(s).
```

### Lower Town base map contract (R-109 evidence boundary)

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
# Godot headless tests: 1 file(s), 19 test(s), 1 failure(s), 0 error(s).
```

The remaining failure is the canonical parity fixture drift already owned by R-606 and recorded by R-603/R-553. R-611 does not regenerate parity or weaken the assertion.

## Downstream gate consumption map

Each downstream decomposition task must consume the linked evidence below and must not promote a blocked upstream row to PASS.

| Downstream gate | Board ref | Status | Must consume from upstream ledger | May not assume |
|---|---|---|---|---|
| Ordinary-fabric acceptance | R-612 | `todo` | R-213 tier counts and `test_burgher_house_tiers`; R-532 / R-487 ordinary-fabric reports; R-6 conditional A-009 boundary | That R-213 closes visual repetition, wear, or roof/material acceptance; that A-009 is final sign-off |
| Exceptional landmark acceptance | R-613 | `todo` | R-533 landmark-boundary report (`done`); R-488 implementation status; R-553 blocked integration ledger | That stable IDs alone close landmark art/history acceptance |
| Playable-route integration | R-614 | `todo` | R-534 route-integration report; R-489 implementation status; R-601 runtime route evidence from R-109 | That source/contract parity equals route-scale occlusion or patrol clearance |
| Runtime and performance gates | R-615 | `todo` | R-535 runtime gate report (`done`); R-490 blocked runtime QA; R-562 clean-load gate; R-563 minimum-hardware evidence gap from R-564 | That implementation of the guard equals green clean checkout or declared-target GPU acceptance |
| Gameplay-scale day/night evidence | R-616 | `todo` | R-536 capture-packet verification (`done`); R-491 matrix and `docs/reports/images/lower_town_p0_101/capture_manifest.json`; R-560 capability handoff | That packet integrity or route reproducibility closes per-row visual review |
| Historical and art sign-off | R-617 | `todo` | R-537 verification report (`done`); R-492 silhouette review; R-6 conditional A-009 decision | That pre-read or reference plates substitute for named reviewer approval |
| Final independent acceptance | R-618 | `todo` | This report plus R-611-R-617 ledgers; R-538 / R-574 closeout boundaries | That any single green sub-gate closes R-108 while R-109 or R-6 remain open |

## Deterministic readiness decision

**R-611 result: BLOCKED.** The dependency ledger is reproducible from the board and linked reports, but the upstream contract is not resolved:

1. **R-109 / P0-100** remains `in_progress` with blocked decomposition and integration evidence.
2. **R-213 / P2-067** is `done` only for structural tier wiring; parity and parent acceptance remain red.
3. **R-6 / A-009** remains `in_review` with conditional reference-art approval only; production kit closeout for all three tiers is incomplete.

Downstream gates R-612 through R-618 must remain `todo` or record their own blocked results until the upstream rows above change on the board. Keep R-108 open.

No duplicate follow-up task is created: the owners already exist as R-109, R-213, R-6, R-487-R-492, R-532-R-537, R-560-R-564, R-606, and R-608.

## Sources

- [`p0_100_decomposition_verification.md`](p0_100_decomposition_verification.md)
- [`r553_lower_town_integration_verification.md`](r553_lower_town_integration_verification.md)
- [`r559_lower_town_dependency_handoff_readiness.md`](r559_lower_town_dependency_handoff_readiness.md)
- [`p0_101_decomposition_readiness.md`](p0_101_decomposition_readiness.md)
- [`burgher_house_art_signoff.md`](burgher_house_art_signoff.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
