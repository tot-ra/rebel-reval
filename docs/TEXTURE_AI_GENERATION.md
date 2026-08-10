# PBR Texture Generation (P0-130)

**Date:** 2026-07-29
**Author:** AI assistant (Leonardo AI pipeline)
**Authority:** [MATERIAL_STYLE_LOCK_KIT.md](MATERIAL_STYLE_LOCK_KIT.md), [ADR 0007](adr/0007-ai-generated-isometric-presentation.md)

## Overview

This document records the AI-generated PBR texture sets for the primary Reval 1343
environment materials. Each material family receives three maps: albedo, normal, and
roughness, replacing the albedo-only placeholders in `assets/materials/style_lock/`.

The PBR textures live under `assets/materials/pbr/<family>/` with the naming convention:
```
<family>_albedo.png    - base color / diffuse
<family>_normal.png    - tangent-space normal map
<family>_roughness.png - per-pixel roughness (grayscale)
```

## Material families

| Family | Description | Typical surfaces |
|--------|-------------|------------------|
| `stone` | Cut limestone ashlar | Enclosure walls, well ring, furnace mass, stair treads |
| `plaster` | Lime plaster infill | House wall infill, rendered surfaces |
| `timber` | Aged structural timber | Frame beams, posts, table legs, chest trim |
| `hay` | Dry straw / thatch | Thatch roofing, hay stacks, field stubble |
| `roof_tile` | Clay roof shingles | Gabled roofs, well canopy |
| `cobble` | Cobblestone paving | Streets, stable lanes |

## Generation pipeline

1. **Source:** Leonardo AI "Lucid Realism" model, 1024x1024 output
2. **Prompts:** Crafted for seamless tileable medieval materials with period-appropriate wear
3. **Post-processing:** `tools/apply_pbr_textures.py` converts JPG to 512x512 PNG using Pillow Lanczos resampling
4. **Output:** Stored in `assets/materials/pbr/<family>/`
5. **Provenance:** Every texture receives an `assets/SOURCES.csv` row under `assets.materials.pbr.<family>.<map_type>`

## Generation log

### Stone (limestone ashlar)

**Albedo prompt:**
> Seamless tileable medieval limestone wall texture, cut ashlar blocks, light grey stone
> with subtle mortar joints, weathered surface, PBR albedo map, photorealistic,
> top-down view, 512x512 tileable pattern

**Normal prompt:**
> Seamless tileable limestone wall normal map, flat tangent-space normal map for cut
> ashlar stone blocks with mortar joints, blue-purple normal map colors, PBR normal map
> texture, top-down view, 512x512 tileable

**Roughness prompt:**
> Seamless tileable limestone roughness map, grayscale texture, white rough areas for
> mortar joints and darker smoother areas for stone faces, PBR roughness map, top-down
> view, 512x512 tileable

**Leonardo generation IDs:** 72c9eec1, 51b612ce, 6ea9567a

### Plaster (lime plaster)

**Albedo prompt:**
> Seamless tileable lime plaster wall texture, warm beige cream color, slightly rough
> surface with subtle cracks and aging, medieval building material, PBR albedo map,
> photorealistic, top-down view, 512x512 tileable pattern

**Normal prompt:**
> Seamless tileable lime plaster wall normal map, flat tangent-space normal map for
> rough plaster surface with subtle cracks, blue-purple normal map colors, PBR normal
> map texture, top-down view, 512x512 tileable

### Runtime terrain albedo pass (2026-08-07)

- Smithy-floor candidate: `3713e478-8edb-4e36-87c1-88a14fce5b24`, selected image `1`, installed at `assets/materials/pbr/smithy_floor/smithy_floor_albedo.png`. The prompt requests irregular hand-laid Baltic flagstones, soot-darkened joints, worn centers, and no brick courses or regular grid.
- The existing procedural `stone` layer was producing a regular ashlar/brick-like grid on the forge floor. The new source is wired only to `TERRAIN_STONE` in the terrain texture array; wall and furnace materials remain unchanged.
- All runtime terrain albedos are resized to the existing 128px texture-array tier. The processor phase-shifts the 1024px source, welds both wrapping edges, and writes a 512x512 RGB PNG.

### Runtime terrain albedo pass (2026-08-06)

- Grass candidate: `76bae8e4-00a6-406f-9471-5f8133eca660`, selected image `-1`, installed at `assets/materials/pbr/grass/grass_albedo.png`. The first grass generation was rejected for a yellow/dry cast and is not wired.
- Timber-floor candidate: `85f90518-4e44-4457-aa49-bc744568f807`, selected image `-1`, installed at `assets/materials/pbr/timber_floor/timber_floor_albedo.png`.
- The prompts use the shared v1.1 style block and explicitly request a neutral top-down material plate with no baked lighting, scene, horizon, or figures. `tools/process_leonardo_terrain_textures.py` resizes each output to 512x512 and welds the wrapping edges.
- The runtime keeps the existing 128px texture-array budget. The smithy floor RGB albedo backs `TERRAIN_STONE`; grass and timber-floor RGB albedos back their existing layers, preserve authored color in the terrain shader, and receive only a restrained family tint. Procedural grayscale fallback remains for all other terrain layers.

**Roughness prompt:**
> Seamless tileable lime plaster roughness map, grayscale texture, medium grey with
> subtle variations for rough plaster surface, PBR roughness map, top-down view,
> 512x512 tileable

**Leonardo generation IDs:** a1dee551, 4161e9fa, c74dc4bc

### Timber (aged structural wood)

**Albedo prompt:**
> Seamless tileable aged timber wood texture, dark brown structural beam surface,
> visible grain and knots, medieval construction wood, PBR albedo map, photorealistic,
> top-down view, 512x512 tileable pattern

**Normal prompt:**
> Seamless tileable aged timber wood normal map, flat tangent-space normal map for wood
> grain and knots, blue-purple normal map colors, PBR normal map texture, top-down view,
> 512x512 tileable

**Roughness prompt:**
> Seamless tileable timber wood roughness map, grayscale texture, varied grey levels
> following wood grain pattern, PBR roughness map, top-down view, 512x512 tileable

**Leonardo generation IDs:** e42db7c1, 10b58670, 5e4dd896

### Hay (thatch / straw)

**Albedo prompt:**
> Seamless tileable dry straw hay thatch roofing texture, golden brown bundled reeds,
> medieval roof material, PBR albedo map, photorealistic, top-down view, 512x512
> tileable pattern

**Normal prompt:**
> Seamless tileable straw hay thatch normal map, flat tangent-space normal map for
> bundled reed thatch roofing, blue-purple normal map colors, PBR normal map texture,
> top-down view, 512x512 tileable

**Roughness prompt:**
> Seamless tileable straw hay thatch roughness map, grayscale texture, very bright rough
> surface for dry straw fibers, PBR roughness map, top-down view, 512x512 tileable

**Leonardo generation IDs:** e1debaf4, 02e14313, a8a8db92

### Roof tile (clay shingles)

**Albedo prompt:**
> Seamless tileable medieval clay roof shingle texture, dark red-brown curved tiles
> overlapping, weathered ceramic surface, PBR albedo map, photorealistic, top-down view,
> 512x512 tileable pattern

**Normal prompt:**
> Seamless tileable clay roof shingle normal map, flat tangent-space normal map for
> overlapping curved ceramic tiles, blue-purple normal map colors, PBR normal map
> texture, top-down view, 512x512 tileable

**Roughness prompt:**
> Seamless tileable clay roof shingle roughness map, grayscale texture, medium-dark grey
> for fired ceramic with slight glossy highlights on edges, PBR roughness map, top-down
> view, 512x512 tileable

**Leonardo generation IDs:** 9c66006f, a0a3a1c9, 40e9e3ac

### Cobble (cobblestone paving)

**Albedo prompt:**
> Seamless tileable medieval cobblestone street texture, irregular grey stone blocks
> with dirt and moss in gaps, worn surface, PBR albedo map, photorealistic, top-down
> view, 512x512 tileable pattern

**Normal prompt:**
> Seamless tileable cobblestone street normal map, flat tangent-space normal map for
> irregular stone blocks with gaps, blue-purple normal map colors, PBR normal map
> texture, top-down view, 512x512 tileable

**Roughness prompt:**
> Seamless tileable cobblestone roughness map, grayscale texture, varied grey levels with
> darker smooth worn stone tops and lighter rough gaps, PBR roughness map, top-down view,
> 512x512 tileable

**Leonardo generation IDs:** 1c85cef0, 151628c8, 3ca9a967

## Runtime integration

The complete PBR sets under `assets/materials/pbr/` remain source/reference material for
future family-by-family migration. This pass wires three selected Leonardo albedo plates into
the existing runtime terrain texture array: `grass/grass_albedo.png` backs grass, meadow,
forest-floor, and bog layers; `timber_floor/timber_floor_albedo.png` backs timber floors;
`smithy_floor/smithy_floor_albedo.png` backs the irregular flagstone `stone` layer used by
Kalev's forge. They are resized to the existing 128px terrain tier at load time, while the
terrain shader preserves their RGB albedo and applies only a restrained palette tint. All
other terrain layers retain the procedural grayscale fallback until a scoped visual pass
approves their replacement.

The existing `style_lock/` albedo-only textures are retained as reference material for
the style-lock kit verification pipeline.

## Verification

```bash
# Check PBR texture presence and dimensions
python3 tools/verify_pbr_textures.py

# Check style-lock albedo references still pass
python3 tools/verify_slice_surface_assets.py

# Full asset lint (style-lock + characters)
python3 tools/verify_asset_lint.py
```

## Style consistency notes

- All albedo maps maintain the master hex palette from `MATERIAL_STYLE_LOCK_KIT.md`
- Stone targets `#919189`, plaster targets `#CDB892`, timber targets `#53372A`
- Normal maps use standard tangent-space encoding (R=X, G=Y, B=Z up-facing flat)
- Roughness maps use linear grayscale (white=rough, black=smooth)
- All textures are 512x512 PNG, matching the existing kit resolution
