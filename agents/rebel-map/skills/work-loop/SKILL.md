---
name: rebel-map-work-loop
description: Deliver historically legible playable spaces and proactively find route, affordance, composition, fabric, and spatial-storytelling gaps.
---

# Rebel Map Author Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Deliver mode

1. Select the highest-priority ready `role: map` row. Preflight Godot/map tools, exact source paths, resolved research and art dependencies, and path overlap before claiming with a lease.
2. Read the slice's player verbs, quest routes, character activity, historical dossier, plates, exclusions, canon, and approved visual vocabulary.
3. Author only the assigned MapBlueprint or `.rrmap` source. Preserve stable IDs, deterministic compilation, authoritative 2D logic parity, and activation gates. Do not hand-edit generated map output or invent a parallel source format.
4. Design in layers: readable primary route and objective; credible alternate or fail-forward route where required; interactions, patrols, and collision; landmark hierarchy; period-grounded plots/buildings/material cues; environmental narrative and lived activity. Historical fabric must also support navigation and play.
5. Label historical basis and exclusions where the source contract allows. Create work requests for missing evidence, props, quest anchors, or runtime factories rather than substituting arbitrary geometry.
6. Run the mandatory map checks from `AGENTS.md`, task-specific composition and walkability checks, deterministic output/parity checks, and `git diff --check`. Capture the gameplay camera at approach, decision point, and objective when presentation changes.
7. On success, release the claim and leave `- [~] + review: canon`. If blocked, release the claim, set a typed blocker, and create one request with an exact clearing condition.

## Improve mode - environment scout

Audit one current-slice route from spawn to objective and aftermath. Look for unclear entrances, weak landmark hierarchy, non-walkable intended paths, no alternate route promised by Quest, interactions hidden by dressing, empty/placeless blocks, repeated primitives, historically wrong fabric, missing NPC work space, or beautiful composition that obscures gameplay.

Create at most two deduplicated requests. Do not move geometry without a task. If route, affordance, atmosphere, and historical fabric are coherent, report `idle: healthy`.

## Completion standard

Players can read goals and routes, required actions and patrols fit the logic plane, the place communicates 1343 Reval without anachronistic shorthand, stable identity and parity hold, and Art/Dev/QA receive exact anchors and evidence.
