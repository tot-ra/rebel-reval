extends SceneTree

## ADR 0031 review captures of the continuous Reval city. Renders an aerial
## overview and street-level shots along named streets. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_reval_city.gd [-- --only=<shot>[,<shot>...]]
## Output: docs/reports/images/city/<shot>.png

const OUTPUT_DIR := "res://docs/reports/images/city"
const VIEWPORT_SIZE := Vector2i(1600, 900)
## Cycle progress for captures (0.42 ~ late morning).
const DAY_PROGRESS := 0.42

var _only := ""
## World children to hide (debugging which layer draws something).
var _hide: PackedStringArray = []
var _wet := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		if arg == "--wet":
			_wet = true
		if arg.begins_with("--hide="):
			_hide = arg.substr(7).split(",")
	call_deferred("_run")


func _street_point(plan: CityPlan, name: String, t: float) -> Dictionary:
	var pts := PackedVector2Array()
	for s: Dictionary in plan.streets:
		if s["name"] == name:
			for p: Array in s["points"]:
				pts.append(Vector2(p[0], p[1]))
	if pts.size() < 2:
		return {}
	var idx := clampi(int(t * (pts.size() - 1)), 0, pts.size() - 2)
	var a := pts[idx]
	var b := pts[idx + 1]
	return {"at": a.lerp(b, 0.5), "dir": (b - a).normalized()}


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var c := plan.bounds.get_center()
	shots.append(
		{
			"name": "city_aerial_ne",
			"eye": Vector3(700, 380, -900),
			"look": Vector3(-80, 20, -150),
			"fov": 50.0
		}
	)
	shots.append(
		{
			"name": "city_aerial_s",
			"eye": Vector3(-150, 330, 700),
			"look": Vector3(-60, 20, -200),
			"fov": 50.0
		}
	)
	shots.append(
		{
			"name": "city_toompea_from_east",
			"eye": Vector3(60, 90, 40),
			"look": Vector3(-380, 45, 80),
			"fov": 55.0
		}
	)
	for spec: Array in [
		["street_pikk_jalg", "Pikk jalg", 0.45, 1.0],
		["street_luhike_jalg", "Lühike jalg", 0.3, 1.0],
		["street_viru", "Viru", 0.3, 1.0],
		["street_vene", "Vene", 0.5, 1.0],
		["street_pikk", "Pikk", 0.5, 1.0],
		["street_lai", "Lai", 0.4, 1.0],
		["street_harju", "Harju", 0.5, -1.0],
	]:
		var sp := _street_point(plan, spec[1], spec[2])
		if sp.is_empty():
			continue
		var at: Vector2 = sp["at"]
		var dir: Vector2 = sp["dir"] * float(spec[3])
		var g := plan.walk_height(at)
		(
			shots
			. append(
				{
					"name": spec[0],
					"eye": Vector3(at.x - dir.x * 4.0, g + 2.0, at.y - dir.y * 4.0),
					"look":
					Vector3(
						at.x + dir.x * 30.0,
						g + 3.0 + (plan.walk_height(at + dir * 30.0) - g),
						at.y + dir.y * 30.0
					),
					"fov": 62.0,
				}
			)
		)
	var forum: Array = plan.data["forum"]["polygon"]
	var fc := Vector2.ZERO
	for p: Array in forum:
		fc += Vector2(p[0], p[1])
	fc /= forum.size()
	shots.append(
		{
			"name": "forum",
			"eye": Vector3(fc.x + 22, plan.ground_height(fc) + 2.2, fc.y - 34),
			"look": Vector3(fc.x, plan.ground_height(fc) + 4.0, fc.y + 10),
			"fov": 62.0
		}
	)
	var coastal := plan.gate("gate.coastal")
	var ca := Vector2(coastal["at"][0], coastal["at"][1])
	shots.append(
		{
			"name": "gate_coastal_from_harbour",
			"eye": Vector3(ca.x + 6, plan.ground_height(ca + Vector2(0, -70)) + 2.2, ca.y - 70),
			"look": Vector3(ca.x, plan.ground_height(ca) + 6.0, ca.y),
			"fov": 58.0
		}
	)
	var viru := plan.gate("gate.viru")
	var va := Vector2(viru["at"][0], viru["at"][1])
	shots.append(
		{
			"name": "gate_viru_from_outside",
			"eye": Vector3(va.x + 70, plan.ground_height(va + Vector2(70, -4)) + 2.2, va.y - 4),
			"look": Vector3(va.x, plan.ground_height(va) + 4.0, va.y),
			"fov": 58.0
		}
	)
	# Concept-style oblique views of the gates from above the town side.
	var vh := plan.ground_height(va)
	shots.append(
		{
			"name": "viru_gate_aerial",
			"eye": Vector3(va.x - 48, vh + 34, va.y - 26),
			"look": Vector3(va.x + 4, vh + 3, va.y + 2),
			"fov": 50.0
		}
	)
	shots.append(
		{
			"name": "coastal_gate_aerial",
			"eye": Vector3(ca.x - 40, plan.ground_height(ca) + 36, ca.y + 40),
			"look": Vector3(ca.x, plan.ground_height(ca) + 4, ca.y),
			"fov": 50.0
		}
	)
	# Street doors of a few houses near the forum (styles vary per house).
	var picked := 0
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if b.get("door") == null or picked >= 3:
			continue
		var door := Vector2(b["door"][0], b["door"][1])
		if door.length() > 60.0 or i % 7 != 0:
			continue
		# Frame from the street side of the door gap actually built.
		var gap := CityDoors.door_gap(plan, i)
		if gap.is_empty():
			continue
		var out: Vector2 = -gap["inward"]
		door = (gap["a"] + gap["b"]) * 0.5
		var fh := plan.floor_height(i)
		# Stand in the street: the nearest distance that is not inside a house.
		var eye := Vector2.INF
		for dist: float in [4.5, 3.6, 2.8]:
			var cand := door + out * dist + Vector2(out.y, -out.x) * dist * 0.27
			if plan.building_at(cand) < 0:
				eye = cand
				break
		if eye == Vector2.INF:
			continue  # door opens onto a neighbour's wall: no street view
		(
			shots
			. append(
				{
					"name": "door_%d" % picked,
					"eye": Vector3(eye.x, maxf(fh, plan.ground_height(eye)) + 1.6, eye.y),
					"look": Vector3(door.x, fh + 1.3, door.y),
					"fov": 55.0,
				}
			)
		)
		picked += 1
	# Landmark sites (ADR 0032): concept-style aerial, straight down, cutaway,
	# the main door from outside, and the biggest room looking along the axis.
	for site in plan.sites:
		var sname := String(site.id).trim_prefix("site.")
		var box := site.bounds()
		var sc := box.get_center()
		var sy := site.level
		var span := maxf(box.size.x, box.size.y)
		var axis := Vector2.from_angle(site.rotation)
		var side := Vector2(-axis.y, axis.x)
		var aerial := sc - axis * span * 0.35 + side * span * 0.55
		shots.append(
			{
				"name": "%s_aerial" % sname,
				"eye": Vector3(aerial.x, sy + span * 0.9, aerial.y),
				"look": Vector3(sc.x, sy + 4.0, sc.y),
				"fov": 50.0
			}
		)
		shots.append(
			{
				"name": "%s_topdown" % sname,
				"eye": Vector3(sc.x, sy + span * 1.6, sc.y + 0.5),
				"look": Vector3(sc.x, sy, sc.y),
				"fov": 50.0
			}
		)
		shots.append(
			{
				"name": "%s_cutaway" % sname,
				"eye": Vector3(aerial.x, sy + span * 0.75, aerial.y),
				"look": Vector3(sc.x, sy + 0.5, sc.y),
				"fov": 50.0,
				"cutaway": true
			}
		)
		var d: Dictionary = site.doors[0] if site.doors.size() < 2 else site.doors[1]
		var door: Vector2 = (d["a"] + d["b"]) * 0.5
		var outside: Vector2 = (
			door
			- (d["inward"] as Vector2) * 14.0
			+ Vector2(-(d["inward"] as Vector2).y, (d["inward"] as Vector2).x) * 5.0
		)
		shots.append(
			{
				"name": "%s_street" % sname,
				"eye": Vector3(outside.x, plan.ground_height(outside) + 1.7, outside.y),
				"look": Vector3(door.x, sy + 5.0, door.y),
				"fov": 62.0
			}
		)
		var biggest: Dictionary = site.rooms[0]
		for r: Dictionary in site.rooms:
			var rr := Rect2(r["polygon"][0], Vector2.ZERO)
			for q: Vector2 in r["polygon"]:
				rr = rr.expand(q)
			var br := Rect2(biggest["polygon"][0], Vector2.ZERO)
			for q: Vector2 in biggest["polygon"]:
				br = br.expand(q)
			if rr.get_area() > br.get_area():
				biggest = r
		var lo := site.to_local((biggest["polygon"] as PackedVector2Array)[0])
		var hi := site.to_local((biggest["polygon"] as PackedVector2Array)[2])
		var inside := site.to_world(Vector2(lo.x + 1.2, (lo.y + hi.y) * 0.5 - 1.5))
		var toward := site.to_world(Vector2(hi.x + 6.0, (lo.y + hi.y) * 0.5 - 0.5))
		shots.append(
			{
				"name": "%s_interior" % sname,
				"eye": Vector3(inside.x, sy + 1.75, inside.y),
				"look": Vector3(toward.x, sy + 2.2, toward.y),
				"fov": 70.0
			}
		)
	# Per-site review views in the manifest (`review_shots`): eye and look in
	# site-local metres (x, y above the level, z), to match reference photos.
	for site in plan.sites:
		for v: Dictionary in site.data.get("review_shots", []):
			var e := site.to_world(Vector2(v["eye"][0], v["eye"][2]))
			var l := site.to_world(Vector2(v["look"][0], v["look"][2]))
			(
				shots
				. append(
					{
						"name": "%s_%s" % [String(site.id).trim_prefix("site."), v["id"]],
						"eye": Vector3(e.x, site.level + float(v["eye"][1]), e.y),
						"look": Vector3(l.x, site.level + float(v["look"][1]), l.y),
						"fov": float(v.get("fov", 60.0)),
						"cutaway": bool(v.get("cutaway", false)),
					}
				)
			)
	# Generic cutaway: Kalev's smithy with its roof and upper walls lifted.
	for i in plan.buildings.size():
		if String(plan.buildings[i].get("landmark_id", "")) == "landmark.kalev_smithy":
			var corner := CityPlan.points(plan.buildings[i]["footprint"])[0]
			var fy := plan.floor_height(i)
			shots.append(
				{
					"name": "smithy_cutaway",
					"eye": Vector3(corner.x + 14.0, fy + 18.0, corner.y + 14.0),
					"look": Vector3(corner.x - 6.0, fy, corner.y - 6.0),
					"fov": 55.0,
					"cutaway_building": i
				}
			)
	# Toompea Kiriku plats: St Mary's west door from the square, and from above.
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if String(b.get("landmark_id", "")) != "landmark.st_mary":
			continue
		var door := Vector2(b["door"][0], b["door"][1])
		var out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
		var gy := plan.ground_height(door + out * 20.0)
		shots.append(
			{
				"name": "kiriku_plats_st_mary",
				"eye": Vector3(door.x + out.x * 24.0, gy + 1.7, door.y + out.y * 24.0 + 6.0),
				"look": Vector3(door.x, plan.floor_height(i) + 6.0, door.y),
				"fov": 60.0
			}
		)
		shots.append(
			{
				"name": "kiriku_plats_aerial",
				"eye": Vector3(door.x + out.x * 45.0 - 30.0, gy + 45.0, door.y + 45.0),
				"look": Vector3(door.x - out.x * 15.0, plan.floor_height(i), door.y),
				"fov": 55.0
			}
		)
	var top := Vector2(-420, 20)
	shots.append(
		{
			"name": "from_toompea_over_roofs",
			"eye": Vector3(-262, plan.ground_height(Vector2(-262, 60)) + 16.0, 60),
			"look": Vector3(60, 18, -140),
			"fov": 60.0
		}
	)
	return shots


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var t0 := Time.get_ticks_msec()
	var plan := CityPlan.load_default()
	if plan.buildings.is_empty():
		push_error("City plan failed to load")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	camera.near = 0.15
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	for child in world.get_children():
		if child.name in _hide and child is Node3D:
			(child as Node3D).visible = false
			print("hidden %s" % child.name)
	world.apply_time(DAY_PROGRESS)
	print("city build stats: %s (total %d ms)" % [world.build_stats, Time.get_ticks_msec() - t0])
	for shot in _shots(plan):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		# Cutaway shots lift a site's rooms (roof, upper walls) as if Kalev were inside.
		for site in plan.sites:
			for r: Dictionary in site.rooms:
				world.set_site_room_hidden(site, r, bool(shot.get("cutaway", false)))
		if shot.has("cutaway_building"):
			world.set_roof_hidden(int(shot["cutaway_building"]), true)
		world.apply_time(DAY_PROGRESS)
		if _wet:
			CityTerrainBuilder.shared_material().set_shader_parameter("puddles", 1.0)
			CityTerrainBuilder.shared_material().set_shader_parameter("wetness", 0.6)
			CityBuildingBuilder.set_wetness(0.7)
		for i in 6:
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := "%s/%s%s.png" % [OUTPUT_DIR, shot["name"], "_wet" if _wet else ""]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured %s" % path)
	quit(0)
