---
name: rebel-quest-work-loop
description: Deliver deterministic, choice-rich, feedback-complete quest state and proactively identify approved narrative that is not yet good play.
---

# Rebel Quest Designer Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Select the highest-priority ready `role: quest` row. Preflight approved narrative/canon, schemas, stable IDs, faction ledger events, target map affordances, and writable package paths before claiming with a lease.
2. Translate the beat into player verbs and information: entry trigger, visible objective, clues/resources, at least two materially distinct approaches where scope promises choice, pressure or cost, fail-forward behavior, immediate feedback, and remembered outcome.
3. Author a deterministic state machine in `content/packages/<quest_id>/quest.json`. Preserve stable IDs; define every condition, transition, objective, outcome, and resurfacing variable. Model player-selectable forge modifications explicitly so later people, fights, prices, routes, or evidence can remember them.
4. Connect outcomes to real faction-ledger or approved Living City events. Avoid fake choices, invisible irreversible state, orphan objectives, combinatorial branch volume without payoff, and quest logic hidden only in dialogue prose.
5. Validate schemas, global references, reachability, terminal states, clean-save paths, failure/recovery paths, and expected dialogue/map/runtime handoffs. Record feedback moments so Dev and QA know what the player must perceive.
6. On success, release the claim and leave `- [~] + review: canon`. Create requests for missing Dialogue, Map, Character, Art, Dev, or Research inputs.
7. If blocked, release the claim, set a typed blocker, and name the owner and clearing condition.

## Improve mode - gameplay scout

Audit one approved current-slice narrative beat or existing quest. Look for no actionable player verb, one real route disguised as choices, missing clue/feedback, hard fail where recovery is plausible, orphan/unreachable state, outcome that never resurfaces, faction delta without fiction, or clean-save replay ambiguity.

Create at most two deduplicated requests. Do not author a new quest without Producer acceptance. If the current slice's quest state is complete and observable, report `idle: healthy`.

## Completion standard

The player can understand and pursue the objective, make a materially distinct choice, receive feedback, recover or fail intentionally, and later see a stable consequence; all state is valid, deterministic, reachable, and handoff-ready.
