# ADR 0007: Programmatic 3D isometric presentation with AI-generated materials

**Reference:** TODO P0-040 rework, P0-051 through P0-053, P0-037 rework  
**Style-lock kit:** [`docs/MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md) (`style-lock-v1.0`)
**Recorded:** 2026-07-16
**Supersedes:** ADR 0004 (clean-painted candidate). **Amends:** ADR 0002 (presentation and direction-count rules).

## Status

Accepted

Amended by [ADR 0011](0011-optional-first-person-camera.md) (2026-07-20): the default gameplay camera remains fixed orthographic dimetric, with an optional first-person inspection toggle exposed in release UI.

## Context

The pre-scope-cut prototype (`quarantine/img/Screenshot 2025-08-26 at 16.42.48.png`, archived after README reverted to `img/banner.jpg`) was an AI-generated painted isometric scene: timber-framed buildings with visible facades and roof mass, textured terrain, dense Fallout/Stoneshard-like mood. That image is the product vision players were shown.

The scope-reduction chain then degraded the visible game in two steps:

1. **ADR 0002** replaced diamond-isometric physics with an orthogonal gameplay plane. Its stated intent explicitly preserved the look — "the art may look isometric" — and that intent was correct: flat-plane logic, simple navigation, and simple depth ordering are real wins and none of them require flat art.
2. **ADR 0004** chose a "clean-painted" style whose only existing implementation is programmatic flat-color rendering: `map_visual_style.gd` maps every terrain and role to a single `Color`, and the terrain/building/prop renderers draw untextured rectangles and polygons. The result on screen is a top-down colored-rectangle diagram, not a three-quarter painted town.

Two production constraints shape the replacement:

- **Everything must stay AI-generateable and fast to generate.** Maps are already LLM-authorable declarative definitions (`scripts/map/definitions/`, contract-tested, deterministic fingerprints); there is no artist on the team, and asset iteration must take minutes-to-hours, not days.
- **Sprite pipelines already failed here on animation and scaling.** The original prototype's AI-sprite approach hit exactly the classic problems: keeping character animation frames consistent across directions, and keeping scale/perspective consistent between independently generated assets. A sprite-based plan (whether image-model sheets or 3D-prerendered sheets) re-enters that failure mode and puts image generation in the critical path of every animation.

## Decision

Adopt a **programmatic 3D isometric presentation**: real runtime 3D geometry generated from the existing map definitions, viewed through a fixed orthographic dimetric camera, surfaced with AI-generated material textures, and graded to the target mood in post. "Fallout-looking" remains the reference bar; the geometry and animation are code, and image models are used only where they are reliable and consistency-free — seamless material textures and portraits.

1. **Logic layer is kept unchanged.** Declarative map definitions, anchors, footprints, collision, navigation, activation guards, and fingerprints remain the single source of truth, simulated on the flat orthogonal plane (ADR 0002 core, reaffirmed). The 3D scene is a pure view layer: a deterministic bridge maps logic coordinates `(x, y)` to world `(x, 0, z)` and synchronizes actor positions from the logic simulation. All existing map contracts and tests remain valid; this decision changes rendering only.
2. **Geometry is generated, not modeled.** A mesh builder converts definition data to 3D at load time: building footprints plus per-type height rules become wall prisms and gabled roofs; terrain cells become a ground plane with per-material regions; props come from a small library of parametric primitives (barrel, cart, well, anvil, hay). Adding a building type is a code change plus a texture, not an asset commission — LLM-authorable end to end.
3. **Camera is fixed orthographic dimetric.** Classic isometric framing (yaw 45°, pitch ~30°, orthographic size frozen in ART_BIBLE v2). No player camera rotation in the slice; the fixed angle is what lets facades, roof mass, and depth read the way the vision image does.
4. **Surfaces use AI-generated seamless material textures under a style-lock kit.** Stone, lime plaster, timber, roof tile, mud, cobble, hay, water — each an independent tileable texture, the one asset class image models generate reliably with no cross-asset consistency problem. The kit freezes palette and material families (carried from the current ART_BIBLE), texture density rules, prompt block, and acceptance rubric; every texture gets a SOURCES.csv provenance row. Procedural noise materials are the placeholder fallback so the renderer never blocks on generation.
5. **Characters are shared low-poly rigs with retargeted animations — no sprites.** One humanoid rig; animations come from a retarget library (Mixamo-class or equivalent), so a new animation is a retarget-and-trim, not a redraw or regeneration. Characters rotate freely, which deletes the direction-count question entirely: the four-direction cap from ADR 0002 is lifted because facing is now a transform. Per-character identity comes from palette/texture swaps, equipment meshes, and silhouette-level shape changes. This directly resolves the recorded animation and scaling failures of the sprite prototype: one rig scales globally, and consistency is structural rather than prompt-enforced.
6. **Lighting and day/night are real.** One sun `DirectionalLight3D` plus ambient; buildings and characters cast real shadows. Night is a deterministic light-angle/color change preserving the existing ART_BIBLE night rules (≥20% darker, terrain identities preserved, warm emissive windows). No per-phase asset regeneration.
7. **The Fallout mood comes from a frozen post-process grade.** Desaturated Baltic palette grade, soft outline or edge darkening, film grain, and vignette, specified in ART_BIBLE v2 and applied uniformly so programmatic geometry reads gritty rather than toy-like.
8. **Generation speed is a hard requirement with a budget.** A new NPC variant with the core animation set in under one working day; a single new animation in under one hour; a new building type (parametric rule plus texture) in under one working day — all measured end to end including retries, and enforced at the P0-037/P0-038 gates. Any pipeline element that misses the budget is replaced or cut, not tolerated.

## Alternatives

- **Keep clean-painted flat rendering (ADR 0004).** Rejected. The on-screen result reads as a placeholder diagram; it fails the product's own value-hierarchy goals and contradicts the published vision image.
- **AI-generated painted isometric sprites/plates (previous draft of this ADR).** Rejected as primary path. Closest to the painted vision image, but it puts image generation in the critical path of every asset and every animation, and the project already experienced its failure mode: cross-direction animation drift and inter-asset scale inconsistency. Baked AI-painted plates remain permitted for stateless one-off backdrops (for example event vignettes) where nothing animates.
- **2D polygon pseudo-3D (extruded prisms drawn in the current 2D renderer).** Rejected. Cheaper to start but caps at a clean vector look, re-solves lighting/shadow/occlusion by hand, and still needs a separate sprite solution for characters — reinheriting the animation problem the 3D view removes.
- **Return to diamond-isometric physics.** Rejected. The orthogonal logic plane is proven, tested, and invisible to players.
- **Free-camera full 3D game.** Rejected. The fixed orthographic camera is the point: it preserves the isometric-RPG identity, keeps geometry demands low (only three faces of anything are ever seen), and keeps the mesh builder simple.

## Consequences

- ADR 0004 is superseded; the clean-painted flat-color profiles in `map_visual_style.gd` become comparison evidence and are replaced by the 3D view layer (P0-052).
- `docs/ART_BIBLE.md` scale, pivot, value-hierarchy, shadow, and night-grade rules carry forward into ART_BIBLE v2, restated for the 3D camera (character height in world units at frozen ortho size, light angles, grade parameters); its flat-color sections are historical evidence only.
- P0-051 becomes the material style-lock kit, P0-052 the 3D view layer, P0-053 the slice texture/prop kit; P0-037 is reframed from cutout rig to the shared low-poly rig and retarget pipeline with the speed budget above; P0-038/P0-039 measure performance and readability of the 3D candidate; P0-040 remains the human decision gate.
- Existing map definitions, catalogs, activation guards, prototypes, and their tests continue to pass unmodified; the view-layer swap must not change any fingerprint.
- Godot 4.7 GL Compatibility renders 3D; if slice scenes miss frame-time budgets on minimum hardware, P0-038 escalates renderer settings (or renderer choice) before any art rework.
- Risk: low-poly characters read as toy-like. Mitigated by the post grade, silhouette rules, and the P0-039 blind readability test.
- Risk: model/tool churn in texture generation. The kit records model, version, and full generation parameters per texture in SOURCES.csv so any texture can be regenerated or matched later.
