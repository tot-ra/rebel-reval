---
name: rebel-dialogue-work-loop
description: Deliver concise state-aware historical dialogue and proactively find silent, generic, contradictory, or consequence-blind conversation states.
---

# Rebel Dialogue Writer Work Loop

Read `agents/playbook.md`, `agents/rebel-dialogue/playbook.md`, and `agents/WORK_PROTOCOL.md` first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Select the highest-priority ready `role: dialogue` row and preflight the package, schemas, quest variables, and character brief before claiming with a lease.
2. Read the approved narrative purpose, character motive and knowledge boundary, quest state machine, historical language evidence, and consequence to surface.
3. Write or revise dialogue and barks that perform a job: clarify a player choice, reveal leverage, express faction pressure, acknowledge evidence, change a relationship, or provide feedback. Prefer subtext and specific material concerns over lore lectures and generic medieval flavor.
4. Make branches observably state-aware. Reference only real variables; never let an NPC know unwitnessed events. Give materially different player choices distinct responses or consequences, and ensure failure/refusal paths remain intelligible.
5. Use period-conscious diction without theatrical archaism, modern idioms, encyclopedic exposition, or false precision about language not supported by evidence. Keep ambient barks short, varied, and tied to legitimate map/phase states.
6. Validate against dialogue and bark schemas, quest references, line budget, reachability, and character knowledge. Read key branches aloud for intent and ambiguity.
7. On success, release the claim and leave `- [~] + review: canon`. Create task-board follow-ups for concrete missing variables, character decisions, or runtime support; use work requests for unresolved evidence or decisions.
8. If blocked, release the claim, set a typed blocker, and name the clearing owner.

## Improve mode - dialogue scout

Audit one current-slice conversation seam: quest state with no spoken feedback, choices that receive the same response, expository monologue, voice drift, knowledge leak, absent failure/refusal branch, repeated bark, or a world-state change the city never acknowledges.

Create at most two deduplicated requests. If dialogue already makes the slice state and stakes audible without excess, report `idle: healthy`.

## Completion standard

Every line respects who knows what and why they speak; choices and consequences are audible; variables and schemas validate; historical texture comes from specific concerns rather than unsupported pseudo-medieval speech.
