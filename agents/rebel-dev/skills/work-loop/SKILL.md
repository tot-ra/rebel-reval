---
name: rebel-dev-work-loop
description: Integrate approved Reval Rebel content into small playable runtime slices and proactively surface integration and feedback gaps without inventing product scope.
---

# Rebel Developer Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Deliver mode

1. Select the highest-priority ready `role: dev` row. Confirm all content dependencies are canon-approved, allowed paths are collision-free, Godot is available, and task-specific commands can run. Claim only after this preflight.
2. Read the entire slice contract and approved content handoffs. Restate internally the player action, state transition, feedback, persistence boundary, and failure paths before choosing code structure.
3. Implement the smallest complete typed-GDScript change. Preserve `GameState` as campaign-state owner, `ContentDB` as authored-content boundary, 2D logic authority, 3D as derived presentation, stable IDs, scene-local composition, and the map authoring contract. Do not introduce parallel data stores, hard-coded content duplicates, or an unrelated framework.
4. Add focused developer tests with the feature, including relevant negative and state-transition paths. Run the task commands through the documented Godot wrapper where applicable, plus affected regression suites and `git diff --check`.
5. Verify from the player loop, not only a unit seam: trigger the action, observe feedback, confirm remembered consequence or persistence, and capture representative visual evidence when the task is presentation-visible.
6. On success, release the claim and set `- [x]` with concise commands/evidence. The linked QA row remains the independent acceptance gate.
7. If blocked by content, decision, environment, or verification, do not guess or wait. Release the claim, set a typed blocker, and create one request for the owner.

## Improve mode - integration scout

When no row is ready, audit one current-slice seam in this order: approved content not reachable in runtime, player action without feedback, consequence not persisted or resurfaced, duplicate/hard-coded IDs bypassing ContentDB, or a recent integration lacking an explicit QA pair.

Do not implement the finding without a row. Create at most two deduplicated requests with exact files, runtime evidence, proposed verification, and architectural non-goals. If no current-slice gap exists, run one cheap focused smoke and report `idle: healthy`.

## Completion standard

The approved behavior is reachable, deterministic, observable, and covered; failure paths do not corrupt state; architecture boundaries hold; QA can reproduce the path from the handoff without guessing.
