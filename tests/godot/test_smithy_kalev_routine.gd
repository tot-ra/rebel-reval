extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)

const KALEV := &"char.kalev"
const ROUTINE_PATH := "res://content/routines/kalev_smithy.json"


func _make_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.configure_from_file(ROUTINE_PATH)
	return controller


func _prologue_context(time_band: StringName) -> Dictionary:
	var controller := _make_controller()
	var state := GameState.new()
	state.phase = GameState.PHASE_PROLOGUE_DAY
	state.set_flag(&"mart_missing", true)
	return controller.build_kalev_context(state, time_band)


func test_time_bands_map_cycle_progress_to_domestic_windows() -> void:
	assert_eq(ControllerScript.time_band_for_cycle_progress(5.0 / 24.0), &"dawn")
	assert_eq(ControllerScript.time_band_for_cycle_progress(8.0 / 24.0), &"morning")
	assert_eq(ControllerScript.time_band_for_cycle_progress(12.0 / 24.0), &"midday")
	assert_eq(ControllerScript.time_band_for_cycle_progress(18.0 / 24.0), &"evening")


func test_prologue_morning_lists_coherent_domestic_activities() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"morning")
	var available := controller.list_available_activities(KALEV, context)
	assert_true(available.has(&"ap.fetch.water"))
	assert_true(available.has(&"ap.prepare.board"))
	assert_true(available.has(&"ap.hearth.tend"))
	controller.free()


func test_prologue_midday_and_evening_activity_sets_differ() -> void:
	var controller := _make_controller()
	var midday := controller.list_available_activities(KALEV, _prologue_context(&"midday"))
	var evening := controller.list_available_activities(KALEV, _prologue_context(&"evening"))
	assert_true(midday.has(&"ap.eat.table"))
	assert_true(evening.has(&"ap.sweep.floor"))
	assert_true(evening.has(&"ap.hearth.bank"))
	controller.free()


func test_phase_entry_sets_hearth_and_table_variants() -> void:
	var controller := _make_controller()
	var dawn := controller.phase_entry_prop_variants(GameState.PHASE_PROLOGUE_DAY, &"dawn")
	var midday := controller.phase_entry_prop_variants(GameState.PHASE_PROLOGUE_DAY, &"midday")
	assert_eq(dawn.get("domestic_hearth"), "hearth.cold")
	assert_eq(midday.get("domestic_hearth"), "hearth.lit")
	assert_eq(midday.get("table_settings"), "kitchenware.group.eating")
	controller.free()


func test_activity_effects_update_props_and_held_socket() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"midday")
	controller.apply_kalev_activity_presentation(&"ap.hearth.tend", context)
	assert_eq(controller.presentation_held_socket(), &"")
	var variants := controller.activity_prop_variants(&"ap.hearth.tend")
	assert_eq(variants.get("domestic_hearth"), "hearth.lit")
	controller.complete_kalev_activity_presentation(&"ap.hearth.tend")
	controller.apply_kalev_activity_presentation(&"ap.wash.basin", context)
	assert_eq(controller.presentation_held_socket(), &"wash_cloth")
	controller.complete_kalev_activity_presentation(&"ap.wash.basin")
	assert_true(controller.presentation_held_socket().is_empty())
	controller.free()


func test_station_tolerance_accepts_authored_approach_positions() -> void:
	var controller := _make_controller()
	var wash := controller.get_activity_point(&"ap.wash.basin")
	assert_true(wash != null)
	assert_true(controller.station_within_tolerance(wash.approach_position, &"ap.wash.basin"))
	var offset := wash.approach_position + Vector2(ControllerScript.STATION_TOLERANCE_PX + 4.0, 0.0)
	assert_false(controller.station_within_tolerance(offset, &"ap.wash.basin"))
	controller.free()


func test_skipping_domestic_actions_keeps_kalev_unassigned() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"morning")
	assert_true(controller.active_activity_for(KALEV).is_empty())
	assert_true(controller.list_available_activities(KALEV, context).size() > 0)
	controller.free()


func test_prop_variants_persist_through_map_world_state() -> void:
	var controller := _make_controller()
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var state := GameState.new()
	var variants := {"domestic_hearth": "hearth.lit", "table_settings": "kitchenware.group.eating"}
	controller.persist_prop_variants(state, variants)
	var restored := controller.restore_prop_variants_from_state(state, definition)
	assert_eq(restored.get("domestic_hearth"), "hearth.lit")
	assert_eq(restored.get("table_settings"), "kitchenware.group.eating")
	controller.free()
