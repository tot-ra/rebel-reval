extends Node

## The context-aware jump (ADR 0053) in the real seamless city. Finds a waist-high churchyard wall
## (a collision wall tagged with its top), a quay or bank over deep water, and a high drop onto
## dry ground; puts Kalev in front of each, presses jump, and saves frames of what the leap network
## chose (crouch, hands on the wall, flight, landing; the jump into the water; the balk at the
## drop). Prints each decision.
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_leap.tscn
##   (add `-- --vault`, `-- --quay` or `-- --drop` for one scene)
## PNGs are large; the docs keep 1280 px JPEGs (`sips -s format jpeg --resampleWidth 1280`).
## Output: docs/reports/images/leaping/*.png, exit code 1 when a scene is not found or the
## decision is not the expected kind.

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const LeapProbe := preload("res://scripts/motion/motion_leap_probe.gd")
const PlayerLeap := preload("res://scripts/player/player_leap.gd")
const OUTPUT_DIR := "res://docs/reports/images/leaping"
const PX := 32.0

var _city: Node
var _player: Player
var _failed := false
var _logged := {}


func _ready() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 2:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name]))
	print("shot %s" % name)


func _ground(xz: Vector2) -> Vector2:
	return Vector2(_city.view.plan.walk_height(xz), _city.view.world.water_surface_at(xz))


func _decide(logic: Vector2, dir: Vector2) -> Dictionary:
	var leap: RefCounted = PlayerLeap.new()
	return leap.plan(_player.get_world_2d().direct_space_state, _ground, logic, dir, 0.0, {})


## Wall quads tagged with a top: [centre (logic px), outward normal, top height above the street].
func _walls() -> Array:
	var out: Array = []
	for body in _city.get_node("CityCollision").get_children():
		for shape in body.get_children():
			if not shape is CollisionPolygon2D or not shape.has_meta(LeapProbe.TOP_META):
				continue
			var poly := (shape as CollisionPolygon2D).polygon
			if poly.size() != 4:
				continue
			var c := (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
			var along := poly[1] - poly[0]
			if along.length() < 3.0 * PX:
				continue
			var n := Vector2(-along.y, along.x).normalized()
			out.append([c, n, float(shape.get_meta(LeapProbe.TOP_META))])
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	for i in 6:
		await get_tree().process_frame
	_player = _city.player
	var only := OS.get_cmdline_user_args()
	if only.is_empty() or "--vault" in only:
		await _wall_vault()
	if only.is_empty() or "--quay" in only:
		await _quay_jump()
	if only.is_empty() or "--drop" in only:
		await _drop_refusal()
	print("RESULT %s" % ("FAIL" if _failed else "OK"))
	get_tree().quit(1 if _failed else 0)


## Puts Kalev at `logic` facing `dir`, presses jump, and shoots the phases.
func _play(name: String, logic: Vector2, dir: Vector2, override: Dictionary = {}) -> Dictionary:
	_player.global_position = logic
	_player.velocity = Vector2.ZERO
	_player.stamina = _player.max_stamina
	_player._facing_direction = dir
	_player.set_camera_facing(Vector2.ZERO)
	for i in 30:
		await get_tree().physics_frame
	await _shot("%s_0_before" % name)
	_player._facing_direction = dir
	# Steep ground pulls a standing body downhill: put it back on the edge for the press.
	_player.global_position = logic
	_player.leap_channels.merge(override, true)
	print("  air %.1f C" % float(_player.leap_channels.get("air_temp", 15.0)))
	_player._try_leap()
	var d: Dictionary = _player.last_leap_decision()
	print("%s: %s %s" % [name, d.get("label", "?"), d.get("knobs", {})])
	if d.has("probe"):
		print(
			(
				"  z %s\n  w %s\n  standable %s"
				% [d["probe"]["z"], d["probe"]["w"], d["probe"]["standable"]]
			)
		)
		print(
			(
				"  start %s takeoff %s landing %s"
				% [logic / PX, _player._leap.takeoff / PX, _player._leap.landing / PX]
			)
		)
	var taken := {}
	for i in 360:
		await get_tree().physics_frame
		if not _player.is_leaping():
			break
		var pose: Dictionary = _player.leap_pose()
		var phase := int(pose.get("phase", 0))
		var t := float(pose.get("t", 0.0))
		var key := ""
		if phase == PlayerLeap.Phase.CROUCH and not taken.has("1"):
			key = "1"
		elif phase == PlayerLeap.Phase.LOWER and t > 0.6 and not taken.has("1"):
			key = "1"
		elif phase == PlayerLeap.Phase.FLIGHT and t > 0.3 and not taken.has("2"):
			key = "2"
		elif phase == PlayerLeap.Phase.FLIGHT and t > 0.7 and not taken.has("3"):
			key = "3"
		elif phase == PlayerLeap.Phase.LAND and t > 0.2 and not taken.has("4"):
			key = "4"
		elif phase == PlayerLeap.Phase.REFUSE and t > 0.45 and not taken.has("2"):
			key = "2"
		if key != "":
			taken[key] = true
			await _shot("%s_%s" % [name, key])
	print("  ended at %s" % [_player.global_position / PX])
	for i in 40:
		await get_tree().physics_frame
	print("  after settling %s" % [_player.global_position / PX])
	await _shot("%s_5_after" % name)
	return d


func _wall_vault() -> void:
	for w: Array in _walls():
		var c: Vector2 = w[0]
		for side: float in [1.0, -1.0]:
			var n: Vector2 = (w[1] as Vector2) * side
			var start: Vector2 = c + n * 0.75 * PX
			var xz := start / PX
			var rise: float = float(w[2]) - float(_city.view.plan.walk_height(xz))
			if rise < 0.6 or rise > 1.1 or _city.view.water_depth_at(xz) > 0.05:
				continue
			if not is_nan(
				LeapProbe.barrier_top(_player.get_world_2d().direct_space_state, start, 0.0)
			):
				continue
			var d := _decide(start, -n)
			if d.get("action", "") == "jump":
				print("wall top %.2f m above the street at %s" % [rise, xz])
				await _play("vault", start, -n)
				return
	print("FAIL no waist-high wall to vault")
	_failed = true


## Walks from `p` (world xz) along `dir` to the edge: the last dry, free point before the ground
## falls away by more than half a metre (or water starts). Returns Vector2.INF if a wall is in
## the way or no edge comes within 4 m.
func _edge(p: Vector2, dir: Vector2) -> Vector2:
	var plan: CityPlan = _city.view.plan
	var space := _player.get_world_2d().direct_space_state
	var h0 := plan.walk_height(p)
	var at := p
	for i in 40:
		var nxt := at + dir * 0.1
		if not is_nan(LeapProbe.barrier_top(space, nxt * PX, 0.0)):
			return Vector2.INF
		if h0 - plan.walk_height(nxt + dir * 0.2) > 0.5 or _city.view.water_depth_at(nxt) > 0.05:
			return at
		if absf(plan.walk_height(nxt) - h0) > 0.3:
			return Vector2.INF
		at = nxt
	return Vector2.INF


## Scans the city for an edge where the leap network (with Kalev's real situation channels) gives
## `want`, and where the profile ahead `accept`s; plays it.
func _find_edge(
	name: String, want: String, accept: Callable, override: Dictionary = {}
) -> Dictionary:
	var plan: CityPlan = _city.view.plan
	var rect: Rect2 = plan.bounds
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			var p := Vector2(x, y)
			if _city.view.water_depth_at(p) == 0.0:
				for k in 8:
					var dir := Vector2.from_angle(k * TAU / 8.0)
					var q := p + dir * 2.5
					if plan.walk_height(p) - plan.walk_height(q) < 1.0:
						continue
					var e := _edge(p, dir)
					if e == Vector2.INF:
						continue
					var ch: Dictionary = _player.leap_channels.duplicate()
					ch.merge(override, true)
					var leap: RefCounted = PlayerLeap.new()
					var d: Dictionary = leap.plan(
						_player.get_world_2d().direct_space_state, _ground, e * PX, dir, 0.0, ch
					)
					if accept.call(d["probe"]) and not _logged.has(name):
						_logged[name] = true
						print("%s candidate %s: %s" % [name, e, d.get("label", "")])
					if String(d.get("label", "")) == want and accept.call(d["probe"]):
						print("%s edge at %s facing %s" % [name, e, dir])
						var out: Dictionary = await _play(name, e * PX, dir, override)
						if name == "quay_summer":
							# The same edge on the city's own date (early spring sea): refused.
							await _play("quay_cold", e * PX, dir)
						return out
			y += 3.0
		x += 3.0
	print("FAIL no %s found" % name)
	_failed = true
	return {}


func _quay_jump() -> void:
	await _find_edge(
		"quay_summer",
		"jump into water",
		func(probe: Dictionary) -> bool:
			var z: PackedFloat32Array = probe["z"]
			var w: PackedFloat32Array = probe["w"]
			return z[4] < -1.0 and w[8] > 1.5,
		{"air_temp": 20.0, "insulation": 0.3}
	)


func _drop_refusal() -> void:
	var plan: CityPlan = _city.view.plan
	await _find_edge(
		"drop",
		"refuse",
		func(probe: Dictionary) -> bool:
			var z: PackedFloat32Array = probe["z"]
			var w: PackedFloat32Array = probe["w"]
			# Open ground on both sides (a cliff, not a floor or a wall walk).
			var pts: Array = probe["points"]
			for i: int in [0, 6]:
				var xz: Vector2 = pts[i]
				if absf(plan.walk_height(xz) - plan.ground_height(xz)) > 0.2:
					return false
			return z[12] < -3.5 and w[12] < 0.05
	)
