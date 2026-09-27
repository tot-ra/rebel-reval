class_name MapTerrainMovement
extends RefCounted

## Resolves locomotion speed penalties from authored terrain variants, bushes, and
## rain-softened mud. Weather remains an optional input so logic-only maps retain
## deterministic dry-terrain behavior.

const MUD_DRY_SPEED_MULTIPLIER := 0.88
const MUD_SATURATED_SPEED_MULTIPLIER := 0.58
## Same tolerance as the MAP_RELIEF_SLOPE validator, so a face exactly at the
## 1/64-quantised limit is walkable in both places.
const RELIEF_RISE_EPSILON := 0.0001


static func speed_multiplier_at(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	world_position: Vector2,
	mud_wetness: float = 0.0
) -> float:
	if definition == null or grid == null:
		return 1.0
	var cell := Vector2i(
		int(floor(world_position.x / float(definition.cell_size))),
		int(floor(world_position.y / float(definition.cell_size)))
	)
	var multiplier := grid.get_movement_speed_multiplier(cell)
	if grid.get_terrain(cell) == MapTypes.TERRAIN_MUD:
		multiplier = minf(multiplier, mud_speed_multiplier(mud_wetness))
	for prop in definition.props:
		multiplier = minf(multiplier, _prop_multiplier_at(prop, world_position))
	multiplier *= slope_speed_multiplier(definition, world_position)
	return TerrainVegetation.clamp_speed_multiplier(multiplier)


## ADR 0023 / WB-03 (R-975): speed scales by cos(slope) of the compiled ground up
## to the walkable limit. Steeper ground is impassable, so the curve never goes
## below cos(35 deg) ~= 0.82. The ADR curve is direction-free, so descending a
## bank costs the same as climbing it; it is monotonic in slope either way.
static func slope_speed_multiplier(definition: MapDefinition, world_position: Vector2) -> float:
	if not has_relief(definition):
		return 1.0
	return slope_cost_multiplier(definition.slope_at_world(world_position))


static func slope_cost_multiplier(slope: float) -> float:
	return cos(clampf(slope, 0.0, MapDefinition.RELIEF_MAX_WALKABLE_SLOPE))


## True when the definition has any non-planar ground (compiled relief or an
## `elevation=` datum with its edge taper). Flat maps skip every relief query.
static func has_relief(definition: MapDefinition) -> bool:
	return not definition.relief_heights.is_empty() or definition.ground_elevation != 0.0


## True when some cell of the map can be relief-blocked. The datum taper is a
## smoothstep over DATUM_TAPER_CELLS, whose steepest rise is 1.5 * datum / taper
## per cell; a datum below the walkable rise can never block, so today's flat and
## `elevation=` maps keep their walkable-cell census exactly.
static func relief_can_block(definition: MapDefinition) -> bool:
	if not definition.relief_heights.is_empty():
		return true
	var datum_rise := 1.5 * absf(definition.ground_elevation) / MapDefinition.DATUM_TAPER_CELLS
	return datum_rise > tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE)


## ADR 0023: a cell is impassable when any 4-neighbour face it shares is steeper
## than the walkable slope, or crosses an authored relief_cliff. Both cells of such
## a face are blocked, so a cliff reads as a band nobody can stand in rather than a
## ledge whose outcome depends on walking direction. Pure and thread-safe: the nav
## bake calls it on a worker.
static func is_relief_blocked_cell(definition: MapDefinition, cell: Vector2i) -> bool:
	if not relief_can_block(definition):
		return false
	var size := definition.size_cells
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	var max_rise := tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE) + RELIEF_RISE_EPSILON
	var here := definition.height_at(cell)
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size.x or neighbor.y >= size.y:
			continue
		if absf(here - definition.height_at(neighbor)) > max_rise:
			return true
		for feature in definition.relief_features:
			if feature.get("kind") != &"cliff":
				continue
			if is_cliff_lowered(feature, cell) != is_cliff_lowered(feature, neighbor):
				return true
	return false


## Single-cell form of MapBlueprintCompilerExpandTerrain.cliff_lowered_mask (the
## compiler builds the whole-map mask; walkability needs one cell at a time).
## test_relief_traversal pins the two to the same answer on every cell.
static func is_cliff_lowered(feature: Dictionary, cell: Vector2i) -> bool:
	var start := Vector2(feature["start"])
	var direction := Vector2(feature["end"]) - start
	var length := direction.length()
	if length <= 0.0:
		return false
	direction /= length
	var offset := Vector2(cell) - start
	var along := offset.dot(direction)
	if along < 0.0 or along > length:
		return false
	return direction.x * offset.y - direction.y * offset.x > 0.0


static func mud_speed_multiplier(wetness: float) -> float:
	# Freshly saturated mud yields underfoot; granular dry mud still drags a little.
	var saturation := smoothstep(0.0, 1.0, clampf(wetness, 0.0, 1.0))
	return lerpf(MUD_DRY_SPEED_MULTIPLIER, MUD_SATURATED_SPEED_MULTIPLIER, saturation)


static func _prop_multiplier_at(prop: Dictionary, world_position: Vector2) -> float:
	var authored: Variant = prop.get("movement_speed_multiplier")
	var base := TerrainVegetation.resolved_prop_speed(prop.get("kind", &""), authored)
	if base >= 1.0:
		return 1.0
	if prop.has("footprint"):
		var footprint: Rect2 = prop["footprint"]
		if footprint.has_point(world_position):
			return base
		return 1.0
	var position: Vector2 = prop.get("position", Vector2.ZERO)
	if position.distance_squared_to(world_position) <= 24.0 * 24.0:
		return base
	return 1.0
