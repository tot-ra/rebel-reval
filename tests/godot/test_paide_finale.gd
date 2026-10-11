extends "res://tests/godot/test_case.gd"

const FinaleModel := preload("res://scripts/quest/paide_finale_model.gd")


func test_every_player_role_preserves_attested_killing_and_selects_distinct_opening() -> void:
	var openings: Array[String] = []
	for role: StringName in FinaleModel.PLAYER_ROLES:
		var state := _forewarned_state(true)
		var record: Dictionary = FinaleModel.record_transition(state, role)
		var validation: Dictionary = FinaleModel.validate_record(record)

		assert_true(validation["valid"], "%s: %s" % [String(role), str(validation["errors"])])
		assert_true(record["four_kings_killed"], "history must not branch for %s" % role)
		assert_eq(String(record["player_role"]), String(role))
		assert_eq(state.get_phase(), FinaleModel.PHASE_ACT3_OPENING)
		assert_eq(state.get_quest_state(FinaleModel.QUEST_ID), FinaleModel.QUEST_STATE_COMPLETE)
		openings.append(String(record["act3_opening_state"]))

	assert_eq(openings.size(), 3)
	assert_ne(openings[0], openings[1])
	assert_ne(openings[0], openings[2])
	assert_ne(openings[1], openings[2])


func test_knowledge_and_warning_states_produce_distinct_validated_records() -> void:
	var cases: Array[Dictionary] = [
		{
			"state": GameState.new(),
			"knowledge": FinaleModel.KNOWLEDGE_UNAWARE,
			"warning": FinaleModel.WARNING_NOT_ATTEMPTED,
		},
		{
			"state": _forewarned_state(false),
			"knowledge": FinaleModel.KNOWLEDGE_FOREWARNED,
			"warning": FinaleModel.WARNING_INTERCEPTED,
		},
		{
			"state": _forewarned_state(true),
			"knowledge": FinaleModel.KNOWLEDGE_FOREWARNED,
			"warning": FinaleModel.WARNING_DELIVERED,
		},
	]
	var signatures: Array[String] = []
	for row: Dictionary in cases:
		var record: Dictionary = FinaleModel.record_transition(
			row["state"], FinaleModel.ROLE_WARNING_COURIER
		)
		var validation: Dictionary = FinaleModel.validate_record(record)
		assert_true(validation["valid"], str(validation["errors"]))
		assert_eq(String(record["knowledge_state"]), String(row["knowledge"]))
		assert_eq(String(record["warning_state"]), String(row["warning"]))
		assert_true(record["four_kings_killed"])
		signatures.append("%s:%s" % [record["knowledge_state"], record["warning_state"]])

	assert_eq(signatures.size(), 3)
	assert_ne(signatures[0], signatures[1])
	assert_ne(signatures[1], signatures[2])


func test_finale_record_round_trips_and_cannot_be_rewritten() -> void:
	var state := _forewarned_state(true)
	var original: Dictionary = FinaleModel.record_transition(
		state, FinaleModel.ROLE_WARNING_COURIER
	)
	assert_false(original.is_empty())

	# Inputs may change after the boundary, but the frozen role/result flags win.
	state.set_fact(FinaleModel.FACT_BETRAYAL_KNOWN, false)
	state.set_flag(FinaleModel.FLAG_WARNING_DELIVERED, false)
	assert_eq(FinaleModel.record_transition(state, FinaleModel.ROLE_HALL_WITNESS), {})

	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	var restored_record: Dictionary = FinaleModel.build_record(restored)
	var validation: Dictionary = FinaleModel.validate_state(restored)
	assert_true(validation["valid"], str(validation["errors"]))
	assert_eq(restored_record, original)


func test_invalid_or_history_rewriting_records_are_rejected() -> void:
	var invalid_state := GameState.new()
	assert_eq(FinaleModel.record_transition(invalid_state, &"unknown_role"), {})

	var state := _forewarned_state(true)
	var record: Dictionary = FinaleModel.record_transition(
		state, FinaleModel.ROLE_HALL_WITNESS
	)
	record["four_kings_killed"] = false
	var validation: Dictionary = FinaleModel.validate_record(record)
	assert_false(validation["valid"])
	assert_true(str(validation["errors"]).contains("must remain true"))

	record = FinaleModel.build_record(state)
	record["act3_opening_state"] = String(FinaleModel.OPENING_BETRAYAL_RECONSTRUCTED)
	validation = FinaleModel.validate_record(record)
	assert_false(validation["valid"])
	assert_true(str(validation["errors"]).contains("does not match player_role"))


func _forewarned_state(delivered: bool) -> GameState:
	var state := GameState.new()
	state.set_fact(FinaleModel.FACT_BETRAYAL_KNOWN, true)
	state.set_flag(FinaleModel.FLAG_WARNING_ATTEMPTED, true)
	state.set_flag(FinaleModel.FLAG_WARNING_DELIVERED, delivered)
	return state
