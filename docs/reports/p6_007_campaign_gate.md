# P6-007 full-campaign authorial gate

**Status:** **BLOCKED - evidence ledger only; campaign acceptance is not signed**
**Task:** R-317 / P6-007
**Date:** 2026-08-25
**Environment:** macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)
**Authority:** [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md)

This report records the current maintainer-gate evidence without promoting incomplete Act 3 work to acceptance. ADR 0014 replaces external player quotas with maintainer playable review plus automated branch traversal and save fixtures. No external playtest quota is used here.

## Gate result

The full-campaign gate cannot pass on the current repository state. Act 1 and the authored Act 2 package corpus have green focused runtime evidence, but the cross-act campaign suite and Act 3 acceptance corpus are not complete.

| Gate area | Result | Evidence / blocker |
|---|---|---|
| Act 1 traversal and invalid-transition rejection | **PASS** | `report_act1_traversal.py --check`; Godot `test_act1_traversal`: 8/8 |
| Act 1 save fixtures | **PASS** | Act 1 Godot traversal suite loads and round-trips all three `seal`, `break`, and `open` boundary fixtures |
| Authored Act 2 package traversal | **PASS for authored corpus** | `report_act2_gate.py --check`: 10 packages, 20 branches, 10 combat + 10 non-combat routes, 906/1200 words |
| Authored Act 2 save fixtures | **PASS for authored corpus** | Godot `test_act2_gate_fixtures`: 1/1; 20 fixture rows hydrate and preserve branch identity |
| Act 2 mission host | **PASS for authored corpus** | Godot `test_act2_mission_host`: 4/4 |
| Act 2 -> Act 3 handoff | **BLOCKED** | P5-009 / R-311 is still `todo`; the Paide finale and branch-dependent Act 3 transition records are absent. See [`p5_010_act2_gate.md`](p5_010_act2_gate.md). |
| Full-campaign traversal and save compatibility | **BLOCKED** | P6-006 / R-315 is still `in_progress`; `content/saves/campaign_fixtures_manifest.json` contains prologue and Act 1 rows only, explicitly deferring Act 2/Act 3 campaign rows until authored fixtures land. |
| Act 3 playable review | **BLOCKED** | No complete Act 3 runtime campaign, traversal corpus, or published Act 3 save fixtures exists. P6-001/P6-002/P6-004/P6-005 remain upstream Act 3 work. |
| Maintainer playable review of every act | **BLOCKED** | Act 1 acceptance exists in earlier gate reports, but this full-campaign review cannot be signed while Act 2's Paide handoff and Act 3 are incomplete. |

## Verification run

Commands were run against the live checkout on 2026-08-25:

```text
python3 tools/report_act1_traversal.py --check
PASS - manifest matches authored traversal model; 3 intended endings, 5 invalid transitions, 6 cycle filters

python3 tools/report_act2_gate.py --check
PASS - authored package/fixture contract; 10 packages, 20 branches, 20 fixtures, 906/1200 words
WARN - P5-009 is not complete; Paide and branch-dependent Act 3 transition records are required
WARN - maintainer review remains pending until P5-009 completes

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act1_traversal
PASS - 1 file, 8 tests, 0 failures, 0 errors

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_gate_fixtures
PASS - 1 file, 1 test, 0 failures, 0 errors

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_mission_host
PASS - 1 file, 4 tests, 0 failures, 0 errors

python3 -m unittest tests.python.test_campaign_save_fixtures -v
FAIL - 3 tests run, 1 failure
```

The failing Python check is an owner handoff to P6-006, not a justification for waiving the gate. `save.game_state_v1_legacy` is declared in the manifest with `source_game_state_version: 1` and is intentionally a migration input, but `tests/python/test_campaign_save_fixtures.py` currently asserts the raw JSON state version equals the current version 2. The test must exercise `SaveEnvelope` migration or distinguish raw migration inputs from current envelopes before P6-006 can be green. The file is currently untracked in this shared checkout and is not changed by this report.

## Severity-ranked findings

| ID | Severity | Status | Scope / owner |
|---|---|---|---|
| P6-007-F01 | **high** | **open** | P5-009 / R-311 has not authored the Paide finale or validated Act 3 transition records. This prevents the Act 2 -> Act 3 handoff and full-campaign review. |
| P6-007-F02 | **high** | **open** | P6-006 / R-315 is not complete: the full-campaign traversal/save suite is absent, and its Python fixture contract currently fails on the intentional legacy migration input. |
| DEF-001 | **high** | **retained baseline** | `docs/reports/known_runtime_defects.md` records the Godot `--check-only` hang. The documented playable-room smoke workaround does not replace the required full-campaign acceptance evidence. No new runtime defect was introduced by this report. |
| P6-007-F03 | **medium** | **open** | No Act 3 runtime campaign and no Act 3 save-fixture corpus are present, so Act 3 completion, continuity, input, and ending-family review cannot be performed. Owners are the P6 implementation rows. |

No critical finding was observed during the focused runs above. The retained high findings and incomplete dependencies are sufficient to keep this gate **BLOCKED**. No finding is silently waived.

## Required closeout sequence

1. Complete P5-009 / R-311 with the attested Four Kings outcome in every branch and validated Act 3 opening state.
2. Complete P6-006 / R-315 with the full campaign traversal model, Act 2/Act 3 save fixtures, and a migration-aware fixture test. The campaign manifest must then contain the authored cross-act rows rather than only the current Act 1 corpus.
3. Run the full campaign traversal and save compatibility suite on a clean imported checkout, including all Act 1, Act 2, and Act 3 branches and invalid-transition cases.
4. Complete a maintainer playable review of every act covering completion, comprehension, pacing, combat/non-combat readability, choice impact, continuity, and supported input.
5. Re-triage all critical/high findings from the review and CI, then replace this ledger's verdict with a signed **PASS** only when none remain open.

## Maintainer sign-off

| Reviewer | Date | Decision |
|---|---|---|
| maintainer | 2026-08-25 | **Not signed - full-campaign gate remains blocked by P5-009, P6-006, missing Act 3 corpus, and retained DEF-001.** |

**Final decision:** **BLOCKED. Keep R-317 / P6-007 open.** This report is the scoped evidence artifact and handoff, not an acceptance waiver.
