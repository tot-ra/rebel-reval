extends SceneTree

const MusicDirectorScript = preload("res://scripts/global/music_director.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_check_routes(failures)
	_check_streams(failures)
	await _check_autoload_playback(failures)

	if failures.is_empty():
		print("MusicDirector tests: PASS")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("MusicDirector tests: FAIL (%d failure(s))" % failures.size())
	quit(1)


func _check_routes(failures: Array[String]) -> void:
	var expected_routes: Dictionary = {
		"res://scenes/menu/main_menu.tscn": &"menu",
		"res://scenes/reval_east/forge/forge.tscn": &"forge",
		"res://scenes/reval_east/reval_east.tscn": &"town",
		"res://scenes/reval_center/reval_center.tscn": &"center",
		"res://scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn": &"center",
		"res://scenes/reval_north/reval_north.tscn": &"north",
		"res://scenes/reval_monastery/reval_monastery.tscn": &"monastery",
		"res://scenes/harbor/harbor_north.tscn": &"harbor",
		"res://scenes/harbor/harbor_east.tscn": &"harbor",
		"res://scenes/reval_toompea/reval_toompea.tscn": &"toompea",
		"res://scenes/reval_south/reval_south.tscn": &"south",
	}
	for scene_path: String in expected_routes:
		var actual: StringName = MusicDirectorScript.theme_for_scene(scene_path)
		var expected: StringName = expected_routes[scene_path]
		if actual != expected:
			failures.append("Expected %s to route to %s, got %s" % [scene_path, expected, actual])

	if not MusicDirectorScript.theme_for_scene("res://scenes/unknown.tscn").is_empty():
		failures.append("Unknown scenes should not have a music route")


func _check_streams(failures: Array[String]) -> void:
	var director := MusicDirectorScript.new()
	for theme_id: StringName in [&"menu", &"forge", &"town", &"center", &"north", &"monastery", &"harbor", &"toompea", &"south"]:
		if not MusicDirectorScript.has_theme(theme_id):
			failures.append("Theme %s is routed but not configured" % theme_id)
			continue

		var day_tracks := MusicDirectorScript.day_track_paths_for_theme(theme_id)
		if day_tracks.is_empty():
			failures.append("Theme %s has no approved day tracks" % theme_id)
		for track_path: String in day_tracks:
			if not ResourceLoader.exists(track_path):
				failures.append("Missing approved track for %s: %s" % [theme_id, track_path])

		for track_path: String in MusicDirectorScript.night_track_paths_for_theme(theme_id):
			if not ResourceLoader.exists(track_path):
				failures.append("Missing approved night track for %s: %s" % [theme_id, track_path])

		var stream: AudioStream = director.get_theme_stream(theme_id)
		if stream == null:
			failures.append("Theme %s did not load a stream" % theme_id)
			continue
		match theme_id:
			&"menu":
				if not stream is AudioStreamMP3:
					failures.append("Menu theme should load an MP3 stream")
				elif not (stream as AudioStreamMP3).loop:
					failures.append("Menu theme should loop")
			&"forge":
				if not stream is AudioStreamRandomizer:
					failures.append("Forge theme should use AudioStreamRandomizer")
			_:
				if not stream is AudioStreamPlaylist:
					failures.append("District theme %s should use AudioStreamPlaylist" % theme_id)

	_check_cycle_volume(failures)
	director.free()


func _check_cycle_volume(failures: Array[String]) -> void:
	var noon_db := MusicDirectorScript.volume_db_for_cycle_progress(0.5)
	var midnight_db := MusicDirectorScript.volume_db_for_cycle_progress(0.0)
	if not is_equal_approx(
		MusicDirectorScript.volume_linear_for_day_blend(DayNightCycle.day_blend(0.0)),
		0.5
	):
		failures.append("Midnight should duck music to 50 percent linear volume")
	if noon_db <= midnight_db:
		failures.append("Day cycle volume must be louder than night cycle volume")


func _check_autoload_playback(failures: Array[String]) -> void:
	var scene_changed_signal := scene_changed
	var change_error := change_scene_to_file("res://scenes/menu/main_menu.tscn")
	if change_error != OK:
		failures.append("Main menu could not be loaded for playback verification: %s" % error_string(change_error))
		return

	await scene_changed_signal
	await process_frame
	await process_frame
	var director := root.get_node_or_null("MusicDirector")
	if director == null:
		failures.append("MusicDirector autoload is missing")
		return

	var player := director.get_node_or_null("ThemePlayer") as AudioStreamPlayer
	if player == null:
		failures.append("MusicDirector did not create ThemePlayer")
		return
	if player.stream == null or not player.playing:
		failures.append(
			"Main-menu theme is not playing through the autoload "
			+ "(scene=%s, stream=%s, playing=%s)" % [
				current_scene.scene_file_path if current_scene != null else "<null>",
				str(player.stream),
				str(player.playing),
			]
		)
