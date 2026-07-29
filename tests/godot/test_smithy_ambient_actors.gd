extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const MartScript := preload("res://scenes/reval_east/forge/smithy_mart.gd")

const MART := &"char.mart"
const KALEV := &"char.kalev"
const CAT := &"char.forge_cat"


func _make_merged_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = MartScript._merge_routine_overlay(
		"res://content/routines/kalev_smithy.json",
		"res://content/routines/mart_smithy.json"
	)
	return controller


func _make_cat_controller() -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.definition = MartScript._merge_routine_overlay(
		"res://content/routines/kalev_smithy.json",
		"res://content/routines/forge_cat.json"
	)
	return controller


func test_mart_hidden_while_mart_missing_flag_set() -> void:
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.set_routine_context(GameState.PHASE_INVESTIGATION_MORNING, &"morning", true)
	assert_false(mart.visible)
	assert_false(mart.is_physics_processing())
	mart.free()


func test_mart_routine_starts_when_mart_returns() -> void:
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.configure_navigation(RID(), Vector2(592, 176))
	mart.set_routine_context(GameState.PHASE_INVESTIGATION_MORNING, &"morning", false)
	assert_true(mart.visible)
	assert_true(mart.is_physics_processing())
	mart.free()


func test_mart_and_kalev_cannot_share_exclusive_station() -> void:
	var controller := _make_merged_controller()
	var context := {
		"phase_id": GameState.PHASE_INVESTIGATION_MORNING,
		"time_band": &"midday",
		"seed": 1343,
		"mart_missing": false,
	}
	assert_true(controller.begin_activity(KALEV, &"ap.eat.table", context))
	assert_false(controller.can_begin(MART, &"ap.eat.table", context))
	controller.free()


func test_mart_has_no_prologue_schedule() -> void:
	var controller := _make_merged_controller()
	assert_eq(controller.definition.schedule_for(MART, GameState.PHASE_PROLOGUE_DAY, &"morning").size(), 0)
	var mart := SmithyMart.new()
	_mount_actor(mart)
	mart.set_routine_context(GameState.PHASE_PROLOGUE_DAY, &"morning", false)
	assert_false(mart.visible)
	mart.free()
	controller.free()


func _mount_actor(actor: CharacterBody2D) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(actor)
