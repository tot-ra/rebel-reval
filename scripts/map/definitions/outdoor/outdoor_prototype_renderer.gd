class_name OutdoorPrototypeRenderer
extends Node2D

## Deterministic clean-painted inspection renderer for every outdoor prototype.
## It consumes MapDefinition metadata only; no location owns bespoke draw code.

var definition: MapDefinition
var grid: MapTerrainGrid


func configure(map_definition: MapDefinition, terrain_grid: MapTerrainGrid) -> void:
	definition = map_definition
	grid = terrain_grid
	queue_redraw()


func _draw() -> void:
	if definition == null or grid == null:
		return
	_draw_terrain()
	for building in definition.buildings:
		_draw_structure(building)
	for prop in definition.props:
		_draw_prop(prop)
	_draw_route()
	_draw_spawn()


func _draw_terrain() -> void:
	var cell_size := float(grid.cell_size)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain: StringName = grid.get_terrain(cell)
			var rect := Rect2(Vector2(cell) * cell_size, Vector2.ONE * cell_size)
			var color := OutdoorTerrainPalette.color(terrain)
			var hash := TerrainPalette.cell_hash(cell, grid.seed, terrain)
			draw_rect(rect, color.darkened(0.035) if hash % 5 == 0 else color)
			if terrain in [MapTypes.TERRAIN_SHALLOW_WATER, MapTypes.TERRAIN_DEEP_WATER] and hash % 3 == 0:
				draw_line(rect.position + Vector2(5, 12), rect.position + Vector2(27, 12), color.lightened(0.16), 1.0)


func _draw_structure(building: Dictionary) -> void:
	var rect: Rect2 = building["footprint"]
	var primitive: StringName = building.get("primitive", &"house")
	var fill := _structure_color(primitive)
	var ink := Color8(43, 38, 36)
	var wall_like := primitive in [&"wall", &"palisade", &"pier", &"bridge", &"ditch_edge", &"tree_line"]
	draw_rect(rect, fill.darkened(0.15), true)
	draw_rect(rect, ink, false, 2.0)
	if not wall_like:
		var roof := PackedVector2Array([
			rect.position + Vector2(-4, 5),
			Vector2(rect.get_center().x, rect.position.y - minf(28.0, rect.size.y * 0.45)),
			Vector2(rect.end.x + 4, rect.position.y + 5),
			Vector2(rect.end.x, rect.end.y - rect.size.y * 0.42),
			Vector2(rect.position.x, rect.end.y - rect.size.y * 0.42),
		])
		draw_colored_polygon(roof, fill.lightened(0.08))
		draw_polyline(PackedVector2Array(Array(roof) + [roof[0]]), ink, 2.0)
	if primitive in [&"gatehouse", &"stone_keep", &"coastal_bishop_castle", &"limestone_tower"]:
		var door := Rect2(rect.get_center() + Vector2(-10, 2), Vector2(20, rect.end.y - rect.get_center().y - 2))
		draw_rect(door, ink, true)


func _draw_prop(prop: Dictionary) -> void:
	var point: Vector2 = prop["position"]
	var primitive: StringName = prop.get("primitive", prop.get("kind", &"marker"))
	var ink := Color8(43, 38, 36)
	match primitive:
		&"ancient_tree":
			# Landmark hingepuu: thicker trunk and broader crown than roadside oaks.
			draw_rect(Rect2(point + Vector2(-10, -72), Vector2(20, 72)), Color8(72, 48, 34))
			draw_circle(point + Vector2(-18, -58), 22.0, Color8(58, 92, 52))
			draw_circle(point + Vector2(16, -62), 24.0, Color8(66, 102, 56))
			draw_circle(point + Vector2(0, -78), 28.0, Color8(62, 98, 54))
		&"tree":
			draw_rect(Rect2(point + Vector2(-4, -28), Vector2(8, 28)), Color8(83, 55, 42))
			draw_circle(point + Vector2(0, -35), 18.0, Color8(73, 103, 62))
		&"crane", &"ship_frame", &"standard", &"beacon":
			draw_line(point, point + Vector2(0, -38), ink, 4.0)
			draw_line(point + Vector2(0, -35), point + Vector2(18, -24), ink, 3.0)
		&"well", &"spring":
			draw_circle(point + Vector2(0, -8), 13.0, Color8(145, 145, 137))
			draw_circle(point + Vector2(0, -8), 8.0, Color8(83, 142, 160))
		&"offering_stone":
			draw_circle(point + Vector2(0, -7), 12.0, Color8(125, 128, 116))
		&"campfire", &"signal_fire":
			draw_circle(point + Vector2(0, -4), 10.0, Color8(173, 81, 42))
		&"fishing_boat", &"merchant_boat":
			var footprint: Rect2 = prop.get("footprint", Rect2(point - Vector2(16, 48), Vector2(32, 96)))
			var merchant_scale := 1.35 if primitive == &"merchant_boat" else 1.0
			var half_length := maxf(36.0, maxf(footprint.size.x, footprint.size.y) * 0.42) * merchant_scale
			var half_beam := maxf(12.0, minf(footprint.size.x, footprint.size.y) * 0.3) * merchant_scale
			var vertical := footprint.size.y > footprint.size.x
			var hull := PackedVector2Array([
				Vector2(-half_beam, -half_length),
				Vector2(half_beam, -half_length),
				Vector2(half_beam * 0.82, half_length * 0.55),
				Vector2(0, half_length),
				Vector2(-half_beam * 0.82, half_length * 0.55),
			])
			if not vertical:
				for index in hull.size():
					hull[index] = Vector2(hull[index].y, hull[index].x)
			for index in hull.size():
				hull[index] += point
			draw_colored_polygon(hull, Color8(119, 77, 45))
			draw_polyline(PackedVector2Array(Array(hull) + [hull[0]]), ink, 2.0)
		_:
			draw_rect(Rect2(point + Vector2(-12, -15), Vector2(24, 15)), Color8(119, 77, 45))
	draw_circle(point, 2.0, ink)


func _draw_route() -> void:
	if definition.patrols.is_empty():
		return
	var points: Array = definition.patrols[0].get("points", [])
	if points.size() > 1:
		draw_polyline(PackedVector2Array(points), Color(0.87, 0.75, 0.35, 0.72), 3.0)


func _draw_spawn() -> void:
	draw_circle(definition.player_spawn, 8.0, Color8(178, 61, 49))
	draw_circle(definition.player_spawn, 8.0, Color8(43, 38, 36), false, 2.0)


func _structure_color(primitive: StringName) -> Color:
	if primitive in [&"wall", &"gatehouse", &"stone_keep", &"stone_hall", &"stone_church", &"monastic_range"]:
		return Color8(145, 145, 137)
	if primitive in [&"palisade", &"pier", &"warehouse", &"barn", &"farmhouse", &"timber_hall", &"work_shed", &"camp"]:
		return Color8(119, 77, 45)
	if primitive == &"tree_line":
		return Color8(64, 91, 55)
	return Color8(180, 155, 116)
