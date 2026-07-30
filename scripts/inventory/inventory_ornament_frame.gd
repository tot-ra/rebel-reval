class_name InventoryOrnamentFrame
extends Control

## Vector-drawn brasswork for the satchel. Keeping the decoration procedural makes
## it scale cleanly with the overlay and avoids a fixed-resolution fantasy frame.

const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 80.0 or size.y < 80.0:
		return

	var brass := InventoryUiThemeScene.BRASS
	var bright := InventoryUiThemeScene.BRASS_BRIGHT
	var dark := InventoryUiThemeScene.PANEL_BORDER.darkened(0.34)
	_draw_chamfered_border(Rect2(Vector2(7, 7), size - Vector2(14, 14)), 18.0, dark, 5.0)
	_draw_chamfered_border(Rect2(Vector2(10, 10), size - Vector2(20, 20)), 15.0, brass, 1.5)
	_draw_chamfered_border(Rect2(Vector2(17, 17), size - Vector2(34, 34)), 10.0, Color(brass, 0.42), 1.0)

	_draw_corner_fitting(Vector2(13, 13), Vector2(1, 1), bright)
	_draw_corner_fitting(Vector2(size.x - 13, 13), Vector2(-1, 1), bright)
	_draw_corner_fitting(Vector2(13, size.y - 13), Vector2(1, -1), bright)
	_draw_corner_fitting(Vector2(size.x - 13, size.y - 13), Vector2(-1, -1), bright)

	_draw_medallion(Vector2(size.x * 0.5, 10), bright)
	_draw_side_clasp(Vector2(9, size.y * 0.5), 1.0, brass)
	_draw_side_clasp(Vector2(size.x - 9, size.y * 0.5), -1.0, brass)
	_draw_bottom_flourish(Vector2(size.x * 0.5, size.y - 10), brass)


func _draw_chamfered_border(rect: Rect2, cut: float, color: Color, width: float) -> void:
	var points := PackedVector2Array([
		Vector2(rect.position.x + cut, rect.position.y),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		Vector2(rect.end.x, rect.end.y - cut),
		Vector2(rect.end.x - cut, rect.end.y),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		Vector2(rect.position.x, rect.position.y + cut),
		Vector2(rect.position.x + cut, rect.position.y),
	])
	draw_polyline(points, color, width, true)


func _draw_corner_fitting(origin: Vector2, direction: Vector2, color: Color) -> void:
	var plate := PackedVector2Array([
		origin,
		origin + Vector2(31.0 * direction.x, 0),
		origin + Vector2(23.0 * direction.x, 7.0 * direction.y),
		origin + Vector2(12.0 * direction.x, 7.0 * direction.y),
		origin + Vector2(7.0 * direction.x, 12.0 * direction.y),
		origin + Vector2(7.0 * direction.x, 23.0 * direction.y),
		origin + Vector2(0, 31.0 * direction.y),
	])
	draw_colored_polygon(plate, Color(color, 0.24))
	var outline := PackedVector2Array(plate)
	outline.append(plate[0])
	draw_polyline(outline, Color(color, 0.82), 1.2, true)
	var rivet := origin + Vector2(8.5 * direction.x, 8.5 * direction.y)
	draw_circle(rivet, 2.2, color)
	draw_circle(rivet, 0.9, color.lightened(0.35))


func _draw_medallion(center: Vector2, color: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -7),
		center + Vector2(10, 0),
		center + Vector2(0, 7),
		center + Vector2(-10, 0),
	])
	draw_colored_polygon(diamond, InventoryUiThemeScene.PANEL_BG.lightened(0.08))
	var outline := PackedVector2Array(diamond)
	outline.append(diamond[0])
	draw_polyline(outline, color, 1.5, true)
	draw_circle(center, 2.2, color)
	draw_line(center + Vector2(-28, 0), center + Vector2(-11, 0), Color(color, 0.62), 1.2)
	draw_line(center + Vector2(11, 0), center + Vector2(28, 0), Color(color, 0.62), 1.2)


func _draw_side_clasp(center: Vector2, inward: float, color: Color) -> void:
	var diamond := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(6 * inward, 0),
		center + Vector2(0, 8),
		center + Vector2(-3 * inward, 0),
	])
	draw_colored_polygon(diamond, Color(color, 0.30))
	var outline := PackedVector2Array(diamond)
	outline.append(diamond[0])
	draw_polyline(outline, Color(color, 0.78), 1.1, true)


func _draw_bottom_flourish(center: Vector2, color: Color) -> void:
	var flourish := PackedVector2Array([
		center + Vector2(-34, 0),
		center + Vector2(-20, -4),
		center + Vector2(-9, 0),
		center + Vector2(0, -5),
		center + Vector2(9, 0),
		center + Vector2(20, -4),
		center + Vector2(34, 0),
	])
	draw_polyline(flourish, Color(color, 0.72), 1.3, true)
	draw_circle(center + Vector2(0, -5), 2.0, color)
