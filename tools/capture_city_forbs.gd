extends SceneTree

## Review plates for the wild plants of the seamless city (R-1519,
## docs/SYSTEMS/VEGETATION_REALISM.md): a studio lineup and close-ups of every
## CityForbMeshes model, then in-world shots where each habitat is strongest
## (worn verge, wall foot, open meadow). The in-world shots grow the plants
## for a campaign date (R-1557): --season=spring|early_summer|summer|autumn|winter
## or --date=YYYY-MM-DD (default: summer). Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_forbs.gd \
##     [-- --season=autumn] [--tag=now] [--studio-only]
## Output: build/forbs/<shot>_<tag>.png (tag defaults to the season name).

const Meshes := preload("res://scripts/city/city_forb_meshes.gd")
const OUTPUT_DIR := "res://build/forbs"
const VIEWPORT_SIZE := Vector2i(1600, 900)
## Representative dates for the forb phases (VegetationPhenology.forb_phase).
const SEASONS := {
	"spring": {"day": 20, "month": 5, "year": 1343},
	"early_summer": {"day": 15, "month": 6, "year": 1343},
	"summer": {"day": 20, "month": 7, "year": 1343},
	"autumn": {"day": 1, "month": 10, "year": 1343},
	"winter": {"day": 15, "month": 1, "year": 1343},
}

var _tag := ""
var _studio_only := false
var _date: Dictionary = SEASONS["summer"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg == "--studio-only":
			_studio_only = true
		elif arg.begins_with("--season="):
			var season := arg.substr(9)
			if not SEASONS.has(season):
				push_error("unknown season %s (%s)" % [season, ", ".join(SEASONS.keys())])
				quit(1)
				return
			_date = SEASONS[season]
			if _tag.is_empty():
				_tag = season
		elif arg.begins_with("--date="):
			var parts := arg.substr(7).split("-")
			_date = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
			if _tag.is_empty():
				_tag = arg.substr(7)
	if _tag.is_empty():
		_tag = "summer"
	print("forbs for %s: %s" % [GameCalendar.format_date(_date), CityForbs.season_key(
		GameCalendar.day_of_year(_date))])
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _studio()
	if not _studio_only:
		await _in_world()
	quit(0)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _save(viewport: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, name, _tag]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)


## Every model on a plain turf plane under a soft summer sun.
func _studio() -> void:
	var viewport := _viewport()
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	ground.mesh = plane
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color(0.30, 0.34, 0.17)
	turf.roughness = 1.0
	ground.material_override = turf
	viewport.add_child(ground)
	var spots := {
		Meshes.KIND_DANDELION_FLOWER: Vector3(-1.05, 0.0, 0.0),
		Meshes.KIND_DANDELION_CLOCK: Vector3(-0.55, 0.0, 0.25),
		Meshes.KIND_DANDELION_LEAVES: Vector3(-0.15, 0.0, -0.15),
		Meshes.KIND_PLANTAIN: Vector3(0.3, 0.0, 0.25),
		Meshes.KIND_WHITE_CLOVER: Vector3(0.75, 0.0, -0.05),
		Meshes.KIND_RED_CLOVER: Vector3(1.2, 0.0, 0.25),
		Meshes.KIND_BURDOCK: Vector3(-0.4, 0.0, -1.4),
		Meshes.KIND_BURDOCK_FLOWERING: Vector3(0.9, 0.0, -1.5),
		# Seasonal variants in a second row 4 m to the right (shot "seasonal").
		Meshes.KIND_PLANTAIN_LEAVES: Vector3(3.55, 0.0, 0.25),
		Meshes.KIND_WHITE_CLOVER_LEAVES: Vector3(4.05, 0.0, -0.05),
		Meshes.KIND_RED_CLOVER_LEAVES: Vector3(4.55, 0.0, 0.25),
		Meshes.KIND_BURDOCK_DRY: Vector3(4.1, 0.0, -1.5),
	}
	for kind: StringName in spots:
		var plant := MeshInstance3D.new()
		plant.mesh = Meshes.mesh_for(kind)
		var large := kind in CityForbs.LARGE_KINDS
		plant.material_override = CityForbs.material(large)
		plant.position = spots[kind]
		viewport.add_child(plant)
		print("%s: %d triangles" % [kind, Meshes.triangle_count(kind)])
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	# name, eye, look-at, fov
	var shots := [
		["lineup", Vector3(0.1, 1.05, 2.3), Vector3(0.1, 0.25, -0.4), 50.0],
		["dandelion", Vector3(-0.85, 0.32, 0.55), Vector3(-0.8, 0.12, 0.08), 45.0],
		["dandelion_clock", Vector3(-0.55, 0.42, 0.65), Vector3(-0.55, 0.20, 0.25), 40.0],
		["plantain", Vector3(0.3, 0.42, 0.68), Vector3(0.3, 0.06, 0.25), 45.0],
		["clover", Vector3(0.85, 0.42, 0.42), Vector3(0.9, 0.06, 0.05), 45.0],
		["burdock", Vector3(0.3, 1.1, 0.6), Vector3(0.25, 0.45, -1.45), 50.0],
		["seasonal", Vector3(4.1, 1.05, 2.3), Vector3(4.1, 0.25, -0.4), 50.0],
		["burdock_dry", Vector3(4.15, 1.1, 0.6), Vector3(4.1, 0.45, -1.45), 50.0],
	]
	for shot: Array in shots:
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2], Vector3.UP)
		for i in 4:
			await process_frame
		await _save(viewport, shot[0])
	viewport.queue_free()


## The city at midday, cameras on the spots where each habitat is strongest.
func _in_world() -> void:
	var viewport := _viewport()
	var plan := CityPlan.load_default()
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	var grass: CityGrass = world.grass
	# Trees, crops and wild plants all follow the capture date.
	MapViewMaterials.apply_vegetation_season(_date)
	world.farmland.set_calendar_date(_date)
	grass.forbs.set_calendar_date(_date)
	var spots := _habitat_spots(plan, grass)
	for name: String in spots:
		var spot: Vector2 = spots[name]["at"]
		var look_dir: Vector2 = spots[name]["dir"]
		var g := plan.ground_height(spot)
		for view: Array in [["eye", 3.2, 1.6, 50.0], ["low", 1.4, 0.55, 55.0]]:
			var eye_xz: Vector2 = spot - look_dir * float(view[1])
			var eye := Vector3(eye_xz.x, plan.ground_height(eye_xz) + float(view[2]), eye_xz.y)
			camera.fov = view[3]
			camera.look_at_from_position(eye, Vector3(spot.x, g + 0.1, spot.y), Vector3.UP)
			world.apply_time(0.45)
			for i in 90:
				grass.update_for(Vector2(eye.x, eye.z))
				await process_frame
			await _save(viewport, "%s_%s" % [name, view[0]])
	viewport.queue_free()


## Best spot per habitat near the pasture the grass plates use, looking along
## the habitat (the verge shot looks along the road edge).
func _habitat_spots(plan: CityPlan, grass: CityGrass) -> Dictionary:
	var focus := Vector2.ZERO
	var best := INF
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"pasture" and (f["centre"] as Vector2).length() < best:
			best = (f["centre"] as Vector2).length()
			focus = f["centre"]
	var scores := {
		"verge": [Meshes.KIND_PLANTAIN, &"dandelion", Meshes.KIND_WHITE_CLOVER],
		"wall": [&"burdock", Meshes.KIND_PLANTAIN],
		"meadow": [Meshes.KIND_RED_CLOVER, &"dandelion"],
	}
	var out := {}
	for name: String in scores:
		var top := -1.0
		for y in range(-160, 161, 4):
			for x in range(-160, 161, 4):
				var p := focus + Vector2(x, y)
				if is_nan(grass.plant_ground_height(p)) or grass.bareness_at(p) > 0.5:
					continue
				var score := 0.0
				for species: StringName in scores[name]:
					for o: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0), Vector2(0, -2)]:
						score += CityForbs.suitability(grass, species, p + o)
				if score > top:
					top = score
					out[name] = {"at": p, "dir": Vector2(1, 0.4).normalized()}
		print("%s spot %s score %.2f" % [name, out.get(name, {}).get("at"), top])
	return out
