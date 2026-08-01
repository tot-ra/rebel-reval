---
name: rebel-map-work-loop
description: Deliver historically legible playable spaces and proactively find route, affordance, composition, fabric, and spatial-storytelling gaps.
---

# Rebel Map Author Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Select the highest-priority ready `role: map` row. Preflight Godot/map tools, exact source paths, resolved research and art dependencies, and path overlap before claiming with a lease.
2. Read the slice's player verbs, quest routes, character activity, historical dossier, plates, exclusions, canon, and approved visual vocabulary.
3. Author only the assigned MapBlueprint or `.rrmap` source. Preserve stable IDs, deterministic compilation, authoritative 2D logic parity, and activation gates. Do not hand-edit generated map output or invent a parallel source format.
4. Design in layers: readable primary route and objective; credible alternate or fail-forward route where required; interactions, patrols, and collision; landmark hierarchy; period-grounded plots/buildings/material cues; environmental narrative and lived activity. Historical fabric must also support navigation and play.
5. Label historical basis and exclusions where the source contract allows. Create task-board follow-ups for concrete missing props, quest anchors, or runtime factories; use a work request for missing evidence or an unresolved decision rather than substituting arbitrary geometry.
6. Run the mandatory map checks from `AGENTS.md`, task-specific composition and walkability checks, deterministic output/parity checks, and `git diff --check`. Capture the gameplay camera at approach, decision point, and objective when presentation changes.
7. On success, release the claim and leave `- [~] + review: canon`. If blocked, release the claim, set a typed blocker, and create one task-board follow-up with an exact clearing condition when executable; otherwise create one request.

## Improve mode - environment scout

Audit one current-slice route from spawn to objective and aftermath. Look for unclear entrances, weak landmark hierarchy, non-walkable intended paths, no alternate route promised by Quest, interactions hidden by dressing, empty/placeless blocks, repeated primitives, historically wrong fabric, missing NPC work space, or beautiful composition that obscures gameplay.

Create at most two deduplicated requests. Do not move geometry without a task. If route, affordance, atmosphere, and historical fabric are coherent, report `idle: healthy`.

## Completion standard

Players can read goals and routes, required actions and patrols fit the logic plane, the place communicates 1343 Reval without anachronistic shorthand, stable identity and parity hold, and Art/Dev/QA receive exact anchors and evidence.
