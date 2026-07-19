# Scene inventory (P0-018, reconciled P0-055)

Recorded: 2026-07-16
Reconciled: 2026-07-19 (gameplay help HUD, minimap HUD, forge commission overlay, journal overlay)

## Summary

| Classification | Count | Role |
|----------------|------:|------|
| `working` | 25 | Active runtime scenes with verified or complete behavior |
| `partial` | 19 | Substantial content but incomplete integration or dev-only use |
| `placeholder` | 3 | Reserved stubs or reference-only visuals, not playable |
| `archive` | 20 | Out of vertical-slice scope; legacy open-world or event shells |
| **Total** | **67** | Matches repository `.tscn` count |

Repository count command:

```bash
find . -name '*.tscn' -not -path './.git/*' | wc -l
# Expected: 67
```

Inventory row count (data rows in the table below): **63**.

## Classification criteria

| Class | Definition | Signals used in this inventory |
|-------|------------|----------------------------------|
| `working` | Scene is on the active runtime path or is a complete reusable component used by playable districts. Loads without missing resources in baseline checks where applicable. | Listed in `run/main_scene`, reachable via `DoorNavigator` or default Start flow, or instanced with complete scripts/collision. P0-017 headless smoke passed for `main_menu` and `reval_east`. |
| `partial` | Scene has meaningful authored content but is not fully integrated, uses legacy HUD/systems, or serves development verification only. | Tile maps and player present but slice mechanics missing; empty collision on used component; legacy NATURAL element HUD still attached; not in default menu flow; P0-033/P0-035 comparison spikes. |
| `placeholder` | Named scene file reserved for future work. Minimal node tree and no gameplay systems. | Root `Node2D` only, or a single reference sprite/screenshot without player, doors, navigation, or scripts. |
| `archive` | Outside first-campaign / vertical-slice scope per `README.md`. Not referenced by `DoorNavigator` or Start flow. Kept as legacy open-world, campaign event, or superseded wrapper. | Empty event/world/toompea shells; superseded root wrapper not used as `run/main_scene`. |

## Scope notes

- `DoorNavigator` registers `reval_south`, but no `scenes/reval_south/reval_south.tscn` exists in the repository (see `DEF-003` in [`known_runtime_defects.md`](./known_runtime_defects.md)). That missing scene is **not** part of this inventory.
- Sub-scenes under `scenes/reval_center/market_civic_quarter/` are placeholders and are **not** instanced by `reval_center.tscn` today.
- World and event folders align with README exclusions (open world, army battles, playable maps outside the approved slice district).
- `scenes/comparison_room/` holds P0-033 and P0-035 greybox spikes; they are not in the default Start flow.

## Inventory

| # | Scene path | Class | Notes |
|---|------------|-------|-------|
| 1 | `game.tscn` | archive | Legacy editor wrapper instancing `main_menu`; not `run/main_scene`. |
| 2 | `player.tscn` | working | Full player rig, greybox visual, inline HealthBar/StaminaBar, and hidden legacy HUD instance; instanced by all district scenes. |
| 3 | `assets/characters/cat/cat_rig.tscn` | partial | Ambient forge-cat rig; instanced by `forge_cat.tscn`; animation set incomplete. |
| 4 | `assets/characters/kalev/kalev.tscn` | working | Kalev variant on `shared_character_rig.tscn`; P0-037 player presentation. |
| 5 | `assets/characters/shared/hammer.tscn` | working | Shared hammer equipment mesh for rig attachment. |
| 6 | `assets/characters/shared/shared_character_rig.tscn` | working | Shared low-poly rig base with animation library; P0-037 foundation. |
| 7 | `assets/characters/shared/spear.tscn` | working | Shared spear equipment mesh; demo forge pickup visual. |
| 8 | `assets/characters/showcase/character_rig_showcase.tscn` | partial | Developer-only rig and animation verification scene. |
| 9 | `assets/characters/variants/henning.tscn` | working | Henning NPC variant; texture and equipment swap on shared rig. |
| 10 | `assets/characters/variants/innkeeper.tscn` | working | Innkeeper NPC variant; future slice cast. |
| 11 | `assets/characters/variants/mart.tscn` | working | Mart NPC variant; demo dialogue target. |
| 12 | `scenes/elements/building.tscn` | working | Reusable building sprite with collision and light occluder. |
| 13 | `scenes/elements/door.tscn` | working | Door transitions via `door.gd` and `DoorNavigator`. |
| 14 | `scenes/elements/FadeArea.tscn` | partial | Instanced in forge; `CollisionPolygon2D` has no polygon yet. |
| 15 | `scenes/elements/location_hud.tscn` | working | District title overlay; active on approved maps. |
| 16 | `scenes/elements/gameplay_help_hud.tscn` | working | Passive control-hint overlay on approved maps; mouse-transparent for click-to-move. |
| 17 | `scenes/elements/minimap_hud.tscn` | working | In-scene minimap HUD; P1-032 terrain, exits, and player marker; toggles with `N`. |
| 18 | `scenes/elements/npc.tscn` | working | NPC prefab with SpriteFrames, AnimationPlayer, navigation script, and HealthBar. |
| 19 | `scenes/elements/turret.tscn` | working | Wall/turret prop with collision and occluder; used in districts. |
| 20 | `scenes/elements/UI.tscn` | partial | Legacy character HUD shell (`visible = false`); still instanced by `player.tscn`. |
| 21 | `scenes/events/paldiski.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 22 | `scenes/events/pernau.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 23 | `scenes/events/pskov_arrival_battle.tscn` | archive | Empty `Node2D`; battle event outside slice. |
| 24 | `scenes/events/rebel_kings.tscn` | archive | Empty `Node2D`; campaign event outside slice. |
| 25 | `scenes/events/saaremaa.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 26 | `scenes/events/swedesh_outpost.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 27 | `scenes/events/swedish_arrival.tscn` | archive | Empty `Node2D`; fleet arrival event outside slice. |
| 28 | `scenes/harbor/harbor.tscn` | placeholder | Single screenshot sprite; no player, doors, or navigation. |
| 29 | `scenes/harbor/warehouse.tscn` | partial | Inactive programmatic warehouse interior prototype (`active=false`); ADR 0006 scope expansion. |
| 30 | `scenes/interaction/interactable.tscn` | working | Shared `Interactable` focus, prompt, and interaction range component. |
| 31 | `scenes/interaction/interaction_test.tscn` | partial | Developer-only interaction and input verification scene. |
| 32 | `scenes/intro/intro.tscn` | placeholder | Empty `Node2D`; intro video lives in `main_menu.tscn`. |
| 33 | `scenes/map/map.tscn` | placeholder | Static map image only; no interaction or travel logic. |
| 34 | `scenes/map_prototype/smithy_courtyard.tscn` | partial | P0-042 deterministic programmatic map-authoring spike; developer-only and not in the active transition manifest. |
| 35 | `scenes/menu/main_menu.tscn` | working | `run/main_scene`; Start/Exit UI, video, audio; P0-017 smoke pass. |
| 36 | `scenes/reval_center/market_civic_quarter/market.tscn` | partial | Inactive programmatic market square prototype; not in active destinations. |
| 37 | `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | partial | Inactive programmatic guild hall interior prototype; not in active destinations. |
| 38 | `scenes/reval_center/reval_center.tscn` | partial | Inactive programmatic market civic quarter prototype; removed from active destinations in P2-020. |
| 39 | `scenes/reval_east/forge/forge.tscn` | working | Programmatic smithy interior; `DoorNavigator` target with stable anchors and courtyard transition. |
| 40 | `scenes/reval_east/forge/forge_cat.tscn` | working | Ambient smithy cat with navigation and idle behavior. |
| 41 | `scenes/reval_east/forge/smithy_henning.tscn` | working | Smithy apprentice Henning with patrol and idle behavior. |
| 42 | `scenes/reval_east/reval_east.tscn` | working | Programmatic bounded Lower Town exterior; default Start destination via manifest. |
| 43 | `scenes/reval_north/reval_north.tscn` | partial | Inactive programmatic north quarter prototype; removed from active destinations in P2-020. |
| 44 | `scenes/reval_toompea/domberg.tscn` | archive | Empty `Node2D`; Toompea district outside slice. |
| 45 | `scenes/reval_toompea/maria_toomkirik.tscn` | archive | Empty `Node2D`; cathedral shell outside slice. |
| 46 | `scenes/tests/font_glyph_render_test.tscn` | partial | Dev-only font glyph verification; not player-facing. |
| 47 | `scenes/tests/dialogue_ui_test.tscn` | partial | Dev-only dialogue UI and settings review scene (P1-012/P1-013). |
| 48 | `scenes/tests/dialogue_overflow_test.tscn` | partial | Dev-only pseudo-localization overflow review scene (P1-014). |
| 49 | `scenes/ui/forge_commission_overlay.tscn` | working | Forge commission flow overlay; P1-019a smithy ledger interaction. |
| 50 | `scenes/ui/inventory_overlay.tscn` | working | Session bag overlay; D-003 pickup and inventory UI. |
| 51 | `scenes/ui/journal_overlay.tscn` | working | Quest journal overlay; P1-016 objectives and discovered evidence. |
| 52 | `scenes/world/haapsalu_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 53 | `scenes/world/harju_village.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 54 | `scenes/world/karja_fortress.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 55 | `scenes/world/maasilinna_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 56 | `scenes/world/padise/padise_monastery1.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 57 | `scenes/world/padise/padise_monastery2.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 58 | `scenes/world/paide_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 59 | `scenes/world/poide_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 60 | `scenes/world/sacred_grove.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 61 | `scenes/world/viljandi_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 62 | `scenes/world/world_item.tscn` | working | Pickup world-item component; D-003 anvil spearhead via `WorldItemController`. |
| 63 | `scenes/comparison_room/comparison_room.tscn` | partial | P0-033 greybox baseline with procedural collisions, HUD, and slice mechanics verification. |
| 64 | `scenes/comparison_room/orthogonal_4_direction.tscn` | partial | P0-035 proposed orthogonal/four-direction variant; dev verification only. |
| 65 | `scenes/comparison_room/diamond_isometric_8_direction.tscn` | partial | P0-035 legacy diamond-isometric/eight-direction variant; dev verification only. |
| 66 | `tools/benchmarks/large_map_benchmark.tscn` | partial | CI large-map pipeline benchmark host; not player-facing. |
| 67 | `tools/benchmarks/lower_town_scene_benchmark.tscn` | partial | CI Lower Town scene-load benchmark host; not player-facing. |

## Totals by folder

| Folder | working | partial | placeholder | archive | Total |
|--------|--------:|--------:|------------:|--------:|------:|
| Repository root | 1 | 0 | 0 | 1 | 2 |
| `assets/characters/` | 8 | 2 | 0 | 0 | 10 |
| `scenes/comparison_room/` | 0 | 3 | 0 | 0 | 3 |
| `scenes/elements/` | 7 | 2 | 0 | 0 | 9 |
| `scenes/events/` | 0 | 0 | 0 | 7 | 7 |
| `scenes/harbor/` | 0 | 1 | 1 | 0 | 2 |
| `scenes/interaction/` | 1 | 1 | 0 | 0 | 2 |
| `scenes/intro/` | 0 | 0 | 1 | 0 | 1 |
| `scenes/map/` | 0 | 0 | 1 | 0 | 1 |
| `scenes/map_prototype/` | 0 | 1 | 0 | 0 | 1 |
| `scenes/menu/` | 1 | 0 | 0 | 0 | 1 |
| `scenes/reval_center/` | 0 | 3 | 0 | 0 | 3 |
| `scenes/reval_east/` | 4 | 0 | 0 | 0 | 4 |
| `scenes/reval_north/` | 0 | 1 | 0 | 0 | 1 |
| `scenes/reval_toompea/` | 0 | 0 | 0 | 2 | 2 |
| `scenes/tests/` | 0 | 3 | 0 | 0 | 3 |
| `scenes/ui/` | 3 | 0 | 0 | 0 | 3 |
| `scenes/world/` | 1 | 0 | 0 | 10 | 11 |
| `tools/benchmarks/` | 0 | 2 | 0 | 0 | 2 |
| **All** | **25** | **19** | **3** | **20** | **67** |

## Verification

```bash
# Repository scene count
find . -name '*.tscn' -not -path './.git/*' | wc -l

# Inventory data rows (excludes header/separator lines)
grep -E '^\| [0-9]+ \|' docs/reports/scene_inventory.md | wc -l
```

Both commands should print `67` on a clean checkout at this revision.

## Related tasks

- **P0-055** - reconcile this inventory and `docs/MAP_CONVERSION_PLAN.md` with the full `.tscn` set (complete).
- **P0-057** - reconcile the four UI overlay scenes added after P0-055 (complete).
- **P0-030** - prune active runtime folders using this inventory.
- **P0-034** - migration matrix for slice-relevant artifacts (complete; see [`migration_matrix_p0_034.md`](./migration_matrix_p0_034.md)).
- **P0-022** - fix door tags and stable scene IDs (`DEF-003`, `DEF-004` in [`known_runtime_defects.md`](./known_runtime_defects.md)).
