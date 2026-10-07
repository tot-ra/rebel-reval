extends Node

## ADR 0031 acceptance walk through the seamless Reval scene with real input.
## Each route teleports Kalev to its start, then holds "move up" with the
## camera turned toward the next waypoint (street polylines from the plan).
## Reports per-route progress, blocks (no progress for STUCK_SEC), the height
## climbed, frame times, and screenshots from the gameplay camera. Also walks
## into an enterable house through its door and checks the roof lifts.
## Host scene so autoloads (SessionState, DoorNavigator) resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn
## Output: docs/reports/images/city/walk_<route>.png, exit code 1 on failure.

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"
const STUCK_SEC := 2.5
const REACH := 2.2
const ROUTE_TIMEOUT := 120.0

var _city: Node
var _failures: Array[String] = []
var _frame_ms: Array[float] = []


func _ready() -> void:
	call_deferred("_run")


func _street(plan: CityPlan, name: String) -> PackedVector2Array:
	var parts: Array = []
	for s: Dictionary in plan.streets:
		if s["name"] == name:
			parts.append(CityPlan.points(s["points"]))
	if parts.is_empty():
		return PackedVector2Array()
	var chain: PackedVector2Array = parts.pop_front()
	while not parts.is_empty():
		var best := -1
		var best_d := INF
		var flip := false
		var at_end := true
		for i in parts.size():
			var p: PackedVector2Array = parts[i]
			for cand: Array in [
				[chain[-1].distance_to(p[0]), false, true],
				[chain[-1].distance_to(p[-1]), true, true],
				[chain[0].distance_to(p[-1]), false, false],
				[chain[0].distance_to(p[0]), true, false]
			]:
				if float(cand[0]) < best_d:
					best_d = cand[0]
					best = i
					flip = cand[1]
					at_end = cand[2]
		var q: PackedVector2Array = parts.pop_at(best)
		if flip:
			q.reverse()
		if at_end:
			chain.append_array(q.slice(1))
		else:
			var head := q.slice(0, q.size() - 1)
			head.append_array(chain)
			chain = head
	return chain


func _densify(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(points[-1])
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var load_start := Time.get_ticks_msec()
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	await get_tree().process_frame
	await get_tree().process_frame
	print("city scene ready in %d ms" % (Time.get_ticks_msec() - load_start))
	var plan: CityPlan = _city.plan
	var viru := _street(plan, "Viru")
	viru.reverse()  # from the gate inward
	if viru[0].distance_to(Vector2(268, 73) / 0.87) > viru[-1].distance_to(Vector2(268, 73) / 0.87):
		viru.reverse()
	var pikk_jalg := _street(plan, "Pikk jalg")
	if plan.ground_height(pikk_jalg[0]) > plan.ground_height(pikk_jalg[-1]):
		pikk_jalg.reverse()
	var luhike := _street(plan, "Lühike jalg")
	if plan.ground_height(luhike[0]) > plan.ground_height(luhike[-1]):
		luhike.reverse()
	var pikk := _street(plan, "Pikk")
	if pikk[0].y < pikk[-1].y:
		pikk.reverse()  # south to north, ending at the Coastal Gate
	var coastal := plan.gate("gate.coastal")
	pikk.append(Vector2(coastal["at"][0], coastal["at"][1]) + Vector2(4, -40) / 0.87)
	await _walk("viru_inward", viru)
	await _walk("pikk_jalg_up", pikk_jalg)
	await _walk("luhike_jalg_up", luhike)
	await _walk("pikk_to_harbour", pikk)
	await _enter_house(plan)
	_frame_ms.sort()
	if not _frame_ms.is_empty():
		print(
			(
				"frame ms p50=%.1f p95=%.1f max=%.1f"
				% [
					_frame_ms[_frame_ms.size() / 2],
					_frame_ms[int(_frame_ms.size() * 0.95)],
					_frame_ms[-1]
				]
			)
		)
	for f in _failures:
		push_error(f)
	print("WALK RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _walk(label: String, route: PackedVector2Array) -> void:
	var plan: CityPlan = _city.plan
	var player: Player = _city.player
	route = _densify(route, 6.0)
	player.global_position = CityPlan.to_logic(route[0])
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start_h := plan.walk_height(route[0])
	var index := 1
	var elapsed := 0.0
	var stuck := 0.0
	var last_pos := player.global_position
	var shot_taken := false
	Input.action_press(&"ui_up")
	while index < route.size() and elapsed < ROUTE_TIMEOUT:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		_frame_ms.append(dt)
		elapsed += get_process_delta_time() if get_process_delta_time() > 0.0 else 1.0 / 60.0
		var xz := CityPlan.to_world_xz(player.global_position)
		var target := route[index]
		if xz.distance_to(target) < REACH:
			index += 1
			continue
		var d := target - xz
		_city.yaw = atan2(-d.x, -d.y)
		if player.global_position.distance_to(last_pos) < 2.0:
			stuck += get_process_delta_time()
		else:
			stuck = 0.0
		last_pos = player.global_position
		if stuck > STUCK_SEC:
			# Skip a waypoint once (corner cut into a house), then give up.
			_failures.append(
				"%s: blocked at %s (waypoint %d/%d)" % [label, xz, index, route.size()]
			)
			break
		if not shot_taken and index > route.size() / 2:
			shot_taken = true
			await _shot("walk_%s" % label)
	Input.action_release(&"ui_up")
	var xz_end := CityPlan.to_world_xz(player.global_position)
	var climbed := plan.walk_height(xz_end) - start_h
	print(
		(
			"%s: reached %d/%d waypoints in %.1f s, climbed %.1f wu (%.1f m)"
			% [label, index, route.size(), elapsed, climbed, climbed * plan.metres_per_unit]
		)
	)
	if index < route.size() - 1:
		_failures.append("%s: did not finish (%d/%d)" % [label, index, route.size()])
	await _shot("walk_%s_end" % label)


func _enter_house(plan: CityPlan) -> void:
	var player: Player = _city.player
	# Nearest enterable house to the forum with a door.
	var forum := Vector2(5, -10) / plan.metres_per_unit
	var best := -1
	var best_d := INF
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if not bool(b.get("enterable", false)) or b.get("door") == null:
			continue
		var door := Vector2(b["door"][0], b["door"][1])
		var d := door.distance_to(forum)
		if d < best_d:
			best_d = d
			best = i
	var b: Dictionary = plan.buildings[best]
	var door := Vector2(b["door"][0], b["door"][1])
	var outward := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
	var start := door + outward * 3.0
	player.global_position = CityPlan.to_logic(start)
	await get_tree().physics_frame
	_city.yaw = atan2(outward.x, outward.y)  # camera behind Kalev, facing the door
	Input.action_press(&"ui_up")
	var t := 0.0
	while t < 3.0 and _city.inside_building != best:
		await get_tree().process_frame
		t += get_process_delta_time()
	# A few more steps into the room.
	var deeper := 0.0
	while deeper < 0.5:
		await get_tree().process_frame
		deeper += get_process_delta_time()
	Input.action_release(&"ui_up")
	await _shot("walk_house_inside")
	var roof: MeshInstance3D = _city.world.roof_nodes.get(best)
	if _city.inside_building != best:
		_failures.append("house %s: could not walk in through the door" % b["id"])
	elif roof == null or roof.visible:
		_failures.append("house %s: roof did not lift inside" % b["id"])
	else:
		print(
			(
				"entered %s through its door; roof lifted; floor %.2f wu"
				% [b["id"], plan.floor_height(best)]
			)
		)
	# And back out.
	_city.yaw = atan2(-outward.x, -outward.y)
	Input.action_press(&"ui_up")
	t = 0.0
	while t < 3.0 and _city.inside_building == best:
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release(&"ui_up")
	if _city.inside_building == best:
		_failures.append("house %s: could not walk out" % b["id"])
	elif roof != null and not roof.visible:
		_failures.append("house %s: roof stayed hidden outside" % b["id"])
	else:
		print("walked back out of %s" % b["id"])


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name]))
