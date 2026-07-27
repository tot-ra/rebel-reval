extends "res://tests/godot/test_case.gd"

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const ModelScript := preload("res://scripts/world/supply_chain_model.gd")
const ControllerScript := preload("res://scripts/world/supply_chain_controller.gd")
const ConvoyScript := preload("res://scripts/world/supply_chain_convoy.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const MERCHANT_DIALOGUE_ID := &"dialogue.merchant.iron_shipment"
const CONVOY_DIALOGUE_ID := &"dialogue.supply.iron_convoy"
const QUEST_ID := &"quest.iron_shipment"

var db: ContentDB
var state: GameState
var presenter: DialogueTestPresenter
var runner: DialogueRunner
var definition: MapDefinition


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	presenter = PresenterScript.new()
	runner = RunnerScript.new()
	runner.configure(db, state, presenter)
	definition = LowerTownSlice.create()


func test_model_resolves_iron_convoy_patrol_from_definition() -> void:
	var points := ModelScript.resolve_patrol_points(definition)
	assert_eq(points.size(), 5)
	assert_true(points[0].distance_squared_to(points[1]) > 1.0)


func test_convoy_active_only_during_investigation_morning() -> void:
	assert_true(ModelScript.convoy_active_for_phase(GameState.PHASE_INVESTIGATION_MORNING))
	assert_false(ModelScript.convoy_active_for_phase(GameState.PHASE_INVESTIGATION_NIGHT))


func test_disruption_flag_disables_convoy_route() -> void:
	state.set_flag(ModelScript.FLAG_DISRUPTED, true)
	assert_true(ModelScript.is_route_disrupted(state))
	var convoy := ConvoyScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(convoy)
	convoy.configure(ModelScript.resolve_patrol_points(definition))
	convoy.set_route_enabled(not ModelScript.is_route_disrupted(state))
	assert_false(convoy.is_route_enabled())
	convoy.queue_free()


func test_quest_delivered_transition_when_convoy_arrives() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	var manager := QuestManager.new(db, state)
	assert_true(manager.start_quest(QUEST_ID))
	state.set_fact(ModelScript.FACT_ARRIVED, true)
	assert_true(manager.transition(QUEST_ID, ModelScript.TRANSITION_DELIVERED))
	assert_eq(state.get_quest_state(QUEST_ID), &"delivered")
	assert_true(state.get_flag(&"flag.supply.iron_in_stock"))


func test_quest_disrupted_transition_when_route_blocked() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	var manager := QuestManager.new(db, state)
	assert_true(manager.start_quest(QUEST_ID))
	state.set_flag(ModelScript.FLAG_DISRUPTED, true)
	assert_true(manager.transition(QUEST_ID, ModelScript.TRANSITION_DISRUPTED))
	assert_eq(state.get_quest_state(QUEST_ID), &"disrupted")
	assert_true(state.get_flag(&"flag.supply.iron_shortage"))


func test_merchant_dialogue_differs_between_delivered_and_disrupted() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.set_quest_state(QUEST_ID, &"delivered")
	assert_true(runner.start(MERCHANT_DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_delivered_opening")

	state.set_quest_state(QUEST_ID, &"disrupted")
	assert_true(runner.start(MERCHANT_DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_disrupted_opening")


func test_convoy_dialogue_sets_disruption_flag() -> void:
	assert_true(runner.start(CONVOY_DIALOGUE_ID))
	runner.advance_for_test()
	assert_true(runner.select_choice("block_route"))
	assert_true(state.get_flag(ModelScript.FLAG_DISRUPTED))


func test_convoy_patrol_points_keep_required_anchor_clearance() -> void:
	var points := ModelScript.resolve_patrol_points(definition)
	var required_anchors: Array[StringName] = [
		&"smithy_door",
		&"brewery_door",
		&"street_start",
		&"checkpoint_west",
		&"checkpoint_east",
	]
	var min_clearance_sq := 24.0 * 24.0
	for anchor_id: StringName in required_anchors:
		var anchor_pos := MapVerification.anchor_position(definition, anchor_id)
		assert_ne(anchor_pos, Vector2.ZERO, "Missing anchor %s" % anchor_id)
		for point: Vector2 in points:
			assert_true(
				anchor_pos.distance_squared_to(point) >= min_clearance_sq,
				"Convoy point %s sits too close to %s" % [point, anchor_id]
			)
