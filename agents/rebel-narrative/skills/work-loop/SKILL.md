---
name: rebel-narrative-work-loop
description: Deliver playable historical dramatic architecture and proactively find passive beats, weak stakes, missing payoff, and consequence discontinuity.
---

# Rebel Narrative Designer Work Loop

Read `agents/playbook.md`, `agents/rebel-narrative/playbook.md`, and `agents/WORK_PROTOCOL.md` first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Select the highest-priority ready `role: narrative` row. Confirm approved scope, research/canon basis, target slice, and downstream handoff before claiming with a lease.
2. Define the beat through dramatic function rather than lore coverage: whose situation changes, what the player wants, what resists them, what information or material leverage is available, and why the choice matters now.
3. Author concise scene/act beats with setup, player verb, pressure, choice, immediate feedback, remembered consequence, delayed payoff, and convergence on the fixed historical spine. Keep the forge a lever when relevant and history a pressure on people, not background wallpaper.
4. Give factions credible competing interests and characters agency when Kalev does nothing. Avoid false good/evil symmetry, choices distinguished only by tone, arbitrary surprise, or branches whose outcomes collapse into identical state.
5. Mark evidence/confidence, unresolved research, required character knowledge, quest variables, locations, art moments, dialogue jobs, and runtime assumptions. Do not invent mechanics or expand the campaign to rescue a beat.
6. Review against `README.md`, canon, current approved pillars, timeline, and consequence continuity from earlier and later beats.
7. On success, release the claim and leave `- [~] + review: canon`. Create requests for missing Research, Character, Quest, Map, Art, or product decisions.
8. If blocked, release the claim, set a typed blocker, and name the owner and clearing condition.

## Improve mode - story scout

Audit one current-slice chain from setup to aftermath. Look for a passive scene, missing player verb, no personal stakes, faction without rational pressure, forge choice that never resurfaces, historical event used only as exposition, branch without state consequence, payoff without setup, or consequence no later person/place remembers.

Create at most two deduplicated requests with the missing dramatic function and intended handoff, not a speculative rewrite. If the chain is playable and causally complete, report `idle: healthy`.

## Completion standard

Quest can turn the beat into deterministic play without inventing intent; Character and Dialogue know motives and knowledge; historical events remain fixed while human outcomes respond to the player; each promised consequence has a later resurfacing point.
