# Scene inventory (P0-018)

Recorded: 2026-07-16

## Summary

| Classification | Count | Role |
|----------------|------:|------|
| `working` | 7 | Active runtime scenes with verified or complete behavior |
| `partial` | 10 | Substantial content but incomplete integration or dev-only use |
| `placeholder` | 5 | Reserved stubs or reference-only visuals, not playable |
| `archive` | 20 | Out of vertical-slice scope; legacy open-world or event shells |
| **Total** | **43** | Matches repository `.tscn` count |

Repository count command:

```bash
find . -name '*.tscn' -not -path './.git/*' | wc -l
# Expected: 43
```

Inventory row count (data rows in the table below): **43**.

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
| 3 | `scenes/elements/building.tscn` | working | Reusable building sprite with collision and light occluder. |
| 4 | `scenes/elements/door.tscn` | working | Door transitions via `door.gd` and `DoorNavigator`. |
| 5 | `scenes/elements/FadeArea.tscn` | partial | Instanced in forge; `CollisionPolygon2D` has no polygon yet. |
| 6 | `scenes/elements/npc.tscn` | working | NPC prefab with SpriteFrames, AnimationPlayer, navigation script, and HealthBar. |
| 7 | `scenes/elements/turret.tscn` | working | Wall/turret prop with collision and occluder; used in districts. |
| 8 | `scenes/elements/UI.tscn` | partial | Legacy character HUD shell (`visible = false`); still instanced by `player.tscn`. |
| 9 | `scenes/events/paldiski.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 10 | `scenes/events/pernau.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 11 | `scenes/events/pskov_arrival_battle.tscn` | archive | Empty `Node2D`; battle event outside slice. |
| 12 | `scenes/events/rebel_kings.tscn` | archive | Empty `Node2D`; campaign event outside slice. |
| 13 | `scenes/events/saaremaa.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 14 | `scenes/events/swedesh_outpost.tscn` | archive | Empty `Node2D`; campaign location outside slice. |
| 15 | `scenes/events/swedish_arrival.tscn` | archive | Empty `Node2D`; fleet arrival event outside slice. |
| 16 | `scenes/harbor/harbor.tscn` | placeholder | Single screenshot sprite; no player, doors, or navigation. |
| 17 | `scenes/harbor/warehouse.tscn` | partial | Inactive programmatic warehouse interior prototype (`active=false`); ADR 0006 scope expansion. |
| 18 | `scenes/intro/intro.tscn` | placeholder | Empty `Node2D`; intro video lives in `main_menu.tscn`. |
| 19 | `scenes/map/map.tscn` | placeholder | Static map image only; no interaction or travel logic. |
| 20 | `scenes/map_prototype/smithy_courtyard.tscn` | partial | P0-042 deterministic programmatic map-authoring spike; developer-only and not in the active transition manifest. |
| 21 | `scenes/menu/main_menu.tscn` | working | `run/main_scene`; Start/Exit UI, video, audio; P0-017 smoke pass. |
| 22 | `scenes/reval_center/market_civic_quarter/market.tscn` | partial | Inactive programmatic market square prototype; not in active destinations. |
| 23 | `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | partial | Inactive programmatic guild hall interior prototype; not in active destinations. |
| 24 | `scenes/reval_center/reval_center.tscn` | partial | Inactive programmatic market civic quarter prototype; removed from active destinations in P2-020. |
| 25 | `scenes/reval_east/forge/forge.tscn` | working | Programmatic smithy interior; `DoorNavigator` target with stable anchors and courtyard transition. |
| 26 | `scenes/reval_east/reval_east.tscn` | working | Programmatic bounded Lower Town exterior; default Start destination via manifest. |
| 27 | `scenes/reval_north/reval_north.tscn` | partial | Inactive programmatic north quarter prototype; removed from active destinations in P2-020. |
| 28 | `scenes/reval_toompea/domberg.tscn` | archive | Empty `Node2D`; Toompea district outside slice. |
| 29 | `scenes/reval_toompea/maria_toomkirik.tscn` | archive | Empty `Node2D`; cathedral shell outside slice. |
| 30 | `scenes/tests/font_glyph_render_test.tscn` | partial | Dev-only font glyph verification; not player-facing. |
| 31 | `scenes/world/haapsalu_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 32 | `scenes/world/harju_village.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 33 | `scenes/world/karja_fortress.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 34 | `scenes/world/maasilinna_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 35 | `scenes/world/padise/padise_monastery1.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 36 | `scenes/world/padise/padise_monastery2.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 37 | `scenes/world/paide_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 38 | `scenes/world/poide_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 39 | `scenes/world/sacred_grove.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 40 | `scenes/world/viljandi_castle.tscn` | archive | Empty `Node2D`; open-world location outside slice. |
| 41 | `scenes/comparison_room/comparison_room.tscn` | partial | P0-033 greybox baseline with procedural collisions, HUD, and slice mechanics verification. |
| 42 | `scenes/comparison_room/orthogonal_4_direction.tscn` | partial | P0-035 proposed orthogonal/four-direction variant; dev verification only. |
| 43 | `scenes/comparison_room/diamond_isometric_8_direction.tscn` | partial | P0-035 legacy diamond-isometric/eight-direction variant; dev verification only. |

## Totals by folder

| Folder | working | partial | placeholder | archive | Total |
|--------|--------:|--------:|------------:|--------:|------:|
| Repository root | 1 | 0 | 0 | 1 | 2 |
| `scenes/comparison_room/` | 0 | 3 | 0 | 0 | 3 |
| `scenes/elements/` | 4 | 2 | 0 | 0 | 6 |
| `scenes/events/` | 0 | 0 | 0 | 7 | 7 |
| `scenes/harbor/` | 0 | 1 | 1 | 0 | 2 |
| `scenes/intro/` | 0 | 0 | 1 | 0 | 1 |
| `scenes/map/` | 0 | 0 | 1 | 0 | 1 |
| `scenes/map_prototype/` | 0 | 1 | 0 | 0 | 1 |
| `scenes/menu/` | 1 | 0 | 0 | 0 | 1 |
| `scenes/reval_center/` | 0 | 1 | 2 | 0 | 3 |
| `scenes/reval_east/` | 1 | 1 | 0 | 0 | 2 |
| `scenes/reval_north/` | 0 | 1 | 0 | 0 | 1 |
| `scenes/reval_toompea/` | 0 | 0 | 0 | 2 | 2 |
| `scenes/tests/` | 0 | 1 | 0 | 0 | 1 |
| `scenes/world/` | 0 | 0 | 0 | 10 | 10 |
| **All** | **7** | **10** | **5** | **20** | **42** |

## Verification

```bash
# Repository scene count
find . -name '*.tscn' -not -path './.git/*' | wc -l

# Inventory data rows (excludes header/separator lines)
grep -E '^\| [0-9]+ \|' docs/reports/scene_inventory.md | wc -l
```

Both commands should print `42` on a clean checkout at this revision.

## Related tasks

- **P0-030** - prune active runtime folders using this inventory.
- **P0-034** - migration matrix for slice-relevant artifacts (complete; see [`migration_matrix_p0_034.md`](./migration_matrix_p0_034.md)).
- **P0-022** - fix door tags and stable scene IDs (`DEF-003`, `DEF-004` in [`known_runtime_defects.md`](./known_runtime_defects.md)).
