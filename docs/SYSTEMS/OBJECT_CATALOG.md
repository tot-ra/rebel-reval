# Physical object catalog

Status: implemented (task **R-OBJ-001**, proposed: create it on the task board before merging). The catalog, schema, validator, preview renderer, agent CLI, `ContentDB` lookup and the bag rules are implemented. The gameplay verbs (throw, push, consume, steal, hang) and map placement do **not** read the catalog yet; see [Limits](#limits). Scope: every physical thing the player can see, take, throw, push, use, eat, wear, steal or leave behind: containers, furniture, tools, weapons, clothing, food, light sources, trade goods, craft stations, vehicles and dressing sets. Out of scope: buildings, gates, walls and stairs (map blueprint system, [ADR 0009](../adr/0009-map-blueprint-authoring-architecture.md)), vegetation ([`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md)), animals ([`WORLD_LIFE.md`](./WORLD_LIFE.md)), quest `item.*` records (they link here through `item_ref`).

## The rule

**If a thing is not in the catalog it cannot be placed in the world, granted, sold or stolen.** A catalog entry is complete only when it has stats, a model (GLB or a named procedural builder) and an image. `tools/validate_object_catalog.py` enforces the coverage half today: every runtime prop GLB and every `MapTypes.ALL_PROP_KINDS` entry must be a catalog object or carry a written exclusion reason in [`docs/data/object_catalog_coverage.json`](../data/object_catalog_coverage.json).

## Handling classes

`handling` decides what the player may do. The validator ties it to mass and to the allowed actions, so stats and verbs cannot drift apart.

| `handling` | Mass | Player can | Bag |
|---|---|---|---|
| `fixed` | any | inspect, use, sit/sleep. Never moves, never stolen (well, anvil, hearth, bed, market stall). | no |
| `heavy` | usually over 25 kg or bulky | push and pull only (barrel, chest, table, cart). Never lifted. | no |
| `carry_two_hands` | 1 to 25 kg | lift in both hands, put down, push, throw if 15 kg or less (crate, keg, sack). | no (`NOT_CARRIABLE`) |
| `carry_one_hand` | up to 8 kg | take into the bag (2 or more cells), throw, equip (tools, weapons, chair, bucket). | yes |
| `pocketable` | under 1 kg | take into the bag (1 or 2 cells), stack when `carry.stackable`, throw (food, cups, keys, purses). | yes |

Everything in a bag still counts toward the 28 kg limit in [`INVENTORY_MECHANICS.md`](../INVENTORY_MECHANICS.md). A container is carried empty; its contents are separate objects.

## Record fields

One JSON file per object at `content/objects/<category>/obj.<name>.json`, validated by [`schemas/world_object.schema.json`](../../schemas/world_object.schema.json) plus the cross-field rules in the validator. IDs are stable and never reused.

| Block | Meaning |
|---|---|
| `id`, `name`, `description`, `category`, `tags` | Identity. `category` is one of container, furniture, tool, weapon, armor_clothing, food, drink, light_source, trade_good, material, household, craft_station, structure, vehicle, scenery, composite. |
| `handling` | Class from the table above. |
| `physical` | `mass_kg`, `size_m` (width, height, depth; derived from the GLB), `materials`, `fragile`, `flammable`, `hot_when_lit`. |
| `actions` | Allowed verbs: inspect, take, drop, throw, push, pull, open, use, equip, consume, light, sit, sleep, stack, hang, load_on_cart, break. Blocks must match: `consume` needs `edible`, `open` needs `container`, `light` needs `light`, `equip` needs `equip`, `throw` needs `throw`. |
| `carry` | Bag footprint (`grid_width`, `grid_height`, `stackable`, `max_stack`). Present exactly for `pocketable` and `carry_one_hand`. |
| `edible` | `kind` (food, drink, ingredient, medicine), `nutrition`, `hydration`, `intoxicating`, `spoils_after_days`, `raw_unsafe`. |
| `container` | `capacity_l`, `lockable`, `default_locked`, `accepts_tags`. |
| `light` | `radius_m`, `burn_hours`, `fuel`, `open_flame`. |
| `equip` | Paper-doll `slot` plus `damage_type` and `protection`. |
| `economy` | `base_pfennigs` (1343 Reval money, as in `TradePriceModel`), `ownership`, `legality`, `theft_severity` 0..3 (0 free, 1 petty, 2 watch responds, 3 capital). Owned takeable objects must be at least 1. |
| `placement` | `mount` (floor, surface, wall, hanging, ground, worn), `spaces` (forge, home_poor, home_burgher, tavern, market, harbor, ...), `grouping`. Used to fill spaces with the right things. |
| `composition` | A dressing set (`composite`) or pile lists the objects it is made of, so a pile of sacks resolves to takeable `obj.sack_grain`. |
| `item_ref` | Links to a quest or combat `item.*` record. The validator checks mass and bag footprint agree with that record. |
| `model` | See below. |
| `visual` | `preview`, `icon`, `icon_status`, `look`, `image_prompt`. |
| `lifecycle` | Derived: `planned` (no model, cannot be placed), `usable` (model exists), `complete` (model plus icon file). The validator rejects a wrong value. |

### Models

`model.status` is one of:

- `glb`: `model.glb` plus `model.node` when the GLB is a kit that holds several objects (kitchenware, household clutter, lighting, table kit). `model.states` maps state names to nodes for one object with several looks (domestic hearth cold/embers/lit, smithy clutter). `measured_size_m` and `physical.size_m` are written from the real geometry by `object_catalog.py sync`, so dimensions cannot be invented. `fitted_variants` lists per-character copies of the same wearable.
- `procedural`: the map view builds it in code. `model.prop_kind` and `model.builder` name the placement hook and the builder script. It needs a GLB eventually; today it is usable but not photogenic.
- `missing`: planned. The entry exists to fix the stats and the image prompt first.

`model.prop_kind` and `model.variant` tie an object to `MapTypes` / `map_prop_style_variants.gd` so a map prop resolves to its catalog stats.

### Images

- **`visual.preview`**: `docs/reports/images/object_catalog/<id>.png`, a deterministic software render of the GLB (`tools/render_object_previews.py`). It exists so agents can see what an object is. It is a flat-shaded reference, not shipped art.
- **`visual.icon`**: `res://assets/objects/icons/<id>.png`, the runtime icon. `icon_status` is `missing`, `generated` or `approved`. Nothing has an icon yet; the existing `assets/UI/inventory/` art is frozen legacy art (P0-040) and is not reused. Icons need an `assets/SOURCES.csv` row and a Godot `.import` sidecar when they land.
- **`visual.image_prompt`** plus the shared style suffix (`object_catalog.py prompts`) is the input for the image generator, with the preview as the shape reference.

## Agent workflow

```bash
python3 tools/object_catalog.py list --category food          # browse; also --handling --lifecycle --tag --text
python3 tools/object_catalog.py show obj.rye_bread_loaf       # full record
python3 tools/object_catalog.py set obj.jug physical.mass_kg=1.1 'tags=["kitchen","liquid"]'
python3 tools/object_catalog.py sync                          # re-measure GLBs, refresh sizes and lifecycle
python3 tools/render_object_previews.py                       # render missing/stale previews (--all, or object ids)
python3 tools/object_catalog.py prompts --missing-icons --out build/object_icon_prompts.jsonl
python3 tools/object_catalog.py index                         # refresh the table below (index --check in CI)
python3 tools/validate_object_catalog.py                      # must print 0 problems
```

To add an object: copy the closest existing JSON into the right category folder, change `id`, text, stats and `model`, run `sync`, then `render_object_previews.py`, `index` and the validator. To add a new GLB: either catalogue it or add an exclusion with a reason, otherwise the coverage check fails. To change a stat, edit the JSON (or `set`); never edit the preview or the index by hand.

## Runtime entry points

| Piece | File | Role |
|---|---|---|
| `ContentDB.get_world_object(id)` | `scripts/content/content_db.gd` | Typed lookup (`obj.` prefix, type `world_object`). |
| Session load | `scripts/session/session_state.gd` | `res://content/objects` is part of `DEMO_CONTENT_DIRS`. |
| `ItemCarryProfile.from_world_object` | `scripts/state/item_carry_profile.gd` | Bag footprint, mass and stack limit from a catalog record. |
| `InventoryBag` | `scripts/state/inventory_bag.gd` | Falls back to the catalog for `obj.*` ids; objects without a `carry` block return `AddResult.NOT_CARRIABLE` ("Too bulky for the bag"). |
| `WorldItemController` | `scripts/world/world_item_controller.gd` | Shows catalog names for `obj.*` world items. |

Save/load: the catalog is static content and adds no saved state. A bag or world item that holds an `obj.*` id saves it like any other id.

## Verification

- `python3 tools/validate_object_catalog.py` (schema, handling and action rules, GLB nodes and measured sizes, preview/icon files, lifecycle, item links, coverage)
- `python3 -m unittest tests.python.test_object_catalog -v`
- `python3 tools/validate_content.py content/objects` (generic content validator accepts the same files)
- `godot --headless --path . --script tools/run_godot_tests.gd` (`tests/godot/test_world_object_catalog.gd`)

## Current inventory

<!-- object-catalog-index:start (generated by tools/object_catalog.py index; do not edit) -->

139 objects (22 planned, 117 usable).

| ID | Name | Category | Handling | Mass (kg) | Actions | Edible | Model | Lifecycle |
|----|------|----------|----------|----------:|---------|:------:|-------|-----------|
| `obj.apron_leather` | Leather apron | armor_clothing | pocketable | 0.9 | take, equip |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdApron | usable |
| `obj.belt_leather` | Leather belt | armor_clothing | pocketable | 0.3 | take, equip |  | missing | planned |
| `obj.cape_wool` | Wool cape | armor_clothing | carry_one_hand | 1.4 | take, equip |  | `characters/shared/hero_cape.glb` | usable |
| `obj.hat_wool` | Wool hat | armor_clothing | pocketable | 0.25 | take, equip |  | `characters/shared/hero_hat.glb` | usable |
| `obj.helmet_open` | Open helmet | armor_clothing | carry_one_hand | 1.6 | take, equip |  | `storybook/equipment/mart_helmet.glb` | usable |
| `obj.leather_boots` | Leather boots | armor_clothing | carry_one_hand | 1.2 | take, equip |  | missing | planned |
| `obj.mail_hauberk` | Mail hauberk | armor_clothing | carry_two_hands | 12 | take, push, equip |  | `characters/shared/hero_mail.glb` | usable |
| `obj.tunic_wool` | Wool tunic | armor_clothing | pocketable | 0.9 | take, equip |  | missing | planned |
| `obj.watch_buckle` | Watchman's buckle | armor_clothing | carry_one_hand | 1.1 | take |  | missing | planned |
| `obj.set_kitchen_cleanup` | Kitchen cleanup setting | composite | fixed | 3 |  |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareGroupCleanup | usable |
| `obj.set_kitchen_eating` | Kitchen eating setting | composite | fixed | 3 |  |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareGroupEating | usable |
| `obj.set_kitchen_prep` | Kitchen prep setting | composite | fixed | 3 |  |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareGroupPrep | usable |
| `obj.set_kitchen_storage` | Kitchen storage corner | composite | fixed | 3 |  |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareGroupStorage | usable |
| `obj.set_smithy_household_clutter` | Smithy household clutter | composite | fixed | 12 |  |  | `props/domestic/household/smithy_household_clutter_kit.glb` › states | usable |
| `obj.barrel_oak` | Oak barrel | container | heavy | 38 | push, pull, open, break |  | procedural (`barrels`) | usable |
| `obj.basket_wicker` | Wicker basket | container | carry_one_hand | 1.2 | take, open |  | `props/furniture/household_kit/household_furniture_kit.glb` › Basket | usable |
| `obj.brewery_keg` | Small keg | container | carry_two_hands | 12 | take, push, open |  | procedural (`brewery_keg_stack`) | usable |
| `obj.cargo_crate` | Cargo crate | container | carry_two_hands | 14 | take, push, open, throw |  | procedural (`cargo_crates`) | usable |
| `obj.chest_burgher` | Burgher chest | container | heavy | 38 | push, pull, open |  | `props/furniture/chest_burgher_household/chest_burgher_household.glb` | usable |
| `obj.chest_merchant_strongbox` | Merchant strongbox | container | heavy | 85 | push, pull, open |  | `props/furniture/chest_merchant_strongbox/chest_merchant_strongbox.glb` | usable |
| `obj.chest_plain_coffer` | Plain coffer | container | heavy | 18 | push, pull, open |  | `props/furniture/chest_poor_household/chest_poor_household.glb` | usable |
| `obj.anvil_smithy` | Kalev's anvil | craft_station | fixed | 120 |  |  | `props/forge/kalev_smithy_anvil/kalev_smithy_anvil.glb` | usable |
| `obj.bellows_smithy` | Smithy bellows | craft_station | fixed | 35 | use |  | `props/forge/kalev_smithy_bellows/kalev_smithy_bellows.glb` | usable |
| `obj.finishing_bench` | Finishing bench | craft_station | fixed | 90 |  |  | `props/forge/kalev_smithy_finishing_bench/kalev_smithy_finishing_bench.glb` | usable |
| `obj.fish_drying_rack` | Fish drying rack | craft_station | fixed | 40 |  |  | procedural (`fish_drying_rack`) | usable |
| `obj.fish_splitting_table` | Fish splitting table | craft_station | fixed | 45 |  |  | procedural (`fish_splitting_table`) | usable |
| `obj.flax_drying_frame` | Flax drying frame | craft_station | fixed | 25 |  |  | procedural (`flax_drying_frame`) | usable |
| `obj.hearth_smithy` | Smithy forge hearth | craft_station | fixed | 900 |  |  | `props/forge/kalev_smithy_hearth/kalev_smithy_hearth.glb` | usable |
| `obj.slack_tub` | Slack tub | craft_station | fixed | 70 |  |  | `props/forge/kalev_smithy_slack_tub/kalev_smithy_slack_tub.glb` | usable |
| `obj.smoke_rack` | Smoke rack | craft_station | fixed | 60 |  |  | procedural (`smoke_rack`) | usable |
| `obj.table_trestle_work` | Trestle work table | craft_station | heavy | 30 | push, pull |  | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › TrestleWorkTable | usable |
| `obj.tanning_frame` | Tanning frame | craft_station | fixed | 40 |  |  | `props/crafts/tanning_frame/tanning_frame.glb` | usable |
| `obj.ale_tankard` | Ale tankard | drink | pocketable | 0.6 | take, throw, consume | yes | missing | planned |
| `obj.beer_jug` | Jug of small beer | drink | pocketable | 0.95 | take, throw, consume | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionBeerJug | usable |
| `obj.wine_flask` | Leather wine flask | drink | carry_one_hand | 1.2 | take, consume | yes | missing | planned |
| `obj.apple` | Apple | food | pocketable | 0.15 | take, throw, consume, stack | yes | missing | planned |
| `obj.cheese_wheel` | Cheese wheel | food | carry_one_hand | 1.2 | take, consume | yes | missing | planned |
| `obj.dried_peas_bin` | Bin of dried peas | food | carry_one_hand | 4 | take, consume | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionDriedPeasBin | usable |
| `obj.fish_smoked` | Smoked fish | food | pocketable | 0.4 | take, consume, stack | yes | missing | planned |
| `obj.herring_filleted` | Filleted herring | food | pocketable | 0.25 | take, consume, stack | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionHerringFilleted | usable |
| `obj.herring_fresh` | Fresh herring | food | pocketable | 0.3 | take, consume, stack | yes | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › FishModule | usable |
| `obj.honey_pot` | Honey pot | food | pocketable | 0.8 | take, consume | yes | missing | planned |
| `obj.onion_braid` | Braid of onions | food | pocketable | 0.6 | take, hang, consume | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionOnionBraid | usable |
| `obj.rye_bread_cut` | Cut rye bread | food | pocketable | 0.35 | take, consume, stack | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionRyeBreadCut | usable |
| `obj.rye_bread_loaf` | Rye loaf | food | pocketable | 0.8 | take, throw, consume, stack | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionRyeBreadLoaf | usable |
| `obj.sack_flour` | Flour sack | food | carry_two_hands | 20 | take, push, consume | yes | missing | planned |
| `obj.armarium_elite` | Elite armarium | furniture | fixed | 140 | open |  | `props/furniture/medieval_storage/elite_armarium/elite_armarium.glb` | usable |
| `obj.bed_smithy` | Smithy bed | furniture | fixed | 60 | sleep, sit |  | `props/furniture/smithy_bed/smithy_bed.glb` | usable |
| `obj.bed_straw_pallet` | Straw-tick box bed | furniture | fixed | 45 | sit, sleep |  | `props/furniture/household_kit/household_furniture_kit.glb` › StrawPallet | usable |
| `obj.bench_plank` | Plank bench | furniture | heavy | 14 | sit, push, pull |  | `props/furniture/household_kit/household_furniture_kit.glb` › Bench | usable |
| `obj.chair_smithy` | Wooden chair | furniture | carry_one_hand | 5 | take, sit, push, pull, throw |  | `props/furniture/smithy_chair/smithy_chair.glb` | usable |
| `obj.cupboard_burgher` | Burgher cupboard | furniture | fixed | 95 | open |  | `props/furniture/medieval_storage/burgher_cupboard/burgher_cupboard.glb` | usable |
| `obj.herb_drying_rack` | Herb drying rack | furniture | fixed | 8 |  |  | procedural (`herb_drying_rack`) | usable |
| `obj.market_stall` | Market stall | furniture | fixed | 150 |  |  | `props/market/market_stall.glb` | usable |
| `obj.shelf_common_open` | Open rack | furniture | fixed | 22 | open |  | `props/furniture/medieval_storage/common_open_rack/common_open_rack.glb` | usable |
| `obj.stock_rack` | Iron stock rack | furniture | fixed | 80 | open |  | `props/forge/kalev_smithy_stock_rack/kalev_smithy_stock_rack.glb` | usable |
| `obj.stool_three_leg` | Three-legged stool | furniture | carry_one_hand | 2.5 | take, sit, throw |  | `props/furniture/household_kit/household_furniture_kit.glb` › Stool | usable |
| `obj.table_common_household` | Household table | furniture | heavy | 28 | push, pull |  | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › CommonHouseholdTable | usable |
| `obj.table_long_board` | Long board table | furniture | heavy | 55 | push, pull |  | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › LongBoardTable | usable |
| `obj.weapon_rack` | Weapon rack | furniture | fixed | 60 | open |  | procedural (`weapon_rack`) | usable |
| `obj.bowl_large` | Large bowl | household | pocketable | 0.5 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareBowlLarge | usable |
| `obj.bowl_small` | Small bowl | household | pocketable | 0.25 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareBowlSmall | usable |
| `obj.clay_pot` | Clay pot | household | pocketable | 0.9 | take, throw, open |  | `props/furniture/household_kit/household_furniture_kit.glb` › ClayPot | usable |
| `obj.coin_purse` | Coin purse | household | pocketable | 0.2 | take |  | missing | planned |
| `obj.cooking_pot` | Lidded cooking pot | household | carry_one_hand | 3 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareCookingPotLidded | usable |
| `obj.cup` | Clay cup | household | pocketable | 0.2 | take, throw |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareCup | usable |
| `obj.cutting_board` | Cutting board | household | carry_one_hand | 1.2 | take, throw |  | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › CuttingBoardModule | usable |
| `obj.iron_key` | Iron key | household | pocketable | 0.1 | take |  | missing | planned |
| `obj.jar_lidded` | Lidded jar | household | pocketable | 0.7 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareJarLidded | usable |
| `obj.jar_open` | Open jar | household | pocketable | 0.6 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareJarOpen | usable |
| `obj.jug` | Water jug | household | pocketable | 0.9 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareJug | usable |
| `obj.ledger_book` | Account ledger | household | carry_one_hand | 1.5 | take, use |  | procedural (`ledger`) | usable |
| `obj.linen_folded` | Folded linen | household | pocketable | 0.4 | take, stack |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdLinenFolded | usable |
| `obj.prep_board` | Kitchen prep board | household | carry_one_hand | 1.5 | take, throw |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwarePrepBoard | usable |
| `obj.quench_bucket` | Quench bucket | household | carry_one_hand | 3 | take, open |  | procedural (`quench_bucket`) | usable |
| `obj.salt_crock` | Salt crock | household | pocketable | 0.9 | take, consume | yes | `props/domestic/household/smithy_household_clutter_kit.glb` › ProvisionSaltCrock | usable |
| `obj.trencher` | Wooden trencher | household | pocketable | 0.3 | take, throw |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareTrencher | usable |
| `obj.wash_basin_cloth` | Wash basin and cloth | household | carry_one_hand | 1.8 | take, throw, open |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareBasinCloth | usable |
| `obj.wash_tub` | Wash tub | household | heavy | 22 | push, pull, open |  | procedural (`wash_tub`) | usable |
| `obj.water_bucket` | Water bucket | household | carry_one_hand | 2.5 | take, use, open |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdWaterBucket | usable |
| `obj.wooden_spoon` | Wooden spoon | household | pocketable | 0.05 | take |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareSpoon | usable |
| `obj.candlestick_beeswax_rich` | Beeswax candlestick | light_source | carry_one_hand | 2.2 | take, light |  | `props/lighting/medieval_lighting_kit.glb` › RichBeeswax | usable |
| `obj.candlestick_tallow_artisan` | Artisan tallow candlestick | light_source | carry_one_hand | 1.4 | take, light |  | `props/lighting/medieval_lighting_kit.glb` › ArtisanTallow | usable |
| `obj.candlestick_tallow_poor` | Poor tallow candle | light_source | pocketable | 0.4 | take, light |  | `props/lighting/medieval_lighting_kit.glb` › PoorTallow | usable |
| `obj.grease_lamp` | Grease lamp | light_source | pocketable | 0.5 | take, light |  | `props/lighting/medieval_lighting_kit.glb` › GreaseLamp | usable |
| `obj.hanging_lantern_iron` | Hanging iron lantern | light_source | carry_one_hand | 1.8 | take, hang, light |  | missing | planned |
| `obj.pine_splint_holder` | Pine splint holder | light_source | carry_one_hand | 1.5 | take, light |  | `props/lighting/medieval_lighting_kit.glb` › PineSplint | usable |
| `obj.wall_torch` | Wall torch | light_source | carry_one_hand | 1.2 | take, hang, throw, light |  | missing | planned |
| `obj.boat_timber_stack` | Boat timber stack | material | fixed | 500 |  |  | procedural (`boat_timber_stack`) | usable |
| `obj.brick_clay` | Clay brick | material | carry_one_hand | 1.8 | take, throw, stack |  | missing | planned |
| `obj.charcoal_storage` | Charcoal store | material | fixed | 120 |  |  | `props/forge/smithy_charcoal_storage/smithy_charcoal_storage.glb` | usable |
| `obj.cobblestone` | Cobblestone | material | carry_one_hand | 2.2 | take, throw, stack |  | missing | planned |
| `obj.cooper_staves` | Bundle of staves | material | carry_two_hands | 20 | take, push |  | procedural (`cooper_staves`) | usable |
| `obj.firewood_armful` | Armful of firewood | material | carry_two_hands | 14 | take, push |  | `props/furniture/household_kit/household_furniture_kit.glb` › FirewoodArmful | usable |
| `obj.firewood_log` | Firewood log | material | carry_one_hand | 2.5 | take, throw, stack |  | `props/furniture/household_kit/household_furniture_kit.glb` › FirewoodLog | usable |
| `obj.firewood_pile_indoor` | Firewood by the hearth | material | fixed | 40 |  |  | `props/furniture/household_kit/household_furniture_kit.glb` › states | usable |
| `obj.firewood_stack` | Firewood stack | material | fixed | 220 |  |  | `props/crafts/yard_firewood_stack/yard_firewood_stack.glb` | usable |
| `obj.hay_stack` | Hay stack | material | fixed | 400 |  |  | procedural (`hay_stack`) | usable |
| `obj.iron_bar` | Iron bar | material | carry_one_hand | 3.5 | take, stack |  | missing | planned |
| `obj.iron_scrap_pile` | Scrap iron pile | material | fixed | 150 |  |  | procedural (`iron_scrap_pile`) | usable |
| `obj.kindling_bundle` | Kindling bundle | material | carry_one_hand | 1.5 | take, stack |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdKindlingBundle | usable |
| `obj.rope_coil_hemp` | Hemp rope coil | material | carry_one_hand | 6.5 | take |  | `props/crafts/rope_coil/rope_coil.glb` | usable |
| `obj.scrap_heap_smithy` | Smithy scrap heap | material | fixed | 60 |  |  | `props/forge/kalev_smithy_scrap_heap/kalev_smithy_scrap_heap.glb` | usable |
| `obj.banner_cloth` | Cloth banner | scenery | fixed | 6 |  |  | procedural (`banner`) | usable |
| `obj.hearth_domestic` | Domestic hearth | structure | fixed | 800 |  |  | `props/domestic/hearth/medieval_hearth_kit.glb` › states | usable |
| `obj.well_stone` | Stone well | structure | fixed | 2500 | use |  | procedural (`well`) | usable |
| `obj.ash_scoop` | Ash scoop | tool | pocketable | 0.7 | take |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdAshScoop | usable |
| `obj.broom` | Twig broom | tool | carry_one_hand | 1 | take, throw |  | `props/domestic/household/smithy_household_clutter_kit.glb` › HouseholdBroom | usable |
| `obj.fish_knife` | Fish knife | tool | pocketable | 0.2 | take, throw |  | `props/furniture/tables/medieval_table_kit/medieval_table_kit.glb` › KnifeModule | usable |
| `obj.kitchen_knife` | Kitchen knife | tool | pocketable | 0.15 | take, throw |  | `props/domestic/kitchenware/medieval_kitchenware_kit.glb` › KitchenwareKnife | usable |
| `obj.lantern_hook` | Street lantern hook | tool | pocketable | 0.9 | take |  | missing | planned |
| `obj.pitchfork` | Pitchfork | tool | carry_one_hand | 2.2 | take, throw, equip |  | `props/tools/pitchfork/pitchfork.glb` | usable |
| `obj.rake` | Wooden rake | tool | carry_one_hand | 1.8 | take, throw |  | `props/tools/rake/rake.glb` | usable |
| `obj.scythe` | Scythe | tool | carry_one_hand | 2.4 | take, equip |  | `props/tools/scythe/scythe.glb` | usable |
| `obj.sickle` | Sickle | tool | pocketable | 0.6 | take, throw, equip |  | `props/tools/sickle/sickle.glb` | usable |
| `obj.smith_hammer` | Smith's hand hammer | tool | carry_one_hand | 1.8 | take, throw, equip |  | `props/tools/blacksmith_hammer/blacksmith_hammer.glb` | usable |
| `obj.smith_punch` | Smith's punch | tool | pocketable | 0.4 | take, throw |  | `props/tools/blacksmith_punch/blacksmith_punch.glb` | usable |
| `obj.smith_tongs` | Smith's tongs | tool | carry_one_hand | 1.6 | take |  | `props/tools/blacksmith_tongs/blacksmith_tongs.glb` | usable |
| `obj.wooden_shovel` | Wooden shovel | tool | carry_one_hand | 1.6 | take |  | `props/tools/wooden_shovel/wooden_shovel.glb` | usable |
| `obj.cargo_cloth_salt` | Cloth and salt | trade_good | heavy | 160 | push, pull |  | `props/trade/western_cloth_salt/western_cloth_salt.glb` | usable |
| `obj.cargo_furs_wax` | Furs and wax | trade_good | heavy | 120 | push, pull |  | `props/trade/eastern_furs_wax/eastern_furs_wax.glb` | usable |
| `obj.cargo_grain_flax` | Grain and flax | trade_good | heavy | 150 | push, pull |  | `props/trade/livonian_grain_flax/livonian_grain_flax.glb` | usable |
| `obj.cargo_herring_barrels` | Barrelled herring | trade_good | heavy | 320 | push, pull |  | `props/trade/barrelled_herring_metal/barrelled_herring_metal.glb` | usable |
| `obj.fishing_nets` | Fishing nets | trade_good | carry_two_hands | 9 | take, push |  | `props/crafts/fishing_nets/fishing_nets.glb` | usable |
| `obj.malt_sack_pile` | Malt sack pile | trade_good | fixed | 180 |  |  | `props/crafts/malt_sack_pile/malt_sack_pile.glb` | usable |
| `obj.market_goods_pallet` | Market goods pallet | trade_good | heavy | 70 | push, pull |  | procedural (`market_goods_pallet`) | usable |
| `obj.sack_grain` | Grain sack | trade_good | carry_two_hands | 22 | take, push, load_on_cart |  | missing | planned |
| `obj.sail_cloth_bale` | Sail cloth bale | trade_good | carry_two_hands | 22 | take, push, load_on_cart |  | procedural (`sail_cloth_bale`) | usable |
| `obj.salt_pile` | Salt pile | trade_good | fixed | 300 |  |  | `props/crafts/salt_pile/salt_pile.glb` | usable |
| `obj.hay_wagon` | Hay wagon | vehicle | heavy | 300 | push, pull, load_on_cart |  | procedural (`hay_wagon`) | usable |
| `obj.merchant_barrow` | Merchant barrow | vehicle | heavy | 30 | push, pull, load_on_cart |  | `props/trade/merchant_barrow/merchant_barrow.glb` | usable |
| `obj.merchant_wagon` | Merchant wagon | vehicle | heavy | 450 | push, pull, load_on_cart |  | `props/trade/merchant_wagon_4w/merchant_wagon_4w.glb` | usable |
| `obj.supply_cart` | Supply cart | vehicle | heavy | 180 | push, pull, load_on_cart |  | `props/trade/supply_cart/supply_cart.glb` | usable |
| `obj.wooden_cart` | Wooden handcart | vehicle | heavy | 160 | push, pull, load_on_cart |  | `props/vehicles/wooden_cart.glb` | usable |
| `obj.forge_hammer` | Forge hammer | weapon | carry_one_hand | 4.5 | take, throw, equip |  | `storybook/equipment/hammer.glb` | usable |
| `obj.shield_round` | Round shield | weapon | carry_one_hand | 3.2 | take, equip |  | `storybook/equipment/shield.glb` | usable |
| `obj.spear_watch` | Watch spear | weapon | carry_one_hand | 2.2 | take, throw, equip |  | missing | planned |
| `obj.spearhead_iron` | Iron spearhead | weapon | pocketable | 0.35 | take |  | missing | planned |
| `obj.sword_cruciform` | Cruciform sword | weapon | carry_one_hand | 1.45 | take, equip |  | `storybook/equipment/sword.glb` | usable |

<!-- object-catalog-index:end -->

## Limits

- No gameplay verb reads the catalog yet beyond bag pickup: throwing, pushing, consuming, lighting, hanging, stealing and theft consequences have no runtime. The `actions`, `throw`, `edible`, `light` and `economy` blocks are the data contract for them.
- Map placement is not gated on `lifecycle`. Map props keep using `MapTypes` kinds; the validator only proves each kind has an object or an exclusion. A placement check ("planned objects cannot be placed") needs a task.
- No runtime icons exist. All 134 objects have `icon_status: missing`; `planned` objects also have no model.
- Dimensions of GLB objects are as authored in the files; several forge props (anvil, bellows, hearth) are larger than their real-world counterparts and were not rescaled.
- The `obj.` objects `obj.forge_hammer`, `obj.sword_cruciform`, `obj.watch_buckle`, `obj.lantern_hook`, `obj.spear_watch` and `obj.spearhead_iron` link to quest and combat `item.*` records through `item_ref`; the item records still own combat numbers and quest flags.
- Arrangements (`composite`) carry a `composition` list, but nothing spawns the parts when a set is split yet.
