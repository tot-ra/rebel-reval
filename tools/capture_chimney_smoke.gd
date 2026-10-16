extends SceneTree

## Chimney review plates: the flue mouth from above and the smoke plume from
## the street and from the iso height, over a lit chimney.
##   tools/godot_render.sh --script tools/capture_chimney_smoke.gd [-- --tag=after --index=0]
## Output: build/chimney_smoke/<shot>_<tag>.png

var _tag := "after"
var _index := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--index="):
			_index = int(arg.substr(8))
	call_deferred("_run")


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://build/chimney_smoke")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var plan := CityPlan.load_default()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	sky.advance(20.0)
	view.apply_cycle_progress(0.42)
	# Lit chimneys that smoke by day, nearest the Old Town centre first.
	var picks: Array = []
	for c: Array in view.world.smoke.lit:
		var seed := String(c[1]).hash()
		var schedule := ChimneySmoke3D.schedule_for(seed)
		if schedule in [ChimneySmoke3D.Schedule.ALWAYS, ChimneySmoke3D.Schedule.DAY_ONLY]:
			picks.append(c)
	if picks.is_empty():
		push_error("no lit chimney")
		quit(1)
		return
	var town := Vector2.ZERO
	picks.sort_custom(
		func(a: Array, b: Array) -> bool:
			var da := Vector2(a[0].x, a[0].z).distance_squared_to(town)
			return da < Vector2(b[0].x, b[0].z).distance_squared_to(town)
	)
	var top: Vector3 = picks[mini(_index, picks.size() - 1)][0]
	print("chimney %s at %s" % [picks[mini(_index, picks.size() - 1)][1], top])
	camera.fov = 50.0
	camera.near = 0.05
	camera.far = 2000.0
	var shots := {
		"mouth": [top + Vector3(0.9, 1.6, 1.1), top],
		"street": [top + Vector3(12.0, -4.0, 14.0), top + Vector3(0.0, 2.5, 0.0)],
		"iso": [top + Vector3(16.0, 18.0, 16.0), top + Vector3(0.0, 1.5, 0.0)],
	}
	for shot: String in shots:
		camera.look_at_from_position(shots[shot][0], shots[shot][1], Vector3.UP)
		# Plumes stream around a focus point; let them spawn and rise.
		for i in 150:
			view.world.smoke.update_for(Vector2(top.x, top.z), 0.6)
			view.apply_cycle_progress(0.42)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [out_dir, shot, _tag]
		root.get_texture().get_image().save_png(path)
		print("plate: %s" % path)
	quit(0)
