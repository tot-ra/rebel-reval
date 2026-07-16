# P0-034 Migration Matrix

Recorded: 2026-07-16

This matrix classifies current slice-relevant artifacts for migration toward the vertical slice. Scene coverage follows all `working` and `partial` scenes from [`scene_inventory.md`](./scene_inventory.md) plus slice placeholders `market.tscn` and `olaf_guild_hall.tscn`. Asset coverage follows all 45 rows in [`ASSET_INVENTORY.md`](../ASSET_INVENTORY.md). Status values are only `retain`, `convert`, or `archive`.

## Maps & Scenes

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn` | `convert` | Greybox player rig still uses legacy district scale and hidden legacy HUD instance; migrate to P0-040 orthogonal/four-direction target. |
| `scenes/comparison_room/comparison_room.tscn` | `retain` | Verified P0-033 greybox baseline with procedural room content and slice mechanics. |
| `scenes/comparison_room/orthogonal_4_direction.tscn` | `retain` | P0-035 proposed orthogonal/four-direction comparison variant; keep as migration reference. |
| `scenes/comparison_room/diamond_isometric_8_direction.tscn` | `archive` | P0-035 legacy diamond-isometric/eight-direction spike; superseded by orthogonal target. |
| `scenes/elements/building.tscn` | `convert` | Reusable district prop; sprite and collision bounds need orthogonal/P0-040 alignment. |
| `scenes/elements/door.tscn` | `convert` | Transition logic is sound but doorway geometry must match new orthogonal room layouts. |
| `scenes/elements/FadeArea.tscn` | `convert` | Instanced in forge with empty `CollisionPolygon2D`; needs authored fade polygon for new maps. |
| `scenes/elements/npc.tscn` | `convert` | NPC prefab with SpriteFrames, AnimationPlayer, and HealthBar; refactor to four-direction rig. |
| `scenes/elements/turret.tscn` | `convert` | Wall/turret prop; sprite and collision bounds need orthogonal/P0-040 alignment. |
| `scenes/elements/UI.tscn` | `archive` | Hidden legacy NATURAL-element HUD shell; remove with P0-041 HUD cleanup. |
| `scenes/menu/main_menu.tscn` | `retain` | `run/main_scene` with verified Start/Exit flow (P0-017 smoke pass). |
| `scenes/reval_center/market_civic_quarter/market.tscn` | `convert` | Slice placeholder stub; populate when market civic quarter lands in the approved district. |
| `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | `convert` | Slice placeholder stub; populate when guild hall content lands in the approved district. |
| `scenes/reval_center/reval_center.tscn` | `convert` | Legacy isometric TileMap district; migrate to orthogonal greybox/primitive baseline. |
| `scenes/reval_east/forge/forge.tscn` | `convert` | Slice hub with embedded TileSet and legacy tile layers; migrate layout and forging systems. |
| `scenes/reval_east/reval_east.tscn` | `convert` | Default Start district on legacy `scenes/tileset.tres`; migrate to orthogonal target. |
| `scenes/reval_north/reval_north.tscn` | `convert` | Legacy isometric TileMap district; migrate to orthogonal greybox/primitive baseline. |
| `scenes/tests/font_glyph_render_test.tscn` | `retain` | Dev-only font verification scene; independent of map projection style. |

## TileSets

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/tileset.tres` | `archive` | Shared legacy isometric TileSet for district TileMapLayers; conflicts with orthogonal decision. |
| `scenes/reval_east/forge/forge.tscn@embedded_tileset` | `convert` | Forge scene embeds its own `TileSet` sub-resource; replace with orthogonal tile sources during forge migration. |
| `assets/tiles/greybox_floor.png` | `convert` | Active greybox floor texture referenced by `scenes/tileset.tres` and forge embedded TileSet until P0-040 art lands. |

## Collisions

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/comparison_room/comparison_room.gd@collisions` | `retain` | P0-033 procedural wall, player, door, and foreground-probe collision setup. |
| `scenes/comparison_room/comparison_room_variant.gd@collisions` | `retain` | P0-035 variant-aware procedural collision geometry for paired equivalence checks. |
| `player.tscn@collision_shape` | `convert` | Capsule collision on legacy scale; retune for orthogonal character height and pivots. |
| `scenes/elements/building.tscn@collision` | `convert` | Static building collision polygons tied to legacy sprite bounds. |
| `scenes/elements/turret.tscn@collision` | `convert` | Turret/wall collision tied to legacy sprite bounds. |
| `scenes/elements/door.tscn@collision` | `convert` | Door trigger geometry must match new orthogonal doorway widths. |
| `scenes/elements/FadeArea.tscn@collision` | `convert` | Empty fade polygon today; requires authored collision for foreground fade behavior. |
| `scenes/elements/npc.tscn@collision` | `convert` | NPC capsule collision on legacy scale; retune with four-direction rig. |

## Animations

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/comparison_room/comparison_room.gd@animations` | `retain` | P0-033 procedural player/NPC motion and combat animation checks. |
| `scenes/comparison_room/comparison_room_variant.gd@animations` | `retain` | P0-035 direction-policy animation behavior for paired equivalence checks. |
| `player.tscn@greybox_visual` | `convert` | Placeholder `ColorRect` body; replace with shared cutout rig (P0-037). |
| `scenes/elements/npc.tscn@sprite_frames` | `convert` | Embedded `SpriteFrames` and `AnimationPlayer` use eight-direction idle frames. |
| `scenes/elements/npc.tscn@animation_player` | `convert` | Legacy `AnimationPlayer` library tied to eight-direction atlas slices. |

## HUD

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn@health_stamina_bars` | `retain` | Inline `HealthBar` and `StaminaBar` ProgressBars are slice-relevant combat HUD. |
| `scenes/elements/UI.tscn@legacy_hud` | `archive` | Hidden legacy element HUD instance parented under player; remove with P0-041. |
| `scenes/elements/npc.tscn@health_bar` | `convert` | NPC overhead `ProgressBar` styling/scale should follow approved HUD rules. |
| `scenes/comparison_room/comparison_room.gd@hud` | `retain` | P0-033 procedural status `CanvasLayer` and dialogue/combat prompts. |
| `scenes/comparison_room/comparison_room_variant.gd@hud` | `retain` | P0-035 variant status overlay used during projection comparison verification. |
| `character/skills/abilities-fonts.tres` | `archive` | Superseded abilities font theme from pre-slice HUD design. |

## Runtime Assets

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `assets/bandits/woman1.png` | `convert` | Prototype NPC portrait/texture; adapt to P0-040 orthogonal style and four-direction rig. |
| `assets/buildings/*` (24 items) | `convert` | District building sprites; redraw or adapt to orthogonal three-quarter presentation. |
| `assets/objects/food/*` (3 items) | `convert` | Forge/market food props; restyle for approved scale and palette. |
| `assets/objects/furniture/*` (7 items) | `convert` | Interior props; restyle for approved scale and palette. |
| `assets/objects/smith-room/*` (8 items) | `convert` | Forge room props referenced by `forge.tscn`; restyle for approved scale and palette. |
| `assets/objects/weapons/hammer.png` | `convert` | Weapon prop art; restyle for approved scale and palette. |

## Verification

```bash
python3 tools/verify_migration_matrix.py
```

The verifier checks required sections, valid statuses, unique artifacts, resolvable paths/globs, full scene-set coverage, and exact coverage of all 45 image rows in `ASSET_INVENTORY.md`.
