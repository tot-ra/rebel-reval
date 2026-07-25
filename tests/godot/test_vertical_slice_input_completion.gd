extends "res://tests/godot/vertical_slice_input_harness.gd"

## P2-017: recorded keyboard/mouse and gamepad runs for every slice input action.

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const MinimapHudScript := preload("res://scripts/ui/minimap_hud.gd")


func test_catalog_actions_fire_keyboard_mouse_events_without_fallback() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.KEYBOARD_MOUSE)
	for action: StringName in InputCatalog.action_ids():
		driver.tap_action(action)
		assert_true(
			_bindings_recognize_action(action, BindingSettings.DEVICE_KEYBOARD_MOUSE),
			"%s must map through keyboard/mouse events" % String(action)
		)
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)


func test_catalog_actions_fire_gamepad_events_without_fallback() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.GAMEPAD)
	var bindings := BindingSettings.default_settings()
	for action: StringName in InputCatalog.action_ids():
		driver.tap_action(action)
		var events := bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD)
		assert_false(events.is_empty(), "%s needs a gamepad binding" % String(action))
		var primary := events[0]
		if primary is InputEventJoypadMotion:
			var motion := primary as InputEventJoypadMotion
			assert_true(absf(motion.axis_value) >= 0.5, "%s needs a full stick deflection" % String(action))
		else:
			assert_true(
				_bindings_recognize_action(action, BindingSettings.DEVICE_GAMEPAD),
				"%s must map through gamepad events" % String(action)
			)
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)


func test_player_overlay_toggles_via_keyboard_mouse_events() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.KEYBOARD_MOUSE)
	var player := _mount_player()
	var inventory := player.get_node("InventoryController") as InventoryController
	var journal := player.get_node("JournalController") as JournalController
	var world_map := player.get_node("WorldMapController") as WorldMapController

	await _toggle_player_overlay_via_input(
		driver,
		player,
		&"toggle_inventory",
		inventory.is_open
	)
	await _toggle_player_overlay_via_input(driver, player, &"toggle_journal", journal.is_open)
	await _toggle_player_overlay_via_input(driver, player, &"toggle_world_map", world_map.is_open)

	var minimap := MinimapHudScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(minimap)
	await _toggle_player_overlay_via_input(driver, player, &"toggle_minimap", minimap.is_open)
	minimap.free()

	driver.tap_action(&"toggle_controls")
	await _settle_frames(1)
	var controls := (Engine.get_main_loop() as SceneTree).root.find_child("ControlsOverlay", true, false)
	if controls != null:
		controls.queue_free()
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)
	player.free()


func test_player_overlay_toggles_via_gamepad_events() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.GAMEPAD)
	var player := _mount_player()
	var inventory := player.get_node("InventoryController") as InventoryController
	var journal := player.get_node("JournalController") as JournalController
	var world_map := player.get_node("WorldMapController") as WorldMapController

	await _toggle_player_overlay_via_input(
		driver,
		player,
		&"toggle_inventory",
		inventory.is_open
	)
	await _toggle_player_overlay_via_input(driver, player, &"toggle_journal", journal.is_open)
	await _toggle_player_overlay_via_input(driver, player, &"toggle_world_map", world_map.is_open)
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used)
	player.free()


func test_honest_branch_completes_via_keyboard_mouse_input() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.KEYBOARD_MOUSE)
	await _run_honest_branch_via_input(driver)
	var branch := FlowModel.branch_for_id(&"honest")
	assert_true(FlowModel.validate_branch_terminal_state(SessionState.state, branch))


func test_honest_branch_completes_via_gamepad_input() -> void:
	var driver := _make_driver(SliceInputDriver.DeviceProfile.GAMEPAD)
	await _run_honest_branch_via_input(driver)
	var branch := FlowModel.branch_for_id(&"honest")
	assert_true(FlowModel.validate_branch_terminal_state(SessionState.state, branch))


func _mount_player() -> Player:
	_ensure_session()
	var player := PLAYER_SCENE.instantiate() as Player
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	return player


func _ensure_session() -> void:
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _bindings_recognize_action(action: StringName, device: StringName) -> bool:
	var bindings := BindingSettings.default_settings()
	for event: InputEvent in bindings.events_for(action, device):
		var sample := event.duplicate() as InputEvent
		if sample is InputEventJoypadMotion:
			var motion := sample as InputEventJoypadMotion
			motion.axis_value = 1.0 if motion.axis_value >= 0.0 else -1.0
			Input.parse_input_event(motion)
			if Input.is_action_pressed(action):
				var released := motion.duplicate() as InputEventJoypadMotion
				released.axis_value = 0.0
				Input.parse_input_event(released)
				return true
			continue
		sample.pressed = true
		if sample.is_action(action):
			return true
	return false
