# Living vegetation: trees, shrubs, grass and ground cover

Status: implemented; visual and performance acceptance remains partial. Documentation reorganized in **R-1696** and merged with the former vegetation realism plan (epic **R-1319**) in **R-1704**. Implemented: procedural tree species with seasons, wind and city LOD; shared wind field (**R-1321**); procedural textures (**R-1329**); ecology placement (**R-1322**); seamless-city rooting and the coastal pine heath (**R-1617**); Weber-Penn tree skeletons and leaf clusters (**R-1324**); city blade grass (**R-1323**, partial); 3D wild plants with seasons (**R-1519**, **R-1557**, **R-1559**); snow cover and the trail buffer (**R-1327**, partial); moss, lichen and the forest floor (**R-1661**, **R-1683**, **R-1684**). Grain fields, the full tree LOD chain and impostors are [planned](#roadmap).

**Start here:** this is the one page for everything that grows in the 3D view. There are **20 procedural tree species** plus a tall city pine form, shrubs that reuse those trees, blade grass, eight 3D wild-plant models, ecology rules that decide where each grows, and moss, lichen and fungi on bark, walls and the forest floor. A tree is assembled from a branching skeleton, wood, leaf-cluster cards and optional fruit; it is not normally a separate `.glb` file. The seamless city adds metre-scale bark, camera-dependent crown detail and whole-tree wind bending. District (blueprint) maps share species and seasons but not every city presentation feature.

Scope: identifying, locating and changing vegetation models, their placement and rendering. Presentation only: no damage, felling, harvesting, collision changes or saved per-plant state. Out of scope: a crop or harvest mechanic (would need an ADR), new biomes, imported game assets, a renderer change (GL Compatibility stays). Farmland crops are owned by [Farmland](./FARMLAND.md); the wider calendar by [Seasons](./SEASONS.md).

## Find what you need

| Question | Go to |
|---|---|
| What does it look like, moving and through the year? | [Visual tour](#visual-tour) |
| Which trees exist? | [Tree species](#tree-species) |
| Where is the model or texture I should edit? | [Model sources and assets](#model-sources-and-assets), [procedural textures](#procedural-textures) |
| How are branches, leaves and bark built? | [From species to rendered tree](#from-species-to-rendered-tree) |
| Why does a near tree look different from a distant one? | [Distance and detail](#distance-and-detail) |
| What changes with date, rain, wind or a weapon swing? | [Living behavior](#living-behavior) |
| Which bushes are visible? | [Shrubs](#shrubs) |
| How is grass drawn? Which wild plants exist? | [Grass](#grass), [Wild plants](#wild-plants-forbs) |
| Why does a plant grow here and not there? | [Placement and ecology](#placement-and-ecology) |
| Moss on walls, mushrooms in the woods? | [Moss, lichen and the forest floor](#moss-lichen-and-the-forest-floor-r-1661) |
| What may vegetation cost? | [Performance budgets](#performance-budgets) |
| Where should I make a particular change? | [Developer workflow](#developer-workflow) |
| How do I reproduce the views or check an edit? | [Preview and verification](#preview-and-verification) |
| What is not built yet? | [Known limits](#known-limits), [Roadmap](#roadmap) |

## Visual tour

Captures under `docs/reports/images/vegetation/`. The three animations were rendered for this page by [`tools/capture_vegetation_animations.gd`](../../tools/capture_vegetation_animations.gd) on 11 October 2026; the other plates are **existing repository captures** from the tasks named in their captions. Older plates are visual references, not proof that every rendering defect is resolved. Open an image for full resolution.

### In motion

**Wind on city trees.** Spruce, oak and birch at city scale (real city wood and near crowns) while the wind ramps from calm to a storm gust and back. The bole stays rooted, the trunk curves, limbs heave and twigs shiver; the flexible birch moves more than the stout oak. Shader time is pinned per frame, so the sequence is reproducible.

![Animation: spruce, oak and birch bending from calm to storm and back](../reports/images/vegetation/anim_tree_storm.gif)

**One gust front.** City blade grass in front of a birch line, wind left to right. The bend travels through the meadow as a visible wave and reaches the crowns later: one [shared wind field](#shared-wind-field-r-1321), not independent sine loops.

![Animation: a gust front rolling across blade grass and into a birch line](../reports/images/vegetation/anim_meadow_wind.gif)

**A year in twenty-four steps.** Birch, oak, maple, apple and spruce on the 1st and 15th of each month from April 1343 to March 1344: bud-burst, full summer leaf, apples in late summer, species-specific autumn colour and leaf loss, bare winter crowns, the evergreen spruce dulling in winter.

![Animation: five tree species through every half-month of a year](../reports/images/vegetation/anim_tree_seasons.gif)

Older motion evidence: [calm vs storm meadow](../reports/images/vegetation/r1321_wind_calm_storm.png), [moving-front analysis sheet](../reports/images/vegetation/r1321_wind_front_sheet.png) (each frame beside its gust map; the warm band should move left to right).

### Tree species and architecture

![Twenty procedural tree species with labels, normalized to a comparable display height](../reports/images/fauna/p0_103_tree_reference_sheet.png)

**A shape catalog, not a height chart:** the tool normalizes every tree to one display height. Compare the spruce cone, high pine crown, broad oak, drooping willow and compact orchard forms. Also: [relative heights](../reports/images/vegetation/r1324_tree_silhouettes_after.png), [crown close-ups](../reports/images/vegetation/r1324_tree_closeups_after.png) (each with a `_before` pair from R-1324).

![Bare procedural tree skeletons showing branching habits without foliage](../reports/images/vegetation/tree_wood_branch_flow.png)

Bare wood: pine, oak, apple, pear, ash, elm, willow, hazel and blackthorn. Use this view when changing forks, scaffold limbs, drooping shoots or multi-stem shrubs; foliage can hide a bad junction.

| Seasonal reference (R-1194) | Mature coastal pine heath (R-1617) |
|---|---|
| ![Birch, oak, maple, apple and spruce on 21 April, 20 May, 15 July, 5 October and 15 January](../reports/images/vegetation/r1194_after.png) | ![Inside the coastal pine heath at eye level](../reports/images/vegetation/r1617_pine_heath_eye.jpg) |
| Rows: birch, oak, maple, apple, spruce. Columns: 21 April, 20 May, 15 July, 5 October, 15 January. | Tall clear boles of `pine_tall`, distinct from the ordinary city pine. [Wide view](../reports/images/vegetation/r1617_pine_heath_wide.jpg). |

### City-scale detail

| Spruce needles at arm's length | Oak bark | Birch bark |
|---|---|---|
| ![City spruce close-up with real 3D needle fronds](../reports/images/vegetation/veg_city_spruce_macro_after.jpg) | ![Oak trunk close-up](../reports/images/vegetation/veg_city_oak_bark_close.jpg) | ![Birch trunk close-up](../reports/images/vegetation/veg_city_birch_bark_close.jpg) |

| Example | Capture | What to inspect |
|---|---|---|
| Spruce beside a human | [Scale](../reports/images/vegetation/veg_city_spruce_scale.jpg), [gameplay camera](../reports/images/vegetation/veg_city_spruce_gameplay.jpg) | Trunk thickness, cone density and leaf scale |
| Pine near the camera | [3D needle crown](../reports/images/vegetation/veg_city_pine_macro_after.jpg) | Tufts have depth instead of flat boards |
| Spruce detail swap | [Near/macro comparison](../reports/images/vegetation/veg_city_spruce_near_macro_parity.jpg) | Needle volume; the swap keeps crown mass |
| Bark joints | [Oak](../reports/images/vegetation/veg_bark_joint_oak_before_after.jpg), [birch](../reports/images/vegetation/veg_bark_joint_birch_before_after.jpg), [spruce](../reports/images/vegetation/veg_bark_joint_spruce_before_after.jpg), [cherry](../reports/images/vegetation/veg_bark_joint_cherry_before_after.jpg) | Bark continuity across forks |

### Shrub examples

| Dog rose | Raspberry | Elder (hazel mesh) |
|---|---|---|
| ![City dog rose with arching canes and leaf cards](../reports/images/vegetation/veg_city_dog_rose_close.jpg) | ![City raspberry canes](../reports/images/vegetation/veg_city_raspberry_close.jpg) | ![Elder drawn with the hazel tree mesh](../reports/images/vegetation/veg_city_elder_close.jpg) |

### Grass and wild plants

| City grass at eye level | City grass, wide |
|---|---|
| ![City blade grass at eye level](../reports/images/vegetation/veg_city_grass_eye.jpg) | ![City blade grass from a wider view](../reports/images/vegetation/veg_city_grass_wide.jpg) |

![Lineup of the eight wild-plant models: dandelion in flower, in seed and as a rosette, plantain, white and red clover, burdock rosette and flowering burdock](../reports/images/vegetation/forbs_lineup.png)

| Dandelion | Plantain | Clover | Burdock |
|---|---|---|---|
| ![Dandelion flower, seed clock and rosette](../reports/images/vegetation/forbs_dandelion.png) | ![Broadleaf plantain with flower spikes](../reports/images/vegetation/forbs_plantain.png) | ![White clover mat and red clover](../reports/images/vegetation/forbs_clover.png) | ![Burdock rosette and flowering candelabra](../reports/images/vegetation/forbs_burdock.png) |

The same verge through the year ([wild-plant seasons](#wild-plant-seasons-r-1557)):

| May | June | October (wall foot) | January |
|---|---|---|---|
| ![Verge in May: dandelions flowering, clover and plantain in leaf](../reports/images/vegetation/forbs_season_may.png) | ![Verge in June: seed clocks, plantain spikes, clover heads](../reports/images/vegetation/forbs_season_june.png) | ![Wall foot in October: rosettes and dry burdock](../reports/images/vegetation/forbs_season_october.png) | ![Verge in January: nothing above ground](../reports/images/vegetation/forbs_season_january.png) |

Habitats: [verge](../reports/images/vegetation/forbs_verge.png), [wall foot](../reports/images/vegetation/forbs_wall.png), [meadow](../reports/images/vegetation/forbs_meadow.png); [leaf-only and dry variants](../reports/images/vegetation/forbs_seasonal_studio.png). Blueprint maps: dandelion [before](../reports/images/vegetation/blueprint_forbs_dandelion_before.png) / [after](../reports/images/vegetation/blueprint_forbs_dandelion_after.png), burdock [before](../reports/images/vegetation/blueprint_forbs_burdock_before.png) / [after](../reports/images/vegetation/blueprint_forbs_burdock_after.png).

### Where things grow (ecology)

Each plate is ecology off | on on `viru_gate_foreland` (R-1322).

![Water edge: sedge and nettle on the bank with ecology on](../reports/images/vegetation/r1322_water_edge.png)

Also: [woodland edge](../reports/images/vegetation/r1322_woodland_edge.png) (scatter trees thinned and redistributed by fertility), [road verge](../reports/images/vegetation/r1322_road_verge.png) (tree and bush cleared from the wall foot), [a clear bridge deck](../reports/images/vegetation/r1617_bridge_clear_tartu.jpg) (R-1617 rooting rules).

### Moss, lichen and the forest floor

| North side of a birch | North wall foot | Forest floor, April | Forest floor, August |
|---|---|---|---|
| ![Moss skirt and lichen on the north side of a birch, with tinder brackets](../reports/images/vegetation/r1684_tree_north_moss.jpg) | ![Cushion moss at the foot of a north wall](../reports/images/vegetation/r1661_wall_moss_closeup.jpg) | ![False morels and moss cushions in April](../reports/images/vegetation/r1661_forest_floor_april.jpg) | ![Chanterelles in August](../reports/images/vegetation/r1661_forest_floor_august.jpg) |

Also: [whole north wall](../reports/images/vegetation/r1661_wall_north_moss.jpg), [shaded ground strip](../reports/images/vegetation/r1661_shaded_ground.jpg), [woods in April](../reports/images/vegetation/r1661_woods_april.jpg) and [August](../reports/images/vegetation/r1661_woods_august.jpg), roofs: [tile](../reports/images/vegetation/r1684_roof_tile.jpg), [shingle](../reports/images/vegetation/r1684_roof_shingle.jpg).

## Tree species

The stable catalog is [`MapViewTreeSpecies.ALL_SPECIES`](../../scripts/map/view3d/map_view_tree_species.gd). District variants use `tree.<species>` and may add `.small`, `.medium` or `.large`. `tree.mixed`, `tree.deciduous` and `tree.orchard` choose weighted pools rather than extra models. City plan entries use the species key without `tree.`.

All 20 species have entries in the [branching presets](../../scripts/map/view3d/tree_skeleton_weber_penn.gd) (`PRESETS`) and [size/leaf profiles](../../scripts/map/view3d/map_view_tree_mesh_profiles.gd) (`profile_for`). These are the editable model sources; there is no exported model file per row.

| Tree | Model key | Habit (what the player sees) | Seasonal group / fruit |
|---|---|---|---|
| Norway spruce | `spruce` | Cone with whorls down to the lower stem, hanging shoots, low skirt | Evergreen |
| Scots pine | `pine` | Clear bole, high open irregular crown, needles in terminal tufts | Evergreen |
| Silver birch | `birch` | Narrow flame of airy sprays over a white bole | Early; gold autumn |
| Pedunculate oak | `oak` | Forks low into a broad crooked crown | Late; brown autumn |
| Alder | `alder` | Compact branching, rounded broadleaf mass | Early; muted olive-brown autumn |
| Eurasian aspen | `aspen` | Slender upright form, relatively high crown | Early; yellow/orange autumn |
| Norway maple | `maple` | Dome, lobed leaf-card family | Late; red/orange autumn |
| Small-leaved linden | `linden` | Full dome, heart-shaped leaf-card family | Late; yellow autumn |
| European ash | `ash` | High airy dome, shoot ends curl up | Late; shared autumn palette |
| Wych elm | `elm` | Low fork into a broad dome with arching shoots | Late; yellow autumn |
| Willow | `willow` | Short leaning bole, ascending limbs, hanging shoot ends (not the later ornamental weeping willow) | Early; shared autumn palette |
| Rowan | `rowan` | Slender two-stemmed oval | Early; red/orange, berries Aug-Nov |
| Hazel | `hazel` | Multi-stemmed stool with no trunk | Early; no modeled nuts |
| Juniper | `juniper` | Compact evergreen column | Evergreen |
| Apple | `apple` | Short bole breaking into four crooked scaffold limbs, crown wider than tall | Early; fruit Aug-Oct |
| Sour cherry | `cherry` | Small multi-stemmed rounded crown with hanging shoots | Early; fruit July |
| Plum | `plum` | Upright irregular oval | Early; fruit Aug-Sep |
| Pear | `pear` | Tall narrow pyramid on a central leader | Early; fruit Aug-Oct |
| Hawthorn | `hawthorn` | Short divided stem under a dense crooked crown | Early; rusty autumn, berries Aug-Nov |
| Blackthorn | `blackthorn` | Multi-stemmed stool, low and dense | Early; sloes Sep-Nov |

"Early" and "late" are rendering groups, not botanical simulations. Leaf-card families are shared: ash, rowan and willow borrow the birch tile, so compound or narrow leaves are not reproduced exactly. Species identity comes from branching, proportions, tint and bark as well as the card. The [flora ledger](../FLORA_FAUNA.md#tree-model-ledger-2020) records authored district-map locations; it is not evidence that every species appears in every scene. Only Baltic 1343 species are allowed ([`FLORA_FAUNA.md`](../FLORA_FAUNA.md)).

**City form, not a 21st species:** `pine_tall` is defined in [`MapViewTreeMeshes.CITY_FORMS`](../../scripts/map/view3d/map_view_tree_meshes.gd). It maps to `pine` for needles, bark, wind, seasons and macro fronds, with its own skeleton profile: `crown_start` 2.25 of 3.35 mesh units, 13 primary limbs, shorter level-1 limbs (`level_overrides`) and needles only on the outer third of each shoot (`preset_overrides`, `cluster_span` 0.32). `MapViewTreeMeshes.base_species()` resolves a form for materials. [`CityVegetationBuilder.HEIGHT_M`](../../scripts/city/city_vegetation_builder.gd) gives it 23 m and `TRUNK_DIAMETER_M` 0.52 m, versus 10 m for ordinary pine (scaling the 10 m pine instead would give a ~15 m wide crown starting a third of the way up). Other city targets: spruce 9.5 m, birch 9 m, oak 10 m, apple/cherry 4 m, juniper 2.5 m; nominal presentation sizes, varied per plan entry.

## Model sources and assets

Most trees are **cached procedural `ArrayMesh` geometry**. The species chooses a growth preset; the generator creates branches and twig anchors; the mesh builder emits wood, canopy and optional fruit. Instances reuse those meshes. Changing a mesh profile is a model edit even though no Blender or GLB file changes.

| Part to open | Source / asset | Responsibility |
|---|---|---|
| Species registry | [`map_view_tree_species.gd`](../../scripts/map/view3d/map_view_tree_species.gd) | Stable IDs, size classes, weighted pools, tints, bark families |
| Branching model | [`tree_skeleton_weber_penn.gd`](../../scripts/map/view3d/tree_skeleton_weber_penn.gd), `PRESETS` | Trunk forks, branch levels, curvature, twig clusters; all 20 species |
| Dimensions and leaves | [`map_view_tree_mesh_profiles.gd`](../../scripts/map/view3d/map_view_tree_mesh_profiles.gd) | Height/radius, leaf sizes, density and fruit settings |
| Mesh assembly and city forms | [`map_view_tree_meshes.gd`](../../scripts/map/view3d/map_view_tree_meshes.gd) | `wood_mesh`, `canopy_mesh`, `fruit_mesh`; `city_*` variants, caching, scale corrections, LOD geometry |
| Leaves, cards, needles | [`map_view_leaf_geometry.gd`](../../scripts/map/view3d/map_view_leaf_geometry.gd) | Folded geometry, card UVs, atlas family mapping (`CARD_TILES`), round needles |
| Leaf-cluster texture | [Atlas](../../assets/materials/pbr/foliage_cards/leaf_card_atlas.png), [normal](../../assets/materials/pbr/foliage_cards/leaf_card_normal.png), [surface](../../assets/materials/pbr/foliage_cards/leaf_card_surface.png) | Shared textures; bound in the wind materials |
| City bark | [Birch](../../assets/materials/pbr/bark_birch/), [oak](../../assets/materials/pbr/bark_oak/), [grey](../../assets/materials/pbr/bark_grey/), [pine](../../assets/materials/pbr/bark_pine/), [spruce](../../assets/materials/pbr/bark_spruce/), [cherry](../../assets/materials/pbr/bark_cherry/) | Albedo/normal pairs; `bark_plate_for` selects the family |
| Materials | [`map_view_wind_materials.gd`](../../scripts/map/view3d/map_view_wind_materials.gd), [`map_view_prop_materials.gd`](../../scripts/map/view3d/map_view_prop_materials.gd) | Crown, bark, fruit, grass, seasonal and wetness parameters |
| Shrub canes | [`map_view_bush_meshes.gd`](../../scripts/map/view3d/map_view_bush_meshes.gd) | Dog rose and raspberry city meshes |
| Grass blades | [`map_view_foliage_meshes.gd`](../../scripts/map/view3d/map_view_foliage_meshes.gd) (`grass_blade_clump_mesh`), [`map_view_grass.gdshader`](../../scripts/map/view3d/map_view_grass.gdshader) | Blade clump mesh and grass shader |
| Wild plants | [`city_forb_meshes.gd`](../../scripts/city/city_forb_meshes.gd), [`city_forb.gdshader`](../../scripts/city/city_forb.gdshader), [`forb_leaf_detail.png`](../../assets/vegetation/forbs/forb_leaf_detail.png) | Eight forb models and their shader |

**Separate authored landmark:** the [sacred-grove ancient oak GLB](../../assets/props/environment/sacred_grove_ancient_oak/sacred_grove_ancient_oak.glb) is a distinct prop, not the source of procedural `tree.oak`; it does not join the crown, LOD or strike systems. Provenance and approval live in [`assets/SOURCES.csv`](../../assets/SOURCES.csv). If any code or asset is copied from an open-source project, add it there with its license first.

### Procedural textures

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

## From species to rendered tree

```text
Authored map scatter / city plan tree entry
  -> species key + position + size
  -> growth profile + branching preset
  -> deterministic skeleton: trunk, branches, twig ends
  -> cached wood mesh + canopy mesh + optional fruit mesh
  -> spatial/species MultiMesh batches
  -> seasonal materials + weather + camera-dependent detail
```

Placement is separate from appearance: see [Placement and ecology](#placement-and-ecology). One species can have many placements without many generated models: **mesh caching** avoids rebuilding geometry and **MultiMesh** draws instances together. Neither removes the cost of overlapping leaf cards, shadows or nearby macro crowns.

### Skeleton (R-1324)

[`TreeSkeletonWeberPenn`](../../scripts/map/view3d/tree_skeleton_weber_penn.gd) implements Weber and Penn, "Creation and Rendering of Realistic Trees" (SIGGRAPH 1995) in GDScript (the GPL Blender Sapling add-on was not used). The trunk takes lean, root flare and taper; each branch level has its own count, length (scaled by a crown shape ratio), down angle, golden-angle phyllotaxis, curvature and an attraction term (gravity droop when negative, phototropism when positive). A preset's `splits` forks the bole into `splits + 1` leaders at `split_height` (R-1391): one split is the fork of oak, maple, elm and rowan; a split near the ground with several leaders is a stool (hazel, blackthorn); a split at a third of the height is an orchard head (apple, cherry, plum, willow, hawthorn). Leaders start slightly inside the bole so no flat cap shows. [`MapViewTreeMeshes.build_skeleton`](../../scripts/map/view3d/map_view_tree_meshes.gd) falls back to the legacy [`MapViewTreeMeshSkeleton`](../../scripts/map/view3d/map_view_tree_mesh_skeleton.gd) for an unknown species; both return the same dictionary. Scale comes from the profiles (`trunk_height`, `trunk_radius`, `crown_start`, `primary_count`; city overrides in `CITY_PROFILE_OVERRIDES`), and a primary limb is never dropped by the segment budget.

- **Smooth limbs.** Limbs are resampled along a cubic Hermite curve (`smooth_polyline`, `BRANCH_SMOOTH_SUBDIV` 3 per coarse piece, 4 in the legacy path), so direction changes read as bends.
- **Branch collars.** `_append_branch_collar` adds a short concave flared cone at every branch base (1.25x on twigs up to 2.0x on large limbs, capped below the parent radius), so limbs blend into the parent.
- **Ground contact.** `_append_root_base` widens the bole into a concave root flare with continuous bark UVs; species in `ROOTED_SPECIES` also get 3-5 buttress roots. `CityVegetationBuilder.litter_mesh` scatters leaf flecks or needle strokes (`CONIFERS`) around about 65 % of city trees (`LITTER_SHARE`), thickest at the foot, not under shrubs.

### Wood and bark

Tapered tubes form trunks and limbs; foliage clusters sit on shoot ends. City wood uses realistic trunk diameters and bark plates tiled along limbs at about 0.55 m. Bark UVs follow the branch frame, so a texture does not restart every segment. Bark **families** are shared: aspen uses birch, juniper spruce, orchard trees cherry, many broadleaves grey. District wood keeps its older procedural bark path.

### Foliage and lighting

A crown mixes folded silhouette leaves with **folded cluster cards**: a small folded surface carrying a transparent image of several leaves or a needle spray. `_append_twig_clusters` places cards over the outer `cluster_span` of each shoot end; clusters near the crown axis get fewer, smaller, darker cards. The alpha cutoff removes empty texels without blend sorting. This makes dense crowns affordable, but cards can look flat edge-on or thin out in distant mips.

The [canopy shader](../../scripts/map/view3d/map_view_canopy.gdshader) combines species/season tint, darker interiors, wrapped crown normals (`_emit_card` bends only shell clusters onto the crown normal), chlorophyll-tinted backlight (`leaf_translucency`), rain wetness and wind. Changing texture brightness alone is not a reliable fix for washed-out foliage.

## Distance and detail

City detail follows the **active camera**. [`CityTreeLod`](../../scripts/city/city_tree_lod.gd) moves individual trees between shared batches with separate enter/exit distances to avoid flicker. Graphics quality scales the radii.

| Tier | Base rule | What is drawn |
|---|---|---|
| Macro conifer | Enter within 10 m, leave beyond 13 m | Spruce/pine/juniper outer shoots as real 3D needle fronds over darker inner cards |
| Near crown | Enter within 34 m, leave beyond 42 m | Smaller clusters: 0.62 m broadleaf cards, 0.58 m conifer cards, 0.28 m on small shrub trees |
| Far crown | Outside the near set | Cheaper large-card crown on the same skeleton |
| Coarse crown and wood | Distant batches, quality-dependent | Reduced crown triangles and trunk-only wood; range and shadows owned by `CityVegetationBuilder` |

A card size is the **whole twig cluster**, not one leaf. Macro needles are deliberately larger than real ones to stay visible. The 480k macro-frond cap covers fronds, not the whole tree; a close spruce is still expensive, so the macro tier must stay local to the camera. The coarse crown is reduced geometry, not a baked billboard; impostors are [planned](#roadmap). District maps have no LOD chain yet. LOD choice is reconstructed from the camera and never saved.

## Living behavior

### Seasons and fruit

[`VegetationPhenology.state_for(species, date)`](../../scripts/map/view3d/vegetation_phenology.gd) computes the look from the campaign date ([animation](#in-motion)):

- Spring expands small, pale, sparse leaves into a full crown; early and late groups use different curves.
- Summer is full leaf. Fruit meshes show only in the species windows above; presentation, not harvesting.
- Autumn mixes species colours within each crown and gradually sheds leaves; a per-cluster seed decides which clusters turn and fall first.
- Winter leaves deciduous trees bare. Spruce, pine and juniper keep needles with a duller, bluer tint.

The opening-date April greenery is an intentional art choice, earlier than typical Tallinn birch budburst. See [Seasons](./SEASONS.md) for the wider calendar. No tree blossom, no snow on branches.

**Snow (R-1327).** `VegetationPhenology.snow_cover_for(date)` (0 before mid-December, 1 by mid-January, melts out 1 March to early April) drives `snow_cover` on the grass shader (blades sink, tips whiten) and the blended terrain shader (ground tint, weaker on trodden mud), pushed from `apply_vegetation_season`. Date-only, no weather input, no depth.

### Rain

Active rain darkens leaves and bark and changes their gloss through the material layer; leaves do not wait for puddles. Compare the same tree, camera and light with only rain changed; a fog-heavy rain screenshot cannot isolate a material problem.

<a id="shared-wind-field-r-1321"></a>

### Shared wind field

One weather-driven wind field (**R-1321**) supplies crowns, grass, wild plants, flags, banners, sails, ropes and nets, so a gust crosses a field, reaches the trees, then the flags ([animation](#in-motion)). The sea has its own wind path; smoke and rain particles do not consume this field.

[`WindField`](../../scripts/map/view3d/wind_field.gd) publishes global shader parameters through `MapViewWindMaterials.apply_world_wind`; they are declared in [`project.godot`](../../project.godot) because the wind shaders are preloaded (heading, strength, gust amplitude/wavelength, speed, turbulence). The [shader include](../../scripts/map/view3d/wind_field.gdshaderinc) samples analytic value noise by world position and time (no texture sampler, exact CPU mirror). Phase is `dot(world_xz, wind_dir) * k - time * speed` at two scales, so the bend travels as a wave. The front is sampled once per tuft, tree or staff, not per vertex. Grass gets a bend sheen so fronts read at distance; crowns use the cheaper `wind_pressure_coarse` because their vertex cost multiplies by shadow cascades. Direction, strength and gustiness come from the weather state ([`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md)).

### Whole-tree bending (city)

City bark and every crown LOD share [`tree_wind.gdshaderinc`](../../scripts/map/view3d/tree_wind.gdshaderinc) (`tree_wind_offset()`), so leaves stay on their shoots. `city_wood_mesh` stores limb flexibility in `COLOR.a` (`limb_flex(radius)`: 0 bole, 1 twig tips). The model is a loaded cantilever in metres: drag load `u^1.4` saturating at 3, bole deflection `y^2 (3L - y) / (2 L^3)` with L = 9 m (about 1.3 m at the top of a 9 m tree in a storm gust, centimetres in a breeze), a ~0.5 Hz sway ring on gusts, per-limb cantilevers whose tip lag grows with the square of reach and ring at ~1.2 Hz, a twig shiver (`flex^2`), and an arc term that lowers the crown as the bole leans. Strong-gust lean is bounded at 30 degrees. Per-species stiffness is `sway_strength` relative to 0.06, so tall pines move more than stout oaks. An analytic approximation: it neither breaks branches nor moves collision.

**District difference:** crowns move but wood stays rigid (`MapViewMaterials.bark`). Do not approve city bending from a district capture.

### Weapon response, falling leaves and ground litter

| Effect | Where / implementation | Persistence |
|---|---|---|
| Player swing shakes a crown and releases a burst | District `MapView3D.strike_vegetation` and [`TreeLeafFall3D`](../../scripts/map/view3d/tree_leaf_fall_3d.gd); reach, facing and attack cone | Temporary shake and particles, no damage |
| Ambient leaf fall near trees | District `TreeLeafFall3D`; city [`CityLeafFall`](../../scripts/city/city_leaf_fall.gd) samples nearby trees from `CityTreeLod` | Particles disappear at the ground |
| Gust leaf loss | `TreeLeafFall3D` `GustLeaves` stream upwind of the player when local wind passes ~0.9 (full at 2.0), leafed species only (`gust_leaf_rate`) | Particles only |
| Leaves/needles lying under city trees | `CityVegetationBuilder.litter_mesh` | Deterministic decoration, not accumulated particles |

A qualifying district swing can shake a tree even when it missed an enemy. Heavy attacks shake harder; autumn yields more leaves, bare crowns none, conifers a few needles. Shake decays over about 1.8 s. NPC attacks, spells and projectiles do not use this path; the city ambient emitter is not evidence of city melee wiring.

## Shrubs

City shrubs reuse tree infrastructure where appropriate ([images](#shrub-examples)). The authoritative mapping is [`CityVegetationBuilder.SHRUB_AS_TREE`](../../scripts/city/city_vegetation_builder.gd):

| City plan species | Rendered model |
|---|---|
| `elder`, `hazel_shrub`, `guelder_rose`, `willow_shrub`, `alder_shrub` | Hazel tree mesh, scaled as a shrub |
| `hawthorn`, `spindle` | Hawthorn tree mesh |
| `blackthorn`, `sea_buckthorn` | Blackthorn tree mesh |
| `juniper_shrub` | Juniper tree mesh |
| `dog_rose`, `raspberry` | Curved canes with leaf cards from [`MapViewBushMeshes.city_mesh_for`](../../scripts/map/view3d/map_view_bush_meshes.gd) |

Dog rose uses rowan leaf material and seasons; raspberry uses hazel. Card length 0.24 m; no flowers, hips or fruit. Species with neither a tree proxy nor a city mesh are skipped rather than drawn as a blob.

### Legacy shrub mesh removed

District maps no longer draw the old ellipsoid/cone shrub meshes: `bush.*` scatter and authored `bush` props have no model. The data still exists and still affects movement slow-down through [`TerrainVegetation`](../../scripts/map/terrain_vegetation.gd) and composition accounting. **Invisible shrub geometry does not mean the gameplay data was deleted.** Restoring district shrubs needs a new reviewed model, not the old fallback.

## Grass

Implemented for the seamless city (**R-1323**; the task stays open for the blueprint-map carpet and grass seasons). Decision (user, 2026-10-08): the ground texture is a primitive colour field and every recognisable plant is 3D geometry. Look target: Ghost of Tsushima fields of individual curved blades with wind rolling across them as a visible front.

- **Ground.** City plates (`grass_ground_*_array.jpg`) and the map-view plate (`pbr/grass/grass_*.png`) are drawn by [`generate_simple_grass_plates.py`](../../tools/assets/generate_simple_grass_plates.py): soft tonal patches and fine grain, no plants in the image. Slice order 0-7 green, 8 dry, 9 moss, 10 litter, 11 trodden.
- **Blades.** [`CityGrass`](../../scripts/city/city_grass.gd) scatters `grass_blade_clump_mesh` (six curved tapered blades, five triangles each, cached) in three tiers, all MultiMesh with GPU wind and trampling:

| Tier | Chunk | Density | Range (scale cross-fade, no alpha fade) | Material |
|---|---|---|---|---|
| Near | 8 m | 4.5 clumps/m2 | 0 to 12 m, shrinks out 12-17 m | `grass_blade_tier(true)` |
| Mid | 16 m | 1 clump/m2, larger | Grows in 9-15 m, shrinks out 38-46 m | `grass_blade_tier(false)` |
| Far | 32 m | 0.25 clumps/m2, 2x width (`FAR_WIDTH_BOOST`) | Grows in 36-48 m, shrinks out 100-118 m | `grass_blade_far()` |

`CityGrass._stream` builds missing chunks nearest first within a 3.5 ms frame budget (at least one per frame), near before mid before far. GL Compatibility has no compute shaders, so placement stays on the CPU. Mid chunks also hold 3D yarrow accents (`PlantMeshes`, 0.012/m2).
- **Shading.** Root-to-tip gradient with warm tip and per-clump dry tip, root colour melting into the ground (`root_tint`), rounded normal across the width, backlight, wind sheen. No shadows.
- **Trampling.** `VegetationInteractionBuffer` keeps a ring of 8 recent player positions so a flattened path remains for a few seconds; NPCs are not fed yet.
- **Blueprint maps** still use textured tuft cards from the R-1103 atlas for the eye-level carpet (`MapViewTerrainDetails`) and scatter tufts.

## Wild plants (forbs)

Implemented (**R-1519**, seasons **R-1557**, blueprint maps **R-1559**). Decision (user, 2026-10-09): accent diamonds and flat single-tone leaves were rejected; plants must read as real botany up close. [`CityForbMeshes`](../../scripts/city/city_forb_meshes.gd) builds eight cached models from botanical proportions ([images](#grass-and-wild-plants)), each with a far variant at a quarter of the triangles or less:

| Plant | Models | Habitat (`CityForbs`) |
|---|---|---|
| Dandelion | In flower, in seed (clock), leaf rosette: runcinate hooked lobes, purplish petiole, hollow scapes | Short grass round settlement |
| Broadleaf plantain | Ribbed ovate leaves, knobbly spikes with a stamen band | Worn verges and yards, pressed flat where trodden |
| White clover | Dense 70-leaf creeping mat, globular heads browning at the base | Patches of short turf |
| Red clover | Upright stems, elliptic leaflets, pink-purple globes | Uncut meadow only |
| Burdock | First-year rosette of wavy heart leaves on red petioles; second-year 1.1-1.3 m candelabra with hooked burrs | Wall feet and road edges, flowering more where nobody cuts |

- **Leaf detail.** Silhouettes are geometry; venation is the procedural atlas [`forb_leaf_detail.png`](../../assets/vegetation/forbs/forb_leaf_detail.png) from [`generate_forb_leaf_atlas.py`](../../tools/assets/generate_forb_leaf_atlas.py), a detail multiplier on UV2 (0.5 = x1; tile order is a contract with the `TILE_*` constants).
- **Placement.** [`CityForbs`](../../scripts/city/city_forbs.gd) reads the fields that drive grass height (`CityGrass.wildness_at`, cached `road_distance_at`, `house_distance_at`, `bareness_at`). Patches come from fixed-seed simplex noise. In tall grass red clover and dandelion scale up evenly (a vertical stretch turned clover into thistles).
- **Drawing.** 8 m chunks within 6 chunks of the player, streamed after the mid grass tier. One MultiMesh per model and detail level (near within 9 m of the player's chunk, `NEAR_RANGE`), refilled from cached per-chunk buffers: about 16 draw calls. [`city_forb.gdshader`](../../scripts/city/city_forb.gdshader): shared wind, per-part flutter, shrink-out fade (small plants 24-32 m, burdock 38-46 m), pale woolly burdock undersides, no shadows. Dandelion yellow stays below full brightness because AgX bleaches saturated yellow to peach.

### Wild-plant seasons (R-1557)

[`VegetationPhenology.forb_phase`](../../scripts/map/view3d/vegetation_phenology.gd) is a pure function of `GameCalendar.day_of_year` (Tallinn-area timings): `none` before 15 April and after 15 November, `leaves`, `flower`, `flower_seed` (dandelion in June), `burrs`, `dry_burrs`.

| Dates | Dandelion | Plantain | White / red clover | Burdock |
|---|---|---|---|---|
| 15-30 April | rosettes | rosettes | leaves | rosettes |
| May | 60 % flowering, rest rosettes | rosettes | leaves | rosettes |
| June | flowers, seed clocks, rosettes | 80 % spiked | in flower | rosettes |
| July-August | rosettes | 80 % spiked | in flower | rosettes, second-year plants with green burrs |
| September | rosettes | 80 % spiked | leaves | rosettes, dry brown burr stalks |
| October | rosettes | rosettes | leaves | rosettes, dry brown burr stalks |
| 1-15 November | rosettes | rosettes | leaves | rosettes |
| 16 November - 14 April | none | none | none | none |

Out-of-season models are the same plants without heads (`plantain_leaves`, `white_clover_leaves`, `red_clover_leaves`, `burdock_dry`). The season only picks which model a candidate becomes (`CityForbs._kind_for(species, pick, wild, phase)`); it never changes random draws, so every spot keeps its plant all year. `CityForbs.set_calendar_date` (from `CityMapView.set_calendar_date`) drops cached chunks only when `season_key` changes. Nothing is saved.

**Blueprint maps (R-1559).** `plant.plantain`, `plant.dandelion`, `plant.clover` and `plant.burdock` zones scatter the same models with `CityForbs.material_unfaded()` (no distance shrink: the map camera is far). `MapViewPlantSpecies.forb_kind_for(species, roll)` picks a fixed high-summer mix from a cell hash (plantain 80 % spike; dandelion 50 % flower, 20 % clock, 30 % leaves; clover 70 % white; burdock 35 % flowering). The `plant.*` IDs are unchanged; other species keep `MapViewPlantMeshes`.

## Placement and ecology

Look target (the Horizon lesson): realism comes more from where things grow than from how each plant is drawn.

### District and blueprint maps (R-1322)

Nothing grows on a trodden road and the verge is thinner; trees and bushes keep a cell clear of roads and wall feet. Sedge crowds the first two cells of a bank, nettle wall feet and damp ground by water, fern and moss only under conifer shade, juniper dry limestone rims, field weeds only field margins, thickets wood edges. Grass and flowers thin under crowns and break into fertility patches. Trees are only ever thinned, never above the authored density.

[`VegetationEcology`](../../scripts/map/vegetation_ecology.gd) (`for_region(definition, grid, rect)`, `density(layer, cell)`, `understory(cell)`, fields `water_distance`, `road_distance`, `wall_distance`, `stone_distance`, `field_distance`, `woodland_shade`, `conifer_shade`, `fertility`, `litter`) is built per chunk by [`MapViewMeshBuilderScatter.begin_scatter`](../../scripts/map/view3d/map_view_mesh_builder_scatter.gd); `collect_rows` multiplies each layer's chance by `density` and appends one understory pick per cell using existing meshes and batches. The urban density multiplier still applies. `MapViewMeshBuilderScatter.ecology_enabled` is a capture-only switch.

Fields are capped at 8 cells and evaluated over the chunk grown by that margin, so chunk splits give byte-identical results from the compiled definition, grid and seed alone. The authored override mask (`vegetation_mask`, [`MAP_AUTHORING.md`](../MAP_AUTHORING.md#ecology-placement-and-the-vegetation-override-mask-r-1322)) is the only ecology data on `MapDefinition`; it enters the fingerprint only when present. Authored props always win. Ecology is derived on demand rather than stored per cell, so preview, runtime, chunking and 3D agree without persisting chunk data. `mud` is plantable; limestone is the `stone` terrain; understory never lands on quays, floors or sand. Follow [map authoring](../MAP_AUTHORING.md) for placement edits; do not move generated nodes.

### Seamless city: rooting and the coastal pine heath (R-1617)

[`CityVegetationBuilder`](../../scripts/city/city_vegetation_builder.gd) consumes the plan's `trees` and `bushes`, converts model dimensions into metres and batches them in spatial chunks; [`CityWorld3D`](../../scripts/city/city_world_3d.gd) removes trees planted in water. See [Seamless city](./SEAMLESS_CITY.md) for plan ownership.

The plan generator [`vegetation_habitat.py`](../../tools/city/vegetation_habitat.py) holds two rule sets, applied by [`build_reval_city_plan.py`](../../tools/city/build_reval_city_plan.py):

- **`Clearance`.** A trunk keeps `TREE_ROAD_EDGE_M` (2 m) beyond every carriageway edge and `TREE_BRIDGE_CLEAR_M` (5 m) off every bridge or deck; shrubs keep `BUSH_BRIDGE_CLEAR_M` (1.5 m). No trunk on a road, no crown through the Hareapea, moat or harbour decks.
- **`Soil`.** Ground within `SAND_SHORE_M` (420 m) of the 1343 shoreline and at most `SAND_MAX_H_M` (10 m) above the 1343 sea is sandy; `heath_ground` excludes the beach strand (under 45 m or 3 m), which stays sand and juniper. On heath ground trees take `heath_species` (62 % `pine_tall`, 18 % `pine`, 8 % birch, 12 % juniper); `pine_heath()` adds the pine bor on a 7 m grid with its own RNG, broken by fbm glades. Inland loam keeps mixed spruce, oak and birch.

**Stable IDs.** Species re-picks use a position hash, the bor its own RNG after all seeded loops, and clearance runs last, so every field, pasture, wood, orchard and farmstead ID is unchanged. Nothing is saved: the plan is static content.

## Moss, lichen and the forest floor (R-1661)

Implemented (**R-1661**; wall plates **R-1683**; roof and bark plates **R-1684**). Decision (user, 2026-10-11): moss and lichens grow on the north side of some trees and buildings, on shaded ground and the forest floor; the forest also gets mushrooms. Out of scope: the woods' tall-grass understorey (R-1595), roof placement rules (R-1465), gathering mushrooms, blueprint-map forest floors (bark only), snow.

- **Tree trunks** (`map_view_bark_wind.gdshader`, city and blueprint trees): a moss skirt climbing highest (up to about 2.6 m) on the north side and pale lichen crusts from shin height, seeded per tree, so only some trunks carry them. Uniforms `moss_amount` (0.6), `lichen_amount` (0.5).
- **Walls** (`shade_growth` in `city_weathering.gdshaderinc`; half strength on outdoor limewash): cushion moss colonies at the damp foot of north faces up to about 1.6 m with a dark damp halo, sparse lichen rosettes (a few orange *Xanthoria*) above. Moss replaces the wall normal with its own relief; drier, higher cushions turn yellow-brown. South faces stay clean.
- **Roofs** (`city_weathered_roof.gdshader`, `city_tile_roof.gdshader`): the same plates on shingle, thatch and clay tiles; R-1465 placement unchanged. See [city roofs](./SEAMLESS_CITY.md#how-buildings-are-built).
- **Shaded ground** (`city_ground.gdshader`): the moss slice in ragged cushions where [`CityShadeMask`](../../scripts/city/city_shade_mask.gd) reports shade (R: strip north of each building, 0.9 of wall height, 2-8 units; G: forest density on a 12-unit grid). Trodden paths stay bare.
- **Forest floor** ([`CityForestFloor`](../../scripts/city/city_forest_floor.gd), built by `CityDressingBuilder` at `Dressing/ForestFloor`): two to four moss cushions round each tree of a closed stand (8+ forest neighbours within 15 units), biased north, plus fungi by mycorrhizal partner. One MultiMesh per kind and 96-unit chunk, lathe meshes with vertex colour, visible to 110 units (moss) and 70 (fungi). `set_calendar_date` toggles kinds via `kinds_in_season(day)`:

| Kind (`KIND_*`) | Species | Grows by | Days of year |
|---|---|---|---|
| `gyromitra` | false morel, *Gyromitra esculenta* | pine | 100-152 (April-May) |
| `chanterelle` | *Cantharellus cibarius*, troops of 3-7 | spruce, pine, birch | 182-280 |
| `porcini` | *Boletus edulis* | spruce, pine, birch, oak | 196-288 |
| `fly_agaric` | *Amanita muscaria* | birch, spruce | 205-295 |
| `bracket` | tinder fungus, *Fomes fomentarius*, 1-3 shelves | birch | all year |
| `moss` | moss cushions | any forest tree | all year |

On the slice's opening date (21 April 1343) the woods show moss, brackets and false morels.

**Plates and sampling.** [`assets/materials/pbr/wall_growth/`](../../assets/materials/pbr/wall_growth/) holds `wall_moss_albedo.png` (A = cushion height), `wall_moss_normal.png`, `wall_lichen.png` (A = rosette mask), built by `python3 tools/assets/build_wall_growth_plates.py` from gpt-image-1 sources recorded in `generated/openai/wall_growth_v1/prompt.json`. `CityBuildingBuilder.bind_ground` sets them as shader defaults on wall, limewash and roof shaders; `MapViewWindMaterials.bark_plate_wind` binds them explicitly for bark, including blueprint trees. [`city_growth_plates.gdshaderinc`](../../scripts/city/city_growth_plates.gdshaderinc) thresholds cushion height and rosette alpha against each caller's coverage field; two rotated moss samples at 0.32/0.47 m tiles break repetition; lichen at 0.5 m; missing plates give zero coverage. Bark uses its continuous mesh UVs, so growth does not swim under wind. Deterministic, seeded by position; nothing saved.

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
| Moss, lichen, fungi | `city_growth_plates.gdshaderinc`, `CityShadeMask`, `CityForestFloor` | North vs south faces; April vs August |
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

## Related systems

- [Farmland](./FARMLAND.md): crops, gardens, pastures and woods outside the walls.
- [Flora and fauna](../FLORA_FAUNA.md): species inventory and authored map evidence; [biomes and wildlife](../LOCATIONS/BIOMES_AND_WILDLIFE.md).
- [Seasons](./SEASONS.md) and [weather ground](./WEATHER_GROUND.md): date controls, snow and ground weather.
- [World presentation](./WORLD_PRESENTATION.md), [Seamless city](./SEAMLESS_CITY.md), [Map authoring](../MAP_AUTHORING.md): how and where vegetation is placed and drawn.
- [Art bible](../ART_BIBLE.md) ("Vegetation realism (P0-208)") and [asset provenance](../../assets/SOURCES.csv).

Implementation lineage, for lookup only: seasonal crowns/strikes **R-1187**; cluster cards **R-1194**; procedural atlas **R-1329**; shared wind **R-1321**; branching presets **R-1324**, orchard habits **R-1391**; city-scale pass **R-712**; shrub cards **R-1315**; macro needles **R-1404**; whole-tree storm bend **R-1433**; ecology **R-1322**; pine heath **R-1617**; city grass **R-1323**; forbs **R-1519**/**R-1557**/**R-1558**/**R-1559**; snow **R-1327**; moss and fungi **R-1661**/**R-1683**/**R-1684**; docs **R-1696**, **R-1704**.
