---
name: rebel-character-work-loop
description: Deliver historically grounded, dramatically useful characters and proactively expose missing agency, knowledge, daily-life, and production handoffs.
---

# Rebel Character Designer Work Loop

Read `agents/playbook.md`, `agents/rebel-character/playbook.md`, and `agents/WORK_PROTOCOL.md` first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Find the highest-priority ready `role: character` row. Preflight required schemas and writable paths, then claim it with a lease before editing.
2. Read its slice brief, relevant evidence, canon, narrative beat, faction ledger, and existing relationships. Do not invent unsupported history to fill a missing dependency.
3. Author or revise the assigned character data and brief. Define stable identity, social/material position, livelihood, allegiance, motive, fear, leverage, relationship pressure, knowledge boundary, voice foundation, and the action this person takes when the player does nothing.
4. Tie every detail to gameplay, narrative causality, historical texture, or visual production. Provide concrete clothing layers/materials, body/action needs, props, and motion states for Art without prescribing unsupported ornament. A named character must not be a generic quest dispenser.
5. Validate against `schemas/character.schema.json`, stable IDs, faction context, and the requested quest/dialogue use. Verify that attested, plausible composite, folklore, and invented biography are distinguished.
6. On success, release the claim and leave `- [~] + review: canon`. Create task-board follow-ups for concrete downstream Art, Dialogue, Quest, or Research needs not already planned; use work requests for unresolved decisions or evidence.
7. If blocked, release the claim, set `- [!] + blocked: <type>(...)`, and create one task-board follow-up naming the owner and clearing condition when executable; otherwise create one request.

## Improve mode - character scout

When no row is ready, audit one current-slice character seam. Look for a quest giver without independent motive, NPC knowledge that exceeds witnessed state, faction membership without personal cost, generic medieval voice, missing daily-life/economic grounding, a relationship that never changes play, or a character with no actionable visual/motion brief.

Create at most two deduplicated task-board follow-ups, using request cards only for unresolved decisions or evidence. If the current slice's cast is coherent and implementable, report `idle: healthy` and exit.

## Completion standard

A downstream writer can tell what the character wants, knows, risks, sounds like, looks like, and does; Quest can expose leverage and consequence; Art has evidence-backed form and action needs; no biography contradicts canon.
