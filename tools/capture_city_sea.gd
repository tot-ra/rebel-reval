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


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var landing := Vector2(plan.data["harbour"]["crane"]["at"][0], plan.data["harbour"]["crane"]["at"][1])
	var g := plan.ground_height(landing)
	var shots: Array[Dictionary] = []
	var schools := CityFish.school_centres(plan)
	if not schools.is_empty():
		var best: Dictionary = schools[0]
		for sc: Dictionary in schools:
			if (sc["at"] as Vector2).distance_to(landing) < (best["at"] as Vector2).distance_to(landing):
				best = sc
		var f: Vector2 = best["at"]
		shots.append({"name": "fish", "wind": 0.1, "rain": 0.0, "eye": Vector3(f.x - 2.0, 2.2, f.y + 3.5), "look": Vector3(f.x, -0.2, f.y), "fov": 60.0, "focus": f})
	for sea: Array in [["calm", 0.1, 0.0], ["storm", 0.95, 0.6]]:
		shots.append({"name": "sea_%s_wide" % sea[0], "wind": sea[1], "rain": sea[2], "eye": Vector3(landing.x - 30.0, 7.0, landing.y + 20.0), "look": Vector3(landing.x + 10.0, 0.0, landing.y - 90.0), "fov": 60.0, "focus": landing})
		shots.append({"name": "sea_%s_shore" % sea[0], "wind": sea[1], "rain": sea[2], "eye": Vector3(landing.x - 60.0, maxf(plan.ground_height(landing + Vector2(-60.0, 8.0)), 0.0) + 1.8, landing.y + 8.0), "look": Vector3(landing.x + 20.0, 0.3, landing.y - 6.0), "fov": 65.0, "focus": landing})
		shots.append({"name": "sea_%s_beach_close" % sea[0], "wind": sea[1], "rain": sea[2], "eye": Vector3(landing.x - 20.0, maxf(plan.ground_height(landing + Vector2(-20.0, 4.0)), 0.0) + 1.0, landing.y + 4.0), "look": Vector3(landing.x - 5.0, 0.0, landing.y - 8.0), "fov": 65.0, "focus": landing})
	return shots


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
		var dummy := Node2D.new()
		dummy.global_position = CityPlan.to_logic(shot["focus"])
		root.add_child(dummy)
		var fish := CityFish.create(plan, dummy)
		world.add_child(fish)
		for i in 40:
			MapViewRuntimeEnvironment.advance_ocean_time(0.05)
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured ", path, " fish schools live: ", fish.live_count())
		fish.queue_free()
		dummy.queue_free()
	quit(0)
