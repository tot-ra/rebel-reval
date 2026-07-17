class_name MapBuildingRenderer
extends RefCounted

## Builds medieval Reval silhouettes over immutable collision footprints.


static func footprint_y_sort_anchor(footprint: Rect2) -> Vector2:
	return Vector2(footprint.position.x + footprint.size.x * 0.5, footprint.end.y)


static func create_building(
	building: Dictionary,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> StaticBody2D:
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
	body.set_meta("visual_target", target)

	# Collision is always derived from the shared footprint, never from target art.
	var collision_shape := RectangleShape2D.new()
	collision_shape.size = local_footprint.size
	var collision := CollisionShape2D.new()
	collision.shape = collision_shape
	collision.position = local_footprint.position + local_footprint.size * 0.5
	body.add_child(collision)

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)

	var wall_height: float = MapTypes.resolved_wall_height_px(building)
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	match kind:
		MapTypes.BUILDING_KIND_WALL, MapTypes.BUILDING_KIND_INTERIOR_WALL:
			_draw_wall(visuals, local_footprint, wall_height, target, time_of_day)
		MapTypes.BUILDING_KIND_INTERIOR_BLOCK:
			_draw_interior_block(visuals, local_footprint, wall_height, target, time_of_day)
		_:
			_draw_house(visuals, local_footprint, wall_height, target, time_of_day, String(building["id"]))
	return body


static func footprint_blocks_point(body: StaticBody2D, point: Vector2) -> bool:
	var footprint: Variant = body.get_meta("footprint", null)
	return footprint is Rect2 and (footprint as Rect2).has_point(point)


static func _draw_house(
	parent: Node2D,
	footprint: Rect2,
	wall_height: float,
	target: StringName,
	time_of_day: StringName,
	building_id: String
) -> void:
	var ink := MapVisualStyle.role_color(&"ink", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var roof := MapVisualStyle.role_color(&"roof", target, time_of_day)
	var outline := MapVisualStyle.outline_width(target)

	var shadow_rect := footprint
	shadow_rect.position += MapVisualStyle.shadow_offset(target)
	_add_polygon(parent, "GroundShadow", _rect_points(shadow_rect), Color(ink, MapVisualStyle.shadow_alpha(target, time_of_day)), -3)
	_add_polygon(parent, "Floor", _rect_points(footprint), plaster.darkened(0.28), -2, ink, outline)

	var facade_height := maxf(20.0, minf(footprint.size.y * 0.62, 30.0))
	var facade := Rect2(footprint.position.x, footprint.end.y - facade_height, footprint.size.x, facade_height)
	_add_polygon(parent, "SouthFacade", _rect_points(facade), plaster, 1, ink, outline)

	var north_face := Rect2(footprint.position.x, footprint.position.y, footprint.size.x, maxf(8.0, footprint.size.y * 0.18))
	_add_polygon(parent, "NorthFacade", _rect_points(north_face), plaster.lightened(0.08), 0, ink, outline)

	var timber_count := maxi(2, int(footprint.size.x / 42.0))
	for index in timber_count:
		var x := facade.position.x + float(index + 1) * facade.size.x / float(timber_count + 1)
		_add_polygon(parent, "Timber%d" % index, _rect_points(Rect2(x - 2.5, facade.position.y, 5.0, facade.size.y)), timber, 3)
	_add_polygon(parent, "CrossBeam", _rect_points(Rect2(facade.position.x, facade.position.y + facade.size.y * 0.42, facade.size.x, 4.0)), timber, 3)

	var door_width := clampf(footprint.size.x * 0.16, 15.0, 24.0)
	var door := Rect2(facade.get_center().x - door_width * 0.5, facade.end.y - 25.0, door_width, 25.0)
	_add_polygon(parent, "Doorway", _rect_points(door), timber.darkened(0.26), 4, ink, outline)

	var window := MapVisualStyle.role_color(&"window", target, time_of_day)
	for window_index in 2:
		var side := -1.0 if window_index == 0 else 1.0
		var window_rect := Rect2(facade.get_center().x + side * footprint.size.x * 0.27 - 6.0, facade.position.y + 6.0, 12.0, 10.0)
		_add_polygon(parent, "Window%d" % window_index, _rect_points(window_rect), window, 4, ink, outline)

	var roof_base := Rect2(footprint.position.x - 9.0, footprint.position.y - wall_height * 0.44, footprint.size.x + 18.0, footprint.size.y * 0.58)
	_add_polygon(parent, "GabledRoof", _gabled_roof_points(roof_base), roof, 5, ink, outline)
	_add_polygon(parent, "RoofLitPlane", _roof_lit_points(roof_base), roof.lightened(0.10), 6)

	if target == MapVisualStyle.TARGET_WOODCUT:
		_add_hatching(parent, roof_base, ink, 7)
	elif target == MapVisualStyle.TARGET_PIXEL:
		for index in mini(8, int(roof_base.size.x / 18.0)):
			_add_polygon(parent, "RoofTile%d" % index, _rect_points(Rect2(roof_base.position.x + 8.0 + index * 18.0, roof_base.end.y - 8.0, 9.0, 4.0)), roof.lightened(0.13), 7)
	else:
		var wash := Color(plaster.lightened(0.16), 0.24)
		_add_polygon(parent, "PaintedWash", _rect_points(Rect2(facade.position + Vector2(5, 5), facade.size - Vector2(10, 10))), wash, 2)

	# Stable detail variation is visual-only and cannot move the footprint or pivot.
	if abs(building_id.hash()) % 2 == 0:
		_add_polygon(parent, "ForgeSign", _rect_points(Rect2(door.end.x + 5.0, facade.position.y + 7.0, 8.0, 8.0)), MapVisualStyle.role_color(&"metal", target, time_of_day), 7, ink, outline)


static func create_interior_window(
	landmark: Dictionary,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Node2D:
	var rect: Rect2 = landmark["rect"]
	var root := Node2D.new()
	root.name = "Landmark_%s" % String(landmark["id"])
	root.position = rect.get_center()
	root.set_meta("y_sort_anchor", rect.get_center())

	var ink := MapVisualStyle.role_color(&"ink", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var window := MapVisualStyle.role_color(&"window", target, time_of_day)
	var outline := MapVisualStyle.outline_width(target)
	var local := Rect2(-rect.size * 0.5, rect.size)
	_add_polygon(root, "Frame", _rect_points(local.grow(-2.0)), timber, 0, ink, outline)
	_add_polygon(root, "Glass", _rect_points(local.grow(-5.0)), window, 1, ink, outline * 0.5)
	return root


static func _draw_interior_block(
	parent: Node2D,
	footprint: Rect2,
	wall_height: float,
	target: StringName,
	time_of_day: StringName
) -> void:
	var ink := MapVisualStyle.role_color(&"ink", target, time_of_day)
	var timber := MapVisualStyle.role_color(&"timber", target, time_of_day)
	var plaster := MapVisualStyle.role_color(&"plaster", target, time_of_day)
	var outline := MapVisualStyle.outline_width(target)
	var shadow_rect := footprint
	shadow_rect.position += MapVisualStyle.shadow_offset(target)
	_add_polygon(parent, "GroundShadow", _rect_points(shadow_rect), Color(ink, MapVisualStyle.shadow_alpha(target, time_of_day)), -3)
	_add_polygon(parent, "BlockMass", _rect_points(footprint), timber.darkened(0.12), 0, ink, outline)
	var face := Rect2(footprint.position.x, footprint.end.y - minf(footprint.size.y * 0.55, wall_height * 0.35), footprint.size.x, minf(footprint.size.y * 0.55, wall_height * 0.35))
	_add_polygon(parent, "BlockFace", _rect_points(face), plaster.darkened(0.08), 1, ink, outline)


static func _draw_wall(parent: Node2D, footprint: Rect2, wall_height: float, target: StringName, time_of_day: StringName) -> void:
	var ink := MapVisualStyle.role_color(&"ink", target, time_of_day)
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var outline := MapVisualStyle.outline_width(target)
	var shadow_rect := footprint
	shadow_rect.position += MapVisualStyle.shadow_offset(target)
	_add_polygon(parent, "GroundShadow", _rect_points(shadow_rect), Color(ink, MapVisualStyle.shadow_alpha(target, time_of_day)), -3)
	_add_polygon(parent, "WallMass", _rect_points(footprint), stone.darkened(0.18), -1, ink, outline)
	var face_height := maxf(10.0, minf(footprint.size.y * 0.65, wall_height * 0.45))
	var face := Rect2(footprint.position.x, footprint.end.y - face_height, footprint.size.x, face_height)
	_add_polygon(parent, "SouthFace", _rect_points(face), stone, 1, ink, outline)
	var coping := Rect2(footprint.position.x - 2.0, footprint.position.y - 6.0, footprint.size.x + 4.0, 7.0)
	_add_polygon(parent, "Coping", _rect_points(coping), stone.lightened(0.13), 2, ink, outline)
	if target == MapVisualStyle.TARGET_WOODCUT:
		_add_hatching(parent, face, ink, 3)


static func _add_hatching(parent: Node, rect: Rect2, color: Color, layer: int) -> void:
	for index in maxi(1, int(rect.size.x / 18.0)):
		var x := rect.position.x + 7.0 + float(index) * 18.0
		var line := Line2D.new()
		line.name = "Hatch%d" % index
		line.points = PackedVector2Array([Vector2(x, rect.end.y - 4.0), Vector2(x + 10.0, rect.position.y + 5.0)])
		line.width = 1.0
		line.default_color = Color(color, 0.48)
		line.z_index = layer
		parent.add_child(line)


static func _add_polygon(
	parent: Node,
	node_name: String,
	points: PackedVector2Array,
	color: Color,
	layer: int,
	outline_color: Color = Color.TRANSPARENT,
	outline_width: float = 0.0
) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.z_index = layer
	parent.add_child(polygon)
	if outline_width > 0.0:
		var line := Line2D.new()
		line.name = "%sOutline" % node_name
		line.points = points
		line.closed = true
		line.width = outline_width
		line.default_color = outline_color
		line.z_index = layer + 1
		parent.add_child(line)


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _gabled_roof_points(rect: Rect2) -> PackedVector2Array:
	var peak := Vector2(rect.get_center().x, rect.position.y - rect.size.y * 0.42)
	return PackedVector2Array([Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.28), peak, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.28)])


static func _roof_lit_points(rect: Rect2) -> PackedVector2Array:
	var peak := Vector2(rect.get_center().x, rect.position.y - rect.size.y * 0.42)
	return PackedVector2Array([Vector2(rect.position.x, rect.end.y), peak, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.28)])
