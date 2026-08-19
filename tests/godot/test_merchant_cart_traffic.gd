extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/cart_transport_controller.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)

const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const PHASE_NIGHT := GameState.PHASE_INVESTIGATION_NIGHT
const PHASE_SIEGE := ControllerScript.PHASE_ACT1_CLIMAX


func test_traffic_keeps_forum_and_harbour_before_siege() -> void:
	var traffic := ControllerScript.traffic_for_phase(PHASE_DAY, true)
	assert_eq(traffic.size(), 3)
	assert_array_contains(_ids(traffic), ControllerScript.PROP_VANATURG_QUEUE)
	assert_array_contains(_ids(traffic), ControllerScript.PROP_HARBOUR_GATE_CART)
	assert_array_contains(_ids(traffic), ControllerScript.PROP_VIRU_GRAIN_CART)


func test_siege_stalls_inland_grain_but_keeps_harbour_dressing() -> void:
	var traffic := ControllerScript.traffic_for_phase(PHASE_SIEGE, false)
	assert_eq(traffic.size(), 2)
	assert_array_contains(_ids(traffic), ControllerScript.PROP_VANATURG_QUEUE)
	assert_array_contains(_ids(traffic), ControllerScript.PROP_HARBOUR_GATE_CART)
	assert_false(_ids(traffic).has(ControllerScript.PROP_VIRU_GRAIN_CART))


func test_night_curfew_removes_ambient_carts_without_touching_iron_convoy_contract() -> void:
	var traffic := ControllerScript.traffic_for_phase(PHASE_NIGHT, true)
	assert_true(traffic.is_empty())
	assert_eq(ControllerScript.TRAFFIC_DESCRIPTORS.size(), 3)


func test_controller_updates_siege_flag_and_active_ids() -> void:
	var definition := LowerTownSlice.create()
	var state := GameState.new()
	state.set_phase(PHASE_DAY)
	var controller := ControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.setup(definition, null, &"loc.lower_town_slice", state)

	assert_true(state.get_flag(ControllerScript.FLAG_SIEGE_INLAND_CART_ACTIVE))
	assert_eq(controller.get_active_traffic().size(), 3)

	controller.sync_for_test(PHASE_SIEGE)
	assert_false(state.get_flag(ControllerScript.FLAG_SIEGE_INLAND_CART_ACTIVE))
	assert_eq(controller.get_active_traffic().size(), 2)

	controller.sync_for_test(PHASE_NIGHT)
	assert_eq(controller.get_active_traffic().size(), 0)
	controller.free()


func _ids(traffic: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for descriptor in traffic:
		result.append(descriptor["prop_id"])
	return result
