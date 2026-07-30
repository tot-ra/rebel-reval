# Material style-lock kit (P0-051)

**Kit version:** `style-lock-v1.1`
**Recorded:** 2026-07-30
**Authority:** [ADR 0018](adr/0018-saturated-hdr-fantasy-anime-visual-direction.md)
**Palette and detail source:** [ART_BIBLE.md](ART_BIBLE.md)
**Legacy reference samples:** `assets/materials/style_lock/*.png` (`style-lock-v1.0`, migration evidence only)

This kit defines coherent environment material generation for the saturated, painterly PBR presentation. It replaces the v1.0 requirement for a desaturated earthy palette and restrained micro-detail. Existing v1.0 textures remain valid until a scoped asset pass revises them; new material decisions and regenerated hero surfaces use v1.1.

## Material families

| ID | Master | Supporting range | Typical surfaces |
|---|---|---|---|
| `stone` | `#9EADB9` | shadow `#667889`, light `#C8D1D3` | limestone walls, wells, furnace mass, stair treads |
| `plaster` | `#E7C98E` | shade `#B89B73`, light `#F3DFB3` | lime plaster, rendered infill, pale interior surfaces |
| `timber` | `#6B3F35` | tar `#342B30`, cut `#A2693F` | beams, posts, doors, furniture |
| `roof_tile` | `#B94A3D` | brick `#8E3837`, sunlit `#D76643` | clay tile and controlled oxide-red architecture accents |
| `mud` | `#9A5A3F` | umber `#663B38`, ochre `#C9873D` | yards, paths, drainage edges |
| `cobble` | `#7F91A1` | deep `#586979`, pale `#AEBBC2` | streets, lanes, stable approaches |
| `hay` | `#E3B83F` | straw `#C99732`, sunlit `#F2CE62` | hay, thatch, harvest material accents |
| `water` | `#168FAA` | deep teal `#14617C`, cyan `#46C7D8` | wells, cisterns, channels, coast and reflected sky |

The master is an identity anchor, not a flat fill. Each albedo needs hue, value, and wear variation inside its range. Character/faction accents such as hero crimson `#D9364D`, rebel indigo `#4052B5`, forge amber `#F0A13E`, and moon cyan `#58C7E8` remain focal colors and must not be tiled uniformly across architecture.

## Texture sets, density, and format

New hero-visible material sets should provide albedo, tangent-space normal, roughness, and AO or ORM where the runtime path supports them. An albedo-only set is a placeholder, not a v1.1 fidelity target.

| Rule | Value |
|---|---|
| Source generation | 2048 x 2048 preferred for hero/landmark materials; 1024 x 1024 minimum |
| Runtime environment size | 1024 x 1024 default; 512 x 512 only for distant/crowd-tier surfaces |
| Color | sRGB for albedo; linear data for normal/roughness/AO/ORM |
| Seam | Left/right and top/bottom edges match after acceptance processing |
| Terrain repeat | 1.0 world unit per tile unless the authored material scale says otherwise |
| Vertical surfaces | Preserve believable masonry, board, plaster, or grain scale in world units |
| Filter | Linear with mipmaps and anisotropic filtering where supported |
| Top-down read | Macro hue/value family and meso pattern remain legible without shimmer |
| Third-person read | Construction, wear zones, and material response remain identifiable |
| Close read | Selective micro craft survives without photographic noise or baked lighting |

World scale remains one logic cell per world unit (`MapViewBridge.WORLD_UNITS_PER_CELL`). Texture resolution never authorizes implausibly tiny bricks, grain, straw, or tool marks.

## Three-scale detail contract

Every material brief must name all three levels:

- **Macro:** dominant hue/value family and the large directional breakup visible across a wall, roof, ground patch, or prop.
- **Meso:** construction rhythm and material identity, such as ashlar courses, boards, tile overlaps, straw bundles, puddles, plaster patches, or grain flow.
- **Micro:** close-camera chisel marks, fibers, scratches, pores, edge chips, soot, polish, and roughness variation.

Micro detail must follow handling, gravity, water flow, heat, weather exposure, and joins. Evenly distributed grunge and random high-frequency noise fail the lock. Geometry carries silhouette-changing detail; texture maps carry most surface craft.

## Shared generation prompt block

Prepend this block to every v1.1 albedo or complete-material generation prompt. Keep the intent verbatim even when a model requires shorter phrasing.

```text
Seamless tileable game material for historically grounded Baltic medieval Reval, 1343,
high-detail painterly PBR surface with fantasy/anime art direction, rich controlled saturation,
clear macro color design, readable meso construction, selective close-camera micro craft,
expressive but materially believable, cinematic HDR-range lighting response without baked light,
third-person and top-down readable, no text, no figures, no border, square 1:1 seamless repeat,
value hierarchy below character and interactable silhouettes
```

### Negative prompt

```text
photograph, photogrammetry noise, pale washed-out palette, global desaturation, flat muddy brown,
random uniform grunge, illegible micro-noise, baked shadows, baked highlights, black cel-outline loops,
neon everywhere, plastic gloss, modern material, sci-fi, text, logo, watermark, border, frame,
perspective scene, characters, animals, weapons, duplicate pattern, visible tile seam, clipped highlights
```

Do not put `normal map`, `roughness map`, `ORM`, or `HDR bloom` in a universal negative prompt. Request data maps explicitly when generating them. Bloom is a runtime lighting effect and must not be baked into albedo.

### Recommended generation parameters

| Parameter | Value |
|---|---|
| Source output | 2048 square preferred, 1024 square minimum |
| Seamless/tileable mode | On when available; still verify/weld edges |
| Guidance/CFG | 6-8 |
| Steps | 30-50 |
| Candidate count | 2-4, then curate one; do not ship an unreviewed first sample |
| Downscale | Lanczos; never upscale a low-resolution source into a hero texture |

Record exact model, model version, generation ID/seed, complete prompt, post-processing, and license/provenance in `assets/SOURCES.csv`.

## Per-material prompt additions

Append the relevant block to the shared prompt. Replace `{MASTER}` and supporting values from the family table.

### `stone`

```text
Material: local Baltic limestone masonry, master {MASTER}, cool blue-gray shadow variation,
macro blocks softened by age, meso ashlar or rubble rhythm appropriate to the named structure,
selective micro chisel marks, pale mortar, rain streaks, chips and lichen only where exposure supports them,
mineral matte roughness with restrained wet sparkle, no generic fantasy runes
```

### `plaster`

```text
Material: medieval lime plaster, master {MASTER}, warm ivory with saturated reflected-light color,
macro patch variation, meso hand-troweled and repaired zones around timber or masonry joins,
selective micro brush/trowel marks, hairline cracks and soot; no modern smooth stucco, no uniform beige wash
```

### `timber`

```text
Material: aged oak or named period timber, master {MASTER}, rich brown with cool tar-dark recesses,
macro beam/board direction, meso grain, joints, pegs and hewn facets,
selective micro tool marks, handling polish, splits and damp darkening; no orange plastic wood
```

### `roof_tile`

```text
Material: overlapping clay roof covering, master {MASTER}, vivid oxide red controlled by weathering,
macro warm roof plane, meso row rhythm and replacement-tile variation,
selective micro chips, mineral bloom, soot and moss at plausible drainage zones; no glossy modern ceramic
```

### `mud`

```text
Material: packed courtyard earth and mud, master {MASTER}, rich amber umber with cool wet recesses,
macro traffic/water flow, meso ruts, footprints, straw and compacted patches,
selective micro grit and wet roughness response; no uniform brown noise, no baked puddle reflections
```

### `cobble`

```text
Material: irregular period street stone, master {MASTER}, blue-gray and subtle violet/green mineral variation,
macro route readability, meso fist-sized setts and drainage rhythm,
selective micro chips, mortar, damp edges and wheel polish; no perfectly repeated modern paving grid
```

### `hay`

```text
Material: dry straw and thatch, master {MASTER}, saturated harvest gold with ochre shadow bundles,
macro bundle direction, meso overlapping stalk groups and ties,
selective micro fibers and broken ends; matte, no green lawn blades, no high-frequency fiber static at distance
```

### `water`

```text
Material: Baltic freshwater or named coastal water, master {MASTER}, deep teal body and cyan highlights,
macro depth/current variation, meso ripples shaped by wind and banks,
selective micro sparkle supplied by runtime normal/specular response; no baked sky, foam, shore, or bloom
```

## Runtime color and HDR-range grade

Day master textures are lit in scene-referred HDR range and compressed through AgX. Current GL Compatibility output remains SDR, so this table describes an HDR-like internal response, not HDR10 delivery.

### Day

| Pass | Setting |
|---|---:|
| Exposure | `1.03` |
| Saturation | `1.20` |
| Contrast | `1.12` |
| Brightness | `1.03` |
| Glow threshold | `0.85` |
| Glow intensity | `0.48` |
| Glow bloom / strength / mix | `0.18` / `1.0` / `0.06` |

### Night

| Pass | Setting |
|---|---:|
| Exposure | `0.82` |
| Saturation | `1.08` |
| Contrast | `1.16` |
| Brightness | `0.78` |
| Glow threshold | `0.85` |
| Glow intensity | `0.62` |
| Glow bloom / strength / mix | `0.18` / `1.0` / `0.06` |

Night luminance proxy remains at least 20 percent below day. Preserve cobalt/indigo shadows, cyan moon edges, teal water, and amber fire rather than applying a gray or opaque blue wash. Emissive maps may exceed 1.0 in shader space; albedo maps may not contain painted bloom halos.

## Acceptance rubric

A candidate passes only when every applicable row passes.

| # | Criterion | Pass threshold |
|---|---|---|
| R1 | Historical/material truth | Construction, scale, pattern, and wear match the named period use and research brief |
| R2 | Seamless tiling | 3x3 montage has no visible seam, repeated hero mark, or edge color jump |
| R3 | Palette family | Master and supporting hues read as the specified saturated family after neutral lighting |
| R4 | Macro readability | Material family and route/building role read in top-down view |
| R5 | Meso identity | Construction and wear zones read in third-person view |
| R6 | Micro craft | Close view rewards inspection without photographic noise or uniform grunge |
| R7 | PBR integrity | Albedo has no baked light; normal/roughness/AO contain the correct data semantics |
| R8 | Highlight safety | AgX retains hue/texture in highlights; bloom stays on eligible luminous/specular features |
| R9 | Value hierarchy | Player, interactable, entrances, and hazards remain stronger than surface detail in grayscale |
| R10 | Night identity | Family hue and material identity survive the darker colorful night grade |
| R11 | Mip/LOD stability | No shimmer, moire, or noisy collapse at gameplay distance |
| R12 | Provenance | Complete `assets/SOURCES.csv` record with tool/model/version/ID/prompt/post-process/license |

## Reference and migration

The `assets/materials/style_lock/*.png` contact sheet proves the old v1.0 tiling pipeline but no longer represents target saturation, resolution, PBR completeness, or micro-detail. Do not recolor those files indiscriminately and call them v1.1. Replace a visible family through a scoped task that supplies:

1. neutral-light swatches or a contact sheet;
2. matched day/night gameplay captures;
3. top-down, third-person, and close detail evidence where the asset is visible;
4. provenance and asset-lint results;
5. confirmation that map logic, collision, and fingerprints are unchanged.

## Wiring notes

- Rendering/material changes may not alter map definitions, gameplay logic, collisions, or navigation.
- Use albedo color variation, normals, roughness/AO, decals, and shader response as a coordinated set.
- World UI and screen-space UI must not inherit world bloom.
- Fallback procedural materials should use the v1.1 family masters and remain visibly simpler than production textures.
- If generated output cannot meet both history and style, correct the brief/source or reject it. Do not hide an implausible asset behind saturation and glow.
