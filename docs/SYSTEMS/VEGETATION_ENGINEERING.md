# Vegetation engineering: budgets, workflow, verification, roadmap

Status: implemented (tasks **R-1320**, **R-1329**, **R-1704**). Engineering companion to [Living vegetation](./LIVING_VEGETATION.md), which shows what each feature looks like and where its code lives. This page holds what a developer needs when changing vegetation: the procedural texture pipeline, performance budgets, the change workflow, capture and test commands, known limits and the roadmap. Out of scope: gameplay, saved state, a crop mechanic.

## Procedural textures

Implemented in **R-1329**. Every vegetation texture is drawn in code, with no image-generator rights risk; the canopy atlas no longer comes from Leonardo (`leaf_cards_v1`) or OpenAI needle plates.

**Run.** `python3 tools/assets/generate_vegetation_atlases.py` (NumPy and Pillow, about 12 s). Every output is a pure function of species parameters and seed 1343 (PCG64 streams, FFT-filtered noise, fixed PNG encoder, no metadata), so two runs give byte-identical files. `--tune` re-derives each leaf species' `size_scale` for its coverage target (about 2.5 min); `--compare-old OLD.png --sheets DIR` writes review sheets; `--out-root DIR` writes elsewhere. `tools/assets/build_leaf_card_atlas.py` calls the generator; `build_vegetation_plates.py` is kept for bark only.

| File | Content | Used by |
|---|---|---|
| `assets/materials/pbr/foliage_cards/leaf_card_atlas.png` | 2048x1024 RGBA, 4x2 tiles: birch, oak, maple, linden / apple, spruce, pine, empty | Canopy shader `leaf_atlas` |
| `.../foliage_cards/leaf_card_normal.png` | OpenGL tangent-space normals of the same tiles | Built; not sampled yet |
| `.../foliage_cards/leaf_card_surface.png` | R roughness, G translucency, B baked occlusion | Built; not sampled yet |
| `assets/vegetation/bark/bark_<kind>_{albedo,normal}.png` | Seamless 512 px `birch`, `oak`, `grey`, `pine`, `spruce`, `cherry` | Built; shipped bark still uses the R-712 plates |
| `assets/vegetation/ground/ground_<kind>_{albedo,normal}.png` | Seamless 512 px `moss`, `leaf_litter`, `needle_litter` | Ground cover (planned binding) |
| `assets/vegetation/grain/grain_ear_atlas.png` | 1024x512, 4x1 tiles: `rye`, `barley`, `oat`, `flax` ears | [Grain fields](#roadmap) (planned) |

**How leaves are drawn.** Each tile is a twig cluster supersampled at 1024 px and box-filtered down. Leaves are signed-distance outlines: deltoid double-serrate birch, obovate lobed oak with basal auricles, palmate Norway maple, oblique cordate linden, elliptic crenate apple, each with midrib, veins, fold shading, per-leaf hue variation, browned tips on a share and a contact shadow. Layouts follow the species (alternate, tip rosettes, opposite pairs, two-ranked, spurs). Spruce is a flat spray of short needles with paler new growth; pine is paired long curved needles on a whorl. Bark uses periodic noise and Voronoi (furrowed oak, plated pine, scaly spruce, white birch with lenticels, smooth grey with lichen, banded cherry).

**Runtime contract (from R-1194).** RGB is relative detail with mean opaque colour at neutral 0.5 grey (the shader multiplies by 2 and owns tint, season and wetness); alpha is coverage for the 0.5 scissor; the petiole end sits on the bottom edge (`UV.y = 0`); empty texels carry nearby leaf colour so mips never halo. Per-species `size_scale` keeps crown density as before: birch 0.32, oak 0.43, maple 0.37, linden 0.40, apple 0.39, spruce 0.39, pine 0.37.

**Review.** Atlas sheets: [birch](../reports/images/vegetation_atlases/birch_before_after.png), [oak](../reports/images/vegetation_atlases/oak_before_after.png), [maple](../reports/images/vegetation_atlases/maple_before_after.png), [linden](../reports/images/vegetation_atlases/linden_before_after.png), [apple](../reports/images/vegetation_atlases/apple_before_after.png), [spruce](../reports/images/vegetation_atlases/spruce_before_after.png), [pine](../reports/images/vegetation_atlases/pine_before_after.png). In-engine crowns: [birch](../reports/images/vegetation_atlases/birch_engine_before_after.png), [oak](../reports/images/vegetation_atlases/oak_engine_before_after.png), [maple](../reports/images/vegetation_atlases/maple_engine_before_after.png), [linden](../reports/images/vegetation_atlases/linden_engine_before_after.png), [apple](../reports/images/vegetation_atlases/apple_engine_before_after.png), [spruce](../reports/images/vegetation_atlases/spruce_engine_before_after.png), [pine](../reports/images/vegetation_atlases/pine_engine_before_after.png). The first pass failed review and was redrawn by parameters, not by loosening the gate.

## Performance budgets

Implemented in **R-1320**. Command, cameras and JSON schema: [`PERFORMANCE_REPORT.md`](../PERFORMANCE_REPORT.md#vegetation-benchmark-r-1320); baseline: [`vegetation_benchmark_baseline.md`](../reports/vegetation_benchmark_baseline.md).

`tools/run_performance_report.sh <out.json> --vegetation` walks six fixed cameras (`meadow_eye_level`, `meadow_gameplay`, `grain_field_eye_level`, `woodland_interior`, `woodland_distance` on `viru_gate_foreland`; `lower_town_street`) and reports instances, triangles and draw calls per layer, frame time and paired shown/hidden layer cost. Counts reproduce exactly; milliseconds do not.

**Baseline (M5 Pro, 1920x1080, 2026-10-08).** Tree crowns are almost the whole cost: 9.5-14.6 M LOD0 crown triangles per rural camera (about 10,400 per tree, no distance reduction), 33-72 ms of a 44-97 ms frame, multiplied about 4.5x by shadow cascades. Grass, grain, flowers and herbs together stayed under 0.2 M triangles and 1 ms.

**Budgets** are a hard gate on counts per camera, main pass (`tools/vegetation_performance.py budgets`). With `--baseline docs/reports/vegetation_benchmark_baseline.json` each limit is `max(target, baseline)`: a layer over target (today only tree crowns) may not grow.

| Layer | Triangles | Draw calls | Baseline peak (tris / draws) | Reasoning |
|---|---|---|---|---|
| `grass_near` | 300,000 | 8 | 87,792 / 4 | About 60,000 visible blades in the 14 m ring |
| `grass_mid` | 100,000 | 24 | 44,480 / 10 | Extra density belongs in the near tier |
| `grain` | 250,000 | 16 | 38,208 / 6 | Stalks and ears to 45 m, one batch per crop per chunk |
| `trees_lod0` | 1,000,000 | 100 | 14,583,844 / 139 | About 95 full crowns; everything farther must go to LOD1/2. Today 14.6x over |
| `trees_lod1` | 600,000 | 60 | 0 / 0 | Simplified crowns to about 90 m |
| `trees_lod2` | 100,000 | 30 | 0 / 0 | Impostors beyond 90 m |
| `shrubs` | 150,000 | 30 | 320 / 1 | Ecology understory |
| `flowers` | 400,000 | 32 | 35,310 / 4 | Includes city forbs (raised from 60,000 / 12 in R-1558) |
| `litter` | 50,000 | 8 | 0 / 0 | Mostly a ground texture |
| `veg_misc` | 100,000 | 16 | 4,252 / 4 | Reeds, cattails, herbs, ferns |
| **All vegetation** | **2,000,000** | **250** | 14,583,844 / 165 | About 7-10 ms on the reference: half of a 60 fps frame |

**City forbs (R-1558).** Each benchmark camera carries a `forbs` block (instances, triangles, draws, chunk build, `_refill()` and `update_for` timings); two cameras, `forb_hotspot_meadow` and `forb_hotspot_kalev_smithy`, are placed at the densest forb windows. Budget: 350,000 triangles and 16 draws (`BUDGETS["forbs"]`). After tuning (`NEAR_RANGE` 13 to 9 m, plantain `MAX_DENSITY` 0.60 to 0.45) the worst camera, the smithy hotspot, measured 348,574 triangles in 12 draws; `_refill()` 0.08-0.14 ms, one chunk build 0.2-1.4 ms (`build/benchmarks/r1558_forbs.json`).

Frame time: no single layer should cost more than 4 ms (advisory; tree timings vary tens of percent between runs). **Decision (R-1320):** budgets are gated on the M5 Pro reference (`tools/benchmarks/target_hardware.json`) with counts as the portable gate; Intel UHD 620 at 1080p (`tools/benchmarks/minimum-hardware.json`, P3-011) is the density floor, and minimum-hardware acceptance stays BLOCKED until R-653 records a real run. Every vegetation phase ends with a before/after `--vegetation` run and `budgets --baseline`.

## Developer workflow

Start with the visual symptom, then edit the responsible layer. Do not change placement to compensate for a bad model, or the global shader to fix one species.

| Desired change | Start here | Compare before accepting |
|---|---|---|
| Move trees / change a species mix | Authored map or city plan, ecology rules, `vegetation_habitat.py` | Root placement, water/road/bridge clearance, stable IDs |
| Make oak broader or willow more drooping | Branching `PRESETS`, then size profile | Bare wood and full crown; neighbours keep distinct shapes |
| Change city tree height or trunk diameter | `CityVegetationBuilder.HEIGHT_M`, `TRUNK_DIAMETER_M`; `CITY_FORMS` | Human-scale city view, not a normalized catalog cell |
| Oversized leaves or sparse close-up crowns | Leaf profiles, cluster settings, city near/macro geometry | Both sides of the LOD boundary |
| Leaf shape, fringe or transparency | Atlas generator, `CARD_TILES`, canopy shader | Edge-on cards, backlight, distant mips, every species sharing the tile |
| Bark stretching or joints | City wood UVs and bark textures | Bare junctions from several angles |
| Spring/autumn or fruit timing | `VegetationPhenology` | April, midsummer, October, January |
| Storm movement | `WindField`, `tree_wind.gdshaderinc`, species `sway_strength` | Calm and storm, bark and foliage, every crown tier |
| Grass density, height or range | `CityGrass` tier constants, `map_view_grass.gdshader` | Tier seams at 12, 46 and 118 m; `grass_near` budget |
| Wild-plant look, habitat or season | `CityForbMeshes`, `CityForbs`, `forb_phase` | Near and far variants; season table; forb budget |
| Moss, lichen, fungi | `city_growth_plates.gdshaderinc` (species mixes, `moss_season_g`), `MapViewWindMaterials.MOSS_SEASON`, `CityShadeMask`, `CityForestFloor` | North vs south faces; April, July, January; no repeating tile at the wall foot |
| Expensive woodland | `CityTreeLod`, graphics settings, batching/shadows | Frame time and overdraw in a dense stand |

For a model edit: **(1)** identify species and runtime path, **(2)** capture the current shape, **(3)** change the owning layer, **(4)** compare silhouette, bare wood and close detail, **(5)** check seasons and LOD transitions, **(6)** update this page. Adding a species also needs registry/pools, profiles/presets, leaf and bark mappings, phenology, placement and checks. Preserve existing IDs.

### Runtime integration reference

| Concern | Entry point |
|---|---|
| District date | `MapView3D.set_calendar_date` -> seasonal crown/fruit materials |
| District weather | `MapViewMaterials.apply_weather_presentation` -> wind and wetness |
| City date and weather | [`CityMapView.set_calendar_date`](../../scripts/city/city_map_view.gd) -> shared seasonal materials, `CityWorld3D.apply_season`, `CityForbs` and `CityForestFloor`; `CityWorld3D.apply_time` drives weather |
| Species material caching | `MapViewWindMaterials.canopy_for_species`; new materials inherit the last published season/wetness |
| District melee | `MapViewRuntimeActors._on_player_melee_attack_resolved` -> `MapView3D.strike_vegetation` |
| Camera-driven crown tier | `CityTreeLod`, under the city vegetation root |

### Mesh and shader contracts

- `UV2.x = 1` marks leaf geometry; `UV2.y = 1` distinguishes cluster cards from folded leaves/needle shoots.
- `CUSTOM0 = (petiole xyz, seed)` anchors each leaf/card; the shader scales or collapses it around that anchor.
- `COLOR.a` stores crown self-occlusion on canopies and limb flexibility on city wood, not transparency. `UV.y` supports base-to-tip flutter.
- District strikeable canopy MultiMeshes carry `INSTANCE_CUSTOM.xy` crown displacement and `.z` flutter, registered through `TreeLeafFall3D.tag_canopy` in `tree_canopy_multimesh`.
- Wind shaders read the shared globals; do not reintroduce per-material wind clocks.

**Save/load:** species, placement, calendar and weather reconstruct the look; meshes, LOD choice, gust phase, shake and particles add no save fields. Seasonal state is deterministic for a date; wind depends on render time, so a load does not resume the exact animation frame.

## Preview and verification

Use the pinned [Godot setup](../SETUP.md). Never open visible Godot windows: headless for tests, the minimized GPU wrapper for captures. Run from the repository root.

```bash
# Animations on this page (frames to build/veg_anim/, then GIFs).
tools/godot_render.sh --script tools/capture_vegetation_animations.gd   # -- --only=storm,meadow,seasons
tools/build_vegetation_animations.sh

# Trees: all species, close-ups, bare wood; seasons; city detail; wind.
tools/godot_render.sh --script tools/capture_tree_reference_sheet.gd
tools/godot_render.sh --script tools/capture_living_vegetation.gd
tools/godot_render.sh --script tools/capture_city_vegetation.gd -- --tag=review --only=spruce_macro,pine_macro,spruce_needles_close
tools/godot_render.sh --script tools/capture_city_vegetation.gd -- --only=pine_tall_scale,pine_heath_eye,pine_heath_wide,bridge_clear_viru,bridge_clear_tartu
tools/godot_render.sh --script tools/capture_city_vegetation.gd -- --only=oak_base_close,pine_base_close,birch_base_close
tools/godot_render.sh --script tools/capture_tree_storm.gd
tools/godot_render.sh --script tools/capture_wind_front.gd

# Grass, wild plants, ecology, moss.
tools/godot_render.sh --script tools/capture_city_grass.gd                          # build/grass/
tools/godot_render.sh --script tools/capture_city_forbs.gd -- --season=summer      # or --date=YYYY-MM-DD
tools/godot_render.sh --script tools/capture_blueprint_forbs.gd -- --tag=now
tools/godot_render.sh --script tools/capture_vegetation_realism.gd -- ecology
tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_moss.tscn      # -- --walls stops after walls
tools/godot_render.sh --resolution 1600x900 --script tools/capture_roof_growth.gd   # -- --unbound | --wet
```

Several tools overwrite tracked evidence; inspect the diff and do not replace reference plates by accident. A fresh PNG proves the capture ran, not that it meets the art target.

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_tree_skeleton,test_vegetation_realism,test_city_vegetation,test_tree_leaf_fall,test_wind_field,test_tree_storm_bend,test_tree_wood_wind,test_map_view_bush_species
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_grass_tiers,test_city_forbs,test_map_view_plant_species,test_vegetation_phenology,test_vegetation_interaction_buffer
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_vegetation_ecology,test_map_view_3d_mesh,test_map_blueprint_compiler,test_lower_town_slice_map,test_city_forest_floor,test_growth_plates
python3 -m unittest tests.python.test_vegetation_habitat tests.python.test_generate_vegetation_atlases -v
python3 tools/city/build_reval_city_plan.py --check
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/docs_index.py --check
python3 tools/generate_active_docs_report.py --check
```

Ecology changes also run the map gate from [`AGENTS.md`](../../AGENTS.md#map-authoring-mandatory). For rendering changes, measure a warmed GPU scene with several nearby trees ([performance budgets](#performance-budgets)).

## Known limits

- **Trees.** Atlas sharing makes growth forms more species-specific than leaf artwork. Leaf cards can show their planes edge-on, and at mid and far distance conifer cards read a low mip of the needle tile, so needle fans turn into lobed, leaf-like blobs (visible in the storm animation's spruce). Fruit are octahedra. The district spruce is capped at 120 coarse wood segments. Root flare tubes are faceted cones; litter flecks are flat and static. Recheck bent joints after geometry changes ([oak joint gap history](../reports/images/vegetation/veg_oak_joint_gap_before_after.jpg)).
- **City vs district.** Bark, whole-tree bending, crown tiers, shrubs and leaf emitters differ. District trees have no LOD chain; `trees_lod0` is 14.6x over budget. The hit-shake offset moves the crown only. District ambient emitters can overlap at hosted-view seams.
- **Grass.** No grass seasons in `VegetationPhenology`, no edge-on blade widening, blueprint maps keep textured tuft cards, no per-tile hysteresis, no measured run against `grass_near`. Trails are player-only.
- **Wild plants.** Phases switch on fixed days (no gradual growth, no autumn yellowing of leaf models, plants vanish in winter while grass stays green, dead burdock is cleared in November). Leap years shift phases by a day. No yarrow model, no trampling beyond flattened plantain. Blueprint maps: no phenology, near model only.
- **Ecology.** District maps draw no bushes, so shrub density and the juniper understory are computed but invisible. `MapViewTerrainDetails` and the seamless city do not read the ecology, so near-camera grass is mostly unchanged. Slope is not an input; litter is computed but not drawn. The city soil mask is two thresholds, not a geological map.
- **Moss and fungi.** The woods stand in tall meadow grass (R-1595) that hides most fungi. The north strip is a fixed southern-sun approximation; the canopy channel is coarse (12 units). Fungi are low-poly lathes with vertex colour.
- **Textures.** Normal, surface, bark, ground and ear textures from R-1329 are built but not yet bound.
- No felling, breakage, harvesting, persistent particle accumulation or elastic simulation. Independent visual acceptance of the crown and storm work remains incomplete.

## Roadmap

Epic **R-1319**; full specs on the task board. Every task updates this page.

| # | Task | ID | State |
|---|---|---|---|
| V0 | Vegetation benchmark and budgets | **R-1320** | done |
| V1 | Procedural leaf, needle, bark and ear atlases | **R-1329** | done |
| V2 | Shared wind field | **R-1321** | done |
| V3 | Ecology placement | **R-1322** | done |
| V4 | Blade grass, tiers and seasons | **R-1323** | city tiers done; blueprint carpet and grass seasons open |
| V5 | Grain fields (`field` primitive, geometry, growth, trampling) | **R-1325** | planned |
| V6 | Tree skeletons and leaf clusters | **R-1324** | done |
| V7 | Tree LOD chain with alpha-coverage mips and impostors | **R-1326** | planned |
| V8 | Leaf litter, snow ground cover, trail buffer | **R-1327** | snow and player trail done; litter layer open |
| V9 | Octahedral impostors (optional) | **R-1328** | planned |

**Planned designs.**

- **Grain fields (V5).** A `field` blueprint primitive (crop `rye`, `barley` or `oats`, furrow direction, edge seed, stable ID) per [`MAP_AUTHORING.md`](../MAP_AUTHORING.md). Rows of curved stalks with ear clusters near, bands of ear-silhouette cards beyond. By month: April green shoots, June knee-high, July silver-green ears, August gold, September stubble and sheaves, as a pure function of the date. The wind front rolls across with ears lagging; the trail buffer presses stalks down. Margins get a weed band, worn path and hedge or stone line. Ear textures already exist.
- **Tree LOD chain (V7).** LOD0 full crowns to about 35 m; LOD1 simplified branches and merged cards to about 90 m; LOD2 cross-plane billboards baked per species beyond, octahedral impostors (V9) only if clearly better (no Godot add-on bakes them). Hysteresis and a dithered cross-fade, not costly alpha self-fade. Coverage-preserving mips so distant needle cards stop thinning; alpha scissor 0.5 with alpha antialiasing on MSAA.
- **Grass seasons (V4).** Green in May, dry in August, yellow and flat in November, snow-pressed in winter; edge-on blades widened in view space; cellular clumping of height, bend and lean; NPC positions in the trail buffer.
- **Leaf litter (V8).** A persistent layer under deciduous crowns in October and November, fed by the leaf-fall curve.

**Research and reuse (for the planned work).**

| Source | Technique / decision | Confidence |
|---|---|---|
| Ghost of Tsushima, [GDC "Procedural Grass"](https://gdcvault.com/play/1027214/Advanced-Graphics-Summit-Procedural-Grass), ["Blowing from the West"](https://gdcvault.com/play/1027124/Blowing-from-the-West-Simulating) | Per-blade GPU grass; wind as one system for grass, trees, cloth and particles | Abstracts only |
| [GodotGrass](https://github.com/2Retr0/GodotGrass) (MIT; assets CC BY 4.0 / CC0) | Bent blades, rounded normals, base AO, view-space widening, tile LOD, cellular clumping. **Technique reference, not vendored**: its CPU tile rebuilds and LOD pops conflict with deterministic blueprint placement | Read from the repo |
| Horizon Zero Dawn, [vegetation summary](https://videohighlight.com/v/wavnKZNSYqU) | LOD chain ending in cross-plane billboards; placement from painted data maps | Secondary summary |
| Witcher 4, [Nanite Foliage](https://dev.epicgames.com/documentation/unreal-engine/nanite-foliage) | Look target only (Unreal-only) | Documentation |
| Godot docs, [visibility ranges](https://docs.godotengine.org/en/4.4/tutorials/3d/visibility_ranges.html) | Alpha scissor is the cheap foliage mode; self-fade costs more | Documentation |
| Terrain3D, ProtonScatter, Zylann Scatter | **Not adopted**: own terrain and `MapBlueprint` placement with stable IDs (ADR 0009) | n/a |
| EZ-Tree port (MIT), Tree3D | Reference only for branching and leaf shaders | n/a |

**Risks.** GL Compatibility limits (no compute placement, no HDR, banding in gradients); draw-call growth, gated by the budgets; procedural textures reading as synthetic; map compiler changes for fields (migrate one pilot map, keep parity checks green); licensing of any copied code.

**Open questions.** (1) Which pilot map shows grain fields first? (2) Octahedral impostors or cross-plane billboards only, once V7 is measured? (3) Should NATURAL aspects tint or bend vegetation through the shared wind and tint channels, and in which act? Decided: minimum hardware target (R-1320, see [budgets](#performance-budgets)).
