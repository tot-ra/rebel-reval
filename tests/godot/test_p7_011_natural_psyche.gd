extends "res://tests/godot/test_case.gd"

const EvaluatorScript := preload("res://scripts/state/state_rule_evaluator.gd")
const ReflectionModelScript := preload("res://scripts/reflection/reflection_model.gd")


func test_natural_and_psyche_round_trip_through_save_service() -> void:
	var state := GameState.new()
	assert_eq(state.get_natural_aspect_rank(&"aspect.nature"), 5)
	assert_true(state.grant_natural_points(2))
	assert_eq(state.spend_natural_point(&"aspect.nature"), &"")
	assert_eq(state.get_natural_aspect_rank(&"aspect.nature"), 6)
	assert_eq(state.get_natural_unspent_points(), 1)
	assert_eq(state.apply_psyche_state(&"psyche.state.ruthless", 2, &"beat.test"), &"")
	assert_eq(state.get_natural_effective_aspect_rank(&"aspect.tenacity"), 9)
	assert_true(state.set_psyche_face_integration(&"face.shadow", 4))
	state.set_flag(&"flag.natural.system_enabled", true)

	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_eq(restored.get_natural_aspect_rank(&"aspect.nature"), 6)
	assert_eq(restored.get_natural_unspent_points(), 1)
	assert_eq(restored.get_natural_effective_aspect_rank(&"aspect.tenacity"), 9)
	assert_eq(restored.get_psyche_states().size(), 1)
	assert_eq(restored.get_psyche_face_integration(&"face.shadow"), 4)


func test_natural_and_psyche_effects_and_reflection_host_are_data_shaped() -> void:
	var state := GameState.new()
	var evaluator := EvaluatorScript.new()
	assert_true(evaluator.apply_effect({"op": "natural.grant_points", "amount": 1}, state))
	assert_true(
		evaluator.apply_effect(
			{"op": "natural.spend_point", "key": "aspect.light"}, state
		)
	)
	assert_true(
		evaluator.apply_effect(
			{
				"op": "psyche.apply_state",
				"key": "psyche.state.melancholy",
				"intensity": 1,
				"source_beat": "beat.test",
			},
			state
		)
	)
	assert_eq(evaluator.get_last_error(), "")
	var snapshot := ReflectionModelScript.build_snapshot(state)
	assert_eq((snapshot["natural_aspects"] as Array).size(), 7)
	assert_eq((snapshot["hingepuu_loci"] as Array).size(), 12)
	assert_eq((snapshot["psyche_states"] as Array).size(), 1)
	assert_eq(state.spend_natural_point(&"aspect.unknown"), &"natural.fail.unknown_aspect")
	assert_eq(state.clear_psyche_state(&"psyche.state.melancholy"), &"")
