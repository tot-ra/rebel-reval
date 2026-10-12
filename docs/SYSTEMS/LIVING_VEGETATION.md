# Living vegetation: trees, shrubs, grass and ground cover

Status: implemented; visual and performance acceptance remains partial. Reorganized in **R-1696**, merged with the former vegetation realism plan (epic **R-1319**) in **R-1704**; rewritten feature by feature with pictures on 11 October 2026. Implemented: 20 procedural tree species with seasons, wind and city LOD; shared wind field (**R-1321**); procedural textures (**R-1329**); ecology placement (**R-1322**); seamless-city rooting and the coastal pine heath (**R-1617**); Weber-Penn skeletons and leaf clusters (**R-1324**); city blade grass (**R-1323**, partial); 3D wild plants with seasons (**R-1519**, **R-1557**, **R-1559**); snow cover (**R-1327**, partial); moss, lichen and the forest floor (**R-1661**, **R-1683**, **R-1684**). Not built: grain fields, the full tree LOD chain, impostors, grass seasons (see the [roadmap](./VEGETATION_ENGINEERING.md#roadmap)).

Scope: identifying, locating and changing vegetation models, their placement and rendering. Presentation only: no damage, felling, harvesting, collision changes or saved per-plant state. Out of scope: a crop or harvest mechanic (needs an ADR), new biomes, imported game assets, a renderer change (GL Compatibility stays). Farmland crops: [Farmland](./FARMLAND.md); calendar: [Seasons](./SEASONS.md). Budgets, workflow, capture commands, limits and roadmap: [Vegetation engineering](./VEGETATION_ENGINEERING.md).

**Every plant has its own card** with a model portrait in the [flora catalogue](../FLORA/README.md): [trees](../FLORA/README.md#trees), [shrubs](../FLORA/README.md#shrubs), [herbs and wild flowers](../FLORA/README.md#herbs-and-wild-flowers), [crops](../FLORA/README.md#crops), and a [wishlist](../FLORA/README.md#wishlist-common-estonian-plants-not-yet-in-the-game) of common Estonian plants still missing. This page explains the systems; the cards say what each plant is, where it grows and how it looks.

Pictures are repository captures under `docs/reports/images/vegetation/`. The three animations were rendered by [`tools/capture_vegetation_animations.gd`](../../tools/capture_vegetation_animations.gd) on 11 October 2026; older plates are visual references, not proof that every defect is resolved. Click an image for full resolution.

## At a glance

| Feature | Looks like | What drives it | Section |
|---|---|---|---|
| 20 tree species | Distinct silhouettes, forks, drooping or upright limbs | Species key, branching preset, size profile | [Trees](#trees) |
| Seasons | Bud-burst, full leaf, autumn colour, bare winter, fruit | Campaign date | [Seasons](#seasons-and-fruit) |
| Wind | One gust front crosses grass, then crowns; trunks bend | Weather state, shared wind field | [Wind](#wind) |
| Detail by distance | Needle fronds up close, cheap crowns far away | Camera distance | [Detail by distance](#detail-by-distance) |
| Shrubs | Canes and tree-mesh bushes | City plan species | [Shrubs](#shrubs) |
| Blade grass | Individual curved blades, trampling, snow | Wildness fields, player position | [Grass](#grass) |
| Wild plants | Dandelion, plantain, clover, burdock, oxeye daisy by month | Date, habitat fields | [Wild plants](#wild-plants-forbs) |
| Ecology | Sedge at the bank, clear road verges, pine heath on sand | Water, road, shade, soil fields | [Placement and ecology](#placement-and-ecology) |
| Moss and fungi | Moss on north sides, mushrooms in the woods | Sun side, shade mask, date | [Moss, lichen and the forest floor](#moss-lichen-and-the-forest-floor-r-1661) |

## Trees

A tree is assembled at runtime from a **branching skeleton**, wood, **leaf-cluster cards** and optional fruit; it is not a `.glb` file. Meshes are cached per species and drawn as MultiMesh batches, so one species can have many placements at no extra model cost. The seamless city adds metre-scale bark, camera-dependent crown detail and whole-tree wind bending; district (blueprint) maps share species and seasons but not every city feature.

```text
plan entry (species, position, size) -> growth profile + branching preset
  -> deterministic skeleton -> cached wood + canopy + fruit meshes
  -> MultiMesh batches -> seasonal materials, weather, camera detail
```

### Species

![Twenty procedural tree species with labels, normalized to a comparable display height|1000](../reports/images/fauna/p0_103_tree_reference_sheet.png)

*A shape catalog, not a height chart: every tree is normalized to one display height.* Real heights: [relative silhouettes](../reports/images/vegetation/r1324_tree_silhouettes_after.png) and [crown close-ups](../reports/images/vegetation/r1324_tree_closeups_after.png).

The registry is [`MapViewTreeSpecies.ALL_SPECIES`](../../scripts/map/view3d/map_view_tree_species.gd). District variants are `tree.<species>` (optionally `.small`, `.medium`, `.large`); `tree.mixed`, `tree.deciduous` and `tree.orchard` are weighted pools. City plans use the bare species key.

| Habit | Species (model key) |
|---|---|
| Evergreen | Norway spruce [`spruce`](../FLORA/trees/spruce.md) (cone, low skirt), Scots pine [`pine`](../FLORA/trees/pine.md) (clear bole, high open crown), juniper [`juniper`](../FLORA/trees/juniper.md) (compact column) |
| Tall, airy broadleaf | birch [`birch`](../FLORA/trees/birch.md) (white bole, gold autumn), aspen `aspen`, ash `ash`, alder [`alder`](../FLORA/trees/alder.md) |
| Broad dome, late leaf | oak [`oak`](../FLORA/trees/oak.md) (low crooked fork, brown autumn), maple [`maple`](../FLORA/trees/maple.md) (red/orange), linden `linden`, elm [`elm`](../FLORA/trees/elm.md) |
| Wet ground | willow [`willow`](../FLORA/trees/willow.md) (leaning bole, hanging shoots) |
| Orchard and fruit | apple [`apple`](../FLORA/trees/apple.md) (fruit Aug-Oct), sour cherry [`cherry`](../FLORA/trees/cherry.md) (July), plum [`plum`](../FLORA/trees/plum.md) (Aug-Sep), pear [`pear`](../FLORA/trees/pear.md) (Aug-Oct) |
| Small and thorny | rowan [`rowan`](../FLORA/trees/rowan.md) (berries Aug-Nov), hawthorn `hawthorn`, blackthorn [`blackthorn`](../FLORA/trees/blackthorn.md) (sloes Sep-Nov), hazel [`hazel`](../FLORA/trees/hazel.md) (stool, no trunk) |

"Early" and "late" leaf are rendering groups, not botanical simulation. Leaf-card families are shared (ash, rowan and willow borrow the birch tile), so identity comes from branching, proportions, tint and bark as well as the card. Only Baltic 1343 species are allowed ([`FLORA_FAUNA.md`](../FLORA_FAUNA.md)). `pine_tall` is a city form of `pine`, not a 21st species: 23 m, 13 primary limbs, needles on the outer third of each shoot; see `MapViewTreeMeshes.CITY_FORMS`.

![Inside the coastal pine heath at eye level](../reports/images/vegetation/r1617_pine_heath_eye.jpg)

*`pine_tall` in the coastal pine heath (R-1617).* [Wide view](../reports/images/vegetation/r1617_pine_heath_wide.jpg).

### Skeleton, wood and leaves (R-1324)

![Bare procedural tree skeletons: pine, oak, apple, pear, ash, elm, willow, hazel and blackthorn](../reports/images/vegetation/tree_wood_branch_flow.png)

*Bare wood. Use this view when changing forks or drooping shoots; foliage hides bad junctions.*

- **Branching.** [`TreeSkeletonWeberPenn`](../../scripts/map/view3d/tree_skeleton_weber_penn.gd) (Weber and Penn 1995, written from the paper in GDScript) gives each species a preset: trunk lean and taper, per-level branch count, angle, curvature and gravity or light attraction. `splits` forks the bole: one split is an oak or maple fork, many low splits a hazel stool, a split at a third of height an orchard head.
- **Smooth limbs and collars.** Limbs are Hermite-smoothed; each branch base gets a flared collar; boles widen into a root flare (buttress roots for `ROOTED_SPECIES`). About 65 % of city trees get litter of their own leaves or needles at the foot ([fallen leaves](#fallen-and-falling-leaves-r-1733)).
- **Bark.** City bark tiles along limbs at about 0.55 m with UVs that follow the branch frame; families are shared (aspen uses birch, juniper spruce, orchard trees cherry).
- **Leaves.** Crowns mix folded leaves with folded **cluster cards** (a small surface carrying an image of several leaves or a needle spray), placed over the outer `cluster_span` of each shoot. The [canopy shader](../../scripts/map/view3d/map_view_canopy.gdshader) adds species and season tint, dark interiors, wrapped normals, backlight, rain wetness and wind.

| Spruce needles at arm's length | Oak bark | Birch bark |
|---|---|---|
| ![City spruce close-up with real 3D needle fronds](../reports/images/vegetation/veg_city_spruce_macro_after.jpg) | ![Oak trunk close-up](../reports/images/vegetation/veg_city_oak_bark_close.jpg) | ![Birch trunk close-up](../reports/images/vegetation/veg_city_birch_bark_close.jpg) |

More: spruce [beside a human](../reports/images/vegetation/veg_city_spruce_scale.jpg) and [at gameplay camera](../reports/images/vegetation/veg_city_spruce_gameplay.jpg); [pine needle crown](../reports/images/vegetation/veg_city_pine_macro_after.jpg); bark continuity across forks on [oak](../reports/images/vegetation/veg_bark_joint_oak_before_after.jpg), [birch](../reports/images/vegetation/veg_bark_joint_birch_before_after.jpg), [spruce](../reports/images/vegetation/veg_bark_joint_spruce_before_after.jpg), [cherry](../reports/images/vegetation/veg_bark_joint_cherry_before_after.jpg).

### Detail by distance

City detail follows the **active camera** ([`CityTreeLod`](../../scripts/city/city_tree_lod.gd)); separate enter and exit distances avoid flicker, and graphics quality scales the radii.

| Tier | Base rule | Drawn |
|---|---|---|
| Macro conifer | in within 10 m, out beyond 13 m | Outer shoots as real 3D needle fronds over darker inner cards |
| Near crown | in within 34 m, out beyond 42 m | Small clusters (0.62 m broadleaf, 0.58 m conifer cards) |
| Far crown | beyond the near set | Cheaper large-card crown on the same skeleton |
| Coarse | distant batches | Reduced crown triangles, trunk-only wood |

| Near card crown | Macro fronds | Same view, swap boundary |
|---|---|---|
| ![Spruce needle detail at near tier](../reports/images/vegetation/veg_city_spruce_needles_close.jpg) | ![Spruce needle detail at macro tier](../reports/images/vegetation/veg_city_spruce_needles_close_macro.jpg) | ![Near versus macro comparison keeping crown mass](../reports/images/vegetation/veg_city_spruce_near_macro_parity.jpg) |

District maps have no LOD chain yet; impostors are planned. LOD choice is reconstructed from the camera and never saved.

## Seasons and fruit

[`VegetationPhenology.state_for(species, date)`](../../scripts/map/view3d/vegetation_phenology.gd) computes the look from the campaign date. Birch, oak, maple, apple and spruce on the 1st and 15th of each month, April 1343 to March 1344:

![Animation: five tree species through every half-month of a year](../reports/images/vegetation/anim_tree_seasons.gif)

| Season | What changes |
|---|---|
| Spring | Small, pale, sparse leaves expand into a full crown; early and late species follow different curves |
| Summer | Full leaf; fruit meshes show in the species windows above |
| Autumn | Species colours mix within a crown and leaves shed gradually; a per-cluster seed decides which turn first |
| Winter | Deciduous trees bare; spruce, pine and juniper keep needles, duller and bluer |

![Birch, oak, maple, apple and spruce on 21 April, 20 May, 15 July, 5 October and 15 January](../reports/images/vegetation/r1194_after.png)

*Rows: birch, oak, maple, apple, spruce. Columns: 21 April, 20 May, 15 July, 5 October, 15 January (R-1194).* April greenery on the opening date is an art choice, earlier than real Tallinn budburst. No blossom, no snow on branches.

**Snow (R-1327).** `VegetationPhenology.snow_cover_for(date)` is 0 before mid-December, 1 by mid-January and melts out from 1 March to early April. It sinks and whitens grass blades and tints the terrain (less on trodden mud). Date only: no weather input, no depth.

**Rain.** Active rain darkens leaves and bark and changes gloss through the material layer. Leaves do not wait for puddles.

## Wind

One weather-driven wind field (**R-1321**) supplies crowns, grass, wild plants, flags, banners, sails, ropes and nets. A gust crosses a field, then reaches the trees, then the flags. The sea has its own wind path; smoke and rain particles do not use this field.

![Animation: a gust front rolling across blade grass and into a birch line](../reports/images/vegetation/anim_meadow_wind.gif)

*Wind left to right. The bend travels through the grass as a visible wave and reaches the crowns later.* Analysis: [calm vs storm meadow](../reports/images/vegetation/r1321_wind_calm_storm.png), [front sheet](../reports/images/vegetation/r1321_wind_front_sheet.png) (each frame beside its gust map; the warm band should move left to right).

[`WindField`](../../scripts/map/view3d/wind_field.gd) publishes global shader parameters (heading, strength, gust amplitude and wavelength, speed, turbulence) declared in [`project.godot`](../../project.godot). The [shader include](../../scripts/map/view3d/wind_field.gdshaderinc) samples analytic value noise by world position and time at two scales, so the bend is a travelling wave, sampled once per tuft or tree rather than per vertex. Direction, strength and gustiness come from the weather state ([contract](../SKY_WEATHER_STATE_CONTRACT.md)). Do not add per-material wind clocks.

### Whole-tree bending (city)

![Animation: spruce, oak and birch bending from calm to storm and back](../reports/images/vegetation/anim_tree_storm.gif)

*Calm, storm gust, calm. The bole stays rooted, the trunk curves, limbs heave and twigs shiver; flexible birch moves more than stout oak.*

City bark and every crown tier share [`tree_wind.gdshaderinc`](../../scripts/map/view3d/tree_wind.gdshaderinc), so leaves stay on their shoots. Limb flexibility is stored in `COLOR.a` of the wood mesh (0 bole, 1 twig tip). The model is a loaded cantilever in metres: about 1.3 m of lean at the top of a 9 m tree in a storm gust and centimetres in a breeze, a slow sway ring after gusts, per-limb lag and a twig shiver, bounded at 30 degrees. Per-species stiffness is `sway_strength`, so tall pines move more than oaks. The bend is evaluated per vertex, so city wood is cut into rings at most `WIND_SECTION_METRES` (0.3 m) apart along every limb (`MapViewTreeMeshes._build_wood_mesh`); with rings only at skeleton joints a trunk bent as a polyline of 2.5 m straight pieces ([before / after](../reports/images/vegetation/r_wood_bend_before_after.png)). Covered by `tests/godot/test_tree_wood_wind.gd`. It is an analytic approximation: no breakage and no collision movement. **District maps:** crowns move but wood stays rigid; do not approve city bending from a district capture.

### Weapon response and falling leaves

| Effect | Implementation | Persistence |
|---|---|---|
| Player swing shakes a crown and releases leaves | District `MapView3D.strike_vegetation`, [`TreeLeafFall3D`](../../scripts/map/view3d/tree_leaf_fall_3d.gd) | Temporary, no damage |
| Ambient leaf fall | District `TreeLeafFall3D`; city [`CityLeafFall`](../../scripts/city/city_leaf_fall.gd) | Particles only |
| Gust leaf loss upwind of the player | `TreeLeafFall3D` `GustLeaves` when local wind passes about 0.9 | Particles only |
| Litter under city trees | `CityVegetationBuilder.litter_mesh` | Deterministic decoration |

### Fallen and falling leaves (R-1733)

Status: implemented (task **R-1733**). Scope: the leaf shape and colour of city litter, city ambient leaf fall (`CityLeafFall`) and district bursts, ambient and gust leaves (`TreeLeafFall3D`). Out of scope: litter amount by season, leaves piling up from particles, the crown leaf-card atlas.

![Leaf litter at the foot of a birch, maple, oak and pine: top row 20 October with this year's yellow, red and tan leaves, bottom row 15 July with weathered brown leaves and rust pine needles|1000](../reports/images/vegetation/leaf_litter_species_seasons.jpg)

*Top: 20 October. Bottom: 15 July. Left to right: birch, maple, oak, pine.* Falling leaves on a plain backdrop: [maple, birch, oak and rowan shedding](../reports/images/vegetation/leaf_fall_species.png).

Every fallen or falling leaf shows the leaf of its tree. The [species leaf atlas](../reports/images/vegetation/leaf_species_atlas_preview.png) holds one leaf per cell: birch, oak, maple, linden, aspen, alder, ash, elm, willow, rowan, cherry, apple, hazel, hawthorn, blackthorn and a pine-needle cluster. Plum and pear borrow apple, and spruce, pine and juniper use the needles. Cells store only the shape (alpha) and neutral grey vein detail, so the colour comes from the tint:

| What | Tint | Where it comes from |
|---|---|---|
| Falling leaves | Today's crown colour: green in summer, the species' two autumn hues plus an older brown | `VegetationPhenology.falling_leaf_colors`; each city tree sends two hues, so one crown sheds a mix |
| Litter, fresh share | This year's autumn colour (yellow birch, red maple and rowan, tan oak) | `VegetationPhenology.fresh_litter_share`: rises as the crown drops its leaves, browns out over about 45 days after the crown is bare |
| Litter, the rest | Weathered brown with a hint of the species hue; rust needles under pine, darker under spruce and juniper | `CityVegetationBuilder.LITTER_BROWNS`, `NEEDLE_BROWNS` |
| Litter under snow | Hidden leaf by leaf as snow cover grows | `snow_cover` from `VegetationPhenology.snow_cover_for` |

- **Runtime.** [`leaf_atlas.gd`](../../scripts/map/view3d/leaf_atlas.gd) maps species to cells, real leaf lengths and the particle material ([`leaf_particle.gdshader`](../../scripts/map/view3d/leaf_particle.gdshader)). City particles carry the cell in the particle colour alpha (`LeafAtlas.cell_code`), and district emitters get a per-species `material_override`. Litter is one square card per leaf with UVs on the species cell, drawn by [`city_leaf_litter.gdshader`](../../scripts/city/city_leaf_litter.gdshader) with one material per species. `CityWorld3D.apply_season` calls `CityVegetationBuilder.apply_litter_season(date, snow)`.
- **Sizes.** Litter leaves are drawn at real size times `LITTER_LEAF_BOOST` (1.35) so they still read from the gameplay camera. Falling leaves keep the larger particle size (city `leaf_size` 0.26, district 14 cm cards).
- **Atlas source.** Raw Leonardo photos (Nano Banana, one leaf on white) are in `generated/leonardo/leaf_species_v1/`, which is gitignored. The generation IDs are in `generations.csv` there and in `assets/SOURCES.csv`. Rebuild with `python3 tools/assets/build_leaf_species_atlas.py`. The cell order in the tool and in `LeafAtlas.CELLS` must match.
- **Save/load.** None: presentation only, a pure function of the date.
- **Verify.** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_leaf_atlas`. Plates: `tools/godot_render.sh --script tools/capture_leaf_litter.gd -- --date=1343-10-20` (also `1343-07-15`) and `tools/godot_render.sh --script tools/capture_leaf_fall_species.gd`.
- **Limits.** The litter amount is the same all year (only its colour changes). Particles still vanish when they reach the ground and do not add to the litter. Needle clusters read as small star bursts up close. `tools/capture_city_leaves.gd` does not show GPU particles in its minimized-window frames, so use `capture_leaf_fall_species.gd` to review falling leaves.

Heavy attacks shake harder; autumn yields more leaves, bare crowns none. Ambient and gust-driven falling leaves are deciduous-only; conifer needles remain on spruce, pine and juniper through seasonal weather. NPC attacks, spells and projectiles do not use this path.

## Shrubs

| Dog rose | Raspberry | Elder (hazel mesh) |
|---|---|---|
| ![City dog rose with arching canes and leaf cards](../reports/images/vegetation/veg_city_dog_rose_close.jpg) | ![City raspberry canes](../reports/images/vegetation/veg_city_raspberry_close.jpg) | ![Elder drawn with the hazel tree mesh](../reports/images/vegetation/veg_city_elder_close.jpg) |

City shrubs reuse tree meshes through [`CityVegetationBuilder.SHRUB_AS_TREE`](../../scripts/city/city_vegetation_builder.gd):

| City plan species | Rendered model |
|---|---|
| [`elder`](../FLORA/shrubs/elder.md), [`hazel_shrub`](../FLORA/shrubs/hazel_shrub.md), [`guelder_rose`](../FLORA/shrubs/guelder_rose.md), [`willow_shrub`](../FLORA/shrubs/willow_shrub.md), [`alder_shrub`](../FLORA/shrubs/alder_shrub.md) | Hazel tree mesh, scaled |
| [`hawthorn`](../FLORA/shrubs/hawthorn.md), [`spindle`](../FLORA/shrubs/spindle.md) | Hawthorn tree mesh |
| [`blackthorn`](../FLORA/shrubs/blackthorn.md), [`sea_buckthorn`](../FLORA/shrubs/sea_buckthorn.md) | Blackthorn tree mesh |
| [`juniper_shrub`](../FLORA/shrubs/juniper_shrub.md) | Juniper tree mesh |
| [`dog_rose`](../FLORA/shrubs/dog_rose.md), [`raspberry`](../FLORA/shrubs/raspberry.md) | Curved canes with leaf cards ([`MapViewBushMeshes.city_mesh_for`](../../scripts/map/view3d/map_view_bush_meshes.gd)); rose uses rowan leaves, raspberry hazel; no flowers or fruit |

Species with neither a proxy nor a city mesh are skipped rather than drawn as a blob.

### Legacy shrub mesh removed

District maps no longer draw the old ellipsoid and cone shrubs: `bush.*` scatter and authored `bush` props have no model. The data still slows movement through [`TerrainVegetation`](../../scripts/map/terrain_vegetation.gd) and counts in composition accounting. **Invisible shrub geometry does not mean the gameplay data was deleted.** Restoring district shrubs needs a new reviewed model.

## Grass

Implemented for the seamless city (**R-1323**; open: blueprint-map carpet and grass seasons). Decision (user, 2026-10-08): the ground texture is a primitive colour field and every recognisable plant is 3D geometry. Target: individual curved blades with wind rolling across them as a visible front.

| City grass at eye level | City grass, wide |
|---|---|
| ![City blade grass at eye level](../reports/images/vegetation/veg_city_grass_eye.jpg) | ![City blade grass from a wider view](../reports/images/vegetation/veg_city_grass_wide.jpg) |

- **Ground.** Plates from [`generate_simple_grass_plates.py`](../../tools/assets/generate_simple_grass_plates.py): soft tonal patches, no plants in the image. Slices 0-7 green, 8 dry, 9 moss, 10 litter, 11 trodden.
- **Blades.** [`CityGrass`](../../scripts/city/city_grass.gd) scatters `grass_blade_clump_mesh` (six curved tapered blades) in three MultiMesh tiers with GPU wind and trampling:

| Tier | Chunk | Density | Range (scale cross-fade) |
|---|---|---|---|
| Near | 8 m | 4.5 clumps/m2 | 0-12 m, out by 17 m |
| Mid | 16 m | 1 clump/m2, larger | 9-46 m |
| Far | 32 m | 0.25 clumps/m2, double width | 36-118 m |

- **Camera independence.** Decision (user, 2026-10-13): grass must look the same in painted iso and the default third-person camera, and must not thin when the camera tilts down. While a player drives the view, tier ranges are measured on the ground from the player (`lod_focus`, set by `apply_grass_interaction`), not from the lens; without a player (captures, blueprint previews) they fall back to camera distance. The shader no longer slims or lowers tufts by camera pitch. Painted iso therefore shows the dense near tier round the player instead of only sparse, large mid clumps. Verified by `tests/godot/test_grass_tiers.gd`.

![Painted iso over the pasture: dense fine near-tier blades round the player](../reports/images/vegetation/grass_iso_near_tier.jpg)

- **Streaming.** Missing chunks are built nearest first within a 3.5 ms frame budget (at least one per frame); placement stays on the CPU (GL Compatibility has no compute).
- **Shading.** Root-to-tip gradient with warm, partly dry tips, root colour melting into the ground, rounded normals, backlight, wind sheen. No shadows.
- **Trampling.** `VegetationInteractionBuffer` keeps the last 8 player positions so a flattened path stays for a few seconds. NPCs are not fed yet.
- **Blueprint maps** still use textured tuft cards (`MapViewTerrainDetails`).

## Wild plants (forbs)

Implemented (**R-1519**, seasons **R-1557**, blueprint maps **R-1559**, oxeye daisy **R-1807**). Decision (user, 2026-10-09): flat accent diamonds were rejected; plants must read as real botany up close. [`CityForbMeshes`](../../scripts/city/city_forb_meshes.gd) builds fourteen cached models (six species with their seasonal variants), each with a far variant at a quarter of the triangles or less. Cards: [dandelion](../FLORA/herbs/dandelion.md), [plantain](../FLORA/herbs/plantain.md), [white clover](../FLORA/herbs/white_clover.md), [red clover](../FLORA/herbs/red_clover.md), [burdock](../FLORA/herbs/burdock.md), [oxeye daisy](../FLORA/herbs/oxeye_daisy.md).

![Lineup of the wild-plant models: oxeye daisy and its rosette at the back left, dandelion in flower, in seed and as a rosette, plantain, white and red clover, burdock rosette and flowering burdock](../reports/images/vegetation/forbs_lineup.png)

| Dandelion | Plantain | Clover | Burdock |
|---|---|---|---|
| ![Dandelion flower, seed clock and rosette](../reports/images/vegetation/forbs_dandelion.png) | ![Broadleaf plantain with flower spikes](../reports/images/vegetation/forbs_plantain.png) | ![White clover mat and red clover](../reports/images/vegetation/forbs_clover.png) | ![Burdock rosette and flowering candelabra](../reports/images/vegetation/forbs_burdock.png) |
| Short grass round settlement | Worn verges and yards | Short turf (white); uncut meadow only (red) | Wall feet and road edges; 1.1-1.3 m when uncut |

### Oxeye daisy (R-1807)

Status: implemented (task **R-1807**). Scope: the model, its season and its habitat. Out of scope (task **R-1792**): dense daisy drifts (cluster instances), a hay-meadow habitat field and a far white speckle; the city meadow therefore shows scattered daisies, not a white carpet. Decision (user, 2026-10-12): model one of the common Estonian meadow flowers first; the oxeye daisy (*Leucanthemum vulgare*, härjasilm) is the white "ромашка" of Estonian hay meadows.

| Studio | Heads | City meadow, 20 July |
|---|---|---|
| ![Oxeye daisy in flower beside its leaf rosette](../FLORA/images/herbs/oxeye_daisy.jpg) | ![Two daisy heads close up: white strap petals round a domed golden disc](../FLORA/images/herbs/oxeye_daisy_closeup.jpg) | ![Daisies scattered with red clover in uncut meadow grass](../FLORA/images/herbs/oxeye_daisy_meadow.jpg) |

- **Model** (`CityForbMeshes._oxeye_daisy`, kinds `oxeye_daisy` and `oxeye_daisy_leaves`): a rosette of 6-9 long-stalked, spoon-shaped, round-toothed leaves; 2-4 wiry stems 30-46 cm high with a slight S and three narrow toothed leaves; one head per stem (about one in six a bud), tilted 10-35 degrees toward the light so it reads from the high camera. A head is 18-23 separate strap petals, each a slightly different white with a notched tip, round a domed golden disc over a cup of dark-edged bracts; one head in five is older with drooping petals. Heads are about 5-6 cm in the model and, like every forb, are scaled up 5-45 % in the city to sit in proportion with its oversized grass. Petals carry high transmission (`COLOR.a` 0.65), so they glow against the sun. About 1,500 triangles near, 160 far (a white fan and a yellow dome per head); the rosette is 360 and 72.
- **Season** (`FORB_WINDOWS["oxeye_daisy"]`): rosette from 15 April, flowers 1 June - 31 July, rosette again until 15 November; 15 % of plants do not flower in a given year.
- **Habitat** (`CityForbs.suitability`): clumped patches (noise 0.05/m, narrow threshold) on open, uncut ground: suitability rises from wildness 0.35 to full at 0.8 and from 2.5 m to 7 m off the road; never in short turf or on the road edge. Grows taller in tall grass, like red clover.
- **Verify.** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_forbs` (heights, season mix, habitat, far budget). Plates: `tools/godot_render.sh --script tools/capture_city_forbs.gd -- --season=summer` (shots `oxeye_daisy`, `oxeye_daisy_heads`, `meadow_eye`).
- **Limits.** Daisy density is the single-plant model of the other forbs (0.3 candidates/m2 at full suitability); in the waist-high city grass (R-1791) many heads are hidden. Blueprint maps have no `plant.oxeye_daisy` zone yet.

Placement ([`CityForbs`](../../scripts/city/city_forbs.gd)) reads the fields that drive grass height (wildness, road, house distance, bareness) with fixed-seed noise patches. Drawing is one MultiMesh per model and detail level in 8 m chunks; empty layers are hidden, so a season draws about 16-20 calls, with shared wind and a shrink-out fade; [`city_forb.gdshader`](../../scripts/city/city_forb.gdshader) gives burdock its pale woolly undersides. Leaf venation comes from the procedural atlas [`forb_leaf_detail.png`](../../assets/vegetation/forbs/forb_leaf_detail.png).

### Wild-plant seasons (R-1557)

[`VegetationPhenology.forb_phase`](../../scripts/map/view3d/vegetation_phenology.gd) is a pure function of the day of year: nothing above ground from 16 November to 14 April.

| May | June | October (wall foot) | January |
|---|---|---|---|
| ![Verge in May: dandelions flowering, clover and plantain in leaf](../reports/images/vegetation/forbs_season_may.png) | ![Verge in June: seed clocks, plantain spikes, clover heads](../reports/images/vegetation/forbs_season_june.png) | ![Wall foot in October: rosettes and dry burdock](../reports/images/vegetation/forbs_season_october.png) | ![Verge in January: nothing above ground](../reports/images/vegetation/forbs_season_january.png) |

| Dates | Dandelion | Plantain | Clover | Burdock |
|---|---|---|---|---|
| 15 Apr - May | rosettes, 60 % flowering in May | rosettes | leaves | rosettes |
| June | flowers, seed clocks | 80 % spiked | in flower | rosettes |
| Jul - Aug | rosettes | 80 % spiked | in flower | second-year plants with green burrs |
| Sep - Oct | rosettes | spiked until Sep | leaves | dry brown burr stalks |

The season only picks which model a candidate becomes; it never changes random draws, so every spot keeps its plant all year. `CityForbs.set_calendar_date` drops cached chunks only when the season key changes. Nothing is saved.

**Blueprint maps (R-1559).** `plant.plantain`, `plant.dandelion`, `plant.clover` and `plant.burdock` zones scatter the same models with no distance fade, using a fixed high-summer mix (`MapViewPlantSpecies.forb_kind_for`). Before and after: [dandelion](../reports/images/vegetation/blueprint_forbs_dandelion_after.png), [burdock](../reports/images/vegetation/blueprint_forbs_burdock_after.png).

## Placement and ecology

Realism comes more from where things grow than from how each plant is drawn.

### District and blueprint maps (R-1322)

![Water edge: sedge and nettle on the bank with ecology on](../reports/images/vegetation/r1322_water_edge.png)

*Water edge on `viru_gate_foreland`, ecology on.* Also: [woodland edge](../reports/images/vegetation/r1322_woodland_edge.png) (trees thinned by fertility), [road verge](../reports/images/vegetation/r1322_road_verge.png) (wall foot cleared).

| Rule | Effect |
|---|---|
| Roads and wall feet | Nothing grows on a trodden road; trees and bushes keep a cell clear |
| Water | Sedge on the first two bank cells; nettle at wall feet and damp ground |
| Shade | Fern and moss only under conifers; grass thins under crowns |
| Soil | Juniper on dry limestone rims; weeds only on field margins; thickets at wood edges |

Trees are only ever thinned, never above the authored density. [`VegetationEcology`](../../scripts/map/vegetation_ecology.gd) is built per chunk by [`MapViewMeshBuilderScatter.begin_scatter`](../../scripts/map/view3d/map_view_mesh_builder_scatter.gd) from the compiled definition, grid and seed alone, with fields capped at 8 cells, so chunk splits are byte-identical. The authored override mask (`vegetation_mask`, [map authoring](../MAP_AUTHORING.md#ecology-placement-and-the-vegetation-override-mask-r-1322)) is the only ecology data on `MapDefinition`. Authored props always win. Ecology is derived on demand, never stored per cell.

### Seamless city: rooting and the coastal pine heath (R-1617)

![A clear bridge deck at Tartu: no trunk or crown on the deck](../reports/images/vegetation/r1617_bridge_clear_tartu.jpg)

*No crown through a bridge deck.* [`CityVegetationBuilder`](../../scripts/city/city_vegetation_builder.gd) consumes the plan's `trees` and `bushes`; [`CityWorld3D`](../../scripts/city/city_world_3d.gd) removes trees planted in water. The plan generator [`vegetation_habitat.py`](../../tools/city/vegetation_habitat.py) holds two rule sets:

- **Clearance.** A trunk keeps 2 m beyond every carriageway edge and 5 m off every bridge or deck; shrubs keep 1.5 m off bridges.
- **Soil.** Ground within 420 m of the 1343 shoreline and at most 10 m above the 1343 sea is sandy heath (62 % `pine_tall`, 18 % `pine`, 8 % birch, 12 % juniper, plus a pine bor on a 7 m grid broken by glades); the beach strand stays sand and juniper. Inland loam keeps mixed spruce, oak and birch.

Stable IDs: species re-picks use a position hash, the bor its own RNG after all seeded loops, and clearance runs last, so existing field, wood, orchard and farmstead IDs are unchanged. The plan is static content; nothing is saved.

## Moss, lichen and the forest floor (R-1661)

Implemented (**R-1661**; walls **R-1683**; roofs and bark **R-1684**; moss species and seasonal colour **R-1747**). Decision (user, 2026-10-11): moss and lichen grow on the north side of some trees and buildings, on shaded ground and the forest floor; the forest also gets mushrooms. Out of scope: the woods' tall-grass understorey (R-1595), roof placement rules (R-1465), gathering mushrooms, blueprint forest floors, snow.

| North side of a birch | North wall foot | Forest floor, April | Forest floor, August |
|---|---|---|---|
| ![Feather moss and lichen on the north side of a birch, with tinder brackets](../reports/images/vegetation/r1747_tree_north_moss.jpg) | ![Feather moss and grimmia colonies at the foot of a north wall (brightened 2.2x)](../reports/images/vegetation/r1747_wall_moss_closeup.jpg) | ![False morels and moss cushions in April](../reports/images/vegetation/r1661_forest_floor_april.jpg) | ![Chanterelles in August](../reports/images/vegetation/r1661_forest_floor_august.jpg) |

Also: [whole north wall](../reports/images/vegetation/r1661_wall_north_moss.jpg), [shaded ground](../reports/images/vegetation/r1661_shaded_ground.jpg), [woods in April](../reports/images/vegetation/r1661_woods_april.jpg) and [August](../reports/images/vegetation/r1661_woods_august.jpg), roofs: [tile](../reports/images/vegetation/r1684_roof_tile.jpg). Seasons (April, July, January): [wall foot](../reports/images/vegetation/r1747_wall_moss_seasons.jpg) (city light also changes with the date; brightened 2.6x), [tile roof](../reports/images/vegetation/r1747_roof_moss_seasons.jpg) (fixed light).

- **Trunks** (`map_view_bark_wind.gdshader`): a moss skirt up to about 2.6 m on the north side and pale lichen crusts from shin height, seeded per tree so only some carry them (`moss_amount` 0.6, `lichen_amount` 0.5).
- **Walls** (`shade_growth` in `city_weathering.gdshaderinc`, half strength on limewash): cushion moss at the damp foot of north faces up to about 1.6 m with a dark halo, sparse lichen above. South faces stay clean.
- **Roofs:** the same plates on shingle, thatch and clay tile ([city roofs](./SEAMLESS_CITY.md#how-buildings-are-built)).
- **Species (R-1747).** Three moss plates: domed cushion moss (`wall_moss_*`), a flat feather-moss carpet (*Hypnum*, `wall_moss_feather_*`) and small hoary *Grimmia* cushions (`wall_moss_grimmia_*`). `growth_moss_sample` tiles each at its own scale and angle, warps the lookup a few centimetres, lets a low-frequency colony field pick the species patch by patch, drifts the hue per colony and jitters the cushion edge, so no plate repeats as a pattern. Mixes (`GROWTH_*_SPECIES`): walls feather with some grimmia, roofs feather and grimmia, bark feather only. Decision (user review, 2026-10-11): the domed plate repeated as rows of half-circle scales (only its dome crowns passed the threshold), so it is out of every mix but stays bound for a reshot plate.
- **Seasonal colour (R-1747).** Moss is evergreen but its colour follows the date: fresh green flush in spring, dry yellow-brown shoot tips in summer drought, deep green after the autumn rains, dull dark olive in winter. `MapViewWindMaterials.moss_season(date)` blends `MOSS_SEASON` by `SeasonState.season_weights` and `apply_vegetation_season` writes it to the `moss_season_g` shader global (rgb tint, a = drought), which every growth surface reads. Snow cover is unchanged.
- **Shaded ground** (`city_ground.gdshader`): ragged moss cushions where [`CityShadeMask`](../../scripts/city/city_shade_mask.gd) reports shade; trodden paths stay bare.
- **Forest floor** ([`CityForestFloor`](../../scripts/city/city_forest_floor.gd)): moss cushions round each tree of a closed stand (8+ forest neighbours within 15 units), biased north, plus fungi by mycorrhizal partner, visible to 110 units (moss) and 70 (fungi).

| Kind | Species | Grows by | Days of year |
|---|---|---|---|
| `gyromitra` | false morel | pine | 100-152 (Apr-May) |
| `chanterelle` | *Cantharellus cibarius*, troops of 3-7 | spruce, pine, birch | 182-280 |
| `porcini` | *Boletus edulis* | spruce, pine, birch, oak | 196-288 |
| `fly_agaric` | *Amanita muscaria* | birch, spruce | 205-295 |
| `bracket` | tinder fungus, 1-3 shelves | birch | all year |
| `moss` | moss cushions | any forest tree | all year |

On the opening date (21 April 1343) the woods show moss, brackets and false morels. Plates are in [`assets/materials/pbr/wall_growth/`](../../assets/materials/pbr/wall_growth/), built by `tools/assets/build_wall_growth_plates.py` (feather and grimmia sources: Leonardo Nano Banana, `generated/leonardo/wall_growth_v2/prompt.json`); coverage is thresholded in [`city_growth_plates.gdshaderinc`](../../scripts/city/city_growth_plates.gdshaderinc). Bark uses continuous mesh UVs, so growth does not swim under wind. Deterministic, seeded by position; nothing saved. Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_growth_plates` (plate bindings, species mixes, season tint and global); captures `tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_moss.tscn -- --walls --date=7-20` and `tools/godot_render.sh --resolution 1600x900 --script tools/capture_roof_growth.gd -- --date=1-15`.

Limits: roof moss is deliberately sparse (R-1465), so its seasonal shift is subtle; grimmia cushions with bright rims can still read as small rings at very low cover; the domed plate needs a straight top-down reshoot before it returns to a mix.

## Where the code and assets live

Most trees are cached procedural `ArrayMesh` geometry, so a mesh profile edit is a model edit even though no Blender or GLB file changes.

| Part | Source |
|---|---|
| Species registry, tints, bark families | [`map_view_tree_species.gd`](../../scripts/map/view3d/map_view_tree_species.gd) |
| Branching presets (all 20) | [`tree_skeleton_weber_penn.gd`](../../scripts/map/view3d/tree_skeleton_weber_penn.gd) `PRESETS` |
| Height, radius, leaf size, fruit | [`map_view_tree_mesh_profiles.gd`](../../scripts/map/view3d/map_view_tree_mesh_profiles.gd) |
| Wood, canopy, fruit meshes, city forms, LOD geometry | [`map_view_tree_meshes.gd`](../../scripts/map/view3d/map_view_tree_meshes.gd) |
| Leaf and needle geometry, atlas tiles | [`map_view_leaf_geometry.gd`](../../scripts/map/view3d/map_view_leaf_geometry.gd), [leaf atlas](../../assets/materials/pbr/foliage_cards/leaf_card_atlas.png) |
| City bark plates | [`assets/materials/pbr/bark_*`](../../assets/materials/pbr/) |
| Materials (crown, bark, grass, season, wetness) | [`map_view_wind_materials.gd`](../../scripts/map/view3d/map_view_wind_materials.gd), [`map_view_prop_materials.gd`](../../scripts/map/view3d/map_view_prop_materials.gd) |
| Shrub canes | [`map_view_bush_meshes.gd`](../../scripts/map/view3d/map_view_bush_meshes.gd) |
| Grass blades and shader | [`map_view_foliage_meshes.gd`](../../scripts/map/view3d/map_view_foliage_meshes.gd), [`map_view_grass.gdshader`](../../scripts/map/view3d/map_view_grass.gdshader) |
| Wild plants | [`city_forb_meshes.gd`](../../scripts/city/city_forb_meshes.gd), [`city_forb.gdshader`](../../scripts/city/city_forb.gdshader) |

The [sacred-grove ancient oak GLB](../../assets/props/environment/sacred_grove_ancient_oak/sacred_grove_ancient_oak.glb) is a separate authored prop; it does not join the crown, LOD or strike systems. Provenance lives in [`assets/SOURCES.csv`](../../assets/SOURCES.csv); add any copied open-source code there with its license first.

**Runtime entry points.** District date: `MapView3D.set_calendar_date`; district weather: `MapViewMaterials.apply_weather_presentation`; city date: [`CityMapView.set_calendar_date`](../../scripts/city/city_map_view.gd) (feeds `CityWorld3D.apply_season`, `CityForbs`, `CityForestFloor`); city weather: `CityWorld3D.apply_time`; district melee: `MapViewRuntimeActors._on_player_melee_attack_resolved`.

**Save/load.** Species, placement, calendar and weather reconstruct the look; meshes, LOD choice, gust phase, shake and particles add no save fields. Wind depends on render time, so a load does not resume the exact animation frame.

## Where to go next

- Texture pipeline, performance budgets, how to change a model, capture and test commands, known limits, roadmap: [Vegetation engineering](./VEGETATION_ENGINEERING.md).
- [Farmland](./FARMLAND.md): crops, gardens, pastures and woods outside the walls.
- [Flora catalogue](../FLORA/README.md): one card per plant with portraits, and the wishlist of common Estonian plants still missing.
- [Flora and fauna](../FLORA_FAUNA.md) and [biomes and wildlife](../LOCATIONS/BIOMES_AND_WILDLIFE.md): species inventory and authored map evidence.
- [Seasons](./SEASONS.md) and [weather ground](./WEATHER_GROUND.md): date controls, snow and ground weather.
- [World presentation](./WORLD_PRESENTATION.md), [Seamless city](./SEAMLESS_CITY.md), [Map authoring](../MAP_AUTHORING.md): how and where vegetation is placed and drawn.
- [Art bible](../ART_BIBLE.md) ("Vegetation realism (P0-208)").

Implementation lineage, for lookup only: seasonal crowns **R-1187**; cluster cards **R-1194**; procedural atlas **R-1329**; shared wind **R-1321**; branching presets **R-1324**, orchard habits **R-1391**; city-scale pass **R-712**; shrub cards **R-1315**; macro needles **R-1404**; whole-tree storm bend **R-1433**; ecology **R-1322**; pine heath **R-1617**; city grass **R-1323**; forbs **R-1519**/**R-1557**/**R-1558**/**R-1559**, oxeye daisy **R-1807**; flora catalogue **R-1808**; snow **R-1327**; moss and fungi **R-1661**/**R-1683**/**R-1684**; docs **R-1696**, **R-1704**.
