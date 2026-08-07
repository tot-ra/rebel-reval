---
name: rebel-art-work-loop
description: Deliver historically grounded, beautiful, readable, animated production art and proactively maintain a bounded evidence-driven asset backlog.
---

# Rebel Art Producer Work Loop

Read `agents/playbook.md`, `agents/rebel-art/playbook.md`, `agents/WORK_PROTOCOL.md`, the binding art direction, and the relevant asset skill first.

## Task board handoffs

Use the `tasks` tool as the operational queue:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. Record progress, evidence, blockers, and handoff with `tasks.update`. Use `in_review` for content awaiting Canon, `testing` for QA handoff, `done` only after verification, and return blocked work to `todo` with a typed clearing condition.
3. When you discover a concrete downstream need, call `tasks.create` with status `idea` rather than leaving it only in a prose handoff. Include the parent task/ref, role, slice, player/production value, exact deliverable, allowed files, dependencies, constraints/non-goals, verification, and handoff; add `follow-up` plus role tags.
4. Use a markdown work request only when the need is not yet executable or requires a Producer/Canon/rights decision. Do not claim or implement another role's follow-up.

## Deliver mode

1. Select the highest-priority ready `role: art` row, including `A-###`. Before claiming, preflight Blender/Python or the named generation service, credentials, storage, exact allowed paths, import/lint commands, and historical evidence. Do not claim work an environment cannot execute.
2. Read the player-facing slice use, dossier `## Brief` and `## Production hooks`, cited plates, historical exclusions, comparable approved assets, technical budget, and required motion states.
3. Turn evidence into a production brief: silhouette, construction, materials, wear, color/value hierarchy, scale, interaction or combat readability, animation class, and uncertainty. When evidence cannot support a period-visible silhouette, request Research instead of decorating a guess.
4. Produce and curate candidates according to `docs/ART_BIBLE.md`, `docs/MATERIAL_STYLE_LOCK_KIT.md`, and the specialized skills. Generated output is a candidate, never automatically game-ready. Import only approved output; keep raw variants in `generated/`.
5. Deliver form and required motion together. A person, animal, machine, cloth, foliage class, or interactive prop is incomplete without the task's clip/state set or an already accepted follow-up. Judge timing, contacts, held props, and silhouettes from gameplay distance.
6. Record rights, workflow/model/prompt or deterministic generator, sources and plate IDs, edits, approval, and derived files in `assets/SOURCES.csv`. Never ship an evidence plate as an asset.
7. Run asset lint, provenance and import checks, task-specific mesh/texture/animation tests, and representative gameplay-camera captures. Compare against neighboring assets for scale, texel density, material response, value grouping, and affordance.
8. On success, release the claim and leave `- [~] + review: canon`. Create task-board follow-ups for runtime wiring, map placement, missing briefs, or research; use a request card only when the need is unresolved.
9. If blocked, release the claim, set a typed blocker, and create one task-board follow-up when executable, otherwise a request. Never hold GPU/tool work while waiting.

## Improve mode - visual production scout

Audit current-slice needs first, then one player-visible surface through these lenses:

- authored IDs with missing production assets or primitive stand-ins;
- motion classes missing clips, contacts, transitions, or state variants;
- anachronistic silhouette, construction, material, ornament, or finish against dossiers/exclusions;
- gameplay-camera readability, landmark hierarchy, interaction affordance, character recognition, scale, or animation timing;
- style/PBR/texel/LOD drift, non-portable materials, missing provenance, or raw generated output in runtime paths.

Art may maintain only `A-###` rows in its own backlog. Refill below three grounded open rows and cap at eight. Scope one asset, one shared animation set, or one coherent material correction per row. Concrete cross-role needs use task-board follow-ups; unresolved needs use work requests.

If no current or near-term visual gap exists, run one cheap asset health check, report `idle: healthy`, and exit.

## Completion standard

The asset is historically reasoned, visually coherent and beautiful at the gameplay camera, readable for its game function, complete for required motion/state, technically valid, rights/provenance clean, and handoff-ready for Map/Dev/QA.
