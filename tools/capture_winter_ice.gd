extends SceneTree

## ADR 0045 task 6 review plates: ice on the moat, the sea shore and puddles.
## Builds the real city view (CityMapView, the game's exposure and sky), pushes a
## campaign date through set_calendar_date and frames: the moat from the follow
## camera and from above, the harbour shore (fast ice and floes) and a frozen
## rut on a snow-free road. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_winter_ice.gd -- --date=1343-02-05
##     [--only=moat_game,puddle]
##     [--time=0.5] day progress; [--exposure=1.0] review-only tonemap multiplier (snow
##     fields clip at the game's daylight exposure, which hides the ice detail);
##     [--ice-snow=0.1] review-only snow on the moat ice (bare black ice plates).
## Output: build/season/ice_<shot>_<date>.png

const OUTPUT_DIR := "res://build/season"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.5

var _date := {"year": 1343, "month": 2, "day": 5}
var _tag := "1343-02-05"
var _only := ""
var _time := DAY_PROGRESS
var _exposure := 1.0
## Review-only override of the snow lying on moat ice (-1 keeps the date's cover).
var _ice_snow := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var parts := arg.substr(7).split("-")
			_date = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
			_tag = arg.substr(7)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--time="):
			_time = float(arg.substr(7))
		elif arg.begins_with("--exposure="):
			_exposure = float(arg.substr(11))
		elif arg.begins_with("--ice-snow="):
			_ice_snow = float(arg.substr(11))
	call_deferred("_run")


func _shots(plan: CityPlan, world: CityWorld3D) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	# A moat record well past the stream segments: follow camera along it, as in play.
	var index := clampi(world.stream_segment_count + 6, 0, world.moat_water.size() - 1)
	var rec: Array = world.moat_water[index]
	var a: Vector2 = rec[0]
	var b: Vector2 = rec[1]
	var along := (b - a).normalized()
	var mid := a.lerp(b, 0.5)
	var surface := float(rec[2])
	var eye := mid - along * 6.0
	var look := mid + along * 12.0
	shots.append({
		"name": "moat_game", "eye": Vector3(eye.x, surface + 3.6, eye.y),
		"look": Vector3(look.x, surface, look.y), "fov": 60.0, "focus": mid
	})
	var side := Vector2(-along.y, along.x)
	var low := mid + side * 2.0 - along * 2.5
	shots.append({
		"name": "moat_close", "eye": Vector3(low.x, surface + 1.6, low.y),
		"look": Vector3(mid.x + along.x * 3.0, surface, mid.y + along.y * 3.0), "fov": 60.0,
		"focus": mid
	})
	# Across the ditch from above one bank: both waterlines against the banks.
	var bank_eye := mid + side * 7.0 - along * 3.0
	shots.append({
		"name": "moat_bank", "eye": Vector3(bank_eye.x, surface + 5.0, bank_eye.y),
		"look": Vector3(mid.x - side.x * 3.0, surface, mid.y - side.y * 3.0), "fov": 60.0,
		"focus": mid
	})
	var high := mid + side * 9.0 - along * 11.0
	shots.append({
		"name": "moat_high", "eye": Vector3(high.x, surface + 14.0, high.y),
		"look": Vector3(mid.x, surface, mid.y), "fov": 55.0, "focus": mid
	})
	# Harbour shore: fast ice along the strand, floes beyond.
	var crane: Array = plan.data["harbour"]["crane"]["at"]
	var landing := Vector2(crane[0], crane[1])
	shots.append({
		"name": "sea_shore",
		"eye": Vector3(
			landing.x - 60.0, maxf(plan.ground_height(landing + Vector2(-60.0, 8.0)), 0.0) + 2.5,
			landing.y + 8.0
		),
		"look": Vector3(landing.x + 20.0, 0.0, landing.y - 20.0), "fov": 65.0, "focus": landing
	})
	shots.append({
		"name": "sea_wide", "eye": Vector3(landing.x - 30.0, 9.0, landing.y + 20.0),
		"look": Vector3(landing.x + 10.0, 0.0, landing.y - 90.0), "fov": 60.0, "focus": landing
	})
	# The waterline of the open strand west of the landing: fast ice and floes.
	var shore: Dictionary = preload("res://scripts/city/city_shore_field.gd").bake(plan)
	var contour: PackedVector2Array = shore["contour"]
	var edge := contour[0]
	var target := landing + Vector2(-165.0, 0.0)
	for point in contour:
		if point.distance_to(target) < edge.distance_to(target):
			edge = point
	var uphill := Vector2(
		plan.ground_height(edge + Vector2(1, 0)) - plan.ground_height(edge - Vector2(1, 0)),
		plan.ground_height(edge + Vector2(0, 1)) - plan.ground_height(edge - Vector2(0, 1))
	).normalized()
	var edge_eye := edge + uphill * 8.0 + Vector2(-uphill.y, uphill.x) * 6.0
	var edge_look := edge - uphill * 14.0
	shots.append({
		"name": "sea_edge",
		"eye": Vector3(edge_eye.x, maxf(plan.ground_height(edge_eye), 0.0) + 4.0, edge_eye.y),
		"look": Vector3(edge_look.x, 0.0, edge_look.y), "fov": 60.0, "focus": edge
	})
	# Bare road (no lying snow), so frozen ruts show there all winter.
	var puddle := _road_spot(plan, Vector2(617.64, 294.69), world)
	var puddle_y := plan.ground_height(puddle)
	print("ice plates: road puddle spot ", puddle)
	shots.append({
		"name": "puddle", "eye": Vector3(puddle.x, puddle_y + 1.4, puddle.y + 2.2),
		"look": Vector3(puddle.x, puddle_y, puddle.y - 1.5), "fov": 55.0, "focus": puddle
	})
	return shots


## The nearest flat, worn cart road (roads.png r = road, b = wear).
func _road_spot(plan: CityPlan, near_point: Vector2, world: CityWorld3D) -> Vector2:
	var img := (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var size := Vector2(img.get_size())
	var best := near_point
	var best_distance := INF
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var px := img.get_pixel(x, y)
			if px.r < 0.95 or px.b < 0.5:
				continue
			var wp := plan.bounds.position + Vector2(x, y) / size * plan.bounds.size
			if (
				plan.ground_height(wp) < 0.5 or plan.slope_at(wp) > 0.08
				or plan.building_at(wp) >= 0 or plan.site_at(wp) != null
				or wp.distance_to(near_point) >= best_distance
				or CitySnow.depth_at(wp, world.snow_cover) > 0.0
			):
				continue
			# Clear of the stream and moat by a few metres (the camera stands back).
			if (
				not world.water_medium_at(wp).is_empty()
				or not world.water_medium_at(wp + Vector2(0, 4)).is_empty()
				or not world.water_medium_at(wp - Vector2(0, 4)).is_empty()
				or not world.water_medium_at(wp + Vector2(4, 0)).is_empty()
				or not world.water_medium_at(wp - Vector2(4, 0)).is_empty()
			):
				continue
			if wp.distance_to(near_point) < best_distance:
				best_distance = wp.distance_to(near_point)
				best = wp
	return best


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ice plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := CityMapView.create_city(plan)
	viewport.add_child(view)
	var world := view.world
	var camera := view.view_camera()
	camera.far = 4000.0
	camera.near = 0.05
	camera.current = true
	world.sky_weather.auto_weather = false
	world.sky_weather.set_process(false)
	view.set_calendar_date(_date)
	if _ice_snow >= 0.0:
		for water: ShaderMaterial in world.water_materials:
			water.set_shader_parameter("ice_snow", _ice_snow)
	print("ice plates: sea ice %.2f fresh %.2f puddle %.2f snow %.2f" % [
		SeasonState.ice_cover_target(SeasonState.ICE_SEA, SeasonState.day_of_year_for(_date)),
		SeasonState.ice_cover_target(SeasonState.ICE_FRESH, SeasonState.day_of_year_for(_date)),
		SeasonState.ice_cover_target(SeasonState.ICE_PUDDLE, SeasonState.day_of_year_for(_date)),
		world.snow_cover,
	])
	for shot in _shots(plan, world):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.sky_weather.set_weather(SkyWeather3D.WEATHER_CLEAR)
		world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		view.apply_cycle_progress(_time)
		world.environment.tonemap_exposure *= _exposure
		MapViewMaterials.apply_sea_weather(0.3, 0.0, Vector2(0.4, -0.9))
		if world.grass != null:
			world.grass.update_for(shot["focus"])
		for i in 40:
			MapViewRuntimeEnvironment.advance_ocean_time(0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/ice_%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		if _exposure != 1.0 or _time != DAY_PROGRESS:
			path = "%s/ice_%s_%s_t%.2f_e%.2f.png" % [OUTPUT_DIR, shot["name"], _tag, _time, _exposure]
		if _ice_snow >= 0.0:
			path = path.replace(".png", "_snow%.2f.png" % _ice_snow)
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("ice plate: ", path)
	quit(0)
