extends SceneTree

## Review captures of the open country outside the Reval walls: rolling relief,
## hollow cart roads with wheel ruts, and footprints/wheel tracks in dry dust
## and in rain-wet clay. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_terrain_relief.gd [-- --only=<shot>,...]
## Output: docs/reports/images/city/terrain_<shot>.png

const OUTPUT_DIR := "res://docs/reports/images/city"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _road(plan: CityPlan, id: String) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for s: Dictionary in plan.streets:
		if s["id"] == id:
			for p: Array in s["points"]:
				pts.append(Vector2(p[0], p[1]))
	return pts


func _along(pts: Array[Vector2], dist: float) -> Dictionary:
	var left := dist
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			var dir := (pts[i + 1] - pts[i]).normalized()
			return {"at": pts[i] + dir * left, "dir": dir}
		left -= seg
	return {"at": pts[-1], "dir": (pts[-1] - pts[-2]).normalized()}


func _walk(world: CityWorld3D, pts: Array[Vector2], from: float, to: float, wheels: bool) -> void:
	var d := from
	var prev := Vector2.INF
	while d < to:
		var s := _along(pts, d)
		var at: Vector2 = s["at"]
		world.trail.update_for(at, 0.016)
		if wheels and prev != Vector2.INF:
			var side := Vector2(-s["dir"].y, s["dir"].x)
			for k: float in [-0.82, 0.82]:
				world.trail.stamp_track(prev + side * k, at + side * k, 0.11, 0.8)
		prev = at
		d += 0.25


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
	camera.far = 6000.0
	camera.near = 0.08
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(DAY_PROGRESS)
	var ground := CityTerrainBuilder.shared_material()
	var tartu := _road(plan, "road.tartu")
	var viru := _road(plan, "road.viru")
	var karja := _road(plan, "road.karja")
	for wet in [false, true]:
		var tag := "wet" if wet else "dry"
		ground.set_shader_parameter("wetness", 0.7 if wet else 0.0)
		ground.set_shader_parameter("puddles", 1.0 if wet else 0.0)
		world.trail.wetness = 0.7 if wet else 0.0
		var shots: Array[Dictionary] = []
		var a: Dictionary = _along(tartu, 140.0)
		var at: Vector2 = a["at"]
		var dir: Vector2 = a["dir"]
		shots.append(_shot("road_low", at, dir, 2.2, -6.0, 40.0, 60.0))
		shots.append(_shot("road_close", at + dir * 6.0, dir, 1.0, -2.5, 8.0, 62.0))
		var v: Dictionary = _along(viru, 120.0)
		shots.append(_shot("viru_road", v["at"], v["dir"], 3.0, -9.0, 60.0, 62.0))
		var k: Dictionary = _along(karja, 150.0)
		shots.append(_shot("country_karja", k["at"], k["dir"], 6.0, -14.0, 120.0, 65.0))
		shots.append(_shot("country_south", Vector2(-60.0, 560.0), Vector2(1.0, -0.35), 2.5, 0.0, 140.0, 65.0))
		shots.append(_shot("country_aerial", Vector2(-120.0, 600.0), Vector2(0.6, -1.0), 38.0, 0.0, 160.0, 60.0))
		shots.append(_shot("country_west", Vector2(-640.0, 380.0), Vector2(1.0, -0.2), 3.0, 0.0, 150.0, 65.0))
		for shot in shots:
			if not _only.is_empty() and not String(shot["name"]) in _only.split(","):
				continue
			var p: Vector2 = shot["pivot"]
			world.trail.update_for(p + Vector2(300.0, 300.0), 0.016)
			world.trail.update_for(p, 0.016)
			if String(shot["name"]).begins_with("road"):
				_walk(world, tartu, 120.0, 150.0, false)
				_walk(world, tartu, 120.0, 150.0, true)
			camera.fov = shot["fov"]
			camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
			for i in 8:
				await process_frame
			var path := "%s/terrain_%s_%s.png" % [OUTPUT_DIR, shot["name"], tag]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("captured %s" % path)
	quit(0)


func _shot(
	shot_name: String, at: Vector2, dir: Vector2, height: float, back: float, ahead: float, fov: float
) -> Dictionary:
	var plan := CityPlan.load_default()
	var eye := at + dir * back
	var look := at + dir * ahead
	return {
		"name": shot_name,
		"pivot": at,
		"eye": Vector3(eye.x, plan.ground_height(eye) + height, eye.y),
		"look": Vector3(look.x, plan.ground_height(look) + 0.5, look.y),
		"fov": fov,
	}
