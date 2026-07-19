class_name WorldItemController
extends Node

## Cursor-driven pickup and drop for world items. Pickups show a persistent
## yellow outline; hover brightens it and shows a tooltip. Left click picks up
## when the bag has room, or drops a selected inventory item when the bag overlay
## is open.

const WORLD_ITEM_SCENE := preload("res://scenes/world/world_item.tscn")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const OverlayScript := preload("res://scripts/world/world_item_overlay.gd")
const PickupLabelsScript := preload("res://scripts/world/world_item_pickup_labels.gd")

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
var _interactables: Dictionary = {}
var _interactable_binder: InteractableViewBinder
var _hovered: WorldItem = null
var _overlay: WorldItemOverlay


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
	_overlay = OverlayScript.new()
	_overlay.name = "WorldItemOverlay"
	add_child(_overlay)
	_items_root = Node2D.new()
	_items_root.name = "WorldItems"
	_scene_root.add_child(_items_root)
	if view_runtime != null:
		_interactable_binder = InteractableViewBinder.new()
		_interactable_binder.name = "WorldItemInteractableViewBinder"
		add_child(_interactable_binder)
		_interactable_binder.setup(view_runtime, definition)
	_seed_defaults_if_needed()
	_sync_from_state()
	if not SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.connect(_on_debug_state_applied)


func _exit_tree() -> void:
	if SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.disconnect(_on_debug_state_applied)
	if _overlay != null:
		_overlay.restore_cursor()


func _on_debug_state_applied(_preset_id: StringName) -> void:
	# SessionState replaces the live GameState; rebind and rebuild world props in place.
	_state = SessionState.state
	_sync_from_state()


func _process(delta: float) -> void:
	if _overlay != null:
		_overlay.tick(delta)
	_update_hover()
	if _overlay != null:
		_overlay.update_cursor(_hovered != null and not _is_inventory_blocking_pickup())
	_update_interactable_prompts()
	_sync_interactable_enabled()
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


func is_pickup_hover_active() -> bool:
	return _overlay != null and _overlay.cursor_over_pickup


func _seed_defaults_if_needed() -> void:
	if _state == null or _definition == null:
		return
	if _state.are_world_defaults_seeded(location_id):
		return
	if not _state.get_world_items(location_id).is_empty():
		_state.mark_world_defaults_seeded(location_id)
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
	if not entries.is_empty():
		_state.mark_world_defaults_seeded(location_id)


func _sync_from_state() -> void:
	_clear_items()
	if _state == null:
		return
	for record: Dictionary in _state.get_world_items(location_id):
		_spawn_item(record)


func set_prop_visibility(object_id: StringName, visible_state: bool) -> void:
	for item: WorldItem in _views.keys():
		if item.get_world_object_id() != object_id:
			continue
		item.visible = visible_state
		var view: WorldItemView = _views.get(item)
		if view != null and is_instance_valid(view):
			view.visible = visible_state
		var interactable: Interactable = _interactables.get(item)
		if interactable != null and is_instance_valid(interactable):
			interactable.visible = visible_state
			if visible_state:
				_refresh_interactable_prompt(interactable, item)
			else:
				interactable.disable_interaction()


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
		item.set_3d_presentation(true)

	if _view_runtime != null:
		var view := WorldItemView.new()
		view.name = "View_%s" % String(object_id).replace(".", "_")
		var scene_path := _item_scene_path(item_id)
		var item_scene: PackedScene = load(scene_path) if not scene_path.is_empty() else null
		view.configure(item_scene, position, _definition.cell_size)
		_view_runtime.add_child(view)
		_views[item] = view

	_spawn_pickup_interactable(item)


func _spawn_pickup_interactable(item: WorldItem) -> void:
	var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
	interactable.name = "Pickup_%s" % String(item.get_world_object_id()).replace(".", "_")
	interactable.interactable_id = StringName("interact.pickup.%s" % String(item.get_world_object_id()))
	interactable.interaction_kind = InteractionKinds.PICKUP
	interactable.global_position = item.global_position
	interactable.set_interact_callback(_on_pickup_interact.bind(item))
	_items_root.add_child(interactable)
	_interactables[item] = interactable
	if _interactable_binder != null:
		_interactable_binder.bind(interactable)
	_refresh_interactable_prompt(interactable, item)


func _clear_items() -> void:
	_hovered = null
	for item: WorldItem in _interactables.keys():
		var interactable: Interactable = _interactables.get(item)
		if interactable != null and is_instance_valid(interactable):
			if _interactable_binder != null:
				_interactable_binder.unbind(interactable)
			interactable.disable_interaction()
			interactable.free()
	_interactables.clear()
	for item: WorldItem in _views.keys():
		var view: WorldItemView = _views[item]
		if is_instance_valid(view):
			view.free()
	_views.clear()
	for child in _items_root.get_children():
		child.free()


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
	if _overlay == null or _hovered == null:
		if _overlay != null:
			_overlay.update_tooltip(null, _is_inventory_blocking_pickup(), "", "", Vector2.ZERO)
		return
	var record := _item_record(_hovered.get_item_id())
	var name_text := String(record.get("name", String(_hovered.get_item_id())))
	var action := _pickup_hint_for(_hovered.get_item_id())
	_overlay.update_tooltip(
		_hovered,
		_is_inventory_blocking_pickup(),
		name_text,
		action,
		get_viewport().get_mouse_position()
	)


func _pickup_hint_for(item_id: StringName) -> String:
	if _state == null:
		return PickupLabelsScript.label_for(InventoryBag.AddResult.UNKNOWN_ITEM)
	return PickupLabelsScript.label_for(_state.bag.check_add(item_id))


func _try_pickup(item: WorldItem) -> bool:
	if _state == null or item == null:
		return false
	var item_id := item.get_item_id()
	var result := _state.bag.try_add(item_id)
	if result != InventoryBag.AddResult.OK:
		if _overlay != null:
			_overlay.show_feedback(PickupLabelsScript.label_for(result))
		return true
	_state.add_item(item_id)
	_state.take_world_item(location_id, item.get_world_object_id())
	var record := _item_record(item_id)
	var name_text := String(record.get("name", String(item_id)))
	if _overlay != null:
		_overlay.show_feedback("Picked up %s" % name_text)
		_overlay.play_pickup_sfx(record)
		_overlay.show_pickup_bark(_overlay.resolve_pickup_feedback(item_id, record, _content_db, _state, location_id))
	_remove_pickup_interactable(item)
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


func _on_pickup_interact(_actor: Node, item: WorldItem) -> void:
	if _is_inventory_blocking_pickup():
		return
	_try_pickup(item)


func _remove_pickup_interactable(item: WorldItem) -> void:
	var interactable: Interactable = _interactables.get(item)
	if interactable != null and is_instance_valid(interactable):
		if _interactable_binder != null:
			_interactable_binder.unbind(interactable)
		interactable.disable_interaction()
		interactable.queue_free()
	_interactables.erase(item)


func _refresh_interactable_prompt(interactable: Interactable, item: WorldItem) -> void:
	if interactable == null or item == null:
		return
	var record := _item_record(item.get_item_id())
	var name_text := String(record.get("name", String(item.get_item_id())))
	var action := _pickup_hint_for(item.get_item_id())
	if _overlay != null and not _overlay.feedback_text.is_empty() and _hovered == item:
		action = _overlay.feedback_text
	interactable.prompt = "%s - %s" % [name_text, action]


func _update_interactable_prompts() -> void:
	for item: WorldItem in _interactables.keys():
		if not is_instance_valid(item):
			continue
		var interactable: Interactable = _interactables[item]
		if interactable == null or not is_instance_valid(interactable):
			continue
		_refresh_interactable_prompt(interactable, item)


func _sync_interactable_enabled() -> void:
	var blocked := _is_inventory_blocking_pickup()
	for item: WorldItem in _interactables.keys():
		var interactable: Interactable = _interactables.get(item)
		if interactable == null or not is_instance_valid(interactable):
			continue
		interactable.enabled = not blocked
