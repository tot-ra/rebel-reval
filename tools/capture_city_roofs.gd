extends SceneTree

## Roof review plates: oblique aerial views of chosen buildings (ids from plan.json).
##   tools/godot_render.sh --script tools/capture_city_roofs.gd [-- --ids=a,b --tag=after]
## Output: build/roofs/roof_<n>_<tag>.png

var _ids := PackedStringArray(["bldg.osm.w200631121", "bldg.osm.w134801476", "bldg.osm.w200644973"])
var _tag := "after"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			_ids = arg.substr(6).split(",")
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/roofs"))
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
	view.apply_cycle_progress(0.45)
	var n := 0
	for b: Dictionary in plan.buildings:
		if not String(b["id"]) in _ids:
			continue
		var c := Vector2.ZERO
		for p in b["footprint"]:
			c += Vector2(p[0], p[1])
		c /= float(b["footprint"].size())
		var y := plan.ground_height(c)
		camera.fov = 55.0
		camera.near = 0.1
		camera.far = 2000.0
		camera.look_at_from_position(
			Vector3(c.x + 14, y + 22, c.y + 20), Vector3(c.x, y + 5, c.y), Vector3.UP
		)
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://build/roofs/roof_%d_%s.png" % [n, _tag])
		)
		n += 1
	quit(0)
