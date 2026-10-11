extends "res://tests/godot/test_case.gd"

const PointScript := preload("res://scripts/world/smithy_activity_point.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")

const KALEV := &"char.kalev"
const MART := &"char.mart"
const HENNING := &"char.henning"
const ROUTINE_PATH := "res://content/routines/kalev_smithy.json"


func _make_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = DefinitionScript.load_from_file(ROUTINE_PATH)
	return controller


func _prologue_context(time_band: StringName = &"morning", extra: Dictionary = {}) -> Dictionary:
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": time_band,
		"seed": 1343,
		"mart_missing": true,
		"visitor_allowed": true,
	}
	for key in extra.keys():
		context[key] = extra[key]
	return context


func test_definition_loads_all_authored_activity_points() -> void:
	var definition := DefinitionScript.load_from_file(ROUTINE_PATH)
	assert_eq(definition.map_id, &"loc.kalev_smithy")
	assert_true(definition.all_activity_ids().size() >= 20)
	var wake := definition.get_activity_point(&"ap.sleep.wake")
	assert_true(wake != null)
	assert_eq(wake.prop_id, &"bed")
	assert_eq(wake.approach_position, PointScript.cell_center_to_position(Vector2i(4, 11)))


func test_pick_next_activity_is_deterministic_for_seed() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"morning")
	var first := controller.pick_next_activity(KALEV, context)
	var second := controller.pick_next_activity(KALEV, context)
	assert_eq(first, &"ap.fetch.water")
	assert_eq(second, &"ap.prepare.board")

	var replay := _make_controller()
	assert_eq(replay.pick_next_activity(KALEV, context), first)
	assert_eq(replay.pick_next_activity(KALEV, context), second)
	controller.free()
	replay.free()


func test_exclusive_station_blocks_second_actor() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"midday")
	assert_true(controller.begin_activity(KALEV, &"ap.eat.table", context))
	assert_true(controller.is_occupied(&"ap.eat.table"))
	assert_false(controller.can_begin(MART, &"ap.eat.table", context))
	controller.end_activity(KALEV, ControllerScript.REASON_COMPLETED)
	assert_false(controller.is_occupied(&"ap.eat.table"))
	controller.free()


func test_occupied_target_falls_back_to_authored_alternate() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"midday", {"mart_missing": false})
	assert_true(controller.begin_activity(KALEV, &"ap.eat.table", context))
	var fallback := controller.resolve_blocked_target(MART, &"ap.eat.table", context)
	assert_eq(fallback, &"ap.prepare.board")
	controller.free()


func test_navigation_failure_uses_fallback_and_releases_assignment() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"midday")
	assert_true(controller.begin_activity(KALEV, &"ap.hearth.cookpot", context))
	var fallback := controller.report_navigation_failure(KALEV, &"ap.hearth.cookpot", context)
	assert_eq(fallback, &"ap.hearth.tend")
	assert_eq(controller.active_activity_for(KALEV), &"ap.hearth.tend")
	controller.free()


func test_dialogue_interrupt_resume_restores_same_activity() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"morning")
	assert_true(controller.begin_activity(KALEV, &"ap.prepare.board", context))
	var snapshot := controller.interrupt_for_dialogue(KALEV, context)
	assert_eq(snapshot.get("activity_id"), &"ap.prepare.board")
	assert_eq(controller.active_activity_for(KALEV), &"")
	assert_true(controller.resume_after_dialogue(KALEV))
	assert_eq(controller.active_activity_for(KALEV), &"ap.prepare.board")
	controller.free()


func test_dialogue_interrupt_cancel_drops_resume_state() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"morning")
	assert_true(controller.begin_activity(KALEV, &"ap.prepare.board", context))
	controller.interrupt_for_dialogue(KALEV, context)
	controller.cancel_after_dialogue(KALEV)
	assert_false(controller.resume_after_dialogue(KALEV))
	assert_eq(controller.active_activity_for(KALEV), &"")
	controller.free()


func test_mart_absent_while_mart_missing_flag_set() -> void:
	var controller := _make_controller()
	var context := {
		"phase_id": GameState.PHASE_INVESTIGATION_MORNING,
		"time_band": &"morning",
		"mart_missing": true,
	}
	assert_false(controller.can_begin(MART, &"ap.wash.basin", context))
	controller.free()


func test_henning_visitor_sequence_advances_without_coordinate_loop() -> void:
	var controller := _make_controller()
	var context := _prologue_context(&"any", {"visitor_allowed": true})
	var steps: Array[StringName] = []
	for _i in 5:
		var next := controller.pick_next_activity(HENNING, context)
		if next.is_empty():
			break
		assert_true(controller.begin_activity(HENNING, next, context))
		steps.append(next)
		controller.end_activity(HENNING, ControllerScript.REASON_COMPLETED)
	assert_eq(
		steps,
		[
			&"ap.visitor.enter",
			&"ap.visitor.wait",
			&"ap.visitor.inspect",
			&"ap.visitor.talk",
			&"ap.visitor.leave",
		]
	)
	controller.free()


func test_requires_approach_before_start_until_actor_reaches_transform() -> void:
	var controller := _make_controller()
	var point := controller.get_activity_point(&"ap.forge.anvil")
	assert_true(
		controller.requires_approach_before_start(KALEV, &"ap.forge.anvil", Vector2.ZERO)
	)
	assert_false(
		controller.requires_approach_before_start(KALEV, &"ap.forge.anvil", point.approach_position)
	)
	controller.free()
