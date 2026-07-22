@tool
class_name MapAlignmentCanvas
extends Control

## Semantic multi-map renderer. Compiled definitions remain authoritative; this
## canvas only stores temporary editor offsets, visibility, opacity, and an
## optional reference background transform.

signal view_changed
signal selected_layer_changed(map_id: StringName)
signal background_changed

const MARGIN := 48.0
const MIN_ZOOM := 0.01
const MAX_ZOOM := 4.0
const MIN_BACKGROUND_SCALE := 0.01
const MAX_BACKGROUND_SCALE := 100.0
const GRID_MIN_SCREEN_PX := 10.0
const ACCENTS: Array[Color] = [
	Color("f5c451"), Color("55bce8"), Color("e879a9"), Color("79d279"),
	Color("bc8cff"), Color("ef8d52"), Color("55d6c2"), Color("d3d65a"),
]
const DISPLAY_NAMES: Dictionary = {
	&"lower_town_slice": "Workers' District",
	&"market_civic_quarter": "Central District",
	&"monastery_quarter": "Monastery District",
	&"archbishops_garden": "Archbishop's Garden",
	&"north_quarter": "Merchant District",
	&"south_quarter": "Knights District",
	&"toompea_quarter": "Toompea",
	&"viru_gate_foreland": "Pirita",
	&"reval_harbor_north": "Coastal Gate Landing",
	&"reval_harbor_east": "Kalamaja Fishing Shore",
}

var layers: Array[Dictionary] = []
var seams: Array[Dictionary] = []
var selected_map_id: StringName = &""
var show_grid := true
var show_ids := false
var show_features := true
var background_texture: Texture2D
var background_path := ""
var background_offset := Vector2.ZERO
var background_scale := 1.0
var background_opacity := 0.55
var background_visible := true
var edit_background := false

var _zoom := 0.12
var _pan := Vector2.ZERO
var _drag_mode := &""
var _last_mouse := Vector2.ZERO
var _fit_requested := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	set_process_unhandled_input(true)
	resized.connect(_on_resized)


func configure(map_definitions: Array[MapDefinition], offsets: Dictionary, map_seams: Array[Dictionary]) -> void:
	layers.clear()
	seams = map_seams
	for index in map_definitions.size():
		var definition := map_definitions[index]
		layers.append({
			"id": definition.map_id,
			"definition": definition,
			"terrain_texture": _build_terrain_texture(definition),
			"offset": Vector2(offsets.get(definition.map_id, Vector2.ZERO)),
			"visible": true,
			"opacity": 1.0,
			"accent": ACCENTS[index % ACCENTS.size()],
		})
	selected_map_id = layers[0]["id"] if not layers.is_empty() else &""
	request_fit()
	queue_redraw()


func clear() -> void:
	layers.clear()
	seams.clear()
	selected_map_id = &""
	queue_redraw()


func layer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for layer in layers:
		ids.append(layer["id"])
	return ids


func layer(map_id: StringName) -> Dictionary:
	for candidate in layers:
		if candidate["id"] == map_id:
			return candidate
	return {}


func select_layer(map_id: StringName) -> void:
	if layer(map_id).is_empty():
		return
	selected_map_id = map_id
	queue_redraw()
	selected_layer_changed.emit(map_id)
	view_changed.emit()


func set_layer_visible(map_id: StringName, visible: bool) -> void:
	var target := layer(map_id)
	if target.is_empty():
		return
	target["visible"] = visible
	queue_redraw()
	view_changed.emit()


func set_selected_opacity(opacity: float) -> void:
	var target := layer(selected_map_id)
	if target.is_empty():
		return
	target["opacity"] = clampf(opacity, 0.03, 1.0)
	queue_redraw()


func selected_opacity() -> float:
	var target := layer(selected_map_id)
	return float(target.get("opacity", 1.0))


func nudge_selected(cell_delta: Vector2i) -> void:
	var target := layer(selected_map_id)
	if target.is_empty():
		return
	var definition: MapDefinition = target["definition"]
	target["offset"] = Vector2(target["offset"]) + Vector2(cell_delta) * float(definition.cell_size)
	queue_redraw()
	view_changed.emit()


func selected_offset() -> Vector2:
	return Vector2(layer(selected_map_id).get("offset", Vector2.ZERO))


func set_background(texture: Texture2D, path: String) -> void:
	background_texture = texture
	background_path = path
	background_offset = Vector2.ZERO
	background_scale = 1.0
	background_visible = true
	queue_redraw()
	background_changed.emit()
	view_changed.emit()


func clear_background() -> void:
	background_texture = null
	background_path = ""
	background_offset = Vector2.ZERO
	background_scale = 1.0
	edit_background = false
	queue_redraw()
	background_changed.emit()
	view_changed.emit()


func has_background() -> bool:
	return background_texture != null


func set_background_visible(visible: bool) -> void:
	background_visible = visible
	queue_redraw()
	background_changed.emit()
	view_changed.emit()


func set_background_opacity(opacity: float) -> void:
	background_opacity = clampf(opacity, 0.0, 1.0)
	queue_redraw()
	background_changed.emit()


func set_background_scale(scale_value: float) -> void:
	background_scale = clampf(scale_value, MIN_BACKGROUND_SCALE, MAX_BACKGROUND_SCALE)
	queue_redraw()
	background_changed.emit()
	view_changed.emit()


func set_background_offset(offset: Vector2) -> void:
	background_offset = offset
	queue_redraw()
	background_changed.emit()
	view_changed.emit()


func nudge_background(delta: Vector2) -> void:
	if not has_background():
		return
	set_background_offset(background_offset + delta)


func background_world_rect() -> Rect2:
	if not has_background():
		return Rect2()
	return Rect2(background_offset, background_texture.get_size() * background_scale)


func request_fit() -> void:
	_fit_requested = true
	call_deferred("_apply_requested_fit")


func fit_to_maps() -> void:
	var bounds := visible_world_bounds()
	if not bounds.has_area() or size.x <= 1.0 or size.y <= 1.0:
		_fit_requested = true
		return
	var available := Vector2(maxf(size.x - MARGIN * 2.0, 1.0), maxf(size.y - MARGIN * 2.0, 1.0))
	_zoom = clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y), MIN_ZOOM, MAX_ZOOM)
	_pan = size * 0.5 - bounds.get_center() * _zoom
	_fit_requested = false
	queue_redraw()
	view_changed.emit()


func visible_world_bounds() -> Rect2:
	var result := Rect2()
	var has_bounds := false
	if has_background() and background_visible:
		result = background_world_rect()
		has_bounds = result.has_area()
	for candidate in layers:
		if not bool(candidate["visible"]):
			continue
		var definition: MapDefinition = candidate["definition"]
		var bounds := Rect2(Vector2(candidate["offset"]), definition.world_size())
		result = result.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return result


func _apply_requested_fit() -> void:
	if _fit_requested and is_inside_tree():
		fit_to_maps()


func _on_resized() -> void:
	# The editor main screen receives its final size after plugin construction.
	# A pending fit must therefore run on resize, not only after maps are parsed.
	if _fit_requested:
		call_deferred("_apply_requested_fit")
	else:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if edit_background and has_background():
					_drag_mode = &"background"
				else:
					_select_layer_at(button.position)
					_drag_mode = &"pan"
			else:
				_drag_mode = &""
			_last_mouse = button.position
			accept_event()
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_mode = &"pan" if button.pressed else &""
			_last_mouse = button.position
			accept_event()
	elif event is InputEventMouseMotion and not _drag_mode.is_empty():
		var motion := event as InputEventMouseMotion
		var screen_delta := motion.position - _last_mouse
		if _drag_mode == &"background":
			# Background geometry uses world pixels, so compensate for view zoom.
			set_background_offset(background_offset + screen_delta / _zoom)
		else:
			_pan += screen_delta
			queue_redraw()
			view_changed.emit()
		_last_mouse = motion.position


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
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
			if edit_background and has_background():
				nudge_background(Vector2(delta))
			elif not selected_map_id.is_empty():
				nudge_selected(delta)
			else:
				return
			get_viewport().set_input_as_handled()


func _select_layer_at(screen_point: Vector2) -> void:
	var world_point := (screen_point - _pan) / _zoom
	for index in range(layers.size() - 1, -1, -1):
		var candidate := layers[index]
		if not bool(candidate["visible"]):
			continue
		var definition: MapDefinition = candidate["definition"]
		if Rect2(Vector2(candidate["offset"]), definition.world_size()).has_point(world_point):
			select_layer(candidate["id"])
			return


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var world_point := (screen_point - _pan) / _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_pan = screen_point - world_point * _zoom
	queue_redraw()
	view_changed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(26, 28, 32), true)
	if has_background() and background_visible:
		_draw_background()
	if layers.is_empty():
		if not has_background():
			_draw_center_message("Add a background or load maps to start aligning")
		return
	for candidate in layers:
		if bool(candidate["visible"]):
			_draw_map(candidate)
	if show_grid:
		_draw_grid()
	_draw_seams()


func _draw_background() -> void:
	var screen_rect := _screen_rect(background_world_rect())
	draw_texture_rect(background_texture, screen_rect, false, Color(1.0, 1.0, 1.0, background_opacity))
	if edit_background:
		draw_rect(screen_rect, Color(0.25, 0.75, 1.0, 0.95), false, 3.0)


func _draw_map(map_layer: Dictionary) -> void:
	var definition: MapDefinition = map_layer["definition"]
	var offset := Vector2(map_layer["offset"])
	var opacity := float(map_layer["opacity"])
	var accent := Color(map_layer["accent"])
	var world_rect := _screen_rect(Rect2(offset, definition.world_size()))
	var texture: Texture2D = map_layer["terrain_texture"]
	draw_texture_rect(texture, world_rect, false, Color(1.0, 1.0, 1.0, opacity))
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
	var selected: bool = StringName(map_layer["id"]) == selected_map_id
	draw_rect(world_rect, Color.WHITE if selected else Color(accent, opacity), false, 5.0 if selected else 2.0)
	_draw_id(String(DISPLAY_NAMES.get(definition.map_id, definition.map_id)), world_rect.position + Vector2(8.0, 20.0), Color.WHITE if selected else accent, opacity, false)


func _build_terrain_texture(definition: MapDefinition) -> ImageTexture:
	var grid := MapBuilder.build(definition)
	var image := Image.create(definition.size_cells.x, definition.size_cells.y, false, Image.FORMAT_RGBA8)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			image.set_pixel(x, y, OutdoorTerrainPalette.color(grid.get_terrain(Vector2i(x, y))))
	return ImageTexture.create_from_image(image)


func _draw_grid() -> void:
	if layers.is_empty():
		return
	var definition: MapDefinition = layers[0]["definition"]
	var cell_size := float(definition.cell_size)
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


func _draw_seams() -> void:
	for seam in seams:
		var first := layer(seam["base_map_id"])
		var second := layer(seam["neighbor_map_id"])
		if first.is_empty() or second.is_empty() or not bool(first["visible"]) or not bool(second["visible"]):
			continue
		var first_rect: Rect2 = seam["base"]["rect"]
		var second_rect: Rect2 = seam["neighbor"]["rect"]
		var first_center := _screen(first_rect.get_center() + Vector2(first["offset"]))
		var second_center := _screen(second_rect.get_center() + Vector2(second["offset"]))
		var mismatch := not is_equal_approx(float(seam["base_span_cells"]), float(seam["neighbor_span_cells"]))
		var color := Color(1.0, 0.25, 0.2) if mismatch else Color(1.0, 0.95, 0.2)
		draw_line(first_center, second_center, color, 4.0)
		draw_circle(first_center, 6.0, Color(first["accent"]))
		draw_circle(second_center, 6.0, Color(second["accent"]))


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
