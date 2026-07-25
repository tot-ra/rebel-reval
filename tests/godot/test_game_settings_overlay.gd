extends "res://tests/godot/test_case.gd"

const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")
const ControllerScript := preload("res://scripts/ui/game_settings_controller.gd")
const OverlayScript := preload("res://scripts/ui/game_settings_overlay.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")


func before_each() -> void:
	_cleanup_temp_dir()
	_redirect_user_settings_store()


func after_each() -> void:
	_cleanup_temp_dir()
	UserSettings.reload_audio_settings()
	UserSettings.reload_dialogue_settings()


func test_overlay_starts_hidden_and_esc_closes_when_open() -> void:
	var controller = await _make_controller()
	assert_false(controller.is_open())
	controller.open()
	assert_true(controller.is_open())
	controller._unhandled_input(_cancel_event())
	assert_false(controller.is_open())
	controller.queue_free()


func test_esc_opens_settings_when_no_modal_is_active() -> void:
	var controller = await _make_controller()
	controller._unhandled_input(_cancel_event())
	assert_true(controller.is_open(), "Esc must open settings when gameplay is idle")
	controller.queue_free()


func test_esc_does_not_open_while_dialogue_modal_group_is_active() -> void:
	var controller = await _make_controller()
	var blocker := Node.new()
	blocker.add_to_group(&"demo_dialogue_active")
	_tree().root.add_child(blocker)
	controller._unhandled_input(_cancel_event())
	assert_false(controller.is_open(), "Esc must not open settings during dialogue")
	blocker.queue_free()
	controller.queue_free()


func test_esc_does_not_open_while_inventory_is_open() -> void:
	var host := Node.new()
	var inventory := InventoryController.new()
	inventory.name = "InventoryController"
	host.add_child(inventory)
	var controller := ControllerScript.new()
	controller.name = "GameSettingsController"
	host.add_child(controller)
	_tree().root.add_child(host)
	inventory.open()
	controller._unhandled_input(_cancel_event())
	assert_false(controller.is_open(), "Esc must not open settings while inventory is open")
	host.queue_free()


func test_volume_slider_changes_persist_through_user_settings() -> void:
	var overlay := OverlayScript.new()
	overlay.configure(UserSettings)
	_tree().root.add_child(overlay)
	overlay.open()

	overlay._on_music_changed(25.0)
	overlay._on_sfx_changed(60.0)

	assert_true(is_equal_approx(UserSettings.audio.music_volume, 0.25))
	assert_true(is_equal_approx(UserSettings.audio.sfx_volume, 0.6))
	var loaded = UserSettings.store.load_audio_settings()
	assert_true(is_equal_approx(loaded.music_volume, 0.25))
	assert_true(is_equal_approx(loaded.sfx_volume, 0.6))

	var music_index := AudioServer.get_bus_index(String(AudioBusServiceScript.BUS_MUSIC))
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(music_index), linear_to_db(0.25)))
	overlay.queue_free()


func test_dialogue_accessibility_changes_persist_through_user_settings() -> void:
	var overlay := OverlayScript.new()
	overlay.configure(UserSettings)
	_tree().root.add_child(overlay)
	overlay.open()

	overlay._on_text_scale_selected(2)
	overlay._on_text_speed_selected(1)
	overlay._on_high_contrast_toggled(true)
	overlay._on_subtitle_background_toggled(false)
	overlay._on_reduced_motion_toggled(true)

	assert_eq(UserSettings.dialogue.text_scale, "large")
	assert_eq(UserSettings.dialogue.text_speed, "normal")
	assert_true(UserSettings.dialogue.high_contrast)
	assert_false(UserSettings.dialogue.subtitle_background)
	assert_true(UserSettings.dialogue.reduced_motion)

	var loaded = UserSettings.store.load_dialogue_settings()
	assert_eq(loaded.text_scale, "large")
	assert_true(loaded.high_contrast)
	assert_true(loaded.reduced_motion)
	overlay.queue_free()


func test_opening_settings_closes_inventory_overlay() -> void:
	var host := Node.new()
	var inventory := InventoryController.new()
	inventory.name = "InventoryController"
	host.add_child(inventory)
	var controller := ControllerScript.new()
	controller.name = "GameSettingsController"
	host.add_child(controller)
	_tree().root.add_child(host)

	inventory.open()
	assert_true(inventory.is_open())
	controller.open()
	assert_false(inventory.is_open(), "settings must close competing overlays")
	assert_true(controller.is_open())
	host.queue_free()


func _make_controller():
	var host := Node.new()
	var controller = ControllerScript.new()
	controller.name = "GameSettingsController"
	host.add_child(controller)
	_tree().root.add_child(host)
	await _tree().process_frame
	return controller


func _cancel_event() -> InputEvent:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func _redirect_user_settings_store() -> void:
	UserSettings.store.settings_directory = _temp_dir("game_settings")


func _temp_dir(prefix: String) -> String:
	return "user://test_%s_%d" % [prefix, Time.get_ticks_msec()]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_temp_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry.begins_with("test_game_settings_"):
			_remove_tree("user://%s" % entry)
		entry = root.get_next()
	root.list_dir_end()


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path.trim_suffix("/"), entry]
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
