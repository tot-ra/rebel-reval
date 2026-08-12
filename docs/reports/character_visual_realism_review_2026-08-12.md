# Character models and animations - visual realism review

Date: 2026-08-12
Trigger: maintainer request to review character-model and animation visual state against Witcher 3 realism inspiration and create improvement tasks.
References: [`docs/WITCHER3_REALISM_INSPIRATION.md`](../WITCHER3_REALISM_INSPIRATION.md), [`docs/reports/face_realism_research.md`](face_realism_research.md), [`docs/VISUAL_FIDELITY_PLAN.md`](../VISUAL_FIDELITY_PLAN.md), [`docs/adr/0016-tiered-character-fidelity.md`](../adr/0016-tiered-character-fidelity.md), [`docs/CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md).

Executable follow-ups: [`docs/CHARACTER_REALISM_BACKLOG.md`](../CHARACTER_REALISM_BACKLOG.md) (**P0-188**..**P0-198**).

## Scope and method

Reviewed committed runtime humanoids under `assets/characters/shared/`, the shared-rig contract, face closeups dated 2026-08-09, older full-body closeups dated 2026-07-31, and the Witcher 3 adaptation document. No sub-agents. No new GLB rebuild in this row.

"Realism" here follows project canon: anatomical, material, and motion credibility inside ADR 0016/0018 budgets - not photographic Witcher parity or facial blendshapes.

## Current measured state (2026-08-12)

| Signal | Evidence | Reading |
|---|---|---|
| Hero LOD0 mesh | `heroic_humanoid.glb` ~50.9k indexed tris, 15 meshes, 18 materials, 12 embedded images, 76 animation clips, ~5.3 MiB | Inside Tier-0 triangle cap; surface pipeline no longer flat-color only |
| Named bodies | `mart`, `henning`, `innkeeper`, `townswoman`, `watchman`, `sergeant`, `danish_warrior`, `bandit` + LOD1/LOD2 | Same shared-rig ladder; distance LODs wired in `SharedCharacterRig` |
| Face pass | `docs/reports/images/characters/face_*.png` (2026-08-09) | Parametric sockets, brow tubes, sculpted mouth, limbal iris, cornea material present; still reads plastic/blocky at dialogue distance |
| Full-body closeups | `docs/reports/images/characters/closeup_*.png` and `townswoman/` (2026-07-31) | **Stale** relative to the Aug face/PBR pass; do not use as current silhouette evidence |
| Animation library | 76 KayKit-derived clips on every body; canonical map in `assets/characters/README.md` | Locomotion/combat/sit/talk coverage exists; smithy bespoke library still deferred (P2-062 note) |
| Renderer ceiling | `gl_compatibility` | No true SSS; wrap/albedo zoning must fake skin response |

## Visual verdict by subsystem

### Face and head (highest third-person cost)

Strengths: deterministic landmark sculpt, layered eye parts (`hero_cornea`, pupil, limbal ring), lip tubes, brow tubes, vertex-colour complexion export path documented in face research.

Gaps that still dominate closeups:

1. Skin reads as hard clay under directional light - insufficient warm wrap / periorbital zoning in the Godot material path.
2. Beard shell keeps a hard cheek crossing edge; fibre tint is exported but `vertex_color_use_as_albedo` stays off on the first head surface (`hero_beard`) per face research.
3. Hair shell still shows ring terracing and UV-island blocks from the procedural hair family.
4. Shared one-bone head forbids FACS blendshapes; dialogue faces stay frozen while Witcher 3 sells emotion through facial animation. Micro-motion must come from look-at, blink proxies, and talk gestures.

### Body, cloth, and props

Strengths: anatomy + clothing layers, profession outerwear, hammer/spear/sword slots, cape/hat garments, muscle modifier, rebuilt walk/run arm carriage with numeric audit.

Gaps:

1. Cloth and leather still lack readable wear, seams, and occupation storytelling at gameplay distance (Witcher environmental storytelling applied to costume).
2. Cape is skinned but has no secondary motion beyond the shared clips.
3. Hand-to-prop contact remains approximate; grips can read as hovering blocks in action frames.
4. Body closeup plates are outdated and understate current PBR detail.

### Animation and living-city motion

Strengths: shared 76-clip library, data-only `animation_overrides` for gait variety, sit/forge/combat/talk canonical names, smithy contact pose offsets.

Gaps versus Witcher 3 immersion adaptations in `WITCHER3_REALISM_INSPIRATION.md`:

1. Idle loops are generic KayKit neutrals - little weight shift, breath, or profession-specific fidget.
2. Ambient NPC routines still need bark-synced gesture variety (document maps this to living-city work; animation assets remain thin).
3. Smithy station work still reuses generic melee/interact clips; bespoke forge animation pack was explicitly deferred after P2-062.
4. No authored blink/look-at/talk head micro layer, so conversation closeups feel doll-like even when body gestures fire.

## Mapping to Witcher 3 inspiration (visual slice only)

| Witcher 3 cue | Project adaptation today | Visual/animation gap |
|---|---|---|
| Readable NPC identity at conversational distance | Tier-0/1 shared rig + face knobs | Face/hair/beard materials still break immersion first |
| Daily routines and ambient life | Routines + barks + station poses | Motion vocabulary too thin for market/guard/drunk/merchant reads |
| Consequence-visible people | Ledger/dialogue variants | Costume wear and posture variants not yet a visual system |
| Investigative/close inspection | Third-person camera + DoF | Closeup fidelity now the limiting factor, not camera |

Gameplay systems in the Witcher doc remain out of this row; only character presentation tasks are claimed below.

## Explicit non-goals

- Separate hero skeleton or abandoning the 76-clip shared library.
- Runtime facial blendshape / FACS system (blocked by head-bone contract).
- HairWorks-class strand simulation.
- Claiming photographic or HDR10 Witcher parity on GL Compatibility.
- Reopening renderer choice (P0-142 already recommends staying on GL Compatibility for the shipped macOS preset).

## Recommended sequence

1. Material truth on current meshes (**P0-189**..**P0-192**) - cheapest visible jump.
2. Hair/beard geometry (**P0-193**) within Tier-0 caps.
3. Refresh evidence plates (**P0-194**) so art review stops judging stale July captures.
4. Motion credibility (**P0-195**..**P0-198**), starting with locomotion/dialogue micro-motion, then smithy and ambient packs.
5. Keep **P0-183** (GLB byte budgets) as the parallel size constraint so realism work does not inflate the ~5 MiB bodies further without LOD/compression.

## Verification performed for this review

- Inspected `heroic_humanoid.glb` JSON chunk: 76 animations, 12 images, ~50.9k tris.
- Reviewed face plates `face_front`, `face_eyes`, `face_mouth`, `face_profile`, `face_three_quarter` and body plates `closeup_iso_*` / townswoman set.
- Cross-checked ADR 0016 budgets, CHARACTER_GENERATION surface pipeline, face_realism_research remaining gaps, and WITCHER3 adaptation rows for NPC routines.
