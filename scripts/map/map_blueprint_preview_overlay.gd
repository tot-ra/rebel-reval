@tool
class_name MapBlueprintPreviewOverlay
extends Node2D

## Editor-only semantic overlays drawn over the disposable 2D map preview.

const ANCHOR_COLOR := Color(0.15, 0.95, 0.85, 0.95)
const LANDMARK_COLOR := Color(0.9, 0.38, 1.0, 0.9)
const ID_COLOR := Color(1.0, 0.92, 0.35, 0.95)
const NAVIGATION_COLOR := Color(0.25, 0.75, 1.0, 0.22)
const NAVIGATION_EDGE_COLOR := Color(0.25, 0.75, 1.0, 0.75)
const CHUNK_PLACEHOLDER_COLOR := Color(1.0, 0.55, 0.18, 0.8)
const CHUNK_PLACEHOLDER_CELLS := 16

var show_stable_ids := false
var show_anchors := true
var show_navigation := false
var show_chunk_bounds := false

var _definition: MapDefinition
var _grid: MapTerrainGrid
var _navigation_outlines: Array[PackedVector2Array] = []


func configure(definition: MapDefinition, grid: MapTerrainGrid) -> void:
	_definition = definition
	_grid = grid
	_navigation_outlines.clear()
	queue_redraw()


func _draw() -> void:
	if _definition == null or _grid == null:
		return
	if show_navigation:
		_draw_navigation()
	_draw_landmarks()
	if show_anchors:
		_draw_anchors()
	if show_stable_ids:
		_draw_stable_ids()
	if show_chunk_bounds:
		_draw_chunk_bounds_placeholder()


func _draw_landmarks() -> void:
	for landmark in _definition.view_landmarks:
		var rect: Rect2 = landmark["rect"]
		draw_rect(rect, Color(LANDMARK_COLOR, 0.12), true)
		draw_rect(rect, LANDMARK_COLOR, false, 3.0)


func _draw_anchors() -> void:
	for anchor in _definition.interaction_anchors:
		var point: Vector2 = anchor["position"]
		draw_circle(point, 7.0, Color(ANCHOR_COLOR, 0.24))
		draw_arc(point, 7.0, 0.0, TAU, 24, ANCHOR_COLOR, 2.0)
		draw_line(point - Vector2(10.0, 0.0), point + Vector2(10.0, 0.0), ANCHOR_COLOR, 1.5)
		draw_line(point - Vector2(0.0, 10.0), point + Vector2(0.0, 10.0), ANCHOR_COLOR, 1.5)


func _draw_stable_ids() -> void:
	for building in _definition.buildings:
		_draw_label(building["footprint"].get_center(), String(building["id"]), ID_COLOR)
	for prop in _definition.props:
		_draw_label(prop["position"], String(prop["id"]), ID_COLOR)
	for landmark in _definition.view_landmarks:
		_draw_label(landmark["rect"].get_center(), String(landmark["id"]), LANDMARK_COLOR)
	for anchor in _definition.interaction_anchors:
		_draw_label(anchor["position"] + Vector2(0.0, -12.0), String(anchor["id"]), ANCHOR_COLOR)
	for transition in _definition.transitions:
		_draw_label(transition["rect"].get_center(), String(transition["id"]), Color(1.0, 0.45, 0.25))


func _draw_navigation() -> void:
	if _navigation_outlines.is_empty():
		_build_navigation_outlines()
	for outline in _navigation_outlines:
		if outline.size() < 3:
			continue
		draw_colored_polygon(outline, NAVIGATION_COLOR)
		var closed := PackedVector2Array(outline)
		closed.append(outline[0])
		draw_polyline(closed, NAVIGATION_EDGE_COLOR, 2.0)


func _build_navigation_outlines() -> void:
	_navigation_outlines.clear()
	# Use the same MapNavBuilder as runtime, but draw only its baked polygon data.
	# The temporary region never enters the scene tree or NavigationServer.
	var region := MapNavBuilder.create_navigation_region(_definition, _grid)
	var polygon := region.navigation_polygon
	if polygon != null:
		for index in polygon.get_polygon_count():
			var indices := polygon.get_polygon(index)
			var vertices := polygon.vertices
			var outline := PackedVector2Array()
			for vertex_index in indices:
				outline.append(vertices[vertex_index])
			_navigation_outlines.append(outline)
	region.free()


func _draw_chunk_bounds_placeholder() -> void:
	# Chunking is intentionally not authored yet. This fixed grid is a visual
	# planning aid only and must not imply runtime streaming boundaries.
	var chunk_px := float(_definition.cell_size * CHUNK_PLACEHOLDER_CELLS)
	var world_size := _definition.world_size()
	var x := 0.0
	while x <= world_size.x:
		draw_dashed_line(Vector2(x, 0.0), Vector2(x, world_size.y), CHUNK_PLACEHOLDER_COLOR, 2.0, 12.0)
		x += chunk_px
	var y := 0.0
	while y <= world_size.y:
		draw_dashed_line(Vector2(0.0, y), Vector2(world_size.x, y), CHUNK_PLACEHOLDER_COLOR, 2.0, 12.0)
		y += chunk_px
	_draw_label(Vector2(8.0, 20.0), "CHUNK BOUNDS PLACEHOLDER (%dx%d cells)" % [CHUNK_PLACEHOLDER_CELLS, CHUNK_PLACEHOLDER_CELLS], CHUNK_PLACEHOLDER_COLOR)


func _draw_label(position: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin := position + Vector2(-size.x * 0.5, -4.0)
	draw_rect(Rect2(origin - Vector2(3.0, float(font_size)), size + Vector2(6.0, 5.0)), Color(0.03, 0.03, 0.04, 0.82), true)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
