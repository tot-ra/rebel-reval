extends "res://tests/godot/test_case.gd"

## ADR 0051: the GDScript port of the skeleto-nn style network, condition registry and body state
## computes the same numbers as the Python trainer (golden vectors exported with the weights).

const MotionStyleNet := preload("res://scripts/motion/motion_style_net.gd")
const MotionConditions := preload("res://scripts/motion/motion_conditions.gd")
const MotionBodyState := preload("res://scripts/motion/motion_body_state.gd")
const MotionStyleAgent := preload("res://scripts/motion/motion_style_agent.gd")
const GOLDEN := "res://tests/godot/fixtures/motion/style_net_golden.json"


func _golden() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))


func test_network_loads_and_matches_python_raw_and_calibrated_styles() -> void:
	var net: RefCounted = MotionStyleNet.shared()
	assert_true(net != null, "style net loads")
	for case: Dictionary in _golden()["cases"]:
		var kind := StringName(case["kind"])
		var raw: Dictionary = net.style(
			kind, case["mass"], case["leg"], case["airborne"], case["froude"], case["channels"]
		)
		var cal: Dictionary = net.calibrated(
			kind, case["mass"], case["leg"], case["airborne"], case["froude"], case["channels"]
		)
		for k: String in case["raw"]:
			assert_almost_eq(
				raw[k], float(case["raw"][k]), 1e-3, "%s %s raw %s" % [kind, case["conditions"], k]
			)
			assert_almost_eq(
				cal[k],
				float(case["calibrated"][k]),
				1e-3,
				"%s %s calibrated %s" % [kind, case["conditions"], k]
			)


func test_condition_registry_matches_python_channels() -> void:
	var net: RefCounted = MotionStyleNet.shared()
	var reg: RefCounted = MotionConditions.shared(net)
	for case: Dictionary in _golden()["cases"]:
		var ch: Dictionary = reg.channels_from(case["conditions"])
		for k: String in case["channels"]:
			assert_almost_eq(
				float(ch[k]),
				float(case["channels"][k]),
				1e-4,
				"%s channel %s" % [case["conditions"], k]
			)


func test_body_state_matches_python_physiology() -> void:
	var net: RefCounted = MotionStyleNet.shared()
	var reg: RefCounted = MotionConditions.shared(net)
	var g: Dictionary = _golden()["physiology"]
	var b: RefCounted = MotionBodyState.new(70.0)
	var w: Dictionary = g["wound"]
	b.add_wound(w["region"], w["side"], float(w["rate"]), float(w["pain"]), reg)
	var trace: Array = g["trace"]
	var ti := 0
	for i in 600:
		var press := float(g["press_even_steps"]) if i % 2 == 0 else 0.0
		b.step(
			1.0,
			g["env"],
			{"rain": g["rain"]},
			g["style"],
			&"biped",
			false,
			float(g["power"]),
			press
		)
		if ti < trace.size() and i + 1 == int(trace[ti]["t"]):
			var row: Dictionary = trace[ti]
			assert_almost_eq(b.wet, float(row["wet"]), 1e-4, "wet at %d s" % (i + 1))
			assert_almost_eq(
				b.core_cold, float(row["core_cold"]), 1e-4, "core_cold at %d s" % (i + 1)
			)
			assert_almost_eq(
				b.blood_lost, float(row["blood_lost"]), 1e-4, "blood_lost at %d s" % (i + 1)
			)
			assert_almost_eq(b.bleed_rate(), float(row["bleed"]), 1e-4, "bleed at %d s" % (i + 1))
			ti += 1
	assert_eq(ti, trace.size(), "all golden rows checked")


func test_agent_adapts_on_ice_and_is_neutral_on_dry_ground() -> void:
	var dry: RefCounted = MotionStyleAgent.new(&"biped", 70.0, 0.9)
	var ice: RefCounted = MotionStyleAgent.new(&"biped", 70.0, 0.9)
	for i in 40:
		dry.update(0.05, [&"dry_ground"], {}, 1.3)
		ice.update(0.05, [&"ice"], {}, 1.3)
	assert_almost_eq(float(dry.style["stride"]), 1.0, 0.02, "dry: normal stride")
	assert_almost_eq(float(dry.style["arm_out"]), 0.0, 0.02, "dry: arms not out")
	assert_true(float(ice.style["stride"]) < 0.92, "ice: shorter steps")
	assert_true(float(ice.style["arm_out"]) > 0.4, "ice: arms out")
	assert_true(ice.speed_factor(1.3) < 0.8, "ice: slower")


func test_agent_wound_brings_the_hand_and_blood_loss_grows() -> void:
	var a: RefCounted = MotionStyleAgent.new(&"biped", 70.0, 0.9)
	a.add_wound("thigh", "L", 0.8, 0.5)
	a.body_time_scale = 20.0
	for i in 60:
		a.update(0.05, [], {}, 1.3)
	assert_true(float(a.style["press_L"]) > 0.6, "left hand presses the left thigh")
	assert_true(a.body.blood_lost > 0.0, "blood lost grows")


func test_quadruped_cannot_press_and_bird_flaps_harder_when_wet() -> void:
	var dog: RefCounted = MotionStyleAgent.new(&"quadruped", 25.0, 0.5)
	dog.add_wound("thigh", "L", 0.8, 0.5)
	var crow: RefCounted = MotionStyleAgent.new(&"bird", 0.45, 0.1)
	crow.airborne = true
	for i in 40:
		dog.update(0.05, [], {}, 1.4)
		crow.update(0.05, [&"drenched"], {}, 1.4)
	assert_eq(float(dog.style["press_L"]), 0.0, "a dog has no hand to press with")
	assert_true(float(dog.style["limp"]) > 0.3, "the dog limps off the wounded leg")
	assert_true(
		float(crow.style["flap_rate"]) * float(crow.style["flap_amp"]) > 1.05,
		"wet plumage: harder wingbeat"
	)
