extends "res://tests/godot/test_case.gd"

## ADR 0053: the GDScript port of the skeleto-nn leap network decides like the Python trainer
## (golden scenes exported with the weights), the probe reads wall tops from the logic collision,
## and the hero's jump plays a decision out: over a churchyard wall, off a quay into the water, or
## a refusal at a drop onto stone.

const LeapNet := preload("res://scripts/motion/motion_leap_net.gd")
const LeapProbe := preload("res://scripts/motion/motion_leap_probe.gd")
const PlayerLeap := preload("res://scripts/player/player_leap.gd")
const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")
const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const GOLDEN := "res://tests/godot/fixtures/motion/leap_net_golden.json"
const PX := 32.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	super.after_each()


func test_network_decides_like_python() -> void:
	var net: RefCounted = LeapNet.shared()
	assert_true(net != null, "leap net loads")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))["cases"]
	assert_true(cases.size() > 20, "golden scenes")
	for case: Dictionary in cases:
		var d: Dictionary = net.decide(
			StringName(case["kind"]),
			case["mass"],
			case["leg"],
			case["speed"],
			case["gain"],
			case["urgency"],
			case["channels"],
			PackedFloat32Array(case["z"]),
			PackedFloat32Array(case["w"]),
			case["standable"]
		)
		var want: Dictionary = case["expect"]
		var tag := "%s %s" % [case["scene"], case["conditions"]]
		assert_eq(d["action"], want["action"], tag + " action")
		assert_eq(d["label"], want["label"], tag + " label")
		if want["action"] != "jump":
			continue
		assert_eq(int(d["cell"]), int(want["cell"]), tag + " landing place")
		for k: String in want["knobs"]:
			assert_almost_eq(float(d["knobs"][k]), float(want["knobs"][k]), 2e-3, tag + " " + k)
		for k: String in ["land_m", "land_z_m", "apex_m", "flight_s", "take_m"]:
			assert_almost_eq(float(d[k]), float(want[k]), 2e-3, tag + " " + k)


## A wall across the way: a polygon tagged with the world height of its top, as
## CityCollisionBuilder tags site walls.
func _wall(x0_m: float, thick_m: float, top: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array(
		[
			Vector2(x0_m, -5.0) * PX,
			Vector2(x0_m + thick_m, -5.0) * PX,
			Vector2(x0_m + thick_m, 5.0) * PX,
			Vector2(x0_m, 5.0) * PX,
		]
	)
	if not is_nan(top):
		shape.set_meta(LeapProbe.TOP_META, top)
	body.add_child(shape)
	(Engine.get_main_loop() as SceneTree).root.add_child(body)
	_nodes.append(body)


func _space() -> PhysicsDirectSpaceState2D:
	return (Engine.get_main_loop() as SceneTree).root.get_world_2d().direct_space_state


func _flat(_xz: Vector2) -> Vector2:
	return Vector2(0.0, -INF)


func test_probe_reads_wall_tops_and_unknown_solids() -> void:
	_wall(0.6, 0.4, 0.85)
	_wall(3.0, 1.0, NAN)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var p: Dictionary = LeapProbe.profile(
		_space(), _flat, Vector2.ZERO, Vector2.RIGHT, 0.86, 20, 0.25, PX
	)
	var z: PackedFloat32Array = p["z"]
	# Samples every 0.215 m: 0.645 and 0.86 m are on the wall, 3.01 .. 3.87 m in the house.
	assert_almost_eq(z[2], 0.85, 1e-4, "wall top")
	assert_false(bool(p["standable"][2]), "a wall top is not a place to stand")
	assert_almost_eq(z[0], 0.0, 1e-4, "street before the wall")
	assert_almost_eq(z[14], LeapProbe.UNKNOWN_HEIGHT, 1e-4, "an untagged solid counts as tall")


func _leap(ground_fn: Callable) -> RefCounted:
	var leap: RefCounted = PlayerLeap.new()
	leap.plan(_space(), ground_fn, Vector2.ZERO, Vector2.RIGHT, 0.0, {})
	return leap


## Plays a planned jump to the end; returns [highest height above the start, final position].
func _play(leap: RefCounted) -> Array:
	var pos := Vector2.ZERO
	var top := -INF
	for i in 400:
		if not leap.is_active():
			break
		pos = leap.advance(1.0 / 60.0, pos)
		top = maxf(top, leap.height_above(0.0))
	return [top, pos]


func test_hero_vaults_a_churchyard_wall() -> void:
	_wall(0.6, 0.4, 0.85)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var leap: RefCounted = _leap(_flat)
	assert_eq(leap.decision["action"], "jump", "the wall is crossed")
	assert_true(
		String(leap.decision["label"]) in ["vault", "hop over"], str(leap.decision["label"])
	)
	assert_true(leap.has_hand_point, "hands go to the wall top")
	assert_almost_eq(leap.hand_point.y, 0.85, 1e-3, "on the top")
	var out := _play(leap)
	assert_true(float(out[0]) > 0.5, "the body rises over the wall: %.2f" % out[0])
	assert_true((out[1] as Vector2).x / PX > 1.0, "lands beyond the wall: %.2f m" % [out[1].x / PX])


func _quay(xz: Vector2) -> Vector2:
	# A quay edge at 0.6 m: the harbour bed 2 m down beyond it, water 2.5 m deep on the bed.
	return Vector2(0.0, -INF) if xz.x < 0.6 else Vector2(-2.0, 0.5)


func test_hero_jumps_off_a_quay_into_deep_water() -> void:
	var leap: RefCounted = _leap(_quay)
	assert_eq(leap.decision["action"], "jump", "jumps in")
	assert_eq(leap.decision["label"], "jump into water")
	assert_true(float(leap.decision["water_m"]) > 1.5, "lands where it is deep")


func _cliff(xz: Vector2) -> Vector2:
	return Vector2(0.0, -INF) if xz.x < 0.6 else Vector2(-6.0, -INF)


func test_hero_refuses_a_drop_onto_stone_and_balks() -> void:
	var leap: RefCounted = _leap(_cliff)
	assert_eq(leap.decision["action"], "refuse", "6 m onto stone is refused")
	assert_eq(leap.phase, PlayerLeap.Phase.REFUSE, "a balk at the edge")
	assert_eq(leap.animation(), &"idle")
	var out := _play(leap)
	assert_eq(out[1], Vector2.ZERO, "stays at the edge")


func test_ice_makes_the_wall_a_refusal() -> void:
	_wall(0.6, 0.4, 0.85)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var leap: RefCounted = PlayerLeap.new()
	var icy := {"friction": 0.09, "air_temp": -5.0}
	leap.plan(_space(), _flat, Vector2.ZERO, Vector2.RIGHT, 0.0, icy)
	assert_eq(leap.decision["action"], "refuse", "no vault from ice")


## Distance of the hands' midpoint from the hand point, with the rig where the jump has it a
## fraction `u` into the flight; `hands` false poses the same moment with the arms free.
func _hand_gap(u: float, hands: bool) -> float:
	var leap: RefCounted = _leap(_flat)
	var pos := Vector2.ZERO
	while leap.phase != PlayerLeap.Phase.FLIGHT or leap.elapsed < u * leap.flight_sec:
		pos = leap.advance(1.0 / 120.0, pos)
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	_nodes.append(rig)
	rig.set_facing(Vector2.RIGHT)
	rig.play_animation(&"jump_air", 0.0)
	rig.global_position = Vector3(pos.x / PX, leap.height_above(0.0), pos.y / PX)
	var pose: Dictionary = leap.pose()
	if not hands:
		pose["hand_weight"] = 0.0
	MotionStylePresenter.leap(rig, pose)
	var sk := rig.skeleton()
	assert_true(sk.get_node_or_null("LeapPose") != null, "pose layer installed")
	var gap := [INF]
	var read := func() -> void:
		var l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.l")).origin
		var r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.r")).origin
		gap[0] = ((l + r) * 0.5).distance_to(leap.hand_point)
	sk.skeleton_updated.connect(read)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	sk.skeleton_updated.disconnect(read)
	return gap[0]


func test_pose_layer_puts_the_hands_on_the_wall() -> void:
	_wall(0.6, 0.4, 0.85)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var with_hands := await _hand_gap(0.3, true)
	var without := await _hand_gap(0.3, false)
	assert_true(
		with_hands < without - 0.2 and with_hands < 0.3,
		"hands go to the wall top: %.2f m (arms free: %.2f m)" % [with_hands, without]
	)
