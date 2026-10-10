# Flora and Fauna of Reval (Estonia, 1343)

This is the implementation ledger for Reval vegetation. It distinguishes concrete botanical models from generic terrain-cover styles and links every status to runtime code and authored locations.

Per-species cards for every animal and bird, with their 3D model files and sources, are in [`ANIMALS-AND-BIRDS/`](ANIMALS-AND-BIRDS/README.md).

## System status

- **Trees: 20/20 target species modeled and authored.** Catalog and visual traits: [`map_view_tree_species.gd`](../scripts/map/view3d/map_view_tree_species.gd). Bounded branching, leaves, and fruit: [`map_view_tree_meshes.gd`](../scripts/map/view3d/map_view_tree_meshes.gd). Seasons, weather response, and leaf fall on weapon hits: [`SYSTEMS/LIVING_VEGETATION.md`](SYSTEMS/LIVING_VEGETATION.md). Reference sheet: [`p0_103_tree_reference_sheet.png`](reports/images/fauna/p0_103_tree_reference_sheet.png). District mix weights are documented under shared constraint 9 in [`HISTORICAL_AUDIT.md`](HISTORICAL_AUDIT.md).
- **Plants, herbs, and crops: 30/30 target species modeled and authored.** Catalog and growth profiles: [`map_view_plant_species.gd`](../scripts/map/view3d/map_view_plant_species.gd). Procedural meshes: [`map_view_plant_meshes.gd`](../scripts/map/view3d/map_view_plant_meshes.gd).
- **Ground-cover styles: 8/8 supported.** These are visual/ecological cover presets, not eight botanical species. Registration and density rules: [`terrain_vegetation.gd`](../scripts/map/terrain_vegetation.gd).
- **Rendering: complete for the scoped flora system.** [`map_view_mesh_builder_scatter.gd`](../scripts/map/view3d/map_view_mesh_builder_scatter.gd) batches each tree or plant species with cached meshes and `MultiMesh`; [`map_view_terrain_details.gd`](../scripts/map/view3d/map_view_terrain_details.gd) adds first-person grass, dry seed heads, clover, and fern detail.
- **Imported 3D flora assets: none by design.** Runtime vegetation is deterministic procedural geometry. Images under [`archive/2d_sprites_inspiration/assets/trees/`](../archive/2d_sprites_inspiration/assets/trees/) are references only and are not gameplay models.
- **Birds: 30/30 target species cataloged; reviewed authored GLBs and procedural fallback are both active.** Catalog, processed clips, district spawn weights, positional song scheduling, and flapping flight actors with V-formation flocks ([Bird flight](#bird-flight)): [`map_view_bird_species.gd`](../scripts/map/view3d/map_view_bird_species.gd), [`map_view_bird_ambient_audio.gd`](../scripts/map/view3d/map_view_bird_ambient_audio.gd), [`map_view_bird_flight.gd`](../scripts/map/view3d/map_view_bird_flight.gd). The loader promotes only reviewed authored poses/cycles under [`assets/birds/`](../assets/birds/) and intentionally retains the procedural fallback for species or poses without an approved GLB: [`map_view_bird_assets.gd`](../scripts/map/view3d/map_view_bird_assets.gd), [`map_view_bird_meshes.gd`](../scripts/map/view3d/map_view_bird_meshes.gd). The reference sheet labels each entry as `[GLB]` or `[procedural]`: [`p0_117_bird_reference_sheet.png`](reports/images/fauna/p0_117_bird_reference_sheet.png).
- **Mammals: 30/30 target species cataloged with procedural reference meshes.** Catalog and district spawn-weight stubs: [`map_view_mammal_species.gd`](../scripts/map/view3d/map_view_mammal_species.gd). Cached low-poly meshes: [`map_view_mammal_meshes.gd`](../scripts/map/view3d/map_view_mammal_meshes.gd). Reference sheet: [`p0_118_mammal_reference_sheet.png`](reports/images/fauna/p0_118_mammal_reference_sheet.png). Urban cat/dog/horse/rat runtime actors ship on `lower_town_slice` and `south_quarter` through [`map_view_urban_fauna.gd`](../scripts/map/view3d/map_view_urban_fauna.gd); cats and dogs cycle hunt, play, groom and investigate intents via [`map_view_companion_intent.gd`](../scripts/map/view3d/map_view_companion_intent.gd). Penned livestock and wild-margin actors ship on `lower_town_slice`, `north_quarter`, and `viru_gate_foreland` through [`map_view_penned_fauna.gd`](../scripts/map/view3d/map_view_penned_fauna.gd).
- **Shrubs: 20/20 target species modeled and authored.** Catalog and ecological groups: [`map_view_bush_species.gd`](../scripts/map/view3d/map_view_bush_species.gd). Procedural meshes: [`map_view_bush_meshes.gd`](../scripts/map/view3d/map_view_bush_meshes.gd). Legacy `bush.dense` and `bush.scrub` remain weighted group aliases.
- **Other fauna: urban and penned livestock active on Lower Town; wild-margin actors on foreland.** Ambient urban actors are **P2-024** (closed); penned livestock and wild-margin flee actors are **P0-106** (closed); folklore bestiary content is not an ambient-fauna system.

Status vocabulary:
- `modeled + used` - registered, produces a concrete cached mesh, and has an authored location below.
- `cover style` - controls terrain tint/density and may reuse a generic/detail mesh; it is not a species model.

## Tree model ledger (20/20)

All tree IDs accept optional `.small`, `.medium`, or `.large` suffixes. Group variants `tree.mixed`, `tree.deciduous`, and `tree.orchard` select weighted species pools.

| Tree | Runtime ID | Status | Concrete authored evidence |
|---|---|---|---|
| Norway spruce | `tree.spruce` | modeled + used | `archbishops_garden.rrmap`, `reval_harbor_east.rrmap` |
| Scots pine | `tree.pine` | modeled + used | `reval_harbor_east.rrmap` |
| Silver birch | `tree.birch` | modeled + used | `reval_harbor_east.rrmap` |
| Pedunculate oak | `tree.oak` | modeled + used | `reval_harbor_north.rrmap` |
| Alder | `tree.alder` | modeled + used | `reval_harbor_east.rrmap` |
| Eurasian aspen | `tree.aspen` | modeled + used | `reval_harbor_east.rrmap` |
| Norway maple | `tree.maple` | modeled + used | `monastery_quarter.rrmap` |
| Small-leaved linden | `tree.linden` | modeled + used | `monastery_quarter.rrmap` |
| Apple | `tree.apple` | modeled + fruit + used | `archbishops_garden.rrmap` |
| Sour cherry | `tree.cherry` | modeled + fruit + used | `archbishops_garden.rrmap` |
| European ash | `tree.ash` | modeled + used | `monastery_quarter.rrmap` |
| Wych elm | `tree.elm` | modeled + used | `monastery_quarter.rrmap` |
| Willow | `tree.willow` | modeled + used | `reval_harbor_east.rrmap` |
| Rowan | `tree.rowan` | modeled + used | `archbishops_garden.rrmap`, `reval_harbor_north.rrmap` |
| Common hazel | `tree.hazel` | modeled + used | `archbishops_garden.rrmap` |
| Common juniper | `tree.juniper` | modeled + used | `reval_harbor_east.rrmap` |
| Plum / damson | `tree.plum` | modeled + fruit + used | `archbishops_garden.rrmap` |
| European pear | `tree.pear` | modeled + fruit + used | `archbishops_garden.rrmap` |
| Common hawthorn | `tree.hawthorn` | modeled + fruit + used | `reval_harbor_north.rrmap` |
| Blackthorn | `tree.blackthorn` | modeled + fruit + used | `reval_harbor_east.rrmap` |

Sacred Grove landmark hingepuu (`primitive=ancient_tree` on the retired `world_sacred_grove.rrmap` greybox; the regional site [`sacred_grove.tscn`](../scenes/world/sites/sacred_grove.tscn) replaced it) uses the authored GLB loaded through [`map_view_mesh_builder_prop_models.gd`](../scripts/map/view3d/map_view_mesh_builder_prop_models.gd) (`sacred_grove_ancient_oak.glb`): buttressed trunk, giant primary limbs, dense canopy, and hanging moss. Grove `primitive=tree_line` buildings dress as large oak rows in 3D rather than house boxes.

Tree tests: `test_map_view_tree_species.gd` was retired with the legacy Lower Town scenes (commit `22811a3c`); it enforced the catalog target, cache reuse, bounded geometry, tapered trunks, size pins, and authored species use.

## Plant, herb, and crop model ledger (30/30)

`plant.*` identifies wild/medicinal/wetland plants; `crop.*` identifies cultivated food and fibre rows. Every entry has a species-specific profile using one of twelve geometry families, including rosette, broadleaf, flowering herb, frond, moss, reed, cattail, aquatic pad, cereal, stalk, and vine forms.

| Plant | Runtime ID | Status | Concrete authored evidence |
|---|---|---|---|
| Stinging nettle | `plant.nettle` | modeled + used | `monastery_quarter.rrmap` |
| Mugwort | `plant.mugwort` | modeled + used | `monastery_quarter.rrmap`, `reval_harbor_north.rrmap` |
| Yarrow | `plant.yarrow` | modeled + used | `monastery_quarter.rrmap` |
| Broadleaf plantain | `plant.plantain` | modeled + used | `monastery_quarter.rrmap`, `reval_harbor_north.rrmap` |
| Dandelion | `plant.dandelion` | modeled + used | `monastery_quarter.rrmap` |
| Burdock | `plant.burdock` | modeled + used | `reval_harbor_east.rrmap` |
| Creeping thistle | `plant.thistle` | modeled + used | `reval_harbor_east.rrmap` |
| Red/white clover | `plant.clover` | modeled + used | `archbishops_garden.rrmap` as a concrete bed; `grass.clover` remains a legacy cover alias |
| Bracken / male fern | `plant.fern` | modeled + used | `archbishops_garden.rrmap` as a concrete bed; `grass.fern` remains a legacy cover alias |
| Sphagnum moss | `plant.moss` | modeled + used | `archbishops_garden.rrmap` as a concrete bed; `grass.mossy` remains a legacy cover alias |
| Common reed | `plant.reed` | modeled + used | `viru_gate_foreland.rrmap` |
| Bulrush / cattail | `plant.cattail` | modeled + used | `viru_gate_foreland.rrmap` |
| White water lily | `plant.water_lily` | modeled + used | `viru_gate_foreland.rrmap` |
| Cabbage | `crop.cabbage` | modeled + used | `archbishops_garden.rrmap` |
| Turnip | `crop.turnip` | modeled + used | `archbishops_garden.rrmap` |
| Onion | `crop.onion` | modeled + used | `archbishops_garden.rrmap` |
| Garlic | `crop.garlic` | modeled + used | `archbishops_garden.rrmap` |
| Pea | `crop.pea` | modeled + used | `archbishops_garden.rrmap` |
| Broad bean | `crop.broad_bean` | modeled + used | `archbishops_garden.rrmap` |
| Rye | `crop.rye` | modeled + used | `archbishops_garden.rrmap` |
| Wheat | `crop.wheat` | modeled + used | `archbishops_garden.rrmap` |
| Barley | `crop.barley` | modeled + used | `archbishops_garden.rrmap` |
| Oat | `crop.oat` | modeled + used | `archbishops_garden.rrmap` |
| Flax | `crop.flax` | modeled + used | `archbishops_garden.rrmap` |
| Hemp | `crop.hemp` | modeled + used | `archbishops_garden.rrmap` |
| Hops | `crop.hops` | modeled + used | `archbishops_garden.rrmap` |
| Mint | `plant.mint` | modeled + used | `archbishops_garden.rrmap` |
| Caraway | `plant.caraway` | modeled + used | `monastery_quarter.rrmap` |
| Chamomile | `plant.chamomile` | modeled + used | `monastery_quarter.rrmap` |
| St. John's wort | `plant.st_johns_wort` | modeled + used | `monastery_quarter.rrmap` |

Plant tests: [`test_map_view_plant_species.gd`](../tests/godot/test_map_view_plant_species.gd). They enforce 30 registered models, cache reuse, geometry-family diversity, valid scatter profiles, and authored location coverage for all 20 trees and 30 plants.

## Shrub model ledger (20/20)

Group variants `bush.dense`, `bush.scrub`, `bush.mixed`, `bush.hedge`, `bush.heath`, `bush.coastal`, and `bush.bog` select weighted species pools. Authors may pin `bush.<species>` on props or terrain styles.

| Shrub | Runtime ID | Group | Status | Concrete authored evidence |
|---|---|---|---|---|
| Bilberry | `bush.bilberry` | berry | modeled + used | `archbishops_garden.rrmap` |
| Cowberry | `bush.cowberry` | berry | modeled + used | `archbishops_garden.rrmap` |
| Cloudberry | `bush.cloudberry` | bog | modeled + used | `archbishops_garden.rrmap` |
| Cranberry | `bush.cranberry` | bog | modeled + used | `archbishops_garden.rrmap` |
| Crowberry | `bush.crowberry` | heath | modeled + used | `archbishops_garden.rrmap` |
| Wild strawberry | `bush.wild_strawberry` | berry | modeled + used | `archbishops_garden.rrmap` |
| Raspberry | `bush.raspberry` | berry | modeled + used | `archbishops_garden.rrmap` |
| Dog rose | `bush.dog_rose` | understory | modeled + used | `archbishops_garden.rrmap` |
| Guelder rose | `bush.guelder_rose` | understory | modeled + used | `archbishops_garden.rrmap` |
| Elder | `bush.elder` | understory | modeled + used | `archbishops_garden.rrmap` |
| Sea buckthorn | `bush.sea_buckthorn` | coastal | modeled + used | `archbishops_garden.rrmap` |
| Heather | `bush.heather` | heath | modeled + used | `archbishops_garden.rrmap` |
| Bog rosemary | `bush.bog_rosemary` | bog | modeled + used | `archbishops_garden.rrmap` |
| Juniper shrub | `bush.juniper_shrub` | coastal | modeled + used | `archbishops_garden.rrmap` |
| Hazel shrub | `bush.hazel_shrub` | hedge | modeled + used | `archbishops_garden.rrmap` |
| Hawthorn | `bush.hawthorn` | hedge | modeled + used | `archbishops_garden.rrmap` |
| Blackthorn | `bush.blackthorn` | hedge | modeled + used | `archbishops_garden.rrmap` |
| Willow shrub | `bush.willow_shrub` | wetland | modeled + used | `archbishops_garden.rrmap` |
| Alder shrub | `bush.alder_shrub` | wetland | modeled + used | `archbishops_garden.rrmap` |
| Spindle | `bush.spindle` | hedge | modeled + used | `archbishops_garden.rrmap` |

Shrub tests: [`test_map_view_bush_species.gd`](../tests/godot/test_map_view_bush_species.gd). They enforce the 20-species catalog, cache reuse, archetype diversity, valid scatter profiles, legacy dense/scrub aliases, and authored location coverage.

## Bird model ledger (30/30)

`bird.*` IDs identify north-Baltic ambient species. Optional pose suffixes `.standing`, `.perched`, and `.gliding` select cached reference meshes. Status is pose-specific: `GLB` means the loader found a reviewed authored asset for the selected default pose or flap cycle; otherwise the entry intentionally uses the procedural fallback. Processed clips, district spawn weights, and runtime scheduling are implemented under **P0-105**.

| Bird | Runtime ID | Group | Status |
|---|---|---|---|
| Herring gull | `bird.herring_gull` | gull | modeled (catalog) + authored GLB flap cycle (**P2-034**) |
| Common gull | `bird.common_gull` | gull | modeled (catalog) + authored GLB flap cycle (**P2-034**) |
| Common tern | `bird.common_tern` | tern | modeled (catalog) + authored GLB flap cycle (**P2-034**) |
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

## Bird flight

Status: implemented (tasks **R-1188**, **R-1628**). Scope: ambient flight of the 30 catalogue species on outdoor maps, rigged leaders and instanced flock followers. Out of scope: take-off and landing, perching transitions, hovering (kestrel), soaring on thermals, and player interaction.

**What the player sees.** Every flying bird beats its wings with a real stroke: a longer power downstroke with the wing spread, then an upstroke with the hand folded back at the wrist. The body heaves up on each downstroke. Wingbeat rate and habit follow the family: geese, ducks, swans and waders row continuously (mallard about 5 beats/s, heron about 2), gulls, raptors and owls alternate flapping bouts with glides, finches, tits and woodpeckers fly in bounds with the wings snapped shut between bursts. Gregarious species (gulls, terns, waterfowl, waders, corvids, swallows) fly as a loose V behind the leader; every follower beats on its own clock, so the skein ripples instead of gliding frozen. The formation opens up for big birds so neighbouring wings do not cross.

**Flying in from and out into the distance (R-1628).** A bird holds its cruise speed for the whole flight; it never brakes to a hover. Each path runs from the edge of the flight window to the opposite edge (the whole map on district maps, a 160 m square round Kalev in the city) and is extended by `FADE_DEPTH` (45 m) into the distance on both sides. On those two legs the rigged leader is simplified: its rig is hidden and it is drawn by the same instanced flipbook as its followers, so it keeps beating its wings, and the whole flock dithers in (approach) or out (departure) through MultiMesh instance alpha (`fade_at(traveled, path_length)`, 0 at either end, 1 inside the window). The bird is retired only at the end of the departure leg, when it is fully transparent.

**Wing models.** Spread wings (anatomy revision 214, `map_view_bird_anatomy.gd`) are a cambered, double-sided wing plate with shingled coverts, rounded overlapping secondaries and family-specific hands: pointed (gulls, terns, swallows, ducks, kestrel), slotted with separated fingers (eagles, buzzards, herons, crows, cormorant) or rounded (songbirds, owls, lapwing). Underwings are paler where the species is. Feather quads are wound to face their normal: bird materials are double-sided and Godot flips the normal of back faces, which before this change lit every feather as if seen from below.

**Runtime entry points.**
- `scripts/map/view3d/map_view_bird_flight.gd`: `flap_profile(species)` (family `FLAP_PROFILES` plus `FLAP_OVERRIDES`), `flap_phase_at(time, profile)` (stroke phase 0..1, or -1 while resting), `wing_pose(phase, profile)` (shoulder and wrist angles plus body heave), `apply_wing_pose(rig, pose)`. Catalogue leaders pose the modular rig (`WingRootL/R`, `WingElbowL/R`); skinned storybook leaders (robin, hooded crow, gulls, mallard) switch `Fly`/`Glide` clips with `Fly` retimed to the species' wingbeat.
- Distant flight: `FADE_DEPTH`, `fade_at()`, `is_simplified(bird)`; `MapViewCrowdRenderer.replace_actor_transforms(transforms, alphas)` uploads the per-instance alpha. Catalogue birds dissolve in `assets/birds/catalog_plumage.gdshader` (`ALPHA = COLOR.a` with alpha hash, opaque pass, no sorting); storybook GLB flipbooks get alpha-hash copies of their standard materials (`_with_fade_materials`). Every species now builds a flipbook (it is the leader's distant LOD), so `configure()` also warms non-flocking skinned species. Flipbook renderers are not range-culled; rigged leaders keep a 220 m safety cull (`BIRD_DETAIL_RANGE`).
- Flock followers: per species `FLOCK_FLAP_FRAMES` (8) baked wingbeat poses plus one rest pose, each a `MapViewCrowdRenderer` MultiMesh (`flock_renderers_for(species)`). Catalogue poses are baked from the posed rig on the first flock (about 15 ms, once per species per session). Skinned poses are CPU-skinned one per frame by `_warm_flock_poses_step()` after `configure()` queues the map's gregarious skinned species, and are cached for the session per GLB; until a flipbook is ready its leader flies alone.
- `scenes/debug/asset_showcase.gd` uses the same wingbeat functions.

**Data and state.** No content IDs, save data or `GameState` change. All timing is deterministic: the start offset comes from the seeded spawn path, follower clocks from their rank.

**Verify.**

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_bird_flight,test_map_view_bird_meshes,test_bird_catalog_realism,test_storybook_live_integration
tools/godot_render.sh --script tools/capture_bird_catalog.gd -- --page=0 --flight --output=res://build/bird_flight_0.png
```

Evidence and before/after captures: [`reports/bird_flight_realism_2026-10-07.md`](reports/bird_flight_realism_2026-10-07.md). Fly-out (R-1628, left to right: rigged leader in the window, then the flipbook flock at fade 1.0, 0.65, 0.3, 0.05): [`r1628_bird_fly_out_fade.png`](reports/images/fauna/r1628_bird_fly_out_fade.png). `tests/godot/test_map_view_bird_flight.gd` covers constant speed, the extended path, the LOD hand-over and the fade materials.

**Limits.** Until a skinned species' flipbook has warmed (about 9 frames after `configure()`), its leader stays rigged on the far legs and is retired without a fade. Storybook surfaces whose vertex colour is not albedo would be recoloured by the fade, so they keep their look and stop drawing at the end of the leg. Wings are still rigid arm and hand sections on a two-joint rig, not a skinned feather simulation; feathers are cards, not a groomed coat. Followers step through 8 poses per wingbeat, which reads smoothly at flock distance but not in close-up. Warming a skinned flipbook costs about 15-23 ms per frame for 9 frames, once per GLB per session.

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
| Chicken | `fauna.chicken` | fowl | Lower Town + foreland pens | runtime (P0-106) |
| Domestic duck | `fauna.duck` | fowl | Lower Town + foreland pens | runtime (P0-106) |
| Domestic goose | `fauna.goose` | fowl | Lower Town + foreland pens | runtime (P0-106) |
| Domestic pig | `fauna.pig` | swine | Lower Town + foreland pens | runtime (P0-106) |
| Cattle | `fauna.cow` | ungulate | Lower Town + foreland pasture | runtime (P0-106) |
| Sheep | `fauna.sheep` | ungulate | foreland pasture (static props) | modeled (catalog) |

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

## Shore debris (CO-02 / R-949)

Beach shorelines (WS-08 `shore_type` beach, never quays) are dressed automatically.
Nothing is authored in `.rrmap`. The family lives in `assets/props/environment/shore/`
and is built by `tools/build_shore_debris.py`.

| Layer | Where | Model |
|---|---|---|
| Granite erratics (1.2 m, 2.1 m) | Shallows, 0.6-5 cells seaward; crown must clear the water | `shore_boulder_granite_medium`, `_large` |
| Barnacled erratic (1.6 m) | Just off the line, waterline at the top of its crust | `shore_boulder_granite_barnacled` |
| Weed apron | Round submerged stones, below the waterline only | `shore_algae_skirt` |
| Bladderwrack and reed drift | Within one cell of the waterline, along the shore | `shore_wrack_line_a`, `_b` |
| Shingle lens, stone clusters, small boulders | Beach, 1.2-6 cells landward | `shore_pebble_patch_*`, `shore_stone_cluster_*`, `shore_boulder_granite_small` |

Stones of 1.0 m or wider stand only on sea cells. Their footprints
(`MapViewTerrainDetails.shore_debris_blocking_cells`) are solid for swimming and boats,
and they never reduce the walkable region. Freshwater banks keep their reeds and cattails
and get no marine wrack.

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
