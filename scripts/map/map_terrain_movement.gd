class_name MapTerrainMovement
extends RefCounted

## Resolves locomotion speed penalties from authored terrain variants and bushes.


static func speed_multiplier_at(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	world_position: Vector2
) -> float:
	if definition == null or grid == null:
		return 1.0
	var cell := Vector2i(
		int(floor(world_position.x / float(definition.cell_size))),
		int(floor(world_position.y / float(definition.cell_size)))
	)
	var multiplier := grid.get_movement_speed_multiplier(cell)
	for prop in definition.props:
		multiplier = minf(multiplier, _prop_multiplier_at(prop, world_position))
	return TerrainVegetation.clamp_speed_multiplier(multiplier)


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
