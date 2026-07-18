class_name WorldItemController
extends Node

## Cursor-driven pickup and drop for world items. Hover shows a contour outline
## and tooltip; left click picks up when the bag has room, or drops a selected
## inventory item when the bag overlay is open.

const WORLD_ITEM_SCENE := preload("res://scenes/world/world_item.tscn")

const DEFAULT_PLACEMENTS: Dictionary = {
	&"loc.kalev_smithy": [
		{
			"object_id": &"world.spearhead_anvil",
			"item_id": &"item.seized_spearhead",
			"anchor_id": &"anvil",
			"offset": Vector2(24.0, 8.0),
		},
	],
}

var location_id: StringName = &""
var _scene_root: Node2D
var _definition: MapDefinition
var _view_runtime: MapViewRuntime
var _player: Player
var _state: GameState
var _content_db: ContentDB
var _items_root: Node2D
var _views: Dictionary = {}
var _hovered: WorldItem = null
var _tooltip: Label
var _tooltip_layer: CanvasLayer
var _feedback_timer := 0.0
var _feedback_text := ""


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	view_runtime: MapViewRuntime,
	player: Player,
	map_location_id: StringName
) -> void:
	_scene_root = scene_root
	_definition = definition
	_view_runtime = view_runtime
	_player = player
	location_id = map_location_id
	_state = SessionState.state
	_content_db = SessionState.content_db
	_build_ui()
	_items_root = Node2D.new()
	_items_root.name = "WorldItems"
	_scene_root.add_child(_items_root)
	_seed_defaults_if_needed()
	_sync_from_state()


func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer = maxf(0.0, _feedback_timer - delta)
		if _feedback_timer <= 0.0:
			_feedback_text = ""
	_update_hover()
	_update_tooltip()


func try_handle_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return false
	if _player == null or _view_runtime == null:
		return false
	if _is_inventory_blocking_pickup():
		return _try_drop_from_inventory(_logic_at_screen(mouse_button.position))

	var logic_position := _logic_at_screen(mouse_button.position)
	var item := _find_item_at(logic_position)
	if item == null:
		return false
	return _try_pickup(item)


func get_hovered_item() -> WorldItem:
	return _hovered


func _seed_defaults_if_needed() -> void:
	if _state == null or _definition == null:
		return
	if not _state.get_world_items(location_id).is_empty():
		return
	var entries: Array = DEFAULT_PLACEMENTS.get(location_id, [])
	for entry: Dictionary in entries:
		var object_id: StringName = entry.get("object_id", &"")
		var item_id: StringName = entry.get("item_id", &"")
		if object_id.is_empty() or item_id.is_empty():
			continue
		if _state.is_world_item_placed(location_id, object_id):
			continue
		var anchor_id: StringName = entry.get("anchor_id", &"")
		var position := MapVerification.anchor_position(_definition, anchor_id)
		position += entry.get("offset", Vector2.ZERO)
		_state.place_world_item(location_id, object_id, item_id, position)


func _sync_from_state() -> void:
	_clear_items()
	if _state == null:
		return
	for record: Dictionary in _state.get_world_items(location_id):
		_spawn_item(record)


func _spawn_item(record: Dictionary) -> void:
	var object_id := StringName(String(record.get("object_id", "")))
	var item_id := StringName(String(record.get("item_id", "")))
	var position: Vector2 = record.get("position", Vector2.ZERO)
	if object_id.is_empty() or item_id.is_empty():
		return

	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(object_id, item_id, location_id, position)
	_items_root.add_child(item)

	if _view_runtime != null:
		var view := WorldItemView.new()
		view.name = "View_%s" % String(object_id).replace(".", "_")
		var scene_path := _item_scene_path(item_id)
		var item_scene: PackedScene = load(scene_path) if not scene_path.is_empty() else null
		view.configure(item_scene, position, _definition.cell_size)
		_view_runtime.add_child(view)
		_views[item] = view


func _clear_items() -> void:
	for item: WorldItem in _views.keys():
		var view: WorldItemView = _views[item]
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	for child in _items_root.get_children():
		child.queue_free()


func _update_hover() -> void:
	var logic_position := _logic_at_screen(get_viewport().get_mouse_position())
	var next := _find_item_at(logic_position)
	if _hovered == next:
		return
	if _hovered != null:
		_hovered.set_hovered(false)
		_set_view_hovered(_hovered, false)
	_hovered = next
	if _hovered != null:
		_hovered.set_hovered(true)
		_set_view_hovered(_hovered, true)


func _set_view_hovered(item: WorldItem, value: bool) -> void:
	var view: WorldItemView = _views.get(item)
	if view != null and is_instance_valid(view):
		view.set_hovered(value)


func _update_tooltip() -> void:
	if _tooltip == null:
		return
	if _hovered == null or _is_inventory_blocking_pickup():
		_tooltip.visible = false
		_tooltip.text = ""
		return

	var record := _item_record(_hovered.get_item_id())
	var name_text := String(record.get("name", String(_hovered.get_item_id())))
	var action := _pickup_hint_for(_hovered.get_item_id())
	if not _feedback_text.is_empty():
		action = _feedback_text
	_tooltip.visible = true
	_tooltip.text = "%s\n%s" % [name_text, action]
	_tooltip.global_position = get_viewport().get_mouse_position() + Vector2(18.0, 18.0)


func _pickup_hint_for(item_id: StringName) -> String:
	if _state == null:
		return _pickup_result_label(InventoryBag.AddResult.UNKNOWN_ITEM)
	return _pickup_result_label(_state.bag.check_add(item_id))


func _try_pickup(item: WorldItem) -> bool:
	if _state == null or item == null:
		return false
	var item_id := item.get_item_id()
	var result := _state.bag.try_add(item_id)
	if result != InventoryBag.AddResult.OK:
		_show_feedback(_pickup_result_label(result))
		return true
	_state.add_item(item_id)
	_state.take_world_item(location_id, item.get_world_object_id())
	var view: WorldItemView = _views.get(item)
	if view != null and is_instance_valid(view):
		view.queue_free()
	_views.erase(item)
	item.queue_free()
	if _hovered == item:
		_hovered = null
	return true


func _try_drop_from_inventory(logic_position: Vector2) -> bool:
	var controller := _player.get_node_or_null("InventoryController") as InventoryController
	if controller == null or not controller.is_open():
		return false
	var placement := controller.get_selected_placement()
	if placement == null:
		return false
	return _drop_placement(placement, logic_position)


func _drop_placement(placement: InventoryPlacement, logic_position: Vector2) -> bool:
	if _state == null or placement == null:
		return false
	var item_id := placement.item_id
	if not _state.bag.remove(placement):
		return false

	var object_id := _next_drop_object_id(item_id)
	if not _state.place_world_item(location_id, object_id, item_id, logic_position):
		_state.bag.try_add(item_id)
		return false

	var controller := _player.get_node_or_null("InventoryController") as InventoryController
	if controller != null:
		controller.clear_selection()

	_spawn_item({
		"object_id": object_id,
		"item_id": item_id,
		"position": logic_position,
	})
	return true


func _next_drop_object_id(item_id: StringName) -> StringName:
	var suffix := 0
	var base := "world.dropped.%s" % String(item_id)
	while _state.is_world_item_placed(location_id, StringName("%s.%d" % [base, suffix])):
		suffix += 1
	return StringName("%s.%d" % [base, suffix])


func _find_item_at(logic_position: Vector2) -> WorldItem:
	var best: WorldItem = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"world_item"):
		var item := node as WorldItem
		if item == null or item.location_id != location_id:
			continue
		if not item.contains_logic_point(logic_position):
			continue
		var distance := item.global_position.distance_squared_to(logic_position)
		if distance < best_distance:
			best_distance = distance
			best = item
	return best


func _logic_at_screen(screen_position: Vector2) -> Vector2:
	if _view_runtime != null:
		return _view_runtime.logic_position_at_screen(screen_position)
	return screen_position


func _is_inventory_blocking_pickup() -> bool:
	var controller := _player.get_node_or_null("InventoryController") as InventoryController
	return controller != null and controller.is_open()


func _item_scene_path(item_id: StringName) -> String:
	var record := _item_record(item_id)
	var gameplay: Dictionary = record.get("gameplay", {})
	var equip_info: Dictionary = gameplay.get("equip", {})
	return String(equip_info.get("scene", ""))


func _item_record(item_id: StringName) -> Dictionary:
	if _content_db != null and _content_db.is_loaded():
		var record := _content_db.get_item(item_id)
		if not record.is_empty():
			return record
	return {"name": String(item_id)}


func _pickup_result_label(result: InventoryBag.AddResult) -> String:
	match result:
		InventoryBag.AddResult.OK:
			return "Pick up"
		InventoryBag.AddResult.NO_SPACE:
			return "Bag is full"
		InventoryBag.AddResult.OVER_WEIGHT:
			return "Too heavy to carry"
		InventoryBag.AddResult.STACK_FULL:
			return "Stack is full"
		_:
			return "Cannot pick up"


func _show_feedback(message: String) -> void:
	_feedback_text = message
	_feedback_timer = 1.4


func _build_ui() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 30
	add_child(_tooltip_layer)
	_tooltip = Label.new()
	_tooltip.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9, 1.0))
	_tooltip.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_tooltip.add_theme_constant_override("outline_size", 4)
	_tooltip.visible = false
	_tooltip_layer.add_child(_tooltip)
