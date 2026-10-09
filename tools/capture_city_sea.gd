extends SceneTree

## Review plates for the city's sea and shore (docs/SYSTEMS/CITY_SEA.md): calm
## and storm water at the merchant landing, the beach and the seabed. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_sea.gd [-- --tag=now] [--only=a,b]
## Output: build/city_sea/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/city_sea"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42

var _tag := "now"
var _only := ""
## Extra sea-clock seconds before each plate, to catch a different swash phase.
var _advance := 0.0
var _bench := 0
var _motion := 0
var _validate_surface := 0
var _baseline := false
var _shader_override := ""
var _hide_water := false
var _tier: StringName = &"recommended"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--advance="):
			_advance = float(arg.substr(10))
		elif arg.begins_with("--bench="):
			_bench = int(arg.substr(8))
		elif arg.begins_with("--motion="):
			_motion = int(arg.substr(9))
		elif arg.begins_with("--validate-surface="):
			_validate_surface = int(arg.substr(19))
		elif arg == "--baseline":
			_baseline = true
		elif arg.begins_with("--shader="):
			_shader_override = arg.substr(9)
		elif arg == "--hide-water":
			_hide_water = true
		elif arg.begins_with("--tier="):
			_tier = StringName(arg.substr(7))
	call_deferred("_run")


func _shots(plan: CityPlan, world: CityWorld3D) -> Array[Dictionary]:
	var crane: Array = plan.data["harbour"]["crane"]["at"]
	var landing := Vector2(crane[0], crane[1])
	var g := plan.ground_height(landing)
	var shots: Array[Dictionary] = []
	var schools := CityFish.school_centres(plan)
	if not schools.is_empty():
		var best: Dictionary = schools[0]
		for sc: Dictionary in schools:
			if (
				(sc["at"] as Vector2).distance_to(landing)
				< (best["at"] as Vector2).distance_to(landing)
			):
				best = sc
		var f: Vector2 = best["at"]
		(
			shots
			. append(
				{
					"name": "fish",
					"wind": 0.1,
					"rain": 0.0,
					"eye": Vector3(f.x - 2.0, 2.2, f.y + 3.5),
					"look": Vector3(f.x, -0.2, f.y),
					"fov": 60.0,
					"focus": f,
				}
			)
		)
		for mode: String in ["under", "straddle", "night", "under_up"]:
			var eye_y := -0.18 if mode == "under" else (0.025 if mode == "straddle" else 1.8)
			if mode == "under_up":
				eye_y = -0.35
			shots.append(
				{
					"name": "fish_" + mode,
					"wind": 0.1,
					"rain": 0.0,
					"eye": Vector3(f.x - 1.0, eye_y, f.y + 1.0),
					"look": Vector3(f.x + 1.5, eye_y - 0.08, f.y - 1.5),
					"fov": 70.0,
					"focus": f,
					"time": 0.94 if mode == "night" else DAY_PROGRESS
				}
			)
			if mode == "under_up":
				shots[-1]["look"] = shots[-1]["eye"] + Vector3(0.1, 1.0, -0.1)
	var stream := Vector2(617.64, 294.69)
	var stream_y := plan.ground_height(stream) + 1.75
	shots.append(
		{
			"name": "stream",
			"wind": 0.65,
			"rain": 0.0,
			"eye": Vector3(stream.x - 2.0, stream_y + 1.1, stream.y + 3.0),
			"look": Vector3(stream.x, stream_y, stream.y - 8.0),
			"fov": 65.0,
			"focus": stream
		}
	)
	var puddle := _puddle_spot(plan, stream, world)
	var puddle_y := plan.ground_height(puddle)
	for weather: Array in [["calm", 0.0, 0.0], ["wind", 0.8, 0.0], ["rain", 0.8, 0.8]]:
		shots.append(
			{
				"name": "puddle_" + weather[0],
				"wind": weather[1],
				"rain": weather[2],
				"eye": Vector3(puddle.x, puddle_y + 1.0, puddle.y + 2.0),
				"look": Vector3(puddle.x, puddle_y, puddle.y - 2.0),
				"fov": 55.0,
				"focus": puddle,
				"puddle": true
			}
		)
	for sea: Array in [["calm", 0.1, 0.0], ["storm", 0.95, 0.6]]:
		(
			shots
			. append(
				{
					"name": "sea_%s_wide" % sea[0],
					"wind": sea[1],
					"rain": sea[2],
					"eye": Vector3(landing.x - 30.0, 7.0, landing.y + 20.0),
					"look": Vector3(landing.x + 10.0, 0.0, landing.y - 90.0),
					"fov": 60.0,
					"focus": landing,
				}
			)
		)
		(
			shots
			. append(
				{
					"name": "sea_%s_shore" % sea[0],
					"wind": sea[1],
					"rain": sea[2],
					"eye":
					Vector3(
						landing.x - 60.0,
						maxf(plan.ground_height(landing + Vector2(-60.0, 8.0)), 0.0) + 1.8,
						landing.y + 8.0
					),
					"look": Vector3(landing.x + 20.0, 0.3, landing.y - 6.0),
					"fov": 65.0,
					"focus": landing,
				}
			)
		)
		(
			shots
			. append(
				{
					"name": "sea_%s_beach_close" % sea[0],
					"wind": sea[1],
					"rain": sea[2],
					"eye":
					Vector3(
						landing.x - 20.0,
						maxf(plan.ground_height(landing + Vector2(-20.0, 4.0)), 0.0) + 1.0,
						landing.y + 4.0
					),
					"look": Vector3(landing.x - 5.0, 0.0, landing.y - 8.0),
					"fov": 65.0,
					"focus": landing,
				}
			)
		)
	shots.append_array(_surf_shots(plan, landing))
	# An open strand away from quay geometry: close-camera material transitions.
	shots.append_array(_surf_shots(plan, landing - Vector2(140.0, 0.0), "close_"))
	var solar := SkyAstronomy.sunrise_sunset_hours(world.sky_weather.calendar_date)
	var morning := (float(solar["sunrise"]) + 0.6) / 24.0
	var evening := (float(solar["sunset"]) - 0.6) / 24.0
	var wide: Dictionary = {}
	var close_shore: Dictionary = {}
	for shot in shots:
		if shot["name"] == "sea_calm_wide":
			wide = shot
		if shot["name"] == "close_shore_reverse_fresh":
			close_shore = shot
	for condition: Array in [
		["morning", morning, 0.15, 0.0, SkyWeather3D.WEATHER_CLEAR],
		["windy", DAY_PROGRESS, 0.6, 0.0, SkyWeather3D.WEATHER_CLOUDY],
		["rain", DAY_PROGRESS, 0.8, 0.8, SkyWeather3D.WEATHER_RAIN],
		["evening", evening, 0.5, 0.0, SkyWeather3D.WEATHER_CLOUDY],
		["night", 0.94, 0.25, 0.0, SkyWeather3D.WEATHER_CLEAR],
		["gale", DAY_PROGRESS, 0.95, 0.6, SkyWeather3D.WEATHER_STORM],
	]:
		var shot: Dictionary = wide.duplicate(true)
		shot.merge({
			"name": "sea_" + condition[0], "time": condition[1], "wind": condition[2],
			"rain": condition[3], "weather": condition[4]
		}, true)
		shots.append(shot)
		var close_shot: Dictionary = close_shore.duplicate(true)
		close_shot.merge({
			"name": "close_" + condition[0], "time": condition[1], "wind": condition[2],
			"rain": condition[3], "weather": condition[4]
		}, true)
		shots.append(close_shot)
	return shots


## Pick actual flat earth/mud, not a grassy bank where water cannot pool.
func _puddle_spot(plan: CityPlan, near_point: Vector2, world: CityWorld3D) -> Vector2:
	var splat := (load(CityPlan.SPLAT_PATH) as Texture2D).get_image()
	var best := near_point
	var score := INF
	for z in range(-100, 101, 2):
		for x in range(-100, 101, 2):
			var p := near_point + Vector2(x, z)
			var uv := (p - plan.bounds.position) / plan.bounds.size
			var s := splat.get_pixel(
				clampi(int(uv.x * splat.get_width()), 0, splat.get_width() - 1),
				clampi(int(uv.y * splat.get_height()), 0, splat.get_height() - 1)
			)
			if s.g < 0.65 or s.r > 0.15 or plan.ground_height(p) < 2.0:
				continue
			if not world.water_medium_at(p).is_empty():
				continue
			if (
				not world.water_medium_at(p + Vector2(0, 3)).is_empty()
				or not world.water_medium_at(p - Vector2(0, 3)).is_empty()
			):
				continue
			var slope := absf(
				plan.ground_height(p + Vector2(2, 0)) - plan.ground_height(p - Vector2(2, 0))
			)
			slope += absf(
				plan.ground_height(p + Vector2(0, 2)) - plan.ground_height(p - Vector2(0, 2))
			)
			var candidate := slope * 500.0 + p.distance_to(near_point)
			if candidate < score:
				best = p
				score = candidate
	return best


## Close surf plates: eye 1.7 m up and 7 units back from the nearest beach waterline
## west of the landing, looking seaward along the shore, in calm and in a gale.
func _surf_shots(plan: CityPlan, landing: Vector2, prefix := "") -> Array[Dictionary]:
	var shore: Dictionary = preload("res://scripts/city/city_shore_field.gd").bake(plan)
	var contour: PackedVector2Array = shore["contour"]
	var best := contour[0]
	var target := landing + Vector2(-25.0, 0.0)
	for point in contour:
		if point.distance_to(target) < best.distance_to(target):
			best = point
	var uphill := (
		Vector2(
			plan.ground_height(best + Vector2(1, 0)) - plan.ground_height(best - Vector2(1, 0)),
			plan.ground_height(best + Vector2(0, 1)) - plan.ground_height(best - Vector2(0, 1))
		)
		. normalized()
	)
	var along := Vector2(-uphill.y, uphill.x)
	var eye2 := best + uphill * 7.0 + along * 4.0
	var look2 := best - uphill * 9.0 - along * 6.0
	var out: Array[Dictionary] = []
	for sea: Array in [["calm", 0.1, 0.0], ["fresh", 0.55, 0.0], ["storm", 0.95, 0.6]]:
		out.append(
			{
				"name": "surf_%s" % sea[0],
				"wind": sea[1],
				"rain": sea[2],
				"eye": Vector3(eye2.x, plan.ground_height(eye2) + 1.7, eye2.y),
				"look": Vector3(look2.x, 0.2, look2.y),
				"fov": 70.0,
				"focus": best
			}
		)
	# Side-on plate: the wave train in profile, rolling in towards the beach.
	var side_eye := best + uphill * 3.0 + along * 16.0
	var side_look := best - uphill * 10.0 - along * 4.0
	for sea: Array in [["calm", 0.1, 0.0], ["fresh", 0.55, 0.0], ["storm", 0.95, 0.6]]:
		out.append(
			{
				"name": "surf_side_%s" % sea[0],
				"wind": sea[1],
				"rain": sea[2],
				"eye": Vector3(side_eye.x, plan.ground_height(side_eye) + 1.4, side_eye.y),
				"look": Vector3(side_look.x, 0.0, side_look.y),
				"fov": 65.0,
				"focus": best
			}
		)
	# Low grazing view exposes sea/run-up joins hidden by the elevated plates.
	for sea: Array in [["calm", 0.1, 0.0], ["fresh", 0.55, 0.0], ["storm", 0.95, 0.6]]:
		var near_eye := best + uphill * 1.0 + along * 10.0
		var near_look := best - uphill * 2.0 - along * 12.0
		out.append({
			"name": "shore_join_" + sea[0], "wind": sea[1], "rain": sea[2],
			"eye": Vector3(near_eye.x, maxf(plan.ground_height(near_eye), 0.0) + 0.7, near_eye.y),
			"look": Vector3(near_look.x, 0.05, near_look.y), "fov": 75.0, "focus": best
		})
		var reverse_eye := best + uphill - along * 10.0
		var reverse_look := best - uphill * 2.0 + along * 12.0
		out.append({
			"name": "shore_reverse_" + sea[0], "wind": sea[1], "rain": sea[2],
			"eye": Vector3(reverse_eye.x, maxf(plan.ground_height(reverse_eye), 0.0) + 0.7,
				reverse_eye.y),
			"look": Vector3(reverse_look.x, 0.05, reverse_look.y), "fov": 75.0, "focus": best
		})
		var swim_eye := best - uphill * 10.0 + along * 14.0
		var swim_look := best - along * 10.0
		out.append({
			"name": "sea_level_" + sea[0], "wind": sea[1], "rain": sea[2],
			"eye": Vector3(swim_eye.x, 1.3, swim_eye.y),
			"look": Vector3(swim_look.x, 0.3, swim_look.y), "fov": 75.0, "focus": best
		})
	for shot in out:
		shot["name"] = prefix + shot["name"]
	return out


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires tools/godot_render.sh and a real renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := CityMapView.create_city(plan, _tier)
	viewport.add_child(view)
	var world := view.world
	print("city sea capture: world ready")
	if _hide_water:
		world.get_node("Water").visible = false
	var camera := view.view_camera()
	camera.far = 4000.0
	camera.near = 0.025
	camera.current = true
	world.sky_weather.set_quality_tier(_tier)
	world.sky_weather.auto_weather = false
	world.sky_weather.set_process(false)
	if _baseline or not _shader_override.is_empty() or _motion > 0:
		var path := "res://scripts/map/view3d/map_view_water.gdshader"
		if _baseline:
			path = "res://build/scratch/water_before/scripts/map/view3d/map_view_water.gdshader"
		if not _shader_override.is_empty():
			path = _shader_override
		if not FileAccess.file_exists(path):
			push_error("Missing capture shader override: %s" % path)
			quit(2)
			return
		var source := FileAccess.get_file_as_string(path)
		if _motion > 0:
			# PNG readback takes wall time. Keep secondary water ripples/foam at
			# the same 24 Hz as the ocean, rather than speeding them up in video.
			# Capture-only shader copy; runtime materials/files are unchanged.
			var clock_token := RegEx.new()
			clock_token.compile("\\bTIME\\b")
			source = clock_token.sub(source, "ocean_time", true)
		var shader := Shader.new()
		shader.code = source
		for terrain: StringName in MapViewMaterials.WATER_TERRAINS:
			MapViewMaterials.water_surface(terrain).shader = shader
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var measurements: Array[Dictionary] = []
	var validity: Array[Dictionary] = []
	for shot in _shots(plan, world):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		print("city sea capture: preparing ", shot["name"])
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		# Independent plates must not inherit wet lens drops from the last shot.
		view.underwater_pass().advance(10.0, NAN, {})
		view.underwater_pass().advance(10.0, NAN, {})
		world.sky_weather.set_weather(shot.get("weather", SkyWeather3D.WEATHER_CLEAR))
		world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		view.apply_cycle_progress(float(shot.get("time", DAY_PROGRESS)))
		MapViewMaterials.apply_sea_weather(shot["wind"], shot["rain"], Vector2(0.4, -0.9))
		MapViewMaterials.apply_world_wind(Vector2(0.4, -0.9), shot["wind"])
		world.set_wind(Vector2(0.4, -0.9))
		if bool(shot.get("puddle", false)):
			var ground := CityTerrainBuilder.shared_material()
			ground.set_shader_parameter("puddles", 1.0)
			ground.set_shader_parameter("wetness", 0.65)
			ground.set_shader_parameter("rain_intensity", shot["rain"])
		if world.spray != null:
			world.spray.set_wind(shot["wind"])
		var dummy := Node2D.new()
		dummy.global_position = CityPlan.to_logic(shot["focus"])
		root.add_child(dummy)
		var fish := CityFish.create(plan, dummy)
		world.add_child(fish)
		fish.set_process(false)
		MapViewRuntimeEnvironment.set_ocean_time(_advance)
		for i in 40:
			fish._process(0.05)
			MapViewRuntimeEnvironment.advance_ocean_time(0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		if world.spray != null:
			var live := 0
			for e in world.spray.get_children():
				live += int(e.emitting and e.visible)
			print(
				"spray emitters live: ",
				live,
				" first at ",
				world.spray.get_child(0).global_position
			)
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured ", path, " fish schools live: ", fish.live_count())
		print("camera medium: ", view.underwater_pass().state)
		print("weather: %s sun elevation: %.2f wind: %.2f rain: %.2f" % [
			world.sky_weather.weather,
			SkyAstronomy.solar_elevation_degrees(view.cycle_progress, world.sky_weather.calendar_date),
			shot["wind"], shot["rain"]
		])
		if _bench > 0:
			var times: Array[float] = []
			for i in _bench:
				var start := Time.get_ticks_usec()
				MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 60.0)
				fish._process(1.0 / 60.0)
				await process_frame
				await RenderingServer.frame_post_draw
				times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			times.sort()
			var sum := 0.0
			for ms in times:
				sum += ms
			measurements.append(
				{
					"shot": shot["name"],
					"frames": _bench,
					"mean_ms": sum / times.size(),
					"p95_ms": times[int(times.size() * 0.95)],
					"draw_calls":
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				}
			)
		if _motion > 0:
			var dir := "%s/%s_%s_motion" % [OUTPUT_DIR, shot["name"], _tag]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			for i in _motion:
				MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 24.0)
				fish._process(1.0 / 24.0)
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png("%s/%04d.png" % [dir, i])
		if _validate_surface > 0:
			validity.append(await _surface_validity(viewport, shot["name"]))
		fish.queue_free()
		dummy.queue_free()
	if _bench > 0:
		var report := {
			"renderer": RenderingServer.get_current_rendering_method(),
			"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
			"tier": _tier,
			"baseline": _baseline,
			"shader_override": _shader_override,
			"water_hidden": _hide_water,
			"measurements": measurements
		}
		var out := FileAccess.open("%s/benchmark_%s.json" % [OUTPUT_DIR, _tag], FileAccess.WRITE)
		out.store_string(JSON.stringify(report, "\t"))
		print(JSON.stringify(report))
	var failed := false
	if not validity.is_empty():
		var output := FileAccess.open("%s/validity_%s.json" % [OUTPUT_DIR, _tag], FileAccess.WRITE)
		output.store_string(JSON.stringify(validity, "\t"))
		print("GPU surface validity: ", JSON.stringify(validity))
		for result in validity:
			failed = (failed or result["invalid_samples"] > 0
				or result["minimum_valid_samples_per_phase"] < 100)
	quit(1 if failed else 0)


## Actual GPU math, not the CPU height approximation. Sample a whole wave period.
func _surface_validity(viewport: SubViewport, shot: String) -> Dictionary:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	material.set_shader_parameter("debug_surface_validity", true)
	var invalid := 0
	var valid := 0
	var minimum_valid := VIEWPORT_SIZE.x * VIEWPORT_SIZE.y
	for frame in _validate_surface:
		MapViewRuntimeEnvironment.advance_ocean_time(1638.4 / 182.0 / _validate_surface)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		if frame == 0:
			pixels.save_png("%s/validity_%s_%s.png" % [OUTPUT_DIR, shot, _tag])
		pixels.convert(Image.FORMAT_RGBA8)
		var bytes := pixels.get_data()
		var phase_valid := 0
		# One in four pixels is sufficient to detect the former whole-wave NaN
		# regions; keep readback out of the independent benchmark timing loop.
		for i in range(0, bytes.size(), 16):
			if bytes[i] > bytes[i + 1] + 60 and bytes[i + 2] > bytes[i + 1] + 60:
				invalid += 1
			if bytes[i + 1] > bytes[i] + 50 and bytes[i + 1] > bytes[i + 2] + 50:
				phase_valid += 1
		valid += phase_valid
		minimum_valid = mini(minimum_valid, phase_valid)
	material.set_shader_parameter("debug_surface_validity", false)
	return {"shot": shot, "phases": _validate_surface,
		"invalid_samples": invalid, "valid_samples": valid,
		"minimum_valid_samples_per_phase": minimum_valid}
