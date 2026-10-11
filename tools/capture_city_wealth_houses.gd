extends SceneTree

## R-1659 review: oblique neighbourhood shots around census poor / master / great
## log houses in the live city, to compare wall plates and windows.
##   tools/godot_render.sh --script tools/capture_city_wealth_houses.gd [-- --ids=a,b,c]
## Output: build/wealth_houses/<id>_area.png

var _ids := PackedStringArray(
	["bldg.osm.w200453901", "bldg.osm.w200453907", "bldg.osm.w200453893"]
)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			_ids = arg.substr(6).split(",")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/wealth_houses"))
	var plan := CityPlan.load_default()
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	sky.advance(20.0)
	view.apply_cycle_progress(0.42)
	for b: Dictionary in plan.buildings:
		if not String(b["id"]) in _ids:
			continue
		var c := Vector2.ZERO
		for p in b["footprint"]:
			c += Vector2(p[0], p[1])
		c /= float(b["footprint"].size())
		# Look at the door wall, slightly from the side, at about first-floor height.
		var out := Vector2(0, 1)
		if b.get("door") != null:
			out = (Vector2(b["door"][0], b["door"][1]) - c).normalized()
		var side := Vector2(-out.y, out.x)
		var y := plan.ground_height(c)
		camera.fov = 55.0
		camera.near = 0.1
		camera.far = 2000.0
		# A wide neighbourhood view: dense lanes put any low or close eye
		# inside a neighbour or under its roof.
		var shots := {"_area": [38.0, 30.0, 0.0]}
		for suffix: String in shots:
			var shot: Array = shots[suffix]
			var eye2 := c + out * float(shot[0]) + side * float(shot[2])
			camera.look_at_from_position(
				Vector3(eye2.x, y + float(shot[1]), eye2.y), Vector3(c.x, y + 2.0, c.y)
			)
			for i in 14:
				await process_frame
			var path := (
				"res://build/wealth_houses/%s%s.png" % [String(b["id"]).replace(".", "_"), suffix]
			)
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("captured ", path)
	quit(0)
