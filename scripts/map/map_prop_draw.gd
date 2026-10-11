class_name MapPropDraw
extends RefCounted

## Shared 2D primitive construction for map props.
## Keeping outlines in one place guarantees every specialised prop renderer
## preserves the same palette-derived edge treatment.


static func add_rect(
	parent: Node,
	node_name: String,
	position: Vector2,
	size: Vector2,
	color: Color,
	target: StringName,
	time_of_day: StringName
) -> void:
	add_polygon(
		parent,
		node_name,
		PackedVector2Array(
			[
				position,
				position + Vector2(size.x, 0),
				position + size,
				position + Vector2(0, size.y)
			]
		),
		color,
		target,
		time_of_day
	)


static func add_circle(
	parent: Node,
	node_name: String,
	center: Vector2,
	radius: float,
	color: Color,
	target: StringName,
	time_of_day: StringName
) -> void:
	add_polygon(
		parent, node_name, ellipse(center, Vector2(radius, radius), 16), color, target, time_of_day
	)


static func add_polygon(
	parent: Node,
	node_name: String,
	points: PackedVector2Array,
	color: Color,
	target: StringName,
	time_of_day: StringName
) -> void:
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


static func add_line(
	parent: Node,
	node_name: String,
	points: PackedVector2Array,
	target: StringName,
	time_of_day: StringName,
	role: StringName = &"ink"
) -> void:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = MapVisualStyle.outline_width(target)
	line.default_color = MapVisualStyle.role_color(role, target, time_of_day)
	line.z_index = 2
	parent.add_child(line)


static func ellipse(center: Vector2, radii: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in steps:
		var angle := float(step) / float(steps) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
