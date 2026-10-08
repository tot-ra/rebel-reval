extends SceneTree

## Review plates for the farmed country (docs/SYSTEMS/FARMLAND.md): fields at
## eye level and from the gameplay camera, a fenced croft, a wood edge and the
## shore shrubs. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_farmland.gd [-- --tag=now]
##     [--only=<shot>[,<shot>...]] [--date=4-21]
## Output: build/farmland/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/farmland"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42

var _tag := "now"
var _only := ""
var _date := {"year": 1343, "month": 4, "day": 21}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--date="):
			var md := arg.substr(7).split("-")
			_date = {"year": 1343, "month": int(md[0]), "day": int(md[1])}
	call_deferred("_run")


## Nearest feature of a kind to a probe point, by id prefix.
func _feature(plan: CityPlan, kind: StringName, crop: StringName = &"") -> Dictionary:
	var best := {}
	var best_d := INF
	for f in CityFarmland.features_for(plan):
		if f["kind"] != kind or (crop != &"" and f.get("crop", &"") != crop):
			continue
		var d := (f["centre"] as Vector2).length()
		if d < best_d:
			best_d = d
			best = f
	return best


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for crop: StringName in [&"rye", &"barley", &"cabbage"]:
		var f := _feature(plan, &"field", crop)
		if f.is_empty():
			continue
		var c: Vector2 = f["centre"]
		var g := plan.ground_height(c)
		var side := Vector2(1, 0.4).normalized()
		shots.append({"name": "field_%s_top" % crop, "eye": Vector3(c.x, g + 70.0, c.y + 1.0), "look": Vector3(c.x, g, c.y), "fov": 50.0, "focus": c})  # gdlint: ignore=max-line-length
		shots.append({"name": "field_%s_eye" % crop, "eye": Vector3(c.x + side.x * 5.0, g + 1.7, c.y + side.y * 5.0), "look": Vector3(c.x, g + 0.4, c.y), "fov": 60.0, "focus": c})  # gdlint: ignore=max-line-length
		shots.append({"name": "field_%s_game" % crop, "eye": Vector3(c.x + side.x * 14.0, g + 6.0, c.y + side.y * 14.0), "look": Vector3(c.x, g, c.y), "fov": 60.0, "focus": c})  # gdlint: ignore=max-line-length
	# The north wall: towers seen from the field side.
	for id: String in ["tower.stolting", "tower.rentenitorn", "gate.coastal.tower"]:
		for t: Dictionary in plan.data.get("towers", []):
			if String(t["id"]) != id:
				continue
			var at := Vector2(t["at"][0], t["at"][1])
			var out := (at - Vector2(100.0, -250.0)).normalized()
			var g := plan.ground_height(at)
			shots.append({"name": "wall_%s" % id.replace(".", "_"), "eye": Vector3(at.x + out.x * 20.0, g + 7.0, at.y + out.y * 20.0), "look": Vector3(at.x, g + 5.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
			shots.append({"name": "wall_%s_in" % id.replace(".", "_"), "eye": Vector3(at.x - out.x * 14.0, g + 9.0, at.y - out.y * 14.0), "look": Vector3(at.x, g + 5.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	# Overviews of the north curtain, outside and inside.
	for spot: Array in [["north_a", Vector2(233.0, -540.0)], ["north_b", Vector2(241.0, -492.0)], ["north_c", Vector2(185.0, -575.0)], ["north_d", Vector2(110.0, -555.0)]]:  # gdlint: ignore=max-line-length
		var at: Vector2 = spot[1]
		var out := (at - Vector2(100.0, -250.0)).normalized()
		var g := plan.ground_height(at)
		shots.append({"name": "%s_out" % spot[0], "eye": Vector3(at.x + out.x * 28.0, g + 14.0, at.y + out.y * 28.0), "look": Vector3(at.x, g + 4.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
		shots.append({"name": "%s_top" % spot[0], "eye": Vector3(at.x, g + 30.0, at.y + 1.0), "look": Vector3(at.x, g, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	for b: Dictionary in plan.data.get("bridges", []):
		var at := Vector2(b["at"][0], b["at"][1])
		var g := plan.ground_height(at)
		var across := Vector2.from_angle(float(b["angle"])).orthogonal()
		var along := Vector2.from_angle(float(b["angle"]))
		shots.append({"name": "%s_side" % String(b["id"]).replace(".", "_"), "eye": Vector3(at.x + across.x * 26.0, 14.0, at.y + across.y * 26.0), "look": Vector3(at.x, 6.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
		var start := at - along * 20.0
		shots.append({"name": "%s_walk" % String(b["id"]).replace(".", "_"), "eye": Vector3(start.x, plan.ground_height(start) + 3.0, start.y), "look": Vector3(at.x, 8.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	for spot: Array in [["moat_east_a", Vector2(215.0, -300.0)], ["moat_east_b", Vector2(262.0, -60.0)], ["moat_east_c", Vector2(232.0, -470.0)]]:  # gdlint: ignore=max-line-length
		var at: Vector2 = spot[1]
		var g := plan.ground_height(at)
		shots.append({"name": spot[0], "eye": Vector3(at.x + 30.0, g + 14.0, at.y), "look": Vector3(at.x, g, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	var pasture := _feature(plan, &"pasture")
	if not pasture.is_empty():
		var c: Vector2 = pasture["centre"]
		var g := plan.ground_height(c)
		shots.append({"name": "pasture", "eye": Vector3(c.x + 14.0, g + 5.0, c.y + 14.0), "look": Vector3(c.x, g + 0.5, c.y), "fov": 60.0, "focus": c})  # gdlint: ignore=max-line-length
	for species: String in ["juniper_shrub", "sea_buckthorn", "heather"]:
		for t: Array in plan.data.get("bushes", []):
			if String(t[2]) == species:
				var b := Vector2(t[0], t[1])
				var g := plan.ground_height(b)
				shots.append({"name": "shrub_%s" % species, "eye": Vector3(b.x + 5.0, g + 1.8, b.y + 5.0), "look": Vector3(b.x, g + 1.0, b.y), "fov": 60.0, "focus": b})  # gdlint: ignore=max-line-length
				break
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
	MapViewMaterials.apply_vegetation_season(_date)
	world.farmland.set_calendar_date(_date)
	for shot in _shots(plan):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		for i in 40:
			world.grass.update_for(shot["focus"])
			world.farmland.update_for(shot["focus"])
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured %s at %s (farm features live: %d)" % [path, shot["focus"], world.farmland.live_count()])  # gdlint: ignore=max-line-length
	quit(0)
