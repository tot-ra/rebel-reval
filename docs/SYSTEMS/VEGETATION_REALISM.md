# Vegetation realism: grass, grain fields, trees

Status: planned (research and technical plan; no task created yet, nothing implemented). Scope: a staged upgrade of how grass, grain fields, trees, and shrubs are rendered in the 3D view, so open country and woods read as real Baltic nature. Out of scope: gameplay changes, felling or damaging trees, new biomes, imported game assets, a renderer change (GL Compatibility stays), and anything that changes saved state. This page is the spec to turn into tasks; it extends [`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md) (seasons, crown shader, leaf fall) and the "Vegetation realism (P0-208)" rule in [`ART_BIBLE.md`](../ART_BIBLE.md).

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

The current leaf atlas is Leonardo-generated and its rights are unverified. Replace it with generated-in-code textures so the pipeline has no external rights risk.

- A Python tool (under `tools/`) draws leaf and needle atlases from parametric outlines (per-species shape, midrib and vein curves, serrations, colour gradients, noise), writes PNGs, and records provenance in `assets/SOURCES.csv`.
- Bark, ground cover, and grain-ear sprites come from the same tool: layered noise with species parameters.
- Procedural textures can look synthetic. Plan a visual review pass with side-by-side captures; if a species fails review, redraw that species by hand rather than loosening the gate.

### 8. Performance budgets

No vegetation budget exists today, and the only baseline is one machine (M5 Pro, 2026-07-25, Lower Town, [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md)); the minimum-hardware checklist (R-653) has no recorded result. Therefore:

1. First task: a vegetation benchmark mode in `tools/run_performance_report.sh` that reports triangles, instances, and draw calls by layer (grass near, mid, grain, trees LOD0/1/2, shrubs) on a fixed set of cameras.
2. Set numeric budgets only after that baseline exists. Starting guesses to be replaced by measurements: vegetation at most 35 percent of total draw calls and triangles in a meadow scene; no layer adds more than 4 ms to the staged-assembly frame budget.
3. Every phase below ends with a before and after benchmark; a phase that regresses the baseline beyond its budget does not merge.

## Delivery plan

Each row is one task, written per the task contract in [`AGENTS.md`](../../AGENTS.md#task-contract). IDs are assigned when the tasks are created. Order is by risk and value.

| # | Task | Depends on | Allowed files (starting set) | Verify |
|---|---|---|---|---|
| V0 | Vegetation benchmark and budgets | none | `tools/run_performance_report.sh`, `docs/PERFORMANCE_REPORT.md`, new `tools/` script | Report prints per-layer counts; run recorded in docs |
| V1 | Procedural leaf, needle, bark, and ear atlases with provenance; remove Leonardo atlas dependency | none | new `tools/assets/` script, `assets/` vegetation textures, `assets/SOURCES.csv`, canopy material loader | `validate_asset_sources.py`, `verify_asset_lint.py`, captures of every species |
| V2 | Shared wind field via global shader parameters | V0 | `map_view_wind_materials.gd`, `map_view_grass.gdshader`, `map_view_canopy.gdshader`, flag and rope wind shaders | New `tests/godot/test_wind_field.gd` (determinism, weather mapping); captures of one gust crossing a meadow |
| V3 | Ecology placement pass | V0 | `map_view_mesh_builder_scatter*.gd`, new ecology module, `tests/` | Tests: same seed gives same density; blueprint IDs unchanged; `validate_map_blueprints.gd`, `build_world_layout.gd --check` pass |
| V4 | Near-tier blade grass, tiers and seasons | V2, V3 | `map_view_grass.gdshader`, `map_view_foliage_meshes.gd`, `map_view_plant_meshes.gd`, `vegetation_phenology.gd` | Captures in each month; benchmark within budget |
| V5 | Grain fields (`field` primitive, geometry, growth, trampling) | V2, V4 | `MapBlueprint` primitives and compiler, `map_blueprint_registry.gd` for one pilot map only, new field mesh and shader | Blueprint diagnostics stable; pilot-map captures April to September; collision and navigation parity unchanged |
| V6 | Tree skeleton generator and leaf clusters | V1 | `map_view_tree_meshes.gd`, `map_view_leaf_geometry.gd`, canopy shader | Mesh determinism test; side-by-side captures per species |
| V7 | Tree LOD chain with alpha-coverage mips and billboard impostors | V0, V6 | `scripts/map/view3d/` tree LOD module, `scripts/city/city_tree_lod.gd` reuse, bake tool | No visible pop at transitions in a captured flythrough; benchmark within budget |
| V8 | Leaf litter, snow ground cover, interaction ring buffer | V4 | grass and ground shaders, `tree_leaf_fall_3d.gd` | Season captures; tests on ring buffer |
| V9 | Octahedral impostors (optional upgrade) | V7 | bake tool, impostor shader | Compare against cross-plane captures; keep only if clearly better |

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
4. Minimum hardware target for vegetation density: the M5 Pro baseline alone, or Intel UHD 620 at 1080p as well (R-653)?

## Verification of this page

`python3 tools/docs_index.py --check` and `python3 tools/generate_active_docs_report.py --check`.
