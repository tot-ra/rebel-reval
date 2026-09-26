# Art Bible v2

**Status:** Normative visual direction; technical production freeze remains gated by P0-038 / P0-040
**Art-direction approval:** [ADR 0022](adr/0022-realistic-human-characters.md), maintainer-directed 2026-09-26 — realistic, historically accurate (KCD2 / Witcher 3 reference). The saturated fantasy/anime rules below from ADR 0018 (2026-07-30) are superseded wherever they conflict; recalibrating the environment grade toward a naturalistic finish is follow-up work.
**Technical foundation:** [ADR 0007](adr/0007-ai-generated-isometric-presentation.md), [ADR 0015](adr/0015-default-third-person-camera.md), [ADR 0016](adr/0016-tiered-character-fidelity.md)
**Material lock:** [`MATERIAL_STYLE_LOCK_KIT.md`](MATERIAL_STYLE_LOCK_KIT.md) (`style-lock-v1.1`)

This document is binding for new art decisions. It replaces the pale/desaturated clean-painted and Fallout-grade targets retained in P0-036 evidence. Existing accepted assets are migration inputs, not the color or detail ceiling for new work.

## Direction in one sentence

**Historically grounded 1343 Reval, presented as a highly detailed, color-saturated fantasy/anime period drama with painterly PBR materials, expressive silhouettes, and HDR-range cinematic lighting.**

Historical grounding controls what exists, how it is built, worn, carried, and used. Stylization controls color, shape emphasis, facial expression, material response, effects, and dramatic composition. Fantasy treatment never licenses an anachronistic object, building, costume, creature, or magical effect without research/canon authorization.

## Kalev realism exception (P0-210)

Per [ADR 0020](adr/0020-kalev-character-realism.md), the maintainer requests a more realistic main character using The Witcher 3 as a fidelity reference. Kalev uses natural adult facial anatomy, groomed hair, restrained skin tones, and detailed cloth/leather/metal PBR, within the existing hero budget and modular shared-rig contract. This supersedes the anime shape language for Kalev only; it does not change NPC or environment art direction.

## Vegetation realism (P0-208)

Maintainer-directed 2026-09-12: use The Witcher 3 as a reference for natural
vegetation structure, light response and wind. Existing botanical species gain
fine curved grass blades, folded species-shaped leaves, restrained light-driven
translucency and irregular ground-cover patches. Keep the Baltic palette,
authored planting, cached procedural meshes and GL Compatibility renderer.
Original geometry only; this revises existing vegetation presentation without
adding a biome, gameplay mechanic or imported game assets.

## Bird realism (P0-207 / P0-212 / P0-216)

Maintainer-directed September 2026: existing birds move toward natural anatomy
and material detail, with The Witcher 3 as a fidelity reference. The five skinned
birds retain P0-207 assets. All 30 ambient catalogue species use original cached
geometry with continuous torso/neck/skull surfaces, layered feather vanes,
species markings, feet and bills. P0-216 keeps that budget and rig, and replaces
the smooth wing sleeve with overlapping folded vanes, a keeled body, flattened
bills, separated flight primaries and a coarser feather shader. Feather, keratin
and eye response share one lit material; ambient meshes remain below 8,000
triangles. Ecology, stable IDs and world placement are unchanged. This is an
incremental realism pass, not a claim of finished AAA animal fidelity. See the
[catalogue evidence](reports/bird_catalog_realism_2026-09-12.md) and the
[contour pass](reports/bird_model_pass_2026-09-23.md).

## Production foundation

- Engine: Godot 4.7; current renderer: GL Compatibility.
- Default view: perspective over-the-shoulder third person per ADR 0015.
- Alternate views: first person and orthographic top-down.
- World logic: deterministic orthogonal plane; rendering does not change map fingerprints, collision, navigation, or interactions.
- Asset language: programmatic/generated 3D geometry, tiered shared-rig characters, painterly PBR surfaces, authored light and VFX.
- Negative constraints: no photoreal photographic noise, pale/desaturated global wash, universal black cel outlines, plastic gloss, uncontrolled bloom, generic neon fantasy, or restored frame-by-frame sprite pipeline.

## Historical truth and stylization boundary

**Animal revision (P0-209, maintainer-directed 2026-09-12):** mammals move toward
grounded realism, with Witcher 3 as a quality reference for anatomy and material
separation. Use continuous musculature, natural eyes/ears, textured fur or fleece,
and distinct wet nose, horn and hoof response. The previous storybook bead fleece,
cone ears and flat coats are superseded. This species-specific direction does not
change the environment palette or authorize copied game assets. P0-209b replaces the
rejected procedural mammals with credited CC BY 4.0 source surfaces, preserving
actual paws/hooves, coat UVs and species silhouettes. Dogs use a shaggy village
phenotype; do not imply a modern Labrador or an attested medieval breed. See
`assets/storybook/mammal_sources.json` for provenance and source limitations.
The rabbit-derived hare remains a documented species-fidelity limitation.
Live cattle and the pack horse are closed procedural bodies on the existing
livestock rig. Their coats are vertex colors (hooves, horns or mane, muzzle),
because a smart-projected albedo atlas breaks those small regions into dots.
Wild-margin mammals (bear, wolf, lynx, elk) and garden mammals (squirrel,
hedgehog) remain catalog ellipsoids until a replacement production pass lands.
Witcher 3 is the
fidelity reference only; do not copy game assets. The standalone
`medieval_horse.glb` copy is not the live fauna model.

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
| Amber earth | `#9A5A3F` | umber `#663B38`, ochre `#C9873D`, trodden street `#6A6154` | dirt, mud, worn yards |
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

The maintainer-directed sky/weather refinement (**P0-211**, 2026-09-12) uses
The Witcher 3 as an atmospheric realism reference: natural celestial scale,
layered cloud extinction and sun-facing shading, restrained haze, diffuse
overcast illumination and wind-driven rain. This applies to atmospheric
presentation within the existing renderer; retain material color identity and
gameplay readability. Implementation and comparison evidence live in
[`weather_realism_2026-09-12.md`](reports/weather_realism_2026-09-12.md).

- Author one rich day-master asset set. Night is deterministic lighting/post, not separately recolored textures.
- Night remains at least 20 percent darker than day while retaining local hue identity.
- Shadows shift toward indigo/cobalt; moon edges may use cyan; fire and windows remain amber/gold.
- Overcast and fog compress contrast and chroma locally, but may not return the whole game to a permanent gray wash.
- Rain deepens albedo and increases selective wet highlights. Snow, lightning, sunrise, and sunset must use authored color scripts rather than neutral exposure changes alone.
- Gameplay prompts, silhouettes, routes, and hazards remain above background value noise in every phase.

## Baltic water

Open water is a choppy Gerstner surface, not a flat animated normal (**P0-222**).
Three bands stand in for a JONSWAP ocean on the GL Compatibility renderer: swell
and wind waves move vertices, and capillary ripples stay in the detail normal.
Harbor water bobs (high standing-wave ratio, low chop). The open Baltic peaks
harder. Rivers stay a tighter current. Crest height must stay readable from the
gameplay camera (deep water above about 0.1 world units before weather) without
a compute FFT, clipmap ocean, or planar reflection pass. Thin wave crests pick
up a warm-teal subsurface pass (`#168FAA` / `#14617C` family) that troughs do
not share; the glow tracks `day_blend` and the caustic twilight envelope, not a
post bloom. Evidence:
[`water_realism_2026-09-24.md`](reports/water_realism_2026-09-24.md).

## Medieval Reval shape language

- Lower Town buildings use compact gables, lime plaster, visible timber or plank structure where sourced, small openings, dark doors, and period roof materials.
- Saturated color comes from light, weathered pigments, cloth, plants, water, and material response, not unsupported modern paint coverage.
- Stone landmarks use regionally plausible limestone construction with individually authored massing and meso detail; exceptional buildings are not scaled-up ordinary houses.
- Walls, towers and gate jambs are **coursed limestone rubble**: roughly levelled bands of irregular hand-split stone in wide lime mortar, with chipped arrises and varied face tone. Even machine ashlar is wrong for Reval and reads as printed grid at gameplay range.
- Masonry repeats follow physical course heights, not visual busyness. One world unit is about 0.87 m; a split limestone course is about 0.3 m and a hand-moulded brick course about 0.1 m.
- Trodden streets are packed earth over limestone rubble and building waste: grey-ochre with gravel, ruts, drying cracks and damp hollows, never saturated red clay. Paving meets earth on an irregular worn edge, not a cut line.
- Gate passages are vaulted tunnels. A gate opening springs into an arch; a flat lintel over two piers reads as a hole cut in a slab.
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
