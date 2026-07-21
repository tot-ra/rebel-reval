class_name WorldMapFastTravelView
extends Control

## Focused fast-travel presentation owned by WorldMapOverlay. It renders and
## focuses graph nodes, then emits a destination intent. The overlay validates
## the plan and WorldMapController remains the only DoorNavigator caller.

signal destination_requested(scene_id: StringName)

const PANEL_SIZE := Vector2(820, 600)
const NODE_SIZE := Vector2(132, 44)
const TRAVEL_NODE_COLOR := Color(0.92, 0.96, 1.0, 1.0)
const TRAVEL_FOCUS_COLOR := Color(1.0, 0.78, 0.28, 1.0)

var _current_scene_id: StringName = &""
var _scene_ids: Array[StringName] = []
var _connections: Array[Dictionary] = []
var _positions: Dictionary = {}
var _travelable: Dictionary = {}


func configure(
	current_scene_id: StringName,
	scene_ids: Array[StringName],
	connections: Array[Dictionary],
	positions: Dictionary,
	travelable: Dictionary
) -> void:
	_current_scene_id = current_scene_id
	_scene_ids = scene_ids.duplicate()
	_connections = connections.duplicate(true)
	_positions = positions.duplicate(true)
	_travelable = travelable.duplicate(true)
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		# WHY: free immediately so rebuilt Node_<id> names stay unique in-frame
		# and facade lookups/focus wiring see only the new buttons.
		child.free()

	var travelable_buttons: Array[Button] = []
	for scene_id in _scene_ids:
		var button := Button.new()
		button.name = "Node_%s" % String(scene_id)
		button.text = LocationHud.display_name_for_scene(scene_id)
		button.tooltip_text = String(scene_id)
		button.custom_minimum_size = NODE_SIZE
		if scene_id == _current_scene_id:
			_configure_current_button(button)
		elif _travelable.has(scene_id):
			_configure_travelable_button(button, scene_id)
			travelable_buttons.append(button)
		else:
			_configure_unavailable_button(button)
		add_child(button)
		_place_node(button, scene_id)
	_wire_focus_neighbors(travelable_buttons)
	queue_redraw()


func get_node_button(scene_id: StringName) -> Button:
	return get_node_or_null("Node_%s" % String(scene_id)) as Button


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
	if focused == null or not is_ancestor_of(focused):
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
	if _current_scene_id.is_empty():
		return "Current scene is outside the active transition registry."
	if _travelable.is_empty():
		return "You are here: %s (no travelable destinations)" % LocationHud.display_name_for_scene(
			_current_scene_id
		)
	if WorldMapGraph.allow_all_active_travel():
		return (
			"You are here: %s - debug: select any active district (click or Confirm)"
			% LocationHud.display_name_for_scene(_current_scene_id)
		)
	return (
		"You are here: %s - select a linked district (click or Confirm)"
		% LocationHud.display_name_for_scene(_current_scene_id)
	)


func help_text() -> String:
	if WorldMapGraph.allow_all_active_travel():
		return (
			"Debug unlock: click or focus any active district, then Confirm to travel. "
			+ "Arrow keys / D-pad move focus between destinations. "
			+ "Your current district stays marked and cannot be selected. "
			+ "Choose Local map to return, or press M / Escape to close."
		)
	return (
		"Click or focus a connected district, then Confirm to travel. "
		+ "Arrow keys / D-pad move focus between linked districts. "
		+ "Your current district stays marked and cannot be selected. "
		+ "Choose Local map to return, or press M / Escape to close."
	)


func _draw() -> void:
	for edge in _connections:
		var from_id: StringName = edge.get("from", &"")
		var to_id: StringName = edge.get("to", &"")
		var from_button := get_node_button(from_id)
		var to_button := get_node_button(to_id)
		if from_button == null or to_button == null:
			continue
		var a := from_button.position + from_button.size * 0.5
		var b := to_button.position + to_button.size * 0.5
		draw_line(a, b, Color(0.72, 0.58, 0.31, 0.85), 2.0, true)


func _configure_current_button(button: Button) -> void:
	# Current scene stays visible but never enters the mouse or focus travel path.
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.12, 0.10, 0.06, 1.0))
	button.modulate = Color(1.0, 0.86, 0.42, 1.0)


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
	var normalized: Vector2 = _positions.get(scene_id, Vector2(0.5, 0.5))
	var area := size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(PANEL_SIZE.x - 40.0, 400.0)
	button.position = Vector2(
		normalized.x * area.x - NODE_SIZE.x * 0.5,
		normalized.y * area.y - NODE_SIZE.y * 0.5
	)
	button.size = NODE_SIZE


func _wire_focus_neighbors(buttons: Array[Button]) -> void:
	# Absolute-positioned graph nodes need explicit focus neighbors because
	# Godot's default search is unreliable in a free Control.
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
	if not button_name.begins_with("Node_"):
		return &""
	return StringName(button_name.substr(5))


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
