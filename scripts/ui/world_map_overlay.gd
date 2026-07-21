class_name WorldMapOverlay
extends CanvasLayer

## Public full-screen map facade. Focused child views own local-map and
## fast-travel presentation; this facade owns modes and validated travel intent.

const WorldMapOverlayBuilder := preload("res://scripts/ui/world_map_overlay_builder.gd")
const LocalMapView := preload("res://scripts/ui/world_map_local_view.gd")
const FastTravelView := preload("res://scripts/ui/world_map_fast_travel_view.gd")

signal closed()
signal travel_requested(scene_id: StringName, spawn_id: StringName)

const MODE_LOCAL := &"local"
const MODE_FAST_TRAVEL := &"fast_travel"
const PANEL_SIZE := WorldMapOverlayBuilder.PANEL_SIZE
const NODE_SIZE := Vector2(132, 44)
const LOCAL_MARKER_SIZE := Vector2(16, 16)
const TRAVEL_NODE_COLOR := Color(0.92, 0.96, 1.0, 1.0)
const TRAVEL_FOCUS_COLOR := Color(1.0, 0.78, 0.28, 1.0)

var _current_scene_id: StringName = &""
var _scene_ids: Array[StringName] = []
var _connections: Array[Dictionary] = []
var _positions: Dictionary = {}
var _travelable: Dictionary = {}
var _mode: StringName = MODE_LOCAL
var _local_map: MinimapHud

var _title: Label
var _subtitle: Label
var _local_view: LocalMapView
var _fast_travel_view: FastTravelView
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
		_configure_views()
		_apply_mode()


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_configure_views()
	_apply_mode()


func open() -> void:
	visible = true
	_configure_views()
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
	if _local_view == null:
		return null
	return _local_view.get_marker()


func get_local_map_texture() -> TextureRect:
	if _local_view == null:
		return null
	return _local_view.get_texture_rect()


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
	if _fast_travel_view == null:
		return null
	return _fast_travel_view.get_node_button(scene_id)


## Returns a validated travel payload without calling DoorNavigator.
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


func focus_travel_node(destination_scene_id: StringName) -> bool:
	if _fast_travel_view == null:
		return false
	return _fast_travel_view.focus_travel_node(destination_scene_id)


func activate_focused_travel() -> bool:
	if _fast_travel_view == null:
		return false
	return _fast_travel_view.activate_focused_travel()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept") and activate_focused_travel():
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var nodes := WorldMapOverlayBuilder.build(self, {
		"close": close,
		"show_local_map": show_local_map,
		"show_fast_travel": show_fast_travel,
	})
	_title = nodes["title"]
	_subtitle = nodes["subtitle"]
	_local_view = nodes["local_view"]
	_fast_travel_view = nodes["fast_travel_view"]
	_local_tab = nodes["local_tab"]
	_fast_travel_tab = nodes["fast_travel_tab"]
	_close_button = nodes["close_button"]
	_help = nodes["help"]
	_fast_travel_view.destination_requested.connect(request_travel_to)


func _configure_views() -> void:
	if _local_view == null or _fast_travel_view == null:
		return
	_local_view.configure(_local_map, _current_scene_id)
	_fast_travel_view.configure(
		_current_scene_id,
		_scene_ids,
		_connections,
		_positions,
		_travelable
	)


func _set_mode(mode: StringName) -> void:
	if mode != MODE_LOCAL and mode != MODE_FAST_TRAVEL:
		return
	_mode = mode
	_apply_mode()


func _apply_mode() -> void:
	if _local_view == null or _fast_travel_view == null:
		return
	var local_selected := _mode == MODE_LOCAL
	_local_view.visible = local_selected
	_fast_travel_view.visible = not local_selected
	_local_tab.disabled = local_selected
	_fast_travel_tab.disabled = not local_selected
	if local_selected:
		_title.text = "Local map"
		_subtitle.text = _local_view.subtitle()
		_help.text = _local_view.help_text()
		_local_view.update_marker()
		if visible:
			_fast_travel_tab.grab_focus()
	else:
		_title.text = "Fast travel"
		_subtitle.text = _fast_travel_view.subtitle()
		_help.text = _fast_travel_view.help_text()
		_fast_travel_view.grab_initial_focus(_close_button)
