# Flora and Fauna of Reval (Estonia, 1343)

This is the implementation ledger for Reval vegetation. It distinguishes concrete botanical models from generic terrain-cover styles and links every status to runtime code and authored locations.

## System status

- **Trees: 20/20 target species modeled and authored.** Catalog and visual traits: [`map_view_tree_species.gd`](../scripts/map/view3d/map_view_tree_species.gd). Bounded branching, leaves, and fruit: [`map_view_tree_meshes.gd`](../scripts/map/view3d/map_view_tree_meshes.gd).
- **Plants, herbs, and crops: 30/30 target species modeled and authored.** Catalog and growth profiles: [`map_view_plant_species.gd`](../scripts/map/view3d/map_view_plant_species.gd). Procedural meshes: [`map_view_plant_meshes.gd`](../scripts/map/view3d/map_view_plant_meshes.gd).
- **Ground-cover styles: 8/8 supported.** These are visual/ecological cover presets, not eight botanical species. Registration and density rules: [`terrain_vegetation.gd`](../scripts/map/terrain_vegetation.gd).
- **Rendering: complete for the scoped flora system.** [`map_view_mesh_builder_scatter.gd`](../scripts/map/view3d/map_view_mesh_builder_scatter.gd) batches each tree or plant species with cached meshes and `MultiMesh`; [`map_view_terrain_details.gd`](../scripts/map/view3d/map_view_terrain_details.gd) adds first-person grass, dry seed heads, clover, and fern detail.
- **Imported 3D flora assets: none by design.** Runtime vegetation is deterministic procedural geometry. Images under [`archive/2d_sprites_inspiration/assets/trees/`](../archive/2d_sprites_inspiration/assets/trees/) are references only and are not gameplay models.
- **Fauna: out of scope for this completion pass.** Ambient birds and animals remain unimplemented; folklore bestiary content is not an ambient-fauna system.

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
- ambient birds, mammals, insects, fish, and their behavior/audio systems;
- art-direction review from gameplay camera and performance profiling on target hardware.
