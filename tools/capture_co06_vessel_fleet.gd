extends SceneTree

## CO-06 (R-953) review plates: the working-craft fleet line-up at fixed framing,
## the six Kalamaja boats on the sand in one shot, and the roadstead, each in
## clear noon and storm. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_co06_vessel_fleet.gd [-- --tag=after] [--only=a,b]
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_co06_vessel_fleet.gd -- --tag=after_metal
## Output: build/co06/<shot>_<tag>.png (copy reviewed plates to docs/reports/images/co06_*).
## The city plates (kalamaja_*, roads_*) do not touch VesselFleet by name, so the
## same script renders the "before" state on a checkout without the fleet.

const OUTPUT_DIR := "res://build/co06"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const NOON := 0.5
const FLEET_SCRIPT := "res://scripts/city/vessel_fleet.gd"

var _tag := "now"
var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _wanted(shot_name: String) -> bool:
	if _only.is_empty():
		return true
	for prefix in _only.split(","):
		if shot_name.begins_with(prefix):
			return true
	return false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _wanted("lineup") and ResourceLoader.exists(FLEET_SCRIPT):
		await _lineup()
	if _wanted("kalamaja") or _wanted("roads"):
		await _city()
	quit(0)


func _save(viewport: SubViewport, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot_name, _tag]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("captured ", path)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


## Every design side by side, keel on a flat sea, in two variants each: furled
## (front row) and the sail set to a following wind (back row).
func _lineup() -> void:
	var fleet: GDScript = load(FLEET_SCRIPT)
	var viewport := _viewport()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	sea.mesh = plane
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.1, 0.28, 0.34)
	sea.material_override = sea_mat
	viewport.add_child(sea)
	var camera := Camera3D.new()
	camera.far = 600.0
	viewport.add_child(camera)
	camera.current = true
	var x := 0.0
	var seeds: Array[String] = ["lineup.a", "lineup.c"]
	for design: StringName in fleet.designs():
		var s: Dictionary = fleet.spec(design)
		var beam := float(s["beam"])
		for row in 2:
			var variant: Dictionary = fleet.variant_for(design, 1343, seeds[row])
			var vessel: Node3D = fleet.build(variant)
			vessel.position = Vector3(row * -14.0, -float(s["draught"]), x + beam * 0.5)
			fleet.set_sail(vessel, row == 1)
			viewport.add_child(vessel)
		x += beam + 3.0
	MapViewMaterials.apply_world_wind(Vector2(-1, 0), 0.6)
	for view: Array in [
		["lineup_side", Vector3(30.0, 7.0, x * 0.5), Vector3(-6.0, 2.5, x * 0.5), 55.0],
		["lineup_quarter", Vector3(22.0, 16.0, -10.0), Vector3(-6.0, 1.0, x * 0.5), 55.0],
	]:
		camera.fov = view[3]
		camera.look_at_from_position(view[1], view[2], Vector3.UP)
		for i in 20:
			await process_frame
		await _save(viewport, view[0])
	viewport.queue_free()


func _city() -> void:
	var plan := CityPlan.load_default()
	var viewport := _viewport()
	var view := CityMapView.create_city(plan)
	viewport.add_child(view)
	var world := view.world
	var camera := view.view_camera()
	camera.far = 4000.0
	camera.near = 0.05
	camera.current = true
	world.sky_weather.auto_weather = false
	world.sky_weather.set_process(false)
	# Centre of the six Kalamaja clinker boats.
	var centre := Vector2.ZERO
	var count := 0
	for boat: Dictionary in plan.data["harbour"]["boats"]:
		if String(boat["type"]) == "clinker":
			centre += Vector2(boat["at"][0], boat["at"][1])
			count += 1
	centre /= float(maxi(count, 1))
	var beach := Vector3(centre.x, plan.ground_height(centre), centre.y)
	var landing := plan.point_of_interest("poi.fish_landing")
	var shore := Vector2(landing["at"][0], landing["at"][1]) if not landing.is_empty() else centre
	# The fish landing, its lighters and afloat boats, with the anchored cogs beyond.
	var roads := Vector3(shore.x - 60.0, 0.0, shore.y - 120.0)
	var shots: Array[Dictionary] = []
	var seas: Array = [
		["clear", 0.2, 0.0, SkyWeather3D.WEATHER_CLEAR],
		["storm", 0.95, 0.6, SkyWeather3D.WEATHER_RAIN],
	]
	for sea: Array in seas:
		shots.append(
			{
				"name": "kalamaja_%s" % sea[0], "eye": beach + Vector3(28.0, 22.0, 26.0),
				"look": beach + Vector3(0, 0.5, 0), "fov": 55.0,
				"wind": sea[1], "rain": sea[2], "weather": sea[3],
			}
		)
		shots.append(
			{
				"name": "roads_%s" % sea[0], "eye": Vector3(shore.x + 40.0, 18.0, shore.y + 10.0),
				"look": roads, "fov": 55.0,
				"wind": sea[1], "rain": sea[2], "weather": sea[3],
			}
		)
	for shot in shots:
		if not _wanted(shot["name"]):
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.sky_weather.set_weather(shot["weather"])
		world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		view.apply_cycle_progress(NOON)
		var wind_dir := Vector2(0.4, -0.9)
		MapViewMaterials.apply_sea_weather(shot["wind"], shot["rain"], wind_dir)
		MapViewMaterials.apply_world_wind(wind_dir, shot["wind"])
		world.set_wind(wind_dir)
		for i in 40:
			MapViewRuntimeEnvironment.advance_ocean_time(0.05)
			await process_frame
		await _save(viewport, shot["name"])
	viewport.queue_free()
