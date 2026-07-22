# P0-034 Migration Matrix

Recorded: 2026-07-16

This matrix classifies current slice-relevant artifacts for migration toward the vertical slice. Scene coverage follows all `working` and `partial` scenes from [`scene_inventory.md`](./scene_inventory.md) plus the slice placeholder `olaf_guild_hall.tscn`. The retired `market.tscn` stub was unified into `reval_center.tscn` and is no longer required. Asset coverage follows all 11 image rows in [`ASSET_INVENTORY.md`](../ASSET_INVENTORY.md). Status values are only `retain`, `convert`, or `archive`.

## Maps & Scenes

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn` | `convert` | Greybox player rig still uses legacy district scale and hidden legacy HUD instance; migrate to P0-040 orthogonal/four-direction target. |
| `assets/characters/cat/cat_rig.tscn` | `convert` | Ambient forge-cat rig; complete animation set under shared-rig production. |
| `assets/characters/kalev/kalev.tscn` | `convert` | Kalev shared-rig variant; freeze under P0-037/P0-040. |
| `assets/characters/shared/hammer.tscn` | `retain` | Shared hammer equipment mesh for rig attachment. |
| `assets/characters/shared/shared_character_rig.tscn` | `convert` | Shared low-poly rig base; production target for P0-037. |
| `assets/characters/shared/spear.tscn` | `retain` | Shared spear equipment mesh for demo forge pickup. |
| `assets/characters/showcase/character_rig_showcase.tscn` | `retain` | Developer-only rig verification scene. |
| `assets/characters/variants/henning.tscn` | `convert` | Henning NPC variant on shared rig. |
| `assets/characters/variants/innkeeper.tscn` | `convert` | Innkeeper NPC variant on shared rig. |
| `assets/characters/variants/mart.tscn` | `convert` | Mart NPC variant; demo dialogue target. |
| `assets/characters/variants/townswoman.tscn` | `convert` | Townswoman shared-rig variant for ambient NPCs. |
| `scenes/comparison_room/comparison_room.tscn` | `retain` | Verified P0-033 greybox baseline with procedural room content and slice mechanics. |
| `scenes/comparison_room/orthogonal_4_direction.tscn` | `retain` | P0-035 proposed orthogonal/four-direction comparison variant; keep as migration reference. |
| `scenes/comparison_room/diamond_isometric_8_direction.tscn` | `archive` | P0-035 legacy diamond-isometric/eight-direction spike; superseded by orthogonal target. |
| `scenes/map_prototype/smithy_courtyard.tscn` | `retain` | P0-042 deterministic declarative authoring spike; keep developer-only as the production schema reference. |
| `scenes/elements/building.tscn` | `convert` | Reusable district prop; sprite and collision bounds need orthogonal/P0-040 alignment. |
| `scenes/elements/door.tscn` | `convert` | Transition logic is sound but doorway geometry must match new orthogonal room layouts. |
| `scenes/elements/FadeArea.tscn` | `convert` | Instanced in forge with empty `CollisionPolygon2D`; needs authored fade polygon for new maps. |
| `scenes/elements/gameplay_help_hud.tscn` | `retain` | Legacy empty shell; control hints live in `QuickAccessMenu` on `player.tscn`. |
| `scenes/elements/location_hud.tscn` | `retain` | District title overlay used by map bootstrap. |
| `scenes/elements/minimap_hud.tscn` | `retain` | In-scene minimap HUD (P1-032). |
| `scenes/elements/npc.tscn` | `convert` | NPC prefab with SpriteFrames, AnimationPlayer, and HealthBar; refactor to four-direction rig. |
| `scenes/elements/turret.tscn` | `convert` | Wall/turret prop; sprite and collision bounds need orthogonal/P0-040 alignment. |
| `scenes/elements/UI.tscn` | `archive` | Hidden legacy NATURAL-element HUD shell; remove with P0-041 HUD cleanup. |
| `scenes/harbor/harbor_north.tscn` | `convert` | Inactive Trade Harbour prototype; developer traversal only. |
| `scenes/harbor/harbor_east.tscn` | `convert` | Inactive Fishing Harbour prototype; developer traversal only. |
| `scenes/harbor/warehouse.tscn` | `archive` | Inactive programmatic warehouse interior prototype (`active=false`). |
| `scenes/interaction/interactable.tscn` | `retain` | Shared focus/prompt interaction component. |
| `scenes/interaction/interaction_test.tscn` | `retain` | Developer-only interaction verification scene. |
| `scenes/menu/main_menu.tscn` | `retain` | `run/main_scene` with verified Start/Exit flow (P0-017 smoke pass). |
| `scenes/reval_archbishops_garden/reval_archbishops_garden.tscn` | `convert` | Inactive Archbishop's Garden western Toompea prototype; developer traversal only and release-gated. |
| `scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn` | `convert` | Slice placeholder stub; populate when guild hall content lands in the approved district. |
| `scenes/reval_center/reval_center.tscn` | `convert` | Unified inactive Central District prototype containing Town Hall market square and civic quarter; release-gated. |
| `scenes/reval_east/forge/forge.tscn` | `convert` | Slice hub with embedded TileSet and legacy tile layers; migrate layout and forging systems. |
| `scenes/reval_east/forge/forge_cat.tscn` | `retain` | Ambient smithy cat actor. |
| `scenes/reval_east/forge/smithy_henning.tscn` | `retain` | Smithy apprentice Henning actor. |
| `scenes/reval_east/reval_east.tscn` | `convert` | Default Start district on legacy `scenes/tileset.tres`; migrate to orthogonal target. |
| `scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn` | `convert` | Inactive Viru Gate road foreland prototype; developer traversal only and release-gated. |
| `scenes/reval_monastery/reval_monastery.tscn` | `convert` | Inactive Monastery District prototype splitting the historic northern ward; developer traversal only. |
| `scenes/reval_north/reval_north.tscn` | `convert` | Inactive programmatic north quarter prototype; developer traversal only. |
| `scenes/reval_south/reval_south.tscn` | `convert` | Inactive southern quarter prototype; developer traversal only. |
| `scenes/reval_toompea/reval_toompea.tscn` | `convert` | Inactive Toompea Upper Town prototype; developer traversal only. |
| `scenes/world_travel/world_sacred_grove.tscn` | `convert` | Sacred Grove developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_harju.tscn` | `convert` | Harju Village developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_padise.tscn` | `convert` | Padise Monastery developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_saaremaa.tscn` | `convert` | Saaremaa developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_rebel_kings.tscn` | `convert` | Rebel Kings Camp developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_kanavere.tscn` | `convert` | Kanavere Bog developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_sojamae.tscn` | `convert` | Sõjamäe Battlefield developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_paide.tscn` | `convert` | Paide Castle developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_parnu.tscn` | `convert` | Pärnu developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/world_travel/world_poide.tscn` | `convert` | Pöide Castle developer route; developer-only P1-037/P1-037a traversal wrapper, kept `release=false`. |
| `scenes/tests/font_glyph_render_test.tscn` | `retain` | Dev-only font verification scene; independent of map projection style. |
| `scenes/tests/dialogue_ui_test.tscn` | `retain` | Dev-only dialogue UI and settings review scene. |
| `scenes/tests/dialogue_overflow_test.tscn` | `retain` | Dev-only pseudo-localization overflow review scene. |
| `scenes/tests/combat_room.tscn` | `retain` | Dev-only P1-024 combat integration room with readable feedback. |
| `scenes/tests/night_encounter_stub.tscn` | `retain` | Dev-only P1-025b/P1-027a night consequence integration host. |
| `scenes/ui/forge_commission_overlay.tscn` | `retain` | Forge commission flow overlay. |
| `scenes/ui/inventory_overlay.tscn` | `retain` | Session bag overlay. |
| `scenes/ui/journal_overlay.tscn` | `retain` | Quest journal overlay. |
| `scenes/interaction/world_item.tscn` | `retain` | Pickup world-item component for D-003. |
| `tools/benchmarks/large_map_benchmark.tscn` | `retain` | CI large-map pipeline benchmark host; not player-facing. |
| `tools/benchmarks/lower_town_scene_benchmark.tscn` | `retain` | CI Lower Town scene-load benchmark host; not player-facing. |
| `tools/capture_demo_walkthrough_host.tscn` | `retain` | D-004 packaged demo walkthrough capture host; not player-facing. |

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
| `assets/characters/shared/kaykit_barbarian_barbarian_texture.png` | `retain` | CC0 KayKit source texture extracted from the pinned proof GLB; retained only for the P0-037 retarget pipeline. |
| `assets/UI/estonia_world_map.png` | `retain` | P1-037 developer Estonia basemap for `WorldMapOverlay`; release-false global map tab only, with C2PA provenance in `assets/SOURCES.csv`. |
| `assets/materials/style_lock/*` (8 items) | `retain` | Provenance-backed P0-051 reference textures; keep for style regression while P0-053 regenerates production surfaces. |

The former `assets/objects/food/*`, `assets/objects/furniture/*`, `assets/objects/smith-room/*`, and `assets/objects/weapons/hammer.png` rows are archived at mirrored `quarantine/assets/objects/` paths because their provenance is unresolved. They are outside the active runtime inventory; generated 3D props own the current runtime presentation.

## Verification

```bash
python3 tools/verify_migration_matrix.py
```

The verifier checks required sections, valid statuses, unique artifacts, resolvable paths/globs, full scene-set coverage, and exact coverage of every active image row in `ASSET_INVENTORY.md`. Quarantined sources remain provenance-tracked in `assets/SOURCES.csv` but are intentionally outside this active migration matrix.
