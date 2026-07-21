class_name MapWallWalkAccess
extends RefCounted

## Shared semantics for authored wall-walk stairs and platforms. The flat 2D
## position remains gameplay-authoritative: platform intersections open only the
## associated fortification collision, while the 3D view mirrors actors onto the
## visible timber access structure.

const ACCESS_PRIMITIVE := &"wall_walk_access"
const PLATFORM_PRIMITIVE := &"wall_walk_platform"


static func is_access_prop(prop: Dictionary) -> bool:
	return (
		prop.get("kind", &"") == MapTypes.PROP_KIND_STAIRS
		and prop.get("primitive", &"") == ACCESS_PRIMITIVE
		and prop.get("footprint") is Rect2
	)


static func is_platform_prop(prop: Dictionary) -> bool:
	return (
		prop.get("kind", &"") == MapTypes.PROP_KIND_STAIRS
		and prop.get("primitive", &"") == PLATFORM_PRIMITIVE
		and prop.get("footprint") is Rect2
	)


static func has_tower_passage(building: Dictionary) -> bool:
	return is_round_tower(building) and passage_axis(building) != &""


static func is_round_tower(building: Dictionary) -> bool:
	return bool(building.get("round_tower", building.get("tower", false)))


static func passage_axis(building: Dictionary) -> StringName:
	var axis := StringName(building.get("wall_walk_axis", &""))
	return axis if axis in [&"x", &"z"] else &""


static func tower_passage_rect(building: Dictionary) -> Rect2:
	if not has_tower_passage(building):
		return Rect2()
	var footprint: Rect2 = building["footprint"]
	var width := minf(
		MapViewMeshBuilderConfig.WALL_WALK_PASSAGE_WIDTH_PX,
		minf(footprint.size.x, footprint.size.y)
	)
	if passage_axis(building) == &"x":
		return Rect2(
			Vector2(footprint.position.x, footprint.get_center().y - width * 0.5),
			Vector2(footprint.size.x, width)
		)
	return Rect2(
		Vector2(footprint.get_center().x - width * 0.5, footprint.position.y),
		Vector2(width, footprint.size.y)
	)


static func collision_rects(definition: MapDefinition, building: Dictionary) -> Array[Rect2]:
	var footprint_value: Variant = building.get("footprint")
	if not (footprint_value is Rect2):
		return []
	var rects: Array[Rect2] = [footprint_value as Rect2]
	if definition == null or building.get("kind", &"") != MapTypes.BUILDING_KIND_WALL:
		return rects

	# WHY: wall geometry remains a solid visual mass, but explicitly authored
	# platforms and tower axes are the gameplay contract for a walkable wall-top
	# corridor. Subtract only those overlaps so unrelated fortifications stay sealed.
	var openings: Array[Rect2] = []
	if has_tower_passage(building):
		openings.append(tower_passage_rect(building))
	for prop in definition.props:
		if not is_platform_prop(prop):
			continue
		var opening := (prop["footprint"] as Rect2).intersection(footprint_value as Rect2)
		if opening.has_area():
			openings.append(opening)

	for opening in openings:
		var remaining: Array[Rect2] = []
		for rect in rects:
			remaining.append_array(_subtract_rect(rect, opening))
		rects = remaining
	return rects


static func point_blocked_by_building(
	definition: MapDefinition,
	building: Dictionary,
	point: Vector2
) -> bool:
	for rect in collision_rects(definition, building):
		if rect.has_point(point):
			return true
	return false


static func target_height(definition: MapDefinition, prop: Dictionary) -> float:
	if definition == null or (not is_access_prop(prop) and not is_platform_prop(prop)):
		return 0.0
	var footprint: Rect2 = prop["footprint"]
	var nearest_distance := INF
	var nearest: Dictionary = {}
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_WALL:
			continue
		if is_round_tower(building):
			continue
		var authored_height := float(building.get("wall_height", 0.0))
		if authored_height < MapViewMeshBuilderConfig.BATTLEMENT_MIN_HEIGHT_PX:
			continue
		var distance := _rect_distance(footprint, building["footprint"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = building
	var max_distance := float(definition.cell_size) * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_MAX_TARGET_DISTANCE_CELLS
	if nearest.is_empty() or nearest_distance > max_distance:
		return 0.0
	return (
		MapTypes.resolved_wall_height_px(nearest)
		* MapViewBridge.world_scale(definition.cell_size)
		+ MapViewMeshBuilderConfig.CAP_HEIGHT
	)


static func elevation_at(definition: MapDefinition, logic_position: Vector2) -> float:
	if definition == null:
		return 0.0
	# Platforms take precedence where authored rectangles touch at their boundary.
	for prop in definition.props:
		if not is_platform_prop(prop):
			continue
		var footprint: Rect2 = prop["footprint"]
		if footprint.has_point(logic_position):
			return target_height(definition, prop)
	for prop in definition.props:
		if not is_access_prop(prop):
			continue
		var footprint: Rect2 = prop["footprint"]
		if not footprint.has_point(logic_position):
			continue
		var facing := Vector2(prop.get("facing", Vector2.RIGHT)).normalized()
		if facing.is_zero_approx():
			continue
		var progress := _progress_along(footprint, logic_position, facing)
		var climb := clampf(
			progress / MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION,
			0.0,
			1.0
		)
		return target_height(definition, prop) * smoothstep(0.0, 1.0, climb)
	return 0.0


static func _progress_along(rect: Rect2, point: Vector2, facing: Vector2) -> float:
	if absf(facing.x) >= absf(facing.y):
		var progress := (point.x - rect.position.x) / rect.size.x
		return progress if facing.x >= 0.0 else 1.0 - progress
	var progress := (point.y - rect.position.y) / rect.size.y
	return progress if facing.y >= 0.0 else 1.0 - progress


static func _rect_distance(left: Rect2, right: Rect2) -> float:
	var dx := maxf(maxf(left.position.x - right.end.x, right.position.x - left.end.x), 0.0)
	var dy := maxf(maxf(left.position.y - right.end.y, right.position.y - left.end.y), 0.0)
	return Vector2(dx, dy).length()


static func _subtract_rect(source: Rect2, opening: Rect2) -> Array[Rect2]:
	var overlap := source.intersection(opening)
	if not overlap.has_area():
		return [source]
	var pieces: Array[Rect2] = []
	_append_rect(pieces, Rect2(
		source.position,
		Vector2(overlap.position.x - source.position.x, source.size.y)
	))
	_append_rect(pieces, Rect2(
		Vector2(overlap.end.x, source.position.y),
		Vector2(source.end.x - overlap.end.x, source.size.y)
	))
	_append_rect(pieces, Rect2(
		Vector2(overlap.position.x, source.position.y),
		Vector2(overlap.size.x, overlap.position.y - source.position.y)
	))
	_append_rect(pieces, Rect2(
		Vector2(overlap.position.x, overlap.end.y),
		Vector2(overlap.size.x, source.end.y - overlap.end.y)
	))
	return pieces


static func _append_rect(rects: Array[Rect2], rect: Rect2) -> void:
	if rect.has_area():
		rects.append(rect)
