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


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--advance="):
			_advance = float(arg.substr(10))
	call_deferred("_run")


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var crane: Array = plan.data["harbour"]["crane"]["at"]
	var landing := Vector2(crane[0], crane[1])
	var g := plan.ground_height(landing)
	var shots: Array[Dictionary] = []
	var schools := CityFish.school_centres(plan)
	if not schools.is_empty():
		var best: Dictionary = schools[0]
		for sc: Dictionary in schools:
			if (sc["at"] as Vector2).distance_to(landing) < (best["at"] as Vector2).distance_to(landing):
				best = sc
		var f: Vector2 = best["at"]
		shots.append({
			"name": "fish",
			"wind": 0.1,
			"rain": 0.0,
			"eye": Vector3(f.x - 2.0, 2.2, f.y + 3.5),
			"look": Vector3(f.x, -0.2, f.y),
			"fov": 60.0,
			"focus": f,
		})
	for sea: Array in [["calm", 0.1, 0.0], ["storm", 0.95, 0.6]]:
		shots.append({
			"name": "sea_%s_wide" % sea[0],
			"wind": sea[1],
			"rain": sea[2],
			"eye": Vector3(landing.x - 30.0, 7.0, landing.y + 20.0),
			"look": Vector3(landing.x + 10.0, 0.0, landing.y - 90.0),
			"fov": 60.0,
			"focus": landing,
		})
		shots.append({
			"name": "sea_%s_shore" % sea[0],
			"wind": sea[1],
			"rain": sea[2],
			"eye": Vector3(
				landing.x - 60.0,
				maxf(plan.ground_height(landing + Vector2(-60.0, 8.0)), 0.0) + 1.8,
				landing.y + 8.0
			),
			"look": Vector3(landing.x + 20.0, 0.3, landing.y - 6.0),
			"fov": 65.0,
			"focus": landing,
		})
		shots.append({
			"name": "sea_%s_beach_close" % sea[0],
			"wind": sea[1],
			"rain": sea[2],
			"eye": Vector3(
				landing.x - 20.0,
				maxf(plan.ground_height(landing + Vector2(-20.0, 4.0)), 0.0) + 1.0,
				landing.y + 4.0
			),
			"look": Vector3(landing.x - 5.0, 0.0, landing.y - 8.0),
			"fov": 65.0,
			"focus": landing,
		})
	shots.append_array(_surf_shots(plan, landing))
	return shots


## Close surf plates: eye 1.7 m up and 7 units back from the nearest beach waterline
## west of the landing, looking seaward along the shore, in calm and in a gale.
func _surf_shots(plan: CityPlan, landing: Vector2) -> Array[Dictionary]:
	var shore: Dictionary = preload("res://scripts/city/city_shore_field.gd").bake(plan)
	var contour: PackedVector2Array = shore["contour"]
	var best := contour[0]
	var target := landing + Vector2(-25.0, 0.0)
	for point in contour:
		if point.distance_to(target) < best.distance_to(target):
			best = point
	var uphill := Vector2(
		plan.ground_height(best + Vector2(1, 0)) - plan.ground_height(best - Vector2(1, 0)),
		plan.ground_height(best + Vector2(0, 1)) - plan.ground_height(best - Vector2(0, 1))
	).normalized()
	var along := Vector2(-uphill.y, uphill.x)
	var eye2 := best + uphill * 7.0 + along * 4.0
	var look2 := best - uphill * 9.0 - along * 6.0
	var out: Array[Dictionary] = []
	for sea: Array in [["calm", 0.1, 0.0], ["fresh", 0.55, 0.0], ["storm", 0.95, 0.6]]:
		out.append({"name": "surf_%s" % sea[0], "wind": sea[1], "rain": sea[2],
			"eye": Vector3(eye2.x, plan.ground_height(eye2) + 1.7, eye2.y),
			"look": Vector3(look2.x, 0.2, look2.y), "fov": 70.0, "focus": best})
	# Side-on plate: the wave train in profile, rolling in towards the beach.
	var side_eye := best + uphill * 3.0 + along * 16.0
	var side_look := best - uphill * 10.0 - along * 4.0
	for sea: Array in [["calm", 0.1, 0.0], ["fresh", 0.55, 0.0], ["storm", 0.95, 0.6]]:
		out.append({"name": "surf_side_%s" % sea[0], "wind": sea[1], "rain": sea[2],
			"eye": Vector3(side_eye.x, plan.ground_height(side_eye) + 1.4, side_eye.y),
			"look": Vector3(side_look.x, 0.0, side_look.y), "fov": 65.0, "focus": best})
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	camera.near = 0.1
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	for shot in _shots(plan):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		MapViewMaterials.apply_sea_weather(shot["wind"], shot["rain"], Vector2(0.4, -0.9))
		if world.spray != null:
			world.spray.set_wind(shot["wind"])
		var dummy := Node2D.new()
		dummy.global_position = CityPlan.to_logic(shot["focus"])
		root.add_child(dummy)
		var fish := CityFish.create(plan, dummy)
		world.add_child(fish)
		MapViewRuntimeEnvironment.advance_ocean_time(_advance)
		for i in 40:
			MapViewRuntimeEnvironment.advance_ocean_time(0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		if world.spray != null:
			var live := 0
			for e in world.spray.get_children():
				live += int(e.emitting and e.visible)
			print("spray emitters live: ", live, " first at ", world.spray.get_child(0).global_position)
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured ", path, " fish schools live: ", fish.live_count())
		fish.queue_free()
		dummy.queue_free()
	quit(0)
