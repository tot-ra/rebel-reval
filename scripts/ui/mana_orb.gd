class_name ManaOrb
extends Control

## Blue resource sphere that drains as magic is spent. Pure drawing, no text of its own.

const SEGMENTS := 40
const GLASS_COLOR := Color(0.03, 0.05, 0.1, 0.82)
const LIQUID_COLOR := Color(0.22, 0.5, 0.95, 0.95)
const SURFACE_COLOR := Color(0.55, 0.78, 1.0, 0.9)
const RIM_COLOR := Color(0.57, 0.45, 0.27, 0.9)

var _value := 0
var _maximum := 1


func _init() -> void:
	custom_minimum_size = Vector2(76.0, 76.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(value: int, maximum: int) -> void:
	_maximum = maxi(1, maximum)
	_value = clampi(value, 0, _maximum)
	queue_redraw()


func fill_ratio() -> float:
	return float(_value) / float(_maximum)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(center, radius, GLASS_COLOR)
	var ratio := fill_ratio()
	if ratio > 0.0:
		# WHY: clip the liquid to the sphere by sampling the circle only below the fill line.
		var level_y := center.y + radius - ratio * radius * 2.0
		var points := PackedVector2Array()
		for i in SEGMENTS + 1:
			var angle := TAU * float(i) / float(SEGMENTS)
			var point := center + Vector2(cos(angle), sin(angle)) * radius
			points.append(Vector2(point.x, maxf(point.y, level_y)))
		var hull := Geometry2D.convex_hull(points)
		if hull.size() >= 3:
			draw_colored_polygon(hull, LIQUID_COLOR)
		var half_width := sqrt(maxf(0.0, radius * radius - (level_y - center.y) ** 2))
		draw_line(
			Vector2(center.x - half_width, level_y), Vector2(center.x + half_width, level_y),
			SURFACE_COLOR, 2.0
		)
	draw_arc(center, radius, 0.0, TAU, 48, RIM_COLOR, 2.0, true)
	draw_arc(center, radius - 5.0, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.25), 2.0, true)
