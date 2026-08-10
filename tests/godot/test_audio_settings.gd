extends "res://tests/godot/test_case.gd"

const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")
const AudioSettingsScript := preload("res://scripts/settings/audio_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")


func before_each() -> void:
	_cleanup_temp_dir()


func after_each() -> void:
	_cleanup_temp_dir()


func test_audio_settings_round_trip_persists_both_volumes() -> void:
	var store = _store()
	var settings = AudioSettingsScript.default_settings()
	settings.music_volume = 0.35
	settings.sfx_volume = 0.8
	settings.voice_volume = 0.45

	assert_true(store.save_audio_settings(settings))
	var loaded = store.load_audio_settings()
	assert_true(is_equal_approx(loaded.music_volume, 0.35))
	assert_true(is_equal_approx(loaded.sfx_volume, 0.8))
	assert_true(is_equal_approx(loaded.voice_volume, 0.45))


func test_invalid_audio_settings_normalize_to_safe_range() -> void:
	var settings = AudioSettingsScript.from_dict({
		"music_volume": 2.5,
		"sfx_volume": -0.4,
		"voice_volume": 4.0,
	})
	settings.normalize()
	assert_true(is_equal_approx(settings.music_volume, 1.0))
	assert_true(is_equal_approx(settings.sfx_volume, 0.0))
	assert_true(is_equal_approx(settings.voice_volume, 1.0))


func test_audio_bus_service_applies_linear_volumes() -> void:
	var settings = AudioSettingsScript.default_settings()
	settings.music_volume = 0.5
	settings.sfx_volume = 0.0
	AudioBusServiceScript.apply_settings(settings)

	var music_index := AudioServer.get_bus_index(String(AudioBusServiceScript.BUS_MUSIC))
	var sfx_index := AudioServer.get_bus_index(String(AudioBusServiceScript.BUS_SFX))
	assert_true(music_index >= 0)
	assert_true(sfx_index >= 0)
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(music_index), linear_to_db(0.5)))
	assert_true(AudioServer.get_bus_volume_db(sfx_index) <= -79.0)


func _store():
	var store = StoreScript.new()
	store.settings_directory = _temp_dir("audio_settings")
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
		if entry.begins_with("test_audio_settings_"):
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
