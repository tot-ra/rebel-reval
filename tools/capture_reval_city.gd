extends SceneTree

## ADR 0031 review captures of the continuous Reval city. Renders an aerial
## overview and street-level shots along named streets. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_reval_city.gd [-- --only=<shot>]
## Output: docs/reports/images/city/<shot>.png

const OUTPUT_DIR := "res://docs/reports/images/city"
const VIEWPORT_SIZE := Vector2i(1600, 900)
## Cycle progress for captures (0.42 ~ late morning).
const DAY_PROGRESS := 0.42

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
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
	var top := Vector2(-420, 20)
	shots.append(
		{
			"name": "from_toompea_over_roofs",
			"eye": Vector3(-262, plan.ground_height(Vector2(-262, 60)) + 3.0, 60),
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
	world.apply_time(DAY_PROGRESS)
	print("city build stats: %s (total %d ms)" % [world.build_stats, Time.get_ticks_msec() - t0])
	for shot in _shots(plan):
		if not _only.is_empty() and shot["name"] != _only:
			continue
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		for i in 6:
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := "%s/%s.png" % [OUTPUT_DIR, shot["name"]]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captured %s" % path)
	quit(0)
