class_name MapPropRenderer
extends RefCounted

## Simple procedural props for map prototype scenes.


static func create_prop(prop: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = prop["position"]
	root.set_meta("y_sort_anchor", prop["position"])

	var kind: StringName = prop["kind"]
	match kind:
		MapTypes.PROP_KIND_ANVIL:
			_draw_anvil(root)
		MapTypes.PROP_KIND_HAY_STACK:
			_draw_hay_stack(root)
		MapTypes.PROP_KIND_CART:
			_draw_cart(root)
		MapTypes.PROP_KIND_WELL:
			_draw_well(root)
		MapTypes.PROP_KIND_BARRELS:
			_draw_barrels(root)
		_:
			_draw_marker(root, Color.MAGENTA)

	return root


static func _draw_anvil(parent: Node2D) -> void:
	_add_rect(parent, "Base", Vector2(-18, -8), Vector2(36, 16), Color(0.20, 0.20, 0.22))
	_add_rect(parent, "Body", Vector2(-14, -20), Vector2(28, 14), Color(0.28, 0.28, 0.30))
	_add_rect(parent, "Face", Vector2(-8, -28), Vector2(16, 10), Color(0.34, 0.34, 0.36))


static func _draw_hay_stack(parent: Node2D) -> void:
	for index in 3:
		var offset := float(index) * 6.0
		_add_rect(
			parent,
			"Hay%d" % index,
			Vector2(-20.0 + offset, -18.0 - offset),
			Vector2(40.0, 14.0),
			Color(0.82, 0.72, 0.28).darkened(index * 0.05)
		)


static func _draw_cart(parent: Node2D) -> void:
	_add_rect(parent, "Bed", Vector2(-28, -16), Vector2(56, 20), Color(0.42, 0.30, 0.18))
	_add_rect(parent, "WheelL", Vector2(-24, 2), Vector2(12, 12), Color(0.24, 0.18, 0.12))
	_add_rect(parent, "WheelR", Vector2(12, 2), Vector2(12, 12), Color(0.24, 0.18, 0.12))


static func _draw_well(parent: Node2D) -> void:
	_add_circle(parent, "Rim", Vector2(0.0, -10.0), 22.0, Color(0.46, 0.48, 0.52))
	_add_circle(parent, "Water", Vector2(0.0, -10.0), 14.0, Color(0.22, 0.38, 0.62))
	_add_rect(parent, "Curb", Vector2(-24.0, -4.0), Vector2(48.0, 8.0), Color(0.40, 0.42, 0.46))


static func _draw_barrels(parent: Node2D) -> void:
	_add_rect(parent, "BarrelA", Vector2(-22, -18), Vector2(18, 24), Color(0.36, 0.24, 0.14))
	_add_rect(parent, "BarrelB", Vector2(4, -16), Vector2(18, 22), Color(0.40, 0.28, 0.16))


static func _draw_marker(parent: Node2D, color: Color) -> void:
	_add_rect(parent, "Marker", Vector2(-8, -8), Vector2(16, 16), color)


static func _add_rect(parent: Node, node_name: String, position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = position
	rect.size = size
	rect.color = color
	parent.add_child(rect)


static func _add_circle(parent: Node, node_name: String, center: Vector2, radius: float, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	var points := PackedVector2Array()
	for step in 16:
		var angle := float(step) / 16.0 * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
