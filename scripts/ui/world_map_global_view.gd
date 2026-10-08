class_name WorldMapGlobalView
extends Control

## Estonia-wide travel presentation owned by WorldMapOverlay. Renders the
## full-screen basemap, inked roads, and round markers, and emits destination
## intent only. Names appear on hover/focus; choosing a destination first walks
## a small traveler along the road, then emits.

signal destination_requested(scene_id: StringName)
signal close_requested

const PANEL_SIZE := Vector2(820, 600)
const MARKER_SIZE := Vector2(40, 40)
const MarkerScript := preload("res://scripts/ui/world_map_marker.gd")
const ROAD_INK := Color(0.26, 0.16, 0.08, 0.92)
const ROAD_WASH := Color(0.26, 0.16, 0.08, 0.18)
const TRAIL_GOLD := Color(1.0, 0.76, 0.24, 1.0)
const ROAD_SAMPLES := 40
## Screen pixels per second the traveler covers; clamped so short hops still read.
const WALK_SPEED := 260.0
const WALK_MIN_SECONDS := 1.4
const WALK_MAX_SECONDS := 4.0

var _current_scene_id: StringName = &""
var _travelable: Dictionary = {}
var _map_rect: TextureRect
var _route_host: Control
var _marker_host: Control
var _name_label: Label
var _blurb_label: Label
var _caption: PanelContainer
var _hovered_id: StringName = &""
var _walk_path: PackedVector2Array = PackedVector2Array()
var _walk_t := 0.0
var _walk_seconds := 0.0
var _walk_target: StringName = &""
var _walking := false


func configure(current_scene_id: StringName, travelable: Dictionary) -> void:
	_current_scene_id = current_scene_id
	_travelable = travelable.duplicate(true)
	_cancel_walk()
	if is_node_ready():
		rebuild()


func _ready() -> void:
	resized.connect(_layout_markers)
	visibility_changed.connect(_on_visibility_changed)
	rebuild()


func is_walking() -> bool:
	return _walking


func rebuild() -> void:
	for child in get_children():
		child.free()

	_map_rect = TextureRect.new()
	_map_rect.name = "EstoniaMap"
	_map_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map_rect.texture = GlobalMapCatalog.load_map_texture()
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_rect)

	_route_host = Control.new()
	_route_host.name = "RouteHost"
	_route_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_route_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_route_host)
	_route_host.draw.connect(_draw_routes)

	_marker_host = Control.new()
	_marker_host.name = "MarkerHost"
	_marker_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_host)

	var travelable_buttons: Array[Button] = []
	for scene_id in GlobalMapCatalog.marker_ids():
		var button: Button = MarkerScript.new()
		button.name = "GlobalNode_%s" % String(scene_id)
		button.custom_minimum_size = MARKER_SIZE
		button.mouse_entered.connect(_show_caption.bind(scene_id))
		button.mouse_exited.connect(_hide_caption.bind(scene_id))
		button.focus_entered.connect(_show_caption.bind(scene_id))
		button.focus_exited.connect(_hide_caption.bind(scene_id))
		var row := GlobalMapCatalog.get_location(scene_id)
		var is_hub := bool(row.get("is_hub", false))
		if GlobalMapCatalog.is_planned(scene_id):
			button.kind = MarkerScript.Kind.PLANNED
			_configure_inert_button(button)
		elif _is_current_marker(scene_id):
			button.kind = MarkerScript.Kind.CURRENT
			_configure_inert_button(button)
		elif _travelable.has(scene_id):
			button.kind = MarkerScript.Kind.HUB if is_hub else MarkerScript.Kind.TRAVELABLE
			_configure_travelable_button(button, scene_id)
			travelable_buttons.append(button)
		else:
			button.kind = MarkerScript.Kind.HUB if is_hub else MarkerScript.Kind.PLANNED
			_configure_inert_button(button)
		_marker_host.add_child(button)

	_build_caption()
	_build_close_button()
	_layout_markers()
	_wire_focus_neighbors(travelable_buttons)
	_route_host.queue_redraw()


func _build_caption() -> void:
	_caption = PanelContainer.new()
	_caption.name = "PlaceCaption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.05, 0.92)
	style.border_color = Color(0.78, 0.60, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_caption.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(box)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58, 1.0))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name_label)
	_blurb_label = Label.new()
	_blurb_label.add_theme_font_size_override("font_size", 13)
	_blurb_label.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64, 1.0))
	_blurb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_blurb_label)
	add_child(_caption)


func _build_close_button() -> void:
	var close_button := Button.new()
	close_button.name = "GlobalCloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Close map"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -52
	close_button.offset_right = -16
	close_button.offset_top = 16
	close_button.offset_bottom = 52
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)


## Maps a normalized basemap point to this control, matching the TextureRect's
## STRETCH_KEEP_ASPECT_COVERED crop so markers stay pinned to the painted geography.
func map_point(normalized: Vector2) -> Vector2:
	var area := size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(PANEL_SIZE.x - 40.0, 400.0)
	var texture := _map_rect.texture if _map_rect != null else null
	if texture == null:
		return normalized * area
	var image_size := Vector2(texture.get_size())
	var scale := maxf(area.x / image_size.x, area.y / image_size.y)
	var drawn := image_size * scale
	return (area - drawn) * 0.5 + normalized * drawn


func _layout_markers() -> void:
	if _marker_host == null:
		return
	for button in _marker_host.get_children():
		var scene_id := _scene_id_from_button(button as Button)
		var normalized: Vector2 = GlobalMapCatalog.layout_positions().get(scene_id, Vector2(0.5, 0.5))
		button.size = MARKER_SIZE
		button.position = map_point(normalized) - MARKER_SIZE * 0.5
	if _route_host != null:
		_route_host.queue_redraw()


func _marker_center(scene_id: StringName) -> Vector2:
	var normalized: Vector2 = GlobalMapCatalog.layout_positions().get(scene_id, Vector2(0.5, 0.5))
	return map_point(normalized)


## Gently bowed road so paths read as hand-inked, not ruler-straight.
func _road_points(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var chord := to_point - from_point
	var bow := chord.orthogonal().normalized() * chord.length() * 0.10
	var control := (from_point + to_point) * 0.5 + bow
	var points := PackedVector2Array()
	for i in ROAD_SAMPLES + 1:
		var t := float(i) / float(ROAD_SAMPLES)
		points.append(from_point.lerp(control, t).lerp(control.lerp(to_point, t), t))
	return points


func _draw_routes() -> void:
	if _route_host == null:
		return
	for edge in GlobalMapCatalog.connections():
		var from_id: StringName = edge.get("from", &"")
		var to_id: StringName = edge.get("to", &"")
		# Always draw in a stable direction so the bow is identical both ways.
		if String(from_id) > String(to_id):
			var swap := from_id
			from_id = to_id
			to_id = swap
		var points := _road_points(_marker_center(from_id), _marker_center(to_id))
		_route_host.draw_polyline(points, ROAD_WASH, 9.0, true)
		_route_host.draw_polyline(points, ROAD_INK, 3.0, true)
	if _walking and _walk_path.size() > 1:
		var upto := int(floor(_walk_t * float(_walk_path.size() - 1))) + 1
		var trail := _walk_path.slice(0, mini(upto + 1, _walk_path.size()))
		if trail.size() > 1:
			_route_host.draw_polyline(trail, TRAIL_GOLD, 4.0, true)
		_draw_traveler(_route_host, _walker_position())


func _walker_position() -> Vector2:
	var f := _walk_t * float(_walk_path.size() - 1)
	var i := clampi(int(floor(f)), 0, _walk_path.size() - 2)
	return _walk_path[i].lerp(_walk_path[i + 1], f - float(i))


## Tiny hooded wanderer drawn from primitives; bobs while walking.
func _draw_traveler(host: Control, at: Vector2) -> void:
	var bob := sin(_walk_t * _walk_seconds * 9.0) * 1.8
	var feet := at + Vector2(0.0, bob)
	host.draw_circle(feet + Vector2(0.0, 2.0), 7.0, Color(0.0, 0.0, 0.0, 0.25))
	var cloak := PackedVector2Array(
		[feet + Vector2(0.0, -17.0), feet + Vector2(8.0, 2.0), feet + Vector2(-8.0, 2.0)]
	)
	host.draw_colored_polygon(cloak, Color(0.62, 0.14, 0.12, 1.0))
	host.draw_polyline(
		PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[0]]), Color(0.16, 0.08, 0.05), 1.5
	)
	host.draw_circle(feet + Vector2(0.0, -17.0), 4.5, Color(0.93, 0.78, 0.58, 1.0))
	host.draw_arc(feet + Vector2(0.0, -17.0), 4.5, 0.0, TAU, 14, Color(0.16, 0.08, 0.05), 1.2, true)
	host.draw_line(feet + Vector2(9.0, 2.0), feet + Vector2(9.0, -18.0), Color(0.35, 0.22, 0.10), 2.0)


func _process(delta: float) -> void:
	if not _walking:
		return
	_walk_t = minf(1.0, _walk_t + delta / maxf(_walk_seconds, 0.01))
	_route_host.queue_redraw()
	if _walk_t >= 1.0:
		var target := _walk_target
		_cancel_walk()
		destination_requested.emit(target)


## Starts the walk, or emits at once when there is nothing to animate (headless
## runs, unknown origin) so travel intent never depends on frame timing.
func _begin_travel(scene_id: StringName) -> void:
	if _walking:
		return
	var origin := _origin_marker_id()
	if (
		DisplayServer.get_name() == "headless"
		or origin.is_empty()
		or not is_visible_in_tree()
		or not GlobalMapCatalog.layout_positions().has(origin)
	):
		destination_requested.emit(scene_id)
		return
	var from_point := _marker_center(origin)
	var to_point := _marker_center(scene_id)
	# Roads are drawn in id order; walk the same curve, reversed when needed.
	var forward := String(origin) < String(scene_id)
	var path := (
		_road_points(from_point, to_point)
		if forward
		else _road_points(to_point, from_point)
	)
	if not forward:
		path.reverse()
	_walk_path = path
	_walk_target = scene_id
	_walk_t = 0.0
	_walk_seconds = clampf(
		from_point.distance_to(to_point) / WALK_SPEED, WALK_MIN_SECONDS, WALK_MAX_SECONDS
	)
	_walking = true
	_set_markers_enabled(false)
	_route_host.queue_redraw()


func _origin_marker_id() -> StringName:
	if GlobalMapCatalog.is_distant_scene(_current_scene_id):
		return _current_scene_id
	if _current_scene_id.is_empty():
		return &""
	return GlobalMapCatalog.REVAL_HUB_ID


func _cancel_walk() -> void:
	_walking = false
	_walk_t = 0.0
	_walk_path = PackedVector2Array()
	if _marker_host != null:
		_set_markers_enabled(true)
	if _route_host != null:
		_route_host.queue_redraw()


func _set_markers_enabled(enabled: bool) -> void:
	if _marker_host == null:
		return
	for button in _marker_host.get_children():
		var scene_id := _scene_id_from_button(button as Button)
		if _travelable.has(scene_id):
			(button as Button).disabled = not enabled


func _on_visibility_changed() -> void:
	if not visible:
		_cancel_walk()
		if _caption != null:
			_caption.visible = false


func _show_caption(scene_id: StringName) -> void:
	if _caption == null or _walking:
		return
	_hovered_id = scene_id
	var row := GlobalMapCatalog.get_location(scene_id)
	_name_label.text = String(row.get("display_name", String(scene_id)))
	var blurb := String(row.get("blurb", ""))
	if GlobalMapCatalog.is_planned(scene_id):
		blurb = "Not yet charted"
	elif _is_current_marker(scene_id):
		blurb = "You are here"
	_blurb_label.text = blurb
	_blurb_label.visible = not blurb.is_empty()
	_caption.visible = true
	_caption.reset_size()
	# Float above the marker, clamped inside the screen.
	var anchor := _marker_center(scene_id)
	var target := anchor + Vector2(-_caption.size.x * 0.5, -_caption.size.y - 26.0)
	if target.y < 8.0:
		target.y = anchor.y + 26.0
	target.x = clampf(target.x, 8.0, maxf(8.0, size.x - _caption.size.x - 8.0))
	_caption.position = target


func _hide_caption(scene_id: StringName) -> void:
	if _caption != null and _hovered_id == scene_id:
		_caption.visible = false
		_hovered_id = &""


func get_node_button(scene_id: StringName) -> Button:
	if _marker_host == null:
		return null
	return _marker_host.get_node_or_null("GlobalNode_%s" % String(scene_id)) as Button


func focus_travel_node(destination_scene_id: StringName) -> bool:
	if not _travelable.has(destination_scene_id):
		return false
	var button := get_node_button(destination_scene_id)
	if button == null or button.focus_mode == Control.FOCUS_NONE:
		return false
	button.grab_focus()
	return get_viewport().gui_get_focus_owner() == button


func activate_focused_travel() -> bool:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or _marker_host == null or not _marker_host.is_ancestor_of(focused):
		return false
	var scene_id := _scene_id_from_button(focused)
	if scene_id.is_empty() or not _travelable.has(scene_id):
		return false
	_begin_travel(scene_id)
	return true


func grab_initial_focus(fallback: Control = null) -> void:
	if not visible:
		return
	var neighbors: Array[StringName] = []
	for scene_id in _travelable.keys():
		neighbors.append(scene_id)
	neighbors.sort()
	if neighbors.is_empty():
		if fallback != null:
			fallback.grab_focus()
		return
	focus_travel_node(neighbors[0])


func subtitle() -> String:
	return ""


func help_text() -> String:
	return ""


func _is_current_marker(scene_id: StringName) -> bool:
	if scene_id == GlobalMapCatalog.REVAL_HUB_ID:
		return (
			not GlobalMapCatalog.is_distant_scene(_current_scene_id)
			and not _current_scene_id.is_empty()
		)
	return scene_id == _current_scene_id


func _configure_inert_button(button: Button) -> void:
	# Current/planned markers hover for their caption but never travel or focus.
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP


func _configure_travelable_button(button: Button, scene_id: StringName) -> void:
	button.disabled = false
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_node_pressed.bind(scene_id))


func _wire_focus_neighbors(buttons: Array[Button]) -> void:
	if buttons.size() < 2:
		return
	for button in buttons:
		var origin := button.position + button.size * 0.5
		button.focus_neighbor_left = _nearest_focus_path(
			button, buttons, origin, Vector2(-1.0, 0.0)
		)
		button.focus_neighbor_right = _nearest_focus_path(
			button, buttons, origin, Vector2(1.0, 0.0)
		)
		button.focus_neighbor_top = _nearest_focus_path(button, buttons, origin, Vector2(0.0, -1.0))
		button.focus_neighbor_bottom = _nearest_focus_path(
			button, buttons, origin, Vector2(0.0, 1.0)
		)


func _nearest_focus_path(
	from_button: Button, candidates: Array[Button], origin: Vector2, direction: Vector2
) -> NodePath:
	var best: Button = null
	var best_score := INF
	for candidate in candidates:
		if candidate == from_button:
			continue
		var delta: Vector2 = (candidate.position + candidate.size * 0.5) - origin
		var aligned := delta.dot(direction)
		if aligned <= 1.0:
			continue
		var sideways := absf(delta.x * direction.y - delta.y * direction.x)
		var score := aligned + sideways * 0.35
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		return NodePath()
	return from_button.get_path_to(best)


func _scene_id_from_button(button: Button) -> StringName:
	var button_name := String(button.name)
	if not button_name.begins_with("GlobalNode_"):
		return &""
	return StringName(button_name.substr(11))


func _on_node_pressed(scene_id: StringName) -> void:
	_begin_travel(scene_id)
