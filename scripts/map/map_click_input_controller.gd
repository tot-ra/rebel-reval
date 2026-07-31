class_name MapClickInputController
extends Node

## Central primary-click (left mouse) routing for map scenes.
##
## The meaning of a click depends on the camera mode, because the pointer means
## different things in each:
## - First/third person: the character aims. A hostile in front answers with an
##   attack, a neutral/quest character, chest, body, or loose item answers with
##   dialogue/pickup/use, and empty ground answers with a swing. There is no
##   click-to-move here; WASD drives locomotion.
## - Top-down: the cursor really points at the ground, so clicks stay
##   pickup -> interact -> click-to-move, and a click on a hostile attacks when
##   it is already within reach.
##
## Scenes opt into world-item and prompt controllers through
## MapViewRuntime.configure_click_input(). Right mouse stays defense (guard) and
## camera orbit; see docs/CONTROLS.md.

var _player: Player
var _view_runtime: MapViewRuntime
var _world_items: WorldItemController
var _pending_interactable: Interactable
## Charged techniques swing on release, so the primary button has to be tracked
## across press and release instead of firing once on press.
var _attack_charge_active := false
var _attack_charge_started_msec := 0


func setup(player: Player, view_runtime: MapViewRuntime) -> void:
	_player = player
	_view_runtime = view_runtime
	# Gameplay clicks must be observed before passive HUD Controls consume them.
	# _input still yields to focusable controls such as quick-access buttons.
	set_process_input(true)
	set_physics_process(true)


func set_world_items(controller: WorldItemController) -> void:
	_world_items = controller


func try_handle_click(event: InputEvent) -> bool:
	if not _is_left_click(event):
		return false
	if _player == null or _view_runtime == null:
		return false
	if _view_runtime.is_camera_drag_active():
		return false
	# WHY: while the bag is open, locomotion is blocked, but selected goods can
	# still be dropped into the world. Do that before the general blocked-input
	# gate; bag chrome itself is filtered out by _control_claims_click.
	if _is_inventory_open():
		return _world_items != null and _world_items.try_handle_click(event)
	if _player.is_movement_input_blocked():
		return false
	if is_character_relative_mode():
		return _handle_character_relative_click(event)
	if _world_items != null and _world_items.try_handle_click(event):
		return true
	return try_handle_logic_click(_view_runtime.logic_position_at_screen(event.position))


## Pointer-mode click on the logic plane: attack a hostile already within reach,
## interact with (or walk up to) an interactable, otherwise move there.
func try_handle_logic_click(logic_position: Vector2) -> bool:
	if _player == null or _view_runtime == null:
		return false
	if _player.is_movement_input_blocked():
		return false
	if _view_runtime.is_camera_drag_active():
		return false

	var interactable := Interactable.find_at_logic_position(logic_position, get_tree())
	if interactable != null:
		return _handle_interactable_click(interactable)

	var hostile := _hostile_at_logic_position(logic_position)
	if hostile != null:
		return _handle_hostile_click(hostile)

	_player.request_navigation_target(logic_position)
	return true


## True while the camera is mounted on the character (first or third person),
## where the character aims instead of the cursor.
func is_character_relative_mode() -> bool:
	if _view_runtime == null:
		return false
	return not _view_runtime.is_top_down()


func _handle_character_relative_click(event: InputEvent) -> bool:
	# A loose item under the cursor is an explicit aim, so keep cursor pickup
	# working in both perspective modes before falling back to the facing cone.
	if _world_items != null and _world_items.try_handle_click(event):
		return true
	var resolution := PlayerPrimaryAction.resolve(_player, _player_facing())
	if int(resolution["intent"]) == PlayerPrimaryAction.Intent.INTERACT:
		var interactable := resolution["target"] as Interactable
		if interactable != null and interactable.interact(_player):
			return true
	return _begin_primary_attack()


func _player_facing() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	if _player.has_method("view_facing"):
		return _player.view_facing()
	return Vector2.ZERO


## Charged techniques hold the swing until the button is released; everything
## else swings immediately so the click stays responsive.
func _begin_primary_attack() -> bool:
	if _player == null:
		return false
	if _player.has_method("supports_charged_attack") and _player.supports_charged_attack():
		_attack_charge_active = true
		_attack_charge_started_msec = Time.get_ticks_msec()
		return true
	return _player.request_primary_attack()


## Releasing the primary button commits a held charge. Public so scenes and tests
## can drive the full press/release pair without going through the viewport.
func try_handle_primary_release(event: InputEvent) -> bool:
	if not _attack_charge_active:
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
		return false
	_attack_charge_active = false
	var hold_sec := float(Time.get_ticks_msec() - _attack_charge_started_msec) / 1000.0
	if _player == null or not _player.has_method("commit_attack_from_charge_hold"):
		return false
	return bool(_player.commit_attack_from_charge_hold(hold_sec))


func _input(event: InputEvent) -> void:
	if try_handle_primary_release(event):
		get_viewport().set_input_as_handled()
		return
	if not _should_route_to_gameplay(event):
		return
	if try_handle_click(event):
		get_viewport().set_input_as_handled()


func _should_route_to_gameplay(event: InputEvent) -> bool:
	if not _is_left_click(event):
		return false
	return not _control_claims_click(get_viewport().gui_get_hovered_control())


static func _control_claims_click(control: Control) -> bool:
	if control == null or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	# Containers and labels default to STOP even when they are only decorative.
	# Focusable widgets are the controls that should retain primary-click ownership.
	if control.focus_mode != Control.FOCUS_NONE:
		return true
	# Bag/journal chrome often uses FOCUS_NONE so overlay keyboard focus stays
	# custom. While that modal chrome is hovered, gameplay must not steal the
	# click or drag-and-drop never starts on grid cells.
	var node: Node = control
	while node != null:
		if node is CanvasLayer and (node as CanvasLayer).visible:
			if node is InventoryOverlay or node.is_in_group(&"modal_input_overlay"):
				return true
		node = node.get_parent()
	return false


func _is_inventory_open() -> bool:
	if _player == null:
		return false
	var inventory := _player.get_node_or_null("InventoryController") as InventoryController
	return inventory != null and inventory.is_open()


func _physics_process(_delta: float) -> void:
	_try_complete_pending_interaction()


func _handle_interactable_click(interactable: Interactable) -> bool:
	if interactable.interact(_player):
		return true
	_pending_interactable = interactable
	_player.request_navigation_target(interactable.global_position)
	return true


## Top-down aggression: swing when the clicked hostile is already in the facing
## cone and within reach, otherwise close the distance first.
func _handle_hostile_click(hostile: Node2D) -> bool:
	var offset := hostile.global_position - _player.global_position
	var in_front := PlayerPrimaryAction.find_hostile_in_front(_player, _player_facing())
	if in_front == hostile or offset.length() <= PlayerPrimaryAction.HOSTILE_SCAN_PX:
		if _player.request_primary_attack():
			return true
	_player.request_navigation_target(hostile.global_position)
	return true


func _hostile_at_logic_position(logic_position: Vector2) -> Node2D:
	const HOSTILE_CLICK_RADIUS := 72.0
	var best: Node2D = null
	var best_distance := HOSTILE_CLICK_RADIUS * HOSTILE_CLICK_RADIUS
	for candidate_node: Node in get_tree().get_nodes_in_group(PlayerPrimaryAction.DAMAGEABLE_GROUP):
		if candidate_node == _player or not candidate_node is Node2D:
			continue
		var candidate := candidate_node as Node2D
		if not candidate.has_method("take_damage") or PlayerPrimaryAction.is_defeated(candidate):
			continue
		var distance_squared := candidate.global_position.distance_squared_to(logic_position)
		if distance_squared > best_distance:
			continue
		best_distance = distance_squared
		best = candidate
	return best


func _try_complete_pending_interaction() -> void:
	if _pending_interactable == null or _player == null:
		return
	if not is_instance_valid(_pending_interactable) or not _pending_interactable.is_enabled():
		_pending_interactable = null
		return
	if not _pending_interactable.is_actor_in_range(_player):
		return
	if _pending_interactable.interact(_player):
		_pending_interactable = null


static func _is_left_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_button := event as InputEventMouseButton
	return mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed
