# Flora and Fauna of Reval (Estonia, 1343)

This is the implementation ledger for Reval vegetation. It distinguishes concrete botanical models from generic terrain-cover styles and links every status to runtime code and authored locations.

## System status

- **Trees: 20/20 target species modeled and authored.** Catalog and visual traits: [`map_view_tree_species.gd`](../scripts/map/view3d/map_view_tree_species.gd). Bounded branching, leaves, and fruit: [`map_view_tree_meshes.gd`](../scripts/map/view3d/map_view_tree_meshes.gd). Reference sheet: [`p0_103_tree_reference_sheet.png`](reports/images/fauna/p0_103_tree_reference_sheet.png). District mix weights are documented under shared constraint 9 in [`HISTORICAL_AUDIT.md`](HISTORICAL_AUDIT.md).
- **Plants, herbs, and crops: 30/30 target species modeled and authored.** Catalog and growth profiles: [`map_view_plant_species.gd`](../scripts/map/view3d/map_view_plant_species.gd). Procedural meshes: [`map_view_plant_meshes.gd`](../scripts/map/view3d/map_view_plant_meshes.gd).
- **Ground-cover styles: 8/8 supported.** These are visual/ecological cover presets, not eight botanical species. Registration and density rules: [`terrain_vegetation.gd`](../scripts/map/terrain_vegetation.gd).
- **Rendering: complete for the scoped flora system.** [`map_view_mesh_builder_scatter.gd`](../scripts/map/view3d/map_view_mesh_builder_scatter.gd) batches each tree or plant species with cached meshes and `MultiMesh`; [`map_view_terrain_details.gd`](../scripts/map/view3d/map_view_terrain_details.gd) adds first-person grass, dry seed heads, clover, and fern detail.
- **Imported 3D flora assets: none by design.** Runtime vegetation is deterministic procedural geometry. Images under [`archive/2d_sprites_inspiration/assets/trees/`](../archive/2d_sprites_inspiration/assets/trees/) are references only and are not gameplay models.
- **Birds: 30/30 target species cataloged with procedural reference meshes and runtime ambient playback.** Catalog, processed clips, district spawn weights, positional song scheduling, and gliding flight actors: [`map_view_bird_species.gd`](../scripts/map/view3d/map_view_bird_species.gd), [`map_view_bird_ambient_audio.gd`](../scripts/map/view3d/map_view_bird_ambient_audio.gd), [`map_view_bird_flight.gd`](../scripts/map/view3d/map_view_bird_flight.gd). Cached low-poly meshes: [`map_view_bird_meshes.gd`](../scripts/map/view3d/map_view_bird_meshes.gd). Reference sheet: [`p0_117_bird_reference_sheet.png`](reports/images/fauna/p0_117_bird_reference_sheet.png).
- **Mammals: 30/30 target species cataloged with procedural reference meshes.** Catalog and district spawn-weight stubs: [`map_view_mammal_species.gd`](../scripts/map/view3d/map_view_mammal_species.gd). Cached low-poly meshes: [`map_view_mammal_meshes.gd`](../scripts/map/view3d/map_view_mammal_meshes.gd). Reference sheet: [`p0_118_mammal_reference_sheet.png`](reports/images/fauna/p0_118_mammal_reference_sheet.png). Urban cat/dog/horse/rat runtime actors ship on `lower_town_slice` through [`map_view_urban_fauna.gd`](../scripts/map/view3d/map_view_urban_fauna.gd); penned livestock runtime behavior remains **P0-106**.
- **Shrubs: 20/20 target species modeled and authored.** Catalog and ecological groups: [`map_view_bush_species.gd`](../scripts/map/view3d/map_view_bush_species.gd). Procedural meshes: [`map_view_bush_meshes.gd`](../scripts/map/view3d/map_view_bush_meshes.gd). Legacy `bush.dense` and `bush.scrub` remain weighted group aliases.
- **Other fauna: urban mammals active on Lower Town; penned livestock pending.** Ambient urban actors are **P2-024** (closed); penned livestock and wild-margin actors remain **P0-106**; folklore bestiary content is not an ambient-fauna system.

Status vocabulary:
- `modeled + used` - registered, produces a concrete cached mesh, and has an authored location below.
- `cover style` - controls terrain tint/density and may reuse a generic/detail mesh; it is not a species model.

## Tree model ledger (20/20)

All tree IDs accept optional `.small`, `.medium`, or `.large` suffixes. Group variants `tree.mixed`, `tree.deciduous`, and `tree.orchard` select weighted species pools.

| Tree | Runtime ID | Status | Concrete authored evidence |
|---|---|---|---|
| Norway spruce | `tree.spruce` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap), [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Scots pine | `tree.pine` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Silver birch | `tree.birch` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Pedunculate oak | `tree.oak` | modeled + used | [`reval_harbor_north.rrmap`](../content/maps/reval_harbor_north.rrmap) |
| Alder | `tree.alder` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Eurasian aspen | `tree.aspen` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Norway maple | `tree.maple` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Small-leaved linden | `tree.linden` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Apple | `tree.apple` | modeled + fruit + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Sour cherry | `tree.cherry` | modeled + fruit + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| European ash | `tree.ash` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Wych elm | `tree.elm` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Willow | `tree.willow` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Rowan | `tree.rowan` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap), [`reval_harbor_north.rrmap`](../content/maps/reval_harbor_north.rrmap) |
| Common hazel | `tree.hazel` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Common juniper | `tree.juniper` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Plum / damson | `tree.plum` | modeled + fruit + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| European pear | `tree.pear` | modeled + fruit + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Common hawthorn | `tree.hawthorn` | modeled + fruit + used | [`reval_harbor_north.rrmap`](../content/maps/reval_harbor_north.rrmap) |
| Blackthorn | `tree.blackthorn` | modeled + fruit + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |

Sacred Grove landmark hingepuu (`primitive=ancient_tree` on [`world_sacred_grove.rrmap`](../content/maps/world_sacred_grove.rrmap)) uses a dedicated mesh in [`map_view_ancient_oak_meshes.gd`](../scripts/map/view3d/map_view_ancient_oak_meshes.gd): buttressed trunk, giant primary limbs, dense canopy, and hanging moss. Grove `primitive=tree_line` buildings dress as large oak rows in 3D rather than house boxes.

Tree tests: [`test_map_view_tree_species.gd`](../tests/godot/test_map_view_tree_species.gd). They enforce the catalog target, cache reuse, bounded geometry, tapered trunks, size pins, and authored species use.

## Plant, herb, and crop model ledger (30/30)

`plant.*` identifies wild/medicinal/wetland plants; `crop.*` identifies cultivated food and fibre rows. Every entry has a species-specific profile using one of twelve geometry families, including rosette, broadleaf, flowering herb, frond, moss, reed, cattail, aquatic pad, cereal, stalk, and vine forms.

| Plant | Runtime ID | Status | Concrete authored evidence |
|---|---|---|---|
| Stinging nettle | `plant.nettle` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Mugwort | `plant.mugwort` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap), [`reval_harbor_north.rrmap`](../content/maps/reval_harbor_north.rrmap) |
| Yarrow | `plant.yarrow` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Broadleaf plantain | `plant.plantain` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap), [`reval_harbor_north.rrmap`](../content/maps/reval_harbor_north.rrmap) |
| Dandelion | `plant.dandelion` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Burdock | `plant.burdock` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Creeping thistle | `plant.thistle` | modeled + used | [`reval_harbor_east.rrmap`](../content/maps/reval_harbor_east.rrmap) |
| Red/white clover | `plant.clover` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) as a concrete bed; `grass.clover` remains a legacy cover alias |
| Bracken / male fern | `plant.fern` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) as a concrete bed; `grass.fern` remains a legacy cover alias |
| Sphagnum moss | `plant.moss` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) as a concrete bed; `grass.mossy` remains a legacy cover alias |
| Common reed | `plant.reed` | modeled + used | [`viru_gate_foreland.rrmap`](../content/maps/viru_gate_foreland.rrmap) |
| Bulrush / cattail | `plant.cattail` | modeled + used | [`viru_gate_foreland.rrmap`](../content/maps/viru_gate_foreland.rrmap) |
| White water lily | `plant.water_lily` | modeled + used | [`viru_gate_foreland.rrmap`](../content/maps/viru_gate_foreland.rrmap) |
| Cabbage | `crop.cabbage` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Turnip | `crop.turnip` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Onion | `crop.onion` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Garlic | `crop.garlic` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Pea | `crop.pea` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Broad bean | `crop.broad_bean` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Rye | `crop.rye` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Wheat | `crop.wheat` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Barley | `crop.barley` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Oat | `crop.oat` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Flax | `crop.flax` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Hemp | `crop.hemp` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Hops | `crop.hops` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Mint | `plant.mint` | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Caraway | `plant.caraway` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| Chamomile | `plant.chamomile` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |
| St. John's wort | `plant.st_johns_wort` | modeled + used | [`monastery_quarter.rrmap`](../content/maps/monastery_quarter.rrmap) |

Plant tests: [`test_map_view_plant_species.gd`](../tests/godot/test_map_view_plant_species.gd). They enforce 30 registered models, cache reuse, geometry-family diversity, valid scatter profiles, and authored location coverage for all 20 trees and 30 plants.

## Shrub model ledger (20/20)

Group variants `bush.dense`, `bush.scrub`, `bush.mixed`, `bush.hedge`, `bush.heath`, `bush.coastal`, and `bush.bog` select weighted species pools. Authors may pin `bush.<species>` on props or terrain styles.

| Shrub | Runtime ID | Group | Status | Concrete authored evidence |
|---|---|---|---|---|
| Bilberry | `bush.bilberry` | berry | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Cowberry | `bush.cowberry` | berry | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Cloudberry | `bush.cloudberry` | bog | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Cranberry | `bush.cranberry` | bog | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Crowberry | `bush.crowberry` | heath | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Wild strawberry | `bush.wild_strawberry` | berry | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Raspberry | `bush.raspberry` | berry | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Dog rose | `bush.dog_rose` | understory | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Guelder rose | `bush.guelder_rose` | understory | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Elder | `bush.elder` | understory | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Sea buckthorn | `bush.sea_buckthorn` | coastal | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Heather | `bush.heather` | heath | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Bog rosemary | `bush.bog_rosemary` | bog | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Juniper shrub | `bush.juniper_shrub` | coastal | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Hazel shrub | `bush.hazel_shrub` | hedge | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Hawthorn | `bush.hawthorn` | hedge | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Blackthorn | `bush.blackthorn` | hedge | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Willow shrub | `bush.willow_shrub` | wetland | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Alder shrub | `bush.alder_shrub` | wetland | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |
| Spindle | `bush.spindle` | hedge | modeled + used | [`archbishops_garden.rrmap`](../content/maps/archbishops_garden.rrmap) |

Shrub tests: [`test_map_view_bush_species.gd`](../tests/godot/test_map_view_bush_species.gd). They enforce the 20-species catalog, cache reuse, archetype diversity, valid scatter profiles, legacy dense/scrub aliases, and authored location coverage.

## Bird model ledger (30/30)

`bird.*` IDs identify north-Baltic ambient species. Optional pose suffixes `.standing`, `.perched`, and `.gliding` select cached reference meshes. Processed clips, district spawn weights, and runtime scheduling are implemented under **P0-105**.

| Bird | Runtime ID | Group | Status |
|---|---|---|---|
| Herring gull | `bird.herring_gull` | gull | modeled (catalog) |
| Common gull | `bird.common_gull` | gull | modeled (catalog) |
| Common tern | `bird.common_tern` | tern | modeled (catalog) |
| Mute swan | `bird.mute_swan` | waterfowl | modeled (catalog) |
| Mallard | `bird.mallard` | waterfowl | modeled (catalog) |
| Greylag goose | `bird.greylag_goose` | waterfowl | modeled (catalog) |
| Great cormorant | `bird.great_cormorant` | waterfowl | modeled (catalog) |
| Grey heron | `bird.grey_heron` | wader | modeled (catalog) |
| Northern lapwing | `bird.northern_lapwing` | wader | modeled (catalog) |
| Common snipe | `bird.common_snipe` | wader | modeled (catalog) |
| White-tailed eagle | `bird.white_tailed_eagle` | raptor | modeled (catalog) |
| Osprey | `bird.osprey` | raptor | modeled (catalog) |
| Common buzzard | `bird.common_buzzard` | raptor | modeled (catalog) |
| Common kestrel | `bird.common_kestrel` | raptor | modeled (catalog) |
| Tawny owl | `bird.tawny_owl` | owl | modeled (catalog) |
| House sparrow | `bird.house_sparrow` | songbird | modeled (catalog) |
| Hooded crow | `bird.hooded_crow` | corvid | modeled (catalog) |
| Rook | `bird.rook` | corvid | modeled (catalog) |
| Western jackdaw | `bird.western_jackdaw` | corvid | modeled (catalog) |
| Eurasian magpie | `bird.eurasian_magpie` | corvid | modeled (catalog) |
| Barn swallow | `bird.barn_swallow` | swallow | modeled (catalog) |
| Skylark | `bird.skylark` | songbird | modeled (catalog) |
| Yellowhammer | `bird.yellowhammer` | songbird | modeled (catalog) |
| Common chaffinch | `bird.common_chaffinch` | songbird | modeled (catalog) |
| Great tit | `bird.great_tit` | songbird | modeled (catalog) |
| European robin | `bird.european_robin` | songbird | modeled (catalog) |
| Common blackbird | `bird.common_blackbird` | songbird | modeled (catalog) |
| Song thrush | `bird.song_thrush` | songbird | modeled (catalog) |
| Common nightingale | `bird.common_nightingale` | songbird | modeled (catalog) |
| Great spotted woodpecker | `bird.great_spotted_woodpecker` | woodpecker | modeled (catalog) |

Bird tests: [`test_map_view_bird_species.gd`](../tests/godot/test_map_view_bird_species.gd). They enforce 30 registered profiles, ten silhouette-group families, cached pose variants, bounded triangle budgets, district spawn weights for every context, and at least ten distinct default-pose envelopes.

## Mammal model ledger (30/30)

`fauna.*` IDs identify north-Baltic ambient mammals. Optional pose suffixes `.standing`, `.grazing`, and `.resting` select cached reference meshes. Runtime urban actors (**P2-024**), penned livestock (**P0-106**), and wild-margin flee behavior are not part of this task.

| Mammal | Runtime ID | Group | Runtime owner | Status |
|---|---|---|---|---|
| Brown bear | `fauna.brown_bear` | bear | wild margin | modeled (catalog) |
| Wolf | `fauna.wolf` | canid | wild margin | modeled (catalog) |
| Red fox | `fauna.red_fox` | canid | wild margin | modeled (catalog) |
| Eurasian lynx | `fauna.lynx` | felid | wild margin | modeled (catalog) |
| Elk | `fauna.elk` | ungulate | wild margin | modeled (catalog) |
| Red deer | `fauna.red_deer` | ungulate | wild margin | modeled (catalog) |
| Roe deer | `fauna.roe_deer` | ungulate | wild margin | modeled (catalog) |
| Wild boar | `fauna.wild_boar` | ungulate | wild margin | modeled (catalog) |
| Beaver | `fauna.beaver` | rodent | wetland margin | modeled (catalog) |
| Eurasian otter | `fauna.otter` | mustelid | wetland margin | modeled (catalog) |
| European badger | `fauna.badger` | mustelid | wild margin | modeled (catalog) |
| Stoat | `fauna.stoat` | mustelid | wild margin | modeled (catalog) |
| Pine marten | `fauna.pine_marten` | mustelid | woodland margin | modeled (catalog) |
| European polecat | `fauna.polecat` | mustelid | wild margin | modeled (catalog) |
| European hare | `fauna.hare` | lagomorph | foreland margin | modeled (catalog) |
| Red squirrel | `fauna.squirrel` | rodent | garden/woodland | modeled (catalog) |
| European hedgehog | `fauna.hedgehog` | insectivore | garden margin | modeled (catalog) |
| Grey seal | `fauna.grey_seal` | seal | harbour margin | modeled (catalog) |
| Ringed seal | `fauna.ringed_seal` | seal | harbour/wetland | modeled (catalog) |
| Common bat | `fauna.common_bat` | bat | night margin | modeled (catalog) |
| Domestic cat | `fauna.cat` | felid | **P2-024** urban | modeled (catalog) |
| Domestic dog | `fauna.dog` | canid | **P2-024** urban | modeled (catalog) |
| Horse | `fauna.horse` | ungulate | **P2-024** urban | modeled (catalog) |
| Brown rat | `fauna.rat` | rodent | **P2-024** urban | modeled (catalog) |
| Chicken | `fauna.chicken` | fowl | **P0-106** penned | modeled (catalog) |
| Domestic duck | `fauna.duck` | fowl | **P0-106** penned | modeled (catalog) |
| Domestic goose | `fauna.goose` | fowl | **P0-106** penned | modeled (catalog) |
| Domestic pig | `fauna.pig` | swine | **P0-106** penned | modeled (catalog) |
| Cattle | `fauna.cow` | ungulate | **P0-106** penned | modeled (catalog) |
| Sheep | `fauna.sheep` | ungulate | **P0-106** penned | modeled (catalog) |

Mammal tests: [`test_map_view_mammal_species.gd`](../tests/godot/test_map_view_mammal_species.gd). They enforce 30 registered profiles, twelve silhouette-group families, cached pose variants, bounded triangle budgets, district spawn weights for every context, and at least eight distinct default-pose envelopes.

## Legacy ground-cover styles

These remain valid for broad area dressing and backwards compatibility. Authors should use concrete `plant.*` / `crop.*` variants when a named species matters.

| Cover ID | Meaning | Mesh/render evidence | Status |
|---|---|---|---|
| `grass.short` | grazed/short cover | generic grass tuft in [`map_view_foliage_meshes.gd`](../scripts/map/view3d/map_view_foliage_meshes.gd) | cover style |
| `grass.tall` | tall meadow cover | generic tuft plus large layer | cover style |
| `grass.flowers` | mixed flowering meadow | generic tuft with flower tint | cover style |
| `grass.dry` | dry seed-bearing cover | `grass_seed_head_mesh()` | cover style |
| `grass.mossy` | low damp cover | ground tint/detail | cover style; concrete model is `plant.moss` |
| `grass.clover` | clover-rich cover | `clover_patch_mesh()` | cover style; concrete model is `plant.clover` |
| `grass.fern` | fern-rich understory | `fern_frond_mesh()` | cover style; concrete model is `plant.fern` |
| `reed.shore` | legacy freshwater bank mix | reed stems and cattail bank layer | cover style; concrete models are `plant.reed` and `plant.cattail` |

## Authoring contract

```rrmap
style tree.rowan
style herb.bed style_variant=plant.yarrow
style crop.row style_variant=crop.rye

terrain medicinal_bed grass 10 12 8 5 style=herb.bed order=3
terrain rye_strip grass 20 12 12 5 style=crop.row order=3
prop landmark_rowan tree 32 18 style=tree.rowan.large
```

- Use direct IDs (`style=plant.yarrow`) or a named style whose `style_variant` resolves to that ID.
- Use tree props for guaranteed landmark specimens; terrain styles scatter deterministic stands/beds.
- Keep wetland species on freshwater banks. Harbor tests deliberately reject reeds/cattails on open Baltic shores.
- Do not add a species to documentation without adding its catalog profile, concrete mesh test, and authored location.

## What is still absent

The scoped tree/herb model system is complete at the target catalog size. Remaining environment work is separate:

- seasonal states, harvest interactions, inventory items, and regrowth simulation;
- species-specific collision or movement beyond current zone/prop multipliers;
- ambient mammal runtime actors and penned livestock behavior (**P2-024**, **P0-106**);
- art-direction review from gameplay camera and performance profiling on target hardware.
