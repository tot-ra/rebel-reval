@tool
class_name MapAlignmentCanvas
extends Control

## Lightweight semantic renderer for aligning two compiled maps. It intentionally
## draws from MapDefinition rather than exposing generated runtime nodes as source.

signal view_changed

const MARGIN := 96.0
const MIN_ZOOM := 0.04
const MAX_ZOOM := 3.0
const GRID_MIN_SCREEN_PX := 10.0

var base_definition: MapDefinition
var neighbor_definition: MapDefinition
var _base_grid: MapTerrainGrid
var _neighbor_grid: MapTerrainGrid
var base_transition: Dictionary = {}
var neighbor_transition: Dictionary = {}
var neighbor_offset_px := Vector2.ZERO
var neighbor_opacity := 0.55
var show_grid := true
var show_ids := false
var show_features := true

var _zoom := 0.12
var _pan := Vector2.ZERO
var _dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process_unhandled_input(true)


func configure(base: MapDefinition, neighbor: MapDefinition) -> void:
	base_definition = base
	neighbor_definition = neighbor
	_base_grid = MapBuilder.build(base) if base != null else null
	_neighbor_grid = MapBuilder.build(neighbor) if neighbor != null else null
	queue_redraw()


func fit_to_maps() -> void:
	if base_definition == null:
		return
	var bounds := Rect2(Vector2.ZERO, base_definition.world_size())
	if neighbor_definition != null:
		bounds = bounds.merge(Rect2(neighbor_offset_px, neighbor_definition.world_size()))
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var available := Vector2(maxf(size.x - MARGIN * 2.0, 1.0), maxf(size.y - MARGIN * 2.0, 1.0))
	_zoom = clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y), MIN_ZOOM, MAX_ZOOM)
	_pan = size * 0.5 - bounds.get_center() * _zoom
	queue_redraw()
	view_changed.emit()


func nudge_neighbor(cell_delta: Vector2i) -> void:
	if neighbor_definition == null:
		return
	neighbor_offset_px += Vector2(cell_delta) * float(neighbor_definition.cell_size)
	queue_redraw()
	view_changed.emit()


func set_neighbor_offset(offset_px: Vector2) -> void:
	neighbor_offset_px = offset_px
	queue_redraw()
	view_changed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / 1.12)
			accept_event()
		elif button.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT]:
			_dragging = button.pressed
			_last_mouse = button.position
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_pan += motion.position - _last_mouse
		_last_mouse = motion.position
		queue_redraw()
		view_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or neighbor_definition == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var delta := Vector2i.ZERO
		match key.keycode:
			KEY_LEFT: delta = Vector2i.LEFT
			KEY_RIGHT: delta = Vector2i.RIGHT
			KEY_UP: delta = Vector2i.UP
			KEY_DOWN: delta = Vector2i.DOWN
		if delta != Vector2i.ZERO:
			if key.shift_pressed:
				delta *= 10
			nudge_neighbor(delta)
			get_viewport().set_input_as_handled()


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var world_point := (screen_point - _pan) / _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_pan = screen_point - world_point * _zoom
	queue_redraw()
	view_changed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(26, 28, 32), true)
	if base_definition == null:
		_draw_center_message("Select two .rrmap files and click Load maps")
		return
	_draw_map(base_definition, _base_grid, Vector2.ZERO, 1.0, Color(1.0, 0.78, 0.28))
	if neighbor_definition != null:
		# Draw the neighbor last so opacity/blink works like a conventional image
		# overlay even when the maps overlap rather than merely touch at a seam.
		_draw_map(neighbor_definition, _neighbor_grid, neighbor_offset_px, neighbor_opacity, Color(0.35, 0.78, 1.0))
	if show_grid:
		_draw_grid()
	_draw_seam_markers()


func _draw_map(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	offset: Vector2,
	opacity: float,
	accent: Color
) -> void:
	if grid == null:
		return
	var world_rect := _screen_rect(Rect2(offset, definition.world_size()))
	draw_rect(world_rect, Color(0.05, 0.05, 0.06, opacity), true)
	var cell_px := float(definition.cell_size)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain := grid.get_terrain(cell)
			var rect := Rect2(offset + Vector2(cell) * cell_px, Vector2.ONE * cell_px)
			draw_rect(_screen_rect(rect), Color(OutdoorTerrainPalette.color(terrain), opacity), true)
	if show_features:
		for building in definition.buildings:
			var primitive := StringName(building.get("primitive", &"house"))
			var fill := Color8(150, 137, 119) if primitive not in [&"wall", &"palisade"] else Color8(86, 82, 79)
			var rect: Rect2 = building["footprint"]
			var screen_rect := _screen_rect(Rect2(rect.position + offset, rect.size))
			draw_rect(screen_rect, Color(fill, opacity * 0.88), true)
			draw_rect(screen_rect, Color(accent, opacity), false, maxf(1.0, _zoom * 2.0))
			if show_ids:
				_draw_id(String(building["id"]), screen_rect.get_center(), accent, opacity)
		for transition in definition.transitions:
			var rect: Rect2 = transition["rect"]
			var screen_rect := _screen_rect(Rect2(rect.position + offset, rect.size))
			draw_rect(screen_rect, Color(1.0, 0.2, 0.2, opacity * 0.38), true)
			draw_rect(screen_rect, Color(1.0, 0.25, 0.2, opacity), false, 3.0)
			if show_ids:
				_draw_id(String(transition["id"]), screen_rect.get_center(), Color(1.0, 0.38, 0.3), opacity)
	draw_rect(world_rect, Color(accent, opacity), false, 3.0)
	_draw_id(String(definition.map_id), world_rect.position + Vector2(8.0, 20.0), accent, opacity, false)


func _draw_grid() -> void:
	var cell_size := float(base_definition.cell_size)
	if cell_size * _zoom < GRID_MIN_SCREEN_PX:
		return
	var visible_world := Rect2(-_pan / _zoom, size / _zoom)
	var start_x := floorf(visible_world.position.x / cell_size) * cell_size
	var start_y := floorf(visible_world.position.y / cell_size) * cell_size
	var x := start_x
	while x <= visible_world.end.x:
		draw_line(_screen(Vector2(x, visible_world.position.y)), _screen(Vector2(x, visible_world.end.y)), Color(1, 1, 1, 0.13), 1.0)
		x += cell_size
	var y := start_y
	while y <= visible_world.end.y:
		draw_line(_screen(Vector2(visible_world.position.x, y)), _screen(Vector2(visible_world.end.x, y)), Color(1, 1, 1, 0.13), 1.0)
		y += cell_size


func _draw_seam_markers() -> void:
	if base_transition.is_empty() or neighbor_transition.is_empty():
		return
	var base_rect: Rect2 = base_transition["rect"]
	var neighbor_rect: Rect2 = neighbor_transition["rect"]
	var base_center := _screen(base_rect.get_center())
	var neighbor_center := _screen(neighbor_rect.get_center() + neighbor_offset_px)
	draw_line(base_center, neighbor_center, Color(1.0, 0.95, 0.2), 4.0)
	draw_circle(base_center, 7.0, Color(1.0, 0.78, 0.28))
	draw_circle(neighbor_center, 7.0, Color(0.35, 0.78, 1.0))


func _draw_id(text: String, position: Vector2, color: Color, opacity: float, centered := true) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin := position - Vector2(text_size.x * 0.5, -font_size * 0.35) if centered else position
	draw_rect(Rect2(origin - Vector2(3.0, float(font_size)), text_size + Vector2(6.0, 5.0)), Color(0.02, 0.02, 0.025, opacity * 0.8), true)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, opacity))


func _draw_center_message(message: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 18
	var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, size * 0.5 - Vector2(text_size.x * 0.5, 0.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color8(190, 194, 201))


func _screen(world: Vector2) -> Vector2:
	return world * _zoom + _pan


func _screen_rect(world_rect: Rect2) -> Rect2:
	return Rect2(_screen(world_rect.position), world_rect.size * _zoom)
