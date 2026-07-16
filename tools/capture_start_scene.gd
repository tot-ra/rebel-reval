extends SceneTree

## D-001 evidence capture: reproduces the post-menu Start flow (spawn at
## street_start in the Lower Town slice) and saves day and night gameplay-view
## PNGs. Requires a rendering-capable run (no --headless):
## godot --path . --script tools/capture_start_scene.gd

const OUTPUT_DIR := "res://docs/reports/images/view3d"
const SETTLE_FRAMES := 30


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var navigator := root.get_node("DoorNavigator")
	navigator.go_to_scene(&"reval_east", &"street_start")
	for time_of_day in MapView3D.ALL_TIMES:
		for _frame in SETTLE_FRAMES:
			await process_frame
		var scene := current_scene
		var runtime: MapViewRuntime = scene.get_node("MapViewRuntime")
		runtime.set_time_of_day(time_of_day)
		for _frame in 4:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/start_scene_%s.png" % [OUTPUT_DIR, time_of_day]
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Failed to save %s" % path)
			quit(1)
			return
		print("Start scene capture: %s" % path)
	var error := await _capture_walk()
	quit(0 if error == OK else 1)


func _capture_walk() -> Error:
	var scene := current_scene
	var runtime: MapViewRuntime = scene.get_node("MapViewRuntime")
	runtime.set_time_of_day(&"day")
	var player: CharacterBody2D = scene.get_node("Actors/Player")
	var start := player.global_position
	player.navigation_agent.set_target_position(start + Vector2(460.0, 140.0))
	for _frame in 40:
		await process_frame
	if player.global_position.distance_to(start) < 100.0:
		push_error("Player did not move in the 3D view; walk capture aborted")
		return FAILED
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/start_scene_walk.png" % OUTPUT_DIR
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error == OK:
		print("Start scene capture: %s" % path)
	return error
