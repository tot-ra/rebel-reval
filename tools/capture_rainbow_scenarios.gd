extends SceneTree

## R-1518 rainbow scenario plates on the seamless city, from the north shore looking out
## over the bay. The sun sits due south at noon, so the antisolar point (the centre of
## the bow) lies north over the water and the water mirrors the bow. Sun elevation is
## chosen by calendar date (noon elevation changes through the year), so each plate is
## a real in-game sky. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_rainbow_scenarios.gd [-- --only=a,b]
##     [--out=res://docs/reports/images/rainbow]
## Output: <out>/rainbow_<plate>.png. tools/rainbow_contact_sheet.py builds the sheet.
##
## Rainbow uniforms are forced each frame after the weather system pushed its own
## (RenderingServer.frame_pre_draw), so a plate can show a drop size or curtain the
## live weather would only reach by chance.

const VIEWPORT_SIZE := Vector2i(1280, 720)
const NORTH := Vector2(0.0, -1.0)
const EYE_HEIGHT := 6.0

## elevation: target noon sun elevation in degrees. yaw: camera turn from the antisolar
## azimuth, degrees (positive = right/east). pitch: camera tilt, degrees. droplet: 0 fog
## .. 1 rain. curtain: "all" (drops all around), "east" / "west" (departed shower).
const PLATES := {
	"a_low_sun_full_double": {"elevation": 8.0, "yaw": 0.0, "pitch": 14.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all"},
	"b_sun_25": {"elevation": 25.0, "yaw": 0.0, "pitch": 6.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all"},
	"c_sun_38_top_only": {"elevation": 38.0, "yaw": 0.0, "pitch": 2.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all"},
	"d_sun_48_secondary_only": {"elevation": 48.0, "yaw": 0.0, "pitch": 2.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all"},
	"e_camera_turned_45": {"elevation": 12.0, "yaw": 45.0, "pitch": 10.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all"},
	"f_departed_shower_east": {"elevation": 12.0, "yaw": 0.0, "pitch": 12.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "east"},
	"g_medium_drops_supernumerary": {"elevation": 12.0, "yaw": 0.0, "pitch": 12.0,
		"fov": 72.0, "droplet": 0.5, "curtain": "all"},
	"h_fog_droplets_fogbow": {"elevation": 12.0, "yaw": 0.0, "pitch": 12.0, "fov": 72.0,
		"droplet": 0.0, "curtain": "all"},
	"i_gameplay_high_camera": {"elevation": 12.0, "yaw": 0.0, "pitch": -38.0, "fov": 60.0,
		"droplet": 0.9, "curtain": "all", "eye_height": 45.0},
	"j_fair_cumulus": {"elevation": 12.0, "yaw": 0.0, "pitch": 12.0,
		"fov": 72.0, "droplet": 0.9, "curtain": "all", "cumulus": true},
	# R-1547: per-shower roll outcomes - a pale single bow and a faint secondary.
	"k_pale_single": {"elevation": 8.0, "yaw": 0.0, "pitch": 14.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all", "strength": 0.4, "secondary": 0.0},
	"l_faint_secondary": {"elevation": 8.0, "yaw": 0.0, "pitch": 14.0, "fov": 72.0,
		"droplet": 0.9, "curtain": "all", "strength": 0.75, "secondary": 0.3},
}

var _only := ""
var _out := "res://docs/reports/images/rainbow"
var _droplet := 0.9
var _curtain := Vector3.ZERO
var _strength := 0.9
var _secondary := 1.0
var _sky: SkyWeather3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	call_deferred("_run")


func _wanted(plate: String) -> bool:
	if _only.is_empty():
		return true
	for prefix in _only.split(","):
		if plate.begins_with(prefix):
			return true
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("rainbow capture needs a real renderer (tools/godot_render.sh)")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view._camera
	_sky = view._sky_weather
	_sky.auto_weather = false
	_sky.time_scale = 0.0
	RenderingServer.frame_pre_draw.connect(_force_rainbow)
	var shore := _shore_spot(plan)
	print("RAINBOW shore %s" % shore)
	var plates := PLATES.keys()
	plates.sort()
	for plate: String in plates:
		if not _wanted(plate):
			continue
		var spec: Dictionary = PLATES[plate]
		var date := _date_for_noon_elevation(float(spec["elevation"]))
		_sky.calendar_date = date
		_sky.set_weather(
			SkyWeather3D.WEATHER_CLEAR if spec.get("cumulus", false)
			else SkyWeather3D.WEATHER_CLOUDLESS
		)
		_sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		view.apply_cycle_progress(0.5)
		var sun := SkyWeather3D.solar_direction(0.5, date)
		_droplet = float(spec["droplet"])
		_curtain = _curtain_for(String(spec["curtain"]))
		_strength = float(spec.get("strength", 0.9))
		_secondary = float(spec.get("secondary", 1.0))
		var anti := Vector2(-sun.x, -sun.z).normalized()
		var heading := anti.rotated(deg_to_rad(float(spec["yaw"])))
		var ground := plan.walk_height(shore)
		var eye_height := float(spec.get("eye_height", EYE_HEIGHT))
		var eye := Vector3(shore.x, maxf(ground, 0.0) + eye_height, shore.y)
		var pitch := deg_to_rad(float(spec["pitch"]))
		var look := eye + Vector3(heading.x * cos(pitch), sin(pitch), heading.y * cos(pitch)) * 100.0
		camera.fov = float(spec["fov"])
		camera.far = 9000.0
		camera.near = 0.08
		camera.look_at_from_position(eye, look, Vector3.UP)
		for i in 10:
			view.apply_cycle_progress(0.5)
			await process_frame
		var path := "%s/rainbow_%s.png" % [_out, plate]
		var image := root.get_texture().get_image()
		if image.get_size() != VIEWPORT_SIZE:
			image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		image.save_png(ProjectSettings.globalize_path(path))
		print("RAINBOW %s date=%s sun_elev=%.1f deg az_anti=%s" % [
			plate, date, rad_to_deg(asin(sun.y)), anti
		])
	quit(0)


## Re-applied after SkyWeather3D and MapViewLighting pushed their live values.
func _force_rainbow() -> void:
	if _sky == null or _sky._material == null:
		return
	_sky._material.set_shader_parameter(&"rainbow_strength", _strength)
	_sky._material.set_shader_parameter(&"rainbow_secondary", _secondary)
	_sky._material.set_shader_parameter(&"rainbow_droplet", _droplet)
	_sky._material.set_shader_parameter(&"rainbow_curtain", _curtain)
	MapViewMaterials.apply_water_rainbow(_strength, _curtain, _droplet, _secondary)


func _curtain_for(mode: String) -> Vector3:
	match mode:
		"east":
			return Vector3(1.0, SkyWeather3D.RAINBOW_CURTAIN_HALF_WIDTH_COS, 0.0)
		"west":
			return Vector3(-1.0, SkyWeather3D.RAINBOW_CURTAIN_HALF_WIDTH_COS, 0.0)
	return Vector3.ZERO


## Day of 1343 whose solar noon elevation is closest to the target.
func _date_for_noon_elevation(elevation_deg: float) -> Dictionary:
	var best := {"day": 21, "month": 3, "year": 1343}
	var best_error := INF
	for month in range(1, 7):
		for day in range(1, 29):
			var date := {"day": day, "month": month, "year": 1343}
			var y := SkyWeather3D.solar_direction(0.5, date).y
			var error := absf(rad_to_deg(asin(clampf(y, -1.0, 1.0))) - elevation_deg)
			if error < best_error:
				best_error = error
				best = date
	return best


## A land point with open sea to the north for at least 400 m.
func _shore_spot(plan: CityPlan) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -INF
	for j in range(-60, 61):
		for i in range(-60, 61):
			var p := Vector2(i, j) * 12.0
			if plan.ground_height(p) < 0.4 or plan.building_at(p) >= 0:
				continue
			var first_water := -1.0
			var open := true
			for k in range(1, 60):
				var q := p + NORTH * float(k) * 8.0
				var h := plan.ground_height(q)
				if first_water < 0.0:
					if h < -0.5:
						first_water = float(k) * 8.0
					elif k > 6:
						open = false
						break
				elif h > -0.3:
					open = false
					break
			if not open or first_water < 0.0:
				continue
			# Prefer the beach line near the town centre.
			var score := -first_water - p.length() * 0.05
			if score > best_score:
				best_score = score
				best = p
	return best
