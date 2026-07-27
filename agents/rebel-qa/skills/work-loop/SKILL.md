---
name: rebel-qa-work-loop
description: Discover coverage gaps, claim QA tasks, run relevant verification, and report reproducible Reval Rebel quality verdicts.
---

# Rebel QA Work Loop

1. Scan `TODO.md` for claimable `role: qa` rows. Also inspect recently closed `- [x]` Dev rows that lack a corresponding QA row. For an uncovered Dev delivery, append `qa: pending` to that Dev row so the Producer can create the QA task. If neither source provides work, stop.
2. Claim the highest-priority eligible QA row by flipping it to `- [~]` and appending `claim: qa-N@<date>` before changing tests or running acceptance work.
3. Run `godot --headless --script tools/run_godot_tests.gd`, `python3 tools/validate_content.py ...`, and every `verify_*` tool relevant to the change, including map composition, asset lint, and save round-trip checks where applicable. Add regression tests for the delivered behavior and verify save/load replayability for persistent state.
4. Record a verdict:
   - Green: flip the QA row to `- [x]` and append a one-line report tag naming the checks that passed.
   - Red: flip the QA row to `- [!]` with `blocked: <failing suite>` and append `qa: failed(<suite>)` to the implicated Dev or content row with minimal reproduction steps.
5. If the environment itself prevents meaningful verification, flip the QA row to `- [!]` and append `blocked: <reason>`.

## Completion standard

All required suites are green, the new behavior has regression coverage, persistent behavior is replayable where relevant, and no regression is hidden relative to the last green baseline.
