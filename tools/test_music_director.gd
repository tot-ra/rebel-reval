extends SceneTree

const MusicDirectorScript = preload("res://scripts/global/music_director.gd")


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
		"res://scenes/reval_center/reval_center.tscn": &"town",
		"res://scenes/reval_north/reval_north.tscn": &"town",
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
	for theme_id: StringName in [&"menu", &"forge", &"town"]:
		if not MusicDirectorScript.has_theme(theme_id):
			failures.append("Theme %s is routed but not configured" % theme_id)
			continue

		var stream: AudioStreamWAV = director.get_theme_stream(theme_id)
		if stream == null:
			failures.append("Theme %s did not synthesize a stream" % theme_id)
			continue
		if stream.data.is_empty():
			failures.append("Theme %s synthesized empty PCM data" % theme_id)
		if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			failures.append("Theme %s is not configured to loop" % theme_id)
		if stream.loop_begin != 0 or stream.loop_end != stream.data.size() / 2:
			failures.append("Theme %s has invalid loop boundaries" % theme_id)

	director.free()


func _check_autoload_playback(failures: Array[String]) -> void:
	var scene_changed_signal := scene_changed
	var change_error := change_scene_to_file("res://scenes/menu/main_menu.tscn")
	if change_error != OK:
		failures.append("Main menu could not be loaded for playback verification: %s" % error_string(change_error))
		return

	await scene_changed_signal
	# `process_frame` is emitted before Node._process callbacks. Wait for the next
	# frame boundary as well so MusicDirector has observed the new current scene.
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
