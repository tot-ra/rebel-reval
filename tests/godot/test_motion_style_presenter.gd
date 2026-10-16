extends "res://tests/godot/test_case.gd"

## ADR 0051: the world's weather and season become motion conditions, and the style reaches the
## shared humanoid rig through MotionStyleModifier.

const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")
const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")

var _rigs: Array[SharedCharacterRig] = []


func after_each() -> void:
	for rig in _rigs:
		SharedCharacterRig._detach_render_geometry(rig)
		rig.free()
	_rigs.clear()
	MotionEnvironment.set_current(null)
	super.after_each()


func _env(
	temp_c: float, puddles: float, wind_strength: float = 0.0, wind_dir: Vector2 = Vector2.ZERO
) -> RefCounted:
	var env: RefCounted = MotionEnvironment.new()
	env.air_temp_c = temp_c
	env.puddle_wetness = puddles
	env.wind_strength = wind_strength
	env.wind_dir = wind_dir
	return env


func _names(conds: Array) -> Array:
	var out: Array = []
	for c: Variant in conds:
		if c is Array:
			out.append(String(c[0]))
	return out


func test_puddles_below_freezing_are_ice_and_above_are_wet_cobbles() -> void:
	assert_array_contains(
		_names(_env(-6.0, 0.6).conditions_at(Vector2.ZERO, Vector2(0, -1))), "ice"
	)
	assert_array_contains(
		_names(_env(8.0, 0.6).conditions_at(Vector2.ZERO, Vector2(0, -1))), "wet_cobbles"
	)
	assert_eq(
		_names(_env(8.0, 0.0).conditions_at(Vector2.ZERO, Vector2(0, -1))),
		[],
		"dry mild day: nothing"
	)


func test_wind_bearing_is_relative_to_the_body() -> void:
	# Facing -Z; the wind blows toward +X, so it comes from -X: the body's left.
	var conds: Array = _env(10.0, 0.0, 0.8, Vector2(1, 0)).conditions_at(
		Vector2.ZERO, Vector2(0, -1)
	)
	var gale: Array = []
	for c: Variant in conds:
		if c is Array and String(c[0]) == "gale":
			gale = c
	assert_false(gale.is_empty(), "wind becomes a gale condition")
	assert_almost_eq(float(gale[2]["dir"]), PI / 2.0, 1e-4, "from the left")


func _hand_spread(env: RefCounted, speed: float = 1.4) -> float:
	MotionEnvironment.set_current(env)
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	_rigs.append(rig)
	rig.play_animation(&"idle", 0.0)
	for i in 40:
		MotionStylePresenter.humanoid(rig, 0.05, speed)
	# Modified poses exist only between the modifier pass and the next frame: read them on the
	# signal.
	var sk := rig.skeleton()
	var spread := [0.0]
	var read := func() -> void:
		var l := sk.get_bone_global_pose(sk.find_bone("hand.l")).origin
		var r := sk.get_bone_global_pose(sk.find_bone("hand.r")).origin
		spread[0] = l.distance_to(r)
	sk.skeleton_updated.connect(read)
	for i in 3:
		await (Engine.get_main_loop() as SceneTree).process_frame
	sk.skeleton_updated.disconnect(read)
	return spread[0]


func test_modifier_is_installed_and_ice_spreads_the_arms() -> void:
	var calm := await _hand_spread(_env(10.0, 0.0))
	var icy := await _hand_spread(_env(-6.0, 0.9))
	assert_true(_rigs[0].skeleton().get_node_or_null("MotionStyle") != null, "modifier installed")
	assert_true(icy > calm * 1.15, "arms held out on ice: %.2f vs %.2f" % [icy, calm])


## R-2036: arms out is a mid-stride balance reflex; standing on ice keeps the idle arms.
func test_standing_on_ice_keeps_the_arms_down() -> void:
	var calm := await _hand_spread(_env(10.0, 0.0), 0.0)
	var icy := await _hand_spread(_env(-6.0, 0.9), 0.0)
	assert_true(icy < calm * 1.05, "standing on ice, arms at rest: %.2f vs %.2f" % [icy, calm])


func test_vitals_become_pain_and_fatigue() -> void:
	var conds := MotionStylePresenter.vitals_conditions(_FakeVitals.new())
	assert_almost_eq(float(conds[0]["pain_torso"]), 0.4, 1e-4)
	assert_almost_eq(float(conds[0]["fatigue"]), 0.75, 1e-4)


class _FakeVitals:
	extends RefCounted
	var health := 50.0
	var max_health := 100.0
	var stamina := 25.0
	var max_stamina := 100.0
