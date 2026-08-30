# P5-010 Act 2 authorial gate

**Status:** **BLOCKED - automated authored-corpus checks pass; maintainer playable review is recorded but not signed off**
**Task:** R-309 / P5-010
**Date:** 2026-08-30
**Environment:** macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)
**Authority:** [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md)
**Manifest:** [`docs/data/act2_gate_manifest.json`](../data/act2_gate_manifest.json)

This report records the remaining P5-010 acceptance review. The automated authored-corpus contract is green, but the full playable gate cannot pass while four authored night routes remain content-only and the boundary-family review lacks runtime evidence. No failed automation is waived, and this report does not promote R-309 to done.

## Scope and review method

1. Reviewed all ten Act 2 package records, their branch maps, objectives, outcomes, content links, and source/approval notes.
2. Reviewed the six production siege offers in `scripts/quest/act2_mission_host.gd` and the dedicated Paide transition model.
3. Ran the authored package, fixture, mission-host, and Paide Godot suites on the live checkout.
4. Compared the available evidence against the ADR 0014 playable-review areas: completion, comprehension, pacing, combat/non-combat readability, choice impact, continuity, and supported input.
5. Kept the gate blocked where repository evidence proves authored data but not an interactive route. The content-only packages are not treated as playable evidence.

## Verdict

**BLOCKED.** The authored package and save-fixture contracts pass, and the six siege mission host routes plus Paide transition model pass their focused suites. The four night missions cannot yet receive a genuine playable review: each package explicitly declares `approval.status: draft` and `notes: Content-only ...; runtime mission host remains downstream work.` The production host catalog contains only the six investment, sortie/supply, and assault missions.

The review therefore records completion of the available evidence and withholds maintainer sign-off. Existing `P5-012` owns the remaining Act 2 end-to-end traversal and save-compatibility coverage; it must not be considered complete until it exercises the night routes and Paide handoff in a playable campaign path.

## Gate area

| Gate area | Result | Evidence / limitation |
|---|---|---|
| Branch traversal | **PASS for authored corpus** | Ten packages, two branches each; Python manifest check and ten generated Godot suites pass, 20/20 branch paths total |
| Save fixtures | **PASS for authored corpus** | 20 current-schema Act 2 envelopes load through `SaveEnvelope` and preserve phase, quest, flags, and ledger identity |
| Content budget | **PASS** | 906 / 1200 words for titles, summaries, state labels, objectives, and outcome summaries |
| Siege mission host | **PASS for six authored siege routes** | `test_act2_mission_host`: 4/4; investment, sortie/supply, and assault expose rebel/ruler offers and direct outcomes round-trip through save/load |
| Paide handoff model | **PASS for transition contract** | `test_paide_finale`: 4/4; all three player roles, knowledge/warning states, immutable Four Kings outcome, and Act 3 opening records validate |
| Night mission playable review | **BLOCKED** | Defense, escort, sabotage, and theft packages are content-only drafts; no runtime mission host or interactive input path is available for these four routes |
| Act 1 boundary-family coverage | **INCOMPLETE** | The host test fixture seeds only `flag.act_boundary.viru_open`; `flag.act_boundary.viru_seal` / `flag.act_boundary.viru_break` offer and traversal evidence is not covered by the focused Act 2 host suite |
| Maintainer playable review | **NOT SIGNED** | Completion, pacing, combat/non-combat readability, choice impact, and supported input cannot be confirmed for the four non-runtime night routes |
| Full Act 2 gate | **BLOCKED** | ADR 0014 requires the automated rows plus maintainer sign-off; the open high findings below remain |

## Maintainer playable review

| Area | Finding | Severity | Status |
|---|---|---:|---|
| Completion | Six siege offers can be started and resolved through the host. The four night packages have authored branch graphs but no playable runtime route, so complete Act 2 traversal is not demonstrated. | **high** | open |
| Comprehension | Titles, summaries, objectives, state labels, and outcome summaries clearly distinguish the ten authored missions and their direct/quiet or combat/non-combat intent. Interactive presentation, feedback, and route readability are not available for the four night packages. | **high** | open |
| Pacing | The package corpus defines compact two-objective missions, but no playable timing or sequencing evidence exists for the four night routes. | **high** | open |
| Combat / non-combat readability | The authored branch maps distinguish `combat` and `non_combat` for all 20 branches. Runtime combat, stealth, diversion, and failure feedback are evidenced only for the six siege host routes, not the four night templates. | **high** | open |
| Choice impact | Each package writes distinct terminal state, flags, and ledger event identities; this is verified statically and by generated traversal. The player-facing consequence presentation for night routes remains unreviewed. | **medium** | open |
| Continuity | All 20 published Act 2 fixtures preserve authored branch identity; six siege host outcomes and the Paide transition model round-trip through `GameState`. End-to-end night-to-Paide campaign continuity remains unverified. | **high** | open |
| Supported input | No input path can be reviewed for the four content-only night routes. The focused host suite verifies model transitions, not keyboard/mouse/gamepad completion. | **high** | open |

No critical finding was observed in the focused automated runs. The high findings above are retained and are sufficient to keep this gate blocked. No finding is silently waived.

## Severity-ranked findings

| ID | Severity | Status | Owner / evidence |
|---|---|---|---|
| P5-010-F01 | **high** | **open** | Four night packages (`act2_night_defense`, `act2_night_escort`, `act2_night_sabotage`, `act2_night_theft`) explicitly remain content-only drafts in their `content/quest.json` approval notes. Add runtime mission presentation, traversal, combat/non-combat feedback, and input coverage before playable review. Follow-up is part of P5-012's Act 2 end-to-end scope. |
| P5-010-F02 | **high** | **open** | Because F01 is open, completion, pacing, combat/non-combat readability, continuity, and supported input cannot be signed for the full Act 2 route set. Re-run this review after the four night routes are playable; do not waive the missing evidence. |
| P5-010-F03 | **medium** | **open** | `tests/godot/test_act2_mission_host.gd` seeds only `flag.act_boundary.viru_open`. Add seal and break boundary-family offer/traversal cases to the Act 2 end-to-end matrix before final sign-off. |

## Automated verification

Commands run successfully on 2026-08-30:

```text
python3 tools/report_act2_gate.py --check
PASS - authored packages: 10; reachable branches: 20; route coverage: combat 10, non_combat 10; save fixtures: 20; mission copy: 906/1200 words
WARN - maintainer playable review remains pending

python3 -m unittest tests.python.test_act2_gate -v
PASS - 4 tests, 0 failures

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_gate_fixtures
PASS - 1 file, 1 test, 0 failures, 0 errors

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_mission_host
PASS - 1 file, 4 tests, 0 failures, 0 errors

/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_paide_finale
PASS - 1 file, 4 tests, 0 failures, 0 errors
```

Generated package suites also passed independently, 2/2 each and 20/20 total:

| Package group | Suite result |
|---|---:|
| `act2_night_defense` | 2/2 |
| `act2_night_escort` | 2/2 |
| `act2_night_sabotage` | 2/2 |
| `act2_night_theft` | 2/2 |
| `act2_siege_assault_rebel` | 2/2 |
| `act2_siege_assault_ruler` | 2/2 |
| `act2_siege_investment_rebel` | 2/2 |
| `act2_siege_investment_ruler` | 2/2 |
| `act2_siege_sortie_rebel` | 2/2 |
| `act2_siege_sortie_ruler` | 2/2 |

The generated suites and Python verifier prove authored graph integrity. They do not replace the missing runtime review for the content-only night routes.

## Maintainer sign-off

| Reviewer | Date | Decision |
|---|---|---|
| maintainer | 2026-08-30 | **Not signed - P5-010-F01 and P5-010-F02 remain open; P5-010-F03 also requires boundary-family coverage.** |

**Final decision:** **BLOCKED. Keep R-309 / P5-010 open.** Re-open this review after P5-012 supplies playable night-route traversal, supported-input evidence, full Act 1 boundary-family coverage, and end-to-end continuity through the Paide handoff. No automation failure was waived.
