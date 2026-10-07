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
const STUCK_SEC := 1.5
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
	if OS.get_cmdline_user_args().has("--only-sites"):
		# Targeted run: walk into the landmark sites only.
		await _enter_sites(plan)
		_finish()
		return
	await _walk("viru_inward", viru)
	await _walk("pikk_jalg_up", pikk_jalg)
	await _walk("luhike_jalg_up", luhike)
	await _walk("pikk_to_harbour", pikk)
	await _enter_house(plan)
	await _enter_sites(plan)
	await _features(plan)
	_finish()


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
	var frames0 := Engine.get_process_frames()
	var wall0 := Time.get_ticks_usec()
	Input.action_press(&"ui_up")
	while index < route.size() and elapsed < ROUTE_TIMEOUT:
		# Steer right before physics: the runtime re-applies the camera basis each frame.
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var xz := CityPlan.to_world_xz(player.global_position)
		var target := route[index]
		if xz.distance_to(target) < REACH:
			index += 1
			continue
		var d := (target - xz).normalized()
		_steer(player, d)
		if player.global_position.distance_to(last_pos) < 2.0:
			stuck += get_physics_process_delta_time()
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
	var frames := Engine.get_process_frames() - frames0
	var frame_ms := (Time.get_ticks_usec() - wall0) / 1000.0 / maxf(frames, 1)
	_frame_ms.append(frame_ms)
	print("%s: %.1f ms per rendered frame" % [label, frame_ms])
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
	_steer(player, -outward)
	Input.action_press(&"ui_up")
	var t := 0.0
	while t < 3.0 and _city.inside_building != best:
		await get_tree().physics_frame
		_steer(player, -outward)
		t += get_physics_process_delta_time()
	# A few more steps into the room.
	var deeper := 0.0
	while deeper < 0.12:
		await get_tree().physics_frame
		_steer(player, -outward)
		deeper += get_physics_process_delta_time()
	Input.action_release(&"ui_up")
	await _shot("walk_house_inside")
	# All three cameras work indoors: the ceiling lifts with the roof.
	var runtime: MapViewRuntime = _city.runtime
	for mode: MapViewRuntimeCamera.CameraMode in [
		MapViewRuntimeCamera.CameraMode.TOP_DOWN, MapViewRuntimeCamera.CameraMode.FIRST_PERSON
	]:
		runtime.set_camera_mode(mode)
		for i in 20:
			await get_tree().process_frame
		await _shot(
			"walk_house_inside_%s" % runtime.camera_mode_label().to_lower().replace(" ", "_")
		)
	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
	if not _city.world.doors.is_open(best):
		_failures.append("house %s: door did not swing open" % b["id"])
	else:
		print("door of %s swung open" % b["id"])
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
	_steer(player, outward)
	Input.action_press(&"ui_up")
	t = 0.0
	while t < 3.0 and _city.inside_building == best:
		await get_tree().physics_frame
		_steer(player, outward)
		t += get_physics_process_delta_time()
	Input.action_release(&"ui_up")
	# Keep walking away; the door shuts behind Kalev.
	var away := 0.0
	Input.action_press(&"ui_up")
	while away < 0.5:
		await get_tree().physics_frame
		_steer(player, outward)
		away += get_physics_process_delta_time()
	Input.action_release(&"ui_up")
	if _city.world.doors.is_open(best):
		_failures.append("house %s: door stayed open after Kalev left" % b["id"])
	else:
		print("door of %s shut behind Kalev" % b["id"])
	if _city.inside_building == best:
		_failures.append("house %s: could not walk out" % b["id"])
	elif roof != null and not roof.visible:
		_failures.append("house %s: roof stayed hidden outside" % b["id"])
	else:
		print("walked back out of %s" % b["id"])


## Screen "up" points along `direction` (world XZ), whatever the camera does.
func _steer(player: Player, direction: Vector2) -> void:
	player.set_screen_movement_basis(Vector2(-direction.y, direction.x), -direction)


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name]))


## Round-3 features: people, chimney smoke, ships, swimming, fast travel and
## the edge of the plan.
func _features(plan: CityPlan) -> void:
	var player: Player = _city.player
	var npcs := _city.find_child("CityNpcs", true, false)
	var people := npcs.get_child_count() if npcs != null else 0
	print("npcs: %d bodies" % people)
	if people < 20:
		_failures.append("npcs: only %d people in the city" % people)
	print("chimneys: %d stacks" % _city.world.chimneys.size())
	if _city.world.chimneys.size() < 200:
		_failures.append("chimneys: only %d" % _city.world.chimneys.size())
	# Fast travel inside the city: a district destination moves Kalev in place.
	DoorNavigator.go_to_scene(&"reval_north", &"anything")
	await get_tree().physics_frame
	var granary := plan.point_of_interest("poi.granary.pikk")
	var at := CityPlan.to_world_xz(player.global_position)
	if at.distance_to(Vector2(granary["at"][0], granary["at"][1])) > 3.0:
		_failures.append("fast travel: Kalev at %s, not at the Pikk granary" % at)
	else:
		print("fast travel to reval_north arrived at the Pikk granary in place")
	for i in 40:
		await get_tree().process_frame
	var plumes: int = _city.world.smoke.plume_count()
	print("chimney smoke plumes near Kalev: %d" % plumes)
	if plumes == 0:
		_failures.append("chimney smoke: no plume near the granary")
	await _shot("walk_chimneys_granary")
	# Birds fly over the town around Kalev (the shared flight layer).
	var birds := 0
	for i in 600:
		await get_tree().process_frame
		birds = _city.runtime._ambient_controller.bird_flight_active_count()
		if birds > 0:
			break
	print("birds in flight near Kalev: %d" % birds)
	var me := CityPlan.to_world_xz(player.global_position)
	var flight: Node = _city.runtime._ambient_controller.get("_bird_flight")
	for bird: Node3D in flight.call("flight_birds"):
		if bird.visible:
			var p := bird.global_position
			print(
				(
					"  bird %.0f m from Kalev, %.1f m above his ground"
					% [Vector2(p.x, p.z).distance_to(me), p.y - plan.ground_height(me)]
				)
			)
	if birds == 0:
		_failures.append("birds: none in flight after 600 frames")
	# Swim: off the fish landing, in water deeper than Kalev is tall.
	var landing := plan.point_of_interest("poi.fish_landing")
	var sea := Vector2(landing["at"][0], landing["at"][1])
	for k in 60:
		if plan.ground_height(sea) < -2.5:
			break
		sea += Vector2(0, -4)
	player.global_position = CityPlan.to_logic(sea)
	for i in 30:
		await get_tree().physics_frame
	print("in the sea: depth %.2f medium %d" % [player.water_depth(), player.water_medium()])
	if player.water_medium() != PlayerSwimState.Medium.SWIM:
		_failures.append(
			"swimming: medium %d at depth %.2f" % [player.water_medium(), player.water_depth()]
		)
	await _shot("walk_swim_harbour")
	# Magic: a Fireball cast on the forum flies as an orb in the 3D view.
	player.global_position = CityPlan.to_logic(CityTravel.spawn_position(plan, "poi.forum"))
	await get_tree().physics_frame
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid", "res://content/examples/support"])
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	MagicResolver.apply_grant_operation(state, db, &"magic.grant.starter_fireball")
	var cast := MagicResolver.cast(
		state, db, &"", [&"element.fire", &"element.air"] as Array[StringName]
	)
	var orb_seen := false
	if MagicCastExecutor2D.execute(cast, player, player.view_facing(), player.get_parent()) != null:
		for i in 12:
			await get_tree().process_frame
			if _city.runtime.find_child("MagicProjectileOrb", true, false) != null:
				orb_seen = true
				break
	if orb_seen:
		print("fireball: orb in flight over the forum")
		await _shot("walk_fireball_forum")
	else:
		_failures.append("fireball: no orb in the 3D view")
	# The edge of the plan opens the travel map instead of an invisible wall.
	var edge := plan.bounds.position + Vector2(10, plan.bounds.size.y * 0.5)
	player.global_position = CityPlan.to_logic(edge)
	for i in 4:
		await get_tree().process_frame
	var world_map := player.get_node_or_null("WorldMapController") as WorldMapController
	if world_map == null or not world_map.is_open():
		_failures.append("edge: travel map did not open")
	else:
		print("edge of the plan opened the travel map (%s)" % world_map.get_overlay().get_mode())
		await _shot("walk_edge_travel_map")
		world_map.close()


## Landmark sites (ADR 0032): walk in through every site door, check the door
## swings, the room's roof lifts and Kalev stands on the site floor, walk out.
func _enter_sites(plan: CityPlan) -> void:
	var player: Player = _city.player
	for site in plan.sites:
		for d: Dictionary in site.doors:
			if bool(d.get("inner", false)):
				continue  # room to room: walked from inside below
			var mid: Vector2 = (d["a"] + d["b"]) * 0.5
			var inward: Vector2 = d["inward"]
			var key := "site:%s" % d["id"]
			player.global_position = CityPlan.to_logic(mid - inward * 3.0)
			await get_tree().physics_frame
			Input.action_press(&"ui_up")
			var t := 0.0
			while t < 1.2:
				await get_tree().physics_frame
				# Steer at a point beyond the door, so drift cannot pull into a jamb.
				var here_in := CityPlan.to_world_xz(player.global_position)
				_steer(player, (mid + inward * 2.5 - here_in).normalized())
				t += get_physics_process_delta_time()
				var room := plan.site_room_at(CityPlan.to_world_xz(player.global_position))
				if (
					not room.is_empty()
					and CityPlan.to_world_xz(player.global_position).distance_to(mid) > 2.0
				):
					break
			Input.action_release(&"ui_up")
			for i in 10:
				await get_tree().process_frame
			var xz := CityPlan.to_world_xz(player.global_position)
			var room := plan.site_room_at(xz)
			if room.is_empty():
				_failures.append(
					"%s: could not walk in through %s (at %s)" % [site.id, d["id"], xz]
				)
				continue
			var roof_paths: Array = room["room"]["hide"]
			var site_node: Node3D = _city.world.site_nodes[site.id]
			var hidden := true
			for path: String in roof_paths:
				hidden = hidden and not (site_node.get_node(path) as Node3D).visible
			if not hidden:
				_failures.append("%s: roof did not lift in %s" % [site.id, room["room"]["id"]])
			if not _city.world.doors.is_open(key):
				_failures.append("%s: door %s did not open" % [site.id, d["id"]])
			print(
				(
					"site %s: walked in through %s; room %s; floor %.2f; roof lifted %s; door open %s"
					% [
						site.id,
						d["id"],
						room["room"]["id"],
						plan.walk_height(xz),
						hidden,
						_city.world.doors.is_open(key)
					]
				)
			)
			await _shot("walk_site_%s_inside" % String(site.id).trim_prefix("site."))
			# Every other door of the site must be reachable from inside: walk to
			# it and through, then back (e.g. the hall into the council chamber).
			for other: Dictionary in site.doors:
				# Only inner doors (room to room in a straight line); the room
				# graph of bigger buildings is checked by validate_city_sites.gd.
				if other == d or not bool(other.get("inner", false)):
					continue
				var omid: Vector2 = (other["a"] + other["b"]) * 0.5
				var oin: Vector2 = other["inward"]
				var goal := omid + oin * 1.5
				Input.action_press(&"ui_up")
				var tt := 0.0
				var approach := omid - oin * 1.2
				var through := false
				while (
					tt < 4.0
					and CityPlan.to_world_xz(player.global_position).distance_to(goal) > 0.6
				):
					await get_tree().physics_frame
					var here := CityPlan.to_world_xz(player.global_position)
					# Approach in front of the door first, then go straight through.
					through = (
						through or here.distance_to(approach) < 0.7 or (here - omid).dot(oin) > -0.3
					)
					_steer(player, ((goal if through else approach) - here).normalized())
					tt += get_physics_process_delta_time()
				Input.action_release(&"ui_up")
				var reached := CityPlan.to_world_xz(player.global_position).distance_to(goal) <= 0.6
				var oroom := plan.site_room_at(CityPlan.to_world_xz(player.global_position))
				print(
					(
						"site %s: through %s into %s: %s"
						% [
							site.id,
							other["id"],
							oroom["room"]["id"] if not oroom.is_empty() else "-",
							reached
						]
					)
				)
				if not reached:
					_failures.append(
						(
							"%s: could not walk through %s (stopped at local %s)"
							% [
								site.id,
								other["id"],
								site.to_local(CityPlan.to_world_xz(player.global_position))
							]
						)
					)
				await _shot(
					(
						"walk_site_%s_%s"
						% [
							String(site.id).trim_prefix("site."),
							String(other["id"]).get_slice(".", 2)
						]
					)
				)
				player.global_position = CityPlan.to_logic(mid + inward * 2.0)
				await get_tree().physics_frame
			var runtime: MapViewRuntime = _city.runtime
			runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
			for i in 20:
				await get_tree().process_frame
			await _shot("walk_site_%s_inside_top_down" % String(site.id).trim_prefix("site."))
			runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
			# Review views (manifest `review_views`): first person from a spot
			# inside, e.g. at the council table, to check people and furniture.
			for view: Dictionary in site.data.get("review_views", []):
				var spot := site.to_world(Vector2(view["at"][0], view["at"][1]))
				player.global_position = CityPlan.to_logic(spot)
				var look := Vector2.from_angle(
					deg_to_rad(float(view["facing_deg"])) + site.rotation
				)
				runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.FIRST_PERSON)
				for i in 30:
					_steer(player, look)
					await get_tree().process_frame
				await _shot(
					"walk_site_%s_view_%s" % [String(site.id).trim_prefix("site."), view["id"]]
				)
			runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
			player.global_position = CityPlan.to_logic(mid + inward * 2.0)
			await get_tree().physics_frame
			# Back out.
			Input.action_press(&"ui_up")
			t = 0.0
			while (
				t < 2.0
				and not plan.site_room_at(CityPlan.to_world_xz(player.global_position)).is_empty()
			):
				await get_tree().physics_frame
				_steer(player, -inward)
				t += get_physics_process_delta_time()
			Input.action_release(&"ui_up")
			if not plan.site_room_at(CityPlan.to_world_xz(player.global_position)).is_empty():
				_failures.append("%s: could not walk out through %s" % [site.id, d["id"]])


func _finish() -> void:
	_frame_ms.sort()
	if not _frame_ms.is_empty():
		print(
			(
				"route frame ms best=%.1f median=%.1f worst=%.1f"
				% [_frame_ms[0], _frame_ms[_frame_ms.size() / 2], _frame_ms[-1]]
			)
		)
	for f in _failures:
		push_error(f)
	print("WALK RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size()))
	get_tree().quit(0 if _failures.is_empty() else 1)
