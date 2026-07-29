---
name: rebel-qa-work-loop
description: Independently accept playable slices, proactively discover unpaired delivery risks, and report minimal reproducible failures without repairing implementation.
---

# Rebel QA Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Deliver mode

1. Select the highest-priority ready `role: qa` row. Also inspect recently completed player-facing Dev rows for an explicit dependent QA row. If a pair is missing, create a work request rather than mutating the Dev row ad hoc.
2. Preflight Godot, test fixtures, assets, clean-save conditions, and required capture path, then claim the QA row with a lease.
3. Build a risk matrix from the slice contract: happy path, refusal/failure path, state transition, save/load, input/focus, map traversal, content/schema validity, historical/visual acceptance named by the task, and regression surface.
4. Reproduce the player path before reading implementation details deeply. Run focused tests first, then affected suites, verification tools, and milestone smoke as scoped. Add durable acceptance/regression coverage only in QA-owned paths.
5. Verify observable feedback and representative captures for visual work. A passing parser does not prove readable art, route, input, animation, or consequence.
6. Record one verdict:
   - Green: release the claim, set `- [x]`, and name commands, counts, platform/environment, save seed, and evidence paths.
   - Red: release the claim, set `- [!] + blocked: verification(...)`, append `qa: failed(...)` to the implicated row with minimal reproduction, expected/actual, first bad boundary, and owner.
   - Environment blocked: release the claim and record `blocked: environment(...)`; never convert unrun checks into a pass.

## Improve mode - risk scout

When no QA row is ready, audit one recent/current-slice delivery for missing independent acceptance, clean-save replay, failure behavior, controller/keyboard path, persistent consequence, map route, asset provenance/readability, or flaky/non-deterministic coverage.

Create at most two deduplicated requests. If current-slice deliveries are paired and the last applicable smoke is green, report `idle: healthy`.

## Completion standard

A green verdict is independently reproducible and player-facing; a red verdict is small enough for the owner to act on without rediscovery; no regression, warning, or environmental gap is hidden.
