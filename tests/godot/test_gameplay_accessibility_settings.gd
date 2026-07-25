extends "res://tests/godot/test_case.gd"

const PlayerActionKind := preload("res://scripts/player/player_action_kind.gd")
const PlayerInputScript := preload("res://scripts/player/player_action_input.gd")
const SettingsScript := preload("res://scripts/settings/gameplay_accessibility_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")
const UiFocusThemeScript := preload("res://scripts/ui/ui_focus_theme.gd")


func before_each() -> void:
	_cleanup_temp_dir()
	PlayerInputScript.reset_guard_toggle()


func after_each() -> void:
	_cleanup_temp_dir()
	PlayerInputScript.reset_guard_toggle()
	if _tree().root.has_node("/root/UserSettings"):
		UserSettings.reload_gameplay_accessibility_settings()


func test_gameplay_accessibility_settings_round_trip_persists_all_fields() -> void:
	var store = _store()
	var settings = SettingsScript.default_settings()
	settings.guard_mode = "toggle"
	settings.screenshake_enabled = false
	settings.reduced_flashing = true
	settings.enhanced_focus_contrast = true

	assert_true(store.save_gameplay_accessibility_settings(settings))
	var loaded = store.load_gameplay_accessibility_settings()
	assert_eq(loaded.guard_mode, "toggle")
	assert_false(loaded.screenshake_enabled)
	assert_true(loaded.reduced_flashing)
	assert_true(loaded.enhanced_focus_contrast)


func test_invalid_guard_mode_normalizes_to_hold() -> void:
	var settings = SettingsScript.from_dict({"guard_mode": "unsupported"})
	settings.normalize()
	assert_eq(settings.guard_mode, "hold")
	assert_true(settings.guard_uses_hold())


func test_guard_toggle_mode_flips_on_press() -> void:
	var gameplay = SettingsScript.default_settings()
	gameplay.guard_mode = "toggle"
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)

	_press_action(PlayerActionKind.ACTION_GUARD)
	assert_true(PlayerInputScript.read_guard_held())
	_release_action(PlayerActionKind.ACTION_GUARD)
	assert_true(
		PlayerInputScript.read_guard_held(),
		"toggle guard stays active after release"
	)

	_press_action(PlayerActionKind.ACTION_GUARD)
	assert_false(
		PlayerInputScript.read_guard_held(),
		"second press clears toggle guard"
	)
	_release_action(PlayerActionKind.ACTION_GUARD)


func test_guard_hold_mode_tracks_pressed_state() -> void:
	var gameplay = SettingsScript.default_settings()
	gameplay.guard_mode = "hold"
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)

	_press_action(PlayerActionKind.ACTION_GUARD)
	assert_true(PlayerInputScript.read_guard_held())
	_release_action(PlayerActionKind.ACTION_GUARD)
	assert_false(PlayerInputScript.read_guard_held())


func test_allows_screenshake_respects_reduced_motion() -> void:
	var settings = SettingsScript.default_settings()
	assert_true(settings.allows_screenshake(false))
	assert_false(settings.allows_screenshake(true))
	settings.screenshake_enabled = false
	assert_false(settings.allows_screenshake(false))


func test_reduced_flashing_scales_lightning() -> void:
	var settings = SettingsScript.default_settings()
	assert_eq(settings.lightning_flash_scale(), 1.0)
	settings.reduced_flashing = true
	assert_eq(settings.lightning_flash_scale(), SettingsScript.REDUCED_FLASH_LIGHTNING_SCALE)


func test_enhanced_focus_theme_widens_border_when_enabled() -> void:
	var gameplay = SettingsScript.default_settings()
	gameplay.enhanced_focus_contrast = false
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)
	assert_eq(UiFocusThemeScript.focus_border_width(), 1)

	gameplay.enhanced_focus_contrast = true
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)
	assert_eq(UiFocusThemeScript.focus_border_width(), 4)


func _store():
	var store = StoreScript.new()
	store.settings_directory = _temp_dir("gameplay_accessibility")
	return store


func _temp_dir(prefix: String) -> String:
	return "user://test_%s_%d" % [prefix, Time.get_ticks_msec()]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _press_action(action: StringName) -> void:
	Input.action_press(action)


func _release_action(action: StringName) -> void:
	Input.action_release(action)


func _cleanup_temp_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry.begins_with("test_gameplay_accessibility_"):
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
