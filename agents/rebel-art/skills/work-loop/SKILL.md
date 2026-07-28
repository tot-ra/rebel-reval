---
name: rebel-art-work-loop
description: Claim, produce, animate, verify, and report Reval Rebel art tasks, and proactively keep the model, animation, and historical-accuracy art backlog in TODO.md filled and prioritised.
---

# Rebel Art Producer Work Loop

You are never idle. An empty art queue is not a stop condition: it means nobody has written down what
the world is still missing, and that audit is your job. Read the binding direction first -
`docs/ART_BIBLE.md`, `docs/MATERIAL_STYLE_LOCK_KIT.md`, `docs/VISUAL_FIDELITY_PLAN.md`, and the asset
pipeline freeze in `AGENTS.md` - then run **Mode A** if an art row is claimable, otherwise **Mode B**.

## Mode A - deliver a claimed art row

1. Scan `TODO.md` for `- [ ]` rows with `role: art`, including `A-###` rows in the `## A -` section, whose dependencies are all `- [x]`. Confirm the common claim criteria in `docs/AGENT_LOOPS.md`, including no same-role path overlap.
2. Claim the highest-priority eligible row *before* creating or modifying assets: flip it to `- [~]` and append `claim: art-N@<date>`. First writer wins.
3. **Establish the historical basis before the first generation.** Open the dossier the row names, or find the covering topic through `history/RESEARCH_INDEX.md`, and read its `## Brief` and `## Production hooks`; those sections are written for you. Pull the plates cited by the hooks from `history/reference/plates.csv` and derive form, construction, material, and finish from them. Plates are evidence, never shipped assets. Where the record is thin, model the generic attested form and record the assumption as `plausible composite` in the brief rather than inventing a decorative invention. Where the missing evidence would decide the silhouette of a period-visible asset, block the row (step 9) so the Producer can route research instead of guessing.
4. Produce candidates according to the style lock kit. Use `agents/rebel-art/skills/3d-renderer/SKILL.md` for 3D and `agents/rebel-art/skills/icon-generator/SKILL.md` for inventory icons. For 3D references, require one object, a neutral pose where applicable, and a plain background. Curate the cleanest candidate; import only production-approved output into `assets/`; record source, rights, prompt or workflow provenance, plates or dossier derived from, and approval information in `assets/SOURCES.csv`. Raw candidates stay in `generated/` and never enter runtime paths before approval.
5. **Animate what moves, in the same row.** Apply the animation contract below: an entity that walks, flies, works, or sways ships its class's clip set together with its mesh. A static delivery of a moving entity is incomplete unless the row defers animation to a named follow-up row that you create in `## A -` before closing.
6. Run `python3 tools/verify_asset_lint.py`. Resolve every failure within owned paths. When the asset has a capture script under `tools/`, render one gameplay-camera frame and keep it as delivery evidence; judge readability from that frame, not from an isolated turntable.
7. On a successful content delivery, replace the claim tag with `review: canon`. Add a concise Canon note when the visual work introduces or interprets canon-relevant material. Do not mark the row done yourself.
8. **Convert leftovers into work.** Anything you saw but did not fix - a neighbouring prop still missing, a species with a mesh but no clips, an anachronism one shelf over - becomes an `## A -` row (Mode B, rule 5). A need belonging to another role goes into `docs/reports/art_downstream_requests.md`. Never leave a dangling note.
9. If the task cannot be completed, flip it to `- [!]` and append `blocked: <reason>`. Do not work around the asset freeze, a missing approval, an unclear brief, or a missing historical basis.

## Mode B - refill the art backlog (run whenever no row is claimable)

Audit through the four lenses below, in this priority order: what currently open `role: map`, `role: dev`, `role: quest`, and `role: character` rows will need first; then what the vertical slice already shows to the player; then breadth.

1. **Model coverage.** Compare what content declares against what exists on disk: the ledgers in `docs/FLORA_FAUNA.md`, `docs/ASSET_INVENTORY.md`, the `style=` and `prop` IDs authored into `content/maps/*.rrmap`, character variants under `assets/characters/variants/`, and the debug showcases in `scenes/debug/`. Gap classes worth a row: an ID authored into a map with no mesh behind it; a player-facing entity still drawn by a primitive stand-in in `scripts/map/view3d/*_meshes.gd`; a ledger entry documented as modeled with no file on disk; an asset whose fidelity tier requires an LOD chain it does not have.
2. **Animation coverage.** Walk the same entity inventory against the animation contract. A modeled but motionless bird, animal, or person is a gap, and so is an entity that borrows a clip from a class it does not belong to, a rig family missing a state the gameplay already asks for (work, carry, sit, graze, perch, take-off), and a clip that exists for one species but not its siblings in the same rig family. Prefer rows that complete a shared clip set for a whole family over rows that animate one asset in isolation.
3. **Historical accuracy.** Read the dossiers whose consumers include Art in `history/RESEARCH_INDEX.md`, their `## Production hooks`, and `docs/HISTORICAL_AUDIT.md` - in particular `### Cross-map exclusions and required corrections`, which lists forms that may not appear as 1343 fabric. Open a correction row when a shipped asset carries an anachronistic form or ornament, the wrong material or construction for its period and place, a phenotype or tack that no regional evidence supports, a texture that contradicts an attested finish, or when content already references a period-attested item that has no asset. Name the dossier and the plate IDs in the row so the fix is verifiable against evidence rather than taste. Texture and material passes count here: historical accuracy lives in surfaces as much as in silhouettes.
4. **Style and fidelity consistency.** Check shipped assets against `docs/ART_BIBLE.md`, `docs/MATERIAL_STYLE_LOCK_KIT.md`, and the frozen tier budgets in `docs/VISUAL_FIDELITY_PLAN.md`: tier budget violations, missing PBR channels, texel density that drifts between neighbouring assets, non-portable materials, and provenance rows missing from `assets/SOURCES.csv`.

5. **Write rows** into the `## A - Art and animation backlog` section of `TODO.md`:
   `- [ ] A-### | role: art | deps: <IDs or none> | deliverable: <target path> - <what must exist> | allowed files: <exact paths> | verify: <what proves it>`.
   Allocate IDs from the highest existing `A-###`; never reuse or rename one. Keep at least six open rows so several instances can run in parallel, and refresh the priority-count table with `python3 tools/update_todo_counts.py` instead of hand-editing it.
6. **Scope every row to a single tick** (20-40 minutes of production): one prop, one species, one clip set for one rig family, one texture pass over one asset class, one correction named by one dossier. A row phrased as "improve the harbour" or "better animals" is malformed - split it.
7. **Split, do not delete.** A superseded row is re-worded or split into successors; a row disappears only once its deliverable exists on disk with provenance.
8. Then claim the top row and continue in Mode A.

## Animation contract

One motion approach per entity class, shared repo-wide. Consistency is the point: a reviewer, a dev
wiring an actor, and the next art instance must all be able to predict clip names from the class.

| Entity class | Rig and clip source | Canonical clips | Runtime |
|---|---|---|---|
| Humanoid | generated body on the retargeted CC0 KayKit skeleton (`tools/generate_hero_body.py`, `tools/rebuild_hero_character.sh`) | all 76 shared clips ship on every body; per-character variety is data through `animation_overrides` in the character `.tres` | `AnimationPlayer` inside the GLB |
| Quadruped and livestock | `tools/assets/medieval_animal_rigs.py` (`create_quadruped_rig` plus the species rig) | `Idle-loop`, `Walk-loop`, plus any state added to that shared module | GLB clips driven by the ambient animal actor |
| Bird | procedural, no skeleton | flap and glide cadence in `scripts/map/view3d/map_view_bird_flight.gd` | script-driven |
| Rigid prop and vegetation | no skeleton | shader or script motion (wind, fire, cloth, water) | material or script |

- A new entity joins an existing class and reuses its clip names and its build tool. Extending a class means adding a clip to the shared module so every member gains it, never authoring a one-off animation for a single asset.
- A fifth motion approach, a divergent clip name, or a per-asset rig is an architecture decision: raise it through the task and let it reach an ADR. Do not invent it inside an asset delivery.
- Every clip loops seamlessly, keeps weight-bearing feet on the ground plane through the cycle, and stays readable at gameplay camera distance. Verify motion in one captured frame sequence, not by inspecting keyframes.
- Clip authoring lives in the build tools under `tools/`, not in hand-edited GLBs, so a rebuild reproduces the same result.

## Backlog authority and its limits

- You may create, re-word, re-order, and split rows **only** inside the `## A - Art and animation backlog` section of `TODO.md` and **only** with `role: art`, and you may keep the `A` line of the priority-count table accurate. Every other row belongs to the Producer; editing one is a protocol violation.
- You never author rows for another role. A need that requires research, dev, map, character, or quest work goes into `docs/reports/art_downstream_requests.md`, which the Producer reads on its reconcile tick.
- You own `assets/` and `generated/`. Runtime catalogs, actors, and scene wiring under `scripts/` and `scenes/` belong to Dev even when they draw your meshes: if an asset needs code to appear, that is a downstream request, not an art edit.
- You never edit canon, content packages, maps, or quests, and you never write a reference plate into `assets/`. Research informs art; it is not replaced by generating an image where evidence is missing.
- Respect the asset pipeline freeze in `AGENTS.md`: do not touch a blocked asset class unless the claimed row names the exact files.

## Completion standard

A delivered asset matches the approved art bible, reads at its intended gameplay scale, is lint-clean,
has complete provenance, and contains no unapproved raw 3D generation. Every moving entity ships the
full clip set of its animation class under that class's names. Every period-visible asset cites the
dossier and plates it derives from, or carries a labelled `plausible composite` assumption with a
rationale. And the tick ends with claimable art work left in `## A -` for the next instance.
