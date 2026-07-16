# P0-034 Migration Matrix

Recorded: 2026-07-16

This matrix classifies current slice-relevant artifacts (TileSets, maps, collisions, animations, HUD, and assets) for their migration path toward the vertical slice, referencing the current `comparison_room` greybox baseline and pending P0-040 art style (orthogonal, 4-direction).

## Maps & Scenes (from scene_inventory.md)

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/comparison_room/comparison_room.tscn` | `retain` | Verified P0-033 baseline using Godot primitive nodes and new mechanics. |
| `scenes/reval_east/reval_east.tscn` | `convert` | Migrate from legacy isometric tilemap to the new orthogonal/primitive base. |
| `scenes/reval_east/forge/forge.tscn` | `convert` | Slice hub needs migration from legacy tile layers to the new style. |
| `scenes/reval_center/reval_center.tscn` | `convert` | District needs migration to the new style. |
| `scenes/reval_north/reval_north.tscn` | `convert` | District needs migration to the new style. |
| `scenes/tests/font_glyph_render_test.tscn` | `retain` | Dev-only verification scene for fonts; remains useful independent of map style. |
| `scenes/menu/main_menu.tscn` | `retain` | Passed P0-017 smoke test; functional start flow. |

## TileSets & Environments

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/tileset.tres` | `archive` | Legacy isometric materials predate the orthogonal style decision. |
| `assets/tiles2.png` | `archive` | Legacy isometric material, inconsistent with new direction. |
| `assets/buildings/*` (25 items) | `convert` | Prototype art; to be adapted or redrawn to match the P0-040 orthogonal style. |
| `assets/objects/*` (18 items) | `convert` | Prototype art; to be adapted or redrawn to match the P0-040 orthogonal style. |

## Player & Animations

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `player.tscn` | `convert` | Rig needs updating to 4-direction animations and removal of legacy HUD. |
| `assets/player/*` (18 items) | `archive` | Eight-direction pixel-frame animations conflict with the pending 4-direction target. |
| `assets/bandits/*` (1 item) | `convert` | Prototype art; adapt to new 4-direction requirements and P0-040 style. |

## HUD & UI

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `character/skills/abilities-fonts.tres` | `archive` | Superseded UI theme related to old abilities design. |
| `character/skills/abilities-fonts.tres` | `archive` | Superseded UI theme related to old abilities design. |
| `assets/UI/*` (12 items) | `archive` | Legacy HUD art is frozen and inconsistent pending P0-040 UI style. |

## Collisions & Elements

| Artifact | Status | Rationale |
|----------|--------|-----------|
| `scenes/elements/building.tscn` | `convert` | Update visual sprite to orthogonal style and adjust collision bounds. |
| `scenes/elements/turret.tscn` | `convert` | Update visual sprite to orthogonal style and adjust collision bounds. |
| `scenes/elements/npc.tscn` | `convert` | Refactor to support new 4-direction animations and primitive/orthogonal scale. |
| `scenes/elements/door.tscn` | `convert` | Functional transition logic but needs adjustment to fit new orthogonal room layouts. |
| `scenes/elements/FadeArea.tscn` | `convert` | Currently has no polygon; requires proper collision shape setup for the new maps. |

