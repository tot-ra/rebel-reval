class_name WorldMapGlobalView
extends Control

## Estonia-wide travel presentation owned by WorldMapOverlay. Renders the
## basemap plus distant markers and emits destination intent only.

signal destination_requested(scene_id: StringName)

const PANEL_SIZE := Vector2(820, 600)
const NODE_SIZE := Vector2(140, 40)
const TRAVEL_NODE_COLOR := Color(0.92, 0.96, 1.0, 1.0)
const TRAVEL_FOCUS_COLOR := Color(1.0, 0.78, 0.28, 1.0)
const HUB_COLOR := Color(1.0, 0.86, 0.42, 1.0)

var _current_scene_id: StringName = &""
var _travelable: Dictionary = {}
var _map_rect: TextureRect
var _marker_host: Control


func configure(current_scene_id: StringName, travelable: Dictionary) -> void:
	_current_scene_id = current_scene_id
	_travelable = travelable.duplicate(true)
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()

	_map_rect = TextureRect.new()
	_map_rect.name = "EstoniaMap"
	_map_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map_rect.texture = GlobalMapCatalog.load_map_texture()
	_map_rect.modulate = Color(0.92, 0.94, 0.96, 1.0)
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_rect)

	var dim := ColorRect.new()
	dim.name = "MapDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.08, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_marker_host = Control.new()
	_marker_host.name = "MarkerHost"
	_marker_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker_host)

	var travelable_buttons: Array[Button] = []
	for scene_id in GlobalMapCatalog.location_ids():
		var row := GlobalMapCatalog.get_location(scene_id)
		var button := Button.new()
		button.name = "GlobalNode_%s" % String(scene_id)
		button.text = String(row.get("display_name", String(scene_id)))
		button.tooltip_text = String(row.get("blurb", ""))
		button.custom_minimum_size = NODE_SIZE
		var is_hub := bool(row.get("is_hub", false))
		var is_current := _is_current_marker(scene_id)
		if is_current:
			_configure_current_button(button)
		elif _travelable.has(scene_id):
			_configure_travelable_button(button, scene_id)
			travelable_buttons.append(button)
		elif is_hub:
			_configure_hub_button(button, scene_id)
			if _travelable.has(scene_id):
				travelable_buttons.append(button)
		else:
			_configure_unavailable_button(button)
		_marker_host.add_child(button)
		_place_node(button, scene_id)
	_wire_focus_neighbors(travelable_buttons)


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
	destination_requested.emit(scene_id)
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
	if GlobalMapCatalog.is_distant_scene(_current_scene_id):
		return (
			"You are outside Reval at %s - choose Reval or stay on the road home"
			% GlobalMapCatalog.display_name(_current_scene_id)
		)
	if _current_scene_id.is_empty():
		return "Estonia overview - select a distant road or sea route"
	return (
		"You are in Reval (%s) - choose a distant placeholder road"
		% LocationHud.display_name_for_scene(_current_scene_id)
	)


func help_text() -> String:
	return (
		"Global map: click or focus a linked distant place, then Confirm to travel. "
		+ "Each placeholder returns through a Tallinn gate (south, east, west, or harbour). "
		+ "District fast travel stays on the Reval graph. Press M / Escape to close."
	)


func _is_current_marker(scene_id: StringName) -> bool:
	if scene_id == GlobalMapCatalog.REVAL_HUB_ID:
		return not GlobalMapCatalog.is_distant_scene(_current_scene_id) and not _current_scene_id.is_empty()
	return scene_id == _current_scene_id


func _configure_current_button(button: Button) -> void:
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.12, 0.10, 0.06, 1.0))
	button.modulate = HUB_COLOR


func _configure_hub_button(button: Button, scene_id: StringName) -> void:
	if _travelable.has(scene_id):
		_configure_travelable_button(button, scene_id)
		button.modulate = HUB_COLOR
		return
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate = HUB_COLOR


func _configure_travelable_button(button: Button, scene_id: StringName) -> void:
	button.disabled = false
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate = TRAVEL_NODE_COLOR
	button.add_theme_stylebox_override("focus", _travel_focus_style())
	button.pressed.connect(_on_node_pressed.bind(scene_id))


func _configure_unavailable_button(button: Button) -> void:
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate = Color(0.72, 0.76, 0.80, 0.85)


func _place_node(button: Button, scene_id: StringName) -> void:
	var normalized: Vector2 = GlobalMapCatalog.layout_positions().get(scene_id, Vector2(0.5, 0.5))
	var area := size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(PANEL_SIZE.x - 40.0, 400.0)
	button.position = Vector2(
		normalized.x * area.x - NODE_SIZE.x * 0.5,
		normalized.y * area.y - NODE_SIZE.y * 0.5
	)
	button.size = NODE_SIZE


func _wire_focus_neighbors(buttons: Array[Button]) -> void:
	if buttons.size() < 2:
		return
	for button in buttons:
		var origin := button.position + button.size * 0.5
		button.focus_neighbor_left = _nearest_focus_path(button, buttons, origin, Vector2(-1.0, 0.0))
		button.focus_neighbor_right = _nearest_focus_path(button, buttons, origin, Vector2(1.0, 0.0))
		button.focus_neighbor_top = _nearest_focus_path(button, buttons, origin, Vector2(0.0, -1.0))
		button.focus_neighbor_bottom = _nearest_focus_path(button, buttons, origin, Vector2(0.0, 1.0))


func _nearest_focus_path(
	from_button: Button,
	candidates: Array[Button],
	origin: Vector2,
	direction: Vector2
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
	destination_requested.emit(scene_id)


func _travel_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.20, 0.28, 0.98)
	style.border_color = TRAVEL_FOCUS_COLOR
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.expand_margin_left = 3
	style.expand_margin_right = 3
	style.expand_margin_top = 3
	style.expand_margin_bottom = 3
	return style
