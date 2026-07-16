class_name MapBuildingRenderer
extends RefCounted

## Builds simple orthogonal 3/4 buildings and matching collision footprints.


static func footprint_y_sort_anchor(footprint: Rect2) -> Vector2:
	return Vector2(footprint.position.x + footprint.size.x * 0.5, footprint.end.y)


static func create_building(building: Dictionary) -> StaticBody2D:
	var footprint: Rect2 = building["footprint"]
	var anchor := footprint_y_sort_anchor(footprint)
	var local_footprint := footprint
	local_footprint.position -= anchor

	var body := StaticBody2D.new()
	body.name = "Building_%s" % String(building["id"])
	body.position = anchor
	body.add_to_group("map_building_collision")
	body.set_meta("building_id", building["id"])
	body.set_meta("footprint", footprint)
	body.set_meta("y_sort_anchor", anchor)

	var wall_height: float = float(building.get("wall_height", 56.0))
	var wall_color: Color = building.get("wall_color", Color(0.35, 0.32, 0.28))
	var roof_color: Color = building.get("roof_color", Color(0.20, 0.18, 0.16))
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)

	var collision_shape := RectangleShape2D.new()
	collision_shape.size = local_footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = collision_shape
	collision.position = local_footprint.position + local_footprint.size * 0.5
	body.add_child(collision)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)

	match kind:
		MapTypes.BUILDING_KIND_WALL:
			_draw_wall(visuals, local_footprint, wall_height, wall_color)
		_:
			_draw_house(visuals, local_footprint, wall_height, wall_color, roof_color, String(building["id"]))

	return body


static func footprint_blocks_point(body: StaticBody2D, point: Vector2) -> bool:
	var footprint: Variant = body.get_meta("footprint", null)
	if footprint == null or not footprint is Rect2:
		return false
	var rect: Rect2 = footprint
	return rect.has_point(point)


static func _draw_house(
	parent: Node2D,
	footprint: Rect2,
	wall_height: float,
	wall_color: Color,
	roof_color: Color,
	building_id: String
) -> void:
	var hash := building_id.hash()

	_add_polygon(
		parent,
		"Floor",
		_rect_points(footprint),
		wall_color.darkened(0.28),
		0
	)

	var south_wall_height := maxf(12.0, minf(footprint.size.y * 0.55, 24.0))
	var south_wall := Rect2(
		footprint.position.x,
		footprint.end.y - south_wall_height,
		footprint.size.x,
		south_wall_height
	)
	_add_polygon(
		parent,
		"SouthFacade",
		_rect_points(south_wall),
		wall_color,
		2
	)

	var timber_spacing := 28.0
	var timber_count := maxi(1, int(footprint.size.x / timber_spacing))
	for index in timber_count:
		var timber_x := south_wall.position.x + float(index + 1) * (south_wall.size.x / float(timber_count + 1))
		var timber := Rect2(timber_x - 3.0, south_wall.position.y + 2.0, 6.0, south_wall.size.y - 4.0)
		_add_polygon(
			parent,
			"Timber%d" % index,
			_rect_points(timber),
			wall_color.darkened(0.18),
			3
		)

	var door_width := clampf(footprint.size.x * 0.18, 14.0, 24.0)
	var door := Rect2(
		south_wall.position.x + south_wall.size.x * 0.5 - door_width * 0.5,
		south_wall.end.y - door_width * 1.15,
		door_width,
		door_width * 1.15
	)
	_add_polygon(
		parent,
		"Doorway",
		_rect_points(door),
		wall_color.darkened(0.42),
		4
	)

	var window_width := clampf(footprint.size.x * 0.12, 10.0, 16.0)
	var window_height := clampf(south_wall.size.y * 0.35, 8.0, 14.0)
	for window_index in 2:
		var side := -1.0 if window_index == 0 else 1.0
		var window := Rect2(
			south_wall.position.x + south_wall.size.x * 0.5 + side * footprint.size.x * 0.22 - window_width * 0.5,
			south_wall.position.y + south_wall.size.y * 0.22,
			window_width,
			window_height
		)
		_add_polygon(
			parent,
			"Window%d" % window_index,
			_rect_points(window),
			Color(0.58, 0.72, 0.86, 1.0).darkened(float(abs(hash + window_index) % 3) * 0.04),
			4
		)

	var north_wall := Rect2(
		footprint.position.x,
		footprint.position.y,
		footprint.size.x,
		maxf(8.0, footprint.size.y * 0.18)
	)
	_add_polygon(
		parent,
		"NorthFacade",
		_rect_points(north_wall),
		wall_color.lightened(0.10),
		1
	)

	var roof_base := Rect2(
		footprint.position.x - 8.0,
		footprint.position.y - wall_height * 0.42,
		footprint.size.x + 16.0,
		footprint.size.y * 0.50
	)
	_add_polygon(
		parent,
		"Roof",
		_gabled_roof_points(roof_base),
		roof_color,
		5
	)
	_add_polygon(
		parent,
		"RoofRidge",
		_roof_ridge_points(roof_base),
		roof_color.lightened(0.06),
		6
	)


static func _draw_wall(
	parent: Node2D,
	footprint: Rect2,
	wall_height: float,
	wall_color: Color
) -> void:
	_add_polygon(
		parent,
		"WallMass",
		_rect_points(footprint),
		wall_color.darkened(0.20),
		0
	)

	var south_face_height := maxf(10.0, minf(footprint.size.y * 0.65, wall_height * 0.45))
	var south_face := Rect2(
		footprint.position.x,
		footprint.end.y - south_face_height,
		footprint.size.x,
		south_face_height
	)
	_add_polygon(
		parent,
		"SouthFace",
		_rect_points(south_face),
		wall_color,
		1
	)

	var coping_height := 6.0
	var coping := Rect2(
		footprint.position.x - 2.0,
		footprint.position.y - coping_height,
		footprint.size.x + 4.0,
		coping_height
	)
	_add_polygon(
		parent,
		"FlatCoping",
		_rect_points(coping),
		wall_color.lightened(0.14),
		2
	)

	var north_face := Rect2(
		footprint.position.x,
		footprint.position.y,
		footprint.size.x,
		maxf(6.0, footprint.size.y * 0.20)
	)
	_add_polygon(
		parent,
		"NorthFace",
		_rect_points(north_face),
		wall_color.lightened(0.06),
		1
	)


static func _add_polygon(parent: Node, node_name: String, points: PackedVector2Array, color: Color, layer: int) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.z_index = layer
	parent.add_child(polygon)


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


static func _gabled_roof_points(rect: Rect2) -> PackedVector2Array:
	var peak := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - rect.size.y * 0.40)
	return PackedVector2Array([
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.end.x, rect.position.y + rect.size.y * 0.28),
		peak,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.28),
	])


static func _roof_ridge_points(rect: Rect2) -> PackedVector2Array:
	var peak := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - rect.size.y * 0.40)
	var ridge_half := rect.size.x * 0.08
	return PackedVector2Array([
		Vector2(peak.x - ridge_half, peak.y + rect.size.y * 0.10),
		Vector2(peak.x + ridge_half, peak.y + rect.size.y * 0.10),
		Vector2(peak.x + ridge_half * 0.5, peak.y),
		Vector2(peak.x - ridge_half * 0.5, peak.y),
	])
