class_name MapTerrainMovement
extends RefCounted

## Resolves locomotion speed penalties from authored terrain variants, bushes, and
## rain-softened mud. Weather remains an optional input so logic-only maps retain
## deterministic dry-terrain behavior.

const MUD_DRY_SPEED_MULTIPLIER := 0.88
const MUD_SATURATED_SPEED_MULTIPLIER := 0.58


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
	return TerrainVegetation.clamp_speed_multiplier(multiplier)


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
