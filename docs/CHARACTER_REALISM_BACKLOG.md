# Character visual realism backlog

Durable claimable contracts from the 2026-08-12 character model/animation review.
Promote each open row to the project task board before claiming implementation.
ID index also listed in [`TODO.md`](../TODO.md).
Evidence report: [`docs/reports/character_visual_realism_review_2026-08-12.md`](reports/character_visual_realism_review_2026-08-12.md).

Companion docs: [`docs/WITCHER3_REALISM_INSPIRATION.md`](WITCHER3_REALISM_INSPIRATION.md), [`docs/reports/face_realism_research.md`](reports/face_realism_research.md), [`docs/VISUAL_FIDELITY_PLAN.md`](VISUAL_FIDELITY_PLAN.md), [`docs/CHARACTER_GENERATION.md`](CHARACTER_GENERATION.md), ADR 0016.

Format: `ID | deps | deliverable | verify`.

## Closed in this review

- [x] P0-188 | deps: none | deliverable: character visual realism review against Witcher 3 inspiration + face research, with claimable follow-ups P0-189..P0-198 and no runtime mesh change in-row | verify: `docs/reports/character_visual_realism_review_2026-08-12.md` and this backlog exist; `TODO.md` indexes the backlog; `python3 tools/generate_active_docs_report.py --check` passes after active-doc registration

## Open - materials and face credibility

- [ ] P0-189 | deps: P0-188 | role: art/dev | deliverable: enable and prove `vertex_color_use_as_albedo` (or equivalent runtime material flag) for generated head/beard/skin surfaces that export COLOR_0 complexion/fibre tints, so Godot no longer leaves beard/skin vertex tint unused on the first head surface | verify: Godot-side `Mesh.ARRAY_COLOR` non-flat on head surfaces; before/after face plates under `docs/reports/images/characters/`; `--filter=test_character_rig` green; asset lint green

- [ ] P0-190 | deps: P0-189 | role: art | deliverable: soften the beard cheek-crossing hard edge and keep fibre tint continuous across the jaw/cheek boundary without breaking the head-bone weight contract or Tier-0 triangle cap | verify: rebuilt hero + at least one bearded named body; face closeups show no hard shelf along the cheek; `python3 tools/verify_asset_lint.py` and `--filter=test_character_rig` green

- [ ] P0-191 | deps: P0-188 | role: art | deliverable: remove or hide hair-shell ring terracing and procedural UV-island block reads on hero/named Tier-0/1 hair materials (azimuth fibre + unwrap/texture fix) | verify: face/three-quarter plates no longer show horizontal terrace bands or hard UV islands at dialogue distance; asset lint + character rig tests green; triangle/texture caps unchanged

- [ ] P0-192 | deps: P0-189 | role: art/dev | deliverable: GL Compatibility wrap-lit skin response plus readable cornea/iris specular path for Tier-0/1 shared-rig bodies (successor to planned P0-146; no true SSS claim) | verify: day/night face plates under third-person lighting; focused material/rig tests; ADR 0016 shader-set docs updated if names change; asset lint green

## Open - hair geometry and evidence

- [ ] P0-193 | deps: P0-191 | role: art | deliverable: hair/beard card or layered shell upgrade inside Tier-0 (60k / 2048 px) and Tier-1 caps, replacing the single hard hair shell where it fails dialogue closeups (successor to planned P0-148) | verify: hero + townswoman (+ one bearded cast) rebuilds; triangle/texture lint; face plates; `--filter=test_character_rig` green

- [ ] P0-194 | deps: P0-189, P0-191 | role: art/qa | deliverable: refresh full-body and townswoman closeup evidence under `docs/reports/images/characters/` so plates match the current PBR/face generator (replace 2026-07-31 stale captures) | verify: new `closeup_*` and townswoman plates dated with the rebuild; `tools/capture_character_closeup.gd` path documented; no review cites July plates as current

## Open - animation and living motion

- [ ] P0-195 | deps: P0-188 | role: art/dev | deliverable: locomotion credibility pass on shared clips - foot plant / weight shift readability, contralateral consistency preserved, optional light cape secondary for walk/run - without new skeletons | verify: `tools/audit_arm_swing.py` targets still hold; new walk/run/idle plates; `--filter=test_character_rig` green

- [ ] P0-196 | deps: P0-188 | role: art/dev | deliverable: dialogue micro-motion layer without facial blendshapes - head look-at toward speaker, blink proxy, and talk-gesture coupling for Tier-0 cast closeups | verify: focused Godot filter covering look-at/blink/talk hooks; dialogue or showcase capture proves non-frozen face framing; shared head-bone contract preserved

- [ ] P0-197 | deps: P0-195 | role: art | deliverable: smithy station bespoke animation pack deferred after P2-062 - anvil strike, bellows, quench, and seated Henning work loops authored or retargeted onto the shared rig and bound through smithy station profiles | verify: smithy domestic/routine filters green; day capture at forge stations; acceptance note updates `docs/reports/kalev_smithy_domestic_life_acceptance.md`

- [ ] P0-198 | deps: P0-196 | role: art/narrative-runtime | deliverable: ambient NPC idle/gesture variety for market vendor, guard patrol, drunk, and merchant reads aligned with `docs/WITCHER3_REALISM_INSPIRATION.md` NPC Daily Routines, using `animation_overrides` and/or small additive clips - no runtime LLM | verify: at least four role gesture mappings with showcase or Lower Town ambient proof; character rig + relevant ambient tests green

## Non-goals for this backlog

- Separate per-hero skeletons or abandoning the 76-clip KayKit-derived library.
- Facial FACS blendshapes or HairWorks-class strand simulation.
- Renderer switch away from GL Compatibility.
- Broad quest/systems work from the Witcher doc (reputation, investigation, economy) - those stay on their existing P2/P4 IDs.
- Inflating body GLB bytes without coordinating **P0-183** size budgets.
