class_name MapPropRenderer
extends RefCounted

## Style-profiled props. Every prop keeps the shared definition anchor as its Y-sort pivot.


static func create_prop(
	prop: Dictionary,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Node2D:
	var root := Node2D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = prop["position"]
	root.set_meta("y_sort_anchor", prop["position"])
	root.set_meta("visual_target", target)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.polygon = _ellipse(Vector2(0, 2) + MapVisualStyle.shadow_offset(target) * 0.35, Vector2(26, 9), 16)
	shadow.color = Color(MapVisualStyle.role_color(&"ink", target, time_of_day), MapVisualStyle.shadow_alpha(target, time_of_day))
	shadow.z_index = -2
	root.add_child(shadow)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL: _draw_anvil(root, target, time_of_day)
		MapTypes.PROP_KIND_HAY_STACK: _draw_hay_stack(root, target, time_of_day)
		MapTypes.PROP_KIND_CART: _draw_cart(root, target, time_of_day)
		MapTypes.PROP_KIND_WELL: _draw_well(root, target, time_of_day)
		MapTypes.PROP_KIND_BARRELS: _draw_barrels(root, target, time_of_day)
		_: _add_rect(root, "Marker", Vector2(-8, -8), Vector2(16, 16), Color.MAGENTA, target, time_of_day)
	return root


static func _draw_anvil(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var metal := MapVisualStyle.role_color(&"metal", target, time_of_day)
	_add_rect(parent, "Base", Vector2(-16, -7), Vector2(32, 11), metal.darkened(0.18), target, time_of_day)
	_add_polygon(parent, "AnvilBody", PackedVector2Array([Vector2(-12, -20), Vector2(13, -20), Vector2(18, -14), Vector2(7, -9), Vector2(-10, -9)]), metal, target, time_of_day)
	_add_rect(parent, "Face", Vector2(-17, -25), Vector2(35, 7), metal.lightened(0.16), target, time_of_day)


static func _draw_hay_stack(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var hay := MapVisualStyle.role_color(&"hay", target, time_of_day)
	for index in 3:
		var offset := float(index) * 6.0
		_add_rect(parent, "Bale%d" % index, Vector2(-21 + offset, -15 - offset), Vector2(42, 13), hay.darkened(index * 0.05), target, time_of_day)
		if target == MapVisualStyle.TARGET_WOODCUT:
			_add_line(parent, "Straw%d" % index, PackedVector2Array([Vector2(-17 + offset, -10 - offset), Vector2(16 + offset, -15 - offset)]), target, time_of_day)


static func _draw_cart(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "Bed", Vector2(-29, -18), Vector2(58, 19), wood, target, time_of_day)
	_add_circle(parent, "WheelL", Vector2(-20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	_add_circle(parent, "WheelR", Vector2(20, 4), 9.0, wood.darkened(0.28), target, time_of_day)
	_add_rect(parent, "Shaft", Vector2(26, -6), Vector2(25, 4), wood.darkened(0.12), target, time_of_day)


static func _draw_well(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var stone := MapVisualStyle.role_color(&"stone", target, time_of_day)
	var water := MapVisualStyle.terrain_color(MapTypes.TERRAIN_WATER, target, time_of_day)
	_add_circle(parent, "Rim", Vector2(0, -9), 23.0, stone, target, time_of_day)
	_add_circle(parent, "Water", Vector2(0, -10), 14.0, water, target, time_of_day)
	_add_rect(parent, "Curb", Vector2(-24, -4), Vector2(48, 8), stone.darkened(0.10), target, time_of_day)
	_add_line(parent, "WaterGlint", PackedVector2Array([Vector2(-8, -12), Vector2(8, -12)]), target, time_of_day, &"water_highlight")


static func _draw_barrels(parent: Node2D, target: StringName, time_of_day: StringName) -> void:
	var wood := MapVisualStyle.role_color(&"wood", target, time_of_day)
	_add_rect(parent, "BarrelA", Vector2(-22, -19), Vector2(18, 25), wood.darkened(0.08), target, time_of_day)
	_add_rect(parent, "BarrelB", Vector2(4, -17), Vector2(18, 23), wood, target, time_of_day)
	_add_rect(parent, "BandA", Vector2(-22, -8), Vector2(18, 3), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)
	_add_rect(parent, "BandB", Vector2(4, -7), Vector2(18, 3), MapVisualStyle.role_color(&"metal", target, time_of_day), target, time_of_day)


static func _add_rect(parent: Node, node_name: String, position: Vector2, size: Vector2, color: Color, target: StringName, time_of_day: StringName) -> void:
	_add_polygon(parent, node_name, PackedVector2Array([position, position + Vector2(size.x, 0), position + size, position + Vector2(0, size.y)]), color, target, time_of_day)


static func _add_circle(parent: Node, node_name: String, center: Vector2, radius: float, color: Color, target: StringName, time_of_day: StringName) -> void:
	_add_polygon(parent, node_name, _ellipse(center, Vector2(radius, radius), 16), color, target, time_of_day)


static func _add_polygon(parent: Node, node_name: String, points: PackedVector2Array, color: Color, target: StringName, time_of_day: StringName) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	var outline := Line2D.new()
	outline.name = "%sOutline" % node_name
	outline.points = points
	outline.closed = true
	outline.width = MapVisualStyle.outline_width(target)
	outline.default_color = MapVisualStyle.role_color(&"ink", target, time_of_day)
	outline.z_index = 1
	parent.add_child(outline)


static func _add_line(parent: Node, node_name: String, points: PackedVector2Array, target: StringName, time_of_day: StringName, role: StringName = &"ink") -> void:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = MapVisualStyle.outline_width(target)
	line.default_color = MapVisualStyle.role_color(role, target, time_of_day)
	line.z_index = 2
	parent.add_child(line)


static func _ellipse(center: Vector2, radii: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in steps:
		var angle := float(step) / float(steps) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
