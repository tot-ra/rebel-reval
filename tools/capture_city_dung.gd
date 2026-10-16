extends Node

## Plates for animal dung (R-2077, docs/SYSTEMS/ANIMAL_DUNG.md) in the running
## seamless city: Kalev stands at the densest stretch of cow pats on a drove
## road, a manure heap, horse dung and sheep pellets; each stop is shot through
## the game camera and close up. A last stop (R-2175) shows a cow with a fresh
## live pat behind it and a pat Kalev trod flat. Exits 1 when a stop fails.
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_dung.tscn [-- --date=7-15]
## Output: build/season/dung_<month>_<day>_<stop>[_near].png (stops road, heap,
## horse, pellets, live)

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://build/season"
const SETTLE_SEC := 4.0
const CLUSTER_RADIUS := 10.0

var _date := {"year": 1343, "month": 7, "day": 15}
var _failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--date="):
			var md := arg.substr(7).split("-")
			_date = {"year": 1343, "month": int(md[0]), "day": int(md[1])}
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var city: Node = SCENE.instantiate()
	get_tree().root.add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	city.view.set_calendar_date(_date)
	var dung: CityDung = city.world.get_node("CityDung")
	var tag := "%d_%d" % [_date["month"], _date["day"]]
	for stop: Array in [
		["road", CityDung.KIND_COW_PAT], ["heap", CityDung.KIND_HEAP],
		["horse", CityDung.KIND_HORSE], ["pellets", CityDung.KIND_PELLETS],
	]:
		var at := _densest(dung, stop[1], city.plan if stop[0] == "road" else null)
		if at == Vector3.INF:
			_failures.append(stop[0])
			continue
		var xz := Vector2(at.x, at.z)
		city.player.global_position = CityPlan.to_logic(xz + Vector2(0.0, 2.5))
		city.player.velocity = Vector2.ZERO
		await _settle(SETTLE_SEC)
		_save("%s/dung_%s_%s.png" % [OUTPUT_DIR, tag, stop[0]])
		# Close up from a hand-held camera, then back to the game camera.
		var game_camera := get_viewport().get_camera_3d()
		var near := Camera3D.new()
		near.fov = 50.0
		near.near = 0.03
		city.world.add_child(near)
		var reach := 1.4 if stop[1] == CityDung.KIND_PELLETS else 2.6
		near.look_at_from_position(at + Vector3(0.5, reach * 0.75, reach), at, Vector3.UP)
		near.make_current()
		await _settle(0.5)
		_save("%s/dung_%s_%s_near.png" % [OUTPUT_DIR, tag, stop[0]])
		near.queue_free()
		if game_camera != null:
			game_camera.make_current()
	await _live_plate(city, tag)
	get_tree().quit(1 if not _failures.is_empty() else 0)


## R-2175: a cow in a pasture with a fresh pat just behind it, and beside it a
## pat Kalev walks over: squashed flat with a smear and muddy prints after it.
## The fresh pat goes through CityDungLive.drop (what the feed calls after ~60 m
## of walking, minutes of grazing); the squash comes from Kalev's real footfalls.
func _live_plate(city: Node, tag: String) -> void:
	var live: CityDungLive = city.world.get_node("CityDungLive")
	var fauna: CityFauna = city.world.get_node("CityFauna")
	# Penned and tethered cows first (their yard is trodden bare, so the pats are
	# not lost in July pasture grass), then herds; the first cow with dry ground
	# behind it and beside that (CityFauna._is_dry) is used.
	var groups: Array[Dictionary] = []
	for group: Dictionary in CityFauna.groups_for(city.plan):
		if group["species"] == &"cow":
			groups.append(group)
	groups.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return x["behavior"] != CityFauna.BEHAVIOR_GRAZE and y["behavior"] == CityFauna.BEHAVIOR_GRAZE
	)
	var cow: Node3D = null
	var back := Vector2.ZERO
	var fresh := Vector2.ZERO
	var side := Vector2.ZERO
	var trodden := Vector2.ZERO
	for group in groups.slice(0, 6):
		var centre: Vector2 = group["centre"]
		city.player.global_position = CityPlan.to_logic(centre + Vector2(0.0, 6.0))
		await _settle(SETTLE_SEC)
		for animal in fauna.live_animals():
			if animal.get_meta(&"species", &"") != &"cow" or _xz(animal).distance_to(centre) > 30.0:
				continue
			# GroundWander faces an animal along -Z (look_at), so +Z is behind it.
			back = Vector2(animal.global_basis.z.x, animal.global_basis.z.z).normalized()
			fresh = _xz(animal) + back * float(CityDungLive.LIVE_BEHIND[CityDung.KIND_COW_PAT])
			side = Vector2(-back.y, back.x)
			trodden = fresh + side * 1.6
			if CityFauna._is_dry(city.plan, fresh) and CityFauna._is_dry(city.plan, trodden):
				cow = animal
				break
		if cow != null:
			print("dung plate: live cow of %s (%s)" % [group["id"], group["behavior"]])
			break
	if cow == null:
		_failures.append("live")
		return
	# Pin the cow over its pat: CityFauna walks its actors from its own process,
	# so the pose is put back after every process step, just before drawing.
	var pinned := cow.global_transform
	var pin := func() -> void:
		if is_instance_valid(cow):
			cow.global_transform = pinned
	RenderingServer.frame_pre_draw.connect(pin)
	var laid := live.drop(&"cow", fresh, 0.7) and live.drop(&"cow", trodden, 2.1)
	# Kalev walks across the second pat until a foot lands on it: each pass is
	# nudged sideways and starts a little further back, shifting the stride phase.
	var squashed := false
	for attempt in 12:
		# Parallel to the cow, 1.6 m to its side, so the fresh pat stays untrodden.
		var lane := trodden + side * (0.08 * float(attempt % 5 - 2))
		var from := lane - back * (3.0 + 0.23 * float(attempt))
		for k in 90:
			city.player.global_position = CityPlan.to_logic(from.lerp(lane + back * 2.5, k / 89.0))
			city.player.velocity = Vector2.ZERO
			await get_tree().process_frame
		squashed = not live.live_drops().is_empty() and bool(live.live_drops()[-1]["squashed"])
		if squashed:
			break
	print("dung plate: live drop laid %s, squashed %s, smears %d" % [
		laid, squashed, live.smears().size()
	])
	if not laid or not squashed:
		_failures.append("live")
		RenderingServer.frame_pre_draw.disconnect(pin)
		return
	await _settle(1.0)
	_save("%s/dung_%s_live.png" % [OUTPUT_DIR, tag])
	var game_camera := get_viewport().get_camera_3d()
	var near := Camera3D.new()
	near.fov = 50.0
	near.near = 0.03
	city.world.add_child(near)
	# From the trodden side, looking past the squashed pat at the cow's rear and
	# its fresh pat.
	var mid := fresh.lerp(trodden, 0.35) - back * 0.3
	var focus := Vector3(mid.x, city.plan.ground_height(mid), mid.y)
	var eye := trodden + side * 2.4 + back * 1.4
	near.look_at_from_position(Vector3(eye.x, focus.y + 1.9, eye.y), focus, Vector3.UP)
	near.make_current()
	# July grass in a pen stands knee-high and hides every pat: the close-up
	# mows it (this plate only) so the drops themselves can be judged.
	var grass: Node3D = city.world.grass
	grass.visible = false
	await _settle(0.5)
	_save("%s/dung_%s_live_near.png" % [OUTPUT_DIR, tag])
	grass.visible = true
	RenderingServer.frame_pre_draw.disconnect(pin)
	near.queue_free()
	if game_camera != null:
		game_camera.make_current()


func _xz(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)


## Centre of the shown instance of `kind` with the most neighbours of its kind.
## With `on_streets`, only instances on a drove street count (the road plate).
func _densest(dung: CityDung, kind: StringName, on_streets: CityPlan = null) -> Vector3:
	var spots: Array[Vector3] = []
	for entry: Array in dung.placements():
		var o := (entry[1] as Transform3D).origin
		if entry[0] == kind and (on_streets == null or _on_street(on_streets, Vector2(o.x, o.z))):
			spots.append(o)
	var best := Vector3.INF
	var best_n := -1
	for p in spots:
		var n := 0
		for q in spots:
			if Vector2(p.x, p.z).distance_squared_to(Vector2(q.x, q.z)) < CLUSTER_RADIUS ** 2:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	print("dung plate: densest %s at %s (%d within %.0f m)" % [kind, best, best_n, CLUSTER_RADIUS])
	return best


func _on_street(plan: CityPlan, xz: Vector2) -> bool:
	for s: Dictionary in plan.streets:
		if CityDung.DROVE_CLASSES.has(String(s.get("class", ""))):
			var hit := CityDung._closest_on(CityPlan.points(s["points"]), xz)
			if float(hit[2]) < float(s.get("width", 4.0)) * 0.5:
				return true
	return false


func _settle(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	get_tree().root.get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(path)
	)
	print("dung plate: ", path)
