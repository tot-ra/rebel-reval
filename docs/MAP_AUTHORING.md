# Programmatic map authoring (P0-042)

This document describes the deterministic, data-driven map spike for the **Smithy Courtyard** and adjacent **Lower Town street**. It is a procedural geometry prototype only: no raster tiles, no edits to active district scenes, and no replacement of production art.

## Goals

1. **Declarative definitions** that are easy for humans and AI agents to extend.
2. **Reusable builder/renderer** that fills world bounds with a base terrain and overlays zones.
3. **Seven distinct terrain IDs** with fixed-seed procedural accents: `grass`, `sand`, `hay`, `dirt`, `cobblestone`, `water`, `stone`.
4. **Data-defined buildings and props** with simple orthogonal 3/4 visuals and `StaticBody2D` collisions derived from the same footprints.
5. **Playable prototype scene** with camera and four-direction greybox player for inspection.

## Layout references (read-only)

Use these legacy images only as **layout and scale references**, not as runtime textures:

| Reference | Path | Use |
|-----------|------|-----|
| City overview | `scenes/revel-map.jpg` | Relative placement of Lower Town quarters, streets, and the eastern forge cluster |
| Wall topology | `scenes/reval_walls_towers/wall-map.png` | Gate spacing, block scale, and north-south street rhythm |

The spike map is **not** a pixel trace of either image. It captures the approved slice relationships:

- A **north-south cobblestone connection** from Lower Town into a **smith work yard**.
- A **street band** along the north edge (Lower Town).
- **Hay, stone forge pad, sand/coal pile, and water trough** inside the courtyard readable at gameplay scale.

## Historical and scale principles

- **Orthogonal gameplay plane** per [ADR 0002](adr/0002-orthogonal-three-quarter-perspective.md): collisions and navigation use flat X/Y; art may suggest depth with facades and roofs.
- **Cell size:** `32` world pixels per terrain cell (see `MapTypes.DEFAULT_CELL_SIZE`).
- **Prototype world:** `50 x 28` cells -> `1600 x 896` pixels, aligned with the project viewport width.
- **Zones** are declared in **cells** as `Rect2i`.
- **Building footprints and prop anchors** are derived from cells via `MapDefinition.cell_rect_to_world_rect()` and `MapDefinition.cell_rect_center()` so authors never mix units in one definition file.
- **Medieval density:** courtyard props and buildings are packed for walkable inspection, not historical cadastral accuracy.

## Architecture

```
scripts/map/
  map_types.gd                  # terrain IDs, building/prop kinds, defaults
  map_definition.gd             # declarative schema + validation + cell helpers
  smithy_courtyard_definition.gd# spike content
  map_terrain_grid.gd           # built per-cell terrain
  map_builder.gd                # fill base + apply zones
  terrain_palette.gd            # colors + deterministic patterns
  map_terrain_renderer.gd       # draws full grid
  map_building_renderer.gd      # 3/4 houses/walls + collisions
  map_prop_renderer.gd          # procedural props
  map_assembler.gd              # wires nodes into a scene
  map_prototype_player.gd       # four-direction greybox walker

scenes/map_prototype/
  smithy_courtyard.tscn         # playable prototype
  smithy_courtyard.gd           # scene bootstrap

tests/godot/
  test_programmatic_map.gd      # validation, determinism, coverage, collisions
```

### Data flow

1. `MapDefinition` holds `base_terrain`, ordered `zones`, `buildings`, `props`, and `player_spawn`.
2. `MapBuilder.build()` fills every cell with `base_terrain`, then paints each zone rectangle.
3. `MapTerrainRenderer` draws every cell with `TerrainPalette.pattern_color()` using `definition.seed`.
4. `MapBuildingRenderer` and `MapPropRenderer` instantiate visuals from the same dictionaries.
5. `smithy_courtyard.gd` loads `SmithyCourtyardDefinition.create()` and calls `MapAssembler.assemble()` with the scene `Actors` node for shared Y-sort.

## Authoring a new map (recipe)

### 1. Create a definition factory

Add `scripts/map/your_map_definition.gd`:

```gdscript
class_name YourMapDefinition
extends RefCounted

static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"your_map"
	definition.seed = 42042
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(50, 28)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = definition.cell_rect_center(Rect2i(20, 15, 2, 2))

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(8, 0, 30, 4)},
	]
	definition.buildings = [
		{
			"id": &"example_hall",
			"kind": MapTypes.BUILDING_KIND_HOUSE,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(10, 8, 6, 4)),
			"wall_height": 64.0,
			"wall_color": Color(0.35, 0.32, 0.28),
			"roof_color": Color(0.20, 0.18, 0.16),
		},
		{
			"id": &"courtyard_wall",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": definition.cell_rect_to_world_rect(Rect2i(8, 8, 1, 10)),
			"wall_height": 48.0,
			"wall_color": Color(0.48, 0.50, 0.54),
		},
	]
	definition.props = [
		{
			"id": &"well",
			"kind": MapTypes.PROP_KIND_WELL,
			"position": definition.cell_rect_center(Rect2i(28, 18, 4, 3)),
		},
	]
	return definition
```

### 2. Validate early

```gdscript
var errors := MapBuilder.validate(YourMapDefinition.create())
assert errors.is_empty()
```

Validation rejects:

- Unknown terrain, building kind, or prop kind
- Empty or out-of-bounds terrain zones
- Duplicate stable IDs across buildings and props
- `player_spawn` or prop positions outside world bounds
- Building footprints outside world bounds

### 3. Add a prototype scene

Copy `scenes/map_prototype/smithy_courtyard.tscn` and point the root script at your definition factory. Pass the scene `Actors` node into `MapAssembler.assemble()` so buildings, props, and the player share one Y-sort hierarchy.

### 4. Extend tests

Mirror `tests/godot/test_programmatic_map.gd` for your definition: validation, fingerprint determinism, full cell coverage, all terrain IDs used, footprint collision equality, cell helper consistency, and negative validation cases.

### 5. Visual check

Run `scenes/map_prototype/smithy_courtyard.tscn` in the editor. Confirm:

- No gaps inside world bounds.
- All seven terrain types are visually distinct.
- Building footprints block the greybox player.
- Stone courtyard walls read as enclosed with the street lane left open.
- The player can walk in front of and behind props/buildings via Y-sort.

## Zone and building fields

### Zone entry

| Field | Type | Notes |
|-------|------|-------|
| `terrain` | `StringName` | One of the seven terrain IDs |
| `rect` | `Rect2i` | Cell rectangle; later zones overwrite earlier ones |

### Building entry

| Field | Type | Notes |
|-------|------|-------|
| `id` | `StringName` | Stable identifier |
| `kind` | `StringName` | `house` (gabled roof, doorway, timber) or `wall` (flat coping, no roof) |
| `footprint` | `Rect2` | World-pixel collision and floor; derive from `cell_rect_to_world_rect()` |
| `wall_height` | `float` | Facade extrusion for 3/4 read |
| `wall_color` / `roof_color` | `Color` | Procedural polygon tints (`roof_color` ignored for `wall`) |

Y-sort anchor for buildings is the **south footprint edge center** (`MapBuildingRenderer.footprint_y_sort_anchor()`).

### Prop entry

| Field | Type | Notes |
|-------|------|-------|
| `id` | `StringName` | Stable identifier |
| `kind` | `StringName` | `anvil`, `hay_stack`, `cart`, `well`, `barrels` |
| `position` | `Vector2` | World-pixel feet anchor; derive from `cell_rect_center()` |

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 2 scenes/map_prototype/smithy_courtyard.tscn
```

Headless tests cover definition validation (including negative cases), terrain determinism, full-grid coverage, presence of all terrain IDs, building footprint collisions, cell helper consistency, well/water alignment, and courtyard wall segments.

## Constraints

- **Procedural geometry only** - no new raster assets.
- **Do not modify active districts** (`reval_east`, `reval_center`, `forge`, etc.) until P0-040 / P2-003.
- **No JSON/schema framework** - plain typed GDScript dictionaries keep the spike small and AI-editable.
