# Vegetation realism: grass, grain fields, trees

Status: in progress (epic **R-1319**). Implemented: V0 benchmark and budgets (**R-1320**, section 8), V1 procedural textures (**R-1329**, section 7) and V2 shared wind field (**R-1321**, section 1); every other phase is planned. Scope: a staged upgrade of how grass, grain fields, trees, and shrubs are rendered in the 3D view, so open country and woods read as real Baltic nature. Out of scope: gameplay changes, felling or damaging trees, new biomes, imported game assets, a renderer change (GL Compatibility stays), and anything that changes saved state. This page is the spec to turn into tasks; it extends [`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md) (seasons, crown shader, leaf fall) and the "Vegetation realism (P0-208)" rule in [`ART_BIBLE.md`](../ART_BIBLE.md).

Scope rule: this revises existing vegetation presentation. It adds no mechanic, area, or pillar, so it needs no ADR. A new crop mechanic (planting, harvest as gameplay) would, and is not part of this plan.

## Target look

Two references, deliberately split:

- **Grass and grain fields: Ghost of Tsushima.** Dense fields of individual curved blades, waves of wind that roll across a meadow or a barley field as a visible front, a gold-green gradient from root to tip, the field closing behind the player.
- **Trees: The Witcher 3.** Species-correct silhouettes, trunks that fork and lean like real trees, crowns made of leaf clusters with light coming through them, readable sub-canopy, bark with relief.

Make it ours: Baltic 1343 species only (see [`FLORA_FAUNA.md`](../FLORA_FAUNA.md)), rye, barley, and oats rather than wheat as the field crops, overcast northern light, the existing seasons and weather, and one signature touch tied to the world (NATURAL aspects reacting through the same wind and tint channels, designed later).

Hard constraints: GL Compatibility (no compute shaders, no HDR, lowest colour precision), cached procedural meshes, original geometry only, deterministic output from map seed and tile coordinates, and the asset freeze (P0-040): no new legacy isometric or pixel art.

## What the research says

Confidence is stated because several details come from community reimplementations, not the original slides.

| Source | Technique | Confidence |
|---|---|---|
| Ghost of Tsushima, [GDC "Procedural Grass"](https://gdcvault.com/play/1027214/Advanced-Graphics-Summit-Procedural-Grass) | Each blade is generated on the GPU with its own shape and animation; acres of grass within memory limits | Abstract only; slides not read |
| [GodotGrass](https://github.com/2Retr0/GodotGrass) (MIT; bundled assets CC BY 4.0 and CC0) | Blades bent by height, normals bent horizontally for a round look, darkened base as fake AO, view-space widening of edge-on blades, LOD tiles with per-tile density, cellular noise for clumped height and bend, scrolling noise for wind direction and strength, high-frequency domain warp for tip jitter | Read from the repo; works with `MultiMeshInstance3D`, placement on CPU |
| Ghost of Tsushima, [GDC "Blowing from the West"](https://gdcvault.com/play/1027124/Blowing-from-the-West-Simulating) | Wind is its own system feeding grass, trees, cloth, and particles | Abstract only |
| Horizon Zero Dawn, [vegetation talk summary](https://videohighlight.com/v/wavnKZNSYqU) | SpeedTree assets with a LOD chain ending in cross-plane billboards; placement driven by painted data maps | Secondary summary |
| Witcher 4, [Nanite Foliage](https://dev.epicgames.com/documentation/unreal-engine/nanite-foliage) | Real geometry trees with voxel LOD plus procedural placement | Not usable here (Unreal-only); look target only |
| Godot docs, [visibility ranges](https://docs.godotengine.org/en/4.4/tutorials/3d/visibility_ranges.html) | Alpha-scissor is the cheap foliage mode; self-fade turns objects transparent and costs more | Documentation |

Not found: any Godot add-on that bakes octahedral impostors; a verified description of Breath of the Wild grass. Do not plan around either.

## Open-source reuse decision

| Candidate | Decision | Reason |
|---|---|---|
| GodotGrass | **Reference for technique, do not vendor.** Port the ideas (bent blade, normal bending, tile LOD, cellular clumping) into our scatter pass | Our placement is blueprint-driven and deterministic; its tile logic rebuilds meshes on the CPU as the camera moves, and its LOD pops are called out by its author |
| Terrain3D | **Do not adopt** | We have our own terrain and map pipeline (ADR 0009). Useful as a reference for its 10-level foliage LOD |
| ProtonScatter, Zylann Scatter | **Do not adopt** | Placement must go through `MapBlueprint` and keep stable IDs |
| EZ-Tree port (MIT), Tree3D | **Reference only** | We already generate trees procedurally and cache them. Check their branching and leaf shaders for ideas |
| Blender Sapling (GPL) | **Do not use** | The add-on is GPL; the algorithm behind it (Weber and Penn, "Creation and Rendering of Realistic Trees") is public and can be implemented in GDScript |

If any code or asset is copied from an open-source project, add it to `assets/SOURCES.csv` with its license first.

## Design

### 1. One wind field for everything

Status: implemented (task **R-1321**, VEGR-2). Runtime contract, globals, weather mapping, tests and evidence: [`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md#shared-wind-field-r-1321). Decisions taken in the task: the noise is analytic value noise in `wind_field.gdshaderinc`, not a texture (no sampler slot, no unbound sampler on GLES, exact CPU mirror); the globals are declared in `project.godot` because the wind shaders are preloaded; the front is sampled once per tuft, tree or staff, not per vertex; grass gets a bend sheen so fronts read at distance; the sea keeps its own wind uniforms. Benchmark before and after (`tools/run_performance_report.sh <out> --vegetation`, then `budgets --baseline`): vegetation counts identical on every camera and layer (the change is shader-only; `compare` differs only in Lower Town's non-vegetation `other` layer, from unrelated concurrent work), and the budget check passes. Frame time was noisy because the editor was running a game on the same GPU: `meadow_gameplay` median over three paired runs was 115 / 105 / 130 ms with the old grass and crown shaders and 113 / 127 / 137 ms with the final ones, within run-to-run spread; the other five cameras matched within 3 ms in the full runs. Crowns sample the noise-free `wind_pressure_coarse` (three `sin`, as before) because their vertex cost multiplies by the shadow cascades; grass keeps the patchy front.

The original design, as specified:

A single deterministic wind model drives grass, grain, crowns, cloth, and falling leaves, so a gust crosses a field, reaches the trees, then the flags.

- **Data:** a seamless-tiling scrolling noise texture plus a few global parameters (direction, base speed, gust amplitude, gust wavelength, turbulence), pushed once per frame through Godot global shader parameters (`RenderingServer.global_shader_parameter_set`), not per-material uniforms. Confirm in a spike that global uniforms behave in Compatibility before committing.
- **Gusts as fronts:** wind phase is `dot(world_xz, wind_dir) * k - time * speed`, sampled at two scales, so the bend travels as a visible wave (the Tsushima field look) instead of each blade swaying on its own.
- **Weather link:** wind direction, strength, and gustiness come from the existing weather state ([`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md)); calm days nearly stop the wave, storms raise amplitude and turbulence.
- **Migration:** `map_view_wind_materials.gd` becomes the single writer. `map_view_grass.gdshader` and `map_view_canopy.gdshader` read the globals instead of their own `wind_*` uniforms. Keep the old uniforms working until every consumer is migrated, then remove them.

### 2. Grass: three tiers

| Tier | Range (starting values, tune by measurement) | Representation |
|---|---|---|
| Near | 0 to about 12 m | Individual blades: a 7-vertex tapered, curved strip per blade (about 5 triangles), 3 to 5 blades per clump, MultiMesh |
| Mid | about 12 to 45 m | The existing cross-card tufts, tinted to match the near tier at the seam |
| Far | beyond about 45 m | No instances. The terrain's grass colour carries it, with a macro noise variation baked into the ground shader |

- **Blade shading (from GodotGrass and the Tsushima technique list):** vertex bend increases with height; normals blended toward a rounded blade normal across the width; base darkened (fake AO); two-tone root-to-tip colour with a dry-tip option; thin backlit translucency so low sun glows through blades; edge-on blades widened in view space so they do not vanish.
- **Ground blend:** each clump samples the terrain colour under its root and lerps toward it near the base, so grass and soil have no seam.
- **Clumping:** a cellular noise field sets height, bend, lean direction, and species mix per clump, so fields have patches rather than a uniform carpet.
- **Seasons:** extend `VegetationPhenology` to grass and shrubs (green in May, dry in August, yellow and flat in November, snow-pressed in winter), which closes a gap named in `LIVING_VEGETATION.md`.
- **Interaction:** replace the single push centre with a small ring buffer of recent player and NPC positions (up to 8 entries) so a path of flattened grass remains for a few seconds.
- **Transitions:** use hysteresis and a dithered fade, not alpha self-fade (costly in Compatibility). Seeded random placement per tile so a tile never reshuffles when you re-enter it.
- **Shadows:** grass casts none. GodotGrass notes shadowed grass is very expensive.

### 3. Grain fields (barley, rye, oats)

A separate content layer, because a field is authored, rectangular, and rhythmic rather than ecological.

- **Authoring:** a `field` primitive on the map blueprint with crop kind (`rye`, `barley`, `oats`), furrow direction, edge irregularity seed, and a growth curve tied to the calendar. Stable ID per field. Follows [`MAP_AUTHORING.md`](../MAP_AUTHORING.md): no raw dictionaries, no renamed IDs.
- **Geometry:** rows of tall stalks following the furrow direction; each stalk is a thin curved strip with an ear (grain head) quad cluster at the top. Near tier gets individual stalks; beyond that, bands of cards that keep the ear-head silhouette.
- **Look by month:** April sown and green-sprouting, June knee-high green, July silver-green with ears forming, August gold, September stubble with sheaf stacks. Growth is a pure function of the date, like the crown phenology.
- **Motion:** the wind front from section 1 rolls across the field; stalks bend as a whole with the ear lagging behind. This is what makes the barley read as in Tsushima.
- **Trampling:** the same ring buffer from section 2 pushes stalks down along the player's path, and they spring back slowly.
- **Edges:** field margins get the weed band (cornflower, poppy-like wildflowers allowed by `FLORA_FAUNA.md`), a worn path, and a hedge or stone line where the map says so.

### 4. Trees: Witcher-style structure

Builds on the existing procedural trees and crown shader rather than replacing them.

- **Skeleton:** a Weber and Penn style parametric generator in GDScript (trunk with taper and flare, branch levels with gravity droop, species presets) producing a branch tree that is meshed once and cached. Species presets: Scots pine, spruce, birch, oak, alder, aspen, juniper, linden, maple.
- **Leaf clusters:** instead of uniformly scattered cards, place leaf cards in clusters along terminal twigs, oriented outward, with inner clusters smaller and darker. This gives the Witcher read: lit outer shell, shadowed hollow, visible branch structure through gaps.
- **Light:** keep the baked crown AO in vertex alpha; add leaf translucency (back-light colour shift) and per-cluster normal bending toward the crown centre so crowns shade as volumes, not as flat cards.
- **Bark:** a tiling normal and albedo plate per species family, generated procedurally (see section 7) with trunk-base moss and a wet response already present.
- **Wind in three levels:** trunk sway (very low frequency), branch heave (existing limb term), leaf flutter (existing). Weights come from vertex data already carried in `CUSTOM0` and `COLOR`, driven by the shared wind field.
- **LOD chain (the biggest current gap; only the city has it today):**
  1. LOD0: full branches and leaf clusters, to about 35 m.
  2. LOD1: simplified branches and larger merged cluster cards, to about 90 m.
  3. LOD2: cross-plane or octahedral impostor, baked per species at build time by a tool script, beyond about 90 m. Start with the simpler cross-plane billboard; octahedral impostors are an upgrade because no Godot add-on exists and the bake and shader are ours to write.
  4. Use hysteresis and a dithered cross-fade between levels.
- **Alpha coverage:** build mips that preserve coverage so distant needle and leaf cards do not thin out (a named gap). Keep alpha scissor at 0.5 and enable alpha antialiasing on MSAA.
- **Understory and shrubs:** juniper, hazel, bramble, and ferns become part of the ecology pass (next section), not stand-alone props.

### 5. Ecology-driven placement

Realism comes more from where things grow than from how each plant is drawn (the Horizon lesson).

- A deterministic per-cell function of: terrain family, slope, distance to water, distance to road and path, tree-canopy shade, and a low-frequency fertility noise, returning density and species weights per layer (ground cover, grass, flowers, shrubs, trees).
- Rules, for example: no grass on trodden road, nettle and sedge at walls and water edges, moss and fern under conifers, juniper on dry limestone, forest floor litter under crowns, field weeds only on field margins.
- Output is data on the compiled `MapDefinition`, so preview, runtime, chunking, and 3D agree, as `MAP_AUTHORING.md` requires. Do not persist chunk coordinates.
- Authored blueprint props always win; a designer can paint an override mask per map without code changes.

### 6. Seasons and weather coverage

- Grass, grain, and shrubs follow the calendar (see sections 2 and 3).
- Wet response everywhere: darker, glossier blades and leaves in rain.
- Snow: a ground-cover tint and per-blade whitening in winter; no snow on branches yet (still a listed limit).
- A persistent leaf-litter layer under deciduous crowns in October and November, fed by the same phenology curve that drives leaf fall.

### 7. Textures without an image generator

Status: implemented (task **R-1329**, VEGR-1). The canopy leaf atlas no longer comes from Leonardo (`leaf_cards_v1`) or OpenAI needle plates; every vegetation texture below is drawn in code and carries no external image-generator rights risk. Out of scope here: tree skeletons, leaf placement, density and wind (VEGR-6, VEGR-2), and binding the new bark, ground and ear textures (VEGR-5, VEGR-6).

**Run.** `python3 tools/assets/generate_vegetation_atlases.py` (NumPy and Pillow, about 12 s). Every output is a pure function of the species parameters and seed 1343: PCG64 random streams, FFT-filtered noise, a fixed PNG encoder and no metadata, so two runs give byte-identical files (`tests/python/test_generate_vegetation_atlases.py` checks both runs and that the committed files match). `--tune` re-derives each leaf species' `size_scale` for its coverage target (about 2.5 min); `--compare-old OLD.png --sheets DIR` writes per-species review sheets. `--out-root DIR` writes the same tree elsewhere. The old entry point `tools/assets/build_leaf_card_atlas.py` now calls the generator; `build_vegetation_plates.py` no longer touches the leaf atlas.

**Outputs** (power-of-two PNGs with committed `.import` sidecars; provenance rows in `assets/SOURCES.csv`):

| File | Content | Used by |
|---|---|---|
| `assets/materials/pbr/foliage_cards/leaf_card_atlas.png` | 2048x1024 RGBA, 4x2 tiles: birch, oak, maple, linden / apple, spruce, pine, empty (order `MapViewLeafGeometry.CARD_TILES`) | Canopy shader `leaf_atlas` via `map_view_wind_materials.gd` (same path and import settings as R-1194) |
| `.../foliage_cards/leaf_card_normal.png` | OpenGL tangent-space normals (+Y up) of the same tiles | VEGR-6 (R-1324); not sampled yet |
| `.../foliage_cards/leaf_card_surface.png` | R roughness, G translucency (low on veins, midrib and twig), B baked occlusion | VEGR-6 (R-1324); not sampled yet |
| `assets/vegetation/bark/bark_<kind>_{albedo,normal}.png` | Seamless 512 px plates for `birch`, `oak`, `grey` (alder, aspen, smooth bark), `pine`, `spruce`, `cherry` | VEGR-6 bark (R-1324); the shipped bark still uses the R-712 plates |
| `assets/vegetation/ground/ground_<kind>_{albedo,normal}.png` | Seamless 512 px `moss`, `leaf_litter`, `needle_litter` | VEGR-3/VEGR-8 ground cover |
| `assets/vegetation/grain/grain_ear_atlas.png` | 1024x512 RGBA, 4x1 tiles of 256x512: `rye`, `barley`, `oat`, `flax` ears on a stalk, base at the bottom edge | VEGR-5 grain fields (R-1325) |

**How the leaves are drawn.** Each tile is a twig cluster on a 1024 px supersampled canvas, downsampled 2x with premultiplied box filtering. Leaves are signed-distance outlines in leaf space: deltoid double-serrate birch, obovate oak with rounded lobes and basal auricles, palmate Norway maple with pointed lobes and side teeth, oblique cordate linden, elliptic crenate apple. Each leaf gets a midrib, pinnate or palmate veins, a fold and dome shading term, per-leaf hue and brightness variation, browned tips or margins on a share of leaves, and a soft contact shadow on what lies beneath. Layouts follow the species: alternate with side shoots (birch), tip rosettes (oak), opposite pairs (maple), two-ranked (linden), short spurs (apple). Spruce is a flat spray of short single needles round alternate side shoots with paler new growth at the tips; Scots pine is paired, long, slightly curved needles on a whorl of shoots. Bark uses periodic noise and periodic Voronoi (furrowed oak ridges, plated pine, scaly spruce, white birch with lenticels and black fissures, smooth grey bark with lichen, banded cherry); ground plates stamp leaves and needles with wraparound so they tile.

**Runtime contract kept from R-1194.** RGB is relative detail scaled so the mean opaque colour is neutral 0.5 grey (the shader multiplies by 2 and owns species tint, season, autumn and wetness); alpha is coverage for the 0.5 scissor; the petiole end sits on the bottom edge (card `UV.y = 0`); empty texels carry nearby leaf colour (normalised blur fill) so mipmaps never halo against the sky. Grain ears follow the same contract.

**Coverage.** Each species' foliage size was tuned (`size_scale`) so the card covers about as much as the tile it replaced, keeping crown density unchanged: birch 0.32 (old 0.34), oak 0.43 (0.45), maple 0.37 (0.41), linden 0.40 (0.47), apple 0.39 (0.39), spruce 0.39 (0.39), pine 0.37 (0.52). Linden and pine stop short because a wider cluster is fitted down into the card; the in-engine captures show crowns of matching density.

**Visual review.** Per-species sheets, each `before | after` at near range then canopy distance, all on the same calendar date and light. Atlas sheets (tile tinted like the shader, then a 32 px mip): [birch](../reports/images/vegetation_atlases/birch_before_after.png), [oak](../reports/images/vegetation_atlases/oak_before_after.png), [maple](../reports/images/vegetation_atlases/maple_before_after.png), [linden](../reports/images/vegetation_atlases/linden_before_after.png), [apple](../reports/images/vegetation_atlases/apple_before_after.png), [spruce](../reports/images/vegetation_atlases/spruce_before_after.png), [pine](../reports/images/vegetation_atlases/pine_before_after.png). In-engine crowns (real tree meshes and canopy material, rendered through `tools/godot_render.sh`): [birch](../reports/images/vegetation_atlases/birch_engine_before_after.png), [oak](../reports/images/vegetation_atlases/oak_engine_before_after.png), [maple](../reports/images/vegetation_atlases/maple_engine_before_after.png), [linden](../reports/images/vegetation_atlases/linden_engine_before_after.png), [apple](../reports/images/vegetation_atlases/apple_engine_before_after.png), [spruce](../reports/images/vegetation_atlases/spruce_engine_before_after.png), [pine](../reports/images/vegetation_atlases/pine_engine_before_after.png). The first pass failed review (sparse cards, holly-like oak lobes, star-shaped maple, thin spruce), and those species were redrawn by parameters, not by loosening the gate.

**Verify.** `python3 -m unittest tests.python.test_generate_vegetation_atlases -v`; run the generator twice and compare SHA-256; `python3 tools/validate_asset_sources.py`; `python3 tools/verify_asset_lint.py`; `python3 tools/verify_storage_hygiene.py`.

**Limits.** At card scale the outlines read well; close up, leaves are flat-shaded vector shapes without the micro texture of a photograph, and linden's heart-shaped base is barely visible in a crowded cluster. The normal, surface, bark, ground and ear textures are built but not mounted in any material until their VEGR tasks bind them. Species without their own tile still borrow the nearest one (`CARD_TILES`).

### 8. Performance budgets

Status: implemented (task **R-1320**, VEGR-0). Benchmark command, camera set, layer attribution and JSON schema: [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md#vegetation-benchmark-r-1320). Baseline run and findings: [`vegetation_benchmark_baseline.md`](../reports/vegetation_benchmark_baseline.md).

`tools/run_performance_report.sh <out.json> --vegetation` walks six fixed cameras (`meadow_eye_level`, `meadow_gameplay`, `grain_field_eye_level`, `woodland_interior`, `woodland_distance` on `viru_gate_foreland`; `lower_town_street` on `lower_town_slice`) and reports instances, triangles and draw calls per layer (`grass_near`, `grass_mid`, `grain`, `trees_lod0/1/2`, `shrubs`, `flowers`, `litter`, `veg_misc`, `other`), frame time, and the paired shown/hidden cost of each layer. Counts reproduce exactly between runs; milliseconds do not.

**What the baseline says (M5 Pro, 1920x1080, 2026-10-08).** Tree crowns are almost the entire cost: 9.5 to 14.6 million LOD0 crown triangles per rural camera (about 10,400 per tree, no distance reduction), 33 to 72 ms of a 44 to 97 ms frame, multiplied about 4.5 times by shadow cascades. Grass, grain, flowers and herbs together stay under 0.2 million triangles and 1 ms. Scatter grass is chunk-culled at 45 m, so the gameplay camera draws none.

**Budgets.** Hard gate on counts, per camera, main pass (`tools/vegetation_performance.py budgets`). With `--baseline docs/reports/vegetation_benchmark_baseline.json` each limit is `max(target, baseline)`: a layer already over target (today only the tree crowns) may not grow, a layer under target may grow up to it. A phase that breaks a limit does not merge.

| Layer | Triangles | Draw calls | Baseline peak (tris / draws) | Reasoning |
|---|---|---|---|---|
| `grass_near` | 300,000 | 8 | 87,792 / 4 | VEGR-4 blades at about 5 triangles each: room for about 60,000 visible blades in the 14 m first-person ring, about 3.4 times today's tufts, in the same few MultiMeshes |
| `grass_mid` | 100,000 | 24 | 44,480 / 10 | Keeps the existing card tier (twice today) chunked; extra density belongs in the near tier |
| `grain` | 250,000 | 16 | 38,208 / 6 | VEGR-5 stalks plus ear clusters fill a field to the 45 m range; one batch per crop per chunk |
| `trees_lod0` | 1,000,000 | 100 | 14,583,844 / 139 | About 95 full crowns near the camera at today's 10,400 triangles; everything farther must go to LOD1/2 (VEGR-6/7). Biggest gap: today 14.6 times over |
| `trees_lod1` | 600,000 | 60 | 0 / 0 | Simplified crowns to about 90 m, about a quarter of LOD0 cost per tree |
| `trees_lod2` | 100,000 | 30 | 0 / 0 | Cross-plane or octahedral impostors beyond 90 m: a few triangles per tree, one batch per species |
| `shrubs` | 150,000 | 30 | 320 / 1 | Ecology pass (VEGR-3) understory: juniper, hazel, bramble, fern clumps |
| `flowers` | 60,000 | 12 | 35,310 / 4 | Field-margin and meadow flowers stay a garnish |
| `litter` | 50,000 | 8 | 0 / 0 | VEGR-8 leaf litter is mostly a ground texture; geometry only near the camera |
| `veg_misc` | 100,000 | 16 | 4,252 / 4 | Reeds, cattails, herbs and ferns |
| **All vegetation** | **2,000,000** | **250** | 14,583,844 / 165 | The baseline measures 0.20 to 0.28 M crown triangles per ms including shadow cascades, so 2 M main-pass triangles cost about 7 to 10 ms on the reference: roughly half of a 60 fps frame, leaving the other half to the rest of the scene (Lower Town street: 15 ms total today) |

Frame time: no single layer should cost more than 4 ms on the reference machine (paired shown/hidden median at 1920x1080). Every non-tree layer measured at most 1.3 ms, so the placeholder holds as an advisory check; the tool prints timing findings as warnings because the tree-layer measurement varies by tens of percent between runs. The spec's placeholder share rule (vegetation at most 35 percent of a meadow) is dropped: vegetation is 93 to 97 percent of a rural frame because it is the scene, so only absolute counts are meaningful.

**Decision (open question 4, R-1320).** Budgets are measured and gated on the development reference (Apple M5 Pro, `tools/benchmarks/target_hardware.json`), with counts as the portable gate. The declared minimum target, Intel UHD 620 at 1920x1080 (`tools/benchmarks/minimum-hardware.json`, P3-011), is the density floor: the count budgets above are what the default density must fit, and a lower density preset is derived from the same per-layer counts once R-653 records a real run on that hardware. Until then minimum-hardware acceptance for vegetation stays BLOCKED, as for every other R-653 row; an M5 Pro run never certifies the UHD 620 target.

Every phase below ends with a before and after benchmark (`--vegetation`, then `budgets --baseline`), and the phase updates the baseline report only when it lowers a count.

## Delivery plan

Each row is one task, written per the task contract in [`AGENTS.md`](../../AGENTS.md#task-contract). Order is by risk and value. Parent epic: **R-1319**; full specs live on the task board.

| # | Task | Task ID | Depends on | Allowed files (starting set) | Verify |
|---|---|---|---|---|---|
| V0 | Vegetation benchmark and budgets | **R-1320** | none | `tools/run_performance_report.sh`, `docs/PERFORMANCE_REPORT.md`, new `tools/` script | Report prints per-layer counts; run recorded in docs |
| V1 | Procedural leaf, needle, bark, and ear atlases with provenance; remove Leonardo atlas dependency | **R-1329** | none | new `tools/assets/` script, `assets/` vegetation textures, `assets/SOURCES.csv`, canopy material loader | `validate_asset_sources.py`, `verify_asset_lint.py`, captures of every species |
| V2 | Shared wind field via global shader parameters | **R-1321** | V0 (R-1320) | `map_view_wind_materials.gd`, `map_view_grass.gdshader`, `map_view_canopy.gdshader`, flag and rope wind shaders | New `tests/godot/test_wind_field.gd` (determinism, weather mapping); captures of one gust crossing a meadow |
| V3 | Ecology placement pass | **R-1322** | V0 (R-1320) | `map_view_mesh_builder_scatter*.gd`, new ecology module, `tests/` | Tests: same seed gives same density; blueprint IDs unchanged; `validate_map_blueprints.gd`, `build_world_layout.gd --check` pass |
| V4 | Near-tier blade grass, tiers and seasons | **R-1323** | V2, V3 (R-1321, R-1322) | `map_view_grass.gdshader`, `map_view_foliage_meshes.gd`, `map_view_plant_meshes.gd`, `vegetation_phenology.gd` | Captures in each month; benchmark within budget |
| V5 | Grain fields (`field` primitive, geometry, growth, trampling) | **R-1325** | V2, V4 (R-1321, R-1323) | `MapBlueprint` primitives and compiler, `map_blueprint_registry.gd` for one pilot map only, new field mesh and shader | Blueprint diagnostics stable; pilot-map captures April to September; collision and navigation parity unchanged |
| V6 | Tree skeleton generator and leaf clusters | **R-1324** | V1 (R-1329) | `map_view_tree_meshes.gd`, `map_view_leaf_geometry.gd`, canopy shader | Mesh determinism test; side-by-side captures per species |
| V7 | Tree LOD chain with alpha-coverage mips and billboard impostors | **R-1326** | V0, V6 (R-1320, R-1324) | `scripts/map/view3d/` tree LOD module, `scripts/city/city_tree_lod.gd` reuse, bake tool | No visible pop at transitions in a captured flythrough; benchmark within budget |
| V8 | Leaf litter, snow ground cover, interaction ring buffer | **R-1327** | V4 (R-1323) | grass and ground shaders, `tree_leaf_fall_3d.gd` | Season captures; tests on ring buffer |
| V9 | Octahedral impostors (optional upgrade) | **R-1328** | V7 (R-1326) | bake tool, impostor shader | Compare against cross-plane captures; keep only if clearly better |

Each task also updates this page and `LIVING_VEGETATION.md`, per the mandatory feature-documentation rule.

## Risks

- **No renderer verification so far.** This plan was written without running Godot. Every visual claim above is a target, to be confirmed by captures in each task.
- **Compatibility renderer limits.** No compute placement, no HDR, low colour precision (banding risk in gradients). Spike global shader parameters and alpha antialiasing before V2 and V7.
- **Draw-call growth.** Dense blades and per-species trees multiply instances. Budgets from V0 gate every phase.
- **Procedural textures read as synthetic.** Mitigation in section 7.
- **Map migration.** Fields and ecology touch the map compiler. Migrate one pilot map at a time and keep the parity checks in `AGENTS.md` green.
- **Licensing.** Do not copy GodotGrass or other code without recording license and attribution; its bundled assets carry separate terms.

## Open questions

1. Which pilot map shows grain fields first (a rural map near Reval or the hinterland group)?
2. Octahedral impostors (V9) or cross-plane billboards only, once V7 is measured?
3. Should NATURAL aspects tint or bend vegetation through the shared wind and tint channels, and in which act?
4. ~~Minimum hardware target for vegetation density~~ Decided in R-1320: budgets gated on the M5 Pro reference, Intel UHD 620 at 1080p is the density floor (see section 8).

## Verification of this page

`python3 tools/docs_index.py --check` and `python3 tools/generate_active_docs_report.py --check`.
