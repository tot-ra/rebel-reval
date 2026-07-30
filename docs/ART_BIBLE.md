# Art Bible v2

**Status:** Normative visual direction; technical production freeze remains gated by P0-038 / P0-040
**Art-direction approval:** [ADR 0018](adr/0018-saturated-hdr-fantasy-anime-visual-direction.md), maintainer-directed 2026-07-30
**Technical foundation:** [ADR 0007](adr/0007-ai-generated-isometric-presentation.md), [ADR 0015](adr/0015-default-third-person-camera.md), [ADR 0016](adr/0016-tiered-character-fidelity.md)
**Material lock:** [`MATERIAL_STYLE_LOCK_KIT.md`](MATERIAL_STYLE_LOCK_KIT.md) (`style-lock-v1.1`)

This document is binding for new art decisions. It replaces the pale/desaturated clean-painted and Fallout-grade targets retained in P0-036 evidence. Existing accepted assets are migration inputs, not the color or detail ceiling for new work.

## Direction in one sentence

**Historically grounded 1343 Reval, presented as a highly detailed, color-saturated fantasy/anime period drama with painterly PBR materials, expressive silhouettes, and HDR-range cinematic lighting.**

Historical grounding controls what exists, how it is built, worn, carried, and used. Stylization controls color, shape emphasis, facial expression, material response, effects, and dramatic composition. Fantasy treatment never licenses an anachronistic object, building, costume, creature, or magical effect without research/canon authorization.

## Production foundation

- Engine: Godot 4.7; current renderer: GL Compatibility.
- Default view: perspective over-the-shoulder third person per ADR 0015.
- Alternate views: first person and orthographic top-down.
- World logic: deterministic orthogonal plane; rendering does not change map fingerprints, collision, navigation, or interactions.
- Asset language: programmatic/generated 3D geometry, tiered shared-rig characters, painterly PBR surfaces, authored light and VFX.
- Negative constraints: no photoreal photographic noise, pale/desaturated global wash, universal black cel outlines, plastic gloss, uncontrolled bloom, generic neon fantasy, or restored frame-by-frame sprite pipeline.

## Historical truth and stylization boundary

### Must remain evidence-led

- footprints, street widths, landmark massing, construction systems, and roof forms;
- garment cuts, armor coverage, tools, furniture, trade goods, material availability, and wear patterns;
- fauna anatomy, husbandry, vegetation, weather, social status, and occupation cues;
- canon labels for attested, plausible composite, folklore, and invented content.

### May be authorially stylized

- slightly heroic proportions and clearer facial features within rig compatibility;
- grouped hair, cloth folds, and material planes that read at gameplay distance;
- selective edge/rim accents, painterly gradients, colored shadows, and luminous highlights;
- stronger faction color identity and expressive poses;
- heightened VFX only where gameplay and canon authorize the underlying event.

## Saturated Baltic fantasy palette

Values are sRGB albedo or UI reference masters, not emitted light values. PBR lighting and AgX tonemapping produce the final image. Variants may move in hue and value, but must remain inside their material family and preserve the value hierarchy.

### Environment families

| Family | Master | Supporting range | Use |
|---|---|---|---|
| Moss/grass | `#4F954F` | pine `#277052`, spring `#72AF4E` | vegetation, damp edges, rural ground |
| Amber earth | `#9A5A3F` | umber `#663B38`, ochre `#C9873D` | dirt, mud, worn yards |
| Harvest gold | `#E3B83F` | straw `#C99732`, sunlit `#F2CE62` | hay, thatch, warm material accents |
| Baltic water | `#168FAA` | deep teal `#14617C`, cyan `#46C7D8` | water, glazed cool accents, reflected sky |
| Limestone blue-gray | `#9EADB9` | shadow `#667889`, light `#C8D1D3` | stone, cobble, cool structural neutrals |
| Warm lime ivory | `#E7C98E` | shade `#B89B73`, light `#F3DFB3` | lime plaster and parchment-like surfaces |
| Oak/bark | `#6B3F35` | tar `#342B30`, cut wood `#A2693F` | timber, doors, furniture |
| Oxide roof red | `#B94A3D` | brick `#8E3837`, sunlit `#D76643` | tile, painted shields, controlled architecture accent |

### Characters, interactables, and light

| Role | Master | Rule |
|---|---|---|
| Deep separation | `#171B2A` | colored near-black, never unrestricted pure-black contouring |
| Hero crimson | `#D9364D` | Kalev/mobile focal accent; reserve for priority reads |
| Rebel indigo | `#4052B5` | cool faction/narrative counter-accent |
| Forge amber | `#F0A13E` | hot metal, fire-adjacent focus, interactable warmth |
| Moon cyan | `#58C7E8` | moon edges and selective supernatural/cold focus |
| Iron blue | `#394C65` | forged iron and cool equipment neutral |
| Copper/brass | `#C98235` | status, inventory frames, civic and craft accents |
| Fire core | `#FFD27A` | HDR-range emissive core; not an albedo paint color |

Skin, hair, eyes, and cloth require authored ranges rather than one universal master. Preserve regionally plausible diversity and material identity. Do not increase saturation by turning every skin tone orange or every garment into a faction color.

## Color scripting

- Saturation is **selective, not uniform**. Characters, interactables, banners, flowers, water highlights, and story lighting may reach the highest chroma.
- Large ground and wall fields use colorful mid-chroma variation so focal accents have room to peak.
- Every composed view should establish a warm/cool relationship: for example amber forge against cyan dusk, oxide roofs against moss/cobalt surroundings, or crimson cloth against limestone blue-gray.
- Reserve at least one quiet value/chroma field around the active focal point. High saturation everywhere is equivalent to no emphasis.
- Gameplay states must remain readable by shape and value before hue. Color-blind-safe differences cannot rely on red versus green alone.

## Detail hierarchy

High detail is mandatory in art decisions, but it is budgeted by scale rather than spread as noise.

1. **Macro, silhouette and composition:** rooflines, body gesture, costume mass, prop profile, landmark asymmetry, and large color blocks. Must read in top-down and at distance.
2. **Meso, construction and identity:** beams, masonry courses, garment panels, belts, tool assemblies, hair clumps, cart joinery, cracks, patched plaster, and readable material transitions. Must read in third person.
3. **Micro, close-camera craft:** weave, stitching, pores, carved motifs, hammered metal, tool marks, edge wear, dirt accumulation, tiny chips, and anisotropic hair/cloth response. Must reward first-person/dialogue closeups.

Rules:

- Every hero character, hero prop, and landmark brief must list required macro, meso, and micro features.
- Micro detail comes from geometry only when it changes silhouette or catches light; otherwise use albedo, normal, roughness, AO, decals, or shader variation.
- Detail must be plausible for the material and concentrated around handling, weather exposure, construction joins, and narrative use.
- Mipmaps/LOD must collapse micro detail cleanly. Distant surfaces may not shimmer, alias, or overpower characters.
- Repetition is a defect: break identical wear, hue, roughness, and silhouette rhythms across adjacent assets.

## Anime/fantasy shape and line language

- Favor clean, intentional shape grouping over scanned realism or procedural lumpiness.
- Faces use readable eye/brow/mouth planes and expressive posing without chibi proportions or oversized eyes.
- Hair and cloth use large graphic clumps/folds, then selective strand/weave detail.
- Selective contours and rim light may separate the player, interactables, or magic effects. Do not ink every internal material edge.
- Exaggerate characteristic curves and angles enough to identify occupation, faction, age, and emotional state at gameplay distance.
- Painterly PBR remains the base: stone stays mineral, cloth stays fibrous, metal stays metallic, skin stays skin. Anime influence does not mean flat unlit materials.

## Value and readability hierarchy

From highest gameplay priority to lowest:

1. Player/NPC silhouette and interaction/combat feedback.
2. Interactable props, hazards, and authorized VFX.
3. Doors, passages, route surfaces, and collision boundaries.
4. Landmark/building identity and faction color blocks.
5. Meso material detail.
6. Terrain variation and micro surface detail.

A grayscale/squint pass must preserve tiers 1-3 in day, night, fog, rain, and firelight. Texture marks may not create stronger edge density than the player or current interactable. UI is rendered and graded separately from world bloom.

## HDR-range light and post-process

"HDR" in the current pipeline means scene-referred values above display white, AgX highlight compression, emissive separation, and controlled bloom before SDR output. It does **not** claim HDR10, wide-gamut, or HDR-monitor delivery.

| Pass | Day (noon) | Night (midnight) |
|---|---:|---:|
| Tonemap | AgX, exposure `0.98` | AgX, exposure `0.90` |
| Saturation | `1.20` | `1.14` |
| Contrast | `1.12` | `1.08` |
| Brightness | `1.03` | `0.89` |
| Glow HDR threshold | `1.05` | `1.05` |
| Glow intensity | `0.32` | `0.48` |
| Glow bloom / strength / mix | `0.10` / `1.0` / `0.05` | same |

- Exposed skies, pale plaster, and metal highlights must retain color/texture through AgX rather than clipping to white.
- Bloom belongs to emissive fire, forge heat, windows, wet speculars, rim effects, and authorized magic. Matte walls and UI text must not glow.
- Do not fake the direction with a full-screen saturation overlay. Rich albedos, colored light, roughness response, atmospheric perspective, and local contrast must all contribute.

## Day, night, and weather

- Author one rich day-master asset set. Night is deterministic lighting/post, not separately recolored textures.
- Night remains at least 20 percent darker than day while retaining local hue identity.
- Shadows shift toward indigo/cobalt; moon edges may use cyan; fire and windows remain amber/gold.
- Overcast and fog compress contrast and chroma locally, but may not return the whole game to a permanent gray wash.
- Rain deepens albedo and increases selective wet highlights. Snow, lightning, sunrise, and sunset must use authored color scripts rather than neutral exposure changes alone.
- Gameplay prompts, silhouettes, routes, and hazards remain above background value noise in every phase.

## Medieval Reval shape language

- Lower Town buildings use compact gables, lime plaster, visible timber or plank structure where sourced, small openings, dark doors, and period roof materials.
- Saturated color comes from light, weathered pigments, cloth, plants, water, and material response, not unsupported modern paint coverage.
- Stone landmarks use regionally plausible limestone construction with individually authored massing and meso detail; exceptional buildings are not scaled-up ordinary houses.
- Props prioritize silhouette recognition first, functional construction second, and close-camera craft third.
- Architecture may exaggerate facade visibility and characteristic roof rhythm for gameplay cameras, but footprints, street widths, and access remain historically and mechanically grounded.

## Character fidelity tiers

All tiers share one skeleton and animation library. The tier determines the maximum budget and required visible detail, not whether the art direction applies.

| Tier | Triangle cap | Texture cap | Required read |
|---:|---:|---:|---|
| 0 Hero | 60,000 | 2048 px | expressive face/hands, authored hair, material-specific PBR, macro/meso/micro costume story |
| 1 Named NPC | 56,000 | 1024 px | distinctive face/silhouette, occupation/status detail, shared but tuned PBR zones |
| 2 Crowd/battle | 12,000 | 512 px | strong palette/silhouette variation, simplified lit materials, clean LOD/instancing |

Performance caps in `tools/character_fidelity_tiers.py` remain binding. High detail means intentional information at the correct tier, not exceeding those caps.

## Approval and migration

The maintainer's saturated HDR-range fantasy/anime decision is accepted through ADR 0018. P0-038 and P0-040 still govern the final technical production freeze for renderer/camera/scale/performance values. Until that gate closes:

1. New art briefs and generated candidates use this v2 direction and `style-lock-v1.1`.
2. Existing production assets are not mass-invalidated or mass-regenerated.
3. Player-visible hero assets and locations migrate opportunistically when a scoped task already revises them.
4. Captures must prove value readability, controlled highlights, material identity, and macro/meso/micro detail at the relevant camera distances.
