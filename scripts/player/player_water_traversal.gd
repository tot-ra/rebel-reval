class_name PlayerWaterTraversal
extends RefCounted

## ADR 0021 player-only water traversal layer. Walkability, navigation and every
## map audit keep treating water as blocked; only the player body ignores the
## water colliders and reads this layer to decide how deep the water is.
##
## Depth is the rendered water column under a logic position, in world units
## (1 unit = 1 cell): the still-water lift plus the WS-13b sea basin the terrain
## mesh already digs below the gameplay bed. Reading the same field the view
## renders means the swimmer's feet meet the seabed the camera actually sees.

## Rivers stay blocking in the first release (ADR 0021 decision 2): currents need
## drift and tuning for little gameplay value.
const BLOCKING_TERRAINS: Array[StringName] = [MapTypes.TERRAIN_RIVER_WATER]


## True for water terrain the player may enter (everything in WATER_TERRAINS
## except rivers). The colliders for the remaining terrain stay solid.
static func is_traversable_terrain(terrain: StringName) -> bool:
	return MapTypes.WATER_TERRAINS.has(terrain) and not BLOCKING_TERRAINS.has(terrain)


## Water column in world units under `logic_position` (location space), 0 on land.
static func depth_at(
	definition: MapDefinition, grid: MapTerrainGrid, logic_position: Vector2
) -> float:
	if definition == null or grid == null:
		return 0.0
	var cell_size := float(definition.cell_size)
	var cell := Vector2i(
		floori(logic_position.x / cell_size), floori(logic_position.y / cell_size)
	)
	if not is_traversable_terrain(grid.get_terrain(cell)):
		return 0.0
	var field := MapViewMeshBuilder.ensure_height_field(definition, grid)
	var world_xz := logic_position / cell_size
	return (
		MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
		+ MapViewMeshBuilderTerrain.basin_extra_depth(field, world_xz)
	)
