# Material style-lock kit (P0-051)

**Kit version:** `style-lock-v1.0`  
**Recorded:** 2026-07-16  
**Authority:** [ADR 0007](adr/0007-ai-generated-isometric-presentation.md)  
**Palette source:** [ART_BIBLE.md](ART_BIBLE.md) (carried forward; flat-color sections remain historical evidence)  
**Sample textures:** `assets/materials/style_lock/*.png`

This kit freezes the eight independent seamless material families for the programmatic 3D isometric presentation. It does **not** wire textures into the renderer (that is P0-053). P0-052 continues on procedural placeholder materials until P0-053 lands.

## Material families

| ID | Master hex | ART_BIBLE role | Typical surfaces |
|---|---|---|---|
| `stone` | `#919189` | Cut stone / terrain stone | Enclosure walls, well ring, furnace mass, stair treads |
| `plaster` | `#CDB892` | Lime plaster | House wall infill, ledger stand, mattress |
| `timber` | `#53372A` | Structural timber | Frame beams, posts, table legs, chest trim |
| `roof_tile` | `#6F3B31` | Roof red-brown | Gabled roofs, well canopy |
| `mud` | `#7C5841` | Dirt / courtyard ground | Unpaved yards, worn paths |
| `cobble` | `#7E7D79` | Cobblestone route | Streets, stable lanes |
| `hay` | `#CDA444` | Hay accent | Hay stacks, stall canopy, pillow fill |
| `water` | `#3A748F` | Water body (`#65B1C4` highlight) | Wells, cisterns, shallow channels |

Accent colors (`#B23D31` cloth, `#EEB15C` warm window light) stay on characters and emissive props only. Do not bake them into terrain or wall albedos.

## Texel density and file format

| Rule | Value |
|---|---:|
| Texture size | 512 x 512 px, sRGB PNG |
| Seam | Left/right and top/bottom edges must match (max channel delta 0 after acceptance weld) |
| Terrain repeat | 1.0 world unit per tile (one logic cell; see `MapViewMeshBuilder` ground UVs) |
| Vertical surfaces | 0.5 world units per tile height on walls; 1.0 world unit per tile width |
| Roof slopes | 1.0 world unit per tile along the slope projection |
| Filter | `TEXTURE_FILTER_LINEAR` with mipmaps enabled in production (P0-053) |
| Target on-screen detail | 6-12 visible texels per 32 logic px at the frozen orthographic size; marks must stay softer than character silhouettes |

World scale: one logic cell equals one world unit (`MapViewBridge.WORLD_UNITS_PER_CELL`).

## Shared texture prompt block

Prepend this block to **every** material prompt. Do not paraphrase; copy verbatim so independent sessions stay aligned.

```text
Seamless tileable game texture, painted Baltic medieval isometric RPG surface,
three-quarter readable at low polygon density, Fallout/Stoneshard mood without photorealism,
hand-painted broad planes with restrained micro-detail, no text, no figures, no hard black outlines,
orthographic-friendly even lighting, sRGB, square 1:1, edge-to-edge seamless repeat,
desaturated earthy palette, value hierarchy below character silhouettes
```

### Negative prompt (append when the tool supports it)

```text
photoreal, PBR ORM pack, normal map, text, logo, watermark, border, frame, perspective scene,
characters, animals, weapons, modern materials, neon, sci-fi, snow, high-gloss plastic, HDR bloom
```

### Recommended generation parameters

| Parameter | Value |
|---|---|
| Output size | 1024 x 1024 (downscale to 512 with Lanczos; never upscale) |
| Seamless / tileable mode | On, when available |
| Guidance / CFG | 6-8 |
| Steps | 28-40 |
| Preferred aspect | 1:1 |

Record the exact model name, version, seed, and full prompt in `assets/SOURCES.csv` for every accepted texture.

## Per-material prompts

Replace `{MASTER}` with the hex from the table above.

### stone

```text
{SHARED_BLOCK}
Material: weathered Baltic limestone ashlar blocks with pale mortar lines,
master color {MASTER}, light neutral cut stone for medieval town walls,
subtle chisel marks, low contrast, few cracks
```

### plaster

```text
{SHARED_BLOCK}
Material: lime plaster infill panels on timber-framed houses,
master color {MASTER}, soft brush streaks, faint lime wash variation, no wood grain
```

### timber

```text
{SHARED_BLOCK}
Material: aged structural oak timber beams and posts,
master color {MASTER}, horizontal grain, occasional knots, matte sawn finish, no paint
```

### roof_tile

```text
{SHARED_BLOCK}
Material: overlapping clay roof tiles on a steep gable,
master color {MASTER}, row offset pattern, dusty surface, subdued red-brown, no sky reflection
```

### mud

```text
{SHARED_BLOCK}
Material: packed courtyard earth and worn dirt,
master color {MASTER}, fine cracks, footprint-scale variation, matte, no grass blades
```

### cobble

```text
{SHARED_BLOCK}
Material: rounded granite cobblestones in gray mortar,
master color {MASTER}, fist-sized stones, irregular but readable at gameplay scale
```

### hay

```text
{SHARED_BLOCK}
Material: dry straw hay bale surface,
master color {MASTER}, parallel straw fibers, warm harvest yellow, matte, no green
```

### water

```text
{SHARED_BLOCK}
Material: still courtyard water surface,
master color {MASTER}, gentle ripple pattern, sparse cool highlights #65B1C4, no foam, no shore
```

## Post-grade specification

Applied uniformly in the 3D view layer (wired in P0-053; parameters freeze in ART_BIBLE v2 at P0-040). Day master textures are graded in post; night does **not** regenerate albedos.

### Day grade (after lighting)

| Pass | Setting |
|---|---|
| Exposure | 1.0 baseline |
| Saturation | 0.82 |
| Contrast | 1.06 |
| Lift (shadow RGB) | `(+0.02, +0.02, +0.03)` |
| Gain (highlight RGB) | `(0.96, 0.95, 0.93)` desaturate warm highlights slightly |
| Color tint | Multiply toward `#E8DFD0` at 8% |
| Edge darkening | Screen-space depth-aware rim, strength 0.18, radius 2 px equivalent |
| Grain | Film grain 4% monochromatic |
| Vignette | Strength 0.12, radius 0.85 |

### Night grade (deterministic light swap + post)

Carry [ART_BIBLE night rules](ART_BIBLE.md#day-and-night-rules) forward:

1. Sun and ambient switch to the frozen `MapView3D` night constants.
2. Non-emissive albedo response: multiply RGB by `(0.43, 0.50, 0.66)`, then blend 20% toward `#19233A`.
3. Water and window emissive highlights: blend 58% toward `#EEB15C`.
4. Overall luminance must be at least 20% darker than the matching day capture while all eight material identities remain distinguishable in a grayscale pass.

No full-screen opaque blue overlay.

## Acceptance rubric

Score each candidate texture **pass/fail** per row. A texture is accepted only when every row passes.

| # | Criterion | Pass threshold |
|---|---|---|
| R1 | Seamless tiling | 3x3 montage shows no visible seam at 100% and 200% zoom |
| R2 | Master hue | Average albedo within Delta E < 12 of the family master hex under sRGB |
| R3 | Detail density | No single mark smaller than 4 px at 512²; nothing reads as noise over character scale |
| R4 | Painted read | Broad planes dominate; no photoreal specular, photograph, or PBR ORM look |
| R5 | Outline discipline | No continuous 1 px black edge loops; separation comes from value, not ink |
| R6 | Value hierarchy | Material contrast lower than interactable prop silhouettes in a squint test |
| R7 | Night identity | After the night grade, blind sorter still groups it with the correct family |
| R8 | Provenance | Complete `assets/SOURCES.csv` row with model, version, seed, and full prompt |
| R9 | Coherence | Two independent sessions using only this kit land in the same blind family group |

## Coherence verification procedure

1. Run two generation sessions on different days or tools, using only the shared block and per-material prompts above.
2. Generate the full set of eight materials in each session.
3. Print a contact sheet: 3x3 tile of each texture at 128 px per tile, labels removed.
4. Ask a reviewer who did not author the kit to sort the sixteen swatches into eight pairs.
5. **Pass:** at least seven of eight families pair correctly; no stone/cobble or plaster/mud confusion.

## Sample textures (reference set)

Accepted reference samples ship in `assets/materials/style_lock/`. They were produced with the palette and density rules above to prove tiling and rubric R1-R6. Production slice surfaces (P0-053) should regenerate via the AI prompt block; keep the reference set for regression until ART_BIBLE v2 approval.

Contact sheet (3x3 tile per material): [`reports/images/p0_051_style_lock_samples.png`](reports/images/p0_051_style_lock_samples.png).

| File | Seed | Notes |
|---|---:|---|
| `stone.png` | 51001 | Ashlar block rhythm |
| `plaster.png` | 51002 | Lime wash streaks |
| `timber.png` | 51003 | Horizontal grain |
| `roof_tile.png` | 51004 | Offset tile rows |
| `mud.png` | 51005 | Packed earth |
| `cobble.png` | 51006 | Rounded setts |
| `hay.png` | 51007 | Straw fibers |
| `water.png` | 51008 | Cool ripple highlights |

## Wiring notes (P0-053)

- Replace `MapViewMaterials` albedo maps only; do not change logic, collision, or fingerprints.
- Terrain uses one material family per `MapTypes` terrain ID mapped in the slice kit table (P0-053).
- Building walls default to `plaster` with `timber` accents; roofs use `roof_tile`; stone caps use `stone`.
- Prop roles in `MapViewMeshBuilder` map: `stone`, `wood`/`timber`, `hay`, `roof`/`roof_tile`, `water_highlight` stays emissive-tinted `water`.

## Versioning

Increment the kit version when any of the following change: master hex values, shared prompt block, per-material prompts, texel density rules, post-grade parameters, or rubric thresholds. Record the version in P0-040 approval and in every new `SOURCES.csv` row (`model_version` field may include `style-lock-vX.Y`).
