class_name WorldMapOverlay
extends CanvasLayer

## Full-screen map mode. It opens on the current local map; the existing
## district graph remains available as an explicit fast-travel option.

const WorldMapOverlayBuilder := preload("res://scripts/ui/world_map_overlay_builder.gd")

signal closed()
signal travel_requested(scene_id: StringName, spawn_id: StringName)

const MODE_LOCAL := &"local"
const MODE_FAST_TRAVEL := &"fast_travel"
const PANEL_SIZE := WorldMapOverlayBuilder.PANEL_SIZE
const NODE_SIZE := WorldMapOverlayBuilder.NODE_SIZE
const LOCAL_MARKER_SIZE := WorldMapOverlayBuilder.LOCAL_MARKER_SIZE
const TRAVEL_NODE_COLOR := Color(0.92, 0.96, 1.0, 1.0)
const TRAVEL_FOCUS_COLOR := Color(1.0, 0.78, 0.28, 1.0)

var _current_scene_id: StringName = &""
var _scene_ids: Array[StringName] = []
var _connections: Array[Dictionary] = []
var _positions: Dictionary = {}
var _travelable: Dictionary = {}
var _mode: StringName = MODE_LOCAL
var _local_map: MinimapHud
var _local_texture: ImageTexture

var _title: Label
var _subtitle: Label
var _local_host: Control
var _local_texture_rect: TextureRect
var _local_marker: Panel
var _local_unavailable: Label
var _graph_host: Control
var _local_tab: Button
var _fast_travel_tab: Button
var _close_button: Button
var _help: Label


func configure(current_scene_id: StringName = &"", local_map: MinimapHud = null) -> void:
	_current_scene_id = current_scene_id
	_local_map = local_map
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
		_rebuild_local_map()
		_rebuild_graph()
		_apply_mode()


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_rebuild_local_map()
	_rebuild_graph()
	_apply_mode()
	set_process(true)


func _process(_delta: float) -> void:
	if visible and _mode == MODE_LOCAL:
		_update_local_marker()


func open() -> void:
	visible = true
	_rebuild_local_map()
	_rebuild_graph()
	show_local_map()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_mode() -> StringName:
	return _mode


func show_local_map() -> void:
	_set_mode(MODE_LOCAL)


func show_fast_travel() -> void:
	_set_mode(MODE_FAST_TRAVEL)


func get_local_map_marker() -> Control:
	return _local_marker


func get_local_map_texture() -> TextureRect:
	return _local_texture_rect


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
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		if activate_focused_travel():
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var nodes := WorldMapOverlayBuilder.build(self, {
		"close": close,
		"show_local_map": show_local_map,
		"show_fast_travel": show_fast_travel,
		"draw_connections": _draw_connections,
	})
	_title = nodes["title"]
	_subtitle = nodes["subtitle"]
	_local_host = nodes["local_host"]
	_local_texture_rect = nodes["local_texture_rect"]
	_local_marker = nodes["local_marker"]
	_local_unavailable = nodes["local_unavailable"]
	_graph_host = nodes["graph_host"]
	_local_tab = nodes["local_tab"]
	_fast_travel_tab = nodes["fast_travel_tab"]
	_close_button = nodes["close_button"]
	_help = nodes["help"]


func _set_mode(mode: StringName) -> void:
	if mode != MODE_LOCAL and mode != MODE_FAST_TRAVEL:
		return
	_mode = mode
	_apply_mode()


func _apply_mode() -> void:
	if _local_host == null or _graph_host == null:
		return
	var local_selected := _mode == MODE_LOCAL
	_local_host.visible = local_selected
	_graph_host.visible = not local_selected
	_local_tab.disabled = local_selected
	_fast_travel_tab.disabled = not local_selected
	if local_selected:
		_title.text = "Local map"
		_subtitle.text = _local_subtitle()
		_help.text = "Your live position is marked in red. Choose Fast travel for connected districts. Press M or Escape to close."
		_update_local_marker()
		if visible:
			_fast_travel_tab.grab_focus()
	else:
		_title.text = "Fast travel"
		_subtitle.text = _subtitle_for_current()
		_help.text = (
			"Click or focus a connected district, then Confirm to travel. "
			+ "Arrow keys / D-pad move focus between linked districts. "
			+ "Your current district stays marked and cannot be selected. "
			+ "Choose Local map to return, or press M / Escape to close."
		)
		_grab_initial_focus()


func _rebuild_local_map() -> void:
	if _local_texture_rect == null:
		return
	_local_texture = null
	_local_texture_rect.texture = null
	var available := _local_map != null and is_instance_valid(_local_map) and _local_map.has_map_data()
	_local_unavailable.visible = not available
	_local_texture_rect.visible = available
	_local_marker.visible = available
	if not available:
		return
	var image := _local_map.get_local_map_image()
	if image == null or image.is_empty():
		_local_unavailable.visible = true
		_local_texture_rect.visible = false
		_local_marker.visible = false
		return
	_local_texture = ImageTexture.create_from_image(image)
	_local_texture_rect.texture = _local_texture
	var area := _local_host.size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(PANEL_SIZE.x - 40.0, 420.0)
	var scale_factor := minf(area.x / float(image.get_width()), area.y / float(image.get_height()))
	var display_size := Vector2(image.get_width(), image.get_height()) * scale_factor
	_local_texture_rect.position = (area - display_size) * 0.5
	_local_texture_rect.size = display_size
	_update_local_marker()


func _update_local_marker() -> void:
	if _local_marker == null or _local_texture_rect == null:
		return
	var available := (
		_mode == MODE_LOCAL
		and _local_map != null
		and is_instance_valid(_local_map)
		and _local_map.has_map_data()
		and _local_texture_rect.texture != null
	)
	if not available:
		_local_marker.visible = false
		return
	var normalized := _local_map.get_player_map_position()
	if normalized.x < 0.0 or normalized.y < 0.0:
		_local_marker.visible = false
		return
	_local_marker.visible = true
	_local_marker.position = (
		_local_texture_rect.position
		+ normalized * _local_texture_rect.size
		- LOCAL_MARKER_SIZE * 0.5
	)


func _local_subtitle() -> String:
	if _local_map != null and is_instance_valid(_local_map):
		var location_name := _local_map.get_location_name()
		if not location_name.is_empty():
			return "You are here: %s" % location_name
	if not _current_scene_id.is_empty():
		return "You are here: %s" % LocationHud.display_name_for_scene(_current_scene_id)
	return "Current location is outside the active map registry."


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
			button.modulate = TRAVEL_NODE_COLOR
			# WHY (P1-031c): the default theme focus can be too subtle against the
			# dim map. A thick warm outline makes the Confirm destination explicit
			# without reusing the current-scene node's gold fill.
			button.add_theme_stylebox_override("focus", _travel_focus_style())
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
