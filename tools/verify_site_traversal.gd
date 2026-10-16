extends Node

## Deterministic traversal check for the regional sites (ADR 0042,
## docs/SYSTEMS/REGIONAL_SITES.md): for every arrival spawn the player is placed
## through the scene's own arrive_at(), must not start inside collision or the
## STEEP layer, and must walk every plan road end to end with real movement input.
## Blocks are logged with site id, world xz, the road id, waypoint index and the
## last slide collider, so each one is a repro. Exit code 1 on any failure.
## Host scene so autoloads resolve:
##   tools/godot_render.sh --headless-ok res://tools/verify_site_traversal.tscn \
##     [-- --site=paide[,padise] --max-roads=6 --out=build/qa/site_traversal.json]
## Plain `godot --headless --path . res://tools/verify_site_traversal.tscn -- ...` works too.

const SITES := ["sacred_grove", "padise", "paide", "saaremaa", "harju", "rebel_kings"]
const STUCK_SEC := 2.0
const REACH := 2.5
const STEP := 6.0
const SPEED_GUESS := 3.0
const SKIP_LINES_BELOW := 12.0

var _sites: Array = SITES
var _max_roads := 99
var _out := ""
## --travel: load every world_travel/*.tscn destination instead and check the arrival spawn.
var _travel := false
## --leak=N: load and free the first --site N times, report static memory after each round.
var _leak_rounds := 0
var _failures: Array[String] = []
var _results: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--site="):
			_sites = arg.substr(7).split(",")
		elif arg.begins_with("--max-roads="):
			_max_roads = int(arg.substr(12))
		elif arg.begins_with("--leak="):
			_leak_rounds = int(arg.substr(7))
		elif arg == "--travel":
			_travel = true
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	if _leak_rounds > 0:
		await _check_reload_leak()
	elif _travel:
		await _check_travel_maps()
	else:
		for site_id in _sites:
			await _check_site(String(site_id))
	for failure in _failures:
		push_error("TRAVERSAL FAIL: " + failure)
	print(
		"TRAVERSAL RESULT: %s (%d failures)" % ["FAIL" if _failures else "PASS", _failures.size()]
	)
	if _out != "":
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"results": _results, "failures": _failures}, "  "))
	get_tree().quit(1 if _failures else 0)


func _check_site(site_id: String) -> void:
	var started := Time.get_ticks_msec()
	var scene: Node = load("res://scenes/world/sites/%s.tscn" % site_id).instantiate()
	add_child(scene)
	for i in 20:
		await get_tree().process_frame
	var plan: CityPlan = scene.get("plan")
	var player: Player = scene.get("player")
	var record := {
		"site": site_id, "load_ms": Time.get_ticks_msec() - started, "spawns": [], "roads": []
	}
	_results.append(record)
	print("== %s loaded in %d ms" % [site_id, record["load_ms"]])
	for spawn: Dictionary in plan.data.get("spawns", []):
		await _check_spawn(scene, plan, player, site_id, String(spawn["id"]), record)
	var roads := 0
	for street in plan.streets:
		if roads >= _max_roads:
			break
		var line := CityPlan.points(street["points"])
		if line.size() < 2 or _length(line) < SKIP_LINES_BELOW:
			continue
		roads += 1
		await _walk_road(plan, player, site_id, String(street["id"]), line, record)
	scene.queue_free()
	await get_tree().process_frame


func _check_spawn(
	scene: Node, plan: CityPlan, player: Player, site_id: String, id: String, record: Dictionary
) -> void:
	scene.call("arrive_at", id)
	for i in 6:
		await get_tree().physics_frame
	var xz := CityPlan.to_world_xz(player.global_position)
	var stuck_in_solid := player.test_move(player.global_transform, Vector2.ZERO)
	var steep := bool(player.call("_is_overlapping_steep"))
	var ok := not stuck_in_solid and not steep and plan.bounds.has_point(xz)
	record["spawns"].append(
		{"id": id, "xz": [xz.x, xz.y], "ok": ok, "in_solid": stuck_in_solid, "steep": steep}
	)
	print(
		(
			"spawn %s/%s at %s: %s"
			% [site_id, id, xz, "ok" if ok else "BAD (solid=%s steep=%s)" % [stuck_in_solid, steep]]
		)
	)
	if not ok:
		_failures.append(
			(
				"%s spawn %s at world xz %s: inside collision=%s steep=%s (repro: --site=%s)"
				% [site_id, id, xz, stuck_in_solid, steep, site_id]
			)
		)


func _walk_road(
	plan: CityPlan,
	player: Player,
	site_id: String,
	road_id: String,
	line: PackedVector2Array,
	record: Dictionary
) -> void:
	var route := _densify(line, STEP)
	# Start 1 m onto the road, inside the plan bounds (edge band opens the travel map).
	var margin_rect := plan.bounds.grow(-34.0)
	player.global_position = CityPlan.to_logic(
		route[0].clamp(margin_rect.position, margin_rect.end)
	)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var index := 1
	var elapsed := 0.0
	var stuck := 0.0
	var last := player.global_position
	var limit := _length(line) / SPEED_GUESS * 3.0 + 10.0
	Input.action_press(&"ui_up")
	var blocked := ""
	while index < route.size() and elapsed < limit:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		var xz := CityPlan.to_world_xz(player.global_position)
		if not margin_rect.has_point(route[index]):
			index += 1  # waypoint inside the edge band: opening the map is not a defect
			continue
		if xz.distance_to(route[index]) < REACH:
			index += 1
			continue
		var d := (route[index] - xz).normalized()
		player.set_screen_movement_basis(Vector2(-d.y, d.x), -d)
		stuck = stuck + dt if player.global_position.distance_to(last) < 0.5 else 0.0
		last = player.global_position
		if stuck > STUCK_SEC:
			var col := player.get_last_slide_collision()
			var who := ""
			if col and col.get_collider():
				var node := col.get_collider() as Node
				who = "%s (%s)" % [node.name, node.get_parent().name if node.get_parent() else ""]
			blocked = (
				"at world xz %s, waypoint %d/%d, last collider %s" % [xz, index, route.size(), who]
			)
			break
	Input.action_release(&"ui_up")
	var done := blocked == "" and index >= route.size() - 1
	record["roads"].append(
		{
			"id": road_id,
			"length": _length(line),
			"reached": index,
			"of": route.size(),
			"ok": done,
			"sim_s": snappedf(elapsed, 0.1),
			"blocked": blocked
		}
	)
	print(
		(
			"road %s/%s: %d/%d in %.1f s %s"
			% [site_id, road_id, index, route.size(), elapsed, "ok" if done else "FAIL " + blocked]
		)
	)
	if not done:
		_failures.append(
			(
				"%s road %s did not complete (%d/%d, %.1f sim s) %s (repro: --site=%s)"
				% [site_id, road_id, index, route.size(), elapsed, blocked, site_id]
			)
		)


func _length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


func _densify(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var n := maxi(1, int(points[i].distance_to(points[i + 1]) / step))
		for k in n:
			out.append(points[i].lerp(points[i + 1], float(k) / n))
	out.append(points[-1])
	return out


## Global-map destinations (scenes/world_travel): load, arrive, report nodes and whether
## the player starts free of collision and can take a few steps in any direction.
func _check_travel_maps() -> void:
	var dir := DirAccess.open("res://scenes/world_travel")
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			names.append(f)
	names.sort()
	for f in names:
		var started := Time.get_ticks_msec()
		var scene: Node = load("res://scenes/world_travel/" + f).instantiate()
		add_child(scene)
		for i in 20:
			await get_tree().process_frame
		var player: Node2D = scene.get("player")
		var ok := player != null
		var solid := false
		var free_dirs := 0
		if ok:
			solid = (player as CharacterBody2D).test_move(player.global_transform, Vector2.ZERO)
			for dir_vec in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				if not (player as CharacterBody2D).test_move(
					player.global_transform, dir_vec * 24.0
				):
					free_dirs += 1
		var load_ms := Time.get_ticks_msec() - started
		var good := ok and not solid and free_dirs > 0
		_results.append(
			{
				"travel_map": f,
				"load_ms": load_ms,
				"ok": good,
				"in_solid": solid,
				"free_dirs": free_dirs,
				"nodes": _count(scene)
			}
		)
		print(
			(
				"travel %s: %d ms, nodes %d, solid=%s free_dirs=%d %s"
				% [f, load_ms, _count(scene), solid, free_dirs, "ok" if good else "BAD"]
			)
		)
		if not good:
			_failures.append(
				(
					"travel map %s: player=%s in_solid=%s free_dirs=%d (repro: --travel)"
					% [f, ok, solid, free_dirs]
				)
			)
		scene.queue_free()
		await get_tree().process_frame


func _count(node: Node) -> int:
	var n := 1
	for c in node.get_children():
		n += _count(c)
	return n


## Repeated transition: the same site is entered and left N times; static memory that keeps
## growing round over round points at a leak (scene, texture or mesh cache never released).
func _check_reload_leak() -> void:
	var site_id := String(_sites[0])
	var samples: Array = []
	for round_index in _leak_rounds:
		var scene: Node = load("res://scenes/world/sites/%s.tscn" % site_id).instantiate()
		add_child(scene)
		for i in 30:
			await get_tree().process_frame
		scene.queue_free()
		for i in 30:
			await get_tree().process_frame
		var mib := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		samples.append({"round": round_index + 1, "static_mib": snappedf(mib, 0.1), "nodes": nodes})
		print(
			(
				"leak %s round %d: static %.1f MiB, live nodes %d"
				% [site_id, round_index + 1, mib, nodes]
			)
		)
	_results.append({"leak_site": site_id, "samples": samples})
	var growth: float = (
		samples[-1]["static_mib"] - samples[1]["static_mib"] if samples.size() > 2 else 0.0
	)
	if growth > 50.0:
		(
			_failures
			. append(
				(
					"%s: static memory grew %.1f MiB between round 2 and %d (repro: --leak=%d --site=%s)"
					% [site_id, growth, samples.size(), _leak_rounds, site_id]
				)
			)
		)
