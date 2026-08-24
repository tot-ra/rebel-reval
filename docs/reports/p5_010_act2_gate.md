# P5-010 Act 2 authorial gate

**Status:** authored-package gate implemented; full Act 2 acceptance is blocked by P5-009
**Task:** R-309 / P5-010
**Authority:** [ADR 0014](../adr/0014-authorial-acceptance-gates-without-external-playtests.md)
**Manifest:** [`docs/data/act2_gate_manifest.json`](../data/act2_gate_manifest.json)

## Scope

This gate covers the authored Act 2 night and siege package corpus currently present in the repository. It does not invent the Paide finale or mark the unfinished P5-009 dependency as accepted.

| Gate area | Evidence | Result |
|---|---|---|
| Branch traversal | Ten authored packages, two branches each; existing generated Godot suites execute the transition paths | **Pass for authored corpus** |
| Save fixtures | Twenty current-schema envelopes under `content/saves/act2/`; the dedicated Godot loader hydrates every fixture through `SaveEnvelope` | **Pass for authored corpus** |
| Content budget | Titles, summaries, state labels, objectives, and outcome summaries total 906 / 1200 words | **Pass** |
| Maintainer playable review | Review must include the Paide finale and all intended Act 2 routes | **Blocked by P5-009** |
| Full Act 2 gate | ADR 0014 requires all rows above plus the Paide branch-dependent Act 3 handoff | **Blocked by P5-009** |

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

- [ ] P5-009 supplies the Paide package, all intended knowledge/warning branches, and validated Act 3 transition records.
- [ ] Clean-save traversal reaches every Act 2 branch, including both Act 1 boundary families where offers differ.
- [ ] Published fixtures load or migrate without identity loss after the P5-009 save contract lands.
- [ ] Maintainer records completion, comprehension, pacing, combat/non-combat readability, choice impact, continuity, and supported input review.
- [ ] Critical/high findings from the preflight are closed; no failed automation is waived.

## Known blocker

`P5-009` remains an explicit dependency. The authored corpus gate is useful evidence and can fail on package/fixture drift, but it must not advance R-309 to done until the Paide finale and maintainer review are complete.
