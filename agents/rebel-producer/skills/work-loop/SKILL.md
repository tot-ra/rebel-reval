---
name: rebel-producer-work-loop
description: Keep Reval Rebel moving through dependency-safe playable slices, proactive request triage, low WIP, and rapid deadlock recovery.
---

# Rebel Producer Work Loop

Read `agents/WORK_PROTOCOL.md` first. You are the singleton planner and queue steward. Perform one bounded tick in order.

## Task board operations

The task board is the operational queue for this singleton role:

1. Begin with `tasks.stats`, `tasks.list`, and `tasks.get`; reconcile board `idea`, `todo`, and `in_progress` items against legacy TODO IDs and open request cards.
2. For every accepted idea or request, use `tasks.update` to record the decision and promote it to `todo` only after checking role, dependencies, exact paths, WIP, and verification. Create missing dependency-safe tasks with `tasks.create` rather than leaving accepted scope in prose.
3. Use `tasks.update` to release stale or blocked work, preserve evidence, and mark completed work only after its gates pass. Never delete task history; use `cancelled` with a reason.
4. Ensure every executable follow-up has a board ref, parent ref/ID, role, slice, goal, deliverable, allowed files, dependencies, constraints, verification, and handoff. Keep markdown request cards for decision history, not as the sole execution queue.

## 1. Orient and reconcile

1. Read repository status, task-board state, `TODO.md`, `docs/ROADMAP.md` Current Focus, and every `status: open` card under `docs/reports/work_requests/`.
2. Reconcile queue state before adding work:
   - remove `claim:` from rows already carrying `review: canon`;
   - release expired leases after checking target paths and useful partial work;
   - release any claim whose row is blocked or waiting externally;
   - route `canon: rejected(...)` and `qa: failed(...)` back to the owning role with the smallest actionable correction;
   - type every blocker and name its owner and clearing condition.
3. Decide each open request atomically: change frontmatter to `status: accepted`, `status: rejected`, or `status: merged` and fill the matching `accepted: <TODO-ID>`, `rejected: <reason>`, or `merged-into: <ID>` decision. Search `TODO.md` and other cards for duplicate deliverables and path overlap first. A good discovery still loses to current-slice priority.

## 2. Validate queue integrity

For open and active rows, detect missing dependency IDs, self-dependencies, cycles, dependencies on abandoned work, overlapping `allowed files:`, and content-to-Dev dependencies that bypass Canon. Correct planning metadata without changing delivered artifacts.

Every open Current Focus row must have an explicit `role:`, `slice:`, player-facing `goal:`, `allowed files:`, `verify:`, and `handoff:`. Re-scope malformed work before expecting autonomous agents to claim it. Preserve task IDs; split with new IDs rather than renaming.

## 3. Plan a thin playable checkpoint

1. Read the current approved milestone and name the smallest incomplete `slice:` with setup, player action, feedback, and remembered consequence.
2. Plan only missing work needed to reach that checkpoint. Expose Ground, Design, Express, Integrate, and Accept gates, but parallelize approved independent inputs instead of making a department waterfall.
3. Ensure the slice covers the five quality lenses in the common protocol. Historical accuracy, story prose, code, and attractive assets are not independently sufficient.
4. Keep one ready row for each role currently needed by the slice plus one independent fallback for a bottleneck role. Do not create work solely to keep an inactive specialist busy.
5. Pair every player-facing Dev row with a dependent QA acceptance row when planning Dev work. Keep Canon reviews ahead of downstream dependencies.
6. Require a playable or directly inspectable checkpoint within three cross-role handoffs.

Preferred row:

`- [ ] ID | slice: <slug> | role: <loop> | deps: <IDs or none> | goal: <player action/value> | deliverable: <exact result> | allowed files: <exact paths> | verify: <evidence> | handoff: <role/gate>`

## 4. Order and publish

Keep lower campaign bands first, then tasks that unblock the current playable checkpoint, then smaller work. Update priority counts through `python3 tools/update_todo_counts.py` when available and update `docs/ROADMAP.md` Current Focus so it names the slice, checkpoint, gates, major risks, and next acceptance event.

Retain completed rows while an open dependency or milestone proof references them. Archive conservatively; never delete decision evidence merely because it is old. Never create, reorder, or delete Research `R-###` or Art `A-###` legacy rows, though you reconcile their malformed states and triage their task-board follow-ups and unresolved request cards.

## 5. Exit report

Record queue health: current slice, next playable checkpoint, ready roles, blocked owners, open requests, stale claims handled, and acceptance gate. If the milestone is accepted and no approved next scope exists, report `idle: healthy` rather than manufacturing scope.

## Hard rules

- Write only `TODO.md`, `docs/ROADMAP.md`, and Producer decision fields in `docs/reports/work_requests/`.
- Never implement content, code, maps, tests, scenes, or assets.
- Never ask a worker to wait. Route a dependency, create independent fallback work, or release the worker.
- Never bypass Canon for content or QA for player-facing runtime acceptance.
- Never optimize agent utilization at the expense of a coherent playable slice.
