extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/world/environmental_consequence_model.gd")
const PressureScript := preload("res://scripts/faction/district_pressure_model.gd")
const SupplyScript := preload("res://scripts/world/supply_chain_model.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapPatrolController := preload("res://scripts/phase/map_patrol_controller.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const DISTRICT := ModelScript.DISTRICT_LOWER_TOWN

var _flag_unrest: StringName
var _flag_martial_law: StringName


func before_each() -> void:
	_flag_unrest = PressureScript.district_flag(DISTRICT, PressureScript.FLAG_UNREST_SUFFIX)
	_flag_martial_law = PressureScript.district_flag(
		DISTRICT,
		PressureScript.FLAG_MARTIAL_LAW_SUFFIX
	)


func test_baseline_hides_all_consequence_overlays() -> void:
	var state := GameState.new()
	var snapshot := ModelScript.resolve_snapshot(DISTRICT, state)
	assert_eq(snapshot.get("consequence_state"), ModelScript.STATE_BASELINE)
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_REBEL_GRAFFITI))
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_ORDER_NOTICE))
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_MARKET_GOODS))


func test_unrest_shows_rebel_graffiti_from_district_flag() -> void:
	var state := GameState.new()
	state.set_flag(_flag_unrest, true)
	var snapshot := ModelScript.resolve_snapshot(DISTRICT, state)
	assert_eq(snapshot.get("consequence_state"), ModelScript.STATE_UNREST)
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_REBEL_GRAFFITI))
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_ORDER_NOTICE))


func test_crackdown_shows_order_notice_and_hides_graffiti() -> void:
	var state := GameState.new()
	state.set_flag(_flag_unrest, true)
	state.set_flag(_flag_martial_law, true)
	var snapshot := ModelScript.resolve_snapshot(DISTRICT, state)
	assert_eq(snapshot.get("consequence_state"), ModelScript.STATE_CRACKDOWN)
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_REBEL_GRAFFITI))
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_ORDER_NOTICE))
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_WATCH_BARRICADE))
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_WALL_REPAIR))
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_MARKET_GOODS))


func test_supply_disruption_adds_scatter_and_hides_market_goods() -> void:
	var state := GameState.new()
	state.set_flag(SupplyScript.FLAG_DISRUPTED, true)
	var snapshot := ModelScript.resolve_snapshot(DISTRICT, state)
	assert_true(snapshot.get("supply_disrupted"))
	assert_true(ModelScript.prop_visible(snapshot, ModelScript.PROP_SUPPLY_SCATTER))
	assert_false(ModelScript.prop_visible(snapshot, ModelScript.PROP_MARKET_GOODS))


func test_unrest_and_supply_states_differ_visually() -> void:
	var unrest := ModelScript.resolve_snapshot(DISTRICT, _unrest_state())
	var supply := ModelScript.resolve_snapshot(DISTRICT, _supply_disrupted_state())
	assert_ne(
		unrest.get("visible_overlays", []),
		supply.get("visible_overlays", []),
		"Unrest and supply disruption must expose different overlay props"
	)
	assert_ne(
		ModelScript.prop_visible(unrest, ModelScript.PROP_MARKET_GOODS),
		ModelScript.prop_visible(supply, ModelScript.PROP_MARKET_GOODS)
	)


func test_consequence_props_do_not_block_required_patrols() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var patrol_points := MapPatrolController._resolve_points(definition, &"viru_watch")
	assert_false(patrol_points.is_empty())
	var min_clearance_sq := 12.0 * 12.0
	for prop_id: StringName in ModelScript.OVERLAY_PROPS_BY_DISTRICT[DISTRICT]:
		var position := MapVerification.prop_position(definition, prop_id)
		assert_ne(position, Vector2.ZERO, "Missing authored consequence prop %s" % String(prop_id))
		for point: Vector2 in patrol_points:
			assert_true(
				position.distance_squared_to(point) >= min_clearance_sq,
				"Consequence prop %s sits too close to Viru patrol point %s" % [prop_id, point]
			)


func _unrest_state() -> GameState:
	var state := GameState.new()
	state.set_flag(_flag_unrest, true)
	return state


func _supply_disrupted_state() -> GameState:
	var state := GameState.new()
	state.set_flag(SupplyScript.FLAG_DISRUPTED, true)
	return state
