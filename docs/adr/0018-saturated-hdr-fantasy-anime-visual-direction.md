# ADR 0018: Saturated HDR-range fantasy/anime visual direction

**Recorded:** 2026-07-30
**Status:** Accepted (maintainer-directed)
**Amends:** [ADR 0007](0007-ai-generated-isometric-presentation.md), [ADR 0016](0016-tiered-character-fidelity.md), [`ART_BIBLE.md`](../ART_BIBLE.md), and [`MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md)

## Context

The production renderer, PBR pipeline, and historically researched environment are strong foundations, but the inherited Fallout-style desaturated grade and pale material masters make the game read flatter and less distinctive than intended. The maintainer has directed the project away from a realistic/pale presentation and toward a more color-saturated, HDR-range, high-detail fantasy/anime presentation.

This is a change in visual treatment, not permission to discard the historical evidence behind Reval in 1343. Architecture, clothing construction, tools, fauna anatomy, street topology, social status cues, and material use still follow research and canon labels. Stylization governs shape emphasis, color scripting, lighting, surface finish, effects, and emotional staging.

## Decision

1. **Use historically grounded forms with an authored fantasy/anime finish.** Proportions, silhouettes, poses, facial readability, hair grouping, cloth folds, material planes, and VFX may be deliberately expressive. Do not add unsupported plate armor, towers, ornaments, creatures, or magical effects merely to make a scene feel more fantastic.
2. **Replace the pale/desaturated master with controlled high chroma.** Environment families use richer moss greens, oxide reds, amber ochres, Baltic cyan/blue, warm ivory, and colored shadow neutrals. Hero characters, interactables, faction accents, and narrative lighting receive the strongest chroma. Saturation may not flatten the value hierarchy or make every surface equally loud.
3. **Use a three-scale detail hierarchy.** Macro detail establishes silhouette and landmark mass, meso detail communicates construction and material identity, and micro detail supplies close-camera craft such as seams, grain, tool marks, edge wear, pores, and engraved motifs. Micro detail must resolve through mipmaps and never turn distant views into noise.
4. **Render through an HDR-range internal lighting pipeline.** Scene lighting and emissive materials may exceed display white, then pass through AgX tonemapping with controlled bloom and highlight roll-off. This creates an HDR-like image on the current SDR/GL Compatibility output. It is not a claim of HDR10, wide-gamut, or HDR-display delivery; those require a later renderer/platform decision.
5. **Keep night colorful.** Night remains at least 20 percent darker than day, but retains cobalt/indigo shadows, cyan moon edges, warm amber fire, and readable local color. Weather can compress contrast and chroma temporarily, but the global art direction is not gray or washed out.
6. **Treat anime/fantasy as a presentation language, not a universal cel shader.** Use clear shape grouping, expressive silhouettes and faces, selective contour/rim accents, luminous focal effects, and painterly PBR surfaces. Avoid full-surface black outlines, plastic gloss, uncontrolled bloom, neon-everywhere color, generic mobile-game gradients, and photoreal photographic noise.
7. **Preserve gameplay readability and accessibility.** Player, NPC, interaction, routes, and hazards must remain distinguishable by value and shape before hue. Never encode gameplay state through saturation alone. UI is graded separately and must not bloom or lose text contrast.
8. **Apply the lock to all new art decisions.** New materials, characters, props, fauna, portraits, icons, VFX, lighting, and marketing captures use `style-lock-v1.1`. Existing accepted assets are not automatically invalidated, but player-visible hero assets and locations should migrate when they are next revised.

## Superseded direction

This ADR replaces the following presentation requirements while preserving the technical architecture around them:

- ADR 0007's Fallout-looking reference bar and mandatory desaturated Baltic post-grade;
- `style-lock-v1.0` prompt language requiring a desaturated earthy palette and restrained detail;
- the visual-fidelity target of naturalistic realism as the final appearance.

Programmatic 3D generation, the flat deterministic logic plane, shared rig and animation library, tiered performance budgets, AI provenance, real PBR lighting, day/night simulation, and historically grounded production briefs remain in force.

## Consequences

- `ART_BIBLE.md` becomes the normative v2 draft for color, lighting, detail, and readability while the broader P0-040 technical approval gate remains open on P0-038.
- `MATERIAL_STYLE_LOCK_KIT.md` advances to `style-lock-v1.1`; v1.0 sample textures remain migration evidence rather than current color targets.
- The runtime post-grade increases saturation and contrast and lowers the glow threshold while retaining AgX and the day/night luminance contract.
- The visual-fidelity plan prioritizes authored detail and stylized PBR response, not photoreal simulation.
- Literal magic, supernatural VFX, and invented motifs still require content authorization and canon labeling under ADR 0017.

## Rejected alternatives

- **Increase saturation globally and change nothing else.** Rejected because a scalar boost cannot create a coherent palette, detail hierarchy, expressive shape language, or safe highlights.
- **Adopt unrestricted anime cel shading.** Rejected because one shader treatment would erase weathered material identity and conflict with the existing PBR asset investment.
- **Abandon historical constraints for generic high fantasy.** Rejected because researched 1343 Reval is a core product identity.
- **Claim full HDR display support now.** Rejected because the current GL Compatibility/SDR output has not established an HDR10 or wide-gamut platform contract.
