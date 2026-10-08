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
	for g: Dictionary in plan.data.get("gates", []):
		if String(g["id"]) != "gate.viru":
			continue
		var at := Vector2(g["at"][0], g["at"][1])
		var gh := plan.ground_height(at)
		shots.append({"name": "viru_gate_out", "eye": Vector3(at.x + 34.0, gh + 2.6, at.y), "look": Vector3(at.x, gh + 4.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
		shots.append({"name": "viru_aerial", "eye": Vector3(at.x + 38.0, gh + 34.0, at.y + 38.0), "look": Vector3(at.x + 6.0, gh + 3.0, at.y), "fov": 50.0, "focus": at})  # gdlint: ignore=max-line-length
		shots.append({"name": "viru_gate_side", "eye": Vector3(at.x + 30.0, gh + 12.0, at.y + 45.0), "look": Vector3(at.x, gh + 2.0, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	for spot: Array in [["moat_reeds", Vector2(228.0, -250.0)]]:
		var at: Vector2 = spot[1]
		var g := plan.ground_height(at)
		shots.append({"name": spot[0], "eye": Vector3(at.x + 14.0, g + 5.2, at.y + 8.0), "look": Vector3(at.x - 2.0, g + 1.0, at.y - 4.0), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	for spot: Array in [["moat_east_a", Vector2(215.0, -300.0)], ["moat_east_b", Vector2(262.0, -60.0)], ["moat_east_c", Vector2(232.0, -470.0)]]:  # gdlint: ignore=max-line-length
		var at: Vector2 = spot[1]
		var g := plan.ground_height(at)
		shots.append({"name": spot[0], "eye": Vector3(at.x + 30.0, g + 14.0, at.y), "look": Vector3(at.x, g, at.y), "fov": 60.0, "focus": at})  # gdlint: ignore=max-line-length
	# Far view: the wheat strips from a vantage 120 m off, as the player sees them.
	var wheat := _feature(plan, &"field", &"wheat")
	if not wheat.is_empty():
		var c: Vector2 = wheat["centre"]
		var g := plan.ground_height(c)
		shots.append({"name": "wheat_far", "eye": Vector3(c.x + 70.0, g + 30.0, c.y + 90.0), "look": Vector3(c.x, g, c.y), "fov": 55.0, "focus": c})
		shots.append({"name": "wheat_wide", "eye": Vector3(c.x + 160.0, g + 70.0, c.y + 200.0), "look": Vector3(c.x, g, c.y), "fov": 55.0, "focus": c})
	# Farmsteads: the yard round one barn-dwelling and round the plainest croft.
	for want: String in ["barn_dwelling", "hen_house"]:
		for b: Dictionary in plan.data["buildings"]:
			if String(b.get("type", "")) != want:
				continue
			var fp := CityPlan.points(b["footprint"])
			var at := fp[0]
			var g := plan.ground_height(at)
			shots.append({"name": "yard_%s" % want, "eye": Vector3(at.x + 22.0, g + 9.0, at.y + 22.0), "look": Vector3(at.x, g + 1.5, at.y), "fov": 60.0, "focus": at})
			shots.append({"name": "yard_%s_close" % want, "eye": Vector3(at.x + 9.0, g + 2.4, at.y + 9.0), "look": Vector3(at.x, g + 1.2, at.y), "fov": 60.0, "focus": at})
			break
	# Harbour: the merchant landing and the Kalamaja fishing shore.
	var harbour: Dictionary = plan.data.get("harbour", {})
	if not harbour.is_empty():
		var crane_at := Vector2(harbour["crane"]["at"][0], harbour["crane"]["at"][1])
		shots.append({"name": "harbour_landing", "eye": Vector3(crane_at.x - 28.0, 9.0, crane_at.y + 26.0), "look": Vector3(crane_at.x, 3.0, crane_at.y - 6.0), "fov": 60.0, "focus": crane_at})
		shots.append({"name": "harbour_landing_sea", "eye": Vector3(crane_at.x + 10.0, 6.0, crane_at.y - 50.0), "look": Vector3(crane_at.x, 2.0, crane_at.y), "fov": 60.0, "focus": crane_at})
		var lighter: Dictionary = {}
		var turned: Dictionary = {}
		for b: Dictionary in harbour["boats"]:
			if b.get("type", "") == "lighter" and lighter.is_empty():
				lighter = b
			if b.get("type", "") == "overturned" and turned.is_empty():
				turned = b
		if not lighter.is_empty():
			var lp := Vector2(lighter["at"][0], lighter["at"][1])
			shots.append({"name": "harbour_lighter", "eye": Vector3(lp.x - 14.0, 5.0, lp.y + 16.0), "look": Vector3(lp.x, 0.5, lp.y), "fov": 60.0, "focus": lp})
		if not turned.is_empty():
			var tp := Vector2(turned["at"][0], turned["at"][1])
			shots.append({"name": "harbour_overturned", "eye": Vector3(tp.x - 8.0, plan.ground_height(tp) + 3.0, tp.y + 9.0), "look": Vector3(tp.x, plan.ground_height(tp) + 1.0, tp.y), "fov": 60.0, "focus": tp})
		var yard: Dictionary = harbour["net_yards"][0]
		var yc := CityPlan.points(yard["polygon"])[0]
		shots.append({"name": "harbour_kalamaja", "eye": Vector3(yc.x - 18.0, 8.0, yc.y + 24.0), "look": Vector3(yc.x + 8.0, 1.5, yc.y - 6.0), "fov": 60.0, "focus": yc})
		shots.append({"name": "harbour_kalamaja_eye", "eye": Vector3(yc.x + 2.0, plan.ground_height(yc) + 1.8, yc.y + 14.0), "look": Vector3(yc.x + 6.0, 1.2, yc.y - 6.0), "fov": 60.0, "focus": yc})
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
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured %s at %s (farm features live: %d)" % [path, shot["focus"], world.farmland.live_count()])  # gdlint: ignore=max-line-length
	quit(0)
