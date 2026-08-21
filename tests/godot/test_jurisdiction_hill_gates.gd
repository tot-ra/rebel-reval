extends "res://tests/godot/test_case.gd"

const JurisdictionModelScript := preload("res://scripts/world/jurisdiction_model.gd")
const HillGateControllerScript := preload("res://scripts/world/hill_gate_curfew_controller.gd")
const MapRrmapParserScript := preload("res://scripts/map/rrmap/map_rrmap_parser.gd")

const TOOMPEA_RRMAP := "res://content/maps/toompea_quarter.rrmap"


func test_toompea_jurisdiction_contract_is_closed_and_inactive() -> void:
	assert_true(JurisdictionModelScript.is_known(JurisdictionModelScript.JURISDICTION_TOOMPEA_DANISH))
	assert_true(JurisdictionModelScript.is_known(JurisdictionModelScript.JURISDICTION_ALL_LINN_LUBECK))
	assert_eq(
		JurisdictionModelScript.jurisdiction_for_map(JurisdictionModelScript.TOOMPEA_MAP_ID),
		JurisdictionModelScript.JURISDICTION_TOOMPEA_DANISH
	)
	var parsed := MapRrmapParserScript.parse_file(TOOMPEA_RRMAP)
	assert_true(parsed.is_ok(), "Toompea RRMap must remain parseable")
	assert_false(parsed.definition.active, "P4-040 must not activate Toompea")
	var snapshot := JurisdictionModelScript.developer_snapshot(
		JurisdictionModelScript.TOOMPEA_MAP_ID,
		parsed.definition.active
	)
	assert_false(bool(snapshot["active"]), "inactive transitions stay developer-visible only")
	assert_eq((snapshot["transitions"] as Array).size(), 2)


func test_day_opens_both_hill_gates_and_night_closes_from_lower_town() -> void:
	var state := GameState.new()
	var controller := HillGateControllerScript.new()
	controller.setup(state)

	assert_false(controller.sync_for_phase(GameState.PHASE_INVESTIGATION_MORNING))
	assert_eq(controller.get_gate_state(controller.GATE_PIKK_JALG), controller.GATE_STATE_OPEN)
	assert_eq(controller.get_gate_state(controller.GATE_LUHIKE_JALG), controller.GATE_STATE_OPEN)
	assert_true(controller.sync_for_phase(GameState.PHASE_INVESTIGATION_NIGHT))
	assert_eq(controller.get_gate_state(controller.GATE_PIKK_JALG), controller.GATE_STATE_CLOSED)
	assert_eq(controller.get_gate_state(controller.GATE_LUHIKE_JALG), controller.GATE_STATE_CLOSED)
	assert_false(
		controller.sync_for_phase(GameState.PHASE_INVESTIGATION_NIGHT, false),
		"upper-town callers must not toggle the Lower Town watch state"
	)
	assert_true(controller.sync_for_phase(GameState.PHASE_REFLECTION_MORNING))
	assert_eq(controller.get_gate_state(controller.GATE_PIKK_JALG), controller.GATE_STATE_OPEN)
	assert_eq(controller.get_gate_state(controller.GATE_LUHIKE_JALG), controller.GATE_STATE_OPEN)


func test_gate_states_round_trip_through_game_state_save_payload() -> void:
	var original := GameState.new()
	var controller := HillGateControllerScript.new()
	controller.setup(original)
	controller.sync_for_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	var payload := original.save_payload()

	var restored := GameState.new()
	assert_eq(restored.load_payload(payload), [])
	var restored_controller := HillGateControllerScript.new()
	restored_controller.setup(restored)
	assert_eq(restored_controller.gate_states(), controller.gate_states())
	assert_eq(
		restored.get_location_state(&"hill_gate.pikk_jalg"),
		HillGateControllerScript.GATE_STATE_CLOSED
	)
	assert_eq(
		restored.get_location_state(&"hill_gate.luhike_jalg"),
		HillGateControllerScript.GATE_STATE_CLOSED
	)


func test_transition_contracts_bind_both_gate_ids_to_all_linn() -> void:
	var contracts := JurisdictionModelScript.transition_contracts()
	for contract in contracts:
		assert_true(
			JurisdictionModelScript.TOOMPEA_TRANSITION_IDS.has(contract["transition_id"])
		)
		assert_true(HillGateControllerScript.is_known_gate(contract["gate_id"]))
		assert_eq(
			contract["from_jurisdiction"],
			JurisdictionModelScript.JURISDICTION_TOOMPEA_DANISH
		)
		assert_eq(
			contract["to_jurisdiction"],
			JurisdictionModelScript.JURISDICTION_ALL_LINN_LUBECK
		)
