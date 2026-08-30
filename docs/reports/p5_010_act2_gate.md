# P5-010 Act 2 authorial gate

**Status:** authored-package gate implemented; automated Act 2 and Paide transition checks pass, while maintainer playable review remains pending
**Task:** R-309 / P5-010
**Authority:** [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md)
**Manifest:** [`docs/data/act2_gate_manifest.json`](../data/act2_gate_manifest.json)

## Scope

This gate covers the authored Act 2 night and siege package corpus currently present in the repository. The Paide finale transition is implemented by P5-009 and verified by its dedicated model suite; this report does not claim that the remaining maintainer playable review has been signed off.

| Gate area | Evidence | Result |
|---|---|---|
| Branch traversal | Ten authored packages, two branches each; existing generated Godot suites execute the transition paths | **Pass for authored corpus** |
| Save fixtures | Twenty current-schema envelopes under `content/saves/act2/`; the dedicated Godot loader hydrates every fixture through `SaveEnvelope` | **Pass for authored corpus** |
| Content budget | Titles, summaries, state labels, objectives, and outcome summaries total 906 / 1200 words | **Pass** |
| Maintainer playable review | Review of all intended Act 2 routes, including the completed Paide finale transition | **Pending** |
| Full Act 2 gate | ADR 0014 requires all rows above plus maintainer sign-off | **Pending maintainer review** |

## Automated verification

```bash
python3 tools/report_act2_gate.py --check
python3 -m unittest tests.python.test_act2_gate -v

export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_gate_fixtures
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_act2_mission_host
```

The generated package filters remain the branch traversal evidence for the ten authored packages. The report command exits zero for the authored corpus while preserving P5-009 as a warning and does not claim the full gate is ready for maintainer sign-off.

## Maintainer review checklist

- [x] P5-009 supplies the Paide finale, all intended knowledge/warning branches, and validated Act 3 transition records (`scripts/quest/paide_finale_model.gd`, `tests/godot/test_paide_finale.gd`, 4/4).
- [ ] Clean-save traversal reaches every Act 2 branch, including both Act 1 boundary families where offers differ.
- [x] Published authored Act 2 fixtures load without identity loss (`test_act2_gate_fixtures`, 1/1); migration coverage remains governed by the save contract.
- [ ] Maintainer records completion, comprehension, pacing, combat/non-combat readability, choice impact, continuity, and supported input review.
- [x] Critical/high findings from the automated preflight are closed; no failed automation is waived.

## Known blocker

`P5-009` is complete and its transition model passes the focused suite. The remaining gate item is maintainer playable review of the authored Act 2 routes and Paide handoff. The automated corpus gate can fail on package/fixture drift, but it must not advance R-309 to done until that review is recorded.
