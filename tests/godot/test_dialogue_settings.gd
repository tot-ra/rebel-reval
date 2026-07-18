extends "res://tests/godot/test_case.gd"

const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")


func before_each() -> void:
	_cleanup_temp_dir()


func after_each() -> void:
	_cleanup_temp_dir()


func test_dialogue_settings_round_trip_persists_all_fields() -> void:
	var store = _store()
	var settings = SettingsScript.default_settings()
	settings.text_scale = "large"
	settings.text_speed = "fast"
	settings.high_contrast = true
	settings.subtitle_background = false
	settings.reduced_motion = true

	assert_true(store.save_dialogue_settings(settings))
	var loaded = store.load_dialogue_settings()
	assert_eq(loaded.text_scale, "large")
	assert_eq(loaded.text_speed, "fast")
	assert_true(loaded.high_contrast)
	assert_false(loaded.subtitle_background)
	assert_true(loaded.reduced_motion)


func test_invalid_settings_normalize_to_defaults() -> void:
	var settings = SettingsScript.from_dict({
		"text_scale": "unsupported",
		"text_speed": "warp",
		"high_contrast": true,
	})
	settings.normalize()
	assert_eq(settings.text_scale, "normal")
	assert_eq(settings.text_speed, "normal")
	assert_true(settings.high_contrast)


func test_reduced_motion_and_instant_speed_reveal_immediately() -> void:
	var root := _make_root()
	var ui = UiScript.new()
	root.add_child(ui)

	var reduced = SettingsScript.default_settings()
	reduced.text_speed = "slow"
	reduced.reduced_motion = true
	ui.apply_settings(reduced)
	ui.present_line(&"char.mart", "Mart", "Measured words.", "node_a")
	assert_true(ui.is_reveal_complete())
	assert_eq(ui.get_visible_line_text(), "Measured words.")

	var instant = SettingsScript.default_settings()
	instant.text_speed = "instant"
	instant.reduced_motion = false
	ui.apply_settings(instant)
	ui.present_line(&"char.mart", "Mart", "Immediate line.", "node_b")
	assert_true(ui.is_reveal_complete())
	assert_eq(ui.get_visible_line_text(), "Immediate line.")
	_cleanup_node(root)


func test_typewriter_reveal_completes_on_second_advance() -> void:
	var root := _make_root()
	var ui = UiScript.new()
	root.add_child(ui)

	var settings = SettingsScript.default_settings()
	settings.text_speed = "slow"
	settings.reduced_motion = false
	ui.apply_settings(settings)
	ui.present_line(&"char.mart", "Mart", "A longer reveal line.", "node_a")
	assert_false(ui.is_reveal_complete())

	assert_false(ui.consume_line_advance())
	assert_true(ui.is_reveal_complete())
	assert_true(ui.consume_line_advance())
	_cleanup_node(root)


func test_apply_settings_updates_text_scale() -> void:
	var root := _make_root()
	var ui = UiScript.new()
	root.add_child(ui)

	var settings = SettingsScript.default_settings()
	settings.text_scale = "extra_large"
	ui.apply_settings(settings)
	assert_eq(ui.get_text_scale(), "extra_large")
	assert_eq(
		TextScaleScript.body_size("extra_large"),
		TextScaleScript.body_size(ui.get_text_scale())
	)
	_cleanup_node(root)


func _store():
	var store = StoreScript.new()
	store.settings_directory = _temp_dir("dialogue_settings")
	return store


func _temp_dir(prefix: String) -> String:
	return "user://test_%s_%d" % [prefix, Time.get_ticks_msec()]


func _cleanup_temp_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry.begins_with("test_dialogue_settings_"):
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


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
