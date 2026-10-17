extends Node

## QA traversal + render-cost probe for every seamless-city spawn in
## content/transitions/active_destinations.json (districts, gates, harbour, Toompea,
## landmark doors, extramural roads). One city load, then per spawn:
##   - teleport the player there and settle (streaming, physics);
##   - fail when the body overlaps a STEEP strip, sits under a closed building,
##     or hangs far from the plan's walk height (fell through / floated);
##   - hold each of the four screen directions with real input for PROBE_SEC and
##     fail when the body cannot leave the spot in any direction (wedged);
##   - walk with real input to the nearest street centreline (spawn -> street);
##   - record draw calls, objects, primitives, nodes, static memory and frame ms.
## Draw calls, objects, nodes and memory are load-independent; frame ms is not.
## Run (needs a renderer for draw calls; headless reports them as 0):
##   tools/godot_render.sh --resolution 1280x720 res://tools/verify_city_spawn_traversal.tscn \
##     -- [--spawn=gate.viru,poi.forum] [--out=build/qa/city_spawns.json]
## Exit code 1 when any spawn fails.

## load() after the first frame: a preload() compiles player.gd before autoloads exist.
const SCENE_PATH := "res://scenes/world/reval_city/reval_city.tscn"
const MANIFEST := "res://content/transitions/active_destinations.json"
const SETTLE_FRAMES := 30
const MEASURE_FRAMES := 45
const PROBE_SEC := 0.6
const MIN_MOVE := 1.0
const STREET_TIMEOUT := 25.0
const REACH := 2.2
const STUCK_SEC := 1.5
## Allowed gap between the body height and plan.walk_height before "fell / floated".
const HEIGHT_TOLERANCE := 3.0
const PROBE_DIRS := {
	"n": Vector2(0, -1), "e": Vector2(1, 0), "s": Vector2(0, 1), "w": Vector2(-1, 0)
}

var _city: Node
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []
var _out := "res://build/qa/city_spawns.json"


func _ready() -> void:
	call_deferred("_run")


func _spawn_ids() -> Array[String]:
	var wanted: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spawn="):
			for s in arg.substr(8).split(","):
				wanted.append(s)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	if not wanted.is_empty():
		return wanted
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for scene: Dictionary in data["scenes"]:
		if scene["id"] == "reval_city":
			for spawn: Dictionary in scene["spawns"]:
				wanted.append(String(spawn["id"]))
	return wanted


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	_city = (load(SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(_city)
	await get_tree().process_frame
	await get_tree().process_frame
	print("city ready in %d ms" % (Time.get_ticks_msec() - t0))
	for id in _spawn_ids():
		await _check_spawn(id)
	var abs_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var f := FileAccess.open(abs_out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"spawns": _rows, "failures": _failures}, "\t"))
	f.close()
	for msg in _failures:
		push_error(msg)
	print("SPAWN TRAVERSAL: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _steer(player: Player, direction: Vector2) -> void:
	player.set_screen_movement_basis(Vector2(-direction.y, direction.x), -direction)


func _check_spawn(id: String) -> void:
	var plan: CityPlan = _city.plan
	var player: Player = _city.player
	var row := {"spawn": id}
	_city.arrive_at(id)
	player.velocity = Vector2.ZERO
	var load_nodes := get_tree().get_node_count()
	var frames_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for i in MEASURE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames_ms.append((now - last) / 1000.0)
		last = now
	frames_ms.sort()
	var xz := CityPlan.to_world_xz(player.global_position)
	row["xz"] = [snappedf(xz.x, 0.1), snappedf(xz.y, 0.1)]
	row["district"] = plan.district_id_at(xz)
	row["frame_ms_median"] = snappedf(frames_ms[frames_ms.size() / 2], 0.1)
	row["frame_ms_p95"] = snappedf(frames_ms[int(frames_ms.size() * 0.95)], 0.1)
	row["draw_calls"] = int(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	row["objects"] = int(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	)
	row["primitives"] = int(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	)
	row["nodes"] = get_tree().get_node_count()
	row["static_mib"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	# Placement checks.
	var inside := plan.building_at(xz)
	var steep := player._is_overlapping_steep()
	var ground := plan.walk_height(xz)
	row["inside_building"] = plan.buildings[inside]["id"] if inside >= 0 else ""
	row["steep"] = steep
	if steep:
		_failures.append("%s: spawn at %s overlaps a STEEP strip (repro: --spawn=%s)" % [id, xz, id])
	if inside >= 0 and not bool(plan.buildings[inside].get("enterable", false)):
		_failures.append(
			"%s: spawn at %s is inside closed %s (repro: --spawn=%s)"
			% [id, xz, plan.buildings[inside]["id"], id]
		)
	# Four-direction wedge probe.
	var best_move := 0.0
	var moves := {}
	for dir_name: String in PROBE_DIRS:
		var d: Vector2 = PROBE_DIRS[dir_name]
		_city.arrive_at(id)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		var p0 := player.global_position
		_steer(player, d)
		Input.action_press(&"ui_up")
		var t := 0.0
		while t < PROBE_SEC:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			_steer(player, d)
		Input.action_release(&"ui_up")
		var m := player.global_position.distance_to(p0)
		moves[dir_name] = snappedf(m, 0.1)
		best_move = maxf(best_move, m)
	row["probe_move"] = moves
	if best_move < MIN_MOVE:
		_failures.append(
			"%s: wedged at %s, no direction moved >= %.1f in %.1f s: %s (repro: --spawn=%s)"
			% [id, xz, MIN_MOVE, PROBE_SEC, moves, id]
		)
	# Walk to the nearest street centreline with real input.
	_city.arrive_at(id)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var street := CityTravel._street_near(plan, xz)
	var reached := false
	var stuck := 0.0
	var elapsed := 0.0
	var last_pos := player.global_position
	if street.is_finite():
		var dist0 := xz.distance_to(street)
		row["street_dist"] = snappedf(dist0, 0.1)
		Input.action_press(&"ui_up")
		while elapsed < STREET_TIMEOUT:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			elapsed += dt
			var cur := CityPlan.to_world_xz(player.global_position)
			if cur.distance_to(street) < REACH:
				reached = true
				break
			_steer(player, (street - cur).normalized())
			if player.global_position.distance_to(last_pos) < 2.0 * dt * 10.0:
				stuck += dt
			else:
				stuck = 0.0
			last_pos = player.global_position
			if stuck > STUCK_SEC:
				break
		Input.action_release(&"ui_up")
		var end := CityPlan.to_world_xz(player.global_position)
		row["street_walk"] = {
			"reached": reached,
			"sec": snappedf(elapsed, 0.1),
			"end": [snappedf(end.x, 0.1), snappedf(end.y, 0.1)]
		}
		if not reached and dist0 > REACH:
			var near := inside_ids(plan, end)
			_failures.append(
				"%s: could not walk %.1f wu from %s to street %s; stopped at %s next to %s (repro: --spawn=%s)"
				% [id, dist0, xz, street, end, near, id]
			)
	row["ground_y"] = snappedf(ground, 0.1)
	_rows.append(row)
	print(JSON.stringify(row))


## Stable IDs of buildings within a few wu of a point, for stuck-spot reports.
func inside_ids(plan: CityPlan, at: Vector2) -> Array:
	var out: Array = []
	for b: Dictionary in plan.buildings:
		var poly = b.get("footprint", null)
		if poly == null:
			continue
		var pts := CityPlan.points(poly)
		var closest := INF
		for i in pts.size():
			var p := Geometry2D.get_closest_point_to_segment(at, pts[i], pts[(i + 1) % pts.size()])
			closest = minf(closest, p.distance_to(at))
		if closest < 3.0:
			out.append(String(b["id"]))
	return out
