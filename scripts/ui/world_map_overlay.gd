class_name WorldMapOverlay
extends CanvasLayer

## Full-screen district graph for authored scene transitions (P1-031).
## Click-to-travel on connected neighbors is P1-031a.
## Keyboard/gamepad focus + ui_accept travel is P1-031b.

signal closed()
signal travel_requested(scene_id: StringName, spawn_id: StringName)

const PANEL_SIZE := Vector2(760, 520)
const NODE_SIZE := Vector2(132, 44)

var _current_scene_id: StringName = &""
var _scene_ids: Array[StringName] = []
var _connections: Array[Dictionary] = []
var _positions: Dictionary = {}
var _travelable: Dictionary = {}

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _graph_host: Control
var _close_button: Button
var _help: Label


func configure(current_scene_id: StringName = &"") -> void:
	_current_scene_id = current_scene_id
	_scene_ids = WorldMapGraph.active_scene_ids()
	_connections = WorldMapGraph.connections()
	_positions = WorldMapGraph.layout_positions(_scene_ids)
	_travelable.clear()
	for neighbor_id in WorldMapGraph.travelable_neighbors(_current_scene_id):
		_travelable[neighbor_id] = WorldMapGraph.resolve_travel_spawn(
			_current_scene_id,
			neighbor_id
		)
	if is_node_ready():
		_rebuild_graph()


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_rebuild_graph()


func open() -> void:
	visible = true
	_rebuild_graph()
	_grab_initial_focus()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_scene_ids() -> Array[StringName]:
	return _scene_ids.duplicate()


func get_connections() -> Array[Dictionary]:
	return _connections.duplicate(true)


func get_current_scene_id() -> StringName:
	return _current_scene_id


func get_travelable_scene_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in _travelable.keys():
		ids.append(scene_id)
	ids.sort()
	return ids


func get_node_button(scene_id: StringName) -> Button:
	if _graph_host == null:
		return null
	return _graph_host.get_node_or_null("Node_%s" % String(scene_id)) as Button


## Returns the planned travel payload when the destination is a travelable neighbor.
## Does not call DoorNavigator; the controller owns execution.
func plan_travel_to(destination_scene_id: StringName) -> Dictionary:
	if not _travelable.has(destination_scene_id):
		return {}
	var spawn: StringName = _travelable[destination_scene_id]
	if spawn.is_empty():
		return {}
	return {
		"scene_id": destination_scene_id,
		"spawn_id": spawn,
	}


func request_travel_to(destination_scene_id: StringName) -> bool:
	var plan := plan_travel_to(destination_scene_id)
	if plan.is_empty():
		return false
	travel_requested.emit(plan["scene_id"], plan["spawn_id"])
	return true


## Focus a travelable neighbor for keyboard/gamepad navigation (P1-031b).
## Returns false when the destination is missing or not travelable (including current).
func focus_travel_node(destination_scene_id: StringName) -> bool:
	if not _travelable.has(destination_scene_id):
		return false
	var button := get_node_button(destination_scene_id)
	if button == null or button.focus_mode == Control.FOCUS_NONE:
		return false
	button.grab_focus()
	return get_viewport().gui_get_focus_owner() == button


## Activate ui_accept against the currently focused travelable node.
## Headless tests call this after focus_travel_node; live play also routes ui_accept here
## when GUI focus did not already consume the event through Button.pressed.
func activate_focused_travel() -> bool:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or _graph_host == null or not _graph_host.is_ancestor_of(focused):
		return false
	var scene_id := _scene_id_from_node_button(focused)
	if scene_id.is_empty():
		return false
	# WHY (P1-031b): current / disconnected nodes use FOCUS_NONE, but still refuse
	# travel if focus somehow lands on a non-travelable Node_* button.
	return request_travel_to(scene_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).is_echo()
		and (event as InputEventKey).keycode == KEY_ESCAPE
	):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		if activate_focused_travel():
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "WorldMapRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.05, 0.08, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	var panel := PanelContainer.new()
	panel.name = "WorldMapPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "District map"
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56, 1.0))
	titles.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 0.95))
	titles.add_child(_subtitle)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_graph_host = Control.new()
	_graph_host.name = "GraphHost"
	_graph_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_host.custom_minimum_size = Vector2(0, 400)
	_graph_host.draw.connect(_draw_connections)
	layout.add_child(_graph_host)

	_help = Label.new()
	_help.name = "HelpLabel"
	_help.text = (
		"Click or focus a connected district, then Confirm to travel. "
		+ "Arrow keys / D-pad move focus between linked districts. "
		+ "Your current district stays marked and cannot be selected. "
		+ "Press M or Escape to close."
	)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.add_theme_font_size_override("font_size", 12)
	_help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 1.0))
	layout.add_child(_help)


func _rebuild_graph() -> void:
	if _graph_host == null:
		return
	for child in _graph_host.get_children():
		# WHY: free immediately so rebuilt Node_<id> names stay unique in-frame
		# and get_node_button / focus wiring see only the new buttons.
		child.free()

	_subtitle.text = _subtitle_for_current()
	var travelable_buttons: Array[Button] = []
	for scene_id in _scene_ids:
		var button := Button.new()
		button.name = "Node_%s" % String(scene_id)
		button.text = LocationHud.display_name_for_scene(scene_id)
		button.tooltip_text = String(scene_id)
		button.custom_minimum_size = NODE_SIZE
		if scene_id == _current_scene_id:
			# WHY (P1-031a / P1-031b): current scene must stay visible but never
			# travel, and must not enter the keyboard/gamepad focus ring.
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06, 1.0))
			button.add_theme_color_override("font_disabled_color", Color(0.12, 0.10, 0.06, 1.0))
			button.modulate = Color(1.0, 0.86, 0.42, 1.0)
		elif _travelable.has(scene_id):
			button.disabled = false
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.modulate = Color(0.92, 0.96, 1.0, 1.0)
			button.pressed.connect(_on_node_pressed.bind(scene_id))
			travelable_buttons.append(button)
		else:
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.modulate = Color(0.72, 0.76, 0.80, 0.85)
		_graph_host.add_child(button)
		_place_node(button, scene_id)
	_wire_travel_focus_neighbors(travelable_buttons)
	_graph_host.queue_redraw()


func _grab_initial_focus() -> void:
	if not visible:
		return
	var neighbors := get_travelable_scene_ids()
	if neighbors.is_empty():
		if _close_button != null:
			_close_button.grab_focus()
		return
	focus_travel_node(neighbors[0])


func _wire_travel_focus_neighbors(buttons: Array[Button]) -> void:
	# WHY (P1-031b): absolute-positioned graph nodes need explicit neighbor paths;
	# Godot's default search is unreliable when siblings sit in a free Control.
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
		# Prefer forward alignment, lightly penalize sideways drift.
		var sideways := absf(delta.x * direction.y - delta.y * direction.x)
		var score := aligned + sideways * 0.35
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		return NodePath()
	return from_button.get_path_to(best)


func _scene_id_from_node_button(button: Button) -> StringName:
	var button_name := String(button.name)
	if not button_name.begins_with("Node_"):
		return &""
	return StringName(button_name.substr(5))


func _on_node_pressed(scene_id: StringName) -> void:
	request_travel_to(scene_id)


func _subtitle_for_current() -> String:
	if _current_scene_id.is_empty():
		return "Current scene is outside the active transition registry."
	if _travelable.is_empty():
		return "You are here: %s (no travelable neighbors)" % LocationHud.display_name_for_scene(
			_current_scene_id
		)
	return (
		"You are here: %s - select a linked district (click or Confirm)"
		% LocationHud.display_name_for_scene(_current_scene_id)
	)


func _place_node(button: Button, scene_id: StringName) -> void:
	var normalized: Vector2 = _positions.get(scene_id, Vector2(0.5, 0.5))
	var area := _graph_host.size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(PANEL_SIZE.x - 40.0, 400.0)
	var top_left := Vector2(
		normalized.x * area.x - NODE_SIZE.x * 0.5,
		normalized.y * area.y - NODE_SIZE.y * 0.5
	)
	button.position = top_left
	button.size = NODE_SIZE


func _draw_connections() -> void:
	if _graph_host == null:
		return
	for edge in _connections:
		var from_id: StringName = edge.get("from", &"")
		var to_id: StringName = edge.get("to", &"")
		var from_button := get_node_button(from_id)
		var to_button := get_node_button(to_id)
		if from_button == null or to_button == null:
			continue
		var a := from_button.position + from_button.size * 0.5
		var b := to_button.position + to_button.size * 0.5
		_graph_host.draw_line(a, b, Color(0.72, 0.58, 0.31, 0.85), 2.0, true)
